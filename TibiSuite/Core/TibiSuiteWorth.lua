--[[============================================================================
  TibiSuiteWorth.lua  -  Page « Patrimoine » du Centre (7.3, lot B)
  ---------------------------------------------------------------------------
  Combien vaut la bande de guerriers et d'ou vient l'argent. Aucune donnee
  de module n'est recopiee : le core lit, au moment d'afficher,
    - WeeklyCompassAPI.GetGold()       or de chaque perso + banque de Bataillon ;
    - SkillTracker_WealthSummary()     valeur des sacs et banques (prix du moment) ;
    - SkillTracker_WealthTop(n)        objets les plus precieux ;
    - SkillTracker_FarmValueSince(t)   valeur recoltee / pechee ;
    - Stats_GoldSources(from, to)      gains par source (vendeur, HV, autres).
  Le perso connecte prend GetMoney() en direct. Sans WeeklyCompass : or du
  perso connecte seulement ; sans SkillTracker : pas de valeur d'objets.

  Historique : un point par jour, TibiSuiteDB.worthHist[AAAAMMJJ] = { g, i }
  (g = or + banque de Bataillon, i = objets), 120 jours. Pris 30 s apres la
  connexion puis toutes les 30 min, et a la deconnexion.
  Mode streaming : montants masques (***).
  API : TibiSuite.GetWorth(), TibiSuite.ExportWorth(), page Centre « worth »,
        /ts patrimoine.
  NON TESTE EN JEU (nouveau fichier : redemarrage complet du client).
============================================================================]]

local L = TibiSuiteL or {}
TibiSuiteL = L
local function D(k, v) if L[k] == nil then L[k] = v end end
D("WTH_PAGE",        "Patrimoine")
D("WTH_DESC",        "Ce que vaut ta bande de guerriers et d'où vient l'argent.")
D("WTH_TOTAL",       "TOTAL")
D("WTH_GOLD",        "OR DES PERSONNAGES")
D("WTH_WARBAND",     "BANQUE DE BATAILLON")
D("WTH_ITEMS",       "OBJETS (SACS ET BANQUES)")
D("WTH_HIST",        "ÉVOLUTION")
D("WTH_D30",         "30 jours")
D("WTH_D90",         "90 jours")
D("WTH_HIST_EMPTY",  "La courbe se remplit jour après jour : un point par jour de jeu.")
D("WTH_WEEK",        "CETTE SEMAINE")
D("WTH_W_VENDOR",    "Ventes aux marchands")
D("WTH_W_AH",        "Hôtel des ventes (courrier)")
D("WTH_W_OTHER",     "Autres gains (butin, quêtes...)")
D("WTH_W_SPENT",     "Dépenses")
D("WTH_W_NET",       "Bilan net")
D("WTH_W_GATHER",    "Valeur récoltée (objets)")
D("WTH_W_FISH",      "Valeur pêchée (objets)")
D("WTH_W_NOSTATS",   "Stats n'est pas chargé : détail des gains indisponible.")
D("WTH_CHARS",       "PERSONNAGES")
D("WTH_TOPITEMS",    "OBJETS LES PLUS PRÉCIEUX")
D("WTH_NOITEMS",     "SkillTracker n'est pas chargé, ou aucun sac n'a encore été relevé.")
D("WTH_NOTE",        "Objets estimés au prix du moment (hôtel des ventes via Auctionator ou TSM, sinon prix marchand). Banque de Bataillon relevée à son ouverture. Or des autres personnages : dernier passage.")
D("WTH_CHAR_FMT",    "%s or  ·  %s objets")
D("WTH_LEGEND",      "%s or      %s objets")
D("HELP_WORTH",      "page Patrimoine du Centre")
D("PAL_C_WORTH",     "Patrimoine de la bande de guerriers")

local HIST_DAYS = 120

local function Streaming() return TibiSuite.IsStreaming and TibiSuite.IsStreaming() end

-- Montants facon jeu : chiffres couleur or, separateur de milliers, piece
-- d'or. hex = autre couleur de chiffres (gains en vert, depenses en orange).
local GOLD_HEX  = "FFD100"
local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"

local function Group(n)
  local s = tostring(math.floor(math.abs(n)))
  local r = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
  return (r:gsub("^ ", ""))
end
TibiSuite.FmtGoldGroup = Group

local function Gold(c, hex, sign)
  if Streaming() then return L.STREAM_GOLD or "***" end
  local g = math.floor(math.abs(tonumber(c) or 0) / 10000)
  local neg = (tonumber(c) or 0) < 0 and g > 0
  local s = (neg and "-") or ((sign and g > 0) and "+") or ""
  return "|cFF" .. (hex or GOLD_HEX) .. s .. Group(g) .. "|r" .. GOLD_ICON
end
TibiSuite.FmtGoldCoin = Gold

local function SignedGold(c, hex) return Gold(c, hex, true) end

-- Pastille de couleur (texture blanche teintee : le caractere carre n'existe
-- pas dans la police du jeu).
local function Swatch(r, g, b)
  return string.format("|TInterface\\Buttons\\WHITE8X8:10:10:0:0:8:8:0:8:0:8:%d:%d:%d|t",
    math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

local function NormKey(name, realm)
  return ((tostring(name or "") .. "-" .. tostring(realm or "")):gsub("[%s']", "")):lower()
end

local function MyNameRealm()
  local name, realm
  if UnitFullName then name, realm = UnitFullName("player") end
  name = name or (UnitName and UnitName("player"))
  if not realm or realm == "" then realm = GetRealmName and GetRealmName() end
  return name, realm
end

-- ── Calcul ──────────────────────────────────────────────────────────
-- Renvoie { total, gold, warband, items, chars = { {name, realm, class,
-- gold, items} }, hasWC, hasST, at }.
function TibiSuite.GetWorth()
  local w = { total = 0, gold = 0, warband = 0, items = 0, chars = {} }
  local byKey = {}
  local myName, myRealm = MyNameRealm()
  local myKey = NormKey(myName, myRealm)
  local function char(name, realm, class)
    local k = NormKey(name, realm)
    local c = byKey[k]
    if not c then
      c = { name = name, realm = realm, class = class, gold = 0, items = 0 }
      byKey[k] = c
      w.chars[#w.chars + 1] = c
    end
    c.class = c.class or class
    return c
  end
  local api = _G.WeeklyCompassAPI
  if api and api.GetGold then
    local ok, g = pcall(api.GetGold)
    if ok and type(g) == "table" then
      w.hasWC = true
      for _, c in ipairs(g.chars or {}) do char(c.name, c.realm, c.class).gold = tonumber(c.gold) or 0 end
      if g.warband then w.warband = tonumber(g.warband.money) or 0 end
    end
  end
  local _, myClass = UnitClass and UnitClass("player")
  char(myName, myRealm, myClass).gold = (GetMoney and tonumber(GetMoney())) or 0
  if _G.SkillTracker_WealthSummary then
    local ok, s = pcall(SkillTracker_WealthSummary)
    if ok and type(s) == "table" then
      w.hasST = true
      w.items = tonumber(s.total) or 0
      w.at = s.at
      for key, c in pairs(s.chars or {}) do
        local name, realm = tostring(key):match("^(.-)%-(.*)$")
        if name then char(name, realm, c.class).items = tonumber(c.value) or 0 end
      end
    end
  end
  for _, c in ipairs(w.chars) do w.gold = w.gold + c.gold end
  w.total = w.gold + w.warband + w.items
  table.sort(w.chars, function(a, b) return (a.gold + a.items) > (b.gold + b.items) end)
  w.me = byKey[myKey]
  return w
end

-- ── Historique ──────────────────────────────────────────────────────
local function Today() return date and date("%Y%m%d") or tostring(math.floor(time() / 86400)) end

local function Record()
  if not TibiSuiteDB then return end
  local ok, w = pcall(TibiSuite.GetWorth)
  if not ok or type(w) ~= "table" or w.total <= 0 then return end
  TibiSuiteDB.worthHist = TibiSuiteDB.worthHist or {}
  local h = TibiSuiteDB.worthHist
  h[Today()] = { g = w.gold + w.warband, i = w.items }
  local keys = {}
  for k in pairs(h) do keys[#keys + 1] = k end
  if #keys > HIST_DAYS then
    table.sort(keys)
    for i = 1, #keys - HIST_DAYS do h[keys[i]] = nil end
  end
end
TibiSuite.RecordWorth = Record

-- Les n derniers points, du plus ancien au plus recent : { {day, g, i} }.
local function History(n)
  local h = TibiSuiteDB and TibiSuiteDB.worthHist or {}
  local keys = {}
  for k in pairs(h) do keys[#keys + 1] = k end
  table.sort(keys)
  local out = {}
  for i = math.max(1, #keys - n + 1), #keys do
    local e = h[keys[i]]
    out[#out + 1] = { day = keys[i], g = tonumber(e.g) or 0, i = tonumber(e.i) or 0 }
  end
  return out
end

local function WeekStart()
  local s = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
  if not tonumber(s) then return time() - 7 * 86400 end
  return time() + s - 7 * 86400
end

local function WeekBreakdown()
  local from, to = WeekStart(), time()
  local out = {}
  if _G.Stats_GoldSources then
    local ok, s = pcall(Stats_GoldSources, from, to)
    if ok and type(s) == "table" then out.src = s end
  end
  if _G.SkillTracker_FarmValueSince then
    local ok, g, f = pcall(SkillTracker_FarmValueSince, from)
    if ok then out.gather, out.fish = g, f end
  end
  return out
end

-- Bloc d'export (data.suite.worth) : montants en cuivre, 90 derniers jours.
function TibiSuite.ExportWorth()
  local w = TibiSuite.GetWorth()
  local hist = {}
  for _, e in ipairs(History(90)) do hist[#hist + 1] = { d = e.day, g = e.g, i = e.i } end
  local chars = {}
  for i, c in ipairs(w.chars) do
    if i > 20 then break end
    chars[#chars + 1] = { n = c.name, r = c.realm, c = c.class, g = c.gold, i = c.items }
  end
  return { v = 1, at = time(), total = w.total, gold = w.gold, warband = w.warband, items = w.items,
           chars = chars, hist = hist }
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_LOGOUT" then pcall(Record); return end
  C_Timer.After(30, function()
    pcall(Record)
    C_Timer.NewTicker(1800, function() pcall(Record) end)
  end)
end)

-- ── Page du Centre ──────────────────────────────────────────────────
local function ClassHex(class)
  local c = class and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
    or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
  if c and c.r then return string.format("|cFF%02X%02X%02X", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255)) end
  return "|cFFECEAE6"
end


local CHART_H = 120

local function Build(p, api)
  local K, UI = api.K, api.UI
  local sc = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
  sc:SetPoint("TOPLEFT", 0, 0); sc:SetPoint("BOTTOMRIGHT", -24, 0)
  if UI and UI.SkinScrollBar then UI.SkinScrollBar(sc, api.ACC) end
  local c = CreateFrame("Frame", nil, sc)
  c:SetSize(api.DockW(), 10)
  sc:SetScrollChild(c)
  p.child = c
  p.days = 30
  p.tiles = {}
  for i, lbl in ipairs({ L.WTH_TOTAL, L.WTH_GOLD, L.WTH_WARBAND, L.WTH_ITEMS }) do
    local t = K.Card(c)
    t:SetHeight(58)
    t.lbl = K.Text(t, "GameFontNormalSmall", lbl, K.COL.MUT); t.lbl:SetPoint("TOPLEFT", 12, -10)
    t.val = K.Text(t, "GameFontHighlightLarge", "", K.COL.TXT)
    t.val:SetPoint("TOPLEFT", t.lbl, "BOTTOMLEFT", 0, -6)
    p.tiles[i] = t
  end
  p.hHead = K.Label(c, L.WTH_HIST)
  p.b30 = K.Btn(c, 80, 22, L.WTH_D30, "ghost")
  p.b90 = K.Btn(c, 80, 22, L.WTH_D90, "ghost")
  p.b30:SetScript("OnClick", function() p.days = 30; p._refresh() end)
  p.b90:SetScript("OnClick", function() p.days = 90; p._refresh() end)
  p.chart = CreateFrame("Frame", nil, c)
  p.chart:SetHeight(CHART_H)
  p.chart.bg = p.chart:CreateTexture(nil, "BACKGROUND"); p.chart.bg:SetAllPoints(); p.chart.bg:SetColorTexture(1, 1, 1, 0.03)
  p.chart.bars = {}
  p.chart.empty = K.Text(p.chart, "GameFontHighlightSmall", L.WTH_HIST_EMPTY, K.COL.DIM)
  p.chart.empty:SetPoint("CENTER")
  p.chart.max = K.Text(p.chart, "GameFontDisableSmall", "", K.COL.DIM); p.chart.max:SetPoint("TOPLEFT", 4, -2)
  p.legend = K.Text(c, "GameFontDisableSmall", "", K.COL.DIM)
  p.wHead = K.Label(c, L.WTH_WEEK)
  p.wRows = {}
  p.cHead = K.Label(c, L.WTH_CHARS)
  p.cRows = {}
  p.iHead = K.Label(c, L.WTH_TOPITEMS)
  p.iRows = {}
  p.note = K.Text(c, "GameFontDisableSmall", L.WTH_NOTE, K.COL.DIM)
  p.note:SetJustifyH("LEFT"); p.note:SetWordWrap(true)
end

local function Line(p, list, i, K)
  local r = list[i]
  if r then return r end
  r = CreateFrame("Frame", nil, p.child)
  r:SetHeight(22)
  r.ico = r:CreateTexture(nil, "ARTWORK"); r.ico:SetSize(18, 18); r.ico:SetPoint("LEFT", 4, 0)
  r.l = K.Text(r, "GameFontHighlight", "", K.COL.TXT); r.l:SetPoint("LEFT", 28, 0)
  r.l:SetJustifyH("LEFT"); r.l:SetWordWrap(false)
  r.v = K.Text(r, "GameFontHighlight", "", K.COL.TXT); r.v:SetPoint("RIGHT", -6, 0)
  r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, 0.025)
  list[i] = r
  return r
end

local function Refresh(p, api)
  local K = api.K
  p._refresh = function() Refresh(p, api) end
  local w = api.DockW()
  local c = p.child
  c:SetWidth(w)
  local data = TibiSuite.GetWorth()
  local y = -2
  -- Tuiles
  local tw = math.floor((w - 3 * 10) / 4)
  local vals = { data.total, data.gold, data.warband, data.items }
  for i, t in ipairs(p.tiles) do
    t:SetWidth(tw); t:ClearAllPoints(); t:SetPoint("TOPLEFT", (i - 1) * (tw + 10), y)
    t.val:SetText(Gold(vals[i]))
  end
  y = y - 70
  -- Courbe (barres empilees : or puis objets)
  p.hHead:ClearAllPoints(); p.hHead:SetPoint("TOPLEFT", 2, y - 4)
  p.b90:ClearAllPoints(); p.b90:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, y)
  p.b30:ClearAllPoints(); p.b30:SetPoint("RIGHT", p.b90, "LEFT", -6, 0)
  p.b30._label:SetTextColor(unpack(p.days == 30 and K.COL.TXT or K.COL.DIM))
  p.b90._label:SetTextColor(unpack(p.days == 90 and K.COL.TXT or K.COL.DIM))
  y = y - 28
  p.chart:SetWidth(w); p.chart:ClearAllPoints(); p.chart:SetPoint("TOPLEFT", 0, y)
  local hist = History(p.days)
  for _, b in ipairs(p.chart.bars) do b.g:Hide(); b.i:Hide() end
  p.chart.empty:SetShown(#hist < 2)
  local top = 0
  for _, e in ipairs(hist) do top = math.max(top, e.g + e.i) end
  p.chart.max:SetText(top > 0 and Gold(top) or "")
  if #hist >= 2 and top > 0 then
    local slot = (w - 8) / p.days
    local bw = math.max(2, math.floor(slot) - 2)
    local a = TibiSuite.ACCENT or { 0.769, 0.122, 0.231 }
    local first = p.days - #hist + 1
    for n, e in ipairs(hist) do
      local b = p.chart.bars[n]
      if not b then
        b = { g = p.chart:CreateTexture(nil, "ARTWORK"), i = p.chart:CreateTexture(nil, "ARTWORK") }
        p.chart.bars[n] = b
      end
      local x = 4 + (first + n - 2) * slot
      local hg = math.max(1, (CHART_H - 18) * e.g / top)
      local hi = (CHART_H - 18) * e.i / top
      b.g:ClearAllPoints(); b.g:SetPoint("BOTTOMLEFT", p.chart, "BOTTOMLEFT", x, 2)
      b.g:SetSize(bw, hg); b.g:SetColorTexture(1, 0.82, 0, 0.85); b.g:Show()
      if hi >= 1 then
        b.i:ClearAllPoints(); b.i:SetPoint("BOTTOMLEFT", b.g, "TOPLEFT", 0, 0)
        b.i:SetSize(bw, hi); b.i:SetColorTexture(a[1], a[2], a[3], 0.85); b.i:Show()
      end
    end
  end
  y = y - CHART_H - 4
  local ac = TibiSuite.ACCENT or { 0.769, 0.122, 0.231 }
  p.legend:SetText(string.format(L.WTH_LEGEND, Swatch(1, 0.82, 0), Swatch(ac[1], ac[2], ac[3])))
  p.legend:ClearAllPoints(); p.legend:SetPoint("TOPLEFT", 2, y)
  y = y - 22
  -- Semaine
  p.wHead:ClearAllPoints(); p.wHead:SetPoint("TOPLEFT", 2, y - 4); y = y - 26
  for _, r in ipairs(p.wRows) do r:Hide() end
  local wk = WeekBreakdown()
  local lines = {}
  if wk.src then
    local s = wk.src
    lines[#lines + 1] = { L.WTH_W_VENDOR, s.vendor }
    lines[#lines + 1] = { L.WTH_W_AH, s.ah }
    lines[#lines + 1] = { L.WTH_W_OTHER, s.other }
    lines[#lines + 1] = { L.WTH_W_SPENT, -(s.spent or 0) }
    lines[#lines + 1] = { L.WTH_W_NET, (s.gain or 0) - (s.spent or 0), true }
  else
    lines[#lines + 1] = { L.WTH_W_NOSTATS }
  end
  if wk.gather and wk.gather > 0 then lines[#lines + 1] = { L.WTH_W_GATHER, wk.gather } end
  if wk.fish and wk.fish > 0 then lines[#lines + 1] = { L.WTH_W_FISH, wk.fish } end
  for i, ln in ipairs(lines) do
    local r = Line(p, p.wRows, i, K)
    r:SetWidth(w); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y)
    r.ico:Hide()
    r.l:SetText((ln[3] and "|cFFFFD100" or "") .. ln[1] .. (ln[3] and "|r" or ""))
    if ln[2] then
      local hex = (ln[2] < 0 and "FF9A3C") or (ln[3] and ln[2] > 0 and "4FD16B") or nil
      r.v:SetText(SignedGold(ln[2], hex))
    else r.v:SetText("") end
    r:Show()
    y = y - 24
  end
  y = y - 8
  -- Personnages
  p.cHead:ClearAllPoints(); p.cHead:SetPoint("TOPLEFT", 2, y - 4); y = y - 26
  for _, r in ipairs(p.cRows) do r:Hide() end
  for i, ch in ipairs(data.chars) do
    if i > 8 then break end
    local r = Line(p, p.cRows, i, K)
    r:SetWidth(w); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y)
    r.ico:Hide()
    local nm = TibiSuite.SafeName and TibiSuite.SafeName(ch.name) or ch.name
    r.l:SetText(ClassHex(ch.class) .. tostring(nm) .. "|r  |cFF62616B" .. tostring(ch.realm or "") .. "|r")
    r.v:SetText(string.format(L.WTH_CHAR_FMT, Gold(ch.gold), Gold(ch.items)))
    r.v:SetTextColor(K.COL.TXT[1], K.COL.TXT[2], K.COL.TXT[3])
    r:Show()
    y = y - 24
  end
  y = y - 8
  -- Objets
  p.iHead:ClearAllPoints(); p.iHead:SetPoint("TOPLEFT", 2, y - 4); y = y - 26
  for _, r in ipairs(p.iRows) do r:Hide() end
  local top6 = {}
  if _G.SkillTracker_WealthTop then
    local ok, l = pcall(SkillTracker_WealthTop, 6)
    if ok and type(l) == "table" then top6 = l end
  end
  if #top6 == 0 then
    local r = Line(p, p.iRows, 1, K)
    r:SetWidth(w); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y)
    r.ico:Hide(); r.l:SetText("|cFF62616B" .. L.WTH_NOITEMS .. "|r"); r.v:SetText(""); r:Show()
    y = y - 24
  end
  for i, it in ipairs(top6) do
    local r = Line(p, p.iRows, i, K)
    r:SetWidth(w); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(it.id)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(it.id)
    r.ico:SetTexture(icon or 134400); r.ico:Show()
    r.l:SetText(tostring(name or ("#" .. it.id)) .. "  |cFFA09EA6x" .. tostring(it.q) .. "|r")
    r.v:SetText(Gold(it.value)); r.v:SetTextColor(K.COL.TXT[1], K.COL.TXT[2], K.COL.TXT[3])
    r:Show()
    y = y - 24
  end
  y = y - 10
  p.note:SetWidth(w - 8); p.note:ClearAllPoints(); p.note:SetPoint("TOPLEFT", 4, y)
  y = y - (p.note:GetStringHeight() or 30) - 10
  c:SetHeight(-y + 10)
end

if TibiSuite.RegisterCentrePage then
  TibiSuite.RegisterCentrePage({ id = "worth", label = "WTH_PAGE", desc = "WTH_DESC", after = "goals",
    build = Build, refresh = Refresh })
end
