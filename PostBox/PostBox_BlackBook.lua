--[[============================================================================
  PostBox_BlackBook - Carnet de contacts, alts, destinataires recents, modeles
  d'envoi, autocompletion, Alt+clic depuis le sac, transfert et copie
  multiple. Pont vers l'onglet "Envoyer" natif de Blizzard.

  L'envoi lui-meme (nom, sujet, corps, or, objets) reste fait par les widgets
  natifs de SendMailFrame : aucune API ne permet de joindre or ou objets sans
  eux. Le carnet les REMPLIT, il ne reimplemente pas le protocole d'envoi.

  ALTS : fusion de trois sources (PostBoxDB.knownChars, WeeklyCompassDB.chars,
  SkillTrackerDB.chars) : un alt apparait des qu'un de ces modules l'a vu, pas
  seulement PostBox. Filtre : meme faction et royaume CONNECTE (le courrier
  ne passe pas vers un royaume non connecte).
============================================================================]]

local P = PostBox
P.BlackBook = P.BlackBook or {}
local B = P.BlackBook
local ACCENT = P.ACCENT
local L = P.L

local function GetUI() return _G.TibiMidnight end

local function ClassHex(class)
  local UI = GetUI()
  if not UI then return "" end
  local c = UI.ClassColor(class)
  return UI.Hex(c[1], c[2], c[3])
end

-- ============================================================================
-- CONTACTS
-- ============================================================================
function B.AddContact(name, note)
  if not name or name == "" then return end
  PostBoxDB.blackBook.contacts[name] = { note = note or "", added = time() }
end

function B.RemoveContact(name)
  PostBoxDB.blackBook.contacts[name] = nil
end

function B.GetContacts()
  local out = {}
  for name, data in pairs(PostBoxDB.blackBook.contacts) do
    out[#out + 1] = { name = name, note = data.note }
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- ============================================================================
-- ALTS (trois sources fusionnees, voir l'en-tete)
-- ============================================================================
function B.GetAlts()
  local selfKey = P.CharKey()
  local selfFaction = UnitFactionGroup("player")
  local map = {}
  local function add(name, realm, class, faction, lastSeen)
    if type(name) ~= "string" or type(realm) ~= "string" then return end
    local key = name .. "-" .. realm
    if key == selfKey then return end
    local e = map[key]
    if not e then e = { key = key, name = name, realm = realm }; map[key] = e end
    e.class = e.class or class
    e.faction = e.faction or faction
    if (lastSeen or 0) > (e.lastSeen or 0) then e.lastSeen = lastSeen end
  end
  for key, info in pairs(PostBoxDB.knownChars or {}) do
    local n, r = P.SplitKey(key)
    add(n, r, info.class, info.faction, info.lastSeen)
  end
  local wc = _G.WeeklyCompassDB
  if type(wc) == "table" and type(wc.chars) == "table" then
    for _, c in pairs(wc.chars) do
      if type(c) == "table" then add(c.name, c.realm, c.class, c.faction, c.lastSeen) end
    end
  end
  local st = _G.SkillTrackerDB
  if type(st) == "table" and type(st.chars) == "table" then
    for realm, chars in pairs(st.chars) do
      if type(chars) == "table" then
        for name, rec in pairs(chars) do
          if type(rec) == "table" then add(name, realm, rec.class, rec.faction, rec.lastSeen) end
        end
      end
    end
  end
  local out = {}
  for _, e in pairs(map) do
    local factionOk = not (e.faction and selfFaction and e.faction ~= selfFaction)
    if factionOk and P.IsConnectedRealm(e.realm) then
      e.mail = P.MailName(e.key)
      out[#out + 1] = e
    end
  end
  table.sort(out, function(a, b) return (a.lastSeen or 0) > (b.lastSeen or 0) end)
  return out
end

-- ============================================================================
-- DESTINATAIRES RECENTS (20 max, plus recent en tete, sans doublon)
-- ============================================================================
function B.RecordRecipient(name)
  if not name or name == "" then return end
  local list = PostBoxDB.recentRecipients
  for i = #list, 1, -1 do
    if list[i]:lower() == name:lower() then table.remove(list, i) end
  end
  table.insert(list, 1, name)
  while #list > 20 do table.remove(list) end
end

-- ============================================================================
-- AUTOCOMPLETION : contacts + alts + recents. Renvoie { {name=, label=}, ... }
-- ============================================================================
function B.Autocomplete(query)
  local UI = GetUI()
  local function norm(s) return UI and UI.Normalize(s) or tostring(s or ""):lower() end
  local q = norm(query)
  if q == "" then return {} end
  local seen, starts, contains = {}, {}, {}
  local function consider(mail, label)
    if not mail or seen[mail:lower()] then return end
    local hay = norm(mail)
    local pos = hay:find(q, 1, true)
    if pos and hay ~= q then
      seen[mail:lower()] = true
      local e = { name = mail, label = label or mail }
      if pos == 1 then starts[#starts + 1] = e else contains[#contains + 1] = e end
    end
  end
  for _, a in ipairs(B.GetAlts()) do consider(a.mail, ClassHex(a.class) .. a.mail .. "|r |cFF888888(" .. L.BB_ALT_TAG .. ")|r") end
  for _, c in ipairs(B.GetContacts()) do consider(c.name) end
  for _, r in ipairs(PostBoxDB.recentRecipients) do consider(r) end
  for _, e in ipairs(contains) do starts[#starts + 1] = e end
  return starts
end

-- ============================================================================
-- MODELES D'ENVOI (destinataire, sujet, corps, or)
-- ============================================================================
function B.AddPreset(name, recipient, subject, body, money)
  PostBoxDB.blackBook.presets[name] = { recipient = recipient, subject = subject or "", body = body or "", money = money or 0 }
end

function B.RemovePreset(name)
  PostBoxDB.blackBook.presets[name] = nil
end

function B.GetPresets()
  local out = {}
  for name, data in pairs(PostBoxDB.blackBook.presets) do
    out[#out + 1] = { name = name, recipient = data.recipient, subject = data.subject, body = data.body, money = data.money }
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

local function ReadSendForm()
  local money = 0
  if _G.SendMailMoney and MoneyInputFrame_GetCopper then
    local ok, c = pcall(MoneyInputFrame_GetCopper, _G.SendMailMoney)
    if ok and c then money = c end
  end
  return {
    recipient = _G.SendMailNameEditBox and _G.SendMailNameEditBox:GetText() or "",
    subject = _G.SendMailSubjectEditBox and _G.SendMailSubjectEditBox:GetText() or "",
    body = _G.SendMailBodyEditBox and _G.SendMailBodyEditBox:GetText() or "",
    money = money,
  }
end
B.ReadSendForm = ReadSendForm

function B.SavePresetPrompt()
  if not P.mailboxOpen then print(L.MSG_OPEN_MAILBOX_FIRST) return end
  local form = ReadSendForm()
  if form.recipient == "" and form.subject == "" then print(L.MSG_PRESET_EMPTY) return end
  P.Prompt(L.PRESET_PROMPT, form.subject ~= "" and form.subject or form.recipient, function(name)
    B.AddPreset(name, form.recipient, form.subject, form.body, form.money)
    print(string.format(L.MSG_PRESET_SAVED_FMT, name))
    B.RefreshUI()
  end)
end

function B.ApplyPreset(name)
  local p = PostBoxDB.blackBook.presets[name]
  if not p then return end
  B.FillSendForm(p.recipient, { subject = p.subject, body = p.body, money = p.money })
end

-- ============================================================================
-- PONT VERS L'ONGLET "ENVOYER" NATIF
-- ============================================================================
local function EnsureSendTab()
  if not P.mailboxOpen then
    print(L.MSG_OPEN_MAILBOX_FIRST)
    return false
  end
  if _G.MailFrameTab2 and not (_G.SendMailFrame and _G.SendMailFrame:IsShown()) then
    _G.MailFrameTab2:Click()
  end
  return _G.SendMailFrame and _G.SendMailFrame:IsShown()
end
B.EnsureSendTab = EnsureSendTab

function B.FillSendForm(recipient, opts)
  opts = opts or {}
  if not EnsureSendTab() then return false end
  if _G.SendMailNameEditBox then _G.SendMailNameEditBox:SetText(recipient or "") end
  if _G.SendMailSubjectEditBox and opts.subject then _G.SendMailSubjectEditBox:SetText(opts.subject) end
  if _G.SendMailBodyEditBox and opts.body then _G.SendMailBodyEditBox:SetText(opts.body) end
  if opts.money and opts.money > 0 and MoneyInputFrame_SetCopper and _G.SendMailMoney then
    MoneyInputFrame_SetCopper(_G.SendMailMoney, opts.money)
  end
  return true
end

-- ============================================================================
-- QUICKATTACH : joint l'objet d'un emplacement de sac au premier emplacement
-- de piece jointe libre (HasSendMailItem). Alt+clic sur un objet du sac le
-- fait directement (sacs Blizzard seulement : un addon de sacs remplace les
-- boutons et n'est pas couvert).
-- ============================================================================
local function FirstFreeAttachment()
  if not HasSendMailItem then return nil end
  for i = 1, (ATTACHMENTS_MAX_SEND or 12) do
    local ok, has = pcall(HasSendMailItem, i)
    if ok and not has then return i end
  end
  return nil
end
B.FirstFreeAttachment = FirstFreeAttachment

function B.QuickAttachFromBag(bag, slot, quiet)
  if not EnsureSendTab() then return false end
  local free = FirstFreeAttachment()
  if not free then
    if not quiet then print(L.MSG_ATTACH_FULL) end
    return false
  end
  ClearCursor()
  C_Container.PickupContainerItem(bag, slot)
  if not CursorHasItem() then return false end
  ClickSendMailItemButton(free)
  if CursorHasItem() then
    ClearCursor()
    return false
  end
  return true
end

local hookedButtons = setmetatable({}, { __mode = "k" })
local function HookBagButton(btn)
  if not btn or hookedButtons[btn] or not btn.HookScript then return end
  hookedButtons[btn] = true
  btn:HookScript("OnClick", function(self, button)
    if button ~= "LeftButton" or not IsAltKeyDown() or not P.mailboxOpen then return end
    local bag = self.GetBagID and self:GetBagID()
    local slot = self.GetID and self:GetID()
    if bag and slot then B.QuickAttachFromBag(bag, slot) end
  end)
end

local function HookContainerFrame(cf)
  if not cf then return end
  if cf.EnumerateValidItems then
    pcall(function()
      for _, btn in cf:EnumerateValidItems() do HookBagButton(btn) end
    end)
  elseif type(cf.Items) == "table" then
    for _, btn in ipairs(cf.Items) do HookBagButton(btn) end
  end
end

function B.HookBags()
  HookContainerFrame(_G.ContainerFrameCombinedBags)
  for i = 1, (NUM_CONTAINER_FRAMES or 13) do HookContainerFrame(_G["ContainerFrame" .. i]) end
end

-- Les sacs peuvent s'ouvrir apres la boite : on relance l'accrochage a chaque
-- ouverture de sac pendant que la boite est ouverte (idempotent).
for _, fn in ipairs({ "OpenAllBags", "ToggleAllBags", "ToggleBackpack", "OpenBag", "ToggleBag" }) do
  if _G[fn] then
    hooksecurefunc(fn, function()
      if P.mailboxOpen then C_Timer.After(0, B.HookBags) end
    end)
  end
end

-- Joint une liste d'objets (itemID) un par tick, en cherchant a chaque fois
-- un emplacement de sac non verrouille (un objet deja joint est verrouille).
local attachTimer
function B.AttachItemIDs(ids, onDone)
  if attachTimer then attachTimer:Cancel(); attachTimer = nil end
  local i, attached = 0, 0
  local function find(id)
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
      for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID == id and not info.isLocked then return bag, slot end
      end
    end
  end
  local function tick()
    i = i + 1
    if i > #ids or not P.mailboxOpen or not FirstFreeAttachment() then
      attachTimer = nil
      if onDone then onDone(attached) end
      return
    end
    local bag, slot = find(ids[i])
    if bag and B.QuickAttachFromBag(bag, slot, true) then attached = attached + 1 end
    attachTimer = C_Timer.NewTimer(0.25, tick)
  end
  -- Petit delai : les objets pris dans le courrier arrivent dans les sacs un
  -- court instant apres la confirmation.
  attachTimer = C_Timer.NewTimer(0.6, tick)
end

-- ============================================================================
-- FORWARD : WoW n'a pas de transfert direct. On prend le contenu (moteur
-- unique, une prise a la fois), puis on pre-remplit l'onglet Envoyer avec le
-- meme sujet, le texte, l'or effectivement recu, et on rejoint les objets
-- repris. L'utilisateur n'a plus qu'a cliquer sur Envoyer.
-- ============================================================================
function B.ForwardPrompt(entry)
  if (entry.cod or 0) > 0 then print(L.MSG_FWD_COD) return end
  P.Prompt(L.FWD_PROMPT, "", function(name) B.Forward(entry, name) end, { names = true })
end

function B.Forward(entry, recipient)
  if P.IsBusy() then print(L.MSG_BUSY) return end
  local okText, body = pcall(GetInboxText, entry.index)
  P.OpenAll({
    keys = { [entry.key] = true }, silent = true,
    onDone = function(res)
      local ids = {}
      for _, link in ipairs(res.slots) do
        local id = P.ItemIDOf(link)
        if id then ids[#ids + 1] = id end
        if #ids >= (ATTACHMENTS_MAX_SEND or 12) then break end
      end
      B.FillSendForm(recipient, {
        subject = L.FORWARD_SUBJECT_PREFIX .. (entry.subject or ""),
        body = (okText and body) or "",
        money = res.gold,
      })
      B.AttachItemIDs(ids, function(n)
        print(string.format(L.MSG_FWD_READY_FMT, n, recipient))
      end)
    end,
  })
end

-- ============================================================================
-- COPIE MULTIPLE (CarbonCopy) : meme sujet, texte et or vers plusieurs
-- destinataires. Le premier est pre-rempli ; apres chaque envoi reussi
-- (MAIL_SEND_SUCCESS), le suivant l'est automatiquement. L'envoi reste un
-- clic du joueur. Les objets ne sont pas dupliques (un objet = un envoi).
-- ============================================================================
B.ccSelected = {}

function B.CarbonCopyStart(recipients)
  if not P.mailboxOpen then print(L.MSG_OPEN_MAILBOX_FIRST) return end
  if #recipients == 0 then print(L.MSG_CC_NONE) return end
  local form = ReadSendForm()
  if form.subject == "" then print(L.MSG_CC_NEED_SUBJECT) return end
  B.ccQueue = { list = recipients, i = 0, subject = form.subject, body = form.body, money = form.money }
  B.CarbonCopyNext()
end

function B.CarbonCopyNext()
  local q = B.ccQueue
  if not q then return end
  q.i = q.i + 1
  local recipient = q.list[q.i]
  if not recipient then
    print(string.format(L.MSG_CC_DONE_FMT, #q.list))
    B.ccQueue = nil
    return
  end
  B.FillSendForm(recipient, { subject = q.subject, body = q.body, money = q.money })
  print(string.format(L.MSG_CARBONCOPY_FMT, q.i, #q.list, recipient))
end

P.OnSendResult(function(ok)
  if ok and B.ccQueue then C_Timer.After(0.6, B.CarbonCopyNext) end
end)

-- ============================================================================
-- CYCLE DE VIE (appele par PostBox_Module.lua)
-- ============================================================================
function B.OnMailShow()
  B.HookBags()
  if _G.SendMailNameEditBox then P.AttachAutocomplete(_G.SendMailNameEditBox) end
end

function B.OnMailClosed()
  B.ccQueue = nil
  if attachTimer then attachTimer:Cancel(); attachTimer = nil end
end

-- ============================================================================
-- FENETRE DU CARNET
-- ============================================================================
local ROW_W = 336

local function MakeRow(parent)
  local UI = GetUI()
  local r = CreateFrame("Button", nil, parent)
  r:SetSize(ROW_W, 22)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.06)
  local cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
  cb:SetSize(18, 18); cb:SetPoint("LEFT", 0, 0)
  r.cb = cb
  local text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("LEFT", cb, "RIGHT", 4, 0); text:SetWidth(250); text:SetJustifyH("LEFT"); text:SetWordWrap(false)
  r.text = text
  local del = UI and UI.MakeButton(r, 20, 18, "x") or CreateFrame("Button", nil, r)
  del:SetPoint("RIGHT", -2, 0)
  r.del = del
  return r
end

function B.BuildUI()
  if _G.PostBoxBlackBookFrame then return end
  local UI = GetUI()
  local f = CreateFrame("Frame", "PostBoxBlackBookFrame", UIParent, "BackdropTemplate")
  f:SetSize(380, 520)
  f:SetPoint("CENTER", 40, 0)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true); f:SetMovable(true); f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UI then UI.SkinFrame(f, ACCENT, UI.C.PANEL) end
  tinsert(UISpecialFrames, "PostBoxBlackBookFrame")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -10)
  title:SetText(P.AccentText(L.BB_TITLE))

  local nameBox = CreateFrame("EditBox", nil, f, "BackdropTemplate")
  nameBox:SetSize(250, 22)
  nameBox:SetPoint("TOPLEFT", 14, -40)
  if UI then
    nameBox:SetBackdrop(UI.FlatBackdrop()); nameBox:SetBackdropColor(0.02, 0.02, 0.03, 0.95)
    nameBox:SetBackdropBorderColor(1, 1, 1, 0.15)
  end
  nameBox:SetAutoFocus(false)
  nameBox:SetFontObject("GameFontHighlightSmall")
  nameBox:SetTextInsets(6, 6, 0, 0)
  nameBox:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  P.AttachAutocomplete(nameBox)
  f.nameBox = nameBox

  local addBtn = P.Btn(f, 90, L.BB_ADD, function()
    local n = strtrim(nameBox:GetText() or "")
    if n ~= "" then B.AddContact(n); nameBox:SetText(""); nameBox:ClearFocus(); B.RefreshUI() end
  end)
  addBtn:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)
  nameBox:SetScript("OnEnterPressed", function() addBtn:Click() end)

  local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 14, -68); hint:SetWidth(350); hint:SetJustifyH("LEFT")
  hint:SetText(L.BB_HINT)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -100)
  scroll:SetPoint("BOTTOMRIGHT", -30, 46)
  if UI and UI.SkinScrollBar then UI.SkinScrollBar(scroll, ACCENT) end
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(ROW_W, 10)
  scroll:SetScrollChild(content)
  f.content = content
  f.rows, f.headers = {}, {}

  local ccBtn = P.Btn(f, 170, L.BB_CC, function()
    local list = {}
    for name in pairs(B.ccSelected) do list[#list + 1] = name end
    table.sort(list)
    B.CarbonCopyStart(list)
  end, L.BB_CC_TIP)
  ccBtn:SetPoint("BOTTOMLEFT", 12, 12)
  local presetBtn = P.Btn(f, 170, L.BB_SAVE_PRESET, function() B.SavePresetPrompt() end, L.BB_SAVE_PRESET_TIP)
  presetBtn:SetPoint("BOTTOMRIGHT", -12, 12)

  f:Hide()
end

function B.RefreshUI()
  local f = _G.PostBoxBlackBookFrame
  if not f or not f:IsShown() then return end
  local entries = {}
  local function header(text) entries[#entries + 1] = { header = text } end

  header(L.BB_SEC_PRESETS)
  for _, p in ipairs(B.GetPresets()) do
    entries[#entries + 1] = { kind = "preset", name = p.name,
      label = p.name .. " |cFF888888-> " .. (p.recipient or "") .. "|r" }
  end
  header(L.BB_SEC_CONTACTS)
  for _, c in ipairs(B.GetContacts()) do entries[#entries + 1] = { kind = "contact", name = c.name, mail = c.name, label = c.name } end
  header(L.BB_SEC_ALTS)
  for _, a in ipairs(B.GetAlts()) do
    entries[#entries + 1] = { kind = "alt", name = a.mail, mail = a.mail, label = ClassHex(a.class) .. a.mail .. "|r" }
  end
  header(L.BB_SEC_RECENT)
  for _, name in ipairs(PostBoxDB.recentRecipients) do entries[#entries + 1] = { kind = "recent", name = name, mail = name, label = name } end

  local y, ri, hi = -4, 0, 0
  for _, e in ipairs(entries) do
    if e.header then
      hi = hi + 1
      local h = f.headers[hi]
      if not h then h = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); f.headers[hi] = h end
      h:ClearAllPoints(); h:SetPoint("TOPLEFT", f.content, "TOPLEFT", 2, y - 4)
      h:SetText(P.AccentText(e.header))
      h:Show()
      y = y - 22
    else
      ri = ri + 1
      local r = f.rows[ri]
      if not r then r = MakeRow(f.content); f.rows[ri] = r end
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, y)
      r.text:SetText(e.label)
      local isPreset = e.kind == "preset"
      r.cb:SetShown(not isPreset)
      r.cb:SetChecked(e.mail and B.ccSelected[e.mail] and true or false)
      r.cb:SetScript("OnClick", function(s) if e.mail then B.ccSelected[e.mail] = s:GetChecked() and true or nil end end)
      r.del:SetShown(e.kind == "contact" or isPreset or e.kind == "recent")
      r.del:SetScript("OnClick", function()
        if isPreset then B.RemovePreset(e.name)
        elseif e.kind == "contact" then B.RemoveContact(e.name)
        else
          for i = #PostBoxDB.recentRecipients, 1, -1 do
            if PostBoxDB.recentRecipients[i] == e.name then table.remove(PostBoxDB.recentRecipients, i) end
          end
        end
        B.RefreshUI()
      end)
      r:SetScript("OnClick", function()
        if isPreset then B.ApplyPreset(e.name) else B.FillSendForm(e.mail) end
      end)
      r:Show()
      y = y - 23
    end
  end
  for i = ri + 1, #f.rows do f.rows[i]:Hide() end
  for i = hi + 1, #f.headers do f.headers[i]:Hide() end
  f.content:SetHeight(math.max(-y + 4, 10))
end

function B.Toggle()
  B.BuildUI()
  local f = _G.PostBoxBlackBookFrame
  if f:IsShown() then f:Hide() else f:Show(); B.RefreshUI() end
end
