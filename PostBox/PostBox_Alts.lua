--[[============================================================================
  PostBox_Alts - "Tous mes persos" : la boite aux lettres de chaque personnage
  vue depuis n'importe lequel.

  A chaque visite d'une boite, PostBox prend un instantane de celle du
  personnage (nombre de courriers, or et objets en attente, contre-
  remboursements, dates d'expiration des courriers qui contiennent quelque
  chose). Quand on envoie un courrier a un de ses alts, il est note "a
  relever" chez lui jusqu'a sa prochaine visite. Au login, une alerte signale
  les courriers d'alts qui vont expirer (et donc etre perdus ou renvoyes).

  Limite honnete : un instantane date de la derniere visite de ce perso. Les
  en-tetes du client ne sont pas rafraichis tant que la boite reste ouverte :
  les objets sont recomptes en lecture directe, l'or pris par PostBox pendant
  la visite est retire (P.sessionMoneyTaken). L'or pris a la main via la
  fenetre Blizzard peut rester compte jusqu'a la visite suivante.
============================================================================]]

local P = PostBox
P.Alts = P.Alts or {}
local A = P.Alts
local ACCENT = P.ACCENT
local L = P.L

local function GetUI() return _G.TibiMidnight end

local MAX_EXP = 12

-- ============================================================================
-- INSTANTANE DE LA BOITE COURANTE
-- ============================================================================
local function LiveItemCount(e) return P.LiveItemCount(e) end

function A.Snapshot(cache)
  local key = P.CharKey()
  if not key then return end
  local _, total = GetInboxNumItems()
  local now = time()
  local snap = { t = now, count = #cache, total = total or #cache, gold = 0, items = 0, cod = 0, exp = {} }
  for _, e in ipairs(cache) do
    local items = LiveItemCount(e)
    local gold = P.sessionMoneyTaken[P.MailIdKey(e)] and 0 or (e.money or 0)
    snap.gold = snap.gold + gold
    snap.items = snap.items + items
    if (e.cod or 0) > 0 then snap.cod = snap.cod + 1 end
    if gold > 0 or items > 0 then
      snap.exp[#snap.exp + 1] = {
        at = now + math.floor((e.daysLeft or 0) * 86400),
        s = e.subject, f = e.sender, g = gold, i = items,
      }
    end
  end
  table.sort(snap.exp, function(a, b) return a.at < b.at end)
  while #snap.exp > MAX_EXP do table.remove(snap.exp) end
  PostBoxDB.inboxes[key] = snap  -- la vraie boite remplace les envois "a relever"
  A.Refresh()
end

-- Envoi reussi vers un de nos persos : note "a relever" chez lui.
function A.RecordIncoming(recipient, gold, items)
  local key = P.ResolveOwnChar(recipient)
  if not key or key == P.CharKey() then return end
  local snap = PostBoxDB.inboxes[key]
  if not snap then snap = { t = 0, count = 0, total = 0, gold = 0, items = 0, cod = 0, exp = {} }; PostBoxDB.inboxes[key] = snap end
  snap.incoming = snap.incoming or {}
  table.insert(snap.incoming, { t = time(), from = P.CharKey(), g = gold or 0, i = items or 0 })
  while #snap.incoming > 30 do table.remove(snap.incoming, 1) end
  A.Refresh()
end

-- ============================================================================
-- OUTILS D'AFFICHAGE
-- ============================================================================
local function FmtLeft(sec)
  if sec <= 0 then return L.TIME_EXPIRED end
  if sec < 3600 then return string.format(L.TIME_MIN_FMT, math.max(1, math.floor(sec / 60))) end
  if sec < 86400 then return string.format(L.TIME_H_FMT, math.floor(sec / 3600)) end
  return string.format(L.TIME_D_FMT, sec / 86400)
end
A.FmtLeft = FmtLeft

local function FmtAgo(t)
  if not t or t == 0 then return "-" end
  return FmtLeft(time() - t)
end

local function ClassHex(key)
  local UI = GetUI()
  local info = PostBoxDB.knownChars[key]
  local class = info and info.class
  if not class then
    local wc = _G.WeeklyCompassDB
    local name, realm = P.SplitKey(key)
    local c = wc and wc.chars and wc.chars[(name or "") .. " - " .. (realm or "")]
    class = c and c.class
  end
  if not UI then return "" end
  local c = UI.ClassColor(class)
  return UI.Hex(c[1], c[2], c[3])
end

local function IncomingTotals(snap)
  local n, g, i = 0, 0, 0
  for _, inc in ipairs(snap.incoming or {}) do n = n + 1; g = g + (inc.g or 0); i = i + (inc.i or 0) end
  return n, g, i
end

-- ============================================================================
-- ALERTE AU LOGIN
-- ============================================================================
function A.LoginAlert()
  if not PostBoxDB.altAlert then return end
  local now = time()
  local horizon = (PostBoxDB.altAlertDays or 3) * 86400
  local lines = {}
  for key, snap in pairs(PostBoxDB.inboxes) do
    local soon, nearest = 0, nil
    for _, x in ipairs(snap.exp or {}) do
      if x.at - now <= horizon then
        soon = soon + 1
        if not nearest or x.at < nearest then nearest = x.at end
      end
    end
    if soon > 0 then
      lines[#lines + 1] = { at = nearest, text = string.format(L.ALERT_EXPIRE_FMT,
        ClassHex(key) .. key .. "|r", soon, FmtLeft(nearest - now)) }
    end
  end
  table.sort(lines, function(a, b) return a.at < b.at end)
  for i, ln in ipairs(lines) do
    if i > 5 then print(string.format(L.ALERT_MORE_FMT, #lines - 5)); break end
    print(ln.text)
  end
end

-- ============================================================================
-- LIGNE D'ETAT DU PANNEAU VIVANT DE TIBISUITE (statusFn, lue par le core)
-- Courriers de valeur qui expirent bientot (tous persos, meme horizon que
-- l'alerte au login), sinon nouveau courrier, sinon le contenu de la boite du
-- perso connecte (instantane de sa derniere visite). Les courriers deja
-- expires a la date de l'instantane ne comptent plus : ils sont partis.
-- ============================================================================
function A.Status()
  if not PostBoxDB or not PostBoxDB.inboxes then return nil end
  local SL = _G.TibiSuiteL or {}
  local now = time()
  local horizon = (PostBoxDB.altAlertDays or 3) * 86400
  local soon = 0
  for _, snap in pairs(PostBoxDB.inboxes) do
    for _, x in ipairs(snap.exp or {}) do
      if x.at > now and x.at - now <= horizon then soon = soon + 1 end
    end
  end
  if soon > 0 then return { text = string.format(SL.ST_MAIL_EXPIRE_FMT or "%d", soon), urgent = true } end
  if HasNewMail and HasNewMail() then return { text = SL.ST_MAIL_NEW } end
  local snap = PostBoxDB.inboxes[P.CharKey() or ""]
  if not snap then return nil end
  if (snap.count or 0) > 0 then return { text = string.format(SL.ST_MAIL_COUNT_FMT or "%d", snap.count) } end
  return { text = SL.ST_MAIL_EMPTY }
end
function PostBox_Status() return A.Status() end

-- ============================================================================
-- FENETRE
-- ============================================================================
local COLS = { 160, 70, 100, 50, 40, 90, 70 }

local function BuildRow(parent)
  local r = CreateFrame("Button", nil, parent)
  r:SetSize(620, 22)
  local bg = r:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.03)
  r.bg = bg
  local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.06)
  r.cells = {}
  local x = 4
  for i, w in ipairs(COLS) do
    local t = r:CreateFontString(nil, "OVERLAY", i == 1 and "GameFontHighlightSmall" or "GameFontHighlightSmall")
    t:SetPoint("LEFT", x, 0); t:SetWidth(w); t:SetWordWrap(false)
    t:SetJustifyH(i == 1 and "LEFT" or "RIGHT")
    r.cells[i] = t
    x = x + w + 4
  end
  local del = _G.TibiMidnight and _G.TibiMidnight.MakeButton(r, 18, 16, "x") or CreateFrame("Button", nil, r)
  del:SetPoint("RIGHT", -2, 0)
  r.del = del
  return r
end

function A.Refresh()
  local f = _G.PostBoxAltsFrame
  if not f or not f:IsShown() then return end
  local now = time()
  local list = {}
  for key, snap in pairs(PostBoxDB.inboxes) do
    local nearest = snap.exp and snap.exp[1] and snap.exp[1].at or math.huge
    list[#list + 1] = { key = key, snap = snap, nearest = nearest }
  end
  table.sort(list, function(a, b)
    if a.nearest ~= b.nearest then return a.nearest < b.nearest end
    return a.key < b.key
  end)

  local tg, ti, tn = 0, 0, 0
  local y = -2
  for i, e in ipairs(list) do
    local r = f.rows[i]
    if not r then r = BuildRow(f.content); f.rows[i] = r end
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, y)
    local s = e.snap
    local incN, incG, incI = IncomingTotals(s)
    local selfMark = (e.key == P.CharKey()) and " |cFF66FF66*|r" or ""
    r.cells[1]:SetText(ClassHex(e.key) .. e.key .. "|r" .. selfMark)
    r.cells[2]:SetText(s.t > 0 and (s.total and s.total > s.count and (s.count .. "/" .. s.total) or tostring(s.count)) or "?")
    r.cells[3]:SetText((s.gold or 0) > 0 and P.Coin(s.gold) or "-")
    r.cells[4]:SetText((s.items or 0) > 0 and tostring(s.items) or "-")
    r.cells[5]:SetText((s.cod or 0) > 0 and ("|cFFFF6650" .. s.cod .. "|r") or "-")
    if e.nearest ~= math.huge then
      local left = e.nearest - now
      local col = left < 86400 and "|cFFFF5555" or (left < 3 * 86400 and "|cFFFF9933" or "|cFFCCCCCC")
      r.cells[6]:SetText(col .. FmtLeft(left) .. "|r")
    else
      r.cells[6]:SetText("-")
    end
    r.cells[7]:SetText(incN > 0 and ("|cFF66CCFF+" .. incN .. "|r") or FmtAgo(s.t))
    r.bg:SetShown(i % 2 == 0)
    r.del:SetScript("OnClick", function() PostBoxDB.inboxes[e.key] = nil; A.Refresh() end)
    r:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(e.key)
      GameTooltip:AddLine(string.format(L.ALTS_TIP_SEEN_FMT, FmtAgo(s.t)), 0.7, 0.7, 0.75)
      for _, x in ipairs(s.exp or {}) do
        local what = {}
        if (x.g or 0) > 0 then what[#what + 1] = P.Coin(x.g) end
        if (x.i or 0) > 0 then what[#what + 1] = string.format(L.ALTS_ITEMS_FMT, x.i) end
        GameTooltip:AddDoubleLine((x.f or "?") .. " : " .. (x.s or ""), FmtLeft(x.at - now) .. "  " .. table.concat(what, " "),
          0.9, 0.9, 0.95, 0.8, 0.8, 0.8)
      end
      if incN > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format(L.ALTS_INCOMING_FMT, incN, P.Coin(incG), incI), 0.4, 0.8, 1)
      end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:Show()
    y = y - 23
    tg = tg + (s.gold or 0) + incG
    ti = ti + (s.items or 0) + incI
    tn = tn + (s.count or 0)
  end
  for i = #list + 1, #f.rows do f.rows[i]:Hide() end
  f.content:SetHeight(math.max(-y + 4, 10))
  f.empty:SetShown(#list == 0)
  f.total:SetText(string.format(L.ALTS_TOTAL_FMT, tn, P.Coin(tg), ti))
end

function A.BuildUI()
  if _G.PostBoxAltsFrame then return end
  local UI = GetUI()
  local f = CreateFrame("Frame", "PostBoxAltsFrame", UIParent, "BackdropTemplate")
  f:SetSize(660, 400)
  f:SetPoint("CENTER", 0, 30)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true); f:SetMovable(true); f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UI then UI.SkinFrame(f, ACCENT, UI.C.PANEL) end
  tinsert(UISpecialFrames, "PostBoxAltsFrame")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -12)
  title:SetText(P.AccentText(L.ALTS_TITLE))

  local total = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  total:SetPoint("TOPLEFT", 16, -40)
  f.total = total

  local headers = { L.ALTS_COL_CHAR, L.ALTS_COL_MAILS, L.ALTS_COL_GOLD, L.ALTS_COL_ITEMS, L.ALTS_COL_COD, L.ALTS_COL_EXPIRY, L.ALTS_COL_SEEN }
  local x = 16
  for i, w in ipairs(COLS) do
    local h = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    h:SetPoint("TOPLEFT", x, -64); h:SetWidth(w); h:SetJustifyH(i == 1 and "LEFT" or "RIGHT")
    h:SetText(headers[i])
    x = x + w + 4
  end

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -80)
  scroll:SetPoint("BOTTOMRIGHT", -30, 30)
  if UI and UI.SkinScrollBar then UI.SkinScrollBar(scroll, ACCENT) end
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(620, 10)
  scroll:SetScrollChild(content)
  f.content, f.rows = content, {}

  local empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  empty:SetPoint("CENTER", scroll, "CENTER"); empty:SetWidth(520); empty:SetText(L.ALTS_EMPTY)
  f.empty = empty

  local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetPoint("BOTTOMLEFT", 16, 10); note:SetWidth(620); note:SetJustifyH("LEFT")
  note:SetText(L.ALTS_NOTE)

  f:Hide()
end

function A.Toggle()
  A.BuildUI()
  local f = _G.PostBoxAltsFrame
  if f:IsShown() then f:Hide() else f:Show(); A.Refresh() end
end
