LegTrackerData = LegTrackerData or {}

--[[
  Structure volontairement simple :
  itemID = objet légendaire final à vérifier dans les sacs/banque/équipement.
  achievementID / achievements = haut fait(s) permettant de confirmer l'acquisition si l'objet n'est plus dans les sacs.
  classes = nil => toutes classes. Sinon liste des classes WoW en anglais : PALADIN, WARRIOR, MAGE...
  quests = quêtes importantes du parcours. Cliquer dans l'addon pose un waypoint TomTom si mapID/x/y existent.
  trackers = composants à suivre via GetItemCount(itemID, true).
]]

LegTrackerData.Extensions = {
  {
    key = "Vanilla",
    label = "Vanilla / Classic",
    items = {
      {
        itemID = 19019,
        name = "Lame-tonnerre, épée bénie du Cherchevent",
        classes = {"WARRIOR","PALADIN","ROGUE","HUNTER","DEATHKNIGHT","MONK","DEMONHUNTER"},
        source = "Suite de quêtes liée aux Liens du Cherchevent, au Seigneur élémentaire Thunderaan et aux raids Cœur du Magma / Repaire de l'Aile noire.",
        quests = {
          {id=7785, name="Examinez le récipient", npc="Grand seigneur Demitrian", zone="Silithus", mapID=81, x=21.8, y=8.6},
          {id=7786, name="Thunderaan le Cherchevent", npc="Grand seigneur Demitrian", zone="Silithus", mapID=81, x=21.8, y=8.6},
        },
        trackers = {
          {itemID=18563, name="Lien du Cherchevent droit", need=1},
          {itemID=18564, name="Lien du Cherchevent gauche", need=1},
          {itemID=17771, name="Barre d'élémentium enchantée", need=10},
          {itemID=19018, name="Lame dormante bénie du Cherchevent", need=1},
        },
      },
      {
        itemID = 17182,
        name = "Sulfuras, Main de Ragnaros",
        classes = {"WARRIOR","PALADIN","DRUID","DEATHKNIGHT","SHAMAN"},
        source = "Forge via l'Œil de Sulfuras obtenu sur Ragnaros et le Marteau en sulfuron.",
        quests = {},
        trackers = {
          {itemID=17204, name="Œil de Sulfuras", need=1},
          {itemID=17193, name="Barre de sulfuron", need=8},
          {itemID=17203, name="Lingot de sulfuron", need=1},
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
      { itemID=32837, name="Glaive de guerre d'Azzinoth", classes={"WARRIOR","ROGUE","DEATHKNIGHT","MONK","DEMONHUNTER"}, source="Butin d'Illidan Hurlorage au Temple noir.", quests={}, trackers={} },
      { itemID=32838, name="Glaive de guerre d'Azzinoth", classes={"WARRIOR","ROGUE","DEATHKNIGHT","MONK","DEMONHUNTER"}, source="Butin d'Illidan Hurlorage au Temple noir.", quests={}, trackers={} },
      { itemID=34334, name="Thori'dal, la Fureur des étoiles", classes={"HUNTER","WARRIOR","ROGUE"}, source="Butin de Kil'jaeden au Plateau du Puits de soleil.", quests={}, trackers={} },
    },
  },
  {
    key = "WrathOfTheLichKing",
    label = "Wrath of the Lich King",
    items = {
      { itemID=46017, name="Val'anyr, le marteau des anciens rois", classes={"PALADIN","PRIEST","SHAMAN","DRUID","MONK"}, source="Suite de quêtes d'Ulduar avec les fragments de Val'anyr puis Yogg-Saron.", quests={{id=13622,name="Ancienne histoire",npc="Archivum",zone="Ulduar",mapID=147, x=37.0, y=44.0}}, trackers={{itemID=45038,name="Fragment de Val'anyr",need=30},{itemID=45039,name="Fragments brisés de Val'anyr",need=1}} },
      { itemID=49623, name="Deuillelombre", classes={"WARRIOR","PALADIN","DEATHKNIGHT"}, source="Suite de quêtes de la Citadelle de la Couronne de glace.", quests={{id=24549,name="Deuillelombre...",npc="Généralissime Darion Mograine",zone="Citadelle de la Couronne de glace",mapID=118, x=40.8, y=85.5}}, trackers={{itemID=50274,name="Saronite primordiale",need=25},{itemID=50226,name="Éclat ombreglace",need=50}} },
    },
  },
  {
    key = "Cataclysm",
    label = "Cataclysm",
    items = {
      { itemID=71086, name="Courroux du dragon, le Repos de Tarecgosa", classes={"MAGE","PRIEST","WARLOCK","DRUID","SHAMAN","EVOKER"}, source="Longue suite de quêtes des Terres de Feu.", quests={{id=29453,name="Votre heure est venue",npc="Ziradormi / Kalecgos",zone="Hurlevent / Orgrimmar",mapID=84, x=49.0, y=87.0}}, trackers={{itemID=71083,name="Bâton runique Nordrassil",need=1},{itemID=71635,name="Essence bouillonnante",need=250},{itemID=71998,name="Cœur de flamme",need=1}} },
      { itemID=77949, name="Golad, Crépuscule des Aspects", classes={"ROGUE"}, source="Suite de quêtes de voleur aux Âmes des dragons.", quests={{id=30118,name="Acte II : le sang du traître",npc="Irion",zone="Ravenholdt",mapID=25, x=71.5, y=45.2}}, trackers={{itemID=77952,name="Les Crocs du père",need=1}} },
      { itemID=77950, name="Tiriosh, Cauchemar des âges", classes={"ROGUE"}, source="Suite de quêtes de voleur aux Âmes des dragons.", quests={{id=30118,name="Acte II : le sang du traître",npc="Irion",zone="Ravenholdt",mapID=25, x=71.5, y=45.2}}, trackers={{itemID=77952,name="Les Crocs du père",need=1}} },
    },
  },
  {
    key = "MistsOfPandaria",
    label = "Mists of Pandaria",
    items = {
      { itemID=102246, name="Xing-Ho, Souffle de Yu'lon", classes=nil, source="Cape légendaire de la suite de quêtes d'Irion en Pandarie.", quests={{id=31454,name="Une légende en devenir",npc="Irion",zone="L'escalier Dérobé",mapID=433, x=64.7, y=70.5}}, trackers={{itemID=94221,name="Secret de l'empire",need=20},{itemID=94593,name="Pierre runique des titans",need=12}} },
      { itemID=102247, name="Qian-Le, Courage de Niuzao", classes=nil, source="Cape légendaire de la suite de quêtes d'Irion en Pandarie.", quests={{id=31454,name="Une légende en devenir",npc="Irion",zone="L'escalier Dérobé",mapID=433, x=64.7, y=70.5}}, trackers={{itemID=94221,name="Secret de l'empire",need=20},{itemID=94593,name="Pierre runique des titans",need=12}} },
      { itemID=102248, name="Fen-Yu, Fureur de Xuen", classes=nil, source="Cape légendaire de la suite de quêtes d'Irion en Pandarie.", quests={{id=31454,name="Une légende en devenir",npc="Irion",zone="L'escalier Dérobé",mapID=433, x=64.7, y=70.5}}, trackers={{itemID=94221,name="Secret de l'empire",need=20},{itemID=94593,name="Pierre runique des titans",need=12}} },
      { itemID=102249, name="Gong-Lu, Force de Xuen", classes=nil, source="Cape légendaire de la suite de quêtes d'Irion en Pandarie.", quests={{id=31454,name="Une légende en devenir",npc="Irion",zone="L'escalier Dérobé",mapID=433, x=64.7, y=70.5}}, trackers={{itemID=94221,name="Secret de l'empire",need=20},{itemID=94593,name="Pierre runique des titans",need=12}} },
      { itemID=102250, name="Jina-Kang, Bonté de Chi Ji", classes=nil, source="Cape légendaire de la suite de quêtes d'Irion en Pandarie.", quests={{id=31454,name="Une légende en devenir",npc="Irion",zone="L'escalier Dérobé",mapID=433, x=64.7, y=70.5}}, trackers={{itemID=94221,name="Secret de l'empire",need=20},{itemID=94593,name="Pierre runique des titans",need=12}} },
    },
  },
  {
    key = "WarlordsOfDraenor",
    label = "Warlords of Draenor",
    items = {
      { itemID=124634, name="Sanctus, cachet de l'Indomptable", classes=nil, source="Anneau légendaire de Khadgar, suite de quêtes de Warlords of Draenor.", quests={{id=36157,name="L'appel de l'archimage",npc="Khadgar",zone="Draenor",mapID=525, x=54.0, y=20.0}}, trackers={{itemID=118099,name="Anneau de départ de Khadgar",need=1},{itemID=113681,name="Noyau de puissance abrogateur",need=125},{itemID=115508,name="Pierre runique élémentaire",need=900}} },
      { itemID=124635, name="Maalus, l'assoiffé de sang", classes=nil, source="Anneau légendaire de Khadgar, suite de quêtes de Warlords of Draenor.", quests={{id=36157,name="L'appel de l'archimage",npc="Khadgar",zone="Draenor",mapID=525, x=54.0, y=20.0}}, trackers={{itemID=113681,name="Noyau de puissance abrogateur",need=125},{itemID=115508,name="Pierre runique élémentaire",need=900}} },
      { itemID=124636, name="Nithramus, l'Omnivoyant", classes=nil, source="Anneau légendaire de Khadgar, suite de quêtes de Warlords of Draenor.", quests={{id=36157,name="L'appel de l'archimage",npc="Khadgar",zone="Draenor",mapID=525, x=54.0, y=20.0}}, trackers={{itemID=113681,name="Noyau de puissance abrogateur",need=125},{itemID=115508,name="Pierre runique élémentaire",need=900}} },
      { itemID=124637, name="Etheralus, récompense éternelle", classes=nil, source="Anneau légendaire de Khadgar, suite de quêtes de Warlords of Draenor.", quests={{id=36157,name="L'appel de l'archimage",npc="Khadgar",zone="Draenor",mapID=525, x=54.0, y=20.0}}, trackers={{itemID=113681,name="Noyau de puissance abrogateur",need=125},{itemID=115508,name="Pierre runique élémentaire",need=900}} },
    },
  },
  {
    key = "Legion",
    label = "Legion",
    items = {
      { itemID=132452, name="Secret de Sephuz", classes=nil, source="Objet légendaire Legion, obtenu via contenus Legion ou sources héritage selon disponibilité.", quests={}, trackers={} },
      { itemID=132443, name="Prydaz, chef-d'œuvre de Xavaric", classes=nil, source="Objet légendaire Legion, obtenu via contenus Legion ou sources héritage selon disponibilité.", quests={}, trackers={} },
      { itemID=132444, name="Foulée d'Aggramar", classes=nil, source="Objet légendaire Legion, obtenu via contenus Legion ou sources héritage selon disponibilité.", quests={}, trackers={} },
      { itemID=132455, name="Racines de Shaladrassil", classes=nil, source="Objet légendaire Legion, obtenu via contenus Legion ou sources héritage selon disponibilité.", quests={}, trackers={} },
      { itemID=144258, name="Vision prophétique de Velen", classes={"PALADIN","PRIEST","SHAMAN","DRUID","MONK"}, source="Légendaire de soin Legion.", quests={}, trackers={} },
      { itemID=151819, name="La Vision brûlante de Kil'jaeden", classes=nil, source="Bijou légendaire Legion.", quests={}, trackers={} },
      { itemID=132864, name="Justice du Porteur de Lumière", classes={"PALADIN"}, source="Légendaire Paladin Legion.", quests={}, trackers={} },
    },
  },
  {
    key = "BattleForAzeroth",
    label = "Battle for Azeroth",
    items = {
      { itemID=169223, name="Ashjra'kamas, Voile de détermination", classes=nil, source="Cape légendaire de la campagne de N'Zoth.", quests={{id=58582,name="Retour du Prince noir",npc="Magni / Irion",zone="Chambre du Cœur",mapID=1021, x=50.0, y=50.0}}, trackers={{itemID=169223,name="Ashjra'kamas",need=1}} },
    },
  },
  {
    key = "Shadowlands",
    label = "Shadowlands",
    items = {
      { itemID=178926, name="Rune du sculpteur de runes", classes=nil, source="Base de création des légendaires Shadowlands chez le Runomancien. Suivi générique : l'objet final dépend du pouvoir choisi.", quests={{id=60215,name="Le souvenir du Runomancien",npc="Le Runomancien",zone="Tourment",mapID=1543, x=48.0, y=39.0}}, trackers={{itemID=183955,name="Cendre d'âme",need=1250},{itemID=187707,name="Scories d'âme",need=2000},{itemID=190189,name="Flux cosmique",need=2000}} },
    },
  },
  {
    key = "Dragonflight",
    label = "Dragonflight",
    items = {
      { itemID=206448, name="Nas'zuro, l'Héritage délié", classes={"EVOKER"}, source="Légendaire Évocateur obtenu via Sarkareth puis suite de quêtes.", quests={{id=76105,name="L'héritage fracturé",npc="Nozdormu / Emberthal",zone="Valdrakken",mapID=2112, x=61.0, y=42.0}}, trackers={{itemID=204987,name="Éclat ancien de Nas'zuro",need=1}} },
      { itemID=206989, name="Fyr'alath le Pourfendeur de rêves", classes={"WARRIOR","PALADIN","DEATHKNIGHT"}, source="Hache légendaire obtenue via Fyrakka puis suite de quêtes de Dragonflight.", quests={{id=78327,name="La hache rêvée",npc="Eadweard Dalyngrigge",zone="Rêve d'Émeraude",mapID=2200, x=50.0, y=62.0}}, trackers={{itemID=206989,name="Fyr'alath",need=1}} },
    },
  },
  {
    key = "TheWarWithin",
    label = "The War Within",
    items = {
      { itemID=226190, name="Légendaire de The War Within", classes=nil, source="Emplacement préparé pour les légendaires The War Within. À compléter avec les IDs exacts au fil des patchs.", placeholder=true, quests={}, trackers={} },
    },
  },
  {
    key = "Midnight",
    label = "Midnight",
    items = {
      { itemID=0, name="À compléter - légendaires Midnight", classes=nil, source="Extension non finalisée : structure prête pour ajout des futurs objets légendaires.", placeholder=true, quests={}, trackers={} },
    },
  },
}
