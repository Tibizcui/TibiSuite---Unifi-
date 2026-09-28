-- ================================================================
-- DailyTracker - Data : Midnight (12.x)
-- Activités quotidiennes, hebdomadaires et uniques
-- ================================================================

DailyTrackerData = DailyTrackerData or {}

DailyTrackerData["Midnight"] = {
  label    = "Midnight",
  patch    = "12.1",
  color    = {r=0.58, g=0.30, b=0.95},
  factions = {

    -- ----------------------------------------------------------------
    -- Cour de Lune-d'Argent (ID 2710) - Bois des Chants Éternels
    -- ----------------------------------------------------------------
    {
      id       = 2710,
      category = "principale",
      name     = "Cour de Lune-d'Argent",
      zone     = "Bois des Chants Éternels",
      color    = {r=0.95, g=0.55, b=0.75},
      quests   = {
        { name="En haute estime",
          npc="Seigneur Saltheril", coords="43.4, 47.4", zone="Bois des Chants Éternels",
          rep=1500, type="weekly", questID=91629, mapID=2395,
          tip="Choisissez votre sous-faction noble pour la semaine." },
        { name="Renforcement des pierres runiques : Chevaliers de sang", group="runestones",
          npc="Représentant des Chevaliers du Sang", coords="43.4, 47.4", zone="Bois des Chants Éternels",
          rep=1000, type="weekly", questID=90574, mapID=2395,
          tip="Disponible après avoir choisi les Chevaliers du Sang comme sous-faction." },
        { name="Renforcement des pierres runiques : Pérégrins", group="runestones",
          npc="Représentant des Éclaireurs", coords="43.4, 47.4", zone="Bois des Chants Éternels",
          rep=1000, type="weekly", questID=90575, mapID=2395,
          tip="Disponible après avoir choisi les Éclaireurs comme sous-faction." },
        { name="Renforcement des pierres runiques : Magistères", group="runestones",
          npc="Représentant des Mages", coords="43.4, 47.4", zone="Bois des Chants Éternels",
          rep=1000, type="weekly", questID=90573, mapID=2395,
          tip="Disponible après avoir choisi les Mages comme sous-faction." },
        { name="Renforcement des pierres runiques : Ombres de l’Allée", group="runestones",
          npc="Représentant des Ombres du Carrefour", coords="43.4, 47.4", zone="Bois des Chants Éternels",
          rep=1000, type="weekly", questID=90576, mapID=2395,
          tip="Disponible après avoir choisi les Ombres du Carrefour comme sous-faction." },
        { name="Quête de donjon hebdomadaire", shared="mid_dungeon",
          npc="Halduron Luisaile", coords="50.4, 38.2", zone="Lune-d'Argent",
          rep=1500, type="weekly", questID=nil, mapID=2372,
          tip="Terminez un donjon Midnight (difficulté libre, même Donjon Compagnon)." },
        { name="Campagne : Bois des Chants Éternels",
          npc="Jonas Everdawn", coords="50.4, 38.2", zone="Lune-d'Argent",
          rep=5000, type="onetime", questID=nil, mapID=nil,
          tip="Compléter la campagne principale des Bois des Chants Éternels." },
        { name="Objets de lore : Bois des Chants Éternels",
          npc="Objets interactifs", coords="43.4, 47.4", zone="Bois des Chants Éternels",
          rep=250, type="onetime", questID=nil, mapID=2395,
          tip="Chaque objet de lore collecté donne 250 rep. À faire une seule fois." },
      },
    },

    -- ----------------------------------------------------------------
    -- Tribu Amani (ID 2696) - Zul'Aman
    -- ----------------------------------------------------------------
    {
      id       = 2696,
      category = "secondaire",
      name     = "Tribu Amani",
      zone     = "Zul'Aman",
      color    = {r=0.85, g=0.42, b=0.10},
      quests   = {
        { name="Offrandes abondantes",
          npc="Magovu", coords="45.8, 65.8", zone="Zul'Aman",
          rep=1000, type="weekly", questID=89507, mapID=2437,
          tip="Gagnez 20 000 points lors des événements Abondance dans Zul'Aman." },
        { name="Quête de donjon hebdomadaire", shared="mid_dungeon",
          npc="Halduron Luisaile", coords="50.4, 38.2", zone="Lune-d'Argent",
          rep=1500, type="weekly", questID=nil, mapID=2372,
          tip="Terminez un donjon Midnight (difficulté libre, même Donjon Compagnon)." },
        { name="Quêtes quotidiennes de zone", wq=true,
          npc="Officiers Amani", coords="45.8, 65.8", zone="Zul'Aman",
          rep=75, type="daily", questID=nil, mapID=2437,
          tip="Quêtes du monde et Missions Spéciales dans Zul'Aman." },
        { name="Campagne principale : Zul'Aman",
          npc="Chef de la Tribu Amani", coords="45.8, 65.8", zone="Zul'Aman",
          rep=5000, type="onetime", questID=nil, mapID=2437,
          tip="Compléter la campagne principale de Zul'Aman. Ne se répète pas." },
        { name="Objets de lore : Zul'Aman",
          npc="Objets interactifs", coords="45.8, 65.8", zone="Zul'Aman",
          rep=250, type="onetime", questID=nil, mapID=2437,
          tip="Collectez les objets de lore dispersés dans Zul'Aman." },
        { name="Télescopes des Sommets",
          npc="Pic de Zul'Aman", coords="45.8, 65.8", zone="Zul'Aman",
          rep=100, type="onetime", questID=nil, mapID=2437,
          tip="Placez les télescopes sur les plus hauts pics de la zone." },
      },
    },

    -- ----------------------------------------------------------------
    -- Hara'ti (ID 2704) - Harandar
    -- ----------------------------------------------------------------
    {
      id       = 2704,
      category = "secondaire",
      name     = "Hara'ti",
      zone     = "Harandar",
      color    = {r=0.30, g=0.80, b=0.55},
      quests   = {
        { name="Légendes oubliées",
          npc="Zur'ashar Kassameh", coords="54.2, 53.0", zone="Harandar",
          rep=1000, type="weekly", questID=89268, mapID=2413,
          tip="Choisissez une relique Hara'ti et jouez son histoire. Choix partagé avec la Warband." },
        { name="Quête de donjon hebdomadaire", shared="mid_dungeon",
          npc="Halduron Luisaile", coords="50.4, 38.2", zone="Lune-d'Argent",
          rep=1500, type="weekly", questID=nil, mapID=2372,
          tip="Terminez un donjon Midnight (difficulté libre, même Donjon Compagnon)." },
        { name="Quêtes quotidiennes de zone", wq=true,
          npc="Membres Hara'ti", coords="51.0, 50.8", zone="Harandar",
          rep=75, type="daily", questID=nil, mapID=2413,
          tip="Quêtes du monde et Missions Spéciales dans Harandar." },
        { name="Campagne principale : Harandar",
          npc="Naynar", coords="51.0, 50.8", zone="Harandar",
          rep=5000, type="onetime", questID=nil, mapID=2413,
          tip="Compléter la campagne principale de Harandar." },
        { name="Objets de lore : Harandar",
          npc="Objets interactifs", coords="51.0, 50.8", zone="Harandar",
          rep=250, type="onetime", questID=nil, mapID=2413,
          tip="Collectez les objets de lore dispersés dans Harandar." },
        { name="Télescopes des Sommets",
          npc="Pic de Harandar", coords="51.0, 50.8", zone="Harandar",
          rep=100, type="onetime", questID=nil, mapID=2413,
          tip="Placez les télescopes sur les plus hauts pics de Harandar." },
      },
    },

    -- ----------------------------------------------------------------
    -- La Singularité (ID 2699) - Tempête du Vide
    -- ----------------------------------------------------------------
    {
      id       = 2699,
      category = "secondaire",
      name     = "La Singularité",
      zone     = "Tempête du Vide",
      color    = {r=0.55, g=0.30, b=0.95},
      quests   = {
        { name="Assaut de Fulgarion",
          npc="Commandant de la Singularité", coords="26.7, 68.2", zone="Tempête du Vide",
          rep=1000, type="weekly", questID=93892, mapID=2405,
          tip="Participez à l'assaut de Fulgarion contre l'Hôte Dévorant." },
        { name="Quête de donjon hebdomadaire", shared="mid_dungeon",
          npc="Halduron Luisaile", coords="50.4, 38.2", zone="Lune-d'Argent",
          rep=1500, type="weekly", questID=nil, mapID=2372,
          tip="Terminez un donjon Midnight (difficulté libre, même Donjon Compagnon)." },
        { name="Quêtes quotidiennes de zone", wq=true,
          npc="Agents de la Singularité", coords="52.6, 72.8", zone="Tempête du Vide",
          rep=75, type="daily", questID=nil, mapID=2405,
          tip="Quêtes du monde et Missions Spéciales dans Voidstorm." },
        { name="Campagne principale : Tempête du Vide",
          npc="Magistère Umbric", coords="52.6, 72.8", zone="Tempête du Vide",
          rep=5000, type="onetime", questID=nil, mapID=2405,
          tip="Compléter la campagne principale de Voidstorm." },
        { name="Objets de lore : Tempête du Vide",
          npc="Chercheur du Vide Anomander", coords="52.6, 72.8", zone="Tempête du Vide",
          rep=250, type="onetime", questID=nil, mapID=2405,
          tip="Collectez les objets de lore dispersés dans Voidstorm." },
        { name="Télescopes des Sommets",
          npc="Pic de Voidstorm", coords="52.6, 72.8", zone="Tempête du Vide",
          rep=100, type="onetime", questID=nil, mapID=2405,
          tip="Placez les télescopes sur les plus hauts pics de Voidstorm." },
      },
    },

    -- ----------------------------------------------------------------
    -- Forces de Zul'Jarra (ID 2772) - Île annelée (Coiled Isle, uiMap 2512)
    -- Patch 12.1 « La malédiction d'Ula'tek ». Données alignées sur
    -- RenTracker (vérifiées Wowhead / Warcraft Wiki / Method.gg, 21/08/2026) :
    --   Purging the Vaults 95520 (500), Turn Back the Surge 96995 (1000).
    -- Noms FR relevés en jeu par /dt check (28/09/2026) : « Nettoyage des
    -- caveaux » et « Repousser la vague ». Le jeu affiche de toute façon son
    -- propre titre, dans la langue du client, dès qu'il l'a chargé.
    -- Montant des coffres de Gouffre Bountiful : estimation, non confirmé.
    -- ----------------------------------------------------------------
    {
      id       = 2772,
      category = "secondaire",
      name     = "Forces de Zul'Jarra",
      zone     = "Île annelée",
      color    = {r=0.42, g=0.32, b=0.75},
      quests   = {
        { name="Nettoyage des caveaux",
          npc="Warleader Abdumati / Talon Commander Zela", coords="Tokka's Landing", zone="Île annelée",
          rep=500, type="weekly", questID=95520, mapID=2512,
          tip="Quête méta hebdomadaire des Vaults of Atal'Utek." },
        { name="Repousser la vague",
          npc="Talon Commander Zela", coords="Île annelée", zone="Île annelée",
          rep=1000, type="weekly", questID=96995, mapID=2512,
          tip="Vaincre 3 Curse Surges dans la semaine. Environ 40 % d'un rang de Renom à elle seule." },
        { name="Quête de donjon hebdomadaire", shared="mid_dungeon",
          npc="Halduron Luisaile", coords="50.4, 38.2", zone="Lune-d'Argent",
          rep=1500, type="weekly", questID=nil, mapID=2372,
          tip="Terminez un donjon Midnight (difficulté libre, même Donjon Compagnon)." },
        { name="Repaire : Nymrissa Wavecaller",
          npc="Nymrissa Wavecaller", coords="Île annelée", zone="Île annelée",
          rep=200, type="weekly", questID=nil, mapID=2512,
          tip="Vaincre le Repaire de Nymrissa Wavecaller une fois par semaine." },
        { name="Coffres de Gouffre Bountiful",
          npc="Coffres de Gouffre", coords="Gouffres de l'Île annelée", zone="Île annelée",
          rep=500, type="weekly", questID=nil, mapID=nil,
          tip="Montant estimé, non confirmé. Les coffres Bountiful (Ring of Glory, Gnarldor Isle...) alimentent la barre une fois par semaine." },
        { name="Quêtes mondiales quotidiennes", wq=true,
          npc="Diverses zones", coords="Île annelée", zone="Île annelée",
          rep=75, type="daily", questID=nil, mapID=2512,
          tip="Quêtes du monde de l'Île annelée. Boostées par le Contrat : Forces de Zul'Jarra (partagé Bataillon)." },
        { name="Quotidiennes des Vaults of Atal'Utek",
          npc="PNJ des Vaults", coords="Sous l'Île annelée", zone="Île annelée",
          rep=50, type="daily", questID=nil, mapID=2512,
          tip="Chaque quotidienne des Vaults of Atal'Utek donne 50 rép." },
        { name="Campagne : La malédiction d'Ula'tek",
          npc="Zul'jarra", coords="Tokka's Landing", zone="Île annelée",
          rep=5000, type="onetime", questID=nil, mapID=2512,
          tip="Campagne principale du patch 12.1. Gros bonus de rép, ne se répète pas." },
        { name="Rares tués (jusqu'à 12)",
          npc="Élites rares", coords="Île annelée", zone="Île annelée",
          rep=50, type="onetime", questID=nil, mapID=2512,
          tip="12 élites rares distincts, 50 rép chacun la première fois. Source distincte des Curse Surges (50 rép par Surge terminée)." },
        { name="Trésors de l'Île annelée (jusqu'à 22)",
          npc="Trésors", coords="Île annelée", zone="Île annelée",
          rep=50, type="onetime", questID=nil, mapID=2512,
          tip="22 trésors dispersés sur l'île, 50 rép chacun." },
        { name="Objets de lore : Student of Hissstory (jusqu'à 10)",
          npc="Objets interactifs", coords="Île annelée", zone="Île annelée",
          rep=250, type="onetime", questID=nil, mapID=2512,
          tip="10 objets de lore, 250 rép chacun." },
      },
    },

    -- ----------------------------------------------------------------
    -- Capitaine Tokka (ID 2773) - Île annelée. Réputation « amitié » axée
    -- pêche (5 rangs), ajoutée en 12.1. Lue via C_GossipInfo (friendship).
    -- Gains de rép par activité non confirmés : laissés à 0.
    -- ----------------------------------------------------------------
    {
      id         = 2773,
      category   = "secondaire",
      name       = "Capitaine Tokka",
      zone       = "Île annelée",
      friendship = true,
      color      = {r=0.20, g=0.70, b=0.55},
      quests     = {
        { name="Quotidiennes de l'équipage",
          npc="Équipage de Tokka", coords="51.65, 49.79", zone="Tokka's Folly",
          rep=0, type="daily", questID=nil, mapID=2512,
          tip="Quotidiennes de l'équipage à Tokka's Folly, l'île juste à l'ouest de Tokka's Landing (coordonnées du second Sluggs)." },
        { name="Pêche maudite : poissons spéciaux",
          npc="Bancs de pêche", coords="Eaux de l'Île annelée", zone="Île annelée",
          rep=0, type="daily", questID=nil, mapID=2512,
          tip="Poissons et objets de quête (haut fait « Treasures of the Damned »). Débloquée via les Curse Surges." },
        { name="Quête mondiale : Open Sea Fishing",
          npc="Quête mondiale", coords="Île annelée", zone="Île annelée",
          rep=0, type="daily", questID=nil, mapID=2512,
          tip="Faites la quête mondiale de pêche en haute mer dès qu'elle apparaît." },
        { name="Pêche empoisonnée : déblocage",
          npc="Capitaine Tokka", coords="Tokka's Landing", zone="Île annelée",
          rep=0, type="onetime", questID=nil, mapID=2512,
          tip="Quête d'introduction « Venom Fishing: Proof is in the Ooze » : débloque la réputation et la Pêche maudite." },
        { name="Chaîne de quêtes de Tokka",
          npc="Capitaine Tokka", coords="Tokka's Landing", zone="Île annelée",
          rep=0, type="onetime", questID=nil, mapID=2512,
          tip="Jusqu'à « Venom Fishing: Maximum Potency ». Fait l'essentiel de la rép jusqu'au dernier rang." },
      },
    },

  }, -- factions
} -- Midnight
