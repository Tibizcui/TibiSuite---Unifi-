--[[============================================================================
  DgnTracker - Glue module pour TibiSuite  (complete DgnTracker_Suite.lua)
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a DgnTrackerDB ni au code de donnees. En mode
  LoadOnDemand, il complete DgnTracker_Suite.lua qui reste charge :
    - RegisterModule : ajoute l'onglet "Donjons" (accent bleu) a la barre
      unifiee de la suite.
    - habille la fenetre DGNMainFrame au style socle (rattrapage cosmetique :
      le handler PLAYER_LOGIN de _Suite.lua ne se declenche plus en LoD).
    - masque le bouton minimap individuel : un seul bouton pour toute la suite.
  La recherche globale et le panneau d'options restent geres par
  DgnTracker_Suite.lua ; on ne les re-enregistre pas ici (pas de doublon).
  Charge en dernier par DgnTracker.toc, apres DgnTracker.lua et _Suite.lua.
============================================================================]]

local FRAME  = "DGNMainFrame"
local ACCENT = { 0.008, 0.404, 0.988 }   -- bleu (logo #0267FC)
local LOGO   = "Interface\\AddOns\\DgnTracker\\medias\\DgnTracker"
local KEY    = "Dgn"

local function GetUI() return _G.TibiMidnight end

-- ---------------------------------------------------------------- Recherche
-- Provider identique a celui de _Suite.lua. Ici il sert uniquement a alimenter
-- la loupe de l'en-tete de la fenetre (habillage). L'inscription au registre
-- global de recherche reste faite par _Suite.lua : on ne la double pas.
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

-- ---------------------------------------------------------- Habillage fenetre
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
    onOptions = function() if _G.DgnTracker_OpenOptions then _G.DgnTracker_OpenOptions() end end,
    provider = provider,
  })
end

-- Un seul bouton minimap pour la suite : on masque celui de DgnTracker.
-- (Le core le re-masque aussi via HookScript ; ceinture et bretelles.)
local function HideOwnMinimap()
  local btn = _G["DGNMinimapBtn"]
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
    key       = KEY,
    label     = "Donjons",
    accent    = ACCENT,
    onOpen    = function() if _G.DgnTracker_Toggle then _G.DgnTracker_Toggle() end end,
    onOptions = function() if _G.DgnTracker_OpenOptions then _G.DgnTracker_OpenOptions() end end,
    -- searchProvider volontairement omis : DgnTracker_Suite.lua enregistre
    -- deja la recherche pour la cle "Dgn".
  })
elseif GetUI() and GetUI().RegisterSearch then
  -- Repli : suite absente mais socle present. _Suite.lua a normalement deja
  -- inscrit la recherche ; on la re-poste par securite (meme cle -> ecrase).
  GetUI().RegisterSearch(KEY, "Donjons", provider)
end

-- Rattrapage LoadOnDemand : DGNMainFrame est construit par DgnTracker.lua sur
-- son ADDON_LOADED (juste avant ce fichier). On habille en differe et on
-- remasque le bouton minimap, avec quelques tentatives de secours.
C_Timer.After(0.2, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(1.0, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(3.0, function() HideOwnMinimap(); Decorate() end)
