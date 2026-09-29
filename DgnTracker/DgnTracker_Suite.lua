--[[============================================================================
  DgnTracker - Intégration TibiSuite "Midnight"  (ajout non destructif)
  Voir DailyTracker_Suite.lua pour le detail du principe.
============================================================================]]

local FRAME    = "DGNMainFrame"
local ACCENT   = { 0.008, 0.404, 0.988 }   -- bleu (logo #0267FC)
local LOGO     = "Interface\\AddOns\\DgnTracker\\medias\\DgnTracker"
local KEY      = "Dgn"
local L        = DgnTrackerL or {}
local function T(key, default) return L[key] or default end

local function GetUI() return _G.TibiMidnight end
local function RefreshMain()
  local f = _G[FRAME]
  if f and f:IsShown() and f.RefreshContent then f:RefreshContent() end
end

-- ---------------------------------------------------------------- Options
local panel
local function BuildOptions()
  local ui = GetUI(); if not ui then return nil end
  if panel then return panel end
  panel = ui.CreateOptionsPanel({
    name = "DgnTrackerOptionsMidnight",
    title = "DgnTracker - Options", accent = ACCENT })

  panel:Section(T("OPT_SEC_WINDOW", "Fenêtre"))
  panel:Button(T("OPT_TOGGLE", "Ouvrir / fermer"), function()
    if _G.DgnTracker_Toggle then _G.DgnTracker_Toggle() end
  end)
  panel:Button(T("OPT_RECENTER", "Recentrer la fenêtre"), function()
    local f = _G[FRAME]; if f then f:ClearAllPoints(); f:SetPoint("CENTER") end
  end)

  panel:Section(T("OPT_SEC_BEHAVIOR", "Comportement"))
  panel:Check(T("OPT_AUTO_WAYPOINT", "Waypoint auto à l'ouverture d'une instance"),
    function() return _G.DgnTrackerDB and _G.DgnTrackerDB.mapPins end,
    function(v) if _G.DgnTrackerDB then _G.DgnTrackerDB.mapPins = v end end)
  panel:Check(T("OPT_BADGES", "Badges sur les instances (verrous, Mythique+, abondant)"),
    function() return _G.DgnTrackerDB and _G.DgnTrackerDB.badges ~= false end,
    function(v) if _G.DgnTrackerDB then if v then _G.DgnTrackerDB.badges = nil else _G.DgnTrackerDB.badges = false end; RefreshMain() end end)
  panel:Check(T("OPT_DETECT", "Ajouter les instances trouvées dans le jeu et absentes des fiches"),
    function() return _G.DgnTrackerDB and _G.DgnTrackerDB.detect ~= false end,
    function(v) if _G.DgnTrackerDB then if v then _G.DgnTrackerDB.detect = nil else _G.DgnTrackerDB.detect = false end end end)
  panel:Note(T("OPT_DETECT_NOTE", "Décocher prend effet au prochain /reload."))

  panel:Section(T("OPT_SEC_DATA", "Données"))
  panel:Button(T("OPT_PROBE", "Lancer la sonde (/dg probe)"), function()
    if SlashCmdList and SlashCmdList["DGNTRACKER"] then SlashCmdList["DGNTRACKER"]("probe") end
  end)
  panel:Note(T("OPT_PROBE_NOTE", "La sonde enregistre ce que le jeu renvoie (entrées, gouffres, saison, verrous) dans la sauvegarde de DgnTracker, pour corriger les fiches. Faites /reload ensuite, puis envoyez le fichier WTF\\...\\SavedVariables\\DgnTracker.lua à Tibiscui."))

  panel:Section(T("OPT_SEC_FLOATING", "Boutons flottants (barre TibiSuite)"))
  panel:Check(T("OPT_HIDE_OPTIONS_BTN", "Masquer le bouton Options"),
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("DGNMainFrame", "options") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("DGNMainFrame", "options", v) end end)
  panel:Check(T("OPT_HIDE_SEARCH_BTN", "Masquer le champ Recherche"),
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("DGNMainFrame", "search") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("DGNMainFrame", "search", v) end end)
  panel:Note(T("OPT_FLOATING_NOTE", "Le bouton Options et le champ Recherche debordent au-dessus de la fenetre. Meme masques, Maj+clic droit sur la fenetre ouvre ces options."))

  panel:Note(T("OPT_NOTE", "Astuce : clic droit sur la vignette Donjons dans la barre TibiSuite ouvre aussi ces options."))
  return panel
end

function DgnTracker_OpenOptions()
  local p = BuildOptions(); if p then p:Toggle() end
end

-- ---------------------------------------------------------------- Recherche
local function provider(q)
  local out, ui = {}, GetUI()
  local data, Live = _G.DgnTrackerData, _G.DgnTrackerLive
  if not ui or type(data) ~= "table" then return out end
  for extKey, ext in pairs(data) do
    if type(ext) == "table" and ext.instances then
      for _, inst in ipairs(ext.instances) do
        -- Nom de data\ ET nom du jeu (langue du client) : "Ara-Kara" se
        -- trouve aussi bien sur un client francais qu'anglais.
        local shown = Live and (Live.DisplayName(inst)) or inst.name or "?"
        local hay = (inst.name or "") .. " " .. shown .. " " .. (inst.zone or "") .. " " .. (inst.region or "")
        if ui.Match(hay, q) then
          out[#out + 1] = {
            text = shown .. "  |cff808080" .. (inst.zone or tostring(extKey)) .. "|r",
            onClick = function()
              if _G.DgnTracker_OpenInstance and _G.DgnTracker_OpenInstance(inst) then return end
              local f = _G[FRAME]
              if _G.DgnTracker_Toggle and (not f or not f:IsShown()) then _G.DgnTracker_Toggle() end
            end }
          if #out >= 60 then return out end
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
      name = "DgnTrackerSearchPopup",
      title = "|cFF0267FCDgnTracker|r  " .. T("SEARCH_TITLE", "Recherche"), accent = ACCENT, logo = LOGO, provider = provider })
  end
  searchPopup.Toggle()
end

-- ---------------------------------------------------------- Attache & skin
local function Decorate()
  local ui = GetUI(); local f = _G[FRAME]
  if not (ui and f) then return end
  if not f._tibiSkinned then
    ui.SkinFrame(f, ACCENT)
    if ui.SkinScrollBar and f.scrollFrame then ui.SkinScrollBar(f.scrollFrame, ACCENT) end
    f._tibiSkinned = true
  end
  if f._tibiControls then return end
  ui.AddHeaderControls(f, {
    accent = ACCENT,
    onOptions = function() DgnTracker_OpenOptions() end,
    provider = provider,
  })
end

-- Exposes pour DgnTracker_Module.lua (meme code, plus de doublon a maintenir)
_G.DgnTracker_SearchProvider = provider
_G.DgnTracker_Decorate = Decorate

-- Inscription immediate au registre de recherche globale
-- (le provider lit les donnees a la volee ; plus fiable que PLAYER_LOGIN seul)
do local _u = GetUI(); if _u and _u.RegisterSearch then _u.RegisterSearch(KEY, T("MODULE_LABEL", "Donjons"), provider) end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local ui = GetUI()
  if ui and ui.RegisterSearch then ui.RegisterSearch(KEY, T("MODULE_LABEL", "Donjons"), provider) end
  C_Timer.After(1.0, Decorate)
  C_Timer.After(3.0, Decorate)
end)
