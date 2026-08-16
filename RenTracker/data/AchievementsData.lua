-- ================================================================
-- RenTracker - AchievementsData.lua
-- Tous les Hauts Faits de réputation, classés par extension
-- Source : Wowhead / Warcraft Wiki
-- ================================================================

RenTrackerAchievements = RenTrackerAchievements or {}

RenTrackerAchievements = {

  -- ============================================================
  -- VANILLA (1.x)
  -- ============================================================
  Vanilla = {
    label = "Classic",
    achievements = {
      { id=5,      name="Ambassadeur de l'Alliance",           faction="Alliance" },
      { id=6,      name="Ambassadeur de la Horde",             faction="Horde" },
      { id=639,    name="Le Diplomate",                        faction="Neutre" },
      { id=2336,   name="Tous des malades",                    faction="Neutre" },
      { id=42,     name="Les Zandalar",                        faction="Neutre" },
      { id=726,    name="Héros d'Azeroth",                     faction="Neutre" },
      { id=878,    name="La Brasserie Thorium",                faction="Neutre" },
      { id=879,    name="Les Hydraxiens Aquatiques",           faction="Neutre" },
      { id=880,    name="Le Cercle Cénarion",                  faction="Neutre" },
      { id=881,    name="L'Aurore Argentée",                   faction="Neutre" },
      { id=882,    name="Ravenholdt",                          faction="Neutre" },
      { id=883,    name="Guilde des Voleurs de Laquais",       faction="Neutre" },
      { id=884,    name="La Foire de Sombrelune",              faction="Neutre" },
      { id=885,    name="Cartel Gantrepression - Cabestan",    faction="Neutre" },
      { id=886,    name="Cartel Gantrepression - Gadgetzan",   faction="Neutre" },
      { id=887,    name="Cartel Gantrepression - Long-Guet",   faction="Neutre" },
      { id=888,    name="Cartel Gantrepression - Baie-du-Butin", faction="Neutre" },
      { id=889,    name="La Voile sanglante",                  faction="Neutre" },
    },
  },

  -- ============================================================
  -- THE BURNING CRUSADE (2.x)
  -- ============================================================
  TheBurningCrusade = {
    label = "The Burning Crusade",
    achievements = {
      { id=890,    name="L'Aldor",                             faction="Neutre" },
      { id=891,    name="Les Scryers",                         faction="Neutre" },
      { id=892,    name="Gardien de Cénarion",                 faction="Neutre" },
      { id=893,    name="L'Expédition Cénarienne",             faction="Neutre" },
      { id=894,    name="L'Assemblée du Sha'tar",              faction="Neutre" },
      { id=895,    name="Le Consortium",                       faction="Neutre" },
      { id=896,    name="Les Kurenai",                         faction="Alliance" },
      { id=897,    name="Les Mag'har",                         faction="Horde" },
      { id=898,    name="La Cité Basse",                       faction="Neutre" },
      { id=899,    name="L'Offensive du Soleil Brisé",         faction="Neutre" },
      { id=900,    name="Violeurs de Crypto",                  faction="Neutre" },
      { id=901,    name="Les Shattered Sun Offensive",         faction="Neutre" },
      { id=902,    name="Les Ogri'la",                         faction="Neutre" },
      { id=903,    name="Les Sha'tari Protecteurs du Ciel",    faction="Neutre" },
      { id=904,    name="Les Sporeggar",                       faction="Neutre" },
    },
  },

  -- ============================================================
  -- WRATH OF THE LICH KING (3.x)
  -- ============================================================
  WrathOfTheLichKing = {
    label = "Wrath of the Lich King",
    achievements = {
      { id=910,    name="La Croisade Argentée",                faction="Neutre" },
      { id=911,    name="L'Accord de Wyrmrest",                faction="Neutre" },
      { id=912,    name="Chevaliers de la Lame d'Ébène",       faction="Neutre" },
      { id=913,    name="Le Kirin Tor",                        faction="Neutre" },
      { id=914,    name="Les Fils de Hodir",                   faction="Neutre" },
      { id=915,    name="L'Expédition de l'Alliance",          faction="Alliance" },
      { id=916,    name="L'Expédition de la Horde",            faction="Horde" },
      { id=917,    name="La Tribu Taunka",                     faction="Horde" },
      { id=918,    name="Le Front du Nord",                    faction="Alliance" },
      { id=919,    name="Les Guardiens du Caveau",             faction="Neutre" },
      { id=920,    name="Les Lances Brisées",                  faction="Neutre" },
      { id=921,    name="Les Oracles",                         faction="Neutre" },
      { id=922,    name="Les Frenzyheart Tribe",               faction="Neutre" },
      { id=1280,   name="Terreur du Nécrocrâne",               faction="Neutre" },
    },
  },

  -- ============================================================
  -- CATACLYSME (4.x)
  -- ============================================================
  Cataclysme = {
    label = "Cataclysme",
    achievements = {
      { id=4944,   name="Les Gardiens d'Hyjal",                faction="Neutre" },
      { id=4945,   name="Thérazane",                           faction="Neutre" },
      { id=4946,   name="Ramkahen",                            faction="Neutre" },
      { id=4947,   name="L'Anneau de Terre",                   faction="Neutre" },
      { id=4948,   name="Clan Martelorage",                    faction="Alliance" },
      { id=4949,   name="Clan Mâchemarteau",                   faction="Horde" },
      { id=5351,   name="Les Avengers d'Hyjal",                faction="Neutre" },
      { id=5352,   name="Fils du Feu Nourricier",              faction="Neutre" },
    },
  },

  -- ============================================================
  -- MISTS OF PANDARIA (5.x)
  -- ============================================================
  MistsOfPandaria = {
    label = "Mists of Pandaria",
    achievements = {
      { id=6941,   name="Le Lotus d'Or",                       faction="Neutre" },
      { id=6942,   name="Le Klaxxi",                           faction="Neutre" },
      { id=6943,   name="Le Shado-Pan",                        faction="Neutre" },
      { id=6944,   name="Les Célestes d'Août",                 faction="Neutre" },
      { id=6945,   name="L'Ordre du Serpent-Nuage",            faction="Neutre" },
      { id=6946,   name="Les Laboureurs",                      faction="Neutre" },
      { id=6947,   name="Les Pêcheurs Anglers",                faction="Neutre" },
      { id=7754,   name="Le Projet Brasserie Kirin Tor",       faction="Neutre" },
      { id=7755,   name="L'Alliance Shado-Pan",                faction="Neutre" },
      { id=8307,   name="Le Poi Kirin'ji",                     faction="Neutre" },
    },
  },

  -- ============================================================
  -- WARLORDS OF DRAENOR (6.x)
  -- ============================================================
  WarlordsOfDraenor = {
    label = "Warlords of Draenor",
    achievements = {
      { id=9476,   name="Les Proscrits Arakkoa",               faction="Neutre" },
      { id=9477,   name="Le Conseil des Exarques",             faction="Alliance" },
      { id=9478,   name="Orcs Loup-de-Givre",                  faction="Horde" },
      { id=9479,   name="Société de Préservation Motobroyeur", faction="Neutre" },
      { id=10095,  name="L'Ordre des Éveillés",                faction="Neutre" },
      { id=10096,  name="Sombreterre",                         faction="Neutre" },
      { id=10097,  name="Chasseurs de Reliques",               faction="Neutre" },
    },
  },

  -- ============================================================
  -- LEGION (7.x)
  -- ============================================================
  Legion = {
    label = "Legion",
    achievements = {
      { id=10762,  name="Les Déchus",                          faction="Neutre" },
      { id=10763,  name="Les Valarjar",                        faction="Neutre" },
      { id=10764,  name="La Tisserrêve",                       faction="Neutre" },
      { id=10765,  name="La Tribu de Haut-Roc",               faction="Neutre" },
      { id=10766,  name="La Cour de Farondis",                 faction="Neutre" },
      { id=10767,  name="Les Gardiennes",                      faction="Neutre" },
      { id=11193,  name="Les Armées de Légionfall",            faction="Neutre" },
      { id=11609,  name="L'Armée de la Lumière",               faction="Neutre" },
      { id=11610,  name="Les Chasseurs de Vulan",              faction="Neutre" },
      { id=11611,  name="Les Archivistes du Codex",            faction="Neutre" },
    },
  },

  -- ============================================================
  -- BATTLE FOR AZEROTH (8.x)
  -- ============================================================
  BattleForAzeroth = {
    label = "Battle for Azeroth",
    achievements = {
      { id=12942,  name="Champions d'Azeroth",                 faction="Neutre" },
      { id=12831,  name="La 7ème Légion",                      faction="Alliance" },
      { id=12832,  name="Le Lien Sacré",                       faction="Horde" },
      { id=12944,  name="Chercheurs Tortollan",                faction="Neutre" },
      { id=13181,  name="La Résistance de Rouillomec",         faction="Neutre" },
      { id=13517,  name="L'Alliance Waveblade",                faction="Alliance" },
      { id=13518,  name="Les Zandalari",                       faction="Horde" },
      { id=13519,  name="Les Unshackled",                      faction="Horde" },
      { id=13520,  name="Rustbolt Resistance",                 faction="Neutre" },
      { id=13546,  name="Les Rajani",                          faction="Neutre" },
      { id=13547,  name="Les Uldum Accord",                    faction="Neutre" },
    },
  },

  -- ============================================================
  -- SHADOWLANDS (9.x)
  -- ============================================================
  Shadowlands = {
    label = "Shadowlands",
    achievements = {
      { id=14731,  name="Les Kyriens",                         faction="Neutre" },
      { id=14732,  name="Les Nécrolords",                      faction="Neutre" },
      { id=14733,  name="Les Faes nocturnes",                  faction="Neutre" },
      { id=14734,  name="Les Venthyr",                         faction="Neutre" },
      { id=14886,  name="Les Mawtribes",                       faction="Neutre" },
      { id=15022,  name="L'Ascendance",                        faction="Neutre" },
      { id=15024,  name="Les Fiefs de l'Ombrechaîne",         faction="Neutre" },
      { id=15025,  name="La Couronne de Guimbrecoiffe",        faction="Neutre" },
    },
  },

  -- ============================================================
  -- DRAGONFLIGHT (10.x)
  -- ============================================================
  Dragonflight = {
    label = "Dragonflight",
    achievements = {
      { id=16580,  name="L'Expédition Dragonscaille",          faction="Neutre" },
      { id=16579,  name="Les Tuskarr d'Iskaara",               faction="Neutre" },
      { id=16578,  name="Les Centaures Maruuk",                faction="Neutre" },
      { id=16577,  name="L'Accord de Valdrakken",              faction="Neutre" },
      { id=17739,  name="Les Niffen de Loamm",                 faction="Neutre" },
      { id=17741,  name="Les Gardiennes du Rêve",              faction="Neutre" },
    },
  },

  -- ============================================================
  -- THE WAR WITHIN (11.x)
  -- ============================================================
  TheWarWithin = {
    label = "The War Within",
    achievements = {
      { id=19478,  name="Le Conseil de Dornogal",              faction="Neutre" },
      { id=19479,  name="L'Assemblée des Profondeurs",         faction="Neutre" },
      { id=19480,  name="Les Arathi de Sacré-Déclin",          faction="Neutre" },
      { id=19481,  name="Les Fils Tranchés",                   faction="Neutre" },
    },
  },

  -- ============================================================
  -- MIDNIGHT (12.x)
  -- ============================================================
  Midnight = {
    label = "Midnight",
    achievements = {
      { id=21002,  name="La Cour de Lune-d'Argent",            faction="Neutre" },
      { id=21003,  name="La Tribu Amani",                      faction="Neutre" },
      { id=21004,  name="Les Hara'ti",                         faction="Neutre" },
      { id=21005,  name="La Singularité",                      faction="Neutre" },
    },
  },

  -- ============================================================
  -- SERIE "X Réputations Exaltées" (global, cross-extension)
  -- ============================================================
  ExaltedSeries = {
    label = "Réputations Exaltées (série)",
    achievements = {
      { id=639,    name="Exalté avec 5 factions",              faction="Neutre" },
      { id=877,    name="Exalté avec 10 factions",             faction="Neutre" },
      { id=1011,   name="Exalté avec 20 factions",             faction="Neutre" },
      { id=1015,   name="Exalté avec 40 factions",             faction="Neutre" },
      { id=5723,   name="Exalté avec 50 factions",             faction="Neutre" },
      { id=6742,   name="Exalté avec 60 factions",             faction="Neutre" },
      { id=8730,   name="Exalté avec 70 factions",             faction="Neutre" },
      { id=12864,  name="Exalté avec 80 factions",             faction="Neutre" },
      { id=12866,  name="Exalté avec 100 factions",            faction="Neutre" },
    },
  },
}
