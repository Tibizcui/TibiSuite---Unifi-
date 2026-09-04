-- ================================================================
-- RenTracker v7.0
-- Suivi des reputations | Toutes les extensions depuis vanilla
-- Auteur : Tibiscui - Kirin Tor
-- ================================================================

local ADDON = "RenTracker"

-- RenTrackerData est rempli par les fichiers data/
RenTrackerData = RenTrackerData or {}

-- Frame principale : declaree tot pour etre capturee comme upvalue par
-- toutes les fonctions definies plus bas (ex : AutoTrackFactionByZone).
local mainFrame

-- ================================================================
-- RAFRAICHISSEMENT GROUPE (debounce)
-- Regroupe les refresh declenches en rafale (UPDATE_FACTION,
-- QUEST_LOG_UPDATE...) en un seul appel pour eviter les micro-freezes.
-- ================================================================
local refreshPending = false
local function ScheduleRefresh()
  if refreshPending then return end
  refreshPending = true
  C_Timer.After(0.15, function()
    refreshPending = false
    if mainFrame and mainFrame:IsShown() and mainFrame.RefreshContent then
      mainFrame:RefreshContent()
    end
  end)
end

-- ================================================================
-- HAUT FAIT : statut de completion (sur le compte)
-- Retourne true si le haut fait est complete.
-- ================================================================
local function IsAchievementDone(achID)
  if not achID then return false end
  if GetAchievementInfo then
    local _, _, _, completed = GetAchievementInfo(achID)
    return completed == true
  end
  return false
end


-- ================================================================
-- COULEURS RENOWN (style qualite d'objet WoW)
-- Adaptatif selon le renownCap de l'extension
-- ================================================================
-- Grille unique : couleur ET label partagent exactement les memes seuils,
-- pour eviter tout desaccord (barre d'une couleur / texte d'un autre rang).
local function GetRenownTier(rank, cap)
  cap = cap or 20
  if rank >= cap then
    return {r=1.00, g=0.50, b=0.00}, "Exalté"   -- Orange
  end
  local pct = rank / cap
  if pct >= 0.85 then return {r=0.65, g=0.30, b=1.00}, "Révéré"   end  -- Violet
  if pct >= 0.65 then return {r=0.30, g=0.60, b=1.00}, "Honoré"   end  -- Bleu
  if pct >= 0.45 then return {r=0.30, g=0.85, b=0.30}, "Aimable"  end  -- Vert
  if pct >= 0.25 then return {r=0.55, g=0.85, b=0.55}, "Familier" end  -- Vert clair
  return              {r=1.00, g=1.00, b=1.00}, "Neutre"              -- Blanc
end

local function GetRenownColor(rank, cap)
  local col = GetRenownTier(rank, cap)
  return col
end

local function GetRenownLabel(rank, cap)
  local _, lbl = GetRenownTier(rank, cap)
  return lbl
end

-- Ordre d'affichage des extensions (du plus recent au plus ancien)
local EXT_ROW1  = { "Midnight","TheWarWithin","Dragonflight","Shadowlands","BattleForAzeroth","Legion" }
local EXT_ROW2  = { "WarlordsOfDraenor","MistsOfPandaria","Cataclysme","WrathOfTheLichKing","TheBurningCrusade","Vanilla" }
local EXT_ORDER = {}
for _, v in ipairs(EXT_ROW1) do table.insert(EXT_ORDER, v) end
for _, v in ipairs(EXT_ROW2) do table.insert(EXT_ORDER, v) end

-- Labels courts dans l'onglet : SIGLE uniquement
local EXT_LABELS = {
  Midnight           = "MID",
  TheWarWithin       = "TWW",
  Dragonflight       = "DF",
  Shadowlands        = "SL",
  BattleForAzeroth   = "BfA",
  Legion             = "LEG",
  WarlordsOfDraenor  = "WoD",
  MistsOfPandaria    = "MoP",
  Cataclysme         = "CATA",
  WrathOfTheLichKing = "WotLK",
  TheBurningCrusade  = "TBC",
}
-- Noms complets pour les tooltips au survol
local EXT_FULLNAMES = {
  Midnight           = "Midnight (12.0)",
  TheWarWithin       = "The War Within (11.0)",
  Dragonflight       = "Dragonflight (10.0)",
  Shadowlands        = "Shadowlands (9.0)",
  BattleForAzeroth   = "Battle for Azeroth (8.0)",
  Legion             = "Legion (7.0)",
  WarlordsOfDraenor  = "Warlords of Draenor (6.0)",
  MistsOfPandaria    = "Mists of Pandaria (5.0)",
  Cataclysme         = "Cataclysme (4.0)",
  WrathOfTheLichKing = "Wrath of the Lich King (3.0)",
  TheBurningCrusade  = "The Burning Crusade (2.0)",
}
-- Couleurs emblematiques par extension (utilisees pour les onglets)
local EXT_TAB_COLORS = {
  Midnight           = {r=0.58, g=0.30, b=0.95},  -- Violet nuit de Quel'Thalas
  TheWarWithin       = {r=0.55, g=0.75, b=0.95},  -- Bleu acier de Khaz Algar
  Dragonflight       = {r=0.95, g=0.45, b=0.10},  -- Orange dragon des Iles
  Shadowlands        = {r=0.45, g=0.55, b=0.95},  -- Bleu spectral de l'ombre
  BattleForAzeroth   = {r=0.85, g=0.25, b=0.25},  -- Rouge guerre Horde/Alliance
  Legion             = {r=0.60, g=0.15, b=0.85},  -- Violet Feu Leger / demon
  WarlordsOfDraenor  = {r=0.85, g=0.50, b=0.10},  -- Orange/brun Draenor
  MistsOfPandaria    = {r=0.20, g=0.65, b=0.45},  -- Vert jade de Pandarie
  Cataclysme         = {r=0.95, g=0.35, b=0.10},  -- Rouge/orange feu de Deathwing
  WrathOfTheLichKing = {r=0.65, g=0.85, b=1.00},  -- Bleu glace de Northrend
  TheBurningCrusade  = {r=0.20, g=0.75, b=0.28},  -- Vert field / portail TBC officiel
}

-- Largeur fixe : 600px pour 6 onglets confortables par rangee
local FRAME_W = 600

-- ================================================================
-- SAUVEGARDE
-- ================================================================
RenTrackerDB = RenTrackerDB or {
  pos        = {point="CENTER", x=0, y=0},
  open       = false,
  selectedFac = nil,   -- {cat="principale", name="Cercle Cénarie"}
  extension  = "Midnight",
  renown     = {},
  mmAngle    = 220,
  sections   = {weekly=false, onetime=false, daily=false},
  groups     = {principale=true, secondaire=true, pvp=false},
  options    = {autoTrack=true, loginMsg=true, sound=false},
}

-- Normalise la DB : garantit que les sous-tables et options existent
-- meme pour les profils sauvegardes avant l'ajout de ces champs.
local OPTION_DEFAULTS = { autoTrack=true, loginMsg=true, sound=false }
local function EnsureDB()
  RenTrackerDB.renown   = RenTrackerDB.renown   or {}
  RenTrackerDB.sections = RenTrackerDB.sections or {weekly=false, onetime=false, daily=false}
  RenTrackerDB.groups   = RenTrackerDB.groups   or {principale=true, secondaire=true, pvp=false}
  RenTrackerDB.options  = RenTrackerDB.options  or {}
  for k, v in pairs(OPTION_DEFAULTS) do
    if RenTrackerDB.options[k] == nil then RenTrackerDB.options[k] = v end
  end
end

-- ================================================================
-- SUIVI AUTO DE REPUTATION PAR ZONE
-- ================================================================
-- Mapping zone (mapID / sous-zone) -> extension + index faction
local ZONE_FACTION_MAP = {
  -- Midnight
  [2395] = {ext="Midnight", fIdx=1},   -- Bois des Chants eternels
  [2437] = {ext="Midnight", fIdx=2},   -- Zul'Aman
  [2413] = {ext="Midnight", fIdx=3},   -- Harandar
  [2405] = {ext="Midnight", fIdx=4},   -- Tempete du Vide
  -- The War Within
  [2248] = {ext="TheWarWithin", fIdx=1},  -- Ile de Dorn
  [2255] = {ext="TheWarWithin", fIdx=2},  -- Profondeurs Sonnantes
  [2346] = {ext="TheWarWithin", fIdx=3},  -- Sacre-Declin
  [2340] = {ext="TheWarWithin", fIdx=4},  -- Azj-Kahet
  -- Dragonflight
  [2022] = {ext="Dragonflight", fIdx=1},  -- Rivages de l'Eveil
  [2024] = {ext="Dragonflight", fIdx=2},  -- Etendue d'Azur
  [2023] = {ext="Dragonflight", fIdx=3},  -- Plaines d'Ohn'ahran
  [2112] = {ext="Dragonflight", fIdx=4},  -- Thaldraszus / Valdrakken
  [2133] = {ext="Dragonflight", fIdx=5},  -- Caverne de Zaralek
  [2200] = {ext="Dragonflight", fIdx=6},  -- Reve d'Emeraude
  -- Shadowlands
  [1533] = {ext="Shadowlands", fIdx=1},   -- Bastion
  [1536] = {ext="Shadowlands", fIdx=2},   -- Maldraxxus
  [1565] = {ext="Shadowlands", fIdx=3},   -- Ardenweald
  [1525] = {ext="Shadowlands", fIdx=4},   -- Revendreth
  -- BfA
  [896]  = {ext="BattleForAzeroth", fIdx=2},  -- Zandalar
  [862]  = {ext="BattleForAzeroth", fIdx=3},  -- Kul Tiras
  -- Legion
  [1015] = {ext="Legion", fIdx=1},  -- Suramar
  [1017] = {ext="Legion", fIdx=2},  -- Stormheim
  [1021] = {ext="Legion", fIdx=3},  -- Val'sharah
  [1018] = {ext="Legion", fIdx=4},  -- Haut-Roc
  [1044] = {ext="Legion", fIdx=5},  -- Azsuna
  -- WoD
  [542]  = {ext="WarlordsOfDraenor", fIdx=1},  -- Fleches de Arak
  [543]  = {ext="WarlordsOfDraenor", fIdx=2},  -- Vallee de l'Ombre de Lune
  [534]  = {ext="WarlordsOfDraenor", fIdx=3},  -- Crete de Feu-de-Givre
  [550]  = {ext="WarlordsOfDraenor", fIdx=4},  -- Nagrand (Draenor)
  [572]  = {ext="WarlordsOfDraenor", fIdx=5},  -- Jungle de Tanaan
  -- MoP
  [390]  = {ext="MistsOfPandaria", fIdx=1},  -- Vale des Fleurs eternelles
  [422]  = {ext="MistsOfPandaria", fIdx=2},  -- Terres Redoutees
  [388]  = {ext="MistsOfPandaria", fIdx=3},  -- Pentes de Townlong
  [371]  = {ext="MistsOfPandaria", fIdx=5},  -- Foret de Jade
  -- Cataclysme
  [606]  = {ext="Cataclysme", fIdx=1},  -- Mont Hyjal
  [640]  = {ext="Cataclysme", fIdx=2},  -- Profondeurs de Terre
  [693]  = {ext="Cataclysme", fIdx=3},  -- Uldum
  [610]  = {ext="Cataclysme", fIdx=4},  -- Vashj'ir
  [627]  = {ext="Cataclysme", fIdx=5},  -- Hautes Terres du Crepuscule
  -- WotLK
  [394]  = {ext="WrathOfTheLichKing", fIdx=1},  -- Pics des Tempetes
  [116]  = {ext="WrathOfTheLichKing", fIdx=2},  -- Draconides
  [118]  = {ext="WrathOfTheLichKing", fIdx=3},  -- Icecrown
  [125]  = {ext="WrathOfTheLichKing", fIdx=5},  -- Dalaran WotLK (Kirin Tor)
  -- TBC
  [978]  = {ext="TheBurningCrusade", fIdx=1},  -- Shattrath (Aldor par defaut)
  [1014] = {ext="TheBurningCrusade", fIdx=3},  -- Shadowmoon Valley
  [941]  = {ext="TheBurningCrusade", fIdx=3},  -- Zangarmarsh
}

local function AutoTrackFactionByZone()
  -- Respecte l'option d'auto-suivi (desactivable dans le panneau d'options)
  if RenTrackerDB.options and RenTrackerDB.options.autoTrack == false then return end
  if not C_Map then return end
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID then return end
  local entry = ZONE_FACTION_MAP[mapID]
  if not entry then return end

  -- Changer l'extension affichee dans l'addon si besoin
  if RenTrackerDB.extension ~= entry.ext then
    RenTrackerDB.extension = entry.ext
  end

  -- Mettre a jour la Barre d'etat 1 de WoW
  local factions = RenTrackerData and RenTrackerData[entry.ext] and RenTrackerData[entry.ext].factions

  -- Selectionner REELLEMENT la faction dans l'addon (cle selectedFac).
  -- On convertit l'index fIdx en {cat, name} attendu par l'interface.
  if factions and factions[entry.fIdx] then
    local f = factions[entry.fIdx]
    RenTrackerDB.selectedFac = { cat = f.category or "secondaire", name = f.name }
  end
  if factions and factions[entry.fIdx] then
    local facID = factions[entry.fIdx].id
    if facID then
      -- API moderne (Dragonflight+) : C_Reputation.SetWatchedFactionByID
      if C_Reputation and C_Reputation.SetWatchedFactionByID then
        C_Reputation.SetWatchedFactionByID(facID)
      -- API legacy (pre-Dragonflight) : parcourir GetFactionInfo
      elseif GetNumFactions and SetWatchedFactionIndex then
        for i = 1, GetNumFactions() do
          local fdata = C_Reputation and C_Reputation.GetFactionDataByIndex and C_Reputation.GetFactionDataByIndex(i)
          if fdata and fdata.factionID == facID then
            SetWatchedFactionIndex(i)
            break
          end
          -- Fallback absolu si C_Reputation.GetFactionDataByIndex absent
          if not (C_Reputation and C_Reputation.GetFactionDataByIndex) then
            local name,_,_,_,_,_,_,_,_,_,_,_,_,fid = GetFactionInfo(i)
            if fid == facID then
              SetWatchedFactionIndex(i)
              break
            end
          end
        end
      end
    end
  end

  -- Rafraichir l'UI de l'addon si visible
  if mainFrame and mainFrame:IsShown() and mainFrame.RefreshContent then
    mainFrame:RefreshContent()
  end
end

-- Retourne les factions de l'extension active
local function GetActiveFactions()
  local ext = RenTrackerDB.extension or "Midnight"
  if RenTrackerData and RenTrackerData[ext] then
    return RenTrackerData[ext].factions or {}
  end
  return {}
end

-- Retourne les factions d'une catégorie, triées alphabétiquement
local function GetFactionsByCategory(cat)
  local result = {}
  for _, fac in ipairs(GetActiveFactions()) do
    if (fac.category or "secondaire") == cat then
      table.insert(result, fac)
    end
  end
  table.sort(result, function(a, b) return a.name < b.name end)
  return result
end

-- État d'ouverture des groupes (persisté en DB)
local GROUP_DEFAULTS = { principale=true, secondaire=true, pvp=false }

-- Retourne les metadonnees de l'extension active
local function GetActiveExtData()
  local ext = RenTrackerDB.extension or "Midnight"
  if RenTrackerData and RenTrackerData[ext] then
    return RenTrackerData[ext]
  end
  return {renownCap=20, repPerRank=2500, color={r=0.5,g=0.5,b=0.5}}
end

-- ================================================================
-- SYSTEME CLASSIQUE : niveaux et couleurs officiels WoW
-- ================================================================
local CLASSIC_LEVELS = {
  {id=1, name="Hostile",  color={r=0.80,g=0.05,b=0.05}},
  {id=2, name="Inamical", color={r=0.90,g=0.25,b=0.05}},
  {id=3, name="Neutre",   color={r=0.85,g=0.85,b=0.00}},
  {id=4, name="Aimable",  color={r=0.35,g=0.75,b=0.35}},
  {id=5, name="Honoré",   color={r=0.30,g=0.75,b=0.65}},
  {id=6, name="Révéré",   color={r=0.25,g=0.65,b=0.90}},
  {id=7, name="Exalté",   color={r=0.95,g=0.70,b=0.10}},
  {id=8, name="Paragon",  color={r=1.00,g=0.90,b=0.50}},
}

-- ================================================================
-- SYSTEME AMITIE (Friendship) : rangs personnalises nommes (ex.
-- Capitaine Tokka, patch 12.1), API native C_GossipInfo.GetFriendshipReputation.
-- Different du systeme "renown" (pas de Renom 1-20, pas de Paragon) : chaque
-- faction a ses propres noms de rang, lus en direct depuis l'API - aucun
-- palier n'est code en dur ici, on affiche exactement ce que le jeu renvoie.
-- ================================================================
local function GetFriendshipData(factionId, fac)
  local ranks = (fac and fac.ranks) or {}
  local info
  if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
    local ok, res = pcall(C_GossipInfo.GetFriendshipReputation, factionId)
    if ok and res and res.standing then info = res end
  end
  if info then
    local cur     = info.standing or 0
    local capped  = not info.nextThreshold
    local max     = info.nextThreshold or info.maxRep or math.max(cur, 1)
    local pct     = capped and 1.0 or math.min(1.0, cur / math.max(max, 1))
    return {
      system     = "friendship",
      cur        = cur,
      max        = max,
      pct        = pct,
      paragon    = false,
      exalted    = false,
      hasParagon = false,
      capped     = capped,
      cap        = #ranks,
      color      = {r=0.20, g=0.70, b=0.55},
      label      = info.name or info.text or ranks[1] or "?",
      found      = true,
    }
  end
  -- Repli : API absente ou faction jamais rencontree (hors-jeu / mock / non
  -- encore debloquee). Affiche le premier rang connu sans pretendre a un
  -- pourcentage reel.
  return {
    system = "friendship", cur = 0, max = 1, pct = 0,
    paragon = false, exalted = false, hasParagon = false, capped = false,
    cap = #ranks, color = {r=0.20, g=0.70, b=0.55}, label = ranks[1] or "?",
    found = false,
  }
end

-- ================================================================
-- LECTURE REPUTATION UNIVERSELLE
-- Supporte : renown (Shadowlands+), classic (BfA et avant), et friendship
-- (rangs personnalises nommes, ex. Capitaine Tokka - voir fac.friendship).
-- hasParagon=true  -> affiche PARAGON apres exalte
-- hasParagon=false -> affiche EXALTÉ (violet) apres exalte
-- ================================================================
local function GetRenownData(factionId, fac)
  if fac and fac.friendship then
    return GetFriendshipData(factionId, fac)
  end
  local extData    = GetActiveExtData()
  local system     = extData.system     or "renown"
  local RENOWN_CAP = extData.renownCap  or 20
  local REP_PER    = extData.repPerRank or 2500
  local hasParagon = extData.hasParagon  -- nil = renown extensions (ont paragon)
  if hasParagon == nil then hasParagon = true end

  -- Systeme RENOWN (SL / DF / TWW / Midnight) --------------------
  if system == "renown" then
    if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
      local ok, d = pcall(C_MajorFactions.GetMajorFactionData, factionId)
      if ok and d then
        local rank    = d.renownLevel            or 0
        local cur     = d.renownReputationEarned or 0
        local atCap   = rank >= RENOWN_CAP
        -- Paragon live via API officielle
        local isLiveParagon = false
        if atCap and hasParagon and C_Reputation and C_Reputation.IsFactionParagon then
          local ok2, res = pcall(C_Reputation.IsFactionParagon, factionId)
          if ok2 then isLiveParagon = res end
        end
        local paragon = atCap and hasParagon
        local col     = GetRenownColor(rank, RENOWN_CAP)
        local lbl     = GetRenownLabel(rank, RENOWN_CAP)
        -- Si paragon actif : lire la progression paragon
        local parCur, parMax = 0, 10000
        if isLiveParagon and C_Reputation.GetFactionParagonInfo then
          local ok3, pCur, pMax = pcall(C_Reputation.GetFactionParagonInfo, factionId)
          if ok3 and pCur and pMax then
            parCur = pCur % pMax
            parMax = pMax
            cur    = parCur
          end
        end
        return {
          system       = "renown",
          rank         = rank,
          cur          = cur,
          max          = atCap and parMax or REP_PER,
          pct          = atCap and (parCur / parMax) or math.min(1.0, cur / REP_PER),
          paragon      = paragon,
          liveParagon  = isLiveParagon,
          cap          = RENOWN_CAP,
          color        = col,
          label        = lbl,
          found        = true,
        }
      end
    end
    -- Fallback renown
    local saved = RenTrackerDB.renown[factionId] or 0
    local rank  = math.min(math.floor(saved / REP_PER), RENOWN_CAP)
    local cur   = saved % REP_PER
    local col   = GetRenownColor(rank, RENOWN_CAP)
    local lbl   = GetRenownLabel(rank, RENOWN_CAP)
    return {
      system  = "renown",
      rank    = rank,
      cur     = cur,
      max     = REP_PER,
      pct     = (cur / REP_PER),
      paragon = (rank >= RENOWN_CAP) and hasParagon,
      cap     = RENOWN_CAP,
      color   = col,
      label   = lbl,
      found   = false,
    }
  end

  -- Systeme CLASSIQUE (BfA, Legion, WoD, etc.) -------------------
  if system == "classic" then
    if C_Reputation and C_Reputation.GetFactionDataByID then
      local ok, d = pcall(C_Reputation.GetFactionDataByID, factionId)
      if ok and d then
        local reaction = d.reaction or 3
        local curMin   = d.currentReactionThreshold  or 0
        local curMax   = d.nextReactionThreshold      or 1
        local curVal   = d.currentStanding           or 0
        local atExalt  = (reaction >= 8)
        local lvlData  = CLASSIC_LEVELS[reaction] or CLASSIC_LEVELS[3]
        local pct      = (curMax > curMin)
                         and math.min(1.0, (curVal - curMin) / (curMax - curMin))
                         or (atExalt and 1.0 or 0)

        -- Paragon live pour Legion et BfA
        local isLiveParagon = false
        local parCur, parMax = 0, 10000
        if atExalt and hasParagon and C_Reputation.IsFactionParagon then
          local ok2, res = pcall(C_Reputation.IsFactionParagon, factionId)
          if ok2 then isLiveParagon = res end
          if isLiveParagon and C_Reputation.GetFactionParagonInfo then
            local ok3, pCur, pMax = pcall(C_Reputation.GetFactionParagonInfo, factionId)
            if ok3 and pCur and pMax then
              parCur = pCur % pMax
              parMax = pMax
              pct    = parCur / parMax
              curVal = parCur
              curMin = 0
              curMax = parMax
            end
          end
        end

        -- Couleur et label : EXALTÉ violet si pas de paragon et exalte
        local finalColor = lvlData.color
        local finalLabel = lvlData.name
        if atExalt and not hasParagon then
          -- Violet officiel WoW pour Exalté (couleur du rang Exalted dans l'UI)
          finalColor = {r=0.78, g=0.27, b=1.00}
          finalLabel = "Exalté"
        end

        return {
          system      = "classic",
          reaction    = reaction,
          cur         = atExalt and parCur or (curVal - curMin),
          max         = atExalt and parMax or (curMax - curMin),
          curAbs      = curVal,
          pct         = pct,
          paragon     = atExalt and hasParagon,
          liveParagon = isLiveParagon,
          exalted     = atExalt,
          hasParagon  = hasParagon,
          cap         = 8,
          color       = finalColor,
          label       = finalLabel,
          found       = true,
        }
      end
    end
    -- Fallback classique
    return {
      system   = "classic",
      reaction = 3,
      cur      = 0,
      max      = 3000,
      curAbs   = 0,
      pct      = 0,
      paragon  = false,
      exalted  = false,
      hasParagon = hasParagon,
      cap      = 8,
      color    = CLASSIC_LEVELS[3].color,
      label    = CLASSIC_LEVELS[3].name,
      found    = false,
    }
  end

  -- Fallback ultime
  return {
    system="renown", rank=0, cur=0, max=REP_PER, pct=0,
    paragon=false, cap=RENOWN_CAP,
    color={r=0.5,g=0.5,b=0.5}, label="Inconnu", found=false,
  }
end

-- ================================================================
-- CONSTRUCTION DE L'INTERFACE
-- (mainFrame est declaree tout en haut du fichier)
-- ================================================================


-- ================================================================
-- COMPTEUR : nombre de réputations max pour une extension
-- ================================================================
local function GetExtRepCounts(extKey)
  local extD = RenTrackerData and RenTrackerData[extKey]
  if not extD or not extD.factions then return 0, 0 end
  local total = #extD.factions
  local done  = 0
  for _, fac in ipairs(extD.factions) do
    if fac.id then
      if fac.friendship then
        local fd = GetFriendshipData(fac.id, fac)
        if fd.capped then done = done + 1 end
      elseif extD.system == "renown" then
        if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
          local ok, d = pcall(C_MajorFactions.GetMajorFactionData, fac.id)
          if ok and d and (d.renownLevel or 0) >= (extD.renownCap or 20) then
            done = done + 1
          end
        end
      else
        if C_Reputation and C_Reputation.GetFactionDataByID then
          local ok, d = pcall(C_Reputation.GetFactionDataByID, fac.id)
          if ok and d and (d.reaction or 0) >= 8 then
            done = done + 1
          end
        end
      end
    end
  end
  return done, total
end

local function BuildUI()

  -- ================================================================
  -- CONSTANTES DE LAYOUT VERTICAL
  -- ================================================================
  local TAB_COL_W  = 96    -- largeur colonne onglets extension
  local TAB_H      = 28    -- hauteur d'un onglet extension
  local TAB_GAP    = 2     -- espacement vertical entre onglets
  local CONTENT_X  = TAB_COL_W + 14  -- X du panneau contenu (apres colonne)
  local FRAME_H_MIN = 60 + (#EXT_ORDER * (TAB_H + TAB_GAP)) + 60

  -- ================================================================
  -- FENETRE PRINCIPALE
  -- ================================================================
  mainFrame = CreateFrame("Frame", "RNTMainFrame", UIParent, "BackdropTemplate")
  mainFrame:SetSize(FRAME_W, FRAME_H_MIN)
  mainFrame:SetClipsChildren(false)

  -- Fermeture par Echap via UISpecialFrames (mecanisme natif Blizzard) : voir
  -- note detaillee dans TibiSuiteCore.lua (WireEscapeFor) - piege reel
  -- confirme en jeu quand un autre addon intercepte lui aussi Echap.
  tinsert(UISpecialFrames, "RNTMainFrame")
  mainFrame:SetFrameStrata("HIGH")
  mainFrame:SetMovable(true)
  mainFrame:EnableMouse(true)
  mainFrame:RegisterForDrag("LeftButton")
  mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
  mainFrame:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local point, _, _, x, y = s:GetPoint()
    RenTrackerDB.pos = {point=point, x=x, y=y}
  end)

  mainFrame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=true, tileSize=32, edgeSize=32,
    insets={left=11, right=12, top=12, bottom=11},
  })
  mainFrame:SetBackdropColor(0.04, 0.02, 0.06, 0.97)
  mainFrame:SetBackdropBorderColor(0.72, 0.60, 0.28, 1.0)

  -- ================================================================
  -- TITRE
  -- ================================================================
  local titleBg = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
  titleBg:SetPoint("TOP", mainFrame, "TOP", 0, 14)
  titleBg:SetSize(380, 44)
  titleBg:SetFrameLevel(mainFrame:GetFrameLevel() + 2)
  titleBg:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=true, tileSize=32, edgeSize=20,
    insets={left=7, right=7, top=7, bottom=7},
  })
  titleBg:SetBackdropColor(0.04, 0.02, 0.06, 0.97)
  titleBg:SetBackdropBorderColor(0.72, 0.60, 0.28, 1.0)

  local logoLeft = titleBg:CreateTexture(nil, "OVERLAY")
  logoLeft:SetSize(20, 20)
  logoLeft:SetTexture("Interface\\AddOns\\RenTracker\\medias\\RenTracker")
  local logoRight = titleBg:CreateTexture(nil, "OVERLAY")
  logoRight:SetSize(20, 20)
  logoRight:SetTexture("Interface\\AddOns\\RenTracker\\medias\\RenTracker")

  local titleStr = titleBg:CreateFontString(nil, "OVERLAY")
  titleStr:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
  titleStr:SetPoint("CENTER", titleBg, "CENTER", 0, 5)
  titleStr:SetText("|cFFFFD700Ren Tracker - |r|cFF9480FFMidnight|r")
  logoLeft:SetPoint("RIGHT", titleStr, "LEFT", -6, 0)
  logoRight:SetPoint("LEFT",  titleStr, "RIGHT", 6, 0)

  local byLine = titleBg:CreateFontString(nil, "OVERLAY")
  byLine:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
  byLine:SetPoint("TOP", titleStr, "BOTTOM", 0, 0)
  byLine:SetText("|cFFF58CBAby Tibiscui|r")

  -- TibiSuite : en-tête comme WeeklyCompass (titre à l'intérieur, haut-gauche)
  logoLeft:Hide(); logoRight:Hide()
  byLine:Hide()
  titleBg:Hide()
  titleStr:SetParent(mainFrame)
  titleStr:SetFontObject("GameFontNormalLarge")
  titleStr:ClearAllPoints()
  titleStr:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 16, -14)
  titleStr:SetText("|cFFDDA669RenTracker|r")

  local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -5, -5)
  closeBtn:SetScript("OnClick", function()
    mainFrame:Hide() ; RenTrackerDB.open = false
  end)

  -- Bouton Options (ouvre le panneau de reglages)
  local optBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  optBtn:SetSize(70, 18)
  optBtn:SetText("Options")
  optBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -2, -4)
  optBtn:SetScript("OnClick", function()
    if RenTracker_ToggleOptions then RenTracker_ToggleOptions() end
  end)


  local drag = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  drag:SetPoint("TOP", 0, -30)
  drag:SetText("|cFF888888Glisser pour deplacer  -  /rt|r")


  -- Separateur haut (sous titre)
  local sepTop = mainFrame:CreateTexture(nil, "ARTWORK")
  sepTop:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepTop:SetPoint("TOPLEFT",  12, -45)
  sepTop:SetPoint("TOPRIGHT", -12, -45)
  sepTop:SetHeight(1)
  sepTop:SetVertexColor(0.72, 0.60, 0.28, 0.9)

  -- ================================================================
  -- COLONNE GAUCHE : ONGLETS EXTENSIONS VERTICAUX
  -- ================================================================
  -- Fond de la colonne
  local tabColBg = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
  tabColBg:SetPoint("TOPLEFT",     12, -50)
  tabColBg:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 12, 14)
  tabColBg:SetWidth(TAB_COL_W)
  tabColBg:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true, tileSize=8, edgeSize=6,
    insets={left=2,right=2,top=2,bottom=2},
  })
  tabColBg:SetBackdropColor(0.02, 0.01, 0.04, 0.85)
  tabColBg:SetBackdropBorderColor(0.72, 0.60, 0.28, 0.35)

  -- (Label "Extensions" supprimé - colonne épurée)

  local extBtns    = {}
  local extStars   = {}   -- table extKey -> fontstring étoile
  local extTabStartY = -58  -- Y du 1er onglet (remonté car label supprimé)

  local MODERN_COUNT = #EXT_ROW1   -- 6

  -- Construire les onglets (MID=idx1 en haut, VAN=idx12 en bas)
  -- Mais attention : on insere le separateur apres les 6 modernes
  -- Les 6 modernes : indices 1-6 du tableau EXT_ORDER (EXT_ROW1)
  -- Les 6 classiques : indices 7-12 (EXT_ROW2) avec offset +separateur

  local function BuildExtTab2(extKey, visualIdx)
    local col      = EXT_TAB_COLORS[extKey] or {r=0.5,g=0.5,b=0.5}
    local lbl      = EXT_LABELS[extKey]    or extKey
    local fullName = EXT_FULLNAMES[extKey] or extKey
    local yOff     = extTabStartY - (visualIdx - 1) * (TAB_H + TAB_GAP)

    local eb = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
    eb:SetPoint("TOPLEFT", 14, yOff)
    eb:SetSize(TAB_COL_W - 4, TAB_H)
    eb:SetBackdrop({
      bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile=true, tileSize=8, edgeSize=6,
      insets={left=2,right=2,top=2,bottom=2},
    })
    eb:SetBackdropColor(col.r*0.12, col.g*0.12, col.b*0.12, 0.95)
    eb:SetBackdropBorderColor(col.r*0.35, col.g*0.35, col.b*0.35, 0.5)

    local accent = eb:CreateTexture(nil, "OVERLAY")
    accent:SetPoint("TOPLEFT",    eb, "TOPLEFT",  2, -2)
    accent:SetPoint("BOTTOMLEFT", eb, "BOTTOMLEFT", 2, 2)
    accent:SetWidth(3)
    accent:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    accent:SetVertexColor(col.r, col.g, col.b, 0.5)

    local eTxt = eb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    eTxt:SetPoint("LEFT", eb, "LEFT", 8, 0)
    eTxt:SetSize(TAB_COL_W - 42, TAB_H - 4)
    eTxt:SetText(string.format("|cFF%02X%02X%02X%s|r",
      math.floor(col.r*255), math.floor(col.g*255), math.floor(col.b*255), lbl))
    eTxt:SetWordWrap(false)
    eTxt:SetJustifyH("LEFT")

    -- Compteur réputations X/total à droite
    local cntLbl = eb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cntLbl:SetPoint("RIGHT", eb, "RIGHT", -4, 0)
    cntLbl:SetJustifyH("RIGHT")
    cntLbl:SetText("")
    eb.cntLbl = cntLbl

    -- Table conservee pour declencher la mise a jour des compteurs par onglet
    extStars[extKey] = cntLbl

    eb.accent  = accent
    eb.extKey  = extKey
    eb.col     = col

    eb:SetScript("OnClick", function()
      RenTrackerDB.extension = extKey
      RenTrackerDB.selectedFac = nil
      
      mainFrame:RefreshContent()
    end)
    eb:SetScript("OnEnter", function(s)
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
      GameTooltip:AddLine(fullName, col.r, col.g, col.b)
      local extD = RenTrackerData and RenTrackerData[extKey]
      if extD then
        local nbFac = extD.factions and #extD.factions or 0
        local sys   = extD.system == "renown" and "Système Renown" or "Système Classique"
        local pg    = extD.hasParagon and "|cFFFFD700Paragon actif|r" or "|cFF888888Sans Paragon|r"
        GameTooltip:AddLine(nbFac.." faction"..(nbFac>1 and "s" or "").." · "..sys, 0.75, 0.75, 0.75)
        GameTooltip:AddLine(pg)
      end
      GameTooltip:Show()
    end)
    eb:SetScript("OnLeave", function() GameTooltip:Hide() end)

    table.insert(extBtns, eb)
    return eb
  end

  -- Rangee modernes (1-6) : positions 1 a 6
  for i, extKey in ipairs(EXT_ROW1) do
    BuildExtTab2(extKey, i)
  end

  -- Separateur ligne dorée entre LEG (modernes) et WoD (classiques)
  local divOffsetY = extTabStartY - MODERN_COUNT * (TAB_H + TAB_GAP) - 3

  local sepDiv1 = mainFrame:CreateTexture(nil, "OVERLAY")
  sepDiv1:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepDiv1:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT", 14, divOffsetY)
  sepDiv1:SetPoint("TOPRIGHT", tabColBg,  "TOPRIGHT", -3, divOffsetY)
  sepDiv1:SetHeight(2)
  sepDiv1:SetVertexColor(0.72, 0.60, 0.28, 1.0)

  -- Rangee classiques (7-12) : positions calees juste sous le separateur
  local classicYBase = divOffsetY - 5

  for i, extKey in ipairs(EXT_ROW2) do
    local yOff = classicYBase - (i - 1) * (TAB_H + TAB_GAP)
    local col      = EXT_TAB_COLORS[extKey] or {r=0.5,g=0.5,b=0.5}
    local lbl      = EXT_LABELS[extKey]    or extKey
    local fullName = EXT_FULLNAMES[extKey] or extKey

    local eb = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
    eb:SetPoint("TOPLEFT", 14, yOff)
    eb:SetSize(TAB_COL_W - 4, TAB_H)
    eb:SetBackdrop({
      bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile=true, tileSize=8, edgeSize=6,
      insets={left=2,right=2,top=2,bottom=2},
    })
    eb:SetBackdropColor(col.r*0.12, col.g*0.12, col.b*0.12, 0.95)
    eb:SetBackdropBorderColor(col.r*0.35, col.g*0.35, col.b*0.35, 0.5)

    local accent = eb:CreateTexture(nil, "OVERLAY")
    accent:SetPoint("TOPLEFT",    eb, "TOPLEFT",  2, -2)
    accent:SetPoint("BOTTOMLEFT", eb, "BOTTOMLEFT", 2, 2)
    accent:SetWidth(3)
    accent:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    accent:SetVertexColor(col.r, col.g, col.b, 0.5)

    local eTxt = eb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    eTxt:SetPoint("LEFT", eb, "LEFT", 8, 0)
    eTxt:SetSize(TAB_COL_W - 42, TAB_H - 4)
    eTxt:SetText(string.format("|cFF%02X%02X%02X%s|r",
      math.floor(col.r*255), math.floor(col.g*255), math.floor(col.b*255), lbl))
    eTxt:SetWordWrap(false)
    eTxt:SetJustifyH("LEFT")

    -- Compteur réputations X/total à droite
    local cntLbl = eb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cntLbl:SetPoint("RIGHT", eb, "RIGHT", -4, 0)
    cntLbl:SetJustifyH("RIGHT")
    cntLbl:SetText("")
    eb.cntLbl = cntLbl
    extStars[extKey] = cntLbl

    eb.accent  = accent
    eb.extKey  = extKey
    eb.col     = col

    eb:SetScript("OnClick", function()
      RenTrackerDB.extension = extKey
      RenTrackerDB.selectedFac = nil
      
      mainFrame:RefreshContent()
    end)
    eb:SetScript("OnEnter", function(s)
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
      GameTooltip:AddLine(fullName, col.r, col.g, col.b)
      local extD = RenTrackerData and RenTrackerData[extKey]
      if extD then
        local nbFac = extD.factions and #extD.factions or 0
        local sys   = extD.system == "renown" and "Système Renown" or "Système Classique"
        local pg    = extD.hasParagon and "|cFFFFD700Paragon actif|r" or "|cFF888888Sans Paragon|r"
        GameTooltip:AddLine(nbFac.." faction"..(nbFac>1 and "s" or "").." · "..sys, 0.75, 0.75, 0.75)
        GameTooltip:AddLine(pg)
      end
      GameTooltip:Show()
    end)
    eb:SetScript("OnLeave", function() GameTooltip:Hide() end)

    table.insert(extBtns, eb)
  end

  -- ================================================================
  -- BOUTON "Le Grand Malade" dans la colonne, sous Vanilla
  -- 2 lignes : "Hauts Faits" + "Le Grand Malade"
  -- ================================================================

  mainFrame.extBtns  = extBtns
  mainFrame.extStars = extStars

  -- (footer supprimé)

  -- ================================================================
  -- SEPARATEUR VERTICAL (entre colonne onglets et contenu)
  -- ================================================================
  local sepVert = mainFrame:CreateTexture(nil, "ARTWORK")
  sepVert:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepVert:SetPoint("TOPLEFT",    TAB_COL_W + 13, -50)
  sepVert:SetPoint("BOTTOMLEFT", TAB_COL_W + 13, 12)
  sepVert:SetWidth(1)
  sepVert:SetVertexColor(0.72, 0.60, 0.28, 0.55)

  -- ================================================================
  -- PANNEAU HAUTS FAITS (masqué par défaut)
  -- ================================================================
  local CX  = TAB_COL_W + 18
  local CTW = FRAME_W - CX - 14


  -- Label "Extensions" (nom de l'ext active, sera mis a jour)
  mainFrame.extActiveLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  mainFrame.extActiveLabel:SetPoint("TOPLEFT", CX, -52)
  mainFrame.extActiveLabel:SetWidth(CTW - 140)
  mainFrame.extActiveLabel:SetJustifyH("LEFT")
  mainFrame.extActiveLabel:SetWordWrap(false)
  mainFrame.extActiveLabel:SetText("|cFFFFD700Extensions|r")

  -- Recap global : total de factions au max toutes extensions confondues
  mainFrame.globalSummary = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mainFrame.globalSummary:SetPoint("TOPRIGHT", -16, -53)
  mainFrame.globalSummary:SetJustifyH("RIGHT")
  mainFrame.globalSummary:SetText("")


  -- ================================================================
  -- GROUPES PLIABLES : Principales / Secondaires / PvP
  -- Chaque groupe : header cliquable + liste lignes avec mini-barre
  -- ================================================================
  local GROUP_Y   = -70     -- Y de départ sous le label extension
  local ROW_H     = 20      -- hauteur d'une ligne faction
  local ROW_GAP   = 1
  local GH_H      = 20      -- hauteur du header de groupe

  local CAT_DEFS = {
    { key="principale", label="Principales", col={r=1.00,g=0.82,b=0.00} },
    { key="secondaire", label="Secondaires", col={r=0.30,g=0.70,b=1.00} },
    { key="pvp",        label="PvP",         col={r=0.95,g=0.30,b=0.30} },
  }

  -- Mini-barre helper : retourne pct (0-1) + label court + r,g,b
  local function GetMiniBarData(fac)
    local extD = GetActiveExtData()
    if not fac.id then
      return 0, "?", 0.4, 0.4, 0.4
    end
    if fac.friendship then
      local fd = GetFriendshipData(fac.id, fac)
      if fd.capped then return 1.0, "Max", fd.color.r, fd.color.g, fd.color.b end
      if not fd.found then return 0, "?", 0.4, 0.4, 0.4 end
      return fd.pct, fd.label, fd.color.r, fd.color.g, fd.color.b
    end
    if extD.system == "renown" then
      if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
        local ok, d = pcall(C_MajorFactions.GetMajorFactionData, fac.id)
        if ok and d then
          local cap  = extD.renownCap or 20
          local rank = d.renownLevel or 0
          local pct  = math.min(1.0, rank / cap)
          if rank >= cap then
            return 1.0, "Max", 0.78, 0.27, 1.00
          end
          local lbl = tostring(rank).."/"..tostring(cap)
          local rc  = GetRenownColor(rank, cap)
          return pct, lbl, rc.r, rc.g, rc.b
        end
      end
      return 0, "?", 0.4, 0.4, 0.4
    else
      if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, d = pcall(C_Reputation.GetFactionDataByID, fac.id)
        if ok and d then
          local reaction = d.reaction or 3
          local lvl = CLASSIC_LEVELS[reaction] or CLASSIC_LEVELS[3]
          local cr  = d.currentReactionThreshold  or 0
          local nx  = d.nextReactionThreshold      or 1
          local cv  = d.currentStanding            or 0
          local pct = (reaction >= 8) and 1.0
                   or ((nx > cr) and math.min(1.0,(cv-cr)/(nx-cr)) or 0)
          local label = lvl.name
          if reaction >= 8 then
            return 1.0, "Exalté", 0.78, 0.27, 1.00
          end
          return pct, label, lvl.color.r, lvl.color.g, lvl.color.b
        end
      end
      return 0, "?", 0.4, 0.4, 0.4
    end
  end

  -- Conteneur de tous les widgets de groupes (pour pouvoir les effacer)
  mainFrame.groupFrames = {}

  -- Sélection courante : {cat, name}
  local function GetSelectedFac()
    local sf = RenTrackerDB.selectedFac
    if not sf then return nil, nil end
    return sf.cat, sf.name
  end
  local function SetSelectedFac(cat, name)
    RenTrackerDB.selectedFac = {cat=cat, name=name}
  end

  -- ================================================================
  -- RebuildGroups : recrée tous les groupes depuis zéro
  -- ================================================================
  local function RebuildGroups()
    -- Cacher et supprimer les anciens widgets
    for _, f in ipairs(mainFrame.groupFrames) do f:Hide() end
    mainFrame.groupFrames = {}

    if not RenTrackerDB.groups then
      RenTrackerDB.groups = {principale=true, secondaire=true, pvp=false}
    end

    local selCat, selName = GetSelectedFac()
    local curY = GROUP_Y  -- Y courant (négatif, descend)

    for _, cd in ipairs(CAT_DEFS) do
      local cat     = cd.key
      local factions = GetFactionsByCategory(cat)
      local nbFac   = #factions
      local isOpen  = RenTrackerDB.groups[cat]
      if isOpen == nil then isOpen = GROUP_DEFAULTS[cat] end

      local col = cd.col
      local r8  = math.floor(col.r*255)
      local g8  = math.floor(col.g*255)
      local b8  = math.floor(col.b*255)

      -- === HEADER DU GROUPE ===
      local gh = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
      gh:SetPoint("TOPLEFT",  CX,   curY)
      gh:SetPoint("TOPRIGHT", -14,  curY)
      gh:SetHeight(GH_H)
      gh:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=8, edgeSize=6,
        insets={left=2,right=2,top=2,bottom=2},
      })
      gh:SetBackdropColor(col.r*0.18, col.g*0.18, col.b*0.18, 1.0)
      gh:SetBackdropBorderColor(col.r*0.55, col.g*0.55, col.b*0.55, 0.9)
      table.insert(mainFrame.groupFrames, gh)

      -- Flèche
      local arrow = gh:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      arrow:SetPoint("LEFT", gh, "LEFT", 6, 0)
      arrow:SetText(isOpen and "|cFF888888-|r" or "|cFF888888+|r")
      gh.arrow = arrow

      -- Label catégorie
      local ghLabel = gh:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      ghLabel:SetPoint("LEFT", gh, "LEFT", 18, 0)
      ghLabel:SetText(string.format("|cFF%02X%02X%02X%s|r", r8, g8, b8, cd.label))

      -- Badge compteur
      local ghBadge = gh:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      ghBadge:SetPoint("RIGHT", gh, "RIGHT", -6, 0)
      ghBadge:SetText(string.format("|cFF%02X%02X%02X%d|r", r8, g8, b8, nbFac))

      gh:SetScript("OnClick", function()
        RenTrackerDB.groups[cat] = not RenTrackerDB.groups[cat]
        mainFrame:RefreshContent()
      end)
      gh:SetScript("OnEnter", function(s)
        s:SetBackdropBorderColor(col.r, col.g, col.b, 1.0)
      end)
      gh:SetScript("OnLeave", function(s)
        s:SetBackdropBorderColor(col.r*0.55, col.g*0.55, col.b*0.55, 0.9)
      end)

      curY = curY - GH_H - ROW_GAP

      -- === LIGNES DE FACTIONS (si groupe ouvert) ===
      if isOpen and nbFac > 0 then
        for _, fac in ipairs(factions) do
          local isSel = (selCat == cat and selName == fac.name)
          local pct, lvlLbl, lr, lg, lb = GetMiniBarData(fac)

          local row = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
          row:SetPoint("TOPLEFT",  CX,  curY)
          row:SetPoint("TOPRIGHT", -14, curY)
          row:SetHeight(ROW_H)
          row:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileSize=8, edgeSize=5,
            insets={left=1,right=1,top=1,bottom=1},
          })
          if isSel then
            row:SetBackdropColor(col.r*0.28, col.g*0.28, col.b*0.28, 1.0)
            row:SetBackdropBorderColor(col.r, col.g, col.b, 1.0)
          else
            row:SetBackdropColor(col.r*0.06, col.g*0.06, col.b*0.06, 0.95)
            row:SetBackdropBorderColor(col.r*0.20, col.g*0.20, col.b*0.20, 0.7)
          end
          table.insert(mainFrame.groupFrames, row)

          -- Dot coloré catégorie
          local dot = row:CreateTexture(nil, "OVERLAY")
          dot:SetPoint("LEFT", row, "LEFT", 5, 0)
          dot:SetSize(5, 5)
          dot:SetTexture("Interface\\BUTTONS\\WHITE8X8")
          dot:SetVertexColor(col.r, col.g, col.b, 0.9)

          -- Nom de la faction
          local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          nameFS:SetPoint("LEFT",  row, "LEFT",  14, 0)
          nameFS:SetPoint("RIGHT", row, "RIGHT", -105, 0)
          nameFS:SetHeight(ROW_H)
          nameFS:SetJustifyH("LEFT")
          nameFS:SetWordWrap(false)
          local nameCol = isSel
            and string.format("|cFF%02X%02X%02X", r8, g8, b8)
            or  string.format("|cFF%02X%02X%02X",
                  math.floor(col.r*0.72*255),
                  math.floor(col.g*0.72*255),
                  math.floor(col.b*0.72*255))
          nameFS:SetText(nameCol..fac.name.."|r")

          -- Mini-barre de progression
          local MBAR_W = 56
          local mbarBg = row:CreateTexture(nil, "ARTWORK")
          mbarBg:SetPoint("RIGHT", row, "RIGHT", -44, 0)
          mbarBg:SetSize(MBAR_W, 5)
          mbarBg:SetTexture("Interface\\BUTTONS\\WHITE8X8")
          mbarBg:SetVertexColor(0.08, 0.06, 0.12, 0.9)

          local mbarFill = row:CreateTexture(nil, "OVERLAY")
          mbarFill:SetPoint("LEFT", mbarBg, "LEFT", 0, 0)
          mbarFill:SetHeight(5)
          local fillW = math.max(1, math.floor(MBAR_W * pct))
          mbarFill:SetWidth(fillW)
          mbarFill:SetTexture("Interface\\BUTTONS\\WHITE8X8")
          if pct >= 1.0 then
            mbarFill:SetVertexColor(0.78, 0.27, 1.00, 1.0)
          else
            mbarFill:SetVertexColor(lr, lg, lb, 0.9)
          end

          -- Label de niveau
          local lvlFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          lvlFS:SetPoint("RIGHT", row, "RIGHT", -4, 0)
          lvlFS:SetWidth(38)
          lvlFS:SetJustifyH("RIGHT")
          lvlFS:SetHeight(ROW_H)
          if pct >= 1.0 then
            lvlFS:SetText("|cFFC090FF"..lvlLbl.."|r")
          else
            lvlFS:SetText(string.format("|cFF%02X%02X%02X%s|r",
              math.floor(lr*255), math.floor(lg*255), math.floor(lb*255), lvlLbl))
          end

          -- Interactions
          local facRef = fac
          local catRef = cat
          row:SetScript("OnClick", function()
            SetSelectedFac(catRef, facRef.name)
            mainFrame:RefreshContent()
          end)
          row:SetScript("OnEnter", function(s)
            s:SetBackdropBorderColor(col.r*0.7, col.g*0.7, col.b*0.7, 1.0)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(facRef.name, col.r, col.g, col.b)
            GameTooltip:AddLine("Zone : "..facRef.zone, 0.8, 0.8, 0.8)
            GameTooltip:Show()
          end)
          row:SetScript("OnLeave", function(s)
            GameTooltip:Hide()
            if not (selCat == catRef and selName == facRef.name) then
              s:SetBackdropBorderColor(col.r*0.20, col.g*0.20, col.b*0.20, 0.7)
            end
          end)

          curY = curY - ROW_H - ROW_GAP
        end
      end

      curY = curY - 3  -- espace entre groupes
    end

    -- Séparateur sous les groupes
    local sepGroups = mainFrame:CreateTexture(nil, "ARTWORK")
    sepGroups:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    sepGroups:SetPoint("TOPLEFT",  CX,  curY)
    sepGroups:SetPoint("TOPRIGHT", -14, curY)
    sepGroups:SetHeight(1)
    sepGroups:SetVertexColor(0.72, 0.60, 0.28, 0.9)
    table.insert(mainFrame.groupFrames, sepGroups)

    -- Stocker le Y final pour que RefreshContent positionne les blocs dessous
    mainFrame._groupsBottomY = curY - 6
  end

  mainFrame.RebuildGroups = RebuildGroups

  -- ================================================================
  -- BLOC REPUTATIONS (barre + info + quêtes)
  -- Positions calculées dynamiquement depuis _groupsBottomY
  -- ================================================================

  -- Titre "Réputations"
  local repHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  mainFrame._repHeader = repHeader
  mainFrame._repHeaderAnchorY = 0  -- sera mis à jour dans RefreshContent

  local barBg = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
  barBg:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true, tileSize=8, edgeSize=6,
    insets={left=2, right=2, top=2, bottom=2},
  })
  barBg:SetHeight(26)
  barBg:SetBackdropColor(0, 0, 0, 0.75)
  barBg:SetBackdropBorderColor(0.5, 0.45, 0.25, 0.8)
  mainFrame._barBg = barBg

  mainFrame.barFill = barBg:CreateTexture(nil, "ARTWORK")
  mainFrame.barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT", 3, -3)
  mainFrame.barFill:SetHeight(20)
  mainFrame.barFill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")

  mainFrame.barText = barBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mainFrame.barText:SetPoint("CENTER", barBg, "CENTER")

  -- ================================================================
  -- ZONE INFO FACTION (PNJ Quartier-maître)
  -- ================================================================
  mainFrame.infoLine1 = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mainFrame.infoLine1:SetHeight(16)
  mainFrame.infoLine1:SetJustifyH("LEFT")

  mainFrame.infoLine2 = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mainFrame.infoLine2:SetHeight(16)
  mainFrame.infoLine2:SetJustifyH("LEFT")

  local sep3 = mainFrame:CreateTexture(nil, "ARTWORK")
  mainFrame._sep3 = sep3
  sep3:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sep3:SetHeight(1)
  sep3:SetVertexColor(0.72, 0.60, 0.28, 0.9)

  -- ================================================================
  -- PANNEAU QUETES (avec scroll)
  -- ================================================================
  local questHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  mainFrame._questHeader = questHeader
  questHeader:SetText("|cFFFFD700Quêtes disponibles|r")

  local legend = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mainFrame._legend = legend
  legend:SetText(
    "|cFF4D99FF[Hebdo]|r  " ..
    "|cFFFFCC00[Unique]|r  " ..
    "|cFF4DCC4D[Quotidien]|r"
  )

  -- scrollBg : cadre contenant les quêtes (pas de scrollbar)
  local scrollBg = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
  scrollBg:SetHeight(200)
  scrollBg:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true, tileSize=8, edgeSize=8,
    insets={left=3, right=3, top=3, bottom=3},
  })
  scrollBg:SetBackdropColor(0.02, 0.01, 0.04, 0.5)
  scrollBg:SetBackdropBorderColor(0.5, 0.45, 0.25, 0.5)

  mainFrame.questContent = CreateFrame("Frame", nil, scrollBg)
  mainFrame.questContent:SetPoint("TOPLEFT",  scrollBg, "TOPLEFT",  6, -6)
  mainFrame.questContent:SetPoint("TOPRIGHT", scrollBg, "TOPRIGHT", -6, -6)
  mainFrame.questContent:SetHeight(200)
  mainFrame.scrollBg = scrollBg

  -- ================================================================
  -- REFRESH CONTENT
  -- ================================================================
  mainFrame.RefreshContent = function(self)

    -- Mise a jour du label extension active
    local extKey  = RenTrackerDB.extension or "Midnight"
    local extD    = RenTrackerData and RenTrackerData[extKey]
    local extCol  = EXT_TAB_COLORS[extKey] or {r=1,g=0.84,b=0}
    local extFull = EXT_FULLNAMES[extKey] or extKey
    self.extActiveLabel:SetText(string.format(
      "|cFFFFD700Extensions|r  |cFF555555--|r  |cFF%02X%02X%02X%s|r",
      math.floor(extCol.r*255), math.floor(extCol.g*255), math.floor(extCol.b*255),
      extFull))

    -- Highlight extension active + compteurs (+ accumulation du recap global)
    local gDone, gTotal = 0, 0
    for _, eb in ipairs(self.extBtns or {}) do
      local col = eb.col or {r=0.5,g=0.5,b=0.5}
      if eb.extKey == RenTrackerDB.extension then
        eb:SetBackdropColor(col.r*0.40, col.g*0.40, col.b*0.40, 1.0)
        eb:SetBackdropBorderColor(col.r, col.g, col.b, 1.0)
        if eb.accent then eb.accent:SetVertexColor(col.r, col.g, col.b, 1.0) end
      else
        eb:SetBackdropColor(col.r*0.12, col.g*0.12, col.b*0.12, 0.95)
        eb:SetBackdropBorderColor(col.r*0.35, col.g*0.35, col.b*0.35, 0.5)
        if eb.accent then eb.accent:SetVertexColor(col.r, col.g, col.b, 0.5) end
      end
      if eb.cntLbl then
        local d, t = GetExtRepCounts(eb.extKey)
        gDone  = gDone  + d
        gTotal = gTotal + t
        if t > 0 then
          if d >= t then
            eb.cntLbl:SetText(string.format("|cFFFFD700%d/%d|r", d, t))
          elseif d > 0 then
            eb.cntLbl:SetText(string.format("|cFFFFAA00%d|r|cFF666666/%d|r", d, t))
          else
            eb.cntLbl:SetText(string.format("|cFF555555%d/%d|r", d, t))
          end
        end
      end
    end

    -- Recap global : total de factions au max, + hauts faits de l'ext active
    if self.globalSummary then
      local summary = string.format("|cFF888888Global :|r |cFFFFD700%d|r|cFF666666/%d au max|r", gDone, gTotal)
      if RenTrackerAchievements and RenTrackerAchievements[extKey]
         and RenTrackerAchievements[extKey].achievements then
        local aDone, aTot = 0, 0
        for _, a in ipairs(RenTrackerAchievements[extKey].achievements) do
          aTot = aTot + 1
          if IsAchievementDone(a.id) then aDone = aDone + 1 end
        end
        if aTot > 0 then
          summary = summary .. string.format("   |cFF888888HF :|r |cFFFFD700%d|r|cFF666666/%d|r", aDone, aTot)
        end
      end
      self.globalSummary:SetText(summary)
    end

    -- Reconstruire les groupes pliables
    self:RebuildGroups()

    -- Y dynamique : juste sous les groupes
    local baseY = self._groupsBottomY or -200

    -- Trouver la faction sélectionnée
    local selCat, selName = GetSelectedFac()
    local fac = nil
    if selCat and selName then
      for _, f in ipairs(GetFactionsByCategory(selCat)) do
        if f.name == selName then fac = f ; break end
      end
    end
    -- Si rien sélectionné, prendre la 1ère disponible toutes catégories
    if not fac then
      for _, cd in ipairs(CAT_DEFS) do
        local list = GetFactionsByCategory(cd.key)
        if #list > 0 then
          fac = list[1]
          SetSelectedFac(cd.key, fac.name)
          break
        end
      end
    end

    if not fac then
      self.infoLine1:SetText("|cFF888888Aucune faction disponible.|r")
      self.infoLine2:SetText("")
      self.barText:SetText("")
      if self.barFill then self.barFill:SetWidth(3) end
      return
    end

    -- === Positionnement dynamique du bloc détail ===
    local barY = baseY - 2

    -- Titre "Réputations"
    self._repHeader:ClearAllPoints()
    self._repHeader:SetPoint("TOPLEFT",  CX,  barY + 2)
    self._repHeader:SetWidth(CTW)
    self._repHeader:SetText("|cFFFFD700Réputations|r")

    local barY2 = barY - 18
    self._barBg:ClearAllPoints()
    self._barBg:SetPoint("TOPLEFT",  CX,  barY2)
    self._barBg:SetPoint("TOPRIGHT", -14, barY2)

    local infoY = barY2 - 34
    self.infoLine1:ClearAllPoints()
    self.infoLine1:SetPoint("TOPLEFT",  CX,  infoY)
    self.infoLine1:SetPoint("TOPRIGHT", -14, infoY)

    self.infoLine2:ClearAllPoints()
    self.infoLine2:SetPoint("TOPLEFT",  CX,  infoY - 18)
    self.infoLine2:SetPoint("TOPRIGHT", -14, infoY - 18)

    self._sep3:ClearAllPoints()
    self._sep3:SetPoint("TOPLEFT",  CX,  infoY - 38)
    self._sep3:SetPoint("TOPRIGHT", -14, infoY - 38)

    local questY = infoY - 52
    self._questHeader:ClearAllPoints()
    self._questHeader:SetPoint("TOPLEFT", CX, questY)

    self._legend:ClearAllPoints()
    self._legend:SetPoint("TOPLEFT", CX, questY - 18)

    self.scrollBg:ClearAllPoints()
    self.scrollBg:SetPoint("TOPLEFT",  CX,  questY - 38)
    self.scrollBg:SetPoint("TOPRIGHT", -14, questY - 38)

    -- Données réputation
    local rd  = GetRenownData(fac.id, fac)
    local col = rd.color

    -- Barre de réputation
    local barInnerW = self._barBg:GetWidth() - 6
    if barInnerW < 10 then barInnerW = CTW - 10 end
    local fillW = math.max(3, math.floor(barInnerW * rd.pct))
    if rd.exalted and not rd.hasParagon then fillW = barInnerW end
    self.barFill:SetWidth(fillW)

    local isMaxed = false
    if rd.exalted and not rd.hasParagon then
      self.barFill:SetVertexColor(0.78, 0.27, 1.00, 1.0)
      isMaxed = true
    elseif rd.liveParagon then
      self.barFill:SetVertexColor(1.00, 0.85, 0.10, 1.0)
    elseif rd.paragon then
      self.barFill:SetVertexColor(1.00, 0.85, 0.10, 1.0)
      isMaxed = true
    else
      self.barFill:SetVertexColor(col.r, col.g, col.b, 1.0)
    end

    -- Texte barre
    if rd.system == "friendship" then
      if rd.capped then
        self.barText:SetText(string.format("|cFF%02X%02X%02X%s - Max|r",
          math.floor(col.r*255), math.floor(col.g*255), math.floor(col.b*255), rd.label))
      else
        self.barText:SetText(string.format("|cFF%02X%02X%02X%s|r  %d / %d rep",
          math.floor(col.r*255), math.floor(col.g*255), math.floor(col.b*255),
          rd.label, rd.cur, rd.max))
      end
    elseif rd.system == "classic" then
      if rd.exalted and not rd.hasParagon then
        self.barText:SetText("|cFFFFFFFFExalté - 100%|r")
      elseif rd.liveParagon then
        self.barText:SetText(string.format("|cFFFFD700%s - PARAGON|r  %d / %d", rd.label, rd.cur, rd.max))
      elseif rd.paragon then
        self.barText:SetText(string.format("|cFFFFD700%s - PARAGON|r", rd.label))
      else
        self.barText:SetText(string.format("|cFF%02X%02X%02X%s|r  %d / %d rep",
          math.floor(col.r*255), math.floor(col.g*255), math.floor(col.b*255),
          rd.label, rd.cur, rd.max))
      end
    else
      if rd.liveParagon then
        self.barText:SetText(string.format("|cFFFFD700Renown %d/%d - %s - PARAGON|r  %d / %d",
          rd.rank, rd.cap, rd.label, rd.cur, rd.max))
      elseif rd.paragon then
        self.barText:SetText(string.format("|cFFFFD700Renown %d/%d - %s - PARAGON|r",
          rd.rank, rd.cap, rd.label))
        isMaxed = true
      else
        self.barText:SetText(string.format("|cFF%02X%02X%02XRenown %d / %d - %s|r  %d / %d rep",
          math.floor(col.r*255), math.floor(col.g*255), math.floor(col.b*255),
          rd.rank, rd.cap, rd.label, rd.cur, rd.max))
      end
    end

    if self.barDoneLabel then self.barDoneLabel:Hide() end

    -- Infos PNJ
    self.infoLine1:SetText(
      "|cFF888888Zone :|r |cFFFFCC44"..fac.zone..
      "|r   |cFF888888Quartier-maître :|r |cFFCCBB88"..fac.qm_name.."|r")
    self.infoLine2:SetText(
      "|cFF888888Localisation :|r |cFF99CCFF"..fac.qm_zone..
      "  ("..fac.qm_coord..")|r")

    -- Nettoyer quetes
    for _, c in pairs({self.questContent:GetChildren()})  do c:Hide() end
    for _, r in pairs({self.questContent:GetRegions()})   do r:Hide() end

    if not RenTrackerDB.sections then
      RenTrackerDB.sections = {weekly=false, onetime=false, daily=false}
    end

    local groups = {
      {key="weekly",  label="Quêtes hebdomadaires", quests={}},
      {key="onetime", label="Quêtes uniques",        quests={}},
      {key="daily",   label="Quêtes quotidiennes",   quests={}},
    }
    for _, quest in ipairs(fac.quests) do
      for _, g in ipairs(groups) do
        if quest.type == g.key then table.insert(g.quests, quest) end
      end
    end

    local rowW  = self.questContent:GetWidth() - 4
    local textW = rowW - 22
    local y     = 0
    local contentHeight = 0

    local function IsQuestDone(qid)
      if not qid then return false end
      if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(qid)
      end
      return IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(qid) or false
    end

    local TYPE_COLORS = {
      weekly  = {r=0.30, g=0.60, b=1.00},
      onetime = {r=1.00, g=0.80, b=0.00},
      daily   = {r=0.30, g=0.80, b=0.30},
    }
    local TYPE_LABELS = {
      weekly  = "[Hebdo]",
      onetime = "[Unique]",
      daily   = "[Quotidien]",
    }

    local function BuildQuestRow(parent, quest, yOff, faction)
      local tc      = TYPE_COLORS[quest.type] or {r=1,g=1,b=1}
      local tlbl    = TYPE_LABELS[quest.type] or ""
      local done    = IsQuestDone(quest.questID)
      local nameCol = done and "|cFF888888" or "|cFFEEEEEE"

      -- Hauteur dynamique : chaque élément a son espace propre
      -- Layout : typeTag(6-20) + qName(18-34) + npcStr(32-46) + repStr(46-60) + tip(60+) + items
      local hasItems = quest.itemTracking and #quest.itemTracking > 0
      -- Hauteur du tip : on estime ~chars/texteWidth lignes à 14px chacune
      local tipText   = quest.tip or ""
      local charsPerLine = math.floor(textW / 7)  -- ~7px par caractère police small
      if charsPerLine < 20 then charsPerLine = 50 end
      local tipLines  = math.ceil(#tipText / charsPerLine)
      tipLines        = math.max(1, math.min(tipLines, 6))
      local baseH     = 64  -- typeTag + qName + npcStr + repStr + padding
      local tipH      = tipLines * 14
      local itemsH    = hasItems and (8 + #quest.itemTracking * 18) or 0
      local rowH      = baseH + tipH + itemsH + 6  -- +6 padding bas

      local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
      row:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -yOff)
      row:SetSize(rowW, rowH)
      row:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=8, edgeSize=6,
        insets={left=2, right=2, top=2, bottom=2},
      })
      if done then
        row:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
        row:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.4)
      else
        row:SetBackdropColor(tc.r*0.08, tc.g*0.08, tc.b*0.08, 0.95)
        row:SetBackdropBorderColor(tc.r*0.4, tc.g*0.4, tc.b*0.4, 0.6)
      end

      local typeTag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      typeTag:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -6)
      if done then
        typeTag:SetText("|cFF555555"..tlbl.." v|r")
      else
        typeTag:SetText(string.format("|cFF%02X%02X%02X%s|r",
          math.floor(tc.r*255), math.floor(tc.g*255), math.floor(tc.b*255), tlbl))
      end

      local qName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      qName:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -18)
      qName:SetSize(textW, 16)
      qName:SetJustifyH("LEFT")
      qName:SetText(nameCol..quest.name.."|r")

      local npcStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      npcStr:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -32)
      npcStr:SetSize(textW, 14)
      npcStr:SetJustifyH("LEFT")
      if done then
        npcStr:SetText("|cFF555555PNJ : "..quest.npc.."  Coord. de zone : "..quest.coords.."|r")
      else
        npcStr:SetText(
          "|cFF888888PNJ :|r |cFFCCBB88"..quest.npc..
          "|r  |cFF888888Coord. de zone :|r |cFF99CCFF"..quest.coords.."|r")
      end

      local repStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      repStr:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -44)
      repStr:SetSize(textW, 14)
      repStr:SetJustifyH("LEFT")
      local facR = math.floor(fac.color.r*255)
      local facG = math.floor(fac.color.g*255)
      local facB = math.floor(fac.color.b*255)
      if done then
        repStr:SetText("|cFF555555Rep : +"..quest.rep.."|r")
      else
        repStr:SetText(string.format("|cFF888888Rep :|r |cFF%02X%02X%02X+%s|r",
          facR, facG, facB, quest.rep))
      end

      -- Tip text (long, avec retour à la ligne)
      if quest.tip and quest.tip ~= "" then
        local tipStr = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tipStr:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -62)
        tipStr:SetSize(textW, tipLines * 14)
        tipStr:SetJustifyH("LEFT")
        tipStr:SetWordWrap(true)
        if done then
          tipStr:SetText("|cFF555555"..quest.tip.."|r")
        else
          tipStr:SetText("|cFF777777"..quest.tip.."|r")
        end
      end

      -- Tracking des items collectables (si défini)
      if quest.itemTracking and #quest.itemTracking > 0 then
        local itemStartY = -62 - tipLines * 14 - 6
        local itemHeader = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itemHeader:SetPoint("TOPLEFT", row, "TOPLEFT", 12, itemStartY)
        itemHeader:SetText("|cFFFFD700Items a collecter :|r")
        for idx, item in ipairs(quest.itemTracking) do
          local inBag = 0
          if item.itemID and GetItemCount then
            inBag = GetItemCount(item.itemID, true) or 0
          end
          local needed  = item.needed or 0
          local itemY   = itemStartY - (idx * 18)
          local itemRow = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          itemRow:SetPoint("TOPLEFT", row, "TOPLEFT", 20, itemY)
          itemRow:SetSize(textW - 8, 16)
          local colStr
          if needed == 0 then
            -- Pas de cap fixe, juste afficher la quantite
            colStr = string.format("|cFFCCBB88%s|r |cFF99CCFF[%d en sac]|r  |cFF666666%s|r",
              item.name, inBag, item.tip or "")
          elseif inBag >= needed then
            colStr = string.format("|cFF44CC44%s|r |cFF44CC44[%d/%d]|r",
              item.name, inBag, needed)
          else
            colStr = string.format("|cFFCCBB88%s|r |cFFFF8844[%d/%d]|r  |cFF666666%s|r",
              item.name, inBag, needed, item.tip or "")
          end
          itemRow:SetText(colStr)
        end
      end

      row:EnableMouse(true)
      row:SetScript("OnClick", function()
        if faction and faction.id then
          if C_Reputation and C_Reputation.SetWatchedFactionByID then
            C_Reputation.SetWatchedFactionByID(faction.id)
          elseif GetNumFactions and SetWatchedFactionIndex then
            for i = 1, GetNumFactions() do
              local fdata = C_Reputation and C_Reputation.GetFactionDataByIndex and C_Reputation.GetFactionDataByIndex(i)
              local fid = fdata and fdata.factionID or select(14, GetFactionInfo(i))
              if fid == faction.id then SetWatchedFactionIndex(i) ; break end
            end
          end
        end
        if quest.coords and quest.coords ~= "" and TomTom then
          local x, y2 = quest.coords:match("([%d%.]+),%s*([%d%.]+)")
          if x and y2 then
            local mapID2 = quest.mapID or C_Map.GetBestMapForUnit("player")
            TomTom:AddWaypoint(mapID2, tonumber(x)/100, tonumber(y2)/100, {
              title = quest.name, persistent = false,
            })
          end
        end
      end)
      row:SetScript("OnEnter", function(s)
        s:SetBackdropBorderColor(tc.r, tc.g, tc.b, 0.9)
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine(quest.name, 1, 1, 1)
        GameTooltip:AddLine("Zone : "..quest.zone, 0.7, 0.7, 0.7)
        GameTooltip:AddLine("+"..quest.rep.." rep", tc.r, tc.g, tc.b)
        if quest.tip and quest.tip ~= "" then
          GameTooltip:AddLine(quest.tip, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function(s)
        GameTooltip:Hide()
        if done then
          s:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.4)
        else
          s:SetBackdropBorderColor(tc.r*0.4, tc.g*0.4, tc.b*0.4, 0.6)
        end
      end)

      return row
    end -- BuildQuestRow

    for _, grp in ipairs(groups) do
      if #grp.quests > 0 then
        local isOpen = RenTrackerDB.sections[grp.key]
        local tc     = TYPE_COLORS[grp.key] or {r=1,g=1,b=1}

        -- En-tete de groupe (accordeon)
        local header = CreateFrame("Button", nil, self.questContent, "BackdropTemplate")
        header:SetPoint("TOPLEFT", self.questContent, "TOPLEFT", 2, -y)
        header:SetSize(rowW, 26)
        header:SetBackdrop({
          bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
          edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
          tile=true, tileSize=8, edgeSize=6,
          insets={left=2,right=2,top=2,bottom=2},
        })
        header:SetBackdropColor(tc.r*0.15, tc.g*0.15, tc.b*0.15, 0.95)
        header:SetBackdropBorderColor(tc.r*0.5, tc.g*0.5, tc.b*0.5, 0.7)

        local arrow = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrow:SetPoint("LEFT", header, "LEFT", 8, 0)
        arrow:SetText(isOpen and "|cFFFFD700-|r" or "|cFF888888+|r")

        local hTxt = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hTxt:SetPoint("LEFT", header, "LEFT", 24, 0)
        hTxt:SetText(string.format("|cFF%02X%02X%02X%s|r  |cFF888888(%d)|r",
          math.floor(tc.r*255), math.floor(tc.g*255), math.floor(tc.b*255),
          grp.label, #grp.quests))

        -- Stocker refs pour toggle
        local questRows = {}
        local currentY  = y + 28
        for _, quest in ipairs(grp.quests) do
          local r = BuildQuestRow(self.questContent, quest, currentY, fac)
          r:SetShown(isOpen)
          table.insert(questRows, r)
          -- Hauteur dynamique : lire la hauteur reelle du row
          local rH = r:GetHeight() or 60
          currentY = currentY + rH + 2
        end

        header:SetScript("OnClick", function()
          RenTrackerDB.sections[grp.key] = not RenTrackerDB.sections[grp.key]
          mainFrame:RefreshContent()
        end)

        if isOpen then
          y = currentY + 4
        else
          y = y + 28 + 4
        end
        contentHeight = y
      end
    end

    -- Ajuster scrollBg et questContent à la hauteur exacte du contenu
    local questH = math.max(40, contentHeight + 12)
    self.questContent:SetHeight(questH)
    if self.scrollBg then
      self.scrollBg:SetHeight(questH + 12)
    end

    -- Auto-resize fenêtre : max(colonne gauche, contenu droit)
    local TAB_H_LOCAL   = 28
    local TAB_GAP_LOCAL = 2
    local nModern       = #EXT_ROW1
    local nClassicLocal = #EXT_ROW2
    local colH = 58
                 + nModern       * (TAB_H_LOCAL + TAB_GAP_LOCAL)
                 + 8
                 + nClassicLocal * (TAB_H_LOCAL + TAB_GAP_LOCAL)
                 + 5 + TAB_H_LOCAL
                 + 20
    -- questY dynamique : baseY - 18 (repHeader) - 18 (barY2) - 34 (infoY) - 52
    local questYabs     = math.abs(baseY) + 18 + 18 + 34 + 52
    local contentNeeded = questYabs + 38 + questH + 20
    local newH = math.max(colH, contentNeeded, 450)
    -- Ajuste la hauteur max a l'ecran disponible (evite de deborder haut/bas)
    local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 900
    newH = math.min(newH, math.max(450, screenH - 80))
    mainFrame:SetHeight(newH)
  end -- RefreshContent

  mainFrame:Hide()
end

-- ================================================================
-- BOUTON MINIMAP
-- Conforme aux règles Blizzard :
--   • Parent = Minimap (ancrage orbital)
--   • Texture icône 64×64 px → affichée 30×30
--   • Ring doré Blizzard en OVERLAY (MiniMap-TrackingBorder)
--   • Highlight en HIGHLIGHT (UI-Minimap-ZoomButton-Highlight)
--   • Rayon dynamique basé sur Minimap:GetWidth() (compatible ElvUI / Dominos)
--   • Drag orbital avec atan2 → angle sauvegardé en DB
--   • SetMovable(false) : pas de déplacement libre, uniquement orbital
-- ================================================================
local minimapBtn

-- Retourne le rayon orbital en pixels, adapté à la taille réelle
-- de la minimap (certains addons la redimensionnent).
local function GetMinimapRadius()
  return (Minimap:GetWidth() / 2) + 10
end

-- Place le bouton sur le cercle orbital à l'angle donné (degrés).
-- Sauvegarde l'angle dans la DB pour le restaurer au prochain login.
local function SetMinimapPos(angle)
  -- Normalise l'angle entre 0 et 360
  angle = angle % 360
  if RenTrackerDB then RenTrackerDB.mmAngle = angle end
  local r   = GetMinimapRadius()
  local rad = math.rad(angle)
  minimapBtn:ClearAllPoints()
  minimapBtn:SetPoint(
    "CENTER", Minimap, "CENTER",
    math.cos(rad) * r,
    math.sin(rad) * r
  )
end

local function BuildMinimapButton()
  -- ── Cadre principal ────────────────────────────────────────────
  -- Bouton 32×32, parent = Minimap (ancrage orbital)
  -- Structure conforme à DBIcon et aux boutons Blizzard natifs
  minimapBtn = CreateFrame("Button", "RNTMinimapBtn", Minimap)
  minimapBtn:SetSize(32, 32)
  minimapBtn:SetFrameStrata("MEDIUM")
  minimapBtn:SetFrameLevel(8)
  minimapBtn:SetMovable(false)
  minimapBtn:EnableMouse(true)
  minimapBtn:SetClampedToScreen(true)
  minimapBtn:SetToplevel(true)

  -- ── Couche 1 : icône custom avec mask circulaire (ARTWORK) ─────
  -- Icône 20×20 (taille standard des icônes minimap Blizzard).
  -- Le mask CircleMask coupe les coins pour un rendu parfaitement circulaire.
  local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER", minimapBtn, "CENTER", 0, 0)
  icon:SetSize(24, 24)
  icon:SetTexture("Interface\\AddOns\\RenTracker\\medias\\RenTracker")
  -- Mask circulaire Blizzard : coupe les 4 coins de l\'icône carrée
  local mask = minimapBtn:CreateMaskTexture()
  mask:SetAllPoints(icon)
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  icon:AddMaskTexture(mask)

  -- ── Couche 2 : ring doré Blizzard (OVERLAY) ────────────────────
  -- Offset standard DBIcon/Blizzard : TOPLEFT(-8, 8) sur SIZE 56×56.
  -- C'est l'offset exact utilisé par tous les addons minimap professionnels
  -- pour aligner le ring doré avec le bord circulaire de la minimap.
  local ring = minimapBtn:CreateTexture(nil, "OVERLAY")
  ring:SetSize(52, 52)
  ring:SetPoint("TOPLEFT", minimapBtn, "TOPLEFT", 0, 0)
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  -- ── Couche 3 : highlight au survol (HIGHLIGHT) ─────────────────
  -- Texture circulaire blanche semi-transparente, avec mask pour rester ronde.
  -- On NE PAS utiliser la couche "HIGHLIGHT" native de WoW car elle ignore les masks.
  -- À la place : deux textures ARTWORK gérées manuellement via OnEnter/OnLeave.
  local hl = minimapBtn:CreateTexture(nil, "ARTWORK")
  hl:SetPoint("CENTER", minimapBtn, "CENTER", 0, 0)
  hl:SetSize(20, 20)
  hl:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
  hl:SetVertexColor(1, 1, 1, 0.25)
  hl:SetAlpha(0)  -- caché par défaut
  -- Mask circulaire identique à l'icône
  local hlMask = minimapBtn:CreateMaskTexture()
  hlMask:SetAllPoints(hl)
  hlMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  hl:AddMaskTexture(hlMask)
  minimapBtn._hl = hl

  -- ── Position initiale ──────────────────────────────────────────
  -- Restaurée depuis la DB (220° = bas-gauche par défaut, comme DBIcon)
  local savedAngle = (RenTrackerDB and RenTrackerDB.mmAngle) or 220
  SetMinimapPos(savedAngle)

  -- Repositionne si la minimap change de taille (ElvUI, Dominos, etc.)
  minimapBtn:SetScript("OnShow", function()
    SetMinimapPos((RenTrackerDB and RenTrackerDB.mmAngle) or 220)
  end)

  -- ── Drag orbital ───────────────────────────────────────────────
  -- L'angle est calculé en temps réel depuis la position du curseur
  -- relativement au centre de la minimap (atan2). Pas de SetMovable(true)
  -- car on ne veut pas que WoW gère le déplacement librement.
  minimapBtn:RegisterForDrag("LeftButton")

  minimapBtn:SetScript("OnDragStart", function(s)
    s:SetScript("OnUpdate", function()
      local mx, my   = Minimap:GetCenter()
      local uiScale  = UIParent:GetEffectiveScale()
      local cx, cy   = GetCursorPosition()
      -- Convertir les coordonnées écran en coordonnées UI
      local angle = math.deg(math.atan2(
        (cy / uiScale) - my,
        (cx / uiScale) - mx
      ))
      SetMinimapPos(angle)
    end)
  end)

  minimapBtn:SetScript("OnDragStop", function(s)
    -- Arrêter le tracking OnUpdate dès que le bouton est relâché
    s:SetScript("OnUpdate", nil)
  end)

  -- ── Recalcul du rayon si la minimap est redimensionnée ─────────
  -- Certains addons (Dominos, SexyMap) redimensionnent la minimap dynamiquement.
  -- On écoute MINIMAP_UPDATE_ZOOM comme signal de changement de taille.
  local resizeWatcher = CreateFrame("Frame")
  resizeWatcher:RegisterEvent("MINIMAP_UPDATE_ZOOM")
  resizeWatcher:SetScript("OnEvent", function()
    SetMinimapPos((RenTrackerDB and RenTrackerDB.mmAngle) or 220)
  end)

  -- ── Clic : ouvrir / fermer la fenêtre principale ───────────────
  minimapBtn:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
      if mainFrame:IsShown() then
        mainFrame:Hide()
        RenTrackerDB.open = false
      else
        mainFrame:Show()
        mainFrame:RefreshContent()
        RenTrackerDB.open = true
      end
    end
  end)
  -- ── Tooltip + highlight circulaire ────────────────────────────────────
  minimapBtn:SetScript("OnEnter", function(s)
    if s._hl then s._hl:SetAlpha(1) end
    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
    GameTooltip:AddLine("RenTracker", 0.45, 0.70, 1.0)
    GameTooltip:AddLine("Suivi des réputations", 0.9, 0.9, 0.9)
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("|cFFFFD700Clic gauche|r : ouvrir / fermer", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("|cFFFFD700Glisser|r : repositionner l'icône", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  minimapBtn:SetScript("OnLeave", function(s)
    if s._hl then s._hl:SetAlpha(0) end
    GameTooltip:Hide()
  end)
end

-- ================================================================
-- ADDON COMPARTMENT (liste Blizzard des addons, icône barre minimap)
-- Ces 3 fonctions sont déclarées en global pour correspondre aux
-- entrées ## AddonCompartmentFunc* du .toc
-- ================================================================
function RenTracker_OnAddonCompartmentClick()
  if mainFrame:IsShown() then
    mainFrame:Hide()
    RenTrackerDB.open = false
  else
    mainFrame:Show()
    mainFrame:RefreshContent()
    RenTrackerDB.open = true
  end
end

function RenTracker_OnAddonCompartmentEnter(btn)
  GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
  GameTooltip:AddLine("RenTracker", 0.45, 0.70, 1.0)
  GameTooltip:AddLine("Suivi des réputations", 0.9, 0.9, 0.9)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("|cFFFFD700Clic|r : ouvrir / fermer", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end

function RenTracker_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end

-- ================================================================
-- TIBISUITE INTEGRATION
-- Fonction publique appelée par TibiSuite pour ouvrir/fermer la fenêtre.
-- ================================================================
function RenTracker_Toggle()
  if mainFrame:IsShown() then
    mainFrame:Hide()
    RenTrackerDB.open = false
  else
    mainFrame:Show()
    mainFrame:RefreshContent()
    RenTrackerDB.open = true
  end
end

-- ================================================================
-- PANNEAU D'OPTIONS
-- Cases a cocher persistees dans RenTrackerDB.options.
-- Accessible via /rt config ou le bouton "Options" de la fenetre.
-- ================================================================
local optFrame

local function BuildOptionsPanel()
  optFrame = CreateFrame("Frame", "RNTOptionsFrame", UIParent, "BackdropTemplate")
  optFrame:SetSize(360, 200)
  optFrame:SetPoint("CENTER")
  optFrame:SetFrameStrata("DIALOG")
  optFrame:SetToplevel(true)
  optFrame:EnableMouse(true)
  optFrame:SetMovable(true)
  optFrame:RegisterForDrag("LeftButton")
  optFrame:SetScript("OnDragStart", optFrame.StartMoving)
  optFrame:SetScript("OnDragStop", optFrame.StopMovingOrSizing)
  optFrame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=true, tileSize=32, edgeSize=32,
    insets={left=11, right=12, top=12, bottom=11},
  })
  optFrame:SetBackdropColor(0.04, 0.02, 0.06, 0.97)
  optFrame:SetBackdropBorderColor(0.72, 0.60, 0.28, 1.0)

  local title = optFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", 0, -16)
  title:SetText("|cFFFFD700RenTracker|r  |cFF888888Options|r")

  local close = CreateFrame("Button", nil, optFrame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  EnsureDB()

  -- Case a cocher + label independant du template (rendu fiable multi-versions)
  local function AddCheck(y, label, key)
    local cb = CreateFrame("CheckButton", nil, optFrame, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 24, y)
    cb:SetSize(26, 26)
    cb:SetChecked(RenTrackerDB.options[key] and true or false)
    local fs = optFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    fs:SetText(label)
    cb:SetScript("OnClick", function(s)
      RenTrackerDB.options[key] = s:GetChecked() and true or false
    end)
    return cb
  end

  AddCheck(-48,  "Suivi automatique par zone",           "autoTrack")
  AddCheck(-80,  "Message de connexion dans le chat",    "loginMsg")
  AddCheck(-112, "Son au passage de niveau de Renown",   "sound")

  local hint = optFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  hint:SetPoint("BOTTOM", 0, 18)
  hint:SetText("|cFF888888/rt config pour rouvrir ce panneau|r")

  optFrame:Hide()
end

-- Global : reference par le bouton "Options" de la fenetre (lookup a l'appel)
function RenTracker_ToggleOptions()
  if not optFrame then BuildOptionsPanel() end
  if optFrame:IsShown() then optFrame:Hide() else optFrame:Show() end
end

-- ================================================================
-- COMMANDES SLASH
-- ================================================================
SLASH_RENTRACKER1 = "/rt"
SlashCmdList["RENTRACKER"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "config" or msg == "options" or msg == "option" then
    RenTracker_ToggleOptions()
    return
  end
  if mainFrame:IsShown() then
    mainFrame:Hide()
    RenTrackerDB.open = false
  else
    mainFrame:Show()
    mainFrame:RefreshContent()
    RenTrackerDB.open = true
  end
end

-- ================================================================
-- EVENEMENTS
-- ================================================================
local evFrame = CreateFrame("Frame")
evFrame:RegisterEvent("ADDON_LOADED")
evFrame:RegisterEvent("PLAYER_LOGIN")
evFrame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
evFrame:RegisterEvent("UPDATE_FACTION")
evFrame:RegisterEvent("QUEST_TURNED_IN")
evFrame:RegisterEvent("QUEST_LOG_UPDATE")
evFrame:RegisterEvent("ZONE_CHANGED")
evFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
evFrame:RegisterEvent("ZONE_CHANGED_INDOORS")

evFrame:SetScript("OnEvent", function(_, event, arg1)

  if event == "ADDON_LOADED" and arg1 == "TibiSuite" then
    -- TibiSuite est actif : on masque le bouton minimap individuel
    local btn = _G["RNTMinimapBtn"]
    if btn and btn.Hide then btn:Hide() end

  elseif event == "ADDON_LOADED" and arg1 == ADDON then

    EnsureDB()  -- garantit options + sous-tables meme pour un profil ancien
    BuildUI()
    BuildMinimapButton()

    -- Restaurer position fenetre
    local p = RenTrackerDB.pos
    if p and p.x then
      mainFrame:ClearAllPoints()
      mainFrame:SetPoint(p.point or "CENTER", UIParent, p.point or "CENTER", p.x, p.y)
    else
      mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- (redimensionnement manuel supprime en v3.4)

    RenTrackerDB.open = false  -- ferme automatiquement au login

    -- Rattrapage LoadOnDemand : quand TibiSuite charge ce module a la demande,
    -- PLAYER_LOGIN est deja passe et son handler ci-dessous ne se declenchera
    -- plus. On rejoue donc ici le travail de login (message + suivi auto par
    -- zone) si la connexion est deja effective. Aucun impact sur les donnees.
    if IsLoggedIn() then
      if not (RenTrackerDB.options and RenTrackerDB.options.loginMsg == false) then
        print("|cFF4D99FFRenTracker|r v7.0 chargé -- tapez |cFFFFD700/rt|r pour ouvrir.")
      end
      C_Timer.After(2, AutoTrackFactionByZone)
    end

  elseif event == "PLAYER_LOGIN" then
    if not (RenTrackerDB.options and RenTrackerDB.options.loginMsg == false) then
      print("|cFF4D99FFRenTracker|r v7.0 chargé -- tapez |cFFFFD700/rt|r pour ouvrir.")
    end
    -- Suivi auto au login (AutoTrackFactionByZone respecte l'option autoTrack)
    C_Timer.After(2, AutoTrackFactionByZone)

  elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" then
    AutoTrackFactionByZone()

  elseif event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" then
    -- Son optionnel au passage de niveau de Renown
    if RenTrackerDB.options and RenTrackerDB.options.sound then
      local snd = (SOUNDKIT and SOUNDKIT.UI_MAJOR_FACTION_RENOWN_LEVEL_UP) or 172586
      if PlaySound then pcall(PlaySound, snd) end
    end
    ScheduleRefresh()

  elseif event == "UPDATE_FACTION" or event == "QUEST_TURNED_IN"
      or event == "QUEST_LOG_UPDATE" then
    ScheduleRefresh()
  end

end)
