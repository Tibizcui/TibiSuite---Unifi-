-- ================================================================
-- DailyTracker - Data : Midnight (12.x)
-- Activités quotidiennes, hebdomadaires et uniques
-- ================================================================

DailyTrackerData = DailyTrackerData or {}

DailyTrackerData["Midnight"] = {
  label    = "Midnight",
  patch    = "12.0",
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
        { name="Haute Estime",
          npc="Seigneur Saltheril", coords="43.4, 47.4", zone="Bois des Chants Éternels",
          rep=1500, type="weekly", questID=91629, mapID=2395,
          tip="Choisissez votre sous-faction noble pour la semaine." },
        { name="Fortifier les Pierres-Runes : Chevaliers du Sang",
          npc="Représentant des Chevaliers du Sang", coords="43.4, 47.4", zone="Bois des Chants Éternels",
          rep=1000, type="weekly", questID=90574, mapID=2395,
          tip="Disponible après avoir choisi les Chevaliers du Sang comme sous-faction." },
        { name="Fortifier les Pierres-Runes : Éclaireurs",
          npc="Représentant des Éclaireurs", coords="43.4, 47.4", zone="Bois des Chants Éternels",
          rep=1000, type="weekly", questID=90575, mapID=2395,
          tip="Disponible après avoir choisi les Éclaireurs comme sous-faction." },
        { name="Fortifier les Pierres-Runes : Mages",
          npc="Représentant des Mages", coords="43.4, 47.4", zone="Bois des Chants Éternels",
          rep=1000, type="weekly", questID=90573, mapID=2395,
          tip="Disponible après avoir choisi les Mages comme sous-faction." },
        { name="Fortifier les Pierres-Runes : Ombres du Carrefour",
          npc="Représentant des Ombres du Carrefour", coords="43.4, 47.4", zone="Bois des Chants Éternels",
          rep=1000, type="weekly", questID=90576, mapID=2395,
          tip="Disponible après avoir choisi les Ombres du Carrefour comme sous-faction." },
        { name="Quête de donjon hebdomadaire",
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
        { name="Offrandes Abondantes",
          npc="Magovu", coords="45.8, 65.8", zone="Zul'Aman",
          rep=1000, type="weekly", questID=89507, mapID=2437,
          tip="Gagnez 20 000 points lors des événements Abondance dans Zul'Aman." },
        { name="Quête de donjon hebdomadaire",
          npc="Halduron Luisaile", coords="50.4, 38.2", zone="Lune-d'Argent",
          rep=1500, type="weekly", questID=nil, mapID=2372,
          tip="Terminez un donjon Midnight (difficulté libre, même Donjon Compagnon)." },
        { name="Quêtes quotidiennes de zone",
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
        { name="Légendes Perdues",
          npc="Zur'ashar Kassameh", coords="54.2, 53.0", zone="Harandar",
          rep=1000, type="weekly", questID=89268, mapID=2413,
          tip="Choisissez une relique Hara'ti et jouez son histoire. Choix partagé avec la Warband." },
        { name="Quête de donjon hebdomadaire",
          npc="Halduron Luisaile", coords="50.4, 38.2", zone="Lune-d'Argent",
          rep=1500, type="weekly", questID=nil, mapID=2372,
          tip="Terminez un donjon Midnight (difficulté libre, même Donjon Compagnon)." },
        { name="Quêtes quotidiennes de zone",
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
        { name="Assaut de Stormarion",
          npc="Commandant de la Singularité", coords="26.7, 68.2", zone="Tempête du Vide",
          rep=1000, type="weekly", questID=93892, mapID=2405,
          tip="Participez à l'assaut de Stormarion contre l'Hôte Dévorant." },
        { name="Quête de donjon hebdomadaire",
          npc="Halduron Luisaile", coords="50.4, 38.2", zone="Lune-d'Argent",
          rep=1500, type="weekly", questID=nil, mapID=2372,
          tip="Terminez un donjon Midnight (difficulté libre, même Donjon Compagnon)." },
        { name="Quêtes quotidiennes de zone",
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
    -- Forces de Zul'Jarra (Zul'Jarra's Forces) - Île lovée (Coiled Isle)
    -- Ajoutée par le patch 12.1 « La malédiction d'Ula'tek » (Midnight S2).
    -- /!\ DONNÉES PROVISOIRES : ID de faction, questID, coords, mapID et
    --     gains de rép exacts À CONFIRMER en jeu / via datamining.
    --     Confirmé : Renom 20, achat en « Voidlight Marl » chez Jan'sari
    --     the Watchful, titre « Hash'ura of Zul'Jarra » au Renom 20.
    -- ----------------------------------------------------------------
    {
      id       = nil,
      category = "secondaire",
      name     = "Forces de Zul'Jarra",
      zone     = "Île lovée (Coiled Isle)",
      color    = {r=0.42, g=0.32, b=0.75},
      quests   = {
        { name="Curse Surges : élites rares",
          npc="Élites rares", coords="?", zone="Île lovée",
          rep=0, type="daily", questID=nil, mapID=nil,
          tip="Tuer les élites rares pendant les Curse Surges débloque des zones et la Pêche maudite. Gain de rép à confirmer." },
        { name="Événements publics",
          npc="Événements de zone", coords="?", zone="Île lovée",
          rep=0, type="daily", questID=nil, mapID=nil,
          tip="Événements publics de l'Île lovée. Gain de rép à confirmer." },
        { name="Vaults of Atal'Utek",
          npc="À confirmer", coords="?", zone="Île lovée",
          rep=0, type="weekly", questID=nil, mapID=nil,
          tip="Activité récurrente de la zone. Gain de rép à confirmer." },
        { name="Pêche maudite : équipage de Tokka",
          npc="Capitaine Tokka", coords="?", zone="Île lovée",
          rep=0, type="daily", questID=nil, mapID=nil,
          tip="La Pêche maudite donne de la rép à l'équipage de Tokka (réputation distincte des Forces de Zul'Jarra). Débloquée via les Curse Surges." },
        { name="Campagne : Île lovée",
          npc="À confirmer", coords="?", zone="Île lovée",
          rep=0, type="onetime", questID=nil, mapID=nil,
          tip="Campagne principale du patch 12.1. Gain de rép à confirmer en jeu." },
      },
    },

  }, -- factions
} -- Midnight
