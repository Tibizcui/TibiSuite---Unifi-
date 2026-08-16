--[[============================================================================
  WeeklyCompass - Glue module pour TibiSuite  (remplace UI\Suite.lua)
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a WeeklyCompassDB ni a la logique de collecte. Il se
  contente d'inscrire WeeklyCompass dans la suite :
    - RegisterModule : ajoute l'onglet "Weekly" (accent turquoise) a la barre
      unifiee et branche le provider dans la recherche globale (RegisterSearch).
    - habille la fenetre WeeklyCompassFrame au style socle (lisere, loupe,
      options), en differe car PLAYER_LOGIN est deja passe en LoadOnDemand.
    - masque le bouton minimap individuel : un seul bouton pour toute la suite.
  Charge en dernier par WeeklyCompass.toc, apres UI\Launcher.lua.
============================================================================]]

local addonName, ns = ...

local FRAME  = "WeeklyCompassFrame"
local ACCENT = { 0.039, 1.000, 0.745 }   -- turquoise (logo #0AFFBE)
local KEY    = "Weekly"

local function GetUI() return _G.TibiMidnight end

-- ---------------------------------------------------------------- Options
-- Panneau d'options au style socle, porte tel quel depuis l'ancien Suite.lua.
local panel
local function BuildOptions()
  local ui = GetUI(); if not ui then return nil end
  if panel then return panel end
  panel = ui.CreateOptionsPanel({
    name = "WeeklyCompassOptionsMidnight",
    title = "|cFF9480FFWeeklyCompass|r  Options", accent = ACCENT })

  panel:Section("Fenêtre")
  panel:Button("Ouvrir / fermer", function()
    if _G.WeeklyCompass_Toggle then _G.WeeklyCompass_Toggle() end
  end)
  panel:Button("Recentrer la fenêtre", function()
    local f = _G[FRAME]; if f then f:ClearAllPoints(); f:SetPoint("CENTER") end
  end)
  panel:Button("Rafraîchir les activités", function()
    if ns and ns.Registry and ns.Registry.RefreshAll then
      pcall(function() ns.Registry:RefreshAll() end)
    end
  end)

  panel:Section("Boutons flottants (barre TibiSuite)")
  panel:Check("Masquer le bouton Options",
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("WeeklyCompassFrame", "options") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("WeeklyCompassFrame", "options", v) end end)
  panel:Check("Masquer le champ Recherche",
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("WeeklyCompassFrame", "search") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("WeeklyCompassFrame", "search", v) end end)
  panel:Note("Le bouton Options et le champ Recherche debordent au-dessus de la fenetre. Meme masques, Maj+clic droit sur la fenetre ouvre ces options.")

  panel:Note("Astuce : clic droit sur l'onglet Weekly dans la barre TibiSuite ouvre aussi ces options.")
  return panel
end

function WeeklyCompass_OpenOptions()
  local p = BuildOptions(); if p then p:Toggle() end
end

-- ---------------------------------------------------------------- Recherche
-- Provider porte tel quel depuis l'ancien Suite.lua : lit ns.Registry a la
-- volee (modules d'activite) et ouvre le tableau de bord au clic.
local function provider(q)
  local out, ui = {}, GetUI()
  if not ui or not ns or not ns.Registry or not ns.Registry.GetAll then return out end
  local ok, modules = pcall(function() return (ns.Registry:GetAll()) end)
  if not ok or type(modules) ~= "table" then return out end
  local L = (ns and ns.L) or {}
  for k, desc in pairs(modules) do
    local labelKey = type(desc) == "table" and desc.labelKey
    local label = (labelKey and L[labelKey])
      or (type(desc) == "table" and (desc.label or desc.title or desc.name)) or k
    local hay = tostring(label) .. " " .. tostring(k) .. " " .. tostring(labelKey or "")
    if ui.Match(hay, q) then
      out[#out + 1] = { text = tostring(label),
        onClick = function()
          local f = _G[FRAME]
          if _G.WeeklyCompass_Toggle and (not f or not f:IsShown()) then _G.WeeklyCompass_Toggle() end
        end }
      if #out >= 60 then return out end
    end
  end
  return out
end

-- ---------------------------------------------------------- Habillage fenetre
local function Decorate()
  local ui = GetUI(); local f = _G[FRAME]
  if not (ui and f) then return end
  if not f._tibiSkinned then
    ui.SkinFrame(f, ACCENT)
    f._tibiSkinned = true
  end
  -- WeeklyCompass redessine son cadre : on reaffirme le lisere a chaque ouverture.
  if ui.SetLisere then ui.SetLisere(f, ACCENT) end
  if not f._tibiLisereHook then
    f._tibiLisereHook = true
    f:HookScript("OnShow", function(self)
      local u = GetUI(); if u and u.SetLisere then u.SetLisere(self, ACCENT) end
    end)
  end
  if f._tibiControls then return end
  ui.AddHeaderControls(f, {
    accent = ACCENT,
    onOptions = function() WeeklyCompass_OpenOptions() end,
    provider = provider,
  })
end

-- Un seul bouton minimap pour la suite : on masque celui de WeeklyCompass.
-- (Le core le re-masque aussi via HookScript ; ceinture et bretelles.)
local function HideOwnMinimap()
  local btn = _G["WeeklyCompassMinimapButton"]
  if btn and btn.Hide then
    btn:Hide()
    if not btn.__tibiHooked then
      btn.__tibiHooked = true
      btn:HookScript("OnShow", function(self) self:Hide() end)
    end
  end
end

-- ---------------------------------------------------------- Inscription suite
-- Le core est charge avant nous (## Dependencies: TibiSuite), donc l'API existe.
if TibiSuite and TibiSuite.RegisterModule then
  TibiSuite.RegisterModule({
    key            = KEY,
    label          = "Weekly",
    accent         = ACCENT,
    onOpen         = function() if _G.WeeklyCompass_Toggle then _G.WeeklyCompass_Toggle() end end,
    onOptions      = function() WeeklyCompass_OpenOptions() end,
    searchProvider = provider,
  })
elseif GetUI() and GetUI().RegisterSearch then
  -- Repli : suite absente mais socle present -> au moins la recherche marche.
  GetUI().RegisterSearch(KEY, "Weekly", provider)
end

-- La fenetre WeeklyCompassFrame est construite par l'UI du module ; on habille
-- donc en differe (et on remasque le bouton minimap), avec des tentatives de
-- secours car PLAYER_LOGIN est deja passe quand ce module est charge a la demande.
C_Timer.After(0.2, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(1.0, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(3.0, function() HideOwnMinimap(); Decorate() end)