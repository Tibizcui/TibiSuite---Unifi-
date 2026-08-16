-- ================================================================
-- DailyTracker - Data : The War Within (11.x)
-- Activités quotidiennes, hebdomadaires et uniques
-- ================================================================

DailyTrackerData = DailyTrackerData or {}

DailyTrackerData["TheWarWithin"] = {
  label    = "The War Within",
  patch    = "11.0",
  color    = {r=0.55, g=0.75, b=0.95},
  factions = {

    -- ----------------------------------------------------------------
    -- Conseil de Dornogal (ID 2590) - Île de Dorn
    -- ----------------------------------------------------------------
    {
      id       = 2590,
      category = "principale",
      name     = "Conseil de Dornogal",
      zone     = "Île de Dorn",
      color    = {r=0.70, g=0.55, b=0.35},
      quests   = {
        { name="Quête de donjon hebdomadaire",
          npc="Biergoth", coords="46.4, 48.2", zone="Dornogal",
          rep=1500, type="weekly", questID=nil, mapID=2248,
          tip="Complétez le donjon désigné cette semaine. N'importe quelle difficulté, même Donjon Compagnon." },
        { name="La Troupe de Théâtre",
          npc="Stage Manager Huberta", coords="51.2, 72.4", zone="Île de Dorn",
          rep=1000, type="weekly", questID=78359, mapID=2248,
          tip="Gagnez 50 Approbation du Public pendant l'événement Théâtre Troupe." },
        { name="Contrat : Conseil de Dornogal",
          npc="Auditeur Balwurz", coords="39.2, 24.3", zone="Dornogal",
          rep=10, type="weekly", questID=nil, mapID=2248,
          tip="Contrat d'Inscription : +10 rep par quête mondiale complète dans Khaz Algar." },
        { name="Quêtes mondiales de zone",
          npc="Diverses zones", coords="Île de Dorn", zone="Île de Dorn",
          rep=75, type="daily", questID=nil, mapID=2248,
          tip="Les quêtes mondiales de l'Île de Dorn donnent de la rep au Conseil de Dornogal." },
        { name="Rares hebdomadaires - Île de Dorn",
          npc="Rares dans la zone", coords="Île de Dorn", zone="Île de Dorn",
          rep=150, type="weekly", questID=nil, mapID=2248,
          tip="Chaque rare de l'Île de Dorn donne 150 rep, une fois par semaine par Warband." },
        { name="Campagne principale : Île de Dorn",
          npc="Conseillère Merrix", coords="42.6, 47.8", zone="Dornogal",
          rep=5000, type="onetime", questID=nil, mapID=2248,
          tip="Compléter la campagne principale de l'Île de Dorn." },
        { name="Chasseur de Lore : Île de Dorn",
          npc="Objets de lore dans la zone", coords="Île de Dorn", zone="Île de Dorn",
          rep=250, type="onetime", questID=nil, mapID=2248,
          tip="Collectez les 5 objets de lore de l'Île de Dorn (haut fait Chasseur de Lore)." },
      },
    },

    -- ----------------------------------------------------------------
    -- Assemblée des Profondeurs (ID 2594) - Les Profondeurs Sonnantes
    -- ----------------------------------------------------------------
    {
      id       = 2594,
      category = "principale",
      name     = "Assemblée des Profondeurs",
      zone     = "Les Profondeurs Sonnantes",
      color    = {r=0.35, g=0.70, b=0.45},
      quests   = {
        { name="Quête de donjon hebdomadaire",
          npc="Biergoth", coords="46.4, 48.2", zone="Dornogal",
          rep=1500, type="weekly", questID=nil, mapID=2248,
          tip="Complétez le donjon désigné cette semaine. N'importe quelle difficulté." },
        { name="L'Éveil de la Machine",
          npc="Intervenant Kuldas", coords="47.4, 31.8", zone="Gundargaz",
          rep=2000, type="weekly", questID=78456, mapID=2255,
          tip="Défendez Kuldas contre des vagues de monstres. Débloqué après Renown 3." },
        { name="Contrat : Assemblée des Profondeurs",
          npc="Ciroleur Squick", coords="47.4, 31.8", zone="Gundargaz",
          rep=10, type="weekly", questID=nil, mapID=2255,
          tip="Contrat d'Inscription : +10 rep par quête mondiale complète dans Khaz Algar." },
        { name="Quêtes mondiales de zone",
          npc="Diverses zones", coords="Profondeurs Sonnantes", zone="Profondeurs Sonnantes",
          rep=75, type="daily", questID=nil, mapID=2255,
          tip="Les quêtes mondiales des Profondeurs Sonnantes donnent de la rep à l'Assemblée." },
        { name="Rares hebdomadaires - Profondeurs Sonnantes",
          npc="Rares dans la zone", coords="Profondeurs Sonnantes", zone="Profondeurs Sonnantes",
          rep=150, type="weekly", questID=nil, mapID=2255,
          tip="Chaque rare des Profondeurs Sonnantes donne 150 rep, une fois par semaine." },
        { name="Campagne principale : Profondeurs Sonnantes",
          npc="Intervenant Kuldas", coords="47.4, 31.8", zone="Gundargaz",
          rep=5000, type="onetime", questID=nil, mapID=2255,
          tip="Compléter la campagne principale des Profondeurs Sonnantes." },
        { name="Chasseur de Lore : Profondeurs Sonnantes",
          npc="Objets de lore dans la zone", coords="Profondeurs Sonnantes", zone="Profondeurs Sonnantes",
          rep=250, type="onetime", questID=nil, mapID=2255,
          tip="Collectez les 5 objets de lore des Profondeurs Sonnantes." },
      },
    },

    -- ----------------------------------------------------------------
    -- Arathi de Sacré-Déclin (ID 2570) - Sacré-Déclin
    -- ----------------------------------------------------------------
    {
      id       = 2570,
      category = "principale",
      name     = "Arathi de Sacré-Déclin",
      zone     = "Sacré-Déclin",
      color    = {r=0.90, g=0.70, b=0.25},
      quests   = {
        { name="Quête de donjon hebdomadaire",
          npc="Biergoth", coords="46.4, 48.2", zone="Dornogal",
          rep=1500, type="weekly", questID=nil, mapID=2248,
          tip="Complétez le donjon désigné cette semaine." },
        { name="Défendre la Flamme Sacrée",
          npc="Officier Arathi", coords="Sacré-Déclin", zone="Sacré-Déclin",
          rep=2000, type="weekly", questID=78902, mapID=2346,
          tip="Participez à l'événement de défense de Beledar dans Sacré-Déclin." },
        { name="Contrat : Arathi de Sacré-Déclin",
          npc="Auralia Ferrelectre", coords="44.8, 52.6", zone="Mereldar",
          rep=10, type="weekly", questID=nil, mapID=2346,
          tip="Contrat d'Inscription : +10 rep par quête mondiale complète dans Khaz Algar." },
        { name="Quêtes mondiales de zone",
          npc="Diverses zones", coords="Sacré-Déclin", zone="Sacré-Déclin",
          rep=75, type="daily", questID=nil, mapID=2346,
          tip="Les quêtes mondiales de Sacré-Déclin donnent de la rep aux Arathi." },
        { name="Rares hebdomadaires - Sacré-Déclin",
          npc="Rares dans la zone", coords="Sacré-Déclin", zone="Sacré-Déclin",
          rep=150, type="weekly", questID=nil, mapID=2346,
          tip="Chaque rare de Sacré-Déclin donne 150 rep, une fois par semaine." },
        { name="Campagne principale : Sacré-Déclin",
          npc="Général Ferrelectre", coords="44.8, 52.6", zone="Mereldar",
          rep=5000, type="onetime", questID=nil, mapID=2346,
          tip="Compléter la campagne principale de Sacré-Déclin." },
        { name="Chasseur de Lore : Sacré-Déclin",
          npc="Objets de lore dans la zone", coords="Sacré-Déclin", zone="Sacré-Déclin",
          rep=250, type="onetime", questID=nil, mapID=2346,
          tip="Collectez les 5 objets de lore de Sacré-Déclin." },
      },
    },

    -- ----------------------------------------------------------------
    -- Les Fils Tranchés (ID 2600) - Azj-Kahet
    -- ----------------------------------------------------------------
    {
      id       = 2600,
      category = "principale",
      name     = "Les Fils Tranchés",
      zone     = "Azj-Kahet",
      color    = {r=0.65, g=0.20, b=0.75},
      quests   = {
        { name="Quête de donjon hebdomadaire",
          npc="Biergoth", coords="46.4, 48.2", zone="Dornogal",
          rep=1500, type="weekly", questID=nil, mapID=2248,
          tip="Complétez le donjon désigné cette semaine." },
        { name="Pacte : Le Tisserand",
          npc="Dame Vinazian", coords="50.2, 51.4", zone="Azj-Kahet",
          rep=1000, type="weekly", questID=79123, mapID=2340,
          tip="Complétez des quêtes, rares et trésors dans Azj-Kahet pour le Tisserand." },
        { name="Pacte : Le Général",
          npc="Anub'azal", coords="Azj-Kahet", zone="Azj-Kahet",
          rep=1000, type="weekly", questID=79124, mapID=2340,
          tip="Complétez des quêtes, rares et trésors dans Azj-Kahet pour le Général." },
        { name="Pacte : Le Vizir",
          npc="Nizrek", coords="Azj-Kahet", zone="Azj-Kahet",
          rep=1000, type="weekly", questID=79125, mapID=2340,
          tip="Complétez des quêtes, rares et trésors dans Azj-Kahet pour le Vizir." },
        { name="Contrat : Les Fils Tranchés",
          npc="Y'tekhi", coords="50.2, 51.4", zone="Repaire du Tisserand",
          rep=10, type="weekly", questID=nil, mapID=2340,
          tip="Contrat d'Inscription : +10 rep par quête mondiale complète dans Khaz Algar." },
        { name="Quêtes mondiales de zone",
          npc="Diverses zones", coords="Azj-Kahet", zone="Azj-Kahet",
          rep=75, type="daily", questID=nil, mapID=2340,
          tip="Les quêtes mondiales d'Azj-Kahet donnent de la rep aux Fils Tranchés." },
        { name="Rares hebdomadaires - Azj-Kahet",
          npc="Rares dans la zone", coords="Azj-Kahet", zone="Azj-Kahet",
          rep=150, type="weekly", questID=nil, mapID=2340,
          tip="Chaque rare d'Azj-Kahet donne 150 rep, une fois par semaine." },
        { name="Campagne principale : Azj-Kahet",
          npc="Dame Vinazian", coords="50.2, 51.4", zone="Repaire du Tisserand",
          rep=5000, type="onetime", questID=nil, mapID=2340,
          tip="Compléter la campagne principale d'Azj-Kahet." },
        { name="Chasseur de Lore : Azj-Kahet",
          npc="Objets de lore dans la zone", coords="Azj-Kahet", zone="Azj-Kahet",
          rep=250, type="onetime", questID=nil, mapID=2340,
          tip="Collectez les 5 objets de lore d'Azj-Kahet." },
      },
    },

    -- ----------------------------------------------------------------
    -- Brann Bronzebeard (ID 2605) - Delves - Khaz Algar
    -- ----------------------------------------------------------------
    {
      id       = 2605,
      category = "secondaire",
      name     = "Brann Bronzebeard",
      zone     = "Khaz Algar - Delves",
      color    = {r=0.85, g=0.65, b=0.20},
      quests   = {
        { name="Delves - Niveau Bravent (Quotidien)",
          npc="Brann Bronzebeard", coords="Diverses Delves", zone="Khaz Algar",
          rep=100, type="daily", questID=nil, mapID=nil,
          tip="Complétez des Delves avec Brann Bronzebeard comme compagnon. Plus la difficulté est haute, plus la rep est élevée." },
        { name="Coffre de Bountiful (Hebdo)",
          npc="Brann Bronzebeard", coords="Diverses Delves", zone="Khaz Algar",
          rep=500, type="weekly", questID=80001, mapID=nil,
          tip="Complétez le Delve Bountiful de la semaine pour un coffre garantissant de la rep et du loot." },
      },
    },

    -- ----------------------------------------------------------------
    -- Cartels de Ratatouille (ID 2640) - Ratatouille - Patch 11.1
    -- ----------------------------------------------------------------
    {
      id       = 2640,
      category = "principale",
      name     = "Cartels de Ratatouille",
      zone     = "Ratatouille",
      color    = {r=0.85, g=0.60, b=0.10},
      quests   = {
        { name="Quête de donjon hebdomadaire",
          npc="Biergoth", coords="46.4, 48.2", zone="Dornogal",
          rep=1500, type="weekly", questID=nil, mapID=2248,
          tip="Complétez le donjon désigné cette semaine." },
        { name="Quêtes mondiales de Ratatouille",
          npc="Diverses zones", coords="Ratatouille", zone="Ratatouille",
          rep=75, type="daily", questID=nil, mapID=nil,
          tip="Les quêtes mondiales de Ratatouille donnent de la rep aux Cartels. Patch 11.1." },
        { name="Rares hebdomadaires - Ratatouille",
          npc="Rares dans la zone", coords="Ratatouille", zone="Ratatouille",
          rep=150, type="weekly", questID=nil, mapID=nil,
          tip="Chaque rare de Ratatouille donne 150 rep, une fois par semaine." },
        { name="Campagne principale : Ratatouille",
          npc="Smaks Topskimmer", coords="50.2, 50.8", zone="Ratatouille",
          rep=5000, type="onetime", questID=nil, mapID=nil,
          tip="Complétez la campagne principale de la zone Ratatouille pour un gros bonus de rep." },
      },
    },

    -- ----------------------------------------------------------------
    -- Flamme Radieuse (ID 2650) - Sacré-Déclin - Patch 11.1
    -- ----------------------------------------------------------------
    {
      id       = 2650,
      category = "secondaire",
      name     = "Flamme Radieuse",
      zone     = "Sacré-Déclin",
      color    = {r=0.95, g=0.55, b=0.10},
      quests   = {
        { name="Défense de Beledar",
          npc="Officier Arathi", coords="Sacré-Déclin", zone="Sacré-Déclin",
          rep=1000, type="weekly", questID=82540, mapID=2346,
          tip="Participez aux événements de défense de la Flamme Radieuse dans Sacré-Déclin (patch 11.1)." },
        { name="Quêtes mondiales Sacré-Déclin",
          npc="Diverses zones", coords="Sacré-Déclin", zone="Sacré-Déclin",
          rep=75, type="daily", questID=nil, mapID=2346,
          tip="Les quêtes mondiales de Sacré-Déclin donnent de la rep à la Flamme Radieuse." },
      },
    },

  }, -- factions
} -- TheWarWithin
