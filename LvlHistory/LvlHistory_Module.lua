--[[============================================================================
  LvlHistory - Glue module pour TibiSuite  (complement de LvlHistory_Suite.lua)
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a LvlHistoryDB ni au code de donnees. Il se contente
  d'inscrire LvlHistory comme onglet de la barre unifiee TibiSuite et de masquer
  le bouton minimap individuel (un seul bouton pour toute la suite).

  La recherche globale, le panneau d'options et l'habillage de la fenetre restent
  geres par LvlHistory_Suite.lua, charge juste avant : on NE les re-enregistre
  PAS ici (pas de doublon). On se limite a :
    - RegisterModule : ajoute la vignette "Lvl Hist" (accent vert) a la barre.
    - masquage du bouton minimap LvlHistoryMinimapButton.
    - rattrapage cosmetique : en LoadOnDemand, le handler PLAYER_LOGIN de
      LvlHistory_Suite.lua ne se declenche plus, donc l'habillage differe qu'il
      programmait ne tourne pas ; on rejoue le skin ici, en reutilisant le
      provider de recherche deja inscrit (pas de reinvention).
  Charge en dernier par LvlHistory.toc, apres LvlHistory_Suite.lua.
============================================================================]]

local FRAME  = "LvlHistoryMainFrame"
local ACCENT = { 0.369, 0.886, 0.137 }   -- vert (logo #5EE223)
local KEY    = "Lvl"
local L      = LvlHistory and LvlHistory.L or {}
local LABEL  = L["MODULE_LABEL"] or "Lvl Hist"

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
  C_Timer.After(45, function()
    print("|cFFC41F3BTibiSuite|r : plus d'infos sur |cFFFFD700https://www.tibiscui.fr|r")
    print("|cFFC41F3BTibiSuite|r : télécharge Tibi-Companion sur |cFFFFD700https://tibiscui.fr/tibi-companion.html|r")
  end)
end

local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
  return TibiSuiteDB.enabledModules[KEY] == true
end

-- Un seul bouton minimap pour la suite EN MODE MODULE seulement : on masque
-- celui de LvlHistory (le core le re-masque aussi ; ceinture et bretelles).
-- En mode standalone, on le laisse visible : c'est le seul bouton disponible.
local function HideOwnMinimap()
  if not HasCore() then return end
  local btn = _G["LvlHistoryMinimapButton"]
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

-- Rattrapage cosmetique. On respecte les memes drapeaux (_tibiSkinned /
-- _tibiControls) que LvlHistory_Suite.lua : idempotent, jamais de double skin.
-- Le provider de recherche est repris tel quel depuis le registre global
-- (inscrit par LvlHistory_Suite.lua) : on ne reinvente rien.
local function Decorate()
  local ui = GetUI(); local f = _G[FRAME]
  if not (ui and f) then return end
  if not f._tibiSkinned then
    ui.SkinFrame(f, ACCENT)
    f._tibiSkinned = true
  end
  if not f._tibiControls then
    local prov = ui.searchProviders and ui.searchProviders[KEY] and ui.searchProviders[KEY].fn
    ui.AddHeaderControls(f, {
      accent    = ACCENT,
      onOptions = function() if _G.LvlHistory_OpenOptions then _G.LvlHistory_OpenOptions() end end,
      provider  = prov,
    })
  end
end

-- ---------------------------------------------------------- Inscription suite
-- MODE MODULE : inscription au catalogue, sauf si explicitement desactive.
-- MODE STANDALONE : rien a faire ici - LvlHistory cree deja son propre bouton
-- minimap (Minimap.lua) et sa commande slash /lvlh de facon inconditionnelle.
-- searchProvider = nil : la recherche est deja inscrite par LvlHistory_Suite.lua
-- (RegisterSearch au chargement), on ne la re-enregistre pas ici.
if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key            = KEY,
    label          = LABEL,
    accent         = ACCENT,
    onOpen         = function() if _G.LvlHistory_Toggle then _G.LvlHistory_Toggle() end end,
    onOptions      = function() if _G.LvlHistory_OpenOptions then _G.LvlHistory_OpenOptions() end end,
    searchProvider = nil,
    -- Ligne d'etat du Panneau vivant : XP du niveau en cours, et temps estime
    -- jusqu'au suivant quand la session a un rythme d'XP. Rien au niveau max.
    statusFn       = function()
      local maxXP = UnitXPMax and UnitXPMax("player") or 0
      if maxXP <= 0 or (IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel()) then return nil end
      local SL, TS = _G.TibiSuiteL or {}, _G.TibiSuite
      local cur, lvl = UnitXP("player") or 0, UnitLevel("player") or 0
      -- Constate en jeu (2026-10-06) : au niveau 90, UnitXPMax reste > 0 et
      -- IsPlayerAtEffectiveMaxLevel ne suffit pas. On compare au plafond de
      -- l'extension, et on se tait aussi si l'XP est bloquee.
      local cap = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
      if (cap and lvl >= cap) or (IsXPUserDisabled and IsXPUserDisabled()) then return nil end
      local pct = cur / maxXP
      local xph = 0
      if _G.LvlHistoryAPI and LvlHistoryAPI.GetSession then
        local ok, s = pcall(LvlHistoryAPI.GetSession)
        if ok and s then xph = tonumber(s.liveXPH) or tonumber(s.xph) or 0 end
      end
      if xph > 0 and TS and TS.FmtDuration then
        return { text = string.format(SL.ST_LVL_ETA_FMT or "%d %s", lvl + 1, TS.FmtDuration((maxXP - cur) / xph * 3600)), progress = pct }
      end
      return { text = string.format(SL.ST_LVL_FMT or "%d %d", lvl, math.floor(pct * 100)), progress = pct }
    end,
    -- Apercu du Centre (7.1.5.45) : niveau, temps avant le suivant, XP/h,
    -- XP reposee, session en cours. Rien au niveau maximum.
    overviewFn = function()
      local SL, TS = _G.TibiSuiteL or {}, _G.TibiSuite
      local out = { lines = {}, empty = SL.OV_LVL_MAX }
      local maxXP = UnitXPMax and UnitXPMax("player") or 0
      local cur, lvl = UnitXP("player") or 0, UnitLevel("player") or 0
      local cap = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
      if maxXP <= 0 or (cap and lvl >= cap) or (IsXPUserDisabled and IsXPUserDisabled()) then return out end
      local lines = out.lines
      local pct = cur / maxXP
      lines[#lines + 1] = { text = string.format(SL.OV_LVL_LEVEL_FMT or "%d", lvl), value = math.floor(pct * 100) .. " %",
        progress = pct, target = 6 }
      local s
      if _G.LvlHistoryAPI and LvlHistoryAPI.GetSession then
        local ok, v = pcall(LvlHistoryAPI.GetSession); if ok then s = v end
      end
      local xph = s and (tonumber(s.liveXPH) or tonumber(s.xph)) or 0
      if xph > 0 and TS and TS.FmtDuration then
        lines[#lines + 1] = { text = SL.OV_LVL_ETA, value = TS.FmtDuration((maxXP - cur) / xph * 3600), target = 1 }
        local n = math.floor(xph)
        lines[#lines + 1] = { text = SL.OV_LVL_XPH, value = (BreakUpLargeNumbers and BreakUpLargeNumbers(n)) or tostring(n), target = 1 }
      end
      local rested = GetXPExhaustion and GetXPExhaustion() or 0
      if rested and rested > 0 then
        lines[#lines + 1] = { text = SL.OV_LVL_RESTED, value = math.floor(math.min(1.5, rested / maxXP) * 100) .. " %",
          color = { 0.31, 0.62, 1 } }
      end
      if s and ((s.quests or 0) + (s.dungeons or 0)) > 0 then
        lines[#lines + 1] = { text = SL.OV_LVL_SESSION, value = string.format(SL.OV_LVL_SESSION_FMT or "%d %d", s.quests or 0, s.dungeons or 0), target = 1 }
      end
      return out
    end,
    openTo = function(tab)
      if _G.LvlHistoryAPI and LvlHistoryAPI.Open and tonumber(tab) then LvlHistoryAPI.Open(tonumber(tab)); return true end
      return false
    end,
  })
end

-- La fenetre LvlHistoryMainFrame est construite par UI.lua ; on habille en
-- differe et on remasque le bouton minimap, avec quelques secours.
C_Timer.After(0.2, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(1.0, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(3.0, function() HideOwnMinimap(); Decorate() end)
