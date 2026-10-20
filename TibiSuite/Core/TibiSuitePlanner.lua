--[[============================================================================
  TibiSuitePlanner.lua  -  « J'ai X minutes » : session guidee (7.3, lot A)
  ---------------------------------------------------------------------------
  Le joueur choisit un temps (15 a 90 min). La suite compose une liste
  ordonnee qui tient dans ce temps, puis la coche au fil de la session.

  Candidats, dans l'ordre de GetNextAction : etats urgents des modules, puis
  « A faire » incomplets, objectifs, suggestions du Conseiller, enfin la
  progression la plus basse. Duree de chaque entree : champ facultatif `est`
  (minutes) du statusFn ou du suggestFn, sinon duree apprise
  (TibiSuiteDB.estLearn[type], moyenne glissante), sinon table DEF_EST.
  Remplissage glouton avec 15 % de marge pour les trajets ; un farm de
  SkillTracker comble le reste s'il reste au moins 15 min.

  Suivi : toutes les 5 s pendant une session (rien sinon). Etat : fait quand
  la progression atteint 100 %, quand l'urgence tombe, quand l'objectif est
  atteint ou quand la suggestion disparait. Clic droit = cocher a la main.
  Fin : tout est fait, ou temps ecoule + 10 min. Bilan d'une ligne dans le
  fil d'activite.

  Donnees : TibiSuiteCharDB.session = { at, budget, items = { {id, key, kind,
  text, est, done, doneAt, auto, p0, u0} } }, TibiSuiteCharDB.sessionLast,
  TibiSuiteDB.estLearn[type] = minutes.
  API : TibiSuite.PlanSession(min), StartSession(min), StopSession(),
        GetSession(), ToggleSessionWindow(), ShowSessionWindow().
  Slash : /ts temps [min]. Raccourci TIBISUITE_PLANNER.
  NON TESTE EN JEU (nouveau fichier : redemarrage complet du client).
============================================================================]]

local L = TibiSuiteL or {}
TibiSuiteL = L
local function D(k, v) if L[k] == nil then L[k] = v end end
D("PLN_TITLE",        "Ma session")
D("PLN_PICK",         "Combien de temps as-tu ?")
D("PLN_PICK_SUB",     "La suite compose une liste qui tient dans ce temps, puis la coche toute seule.")
D("PLN_MIN_FMT",      "%d min")
D("PLN_EST_FMT",      "~%d min")
D("PLN_SUB_FMT",      "%d min choisies  ·  reste %s  ·  %d / %d faits")
D("PLN_OVER",         "temps écoulé")
D("PLN_EMPTY",        "Rien à proposer pour l'instant : tout est à jour. Profite !")
D("PLN_STOP",         "Terminer")
D("PLN_REPLAN",       "Refaire le plan")
D("PLN_FARM",         "Récolte ou pêche pour finir la session")
D("PLN_HINT",         "Clic : y aller.  Clic droit : cocher ou décocher.")
D("PLN_DONE_FMT",     "Session terminée : %d / %d faits en %s.")
D("PLN_ALLDONE",      "Tout est fait, bravo !")
D("PLN_ABOUT",        "Les durées sont des estimations, affinées au fil de tes sessions.")
D("BIND_PLANNER",     "Session guidée (J'ai X minutes)")
D("HELP_TEMPS",       "session guidée : /ts temps 45")
D("PAL_C_PLANNER",    "J'ai du temps : session guidée")
D("CTR_Q_PLANNER",    "J'ai du temps")

BINDING_NAME_TIBISUITE_PLANNER = L.BIND_PLANNER

local BUDGETS = { 15, 30, 45, 60, 90 }
local MARGIN  = 0.85      -- 15 % de marge pour les trajets
local FARM_MIN = 15
local W, ROW_H = 420, 34

-- Durees par defaut (minutes). Modules : une ligne d'etat ; suggestions :
-- par type ; objectifs : une valeur unique.
local DEF_EST = {
  mod_Daily = 20, mod_Weekly = 30, mod_Post = 3, mod_Rep = 15, mod_Skill = 10,
  mod_Lvl = 30, mod_Stats = 15, mod_Dgn = 20, mod_Leg = 30, mod_Lair = 15,
  sug_ach = 15, sug_coll = 20, sug_rare = 3, sug_wb = 6, sug_renown = 15,
  sug_weekly = 25, sug_legendary = 30, sug_mplus = 30,
  goal = 15,
}

local K
local function Kit() K = K or TibiSuite._kit; return K ~= nil end
local function Acc() return TibiSuite.ACCENT or { 0.769, 0.122, 0.231 } end

local function CDB()
  TibiSuiteCharDB = TibiSuiteCharDB or {}
  return TibiSuiteCharDB
end

local function Learned(kind)
  local t = TibiSuiteDB and TibiSuiteDB.estLearn
  local v = t and tonumber(t[kind])
  return v and v > 0 and v or nil
end

local function Est(kind, given)
  local g = tonumber(given)
  if g and g > 0 then return math.floor(g + 0.5) end
  return math.floor((Learned(kind) or DEF_EST[kind] or 15) + 0.5)
end

-- Apprentissage : duree entre deux coches automatiques consecutives (ou
-- depuis le debut de session), gardee si elle reste plausible.
local function Learn(kind, minutes, est)
  if not (TibiSuiteDB and kind and minutes) then return end
  if minutes < 1 or minutes > math.max(3 * (est or 15), 10) then return end
  TibiSuiteDB.estLearn = TibiSuiteDB.estLearn or {}
  local old = tonumber(TibiSuiteDB.estLearn[kind])
  local v = old and (old * 0.7 + minutes * 0.3) or minutes
  TibiSuiteDB.estLearn[kind] = math.floor(math.max(1, math.min(120, v)) * 10 + 0.5) / 10
end

local function CatalogByKey()
  local cat = {}
  for _, mod in ipairs(TibiSuite.GetCatalog()) do cat[mod.key] = mod end
  return cat
end

-- ── Candidats ───────────────────────────────────────────────────────
-- Meme ordre que GetNextAction : urgent (1-99), A faire (100+), objectifs
-- (150+), suggestions (180+), progression faible (200+).
local function Candidates()
  local out, cat = {}, CatalogByKey()
  local loaded = function(key)
    local m = cat[key]
    return m and C_AddOns.IsAddOnLoaded(m.addonName)
  end
  for gi, g in ipairs(TibiSuite.PANEL_GROUPS or {}) do
    if not g.icons then
      for ki, key in ipairs(g.keys) do
        local st = loaded(key) and TibiSuite.GetModuleStatus and TibiSuite.GetModuleStatus(key)
        if st then
          local prog = tonumber(st.progress)
          local score
          if st.urgent then score = ki
          elseif gi == 1 and (prog == nil or prog < 1) then score = 100 + ki
          elseif prog and prog < 1 then score = 200 + math.floor(prog * 100)
          end
          if score then
            local kind = "mod_" .. key
            out[#out + 1] = { id = "m:" .. key, key = key, kind = kind, text = st.text or key,
              est = Est(kind, st.est), score = score, p0 = prog, u0 = st.urgent and true or nil }
          end
        end
      end
    end
  end
  if TibiSuite.GetGoals and TibiSuite.GoalProgress then
    for i, g in ipairs(TibiSuite.GetGoals()) do
      local ok, _, _, done = pcall(TibiSuite.GoalProgress, g)
      if ok and not done and g.id then
        local key = (g.kind == "module" and g.module) or (g.kind == "gather" and "Skill")
          or (g.kind == "gold" and "Stats") or "Suite"
        out[#out + 1] = { id = "g:" .. tostring(g.id), key = key, kind = "goal", goal = g.id,
          text = g.text, est = Est("goal", g.est), score = 150 + i }
      end
    end
  end
  if TibiSuite.SuggestOn and TibiSuite.SuggestOn() and TibiSuite.GetSuggestions then
    local ok, list = pcall(TibiSuite.GetSuggestions, 6)
    if ok and type(list) == "table" then
      for i, s in ipairs(list) do
        local kind = "sug_" .. tostring(s.kind)
        out[#out + 1] = { id = "s:" .. tostring(s.id), key = s.key, kind = kind, sug = s.id,
          text = s.text, est = Est(kind, s.est), score = 180 + i }
      end
    end
  end
  table.sort(out, function(a, b) return a.score < b.score end)
  return out
end

-- Plan glouton : renvoie la liste des entrees (sans les enregistrer).
function TibiSuite.PlanSession(budget)
  budget = math.max(5, tonumber(budget) or 30)
  local room = budget * MARGIN
  local items, used, seen = {}, 0, {}
  local cands = Candidates()
  for _, c in ipairs(cands) do
    if not seen[c.id] and used + c.est <= room then
      seen[c.id] = true
      items[#items + 1] = c
      used = used + c.est
    end
  end
  -- Rien ne tient : la plus courte des trois premieres, mieux que rien.
  if #items == 0 and #cands > 0 then
    local best
    for i = 1, math.min(3, #cands) do
      if not best or cands[i].est < best.est then best = cands[i] end
    end
    items[1] = best; used = best.est
  end
  local skill = CatalogByKey().Skill
  if room - used >= FARM_MIN and skill and C_AddOns.IsAddOnLoaded(skill.addonName) then
    items[#items + 1] = { id = "farm", key = "Skill", kind = "farm", text = L.PLN_FARM,
      est = math.floor(room - used), score = 999 }
  end
  for _, it in ipairs(items) do it.score = nil end
  return items
end

-- ── Session ─────────────────────────────────────────────────────────
local ticker, Refresh, f

function TibiSuite.GetSession()
  local s = CDB().session
  if type(s) ~= "table" or type(s.items) ~= "table" then return nil end
  return s
end

local function CountDone(s)
  local n = 0
  for _, it in ipairs(s.items) do if it.done then n = n + 1 end end
  return n
end

local function Finish(reason)
  local s = TibiSuite.GetSession()
  if not s then return end
  local n, tot = CountDone(s), #s.items
  local dur = math.max(60, time() - (s.at or time()))
  CDB().sessionLast = { at = s.at, budget = s.budget, done = n, total = tot, dur = dur, why = reason }
  CDB().session = nil
  if ticker then ticker:Cancel(); ticker = nil end
  if tot > 0 and TibiSuite.Notify then
    local txt = string.format(L.PLN_DONE_FMT, n, tot, TibiSuite.FmtDuration and TibiSuite.FmtDuration(dur) or (math.floor(dur / 60) .. " min"))
    TibiSuite.Notify("Suite", txt, { toast = reason == "all" })
  end
  if Refresh then Refresh() end
end

function TibiSuite.StopSession() Finish("stop") end

local function FindSuggestion(id)
  if not (id and TibiSuite.GetSuggestions) then return nil end
  local ok, list = pcall(TibiSuite.GetSuggestions, 30)
  if not ok or type(list) ~= "table" then return nil end
  for _, s in ipairs(list) do if s.id == id then return s end end
  return nil
end

local function FindGoal(id)
  for _, g in ipairs(TibiSuite.GetGoals and TibiSuite.GetGoals() or {}) do
    if tostring(g.id) == tostring(id) then return g end
  end
  return nil
end

local function IsDoneNow(it)
  if it.kind == "farm" then return false end
  if it.goal then
    local g = FindGoal(it.goal)
    if not g then return true end
    local ok, _, _, done = pcall(TibiSuite.GoalProgress, g)
    return ok and done and true or false
  end
  if it.sug then
    -- Disparue de la liste = faite (ou ecartee) ; suggestion avec compteur
    -- complet = faite.
    local s = FindSuggestion(it.sug)
    if not s then return true end
    return (tonumber(s.total) and tonumber(s.done) and s.done >= s.total) and true or false
  end
  local st = TibiSuite.GetModuleStatus and TibiSuite.GetModuleStatus(it.key)
  if not st then return false end
  local p = tonumber(st.progress)
  if p and p >= 1 then return true end
  if it.u0 and not st.urgent then return true end
  return false
end

local function Tick()
  local s = TibiSuite.GetSession()
  if not s then if ticker then ticker:Cancel(); ticker = nil end; return end
  local now, changed = time(), false
  for _, it in ipairs(s.items) do
    if not it.done and IsDoneNow(it) then
      -- Duree reelle depuis la coche automatique precedente (ou le debut).
      local last = s.at
      for _, o in ipairs(s.items) do
        if o.done and o.auto and (o.doneAt or 0) > last then last = o.doneAt end
      end
      Learn(it.kind, (now - last) / 60, it.est)
      it.done, it.doneAt, it.auto, changed = true, now, true, true
    end
  end
  local n = CountDone(s)
  local farmOnly = true
  for _, it in ipairs(s.items) do if not it.done and it.kind ~= "farm" then farmOnly = false end end
  if n == #s.items and #s.items > 0 then Finish("all"); return end
  if now > (s.at + s.budget * 60 + 600) then Finish("time"); return end
  if farmOnly and n > 0 and now > (s.at + s.budget * 60) then Finish("time"); return end
  if Refresh and (changed or (f and f:IsShown())) then Refresh() end
end

local function EnsureTicker()
  if ticker or not TibiSuite.GetSession() then return end
  ticker = C_Timer.NewTicker(5, Tick)
end

function TibiSuite.StartSession(budget)
  budget = math.max(5, math.min(240, math.floor(tonumber(budget) or 30)))
  local items = TibiSuite.PlanSession(budget)
  CDB().session = { at = time(), budget = budget, items = items }
  EnsureTicker()
  if Refresh then Refresh() end
  return items
end

-- Garde les entrees faites, recompose le reste avec le temps qui reste.
local function Replan()
  local s = TibiSuite.GetSession()
  if not s then return end
  local left = math.max(5, math.floor((s.at + s.budget * 60 - time()) / 60))
  local kept, seen = {}, {}
  for _, it in ipairs(s.items) do
    if it.done then kept[#kept + 1] = it; seen[it.id] = true end
  end
  for _, it in ipairs(TibiSuite.PlanSession(left)) do
    if not seen[it.id] then kept[#kept + 1] = it end
  end
  s.items = kept
  if Refresh then Refresh() end
end

local function OpenItem(it)
  if it.kind == "farm" then TibiSuite.OpenModuleTo("Skill", "farm"); return end
  if it.goal then
    local g = FindGoal(it.goal)
    if g and g.kind == "gather" then TibiSuite.OpenModuleTo("Skill", "farm")
    elseif g and g.kind == "module" and g.module then TibiSuite.OpenModule(g.module)
    elseif TibiSuite.OpenCentre then TibiSuite.OpenCentre("goals") end
    return
  end
  if it.sug then
    local s = FindSuggestion(it.sug)
    if s then TibiSuite.OpenSuggestion(s); return end
  end
  if it.key and it.key ~= "Suite" then TibiSuite.OpenModule(it.key) end
end

-- ── Fenetre ─────────────────────────────────────────────────────────
local rows, picks = {}, {}

local function ModColor(key)
  for _, mod in ipairs(TibiSuite.GetCatalog()) do
    if mod.key == key and mod.col then return { mod.col.r, mod.col.g, mod.col.b } end
  end
  return Acc()
end

local function MakeRow(i)
  local r = CreateFrame("Button", nil, f, "BackdropTemplate")
  r:SetSize(W - 32, ROW_H)
  r:SetBackdrop(K.FLAT)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local function paint(hover)
    local b = K.COL.CARD2
    r:SetBackdropColor(b[1] + (hover and 0.03 or 0), b[2] + (hover and 0.03 or 0), b[3] + (hover and 0.035 or 0), 0.98)
    r:SetBackdropBorderColor(0, 0, 0, 1)
  end
  r.Paint = paint
  r.stripe = r:CreateTexture(nil, "ARTWORK"); r.stripe:SetPoint("TOPLEFT", 1, -1); r.stripe:SetPoint("BOTTOMLEFT", 1, 1); r.stripe:SetWidth(3)
  r.box = r:CreateTexture(nil, "ARTWORK"); r.box:SetSize(16, 16); r.box:SetPoint("LEFT", 12, 0)
  r.ico = r:CreateTexture(nil, "ARTWORK"); r.ico:SetSize(20, 20); r.ico:SetPoint("LEFT", r.box, "RIGHT", 8, 0)
  r.est = K.Text(r, "GameFontNormalSmall", "", K.COL.MUT)
  r.est:SetPoint("RIGHT", -12, 0)
  r.txt = K.Text(r, "GameFontHighlight", "", K.COL.TXT)
  r.txt:SetPoint("LEFT", r.ico, "RIGHT", 8, 0); r.txt:SetPoint("RIGHT", r.est, "LEFT", -10, 0)
  r.txt:SetJustifyH("LEFT"); r.txt:SetWordWrap(false)
  r:SetScript("OnEnter", function(s)
    s:Paint(true)
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    GameTooltip:AddLine(s.it and s.it.text or "", 1, 1, 1, true)
    GameTooltip:AddLine(L.PLN_HINT, 0.55, 0.55, 0.60, true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function(s) s:Paint(false); GameTooltip:Hide() end)
  r:SetScript("OnClick", function(s, btn)
    if not s.it then return end
    if btn == "RightButton" then
      s.it.done = not s.it.done or nil
      s.it.doneAt, s.it.auto = s.it.done and time() or nil, nil
      local ses = TibiSuite.GetSession()
      if ses and CountDone(ses) == #ses.items then Finish("all") elseif Refresh then Refresh() end
      return
    end
    OpenItem(s.it)
  end)
  paint(false)
  rows[i] = r
  return r
end

local function Build()
  if f or not Kit() then return f end
  f = CreateFrame("Frame", "TibiSuitePlanner", UIParent, "BackdropTemplate")
  f:SetSize(W, 200)
  f:SetPoint("RIGHT", UIParent, "RIGHT", -120, 60)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local p, _, rp, x, y = s:GetPoint()
    TibiSuiteDB.plannerPos = { p, rp, x, y }
  end)
  local pos = TibiSuiteDB and TibiSuiteDB.plannerPos
  if type(pos) == "table" and pos[1] then
    f:ClearAllPoints(); f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  end
  if K.SkinLikeSuite then K.SkinLikeSuite(f, K.ACC) end
  table.insert(UISpecialFrames, "TibiSuitePlanner")

  f.logo = f:CreateTexture(nil, "ARTWORK"); f.logo:SetSize(26, 26); f.logo:SetPoint("TOPLEFT", 14, -12)
  f.logo:SetTexture(K.LOGO)
  f.title = K.Text(f, "GameFontNormalLarge", L.PLN_TITLE, Acc())
  f.title:SetPoint("TOPLEFT", f.logo, "TOPRIGHT", 10, 1)
  f.sub = K.Text(f, "GameFontHighlightSmall", "", K.COL.MUT)
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
  f.close = K.Btn(f, 24, 24, "X", "ghost")
  f.close:SetPoint("TOPRIGHT", -8, -8)
  f.close:SetScript("OnClick", function() f:Hide() end)
  f.sep = f:CreateTexture(nil, "ARTWORK"); f.sep:SetHeight(1)
  f.sep:SetPoint("TOPLEFT", 14, -50); f.sep:SetPoint("TOPRIGHT", -14, -50)
  f.sep:SetColorTexture(1, 1, 1, 0.10)

  -- Choix du temps (pas de session en cours).
  f.pickTxt = K.Text(f, "GameFontHighlight", L.PLN_PICK, K.COL.TXT)
  f.pickTxt:SetPoint("TOPLEFT", 18, -64)
  f.pickSub = K.Text(f, "GameFontHighlightSmall", L.PLN_PICK_SUB, K.COL.MUT, W - 40)
  f.pickSub:SetPoint("TOPLEFT", f.pickTxt, "BOTTOMLEFT", 0, -4)
  local bw = math.floor((W - 36 - 4 * 8) / #BUDGETS)
  for i, m in ipairs(BUDGETS) do
    local b = K.Btn(f, bw, 30, string.format(L.PLN_MIN_FMT, m), i == 3 and "pri" or nil)
    b:SetPoint("TOPLEFT", 18 + (i - 1) * (bw + 8), -112)
    b:SetScript("OnClick", function() TibiSuite.StartSession(m) end)
    picks[i] = b
  end
  f.about = K.Text(f, "GameFontDisableSmall", L.PLN_ABOUT, K.COL.DIM, W - 40)

  f.empty = K.Text(f, "GameFontHighlight", L.PLN_EMPTY, K.COL.MUT, W - 48)
  f.stop = K.Btn(f, 110, 26, L.PLN_STOP)
  f.stop:SetPoint("BOTTOMRIGHT", -14, 12)
  f.stop:SetScript("OnClick", function() TibiSuite.StopSession() end)
  f.replan = K.Btn(f, 140, 26, L.PLN_REPLAN, "ghost")
  f.replan:SetPoint("RIGHT", f.stop, "LEFT", -8, 0)
  f.replan:SetScript("OnClick", Replan)

  -- En combat : la fenetre s'efface, elle revient apres.
  f:RegisterEvent("PLAYER_REGEN_DISABLED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:SetScript("OnEvent", function(s, ev)
    if ev == "PLAYER_REGEN_DISABLED" then s:SetAlpha(0.25)
    else s:SetAlpha(1) end
  end)
  f:Hide()
  return f
end

function Refresh()
  if not f then return end
  f.title:SetTextColor(Acc()[1], Acc()[2], Acc()[3])
  local s = TibiSuite.GetSession()
  local picking = s == nil
  f.pickTxt:SetShown(picking); f.pickSub:SetShown(picking)
  for _, b in ipairs(picks) do b:SetShown(picking) end
  f.stop:SetShown(not picking); f.replan:SetShown(not picking)
  if picking then
    for _, r in ipairs(rows) do r:Hide() end
    f.empty:Hide()
    local last = CDB().sessionLast
    f.sub:SetText(last and string.format(L.PLN_DONE_FMT, last.done or 0, last.total or 0,
      TibiSuite.FmtDuration and TibiSuite.FmtDuration(last.dur or 0) or "") or "")
    f.about:ClearAllPoints(); f.about:SetPoint("TOPLEFT", 18, -152); f.about:Show()
    f:SetHeight(186)
    return
  end
  f.about:Hide()
  local left = s.at + s.budget * 60 - time()
  local leftTxt = left > 0 and (TibiSuite.FmtDuration and TibiSuite.FmtDuration(left) or (math.floor(left / 60) .. " min")) or L.PLN_OVER
  f.sub:SetText(string.format(L.PLN_SUB_FMT, s.budget, leftTxt, CountDone(s), #s.items))
  local y = -60
  local OK = "|TInterface\\Buttons\\UI-CheckBox-Check:16:16|t"
  for i, it in ipairs(s.items) do
    local r = rows[i] or MakeRow(i)
    r.it = it
    local c = it.key == "Suite" and Acc() or ModColor(it.key)
    r.stripe:SetColorTexture(c[1], c[2], c[3], 1)
    if it.done then r.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    else r.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up") end
    r.ico:SetTexture((TibiSuite.MODULE_LOGO and TibiSuite.MODULE_LOGO[it.key]) or K.LOGO)
    r.txt:SetText(it.text or "")
    local tc = it.done and K.COL.DIM or K.COL.TXT
    r.txt:SetTextColor(tc[1], tc[2], tc[3])
    r.est:SetText(it.done and OK or string.format(L.PLN_EST_FMT, it.est or 0))
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 16, y)
    r:Show()
    y = y - ROW_H - 4
  end
  for i = #s.items + 1, #rows do rows[i]:Hide() end
  f.empty:SetShown(#s.items == 0)
  if #s.items == 0 then
    f.empty:ClearAllPoints(); f.empty:SetPoint("TOPLEFT", 20, y - 4)
    y = y - 40
  end
  f:SetHeight(-y + 50)
end

function TibiSuite.ShowSessionWindow()
  if not Build() then return false end
  if TibiSuite.ApplyUIScaleTo then TibiSuite.ApplyUIScaleTo(f) end
  Refresh()
  f:Show()
  return true
end

function TibiSuite.ToggleSessionWindow()
  if f and f:IsShown() then f:Hide() else TibiSuite.ShowSessionWindow() end
end

-- /ts temps [min] : sans nombre, ouvre la fenetre (choix ou session en cours).
function TibiSuite.SessionSlash(arg)
  local m = tonumber(arg)
  if m then TibiSuite.StartSession(m) end
  TibiSuite.ShowSessionWindow()
end

-- Reprise apres /reload ou reconnexion : la session en cours continue si
-- son temps n'est pas depasse de plus de 10 min, sinon elle est close.
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local s = TibiSuite.GetSession()
  if not s then return end
  if time() > (s.at or 0) + (s.budget or 0) * 60 + 600 then
    C_Timer.After(5, function() Finish("time") end)
  else
    EnsureTicker()
    C_Timer.After(4, function() TibiSuite.ShowSessionWindow() end)
  end
end)
