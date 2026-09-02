--[[============================================================================
  DailyTracker - Intégration TibiSuite "Midnight"  (ajout non destructif)
  ---------------------------------------------------------------------------
  Ajoute, sans toucher au code existant :
    - un panneau d'Options flottant Midnight (DailyTracker_OpenOptions)
    - un bouton texte "Options" + une loupe dans l'en-tête de la fenêtre
    - une recherche (locale + inscrite pour la recherche globale de TibiSuite)
    - l'harmonisation de la bordure a la couleur d'identite de l'addon
  Requiert TibiMidnightUI.lua (charge avant, via le .toc).
============================================================================]]

local FRAME    = "DTMainFrame"
local ACCENT   = { 0.086, 0.769, 0.988 }   -- cyan (logo #16C4FC)
local LOGO     = "Interface\\AddOns\\DailyTracker\\medias\\DailyTracker"
local KEY      = "Daily"
local FULLSKIN = false                       -- deja en palette Midnight -> bordure seule

local function GetUI() return _G.TibiMidnight end

-- ---------------------------------------------------------------- Options
local panel
local function BuildOptions()
  local ui = GetUI(); if not ui then return nil end
  if panel then return panel end
  panel = ui.CreateOptionsPanel({
    name = "DailyTrackerOptionsMidnight",
    title = "DailyTracker - Options", accent = ACCENT })

  panel:Section("Fenêtre")
  panel:Button("Ouvrir / fermer", function()
    if _G.DailyTracker_Toggle then _G.DailyTracker_Toggle() end
  end)
  panel:Button("Recentrer la fenêtre", function()
    local f = _G[FRAME]; if f then f:ClearAllPoints(); f:SetPoint("CENTER") end
  end)

  panel:Section("Affichage")
  panel:Check("Masquer les quêtes terminées",
    function() return _G.DailyTrackerDB and _G.DailyTrackerDB.hideCompleted end,
    function(v)
      if _G.DailyTrackerDB then _G.DailyTrackerDB.hideCompleted = v end
      local f = _G[FRAME]; if f and f.RefreshContent then f:RefreshContent() end
    end)

  panel:Section("Boutons flottants (barre TibiSuite)")
  panel:Check("Masquer le bouton Options",
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("DTMainFrame", "options") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("DTMainFrame", "options", v) end end)
  panel:Check("Masquer le champ Recherche",
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("DTMainFrame", "search") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("DTMainFrame", "search", v) end end)
  panel:Note("Le bouton Options et le champ Recherche debordent au-dessus de la fenetre. Meme masques, Maj+clic droit sur la fenetre ouvre ces options.")

  panel:Note("Astuce : clic droit sur la vignette Daily dans la barre TibiSuite ouvre aussi ces options.")
  return panel
end

function DailyTracker_OpenOptions()
  local p = BuildOptions(); if p then p:Toggle() end
end

-- ---------------------------------------------------------------- Recherche
local function provider(q)
  local out, ui = {}, GetUI()
  local data = _G.DailyTrackerData
  if not ui or type(data) ~= "table" then return out end
  for extKey, ext in pairs(data) do
    if type(ext) == "table" and ext.factions then
      for _, fac in ipairs(ext.factions) do
        if fac.name and ui.Match(fac.name, q) then
          out[#out + 1] = {
            text = fac.name .. "  |cff808080faction · " .. tostring(extKey) .. "|r",
            onClick = function()
              local f = _G[FRAME]
              if _G.DailyTracker_Toggle and (not f or not f:IsShown()) then _G.DailyTracker_Toggle() end
            end }
        end
        for _, quest in ipairs(fac.quests or {}) do
          if quest.name and ui.Match(quest.name, q) then
            out[#out + 1] = {
              text = quest.name .. "  |cff808080" .. (fac.name or extKey) .. "|r",
              onClick = function()
                local f = _G[FRAME]
                if _G.DailyTracker_Toggle and (not f or not f:IsShown()) then _G.DailyTracker_Toggle() end
              end }
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
      title = "|cFF9480FFDailyTracker|r  Recherche", accent = ACCENT, logo = LOGO, provider = provider })
  end
  searchPopup.Toggle()
end

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
