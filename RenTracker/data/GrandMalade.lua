-- ================================================================
-- RenTracker - Data : HF "Tous des malades" - Le grand malade
-- Achievement ID : 2336
-- Nom : Tous des malades (Haut fait Le Grand Malade)
-- ================================================================
-- Ce module est special : il n'utilise pas le systeme de reputation
-- standard mais suit les 7 factions requises pour le haut fait.
-- Factions requises (retail modern WoW) :
--   HONORE   : Voile sanglante
--   EXALTE   : Baie-du-Butin, Long-Guet, Gadgetzan, Cabestan,
--              Foire de Sombrelune, Ravenholdt
-- ================================================================

RenTrackerData = RenTrackerData or {}

RenTrackerData["GrandMalade"] = {
  label      = "Le Grand Malade",
  tocLabel   = "10000",
  system     = "classic",
  hasParagon = false,
  renownCap  = 8,
  repPerRank = 3000,
  color      = {r=1.00, g=0.82, b=0.00},  -- Jaune hauts faits WoW
  -- Note : achievementID = 2336 (Tous des malades)
  factions   = {
    -- ----------------------------------------------------------------
    -- 1. ETAPE 1 (en premier absolument) : Voile sanglante (ID 59)
    --    Objectif : HONORE (pas Exalté - au-delà reduit les Cartels)
    -- ----------------------------------------------------------------
    {
      id       = 59,
      name     = "Voile sanglante",
      zone     = "Tanaris / Baie-du-Butin",
      qm_name  = "PNJ de la Voile (pas de QM standard)",
      qm_coord = "Baie-du-Butin, Tanaris",
      qm_zone  = "Baie-du-Butin, Tanaris",
      color    = {r=0.95, g=0.25, b=0.25},
      quests   = {
        { name="[ETAPE 1 - EN PREMIER] Tuer les gardes Cartel pour monter de Deteste a Honore",
          npc="Gardes Cartel (Baie-du-Butin, Gadgetzan, Cabestan, Long-Guet)",
          coords="52.0, 43.0",
          zone="Baie-du-Butin, Tanaris",
          rep=5, type="daily", questID=nil, mapID=440,
          tip="IMPORTANT : Faites cette faction EN PREMIER et STOP a Honore. Chaque garde tue donne 5 rep Voile sanglante mais REDUIT de 5 rep les 4 factions Cartel. Environ 2000 gardes tues pour passer de Deteste a Honore." },
        { name="[Bonus] En avant toutes, Amiral ! (Unique - a Aimable)",
          npc="Fleet Master Seahorn", coords="52.0, 43.0",
          zone="Baie-du-Butin, Tanaris",
          rep=0, type="onetime", questID=nil, mapID=440,
          tip="A Aimable avec la Voile sanglante : completez cette quete pour obtenir le titre Amiral de la Voile sanglante. Bonus du grand malade !" },
        { name="Arret OBLIGATOIRE a Honore",
          npc="N/A - Verifier votre barre de reputation",
          coords="Votre barre de rep",
          zone="N/A",
          rep=0, type="onetime", questID=nil, mapID=nil,
          tip="STOP a Honore ! Ne depassez pas Honore avec la Voile sanglante. Au-dela vous ne pourrez plus faire les quetes Cartel necessaires pour les 4 factions Gobelin." },
      },
    },
    -- ----------------------------------------------------------------
    -- 2. Foire de Sombrelune (ID 391) - TIMEGATED : a faire en continu
    -- ----------------------------------------------------------------
    {
      id       = 391,
      name     = "Foire de Sombrelune",
      zone     = "Iles de la Sombrelune (1er dimanche du mois)",
      qm_name  = "Lhara (animaux) / Gelvas Grimegate (quetes)",
      qm_coord = "Ile de la Sombrelune",
      qm_zone  = "Ile de la Sombrelune (Teldar ou Elwynn)",
      color    = {r=0.65, g=0.30, b=0.90},
      quests   = {
        { name="[TIMEGATED] Quetes mensuelles de la Foire (Mensuel)",
          npc="PNJ de la Foire de Sombrelune", coords="Ile de la Sombrelune",
          zone="Ile de la Sombrelune",
          rep=500, type="weekly", questID=nil, mapID=862,
          tip="La Foire a lieu 1 semaine par mois (1er dimanche). Completez TOUTES les quetes disponibles : manege, jeux, quetes de profession. Environ 500-600 rep/jour x 7 jours = ~4000 rep par mois." },
        { name="Quetes de profession (Mensuel)",
          npc="PNJ de profession de la Foire", coords="Ile de la Sombrelune",
          zone="Ile de la Sombrelune",
          rep=250, type="weekly", questID=nil, mapID=862,
          tip="Chaque quete de profession (cuisine, peche, archeo, etc.) donne 250 rep. Completez-les toutes chaque mois." },
        { name="Suites de Sombrelune (Hebdo - cartes)",
          npc="Chester (Suite du tonnerre, etc.)", coords="Ile de la Sombrelune",
          zone="Ile de la Sombrelune",
          rep=2500, type="weekly", questID=nil, mapID=862,
          tip="Completez et remettez des Suites de Sombrelune (Tonnerre, Ours, etc.) : 2500 rep par suite. Achetez les cartes a l'HV ou farmez-les en instance." },
        { name="Coffrets lourds - Vol a la tire (Repetable)",
          npc="Silas Darkmoon", coords="Ile de la Sombrelune",
          zone="Ile de la Sombrelune",
          rep=25, type="daily", questID=nil, mapID=862,
          tip="Un voleur peut farmer des Coffrets lourds sur des humanoïdes level 50+ et les remettre pour 25 rep chacun. Lent mais possible entre les foires." },
      },
    },
    -- ----------------------------------------------------------------
    -- 3. Ravenholdt (ID 349) - Necessite un voleur pour Exalte
    -- ----------------------------------------------------------------
    {
      id       = 349,
      name     = "Ravenholdt",
      zone     = "Hautes Terres d'Alterac",
      qm_name  = "Lord Jorach Ravenholdt",
      qm_coord = "71.8, 19.8",
      qm_zone  = "Manoir Ravenholdt, Hautes Terres d'Alterac",
      color    = {r=0.55, g=0.55, b=0.55},
      quests   = {
        { name="Tuer les membres du Syndicat jusqu'a Honore (Repetable)",
          npc="Membres du Syndicat", coords="Donjon de Stormgarde / Hautes Terres",
          zone="Hautes Terres d'Alterac",
          rep=5, type="daily", questID=nil, mapID=36,
          tip="De Neutre a Honore : tuez des membres du Syndicat (5 rep chacun). Le Donjon de Stormgarde est le meilleur spot (dense en humanoïdes). Accessible a tous." },
        { name="[VOLEUR REQUIS] Coffrets lourds - de Honore a Exalte (Repetable)",
          npc="Lord Jorach Ravenholdt", coords="71.8, 19.8",
          zone="Manoir Ravenholdt",
          rep=75, type="daily", questID=nil, mapID=36,
          itemTracking = {
            {itemID=13113, name="Coffret lourd", needed=0, tip="Vol a la tire sur humanoïdes lv50+. 75 rep/coffret."},
          },
          tip="ATTENTION : Au-dela de Honore, SEULS les Coffrets lourds remis a Ravenholdt donnent de la rep (75 rep chacun). Seul un VOLEUR peut faire du Vol a la tire pour obtenir ces coffrets sur des mobs level 50+. Les coffrets ne s'empilent pas !" },
        { name="Acce : En avant toutes, Amiral ! - si pas encore fait",
          npc="Verifier votre status Voile sanglante", coords="Baie-du-Butin",
          zone="Tanaris",
          rep=0, type="onetime", questID=nil, mapID=nil,
          tip="Si vous avez deja monte la Voile sanglante a Honore precedemment, assurez-vous d'avoir completee la quete En avant toutes, Amiral ! avant de continuer Ravenholdt." },
      },
    },
    -- ----------------------------------------------------------------
    -- 4. Baie-du-Butin (ID 637) - Cartel Gantrepression
    -- ----------------------------------------------------------------
    {
      id       = 637,
      name     = "Baie-du-Butin",
      zone     = "Tanaris",
      qm_name  = "Kravel Koalbeard",
      qm_coord = "51.8, 43.2",
      qm_zone  = "Baie-du-Butin, Tanaris",
      color    = {r=0.90, g=0.65, b=0.10},
      quests   = {
        { name="Remettre des Etoffes (Repetable)",
          npc="Gordok Tribute (Hache-Tripe) / Marchands",
          coords="51.8, 43.2",
          zone="Baie-du-Butin, Tanaris",
          rep=75, type="daily", questID=nil, mapID=440,
          itemTracking = {
            {itemID=14047, name="Runecloth (x20)", needed=20, tip="350 rep / pile de 20 - le plus efficace"},
            {itemID=4338,  name="Mageweave (x20)", needed=20, tip="250 rep / pile de 20"},
            {itemID=4306,  name="Soie (x20)",      needed=20, tip="200 rep / pile de 20"},
            {itemID=2592,  name="Laine (x20)",     needed=20, tip="75 rep / pile de 20"},
            {itemID=2589,  name="Lin (x20)",       needed=20, tip="75 rep / pile de 20"},
          },
          tip="Remettez des piles de 20 etoffes (lin, laine, soie, mithril, runecloth) pour 75-350 rep selon l'etoffe. La runecloth donne le plus de rep par pile (350). Acheter a l'HV ou farme en instance." },
        { name="Quetes de zone de Tanaris (Unique)",
          npc="PNJ de Baie-du-Butin", coords="51.8, 43.2",
          zone="Baie-du-Butin, Tanaris",
          rep=5000, type="onetime", questID=nil, mapID=440,
          tip="Completez toutes les quetes de Tanaris liees a la Baie-du-Butin pour un important bonus de rep de depart." },
        { name="Quetes de Gentepression (Repetable)",
          npc="PNJ de Gentepression", coords="Tanaris",
          zone="Tanaris",
          rep=350, type="daily", questID=nil, mapID=440,
          tip="Les quetes repetables de Gentepression dans le desert de Tanaris donnent de la rep a Baie-du-Butin et aux autres factions Cartel." },
      },
    },
    -- ----------------------------------------------------------------
    -- 5. Long-Guet (ID 369) - Cartel Gantrepression
    -- ----------------------------------------------------------------
    {
      id       = 369,
      name     = "Long-Guet",
      zone     = "Mille Pointes",
      qm_name  = "Rixaband (vente objets)",
      qm_coord = "41.8, 49.8",
      qm_zone  = "Long-Guet, Mille Pointes",
      color    = {r=0.90, g=0.65, b=0.10},
      quests   = {
        { name="Remettre des Etoffes (Repetable)",
          npc="PNJ de Long-Guet", coords="41.8, 49.8",
          zone="Long-Guet, Mille Pointes",
          rep=75, type="daily", questID=nil, mapID=400,
          itemTracking = {
            {itemID=14047, name="Runecloth (x20)", needed=20, tip="350 rep / pile de 20 - le plus efficace"},
            {itemID=4338,  name="Mageweave (x20)", needed=20, tip="250 rep / pile de 20"},
            {itemID=4306,  name="Soie (x20)",      needed=20, tip="200 rep / pile de 20"},
            {itemID=2592,  name="Laine (x20)",     needed=20, tip="75 rep / pile de 20"},
            {itemID=2589,  name="Lin (x20)",       needed=20, tip="75 rep / pile de 20"},
          },
          tip="Remettez des piles de 20 etoffes (lin, laine, soie, mithril, runecloth) pour 75-350 rep. La runecloth est le plus efficace." },
        { name="Quetes de zone des Mille Pointes (Unique)",
          npc="PNJ de Long-Guet", coords="41.8, 49.8",
          zone="Long-Guet, Mille Pointes",
          rep=3000, type="onetime", questID=nil, mapID=400,
          tip="Completez les quetes de zone des Mille Pointes pour monter la rep Long-Guet." },
        { name="Demande de Coffrets (Repetable - voleur)",
          npc="Lou Pierret / Manoir Ranveholdt", coords="Mille Pointes",
          zone="Mille Pointes",
          rep=150, type="daily", questID=nil, mapID=400,
          tip="Quete repetable : remettez des Coffrets lourds a Lou Pierret dans le Manoir de Ranveholdt (Mille Pointes) pour 150 rep Long-Guet + Ravenholdt." },
      },
    },
    -- ----------------------------------------------------------------
    -- 6. Gadgetzan (ID 369 -> 577) - Cartel Gantrepression
    -- ----------------------------------------------------------------
    {
      id       = 577,
      name     = "Gadgetzan",
      zone     = "Tanaris",
      qm_name  = "Jhordy Lapforge",
      qm_coord = "51.2, 29.4",
      qm_zone  = "Gadgetzan, Tanaris",
      color    = {r=0.90, g=0.65, b=0.10},
      quests   = {
        { name="Remettre des Etoffes (Repetable)",
          npc="PNJ de Gadgetzan", coords="51.2, 29.4",
          zone="Gadgetzan, Tanaris",
          rep=75, type="daily", questID=nil, mapID=440,
          itemTracking = {
            {itemID=14047, name="Runecloth (x20)", needed=20, tip="350 rep / pile de 20 - le plus efficace"},
            {itemID=4338,  name="Mageweave (x20)", needed=20, tip="250 rep / pile de 20"},
            {itemID=4306,  name="Soie (x20)",      needed=20, tip="200 rep / pile de 20"},
            {itemID=2592,  name="Laine (x20)",     needed=20, tip="75 rep / pile de 20"},
            {itemID=2589,  name="Lin (x20)",       needed=20, tip="75 rep / pile de 20"},
          },
          tip="Remettez des piles de 20 etoffes (lin, laine, soie, mithril, runecloth) pour 75-350 rep. La runecloth est le plus efficace." },
        { name="Quetes de zone de Tanaris / Gadgetzan (Unique)",
          npc="PNJ de Gadgetzan", coords="51.2, 29.4",
          zone="Gadgetzan, Tanaris",
          rep=4000, type="onetime", questID=nil, mapID=440,
          tip="Completez les quetes de zone de Tanaris liees a Gadgetzan pour un bon bonus de rep de depart." },
        { name="Quetes de la Zone de Vol (Repetable)",
          npc="PNJ de Gadgetzan", coords="Tanaris",
          zone="Tanaris",
          rep=350, type="daily", questID=nil, mapID=440,
          tip="Quetes repetables dans la Zone de Vol au nord de Gadgetzan." },
      },
    },
    -- ----------------------------------------------------------------
    -- 7. Cabestan (ID 577 -> 589) - Cartel Gantrepression
    -- ----------------------------------------------------------------
    {
      id       = 589,
      name     = "Cabestan",
      zone     = "Les Serres-Rocheuses",
      qm_name  = "Liv Rizzlefix",
      qm_coord = "62.4, 47.8",
      qm_zone  = "Cabestan, Les Serres-Rocheuses",
      color    = {r=0.90, g=0.65, b=0.10},
      quests   = {
        { name="Remettre des Etoffes (Repetable)",
          npc="PNJ de Cabestan", coords="62.4, 47.8",
          zone="Cabestan, Les Serres-Rocheuses",
          rep=75, type="daily", questID=nil, mapID=400,
          itemTracking = {
            {itemID=14047, name="Runecloth (x20)", needed=20, tip="350 rep / pile de 20 - le plus efficace"},
            {itemID=4338,  name="Mageweave (x20)", needed=20, tip="250 rep / pile de 20"},
            {itemID=4306,  name="Soie (x20)",      needed=20, tip="200 rep / pile de 20"},
            {itemID=2592,  name="Laine (x20)",     needed=20, tip="75 rep / pile de 20"},
            {itemID=2589,  name="Lin (x20)",       needed=20, tip="75 rep / pile de 20"},
          },
          tip="Remettez des piles de 20 etoffes (lin, laine, soie, mithril, runecloth) pour 75-350 rep. La runecloth est le plus efficace." },
        { name="Quetes de zone des Serres-Rocheuses (Unique)",
          npc="PNJ de Cabestan", coords="62.4, 47.8",
          zone="Cabestan, Les Serres-Rocheuses",
          rep=3500, type="onetime", questID=nil, mapID=400,
          tip="Completez les quetes de zone des Serres-Rocheuses liees a Cabestan." },
        { name="Quetes du Gobelin du Rivage (Repetable)",
          npc="Gobelin du Rivage", coords="Les Serres-Rocheuses",
          zone="Les Serres-Rocheuses",
          rep=100, type="daily", questID=nil, mapID=400,
          tip="Quetes repetables du Gobelin du Rivage dans les Serres-Rocheuses : 2 quetes donnant chacune ~50 rep aux 4 factions Cartel." },
      },
    },
  },
}
