-- ================================================================
-- LegTracker v7.1.5.38
-- Suivi des objets legendaires de toutes les extensions WoW
-- Auteur : Tibiscui - Kirin Tor
-- Design & architecture propre a LegTracker
-- ================================================================
-- NOUVEAUTES v2.0 :
--   * Onglets verticaux (Midnight en haut)
--   * Icones d'extension visibles dans les onglets
--   * Suivi compte complet : scanne tous vos personnages connus
--   * Affiche quel personnage detient chaque legendaire
--   * Section "Comment obtenir les composants" dans le panneau detail
--   * Correction Sulfuras : verifie equipe + sac + coffre + banque
-- ================================================================

local ADDON = "LegTracker"
local L     = LegTrackerL or {}
local function T(key, default) return L[key] or default end

-- ================================================================
-- COULEURS GLOBALES
-- ================================================================
local COL_GOLD   = "|cFFFFD700"
local COL_PURPLE = "|cFF9480FF"
local COL_GREY   = "|cFF888888"
local COL_GREEN  = "|cFF44FF44"
local COL_RED    = "|cFFFF4444"
local COL_YELLOW = "|cFFFFCC00"
local COL_BLUE   = "|cFF4D99FF"
local COL_WHITE  = "|cFFEEEEEE"
local COL_PINK   = "|cFFF58CBA"
local COL_RESET  = "|r"

-- (pas d'icones dans les onglets - layout texte seul)

-- Couleurs des extensions (onglets)
local EXT_TAB_COLORS = {
  Midnight           = {r=0.58, g=0.30, b=0.95},
  TheWarWithin       = {r=0.55, g=0.75, b=0.95},
  Dragonflight       = {r=0.95, g=0.45, b=0.10},
  Shadowlands        = {r=0.45, g=0.55, b=0.95},
  BattleForAzeroth   = {r=0.85, g=0.25, b=0.25},
  Legion             = {r=0.60, g=0.15, b=0.85},
  WarlordsOfDraenor  = {r=0.85, g=0.50, b=0.10},
  MistsOfPandaria    = {r=0.20, g=0.65, b=0.45},
  Cataclysm          = {r=0.95, g=0.35, b=0.10},
  WrathOfTheLichKing = {r=0.65, g=0.85, b=1.00},
  TheBurningCrusade  = {r=0.20, g=0.75, b=0.28},
  Vanilla            = {r=0.95, g=0.78, b=0.35},
}

local EXT_LABELS = {
  Midnight           = "MID",
  TheWarWithin       = "TWW",
  Dragonflight       = "DF",
  Shadowlands        = "SL",
  BattleForAzeroth   = "BfA",
  Legion             = "LEG",
  WarlordsOfDraenor  = "WoD",
  MistsOfPandaria    = "MoP",
  Cataclysm          = "CATA",
  WrathOfTheLichKing = "WotLK",
  TheBurningCrusade  = "TBC",
  Vanilla            = "VAN",
}

local EXT_FULLNAMES = {
  Midnight           = "Midnight",
  TheWarWithin       = "The War Within (11.0)",
  Dragonflight       = "Dragonflight (10.0)",
  Shadowlands        = "Shadowlands (9.0)",
  BattleForAzeroth   = "Battle for Azeroth (8.0)",
  Legion             = "Legion (7.0)",
  WarlordsOfDraenor  = "Warlords of Draenor (6.0)",
  MistsOfPandaria    = "Mists of Pandaria (5.0)",
  Cataclysm          = "Cataclysm (4.0)",
  WrathOfTheLichKing = "Wrath of the Lich King (3.0)",
  TheBurningCrusade  = "The Burning Crusade (2.0)",
  Vanilla            = "Vanilla / Classic",
}

-- Couleurs officielles WoW par classe (codes hex Blizzard)
local CLASS_COLORS = {
  WARRIOR      = "C69B3A",
  PALADIN      = "F48CBA",
  HUNTER       = "AAD372",
  ROGUE        = "FFF468",
  PRIEST       = "FFFFFF",
  DEATHKNIGHT  = "C41E3A",
  SHAMAN       = "0070DD",
  MAGE         = "3FC7EB",
  WARLOCK      = "8788EE",
  MONK         = "00FF98",
  DRUID        = "FF7C0A",
  DEMONHUNTER  = "A330C9",
  EVOKER       = "33937F",
}

-- Noms localisés des classes (français)
local CLASS_NAMES_FR = {
  WARRIOR      = "Guerrier",
  PALADIN      = "Paladin",
  HUNTER       = "Chasseur",
  ROGUE        = "Voleur",
  PRIEST       = "Prêtre",
  DEATHKNIGHT  = "Chevalier de la mort",
  SHAMAN       = "Chaman",
  MAGE         = "Mage",
  WARLOCK      = "Démoniste",
  MONK         = "Moine",
  DRUID        = "Druide",
  DEMONHUNTER  = "Chasseur de démons",
  EVOKER       = "Évocateur",
}

-- Retourne une chaîne colorée listant les classes requises
local function GetClassesText(item)
  if not item.classes or #item.classes == 0 then
    return "|cFFFFFFFF" .. T("ALL_CLASSES", "Toutes classes") .. "|r"
  end
  local parts = {}
  for _, cls in ipairs(item.classes) do
    local hex  = CLASS_COLORS[cls]    or "AAAAAA"
    local name = CLASS_NAMES_FR[cls]  or cls
    table.insert(parts, "|cFF" .. hex .. name .. "|r")
  end
  return table.concat(parts, "|cFFAAAAAA, |r")
end


local EXT_ROW1 = { "Midnight","TheWarWithin","Dragonflight","Shadowlands","BattleForAzeroth","Legion" }
local EXT_ROW2 = { "WarlordsOfDraenor","MistsOfPandaria","Cataclysm","WrathOfTheLichKing","TheBurningCrusade","Vanilla" }

local STATUS_COLORS = {
  OBTAINED    = {r=0.27, g=1.00, b=0.27},
  IN_PROGRESS = {r=1.00, g=0.82, b=0.00},
  MISSING     = {r=1.00, g=0.27, b=0.27},
  UNAVAILABLE = {r=0.53, g=0.53, b=0.53},
}

-- ================================================================
-- DONNEES JOUEUR ET COMPTE
-- ================================================================
local PLAYER_CLASS = nil
local PLAYER_NAME  = nil
local PLAYER_REALM = nil

-- ================================================================
-- SAUVEGARDE
-- ================================================================
local function InitDB()
  LegTrackerDB = LegTrackerDB or {}
  local db = LegTrackerDB
  if not db.pos               then db.pos = {x=0, y=0} end
  if db.pos.x == nil          then db.pos.x = 0 end
  if db.pos.y == nil          then db.pos.y = 0 end
  if db.selectedExtension == nil then db.selectedExtension = 1 end
  if db.mmAngle == nil        then db.mmAngle = 220 end
  if db.open == nil           then db.open = false end
  if db.sections == nil       then db.sections = {} end
  -- Donnees de compte : db.accountData[realm][charName][itemID] = true
  if not db.accountData       then db.accountData = {} end

  -- Options
  if not db.filters           then db.filters = {} end
  if db.filters.hideObtained    == nil then db.filters.hideObtained    = false end
  if db.filters.hideUnavailable == nil then db.filters.hideUnavailable = false end
  if db.filters.hideLegacy      == nil then db.filters.hideLegacy      = false end
  if db.scale       == nil    then db.scale       = 1.0 end
  if db.alpha       == nil    then db.alpha       = 0.97 end
  if db.locked      == nil    then db.locked      = false end
  if db.showMinimap == nil    then db.showMinimap = true end
  if db.autoOpen    == nil    then db.autoOpen    = false end
  if db.tooltips    == nil    then db.tooltips    = true  end   -- infobulles des composants (lot B)
  if db.lootAlert   == nil    then db.lootAlert   = true  end   -- alerte au butin (lot C)
  if db.lootSound   == nil    then db.lootSound   = true  end
  -- db.width / db.height : renseignes seulement apres un redimensionnement manuel
end

-- Filtre d'affichage : true = l'item doit etre visible
local function ItemPassesFilter(item)
  local f  = (LegTrackerDB and LegTrackerDB.filters) or {}
  local st = item._status
  if f.hideObtained    and st == "OBTAINED"    then return false end
  if f.hideUnavailable and st == "UNAVAILABLE" then return false end
  if f.hideLegacy      and item.legacy         then return false end
  return true
end

-- ================================================================
-- UTILITAIRES : DETECTION ITEM (CORRIGE POUR SULFURAS)
-- ================================================================

-- Verifie si un item est equipe sur le personnage actuel
local function IsEquipped(itemID)
  if not itemID or itemID == 0 then return false end
  for slot = 1, 19 do
    if GetInventoryItemID("player", slot) == itemID then return true end
  end
  return false
end

-- Compte l'item partout : sacs, banque, banque de composants, banque de
-- bataillon (arguments includeBank, includeUses, includeReagentBank,
-- includeAccountBank). 7.1.5.31 : le global GetItemCount (deprecie) n'est
-- plus appele que si C_Item.GetItemCount n'existe pas, et seulement s'il
-- existe lui-meme. Avant, il etait appele a chaque resultat 0, soit
-- presque a chaque scan.
local function CountItemEverywhere(itemID)
  if not itemID or itemID == 0 then return 0 end
  if C_Item and C_Item.GetItemCount then
    return C_Item.GetItemCount(itemID, true, false, true, true) or 0
  end
  if GetItemCount then return GetItemCount(itemID, true) or 0 end
  return 0
end

-- Quantite d'une monnaie (Cendre d'ame, Flux cosmique...)
local function CountCurrency(currencyID)
  if not (currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return 0 end
  local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
  return (info and info.quantity) or 0
end

-- Quantite possedee pour un composant (objet ou monnaie)
local function TrackerCount(tr)
  if tr.currencyID then return CountCurrency(tr.currencyID) end
  return CountItemEverywhere(tr.itemID)
end

-- Cache "possede sur ce personnage", vide au debut de chaque ScanAll : un
-- meme objet etait interroge 3 a 4 fois par rafraichissement (scan, sauvegarde
-- compte, proprietaires, infobulle).
local ownedCache = {}

-- Verification complete sur le personnage actuel
local function IsObtainedOnCurrentChar(itemID)
  if not itemID or itemID == 0 then return false end
  local cached = ownedCache[itemID]
  if cached ~= nil then return cached end
  local owned = IsEquipped(itemID) or CountItemEverywhere(itemID) > 0
  ownedCache[itemID] = owned
  return owned
end

-- ================================================================
-- GESTION DES DONNEES DE COMPTE (suivi multi-personnages)
-- ================================================================

local function SaveCurrentCharData()
  if not LegTrackerDB or not PLAYER_NAME or not PLAYER_REALM then return end
  local db = LegTrackerDB
  if not db.accountData[PLAYER_REALM] then db.accountData[PLAYER_REALM] = {} end
  -- Table reutilisee (videe) plutot que recreee a chaque scan
  local charData = db.accountData[PLAYER_REALM][PLAYER_NAME]
  if type(charData) == "table" then wipe(charData) else charData = {} end
  db.accountData[PLAYER_REALM][PLAYER_NAME] = charData

  -- Sauvegarde de la classe du personnage pour colorisation
  if PLAYER_CLASS then
    charData._class = PLAYER_CLASS
  end

  if not LegTrackerData or not LegTrackerData.Extensions then return end
  for _, ext in ipairs(LegTrackerData.Extensions) do
    for _, item in ipairs(ext.items or {}) do
      if item.itemID and item.itemID > 0 then
        if IsObtainedOnCurrentChar(item.itemID) then
          charData[item.itemID] = true
        end
      end
    end
  end
end

-- Retourne une liste de tables {display=..., class=...} pour chaque personnage possedant l'item
local function GetCharsWithItem(itemID)
  if not LegTrackerDB or not LegTrackerDB.accountData then return {} end
  local result = {}
  for realm, chars in pairs(LegTrackerDB.accountData) do
    for charName, items in pairs(chars) do
      if items[itemID] then
        table.insert(result, {
          display = charName .. " (" .. realm .. ")",
          name    = charName,
          realm   = realm,
          class   = items._class or nil,
        })
      end
    end
  end
  return result
end

-- Retourne une chaine avec les noms des proprietaires colores par classe
-- compact=true : noms courts sans royaume, pour la colonne centrale
local function GetOwnersText(itemID, compact)
  local chars = GetCharsWithItem(itemID)
  -- Ajouter le personnage actuel s'il possede l'objet
  if IsObtainedOnCurrentChar(itemID) and PLAYER_NAME then
    local cur = PLAYER_NAME .. " (" .. (PLAYER_REALM or "?") .. ")"
    local found = false
    for _, c in ipairs(chars) do if c.display == cur then found = true break end end
    if not found then
      table.insert(chars, {
        display = cur,
        name    = PLAYER_NAME,
        realm   = PLAYER_REALM or "?",
        class   = PLAYER_CLASS,
      })
    end
  end
  if #chars == 0 then return nil end
  local parts = {}
  for _, c in ipairs(chars) do
    local hex   = CLASS_COLORS[c.class] or "AAAAAA"
    local label = compact and c.name or c.display
    table.insert(parts, "|cFF" .. hex .. label .. "|r")
  end
  return table.concat(parts, "|cFFAAAAAA, |r")
end

-- ================================================================
-- FONCTIONS UTILITAIRES
-- ================================================================
local function HasClass(item)
  if item.placeholder then return false end
  if not item.classes  then return true  end
  if not PLAYER_CLASS  then return true  end
  for _, c in ipairs(item.classes) do
    if c == PLAYER_CLASS then return true end
  end
  return false
end

local function IsAchievementCompleted(id)
  if not id or id == 0 then return false end
  local _, _, _, completed = GetAchievementInfo(id)
  return completed == true
end

local function AnyAchievementCompleted(item)
  if item.achievementID and IsAchievementCompleted(item.achievementID) then return true end
  if item.achievements then
    for _, id in ipairs(item.achievements) do
      if IsAchievementCompleted(id) then return true end
    end
  end
  return false
end

-- Apparence apprise (collection du compte entier). Lot B : un legendaire
-- detenu un jour par n'importe quel personnage du compte, puis vendu,
-- detruit ou jamais scanne, est ainsi reconnu sans connecter chaque perso.
-- Sans effet pour les objets sans apparence (anneaux, bijoux, colliers).
local function HasTransmog(itemID)
  if not (itemID and itemID > 0 and C_TransmogCollection and C_TransmogCollection.PlayerHasTransmog) then return false end
  local ok, has = pcall(C_TransmogCollection.PlayerHasTransmog, itemID)
  return ok and has == true
end

-- Obtenu sur un AUTRE personnage deja scanne (LegTrackerDB.accountData)
local function IsObtainedOnAlt(itemID)
  if not itemID or itemID == 0 or not (LegTrackerDB and LegTrackerDB.accountData) then return false end
  for realm, chars in pairs(LegTrackerDB.accountData) do
    for charName, items in pairs(chars) do
      if items[itemID] and not (charName == PLAYER_NAME and realm == PLAYER_REALM) then return true end
    end
  end
  return false
end

local function IsOnQuest(questID)
  return questID and C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID) == true
end

local function QuestCompleted(questID)
  return questID
    and C_QuestLog
    and C_QuestLog.IsQuestFlaggedCompleted
    and C_QuestLog.IsQuestFlaggedCompleted(questID) == true
end

local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function GetIcon(itemID)
  if itemID and itemID > 0 then
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
    if icon then return icon end
    -- GetItemInfoInstant : l'icone est le 5e retour (l'ancien code lisait le
    -- 4e, le sous-type d'equipement). Global deprecie : C_Item en priorite.
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if instant then
      local _, _, _, _, icon2 = instant(itemID)
      if icon2 then return icon2 end
    end
  end
  return QUESTION_ICON
end

-- Icone d'un composant (objet ou monnaie)
local function GetTrackerIcon(tr)
  if tr.currencyID then
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(tr.currencyID)
    return (info and info.iconFileID) or QUESTION_ICON
  end
  return GetIcon(tr.itemID)
end

local function GetItemName(item)
  if item.itemID and item.itemID > 0 then
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item.itemID)
    if name then return name end
  end
  return item.name or T("UNKNOWN", "Inconnu")
end

-- Nom + classe quand l'objet est reserve a UNE classe : distingue les
-- quatre Atiesh (meme nom en jeu) dans la vue Collection et le Dashboard.
local function DisplayName(item)
  local name = GetItemName(item)
  if item.classes and #item.classes == 1 then
    local cls = item.classes[1]
    local loc = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cls]) or CLASS_NAMES_FR[cls] or cls
    name = name .. " (" .. loc .. ")"
  end
  return name
end

-- ================================================================
-- SCAN DES LEGENDAIRES (niveau compte)
-- ================================================================
local function ScanLegendaryStatus(item)
  -- Fiche d'attente (pas encore d'objet reel) : jamais "obtenue"
  if item.placeholder then return "UNAVAILABLE", 0, 0, 0, 0 end
  local equippable = HasClass(item)

  -- Obtenu, meme si non equippable. "via" dit comment on le sait (lot B) :
  --   char = sur ce personnage, alt = sur un autre personnage scanne,
  --   achievement = tour de force du compte, transmog = apparence apprise.
  local id  = item.itemID
  local via = (IsObtainedOnCurrentChar(id) and "char")
           or (IsObtainedOnAlt(id) and "alt")
           or (AnyAchievementCompleted(item) and "achievement")
           or (HasTransmog(id) and "transmog")
           or nil
  if via then return "OBTAINED", 0, 0, 0, 0, via end

  if not equippable then return "UNAVAILABLE", 0, 0, 0, 0 end

  -- Etapes : les quetes sont listees dans l'ordre de la suite. L'etape en
  -- cours est la premiere quete non terminee ; onQuest = elle est dans le
  -- journal de quetes.
  local questDone, questTotal = 0, 0
  local step, onQuest = nil, false
  if item.quests then
    for i, q in ipairs(item.quests) do
      if q.id then
        questTotal = questTotal + 1
        if QuestCompleted(q.id) then
          questDone = questDone + 1
        elseif not step then
          step, onQuest = i, IsOnQuest(q.id)
        end
      end
    end
  end

  local trackerDone, trackerTotal = 0, 0
  if item.trackers then
    for _, tr in ipairs(item.trackers) do
      if tr.itemID or tr.currencyID then
        trackerTotal = trackerTotal + 1
        if TrackerCount(tr) >= (tr.need or 1) then trackerDone = trackerDone + 1 end
      end
    end
  end

  if questDone > 0 or trackerDone > 0 or onQuest then
    return "IN_PROGRESS", questDone, questTotal, trackerDone, trackerTotal, nil, step, onQuest
  end
  return "MISSING", questDone, questTotal, trackerDone, trackerTotal, nil, step, onQuest
end

-- ----------------------------------------------------------------
-- RESUME POUR LE DASHBOARD (lot C) : LegTrackerDB.dashboard, reecrit a
-- chaque scan. Autonome (noms deja localises, proprietaires au format
-- "Nom-Royaume" des cles de StatsDB) : Stats le recopie tel quel dans son
-- code d'export (data.legendaries) sans jamais appeler le code de
-- LegTracker. Champ additif de la SavedVariable, rien d'autre ne change.
-- ----------------------------------------------------------------
local function WriteDashboardSnapshot()
  if not LegTrackerDB then return end
  local owners = {}   -- itemID -> { "Nom-Royaume", ... }
  for realm, chars in pairs(LegTrackerDB.accountData or {}) do
    for charName, items in pairs(chars) do
      for id, v in pairs(items) do
        if type(id) == "number" and v then
          owners[id] = owners[id] or {}
          table.insert(owners[id], charName .. "-" .. realm)
        end
      end
    end
  end
  local exts = {}
  for _, ext in ipairs(LegTrackerData.Extensions) do
    local list = {}
    for _, item in ipairs(ext.items or {}) do
      if not item.placeholder and item.itemID and item.itemID > 0 then
        local o = owners[item.itemID]
        if o then table.sort(o) end
        list[#list + 1] = {
          id = item.itemID, name = DisplayName(item),
          status = item._status, via = item._via,
          legacy = item.legacy and true or nil,
          owners = o,
          step = (item._status ~= "OBTAINED") and item._step or nil,
          steps = (item.quests and #item.quests > 0) and #item.quests or nil,
          compDone = item._tDone, compTotal = (item._tTotal or 0) > 0 and item._tTotal or nil,
        }
      end
    end
    if #list > 0 then exts[#exts + 1] = { key = ext.key, label = ext.label, items = list } end
  end
  LegTrackerDB.dashboard = { at = time(), by = (PLAYER_NAME and PLAYER_REALM) and (PLAYER_NAME .. "-" .. PLAYER_REALM) or nil, exts = exts }
end

local function ScanAll()
  if not LegTrackerData or not LegTrackerData.Extensions then return end
  wipe(ownedCache)
  for _, ext in ipairs(LegTrackerData.Extensions) do
    for _, item in ipairs(ext.items or {}) do
      local status, qDone, qTotal, tDone, tTotal, via, step, onQuest = ScanLegendaryStatus(item)
      item._status = status
      item._via    = via
      item._step   = step
      item._onQuest = onQuest
      item._qDone  = qDone
      item._qTotal = qTotal
      item._tDone  = tDone
      item._tTotal = tTotal
    end
  end
  SaveCurrentCharData()
  WriteDashboardSnapshot()
end

-- Libelle court expliquant comment l'obtention a ete detectee (lot B)
local function ViaLabel(item)
  local via = item._via
  if via == "alt"         then return T("VIA_ALT", "sur un autre personnage") end
  if via == "achievement" then return T("VIA_ACHIEVEMENT", "tour de force du compte") end
  if via == "transmog"    then return T("VIA_TRANSMOG", "apparence apprise") end
  return nil
end

-- ----------------------------------------------------------------
-- FARM HEBDOMADAIRE (lot C) : pour chaque raid utile a un legendaire
-- (champ raids des donnees, instanceID = ID d'instance du client), lit les
-- verrouillages du personnage (GetSavedInstanceInfo, 14e retour =
-- instanceId). Lecture seule ; RequestRaidInfo() a l'ouverture de la
-- fenetre, UPDATE_INSTANCE_INFO rafraichit.
-- ----------------------------------------------------------------
local function GetRaidLockouts(instanceID)
  local out = {}
  if not (GetNumSavedInstances and GetSavedInstanceInfo) then return out end
  for i = 1, GetNumSavedInstances() do
    local _, _, reset, _, locked, extended, _, _, _, diffName, numEnc, encProg, _, instID = GetSavedInstanceInfo(i)
    if instID == instanceID and (locked or extended) and (reset or 0) > 0 then
      out[#out + 1] = { diff = diffName or "?", done = encProg or 0, total = numEnc or 0 }
    end
  end
  return out
end

local function RaidName(raid)
  if raid.name then return raid.name end
  local z = GetRealZoneText and GetRealZoneText(raid.instanceID)
  return (z and z ~= "") and z or ("#" .. tostring(raid.instanceID))
end

-- Texte multi-ligne du bloc "Farm cette semaine" (nil si sans objet)
local function FarmText(item)
  if not item.raids or item._status == "OBTAINED" or not HasClass(item) then return nil end
  local lines = {}
  for _, raid in ipairs(item.raids) do
    local locks = GetRaidLockouts(raid.instanceID)
    local line
    if #locks == 0 then
      line = COL_GREEN .. "- " .. RaidName(raid) .. " : " .. T("FARM_FREE", "libre cette semaine") .. COL_RESET
    else
      local parts = {}
      for _, lk in ipairs(locks) do parts[#parts + 1] = lk.diff .. " " .. lk.done .. "/" .. lk.total end
      line = "|cFFFF8800- " .. RaidName(raid) .. " : " .. T("FARM_LOCKED", "verrouille") .. " (" .. table.concat(parts, ", ") .. ")|r"
    end
    if raid.bosses then line = line .. "\n   |cFF888888" .. raid.bosses .. "|r" end
    lines[#lines + 1] = line
  end
  return table.concat(lines, "\n")
end

local function CountExtension(ext)
  local got, total, inProg = 0, 0, 0
  for _, item in ipairs(ext.items or {}) do
    if not item.placeholder and HasClass(item) then
      total = total + 1
      if item._status == "OBTAINED"     then got    = got + 1 end
      if item._status == "IN_PROGRESS"  then inProg = inProg + 1 end
    end
  end
  return got, total, inProg
end

-- ================================================================
-- TOMTOM
-- ================================================================
local function AddTomTomWaypoint(q)
  if not q or not q.mapID or not q.x or not q.y then
    print(COL_BLUE .. "LegTracker" .. COL_RESET .. " " .. T("NO_COORDS", "Aucune coordonnee disponible."))
    return
  end
  if not TomTom or not TomTom.AddWaypoint then
    -- Fallback natif Blizzard : point de route + grande fleche de suivi (equiv /way)
    if C_Map and C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(q.mapID) then
      -- Carte d'instance (Ulduar, Citadelle...) : le client refuse les points
      -- de route utilisateur sur ces cartes (erreur Lua sans ce test)
      print(COL_BLUE .. "LegTracker" .. COL_RESET
            .. " " .. T("WP_CANT_ON_MAP", "Point de route impossible sur cette carte (instance). Installez |cFFFFD700TomTom|r ou rendez-vous a l'entree :") .. " " .. (q.zone or "?"))
    elseif C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(q.mapID, q.x / 100, q.y / 100))
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
      end
      print(COL_BLUE .. "LegTracker" .. COL_RESET
            .. " " .. T("WP_MAP_ADDED", "Waypoint (carte) :") .. " " .. (q.name or "?") .. " (" .. (q.zone or "?") .. ")")
    else
      print(COL_BLUE .. "LegTracker" .. COL_RESET
            .. " " .. T("WP_NATIVE_FAIL", "Impossible de poser un waypoint natif. Installez |cFFFFD700TomTom|r."))
    end
    return
  end
  TomTom:AddWaypoint(q.mapID, q.x / 100, q.y / 100, {
    title      = (q.name or T("LEGENDARY_QUEST", "Quete legendaire")) .. (q.npc and (" - " .. q.npc) or ""),
    persistent = false, minimap = true, world = true,
  })
  print(COL_BLUE .. "LegTracker" .. COL_RESET
        .. " " .. T("WP_TOMTOM_ADDED", "Waypoint ajoute :") .. " " .. (q.name or "?") .. " (" .. (q.zone or "?") .. ")")
end

-- ================================================================
-- BACKDROPS
-- ================================================================
local BACKDROP_MAIN = {
  bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile=true, tileSize=32, edgeSize=32,
  insets={left=11, right=12, top=12, bottom=11},
}
local BACKDROP_TITLE = {
  bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile=true, tileSize=32, edgeSize=20,
  insets={left=7, right=7, top=7, bottom=7},
}
local BACKDROP_BTN = {
  bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile=true, tileSize=8, edgeSize=8,
  insets={left=3, right=3, top=3, bottom=3},
}
local BACKDROP_ROW = {
  bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile=true, tileSize=8, edgeSize=6,
  insets={left=2, right=2, top=2, bottom=2},
}

-- ================================================================
-- BASE DE DONNEES "COMMENT OBTENIR" LES COMPOSANTS
-- ================================================================
local HOW_TO_OBTAIN = {
  -- 7.1.5.31 : table realignee sur les IDs verifies en jeu (/lt verify)
  -- Vanilla
  [18563] = "Butin de Garr ou du Baron Geddon (Cœur du Magma), un Lien sur chacun.",
  [18564] = "Butin de Garr ou du Baron Geddon (Cœur du Magma), un Lien sur chacun.",
  [17771] = "Minerai d'élémentium du Repaire de l'Aile noire, transformé en barre.",
  [19018] = "Remise par le Grand seigneur Demitrian (Silithus) contre les deux Liens du Cherchevent.",
  [17204] = "Butin de Ragnaros (boss final du Cœur du Magma).",
  [17203] = "Butin des boss du Cœur du Magma.",
  [17193] = "Forgé à partir du plan du Marteau en sulfuron et des Lingots de sulfuron.",
  [22726] = "Butin sur les boss de Naxxramas original (non disponible en Retail moderne).",
  -- WotLK
  [45038] = "Butin sur n'importe quel boss d'Ulduar (~5% de chance par boss).",
  [45039] = "Obtenez 30 Fragments de Val'anyr, puis tuez Yogg-Saron.",
  [49908] = "Butin des boss de la Citadelle de la Couronne de glace.",
  [50274] = "Butin des boss de fin d'aile de la Citadelle de la Couronne de glace (25 joueurs).",
  -- Cata
  [69848] = "Butin de Ragnaros (Terres de Feu) une fois les 250 Essences fumantes siphonnées.",
  [77952] = "Butin des boss de l'Âme des dragons pendant l'étape « Aiguiser vos crocs ».",
  -- MoP
  [94593] = "Butin des raids de Pandarie pendant l'étape correspondante de la suite d'Irion.",
  [94221] = "Butin du Trône du tonnerre pendant l'étape correspondante de la suite d'Irion.",
  -- SL : monnaies, texte porte par le champ howTo des donnees
}

local function GetHowToObtain(tr)
  return (tr.itemID and HOW_TO_OBTAIN[tr.itemID]) or tr.howTo or nil
end

-- ================================================================
-- PANNEAU DETAIL (colonne droite)
-- ================================================================
local detailFrame

-- ----------------------------------------------------------------
-- 7.1.5.31 : panneau detail en POOL. Avant, chaque rafraichissement
-- (BAG_UPDATE_DELAYED, QUEST_LOG_UPDATE... fenetre ouverte) detachait
-- puis RECREAIT toutes les frames du panneau ; WoW ne libere jamais une
-- frame, la memoire grossissait donc a chaque sac ouvert. Le squelette est
-- maintenant construit une seule fois, les lignes de quetes et de
-- composants sont reutilisees par index, et un refresh ne fait plus que
-- mettre a jour textes, couleurs et positions (meme principe que la liste
-- centrale, MakeListRow / FillListRow).
-- ----------------------------------------------------------------
local D = { qRows = {}, cRows = {} }
local Q_COLOR = {r=0.30, g=0.60, b=1.00}
local C_COLOR = {r=1.00, g=0.82, b=0.00}
local RefreshDetail

local function MakeSeparator(parent)
  local sep = parent:CreateTexture(nil, "ARTWORK")
  sep:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
  sep:SetHeight(14)
  return sep
end

local function MakeFS(parent, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template)
  fs:SetJustifyH("LEFT")
  return fs
end

-- En-tete de section repliable (Quetes / Composants)
local function MakeSectionHeader(color, prefix)
  local h = CreateFrame("Button", nil, detailFrame, "BackdropTemplate")
  h:SetBackdrop(BACKDROP_ROW)
  h:SetBackdropColor(color.r*0.18, color.g*0.18, color.b*0.18, 0.95)
  h:SetBackdropBorderColor(color.r*0.8, color.g*0.8, color.b*0.8, 0.9)
  h.arrow = MakeFS(h, "GameFontNormalSmall")
  h.arrow:SetPoint("LEFT", h, "LEFT", 6, 0)
  h.title = MakeFS(h, "GameFontNormalSmall")
  h.title:SetPoint("LEFT", h, "LEFT", 26, 0)
  h.count = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  h.count:SetPoint("RIGHT", h, "RIGHT", -6, 0)
  h:SetScript("OnClick", function()
    local item = D.item
    if not item then return end
    local key = prefix .. tostring(item.itemID)
    LegTrackerDB.sections[key] = not (LegTrackerDB.sections[key] ~= false)
    RefreshDetail(item)
  end)
  h:SetScript("OnEnter", function(s) s:SetBackdropColor(color.r*0.30, color.g*0.30, color.b*0.30, 1.0) end)
  h:SetScript("OnLeave", function(s) s:SetBackdropColor(color.r*0.18, color.g*0.18, color.b*0.18, 0.95) end)
  return h
end

local function BuildDetailSkeleton()
  if D.built then return end
  D.built = true
  local f = detailFrame

  D.icon = f:CreateTexture(nil, "ARTWORK")
  D.icon:SetSize(40, 40)
  D.name = f:CreateFontString(nil, "OVERLAY")
  D.name:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
  D.name:SetWordWrap(true)
  D.name:SetJustifyH("LEFT")
  D.status = MakeFS(f, "GameFontNormalSmall")
  D.status:SetWordWrap(true)
  D.owner = MakeFS(f, "GameFontNormalSmall")
  D.owner:SetWordWrap(true)
  D.stripe = f:CreateTexture(nil, "ARTWORK")
  D.stripe:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  D.sep1, D.sep2, D.sep3 = MakeSeparator(f), MakeSeparator(f), MakeSeparator(f)
  D.srcHdr = MakeFS(f, "GameFontNormalSmall")
  D.src = MakeFS(f, "GameFontHighlightSmall")
  D.src:SetWordWrap(true)
  D.qHeader = MakeSectionHeader(Q_COLOR, "q_")
  D.qNone = MakeFS(f, "GameFontHighlightSmall")
  D.cHeader = MakeSectionHeader(C_COLOR, "c_")
  D.cNone = MakeFS(f, "GameFontHighlightSmall")
  D.farmHdr = MakeFS(f, "GameFontNormalSmall")
  D.farm = MakeFS(f, "GameFontHighlightSmall")
  D.farm:SetWordWrap(true)
end

-- Ligne de quete (construite une fois, reutilisee)
local function MakeQuestRow()
  local r = CreateFrame("Button", nil, detailFrame, "BackdropTemplate")
  r:SetBackdrop(BACKDROP_ROW)
  r.stripe = r:CreateTexture(nil, "ARTWORK")
  r.stripe:SetPoint("TOPLEFT", r, "TOPLEFT", 2, -2)
  r.stripe:SetSize(4, 48)
  r.stripe:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  r.statusFS = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.statusFS:SetPoint("TOPRIGHT", r, "TOPRIGHT", -5, -4)
  r.nameFS = MakeFS(r, "GameFontNormalSmall")
  r.nameFS:SetPoint("TOPLEFT", r, "TOPLEFT", 12, -4)
  r.nameFS:SetWordWrap(false)
  r.infoFS = MakeFS(r, "GameFontHighlightSmall")
  r.infoFS:SetPoint("TOPLEFT", r, "TOPLEFT", 12, -20)
  r.infoFS:SetWordWrap(false)
  r.hintFS = MakeFS(r, "GameFontHighlightSmall")
  r.hintFS:SetPoint("TOPLEFT", r, "TOPLEFT", 12, -34)

  r:SetScript("OnClick", function(s) if s.q then AddTomTomWaypoint(s.q) end end)
  r:SetScript("OnEnter", function(s)
    local q = s.q
    if not q then return end
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    GameTooltip:AddLine(q.name or T("LEGENDARY_QUEST", "Quete legendaire"), 0.30, 0.60, 1.0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T("NPC_LABEL", "PNJ :") .. " " .. (q.npc or T("UNKNOWN_LOWER", "inconnu")), 0.9, 0.9, 0.7)
    GameTooltip:AddLine(T("ZONE_LABEL", "Zone :") .. " " .. (q.zone or T("UNKNOWN_FEM", "inconnue")), 0.8, 0.8, 0.8)
    if q.x and q.y then
      GameTooltip:AddLine(string.format(T("COORDS_FMT", "Coordonnees : %.1f, %.1f"), q.x, q.y), 0.7, 0.9, 1.0)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T("CLICK_WAYPOINT_HINT", "Clic pour ajouter un waypoint TomTom."), 0.75, 0.75, 0.75, true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return r
end

-- isCurrent : etape en cours de la suite (premiere quete non terminee)
local function FillQuestRow(r, q, W, idx, isCurrent)
  local done = q.id and QuestCompleted(q.id)
  local inLog = isCurrent and IsOnQuest(q.id)
  r.q = q
  r:SetSize(W, 52)
  r:SetBackdropColor(Q_COLOR.r*0.06, Q_COLOR.g*0.06, Q_COLOR.b*0.06, done and 0.4 or 0.85)
  if isCurrent then
    -- Etape en cours : liseré dore, comme la selection de la liste
    r:SetBackdropBorderColor(0.72, 0.60, 0.28, 1.0)
    r.stripe:SetVertexColor(1.00, 0.82, 0.00, 1.0)
  else
    r:SetBackdropBorderColor(Q_COLOR.r*0.4, Q_COLOR.g*0.4, Q_COLOR.b*0.4, done and 0.3 or 0.7)
    r.stripe:SetVertexColor(done and 0.35 or 0.30, done and 0.35 or 0.60, done and 0.35 or 1.00, done and 0.5 or 0.9)
  end
  local tag
  if done then
    tag = COL_GREEN .. T("TAG_DONE", "[Fait]") .. COL_RESET
  elseif inLog then
    tag = COL_GREEN .. T("TAG_IN_LOG", "[Dans le journal]") .. COL_RESET
  elseif isCurrent then
    tag = COL_YELLOW .. T("TAG_CURRENT_STEP", "[Etape en cours]") .. COL_RESET
  else
    tag = "|cFF4D99FF" .. T("TAG_TODO", "[A faire]") .. "|r"
  end
  r.statusFS:SetText(tag)
  r.nameFS:SetWidth(W - 110)
  r.nameFS:SetText((done and COL_GREY or COL_WHITE) .. (idx and (idx .. ". ") or "")
                   .. (q.name or (T("QUEST_HASH", "Quete #") .. tostring(q.id))) .. COL_RESET)
  r.infoFS:SetWidth(W - 14)
  if done then
    r.infoFS:SetText("|cFF555555" .. (q.npc or T("NPC_UNKNOWN", "PNJ inconnu")) .. "  " .. (q.zone or T("ZONE_UNKNOWN", "Zone inconnue")) .. "|r")
  else
    r.infoFS:SetText("|cFF888888" .. T("NPC_LABEL", "PNJ :") .. "|r |cFFCCBB88" .. (q.npc or T("UNKNOWN_LOWER", "inconnu")) .. "|r"
                     .. "  |cFF888888" .. T("ZONE_LABEL", "Zone :") .. "|r |cFF99CCFF" .. (q.zone or T("UNKNOWN_FEM", "inconnue")) .. "|r")
  end
  r.hintFS:SetWidth(W - 14)
  if q.x and q.y then
    r.hintFS:SetText(string.format("|cFF666666%.1f, %.1f - " .. T("WAYPOINT_HINT_SHORT", "Clic: waypoint TomTom") .. "|r", q.x, q.y))
  else
    r.hintFS:SetText("|cFF666666" .. T("WAYPOINT_HINT", "Clic : waypoint TomTom") .. "|r")
  end
end

-- Ligne de composant (objet ou monnaie ; construite une fois, reutilisee)
local function MakeCompRow()
  local r = CreateFrame("Button", nil, detailFrame, "BackdropTemplate")
  r._legOwn = true
  r:SetBackdrop(BACKDROP_ROW)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(22, 22)
  r.icon:SetPoint("TOPLEFT", r, "TOPLEFT", 10, -4)
  r.nameFS = MakeFS(r, "GameFontNormalSmall")
  r.nameFS:SetPoint("TOPLEFT", r, "TOPLEFT", 36, -4)
  r.nameFS:SetWordWrap(false)
  r.cntFS = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.cntFS:SetPoint("TOPRIGHT", r, "TOPRIGHT", -8, -4)
  r.barBg = CreateFrame("Frame", nil, r, "BackdropTemplate")
  r.barBg:SetPoint("TOPLEFT", r, "TOPLEFT", 10, -28)
  r.barBg:SetBackdrop(BACKDROP_ROW)
  r.barBg:SetBackdropColor(0, 0, 0, 0.6)
  r.barBg:SetBackdropBorderColor(0.5, 0.45, 0.25, 0.5)
  r.barFill = r.barBg:CreateTexture(nil, "ARTWORK")
  r.barFill:SetPoint("TOPLEFT", r.barBg, "TOPLEFT", 2, -2)
  r.barFill:SetHeight(4)
  r.barFill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
  r.howFS = MakeFS(r, "GameFontHighlightSmall")
  r.howFS:SetPoint("TOPLEFT", r, "TOPLEFT", 10, -40)
  r.howFS:SetWordWrap(true)
  r.stripe = r:CreateTexture(nil, "ARTWORK")
  r.stripe:SetPoint("TOPLEFT", r, "TOPLEFT", 2, -2)
  r.stripe:SetTexture("Interface\\BUTTONS\\WHITE8X8")

  r:SetScript("OnEnter", function(s)
    local tr = s.tr
    if not tr then return end
    local hasItem = tr.itemID and tr.itemID > 0
    if not (hasItem or tr.currencyID) then return end
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    if tr.currencyID then
      GameTooltip:SetCurrencyByID(tr.currencyID)
    else
      GameTooltip:SetItemByID(tr.itemID)
    end
    local ok = s.ok
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(string.format(T("OWNED_COUNT_FMT", "Possede : %d / %d"), s.count or 0, s.need or 1),
      ok and 0.27 or C_COLOR.r, ok and 1.00 or C_COLOR.g, ok and 0.27 or C_COLOR.b)
    if s.howTo then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(T("HOWTO_HEADER_COLON", "Comment l'obtenir :"), 0.95, 0.78, 0.35)
      GameTooltip:AddLine(s.howTo, 0.8, 0.8, 0.8, true)
    end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return r
end

-- Remplit la ligne, retourne sa hauteur
local function FillCompRow(r, tr, W)
  local count = TrackerCount(tr)
  local need  = tr.need or 1
  local ok    = count >= need
  local pct   = math.min(1.0, count / need)
  local howTo = GetHowToObtain(tr)
  r.tr, r.count, r.need, r.ok, r.howTo = tr, count, need, ok, howTo

  r:SetBackdropColor(C_COLOR.r*0.06, C_COLOR.g*0.06, C_COLOR.b*0.06, ok and 0.4 or 0.85)
  r:SetBackdropBorderColor(C_COLOR.r*0.4, C_COLOR.g*0.4, C_COLOR.b*0.4, ok and 0.3 or 0.7)
  r.icon:SetTexture(GetTrackerIcon(tr))
  r.nameFS:SetWidth(W - 90)
  local fallback = tr.currencyID and ("#" .. tostring(tr.currencyID)) or (T("ITEM_HASH", "Item #") .. tostring(tr.itemID))
  r.nameFS:SetText((ok and COL_GREY or COL_WHITE) .. (tr.name or fallback) .. COL_RESET)
  r.cntFS:SetText((ok and COL_GREEN or COL_YELLOW) .. count .. "/" .. need .. COL_RESET)
  r.barBg:SetSize(W - 24, 8)
  r.barFill:SetWidth(math.max(2, math.floor((W - 28) * pct)))
  r.barFill:SetVertexColor(ok and 0.27 or C_COLOR.r, ok and 1.00 or C_COLOR.g, ok and 0.27 or C_COLOR.b, 1.0)

  -- "Comment obtenir" : hauteur mesuree pour eviter le chevauchement
  local rowH = 50
  if howTo then
    r.howFS:SetWidth(W - 20)
    r.howFS:SetText("|cFF888888 " .. howTo .. "|r")
    r.howFS:Show()
    rowH = math.max(50, 44 + math.ceil(r.howFS:GetStringHeight()) + 6)
  else
    r.howFS:SetText("")
    r.howFS:Hide()
  end
  r:SetSize(W, rowH)
  r.stripe:SetSize(4, rowH - 4)
  r.stripe:SetVertexColor(ok and 0.27 or C_COLOR.r, ok and 1.00 or C_COLOR.g, ok and 0.27 or C_COLOR.b, 0.9)
  return rowH
end

local function PlaceAt(region, x, y)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", detailFrame, "TOPLEFT", x, y)
  region:Show()
end

function RefreshDetail(item)
  if not detailFrame then return end
  if not item then return end
  BuildDetailSkeleton()
  D.item = item

  local W  = detailFrame:GetWidth() - 20
  local y  = -12
  local sc = STATUS_COLORS[item._status] or STATUS_COLORS["MISSING"]

  -- Icone + nom
  PlaceAt(D.icon, 10, y)
  D.icon:SetTexture(GetIcon(item.itemID))
  -- Icone en couleur si obtenu (meme par un autre perso), desature si non equippable et non obtenu
  D.icon:SetDesaturated((not HasClass(item) and item._status ~= "OBTAINED") and true or false)
  PlaceAt(D.name, 56, y)
  D.name:SetWidth(W - 46)
  D.name:SetText(COL_GOLD .. GetItemName(item) .. COL_RESET)
  y = y - 50

  -- Statut
  PlaceAt(D.status, 10, y)
  D.status:SetWidth(W)
  local status = item._status or "MISSING"
  local sLabel
  if status == "OBTAINED" then
    sLabel = COL_GREEN .. T("TAG_OBTAINED", "[Obtenu]") .. COL_RESET
    local via = ViaLabel(item)
    if via then sLabel = sLabel .. " |cFFAAAAAA(" .. via .. ")|r" end
  elseif status == "IN_PROGRESS" then
    sLabel = COL_YELLOW .. T("TAG_IN_PROGRESS", "[En cours]") .. COL_RESET
             .. string.format(" |cFFAAAAAA" .. T("PROGRESS_DETAIL_FMT", "(%d/%d quetes, %d/%d composants)") .. "|r",
                item._qDone or 0, item._qTotal or 0,
                item._tDone or 0, item._tTotal or 0)
  elseif status == "UNAVAILABLE" then
    sLabel = COL_GREY .. T("RESERVED_LABEL", "Reserve : ") .. COL_RESET .. GetClassesText(item)
  else
    sLabel = COL_RED .. T("TAG_NOT_OBTAINED", "[Non obtenu]") .. COL_RESET
  end
  D.status:SetText(sLabel)
  y = y - 22

  -- Qui possede cet item ? (suivi de compte)
  local ownerStr = item.itemID and item.itemID > 0 and GetOwnersText(item.itemID, false) or nil
  if ownerStr then
    PlaceAt(D.owner, 10, y)
    D.owner:SetWidth(W)
    D.owner:SetText(COL_GREEN .. T("OWNED_BY", "Detenu par : ") .. COL_RESET .. ownerStr)
    y = y - 20
  else
    D.owner:Hide()
  end

  -- Bande de statut laterale
  PlaceAt(D.stripe, 4, -12)
  D.stripe:SetSize(4, -(y + 12) - 4)
  D.stripe:SetVertexColor(sc.r, sc.g, sc.b, 0.9)

  PlaceAt(D.sep1, 8, y)
  D.sep1:SetWidth(W + 4)
  y = y - 16

  -- Section source / comment obtenir
  PlaceAt(D.srcHdr, 10, y)
  D.srcHdr:SetText(COL_GOLD .. T("HOWTO_HEADER", "Comment l'obtenir") .. COL_RESET)
  y = y - 18

  PlaceAt(D.src, 10, y)
  D.src:SetWidth(W)
  D.src:SetText("|cFFCCBB88" .. (item.source or T("UNKNOWN", "Inconnu")) .. COL_RESET)
  -- Hauteur reelle mesuree apres rendu (evite le chevauchement des sections)
  y = y - math.max(28, math.ceil(D.src:GetStringHeight()) + 6)

  -- Farm cette semaine (lot C)
  local farm = FarmText(item)
  if farm then
    PlaceAt(D.farmHdr, 10, y)
    D.farmHdr:SetText(COL_GOLD .. T("FARM_HEADER", "Farm cette semaine") .. COL_RESET)
    y = y - 18
    PlaceAt(D.farm, 10, y)
    D.farm:SetWidth(W)
    D.farm:SetText(farm)
    y = y - (math.ceil(D.farm:GetStringHeight()) + 8)
  else
    D.farmHdr:Hide()
    D.farm:Hide()
  end

  PlaceAt(D.sep2, 8, y)
  D.sep2:SetWidth(W + 4)
  y = y - 16

  -- Section quetes
  local qOpen  = LegTrackerDB.sections["q_" .. tostring(item.itemID)] ~= false
  local quests = item.quests or {}
  local qCount = #quests
  PlaceAt(D.qHeader, 10, y)
  D.qHeader:SetSize(W, 24)
  D.qHeader.arrow:SetText(qOpen and "|cFFFFFFFF[-]|r" or "|cFFFFFFFF[+]|r")
  D.qHeader.title:SetText("|cFF4D99FF" .. T("QUESTS_HEADER", "Quetes") .. "|r")
  -- Etape en cours seulement si l'objet n'est pas deja obtenu
  local curStep = (item._status ~= "OBTAINED") and item._step or nil
  if curStep and qCount > 1 then
    D.qHeader.count:SetText(COL_YELLOW .. string.format(T("STEP_FMT", "Etape %d/%d"), curStep, qCount) .. "|r")
  else
    D.qHeader.count:SetText("|cFFAAAAAA" .. qCount .. " " .. (qCount > 1 and T("QUESTS_PLURAL", "quetes") or T("QUEST_SINGULAR", "quete")) .. "|r")
  end
  y = y - 28

  local qUsed = 0
  D.qNone:Hide()
  if qOpen then
    if qCount > 0 then
      for i, q in ipairs(quests) do
        local r = D.qRows[i]
        if not r then r = MakeQuestRow(); D.qRows[i] = r end
        FillQuestRow(r, q, W, qCount > 1 and i or nil, i == curStep)
        PlaceAt(r, 10, y)
        y = y - 56
        qUsed = i
      end
    else
      PlaceAt(D.qNone, 14, y)
      D.qNone:SetText(COL_GREY .. T("NO_QUEST_LISTED", "Aucune quete specifique renseignee.") .. COL_RESET)
      y = y - 20
    end
  end
  for i = qUsed + 1, #D.qRows do D.qRows[i]:Hide() end

  y = y - 8
  PlaceAt(D.sep3, 8, y)
  D.sep3:SetWidth(W + 4)
  y = y - 16

  -- Section composants
  local cOpen    = LegTrackerDB.sections["c_" .. tostring(item.itemID)] ~= false
  local trackers = item.trackers or {}
  local cCount   = #trackers
  PlaceAt(D.cHeader, 10, y)
  D.cHeader:SetSize(W, 24)
  D.cHeader.arrow:SetText(cOpen and "|cFFFFFFFF[-]|r" or "|cFFFFFFFF[+]|r")
  D.cHeader.title:SetText(COL_YELLOW .. T("COMPONENTS_HEADER", "Composants") .. COL_RESET)
  D.cHeader.count:SetText("|cFFAAAAAA" .. cCount .. " " .. (cCount > 1 and T("ITEMS_PLURAL", "items") or T("ITEM_SINGULAR", "item")) .. "|r")
  y = y - 28

  local cUsed = 0
  D.cNone:Hide()
  if cOpen then
    if cCount > 0 then
      for i, tr in ipairs(trackers) do
        local r = D.cRows[i]
        if not r then r = MakeCompRow(); D.cRows[i] = r end
        local rowH = FillCompRow(r, tr, W)
        PlaceAt(r, 10, y)
        y = y - (rowH + 4)
        cUsed = i
      end
    else
      PlaceAt(D.cNone, 14, y)
      D.cNone:SetText(COL_GREY .. T("NO_COMPONENT_LISTED", "Aucun composant a suivre.") .. COL_RESET)
      y = y - 20
    end
  end
  for i = cUsed + 1, #D.cRows do D.cRows[i]:Hide() end

  detailFrame:SetHeight(math.max(300, -(y) + 20))
end

-- ================================================================
-- CONSTRUCTION UI PRINCIPALE (onglets verticaux)
-- ================================================================
local mainFrame, minimapBtn
local RefreshCollection, ApplyViewMode   -- vue Collection (lot C), definies apres BuildUI

-- ================================================================
-- LIGNES DE LISTE REUTILISABLES (pool par index)
-- Le squelette (frame + sous-elements) est construit UNE SEULE fois par
-- ligne ; les rafraichissements ne font que mettre a jour les proprietes.
-- Evite la creation de frames a chaque refresh (fuite memoire / taint).
-- ================================================================
local function MakeListRow(parent)
  local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
  row._legOwn = true   -- l'infobulle globale LegTracker ne s'ajoute pas ici
  row:SetSize(290, 64)
  row:SetBackdrop(BACKDROP_ROW)

  row.stripe = row:CreateTexture(nil, "ARTWORK")
  row.stripe:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)
  row.stripe:SetTexture("Interface\\BUTTONS\\WHITE8X8")

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(34, 34)

  row.nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.nameFS:SetPoint("TOPLEFT", row, "TOPLEFT", 50, -5)
  row.nameFS:SetWidth(234)
  row.nameFS:SetWordWrap(true)
  row.nameFS:SetJustifyH("LEFT")

  row.subFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.subFS:SetPoint("TOPLEFT", row, "TOPLEFT", 50, -22)
  row.subFS:SetWidth(234)
  row.subFS:SetJustifyH("LEFT")

  -- Barre de progression (masquee par defaut, affichee pour les items en cours)
  row.barBg = CreateFrame("Frame", nil, row, "BackdropTemplate")
  row.barBg:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  50, 8)
  row.barBg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 8)
  row.barBg:SetHeight(8)
  row.barBg:SetBackdrop(BACKDROP_ROW)
  row.barBg:SetBackdropColor(0, 0, 0, 0.7)

  row.barFill = row.barBg:CreateTexture(nil, "ARTWORK")
  row.barFill:SetPoint("TOPLEFT", row.barBg, "TOPLEFT", 2, -2)
  row.barFill:SetHeight(4)
  row.barFill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")

  row.pctFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.pctFS:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 7)

  row:SetScript("OnClick", function(s)
    local item = s.item
    if not item then return end
    mainFrame.selectedItem = item
    RefreshDetail(item)
    if mainFrame.listRows then
      for _, r in ipairs(mainFrame.listRows) do
        if r:IsShown() and r._sc then
          r:SetBackdropBorderColor(r._sc.r*0.4, r._sc.g*0.4, r._sc.b*0.4, 0.7)
        end
      end
    end
    s:SetBackdropBorderColor(0.72, 0.60, 0.28, 1.0)
  end)

  row:SetScript("OnEnter", function(s)
    local item = s.item
    s:SetBackdropBorderColor(0.72, 0.60, 0.28, 1.0)
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    if item and item.itemID and item.itemID > 0 then
      GameTooltip:SetItemByID(item.itemID)
    else
      GameTooltip:SetText((item and item.name) or T("TO_COMPLETE", "A completer"))
    end
    if item and s._inProgress then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(T("PROGRESS_HEADER", "Progression :"), 0.95, 0.78, 0.35)
      local qD, qT = item._qDone or 0, item._qTotal or 0
      local tD, tT = item._tDone or 0, item._tTotal or 0
      if qT > 0 then GameTooltip:AddLine(string.format("  " .. T("QUESTS_COUNT_FMT", "Quêtes : %d / %d"), qD, qT), 0.30, 0.60, 1.0) end
      if tT > 0 then GameTooltip:AddLine(string.format("  " .. T("COMPONENTS_COUNT_FMT", "Composants : %d / %d"), tD, tT), 1.0, 0.82, 0.0) end
    end
    if item and s._obtained and item.itemID and item.itemID > 0 then
      local chars = GetCharsWithItem(item.itemID)
      if IsObtainedOnCurrentChar(item.itemID) and PLAYER_NAME then
        local cur = PLAYER_NAME .. " (" .. (PLAYER_REALM or "?") .. ")"
        local found = false
        for _, ch in ipairs(chars) do if ch.display == cur then found = true break end end
        if not found then
          table.insert(chars, { display=cur, name=PLAYER_NAME, realm=PLAYER_REALM or "?", class=PLAYER_CLASS })
        end
      end
      if #chars > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(T("OWNED_BY_HEADER", "Detenu par :"), 0.95, 0.78, 0.35)
        for _, ch in ipairs(chars) do
          local hex = ch.class and CLASS_COLORS[ch.class] or nil
          if hex then
            local r = tonumber(hex:sub(1,2),16)/255
            local g = tonumber(hex:sub(3,4),16)/255
            local b = tonumber(hex:sub(5,6),16)/255
            GameTooltip:AddLine("  " .. ch.display, r, g, b)
          else
            GameTooltip:AddLine("  " .. ch.display, 0.7, 1.0, 0.7)
          end
        end
      end
    end
    GameTooltip:Show()
  end)

  row:SetScript("OnLeave", function(s)
    GameTooltip:Hide()
    local dispSc = s._dispSc
    if dispSc then
      s:SetBackdropBorderColor(dispSc.r*0.4, dispSc.g*0.4, dispSc.b*0.4, s._obtained and 0.3 or 0.7)
    end
  end)

  return row
end

-- Met a jour une ligne existante pour representer 'item' (aucune allocation)
-- rowW : largeur cible (permet l'etirement lors d'un redimensionnement)
local function FillListRow(row, item, rowW)
  rowW = rowW or 290
  local equippable = HasClass(item)
  local status     = item._status or "MISSING"
  local sc         = STATUS_COLORS[status] or STATUS_COLORS["MISSING"]
  local obtained   = status == "OBTAINED"
  local inProgress = status == "IN_PROGRESS"
  local dispSc     = obtained and STATUS_COLORS["OBTAINED"] or sc
  local rowH       = (inProgress and equippable) and 82 or 64

  row.item        = item
  row._sc         = dispSc
  row._dispSc     = dispSc
  row._obtained   = obtained
  row._inProgress = inProgress

  row:SetSize(rowW, rowH)
  row.nameFS:SetWidth(rowW - 56)
  row.subFS:SetWidth(rowW - 56)
  row:SetBackdropColor(dispSc.r*0.06, dispSc.g*0.06, dispSc.b*0.06, obtained and 0.4 or 0.85)
  row:SetBackdropBorderColor(dispSc.r*0.4, dispSc.g*0.4, dispSc.b*0.4, obtained and 0.3 or 0.7)

  row.stripe:SetSize(4, rowH - 4)
  if obtained then
    row.stripe:SetVertexColor(0.27, 1.00, 0.27, 0.9)
  else
    row.stripe:SetVertexColor(sc.r, sc.g, sc.b, 0.9)
  end

  row.icon:ClearAllPoints()
  row.icon:SetPoint("LEFT", 10, inProgress and 6 or 0)
  row.icon:SetTexture(GetIcon(item.itemID))
  row.icon:SetDesaturated((not obtained and not equippable) and true or false)

  local nameCol = obtained and COL_GREEN or (equippable and COL_WHITE or COL_GREY)
  local prefix  = obtained and (COL_GREEN .. "* " .. COL_RESET) or ""
  row.nameFS:SetText(prefix .. nameCol .. GetItemName(item) .. COL_RESET)

  -- Par defaut : barre masquee, pourcentage vide
  row.barBg:Hide()
  row.pctFS:SetText("")

  if item.placeholder then
    row.subFS:SetText(COL_GREY .. T("TO_COMPLETE", "A completer") .. COL_RESET)
  elseif obtained then
    local ownerStr = item.itemID and item.itemID > 0 and GetOwnersText(item.itemID, true) or nil
    if ownerStr then
      row.subFS:SetText(COL_GREEN .. T("TAG_OBTAINED", "[Obtenu]") .. COL_RESET .. "  " .. ownerStr)
    else
      local via = ViaLabel(item)
      row.subFS:SetText(COL_GREEN .. T("TAG_OBTAINED", "[Obtenu]") .. COL_RESET
                        .. (via and ("  |cFFAAAAAA" .. via .. "|r") or ""))
    end
  elseif not equippable then
    row.subFS:SetText(GetClassesText(item))
  elseif inProgress then
    local qD, qT = item._qDone or 0, item._qTotal or 0
    local tD, tT = item._tDone or 0, item._tTotal or 0
    local parts = {}
    if qT > 0 then table.insert(parts, string.format("|cFF4D99FF" .. T("QUESTS_SHORT_FMT", "Quêtes %d/%d") .. "|r", qD, qT)) end
    if tT > 0 then table.insert(parts, string.format("|cFFFFCC00" .. T("COMPONENTS_SHORT_FMT", "Compos. %d/%d") .. "|r", tD, tT)) end
    row.subFS:SetText(COL_YELLOW .. T("TAG_IN_PROGRESS_SP", "[En cours] ") .. COL_RESET
                      .. (#parts > 0 and table.concat(parts, "  ") or ""))

    local totalDone  = (item._qDone or 0) + (item._tDone or 0)
    local totalTotal = (item._qTotal or 0) + (item._tTotal or 0)
    local pct = (totalTotal > 0) and math.min(1.0, totalDone / totalTotal) or 0

    row.barBg:SetBackdropBorderColor(sc.r*0.4, sc.g*0.4, sc.b*0.4, 0.6)
    row.barFill:SetWidth(math.max(2, math.floor((rowW - 66) * pct)))
    row.barFill:SetVertexColor(sc.r, sc.g, sc.b, 1.0)
    row.barBg:Show()

    row.pctFS:SetText(string.format("|cFFFFCC00%d%%|r", math.floor(pct * 100)))
  else
    row.subFS:SetText(COL_RED .. T("TAG_NOT_OBTAINED", "[Non obtenu]") .. COL_RESET)
  end
end

local function BuildUI()

  local TAB_COL_W = 100
  local TAB_H     = 28
  local TAB_GAP   = 2
  local FRAME_W   = 750
  local FRAME_H   = 700

  mainFrame = CreateFrame("Frame", "LegTrackerMainFrame", UIParent, "BackdropTemplate")
  mainFrame:SetSize(FRAME_W, FRAME_H)
  mainFrame:SetBackdrop(BACKDROP_MAIN)
  mainFrame:SetBackdropColor(0.04, 0.02, 0.06, 0.97)
  mainFrame:SetBackdropBorderColor(0.72, 0.60, 0.28, 1.0)
  mainFrame:SetFrameStrata("HIGH")
  mainFrame:SetMovable(true)
  mainFrame:SetResizable(true)
  mainFrame:EnableMouse(true)
  mainFrame:RegisterForDrag("LeftButton")
  mainFrame:SetScript("OnDragStart", function(s)
    if not (LegTrackerDB and LegTrackerDB.locked) then s:StartMoving() end
  end)
  mainFrame:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local _, _, _, x, y = s:GetPoint()
    LegTrackerDB.pos = {x=x, y=y}
  end)

  -- Bornes de redimensionnement (API moderne avec repli)
  if mainFrame.SetResizeBounds then
    mainFrame:SetResizeBounds(680, 440, 1400, 1100)
  elseif mainFrame.SetMinResize then
    mainFrame:SetMinResize(680, 440)
    mainFrame:SetMaxResize(1400, 1100)
  end
  mainFrame.defaultW = FRAME_W
  mainFrame.defaultH = FRAME_H
  -- Fermeture par Echap via UISpecialFrames (mecanisme natif Blizzard) : voir
  -- note detaillee dans TibiSuiteCore.lua (WireEscapeFor) - piege reel
  -- confirme en jeu quand un autre addon intercepte lui aussi Echap. AUCUN
  -- OnHide/OnKeyDown ne doit etre accroche a cette fenetre desormais (c'est
  -- exactement la combinaison qui causait le tout premier blocage trouve
  -- ici) : LegTrackerDB.open n'est donc plus resynchronise sur une fermeture
  -- par Echap (repli assume, cf. Toggle/slash qui restent, eux, corrects).
  tinsert(UISpecialFrames, "LegTrackerMainFrame")
  -- Redimensionnement manuel desactive : la fenetre s'adapte au contenu

  -- Titre
  local titleBg = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
  titleBg:SetPoint("TOP", mainFrame, "TOP", 0, 14)
  titleBg:SetSize(440, 44)
  titleBg:SetFrameLevel(mainFrame:GetFrameLevel() + 2)
  titleBg:SetBackdrop(BACKDROP_TITLE)
  titleBg:SetBackdropColor(0.04, 0.02, 0.06, 0.97)
  titleBg:SetBackdropBorderColor(0.72, 0.60, 0.28, 1.0)

  local logoLeft = titleBg:CreateTexture(nil, "OVERLAY")
  logoLeft:SetSize(20, 20)
  logoLeft:SetTexture("Interface\\AddOns\\LegTracker\\medias\\LegTracker")
  local logoRight = titleBg:CreateTexture(nil, "OVERLAY")
  logoRight:SetSize(20, 20)
  logoRight:SetTexture("Interface\\AddOns\\LegTracker\\medias\\LegTracker")

  local titleStr = titleBg:CreateFontString(nil, "OVERLAY")
  titleStr:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
  titleStr:SetPoint("CENTER", titleBg, "CENTER", 0, 5)
  titleStr:SetText(COL_GOLD .. "Leg Tracker - " .. COL_RESET .. COL_PURPLE .. "Midnight" .. COL_RESET)
  logoLeft:SetPoint("RIGHT",  titleStr, "LEFT",  -6, 0)
  logoRight:SetPoint("LEFT",  titleStr, "RIGHT",  6, 0)

  local byLine = titleBg:CreateFontString(nil, "OVERLAY")
  byLine:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
  byLine:SetPoint("TOP", titleStr, "BOTTOM", 0, 0)
  byLine:SetText(COL_PINK .. "by Tibiscui" .. COL_RESET)

  -- TibiSuite : en-tête comme WeeklyCompass (titre à l'intérieur, haut-gauche)
  logoLeft:Hide(); logoRight:Hide()
  byLine:Hide()
  titleBg:Hide()
  titleStr:SetParent(mainFrame)
  titleStr:SetFontObject("GameFontNormalLarge")
  titleStr:ClearAllPoints()
  titleStr:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 16, -14)
  titleStr:SetText("|cFFFF6D0BLegTracker|r")

  local collBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  collBtn:SetSize(96, 20)
  collBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -38, -10)
  collBtn:SetText(T("COLL_BTN", "Collection"))
  collBtn:SetScript("OnClick", function()
    mainFrame.collMode = not mainFrame.collMode
    ApplyViewMode()
    mainFrame:RefreshContent()
  end)
  mainFrame.collBtn = collBtn

  local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -5, -5)
  closeBtn:SetScript("OnClick", function()
    mainFrame:Hide() ; LegTrackerDB.open = false
  end)

  local dragHint = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  dragHint:SetPoint("TOP", 0, -30)
  dragHint:SetText("|cFF888888" .. T("DRAG_HINT", "Glisser pour deplacer  -  /lt") .. "|r")

  -- Separateur haut : PLEINE LARGEUR (de bord a bord de la fenetre)
  local sepTop = mainFrame:CreateTexture(nil, "ARTWORK")
  sepTop:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepTop:SetPoint("TOPLEFT",  12, -45)
  sepTop:SetPoint("TOPRIGHT", -12, -45)
  sepTop:SetHeight(1)
  sepTop:SetVertexColor(0.72, 0.60, 0.28, 0.9)

  -- Colonne gauche : fond, commence sous le separateur haut
  local tabColBg = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
  tabColBg:SetPoint("TOPLEFT",    12, -48)
  tabColBg:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 12, 14)
  tabColBg:SetWidth(TAB_COL_W)
  tabColBg:SetBackdrop(BACKDROP_ROW)
  tabColBg:SetBackdropColor(0.02, 0.01, 0.04, 0.85)
  tabColBg:SetBackdropBorderColor(0.72, 0.60, 0.28, 0.35)

  local extBtns      = {}
  local extTabStartY = -4   -- onglets ancres dans tabColBg directement

  local function BuildExtTab(extKey, yOff)
    local col      = EXT_TAB_COLORS[extKey]  or {r=0.5,g=0.5,b=0.5}
    local lbl      = EXT_LABELS[extKey]      or extKey
    local fullName = EXT_FULLNAMES[extKey]   or extKey

    -- Onglets ancres dans tabColBg (pas mainFrame) => alignement garanti
    local eb = CreateFrame("Button", nil, tabColBg, "BackdropTemplate")
    eb:SetPoint("TOPLEFT", tabColBg, "TOPLEFT", 3, yOff)
    eb:SetSize(TAB_COL_W - 6, TAB_H)
    eb:SetBackdrop(BACKDROP_BTN)
    eb:SetBackdropColor(col.r*0.12, col.g*0.12, col.b*0.12, 0.95)
    eb:SetBackdropBorderColor(col.r*0.35, col.g*0.35, col.b*0.35, 0.5)

    -- Barre d'accent gauche
    local accent = eb:CreateTexture(nil, "OVERLAY")
    accent:SetPoint("TOPLEFT",    eb, "TOPLEFT",    2, -2)
    accent:SetPoint("BOTTOMLEFT", eb, "BOTTOMLEFT", 2,  2)
    accent:SetWidth(3)
    accent:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    accent:SetVertexColor(col.r, col.g, col.b, 0.6)

    -- Sigle texte (gauche)
    local eTxt = eb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    eTxt:SetPoint("LEFT", eb, "LEFT", 8, 0)
    eTxt:SetText(string.format("|cFF%02X%02X%02X%s|r",
      math.floor(col.r*255), math.floor(col.g*255), math.floor(col.b*255), lbl))
    eTxt:SetWordWrap(false)
    eTxt:SetJustifyH("LEFT")

    -- Compteur X/total (droite) : orange si > 0, gris si 0
    local cntLbl = eb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cntLbl:SetPoint("RIGHT", eb, "RIGHT", -6, 0)
    cntLbl:SetJustifyH("RIGHT")
    cntLbl:SetText("")
    eb.cntLbl = cntLbl

    eb.accent  = accent
    eb.extKey  = extKey
    eb.col     = col

    eb:SetScript("OnClick", function()
      local exts = (LegTrackerData and LegTrackerData.Extensions) or {}
      for i, extD in ipairs(exts) do
        if extD.key == extKey then
          LegTrackerDB.selectedExtension = i
          break
        end
      end
      if mainFrame.collMode then mainFrame.collMode = false ; ApplyViewMode() end
      mainFrame:RefreshContent()
    end)
    eb:SetScript("OnEnter", function(s)
      s:SetBackdropBorderColor(col.r, col.g, col.b, 1.0)
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
      GameTooltip:AddLine(fullName, col.r, col.g, col.b)
      GameTooltip:AddLine(T("EXT_TAB_TOOLTIP", "Legendaires de l'extension"), 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)
    eb:SetScript("OnLeave", function(s)
      GameTooltip:Hide()
      s:SetBackdropBorderColor(col.r*0.35, col.g*0.35, col.b*0.35, 0.5)
    end)

    table.insert(extBtns, eb)
    return eb
  end

  -- Construction des onglets : modernes (MID en haut) puis classiques (VAN en bas)
  local yPos = extTabStartY
  for _, extKey in ipairs(EXT_ROW1) do
    BuildExtTab(extKey, yPos)
    yPos = yPos - (TAB_H + TAB_GAP)
  end

  -- Separateur dore entre modernes et classiques (ancre dans tabColBg comme les onglets)
  local sepDiv = tabColBg:CreateTexture(nil, "OVERLAY")
  sepDiv:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepDiv:SetPoint("TOPLEFT",  tabColBg, "TOPLEFT",  3, yPos - 2)
  sepDiv:SetPoint("TOPRIGHT", tabColBg, "TOPRIGHT", -3, yPos - 2)
  sepDiv:SetHeight(2)
  sepDiv:SetVertexColor(0.72, 0.60, 0.28, 0.8)

  yPos = yPos - 6
  for _, extKey in ipairs(EXT_ROW2) do
    BuildExtTab(extKey, yPos)
    yPos = yPos - (TAB_H + TAB_GAP)
  end

  mainFrame.extBtns = extBtns

  -- Separateur vertical (entre colonne onglets et contenu)
  local sepVert = mainFrame:CreateTexture(nil, "ARTWORK")
  sepVert:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepVert:SetPoint("TOPLEFT",    tabColBg, "TOPRIGHT",    1, 0)
  sepVert:SetPoint("BOTTOMLEFT", tabColBg, "BOTTOMRIGHT", 1, 0)
  sepVert:SetWidth(1)
  sepVert:SetVertexColor(0.72, 0.60, 0.28, 0.55)

  mainFrame.headerText = mainFrame:CreateFontString(nil, "OVERLAY")
  mainFrame.headerText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
  mainFrame.headerText:SetPoint("TOPLEFT", tabColBg, "TOPRIGHT", 8, -2)
  mainFrame.headerText:SetText(COL_GOLD .. T("SELECT_EXT", "Selectionnez une extension") .. COL_RESET)

  mainFrame.tabColBg = tabColBg
  local legend = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mainFrame.legend = legend
  legend:SetPoint("TOPLEFT", tabColBg, "TOPRIGHT", 8, -18)
  legend:SetText(
    COL_GREEN  .. "  " .. T("LEGEND_OBTAINED", "Obtenu") .. "  " .. COL_RESET ..
    COL_YELLOW .. "  " .. T("LEGEND_IN_PROGRESS", "En cours") .. "  " .. COL_RESET ..
    COL_RED    .. "  " .. T("LEGEND_NOT_OBTAINED", "Non obtenu") .. "  " .. COL_RESET ..
    COL_GREY   .. "  " .. T("LEGEND_UNAVAILABLE", "Non dispo") .. COL_RESET
  )

  -- Zone centrale scrollable (commence sous headerText + legend)
  local rightW = 280
  local listBg = CreateFrame("Frame", nil, mainFrame)
  mainFrame.listBg = listBg
  listBg:SetPoint("TOPLEFT",  tabColBg, "TOPRIGHT",     8,   -34)
  listBg:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT",    -(rightW + 20), -48)
  listBg:SetPoint("BOTTOM",   mainFrame, "BOTTOM",       0, 22)

  local listScroll = CreateFrame("ScrollFrame", "TibiLegListScroll", listBg, "UIPanelScrollFrameTemplate")
  listScroll:SetPoint("TOPLEFT",     listBg, "TOPLEFT",     5,  -5)
  listScroll:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -22, 5)
  mainFrame.listScroll = listScroll

  mainFrame.listContent = CreateFrame("Frame", nil, listScroll)
  mainFrame.listContent:SetWidth(300)
  listScroll:SetScrollChild(mainFrame.listContent)

  -- Message affiche quand les filtres masquent tout
  mainFrame.emptyFS = mainFrame.listContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mainFrame.emptyFS:SetPoint("TOPLEFT", 6, -10)
  mainFrame.emptyFS:SetWidth(260)
  mainFrame.emptyFS:SetJustifyH("LEFT")
  mainFrame.emptyFS:Hide()

  -- Panneau detail (colonne droite)
  detailFrame = CreateFrame("Frame", "TibiLegDetailFrame", nil, "BackdropTemplate")
  detailFrame:SetBackdrop(BACKDROP_ROW)
  detailFrame:SetBackdropColor(0.02, 0.01, 0.04, 0.88)
  detailFrame:SetBackdropBorderColor(0.5, 0.45, 0.25, 0.6)

  local detailScrollBg = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
  mainFrame.detailScrollBg = detailScrollBg
  detailScrollBg:SetPoint("TOPLEFT",     mainFrame, "TOPRIGHT",     -(rightW + 16), -48)
  detailScrollBg:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT",  -12,             22)
  detailScrollBg:SetBackdrop(BACKDROP_ROW)
  detailScrollBg:SetBackdropColor(0.02, 0.01, 0.04, 0.88)
  detailScrollBg:SetBackdropBorderColor(0.5, 0.45, 0.25, 0.6)

  local detailScroll = CreateFrame("ScrollFrame", "TibiLegDetailScroll", detailScrollBg, "UIPanelScrollFrameTemplate")
  detailScroll:SetPoint("TOPLEFT",     detailScrollBg, "TOPLEFT",     5,  -5)
  detailScroll:SetPoint("BOTTOMRIGHT", detailScrollBg, "BOTTOMRIGHT", -22, 5)

  detailFrame:SetWidth(rightW - 16)
  detailScroll:SetScrollChild(detailFrame)

  -- ================================================================
  -- APPLICATION DES OPTIONS (echelle, opacite, minimap, verrou)
  -- ================================================================
  function mainFrame:ApplyOptions()
    local db = LegTrackerDB
    if not db then return end
    self:SetScale(db.scale or 1.0)
    self:SetBackdropColor(0.04, 0.02, 0.06, db.alpha or 0.97)
    if minimapBtn then
      if db.showMinimap == false then minimapBtn:Hide() else minimapBtn:Show() end
    end
    if self.resizeBtn then
      if db.locked then self.resizeBtn:Hide() else self.resizeBtn:Show() end
    end
  end

  -- ================================================================
  -- POIGNEE DE REDIMENSIONNEMENT (bas droite)
  -- ================================================================
  local resizeBtn = CreateFrame("Button", nil, mainFrame)
  resizeBtn:SetSize(16, 16)
  resizeBtn:SetPoint("BOTTOMRIGHT", -6, 7)
  resizeBtn:SetFrameLevel(mainFrame:GetFrameLevel() + 5)
  resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  resizeBtn:SetScript("OnMouseDown", function()
    if not (LegTrackerDB and LegTrackerDB.locked) then mainFrame:StartSizing("BOTTOMRIGHT") end
  end)
  resizeBtn:SetScript("OnMouseUp", function()
    mainFrame:StopMovingOrSizing()
    LegTrackerDB.width  = math.floor(mainFrame:GetWidth())
    LegTrackerDB.height = math.floor(mainFrame:GetHeight())
    mainFrame:RefreshContent()
  end)
  resizeBtn:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
    GameTooltip:AddLine(T("RESIZE_HINT", "Etirer la fenetre"), 0.95, 0.78, 0.35)
    GameTooltip:Show()
  end)
  resizeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  mainFrame.resizeBtn = resizeBtn

  -- ================================================================
  -- Bouton Options : voir le bouton texte "Options" ajoute par le socle
  -- (UI.AddHeaderControls, cf. LegTracker_Module.lua / LegTracker_Suite.lua)
  -- au-dessus de la fenetre - meme convention que les autres modules de la
  -- suite. L'ancienne roue crantee dediee a ete retiree pour ne garder
  -- qu'un seul point d'entree Options ; le panneau riche ci-dessous a ete
  -- migre integralement dans LegTracker_Suite.lua (BuildOptions), ouvert
  -- par ce meme bouton du socle via LegTracker_OpenOptions().
  -- ================================================================

  -- ================================================================
  -- CASE "MASQUER OBTENUS" toujours visible (acces rapide)
  -- ================================================================
  local hideObtLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mainFrame.hideObtLabel = hideObtLabel
  hideObtLabel:SetText("|cFFDDDDDD" .. T("HIDE_OBTAINED_LABEL", "Masquer obtenus") .. "|r")
  hideObtLabel:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -(rightW + 26), -50)

  local hideObtCheck = CreateFrame("CheckButton", nil, mainFrame, "UICheckButtonTemplate")
  hideObtCheck:SetSize(22, 22)
  hideObtCheck:SetPoint("LEFT", hideObtLabel, "RIGHT", 2, 0)
  hideObtCheck:SetScript("OnClick", function(s)
    LegTrackerDB.filters = LegTrackerDB.filters or {}
    LegTrackerDB.filters.hideObtained = s:GetChecked() and true or false
    mainFrame:RefreshContent()
    if mainFrame.optHideObtained then
      mainFrame.optHideObtained:SetChecked(LegTrackerDB.filters.hideObtained)
    end
  end)
  hideObtCheck:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
    GameTooltip:AddLine(T("HIDE_OBTAINED_TT", "Masquer / afficher les objets deja obtenus"), 0.9, 0.9, 0.9)
    GameTooltip:Show()
  end)
  hideObtCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
  mainFrame.hideObtainedCheck = hideObtCheck

  -- ================================================================
  -- RAFRAICHISSEMENT PRINCIPAL
  -- ================================================================
  function mainFrame:RefreshContent()
    ScanAll()

    local exts   = (LegTrackerData and LegTrackerData.Extensions) or {}
    local selIdx = LegTrackerDB.selectedExtension or 1
    local ext    = exts[selIdx] or exts[1]

    -- Mise a jour des onglets
    for _, btn in ipairs(self.extBtns) do
      local bKey    = btn.extKey
      local c       = btn.col
      local isActive = (ext and ext.key == bKey)

      if isActive then
        btn:SetBackdropColor(c.r*0.35, c.g*0.35, c.b*0.35, 1.0)
        btn:SetBackdropBorderColor(c.r, c.g, c.b, 1.0)
        btn.accent:SetVertexColor(c.r, c.g, c.b, 1.0)
      else
        btn:SetBackdropColor(c.r*0.12, c.g*0.12, c.b*0.12, 0.95)
        btn:SetBackdropBorderColor(c.r*0.35, c.g*0.35, c.b*0.35, 0.5)
        btn.accent:SetVertexColor(c.r, c.g, c.b, 0.4)
      end

      for _, extD in ipairs(exts) do
        if extD.key == bKey then
          local g, t, ip = CountExtension(extD)
          if btn.cntLbl then
            local col2
            if g == t and t > 0 then
              col2 = COL_GREEN      -- vert = tout obtenu
            elseif g > 0 then
              col2 = "|cFFFF8800"   -- orange = certains obtenus
            else
              col2 = "|cFFAAAAAA"   -- gris = rien
            end
            btn.cntLbl:SetText(col2 .. g .. "/" .. t .. "|r")
          end
          break
        end
      end
    end

    if not ext then return end

    local got, total, inProg = CountExtension(ext)
    local c = EXT_TAB_COLORS[ext.key] or {r=1, g=0.5, b=0}
    self.headerText:SetText(
      string.format("|cFF%02X%02X%02X%s|r  |cFFAAAAAA(%d/%d obtenus)|r",
        math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255), ext.label, got, total)
    )

    -- Applique les filtres d'affichage (options)
    local items = {}
    for _, it in ipairs(ext.items or {}) do
      if ItemPassesFilter(it) then items[#items + 1] = it end
    end

    -- Largeur cible des lignes : s'etire avec la fenetre (redimensionnement)
    local vw = self.listScroll and self.listScroll:GetWidth() or 300
    if not vw or vw < 120 then vw = 300 end
    local rowW = math.floor(vw - 4)
    self.listContent:SetWidth(vw)

    -- Pool par index : on reutilise les lignes existantes au lieu d'en creer
    -- de nouvelles a chaque rafraichissement.
    self.listRows = self.listRows or {}
    local y = 0
    local firstItem = nil

    for idx, item in ipairs(items) do
      local row = self.listRows[idx]
      if not row then
        row = MakeListRow(self.listContent)
        self.listRows[idx] = row
      end
      FillListRow(row, item, rowW)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, -y)
      row:Show()
      y = y + row:GetHeight() + 4
      if idx == 1 then firstItem = item end
    end

    -- Masque les lignes en trop (extension plus courte ou items filtres)
    for i = #items + 1, #self.listRows do
      self.listRows[i]:Hide()
    end

    -- Message si tout est masque par les filtres
    if self.emptyFS then
      if #items == 0 then
        self.emptyFS:SetText(COL_GREY .. T("NO_ITEM_WITH_FILTERS", "Aucun objet a afficher avec les filtres actuels.") .. COL_RESET)
        self.emptyFS:Show()
      else
        self.emptyFS:Hide()
      end
    end

    -- Synchronise la case "Masquer obtenus" toujours visible
    if self.hideObtainedCheck then
      self.hideObtainedCheck:SetChecked((LegTrackerDB.filters or {}).hideObtained and true or false)
    end

    self.listContent:SetHeight(math.max(300, y + 10))

    -- Restaure la selection precedente si l'item existe toujours dans cette
    -- extension, sinon affiche le premier item. Evite que le panneau detail
    -- ne "saute" vers le premier item a chaque rafraichissement (bag update...).
    local toShow = firstItem
    if self.selectedItem then
      for _, it in ipairs(items) do
        if it == self.selectedItem then toShow = it break end
      end
    end
    self.selectedItem = toShow
    if toShow then
      RefreshDetail(toShow)
      -- Surbrillance doree de la ligne selectionnee
      for idx, it in ipairs(items) do
        local row = self.listRows[idx]
        if row and it == toShow then
          row:SetBackdropBorderColor(0.72, 0.60, 0.28, 1.0)
        end
      end
    end
    if self.collMode then RefreshCollection() end
  end

  mainFrame:Hide()
end

-- ================================================================
-- VUE COLLECTION (lot C) : tous les legendaires du compte en une grille,
-- une colonne par personnage scanne (les 7 qui en detiennent le plus, le
-- personnage actuel en premier) + une colonne "Compte" (tour de force,
-- apparence). En tete : taux de collection et raids de farm encore libres
-- cette semaine. Clic sur une ligne : retour a la liste sur cet objet.
-- Construite a la premiere ouverture, lignes en pool.
-- ================================================================
local COLL_NAME_W, COLL_COL_W, COLL_MAX_CHARS, COLL_ROW_H, COLL_ACCT_W = 190, 46, 7, 20, 80
local READY_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready"
local collFrame

local function KnownChars()
  local list = {}
  for realm, chars in pairs((LegTrackerDB and LegTrackerDB.accountData) or {}) do
    for name, items in pairs(chars) do
      local n = 0
      for k, v in pairs(items) do if type(k) == "number" and v then n = n + 1 end end
      list[#list + 1] = { name = name, realm = realm, class = items._class, items = items, count = n,
                          current = (name == PLAYER_NAME and realm == PLAYER_REALM) }
    end
  end
  table.sort(list, function(a, b)
    if a.current ~= b.current then return a.current end
    if a.count ~= b.count then return a.count > b.count end
    return a.name < b.name
  end)
  return list
end

local function MakeCollRow(parent)
  local r = CreateFrame("Button", nil, parent)
  r._legOwn = true
  r:SetHeight(COLL_ROW_H)
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.bg:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.name:SetPoint("LEFT", r, "LEFT", 4, 0)
  r.name:SetWidth(COLL_NAME_W - 8)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r.cells = {}
  for i = 1, COLL_MAX_CHARS do
    local t = r:CreateTexture(nil, "OVERLAY")
    t:SetSize(14, 14)
    t:SetPoint("CENTER", r, "LEFT", COLL_NAME_W + (i - 1) * COLL_COL_W + COLL_COL_W / 2, 0)
    t:SetTexture(READY_TEX)
    r.cells[i] = t
  end
  r.acct = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.acct:SetPoint("LEFT", r, "LEFT", COLL_NAME_W + COLL_MAX_CHARS * COLL_COL_W + 4, 0)
  r.acct:SetWidth(COLL_ACCT_W)
  r.acct:SetJustifyH("LEFT")
  r.acct:SetWordWrap(false)
  r:SetScript("OnClick", function(s)
    if not s.item then return end
    LegTrackerDB.selectedExtension = s.extIdx
    mainFrame.selectedItem = s.item
    mainFrame.collMode = false
    ApplyViewMode()
    mainFrame:RefreshContent()
  end)
  r:SetScript("OnEnter", function(s)
    if not s.item then return end
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    if s.item.itemID and s.item.itemID > 0 then GameTooltip:SetItemByID(s.item.itemID) else GameTooltip:SetText(s.item.name or "?") end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return r
end

local function BuildCollection()
  if collFrame then return end
  collFrame = CreateFrame("Frame", nil, mainFrame)
  collFrame:SetPoint("TOPLEFT", mainFrame.tabColBg, "TOPRIGHT", 8, -2)
  collFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -12, 22)
  collFrame:Hide()

  collFrame.title = collFrame:CreateFontString(nil, "OVERLAY")
  collFrame.title:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
  collFrame.title:SetPoint("TOPLEFT", collFrame, "TOPLEFT", 0, 0)
  collFrame.summary = collFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  collFrame.summary:SetPoint("TOPLEFT", collFrame, "TOPLEFT", 0, -18)
  collFrame.summary:SetJustifyH("LEFT")
  collFrame.farm = collFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  collFrame.farm:SetPoint("TOPLEFT", collFrame, "TOPLEFT", 0, -34)
  collFrame.farm:SetPoint("TOPRIGHT", collFrame, "TOPRIGHT", -24, -34)
  collFrame.farm:SetJustifyH("LEFT")
  collFrame.farm:SetWordWrap(true)

  local header = CreateFrame("Frame", nil, collFrame)
  header:SetHeight(18)
  header:SetPoint("TOPLEFT", collFrame.farm, "BOTTOMLEFT", 0, -8)
  header:SetPoint("RIGHT", collFrame, "RIGHT", -24, 0)
  header.cols = {}
  for i = 1, COLL_MAX_CHARS do
    local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", header, "LEFT", COLL_NAME_W + (i - 1) * COLL_COL_W, 0)
    fs:SetWidth(COLL_COL_W - 2)
    fs:SetWordWrap(false)
    header.cols[i] = fs
  end
  header.acct = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  header.acct:SetPoint("LEFT", header, "LEFT", COLL_NAME_W + COLL_MAX_CHARS * COLL_COL_W + 4, 0)
  local line = header:CreateTexture(nil, "ARTWORK")
  line:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, -2)
  line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, -2)
  line:SetHeight(1)
  line:SetVertexColor(0.72, 0.60, 0.28, 0.6)
  collFrame.header = header

  local scroll = CreateFrame("ScrollFrame", nil, collFrame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
  scroll:SetPoint("BOTTOMRIGHT", collFrame, "BOTTOMRIGHT", -22, 0)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetWidth(COLL_NAME_W + COLL_MAX_CHARS * COLL_COL_W + COLL_ACCT_W)
  content:SetHeight(100)
  scroll:SetScrollChild(content)
  collFrame.content = content
  collFrame.rows = {}
end

function RefreshCollection()
  if not (collFrame and collFrame:IsShown()) then return end
  local exts  = (LegTrackerData and LegTrackerData.Extensions) or {}
  local chars = KnownChars()

  for i = 1, COLL_MAX_CHARS do
    local fs, c = collFrame.header.cols[i], chars[i]
    if c then
      fs:SetText("|cFF" .. (CLASS_COLORS[c.class] or "AAAAAA") .. c.name .. "|r")
      fs:Show()
    else
      fs:Hide()
    end
  end
  collFrame.header.acct:SetText(COL_GOLD .. T("COLL_ACCOUNT", "Compte") .. COL_RESET)

  local rows, idx, y = collFrame.rows, 0, 0
  local got, total = 0, 0
  local freeRaids, seenRaid, farmCandidates = {}, {}, 0
  local function nextRow()
    idx = idx + 1
    local r = rows[idx]
    if not r then r = MakeCollRow(collFrame.content) ; rows[idx] = r end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", collFrame.content, "TOPLEFT", 0, -y)
    r:SetPoint("RIGHT", collFrame.content, "RIGHT", 0, 0)
    r:Show()
    y = y + COLL_ROW_H
    return r
  end

  for extIdx, ext in ipairs(exts) do
    local list = {}
    for _, it in ipairs(ext.items or {}) do if not it.placeholder then list[#list + 1] = it end end
    if #list > 0 then
      local c = EXT_TAB_COLORS[ext.key] or {r=0.5, g=0.5, b=0.5}
      local h = nextRow()
      h.item = nil
      h.bg:SetVertexColor(c.r, c.g, c.b, 0.22)
      h.name:SetText(string.format("|cFF%02X%02X%02X%s|r", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255), ext.label))
      for i = 1, COLL_MAX_CHARS do h.cells[i]:Hide() end
      h.acct:SetText("")
      for n, it in ipairs(list) do
        local obtained = it._status == "OBTAINED"
        total = total + 1
        if obtained then got = got + 1 end
        local r = nextRow()
        r.item, r.extIdx = it, extIdx
        r.bg:SetVertexColor(1, 1, 1, (n % 2 == 0) and 0.04 or 0.0)
        local col = obtained and COL_GREEN or ((it.legacy or not HasClass(it)) and COL_GREY or COL_WHITE)
        r.name:SetText(col .. DisplayName(it) .. COL_RESET .. (it.legacy and (" |cFF666666" .. T("COLL_LEGACY", "(legacy)") .. "|r") or ""))
        for i = 1, COLL_MAX_CHARS do
          local ch = chars[i]
          r.cells[i]:SetShown(ch and it.itemID and ch.items[it.itemID] and true or false)
        end
        local acct = ""
        if obtained then
          if it._via == "achievement" then acct = COL_GREEN .. T("COLL_VIA_ACH", "Tour de force") .. COL_RESET
          elseif it._via == "transmog" then acct = COL_GREEN .. T("COLL_VIA_TMOG", "Apparence") .. COL_RESET
          else acct = COL_GREEN .. T("COLL_YES", "Oui") .. COL_RESET end
        elseif it._status == "IN_PROGRESS" then
          acct = COL_YELLOW .. T("LEGEND_IN_PROGRESS", "En cours") .. COL_RESET
        end
        r.acct:SetText(acct)
        -- Raids de farm encore libres (objets non obtenus, equipables)
        if not obtained and it.raids and HasClass(it) and not it.legacy then
          farmCandidates = farmCandidates + 1
          for _, raid in ipairs(it.raids) do
            if not seenRaid[raid.instanceID] and #GetRaidLockouts(raid.instanceID) == 0 then
              seenRaid[raid.instanceID] = true
              freeRaids[#freeRaids + 1] = RaidName(raid)
            end
          end
        end
      end
    end
  end
  for i = idx + 1, #rows do rows[i]:Hide() end
  collFrame.content:SetHeight(math.max(100, y + 10))

  collFrame.title:SetText(COL_GOLD .. T("COLL_TITLE", "Collection du compte") .. COL_RESET)
  local pct = (total > 0) and math.floor(got * 100 / total) or 0
  collFrame.summary:SetText(string.format(T("COLL_SUMMARY", "%d / %d legendaires obtenus (%d%%)"), got, total, pct))
  if #freeRaids > 0 then
    collFrame.farm:SetText(COL_GOLD .. T("COLL_FARM", "A farmer cette semaine (raids libres) :") .. COL_RESET .. " " .. table.concat(freeRaids, ", "))
  elseif farmCandidates > 0 then
    collFrame.farm:SetText(COL_GREY .. T("COLL_FARM_DONE", "Tous les raids de farm sont deja faits cette semaine.") .. COL_RESET)
  else
    collFrame.farm:SetText(COL_GREY .. T("COLL_FARM_NONE", "Aucun raid de farm en attente pour ce personnage.") .. COL_RESET)
  end
end

function ApplyViewMode()
  local coll = mainFrame.collMode and true or false
  for _, region in ipairs({ mainFrame.listBg, mainFrame.detailScrollBg, mainFrame.headerText,
                            mainFrame.legend, mainFrame.hideObtLabel, mainFrame.hideObtainedCheck }) do
    if region then region:SetShown(not coll) end
  end
  if coll then
    BuildCollection()
    collFrame:Show()
    if RequestRaidInfo then RequestRaidInfo() end
  elseif collFrame then
    collFrame:Hide()
  end
  mainFrame.collBtn:SetText(coll and T("COLL_BTN_LIST", "Liste") or T("COLL_BTN", "Collection"))
end

-- ================================================================
-- BOUTON MINIMAP
-- ================================================================
local function GetMinimapRadius()
  return (Minimap:GetWidth() / 2) + 10
end

local function SetMinimapPos(angle)
  angle = angle % 360
  if LegTrackerDB then LegTrackerDB.mmAngle = angle end
  local r   = GetMinimapRadius()
  local rad = math.rad(angle)
  minimapBtn:ClearAllPoints()
  minimapBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad)*r, math.sin(rad)*r)
end

local function BuildMinimapButton()
  minimapBtn = CreateFrame("Button", "LegTrackerMinimapBtn", Minimap)
  minimapBtn:SetSize(32, 32)
  minimapBtn:SetFrameStrata("MEDIUM")
  minimapBtn:SetFrameLevel(8)
  minimapBtn:SetMovable(false)
  minimapBtn:EnableMouse(true)
  minimapBtn:SetClampedToScreen(true)
  minimapBtn:SetToplevel(true)

  local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER", minimapBtn, "CENTER", 0, 0)
  icon:SetSize(24, 24)
  icon:SetTexture("Interface\\AddOns\\LegTracker\\medias\\LegTracker")
  local mask = minimapBtn:CreateMaskTexture()
  mask:SetAllPoints(icon)
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  icon:AddMaskTexture(mask)

  local ring = minimapBtn:CreateTexture(nil, "OVERLAY")
  ring:SetSize(52, 52)
  ring:SetPoint("TOPLEFT", minimapBtn, "TOPLEFT", 0, 0)
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  local hl = minimapBtn:CreateTexture(nil, "ARTWORK")
  hl:SetPoint("CENTER", minimapBtn, "CENTER", 0, 0)
  hl:SetSize(20, 20)
  hl:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
  hl:SetVertexColor(1, 1, 1, 0.25)
  hl:SetAlpha(0)
  local hlMask = minimapBtn:CreateMaskTexture()
  hlMask:SetAllPoints(hl)
  hlMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  hl:AddMaskTexture(hlMask)
  minimapBtn._hl = hl

  SetMinimapPos((LegTrackerDB and LegTrackerDB.mmAngle) or 220)
  minimapBtn:SetScript("OnShow", function()
    SetMinimapPos((LegTrackerDB and LegTrackerDB.mmAngle) or 220)
  end)

  minimapBtn:RegisterForDrag("LeftButton")
  minimapBtn:SetScript("OnDragStart", function(s)
    s:SetScript("OnUpdate", function()
      local mx, my  = Minimap:GetCenter()
      local uiScale = UIParent:GetEffectiveScale()
      local cx, cy  = GetCursorPosition()
      SetMinimapPos(math.deg(math.atan2((cy/uiScale)-my, (cx/uiScale)-mx)))
    end)
  end)
  minimapBtn:SetScript("OnDragStop", function(s)
    s:SetScript("OnUpdate", nil)
  end)

  local rw = CreateFrame("Frame")
  rw:RegisterEvent("MINIMAP_UPDATE_ZOOM")
  rw:SetScript("OnEvent", function()
    SetMinimapPos((LegTrackerDB and LegTrackerDB.mmAngle) or 220)
  end)

  minimapBtn:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
      if mainFrame:IsShown() then
        mainFrame:Hide() ; LegTrackerDB.open = false
      else
        mainFrame:Show() ; mainFrame:RefreshContent() ; LegTrackerDB.open = true
      end
    end
  end)

  minimapBtn:SetScript("OnEnter", function(s)
    if s._hl then s._hl:SetAlpha(1) end
    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cFFff954eLegTracker|r", 0.95, 0.78, 0.35)
    GameTooltip:AddLine(T("MM_TT_SUBTITLE", "Suivi des objets legendaires"), 0.9, 0.9, 0.9)
    GameTooltip:AddLine(T("MM_TT_SUBTITLE2", "Suivi de compte complet"), 0.7, 0.9, 0.7)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cFFFFD700" .. T("MM_TT_LEFTCLICK_LABEL", "Clic gauche") .. "|r : " .. T("TOGGLE_HINT", "ouvrir / fermer"), 0.7, 0.7, 0.7)
    GameTooltip:AddLine("|cFFFFD700" .. T("MM_TT_DRAG_LABEL", "Glisser") .. "|r : " .. T("REPOSITION_HINT", "repositionner l'icone"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  minimapBtn:SetScript("OnLeave", function(s)
    if s._hl then s._hl:SetAlpha(0) end
    GameTooltip:Hide()
  end)
end

-- ================================================================
-- ADDON COMPARTMENT
-- ================================================================
function LegTracker_OnAddonCompartmentClick()
  if mainFrame:IsShown() then
    mainFrame:Hide() ; LegTrackerDB.open = false
  else
    mainFrame:Show() ; mainFrame:RefreshContent() ; LegTrackerDB.open = true
  end
end

function LegTracker_OnAddonCompartmentEnter(btn)
  GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
  GameTooltip:AddLine("LegTracker", 0.95, 0.78, 0.35)
  GameTooltip:AddLine(T("AC_TT_SUBTITLE", "Suivi des legendaires (compte complet)"), 0.9, 0.9, 0.9)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("|cFFFFD700" .. T("CLICK_LABEL", "Clic") .. "|r : " .. T("TOGGLE_HINT", "ouvrir / fermer"), 0.7, 0.7, 0.7)
  GameTooltip:Show()
end

function LegTracker_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end

-- ================================================================
-- /lt verify : CONTROLE DES IDS EN JEU
-- Les IDs de LegendaryItems.lua ont ete saisis a la main et plusieurs se
-- sont reveles faux (Nasz'uro, anneaux WoD, capes MoP). Cette commande
-- interroge le client pour chaque objet, monnaie et quete, et signale :
--   * les IDs inconnus du client ;
--   * sur un client francais, les noms qui ne correspondent pas aux donnees.
-- Lecture seule, n'ecrit rien dans LegTrackerDB.
-- ================================================================
local PREFIX = COL_BLUE .. "LegTracker" .. COL_RESET .. " "

local function NormName(s)
  s = tostring(s or ""):gsub("\226\128\153", "'")   -- apostrophe typographique
  local ui = _G.TibiMidnight
  s = (ui and ui.Normalize) and ui.Normalize(s) or s:lower()
  return (s:gsub("[%s%p]", ""))
end

local verifyRunning = false
local function VerifyData()
  local exts = LegTrackerData and LegTrackerData.Extensions
  if not exts then return end
  if verifyRunning then
    print(PREFIX .. T("VERIFY_BUSY", "Verification deja en cours, patientez quelques secondes."))
    return
  end
  verifyRunning = true
  local compareNames = (GetLocale() == "frFR")
  print(PREFIX .. T("VERIFY_START", "Verification des IDs en cours..."))
  if not compareNames then
    print(PREFIX .. "|cFF888888" .. T("VERIFY_NOT_FR", "Client non francais : seuls les IDs inconnus sont signales (les noms des donnees sont en francais).") .. "|r")
  end

  -- Collecte dedoublonnee : kind = item / currency / quest
  local entries, seen = {}, {}
  local function add(kind, id, name, where)
    if not id or id == 0 then return end
    local key = kind .. id
    if seen[key] then return end
    seen[key] = true
    entries[#entries + 1] = { kind = kind, id = id, name = name, where = where }
  end
  for _, ext in ipairs(exts) do
    for _, item in ipairs(ext.items or {}) do
      if not item.placeholder then add("item", item.itemID, item.name, ext.key) end
      if item.achievementID then add("achievement", item.achievementID, item.achievementName or item.name, ext.key) end
      for _, raid in ipairs(item.raids or {}) do add("instance", raid.instanceID, raid.name, ext.key) end
      for _, tr in ipairs(item.trackers or {}) do
        if tr.currencyID then add("currency", tr.currencyID, tr.name, ext.key)
        else add("item", tr.itemID, tr.name, ext.key) end
      end
      for _, q in ipairs(item.quests or {}) do add("quest", q.id, q.name, ext.key) end
    end
  end

  local okCount, problems = 0, 0
  local KIND_LABEL = { item = "item", currency = "currency", quest = "quest", achievement = "achievement", instance = "instance" }
  local function report(e, clientName)
    local tag = KIND_LABEL[e.kind] .. " " .. e.id .. " |cFF888888(" .. e.where .. ")|r"
    if not clientName or clientName == "" then
      problems = problems + 1
      print(PREFIX .. COL_RED .. T("VERIFY_MISSING", "Inconnu du client :") .. COL_RESET .. " " .. tag
            .. "  " .. COL_GREY .. (e.name or "?") .. COL_RESET)
    elseif compareNames and e.name and NormName(clientName) ~= NormName(e.name) then
      problems = problems + 1
      print(PREFIX .. COL_YELLOW .. T("VERIFY_NAME_DIFF", "Nom different :") .. COL_RESET .. " " .. tag
            .. "  " .. T("VERIFY_CLIENT", "client") .. " = " .. COL_WHITE .. clientName .. COL_RESET
            .. ", " .. T("VERIFY_DATA", "donnees") .. " = " .. COL_GREY .. e.name .. COL_RESET)
    else
      okCount = okCount + 1
    end
  end

  local pendingItems, questsTimerDone, finished = 0, false, false
  local questEntries = {}
  local function finish(timedOut)
    if finished then return end
    finished = true
    verifyRunning = false
    -- Titres de quetes sous pcall : une erreur ici ne doit pas avaler le
    -- resume, elle est affichee dans le chat pour diagnostic.
    local okQ, errQ = pcall(function()
      for _, e in ipairs(questEntries) do
        report(e, C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(e.id))
      end
    end)
    if not okQ then
      print(PREFIX .. COL_RED .. "verify (quetes) : " .. tostring(errQ) .. COL_RESET)
    end
    if timedOut and pendingItems > 0 then
      print(PREFIX .. COL_YELLOW .. string.format(T("VERIFY_TIMEOUT", "%d objet(s) sans reponse du serveur : relancez /lt verify."), pendingItems) .. COL_RESET)
    end
    print(PREFIX .. string.format(T("VERIFY_SUMMARY", "Verification terminee : %d OK, %d a controler (sur %d IDs)."),
      okCount, problems, #entries))
  end
  local function maybeFinish()
    if pendingItems == 0 and questsTimerDone then finish(false) end
  end

  for _, e in ipairs(entries) do
    if e.kind == "currency" then
      local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(e.id)
      report(e, info and info.name)
    elseif e.kind == "instance" then
      report(e, GetRealZoneText and GetRealZoneText(e.id))
    elseif e.kind == "achievement" then
      local _, aName = GetAchievementInfo(e.id)
      report(e, aName)
    elseif e.kind == "quest" then
      -- Titre charge a la demande : on le demande maintenant, on le lit a la fin
      if C_QuestLog and C_QuestLog.RequestLoadQuestByID then C_QuestLog.RequestLoadQuestByID(e.id) end
      questEntries[#questEntries + 1] = e
    elseif C_Item and C_Item.DoesItemExistByID and not C_Item.DoesItemExistByID(e.id) then
      report(e, nil)
    elseif Item and Item.CreateFromItemID then
      pendingItems = pendingItems + 1
      local obj = Item:CreateFromItemID(e.id)
      obj:ContinueOnItemLoad(function()
        if finished then return end
        report(e, obj:GetItemName())
        pendingItems = pendingItems - 1
        maybeFinish()
      end)
    else
      report(e, C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(e.id))
    end
  end

  -- Laisse le temps aux titres de quetes d'arriver, puis filet de securite
  C_Timer.After(4, function() questsTimerDone = true; maybeFinish() end)
  C_Timer.After(15, function() finish(true) end)
end

-- ================================================================
-- COMMANDES SLASH
-- ================================================================
SLASH_LEGTRACKER1 = "/lt"
SlashCmdList["LEGTRACKER"] = function(msg)
  msg = (msg or ""):lower()
  if msg == "verify" or msg == "verif" then
    VerifyData()
    return
  end
  if msg == "collection" or msg == "coll" then
    if not mainFrame:IsShown() then LegTracker_Toggle() end
    mainFrame.collMode = true
    ApplyViewMode()
    mainFrame:RefreshContent()
    return
  end
  if msg == "scan" then
    ScanAll()
    print(COL_BLUE .. "LegTracker" .. COL_RESET .. " " .. T("SCAN_DONE", "Scan termine (compte complet)."))
    if mainFrame and mainFrame:IsShown() then mainFrame:RefreshContent() end
    return
  end
  if msg == "reset" then
    if LegTrackerDB then LegTrackerDB.accountData = {} end
    print(COL_BLUE .. "LegTracker" .. COL_RESET .. " " .. T("ACCOUNT_DATA_RESET", "Donnees de compte reinitialisees."))
    return
  end
  if msg == "options" or msg == "config" then
    if LegTracker_OpenOptions then LegTracker_OpenOptions() end
    return
  end
  if mainFrame:IsShown() then
    mainFrame:Hide() ; LegTrackerDB.open = false
  else
    mainFrame:Show() ; mainFrame:RefreshContent() ; LegTrackerDB.open = true
  end
end

-- ================================================================
-- INFOBULLES (lot B) : sur un composant (objet ou monnaie), ajoute
-- "LegTracker : Composant de <legendaire>  n/besoin" ; sur un legendaire
-- suivi, ajoute son statut. Via TooltipDataProcessor (post-traitement
-- officiel des infobulles, aucun hook de fonction Blizzard, pas de taint).
-- Desactivable dans les options (LegTrackerDB.tooltips).
-- ================================================================
local tipIndex
local function BuildTooltipIndex()
  tipIndex = { item = {}, currency = {}, leg = {} }
  for _, ext in ipairs((LegTrackerData and LegTrackerData.Extensions) or {}) do
    for _, item in ipairs(ext.items or {}) do
      if item.itemID and item.itemID > 0 and not item.placeholder then tipIndex.leg[item.itemID] = item end
      for _, tr in ipairs(item.trackers or {}) do
        local bucket = tr.currencyID and tipIndex.currency or tipIndex.item
        local id = tr.currencyID or tr.itemID
        if id and id > 0 then
          bucket[id] = bucket[id] or {}
          table.insert(bucket[id], { item = item, tr = tr })
        end
      end
    end
  end
end

local LEG_TAG = "|cFFFF6D0BLegTracker|r "

local function AddComponentLine(tooltip, list)
  local first = list[1]
  local count, need = TrackerCount(first.tr), first.tr.need or 1
  local col  = (count >= need) and COL_GREEN or COL_YELLOW
  -- Composant partage (ex. 6 capes MoP) : un seul nom + "(+N)"
  local more = (#list > 1) and (" |cFF888888" .. string.format(T("TT_AND_MORE", "(+%d)"), #list - 1) .. "|r") or ""
  tooltip:AddLine(LEG_TAG .. T("TT_COMPONENT_OF", "Composant de") .. " " .. COL_GOLD .. GetItemName(first.item) .. COL_RESET
                  .. more .. "  " .. col .. count .. "/" .. need .. COL_RESET)
end

local function AddLegendaryLine(tooltip, item)
  local st = item._status
  local text
  if st == "OBTAINED" then
    local via = ViaLabel(item)
    text = COL_GREEN .. T("LEGEND_OBTAINED", "Obtenu") .. COL_RESET .. (via and (" |cFFAAAAAA(" .. via .. ")|r") or "")
  elseif st == "IN_PROGRESS" then
    text = COL_YELLOW .. T("LEGEND_IN_PROGRESS", "En cours") .. COL_RESET
  elseif st == "UNAVAILABLE" then
    text = COL_GREY .. T("LEGEND_UNAVAILABLE", "Non dispo") .. COL_RESET
  else
    text = COL_RED .. T("LEGEND_NOT_OBTAINED", "Non obtenu") .. COL_RESET
  end
  tooltip:AddLine(LEG_TAG .. text)
end

local function OnTooltipData(kind, tooltip, data)
  if not (LegTrackerDB and LegTrackerDB.tooltips ~= false) then return end
  if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
  if tooltip.IsForbidden and tooltip:IsForbidden() then return end
  local owner = tooltip.GetOwner and tooltip:GetOwner()
  if owner and owner._legOwn then return end
  local id = data and data.id
  if type(id) ~= "number" then return end
  if not tipIndex then BuildTooltipIndex() end
  if kind == "currency" then
    local list = tipIndex.currency[id]
    if list then AddComponentLine(tooltip, list) end
  else
    local leg = tipIndex.leg[id]
    if leg and leg._status then AddLegendaryLine(tooltip, leg) end
    local list = tipIndex.item[id]
    if list then AddComponentLine(tooltip, list) end
  end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  -- pcall : une infobulle ne doit jamais casser a cause de LegTracker
  if Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data) pcall(OnTooltipData, "item", tt, data) end)
  end
  if Enum.TooltipDataType.Currency then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Currency, function(tt, data) pcall(OnTooltipData, "currency", tt, data) end)
  end
end

-- ================================================================
-- ALERTE AU BUTIN (lot C) : compare les quantites de composants suivis
-- (et la possession des legendaires) avant / apres chaque mise a jour des
-- sacs. Independant de la langue du client (pas d'analyse du chat).
-- Muet 2 s apres ouverture / fermeture de la banque (arrivee des donnees
-- de banque) et pour la premiere photo au login.
-- ================================================================
local lootBaseline, legBaseline
local lootMuteUntil = 0

local function LootAlert(text)
  print(PREFIX .. text)
  if RaidNotice_AddMessage and RaidWarningFrame then
    pcall(RaidNotice_AddMessage, RaidWarningFrame, text,
          (ChatTypeInfo and ChatTypeInfo["RAID_WARNING"]) or {r=1, g=0.43, b=0.04})
  end
  if LegTrackerDB.lootSound ~= false and PlaySound and SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST then
    pcall(PlaySound, SOUNDKIT.UI_EPICLOOT_TOAST)
  end
end

local function CheckLoot(silent)
  if not LegTrackerDB or not LegTrackerData then return end
  if not tipIndex then BuildTooltipIndex() end
  local comps, legs = {}, {}
  for id in pairs(tipIndex.item) do comps[id] = CountItemEverywhere(id) end
  for id in pairs(tipIndex.leg) do legs[id] = IsEquipped(id) or CountItemEverywhere(id) > 0 end
  if GetTime and GetTime() < lootMuteUntil then silent = true end
  if lootBaseline and not silent and LegTrackerDB.lootAlert ~= false then
    for id, owned in pairs(legs) do
      if owned and not legBaseline[id] then
        LootAlert(COL_GOLD .. T("ALERT_LEGENDARY", "Legendaire obtenu :") .. " " .. GetItemName(tipIndex.leg[id]) .. " !" .. COL_RESET)
      end
    end
    for id, n in pairs(comps) do
      local before = lootBaseline[id] or 0
      local e = tipIndex.item[id][1]
      local need = e.tr.need or 1
      if n > before and before < need then
        LootAlert(string.format(T("ALERT_COMPONENT", "Composant : %s  %d/%d  (%s)"),
          e.tr.name or ("#" .. id), n, need, GetItemName(e.item)))
      end
    end
  end
  lootBaseline, legBaseline = comps, legs
end

local lootPending = false
local function RequestLootCheck()
  if lootPending then return end
  lootPending = true
  C_Timer.After(0.5, function() lootPending = false ; CheckLoot(false) end)
end

-- Premiere photo, muette, un peu apres la connexion
local function StartLootWatch()
  C_Timer.After(3, function() CheckLoot(true) end)
end

-- ================================================================
-- THROTTLE : coalesce les events rapides en un seul rescan
-- Des events comme QUEST_LOG_UPDATE ou BAG_UPDATE_DELAYED peuvent se
-- declencher en rafale ; on evite ainsi un ScanAll complet a chaque fire.
-- ================================================================
local refreshPending = false
local function RequestRefresh(delay)
  if refreshPending then return end
  refreshPending = true
  C_Timer.After(delay or 0.3, function()
    refreshPending = false
    if mainFrame and mainFrame:IsShown() then
      mainFrame:RefreshContent()
    end
  end)
end

-- ================================================================
-- EVENEMENTS
-- ================================================================
local evFrame = CreateFrame("Frame")
evFrame:RegisterEvent("ADDON_LOADED")
evFrame:RegisterEvent("PLAYER_LOGIN")
evFrame:RegisterEvent("BAG_UPDATE_DELAYED")
evFrame:RegisterEvent("QUEST_TURNED_IN")
evFrame:RegisterEvent("QUEST_LOG_UPDATE")
evFrame:RegisterEvent("ACHIEVEMENT_EARNED")
evFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
evFrame:RegisterEvent("BANKFRAME_OPENED")
evFrame:RegisterEvent("BANKFRAME_CLOSED")
-- Lot B : etape "dans le journal", apparences apprises, monnaies
evFrame:RegisterEvent("QUEST_ACCEPTED")
evFrame:RegisterEvent("QUEST_REMOVED")
evFrame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
evFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
-- Lot C : verrouillages de raid
evFrame:RegisterEvent("UPDATE_INSTANCE_INFO")

evFrame:SetScript("OnEvent", function(_, event, arg1)

  if event == "ADDON_LOADED" and arg1 == ADDON then
    InitDB()
    BuildUI()
    BuildMinimapButton()

    local p = LegTrackerDB.pos
    mainFrame:ClearAllPoints()
    if p and p.x then
      mainFrame:SetPoint("CENTER", UIParent, "CENTER", p.x, p.y)
    else
      mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- Taille sauvegardee (redimensionnement manuel)
    if LegTrackerDB.width and LegTrackerDB.height then
      mainFrame:SetSize(LegTrackerDB.width, LegTrackerDB.height)
    end

    -- Applique les options (echelle, opacite, minimap, verrou)
    if mainFrame.ApplyOptions then mainFrame:ApplyOptions() end

    LegTrackerDB.open = false  -- l'ouverture auto est geree au PLAYER_LOGIN

    -- Rattrapage LoadOnDemand : quand TibiSuite charge ce module a la demande,
    -- PLAYER_LOGIN est deja passe et son handler ci-dessous ne se declenchera
    -- plus. On rejoue donc ici le travail fonctionnel de login (identite du
    -- personnage indispensable a ScanAll, puis scan des objets legendaires et
    -- ouverture auto) si la connexion est deja effective. Aucun impact donnees.
    if IsLoggedIn() then
      local _, cls = UnitClass("player")
      PLAYER_CLASS = cls
      PLAYER_NAME  = UnitName("player")
      PLAYER_REALM = GetRealmName()
      ScanAll()
      StartLootWatch()
      if LegTrackerDB.autoOpen and mainFrame then
        mainFrame:Show() ; mainFrame:RefreshContent() ; LegTrackerDB.open = true
      end
    end

  elseif event == "ADDON_LOADED" and arg1 == "TibiSuite" then
    -- TibiSuite est présent : il gère le bouton minimap unifié
    if minimapBtn then minimapBtn:Hide() end

  elseif event == "PLAYER_LOGIN" then
    local _, cls = UnitClass("player")
    PLAYER_CLASS = cls
    PLAYER_NAME  = UnitName("player")
    PLAYER_REALM = GetRealmName()

    -- Si TibiSuite est deja charge (il peut se charger avant LegTracker),
    -- il gere le bouton minimap unifie : on masque le notre.
    if minimapBtn and C_AddOns and C_AddOns.IsAddOnLoaded
       and C_AddOns.IsAddOnLoaded("TibiSuite") then
      minimapBtn:Hide()
    end

    ScanAll()
    StartLootWatch()
    if RequestRaidInfo then RequestRaidInfo() end

    -- Ouverture automatique au login si l'option est active
    if LegTrackerDB.autoOpen and mainFrame then
      mainFrame:Show() ; mainFrame:RefreshContent() ; LegTrackerDB.open = true
    end

    print(COL_BLUE .. "LegTracker v7.1.5.38" .. COL_RESET
          .. " " .. T("LOGIN_LOADED", "chargé -- tapez") .. " " .. COL_GOLD .. "/lt" .. COL_RESET .. " " .. T("LOGIN_TO_OPEN", "pour ouvrir.")
          .. " |cFF888888" .. T("LOGIN_SUBCMDS", "(/lt scan = forcer scan, /lt verify = controler les IDs, /lt reset = reinit donnees compte)") .. "|r")

  elseif event == "BANKFRAME_OPENED" or event == "BANKFRAME_CLOSED" then
    -- Rescanner apres ouverture/fermeture banque (pour detecter items en banque)
    RequestRefresh(0.5)
    -- Les quantites de banque peuvent arriver maintenant : pas d'alerte
    lootMuteUntil = (GetTime and GetTime() or 0) + 2
    C_Timer.After(2.1, function() CheckLoot(true) end)

  elseif event == "ADDON_LOADED" then
    -- ADDON_LOADED d'un autre addon : rien a faire (evite les rescans inutiles)

  else
    -- BAG_UPDATE_DELAYED, QUEST_TURNED_IN, QUEST_LOG_UPDATE,
    -- ACHIEVEMENT_EARNED, PLAYER_EQUIPMENT_CHANGED : rescan throttle
    if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" then RequestLootCheck() end
    RequestRefresh()
  end

end)

-- ================================================================
-- TOGGLE PUBLIC -- appelé par TibiSuite
-- ================================================================
function LegTracker_Toggle()
  if mainFrame:IsShown() then
    mainFrame:Hide()
    LegTrackerDB.open = false
  else
    if RequestRaidInfo then RequestRaidInfo() end
    mainFrame:Show()
    mainFrame:RefreshContent()
    LegTrackerDB.open = true
  end
end
