--[[============================================================================
  TibiSuiteRecap.lua  -  Bilan de fin de semaine (7.3, lot D)
  ---------------------------------------------------------------------------
  Au premier login (vrai login, pas /reload) apres le reset hebdo : ce que la
  bande de guerriers a fait la semaine passee, compare a la precedente.

  Le piege : au reset, les compteurs de la semaine sont deja remis a zero.
  La semaine est donc figee EN CONTINU (toutes les 10 min, a chaque
  changement d'etat regroupe a 60 s, et a la deconnexion) dans
    TibiSuiteDB.weekRecap[wid] = { at, from, to, s = Stats_Summary(...),
      g = { d, t }, best = { k, x, t }, worth, chars = weekSnap de la semaine }
  wid = heure du reset qui CLOT la semaine (GetSecondsUntilWeeklyReset, en
  heures). 8 semaines gardees.

  Fenetre « Ta semaine passee » : 8 tuiles avec l'evolution, objectifs,
  meilleur moment (fil d'activite), patrimoine, Grand coffre par perso.
  Reglage TibiSuiteDB.weekRecapPopup (nil = actif, SET_KEYS).
  API : TibiSuite.FreezeWeek(), GetRecaps(), ShowRecap(wid), ExportRecap().
  Slash : /ts bilan.
  NON TESTE EN JEU (nouveau fichier : redemarrage complet du client).
============================================================================]]

local L = TibiSuiteL or {}
TibiSuiteL = L
local function D(k, v) if L[k] == nil then L[k] = v end end
D("RCP_TITLE",       "Ta semaine passée")
D("RCP_TITLE_CUR",   "Ta semaine en cours")
D("RCP_SUB_FMT",     "Du %s au %s")
D("RCP_VS",          "comparé à la semaine d'avant")
D("RCP_T_PLAYED",    "TEMPS JOUÉ")
D("RCP_T_QUESTS",    "QUÊTES")
D("RCP_T_DUNGEONS",  "DONJONS")
D("RCP_T_RAIDS",     "RAIDS")
D("RCP_T_DELVES",    "GOUFFRES")
D("RCP_T_GOLD",      "OR NET")
D("RCP_T_REP",       "RÉPUTATION")
D("RCP_T_ACH",       "HAUTS FAITS")
D("RCP_MPLUS_FMT",   "dont %d en Mythique+")
D("RCP_WQ_FMT",      "dont %d du monde")
D("RCP_PTS",         "points")
D("RCP_GOALS",       "Objectifs")
D("RCP_GOALS_FMT",   "%d / %d atteints")
D("RCP_GOALS_NONE",  "aucun objectif cette semaine")
D("RCP_BEST",        "Meilleur moment")
D("RCP_BEST_NONE",   "rien de marquant dans le fil d'activité")
D("RCP_WORTH",       "Patrimoine")
D("RCP_VAULT",       "GRAND COFFRE ET À FAIRE, PAR PERSONNAGE")
D("RCP_NEW",         "nouveau")
D("RCP_LOGIN",       "Afficher chaque semaine")
D("RCP_WEEK",        "Ma semaine")
D("RCP_CLOSE",       "Fermer")
D("RCP_NONE",        "Pas encore de bilan : il se construit pendant que tu joues.")
D("HELP_RECAP",      "bilan de la semaine passée")
D("RCP_PREV_TT",     "Semaine précédente")
D("RCP_NEXT_TT",     "Semaine suivante")
D("RCP_HIST_FMT",    "Semaine %d sur %d gardées")
D("CTR_Q_RECAP",     "Bilan de la semaine")
D("PAL_C_RECAP",     "Bilan de la semaine passée")

local KEEP = 8
local FREEZE_EVERY = 600

local K
local function Kit() K = K or TibiSuite._kit; return K ~= nil end
local function Acc() return TibiSuite.ACCENT or { 0.769, 0.122, 0.231 } end

local function SecsToReset()
  local f = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
  if not f then return nil end
  local ok, s = pcall(f)
  return ok and tonumber(s) or nil
end

-- Semaine en cours : wid (heure du reset qui la clot), debut, fin.
local function CurrentWeek()
  local s = SecsToReset()
  if not s then return nil end
  local to = time() + s
  local wid = math.floor(to / 3600)
  return wid, wid * 3600 - 7 * 86400, wid * 3600
end
TibiSuite.RecapWeekId = CurrentWeek

-- Moment marquant du fil, par ordre d'interet du module.
local BEST_RANK = { Leg = 60, Dgn = 50, Lvl = 40, Rep = 30, Stats = 25, Skill = 20, Daily = 15, Weekly = 15 }

local function BestMoment(from, to)
  local best, bs
  for _, e in ipairs(TibiSuite.GetFeed and TibiSuite.GetFeed() or {}) do
    local t = tonumber(e.t) or 0
    if t >= from and t < to and e.x then
      local sc = (BEST_RANK[e.k] or 0) + (t - from) / (to - from + 1)
      if BEST_RANK[e.k] and (not bs or sc > bs) then best, bs = { k = e.k, x = e.x, t = t }, sc end
    end
  end
  return best
end

local function GoalsOfWeek()
  local d, t = 0, 0
  for _, g in ipairs(TibiSuite.GetGoals and TibiSuite.GetGoals() or {}) do
    if g.weekly then
      t = t + 1
      local ok, _, _, done = pcall(TibiSuite.GoalProgress, g)
      if ok and done then d = d + 1 end
    end
  end
  return { d = d, t = t }
end

function TibiSuite.FreezeWeek()
  if not TibiSuiteDB then return end
  local wid, from, to = CurrentWeek()
  if not wid then return end
  local now = time()
  local r = {
    at = now, from = from, to = to,
    s = _G.Stats_Summary and Stats_Summary(from, now) or nil,
    g = GoalsOfWeek(),
    best = BestMoment(from, to),
  }
  if TibiSuite.GetWorth then
    local ok, w = pcall(TibiSuite.GetWorth)
    if ok and type(w) == "table" and w.total > 0 then r.worth = w.total end
  end
  if TibiSuite.TakeWeekSnap then pcall(TibiSuite.TakeWeekSnap) end
  local chars = {}
  for k, v in pairs(TibiSuiteDB.weekSnap or {}) do
    if type(v) == "table" and (tonumber(v.at) or 0) >= from then chars[k] = v end
  end
  r.chars = chars
  TibiSuiteDB.weekRecap = TibiSuiteDB.weekRecap or {}
  local wr = TibiSuiteDB.weekRecap
  wr[wid] = r
  local ids = {}
  for id in pairs(wr) do ids[#ids + 1] = id end
  if #ids > KEEP then
    table.sort(ids)
    for i = 1, #ids - KEEP do wr[ids[i]] = nil end
  end
end

-- Bilans tries du plus recent au plus ancien : { {wid, rec} }.
function TibiSuite.GetRecaps()
  local out = {}
  for id, r in pairs(TibiSuiteDB and TibiSuiteDB.weekRecap or {}) do
    if type(r) == "table" then out[#out + 1] = { wid = tonumber(id), rec = r } end
  end
  table.sort(out, function(a, b) return a.wid > b.wid end)
  return out
end

-- Bloc d'export (data.suite.recap) : 8 semaines, compact.
function TibiSuite.ExportRecap()
  local out = {}
  for _, e in ipairs(TibiSuite.GetRecaps()) do
    local r = e.rec
    out[#out + 1] = { w = e.wid * 3600, s = r.s, g = r.g, b = r.best and r.best.x or nil, wo = r.worth }
  end
  return out
end

-- ── Fenetre ─────────────────────────────────────────────────────────
local f, Refresh
local tiles, vrows = {}, {}
local TILES = {
  { key = "played",  lbl = "RCP_T_PLAYED" },
  { key = "quests",  lbl = "RCP_T_QUESTS",   sub = "worldQuests", subFmt = "RCP_WQ_FMT" },
  { key = "dungeons", lbl = "RCP_T_DUNGEONS", sub = "mplus", subFmt = "RCP_MPLUS_FMT" },
  { key = "raids",   lbl = "RCP_T_RAIDS" },
  { key = "delves",  lbl = "RCP_T_DELVES" },
  { key = "gold",    lbl = "RCP_T_GOLD" },
  { key = "rep",     lbl = "RCP_T_REP" },
  { key = "ach",     lbl = "RCP_T_ACH" },
}
local W = 600

local function Fmt(key, v)
  v = tonumber(v) or 0
  if key == "played" then return TibiSuite.FmtDuration and TibiSuite.FmtDuration(v) or (math.floor(v / 3600) .. " h") end
  if key == "gold" then
    if TibiSuite.FmtGoldCoin then return TibiSuite.FmtGoldCoin(v) end
    if TibiSuite.IsStreaming and TibiSuite.IsStreaming() then return L.STREAM_GOLD or "***" end
    return tostring(math.floor(v / 10000)) .. " po"
  end
  if key == "ach" then return tostring(v) .. " " .. L.RCP_PTS end
  return (BreakUpLargeNumbers and BreakUpLargeNumbers(v)) or tostring(v)
end

-- Evolution : texte colore, ou nil sans semaine de comparaison.
local function Delta(cur, prev)
  cur, prev = tonumber(cur), tonumber(prev)
  if not (cur and prev) then return nil end
  if prev == 0 then
    if cur == 0 then return "|cFF62616B=|r" end
    return "|cFF4FD16B" .. L.RCP_NEW .. "|r"
  end
  local pct = math.floor((cur - prev) / math.abs(prev) * 100 + 0.5)
  if pct == 0 then return "|cFF62616B=|r" end
  if pct > 0 then return "|cFF4FD16B+" .. pct .. " %|r" end
  return "|cFFFF9A3C" .. pct .. " %|r"
end

local function Build()
  if f or not Kit() then return f end
  f = CreateFrame("Frame", "TibiSuiteRecap", UIParent, "BackdropTemplate")
  f:SetSize(W, 400)
  f:SetPoint("CENTER", 0, 60)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if K.SkinLikeSuite then K.SkinLikeSuite(f, K.ACC) end
  if K.AddFadeIn then K.AddFadeIn(f, 0.25) end
  table.insert(UISpecialFrames, "TibiSuiteRecap")
  f.logo = f:CreateTexture(nil, "ARTWORK"); f.logo:SetSize(38, 38); f.logo:SetPoint("TOPLEFT", 18, -16)
  f.logo:SetTexture(K.LOGO)
  f.title = K.Text(f, "GameFontNormalLarge", L.RCP_TITLE, Acc())
  f.title:SetPoint("TOPLEFT", f.logo, "TOPRIGHT", 12, -1)
  f.sub = K.Text(f, "GameFontHighlightSmall", "", K.COL.MUT)
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
  f.close = K.Btn(f, 26, 26, "X", "ghost")
  f.close:SetPoint("TOPRIGHT", -10, -10)
  f.close:SetScript("OnClick", function() f:Hide() end)
  -- Historique : fleches entre les semaines gardees (8 au plus).
  f.nextW = K.Btn(f, 26, 26, ">", "ghost")
  f.nextW:SetPoint("RIGHT", f.close, "LEFT", -12, 0)
  f.prevW = K.Btn(f, 26, 26, "<", "ghost")
  f.prevW:SetPoint("RIGHT", f.nextW, "LEFT", -4, 0)
  f.histTxt = K.Text(f, "GameFontDisableSmall", "", K.COL.DIM)
  f.histTxt:SetPoint("RIGHT", f.prevW, "LEFT", -8, 0)
  local function step(d)
    local list = TibiSuite.GetRecaps()
    for i, e in ipairs(list) do
      if e.wid == f.wid then
        local o = list[i + d]   -- liste du plus recent au plus ancien
        if o then Refresh(o.wid) end
        return
      end
    end
  end
  f.prevW:SetScript("OnClick", function() step(1) end)
  f.nextW:SetScript("OnClick", function() step(-1) end)
  for _, b in ipairs({ { f.prevW, "RCP_PREV_TT" }, { f.nextW, "RCP_NEXT_TT" } }) do
    b[1]:HookScript("OnEnter", function(s)
      GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:AddLine(L[b[2]], 1, 1, 1); GameTooltip:Show()
    end)
    b[1]:HookScript("OnLeave", function() GameTooltip:Hide() end)
  end
  f.sep = f:CreateTexture(nil, "ARTWORK"); f.sep:SetHeight(1)
  f.sep:SetPoint("TOPLEFT", 16, -68); f.sep:SetPoint("TOPRIGHT", -16, -68)
  f.sep:SetColorTexture(1, 1, 1, 0.10)
  local tw = math.floor((W - 32 - 3 * 8) / 4)
  for i, def in ipairs(TILES) do
    local t = K.Card(f)
    t:SetSize(tw, 62)
    t:SetPoint("TOPLEFT", 16 + ((i - 1) % 4) * (tw + 8), -80 - math.floor((i - 1) / 4) * 70)
    t.lbl = K.Text(t, "GameFontNormalSmall", L[def.lbl], K.COL.MUT); t.lbl:SetPoint("TOPLEFT", 10, -8)
    t.val = K.Text(t, "GameFontHighlightLarge", "", K.COL.TXT); t.val:SetPoint("TOPLEFT", t.lbl, "BOTTOMLEFT", 0, -4)
    t.d = K.Text(t, "GameFontNormalSmall", "", K.COL.MUT); t.d:SetPoint("TOPRIGHT", -8, -8)
    t.sub = K.Text(t, "GameFontDisableSmall", "", K.COL.DIM); t.sub:SetPoint("TOPLEFT", t.val, "BOTTOMLEFT", 0, -2)
    tiles[i] = t
  end
  f.lines = K.Text(f, "GameFontHighlight", "", K.COL.TXT, W - 40)
  f.lines:SetPoint("TOPLEFT", 20, -230)
  f.lines:SetJustifyH("LEFT"); f.lines:SetSpacing(5)
  f.vHead = K.Label(f, L.RCP_VAULT)
  f.empty = K.Text(f, "GameFontHighlight", L.RCP_NONE, K.COL.MUT, W - 48)
  f.login = K.Btn(f, 220, 24, "", "ghost")
  f.login:SetPoint("BOTTOMLEFT", 12, 14)
  f.login._label:ClearAllPoints(); f.login._label:SetPoint("LEFT", 6, 0)
  local function paintLogin()
    local on = TibiSuiteDB.weekRecapPopup ~= false
    local box = on and "|TInterface\\Buttons\\UI-CheckBox-Check:16:16|t" or "|TInterface\\Buttons\\UI-CheckBox-Up:16:16|t"
    f.login._label:SetText(box .. " " .. L.RCP_LOGIN)
  end
  f.login:SetScript("OnClick", function()
    TibiSuiteDB.weekRecapPopup = (TibiSuiteDB.weekRecapPopup ~= false) and false or nil
    paintLogin()
  end)
  f.PaintLogin = paintLogin
  f.ok = K.Btn(f, 120, 28, L.RCP_CLOSE, "pri")
  f.ok:SetPoint("BOTTOMRIGHT", -16, 12)
  f.ok:SetScript("OnClick", function() f:Hide() end)
  f.week = K.Btn(f, 140, 28, L.RCP_WEEK)
  f.week:SetPoint("RIGHT", f.ok, "LEFT", -10, 0)
  f.week:SetScript("OnClick", function() f:Hide(); if TibiSuite.OpenCentre then TibiSuite.OpenCentre("home") end end)
  f:Hide()
  return f
end

local function DayText(t) return date and date("%d/%m", t) or tostring(t) end

function Refresh(wid)
  if not f then return end
  f.title:SetTextColor(Acc()[1], Acc()[2], Acc()[3])
  f.PaintLogin()
  local list = TibiSuite.GetRecaps()
  local idx
  for i, e in ipairs(list) do if e.wid == wid then idx = i end end
  local e = idx and list[idx]
  local prev = idx and list[idx + 1]
  f.wid = wid
  f.prevW:SetEnabled(prev ~= nil); f.prevW:SetAlpha(prev and 1 or 0.3)
  f.nextW:SetEnabled(idx ~= nil and idx > 1); f.nextW:SetAlpha((idx and idx > 1) and 1 or 0.3)
  f.histTxt:SetText(idx and #list > 1 and string.format(L.RCP_HIST_FMT, #list - idx + 1, #list) or "")
  -- Semaine d'avant seulement si elle suit directement (pas de trou).
  if prev and e and (e.wid - prev.wid) > 7 * 24 + 2 then prev = nil end
  local curWid = CurrentWeek()
  f.title:SetText((e and e.wid == curWid) and L.RCP_TITLE_CUR or L.RCP_TITLE)
  for _, t in ipairs(tiles) do t:SetShown(e ~= nil) end
  for _, r in ipairs(vrows) do r:Hide() end
  f.lines:SetShown(e ~= nil); f.vHead:SetShown(e ~= nil)
  f.empty:SetShown(e == nil)
  if not e then
    f.sub:SetText("")
    f.empty:ClearAllPoints(); f.empty:SetPoint("TOPLEFT", 24, -86)
    f:SetHeight(180)
    return
  end
  local r = e.rec
  f.sub:SetText(string.format(L.RCP_SUB_FMT, DayText(r.from or 0), DayText((r.to or 0) - 60))
    .. (prev and ("  ·  " .. L.RCP_VS) or ""))
  local s, ps = r.s or {}, prev and prev.rec.s or nil
  for i, def in ipairs(TILES) do
    local t = tiles[i]
    t.val:SetText(Fmt(def.key, s[def.key]))
    t.d:SetText(ps and Delta(s[def.key], ps[def.key]) or "")
    if def.sub and (tonumber(s[def.sub]) or 0) > 0 then t.sub:SetText(string.format(L[def.subFmt], s[def.sub]))
    else t.sub:SetText("") end
  end
  local lines = {}
  local g = r.g or { d = 0, t = 0 }
  lines[#lines + 1] = "|cFFFFD100" .. L.RCP_GOALS .. "|r  " .. ((g.t or 0) > 0 and string.format(L.RCP_GOALS_FMT, g.d, g.t) or L.RCP_GOALS_NONE)
  lines[#lines + 1] = "|cFFFFD100" .. L.RCP_BEST .. "|r  " .. (r.best and tostring(r.best.x) or ("|cFF62616B" .. L.RCP_BEST_NONE .. "|r"))
  if r.worth then
    local d = prev and prev.rec.worth and Delta(r.worth, prev.rec.worth) or nil
    lines[#lines + 1] = "|cFFFFD100" .. L.RCP_WORTH .. "|r  " .. Fmt("gold", r.worth) .. (d and ("  " .. d) or "")
  end
  f.lines:SetText(table.concat(lines, "\n"))
  local y = -230 - (f.lines:GetStringHeight() or 60) - 16
  f.vHead:ClearAllPoints(); f.vHead:SetPoint("TOPLEFT", 18, y); y = y - 24
  local n = 0
  local keys = {}
  for k in pairs(r.chars or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local snap = r.chars[k]
    local parts = {}
    for _, l in ipairs(snap.l or {}) do
      if l.g == 1 and l.x and l.x ~= "" then parts[#parts + 1] = tostring(l.x) end
    end
    if #parts > 0 and n < 6 then
      n = n + 1
      local row = vrows[n]
      if not row then
        row = K.Text(f, "GameFontHighlightSmall", "", K.COL.TXT, W - 44)
        row:SetJustifyH("LEFT"); row:SetWordWrap(false)
        vrows[n] = row
      end
      local who = k:match("^(.-)%-") or k
      who = who:gsub("^%l", string.upper)
      if TibiSuite.SafeName then who = TibiSuite.SafeName(who) end
      row:SetText("|cFFA09EA6" .. who .. "|r   " .. table.concat(parts, "  ·  "))
      row:ClearAllPoints(); row:SetPoint("TOPLEFT", 22, y)
      row:Show()
      y = y - 20
    end
  end
  f.vHead:SetShown(n > 0)
  if n == 0 then y = y + 24 end
  f:SetHeight(-y + 60)
end

-- wid = nil : derniere semaine close, sinon la semaine en cours.
function TibiSuite.ShowRecap(wid)
  if not Build() then return false end
  pcall(TibiSuite.FreezeWeek)
  if not wid then
    local cur = CurrentWeek()
    for _, e in ipairs(TibiSuite.GetRecaps()) do
      if e.wid ~= cur then wid = e.wid; break end
    end
    wid = wid or cur
  end
  if TibiSuite.ApplyUIScaleTo then TibiSuite.ApplyUIScaleTo(f) end
  Refresh(wid)
  f:Show()
  return true
end

-- ── Gel continu et fenetre a la connexion ───────────────────────────
local pending = false
if TibiSuite.OnStatusChanged then
  TibiSuite.OnStatusChanged(function()
    if pending then return end
    pending = true
    C_Timer.After(60, function() pending = false; pcall(TibiSuite.FreezeWeek) end)
  end)
end

local function Shown(name) local x = _G[name]; return x and x.IsShown and x:IsShown() or false end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, e, isLogin)
  if e == "PLAYER_LOGOUT" then pcall(TibiSuite.FreezeWeek); return end
  ev:UnregisterEvent("PLAYER_ENTERING_WORLD")
  -- Le gel de la semaine precedente a eu lieu pendant la session d'avant :
  -- on lit d'abord, on ne gele la nouvelle semaine qu'apres.
  local wid = CurrentWeek()
  local last
  for _, x in ipairs(TibiSuite.GetRecaps()) do
    if x.wid ~= wid then last = x; break end
  end
  C_Timer.After(15, function()
    pcall(TibiSuite.FreezeWeek)
    C_Timer.NewTicker(FREEZE_EVERY, function() pcall(TibiSuite.FreezeWeek) end)
  end)
  if not (isLogin and wid and last) then return end
  if TibiSuiteDB.recapSeen == wid then return end
  if TibiSuiteDB.weekRecapPopup == false then TibiSuiteDB.recapSeen = wid; return end
  local tries = 0
  local function try()
    tries = tries + 1
    local busy = InCombatLockdown() or (IsInInstance and IsInInstance())
      or Shown("TibiSuiteSetupWizard") or Shown("TibiSuiteWhatsNew") or Shown("TibiSuitePalette")
      or (TibiSuite.IsCentreShown and TibiSuite.IsCentreShown())
    if not busy then
      TibiSuiteDB.recapSeen = wid
      TibiSuite.ShowRecap(last.wid)
      return
    end
    if tries < 40 then C_Timer.After(5, try) end
  end
  C_Timer.After(20, try)
end)
