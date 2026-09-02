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

-- MODE DOUBLE : le core est-il present et fonctionnel ?
local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end

-- Rappel du site officiel, 10s apres le login, UNIQUEMENT en mode standalone
-- (sans core) : si TibiSuite est present, c'est LUI qui affiche ce message
-- une seule fois (voir TibiSuiteCore.lua) - sinon il apparaitrait jusqu'a
-- 12 fois, une par module.
if not HasCore() then
  C_Timer.After(10, function()
    print("|cFFC41F3BTibiSuite|r : plus d'infos sur |cFFFFD700https://www.tibiscui.fr|r")
  end)
end

local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
  return TibiSuiteDB.enabledModules[KEY] == true
end

-- ---------------------------------------------------------------- Options
-- Panneau d'options au style socle, porte tel quel depuis l'ancien Suite.lua.
local panel
local function BuildOptions()
  local ui = GetUI(); if not ui then return nil end
  if panel then return panel end
  panel = ui.CreateOptionsPanel({
    name = "WeeklyCompassOptionsMidnight",
    title = "WeeklyCompass - Options", accent = ACCENT })

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

-- Un seul bouton minimap pour la suite EN MODE MODULE seulement : on masque
-- celui de WeeklyCompass (le core le re-masque aussi ; ceinture et bretelles).
-- En mode standalone, on le laisse visible : c'est le seul bouton disponible.
local function HideOwnMinimap()
  if not HasCore() then return end
  local btn = _G["WeeklyCompassMinimapButton"]
  if btn and btn.Hide then
    btn:Hide()
    if not btn.__tibiHooked then
      btn.__tibiHooked = true
      -- Differe via C_Timer.After(0, ...) : eviter d'executer notre code de
      -- facon synchrone dans le script OnShow d'un bouton qui ne nous
      -- appartient pas (piege ADDON_ACTION_FORBIDDEN, voir TibiSuiteCore.lua).
      btn:HookScript("OnShow", function(self) C_Timer.After(0, function() self:Hide() end) end)
    end
  end
end

-- ---------------------------------------------------------- Inscription suite
-- MODE MODULE : inscription au catalogue, sauf si explicitement desactive.
-- MODE STANDALONE : rien a faire ici - WeeklyCompass cree deja son propre
-- bouton minimap (UI\Launcher.lua) et sa commande slash /wc de facon
-- inconditionnelle.
if HasCore() and IsEnabledByCore() then
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