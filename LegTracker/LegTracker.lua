-- ================================================================
-- LegTracker v6.0
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
    return "|cFFFFFFFFToutes classes|r"
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

-- Compte l'item partout : sacs, banque, coffre de guilde, equipe
-- includeBank=true, includeReagentBank=true couvre banque normale + banque de reagents
local function CountItemEverywhere(itemID)
  if not itemID or itemID == 0 then return 0 end
  local n = 0
  -- API moderne (recommandee Dragonflight+)
  if C_Item and C_Item.GetItemCount then
    n = C_Item.GetItemCount(itemID, true, false, true, true) or 0
    if n > 0 then return n end
  end
  -- Fallback : GetItemCount(id, includeBank)
  n = GetItemCount(itemID, true) or 0
  return n
end

-- Verification complete sur le personnage actuel
local function IsObtainedOnCurrentChar(itemID)
  if not itemID or itemID == 0 then return false end
  -- 1. Verifie si equipe
  if IsEquipped(itemID) then return true end
  -- 2. Verifie dans les sacs et la banque
  if CountItemEverywhere(itemID) > 0 then return true end
  return false
end

-- ================================================================
-- GESTION DES DONNEES DE COMPTE (suivi multi-personnages)
-- ================================================================

local function SaveCurrentCharData()
  if not LegTrackerDB or not PLAYER_NAME or not PLAYER_REALM then return end
  local db = LegTrackerDB
  if not db.accountData[PLAYER_REALM] then db.accountData[PLAYER_REALM] = {} end
  db.accountData[PLAYER_REALM][PLAYER_NAME] = {}

  -- Sauvegarde de la classe du personnage pour colorisation
  if PLAYER_CLASS then
    db.accountData[PLAYER_REALM][PLAYER_NAME]._class = PLAYER_CLASS
  end

  if not LegTrackerData or not LegTrackerData.Extensions then return end
  for _, ext in ipairs(LegTrackerData.Extensions) do
    for _, item in ipairs(ext.items or {}) do
      if item.itemID and item.itemID > 0 then
        if IsObtainedOnCurrentChar(item.itemID) then
          db.accountData[PLAYER_REALM][PLAYER_NAME][item.itemID] = true
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

local function IsObtainedOnAccount(itemID)
  if not itemID or itemID == 0 then return false end
  if IsObtainedOnCurrentChar(itemID) then return true end
  if not LegTrackerDB or not LegTrackerDB.accountData then return false end
  for _, chars in pairs(LegTrackerDB.accountData) do
    for _, items in pairs(chars) do
      if items[itemID] then return true end
    end
  end
  return false
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

local function QuestCompleted(questID)
  return questID
    and C_QuestLog
    and C_QuestLog.IsQuestFlaggedCompleted
    and C_QuestLog.IsQuestFlaggedCompleted(questID) == true
end

local function GetIcon(itemID)
  if itemID and itemID > 0 then
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
    if icon then return icon end
    local _, _, _, icon2 = GetItemInfoInstant(itemID)
    if icon2 then return icon2 end
  end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function GetItemName(item)
  if item.itemID and item.itemID > 0 then
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item.itemID)
    if name then return name end
  end
  return item.name or T("UNKNOWN", "Inconnu")
end

-- ================================================================
-- SCAN DES LEGENDAIRES (niveau compte)
-- ================================================================
local function ScanLegendaryStatus(item)
  local equippable = HasClass(item)

  -- Si possede sur le compte (autre perso inclus) ou achievement : OBTAINED meme si non equippable
  if IsObtainedOnAccount(item.itemID) or AnyAchievementCompleted(item) then
    return "OBTAINED", 0, 0, 0, 0
  end

  if not equippable then return "UNAVAILABLE", 0, 0, 0, 0 end

  local questDone, questTotal = 0, 0
  if item.quests then
    for _, q in ipairs(item.quests) do
      if q.id then
        questTotal = questTotal + 1
        if QuestCompleted(q.id) then questDone = questDone + 1 end
      end
    end
  end

  local trackerDone, trackerTotal = 0, 0
  if item.trackers then
    for _, tr in ipairs(item.trackers) do
      if tr.itemID then
        trackerTotal = trackerTotal + 1
        if CountItemEverywhere(tr.itemID) >= (tr.need or 1) then trackerDone = trackerDone + 1 end
      end
    end
  end

  if questDone > 0 or trackerDone > 0 then
    return "IN_PROGRESS", questDone, questTotal, trackerDone, trackerTotal
  end
  return "MISSING", questDone, questTotal, trackerDone, trackerTotal
end

local function ScanAll()
  if not LegTrackerData or not LegTrackerData.Extensions then return end
  for _, ext in ipairs(LegTrackerData.Extensions) do
    for _, item in ipairs(ext.items or {}) do
      local status, qDone, qTotal, tDone, tTotal = ScanLegendaryStatus(item)
      item._status = status
      item._qDone  = qDone
      item._qTotal = qTotal
      item._tDone  = tDone
      item._tTotal = tTotal
    end
  end
  SaveCurrentCharData()
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
    print(COL_BLUE .. "LegTracker" .. COL_RESET .. " Aucune coordonnee disponible.")
    return
  end
  if not TomTom or not TomTom.AddWaypoint then
    -- Fallback natif Blizzard : point de route + grande fleche de suivi (equiv /way)
    if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(q.mapID, q.x / 100, q.y / 100))
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
      end
      print(COL_BLUE .. "LegTracker" .. COL_RESET
            .. " Waypoint (carte) : " .. (q.name or "?") .. " (" .. (q.zone or "?") .. ")")
    else
      print(COL_BLUE .. "LegTracker" .. COL_RESET
            .. " Impossible de poser un waypoint natif. Installez |cFFFFD700TomTom|r.")
    end
    return
  end
  TomTom:AddWaypoint(q.mapID, q.x / 100, q.y / 100, {
    title      = (q.name or "Quete legendaire") .. (q.npc and (" - " .. q.npc) or ""),
    persistent = false, minimap = true, world = true,
  })
  print(COL_BLUE .. "LegTracker" .. COL_RESET
        .. " Waypoint ajoute : " .. (q.name or "?") .. " (" .. (q.zone or "?") .. ")")
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

local function ClearChildren(parent)
  if not parent then return end
  for _, child in ipairs({ parent:GetChildren() }) do
    ClearChildren(child)
    child:Hide()
    child:SetParent(nil)
  end
  for _, region in ipairs({ parent:GetRegions() }) do
    region:Hide()
  end
end

local function MakeSeparator(parent, x, y, w)
  local sep = parent:CreateTexture(nil, "ARTWORK")
  sep:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
  sep:SetPoint("TOPLEFT", x, y)
  sep:SetSize(w or 490, 14)
  return sep
end

-- ================================================================
-- BASE DE DONNEES "COMMENT OBTENIR" LES COMPOSANTS
-- ================================================================
local HOW_TO_OBTAIN = {
  -- Vanilla
  [18563] = "Butin sur le Seigneur Thunderaan apres la quete de convocation (Silithus).",
  [18564] = "Butin sur le Seigneur Thunderaan apres la quete de convocation (Silithus).",
  [17771] = "Craft : 8x Lingots de sulfuron + 4x Eclat de lave + 2x Fil de rune sombre (ingenieur/forgeron).",
  [17204] = "Butin de Ragnaros (boss final du Coeur du Magma).",
  [17193] = "Craft a partir de 8 Barres de sulfuron (elles-memes craftees avec 4 Noyaux d'essence de feu).",
  [17203] = "Craft : 8 Barres de sulfuron assemblees (elles-memes craftees avec des Noyaux d'essence).",
  [22726] = "Butin sur les boss de Naxxramas original (non disponible en Retail moderne).",
  -- WotLK
  [45038] = "Butin sur n'importe quel boss d'Ulduar (~5% de chance par boss).",
  [45039] = "Obtenez 30 Fragments de Val'anyr, lancez le sac brise dans la Fontaine d'Ulduar, puis tuez Yogg-Saron.",
  [50274] = "Butin sur les boss du Palier 25 de la Citadelle de la Couronne de glace.",
  [50226] = "Butin sur Arthas le Roi-Liche (boss final de la Citadelle de la Couronne de glace).",
  -- Cata
  [71083] = "Recompense de la quete intermediaire de la chaine legendaire (Terres de Feu).",
  [71635] = "Farme les boss des Terres de Feu. 250 necessaires au total.",
  [71998] = "Butin sur Ragnaros (boss final des Terres de Feu).",
  [77952] = "Butin sur Deathwing, obtenu via la quete de voleur (Ames des dragons).",
  -- MoP
  [94221] = "Butin sur les boss LFR/Normal du Coeur de la Peur, Terrace du Printemps, Trone du Tonnerre.",
  [94593] = "Recompense de la suite de quetes legendaires d'Irion en Pandarie.",
  -- WoD
  [118099] = "Recompense de la quete de debut 'L'appel de l'archimage' aupres de Khadgar.",
  [113681] = "Butin dans les coffres de la Citadelle des Flammes Infernales (toute difficulte).",
  [115508] = "Butin sur les boss de la Citadelle des Flammes Infernales (Heroique ou Mythique).",
  -- BfA
  [169223] = "Obtenu via la quete de campagne N'Zoth. Ameliorez le rang en completant les objectifs.",
  -- SL
  [183955] = "Butin commun dans les raids Shadowlands (Nathria, Sanctum, Sepulcre).",
  [187707] = "Butin dans les Chateaux de Nathria.",
  [190189] = "Obtenus dans les donjons Heroiques/Mythiques de Shadowlands.",
  -- DF
  [204987] = "Butin sur Sarkareth en Mythique (Aberrus, l'Ombre de la Forgeresse).",
}

local function GetHowToObtain(tr)
  return HOW_TO_OBTAIN[tr.itemID] or tr.howTo or nil
end

-- ================================================================
-- PANNEAU DETAIL (colonne droite)
-- ================================================================
local detailFrame

local function RefreshDetail(item)
  if not detailFrame then return end
  if not item then return end
  ClearChildren(detailFrame)

  local W  = detailFrame:GetWidth() - 20
  local y  = -12
  local sc = STATUS_COLORS[item._status] or STATUS_COLORS["MISSING"]

  -- Icone + nom
  local iconTex = detailFrame:CreateTexture(nil, "ARTWORK")
  iconTex:SetSize(40, 40)
  iconTex:SetPoint("TOPLEFT", 10, y)
  iconTex:SetTexture(GetIcon(item.itemID))
  -- Icone en couleur si obtenu (meme par un autre perso), desature si non equippable et non obtenu
  if not HasClass(item) and item._status ~= "OBTAINED" then iconTex:SetDesaturated(true) end

  local nameFS = detailFrame:CreateFontString(nil, "OVERLAY")
  nameFS:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
  nameFS:SetPoint("TOPLEFT", 56, y)
  nameFS:SetWidth(W - 46)
  nameFS:SetWordWrap(true)
  nameFS:SetJustifyH("LEFT")
  nameFS:SetText(COL_GOLD .. GetItemName(item) .. COL_RESET)
  y = y - 50

  -- Statut
  local statusFS = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  statusFS:SetPoint("TOPLEFT", 10, y)
  statusFS:SetWidth(W)
  statusFS:SetWordWrap(true)
  local status = item._status or "MISSING"
  local sLabel
  if status == "OBTAINED" then
    sLabel = COL_GREEN .. "[Obtenu]" .. COL_RESET
  elseif status == "IN_PROGRESS" then
    sLabel = COL_YELLOW .. "[En cours]" .. COL_RESET
             .. string.format(" |cFFAAAAAA(%d/%d quetes, %d/%d composants)|r",
                item._qDone or 0, item._qTotal or 0,
                item._tDone or 0, item._tTotal or 0)
  elseif status == "UNAVAILABLE" then
    sLabel = COL_GREY .. "Reservé : " .. COL_RESET .. GetClassesText(item)
  else
    sLabel = COL_RED .. "[Non obtenu]" .. COL_RESET
  end
  statusFS:SetText(sLabel)
  y = y - 22

  -- Qui possede cet item ? (suivi de compte)
  if item.itemID and item.itemID > 0 then
    local ownerStr = GetOwnersText(item.itemID, false)
    if ownerStr then
      local ownerFS = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      ownerFS:SetPoint("TOPLEFT", 10, y)
      ownerFS:SetWidth(W)
      ownerFS:SetWordWrap(true)
      ownerFS:SetText(COL_GREEN .. "Detenu par : " .. COL_RESET .. ownerStr)
      y = y - 20
    end
  end

  -- Bande de statut laterale
  local stripe = detailFrame:CreateTexture(nil, "ARTWORK")
  stripe:SetPoint("TOPLEFT", 4, -12)
  stripe:SetSize(4, -(y + 12) - 4)
  stripe:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  stripe:SetVertexColor(sc.r, sc.g, sc.b, 0.9)

  MakeSeparator(detailFrame, 8, y, W + 4)
  y = y - 16

  -- Section source / comment obtenir
  local srcHdr = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  srcHdr:SetPoint("TOPLEFT", 10, y)
  srcHdr:SetText(COL_GOLD .. "Comment l'obtenir" .. COL_RESET)
  y = y - 18

  local srcFS = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  srcFS:SetPoint("TOPLEFT", 10, y)
  srcFS:SetWidth(W)
  srcFS:SetWordWrap(true)
  srcFS:SetJustifyH("LEFT")
  srcFS:SetText("|cFFCCBB88" .. (item.source or T("UNKNOWN","Inconnu")) .. COL_RESET)
  -- Hauteur reelle mesuree apres rendu (evite le chevauchement des sections)
  local srcH = math.max(28, math.ceil(srcFS:GetStringHeight()) + 6)
  y = y - srcH

  MakeSeparator(detailFrame, 8, y, W + 4)
  y = y - 16

  -- Section quetes
  local qKey   = "q_" .. tostring(item.itemID)
  local qOpen  = LegTrackerDB.sections[qKey] ~= false
  local qCount = item.quests and #item.quests or 0

  local qHeader = CreateFrame("Button", nil, detailFrame, "BackdropTemplate")
  qHeader:SetSize(W, 24)
  qHeader:SetPoint("TOPLEFT", 10, y)
  qHeader:SetBackdrop(BACKDROP_ROW)
  qHeader:SetBackdropColor(0.30*0.18, 0.60*0.18, 1.00*0.18, 0.95)
  qHeader:SetBackdropBorderColor(0.30*0.8, 0.60*0.8, 1.00*0.8, 0.9)

  local qArrow = qHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  qArrow:SetPoint("LEFT", qHeader, "LEFT", 6, 0)
  qArrow:SetText(qOpen and "|cFFFFFFFF[-]|r" or "|cFFFFFFFF[+]|r")

  local qTitle = qHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  qTitle:SetPoint("LEFT", qHeader, "LEFT", 26, 0)
  qTitle:SetText("|cFF4D99FFQuetes|r")

  local qCountFS = qHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  qCountFS:SetPoint("RIGHT", qHeader, "RIGHT", -6, 0)
  qCountFS:SetText("|cFFAAAAAA" .. qCount .. " quete" .. (qCount > 1 and "s" or "") .. "|r")
  y = y - 28

  if qOpen then
    if item.quests and #item.quests > 0 then
      for _, q in ipairs(item.quests) do
        local done = q.id and QuestCompleted(q.id)
        local qRow = CreateFrame("Button", nil, detailFrame, "BackdropTemplate")
        qRow:SetSize(W, 52)
        qRow:SetPoint("TOPLEFT", 10, y)
        qRow:SetBackdrop(BACKDROP_ROW)
        qRow:SetBackdropColor(0.30*0.06, 0.60*0.06, 1.00*0.06, done and 0.4 or 0.85)
        qRow:SetBackdropBorderColor(0.30*0.4, 0.60*0.4, 1.00*0.4, done and 0.3 or 0.7)

        local qs = qRow:CreateTexture(nil, "ARTWORK")
        qs:SetPoint("TOPLEFT", qRow, "TOPLEFT", 2, -2)
        qs:SetSize(4, 48)
        qs:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        qs:SetVertexColor(done and 0.35 or 0.30, done and 0.35 or 0.60, done and 0.35 or 1.00, done and 0.5 or 0.9)

        local qStatus = qRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        qStatus:SetPoint("TOPRIGHT", qRow, "TOPRIGHT", -5, -4)
        qStatus:SetText(done and (COL_GREEN .. "[Fait]" .. COL_RESET) or "|cFF4D99FF[A faire]|r")

        local qNameFS = qRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        qNameFS:SetPoint("TOPLEFT", qRow, "TOPLEFT", 12, -4)
        qNameFS:SetWidth(W - 70)
        qNameFS:SetWordWrap(false)
        qNameFS:SetJustifyH("LEFT")
        qNameFS:SetText((done and COL_GREY or COL_WHITE) .. (q.name or ("Quete #" .. tostring(q.id))) .. COL_RESET)

        local qInfo = qRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        qInfo:SetPoint("TOPLEFT", qRow, "TOPLEFT", 12, -20)
        qInfo:SetWidth(W - 14)
        qInfo:SetWordWrap(false)
        qInfo:SetJustifyH("LEFT")
        if done then
          qInfo:SetText("|cFF555555" .. (q.npc or "PNJ inconnu") .. "  " .. (q.zone or "Zone inconnue") .. "|r")
        else
          qInfo:SetText("|cFF888888PNJ :|r |cFFCCBB88" .. (q.npc or "inconnu") .. "|r"
                        .. "  |cFF888888Zone :|r |cFF99CCFF" .. (q.zone or "inconnue") .. "|r")
        end

        local qHint = qRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        qHint:SetPoint("TOPLEFT", qRow, "TOPLEFT", 12, -34)
        qHint:SetWidth(W - 14)
        qHint:SetJustifyH("LEFT")
        if q.x and q.y then
          qHint:SetText(string.format("|cFF666666%.1f, %.1f - Clic: waypoint TomTom|r", q.x, q.y))
        else
          qHint:SetText("|cFF666666Clic : waypoint TomTom|r")
        end

        qRow:SetScript("OnClick", function() AddTomTomWaypoint(q) end)
        qRow:SetScript("OnEnter", function(s)
          GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
          GameTooltip:AddLine(q.name or "Quete legendaire", 0.30, 0.60, 1.0)
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine("PNJ : " .. (q.npc or "inconnu"), 0.9, 0.9, 0.7)
          GameTooltip:AddLine("Zone : " .. (q.zone or "inconnue"), 0.8, 0.8, 0.8)
          if q.x and q.y then
            GameTooltip:AddLine(string.format("Coordonnees : %.1f, %.1f", q.x, q.y), 0.7, 0.9, 1.0)
          end
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine("Clic pour ajouter un waypoint TomTom.", 0.75, 0.75, 0.75, true)
          GameTooltip:Show()
        end)
        qRow:SetScript("OnLeave", function() GameTooltip:Hide() end)
        y = y - 56
      end
    else
      local qNone = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      qNone:SetPoint("TOPLEFT", 14, y)
      qNone:SetText(COL_GREY .. "Aucune quete specifique renseignee." .. COL_RESET)
      y = y - 20
    end
  end

  qHeader:SetScript("OnClick", function()
    LegTrackerDB.sections[qKey] = not qOpen
    RefreshDetail(item)
  end)
  qHeader:SetScript("OnEnter", function(s) s:SetBackdropColor(0.30*0.30, 0.60*0.30, 1.00*0.30, 1.0) end)
  qHeader:SetScript("OnLeave", function(s) s:SetBackdropColor(0.30*0.18, 0.60*0.18, 1.00*0.18, 0.95) end)

  y = y - 8
  MakeSeparator(detailFrame, 8, y, W + 4)
  y = y - 16

  -- Section composants
  local cKey   = "c_" .. tostring(item.itemID)
  local cOpen  = LegTrackerDB.sections[cKey] ~= false
  local cCount = item.trackers and #item.trackers or 0
  local cColor = {r=1.00, g=0.82, b=0.00}

  local cHeader = CreateFrame("Button", nil, detailFrame, "BackdropTemplate")
  cHeader:SetSize(W, 24)
  cHeader:SetPoint("TOPLEFT", 10, y)
  cHeader:SetBackdrop(BACKDROP_ROW)
  cHeader:SetBackdropColor(cColor.r*0.18, cColor.g*0.18, cColor.b*0.18, 0.95)
  cHeader:SetBackdropBorderColor(cColor.r*0.8, cColor.g*0.8, cColor.b*0.8, 0.9)

  local cArrow = cHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  cArrow:SetPoint("LEFT", cHeader, "LEFT", 6, 0)
  cArrow:SetText(cOpen and "|cFFFFFFFF[-]|r" or "|cFFFFFFFF[+]|r")

  local cTitle = cHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  cTitle:SetPoint("LEFT", cHeader, "LEFT", 26, 0)
  cTitle:SetText(COL_YELLOW .. "Composants" .. COL_RESET)

  local cCountFS = cHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  cCountFS:SetPoint("RIGHT", cHeader, "RIGHT", -6, 0)
  cCountFS:SetText("|cFFAAAAAA" .. cCount .. " item" .. (cCount > 1 and "s" or "") .. "|r")
  y = y - 28

  if cOpen then
    if item.trackers and #item.trackers > 0 then
      for _, tr in ipairs(item.trackers) do
        local count  = tr.itemID and CountItemEverywhere(tr.itemID) or 0
        local need   = tr.need or 1
        local ok     = count >= need
        local pct    = math.min(1.0, count / need)
        local howTo  = GetHowToObtain(tr)

        local cRow = CreateFrame("Button", nil, detailFrame, "BackdropTemplate")
        cRow:SetPoint("TOPLEFT", 10, y)
        cRow:SetBackdrop(BACKDROP_ROW)
        cRow:SetBackdropColor(cColor.r*0.06, cColor.g*0.06, cColor.b*0.06, ok and 0.4 or 0.85)
        cRow:SetBackdropBorderColor(cColor.r*0.4, cColor.g*0.4, cColor.b*0.4, ok and 0.3 or 0.7)

        -- Icone du composant
        local cIconTex = cRow:CreateTexture(nil, "ARTWORK")
        cIconTex:SetSize(22, 22)
        cIconTex:SetPoint("TOPLEFT", cRow, "TOPLEFT", 10, -4)
        cIconTex:SetTexture(GetIcon(tr.itemID))

        local cNameFS = cRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cNameFS:SetPoint("TOPLEFT", cRow, "TOPLEFT", 36, -4)
        cNameFS:SetWidth(W - 90)
        cNameFS:SetWordWrap(false)
        cNameFS:SetJustifyH("LEFT")
        cNameFS:SetText((ok and COL_GREY or COL_WHITE) .. (tr.name or ("Item #" .. tostring(tr.itemID))) .. COL_RESET)

        local cCntFS = cRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cCntFS:SetPoint("TOPRIGHT", cRow, "TOPRIGHT", -8, -4)
        cCntFS:SetText((ok and COL_GREEN or COL_YELLOW) .. count .. "/" .. need .. COL_RESET)

        -- Mini barre de progression
        local barBg = CreateFrame("Frame", nil, cRow, "BackdropTemplate")
        barBg:SetPoint("TOPLEFT", cRow, "TOPLEFT", 10, -28)
        barBg:SetSize(W - 24, 8)
        barBg:SetBackdrop(BACKDROP_ROW)
        barBg:SetBackdropColor(0, 0, 0, 0.6)
        barBg:SetBackdropBorderColor(0.5, 0.45, 0.25, 0.5)

        local barFill = barBg:CreateTexture(nil, "ARTWORK")
        barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT", 2, -2)
        barFill:SetHeight(4)
        barFill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        local fillW = math.max(2, math.floor((W - 28) * pct))
        barFill:SetWidth(fillW)
        barFill:SetVertexColor(ok and 0.27 or cColor.r, ok and 1.00 or cColor.g, ok and 0.27 or cColor.b, 1.0)

        -- "Comment obtenir" ce composant : hauteur mesuree pour eviter le chevauchement
        local rowH = 50
        if howTo then
          local howFS = cRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
          howFS:SetPoint("TOPLEFT", cRow, "TOPLEFT", 10, -40)
          howFS:SetWidth(W - 20)
          howFS:SetWordWrap(true)
          howFS:SetJustifyH("LEFT")
          howFS:SetText("|cFF888888 " .. howTo .. "|r")
          rowH = math.max(50, 44 + math.ceil(howFS:GetStringHeight()) + 6)
        end

        cRow:SetSize(W, rowH)

        -- Bande laterale de statut (dimensionnee apres calcul de rowH)
        local cs = cRow:CreateTexture(nil, "ARTWORK")
        cs:SetPoint("TOPLEFT", cRow, "TOPLEFT", 2, -2)
        cs:SetSize(4, rowH - 4)
        cs:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        cs:SetVertexColor(ok and 0.27 or cColor.r, ok and 1.00 or cColor.g, ok and 0.27 or cColor.b, 0.9)

        cRow:SetScript("OnEnter", function(s)
          if tr.itemID and tr.itemID > 0 then
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(tr.itemID)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format("Possede : %d / %d", count, need),
              ok and 0.27 or cColor.r, ok and 1.00 or cColor.g, ok and 0.27 or cColor.b)
            if howTo then
              GameTooltip:AddLine(" ")
              GameTooltip:AddLine("Comment l'obtenir :", 0.95, 0.78, 0.35)
              GameTooltip:AddLine(howTo, 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
          end
        end)
        cRow:SetScript("OnLeave", function() GameTooltip:Hide() end)
        y = y - (rowH + 4)
      end
    else
      local cNone = detailFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      cNone:SetPoint("TOPLEFT", 14, y)
      cNone:SetText(COL_GREY .. "Aucun composant a suivre." .. COL_RESET)
      y = y - 20
    end
  end

  cHeader:SetScript("OnClick", function()
    LegTrackerDB.sections[cKey] = not cOpen
    RefreshDetail(item)
  end)
  cHeader:SetScript("OnEnter", function(s) s:SetBackdropColor(cColor.r*0.30, cColor.g*0.30, cColor.b*0.30, 1.0) end)
  cHeader:SetScript("OnLeave", function(s) s:SetBackdropColor(cColor.r*0.18, cColor.g*0.18, cColor.b*0.18, 0.95) end)

  detailFrame:SetHeight(math.max(300, -(y) + 20))
end

-- ================================================================
-- CONSTRUCTION UI PRINCIPALE (onglets verticaux)
-- ================================================================
local mainFrame, minimapBtn

-- ================================================================
-- LIGNES DE LISTE REUTILISABLES (pool par index)
-- Le squelette (frame + sous-elements) est construit UNE SEULE fois par
-- ligne ; les rafraichissements ne font que mettre a jour les proprietes.
-- Evite la creation de frames a chaque refresh (fuite memoire / taint).
-- ================================================================
local function MakeListRow(parent)
  local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
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
      GameTooltip:SetText((item and item.name) or "A completer")
    end
    if item and s._inProgress then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Progression :", 0.95, 0.78, 0.35)
      local qD, qT = item._qDone or 0, item._qTotal or 0
      local tD, tT = item._tDone or 0, item._tTotal or 0
      if qT > 0 then GameTooltip:AddLine(string.format("  Quêtes : %d / %d", qD, qT), 0.30, 0.60, 1.0) end
      if tT > 0 then GameTooltip:AddLine(string.format("  Composants : %d / %d", tD, tT), 1.0, 0.82, 0.0) end
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
        GameTooltip:AddLine("Detenu par :", 0.95, 0.78, 0.35)
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
    row.subFS:SetText(COL_GREY .. "A completer" .. COL_RESET)
  elseif obtained then
    local ownerStr = item.itemID and item.itemID > 0 and GetOwnersText(item.itemID, true) or nil
    if ownerStr then
      row.subFS:SetText(COL_GREEN .. "[Obtenu]" .. COL_RESET .. "  " .. ownerStr)
    else
      row.subFS:SetText(COL_GREEN .. "[Obtenu]" .. COL_RESET)
    end
  elseif not equippable then
    row.subFS:SetText(GetClassesText(item))
  elseif inProgress then
    local qD, qT = item._qDone or 0, item._qTotal or 0
    local tD, tT = item._tDone or 0, item._tTotal or 0
    local parts = {}
    if qT > 0 then table.insert(parts, string.format("|cFF4D99FFQuêtes %d/%d|r", qD, qT)) end
    if tT > 0 then table.insert(parts, string.format("|cFFFFCC00Compos. %d/%d|r", tD, tT)) end
    row.subFS:SetText(COL_YELLOW .. "[En cours] " .. COL_RESET
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
    row.subFS:SetText(COL_RED .. "[Non obtenu]" .. COL_RESET)
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

  local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -5, -5)
  closeBtn:SetScript("OnClick", function()
    mainFrame:Hide() ; LegTrackerDB.open = false
  end)

  local dragHint = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  dragHint:SetPoint("TOP", 0, -30)
  dragHint:SetText("|cFF888888Glisser pour deplacer  -  /lt|r")

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
      mainFrame:RefreshContent()
    end)
    eb:SetScript("OnEnter", function(s)
      s:SetBackdropBorderColor(col.r, col.g, col.b, 1.0)
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
      GameTooltip:AddLine(fullName, col.r, col.g, col.b)
      GameTooltip:AddLine("Legendaires de l'extension", 0.8, 0.8, 0.8)
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
  mainFrame.headerText:SetText(COL_GOLD .. "Selectionnez une extension" .. COL_RESET)

  local legend = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  legend:SetPoint("TOPLEFT", tabColBg, "TOPRIGHT", 8, -18)
  legend:SetText(
    COL_GREEN  .. "  Obtenu  " .. COL_RESET ..
    COL_YELLOW .. "  En cours  " .. COL_RESET ..
    COL_RED    .. "  Non obtenu  " .. COL_RESET ..
    COL_GREY   .. "  Non dispo" .. COL_RESET
  )

  -- Zone centrale scrollable (commence sous headerText + legend)
  local rightW = 280
  local listBg = CreateFrame("Frame", nil, mainFrame)
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
    GameTooltip:AddLine("Etirer la fenetre", 0.95, 0.78, 0.35)
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
  hideObtLabel:SetText("|cFFDDDDDDMasquer obtenus|r")
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
    GameTooltip:AddLine("Masquer / afficher les objets deja obtenus", 0.9, 0.9, 0.9)
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
        self.emptyFS:SetText(COL_GREY .. "Aucun objet a afficher avec les filtres actuels." .. COL_RESET)
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
  end

  mainFrame:Hide()
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
    GameTooltip:AddLine("Suivi des objets legendaires", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Suivi de compte complet", 0.7, 0.9, 0.7)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cFFFFD700Clic gauche|r : ouvrir / fermer", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("|cFFFFD700Glisser|r : repositionner l'icone", 0.7, 0.7, 0.7)
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
  GameTooltip:AddLine("Suivi des legendaires (compte complet)", 0.9, 0.9, 0.9)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("|cFFFFD700Clic|r : ouvrir / fermer", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end

function LegTracker_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end

-- ================================================================
-- COMMANDES SLASH
-- ================================================================
SLASH_LEGTRACKER1 = "/lt"
SlashCmdList["LEGTRACKER"] = function(msg)
  msg = (msg or ""):lower()
  if msg == "scan" then
    ScanAll()
    print(COL_BLUE .. "LegTracker" .. COL_RESET .. " Scan termine (compte complet).")
    if mainFrame and mainFrame:IsShown() then mainFrame:RefreshContent() end
    return
  end
  if msg == "reset" then
    if LegTrackerDB then LegTrackerDB.accountData = {} end
    print(COL_BLUE .. "LegTracker" .. COL_RESET .. " Donnees de compte reinitialises.")
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

    -- Ouverture automatique au login si l'option est active
    if LegTrackerDB.autoOpen and mainFrame then
      mainFrame:Show() ; mainFrame:RefreshContent() ; LegTrackerDB.open = true
    end

    print(COL_BLUE .. "LegTracker v6.0" .. COL_RESET
          .. " charge -- tapez " .. COL_GOLD .. "/lt" .. COL_RESET .. " pour ouvrir."
          .. " |cFF888888(/lt scan = forcer scan, /lt reset = reinit donnees compte)|r")

  elseif event == "BANKFRAME_OPENED" or event == "BANKFRAME_CLOSED" then
    -- Rescanner apres ouverture/fermeture banque (pour detecter items en banque)
    RequestRefresh(0.5)

  elseif event == "ADDON_LOADED" then
    -- ADDON_LOADED d'un autre addon : rien a faire (evite les rescans inutiles)

  else
    -- BAG_UPDATE_DELAYED, QUEST_TURNED_IN, QUEST_LOG_UPDATE,
    -- ACHIEVEMENT_EARNED, PLAYER_EQUIPMENT_CHANGED : rescan throttle
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
    mainFrame:Show()
    mainFrame:RefreshContent()
    LegTrackerDB.open = true
  end
end
