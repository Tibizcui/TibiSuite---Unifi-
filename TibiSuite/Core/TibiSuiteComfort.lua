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
  "TibiSuiteProfileFrame", "TibiSuiteConfirmFrame", "TibiSuiteURLFrame" }
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
  local n, r = UnitFullName and UnitFullName("player")
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
  local name, realm = UnitFullName and UnitFullName("player")
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
  return {
    v = 1, at = now, mods = mods,
    reset = { d = d and (now + d) or nil, w = w and (now + w) or nil },
    feed = feed,
    chars = TibiSuiteDB.weekSnap or {},
  }
end

local evOut = CreateFrame("Frame")
evOut:RegisterEvent("PLAYER_LOGOUT")
evOut:SetScript("OnEvent", function() pcall(TakeWeekSnap) end)
