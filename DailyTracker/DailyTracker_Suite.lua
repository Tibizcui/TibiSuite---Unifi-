--[[============================================================================
  DailyTracker - Intégration TibiSuite (options, recherche, habillage)
  ---------------------------------------------------------------------------
    - panneau d'Options flottant du socle (DailyTracker_OpenOptions)
    - bouton texte "Options" + champ de recherche dans l'en-tête de la fenêtre
    - recherche locale + inscription à la recherche globale de TibiSuite
      (un clic sur un résultat ouvre la faction et défile jusqu'à la quête)
    - habillage de la fenêtre à la couleur d'identité de l'addon
  C'est le SEUL fichier qui habille DTMainFrame (DailyTracker_Module.lua ne
  le fait plus : doublon retiré).
============================================================================]]

local ADDON, NS = ...
NS = NS or {}
local L = NS.L or setmetatable({}, {__index=function(_, k) return k end})

local FRAME    = "DTMainFrame"
local ACCENT   = { 0.086, 0.769, 0.988 }   -- cyan (logo #16C4FC)
local LOGO     = "Interface\\AddOns\\DailyTracker\\medias\\DailyTracker"
local KEY      = "Daily"

local function GetUI() return _G.TibiMidnight end
local function DB() return _G.DailyTrackerDB or {} end
local function Refresh() if NS.RefreshAll then NS.RefreshAll() end end

-- ---------------------------------------------------------------- Options
local panel
local function BuildOptions()
  local ui = GetUI(); if not ui then return nil end
  if panel then return panel end
  panel = ui.CreateOptionsPanel({
    name = "DailyTrackerOptionsMidnight",
    title = L.OPT_TITLE, accent = ACCENT })

  panel:Section(L.OPT_WINDOW)
  panel:Button(L.OPT_TOGGLE, function()
    if _G.DailyTracker_Toggle then _G.DailyTracker_Toggle() end
  end)
  panel:Button(L.OPT_RECENTER, function()
    local f = _G[FRAME]; if f then f:ClearAllPoints(); f:SetPoint("CENTER") end
  end)
  panel:Button(L.OPT_ALTS_OPEN, function()
    local db = _G.DailyTrackerDB; if not db then return end
    db.view = "alts"
    local f = _G[FRAME]
    if f then f:Show(); db.open = true; if f.RefreshContent then f:RefreshContent() end end
  end)

  panel:Section(L.OPT_DISPLAY)
  panel:Check(L.OPT_HIDEDONE,
    function() return DB().hideCompleted end,
    function(v) if _G.DailyTrackerDB then _G.DailyTrackerDB.hideCompleted = v end; Refresh() end)
  panel:Check(L.OPT_RENOWN,
    function() return DB().showRenown ~= false end,
    function(v) if _G.DailyTrackerDB then _G.DailyTrackerDB.showRenown = v end; Refresh() end)
  panel:Check(L.OPT_WQ,
    function() return DB().showWQ ~= false end,
    function(v) if _G.DailyTrackerDB then _G.DailyTrackerDB.showWQ = v end; Refresh() end,
    L.WQ_HINT)

  panel:Section(L.OPT_TODO)
  panel:Check(L.OPT_TODO_SHOW,
    function() return DB().todo and DB().todo.shown end,
    function(v) if NS.SetTodoShown then NS.SetTodoShown(v) end end)
  panel:Check(L.OPT_TODO_DAILY,
    function() return DB().todo and DB().todo.daily end,
    function(v)
      local db = _G.DailyTrackerDB; if not db then return end
      db.todo = db.todo or {}; db.todo.daily = v; Refresh()
    end)
  panel:Check(L.OPT_TODO_LOCK,
    function() return DB().todo and DB().todo.locked end,
    function(v)
      local db = _G.DailyTrackerDB; if not db then return end
      db.todo = db.todo or {}; db.todo.locked = v
    end)

  panel:Section(L.OPT_REMIND_SECTION)
  panel:Slider(L.OPT_REMIND, 0, 48, 1,
    function() local h = tonumber(DB().remindHours); if h == nil then h = 12 end; return h end,
    function(v) if _G.DailyTrackerDB then _G.DailyTrackerDB.remindHours = v end end)
  panel:Button(L.OPT_REMIND_TEST, function() if NS.CheckReminderNow then NS.CheckReminderNow() end end)

  panel:Section(L.OPT_SUITE)
  panel:Check(L.OPT_BADGE,
    function() return DB().badge ~= false end,
    function(v) if _G.DailyTrackerDB then _G.DailyTrackerDB.badge = v end; Refresh() end)
  panel:Check(L.OPT_HIDE_OPTS,
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden(FRAME, "options") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden(FRAME, "options", v) end end)
  panel:Check(L.OPT_HIDE_SEARCH,
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden(FRAME, "search") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden(FRAME, "search", v) end end)
  panel:Note(L.OPT_FLOAT_NOTE)
  panel:Note(L.OPT_TIP_NOTE)
  return panel
end

function DailyTracker_OpenOptions()
  local p = BuildOptions(); if p then p:Toggle() end
end

-- ---------------------------------------------------------------- Recherche
local function Open(extKey, facName, questName)
  if _G.DailyTracker_ShowFaction then
    _G.DailyTracker_ShowFaction(extKey, facName, questName)
  else
    local f = _G[FRAME]
    if _G.DailyTracker_Toggle and (not f or not f:IsShown()) then _G.DailyTracker_Toggle() end
  end
end

local function provider(q)
  local out, ui = {}, GetUI()
  local data = _G.DailyTrackerData
  if not ui or type(data) ~= "table" then return out end
  for extKey, ext in pairs(data) do
    if type(ext) == "table" and ext.factions then
      for _, fac in ipairs(ext.factions) do
        if fac.name and ui.Match(fac.name, q) then
          out[#out + 1] = {
            text = fac.name .. "  |cff808080" .. L.SEARCH_FACTION .. " · " .. tostring(ext.label or extKey) .. "|r",
            onClick = function() Open(extKey, fac.name) end }
        end
        for _, quest in ipairs(fac.quests or {}) do
          -- Nom des donnees OU titre du client (langue du jeu)
          local shown = (NS.DisplayName and NS.DisplayName(quest)) or quest.name
          if quest.name and (ui.Match(quest.name, q) or (shown ~= quest.name and ui.Match(shown, q))) then
            out[#out + 1] = {
              text = shown .. "  |cff808080" .. (fac.name or extKey) .. "|r",
              onClick = function() Open(extKey, fac.name, quest.name) end }
            if #out >= 60 then return out end
          end
        end
      end
    end
  end
  return out
end

local searchPopup
local function OpenSearch()
  local ui = GetUI(); if not ui then return end
  if not searchPopup then
    searchPopup = ui.CreateSearchPopup({
      name = "DailyTrackerSearchPopup",
      title = "|cFF16C4FCDailyTracker|r  " .. L.SEARCH_TITLE, accent = ACCENT, logo = LOGO, provider = provider })
  end
  searchPopup.Toggle()
end
NS.OpenSearch = OpenSearch

-- ---------------------------------------------------------- Attache & skin
local function Decorate()
  local ui = GetUI(); local f = _G[FRAME]
  if not (ui and f) then return end
  if not f._tibiSkinned then
    ui.SkinFrame(f, ACCENT)
    f._tibiSkinned = true
  end
  if f._tibiControls then return end
  ui.AddHeaderControls(f, {
    accent = ACCENT,
    onOptions = function() DailyTracker_OpenOptions() end,
    provider = provider,
  })
end

-- Inscription immediate au registre de recherche globale
-- (le provider lit les donnees a la volee ; plus fiable que PLAYER_LOGIN seul)
do local _u = GetUI(); if _u and _u.RegisterSearch then _u.RegisterSearch(KEY, "Daily", provider) end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local ui = GetUI()
  if ui and ui.RegisterSearch then ui.RegisterSearch(KEY, "Daily", provider) end
  C_Timer.After(1.0, Decorate)
  C_Timer.After(3.0, Decorate)  -- 2e passe si la fenetre est construite tardivement
end)
