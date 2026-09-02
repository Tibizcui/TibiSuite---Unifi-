--[[============================================================================
  LegTracker - Intégration TibiSuite "Midnight"  (ajout non destructif)
============================================================================]]

local FRAME    = "LegTrackerMainFrame"
local ACCENT   = { 1.000, 0.427, 0.043 }   -- orange (logo #FF6D0B)
local LOGO     = "Interface\\AddOns\\LegTracker\\medias\\LegTracker"
local KEY      = "Leg"
local FULLSKIN = false

local function GetUI() return _G.TibiMidnight end
local function ApplyOpts()
  local f = _G[FRAME]; if f and f.ApplyOptions then f:ApplyOptions() end
end
local function Refresh()
  local f = _G[FRAME]; if f and f.RefreshContent then f:RefreshContent() end
end

-- ---------------------------------------------------------------- Options
local panel
local function BuildOptions()
  local ui = GetUI(); if not ui then return nil end
  if panel then return panel end
  panel = ui.CreateOptionsPanel({
    name = "LegTrackerOptionsMidnight",
    title = "LegTracker - Options", accent = ACCENT })

  panel:Section("Fenêtre")
  panel:Button("Ouvrir / fermer", function()
    if _G.LegTracker_Toggle then _G.LegTracker_Toggle() end
  end)
  panel:Slider("Échelle (%)", 70, 150, 5,
    function() return math.floor(((_G.LegTrackerDB and _G.LegTrackerDB.scale) or 1) * 100 + 0.5) end,
    function(v) if _G.LegTrackerDB then _G.LegTrackerDB.scale = v / 100 end; ApplyOpts() end)
  panel:Slider("Opacité (%)", 40, 100, 5,
    function() return math.floor(((_G.LegTrackerDB and _G.LegTrackerDB.alpha) or 0.97) * 100 + 0.5) end,
    function(v) if _G.LegTrackerDB then _G.LegTrackerDB.alpha = v / 100 end; ApplyOpts() end)
  panel:Check("Verrouiller la fenêtre",
    function() return _G.LegTrackerDB and _G.LegTrackerDB.locked end,
    function(v) if _G.LegTrackerDB then _G.LegTrackerDB.locked = v end; ApplyOpts() end)
  panel:Check("Afficher le bouton minimap",
    function() return _G.LegTrackerDB and _G.LegTrackerDB.showMinimap ~= false end,
    function(v) if _G.LegTrackerDB then _G.LegTrackerDB.showMinimap = v end; ApplyOpts() end)
  panel:Check("Ouvrir automatiquement au login",
    function() return _G.LegTrackerDB and _G.LegTrackerDB.autoOpen end,
    function(v) if _G.LegTrackerDB then _G.LegTrackerDB.autoOpen = v end end)

  panel:Section("Filtres")
  panel:Check("Masquer les objets obtenus",
    function() return _G.LegTrackerDB and _G.LegTrackerDB.filters and _G.LegTrackerDB.filters.hideObtained end,
    function(v)
      if _G.LegTrackerDB then _G.LegTrackerDB.filters = _G.LegTrackerDB.filters or {}; _G.LegTrackerDB.filters.hideObtained = v end
      local f = _G[FRAME]
      if f and f.hideObtainedCheck then f.hideObtainedCheck:SetChecked(v) end
      Refresh()
    end)
  panel:Check("Masquer les non-équipables",
    function() return _G.LegTrackerDB and _G.LegTrackerDB.filters and _G.LegTrackerDB.filters.hideUnavailable end,
    function(v)
      if _G.LegTrackerDB then _G.LegTrackerDB.filters = _G.LegTrackerDB.filters or {}; _G.LegTrackerDB.filters.hideUnavailable = v end
      Refresh()
    end)
  panel:Check("Masquer les objets legacy",
    function() return _G.LegTrackerDB and _G.LegTrackerDB.filters and _G.LegTrackerDB.filters.hideLegacy end,
    function(v)
      if _G.LegTrackerDB then _G.LegTrackerDB.filters = _G.LegTrackerDB.filters or {}; _G.LegTrackerDB.filters.hideLegacy = v end
      Refresh()
    end)

  panel:Section("Boutons flottants")
  panel:Check("Masquer le bouton Options",
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden(FRAME, "options") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden(FRAME, "options", v) end end,
    "Masque le bouton Options qui deborde au-dessus de la fenetre. Meme masque, Maj+clic droit sur la fenetre l'ouvre.")
  panel:Check("Masquer le champ Recherche",
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden(FRAME, "search") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden(FRAME, "search", v) end end,
    "Masque le champ Recherche qui deborde au-dessus de la fenetre.")

  panel:Section("Réinitialisation")
  panel:Button("Recentrer la fenêtre", function()
    local f = _G[FRAME]
    if not f then return end
    LegTrackerDB.pos = {x = 0, y = 0}
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end)
  panel:Button("Taille par défaut", function()
    local f = _G[FRAME]
    if not f then return end
    LegTrackerDB.width  = f.defaultW
    LegTrackerDB.height = f.defaultH
    f:SetSize(f.defaultW, f.defaultH)
    Refresh()
  end)

  panel:Note("Astuce : clic droit sur la vignette LegTracker dans la barre TibiSuite ouvre aussi ces options.")
  return panel
end

function LegTracker_OpenOptions()
  local p = BuildOptions(); if p then p:Toggle() end
end

-- ---------------------------------------------------------------- Recherche
local function provider(q)
  local out, ui = {}, GetUI()
  local data = _G.LegTrackerData
  if not ui or type(data) ~= "table" or type(data.Extensions) ~= "table" then return out end
  local function open()
    local f = _G[FRAME]
    if _G.LegTracker_Toggle and (not f or not f:IsShown()) then _G.LegTracker_Toggle() end
  end
  local function add(text) out[#out + 1] = { text = text, onClick = open } end
  for extKey, ext in pairs(data.Extensions) do
    if type(ext) == "table" and ext.items then
      local extLabel = ext.label or ext.key or tostring(extKey)
      for _, item in ipairs(ext.items) do
        local iname = item.name or "?"
        -- 1) objet légendaire (nom + source/description)
        if (item.name and ui.Match(item.name, q))
           or (item.source and ui.Match(item.source, q)) then
          add(iname .. "  |cff808080" .. extLabel .. "|r")
        end
        -- 2) quêtes de l'objet (nom, pnj, zone)
        if type(item.quests) == "table" then
          for _, qu in ipairs(item.quests) do
            local qhay = (qu.name or "") .. " " .. (qu.npc or "") .. " " .. (qu.zone or "")
            if ui.Match(qhay, q) then
              add((qu.name or "quête") .. "  |cff808080quête · " .. iname .. "|r")
            end
          end
        end
        -- 3) composants à farmer (trackers)
        if type(item.trackers) == "table" then
          for _, tr in ipairs(item.trackers) do
            if tr.name and ui.Match(tr.name, q) then
              add(tr.name .. "  |cff808080composant · " .. iname .. "|r")
            end
          end
        end
        if #out >= 80 then return out end
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
      name = "LegTrackerSearchPopup",
      title = "|cFF9480FFLegTracker|r  Recherche", accent = ACCENT, logo = LOGO, provider = provider })
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
    onOptions = function() LegTracker_OpenOptions() end,
    provider = provider,
  })
end

-- Inscription immediate au registre de recherche globale
-- (le provider lit les donnees a la volee ; plus fiable que PLAYER_LOGIN seul)
do local _u = GetUI(); if _u and _u.RegisterSearch then _u.RegisterSearch(KEY, "LegTracker", provider) end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local ui = GetUI()
  if ui and ui.RegisterSearch then ui.RegisterSearch(KEY, "LegTracker", provider) end
  C_Timer.After(1.0, Decorate)
  C_Timer.After(3.0, Decorate)
end)
