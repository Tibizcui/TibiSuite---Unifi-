-- ================================================================
-- DgnTracker - API.lua
-- API publique pour les autres modules de la suite (LvlHistory,
-- WeeklyCompass...) et pour les addons tiers. Toujours tester sa presence :
--   if _G.DgnTrackerAPI then DgnTrackerAPI.OpenInstance("Ara-Kara") end
-- Aucune ecriture dans la sauvegarde d'un autre module : on ne fait
-- qu'ouvrir la fenetre de DgnTracker sur la bonne fiche.
-- NON TESTE EN JEU : a valider par Tibiscui (nouveau fichier : redemarrage
-- complet du client).
-- ================================================================

local Live = DgnTrackerLive

DgnTrackerAPI = {
  version = 1,

  -- Ouvre DgnTracker sur une instance, fiche depliee.
  -- q : nom (toute langue connue du jeu ou de DgnTracker), ou table
  --     { name=, instMapID=, challengeMapID=, jid=, type="dungeon"|"raid"|"delve" }
  -- Renvoie true si l'instance a ete trouvee.
  OpenInstance = function(q)
    if not _G.DgnTracker_OpenInstance then return false end
    return _G.DgnTracker_OpenInstance(q) and true or false
  end,

  -- Instance connue ? Renvoie le nom affiche (langue du client) ou nil.
  Find = function(q)
    local inst = Live and Live.Find(q)
    return inst and (Live.DisplayName(inst)) or nil
  end,

  -- Ouvre une vue : "Season", "Nearby", "Favs" ou une extension ("Midnight"...).
  OpenView = function(view)
    if not (DgnTrackerDB and _G.DgnTracker_Toggle) then return end
    DgnTrackerDB.extension = view
    DgnTrackerDB.activeTab = "dungeon"
    local f = _G.DGNMainFrame
    if f and f:IsShown() then f:RefreshContent() else _G.DgnTracker_Toggle() end
  end,
}
