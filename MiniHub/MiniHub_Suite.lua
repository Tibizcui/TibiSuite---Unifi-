--[[============================================================================
  MiniHub - Intégration TibiSuite "Midnight"  (ajout non destructif)
  Migre l'ouverture des options vers un panneau flottant Midnight (au lieu de
  la fenetre Reglages de Blizzard), tout en conservant le code existant.
============================================================================]]

local FRAME    = "MiniHubContainer"
local ACCENT   = { 0.988, 0.843, 0.282 }   -- or vif (logo #FCD748)
local LOGO     = "Interface\\AddOns\\MiniHub\\media\\Logo_MiniHub"
local KEY      = "MiniHub"
local FULLSKIN = false

local function GetUI() return _G.TibiMidnight end
local function MH() return _G.MiniHub end
local function DB() return _G.MiniHubDB end
local function Layout() local m = MH(); if m and m.Layout then m.Layout() end end
local function Ctx() local m = MH(); if m and m.UpdateContextVisibility then m.UpdateContextVisibility() end end

-- ---------------------------------------------------------------- Options
local panel
local function BuildOptions()
  local ui = GetUI(); if not ui then return nil end
  if panel then return panel end
  panel = ui.CreateOptionsPanel({
    name = "MiniHubOptionsMidnight",
    title = "MiniHub - Options", accent = ACCENT })

  panel:Section("Disposition")
  panel:Check("Orientation verticale",
    function() return DB() and DB().orientation == "VERTICAL" end,
    function(v) if DB() then DB().orientation = v and "VERTICAL" or "HORIZONTAL" end; Layout() end)
  panel:Slider("Boutons par ligne/colonne", 1, 12, 1,
    function() return (DB() and DB().perLine) or 6 end,
    function(v) if DB() then DB().perLine = v end; Layout() end)
  panel:Slider("Taille des boutons", 20, 48, 1,
    function() return (DB() and DB().buttonSize) or 32 end,
    function(v) if DB() then DB().buttonSize = v end; Layout() end)
  panel:Slider("Espacement", 0, 12, 1,
    function() return (DB() and DB().spacing) or 4 end,
    function(v) if DB() then DB().spacing = v end; Layout() end)

  panel:Section("Apparence")
  panel:Check("Afficher le titre",
    function() return DB() and DB().showTitle end,
    function(v) if DB() then DB().showTitle = v end; Layout() end)
  panel:Check("Masquer les boutons de zoom de la minicarte",
    function() return DB() and DB().hideZoomButtons end,
    function(v) if DB() then DB().hideZoomButtons = v end
      local m = MH(); if m and m.ApplyBlizzardHiding then m.ApplyBlizzardHiding() end end)

  panel:Section("Comportement")
  panel:Check("Verrouiller la position",
    function() return DB() and DB().locked end,
    function(v) if DB() then DB().locked = v end end)
  panel:Check("Ouvrir au survol",
    function() return DB() and DB().hoverOpen end,
    function(v) if DB() then DB().hoverOpen = v end end)
  panel:Check("Fermeture automatique",
    function() return DB() and DB().autoClose end,
    function(v) if DB() then DB().autoClose = v end end)
  panel:Check("Masquer en combat",
    function() return DB() and DB().hideInCombat end,
    function(v) if DB() then DB().hideInCombat = v end; Ctx() end)

  panel:Section("Actions")
  panel:Button("Rescanner les boutons", function()
    local m = MH(); if m and m.Scan then m.Scan() end
  end)
  panel:Button("Recentrer", function()
    if DB() then
      DB().point = { "CENTER", "UIParent", "CENTER", 0, 0 }
      DB().mainPoint = { "CENTER", "UIParent", "CENTER", 200, 0 }
    end
    local m = MH(); if m and m.RestorePosition then m.RestorePosition() end
  end)
  return panel
end

function MiniHub_OpenOptions()
  local p = BuildOptions(); if p then p:Toggle() end
end

-- ---------------------------------------------------------------- Recherche
local function provider(q)
  local out, ui = {}, GetUI()
  local m = MH()
  if not ui or not m or type(m.order) ~= "table" then return out end
  for _, btn in ipairs(m.order) do
    local name = btn and btn.GetName and btn:GetName()
    if name and ui.Match(name, q) then
      out[#out + 1] = { text = name,
        onClick = function() if m.Open then m.Open() elseif m.Toggle then m.Toggle() end end }
      if #out >= 60 then return out end
    end
  end
  return out
end

local searchPopup
local function OpenSearch()
  local ui = GetUI(); if not ui then return end
  if not searchPopup then
    searchPopup = ui.CreateSearchPopup({
      name = "MiniHubSearchPopup",
      title = "|cFF9480FFMiniHub|r  Recherche", accent = ACCENT, logo = LOGO, provider = provider })
  end
  searchPopup.Toggle()
end

-- ---------------------------------------------------------- Attache & skin
local function Decorate()
  local ui = GetUI(); local f = _G[FRAME]
  -- Migration : les options passent par le panneau flottant Midnight.
  local m = MH()
  if m then m.OpenOptions = function() MiniHub_OpenOptions() end end
  if not (ui and f) then return end
  if not f._tibiSkinned then
    ui.SkinFrame(f, ACCENT)
    -- En-tête sobre : pas d'icône ajoutée, le titre MiniHub reste à sa place d'origine
    if f.header and f.title then
      f.title:ClearAllPoints()
      f.title:SetPoint("LEFT", f.header, "LEFT", 7, 0)
    end
    f._tibiSkinned = true
  end
  if f._tibiControls then return end
  ui.AddHeaderControls(f, {
    accent = ACCENT,
    onOptions = function() MiniHub_OpenOptions() end,
    provider = provider,
  })
end

-- Inscription immediate au registre de recherche globale
-- (le provider lit les donnees a la volee ; plus fiable que PLAYER_LOGIN seul)
do local _u = GetUI(); if _u and _u.RegisterSearch then _u.RegisterSearch(KEY, "MiniHub", provider) end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local ui = GetUI()
  if ui and ui.RegisterSearch then ui.RegisterSearch(KEY, "MiniHub", provider) end
  C_Timer.After(1.0, Decorate)
  C_Timer.After(3.0, Decorate)
end)
