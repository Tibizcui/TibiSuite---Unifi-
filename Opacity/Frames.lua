--[[============================================================================
  Opacity - Frames.lua
  ---------------------------------------------------------------------------
  Tout ce qui sert a CHOISIR une frame :
    - catalogue des fenetres et elements d'interface Blizzard (noms 12.x, avec
      variantes quand Blizzard a renomme une frame entre deux versions) ;
    - fenetres de la suite TibiSuite (lues dans le catalogue du core) ;
    - scan des autres addons : enfants nommes de UIParent, regroupes par addon
      proprietaire ;
    - detection des frames gerees par ElvUI / EllesmereUI.

  QUI A CREE CETTE FRAME ? WoW n'a pas d'API directe, mais issecurevariable(nom)
  renvoie, pour une globale ecrite par du code d'addon, le NOM de cet addon
  (c'est le mecanisme de suivi du taint). Une frame Blizzard renvoie "securisee".
  Fiable dans l'immense majorite des cas, mais NON VERIFIE EN JEU sous 12.x :
  si un groupe "Addon inconnu" apparait, c'est que cette lecture a echoue.
============================================================================]]

local ADDON, OP = ...
local T = OP.T

-- ============================================================================
-- CATALOGUE BLIZZARD
--   names : noms possibles (le premier qui existe gagne ; sinon le premier)
--   cat   : "win" = fenetre, "hud" = element d'interface permanent
-- Certaines fenetres n'existent qu'apres leur premiere ouverture (chargees a
-- la demande par Blizzard) : elles restent "en attente" jusque-la.
-- ============================================================================
local BLIZZARD = {
  -- Fenetres
  { names = { "CharacterFrame" },             cat = "win", label = T("F_CHARACTER",   "Personnage") },
  { names = { "PlayerSpellsFrame" },          cat = "win", label = T("F_SPELLS",      "Talents et sorts") },
  { names = { "ProfessionsBookFrame" },       cat = "win", label = T("F_PROFBOOK",    "Livre des métiers") },
  { names = { "ProfessionsFrame" },           cat = "win", label = T("F_PROFESSIONS", "Artisanat") },
  { names = { "CollectionsJournal" },         cat = "win", label = T("F_COLLECTIONS", "Collections") },
  { names = { "EncounterJournal" },           cat = "win", label = T("F_JOURNAL",     "Guide de l'aventurier") },
  { names = { "PVEFrame" },                   cat = "win", label = T("F_PVE",         "Recherche de groupe") },
  { names = { "WorldMapFrame" },              cat = "win", label = T("F_WORLDMAP",    "Carte du monde") },
  { names = { "FriendsFrame" },               cat = "win", label = T("F_FRIENDS",     "Social") },
  { names = { "CommunitiesFrame" },           cat = "win", label = T("F_GUILD",       "Guilde et communautés") },
  { names = { "AchievementFrame" },           cat = "win", label = T("F_ACHIEV",      "Hauts faits") },
  { names = { "ContainerFrameCombinedBags" }, cat = "win", label = T("F_BAGS",        "Sacs (combinés)") },
  { names = { "ContainerFrame1" },            cat = "win", label = T("F_BAG1",        "Sac à dos (séparé)") },
  { names = { "ContainerFrame2" },            cat = "win", label = T("F_BAG2",        "Sac 2 (séparé)") },
  { names = { "ContainerFrame3" },            cat = "win", label = T("F_BAG3",        "Sac 3 (séparé)") },
  { names = { "ContainerFrame4" },            cat = "win", label = T("F_BAG4",        "Sac 4 (séparé)") },
  { names = { "ContainerFrame5" },            cat = "win", label = T("F_BAG5",        "Sac 5 (séparé)") },
  { names = { "BankFrame" },                  cat = "win", label = T("F_BANK",        "Banque") },
  { names = { "MerchantFrame" },              cat = "win", label = T("F_MERCHANT",    "Marchand") },
  { names = { "MailFrame" },                  cat = "win", label = T("F_MAIL",        "Courrier") },
  { names = { "AuctionHouseFrame" },          cat = "win", label = T("F_AH",          "Hôtel des ventes") },
  { names = { "GossipFrame" },                cat = "win", label = T("F_GOSSIP",      "Dialogues des PNJ") },
  { names = { "QuestFrame" },                 cat = "win", label = T("F_QUEST",       "Quêtes (PNJ)") },
  { names = { "DressUpFrame" },               cat = "win", label = T("F_DRESSUP",     "Cabine d'essayage") },
  { names = { "TradeFrame" },                 cat = "win", label = T("F_TRADE",       "Échange") },
  { names = { "LootFrame" },                  cat = "win", label = T("F_LOOT",        "Butin") },
  { names = { "WeeklyRewardsFrame" },         cat = "win", label = T("F_VAULT",       "Grande chambre forte") },
  { names = { "MacroFrame" },                 cat = "win", label = T("F_MACRO",       "Macros") },

  -- Interface permanente
  { names = { "PlayerFrame" },                cat = "hud", label = T("F_PLAYER",      "Cadre du joueur") },
  { names = { "TargetFrame" },                cat = "hud", label = T("F_TARGET",      "Cadre de la cible") },
  { names = { "FocusFrame" },                 cat = "hud", label = T("F_FOCUS",       "Cadre de focalisation") },
  { names = { "PetFrame" },                   cat = "hud", label = T("F_PET",         "Cadre du familier") },
  { names = { "PartyFrame" },                 cat = "hud", label = T("F_PARTY",       "Cadres de groupe") },
  { names = { "CompactRaidFrameContainer" },  cat = "hud", label = T("F_RAID",        "Cadres de raid") },
  { names = { "BossTargetFrameContainer" },   cat = "hud", label = T("F_BOSS",        "Cadres de boss") },
  { names = { "MainActionBar", "MainMenuBar" }, cat = "hud", label = T("F_BAR1",      "Barre d'action 1") },
  { names = { "MultiBarBottomLeft" },         cat = "hud", label = T("F_BAR2",        "Barre d'action 2") },
  { names = { "MultiBarBottomRight" },        cat = "hud", label = T("F_BAR3",        "Barre d'action 3") },
  { names = { "MultiBarRight" },              cat = "hud", label = T("F_BAR4",        "Barre d'action 4") },
  { names = { "MultiBarLeft" },               cat = "hud", label = T("F_BAR5",        "Barre d'action 5") },
  { names = { "MultiBar5" },                  cat = "hud", label = T("F_BAR6",        "Barre d'action 6") },
  { names = { "MultiBar6" },                  cat = "hud", label = T("F_BAR7",        "Barre d'action 7") },
  { names = { "MultiBar7" },                  cat = "hud", label = T("F_BAR8",        "Barre d'action 8") },
  { names = { "StanceBar" },                  cat = "hud", label = T("F_STANCE",      "Barre de posture") },
  { names = { "PetActionBar" },               cat = "hud", label = T("F_PETBAR",      "Barre du familier") },
  { names = { "MicroMenuContainer" },         cat = "hud", label = T("F_MICRO",       "Micro-menu") },
  { names = { "BagsBar" },                    cat = "hud", label = T("F_BAGSBAR",     "Barre des sacs") },
  { names = { "MinimapCluster" },             cat = "hud", label = T("F_MINIMAP",     "Minicarte") },
  { names = { "ObjectiveTrackerFrame" },      cat = "hud", label = T("F_OBJECTIVES",  "Suivi des objectifs") },
  { names = { "BuffFrame" },                  cat = "hud", label = T("F_BUFFS",       "Améliorations") },
  { names = { "DebuffFrame" },                cat = "hud", label = T("F_DEBUFFS",     "Affaiblissements") },
  { names = { "ChatFrame1" },                 cat = "hud", label = T("F_CHAT",        "Discussion (fenêtre 1)") },
  { names = { "GeneralDockManager" },         cat = "hud", label = T("F_CHATTABS",    "Onglets de discussion") },
  { names = { "PlayerCastingBarFrame" },      cat = "hud", label = T("F_CASTBAR",     "Barre d'incantation") },
  { names = { "MainStatusTrackingBarContainer" },      cat = "hud", label = T("F_XPBAR",  "Barre d'expérience / réputation") },
  { names = { "SecondaryStatusTrackingBarContainer" }, cat = "hud", label = T("F_XPBAR2", "Barre de suivi secondaire") },
  { names = { "EssentialCooldownViewer" },    cat = "hud", label = T("F_CDM1",        "Recharges : essentielles") },
  { names = { "UtilityCooldownViewer" },      cat = "hud", label = T("F_CDM2",        "Recharges : utilitaires") },
  { names = { "BuffIconCooldownViewer" },     cat = "hud", label = T("F_CDM3",        "Recharges : icônes d'amélioration") },
  { names = { "BuffBarCooldownViewer" },      cat = "hud", label = T("F_CDM4",        "Recharges : barres d'amélioration") },
  { names = { "ExtraAbilityContainer" },      cat = "hud", label = T("F_EXTRA",       "Bouton de technique supplémentaire") },
  { names = { "EncounterBar" },               cat = "hud", label = T("F_ENCOUNTER",   "Barre de rencontre / vol dynamique") },
  { names = { "UIWidgetTopCenterContainerFrame" }, cat = "hud", label = T("F_WIDGETS", "Objectifs de zone (haut centre)") },
  { names = { "TalkingHeadFrame" },           cat = "hud", label = T("F_TALKING",     "Tête parlante") },
  { names = { "DurabilityFrame" },            cat = "hud", label = T("F_DURABILITY",  "Durabilité") },
}

-- Repli si le core TibiSuite est absent (mode standalone) : les frames
-- principales connues des modules de la suite.
local SUITE_FALLBACK = {
  { name = "DTMainFrame",            label = "DailyTracker" },
  { name = "DGNMainFrame",           label = "DgnTracker" },
  { name = "LegTrackerMainFrame",    label = "LegTracker" },
  { name = "RNTMainFrame",           label = "RenTracker" },
  { name = "LvlHistoryMainFrame",    label = "LvlHistory" },
  { name = "WeeklyCompassFrame",     label = "WeeklyCompass" },
  { name = "XPBarContainer",         label = "XPBar" },
  { name = "RepBarContainer",        label = "RepBar" },
  { name = "LairLensAuditFrame",     label = "LairLens" },
  { name = "SkillTrackerMainFrame",  label = "SkillTracker" },
  { name = "PostBoxMainFrame",       label = "PostBox" },
  { name = "StatsMainFrame",         label = "Stats" },
}

-- Nom effectif d'une entree du catalogue Blizzard.
local function EntryName(e)
  for _, n in ipairs(e.names) do
    if OP.IsUsableFrame(_G[n]) then return n end
  end
  return e.names[1]
end

-- Index nom -> libelle / categorie (toutes les variantes de nom).
local known = {}
for _, e in ipairs(BLIZZARD) do
  for _, n in ipairs(e.names) do known[n] = { label = e.label, cat = e.cat } end
end

-- ============================================================================
-- ElvUI / EllesmereUI
-- ============================================================================
-- Prefixes des frames creees par chaque suite (EllesmereUI : releves dans les
-- sources installees chez Tibiscui, 2026-09). Et, par sous-addon charge, les
-- frames Blizzard dont la suite pilote elle-meme l'opacite ou qu'elle remplace.
-- Ce second tableau est DEDUIT des noms de sous-addons, pas verifie frame par
-- frame : l'option "Forcer" reste toujours disponible.
local SUITES = {
  {
    key = "ElvUI", addon = "ElvUI",
    prefixes = { "^ElvUI", "^ElvUF_", "^ElvLoot", "^ElvConfig" },
    blizzard = {},
  },
  {
    key = "EllesmereUI", addon = "EllesmereUI",
    prefixes = { "^Ellesmere", "^EUI", "^EAB", "^ERF", "^ERB", "^ECME", "^ECL", "^EWB" },
    blizzard = {
      EllesmereUIMinimap         = { "MinimapCluster" },
      EllesmereUIQuestTracker    = { "ObjectiveTrackerFrame" },
      EllesmereUIChat            = { "ChatFrame1", "GeneralDockManager" },
      EllesmereUIActionBars      = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight",
                                     "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7",
                                     "StanceBar", "PetActionBar", "MicroMenuContainer", "BagsBar" },
      EllesmereUIUnitFrames      = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "BossTargetFrameContainer" },
      EllesmereUIRaidFrames      = { "CompactRaidFrameContainer", "PartyFrame" },
      EllesmereUICooldownManager = { "EssentialCooldownViewer", "UtilityCooldownViewer",
                                     "BuffIconCooldownViewer", "BuffBarCooldownViewer" },
      EllesmereUIResourceBars    = { "PlayerCastingBarFrame" },
      EllesmereUIDataBars        = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" },
    },
  },
}

local activeSuites = {}      -- liste des suites chargees
local managedBlizzard = {}   -- [nomFrameBlizzard] = "EllesmereUI"

local function IsLoaded(name)
  return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) or false
end

function OP.DetectSuites()
  wipe(activeSuites); wipe(managedBlizzard)
  for _, s in ipairs(SUITES) do
    if IsLoaded(s.addon) then
      activeSuites[#activeSuites + 1] = s
      for sub, frames in pairs(s.blizzard) do
        if IsLoaded(sub) then
          for _, n in ipairs(frames) do managedBlizzard[n] = s.key end
        end
      end
    end
  end
end

-- "ElvUI" / "EllesmereUI" si la frame est geree par une de ces suites, sinon nil.
function OP.ManagedBy(name)
  if managedBlizzard[name] then return managedBlizzard[name] end
  for _, s in ipairs(activeSuites) do
    for _, pat in ipairs(s.prefixes) do
      if name:find(pat) then return s.key end
    end
  end
  return nil
end

function OP.ActiveSuites()
  local out = {}
  for _, s in ipairs(activeSuites) do out[#out + 1] = s.key end
  return out
end

-- ============================================================================
-- PROPRIETAIRE ET LIBELLE D'UNE FRAME
-- ============================================================================
local suiteNames   -- [frameName] = libelle de module TibiSuite

local function BuildSuiteNames()
  suiteNames = {}
  local TS = _G.TibiSuite
  if TS and TS.GetCatalog then
    for _, mod in ipairs(TS.GetCatalog()) do
      if mod.frameGlobal then suiteNames[mod.frameGlobal] = mod.addonName or mod.label end
    end
    suiteNames.TibiSuiteBar = T("F_TSBAR", "Barre TibiSuite")
  else
    for _, e in ipairs(SUITE_FALLBACK) do suiteNames[e.name] = e.label end
  end
  suiteNames.OpacityMainFrame = "Opacity"
end

-- Addon proprietaire : "Blizzard", "TibiSuite", un nom d'addon, ou nil.
local ownerCache = {}
function OP.OwnerOf(name)
  if known[name] then return "Blizzard" end
  if not suiteNames then BuildSuiteNames() end
  if suiteNames[name] then return "TibiSuite" end
  if ownerCache[name] ~= nil then return ownerCache[name] or nil end
  local owner = false
  if _G[name] ~= nil and issecurevariable then
    local ok, secure, taint = pcall(issecurevariable, name)
    if ok then
      if secure then owner = "Blizzard"
      elseif type(taint) == "string" and taint ~= "" then owner = taint end
    end
  end
  ownerCache[name] = owner
  return owner or nil
end

-- Libelle lisible pour la liste.
function OP.LabelOf(name)
  if known[name] then return known[name].label end
  if not suiteNames then BuildSuiteNames() end
  if suiteNames[name] then return suiteNames[name] end
  return name
end

-- ============================================================================
-- LISTES POUR LA FENETRE "AJOUTER"
-- Renvoie des groupes : { {title=, items={ {name=, label=, exists=, protected=} } } }
-- ============================================================================
local function Item(name, label)
  local f = _G[name]
  local usable = OP.IsUsableFrame(f)
  return {
    name = name, label = label or name, exists = usable,
    protected = usable and f.IsProtected and f:IsProtected() or false,
    managed = OP.ManagedBy(name),
  }
end

local function SmallOrHuge(f)
  local ok, w, h = pcall(function() return f:GetWidth(), f:GetHeight() end)
  if not ok or not w or not h then return true end
  if w < 4 or h < 4 then return true end
  local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
  if w >= sw * 0.98 and h >= sh * 0.98 then return true end   -- calques plein ecran
  return false
end

function OP.BuildCatalogGroups()
  if not suiteNames then BuildSuiteNames() end
  local groups = {}

  local win, hud = {}, {}
  for _, e in ipairs(BLIZZARD) do
    local it = Item(EntryName(e), e.label)
    if e.cat == "win" then win[#win + 1] = it else hud[#hud + 1] = it end
  end
  groups[#groups + 1] = { title = T("G_WIN", "Blizzard : fenêtres"), items = win }
  groups[#groups + 1] = { title = T("G_HUD", "Blizzard : interface"), items = hud }

  local suite = {}
  for name, label in pairs(suiteNames) do
    if name ~= "OpacityMainFrame" then suite[#suite + 1] = Item(name, label) end
  end
  table.sort(suite, function(a, b) return a.label < b.label end)
  groups[#groups + 1] = { title = "TibiSuite", items = suite }

  -- Autres addons : enfants directs et nommes de UIParent, ecrits par un addon.
  -- Chaque enfant est lu sous pcall : une frame interdite (12.x) ou bizarre
  -- ne doit jamais faire tomber la liste entiere.
  local byOwner = {}
  local function ScanChild(f)
    if not OP.IsUsableFrame(f) then return end   -- IsForbidden teste en premier
    local name = f:GetName()
    if name and OP.ValidName(name) and not known[name] and not suiteNames[name]
       and _G[name] == f and not SmallOrHuge(f) then
      local owner = OP.OwnerOf(name)
      if owner ~= "Blizzard" and owner ~= ADDON then
        owner = owner or T("G_UNKNOWN", "Addon inconnu")
        byOwner[owner] = byOwner[owner] or {}
        table.insert(byOwner[owner], Item(name, name))
      end
    end
  end
  local okList, children = pcall(function() return { UIParent:GetChildren() } end)
  if okList then
    for _, f in ipairs(children) do pcall(ScanChild, f) end
  end
  local owners = {}
  for o in pairs(byOwner) do owners[#owners + 1] = o end
  table.sort(owners)
  for _, o in ipairs(owners) do
    table.sort(byOwner[o], function(a, b) return a.name < b.name end)
    groups[#groups + 1] = { title = o, items = byOwner[o], addon = true }
  end
  return groups
end
