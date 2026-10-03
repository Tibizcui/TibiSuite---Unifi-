--[[============================================================================
  PostBox_Mule - Mule automatique : des regles "telle categorie (ou tel
  objet) va a tel personnage", puis un clic envoie tout, 12 pieces jointes
  par courrier, un courrier apres l'autre.

  Categories = sous-classes des Fournitures d'artisanat (Tissu, Cuir, Metal et
  pierre, Herbe, Enchantement...), lues dans le jeu (C_Item.GetItemSubClassInfo).
  Suggestions de destinataire : les alts qui ont le metier correspondant,
  lus dans SkillTrackerDB (lecture seule) si SkillTracker est installe.

  Jamais envoye : objets lies (isBound), objets verrouilles, objets vers le
  personnage courant. Le formulaire Envoyer doit etre vide au depart.

  ENVOI : par defaut SendMail() est appele par PostBox apres chaque
  remplissage. A VERIFIER EN JEU : si le client exige un clic du joueur pour
  envoyer (ADDON_ACTION_BLOCKED / FORBIDDEN sur PostBox), la mule bascule
  aussitot en mode manuel : elle remplit et joint, le joueur clique sur
  Envoyer, et la mule enchaine le courrier suivant apres chaque envoi reussi.
============================================================================]]

local P = PostBox
P.Mule = P.Mule or {}
local M = P.Mule
local ACCENT = P.ACCENT
local L = P.L

local function GetUI() return _G.TibiMidnight end

local TRADE = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or 7
local SUBS = { 5, 6, 7, 9, 12, 4, 16, 8, 1, 10, 18, 19, 11 }
-- Sous-classe -> metiers (skill line parent) qui l'utilisent.
local PROF_BY_SUB = {
  [1] = { 202 }, [4] = { 755 }, [5] = { 197 }, [6] = { 165 }, [7] = { 164, 202, 755 },
  [8] = { 185 }, [9] = { 171, 773 }, [10] = { 171, 164, 197, 165 }, [12] = { 333 }, [16] = { 773 },
}

function M.SubName(sub)
  local fn = (C_Item and C_Item.GetItemSubClassInfo) or _G.GetItemSubClassInfo
  if fn then
    local ok, name = pcall(fn, TRADE, sub)
    if ok and name and name ~= "" then return name end
  end
  return "#" .. tostring(sub)
end

local function ItemName(id)
  local fn = (C_Item and C_Item.GetItemNameByID) or nil
  local n = fn and fn(id)
  if not n and _G.GetItemInfo then n = GetItemInfo(id) end
  return n or ("item:" .. id)
end

-- ============================================================================
-- REGLES
-- ============================================================================
local function Rules() return PostBoxDB.mule.rules end

function M.AddRule(to, kind, value)
  to = strtrim(to or "")
  if to == "" then print(L.MULE_NEED_RECIPIENT) return end
  local r = { to = to, kind = kind, on = true }
  if kind == "sub" then r.sub = value else r.itemID = value end
  table.insert(Rules(), r)
  M.Refresh()
end

function M.RuleLabel(r)
  if r.kind == "item" then
    local _, link = (C_Item and C_Item.GetItemInfo or GetItemInfo)(r.itemID)
    return link or ItemName(r.itemID)
  end
  return M.SubName(r.sub)
end

-- Suggestions : alts qui ont un metier lie a la sous-classe.
function M.Suggest(sub)
  local ids = PROF_BY_SUB[sub]
  local st = _G.SkillTrackerDB
  local out = {}
  if not ids or type(st) ~= "table" or type(st.chars) ~= "table" then return out end
  local selfKey = P.CharKey()
  local selfFaction = UnitFactionGroup("player")
  for realm, chars in pairs(st.chars) do
    if type(chars) == "table" and P.IsConnectedRealm(realm) then
      for name, rec in pairs(chars) do
        local key = name .. "-" .. realm
        if type(rec) == "table" and key ~= selfKey and not (rec.faction and rec.faction ~= selfFaction) then
          for _, pid in ipairs(ids) do
            local prof = rec.professions and rec.professions[pid]
            if prof then
              out[#out + 1] = { key = key, mail = P.MailName(key), prof = prof.name, class = rec.class }
              break
            end
          end
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.mail < b.mail end)
  return out
end

-- ============================================================================
-- PLAN : quels emplacements de sac partent vers qui
-- Les regles "objet precis" passent avant les regles de categorie.
-- ============================================================================
local function IsSelf(to)
  local key = P.ResolveOwnChar(to)
  if key and key == P.CharKey() then return true end
  return to:lower() == (UnitName("player") or ""):lower()
end

function M.BuildPlan()
  local ordered = {}
  for i, r in ipairs(Rules()) do
    r._count = 0
    if r.on and not IsSelf(r.to) then ordered[#ordered + 1] = r end
  end
  table.sort(ordered, function(a, b)
    if a.kind ~= b.kind then return a.kind == "item" end
    return false
  end)
  local groups, byTo = {}, {}
  local maxBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or ((NUM_BAG_SLOTS or 4) + 1)
  for bag = 0, maxBag do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID and not info.isBound and not info.isLocked then
        local _, _, _, _, _, classID, subID = (C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant)(info.itemID)
        for _, r in ipairs(ordered) do
          local hit = (r.kind == "item" and r.itemID == info.itemID)
            or (r.kind == "sub" and classID == TRADE and subID == r.sub)
          if hit then
            local k = r.to:lower()
            local g = byTo[k]
            if not g then g = { to = r.to, slots = {} }; byTo[k] = g; groups[#groups + 1] = g end
            g.slots[#g.slots + 1] = { bag = bag, slot = slot, id = info.itemID, n = info.stackCount or 1 }
            r._count = r._count + (info.stackCount or 1)
            break
          end
        end
      end
    end
  end
  return groups
end

-- ============================================================================
-- ENVOI EN FILE
-- ============================================================================
M.run = nil
M.forceManual = false
local runTimer

local function Status(text)
  local f = _G.PostBoxMuleFrame
  if f and f.status then f.status:SetText(text or "") end
end

function M.Stop(msg)
  if runTimer then runTimer:Cancel(); runTimer = nil end
  if msg then print(msg) end
  M.run = nil
  Status("")
  M.Refresh()
end

local function Finish()
  local run = M.run
  M.Stop(string.format(L.MULE_DONE_FMT, run and run.sent or 0, run and run.mails or 0))
end

function M.NextBatch()
  local run = M.run
  if not run then return end
  if not P.mailboxOpen then return M.Stop(L.MULE_STOPPED_CLOSED) end
  local grp = run.plan[run.pi]
  if not grp then return Finish() end
  -- Positions fraiches a chaque courrier (les sacs bougent entre deux envois).
  local fresh
  for _, g in ipairs(M.BuildPlan()) do
    if g.to:lower() == grp.to:lower() then fresh = g; break end
  end
  if not fresh or #fresh.slots == 0 then
    run.pi = run.pi + 1
    return M.NextBatch()
  end
  if P.CountSendAttachments() > 0 then return M.Stop(L.MULE_CLEAR_FIRST) end
  local count = math.min(#fresh.slots, ATTACHMENTS_MAX_SEND or 12)
  local subject = string.format(L.MULE_SUBJECT_FMT, count)
  if not P.BlackBook.FillSendForm(fresh.to, { subject = subject, body = "" }) then
    return M.Stop(L.MULE_STOPPED_CLOSED)
  end
  Status(string.format(L.MULE_STATUS_FMT, fresh.to, run.mails + 1))

  local i, attached = 0, 0
  local function attachTick()
    i = i + 1
    if not M.run then return end
    if i <= count then
      local s = fresh.slots[i]
      if P.BlackBook.QuickAttachFromBag(s.bag, s.slot, true) then attached = attached + 1 end
      runTimer = C_Timer.NewTimer(0.15, attachTick)
      return
    end
    if attached == 0 then
      run.pi = run.pi + 1
      runTimer = C_Timer.NewTimer(0.2, M.NextBatch)
      return
    end
    run.pending = attached
    run.waiting = true
    if GetSendMailPrice and GetSendMailPrice() > GetMoney() then
      return M.Stop(L.MULE_NO_GOLD)
    end
    if run.manual then
      print(string.format(L.MULE_CLICK_SEND_FMT, fresh.to))
      Status(string.format(L.MULE_CLICK_SEND_FMT, fresh.to))
    else
      local name = _G.SendMailNameEditBox and _G.SendMailNameEditBox:GetText() or fresh.to
      SendMail(name, subject, "")
      runTimer = C_Timer.NewTimer(15, function()
        if M.run and M.run.waiting then M.Stop(L.MULE_TIMEOUT) end
      end)
    end
  end
  runTimer = C_Timer.NewTimer(0.3, attachTick)
end

function M.Start()
  if not P.mailboxOpen then print(L.MSG_OPEN_MAILBOX_FIRST) return end
  if M.run then print(L.MSG_BUSY) return end
  if P.IsBusy() then print(L.MSG_BUSY) return end
  if P.CountSendAttachments() > 0 then print(L.MULE_CLEAR_FIRST) return end
  local plan = M.BuildPlan()
  if #plan == 0 then print(L.MULE_NOTHING) M.Refresh() return end
  local lines, slots = {}, 0
  for _, g in ipairs(plan) do
    lines[#lines + 1] = string.format(L.MULE_PLAN_LINE_FMT, g.to, #g.slots, math.ceil(#g.slots / (ATTACHMENTS_MAX_SEND or 12)))
    slots = slots + #g.slots
  end
  local text = L.MULE_CONFIRM .. "\n\n" .. table.concat(lines, "\n") .. "\n\n"
    .. string.format(L.MULE_POSTAGE_FMT, P.Coin(slots * 30))
  P.Confirm(text, function()
    M.run = { plan = plan, pi = 1, sent = 0, mails = 0, manual = (PostBoxDB.mule.autoSend == false) or M.forceManual }
    M.NextBatch()
  end)
end

P.OnSendResult(function(ok)
  local run = M.run
  if not run or not run.waiting then return end
  run.waiting = false
  if runTimer then runTimer:Cancel(); runTimer = nil end
  if ok then
    run.mails = run.mails + 1
    run.sent = run.sent + (run.pending or 0)
    runTimer = C_Timer.NewTimer(0.8, M.NextBatch)
  else
    M.Stop(L.MULE_SEND_FAILED)
  end
end)

-- Envoi bloque par le client : bascule en mode manuel pour le reste de la
-- session (le formulaire reste rempli, le joueur clique sur Envoyer).
local blockWatcher = CreateFrame("Frame")
blockWatcher:RegisterEvent("ADDON_ACTION_BLOCKED")
blockWatcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
blockWatcher:SetScript("OnEvent", function(_, _, addon)
  if addon == "PostBox" and M.run and M.run.waiting and not M.run.manual then
    M.forceManual = true
    M.run.manual = true
    if runTimer then runTimer:Cancel(); runTimer = nil end
    print(L.MULE_MANUAL_SWITCH)
    Status(L.MULE_MANUAL_SWITCH)
  end
end)

-- Fenetre ouverte : les compteurs "en sac" suivent les mouvements de sac.
local bagWatcher = CreateFrame("Frame")
bagWatcher:RegisterEvent("BAG_UPDATE_DELAYED")
bagWatcher:SetScript("OnEvent", function()
  local f = _G.PostBoxMuleFrame
  if f and f:IsShown() and not M.run then M.Refresh() end
end)

function M.OnMailClosed()
  if M.run then M.Stop(L.MULE_STOPPED_CLOSED) end
end

-- ============================================================================
-- FENETRE
-- ============================================================================
M.pickSub = 5

local function SubMenu(anchor)
  local UI = GetUI()
  local menu = _G.PostBoxMuleSubMenu
  if not menu then
    menu = CreateFrame("Frame", "PostBoxMuleSubMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("TOOLTIP")
    if UI then UI.SkinFrame(menu, ACCENT, UI.C.PANEL) end
    menu.rows = {}
    for i, sub in ipairs(SUBS) do
      local b = UI and UI.MakeButton(menu, 170, 18, "") or CreateFrame("Button", nil, menu)
      b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 19)
      b._label:ClearAllPoints(); b._label:SetPoint("LEFT", 6, 0); b._label:SetJustifyH("LEFT")
      b:SetScript("OnClick", function() M.pickSub = sub; menu:Hide(); M.Refresh() end)
      menu.rows[i] = { btn = b, sub = sub }
    end
    menu:SetSize(178, #SUBS * 19 + 8)
    menu:Hide()
  end
  for _, r in ipairs(menu.rows) do r.btn._label:SetText(M.SubName(r.sub)) end
  if menu:IsShown() then menu:Hide() return end
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  menu:Show()
end

local function RuleRow(parent)
  local UI = GetUI()
  local r = CreateFrame("Frame", nil, parent)
  r:SetSize(400, 22)
  local bg = r:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.03)
  r.bg = bg
  local cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
  cb:SetSize(18, 18); cb:SetPoint("LEFT", 2, 0)
  r.cb = cb
  local text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("LEFT", cb, "RIGHT", 4, 0); text:SetWidth(330); text:SetJustifyH("LEFT"); text:SetWordWrap(false)
  r.text = text
  local del = UI and UI.MakeButton(r, 20, 18, "x") or CreateFrame("Button", nil, r)
  del:SetPoint("RIGHT", -2, 0)
  r.del = del
  return r
end

function M.Refresh()
  local f = _G.PostBoxMuleFrame
  if not f or not f:IsShown() then return end
  f.subBtn._label:SetText(M.SubName(M.pickSub) .. "  v")

  -- Suggestions de destinataire pour la categorie choisie.
  local sugg = M.Suggest(M.pickSub)
  for i, b in ipairs(f.sugg) do
    local s = sugg[i]
    if s then
      local UI = GetUI()
      local c = UI and UI.ClassColor(s.class) or { 1, 1, 1 }
      b._label:SetText((UI and UI.Hex(c[1], c[2], c[3]) or "") .. s.mail .. "|r |cFF888888" .. (s.prof or "") .. "|r")
      b:SetScript("OnClick", function() f.toBox:SetText(s.mail) end)
      b:Show()
    else
      b:Hide()
    end
  end
  f.suggLabel:SetText(#sugg > 0 and L.MULE_SUGGEST or (_G.SkillTrackerDB and L.MULE_SUGGEST_NONE or L.MULE_SUGGEST_NOST))

  local plan = M.BuildPlan()
  local y = -2
  local rules = Rules()
  for i, r in ipairs(rules) do
    local row = f.rows[i]
    if not row then row = RuleRow(f.content); f.rows[i] = row end
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, y)
    local selfTag = IsSelf(r.to) and (" |cFFFF9933" .. L.MULE_SELF .. "|r") or ""
    row.text:SetText(string.format(L.MULE_RULE_FMT, M.RuleLabel(r), r.to, r._count or 0) .. selfTag)
    row.cb:SetChecked(r.on)
    row.cb:SetScript("OnClick", function(s) r.on = s:GetChecked() and true or false; M.Refresh() end)
    row.del:SetScript("OnClick", function() table.remove(rules, i); M.Refresh() end)
    row.bg:SetShown(i % 2 == 0)
    row:Show()
    y = y - 23
  end
  for i = #rules + 1, #f.rows do f.rows[i]:Hide() end
  f.content:SetHeight(math.max(-y + 4, 10))
  f.empty:SetShown(#rules == 0)

  local slots, mails = 0, 0
  for _, g in ipairs(plan) do
    slots = slots + #g.slots
    mails = mails + math.ceil(#g.slots / (ATTACHMENTS_MAX_SEND or 12))
  end
  f.summary:SetText(string.format(L.MULE_SUMMARY_FMT, slots, mails, #plan))
end

function M.BuildUI()
  if _G.PostBoxMuleFrame then return end
  local UI = GetUI()
  local f = CreateFrame("Frame", "PostBoxMuleFrame", UIParent, "BackdropTemplate")
  f:SetSize(440, 540)
  f:SetPoint("CENTER", -40, 20)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true); f:SetMovable(true); f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UI then UI.SkinFrame(f, ACCENT, UI.C.PANEL) end
  tinsert(UISpecialFrames, "PostBoxMuleFrame")
  f:SetScript("OnHide", function() if _G.PostBoxMuleSubMenu then _G.PostBoxMuleSubMenu:Hide() end end)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -12)
  title:SetText(P.AccentText(L.MULE_TITLE))
  local intro = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  intro:SetPoint("TOPLEFT", 16, -36); intro:SetWidth(408); intro:SetJustifyH("LEFT")
  intro:SetText(L.MULE_INTRO)

  -- Ligne d'ajout : destinataire + categorie + bouton
  local toLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  toLabel:SetPoint("TOPLEFT", 16, -76); toLabel:SetText(L.MULE_TO)
  local toBox = CreateFrame("EditBox", nil, f, "BackdropTemplate")
  toBox:SetSize(150, 22)
  toBox:SetPoint("TOPLEFT", 16, -92)
  if UI then
    toBox:SetBackdrop(UI.FlatBackdrop()); toBox:SetBackdropColor(0.02, 0.02, 0.03, 0.95)
    toBox:SetBackdropBorderColor(1, 1, 1, 0.15)
  end
  toBox:SetAutoFocus(false); toBox:SetFontObject("GameFontHighlightSmall"); toBox:SetTextInsets(6, 6, 0, 0)
  toBox:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  toBox:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
  P.AttachAutocomplete(toBox)
  f.toBox = toBox

  local subBtn = UI and UI.MakeButton(f, 150, 22, "") or CreateFrame("Button", nil, f)
  subBtn:SetPoint("LEFT", toBox, "RIGHT", 6, 0)
  subBtn:SetScript("OnClick", function(s) SubMenu(s) end)
  f.subBtn = subBtn

  local addBtn = P.Btn(f, 92, L.MULE_ADD, function() M.AddRule(toBox:GetText(), "sub", M.pickSub) end)
  addBtn:SetPoint("LEFT", subBtn, "RIGHT", 6, 0)

  -- Suggestions (SkillTracker)
  local suggLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  suggLabel:SetPoint("TOPLEFT", 16, -122); suggLabel:SetWidth(408); suggLabel:SetJustifyH("LEFT")
  f.suggLabel = suggLabel
  f.sugg = {}
  for i = 1, 3 do
    local b = UI and UI.MakeButton(f, 132, 20, "") or CreateFrame("Button", nil, f)
    b:SetPoint("TOPLEFT", 16 + (i - 1) * 138, -138)
    b:Hide()
    f.sugg[i] = b
  end

  -- Zone de depot : regle par objet precis
  local drop = UI and UI.MakeButton(f, 408, 26, L.MULE_DROP) or CreateFrame("Button", nil, f)
  drop:SetPoint("TOPLEFT", 16, -166)
  local function takeCursor()
    local kind, id = GetCursorInfo()
    if kind == "item" and id then
      ClearCursor()
      M.AddRule(toBox:GetText(), "item", id)
    end
  end
  drop:SetScript("OnReceiveDrag", takeCursor)
  drop:SetScript("OnClick", takeCursor)

  local rulesTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  rulesTitle:SetPoint("TOPLEFT", 16, -202); rulesTitle:SetText(P.AccentText(L.MULE_RULES))

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -220)
  scroll:SetPoint("BOTTOMRIGHT", -30, 96)
  if UI and UI.SkinScrollBar then UI.SkinScrollBar(scroll, ACCENT) end
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(400, 10)
  scroll:SetScrollChild(content)
  f.content, f.rows = content, {}
  local empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  empty:SetPoint("CENTER", scroll, "CENTER"); empty:SetWidth(360); empty:SetText(L.MULE_EMPTY)
  f.empty = empty

  local summary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  summary:SetPoint("BOTTOMLEFT", 16, 72); summary:SetWidth(408); summary:SetJustifyH("LEFT")
  f.summary = summary
  local status = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  status:SetPoint("BOTTOMLEFT", 16, 54); status:SetWidth(408); status:SetJustifyH("LEFT")
  f.status = status

  local refreshBtn = P.Btn(f, 120, L.BTN_REFRESH, function() M.Refresh() end)
  refreshBtn:SetPoint("BOTTOMLEFT", 14, 14)
  local stopBtn = P.Btn(f, 100, L.MULE_STOP, function() if M.run then M.Stop(L.MULE_STOPPED) end end)
  stopBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 6, 0)
  local goBtn = P.Btn(f, 170, L.MULE_SEND_ALL, function() M.Start() end, L.MULE_SEND_ALL_TIP)
  goBtn:SetPoint("BOTTOMRIGHT", -14, 14)

  f:Hide()
end

function M.Toggle()
  M.BuildUI()
  local f = _G.PostBoxMuleFrame
  if f:IsShown() then f:Hide() else f:Show(); M.Refresh() end
end
