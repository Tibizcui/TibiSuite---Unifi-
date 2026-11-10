--[[============================================================================
  Anchor - Frames.lua
  ---------------------------------------------------------------------------
  Catalogue des fenetres deplacables, toutes versions confondues (Midnight,
  WoW Forever, Classic Era, TBC, Wrath, Cataclysm, Mists). Chaque entree
  liste plusieurs noms possibles : le premier qui existe gagne, une entree
  introuvable reste « en attente » sans erreur (fenetre pas encore chargee
  par Blizzard, ou absente de cette version du jeu). Aucun numero de version
  n'est teste : on regarde ce qui existe.

    names : noms globaux possibles
    cat   : "win" (fenetre) ou "loot" (butin)
    subs  : sous-fenetres qui couvrent le corps de la fenetre et avalent les
            clics (on les rend « poignees » de la fenetre principale)
    place : "proxy" = la fenetre ne prend pas la souris (lancers de des) :
            elle se place avec le mode Placement (Loot.lua)
    skip  : fonction(frame) -> true pour ne pas imposer la position (ex.
            carte du monde agrandie)

  COHABITATION (lue dans le code d'ElvUI 15.26 et d'EllesmereUI 9.8.3) :
    - BlizzMove ou MoveAny charges : Anchor s'efface (sauf « Forcer »).
    - EllesmereUI Shifter actif (EllesmereUIDB.shifterEnabled) : les fenetres
      de SA liste lui appartiennent ; Anchor garde les autres (le butin, par
      exemple). Ses fenetres de butin (shifterLootUnlock) idem.
    - ElvUI : butin remplace (ElvLootFrame), lancers de des places par ElvUI
      (PositionGroupLootContainer), sacs remplaces (ElvUI_ContainerFrame).
    - Frame ancree sur un « mover » ElvUI : laissee a ElvUI.
  Valide en jeu par Tibiscui le 2026-11-10 (7.5.0).
============================================================================]]

local ADDON, AN = ...
local T = AN.T

local function NoMaxMap(f)
  return f.IsMaximized and select(2, pcall(f.IsMaximized, f)) == true
end

AN.CATALOG = {
  -- Personnage et progression
  { names = { "CharacterFrame" }, cat = "win", label = T("F_CHARACTER", "Personnage"),
    subs = { "PaperDollFrame", "ReputationFrame", "TokenFrame", "PetPaperDollFrame", "SkillFrame", "HonorFrame" } },
  { names = { "PlayerSpellsFrame" },          cat = "win", label = T("F_SPELLS", "Talents et sorts") },
  { names = { "SpellBookFrame" },             cat = "win", label = T("F_SPELLBOOK", "Livre de sorts") },
  { names = { "PlayerTalentFrame", "TalentFrame" }, cat = "win", label = T("F_TALENTS", "Talents") },
  { names = { "ProfessionsBookFrame" },       cat = "win", label = T("F_PROFBOOK", "Livre des métiers") },
  { names = { "ProfessionsFrame" },           cat = "win", label = T("F_PROFESSIONS", "Artisanat") },
  { names = { "TradeSkillFrame" },            cat = "win", label = T("F_TRADESKILL", "Métier") },
  { names = { "CraftFrame" },                 cat = "win", label = T("F_CRAFT", "Artisanat (Classic)") },
  { names = { "ClassTrainerFrame" },          cat = "win", label = T("F_TRAINER", "Maître de classe") },
  { names = { "AchievementFrame" },           cat = "win", label = T("F_ACHIEV", "Hauts faits") },
  { names = { "CollectionsJournal" },         cat = "win", label = T("F_COLLECTIONS", "Collections"),
    subs = { "MountJournal", "PetJournal", "ToyBox", "HeirloomsJournal", "WardrobeCollectionFrame" } },
  { names = { "WardrobeFrame" },              cat = "win", label = T("F_WARDROBE", "Transmogrification") },
  { names = { "TransmogFrame" },              cat = "win", label = T("F_TRANSMOG", "Transmogrification (12.x)") },
  { names = { "EncounterJournal" },           cat = "win", label = T("F_JOURNAL", "Guide de l'aventurier") },
  { names = { "WeeklyRewardsFrame" },         cat = "win", label = T("F_VAULT", "Grande chambre forte") },
  { names = { "MajorFactionRenownFrame" },    cat = "win", label = T("F_RENOWN", "Renom") },
  { names = { "ExpansionLandingPage" },       cat = "win", label = T("F_LANDING", "Page de l'extension") },
  { names = { "GenericTraitFrame" },          cat = "win", label = T("F_TRAITS", "Arbres de talents annexes") },
  { names = { "DelvesCompanionConfigurationFrame" }, cat = "win", label = T("F_DELVES_COMP", "Compagnon des gouffres") },
  { names = { "DelvesDifficultyPickerFrame" }, cat = "win", label = T("F_DELVES_DIFF", "Difficulté des gouffres") },
  { names = { "ChallengesKeystoneFrame" },    cat = "win", label = T("F_KEYSTONE", "Clé mythique (insertion)") },
  { names = { "InspectFrame" },               cat = "win", label = T("F_INSPECT", "Inspection") },
  { names = { "LegacySystemFrame" },          cat = "win", label = T("F_LEGACY", "Héritage (Forever)") },

  -- Groupe et social
  { names = { "PVEFrame" },                   cat = "win", label = T("F_PVE", "Recherche de groupe") },
  { names = { "LFGParentFrame" },             cat = "win", label = T("F_LFG_OLD", "Recherche de groupe (Classic / Forever)"),
    subs = { "LFGBrowseFrame", "LFGListingFrame", "LFGWhoListFrame" } },
  { names = { "PVPFrame", "PVPParentFrame" }, cat = "win", label = T("F_PVP", "JcJ (Classic)") },
  { names = { "FriendsFrame" },               cat = "win", label = T("F_FRIENDS", "Social") },
  { names = { "SocialUIFrame" },              cat = "win", label = T("F_SOCIAL", "Social (12.x)") },
  { names = { "CommunitiesFrame" },           cat = "win", label = T("F_GUILD", "Guilde et communautés") },
  { names = { "GuildFrame" },                 cat = "win", label = T("F_GUILD_OLD", "Guilde (Classic)") },
  { names = { "GuildBankFrame" },             cat = "win", label = T("F_GUILDBANK", "Banque de guilde") },
  { names = { "CalendarFrame" },              cat = "win", label = T("F_CALENDAR", "Calendrier") },

  -- Monde et quetes
  { names = { "WorldMapFrame" },              cat = "win", label = T("F_WORLDMAP", "Carte du monde"), skip = NoMaxMap },
  { names = { "QuestLogFrame" },              cat = "win", label = T("F_QUESTLOG", "Journal de quêtes (Classic)") },
  { names = { "GossipFrame" },                cat = "win", label = T("F_GOSSIP", "Dialogues des PNJ") },
  { names = { "QuestFrame" },                 cat = "win", label = T("F_QUEST", "Quêtes (PNJ)") },
  { names = { "ItemTextFrame" },              cat = "win", label = T("F_ITEMTEXT", "Livres et lettres") },
  { names = { "FlightMapFrame" },             cat = "win", label = T("F_FLIGHTMAP", "Carte des vols") },
  { names = { "TaxiFrame" },                  cat = "win", label = T("F_TAXI", "Maître de vol") },

  -- Commerce et inventaire
  { names = { "ContainerFrameCombinedBags" }, cat = "win", label = T("F_BAGS", "Sacs (combinés)"), bags = true },
  { names = { "ContainerFrame1" },            cat = "win", label = T("F_BAG1", "Sac à dos (séparé)"), bags = true },
  { names = { "BankFrame" },                  cat = "win", label = T("F_BANK", "Banque"), bags = true },
  { names = { "MerchantFrame" },              cat = "win", label = T("F_MERCHANT", "Marchand") },
  { names = { "MailFrame" },                  cat = "win", label = T("F_MAIL", "Courrier") },
  { names = { "OpenMailFrame" },              cat = "win", label = T("F_OPENMAIL", "Lettre ouverte") },
  { names = { "AuctionHouseFrame", "AuctionFrame" }, cat = "win", label = T("F_AH", "Hôtel des ventes") },
  { names = { "BlackMarketFrame" },           cat = "win", label = T("F_BLACKMARKET", "Marché noir") },
  { names = { "TradeFrame" },                 cat = "win", label = T("F_TRADE", "Échange") },
  { names = { "ProfessionsCustomerOrdersFrame" }, cat = "win", label = T("F_ORDERS", "Commandes d'artisanat") },
  { names = { "ItemUpgradeFrame" },           cat = "win", label = T("F_UPGRADE", "Amélioration d'objets") },
  { names = { "ItemInteractionFrame" },       cat = "win", label = T("F_CATALYST", "Catalyseur / interactions d'objets") },
  { names = { "ItemSocketingFrame" },         cat = "win", label = T("F_SOCKET", "Châsses") },
  { names = { "ScrappingMachineFrame" },      cat = "win", label = T("F_SCRAP", "Machine de recyclage") },
  { names = { "DressUpFrame" },               cat = "win", label = T("F_DRESSUP", "Cabine d'essayage") },
  { names = { "StableFrame", "PetStableFrame" }, cat = "win", label = T("F_STABLE", "Écurie") },
  { names = { "TabardFrame" },                cat = "win", label = T("F_TABARD", "Tabard") },
  { names = { "GuildRegistrarFrame" },        cat = "win", label = T("F_REGISTRAR", "Création de guilde") },

  -- Systeme
  { names = { "SettingsPanel", "InterfaceOptionsFrame" }, cat = "win", label = T("F_SETTINGS", "Options du jeu") },
  { names = { "VideoOptionsFrame" },          cat = "win", label = T("F_VIDEO", "Options vidéo (Classic)") },
  { names = { "KeyBindingFrame" },            cat = "win", label = T("F_BINDINGS", "Raccourcis (Classic)") },
  { names = { "AddonList" },                  cat = "win", label = T("F_ADDONS", "Liste des addons") },
  { names = { "MacroFrame" },                 cat = "win", label = T("F_MACRO", "Macros") },
  { names = { "ChatConfigFrame" },            cat = "win", label = T("F_CHATCFG", "Configuration du chat") },
  { names = { "HelpFrame" },                  cat = "win", label = T("F_HELP", "Aide") },
  { names = { "CooldownViewerSettings" },     cat = "win", label = T("F_CDM", "Gestionnaire de temps de recharge") },

  -- Butin
  { names = { "LootFrame" },                  cat = "loot", label = T("F_LOOT", "Fenêtre de butin") },
  { names = { "GroupLootContainer", "GroupLootFrame1" }, cat = "loot", place = "proxy",
    label = T("F_ROLLS", "Lancers de dés (Besoin / Cupidité)"), defW = 300, defH = 80, defY = 340 },
  { names = { "BonusRollFrame" },             cat = "loot", place = "proxy",
    label = T("F_BONUSROLL", "Jet de bonus"), defW = 330, defH = 120, defY = 240 },
}

-- Index par nom (tous les noms possibles pointent vers leur entree)
AN.ENTRY = {}
for _, e in ipairs(AN.CATALOG) do
  for _, n in ipairs(e.names) do AN.ENTRY[n] = e end
end

-- Nom reellement utilise par une entree sur ce client (le premier qui existe).
function AN.NameOf(e)
  for _, n in ipairs(e.names) do
    if type(_G[n]) == "table" then return n end
  end
  return nil
end

-- ============================================================================
-- COHABITATION
-- ============================================================================
local function Loaded(name)
  local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
  if not f then return false end
  local ok, v = pcall(f, name)
  return ok and v and true or false
end
AN.AddonLoaded = Loaded

-- Fenetres du Shifter d'EllesmereUI (liste relevee dans
-- EllesmereUIQoL_Shifter.lua, version 9.8.3). A RELIRE a chaque mise a jour
-- d'EllesmereUI : une fenetre ajoutee chez eux et pas ici serait deplacee
-- par les deux addons.
local SHIFTER = {}
for _, n in ipairs({
  "ContainerFrameCombinedBags", "CharacterFrame", "FriendsFrame", "PVEFrame", "DressUpFrame",
  "BankFrame", "MailFrame", "OpenMailFrame", "GossipFrame", "QuestFrame", "MerchantFrame",
  "AddonList", "ChatConfigFrame", "ItemTextFrame", "LFGDungeonReadyDialog", "GuildInviteFrame",
  "TabardFrame", "GuildRegistrarFrame", "SettingsPanel",
  "AchievementFrame", "AlliedRacesFrame", "ArchaeologyFrame", "ArtifactFrame", "AuctionHouseFrame",
  "BlackMarketFrame", "CalendarFrame", "CalendarViewEventFrame", "ChallengesKeystoneFrame",
  "ChromieTimeFrame", "ClassTalentFrame", "CollectionsJournal", "WardrobeFrame", "CommunitiesFrame",
  "CooldownViewerSettings", "EncounterJournal", "ExpansionLandingPage", "FlightMapFrame",
  "GenericTraitFrame", "LFGParentFrame", "GuildBankFrame", "GuildControlUI", "InspectFrame",
  "ItemInteractionFrame", "ItemSocketingFrame", "ItemUpgradeFrame", "LegacySystemFrame", "MacroFrame",
  "MajorFactionRenownFrame", "PlayerSpellsFrame", "ProfessionsFrame", "ProfessionsBookFrame",
  "ProfessionsCustomerOrdersFrame", "ScrappingMachineFrame", "SocialUIFrame", "StableFrame",
  "PetStableFrame", "CurrencyTransferMenu", "ClassTrainerFrame", "TradeSkillFrame", "TransmogFrame",
  "WeeklyRewardsFrame", "WorldMapFrame", "HousingDashboardFrame", "DelvesCompanionConfigurationFrame",
  "DelvesCompanionAbilityListFrame", "DelvesDifficultyPickerFrame",
}) do SHIFTER[n] = true end
local SHIFTER_LOOT = { GroupLootContainer = true, BonusRollFrame = true }

-- Addon qui deplace deja les fenetres : Anchor s'efface (sauf « Forcer »).
function AN.Conflict()
  if Loaded("BlizzMove") then return "BlizzMove" end
  if Loaded("MoveAny") then return "MoveAny" end
  return nil
end

local function ShifterOn()
  return Loaded("EllesmereUIQoL") and type(EllesmereUIDB) == "table" and EllesmereUIDB.shifterEnabled and true or false
end
local function ShifterLootOn()
  return Loaded("EllesmereUIQoL") and type(EllesmereUIDB) == "table" and EllesmereUIDB.shifterLootUnlock and true or false
end

-- Vrai si la frame est ancree sur un mover d'ElvUI (ou sur son conteneur).
local function OnElvMover(f)
  if not Loaded("ElvUI") then return false end
  local ok, n = pcall(f.GetNumPoints, f)
  if not ok or not AN.Safe(n) or not n or n < 1 then return false end
  local ok2, _, rel = pcall(f.GetPoint, f, 1)
  if not ok2 or not AN.Safe(rel) or type(rel) ~= "table" then return false end
  local okN, rn = pcall(rel.GetName, rel)
  rn = okN and AN.Safe(rn) and rn or nil
  if rn and (rn:find("Mover$") or rn:find("^ElvUI") or rn:find("^ElvLoot")) then return true end
  return false
end

-- Qui gere deja cette fenetre ? Renvoie un nom d'addon, ou nil (Anchor peut).
function AN.ManagedBy(name, f)
  if TibiAnchorDB and TibiAnchorDB.force then return nil end
  local e = AN.ENTRY[name]
  if ShifterOn() and SHIFTER[name] then return "EllesmereUI (Shifter)" end
  if ShifterLootOn() and SHIFTER_LOOT[name] then return "EllesmereUI (Shifter)" end
  if Loaded("ElvUI") then
    if name == "LootFrame" and _G.ElvLootFrame then return "ElvUI" end
    if (name == "GroupLootContainer" or name == "GroupLootFrame1") then return "ElvUI" end
    if e and e.bags and _G.ElvUI_ContainerFrame then return "ElvUI" end
  end
  if e and e.bags and Loaded("EllesmereUIBags") and _G.EUI_MainBagFrame then return "EllesmereUI" end
  if f and OnElvMover(f) then return "ElvUI" end
  return nil
end
