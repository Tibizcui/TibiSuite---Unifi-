--[[============================================================================
  DgnTracker - Intégration TibiSuite "Midnight"  (ajout non destructif)
  Voir DailyTracker_Suite.lua pour le detail du principe.
============================================================================]]

local FRAME    = "DGNMainFrame"
local ACCENT   = { 0.008, 0.404, 0.988 }   -- bleu (logo #0267FC)
local LOGO     = "Interface\\AddOns\\DgnTracker\\medias\\DgnTracker"
local KEY      = "Dgn"
local FULLSKIN = false

local function GetUI() return _G.TibiMidnight end

-- ---------------------------------------------------------------- Options
local panel
local function BuildOptions()
  local ui = GetUI(); if not ui then return nil end
  if panel then return panel end
  panel = ui.CreateOptionsPanel({
    name = "DgnTrackerOptionsMidnight",
    title = "|cFF9480FFDgnTracker|r  Options", accent = ACCENT })

  panel:Section("Fenêtre")
  panel:Button("Ouvrir / fermer", function()
    if _G.DgnTracker_Toggle then _G.DgnTracker_Toggle() end
  end)
  panel:Button("Recentrer la fenêtre", function()
    local f = _G[FRAME]; if f then f:ClearAllPoints(); f:SetPoint("CENTER") end
  end)

  panel:Section("Comportement")
  panel:Check("Waypoint auto à l'ouverture d'une instance",
    function() return _G.DgnTrackerDB and _G.DgnTrackerDB.mapPins end,
    function(v) if _G.DgnTrackerDB then _G.DgnTrackerDB.mapPins = v end end)

  panel:Section("Boutons flottants (barre TibiSuite)")
  panel:Check("Masquer le bouton Options",
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("DGNMainFrame", "options") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("DGNMainFrame", "options", v) end end)
  panel:Check("Masquer le champ Recherche",
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("DGNMainFrame", "search") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("DGNMainFrame", "search", v) end end)
  panel:Note("Le bouton Options et le champ Recherche debordent au-dessus de la fenetre. Meme masques, Maj+clic droit sur la fenetre ouvre ces options.")

  panel:Note("Astuce : clic droit sur la vignette Donjons dans la barre TibiSuite ouvre aussi ces options.")
  return panel
end

function DgnTracker_OpenOptions()
  local p = BuildOptions(); if p then p:Toggle() end
end

-- ---------------------------------------------------------------- Recherche
local function provider(q)
  local out, ui = {}, GetUI()
  local data = _G.DgnTrackerData
  if not ui or type(data) ~= "table" then return out end
  for extKey, ext in pairs(data) do
    if type(ext) == "table" and ext.instances then
      for _, inst in ipairs(ext.instances) do
        local hay = (inst.name or "") .. " " .. (inst.zone or "") .. " " .. (inst.region or "")
        if ui.Match(hay, q) then
          out[#out + 1] = {
            text = (inst.name or "?") .. "  |cff808080" .. (inst.zone or tostring(extKey)) .. "|r",
            onClick = function()
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
      title = "|cFF9480FFDgnTracker|r  Recherche", accent = ACCENT, logo = LOGO, provider = provider })
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
    onOptions = function() DgnTracker_OpenOptions() end,
    provider = provider,
  })
end

-- Inscription immediate au registre de recherche globale
-- (le provider lit les donnees a la volee ; plus fiable que PLAYER_LOGIN seul)
do local _u = GetUI(); if _u and _u.RegisterSearch then _u.RegisterSearch(KEY, "Donjons", provider) end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local ui = GetUI()
  if ui and ui.RegisterSearch then ui.RegisterSearch(KEY, "Donjons", provider) end
  C_Timer.After(1.0, Decorate)
  C_Timer.After(3.0, Decorate)
end)
