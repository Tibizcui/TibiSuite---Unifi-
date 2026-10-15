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
local KEY    = "Dgn"
local L      = DgnTrackerL or {}
local function T(key, default) return L[key] or default end

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

-- Recherche et habillage : le code vit dans DgnTracker_Suite.lua (charge juste
-- avant ce fichier) et est expose en global - on ne le duplique plus ici.
local function provider(q)
  return _G.DgnTracker_SearchProvider and _G.DgnTracker_SearchProvider(q) or {}
end
local function Decorate()
  if _G.DgnTracker_Decorate then _G.DgnTracker_Decorate() end
end

-- Un seul bouton minimap pour la suite EN MODE MODULE seulement : on masque
-- celui de DgnTracker (le core le re-masque aussi ; ceinture et bretelles).
-- En mode standalone, on le laisse visible : c'est le seul bouton disponible.
local function HideOwnMinimap()
  if not HasCore() then return end
  local btn = _G["DGNMinimapBtn"]
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
-- MODE STANDALONE : rien a faire ici - DgnTracker.lua cree deja son propre
-- bouton minimap et sa commande slash /dg de facon inconditionnelle.
if HasCore() and IsEnabledByCore() then
  TibiSuite.RegisterModule({
    key       = KEY,
    label     = T("MODULE_LABEL", "Donjons"),
    accent    = ACCENT,
    onOpen    = function() if _G.DgnTracker_Toggle then _G.DgnTracker_Toggle() end end,
    onOptions = function() if _G.DgnTracker_OpenOptions then _G.DgnTracker_OpenOptions() end end,
    -- searchProvider volontairement omis : DgnTracker_Suite.lua enregistre
    -- deja la recherche pour la cle "Dgn".
    -- Ligne d'etat du Panneau vivant : sauvegardes d'instance encore actives
    -- (donjons et raids), lues dans l'API du jeu.
    statusFn  = function()
      if not (GetNumSavedInstances and GetSavedInstanceInfo) then return nil end
      local n = 0
      for i = 1, GetNumSavedInstances() or 0 do
        local _, _, reset, _, locked = GetSavedInstanceInfo(i)
        if locked and (reset or 0) > 0 then n = n + 1 end
      end
      if n == 0 then return nil end
      local SL = _G.TibiSuiteL or {}
      return { text = string.format(SL.ST_LOCK_FMT or "%d", n) }
    end,
    -- Apercu du Centre (7.1.5.45) : verrous en cours, reset le plus proche
    -- d'abord ; un clic ouvre la fiche de l'instance.
    overviewFn = function()
      local SL, TS = _G.TibiSuiteL or {}, _G.TibiSuite
      local out = { lines = {}, empty = SL.OV_DGN_EMPTY }
      -- Collections faisables cette semaine (7.1.5.45) : une ligne de total,
      -- puis l'instance qui en offre le plus (deja entamee en tete).
      local C = _G.DgnTrackerColl
      local okS, sum = false, nil
      if C and C.Catalog and C.Catalog() then okS, sum = pcall(C.Summary) end
      if okS and type(sum) == "table" and (sum.mount + sum.pet + sum.toy) > 0 then
        out.lines[#out.lines + 1] = { text = SL.OV_DGN_COLL or "Collections", target = "coll",
          value = string.format(SL.OV_DGN_COLL_FMT or "%d / %d / %d", sum.mount, sum.pet, sum.toy) }
        local top = sum.top[1]
        if top then
          out.lines[#out.lines + 1] = { text = top.name, target = "coll",
            value = string.format(SL.OV_DGN_COLL_TOP_FMT or "%d", top.mounts) }
        end
      end
      if not (GetNumSavedInstances and GetSavedInstanceInfo) then return out end
      local list = {}
      for i = 1, GetNumSavedInstances() or 0 do
        local name, _, reset, _, locked, _, _, isRaid, _, diffName, numEnc, encProg = GetSavedInstanceInfo(i)
        if name and locked and (reset or 0) > 0 then
          list[#list + 1] = { name = name, reset = reset, raid = isRaid, diff = diffName, n = numEnc or 0, done = encProg or 0 }
        end
      end
      table.sort(list, function(a, b) return a.reset < b.reset end)
      local maxL = 4 - #out.lines
      for i, e in ipairs(list) do
        if i > math.max(1, maxL) then
          out.lines[#out.lines + 1] = { text = string.format(SL.OV_DGN_MORE_FMT or "%d", #list - (i - 1)) }
          break
        end
        local txt = e.name .. (e.diff and e.diff ~= "" and ("  |cFF8F8C98" .. e.diff .. "|r") or "")
        local val = (e.n > 0 and string.format(SL.OV_DGN_BOSS_FMT or "%d/%d", e.done, e.n) or "")
          .. (TS and TS.FmtDuration and ("   " .. TS.FmtDuration(e.reset)) or "")
        out.lines[#out.lines + 1] = { text = txt, value = val, progress = e.n > 0 and e.done / e.n or nil,
          target = { name = e.name, type = e.raid and "raid" or "dungeon" } }
      end
      return out
    end,
    -- Conseiller (lot 3) : montures faisables cette semaine.
    suggestFn = function()
      local C = _G.DgnTrackerColl
      if C and C.Suggestions then return C.Suggestions(6) end
      return nil
    end,
    openTo = function(target)
      if target == "coll" and _G.DgnTracker_OpenView then _G.DgnTracker_OpenView("Coll"); return true end
      if type(target) == "table" and _G.DgnTrackerAPI and DgnTrackerAPI.OpenInstance then
        return DgnTrackerAPI.OpenInstance(target) and true or false
      end
      return false
    end,
  })
elseif GetUI() and GetUI().RegisterSearch then
  -- Repli : suite absente mais socle present. _Suite.lua a normalement deja
  -- inscrit la recherche ; on la re-poste par securite (meme cle -> ecrase).
  GetUI().RegisterSearch(KEY, T("MODULE_LABEL", "Donjons"), provider)
end

-- Rattrapage LoadOnDemand : DGNMainFrame est construit par DgnTracker.lua sur
-- son ADDON_LOADED (juste avant ce fichier). On habille en differe et on
-- remasque le bouton minimap, avec quelques tentatives de secours.
C_Timer.After(0.2, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(1.0, function() HideOwnMinimap(); Decorate() end)
C_Timer.After(3.0, function() HideOwnMinimap(); Decorate() end)
