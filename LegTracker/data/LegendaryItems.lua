LegTrackerData = LegTrackerData or {}

--[[
  Structure volontairement simple :
  itemID = objet légendaire final à vérifier dans les sacs/banque/équipement.
  achievementID / achievements = haut fait(s) permettant de confirmer l'acquisition si l'objet n'est plus dans les sacs.
             Tours de force renseignes au lot B (7.1.5.31). Atiesh volontairement sans : un
             seul tour de force pour 4 batons, il marquerait les 4 classes comme obtenues.
             achievementName (facultatif) = nom attendu par /lt verify si different de name.
  classes = nil => toutes classes. Sinon liste des classes WoW en anglais : PALADIN, WARRIOR, MAGE...
  raids = raids ou se farme le legendaire (lot C) : {instanceID=ID d'instance du client,
          name=nom FR, bosses=texte}. Sert au bloc "Farm cette semaine" (verrouillages
          lus via GetSavedInstanceInfo). IDs controles par /lt verify (GetRealZoneText).
  quests = quêtes importantes du parcours. Cliquer dans l'addon pose un waypoint TomTom si mapID/x/y existent.
  trackers = composants à suivre : {itemID=...} (sacs + banques via C_Item.GetItemCount)
             ou {currencyID=...} pour une monnaie (C_CurrencyInfo), avec need et
             éventuellement howTo (texte "comment l'obtenir").
  IDs à contrôler en jeu : /lt verify compare chaque ID au nom renvoyé par le client.
]]

LegTrackerData.Extensions = {
  {
    key = "Vanilla",
    label = "Vanilla / Classic",
    items = {
      {
        itemID = 19019,
        achievementID = 428,   -- tour de force (lot B, verifie en jeu par /lt verify)
        raids = {
          {instanceID=409, name="Cœur du Magma", bosses="Garr et Baron Geddon (Liens du Cherchevent)"},
          {instanceID=469, name="Repaire de l'Aile noire", bosses="Minerai d'élémentium"},
        },
        name = "Lame-tonnerre, épée bénie du Cherchevent",
        classes = {"WARRIOR","PALADIN","ROGUE","HUNTER","DEATHKNIGHT","MONK","DEMONHUNTER"},
        source = "Suite de quêtes liée aux Liens du Cherchevent, au Seigneur élémentaire Thunderaan et aux raids Cœur du Magma / Repaire de l'Aile noire.",
        quests = {
          {id=7785, name="Examiner le Calice", npc="Grand seigneur Demitrian", zone="Silithus", mapID=81, x=21.8, y=8.6},
          {id=7786, name="Tonneraan le Cherchevent", npc="Grand seigneur Demitrian", zone="Silithus", mapID=81, x=21.8, y=8.6},
        },
        -- 7.1.5.31 : noms alignes sur le client FR (/lt verify). Les deux
        -- Liens portent le meme nom en jeu (droit et gauche).
        trackers = {
          {itemID=18563, name="Liens du Cherchevent", need=1},
          {itemID=18564, name="Liens du Cherchevent", need=1},
          {itemID=17771, name="Barre d'élémentium enchantée", need=10},
          {itemID=19018, name="Lame du baiser du vent dormante", need=1},
        },
      },
      {
        itemID = 17182,
        achievementID = 429,
        raids = { {instanceID=409, name="Cœur du Magma", bosses="Ragnaros (Oeil de Sulfuras), boss du raid (lingots)"} },
        name = "Sulfuras, Main de Ragnaros",
        classes = {"WARRIOR","PALADIN","DRUID","DEATHKNIGHT","SHAMAN"},
        source = "Forge via l'Œil de Sulfuras obtenu sur Ragnaros et le Marteau en sulfuron.",
        quests = {},
        -- 7.1.5.31 : 17193 est le Marteau en sulfuron (1), 17203 le Lingot (8).
        trackers = {
          {itemID=17204, name="Oeil de Sulfuras", need=1},
          {itemID=17203, name="Lingot de sulfuron", need=8},
          {itemID=17193, name="Marteau en sulfuron", need=1},
        },
      },
      { itemID=22630, name="Atiesh, grand bâton du Gardien", classes={"MAGE"}, source="Ancienne suite de quêtes de Naxxramas original. Généralement non obtenable sur Retail moderne.", legacy=true, quests={}, trackers={{itemID=22726,name="Fragment d'Atiesh",need=40}} },
      { itemID=22589, name="Atiesh, grand bâton du Gardien", classes={"DRUID"}, source="Ancienne suite de quêtes de Naxxramas original. Généralement non obtenable sur Retail moderne.", legacy=true, quests={}, trackers={{itemID=22726,name="Fragment d'Atiesh",need=40}} },
      { itemID=22631, name="Atiesh, grand bâton du Gardien", classes={"PRIEST"}, source="Ancienne suite de quêtes de Naxxramas original. Généralement non obtenable sur Retail moderne.", legacy=true, quests={}, trackers={{itemID=22726,name="Fragment d'Atiesh",need=40}} },
      { itemID=22632, name="Atiesh, grand bâton du Gardien", classes={"WARLOCK"}, source="Ancienne suite de quêtes de Naxxramas original. Généralement non obtenable sur Retail moderne.", legacy=true, quests={}, trackers={{itemID=22726,name="Fragment d'Atiesh",need=40}} },
    },
  },
  {
    key = "TheBurningCrusade",
    label = "The Burning Crusade",
    items = {
      { itemID=32837, achievementID=426, raids={{instanceID=564, name="Temple noir", bosses="Illidan Hurlorage"}}, achievementName="Glaives de guerre d'Azzinoth", name="Glaive de guerre d'Azzinoth", classes={"WARRIOR","ROGUE","DEATHKNIGHT","MONK","DEMONHUNTER"}, source="Butin d'Illidan Hurlorage au Temple noir.", quests={}, trackers={} },
      { itemID=32838, achievementID=426, raids={{instanceID=564, name="Temple noir", bosses="Illidan Hurlorage"}}, achievementName="Glaives de guerre d'Azzinoth", name="Glaive de guerre d'Azzinoth", classes={"WARRIOR","ROGUE","DEATHKNIGHT","MONK","DEMONHUNTER"}, source="Butin d'Illidan Hurlorage au Temple noir.", quests={}, trackers={} },
      { itemID=34334, achievementID=725, raids={{instanceID=580, name="Plateau du Puits de soleil", bosses="Kil'jaeden"}}, name="Thori'dal, la Fureur des étoiles", classes={"HUNTER","WARRIOR","ROGUE"}, source="Butin de Kil'jaeden au Plateau du Puits de soleil.", quests={}, trackers={} },
    },
  },
  {
    key = "WrathOfTheLichKing",
    label = "Wrath of the Lich King",
    items = {
      { itemID=46017, achievementID=3142, raids={{instanceID=603, name="Ulduar", bosses="Tous les boss (fragments), puis Yogg-Saron"}}, name="Val'anyr, le marteau des anciens rois", classes={"PALADIN","PRIEST","SHAMAN","DRUID","MONK"}, source="Suite de quêtes d'Ulduar avec les fragments de Val'anyr puis Yogg-Saron.", quests={{id=13622,name="De l'histoire ancienne",npc="Archivum",zone="Ulduar",mapID=147, x=37.0, y=44.0}}, trackers={{itemID=45038,name="Fragment de Val'anyr",need=30},{itemID=45039,name="Fragments brisés de Val'anyr",need=1}} },
      { itemID=49623, achievementID=4623, raids={{instanceID=631, name="Citadelle de la Couronne de glace", bosses="Boss de fin d'aile (éclats), boss du raid (saronite)"}}, name="Deuillelombre", classes={"WARRIOR","PALADIN","DEATHKNIGHT"}, source="Suite de quêtes de la Citadelle de la Couronne de glace.", quests={{id=24549,name="Deuillelombre…",npc="Généralissime Darion Mograine",zone="Citadelle de la Couronne de glace",mapID=118, x=40.8, y=85.5}}, trackers={{itemID=49908,name="Saronite primordiale",need=25},{itemID=50274,name="Éclat givre-ombre",need=50}} },
    },
  },
  {
    key = "Cataclysm",
    label = "Cataclysm",
    items = {
      { itemID=71086, achievementID=5839, raids={{instanceID=720, name="Terres de Feu", bosses="Tous les boss (essences), puis Ragnaros"}}, name="Courroux du dragon, le Repos de Tarecgosa", classes={"MAGE","PRIEST","WARLOCK","DRUID","SHAMAN","EVOKER"}, source="Longue suite de quêtes des Terres de Feu. Les 250 Essences fumantes se siphonnent sur les boss avec le bâton runique (ce ne sont pas des objets, elles ne se suivent pas ici), puis le Cœur de flamme tombe sur Ragnaros.", quests={{id=29453,name="Votre heure est venue",npc="Ziradormi / Kalecgos",zone="Hurlevent / Orgrimmar",mapID=84, x=49.0, y=87.0}}, trackers={{itemID=69848,name="Cœur des flammes",need=1}} },
      { itemID=77949, achievementID=6181, raids={{instanceID=967, name="L'Âme des dragons", bosses="Tous les boss (chapelets de gemmes)"}}, achievementName="Crocs du père", name="Golad, le Crépuscule des Aspects", classes={"ROGUE"}, source="Suite de quêtes de voleur aux Âmes des dragons.", quests={{id=30118,name="Parricide",npc="Irion",zone="Ravenholdt",mapID=25, x=71.5, y=45.2}}, trackers={{itemID=77952,name="Chapelet de gemmes en élémentium",need=60}} },
      { itemID=77950, achievementID=6181, raids={{instanceID=967, name="L'Âme des dragons", bosses="Tous les boss (chapelets de gemmes)"}}, achievementName="Crocs du père", name="Tiriosh, le Cauchemar des âges", classes={"ROGUE"}, source="Suite de quêtes de voleur aux Âmes des dragons.", quests={{id=30118,name="Parricide",npc="Irion",zone="Ravenholdt",mapID=25, x=71.5, y=45.2}}, trackers={{itemID=77952,name="Chapelet de gemmes en élémentium",need=60}} },
    },
  },
  {
    key = "MistsOfPandaria",
    label = "Mists of Pandaria",
    items = {
      -- 7.1.5.31 : IDs corriges. 102245 (Qian-Le) et 102250 (Qian-Ying)
      -- confirmes sur Wowhead ; 102247 = Jina-Kang deduit de la suite
      -- 102245..102250 (a confirmer par /lt verify).
      { itemID=102245, raids={{instanceID=1098, name="Trône du tonnerre", bosses="Boss du raid (étapes de la suite)"}}, name="Qian-Le, Courage de Niuzao", classes=nil, source="Cape légendaire de la suite de quêtes d'Irion en Pandarie.", quests={{id=31454,name="Naissance d'une légende",npc="Irion",zone="L'escalier Dérobé",mapID=433, x=64.7, y=70.5}}, trackers={{itemID=94593,name="Les secrets de l'empire",need=20},{itemID=94221,name="Pierre rituelle shan'ze",need=20}} },
      { itemID=102246, raids={{instanceID=1098, name="Trône du tonnerre", bosses="Boss du raid (étapes de la suite)"}}, name="Xing-Ho, Souffle de Yu'lon", classes=nil, source="Cape légendaire de la suite de quêtes d'Irion en Pandarie.", quests={{id=31454,name="Naissance d'une légende",npc="Irion",zone="L'escalier Dérobé",mapID=433, x=64.7, y=70.5}}, trackers={{itemID=94593,name="Les secrets de l'empire",need=20},{itemID=94221,name="Pierre rituelle shan'ze",need=20}} },
      { itemID=102247, raids={{instanceID=1098, name="Trône du tonnerre", bosses="Boss du raid (étapes de la suite)"}}, name="Jina-Kang, Bonté de Chi Ji", classes=nil, source="Cape légendaire de la suite de quêtes d'Irion en Pandarie.", quests={{id=31454,name="Naissance d'une légende",npc="Irion",zone="L'escalier Dérobé",mapID=433, x=64.7, y=70.5}}, trackers={{itemID=94593,name="Les secrets de l'empire",need=20},{itemID=94221,name="Pierre rituelle shan'ze",need=20}} },
      { itemID=102248, raids={{instanceID=1098, name="Trône du tonnerre", bosses="Boss du raid (étapes de la suite)"}}, name="Fen-Yu, Fureur de Xuen", classes=nil, source="Cape légendaire de la suite de quêtes d'Irion en Pandarie.", quests={{id=31454,name="Naissance d'une légende",npc="Irion",zone="L'escalier Dérobé",mapID=433, x=64.7, y=70.5}}, trackers={{itemID=94593,name="Les secrets de l'empire",need=20},{itemID=94221,name="Pierre rituelle shan'ze",need=20}} },
      { itemID=102249, raids={{instanceID=1098, name="Trône du tonnerre", bosses="Boss du raid (étapes de la suite)"}}, name="Gong-Lu, Force de Xuen", classes=nil, source="Cape légendaire de la suite de quêtes d'Irion en Pandarie.", quests={{id=31454,name="Naissance d'une légende",npc="Irion",zone="L'escalier Dérobé",mapID=433, x=64.7, y=70.5}}, trackers={{itemID=94593,name="Les secrets de l'empire",need=20},{itemID=94221,name="Pierre rituelle shan'ze",need=20}} },
      { itemID=102250, raids={{instanceID=1098, name="Trône du tonnerre", bosses="Boss du raid (étapes de la suite)"}}, name="Qian-Ying, Robustesse de Niuzao", classes=nil, source="Cape légendaire de la suite de quêtes d'Irion en Pandarie.", quests={{id=31454,name="Naissance d'une légende",npc="Irion",zone="L'escalier Dérobé",mapID=433, x=64.7, y=70.5}}, trackers={{itemID=94593,name="Les secrets de l'empire",need=20},{itemID=94221,name="Pierre rituelle shan'ze",need=20}} },
    },
  },
  {
    key = "WarlordsOfDraenor",
    label = "Warlords of Draenor",
    items = {
      -- 7.1.5.31 : IDs et noms realignes sur Wowhead (Thorasus 124634,
      -- Nithramus 124635, Maalus 124636, Sanctus 124637, Etheralus 124638).
      -- Avant : noms decales d'un cran, Thorasus et Etheralus absents.
      -- Noms FR du client via /lt verify. Les anciens composants (113681,
      -- 115508, 118099) etaient des objets sans rapport : retires.
      { itemID=124634, name="Thorasus, cœur de pierre de Draenor", classes=nil, legacy=true, source="Anneau légendaire de Khadgar (Warlords of Draenor). Suite de quêtes retirée avec Legion : plus obtenable.", quests={}, trackers={} },
      { itemID=124635, name="Nithramus, Omnivoyant", classes=nil, legacy=true, source="Anneau légendaire de Khadgar (Warlords of Draenor). Suite de quêtes retirée avec Legion : plus obtenable.", quests={}, trackers={} },
      { itemID=124636, name="Maalus, Buveur de sang", classes=nil, legacy=true, source="Anneau légendaire de Khadgar (Warlords of Draenor). Suite de quêtes retirée avec Legion : plus obtenable.", quests={}, trackers={} },
      { itemID=124637, name="Sanctus, Cachet des indomptables", classes=nil, legacy=true, source="Anneau légendaire de Khadgar (Warlords of Draenor). Suite de quêtes retirée avec Legion : plus obtenable.", quests={}, trackers={} },
      { itemID=124638, name="Etheralus, récompense éternelle", classes=nil, legacy=true, source="Anneau légendaire de Khadgar (Warlords of Draenor). Suite de quêtes retirée avec Legion : plus obtenable.", quests={}, trackers={} },
    },
  },
  {
    key = "Legion",
    label = "Legion",
    items = {
      -- Pêcheur de Terradiance (Underlight Angler, itemID 133755) : canne à
      -- pêche legendaire/artefact de Legion, ouverte a toutes les classes.
      -- Chaine verifiee via Warcraft Wiki et Wowhead le 21/08/2026 (source
      -- initiale du joueur : guide mamytwink.com) :
      --   1. Haut fait prealable "Passons aux gros poissons" / "Bigger Fish
      --      to Fry" (ID 10596) : pecher 18 poissons rares repartis sur
      --      6 zones des Iles Brisees (Haut-Roc, Tornheim, Azsuna,
      --      Val'sharah, Suramar, Grande Mer), chacun necessitant un appat
      --      specifique prealable. Pas modelise en "trackers" ici (criteres
      --      de haut fait, pas des objets qui restent dans les sacs).
      --   2. Une fois le haut fait valide, pecher la "Perle lumineuse"
      --      (itemID 133887) dans n'importe quel banc/eau libre des Iles
      --      Brisees.
      --   3. Quete "Perle lumineuse" (id 40960, demarree par l'objet) ->
      --      remise a l'Archimage Khadgar a Dalaran (Cite violette).
      --   4. Quete "La fontaine de Dalaran" (id 40961) -> Marcia Chase, pres
      --      de la fontaine de Dalaran.
      --   5. Quete "Frenesie de poisson" (id 41010) -> Nat Pagle, a la
      --      fontaine de Dalaran ; scenario au Recif du Crepuscule, au large
      --      de Val'sharah. Recompense finale : Pecheur de Terradiance.
      -- /!\ Coordonnees precises (x/y) des PNJ a Dalaran non retrouvees de
      --     facon fiable pour ce patch : laissees vides (pas de waypoint
      --     TomTom propose) plutot que d'inventer des chiffres non verifies.
      --     Le prerequis "competence de peche 800" cite par d'anciens guides
      --     date du systeme de metiers de Legion ; sa pertinence exacte sur
      --     le client actuel (apres plusieurs refontes des metiers) n'a pas
      --     pu etre confirmee.
      { itemID=133755, name="Pêcheur de Terradiance", classes=nil,
        source="Canne a peche legendaire de Legion (toutes classes). Necessite le haut fait 'Passons aux gros poissons' (18 poissons rares des Iles Brisees), puis la peche d'une Perle lumineuse et la suite de quetes de Khadgar / Marcia Chase / Nat Pagle a Dalaran.",
        quests = {
          {id=40960, name="Perle lumineuse", npc="Archimage Khadgar", zone="Dalaran (Cite violette)"},
          {id=40961, name="La fontaine de Dalaran", npc="Marcia Chase", zone="Dalaran (fontaine)"},
          {id=41010, name="Frénésie de poisson", npc="Nat Pagle", zone="Dalaran (fontaine) -> Recif du Crepuscule, Val'sharah"},
        },
        trackers = {
          {itemID=133887, name="Perle lumineuse", need=1},
        },
      },
      -- 7.1.5.31 (/lt verify) : 132443 / 132444 inverses, 132455 est la
      -- Prescience de Norgannon, 132864 la Demence de Mangaza (Demoniste),
      -- 151819 etait le Coeur fumant : remplace par 144259 (Voeu ardent de
      -- Kil'jaeden, ID et nom FR a confirmer au prochain /lt verify).
      { itemID=132452, name="Secret de Sephuz", classes=nil, source="Objet légendaire Legion, obtenu via contenus Legion ou sources héritage selon disponibilité.", quests={}, trackers={} },
      { itemID=132443, name="Foulée d'Aggramar", classes=nil, source="Objet légendaire Legion, obtenu via contenus Legion ou sources héritage selon disponibilité.", quests={}, trackers={} },
      { itemID=132444, name="Prydaz, chef-d'œuvre de Xavaric", classes=nil, source="Objet légendaire Legion, obtenu via contenus Legion ou sources héritage selon disponibilité.", quests={}, trackers={} },
      { itemID=132455, name="Prescience de Norgannon", classes=nil, source="Objet légendaire Legion, obtenu via contenus Legion ou sources héritage selon disponibilité.", quests={}, trackers={} },
      { itemID=144258, name="Vision future de Velen", classes={"PALADIN","PRIEST","SHAMAN","DRUID","MONK"}, source="Légendaire de soin Legion.", quests={}, trackers={} },
      { itemID=144259, name="Souhait ardent de Kil'jaeden", classes=nil, source="Bijou légendaire Legion.", quests={}, trackers={} },
      { itemID=132864, name="Démence de Mangaza", classes={"WARLOCK"}, source="Légendaire Démoniste Legion.", quests={}, trackers={} },
    },
  },
  {
    key = "BattleForAzeroth",
    label = "Battle for Azeroth",
    items = {
      { itemID=169223, name="Ashjra'kamas, Voile de détermination", classes=nil, source="Cape légendaire de la campagne de N'Zoth.", quests={{id=58582,name="Le retour du prince noir",npc="Magni / Irion",zone="Chambre du Cœur",mapID=1021, x=50.0, y=50.0}}, trackers={} },
    },
  },
  {
    key = "Shadowlands",
    label = "Shadowlands",
    items = {
      { itemID=178926, name="Anneau ombrepeur", classes=nil, source="Anneau de base pour créer un légendaire Shadowlands chez le Runomancien. Suivi générique : le légendaire final dépend du pouvoir choisi.", quests={}, trackers={
        -- 7.1.5.31 : ce sont des MONNAIES (IDs 1828 / 1906 / 2009), pas des
        -- objets : GetItemCount renvoyait toujours 0. 1828 confirme (WoWDB),
        -- 1906 et 2009 a confirmer par /lt verify.
        {currencyID=1828, name="Cendre d'âme", need=1250, howTo="Tourment et désenchantement de légendaires chez le Runomancien."},
        {currencyID=1906, name="Scories d'âme", need=2000, howTo="Tourment (étages supérieurs) et désenchantement de légendaires."},
        {currencyID=2009, name="Flux cosmique", need=2000, howTo="Contenus de Zereth Mortis, raids et donjons de Shadowlands 9.2."},
      } },
    },
  },
  {
    key = "Dragonflight",
    label = "Dragonflight",
    items = {
      -- 7.1.5.31 : l'ancien ID de Nasz'uro (206448) etait celui de Fyr'alath
      -- (un Guerrier possedant Fyr'alath voyait Nasz'uro "Obtenu").
      -- Nasz'uro = 204177, Fyr'alath = 206448 (Wowhead). L'"Eclat" 204987
      -- etait un couteau de travail du cuir (/lt verify) : retire.
      -- Quetes : les anciens IDs 76105 / 78327 etaient sans rapport. 74924
      -- (derniere quete de Nasz'uro) et 77093 (premiere quete de Fyr'alath,
      -- declenchee en equipant la hache) viennent de Wowhead, noms FR verifies
      -- en jeu ; coordonnees non verifiees, donc pas de waypoint.
      { itemID=204177, raids={{instanceID=2569, name="Aberrus, le Creuset ombreux", bosses="Sarkareth"}}, name="Nasz'uro, l'Héritage délié", classes={"EVOKER"}, source="Légendaire Évocateur obtenu via Sarkareth puis suite de quêtes.", quests={{id=74924,name="Nasz'uro, l'Héritage délié",npc="Nozdormu",zone="Maelström (dernière quête de la suite)"}}, trackers={} },
      { itemID=206448, raids={{instanceID=2549, name="Amirdrassil, l'Espoir du Rêve", bosses="Fyrakk (Mythique)"}}, name="Fyr'alath le Pourfendeur de rêve", classes={"WARRIOR","PALADIN","DEATHKNIGHT"}, source="Hache légendaire obtenue via Fyrakka puis suite de quêtes de Dragonflight.", quests={{id=77093,name="La hache d'ombreflamme",npc="Eadweard Dalyngrigge",zone="Archives azérothiennes, Thaldraszus"}}, trackers={} },
    },
  },
  {
    key = "TheWarWithin",
    label = "The War Within",
    items = {
      { itemID=0, name="Aucun légendaire en The War Within", classes=nil, source="The War Within n'a pas eu d'arme ou d'objet légendaire à proprement parler. Les Reshii Wraps (11.2) sont une cape de type artefact.", placeholder=true, quests={}, trackers={} },
    },
  },
  {
    key = "Midnight",
    label = "Midnight",
    items = {
      -- Patch 12.2 : a la sortie de Midnight's Edge, remplacer la fiche
      -- d'attente ci-dessous par une vraie entree (puis /lt verify) :
      --   { itemID=<ID>, name="<nom FR>", classes={<classes lanceurs>},
      --     raids={{instanceID=<ID du raid Worldcore>, name="<nom FR>", bosses="..."}},
      --     source="...", quests={{id=<premiere quete>, name="...", npc="...", zone="..."}},
      --     trackers={...} },
      { itemID=0, name="Midnight's Edge (patch 12.2)", classes=nil, source="Aucun légendaire en 12.1. Le patch 12.2 annonce Midnight's Edge, dague légendaire de lanceur de sorts dont la suite de quêtes démarre dans le raid Worldcore. Fiche complétée à la sortie du patch.", placeholder=true, quests={}, trackers={} },
    },
  },
}
