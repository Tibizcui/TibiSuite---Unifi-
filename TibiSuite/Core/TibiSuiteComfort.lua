--[[============================================================================
  TibiSuiteComfort.lua  -  Annuler, restauration, lisibilite, profils
                           automatiques, rappels
  ---------------------------------------------------------------------------
  1. ANNULER. Le socle (v15) confie a UI.RecordUndo une photo du panneau
     d'options juste avant chaque changement fait a la souris (case,
     curseur), dans N'IMPORTE QUEL panneau du socle : suite et modules.
     TibiSuite.Undo() remet le panneau dans l'etat de la photo. Pile de 30,
     en memoire seulement (session). Un curseur tire en continu = une seule
     entree.
  2. POINTS DE RESTAURATION. Photo des reglages de la SUITE (TibiSuiteDB,
     liste SET_KEYS + modules actives), jamais des donnees des modules.
     Automatique a la connexion (si quelque chose a change), avant un profil
     importe, un profil automatique ou une restauration. 8 points gardes
     (TibiSuiteDB.restorePoints), le plus ancien automatique part en premier.
  3. LISIBILITE. Taille des fenetres de la suite (uiScale, 90-130 %),
     contraste eleve et mode daltonien (UI.ApplyReadability du socle + kit
     du core, modifies sur place).
  4. PROFILS AUTOMATIQUES. Profils de suite nommes (TibiSuiteDB.setups) et
     regles : specialisation > personnage > montee de niveau. Le profil actif
     (TibiSuiteDB.activeSetup) est memorise avant de passer a un autre. Les
     modules a activer ou couper demandent un rechargement : propose, jamais
     force.
  5. RAPPELS. Reset quotidien / hebdo (une fois par reset), note par
     personnage a la connexion, evenements du calendrier (guilde, invitations
     acceptees) 15 min avant. Tout passe par TibiSuite.Notify.
============================================================================]]

local L = TibiSuiteL or {}
TibiSuiteL = L
local function D(k, v) if L[k] == nil then L[k] = v end end
D("UNDO_DONE_FMT",   "Annulé : %s")
D("UNDO_NONE",       "Rien à annuler.")
D("RP_LOGIN",        "Connexion")
D("RP_MANUAL",       "Manuel")
D("RP_BEFORE_PROF",  "Avant import d'un profil")
D("RP_BEFORE_SETUP_FMT", "Avant le profil « %s »")
D("RP_BEFORE_RESTORE", "Avant restauration")
D("RP_CREATED",      "Point de restauration créé.")
D("RP_SAME",         "Rien n'a changé depuis le dernier point.")
D("RP_RESTORED",     "Réglages de la suite restaurés.")
D("RP_RELOAD_ASK",   "Des modules changent d'état : un rechargement de l'interface est nécessaire pour finir.\n\nRecharger maintenant ?")
D("SETUP_APPLIED_FMT", "Profil « %s » appliqué.")
D("SETUP_SAVED_FMT", "Profil « %s » enregistré.")
D("SETUP_DEFAULT_FMT", "Profil %d")
D("REM_DAILY_FMT",   "Reset quotidien dans %s.")
D("REM_WEEKLY_FMT",  "Reset hebdomadaire dans %s.")
D("REM_WEEKLY_LEFT_FMT", "Reset hebdomadaire dans %s : %d module(s) pas terminé(s).")
D("REM_NOTE_FMT",    "Note pour ce personnage : %s")
D("REM_CAL_FMT",     "Calendrier : « %s » à %s.")
D("READ_RELOAD",     "Contraste et couleurs : complet après un rechargement de l'interface.")

local UI = _G.TibiMidnight

-- ================================================================
-- REGLAGES DE LA SUITE : photo et application
-- ================================================================
local SET_KEYS = {
  "hidden", "vertical", "locked", "logoSize", "floatHidden", "mmHidden", "loginMsg", "cols", "rows",
  "scale", "barStyle", "dockLabels", "accentMode", "panelW", "panelH", "optionsInCentre",
  "gameMenuEntry", "statsAutoExport", "mmAngle",
  "notifToasts", "notifSound", "notifCombat", "notifMute",
  "streaming", "autoCombat", "autoInstance", "autoMount", "autoVehicle", "autoPet", "autoMode", "autoFade",
  "widgets", "widgetsLocked", "widgetScale",
  "uiScale", "highContrast", "cvd",
  "remindDaily", "remindDailyMin", "remindWeekly", "remindWeeklyH", "remindCal", "remindNote",
  "sugOn", "sugHabits", "sugNoGroup", "sugKinds", "advPopup",
  "versionCheck",
}
TibiSuite.SET_KEYS = SET_KEYS

local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = Copy(x) end
  return t
end

local function Same(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

function TibiSuite.CaptureSettings()
  local s = { db = {}, mods = {} }
  for _, k in ipairs(SET_KEYS) do s.db[k] = Copy(TibiSuiteDB[k]) end
  for _, mod in ipairs(TibiSuite.GetCatalog()) do
    if TibiSuite.ModuleExists(mod.addonName) then s.mods[mod.key] = TibiSuite.IsModuleEnabled(mod.key) and true or false end
  end
  return s
end

local function AskReload()
  if TibiSuite.NeedsReload and TibiSuite.NeedsReload() and TibiSuite.ShowConfirm then
    TibiSuite.ShowConfirm(L.RP_RELOAD_ASK, function() TibiSuite.Reload() end)
    return true
  end
  return false
end

-- Applique une photo de reglages, en direct pour tout ce qui le permet.
-- Renvoie true si un rechargement est necessaire (modules).
function TibiSuite.ApplySettings(s, noAsk)
  if type(s) ~= "table" or type(s.db) ~= "table" then return false end
  local wasStream = TibiSuite.IsStreaming and TibiSuite.IsStreaming()
  for _, k in ipairs(SET_KEYS) do TibiSuiteDB[k] = Copy(s.db[k]) end
  if TibiSuite.SetAccentMode then pcall(TibiSuite.SetAccentMode, s.db.accentMode == "class" and "class" or "suite") end
  if TibiSuite.SetMinimapHidden then pcall(TibiSuite.SetMinimapHidden, s.db.mmHidden and true or false) end
  if TibiSuite.ApplyBarSettings then pcall(TibiSuite.ApplyBarSettings, {}) end
  if TibiSuite.SetStreaming and (s.db.streaming == true) ~= (wasStream and true or false) then
    pcall(TibiSuite.SetStreaming, s.db.streaming == true)
  end
  if TibiSuite.ApplyWidgets then pcall(TibiSuite.ApplyWidgets) end
  if TibiSuite.ApplyAutoBar then pcall(TibiSuite.ApplyAutoBar) end
  if TibiSuite.ApplyReadability then pcall(TibiSuite.ApplyReadability, true) end
  for key, on in pairs(s.mods or {}) do
    if TibiSuite.IsModuleEnabled(key) ~= on then pcall(TibiSuite.SetModuleEnabled, key, on) end
  end
  if TibiSuite.RefreshCentreBar then pcall(TibiSuite.RefreshCentreBar) end
  if TibiSuite.RefreshStatus then TibiSuite.RefreshStatus() end
  if noAsk then return TibiSuite.NeedsReload and TibiSuite.NeedsReload() end
  return AskReload()
end

-- ================================================================
-- 1. ANNULER
-- ================================================================
local undo = {}
local MAX_UNDO = 30
local undoListeners = {}
function TibiSuite.OnUndoChanged(fn) if type(fn) == "function" then undoListeners[#undoListeners + 1] = fn end end
local function UndoChanged() for _, fn in ipairs(undoListeners) do pcall(fn) end end

if UI then
  UI.RecordUndo = function(panel, item, snapFn)
    local top = undo[#undo]
    -- Curseur tire en continu : une seule entree.
    if top and top.item == item and item.kind == "slider" and (GetTime() - top.t) < 2 then
      top.t = GetTime()
      return
    end
    undo[#undo + 1] = { panel = panel, item = item, label = item.label, snap = snapFn(), t = GetTime() }
    if #undo > MAX_UNDO then table.remove(undo, 1) end
    UndoChanged()
  end
end

local function Plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")) end

function TibiSuite.CanUndo() return #undo > 0 end
function TibiSuite.GetUndoLabel() local e = undo[#undo]; return e and Plain(e.label) or nil end

function TibiSuite.Undo()
  local e = table.remove(undo)
  if not e then
    if TibiSuite.ShowToast then TibiSuite.ShowToast(L.UNDO_NONE) end
    return false
  end
  pcall(e.panel.ApplySnapshot, e.panel, e.snap)
  UndoChanged()
  if TibiSuite.ShowToast then TibiSuite.ShowToast(string.format(L.UNDO_DONE_FMT, Plain(e.label))) end
  return true
end

-- ================================================================
-- 2. POINTS DE RESTAURATION
-- ================================================================
local MAX_POINTS = 8
local rpListeners = {}
function TibiSuite.OnRestorePointsChanged(fn) if type(fn) == "function" then rpListeners[#rpListeners + 1] = fn end end
local function RPChanged() for _, fn in ipairs(rpListeners) do pcall(fn) end end

function TibiSuite.GetRestorePoints()
  TibiSuiteDB.restorePoints = TibiSuiteDB.restorePoints or {}
  return TibiSuiteDB.restorePoints
end

-- why : texte affiche ; auto = vrai pour les points automatiques.
-- Renvoie false si rien n'a change depuis le dernier point.
function TibiSuite.CreateRestorePoint(why, auto)
  local list = TibiSuite.GetRestorePoints()
  local s = TibiSuite.CaptureSettings()
  local last = list[#list]
  if last and Same(last.s, s) then return false end
  list[#list + 1] = { t = time(), why = why or L.RP_MANUAL, auto = auto and true or nil, s = s }
  while #list > MAX_POINTS do
    local idx = 1
    for i, p in ipairs(list) do if p.auto then idx = i; break end end
    table.remove(list, idx)
  end
  RPChanged()
  return true
end

function TibiSuite.RestorePoint(i)
  local list = TibiSuite.GetRestorePoints()
  local p = list[i]
  if not p then return end
  TibiSuite.CreateRestorePoint(L.RP_BEFORE_RESTORE, true)
  TibiSuite.ApplySettings(p.s)
  if TibiSuite.ShowToast then TibiSuite.ShowToast(L.RP_RESTORED) end
  RPChanged()
end

function TibiSuite.DeleteRestorePoint(i)
  local list = TibiSuite.GetRestorePoints()
  if list[i] then table.remove(list, i); RPChanged() end
end

-- Un profil TS1 importe : point de restauration juste avant.
if TibiSuite.ApplyProfile then
  local orig = TibiSuite.ApplyProfile
  TibiSuite.ApplyProfile = function(prof, skipModules)
    if TibiSuiteDB and TibiSuiteDB.setupDone then TibiSuite.CreateRestorePoint(L.RP_BEFORE_PROF, true) end
    return orig(prof, skipModules)
  end
end

-- ================================================================
-- 3. LISIBILITE
-- ================================================================
local KIT_BASE, HX_BASE
local function KitTint(contrast, cvd)
  local K = TibiSuite._kit
  if not K then return end
  if not KIT_BASE then
    KIT_BASE, HX_BASE = {}, {}
    for _, k in ipairs({ "TXT", "MUT", "DIM", "OK", "WARN" }) do
      local c = K.COL[k]; KIT_BASE[k] = { c[1], c[2], c[3] }; HX_BASE[k] = K.HX[k]
    end
  end
  local function set(k, r, g, b)
    local c = K.COL[k]; c[1], c[2], c[3] = r, g, b
    K.HX[k] = string.format("|cFF%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
  end
  for k, c in pairs(KIT_BASE) do set(k, c[1], c[2], c[3]) end
  if contrast then
    set("TXT", 1, 1, 1); set("MUT", 0.820, 0.815, 0.840); set("DIM", 0.640, 0.635, 0.680)
  end
  if cvd then
    set("OK", 0.337, 0.706, 0.914); set("WARN", 0.941, 0.894, 0.259)
  end
end

function TibiSuite.GetUIScale()
  local v = tonumber(TibiSuiteDB and TibiSuiteDB.uiScale) or 100
  return math.max(0.9, math.min(1.3, v / 100))
end

-- Fenetres de la suite qui suivent la taille choisie (si elles existent).
local SCALED = { "TibiSuiteCentre", "TibiSuitePalette", "TibiSuiteSetupWizard", "TibiSuiteWhatsNew",
  "TibiSuiteProfileFrame", "TibiSuiteConfirmFrame", "TibiSuiteURLFrame", "TibiSuiteAdvisor" }
function TibiSuite.ApplyUIScaleTo(f) if f and f.SetScale then f:SetScale(TibiSuite.GetUIScale()) end end

-- Fenetres creees a la demande : la taille est reappliquee a l'ouverture.
for fn, name in pairs({ RunSetup = "TibiSuiteSetupWizard", ShowWhatsNew = "TibiSuiteWhatsNew",
  OpenProfileWindow = "TibiSuiteProfileFrame", ShowConfirm = "TibiSuiteConfirmFrame", ShowURL = "TibiSuiteURLFrame" }) do
  local orig = TibiSuite[fn]
  if type(orig) == "function" then
    TibiSuite[fn] = function(...)
      local r1, r2 = orig(...)
      TibiSuite.ApplyUIScaleTo(_G[name])
      return r1, r2
    end
  end
end

-- fromSnapshot : appele par ApplySettings (pas de message).
function TibiSuite.ApplyReadability(fromSnapshot)
  local contrast, cvd = TibiSuiteDB.highContrast == true, TibiSuiteDB.cvd == true
  local U = _G.TibiMidnight
  if U and U.ApplyReadability then pcall(U.ApplyReadability, { contrast = contrast, cvd = cvd }) end
  KitTint(contrast, cvd)
  for _, name in ipairs(SCALED) do TibiSuite.ApplyUIScaleTo(_G[name]) end
  if TibiSuite.ApplyWidgets then pcall(TibiSuite.ApplyWidgets) end
end

-- ================================================================
-- 4. PROFILS AUTOMATIQUES
-- ================================================================
local setupListeners = {}
function TibiSuite.OnSetupsChanged(fn) if type(fn) == "function" then setupListeners[#setupListeners + 1] = fn end end
local function SetupsChanged() for _, fn in ipairs(setupListeners) do pcall(fn) end end

local function Setups()
  TibiSuiteDB.setups = TibiSuiteDB.setups or {}
  return TibiSuiteDB.setups
end
local function Rules()
  TibiSuiteDB.setupRules = TibiSuiteDB.setupRules or { char = {}, spec = {} }
  local r = TibiSuiteDB.setupRules
  r.char, r.spec = r.char or {}, r.spec or {}
  return r
end

function TibiSuite.GetSetupNames()
  local out = {}
  for name in pairs(Setups()) do out[#out + 1] = name end
  table.sort(out)
  return out
end

function TibiSuite.GetActiveSetup() return TibiSuiteDB.activeSetup end

function TibiSuite.SaveSetup(name)
  name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then
    local n = 1
    while Setups()[string.format(L.SETUP_DEFAULT_FMT, n)] do n = n + 1 end
    name = string.format(L.SETUP_DEFAULT_FMT, n)
  end
  name = name:sub(1, 32)
  Setups()[name] = { t = time(), s = TibiSuite.CaptureSettings() }
  TibiSuiteDB.activeSetup = name
  SetupsChanged()
  if TibiSuite.ShowToast then TibiSuite.ShowToast(string.format(L.SETUP_SAVED_FMT, name)) end
  return name
end

function TibiSuite.DeleteSetup(name)
  Setups()[name] = nil
  if TibiSuiteDB.activeSetup == name then TibiSuiteDB.activeSetup = nil end
  local r = Rules()
  for k, v in pairs(r.char) do if v == name then r.char[k] = nil end end
  for k, v in pairs(r.spec) do if v == name then r.spec[k] = nil end end
  if r.leveling == name then r.leveling = nil end
  SetupsChanged()
end

-- Passe au profil `name` : memorise d'abord le profil actif, puis applique.
function TibiSuite.ApplySetup(name, silent)
  local st = Setups()[name]
  if not st then return false end
  local cur = TibiSuiteDB.activeSetup
  if cur and cur ~= name and Setups()[cur] then
    Setups()[cur].s = TibiSuite.CaptureSettings()
    Setups()[cur].t = time()
  end
  TibiSuite.CreateRestorePoint(string.format(L.RP_BEFORE_SETUP_FMT, name), true)
  TibiSuiteDB.activeSetup = name
  TibiSuite.ApplySettings(st.s)
  SetupsChanged()
  if TibiSuite.Notify and not silent then
    TibiSuite.Notify("Suite", string.format(L.SETUP_APPLIED_FMT, name), { sound = false })
  end
  return true
end

local function CharKey()
  local n, r
  if UnitFullName then n, r = UnitFullName("player") end
  n = n or (UnitName and UnitName("player")) or "?"
  r = r or (GetRealmName and GetRealmName()) or ""
  return n .. "-" .. tostring(r):gsub("[%s%-']", "")
end
local function SpecKey()
  local idx = GetSpecialization and GetSpecialization()
  local id = idx and GetSpecializationInfo and GetSpecializationInfo(idx)
  return id and (CharKey() .. ":" .. id) or nil, id
end
TibiSuite._CharKey, TibiSuite._SpecKey = CharKey, SpecKey

local function IsLeveling()
  local lvl = UnitLevel and UnitLevel("player") or 0
  local max = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion())
    or (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 80
  return lvl > 0 and lvl < max
end
TibiSuite._IsLeveling = IsLeveling

function TibiSuite.GetSetupRule(kind)
  local r = Rules()
  if kind == "char" then return r.char[CharKey()]
  elseif kind == "spec" then local k = SpecKey(); return k and r.spec[k] or nil
  elseif kind == "leveling" then return r.leveling end
end

function TibiSuite.SetSetupRule(kind, name)
  local r = Rules()
  if name and not Setups()[name] then name = nil end
  if kind == "char" then r.char[CharKey()] = name
  elseif kind == "spec" then local k = SpecKey(); if k then r.spec[k] = name end
  elseif kind == "leveling" then r.leveling = name end
  SetupsChanged()
end

-- Profil voulu pour ce personnage maintenant : spe > perso > montee de niveau.
function TibiSuite.ResolveSetup()
  local r = Rules()
  local sk = SpecKey()
  local name = (sk and r.spec[sk]) or r.char[CharKey()] or (IsLeveling() and r.leveling) or nil
  if name and Setups()[name] then return name end
  return nil
end

local function CheckAutoSetup()
  if not TibiSuiteDB or not TibiSuiteDB.setupDone then return end
  local want = TibiSuite.ResolveSetup()
  if want and want ~= TibiSuiteDB.activeSetup then TibiSuite.ApplySetup(want) end
end
TibiSuite.CheckAutoSetup = CheckAutoSetup

-- ================================================================
-- 5. RAPPELS
-- ================================================================
-- Defauts : hebdo actif (3 h avant, s'il reste des choses), quotidien
-- coupe, calendrier actif, note par personnage si elle existe.
function TibiSuite.RemindOn(k)
  if k == "daily" then return TibiSuiteDB.remindDaily == true end
  if k == "weekly" then return TibiSuiteDB.remindWeekly ~= false end
  if k == "cal" then return TibiSuiteDB.remindCal ~= false end
  if k == "note" then return TibiSuiteDB.remindNote ~= false end
end

local function ResetIn(kind)
  local f = C_DateAndTime and (kind == "week" and C_DateAndTime.GetSecondsUntilWeeklyReset
    or C_DateAndTime.GetSecondsUntilDailyReset)
  if f then
    local ok, s = pcall(f)
    if ok and tonumber(s) then return tonumber(s) end
  end
end

local function Fired(key)
  TibiSuiteCharDB.remindFired = TibiSuiteCharDB.remindFired or {}
  local t = TibiSuiteCharDB.remindFired
  if t[key] then return true end
  t[key] = time()
  -- Menage : plus de 8 jours.
  for k, v in pairs(t) do if time() - v > 8 * 86400 then t[k] = nil end end
  return false
end

-- Modules du groupe « A faire » pas termines.
local function TodoLeft()
  local n = 0
  local g = TibiSuite.PANEL_GROUPS and TibiSuite.PANEL_GROUPS[1]
  for _, key in ipairs(g and g.keys or {}) do
    local st = TibiSuite.GetModuleStatus and TibiSuite.GetModuleStatus(key)
    if st and (st.urgent or (tonumber(st.progress) and tonumber(st.progress) < 1)) then n = n + 1 end
  end
  return n
end

local function CheckResets()
  if not TibiSuite.Notify then return end
  local now = time()
  if TibiSuite.RemindOn("daily") then
    local s = ResetIn("day")
    local lead = (tonumber(TibiSuiteDB.remindDailyMin) or 60) * 60
    if s and s <= lead and s > 30 then
      local stamp = math.floor((now + s) / 600)
      if not Fired("d" .. stamp) then
        TibiSuite.Notify("Suite", string.format(L.REM_DAILY_FMT, TibiSuite.FmtDuration(s)), { sound = false })
      end
    end
  end
  if TibiSuite.RemindOn("weekly") then
    local s = ResetIn("week")
    local lead = (tonumber(TibiSuiteDB.remindWeeklyH) or 3) * 3600
    if s and s <= lead and s > 30 then
      local stamp = math.floor((now + s) / 600)
      local left = TodoLeft()
      if not Fired("w" .. stamp) then
        local txt = left > 0 and string.format(L.REM_WEEKLY_LEFT_FMT, TibiSuite.FmtDuration(s), left)
          or string.format(L.REM_WEEKLY_FMT, TibiSuite.FmtDuration(s))
        TibiSuite.Notify("Suite", txt, { urgent = left > 0 })
      end
    end
  end
end

-- Calendrier : evenements du jour qui commencent dans les 15 minutes.
-- Lecture seule (C_Calendar), sous pcall : rien n'est envoye au serveur
-- sauf la demande d'ouverture habituelle du calendrier.
local calOpened = false
local CAL_SKIP = { HOLIDAY = true, RAID_LOCKOUT = true, RAID_RESET = true, SYSTEM = true }
local function CheckCalendar()
  if not TibiSuite.RemindOn("cal") or not (C_Calendar and C_Calendar.GetNumDayEvents and C_DateAndTime) then return end
  if not calOpened and C_Calendar.OpenCalendar then calOpened = true; pcall(C_Calendar.OpenCalendar) end
  local ok, today = pcall(C_DateAndTime.GetCurrentCalendarTime)
  if not ok or type(today) ~= "table" then return end
  local okN, n = pcall(C_Calendar.GetNumDayEvents, 0, today.monthDay)
  if not okN or not n then return end
  local nowMin = (today.hour or 0) * 60 + (today.minute or 0)
  for i = 1, n do
    local okE, ev = pcall(C_Calendar.GetDayEvent, 0, today.monthDay, i)
    if okE and type(ev) == "table" and ev.title and not CAL_SKIP[ev.calendarType or ""] and ev.startTime then
      local st = (ev.startTime.hour or 0) * 60 + (ev.startTime.minute or 0)
      local delta = st - nowMin
      if delta >= 0 and delta <= 15 then
        local key = "c" .. tostring(ev.eventID or ev.title) .. ":" .. today.monthDay .. ":" .. st
        if not Fired(key) then
          TibiSuite.Notify("Suite", string.format(L.REM_CAL_FMT, ev.title,
            string.format("%02d:%02d", ev.startTime.hour or 0, ev.startTime.minute or 0)), { urgent = true })
        end
      end
    end
  end
end

function TibiSuite.GetCharNote() return TibiSuiteCharDB and TibiSuiteCharDB.note or "" end
function TibiSuite.SetCharNote(txt)
  txt = tostring(txt or ""):gsub("^%s+", ""):gsub("%s+$", "")
  TibiSuiteCharDB.note = (txt ~= "") and txt:sub(1, 200) or nil
end

-- ================================================================
-- EVENEMENTS
-- ================================================================
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
pcall(ev.RegisterEvent, ev, "PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_LOGIN" then
    TibiSuite.ApplyReadability(true)
    -- Les modules s'inscrivent pendant le chargement : un instant plus tard.
    C_Timer.After(3, function()
      if TibiSuiteDB.setupDone then TibiSuite.CreateRestorePoint(L.RP_LOGIN, true) end
      CheckAutoSetup()
    end)
    C_Timer.After(8, function()
      local note = TibiSuite.GetCharNote()
      if note ~= "" and TibiSuite.RemindOn("note") and TibiSuite.Notify then
        TibiSuite.Notify("Suite", string.format(L.REM_NOTE_FMT, note), { sound = false })
      end
    end)
    C_Timer.After(15, function() CheckResets(); CheckCalendar() end)
    C_Timer.NewTicker(60, function() CheckResets(); CheckCalendar() end)
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    if unit == nil or unit == "player" then C_Timer.After(1, CheckAutoSetup) end
  elseif event == "PLAYER_LEVEL_UP" then
    C_Timer.After(1, CheckAutoSetup)
  end
end)

-- Pour les tests et le Diagnostic.
TibiSuite._CheckResets, TibiSuite._CheckCalendar = CheckResets, CheckCalendar

-- ================================================================
-- 7. OBJECTIFS PERSONNELS DE LA SEMAINE (7.1.5.45, feuille de route lot 3)
-- ----------------------------------------------------------------
-- TibiSuiteDB.goals = { { id, text, kind, target, item, itemName, module,
--   weekly (bool), created, done, doneWeek, notified } }
-- kind : "manual" (a cocher), "gather" (recolter N d'un objet, SkillTracker),
--        "gold" (gagner N po cette semaine, Stats, tout le compte),
--        "module" (finir la ligne d'etat d'un module : progression 100 %).
-- weekly = vrai : remis a zero a chaque reset hebdo (identifiant de semaine
-- = heure du prochain reset). Objectif atteint => une ligne dans le fil.
-- ================================================================
D("GOAL_DONE_FMT",  "Objectif atteint : %s")
D("GOAL_DONE",      "Fait")
D("GOAL_TODO",      "À faire")

local function WeekId()
  local s = ResetIn("week")
  return s and math.floor((time() + s) / 3600) or 0
end
TibiSuite.GoalWeekId = WeekId

local function WeekStart()
  local s = ResetIn("week")
  return s and (time() + s - 7 * 86400) or (time() - 7 * 86400)
end

local goalListeners = {}
function TibiSuite.OnGoalsChanged(fn) if type(fn) == "function" then goalListeners[#goalListeners + 1] = fn end end
local function GoalsChanged() for _, fn in ipairs(goalListeners) do pcall(fn) end end

function TibiSuite.GetGoals()
  TibiSuiteDB.goals = TibiSuiteDB.goals or {}
  return TibiSuiteDB.goals
end

-- Etat d'un objectif : cur, target, done, texte de valeur.
function TibiSuite.GoalProgress(g)
  local wk = WeekId()
  if g.kind == "manual" then
    local done = g.weekly and (g.doneWeek == wk) or (not g.weekly and g.done == true)
    return done and 1 or 0, 1, done, done and L.GOAL_DONE or L.GOAL_TODO
  elseif g.kind == "gather" then
    local since = g.weekly and WeekStart() or (g.created or 0)
    local cur = (_G.SkillTracker_GatheredSince and SkillTracker_GatheredSince(since, g.item)) or 0
    local t = math.max(1, tonumber(g.target) or 1)
    return math.min(cur, t), t, cur >= t, cur .. " / " .. t
  elseif g.kind == "gold" then
    local net = (_G.Stats_WeeklyNet and Stats_WeeklyNet()) or 0
    local cur = math.max(0, math.floor(net / 10000))
    local t = math.max(1, tonumber(g.target) or 1)
    local fmt = function(v) return (BreakUpLargeNumbers and BreakUpLargeNumbers(v)) or tostring(v) end
    local shown = (TibiSuite.IsStreaming and TibiSuite.IsStreaming()) and "***" or fmt(cur)
    return math.min(cur, t), t, cur >= t, shown .. " / " .. fmt(t) .. " po"
  elseif g.kind == "module" then
    local st = g.module and TibiSuite.GetModuleStatus and TibiSuite.GetModuleStatus(g.module)
    local p = st and tonumber(st.progress) or 0
    return p, 1, p >= 1, st and st.text or "-"
  end
  return 0, 1, false, "-"
end

function TibiSuite.AddGoal(spec)
  if type(spec) ~= "table" then return end
  local text = tostring(spec.text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return end
  local list = TibiSuite.GetGoals()
  local id = (TibiSuiteDB.goalSeq or 0) + 1
  TibiSuiteDB.goalSeq = id
  list[#list + 1] = { id = id, text = text:sub(1, 60), kind = spec.kind or "manual", target = tonumber(spec.target),
    item = tonumber(spec.item), itemName = spec.itemName, module = spec.module,
    weekly = spec.weekly ~= false, created = time() }
  GoalsChanged()
  return id
end

local function FindGoal(id)
  for i, g in ipairs(TibiSuite.GetGoals()) do if g.id == id then return g, i end end
end

function TibiSuite.RemoveGoal(id)
  local _, i = FindGoal(id)
  if i then table.remove(TibiSuite.GetGoals(), i); GoalsChanged() end
end

-- Objectif a cocher : bascule fait / a faire.
function TibiSuite.ToggleGoal(id)
  local g = FindGoal(id)
  if not g or g.kind ~= "manual" then return end
  if g.weekly then g.doneWeek = (g.doneWeek == WeekId()) and nil or WeekId()
  else g.done = not g.done end
  GoalsChanged()
  if TibiSuite.CheckGoals then TibiSuite.CheckGoals() end
end

-- Objectifs atteints depuis le dernier passage : une ligne dans le fil.
function TibiSuite.CheckGoals()
  local wk = WeekId()
  for _, g in ipairs(TibiSuite.GetGoals()) do
    local _, _, done = TibiSuite.GoalProgress(g)
    local stamp = g.weekly and wk or 1
    if done and g.notified ~= stamp then
      g.notified = stamp
      if TibiSuite.Notify then TibiSuite.Notify("Suite", string.format(L.GOAL_DONE_FMT, g.text), { sound = true }) end
    elseif not done and g.notified == stamp and g.kind == "manual" then
      g.notified = nil
    end
  end
end

if TibiSuite.OnStatusChanged then TibiSuite.OnStatusChanged(function() pcall(TibiSuite.CheckGoals) end) end

-- ================================================================
-- 6. MA SEMAINE ET FIL D'ACTIVITE HORS JEU (lot 7)
-- ----------------------------------------------------------------
-- Une photo des lignes d'etat est gardee PAR PERSONNAGE dans
-- TibiSuiteDB.weekSnap[cle] (cle = "nom-royaume" en minuscules, royaume sans
-- espace, tiret ni apostrophe : meme rapprochement que les absences de
-- Standby dans Stats). Elle est rafraichie a chaque changement d'etat
-- (regroupe a 5 s) et a la deconnexion. Stats l'ajoute a son code d'export
-- (chars[k].week + data.suite) pour le Dashboard du site et Tibi Companion.
-- Le mode streaming ne masque jamais ces donnees (elles restent au joueur).
-- Format (court, le code d'export est compresse mais lu sur le site) :
--   weekSnap[cle] = { at, l = { {k, x, p, u, g} }, nx = {k, x, u} }
--   ExportSuite() = { v = 1, at, mods = { [k] = {n, c} }, reset = {d, w},
--                     feed = { {t, k, x, u, c} } (60 derniers), chars = weekSnap }
-- ================================================================
local function SnapKey(name, realm)
  if not name or name == "" then return nil end
  return (name .. "-" .. tostring(realm or ""):gsub("[%s%-']", "")):lower()
end
TibiSuite.SnapKey = SnapKey

-- Texte sans codes de couleur, d'icone ni d'atlas WoW.
local function Bare(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
  return s
end

local function TakeWeekSnap()
  if not (TibiSuiteDB and TibiSuite.GetModuleStatus and TibiSuite.PANEL_GROUPS) then return end
  local name, realm
  if UnitFullName then name, realm = UnitFullName("player") end
  if not realm or realm == "" then realm = GetRealmName and GetRealmName() end
  local key = SnapKey(name or (UnitName and UnitName("player")), realm)
  if not key then return end
  TibiSuite._noMask = true
  local list = {}
  for gi, g in ipairs(TibiSuite.PANEL_GROUPS) do
    if not g.icons then
      for _, k in ipairs(g.keys) do
        local ok, st = pcall(TibiSuite.GetModuleStatus, k)
        if ok and type(st) == "table" then
          list[#list + 1] = { k = k, x = Bare(st.text), g = gi,
            p = tonumber(st.progress) and math.floor(tonumber(st.progress) * 100 + 0.5) / 100 or nil,
            u = st.urgent and true or nil }
        end
      end
    end
  end
  local nx
  if TibiSuite.GetNextAction then
    local ok, na = pcall(TibiSuite.GetNextAction)
    if ok and na then nx = { k = na.key, x = Bare(na.text), u = na.urgent or nil } end
  end
  TibiSuite._noMask = nil
  TibiSuiteDB.weekSnap = TibiSuiteDB.weekSnap or {}
  -- Aucun module ne donne d'etat (tous coupes) : on garde la photo precedente.
  if #list == 0 and TibiSuiteDB.weekSnap[key] then return end
  TibiSuiteDB.weekSnap[key] = { at = time(), l = list, nx = nx }
  -- Menage : personnages pas vus depuis 60 jours.
  for k, v in pairs(TibiSuiteDB.weekSnap) do
    if type(v) ~= "table" or time() - (tonumber(v.at) or 0) > 60 * 86400 then TibiSuiteDB.weekSnap[k] = nil end
  end
end
TibiSuite.TakeWeekSnap = TakeWeekSnap

local snapPending = false
if TibiSuite.OnStatusChanged then
  TibiSuite.OnStatusChanged(function()
    if snapPending then return end
    snapPending = true
    C_Timer.After(5, function() snapPending = false; pcall(TakeWeekSnap) end)
  end)
end

local function Hex6(c)
  if type(c) ~= "table" then return nil end
  local r, g, b = c.r or c[1] or 0.6, c.g or c[2] or 0.6, c.b or c[3] or 0.6
  return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- Lu par Stats (Export.lua) au moment de generer le code. Photo du
-- personnage connecte prise a l'instant, puis tout le compte.
function TibiSuite.ExportSuite()
  pcall(TakeWeekSnap)
  local mods = {}
  for _, m in ipairs(TibiSuite.GetCatalog()) do mods[m.key] = { n = m.addonName, c = Hex6(m.col) } end
  local now = time()
  local d, w = ResetIn("day"), ResetIn("week")
  local feed = {}
  local src = TibiSuiteDB.feed or {}
  for i = math.max(1, #src - 59), #src do
    local e = src[i]
    if type(e) == "table" and e.x then
      feed[#feed + 1] = { t = e.t, k = e.k, x = Bare(e.x), u = e.u and true or nil, c = e.c }
    end
  end
  local goals = {}
  for _, g in ipairs(TibiSuiteDB.goals or {}) do
    local okG, cur, t, done, val = pcall(TibiSuite.GoalProgress, g)
    if okG then
      goals[#goals + 1] = { x = Bare(g.text), v = Bare(val), p = t > 0 and math.floor(cur / t * 100 + 0.5) / 100 or 0,
        d = done and true or nil, w = g.weekly and true or nil, k = g.kind }
    end
  end
  return {
    v = 1, at = now, mods = mods,
    reset = { d = d and (now + d) or nil, w = w and (now + w) or nil },
    feed = feed, goals = goals,
    chars = TibiSuiteDB.weekSnap or {},
  }
end

local evOut = CreateFrame("Frame")
evOut:RegisterEvent("PLAYER_LOGOUT")
evOut:SetScript("OnEvent", function() pcall(TakeWeekSnap) end)

-- ================================================================
-- 8. EVENEMENT DE LA SEMAINE (7.1.5.45, feuille de route lot 4)
-- ----------------------------------------------------------------
-- Fetes et evenements bonus du jour lus dans le calendrier (type HOLIDAY),
-- avec leur date de fin. Lecture seule, memoire d'une minute.
-- TibiSuite.GetWeekEvents() -> { { title, endsAt } } (2 au plus, fin la
-- plus proche d'abord).
-- ================================================================
local function Secret(v) return issecretvalue and issecretvalue(v) or false end
local evCache, evAt = nil, 0
local function CalTime(t)
  if type(t) ~= "table" or not t.year then return nil end
  return time({ year = t.year, month = t.month, day = t.monthDay, hour = t.hour or 0, min = t.minute or 0 })
end
function TibiSuite.GetWeekEvents()
  if evCache and GetTime() - evAt < 60 then return evCache end
  local out = {}
  if C_Calendar and C_Calendar.GetNumDayEvents and C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
    if C_Calendar.OpenCalendar and not TibiSuite._calOpened then TibiSuite._calOpened = true; pcall(C_Calendar.OpenCalendar) end
    local ok, today = pcall(C_DateAndTime.GetCurrentCalendarTime)
    if ok and type(today) == "table" then
      local okN, n = pcall(C_Calendar.GetNumDayEvents, 0, today.monthDay)
      local seen = {}
      for i = 1, (okN and n or 0) do
        local okE, ev = pcall(C_Calendar.GetDayEvent, 0, today.monthDay, i)
        if okE and type(ev) == "table" and ev.calendarType == "HOLIDAY" and type(ev.title) == "string"
          and not Secret(ev.title) and not seen[ev.title] then
          seen[ev.title] = true
          out[#out + 1] = { title = ev.title, endsAt = CalTime(ev.endTime) }
        end
      end
    end
  end
  table.sort(out, function(a, b) return (a.endsAt or math.huge) < (b.endsAt or math.huge) end)
  while #out > 2 do table.remove(out) end
  evCache, evAt = out, GetTime()
  return out
end

-- ================================================================
-- CONSEILLER (lot 1, _dev/Conseiller.md)
-- ----------------------------------------------------------------
-- Contrat facultatif de RegisterModule :
--   suggestFn() -> liste, pending
--     liste = { { id, kind, text, tag, proximity (0..1), done, total,
--                 endsAt, group, note, icon, weight, why (raison du
--                 module, remplace l'avancement), open (fonction) ou
--                 target (openTo) } }
--     pending = true si le module calcule encore (parcours en cours).
-- Le core note chaque suggestion :
--   100 * proximite^1.5 * (0.4 + affinite) * fenetre * poids * groupe
-- affinite = Stats_Affinity (habitudes des 28 derniers jours, 0..1 par
-- tag), 0.5 sans Stats ou si le joueur coupe « mes habitudes ».
-- Reglages (SET_KEYS) : sugOn (nil = actif), sugHabits (nil = actif),
-- sugNoGroup (nil = non), sugKinds[kind] = false pour couper un type.
-- Donnees : TibiSuiteDB.sugDismissed[id] = heure de fin (pas un reglage).
-- ================================================================
D("SUG_TITLE",        "Suggestions")
D("SUG_NONE",         "Aucune suggestion pour l'instant.")
D("SUG_PENDING",      "Analyse des hauts faits en cours, réessaie dans quelques secondes.")
D("SUG_OFF",          "Le Conseiller est désactivé.")
D("SUG_R_ENDS_FMT",   "Se termine dans %s.")
D("SUG_R_HABIT_FMT",  "Tu as fait %d %s ces 4 dernières semaines.")
D("SUG_R_NEAR_FMT",   "Presque fini : %d sur %d.")
D("SUG_R_PCT_FMT",    "Déjà %d %% fait.")
D("SUG_R_NEARPCT_FMT","Presque fini : %d %%.")
D("SUG_R_NEARLEFT_FMT","Presque fini : plus que %d.")
D("SUG_R_LEFT_FMT",   "Plus que %d.")
D("SUG_RESTORED",     "Suggestions écartées remises en jeu.")
D("SUG_NOTE_META_FMT","Fait partie de : %s")
D("SUG_MENU_OPEN",    "Y aller")
D("SUG_MENU_LATER",   "Plus tard (7 jours)")
D("SUG_MENU_NEVER",   "Pas intéressé")
D("SUG_MENU_PAGE",    "Toutes les suggestions")
D("SUG_STATE_FMT",    "analyse des hauts faits : %d %%")
D("SUG_STATE_COMBAT", "(en pause pendant le combat)")
D("SUG_STATE_ERR_FMT","Erreur notée pendant l'analyse : %s")
-- Raisons fournies par les modules (lot 3)
D("SUG_C_MOUNT_FMT",  "Monture de %s (%s), pas encore obtenue.")
D("SUG_C_MOUNT_INST_FMT", "Monture de %s, pas encore obtenue.")
D("SUG_C_LOCKED",     "Instance déjà entamée cette semaine.")
D("SUG_D_WB_FMT",     "Boss mondial de la semaine, pas encore vaincu (%s).")
D("SUG_D_RARE_FMT",   "Rare disponible dans %s.")
D("SUG_W_VAULT_FMT",  "%d sur %d pour le prochain emplacement du Grand coffre.")
D("SUG_L_FMT",        "Raid de farm libre cette semaine pour %s (légendaire épinglé).")
D("SUG_U_quest", "Tu fais beaucoup de quêtes : %d en 4 semaines.")
D("SUG_U_world", "Tu fais souvent des quêtes du monde : %d en 4 semaines.")
D("SUG_U_explore", "Tu fais beaucoup de quêtes : %d en 4 semaines.")
D("SUG_U_dungeon", "Tu joues souvent en donjon : %d visites en 4 semaines.")
D("SUG_U_mplus", "Tu fais souvent des clés mythiques : %d en 4 semaines.")
D("SUG_U_raid", "Tu joues souvent en raid : %d visites en 4 semaines.")
D("SUG_U_delve", "Tu fais souvent des gouffres : %d en 4 semaines.")
D("SUG_U_pvp", "Tu joues souvent en JcJ : %d parties en 4 semaines.")
D("SUG_U_prof", "Tu montes souvent tes métiers : %d points en 4 semaines.")

local sugListeners, sugCache, sugAt, sugPending = {}, nil, 0, false
local SUG_TTL = 300

function TibiSuite.SuggestOn() return TibiSuiteDB ~= nil and TibiSuiteDB.sugOn ~= false end
function TibiSuite.OnSuggestionsChanged(fn) if type(fn) == "function" then sugListeners[#sugListeners + 1] = fn end end

local sugFireT
local function FireSuggestions()
  sugFireT = nil
  for _, fn in ipairs(sugListeners) do pcall(fn) end
end

-- Un module dont les donnees ont change le signale ici : la liste sera
-- recalculee au prochain appel, les abonnes sont prevenus (regroupe a 1 s).
function TibiSuite.InvalidateSuggestions()
  sugCache = nil
  if not sugFireT then sugFireT = C_Timer.NewTimer(1, FireSuggestions) end
end

-- Habitudes : { aff = { tag = 0..1 }, counts = { tag = n }, days = 28 },
-- lues chez Stats, gardees 10 min.
local affCache, affAt = nil, 0
function TibiSuite.GetAffinity()
  if TibiSuiteDB and TibiSuiteDB.sugHabits == false then return nil end
  if affCache and GetTime() - affAt < 600 then return affCache end
  local fn = _G.Stats_Affinity
  if type(fn) ~= "function" then return nil end
  local ok, a = pcall(fn, 28)
  if ok and type(a) == "table" and type(a.aff) == "table" then
    a.counts = a.counts or {}
    affCache = a
  else
    affCache = nil
  end
  affAt = GetTime()
  return affCache
end

local function Dismissed(id)
  local t = TibiSuiteDB and TibiSuiteDB.sugDismissed
  local u = t and t[id]
  if not u then return false end
  if u > time() then return true end
  t[id] = nil
  return false
end

-- Raison affichee : fin proche d'abord ; sinon « presque fini » en tete
-- (80 % et plus) puis l'habitude, ou l'habitude puis l'avancement. Au-dela
-- de 25 elements, l'avancement est en pourcentage (« plus que 1199 » ne
-- parlait pas, vu en jeu).
local function Reason(s, aff)
  local now = time()
  -- 3 derniers jours seulement : tout l'hebdo finit au reset, donc toujours
  -- « dans moins de 7 jours » (mention repetee partout, vu en jeu).
  local soon = s.endsAt and s.endsAt > now and s.endsAt - now < 3 * 86400 and TibiSuite.FmtDuration
  -- Raison donnee par le module (monture, boss mondial, Grand coffre : pas
  -- de « pourcentage fait »), suivie de la fin si elle approche.
  if type(s.why) == "string" and s.why ~= "" then
    if soon then return s.why .. " " .. string.format(L.SUG_R_ENDS_FMT, TibiSuite.FmtDuration(s.endsAt - now)) end
    return s.why
  end
  if soon then
    return string.format(L.SUG_R_ENDS_FMT, TibiSuite.FmtDuration(s.endsAt - now))
  end
  local prox = s.proximity or 0
  local pct = math.floor(prox * 100)
  local near = prox >= 0.8
  local prog
  local left = (s.total and s.done) and (s.total - s.done) or nil
  if left and s.total <= 25 then
    prog = near and string.format(L.SUG_R_NEAR_FMT, s.done, s.total) or string.format(L.SUG_R_LEFT_FMT, left)
  elseif left and left <= 25 then
    -- Gros total mais peu de reste (298 sur 300 montures) : le reste parle mieux.
    prog = near and string.format(L.SUG_R_NEARLEFT_FMT, left) or string.format(L.SUG_R_LEFT_FMT, left)
  else
    prog = near and string.format(L.SUG_R_NEARPCT_FMT, pct) or string.format(L.SUG_R_PCT_FMT, pct)
  end
  local habit
  if aff and s.tag and (aff.aff[s.tag] or 0) >= 0.5 and (aff.counts[s.tag] or 0) > 0 and L["SUG_U_" .. s.tag] then
    -- Phrase complete par type (« Tu joues souvent en raid : 26 visites en 4
    -- semaines. ») : « 26 raids » laissait croire a 26 raids differents.
    habit = string.format(L["SUG_U_" .. s.tag], aff.counts[s.tag])
  end
  if not habit then return prog end
  if near then return prog .. " " .. habit end
  return habit .. " " .. prog
end

local function Score(s, aff)
  local prox = math.max(0, math.min(1, tonumber(s.proximity) or 0))
  local a = 0.5
  if aff and s.tag and aff.aff[s.tag] ~= nil then a = aff.aff[s.tag] end
  local win, now = 1, time()
  if s.endsAt and s.endsAt > now then
    local left = s.endsAt - now
    if left < 86400 then win = 1.6 elseif left < 3 * 86400 then win = 1.3 end
  end
  local grp = (s.group and a < 0.2) and 0.6 or 1
  local w = tonumber(s.weight) or 1
  return 100 * (prox ^ 1.5) * (0.4 + a) * win * grp * w
end

-- Liste notee, du meilleur au moins bon, 2 au plus par tag. n = 5 par
-- defaut. Chaque entree recoit key (module), score, reason.
-- Renvoie liste, pending.
function TibiSuite.GetSuggestions(n, fresh)
  n = n or 5
  if not TibiSuite.SuggestOn() then return {}, false end
  if fresh or not sugCache or GetTime() - sugAt > SUG_TTL then
    local all, pending = {}, false
    local aff = TibiSuite.GetAffinity()
    local kinds = TibiSuiteDB.sugKinds or {}
    local noGroup = TibiSuiteDB.sugNoGroup == true
    for _, mod in ipairs(TibiSuite.GetCatalog()) do
      local reg = TibiSuite.registered and TibiSuite.registered[mod.key]
      if reg and type(reg.suggestFn) == "function" and C_AddOns.IsAddOnLoaded(mod.addonName) then
        local ok, list, pend = pcall(reg.suggestFn)
        if ok and pend then pending = true end
        if ok and type(list) == "table" then
          for _, s in ipairs(list) do
            if type(s) == "table" and s.id and s.text and kinds[s.kind or ""] ~= false
               and not (noGroup and s.group) and not Dismissed(s.id) then
              s.key = mod.key
              s.score = Score(s, aff)
              s.reason = Reason(s, aff)
              if s.score > 0 then all[#all + 1] = s end
            end
          end
        end
      end
    end
    table.sort(all, function(a, b) return a.score > b.score end)
    sugCache, sugAt, sugPending = all, GetTime(), pending
  end
  local out, per = {}, {}
  for _, s in ipairs(sugCache) do
    local t = s.tag or "?"
    if (per[t] or 0) < 2 then
      per[t] = (per[t] or 0) + 1
      out[#out + 1] = s
      if #out >= n then break end
    end
  end
  return out, sugPending
end

-- Ecarter : 90 jours (« pas interesse ») par defaut, 7 pour « plus tard ».
function TibiSuite.DismissSuggestion(id, days)
  if not id then return end
  TibiSuiteDB.sugDismissed = TibiSuiteDB.sugDismissed or {}
  TibiSuiteDB.sugDismissed[id] = time() + (days or 90) * 86400
  TibiSuite.InvalidateSuggestions()
end

function TibiSuite.RestoreSuggestions()
  TibiSuiteDB.sugDismissed = nil
  TibiSuite.InvalidateSuggestions()
end

function TibiSuite.OpenSuggestion(s)
  if type(s) ~= "table" then return end
  if type(s.open) == "function" then pcall(s.open); return end
  if s.key and TibiSuite.OpenModuleTo then TibiSuite.OpenModuleTo(s.key, s.target) end
end

-- Clic droit sur une suggestion (Ma semaine, page Suggestions) : y aller,
-- plus tard (7 jours), pas interesse (90 jours), page des suggestions.
-- Sans MenuUtil : « plus tard » directement. onChange appele apres un ecart.
function TibiSuite.ShowSuggestionMenu(owner, s, onChange)
  if type(s) ~= "table" then return end
  local function dismiss(days)
    TibiSuite.DismissSuggestion(s.id, days)
    TibiSuite.GetSuggestions(5, true)
    if onChange then pcall(onChange) end
  end
  if not (MenuUtil and MenuUtil.CreateContextMenu) then dismiss(7); return end
  pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
    root:CreateTitle(s.text)
    root:CreateButton(L.SUG_MENU_OPEN, function() TibiSuite.OpenSuggestion(s) end)
    root:CreateButton(L.SUG_MENU_LATER, function() dismiss(7) end)
    root:CreateButton(L.SUG_MENU_NEVER, function() dismiss(90) end)
    if TibiSuite.OpenCentre then root:CreateButton(L.SUG_MENU_PAGE, function() TibiSuite.OpenCentre("suggest") end) end
  end)
end

-- /ts conseil [all|reset] : liste dans le chat, en attendant la carte de
-- Ma semaine (lot 4).
function TibiSuite.PrintSuggestions(arg)
  local P = "|cFFC41F3BTibiSuite|r : "
  if arg == "reset" then TibiSuite.RestoreSuggestions(); print(P .. L.SUG_RESTORED); return end
  if arg == "show" or arg == "popup" then
    if TibiSuite.ShowAdvisor then TibiSuite.ShowAdvisor(true) end
    return
  end
  if not TibiSuite.SuggestOn() then print(P .. L.SUG_OFF); return end
  local list, pending = TibiSuite.GetSuggestions(arg == "all" and 15 or 5, true)
  -- Etat du parcours des hauts faits (Stats) : avancement, pause en combat,
  -- derniere erreur notee.
  local st
  if type(_G.Stats_AdvisorState) == "function" then
    local okS, v = pcall(_G.Stats_AdvisorState)
    if okS and type(v) == "table" then st = v end
  end
  local pend = L.SUG_PENDING
  if pending and st and st.running and st.pct then
    pend = string.format(L.SUG_STATE_FMT, st.pct) .. (st.combat and (" " .. L.SUG_STATE_COMBAT) or "")
  end
  local function Err()
    if st and st.err then print(P .. "|cFFFF7777" .. string.format(L.SUG_STATE_ERR_FMT, tostring(st.err)) .. "|r") end
  end
  if #list == 0 then print(P .. (pending and pend or L.SUG_NONE)); Err(); return end
  print(P .. "|cFFFFD700" .. L.SUG_TITLE .. "|r" .. (pending and ("  (" .. pend .. ")") or ""))
  Err()
  for i, s in ipairs(list) do
    print(string.format("  %d. |cFFFFFFFF%s|r  |cFF999999[%s, %d]|r", i, s.text, s.tag or "?", math.floor(s.score + 0.5)))
    print("      |cFFBBBBBB" .. (s.reason or "") .. "|r" .. (s.note and ("  |cFF888888" .. s.note .. "|r") or ""))
  end
end
