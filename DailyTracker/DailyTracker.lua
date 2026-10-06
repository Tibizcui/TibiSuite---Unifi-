-- ================================================================
-- DailyTracker
-- Auteur : Tibiscui - Kirin Tor
-- Pool de frames (anti-fuite) + refresh throttlé
-- Scroll réel, 10 langues (Locales.lua), suivi manuel PAR PERSONNAGE,
-- timers de reset, quêtes partagées / au choix comptées une fois,
-- renom réel, quêtes du monde en direct, vue Alts, liste « À faire »,
-- rappel avant reset, pont de données avec RenTracker.
-- ================================================================

local ADDON, NS = ...
ADDON = ADDON or "DailyTracker"
NS = NS or {}
DailyTrackerData = DailyTrackerData or {}

DailyTrackerDB = DailyTrackerDB or {
  pos           = {point="CENTER", x=0, y=0},
  open          = false,
  extension     = "Midnight",
  selectedFac   = nil,
  sections      = {weekly=true, daily=true, onetime=false},
  groups        = {principale=true, secondaire=true, pvp=false},
  mmAngle       = 220,
  filter        = "all",
  hideCompleted = false,
  manual        = {},
}

-- Textes d'interface : Locales.lua (charge avant ce fichier par le .toc).
-- Filet de securite si le fichier de langue manque (ancienne install) :
-- la cle elle-meme s'affiche au lieu d'une erreur Lua.
local L = NS.L or setmetatable({}, {__index=function(_, k) return k end})

local VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version"))
  or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "?"
local ACCENT_HEX  = "|cFF16C4FC"               -- cyan d'identite (logo #16C4FC)
local ACCENT      = {0.086, 0.769, 0.988}
local CURRENT_EXT = "Midnight"                 -- extension courante (badge, rappel, liste)

local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end

-- Libelles des groupes « au choix » (une seule quete du groupe par semaine).
local GROUP_LABELS = {
  runestones = "Renforcement des pierres runiques",
  pacts      = "Pacte des Fils Tranchés",
}

-- ================================================================
-- PERSONNAGE COURANT (suivi manuel et instantanes par perso)
-- DailyTrackerDB est partage par tout le compte : les coches manuelles
-- des quetes vivent donc sous chars[<Nom-Royaume>]. DailyTrackerDB.manual
-- ne garde que les entrees marquees warband=true dans les donnees.
-- ================================================================
local MY_KEY
local TEMP_CHAR = {manual={}, done={}}   -- avant PLAYER_LOGIN (nom inconnu)

local function CharData()
  if not MY_KEY then return TEMP_CHAR end
  DailyTrackerDB.chars = DailyTrackerDB.chars or {}
  local c = DailyTrackerDB.chars[MY_KEY]
  if not c then c = {}; DailyTrackerDB.chars[MY_KEY] = c end
  if type(c.manual) ~= "table" then c.manual = {} end
  if type(c.done)   ~= "table" then c.done   = {} end
  return c
end

local function InitCharacter()
  local name = UnitName and UnitName("player")
  local realm = GetRealmName and GetRealmName()
  if not name or name == "" or name == UNKNOWNOBJECT then return false end
  MY_KEY = name .. "-" .. (realm or "?")
  local c = CharData()
  c.name  = name
  c.realm = realm
  local _, classToken = UnitClass("player")
  c.class = classToken
  c.level = UnitLevel and UnitLevel("player") or c.level
  return true
end

-- ================================================================
-- DETECTION AUTO + RESET + SUIVI MANUEL
-- ================================================================
local function IsQuestDone(questID)
  if not questID then return false end
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    return C_QuestLog.IsQuestFlaggedCompleted(questID) == true
  end
  return IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(questID) == true or false
end

-- Secondes avant reset. Robuste si l'API manque.
local function SecUntilDailyReset()
  if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
    local ok,v = pcall(C_DateAndTime.GetSecondsUntilDailyReset)
    if ok and type(v)=="number" then return v end
  end
  return 0
end
local function SecUntilWeeklyReset()
  if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
    local ok,v = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
    if ok and type(v)=="number" then return v end
  end
  return 0
end

-- Cle de suivi manuel. Une quete partagee (shared=...) a UNE seule cle pour
-- toutes les factions : cochee une fois, elle l'est partout.
-- onetime -> true (permanent) ; daily/weekly -> timestamp d'expiration.
local function ManualKey(extKey, facName, quest)
  if quest.shared then return (extKey or "?").."::*"..quest.shared end
  return (extKey or "?").."::"..(facName or "?").."::"..(quest.name or "?")
end
local function ManualStore(quest)
  if quest.warband then
    if type(DailyTrackerDB.manual)~="table" then DailyTrackerDB.manual = {} end
    return DailyTrackerDB.manual
  end
  return CharData().manual
end
local function IsManualDone(extKey, fac, quest)
  local v = ManualStore(quest)[ManualKey(extKey, fac.name, quest)]
  if not v then return false end
  if quest.type=="onetime" then
    return v==true or type(v)=="number"
  end
  if type(v)=="number" then return time() < v end
  return v==true
end

-- Cache de completion : vide a chaque rafraichissement et a chaque
-- evenement de quete. Evite de reinterroger le client 4 fois par quete.
local doneCache = {}
local function InvalidateCache() wipe(doneCache) end

local function IsSingleDone(extKey, fac, q)
  if q.questID then return IsQuestDone(q.questID) end
  return IsManualDone(extKey, fac, q)
end

-- Completion unifiee : questID auto OU suivi manuel. Pour un groupe « au
-- choix » (group=...), la quete compte comme faite des qu'une du groupe l'est.
local function IsQuestComplete(extKey, fac, quest)
  local c = doneCache[quest]
  if c ~= nil then return c end
  local done
  if quest.group then
    done = false
    for _, o in ipairs(fac.quests or {}) do
      if o.group == quest.group and IsSingleDone(extKey, fac, o) then done = true; break end
    end
  else
    done = IsSingleDone(extKey, fac, quest)
  end
  doneCache[quest] = done
  return done
end

local RequestBackground   -- defini plus bas (badge, liste, instantane, rappel)

local function ToggleManual(extKey, fac, quest)
  local store = ManualStore(quest)
  local key = ManualKey(extKey, fac.name, quest)
  if IsManualDone(extKey, fac, quest) then
    store[key] = nil
  elseif quest.type=="onetime" then
    store[key] = true
  elseif quest.type=="weekly" then
    store[key] = time() + SecUntilWeeklyReset()
  else
    store[key] = time() + SecUntilDailyReset()
  end
  InvalidateCache()
  if RequestBackground then RequestBackground() end
end

-- Purge des completions manuelles expirees (compte + chaque personnage).
local function PurgeTable(db, now)
  for k,v in pairs(db) do
    if type(v)=="number" and now>=v then db[k]=nil end
  end
end
local function PurgeExpiredManual()
  if type(DailyTrackerDB.manual)~="table" then DailyTrackerDB.manual={} end
  local now = time()
  PurgeTable(DailyTrackerDB.manual, now)
  for _, c in pairs(DailyTrackerDB.chars or {}) do
    if type(c.manual)=="table" then PurgeTable(c.manual, now) end
  end
end

-- ================================================================
-- UNITES DE SUIVI : une quete partagee entre factions ou un groupe « au
-- choix » compte pour UNE activite (sinon le donjon hebdo comptait 4 fois
-- et les 4 Pierres-Runes, dont une seule est faisable, bloquaient a 1/4).
-- ================================================================
-- Cle stable : le questID quand il existe (un nom peut etre corrige ou
-- traduit sans casser les instantanes des Alts), sinon faction + nom.
local function UnitKey(extKey, fac, q)
  if q.shared then return extKey.."|s|"..q.shared end
  if q.group  then return extKey.."|g|"..tostring(fac.id or fac.name).."|"..q.group end
  if q.questID then return extKey.."|id|"..q.questID end
  return extKey.."|q|"..fac.name.."|"..q.name
end

-- ================================================================
-- NOMS DU CLIENT : pour une quete a questID, on affiche le titre que le jeu
-- connait, dans la langue du client (ex. « Nettoyage des caveaux » au lieu
-- de « Purging the Vaults »). Le nom des donnees sert de repli tant que le
-- serveur n'a pas envoye la quete, et reste la cle interne (recherche...).
-- ================================================================
local titleCache = {}
local function DisplayName(q)
  local id = q.questID
  if not id then return q.name end
  local t = titleCache[id]
  if t == nil and C_QuestLog and C_QuestLog.GetTitleForQuestID then
    local ok, v = pcall(C_QuestLog.GetTitleForQuestID, id)
    if ok and type(v) == "string" and v ~= "" then
      -- Certains titres portent le prefixe d'extension (« Midnight : Assaut
      -- de Fulgarion ») : on le retire. Recherche en mode texte brut, car le
      -- client FR met une espace insecable avant les deux-points.
      if v:sub(1, 8) == "Midnight" then
        local c = v:find(":", 9, true)
        if c and c <= 13 then v = v:sub(c + 1):gsub("^[ \194\160]+", "") end
      end
      t = v; titleCache[id] = v
    end
  end
  return t or q.name
end

local function UnitLabel(fac, q)
  if q.shared then return q.name end
  if q.group then return fac.name.." : "..(GROUP_LABELS[q.group] or q.name) end
  return fac.name.." : "..DisplayName(q)
end

-- ================================================================
-- CONSTANTES VISUELLES
-- ================================================================
local TYPE_COLORS = {
  weekly  = {r=0.30, g=0.60, b=1.00},
  onetime = {r=1.00, g=0.82, b=0.00},
  daily   = {r=0.30, g=0.85, b=0.30},
}
local TYPE_LABELS = {
  weekly  = L.TAG_WEEKLY,
  onetime = L.TAG_ONETIME,
  daily   = L.TAG_DAILY,
}
local EXT_TAB_COLORS = {
  Midnight     = {r=0.58, g=0.30, b=0.95},
  TheWarWithin = {r=0.58, g=0.50, b=1.00},
}
local EXT_LABELS    = {Midnight="MID", TheWarWithin="TWW"}
local EXT_FULLNAMES = {
  Midnight     = "Midnight",
  TheWarWithin = "The War Within",
}
local EXT_ORDER = {"Midnight","TheWarWithin"}

local CAT_DEFS = {
  {key="principale", label=L.CAT_PRINCIPALE, col={r=1.00,g=0.82,b=0.00}},
  {key="secondaire", label=L.CAT_SECONDAIRE, col={r=0.30,g=0.70,b=1.00}},
  {key="pvp",        label=L.CAT_PVP,         col={r=0.95,g=0.30,b=0.30}},
}
local GROUP_DEFAULTS = {principale=true, secondaire=true, pvp=false}

-- ================================================================
-- LAYOUT
-- ================================================================
local TAB_COL_W  = 70
local TAB_H      = 26
local TAB_GAP    = 2
local MARGIN_L   = 14
local MARGIN_R   = 14
local MARGIN_BOT = 18
local CX         = TAB_COL_W + MARGIN_L + 4
local H_TITLE    = 48
local H_FILTER   = 22
local Y_GROUPS   = H_TITLE + H_FILTER + 4
local W_MIN = 520 ; local W_MAX = 920
local H_MIN = 350 ; local H_MAX = 980
local MBAR_W = 56
local SB_W   = 14   -- largeur barre de defilement

-- ================================================================
-- HELPERS DONNEES
-- ================================================================
local function GetActiveFactions(extKey)
  local d = DailyTrackerData and DailyTrackerData[extKey or DailyTrackerDB.extension]
  return d and d.factions or {}
end

-- Listes triees par categorie, calculees une fois par extension (les
-- donnees sont statiques ; le pont RenTracker ne touche ni noms ni categories).
local catCache = {}
local function GetFactionsByCategory(cat, extKey)
  extKey = extKey or DailyTrackerDB.extension
  local ck = tostring(extKey).."|"..cat
  local cached = catCache[ck]
  if cached then return cached end
  local result = {}
  for _, fac in ipairs(GetActiveFactions(extKey)) do
    if (fac.category or "secondaire") == cat then table.insert(result,fac) end
  end
  table.sort(result, function(a,b) return a.name < b.name end)
  catCache[ck] = result
  return result
end

local function FindFaction(extKey, facName)
  for _, f in ipairs(GetActiveFactions(extKey)) do
    if f.name == facName then return f end
  end
end

local function GetSelectedFac()
  local sf = DailyTrackerDB.selectedFac
  if not sf then return nil, nil end
  return sf.cat, sf.name
end
local function SetSelectedFac(cat, name)
  DailyTrackerDB.selectedFac = {cat=cat, name=name}
end

-- Parcourt les unites de suivi d'une extension (dedoublonnees).
-- typ : "weekly" | "daily" | nil (= toutes sauf uniques). fn(key, fac, q)
local function ForEachUnit(extKey, typ, fn, onlyFac)
  local seen = {}
  local list = onlyFac and {onlyFac} or GetActiveFactions(extKey)
  for _, fac in ipairs(list) do
    for _, q in ipairs(fac.quests or {}) do
      local ok
      if typ then ok = (q.type == typ) else ok = (q.type ~= "onetime") end
      if ok then
        local k = UnitKey(extKey, fac, q)
        if not seen[k] then seen[k] = true; fn(k, fac, q) end
      end
    end
  end
end

local function GetFactionQuestStats(fac, extKey)
  extKey = extKey or DailyTrackerDB.extension
  local total, done = 0, 0
  ForEachUnit(extKey, nil, function(_, f, q)
    total = total + 1
    if IsQuestComplete(extKey, f, q) then done = done + 1 end
  end, fac)
  return done, total
end

local function GetExtStats(extKey, typ)
  extKey = extKey or DailyTrackerDB.extension
  local total, done = 0, 0
  ForEachUnit(extKey, typ, function(_, f, q)
    total = total + 1
    if IsQuestComplete(extKey, f, q) then done = done + 1 end
  end)
  return done, total
end

-- Activites restantes du personnage courant (liste « A faire », badge, rappel).
local function GetRemaining(extKey, withDaily)
  local out = {}
  local function add(_, f, q)
    if not IsQuestComplete(extKey, f, q) then out[#out+1] = {fac=f, q=q} end
  end
  ForEachUnit(extKey, "weekly", add)
  if withDaily then ForEachUnit(extKey, "daily", add) end
  return out
end

-- Format duree compacte "3j 5h" / "5h 12m" / "12m"
local function FormatDuration(sec)
  sec = math.max(0, math.floor(sec or 0))
  local d = math.floor(sec/86400)
  local h = math.floor((sec%86400)/3600)
  local m = math.floor((sec%3600)/60)
  if d>0 then return string.format(L.DUR_DH, d, h) end
  if h>0 then return string.format(L.DUR_HM, h, m) end
  return string.format(L.DUR_M, m)
end
local function FormatResetInfo()
  return string.format("|cFF888888%s:|r |cFFCCCCCC%s|r   |cFF888888%s:|r |cFFCCCCCC%s|r",
    L.RESET_DAILY,  FormatDuration(SecUntilDailyReset()),
    L.RESET_WEEKLY, FormatDuration(SecUntilWeeklyReset()))
end

-- Longueur en caracteres (et non en octets) d'une chaine UTF-8 : un accent
-- francais pese 2 octets et faussait l'auto-largeur de la fenetre.
local function Utf8Len(s)
  local _, n = tostring(s or ""):gsub("[^\128-\191]", "")
  return n
end

-- Valeurs « secretes » de Midnight (12.x) : illisibles par un addon dans
-- certains contextes. On les ignore au lieu de planter.
local function IsSecret(v)
  return issecretvalue and issecretvalue(v) or false
end

-- ================================================================
-- RENOM / AMITIE REELS (C_MajorFactions, C_GossipInfo)
-- Renvoie un texte court (colonne) et une ligne d'infobulle, ou nil.
-- ================================================================
local function GetStanding(fac)
  if not (fac and fac.id) then return nil end
  if fac.friendship then
    if not (C_GossipInfo and C_GossipInfo.GetFriendshipReputationRanks) then return nil end
    local ok, r = pcall(C_GossipInfo.GetFriendshipReputationRanks, fac.id)
    if not (ok and type(r)=="table" and r.maxLevel and not IsSecret(r.maxLevel) and r.maxLevel > 0) then return nil end
    local reaction = ""
    if C_GossipInfo.GetFriendshipReputation then
      local ok2, info = pcall(C_GossipInfo.GetFriendshipReputation, fac.id)
      if ok2 and type(info)=="table" and type(info.reaction)=="string" then reaction = info.reaction end
    end
    local cur = r.currentLevel or 0
    return string.format("%d/%d", cur, r.maxLevel), string.format(L.FRIEND_TIP, cur, r.maxLevel, reaction)
  end
  if not (C_MajorFactions and C_MajorFactions.GetMajorFactionData) then return nil end
  local ok, d = pcall(C_MajorFactions.GetMajorFactionData, fac.id)
  if not (ok and type(d)=="table" and d.renownLevel) or IsSecret(d.renownLevel) then return nil end
  local earned, thr = d.renownReputationEarned or 0, d.renownLevelThreshold or 0
  if IsSecret(earned) or IsSecret(thr) then earned, thr = 0, 0 end
  return string.format(L.RENOWN_SHORT, d.renownLevel), string.format(L.RENOWN_TIP, d.renownLevel, earned, thr)
end

-- ================================================================
-- QUETES DU MONDE EN DIRECT (C_TaskQuest) - cache 60 s par carte.
-- Le client ne connait parfois que les WQ des cartes proches : le compte
-- peut etre incomplet loin de la zone (signale dans l'infobulle).
-- ================================================================
local wqCache = {}
local function CountWorldQuests(mapID)
  if not (mapID and C_TaskQuest) then return nil end
  local now = GetTime()
  local c = wqCache[mapID]
  if c and now - c.t < 60 then return c.n end
  local fn = C_TaskQuest.GetQuestsOnMap or C_TaskQuest.GetQuestsForPlayerByMapID
  if not fn then return nil end
  local ok, list = pcall(fn, mapID)
  if not ok or type(list) ~= "table" then return nil end
  local n, seen = 0, {}
  local isWQ = C_QuestLog and C_QuestLog.IsWorldQuest
  for _, info in ipairs(list) do
    local id = type(info)=="table" and (info.questID or info.questId)
    if id and not seen[id] and (not isWQ or isWQ(id)) and not IsQuestDone(id) then
      seen[id] = true; n = n + 1
    end
  end
  wqCache[mapID] = {n=n, t=now}
  return n
end

-- ================================================================
-- POINT DE PASSAGE : TomTom s'il est installe, sinon le point natif de la
-- carte (C_Map.SetUserWaypoint + C_SuperTrack). Meme logique que RenTracker.
-- ================================================================
local function ParseCoords(s)
  local x, y = (s or ""):match("([%d%.]+)%s*,%s*([%d%.]+)")
  return tonumber(x), tonumber(y)
end

local function CanWaypoint(q)
  local x, y = ParseCoords(q.coords)
  return q.mapID and x and y and true or false
end

local function PlaceWaypoint(mapID, coords, title)
  local x, y = ParseCoords(coords)
  if not (mapID and x and y) then return false end
  if TomTom and TomTom.AddWaypoint then
    TomTom:AddWaypoint(mapID, x/100, y/100, {title=title, persistent=false})
    print(ACCENT_HEX.."DailyTracker|r "..string.format(L.WAYPOINT_SET, title or "", x, y))
    return true
  end
  if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return false end
  if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then return false end
  local ok = pcall(function()
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x/100, y/100))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
      C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
  end)
  if ok then print(ACCENT_HEX.."DailyTracker|r "..string.format(L.WAYPOINT_SET, title or "", x, y)) end
  return ok
end

-- ================================================================
-- PONT DE DONNEES AVEC RENTRACKER (synergie de suite)
-- RenTracker suit les memes factions et ses donnees sont souvent verifiees
-- en premier. Quand il est charge, on complete ICI ce qui nous manque
-- (ID de faction, questID, mapID) en appariant par ID de faction puis par
-- nom de quete normalise. On n'ecrase jamais une valeur deja presente :
-- une difference est seulement signalee par /dt check.
-- ================================================================
local function Norm(s)
  s = tostring(s or "")
  s = s:gsub("%s*%b()", "")
  local ui = _G.TibiMidnight
  if ui and ui.Normalize then s = ui.Normalize(s) else s = s:lower() end
  return (s:gsub("[^%w]", ""))
end

local bridge = {imported=0, diverge={}}
local function BridgeRenTracker()
  local R = _G.RenTrackerData
  if type(R) ~= "table" then return 0 end
  local n = 0
  for _, extKey in ipairs({"Midnight", "TheWarWithin"}) do
    local rext = R[extKey]
    if type(rext)=="table" and type(rext.factions)=="table" then
      local byId, byName = {}, {}
      for _, rf in ipairs(rext.factions) do
        if rf.id then byId[rf.id] = rf end
        if rf.name then byName[Norm(rf.name)] = rf end
      end
      for _, fac in ipairs(GetActiveFactions(extKey)) do
        local rf = (fac.id and byId[fac.id]) or byName[Norm(fac.name)]
        if rf then
          if not fac.id and rf.id then fac.id = rf.id; n = n + 1 end
          local rq = {}
          for _, q in ipairs(rf.quests or {}) do
            if q.name then rq[Norm(q.name)] = q end
          end
          for _, q in ipairs(fac.quests or {}) do
            local r = rq[Norm(q.name)]
            if r and r.type == q.type then
              if not q.questID and r.questID then q.questID = r.questID; q.fromRT = true; n = n + 1 end
              if not q.mapID and r.mapID then q.mapID = r.mapID end
              if q.questID and r.questID and q.questID ~= r.questID then
                bridge.diverge[#bridge.diverge+1] = string.format("%s : %s [%d] / RenTracker [%d]",
                  fac.name, q.name, q.questID, r.questID)
              end
            end
          end
        end
      end
    end
  end
  bridge.imported = n
  InvalidateCache()
  return n
end

-- ================================================================
-- FRAME PRINCIPALE
-- ================================================================
local mainFrame
local ToggleTodo, RefreshTodo, UpdateBadge   -- definis plus bas

local function BuildUI()

  mainFrame = CreateFrame("Frame","DTMainFrame",UIParent,"BackdropTemplate")
  mainFrame:SetSize(W_MIN, H_MIN)
  mainFrame:SetClipsChildren(false)
  mainFrame:SetFrameStrata("HIGH")
  mainFrame:SetMovable(true)
  mainFrame:EnableMouse(true)
  mainFrame:RegisterForDrag("LeftButton")
  mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
  mainFrame:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local point,_,_,x,y = s:GetPoint()
    DailyTrackerDB.pos = {point=point,x=x,y=y}
  end)
  -- Fermeture par Echap via UISpecialFrames (mecanisme natif Blizzard) :
  -- aucun code a nous ne s'execute en reaction a la touche, donc aucune
  -- interference possible avec un autre addon qui reagit lui aussi a Echap
  -- (piege reel confirme en jeu : ADDON_ACTION_FORBIDDEN sur SpellStopCasting
  -- / SpellStopTargeting quand deux addons interceptent Echap eux-memes).
  -- Necessaire ici pour le mode standalone (sans le core, qui fait deja ce
  -- meme enregistrement via WireEscapeFor en mode integre - doublon sans
  -- risque, UISpecialFrames tolere les entrees redondantes).
  tinsert(UISpecialFrames, "DTMainFrame")
  mainFrame:SetBackdrop({
    bgFile="Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=true,tileSize=32,edgeSize=32,
    insets={left=11,right=12,top=12,bottom=11},
  })
  mainFrame:SetBackdropColor(0.04,0.02,0.06,0.97)
  mainFrame:SetBackdropBorderColor(0.72,0.60,0.28,1.0)
  -- Habillage du socle applique tout de suite (sinon la fenetre rouverte au
  -- login s'affichait 1 a 3 s avec l'ancien cadre dore avant _Suite.lua).
  do
    local ui = _G.TibiMidnight
    if ui and ui.SkinFrame then ui.SkinFrame(mainFrame, ACCENT); mainFrame._tibiSkinned = true end
  end

  -- ----------------------------------------------------------
  -- TITRE (en-tete TibiSuite : titre a l'interieur, haut-gauche,
  -- comme WeeklyCompass). L'ancien bandeau flottant a ete retire.
  -- ----------------------------------------------------------
  local titleStr = mainFrame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  titleStr:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 16, -14)
  titleStr:SetText(ACCENT_HEX.."DailyTracker|r")
  mainFrame._titleStr = titleStr

  local closeBtn = CreateFrame("Button",nil,mainFrame,"UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT",-5,-5)
  closeBtn:SetScript("OnClick",function()
    mainFrame:Hide(); DailyTrackerDB.open=false
  end)

  local drag = mainFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  drag:SetPoint("TOP",0,-30)
  drag:SetText("|cFF888888"..L.DRAG_HINT.."|r")

  -- Separateur dore sous titre
  local sepTop = mainFrame:CreateTexture(nil,"ARTWORK")
  sepTop:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepTop:SetPoint("TOPLEFT",  MARGIN_L, -44)
  sepTop:SetPoint("TOPRIGHT",-MARGIN_R, -44)
  sepTop:SetHeight(1)
  sepTop:SetVertexColor(0.72,0.60,0.28,0.9)

  -- ----------------------------------------------------------
  -- BARRE FILTRES + toggles (evolutions 3 et 4)
  -- ----------------------------------------------------------
  local filterDefs = {
    {key="all",     lbl=L.F_ALL,     col={r=0.85,g=0.85,b=0.85}},
    {key="weekly",  lbl=L.F_WEEKLY,  col={r=0.30,g=0.60,b=1.00}},
    {key="daily",   lbl=L.F_DAILY,   col={r=0.30,g=0.85,b=0.30}},
    {key="onetime", lbl=L.F_ONETIME, col={r=1.00,g=0.82,b=0.00}},
  }

  local filterBarBg = CreateFrame("Frame",nil,mainFrame,"BackdropTemplate")
  filterBarBg:SetPoint("TOPLEFT",  CX,       -46)
  filterBarBg:SetPoint("TOPRIGHT",-MARGIN_R, -46)
  filterBarBg:SetHeight(H_FILTER)
  filterBarBg:SetBackdrop({
    bgFile="Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true,tileSize=8,edgeSize=6,
    insets={left=2,right=2,top=2,bottom=2},
  })
  filterBarBg:SetBackdropColor(0.04,0.02,0.08,0.90)
  filterBarBg:SetBackdropBorderColor(0.72,0.60,0.28,0.45)

  local filterBtns = {}
  local fBtnW = 62 ; local fBtnH = H_FILTER-4 ; local fBtnX = 4

  for _, fd in ipairs(filterDefs) do
    local btn = CreateFrame("Button",nil,filterBarBg,"BackdropTemplate")
    btn:SetPoint("LEFT",filterBarBg,"LEFT",fBtnX,0)
    btn:SetSize(fBtnW,fBtnH)
    btn:SetBackdrop({
      bgFile="Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
      tile=true,tileSize=8,edgeSize=6,
      insets={left=2,right=2,top=2,bottom=2},
    })
    local acc = btn:CreateTexture(nil,"OVERLAY")
    acc:SetPoint("TOPLEFT",   btn,"TOPLEFT",  2,-2)
    acc:SetPoint("BOTTOMLEFT",btn,"BOTTOMLEFT",2, 2)
    acc:SetWidth(3) ; acc:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    acc:SetVertexColor(fd.col.r,fd.col.g,fd.col.b,0.5)
    btn.accent = acc
    local lTxt = btn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lTxt:SetPoint("CENTER",btn,"CENTER",2,0)
    lTxt:SetText(string.format("|cFF%02X%02X%02X%s|r",
      math.floor(fd.col.r*255),math.floor(fd.col.g*255),math.floor(fd.col.b*255),fd.lbl))
    btn.col=fd.col ; btn.filterKey=fd.key
    filterBtns[fd.key]=btn
    fBtnX = fBtnX+fBtnW+2
    local capturedKey=fd.key
    btn:SetScript("OnClick",function()
      DailyTrackerDB.filter=capturedKey ; mainFrame:RefreshContent()
    end)
    btn:SetScript("OnEnter",function(s) s:SetBackdropBorderColor(fd.col.r,fd.col.g,fd.col.b,0.9) end)
    btn:SetScript("OnLeave",function(s)
      if DailyTrackerDB.filter~=capturedKey then
        s:SetBackdropBorderColor(fd.col.r*0.35,fd.col.g*0.35,fd.col.b*0.35,0.5) end
    end)
  end
  mainFrame.filterBtns = filterBtns

  -- Toggle "A faire" (masquer completees) - evolution 4
  local todoCol = {r=0.55,g=0.90,b=0.65}
  local todoBtn = CreateFrame("Button",nil,filterBarBg,"BackdropTemplate")
  todoBtn:SetPoint("RIGHT",filterBarBg,"RIGHT",-4,0)
  todoBtn:SetSize(56,fBtnH)
  todoBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=6,insets={left=2,right=2,top=2,bottom=2}})
  local todoTxt = todoBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  todoTxt:SetPoint("CENTER",todoBtn,"CENTER",0,0)
  todoTxt:SetText(string.format("|cFF%02X%02X%02X%s|r",math.floor(todoCol.r*255),math.floor(todoCol.g*255),math.floor(todoCol.b*255),L.TODO))
  todoBtn.col=todoCol
  todoBtn:SetScript("OnClick",function() DailyTrackerDB.hideCompleted=not DailyTrackerDB.hideCompleted; mainFrame:RefreshContent() end)
  todoBtn:SetScript("OnEnter",function(s) s:SetBackdropBorderColor(todoCol.r,todoCol.g,todoCol.b,0.9) end)
  todoBtn:SetScript("OnLeave",function(s)
    if not DailyTrackerDB.hideCompleted then s:SetBackdropBorderColor(todoCol.r*0.35,todoCol.g*0.35,todoCol.b*0.35,0.5) end
  end)
  mainFrame._todoBtn = todoBtn

  -- Toggle "Reduire tout / Deployer tout" - evolution 3
  local caCol = {r=0.80,g=0.75,b=0.55}
  local collapseBtn = CreateFrame("Button",nil,filterBarBg,"BackdropTemplate")
  collapseBtn:SetPoint("RIGHT",todoBtn,"LEFT",-4,0)
  collapseBtn:SetSize(80,fBtnH)
  collapseBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=6,insets={left=2,right=2,top=2,bottom=2}})
  collapseBtn:SetBackdropColor(0.08,0.06,0.10,0.95)
  local collapseTxt = collapseBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  collapseTxt:SetPoint("CENTER",collapseBtn,"CENTER",0,0)
  collapseBtn.col=caCol
  collapseBtn._txt=collapseTxt
  collapseBtn:SetScript("OnClick",function()
    local s=DailyTrackerDB.sections
    local allOpen = s.weekly and s.onetime and s.daily
    local nv = not allOpen
    s.weekly=nv; s.onetime=nv; s.daily=nv
    mainFrame:RefreshContent()
  end)
  collapseBtn:SetScript("OnEnter",function(s) s:SetBackdropBorderColor(caCol.r,caCol.g,caCol.b,0.9) end)
  collapseBtn:SetScript("OnLeave",function(s) s:SetBackdropBorderColor(caCol.r*0.35,caCol.g*0.35,caCol.b*0.35,0.5) end)
  mainFrame._collapseBtn = collapseBtn

  -- Separateur dore sous barre filtre
  local sepFilt = mainFrame:CreateTexture(nil,"ARTWORK")
  sepFilt:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepFilt:SetPoint("TOPLEFT",  CX,       -(46+H_FILTER+2))
  sepFilt:SetPoint("TOPRIGHT",-MARGIN_R, -(46+H_FILTER+2))
  sepFilt:SetHeight(1)
  sepFilt:SetVertexColor(0.72,0.60,0.28,0.45)

  -- ----------------------------------------------------------
  -- COLONNE GAUCHE
  -- ----------------------------------------------------------
  local tabColBg = CreateFrame("Frame",nil,mainFrame,"BackdropTemplate")
  tabColBg:SetPoint("TOPLEFT",  MARGIN_L,-50)
  tabColBg:SetPoint("BOTTOMLEFT",mainFrame,"BOTTOMLEFT",MARGIN_L,MARGIN_BOT)
  tabColBg:SetWidth(TAB_COL_W)
  tabColBg:SetBackdrop({
    bgFile="Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true,tileSize=8,edgeSize=6,
    insets={left=2,right=2,top=2,bottom=2},
  })
  tabColBg:SetBackdropColor(0.02,0.01,0.04,0.85)
  tabColBg:SetBackdropBorderColor(0.72,0.60,0.28,0.35)

  local extBtns = {}
  local extTabStartY = -58

  for idx, extKey in ipairs(EXT_ORDER) do
    local col  = EXT_TAB_COLORS[extKey] or {r=0.5,g=0.5,b=0.5}
    local yOff = extTabStartY-(idx-1)*(TAB_H+TAB_GAP)
    local eb   = CreateFrame("Button",nil,mainFrame,"BackdropTemplate")
    eb:SetPoint("TOPLEFT",MARGIN_L+2,yOff)
    eb:SetSize(TAB_COL_W-4,TAB_H)
    eb:SetBackdrop({
      bgFile="Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
      tile=true,tileSize=8,edgeSize=6,
      insets={left=2,right=2,top=2,bottom=2},
    })
    eb:SetBackdropColor(col.r*0.12,col.g*0.12,col.b*0.12,0.95)
    eb:SetBackdropBorderColor(col.r*0.35,col.g*0.35,col.b*0.35,0.5)
    local accent = eb:CreateTexture(nil,"OVERLAY")
    accent:SetPoint("TOPLEFT",   eb,"TOPLEFT",  2,-2)
    accent:SetPoint("BOTTOMLEFT",eb,"BOTTOMLEFT",2, 2)
    accent:SetWidth(3) ; accent:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    accent:SetVertexColor(col.r,col.g,col.b,0.5)
    local eTxt = eb:CreateFontString(nil,"OVERLAY","GameFontNormal")
    eTxt:SetPoint("CENTER",eb,"CENTER",2,0)
    eTxt:SetSize(TAB_COL_W-10,TAB_H-4)
    eTxt:SetText(string.format("|cFF%02X%02X%02X%s|r",
      math.floor(col.r*255),math.floor(col.g*255),math.floor(col.b*255),EXT_LABELS[extKey]))
    eTxt:SetWordWrap(false) ; eTxt:SetJustifyH("CENTER")
    eb.accent=accent ; eb.extKey=extKey ; eb.col=col
    local capturedKey=extKey
    eb:SetScript("OnClick",function()
      DailyTrackerDB.extension=capturedKey
      DailyTrackerDB.selectedFac=nil
      DailyTrackerDB.view=nil
      mainFrame:RefreshContent()
    end)
    eb:SetScript("OnEnter",function(s)
      GameTooltip:SetOwner(s,"ANCHOR_RIGHT")
      GameTooltip:AddLine(EXT_FULLNAMES[capturedKey],col.r,col.g,col.b)
      local d,t=GetExtStats(capturedKey)
      GameTooltip:AddLine(string.format(L.ACT_COUNT,d,t),0.75,0.75,0.75)
      GameTooltip:Show()
    end)
    eb:SetScript("OnLeave",function() GameTooltip:Hide() end)
    table.insert(extBtns,eb)
  end
  mainFrame.extBtns = extBtns

  -- Onglets de vue : ALTS (tous les personnages) et LISTE (liste compacte
  -- « A faire » a l'ecran). Meme habillage que les onglets d'extension.
  local function MakeSideTab(idx, label, col, onClick, tipTitle, tipBody)
    local yOff = extTabStartY-(idx-1)*(TAB_H+TAB_GAP) - 8
    local b = CreateFrame("Button",nil,mainFrame,"BackdropTemplate")
    b:SetPoint("TOPLEFT",MARGIN_L+2,yOff)
    b:SetSize(TAB_COL_W-4,TAB_H)
    b:SetBackdrop({
      bgFile="Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
      tile=true,tileSize=8,edgeSize=6,
      insets={left=2,right=2,top=2,bottom=2},
    })
    local accent = b:CreateTexture(nil,"OVERLAY")
    accent:SetPoint("TOPLEFT",   b,"TOPLEFT",  2,-2)
    accent:SetPoint("BOTTOMLEFT",b,"BOTTOMLEFT",2, 2)
    accent:SetWidth(3) ; accent:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    local t = b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    t:SetPoint("CENTER",b,"CENTER",2,0)
    t:SetText(string.format("|cFF%02X%02X%02X%s|r",
      math.floor(col.r*255),math.floor(col.g*255),math.floor(col.b*255),label))
    b.accent=accent ; b.col=col
    b:SetScript("OnClick",onClick)
    b:SetScript("OnEnter",function(s)
      GameTooltip:SetOwner(s,"ANCHOR_RIGHT")
      GameTooltip:AddLine(tipTitle,col.r,col.g,col.b)
      GameTooltip:AddLine(tipBody,0.8,0.8,0.8,true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return b
  end
  local nExt = #EXT_ORDER
  mainFrame._altsBtn = MakeSideTab(nExt+1, L.TAB_ALTS, {r=0.95,g=0.75,b=0.35}, function()
    DailyTrackerDB.view = (DailyTrackerDB.view=="alts") and nil or "alts"
    mainFrame._scrollOffset = 0
    mainFrame:RefreshContent()
  end, L.ALTS_TITLE, L.ALTS_TAB_TIP)
  mainFrame._listBtn = MakeSideTab(nExt+2, L.TAB_LIST, {r=0.55,g=0.90,b=0.65}, function()
    if ToggleTodo then ToggleTodo() end
    mainFrame:RefreshContent()
  end, L.TODO_TITLE, L.LIST_TAB_TIP)

  local sepVert = mainFrame:CreateTexture(nil,"ARTWORK")
  sepVert:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepVert:SetPoint("TOPLEFT",   CX-2,-50)
  sepVert:SetPoint("BOTTOMLEFT",CX-2, MARGIN_BOT)
  sepVert:SetWidth(1)
  sepVert:SetVertexColor(0.72,0.60,0.28,0.55)

  -- ----------------------------------------------------------
  -- BLOC QUETES : elements statiques
  -- ----------------------------------------------------------
  local questHeader = mainFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
  mainFrame._questHeader = questHeader

  -- Compteur global (evolution 2)
  local counter = mainFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  counter:SetJustifyH("RIGHT")
  mainFrame._counter = counter

  local legend = mainFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  mainFrame._legend = legend
  legend:SetJustifyH("LEFT") ; legend:SetWordWrap(false)
  legend:SetText(string.format("|cFF4D99FF%s|r  |cFFFFCC00%s|r  |cFF4DCC4D%s|r",
    L.TAG_WEEKLY, L.TAG_ONETIME, L.TAG_DAILY))

  -- Timers de reset (evolution 6)
  local resetInfo = mainFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  resetInfo:SetJustifyH("RIGHT")
  mainFrame._resetInfo = resetInfo

  -- ----------------------------------------------------------
  -- ZONE DEFILANTE (evolution 1) : scrollBg (cadre) + ScrollFrame + child + barre
  -- ----------------------------------------------------------
  local scrollBg = CreateFrame("Frame",nil,mainFrame,"BackdropTemplate")
  scrollBg:SetBackdrop({
    bgFile="Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true,tileSize=8,edgeSize=8,
    insets={left=3,right=3,top=3,bottom=3},
  })
  scrollBg:SetBackdropColor(0.02,0.01,0.04,0.5)
  scrollBg:SetBackdropBorderColor(0.5,0.45,0.25,0.5)
  mainFrame.scrollBg = scrollBg

  local scrollFrame = CreateFrame("ScrollFrame",nil,scrollBg)
  scrollFrame:SetPoint("TOPLEFT",scrollBg,"TOPLEFT",6,-6)
  mainFrame.scrollFrame = scrollFrame

  local questContent = CreateFrame("Frame",nil,scrollFrame)
  questContent:SetSize(10,10)
  scrollFrame:SetScrollChild(questContent)
  mainFrame.questContent = questContent

  -- Barre de defilement
  local scrollBar = CreateFrame("Slider",nil,scrollBg)
  scrollBar:SetOrientation("VERTICAL")
  scrollBar:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
  local thumb = scrollBar:GetThumbTexture()
  thumb:SetSize(SB_W-6,26) ; thumb:SetVertexColor(0.72,0.60,0.28,0.9)
  local sbTrack = scrollBar:CreateTexture(nil,"BACKGROUND")
  sbTrack:SetAllPoints(scrollBar) ; sbTrack:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sbTrack:SetVertexColor(0.10,0.08,0.14,0.6)
  scrollBar:SetValueStep(1) ; scrollBar:SetObeyStepOnDrag(true)
  scrollBar:SetScript("OnValueChanged",function(_,val)
    scrollFrame:SetVerticalScroll(val) ; mainFrame._scrollOffset=val
  end)
  mainFrame.scrollBar = scrollBar

  scrollFrame:EnableMouseWheel(true)
  scrollFrame:SetScript("OnMouseWheel",function(_,delta)
    local maxv = mainFrame._scrollMax or 0
    local cur  = mainFrame._scrollOffset or 0
    local nv   = math.max(0, math.min(maxv, cur - delta*30))
    mainFrame._scrollOffset = nv
    scrollFrame:SetVerticalScroll(nv)
    if scrollBar then scrollBar:SetValue(nv) end
  end)

  -- ============================================================
  -- POOL DE FRAMES REUTILISABLES (anti-fuite memoire)
  -- ============================================================
  local BD_EDGE6 = {bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=6,insets={left=2,right=2,top=2,bottom=2}}
  local BD_EDGE5 = {bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=5,insets={left=1,right=1,top=1,bottom=1}}

  local function MakeSep()
    local t = mainFrame:CreateTexture(nil,"ARTWORK")
    t:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    return t
  end

  local function MakeGroupHeader()
    local gh = CreateFrame("Button",nil,mainFrame,"BackdropTemplate")
    gh:SetBackdrop(BD_EDGE6)
    gh.arrow = gh:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    gh.arrow:SetPoint("LEFT",gh,"LEFT",6,0)
    gh.label = gh:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    gh.label:SetPoint("LEFT",gh,"LEFT",18,0)
    gh.badge = gh:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    gh.badge:SetPoint("RIGHT",gh,"RIGHT",-6,0)
    gh:SetScript("OnClick",function(s)
      DailyTrackerDB.groups[s._cat] = not DailyTrackerDB.groups[s._cat]
      mainFrame:RefreshContent()
    end)
    gh:SetScript("OnEnter",function(s) local c=s._col; s:SetBackdropBorderColor(c.r,c.g,c.b,1.0) end)
    gh:SetScript("OnLeave",function(s) local c=s._col; s:SetBackdropBorderColor(c.r*0.55,c.g*0.55,c.b*0.55,0.9) end)
    return gh
  end

  local function MakeFactionRow()
    local row = CreateFrame("Button",nil,mainFrame,"BackdropTemplate")
    row:SetBackdrop(BD_EDGE5)
    row.dot = row:CreateTexture(nil,"OVERLAY")
    row.dot:SetPoint("LEFT",row,"LEFT",5,0) ; row.dot:SetSize(5,5)
    row.dot:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    row.nameFS = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.nameFS:SetPoint("LEFT",row,"LEFT",14,0)
    row.nameFS:SetPoint("RIGHT",row,"RIGHT",-142,0)
    row.nameFS:SetJustifyH("LEFT") ; row.nameFS:SetWordWrap(false)
    -- Renom / rang d'amitie reel (lu dans le jeu, pas dans nos donnees)
    row.renFS = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.renFS:SetPoint("RIGHT",row,"RIGHT",-104,0) ; row.renFS:SetWidth(36) ; row.renFS:SetJustifyH("RIGHT")
    row.mbarBg = row:CreateTexture(nil,"ARTWORK")
    row.mbarBg:SetPoint("RIGHT",row,"RIGHT",-44,0) ; row.mbarBg:SetSize(MBAR_W,5)
    row.mbarBg:SetTexture("Interface\\BUTTONS\\WHITE8X8") ; row.mbarBg:SetVertexColor(0.08,0.06,0.12,0.9)
    row.mbarFill = row:CreateTexture(nil,"OVERLAY")
    row.mbarFill:SetPoint("LEFT",row.mbarBg,"LEFT",0,0) ; row.mbarFill:SetHeight(5)
    row.mbarFill:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    row.lvlFS = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.lvlFS:SetPoint("RIGHT",row,"RIGHT",-4,0) ; row.lvlFS:SetWidth(38) ; row.lvlFS:SetJustifyH("RIGHT")
    row:SetScript("OnClick",function(s) SetSelectedFac(s._cat,s._facName); mainFrame:RefreshContent() end)
    row:SetScript("OnEnter",function(s)
      local c=s._col
      s:SetBackdropBorderColor(c.r*0.7,c.g*0.7,c.b*0.7,1.0)
      GameTooltip:SetOwner(s,"ANCHOR_RIGHT")
      GameTooltip:AddLine(s._facName,c.r,c.g,c.b)
      GameTooltip:AddLine(L.ZONE..(s._zone or ""),0.8,0.8,0.8)
      if s._standTip then GameTooltip:AddLine(s._standTip,0.95,0.85,0.45) end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave",function(s)
      GameTooltip:Hide()
      if not s._selected then local c=s._col; s:SetBackdropBorderColor(c.r*0.20,c.g*0.20,c.b*0.20,0.7) end
    end)
    return row
  end

  local function MakeQuestHeader()
    local header = CreateFrame("Button",nil,mainFrame.questContent,"BackdropTemplate")
    header:SetBackdrop(BD_EDGE6)
    header.arrow = header:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    header.arrow:SetPoint("LEFT",header,"LEFT",8,0)
    header.label = header:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    header.label:SetPoint("LEFT",header,"LEFT",24,0)
    header:SetScript("OnClick",function(s)
      DailyTrackerDB.sections[s._sectionKey]=not DailyTrackerDB.sections[s._sectionKey]
      mainFrame:RefreshContent()
    end)
    header:SetScript("OnEnter",function(s) local c=s._tc; s:SetBackdropBorderColor(c.r,c.g,c.b,0.9) end)
    header:SetScript("OnLeave",function(s) local c=s._tc; s:SetBackdropBorderColor(c.r*0.5,c.g*0.5,c.b*0.5,0.7) end)
    return header
  end

  local function MakeQuestRow()
    local row = CreateFrame("Button",nil,mainFrame.questContent,"BackdropTemplate")
    row:SetBackdrop(BD_EDGE6)
    row.si = row:CreateTexture(nil,"OVERLAY")
    row.si:SetPoint("TOPLEFT",row,"TOPLEFT",5,-7) ; row.si:SetSize(12,12)
    row.typeTag = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.typeTag:SetPoint("TOPLEFT",row,"TOPLEFT",22,-6)
    -- Etiquette auto (quetes avec questID)
    row.autoLabel = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.autoLabel:SetPoint("TOPRIGHT",row,"TOPRIGHT",-6,-6)
    -- Bouton de suivi manuel (quetes sans questID) - evolution 5
    row.manualBtn = CreateFrame("Button",nil,row)
    row.manualBtn:SetPoint("TOPRIGHT",row,"TOPRIGHT",-6,-4)
    row.manualBtn:SetSize(58,14)
    row.manualBtn._txt = row.manualBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.manualBtn._txt:SetPoint("RIGHT",row.manualBtn,"RIGHT",0,0)
    row.manualBtn:SetScript("OnClick",function(s)
      ToggleManual(s._ext, s._fac, s._quest)
      mainFrame:RefreshContent()
    end)
    row.manualBtn:SetScript("OnEnter",function(s)
      GameTooltip:SetOwner(s,"ANCHOR_TOPRIGHT")
      GameTooltip:AddLine(L.MANUAL_HINT,0.9,0.9,0.9) ; GameTooltip:Show()
    end)
    row.manualBtn:SetScript("OnLeave",function() GameTooltip:Hide() end)
    row.qName = row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    row.qName:SetPoint("TOPLEFT",row,"TOPLEFT",22,-18) ; row.qName:SetJustifyH("LEFT")
    row.npcStr = row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    row.npcStr:SetPoint("TOPLEFT",row,"TOPLEFT",22,-32) ; row.npcStr:SetJustifyH("LEFT")
    row.repStr = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.repStr:SetPoint("TOPLEFT",row,"TOPLEFT",22,-44) ; row.repStr:SetJustifyH("LEFT")
    row.zStr = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.zStr:SetPoint("TOPRIGHT",row,"TOPRIGHT",-6,-44) ; row.zStr:SetJustifyH("RIGHT")
    row.tipStr = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.tipStr:SetPoint("TOPLEFT",row,"TOPLEFT",22,-58) ; row.tipStr:SetJustifyH("LEFT") ; row.tipStr:SetWordWrap(true)
    row:EnableMouse(true)
    row:SetScript("OnEnter",function(s)
      local tc=s._tc ; local quest=s._quest ; local done=s._done
      s:SetBackdropBorderColor(tc.r,tc.g,tc.b,done and 0.5 or 0.9)
      GameTooltip:SetOwner(s,"ANCHOR_BOTTOMRIGHT")
      GameTooltip:AddLine(DisplayName(quest),1,1,1)
      if quest.questID then
        if done then GameTooltip:AddLine(L.DONE.." (ID: "..quest.questID..")",0.3,0.9,0.4)
        else GameTooltip:AddLine(L.NOTDONE.." (ID: "..quest.questID..")",0.8,0.5,0.3) end
      else GameTooltip:AddLine(L.NO_QUESTID,0.5,0.5,0.7) end
      if quest.fromRT then GameTooltip:AddLine(L.FROM_RT,0.5,0.7,0.9) end
      GameTooltip:AddLine(L.ZONE..quest.zone,0.7,0.7,0.7)
      GameTooltip:AddLine("+"..(quest.rep or 0)..L.REP_SUFFIX,tc.r,tc.g,tc.b)
      if quest.shared then GameTooltip:AddLine(L.SHARED_HINT,0.6,0.8,1.0,true) end
      if quest.group then GameTooltip:AddLine(L.GROUP_HINT,0.6,0.8,1.0,true) end
      if s._wq then GameTooltip:AddLine(L.WQ_HINT,0.6,0.6,0.6,true) end
      if s._tipText~="" then GameTooltip:AddLine(" "); GameTooltip:AddLine(s._tipText,0.8,0.8,0.8,true) end
      if CanWaypoint(quest) then GameTooltip:AddLine("|cFFFFD700"..L.WAYPOINT_HINT.."|r") end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave",function(s)
      GameTooltip:Hide()
      if s._done then s:SetBackdropBorderColor(0.3,0.3,0.3,0.4)
      else local tc=s._tc; s:SetBackdropBorderColor(tc.r*0.4,tc.g*0.4,tc.b*0.4,0.6) end
    end)
    row:SetScript("OnClick",function(s)
      local facRef=s._fac ; local quest=s._quest
      if (facRef and facRef.id) and C_Reputation and C_Reputation.SetWatchedFactionByID then
        C_Reputation.SetWatchedFactionByID(facRef.id)
      end
      if CanWaypoint(quest) then PlaceWaypoint(quest.mapID, quest.coords, DisplayName(quest)) end
    end)
    return row
  end

  -- Ligne de la vue Alts (un personnage)
  local function MakeAltRow()
    local row = CreateFrame("Button",nil,mainFrame.questContent,"BackdropTemplate")
    row:SetBackdrop(BD_EDGE6)
    row:RegisterForClicks("AnyUp")
    row.nameFS = row:CreateFontString(nil,"OVERLAY","GameFontNormal")
    row.nameFS:SetPoint("TOPLEFT",row,"TOPLEFT",10,-6) ; row.nameFS:SetJustifyH("LEFT")
    row.seenFS = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.seenFS:SetPoint("TOPRIGHT",row,"TOPRIGHT",-8,-7) ; row.seenFS:SetJustifyH("RIGHT")
    row.lineFS = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.lineFS:SetPoint("TOPLEFT",row,"TOPLEFT",10,-22) ; row.lineFS:SetJustifyH("LEFT")
    row.barBg = row:CreateTexture(nil,"ARTWORK")
    row.barBg:SetPoint("TOPRIGHT",row,"TOPRIGHT",-8,-26) ; row.barBg:SetSize(90,5)
    row.barBg:SetTexture("Interface\\BUTTONS\\WHITE8X8") ; row.barBg:SetVertexColor(0.08,0.06,0.12,0.9)
    row.barFill = row:CreateTexture(nil,"OVERLAY")
    row.barFill:SetPoint("LEFT",row.barBg,"LEFT",0,0) ; row.barFill:SetHeight(5)
    row.barFill:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    row:SetScript("OnEnter",function(s)
      s:SetBackdropBorderColor(0.95,0.75,0.35,0.9)
      GameTooltip:SetOwner(s,"ANCHOR_RIGHT")
      GameTooltip:AddLine(s._title or "",1,1,1)
      if s._stale then GameTooltip:AddLine(L.ALTS_RESET_PASSED,0.9,0.6,0.3,true) end
      if s._remaining and #s._remaining>0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.ALTS_REMAINING,1,0.82,0)
        for i, lbl in ipairs(s._remaining) do
          if i>18 then GameTooltip:AddLine(string.format(L.TODO_MORE, #s._remaining-18),0.6,0.6,0.6); break end
          GameTooltip:AddLine("- "..lbl,0.85,0.85,0.85)
        end
      else
        GameTooltip:AddLine(L.ALTS_ALLDONE,0.3,0.9,0.45)
      end
      if not s._isMe then GameTooltip:AddLine(" "); GameTooltip:AddLine(L.ALTS_DEL_HINT,0.6,0.6,0.6) end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave",function(s)
      GameTooltip:Hide()
      s:SetBackdropBorderColor(0.45,0.35,0.18,0.6)
    end)
    row:SetScript("OnClick",function(s, button)
      if button=="RightButton" and IsShiftKeyDown() and not s._isMe and s._key then
        if DailyTrackerDB.chars then DailyTrackerDB.chars[s._key] = nil end
        GameTooltip:Hide()
        mainFrame:RefreshContent()
      end
    end)
    return row
  end

  local WIDGET_FACTORY = {
    sep         = MakeSep,
    groupHeader = MakeGroupHeader,
    factionRow  = MakeFactionRow,
    questHeader = MakeQuestHeader,
    questRow    = MakeQuestRow,
    altRow      = MakeAltRow,
  }

  mainFrame._pools    = {}
  mainFrame._poolUsed = {}
  local function AcquireWidget(kind)
    local pools = mainFrame._pools
    local used  = mainFrame._poolUsed
    if not pools[kind] then pools[kind] = {} ; used[kind] = 0 end
    local i = used[kind] + 1
    used[kind] = i
    local w = pools[kind][i]
    if not w then w = WIDGET_FACTORY[kind]() ; pools[kind][i] = w end
    w:ClearAllPoints()
    w:Show()
    return w
  end
  local function ResetPools()
    for kind, list in pairs(mainFrame._pools) do
      for _, w in ipairs(list) do w:Hide() end
      mainFrame._poolUsed[kind] = 0
    end
  end

  -- ----------------------------------------------------------
  -- GROUPES PLIABLES (evolution 7 : categories vides masquees)
  -- ----------------------------------------------------------
  local function RebuildGroups(startY)
    if not DailyTrackerDB.groups then
      DailyTrackerDB.groups={principale=true,secondaire=true,pvp=false}
    end
    local extKey = DailyTrackerDB.extension
    local selCat,selName = GetSelectedFac()
    local curY = startY
    local ROW_H=20 ; local ROW_GAP=1 ; local GH_H=20

    for _, cd in ipairs(CAT_DEFS) do
      local cat      = cd.key
      local factions = GetFactionsByCategory(cat)
      local nbFac    = #factions

      -- evolution 7 : on saute completement une categorie sans faction
      if nbFac>0 then
        local isOpen   = DailyTrackerDB.groups[cat]
        if isOpen==nil then isOpen=GROUP_DEFAULTS[cat] end
        local col=cd.col
        local r8=math.floor(col.r*255) ; local g8=math.floor(col.g*255) ; local b8=math.floor(col.b*255)

        local gh = AcquireWidget("groupHeader")
        gh:SetPoint("TOPLEFT", CX,       -curY)
        gh:SetPoint("TOPRIGHT",-MARGIN_R,-curY)
        gh:SetHeight(GH_H)
        gh:SetBackdropColor(col.r*0.18,col.g*0.18,col.b*0.18,1.0)
        gh:SetBackdropBorderColor(col.r*0.55,col.g*0.55,col.b*0.55,0.9)
        gh.arrow:SetText(isOpen and "|cFF888888-|r" or "|cFF888888+|r")
        gh.label:SetText(string.format("|cFF%02X%02X%02X%s|r",r8,g8,b8,cd.label))
        gh.badge:SetText(string.format("|cFF%02X%02X%02X%d|r",r8,g8,b8,nbFac))
        gh._cat=cat ; gh._col=col
        curY = curY+GH_H+ROW_GAP

        if isOpen then
          for _, fac in ipairs(factions) do
            local isSel=(selCat==cat and selName==fac.name)
            local fDone,fTotal=GetFactionQuestStats(fac, extKey)
            local pct=fTotal>0 and (fDone/fTotal) or 0
            local lr,lg,lb
            if pct>=1.0 then lr,lg,lb=0.30,0.90,0.45
            else local fc=fac.color or {r=0.5,g=0.5,b=0.5}; lr,lg,lb=fc.r,fc.g,fc.b end

            local row = AcquireWidget("factionRow")
            row:SetPoint("TOPLEFT", CX,       -curY)
            row:SetPoint("TOPRIGHT",-MARGIN_R,-curY)
            row:SetHeight(ROW_H)
            if isSel then
              row:SetBackdropColor(col.r*0.28,col.g*0.28,col.b*0.28,1.0)
              row:SetBackdropBorderColor(col.r,col.g,col.b,1.0)
            else
              row:SetBackdropColor(col.r*0.06,col.g*0.06,col.b*0.06,0.95)
              row:SetBackdropBorderColor(col.r*0.20,col.g*0.20,col.b*0.20,0.7)
            end
            row.dot:SetVertexColor(col.r,col.g,col.b,0.9)

            row.nameFS:SetHeight(ROW_H)
            local nameCol=isSel
              and string.format("|cFF%02X%02X%02X",r8,g8,b8)
              or  string.format("|cFF%02X%02X%02X",math.floor(col.r*0.72*255),math.floor(col.g*0.72*255),math.floor(col.b*0.72*255))
            row.nameFS:SetText(nameCol..fac.name.."|r")

            row.mbarFill:SetWidth(math.max(1,math.floor(MBAR_W*pct)))
            row.mbarFill:SetVertexColor(lr,lg,lb,0.9)

            row.lvlFS:SetHeight(ROW_H)
            if pct>=1.0 then row.lvlFS:SetText(string.format("|cFF4DCC72%d/%d|r",fDone,fTotal))
            else row.lvlFS:SetText(string.format("|cFF%02X%02X%02X%d/%d|r",math.floor(lr*255),math.floor(lg*255),math.floor(lb*255),fDone,fTotal)) end

            local stShort, stTip
            if DailyTrackerDB.showRenown ~= false then stShort, stTip = GetStanding(fac) end
            row.renFS:SetText(stShort and ("|cFFE8C872"..stShort.."|r") or "")
            row._standTip = stTip

            row._cat=cat ; row._facName=fac.name ; row._zone=fac.zone ; row._col=col ; row._selected=isSel
            curY=curY+ROW_H+ROW_GAP
          end
        end
        curY=curY+3
      end
    end

    local sepG = AcquireWidget("sep")
    sepG:SetPoint("TOPLEFT", CX,       -curY)
    sepG:SetPoint("TOPRIGHT",-MARGIN_R,-curY)
    sepG:SetHeight(1) ; sepG:SetVertexColor(0.72,0.60,0.28,0.9)
    return curY+6
  end
  mainFrame.RebuildGroups = RebuildGroups

  -- ============================================================
  -- DEFILEMENT + AUTO-HAUTEUR (commun a la vue quetes et a la vue Alts)
  -- ============================================================
  local function ApplyScrollLayout(self, qScrollY, contentH, viewportW)
    local questH = math.max(40, contentH+12)

    -- Hauteur max de viewport pour rester sous H_MAX
    local maxVP = math.max(60, H_MAX - qScrollY - 12 - MARGIN_BOT - 4)
    local viewportH = math.min(questH, maxVP)
    local scrollBgH = viewportH + 12

    self.questContent:SetSize(viewportW, questH)
    self.scrollFrame:SetSize(viewportW, viewportH)
    self.scrollBg:SetHeight(scrollBgH)

    local scrollMax = math.max(0, questH - viewportH)
    self._scrollMax = scrollMax
    self.scrollBar:ClearAllPoints()
    self.scrollBar:SetPoint("TOPRIGHT",self.scrollBg,"TOPRIGHT",-4,-6)
    self.scrollBar:SetSize(SB_W-4, viewportH)
    self.scrollBar:SetMinMaxValues(0, scrollMax)
    if scrollMax>0 then
      self.scrollBar:Show()
      local off = math.max(0, math.min(scrollMax, self._scrollOffset or 0))
      self._scrollOffset = off
      self.scrollBar:SetValue(off)
      self.scrollFrame:SetVerticalScroll(off)
    else
      self._scrollOffset = 0
      self.scrollBar:SetValue(0)
      self.scrollFrame:SetVerticalScroll(0)
      self.scrollBar:Hide()
    end

    local newH = math.max(H_MIN, math.min(H_MAX, qScrollY + scrollBgH + MARGIN_BOT + 4))
    self:SetHeight(newH)
  end

  local function SetTabState(b, active)
    if not b then return end
    local col = b.col
    if active then
      b:SetBackdropColor(col.r*0.40,col.g*0.40,col.b*0.40,1.0)
      b:SetBackdropBorderColor(col.r,col.g,col.b,1.0)
      if b.accent then b.accent:SetVertexColor(col.r,col.g,col.b,1.0) end
    else
      b:SetBackdropColor(col.r*0.12,col.g*0.12,col.b*0.12,0.95)
      b:SetBackdropBorderColor(col.r*0.35,col.g*0.35,col.b*0.35,0.5)
      if b.accent then b.accent:SetVertexColor(col.r,col.g,col.b,0.5) end
    end
  end

  -- ============================================================
  -- VUE ALTS : un instantane par personnage (pris au login, a chaque
  -- quete rendue et a la deconnexion). Un reset passe depuis la derniere
  -- visite remet ses compteurs a zero (on ne devine rien).
  -- ============================================================
  local function SnapStats(snap, extKey, typ)
    local now = time()
    local valid
    if typ=="weekly" then valid = snap.wExp and now < snap.wExp
    else valid = snap.dExp and now < snap.dExp end
    local done, total, remaining = 0, 0, {}
    ForEachUnit(extKey, typ, function(k, f, q)
      total = total + 1
      if valid and snap.done and snap.done[k] then done = done + 1
      else remaining[#remaining+1] = UnitLabel(f, q) end
    end)
    return done, total, remaining, not valid
  end

  -- La legende (gauche) et les timers de reset (droite) partagent la meme
  -- ligne : la legende est bornee a la place restante, tronquee au besoin.
  local function FitLegend(self)
    local w = (self:GetWidth() or W_MIN) - CX - MARGIN_R - (self._resetInfo:GetStringWidth() or 0) - 12
    self._legend:SetWidth(math.max(40, w))
  end

  local function RenderAlts(self)
    self._questHeader:ClearAllPoints()
    self._questHeader:SetPoint("TOPLEFT",CX,-Y_GROUPS)
    self._questHeader:SetText("|cFFFFD700"..L.ALTS_TITLE.."|r  |cFF888888"..(EXT_FULLNAMES[CURRENT_EXT] or CURRENT_EXT).."|r")
    self._counter:SetText("")
    self._legend:ClearAllPoints()
    self._legend:SetPoint("TOPLEFT",CX,-(Y_GROUPS+16))
    self._legend:SetText("|cFF888888"..L.ALTS_SUB.."|r")
    self._resetInfo:ClearAllPoints()
    self._resetInfo:SetPoint("TOPRIGHT",-MARGIN_R,-(Y_GROUPS+16))
    self._resetInfo:SetText(FormatResetInfo())

    local qScrollY = Y_GROUPS + 32
    local newW = 560
    self:SetWidth(newW)
    FitLegend(self)
    local sbW = newW - CX - MARGIN_R - 4
    local viewportW = sbW - 12 - SB_W
    self.scrollBg:ClearAllPoints()
    self.scrollBg:SetPoint("TOPLEFT",CX,-qScrollY)
    self.scrollBg:SetWidth(sbW)

    local list = {}
    for key, c in pairs(DailyTrackerDB.chars or {}) do
      if type(c)=="table" and c.name then list[#list+1] = {key=key, c=c} end
    end
    table.sort(list, function(a,b)
      if a.key==MY_KEY then return true end
      if b.key==MY_KEY then return false end
      return (a.c.seen or 0) > (b.c.seen or 0)
    end)

    local y = 0
    if not self._altsEmpty then
      local fs = self.questContent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
      fs:SetPoint("TOPLEFT",self.questContent,"TOPLEFT",8,-8)
      fs:SetJustifyH("LEFT") ; fs:SetWordWrap(true)
      self._altsEmpty = fs
    end
    if #list==0 then
      self._altsEmpty:SetWidth(viewportW-16)
      self._altsEmpty:SetText("|cFF888888"..L.ALTS_EMPTY.."|r")
      self._altsEmpty:Show()
      y = math.ceil(self._altsEmpty:GetStringHeight() or 14) + 16
    else
      self._altsEmpty:Hide()
    end
    for _, e in ipairs(list) do
      local c, isMe = e.c, (e.key==MY_KEY)
      local wd, wt, wRem, wStale = SnapStats(c, CURRENT_EXT, "weekly")
      local dd, dt = SnapStats(c, CURRENT_EXT, "daily")
      local row = AcquireWidget("altRow")
      row:SetPoint("TOPLEFT",self.questContent,"TOPLEFT",2,-y)
      row:SetSize(viewportW, 36)
      row:SetBackdropColor(isMe and 0.10 or 0.05, isMe and 0.08 or 0.04, 0.03, 0.95)
      row:SetBackdropBorderColor(0.45,0.35,0.18,0.6)

      local hex = "|cFFDDDDDD"
      local ui = _G.TibiMidnight
      if c.class and ui and ui.ClassColor then
        local cc = ui.ClassColor(c.class)
        if type(cc)=="table" then
          local r, g, b = cc.r or cc[1], cc.g or cc[2], cc.b or cc[3]
          if r and g and b then hex = string.format("|cFF%02X%02X%02X", math.floor(r*255), math.floor(g*255), math.floor(b*255)) end
        end
      elseif c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class] then
        local cc = RAID_CLASS_COLORS[c.class]
        hex = string.format("|cFF%02X%02X%02X", math.floor(cc.r*255), math.floor(cc.g*255), math.floor(cc.b*255))
      end
      local title = hex..(c.name or "?").."|r |cFF888888"..(c.level and ("("..c.level..")") or "")
        .."  "..(c.realm or "").."|r"
      if isMe then title = title.."  |cFF55DD77"..L.ALTS_CURRENT.."|r" end
      row.nameFS:SetText(title)

      if isMe then row.seenFS:SetText("")
      else row.seenFS:SetText("|cFF777777"..string.format(L.ALTS_SEEN, FormatDuration(time()-(c.seen or time()))).."|r") end

      local wCol = (wd>=wt and wt>0) and "|cFF4DCC72" or "|cFF4D99FF"
      row.lineFS:SetText(string.format("%s"..L.ALTS_WEEKLY.."|r   |cFF4DCC4D"..L.ALTS_DAILY.."|r", wCol, wd, wt, dd, dt)
        ..(wStale and ("   |cFFCC8844"..L.ALTS_STALE.."|r") or ""))
      local pct = wt>0 and wd/wt or 0
      row.barFill:SetWidth(math.max(1, math.floor(90*pct)))
      if pct>=1 then row.barFill:SetVertexColor(0.30,0.90,0.45,0.9) else row.barFill:SetVertexColor(0.30,0.60,1.00,0.9) end

      row._key=e.key ; row._isMe=isMe ; row._remaining=wRem ; row._stale=wStale
      row._title=(c.name or "?").." - "..(c.realm or "")
      y = y + 38
    end

    ApplyScrollLayout(self, qScrollY, y, viewportW)
  end

  -- ============================================================
  -- REFRESH CONTENT
  -- ============================================================
  mainFrame.RefreshContent = function(self)

    ResetPools()
    InvalidateCache()
    self:EnsureTicker()

    local extKey  = DailyTrackerDB.extension or "Midnight"
    local filter  = DailyTrackerDB.filter or "all"
    local hideDone= DailyTrackerDB.hideCompleted and true or false
    local altsView= (DailyTrackerDB.view=="alts")

    self._titleStr:SetText(ACCENT_HEX.."DailyTracker|r")

    -- Compteur global (activites dedoublonnees)
    local gDone,gTotal = GetExtStats(extKey)
    self._counter:SetText(string.format("|cFFFFD700"..L.TOTAL.."|r", gDone, gTotal))
    self._legend:SetText(string.format("|cFF4D99FF%s|r  |cFFFFCC00%s|r  |cFF4DCC4D%s|r",
      L.TAG_WEEKLY, L.TAG_ONETIME, L.TAG_DAILY))

    self._resetInfo:SetText(FormatResetInfo())

    -- Etat bouton reduire/deployer
    local sdb=DailyTrackerDB.sections
    local allOpen = sdb.weekly and sdb.onetime and sdb.daily
    self._collapseBtn._txt:SetText(string.format("|cFF%02X%02X%02X%s|r",
      math.floor(0.98*255),math.floor(0.95*255),math.floor(0.80*255),
      allOpen and L.COLLAPSE_ALL or L.EXPAND_ALL))

    -- Onglets de gauche
    for _, eb in ipairs(self.extBtns or {}) do SetTabState(eb, (not altsView) and eb.extKey==extKey) end
    SetTabState(self._altsBtn, altsView)
    SetTabState(self._listBtn, DailyTrackerDB.todo and DailyTrackerDB.todo.shown)

    -- Highlight filtres type
    for key,btn in pairs(self.filterBtns or {}) do
      local col=btn.col or {r=0.5,g=0.5,b=0.5}
      if key==filter then
        btn:SetBackdropColor(col.r*0.30,col.g*0.30,col.b*0.30,1.0)
        btn:SetBackdropBorderColor(col.r,col.g,col.b,1.0)
        if btn.accent then btn.accent:SetVertexColor(col.r,col.g,col.b,1.0) end
      else
        btn:SetBackdropColor(col.r*0.08,col.g*0.08,col.b*0.08,0.9)
        btn:SetBackdropBorderColor(col.r*0.25,col.g*0.25,col.b*0.25,0.5)
        if btn.accent then btn.accent:SetVertexColor(col.r,col.g,col.b,0.4) end
      end
    end

    -- Highlight toggle "A faire"
    do
      local c=self._todoBtn.col
      if hideDone then
        self._todoBtn:SetBackdropColor(c.r*0.30,c.g*0.30,c.b*0.30,1.0)
        self._todoBtn:SetBackdropBorderColor(c.r,c.g,c.b,1.0)
      else
        self._todoBtn:SetBackdropColor(c.r*0.08,c.g*0.08,c.b*0.08,0.9)
        self._todoBtn:SetBackdropBorderColor(c.r*0.25,c.g*0.25,c.b*0.25,0.5)
      end
    end

    if altsView then RenderAlts(self); return end
    if self._altsEmpty then self._altsEmpty:Hide() end

    -- Groupes
    local groupsEndY = RebuildGroups(Y_GROUPS)

    -- Faction selectionnee
    local selCat,selName = GetSelectedFac()
    local fac = nil
    if selCat and selName then
      for _, f in ipairs(GetFactionsByCategory(selCat)) do
        if f.name==selName then fac=f; break end
      end
    end
    if not fac then
      for _, cd in ipairs(CAT_DEFS) do
        local list=GetFactionsByCategory(cd.key)
        if #list>0 then fac=list[1]; SetSelectedFac(cd.key,fac.name); break end
      end
    end
    if not fac then return end

    -- Positionnement du bloc quetes
    local qHeaderY = groupsEndY + 4
    local qLegendY = qHeaderY + 16
    local qScrollY = qLegendY + 14

    self._questHeader:ClearAllPoints()
    self._questHeader:SetPoint("TOPLEFT",CX,-qHeaderY)
    self._questHeader:SetText("|cFFFFD700"..L.ACTIVITIES.."|r"..fac.name)

    self._counter:ClearAllPoints()
    self._counter:SetPoint("TOPRIGHT",-MARGIN_R,-qHeaderY)

    self._legend:ClearAllPoints()
    self._legend:SetPoint("TOPLEFT",CX,-qLegendY)

    self._resetInfo:ClearAllPoints()
    self._resetInfo:SetPoint("TOPRIGHT",-MARGIN_R,-qLegendY)

    -- AUTO-SIZING HORIZONTAL (longueur en caracteres, pas en octets)
    local maxNameLen = 0
    for _, q in ipairs(fac.quests) do
      if (filter=="all" or filter==q.type) then
        if not (hideDone and IsQuestComplete(extKey, fac, q)) then
          local n = Utf8Len(DisplayName(q))
          if n>maxNameLen then maxNameLen=n end
        end
      end
    end
    local neededW  = CX + maxNameLen*7 + 240
    local newW     = math.max(W_MIN, math.min(W_MAX, neededW))
    self:SetWidth(newW)
    FitLegend(self)

    local sbW      = newW - CX - MARGIN_R - 4     -- largeur cadre scrollBg
    local viewportW= sbW - 12 - SB_W              -- largeur utile (moins barre)
    local qcW      = viewportW
    local textW    = qcW - 22

    self.scrollBg:ClearAllPoints()
    self.scrollBg:SetPoint("TOPLEFT",CX,-qScrollY)
    self.scrollBg:SetWidth(sbW)

    -- Collecte + tri par type
    local questsFiltered = {}
    for _, q in ipairs(fac.quests) do
      if filter=="all" or filter==q.type then table.insert(questsFiltered,q) end
    end

    local y = 0
    local showWQ = DailyTrackerDB.showWQ ~= false

    local function PopulateQuestRow(quest, yOff, facRef)
      local tc   = TYPE_COLORS[quest.type]  or {r=1,g=1,b=1}
      local tlbl = TYPE_LABELS[quest.type]  or ""
      local fc   = (facRef and facRef.color) or {r=0.5,g=0.5,b=0.5}
      local done = IsQuestComplete(extKey, facRef, quest)
      -- Groupe « au choix » : fait via une autre quete du groupe
      local otherChoice = done and quest.group and not IsSingleDone(extKey, facRef, quest)

      local row = AcquireWidget("questRow")
      row:SetPoint("TOPLEFT",self.questContent,"TOPLEFT",2,-yOff)
      if done then
        row:SetBackdropColor(0.05,0.05,0.05,0.6)
        row:SetBackdropBorderColor(0.3,0.3,0.3,0.4)
      else
        row:SetBackdropColor(tc.r*0.08,tc.g*0.08,tc.b*0.08,0.95)
        row:SetBackdropBorderColor(tc.r*0.4,tc.g*0.4,tc.b*0.4,0.6)
      end

      if done then row.si:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); row.si:SetVertexColor(0.3,1.0,0.4,otherChoice and 0.4 or 1)
      elseif quest.questID then row.si:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady"); row.si:SetVertexColor(0.7,0.3,0.3,0.7)
      else row.si:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting"); row.si:SetVertexColor(0.6,0.6,0.6,0.5) end

      if done then row.typeTag:SetText("|cFF555566"..tlbl.." |r")
      else row.typeTag:SetText(string.format("|cFF%02X%02X%02X%s|r",math.floor(tc.r*255),math.floor(tc.g*255),math.floor(tc.b*255),tlbl)) end

      -- Auto vs manuel
      if quest.questID then
        row.autoLabel:Show()
        if otherChoice then row.autoLabel:SetText("|cFF777788"..L.GROUP_OTHER.."|r")
        else row.autoLabel:SetText(done and "|cFF44AA44"..L.AUTO_DONE.."|r" or "|cFF555566"..L.AUTO_TODO.."|r") end
        row.manualBtn:Hide()
      else
        row.autoLabel:Hide()
        row.manualBtn:Show()
        row.manualBtn._ext=extKey ; row.manualBtn._fac=facRef ; row.manualBtn._quest=quest
        row.manualBtn._txt:SetText(done and "|cFF44DD66"..L.MANUAL_DONE.."|r" or "|cFFCCAA44"..L.MANUAL_TODO.."|r")
      end

      row.qName:SetSize(textW,16)
      local dname = DisplayName(quest)
      row.qName:SetText(done and "|cFF888888"..dname.."|r" or "|cFFEEEEEE"..dname.."|r")

      row.npcStr:SetSize(textW,14)
      if done then row.npcStr:SetText("|cFF555555"..L.NPC.." "..quest.npc.."  "..L.COORDS.." "..quest.coords.."|r")
      else row.npcStr:SetText("|cFF888888"..L.NPC.."|r |cFFCCBB88"..quest.npc.."|r  |cFF888888"..L.COORDS.."|r |cFF99CCFF"..quest.coords.."|r") end

      -- Quetes du monde en direct (entrees wq=true)
      local wqTxt = ""
      row._wq = nil
      if quest.wq and showWQ then
        local n = CountWorldQuests(quest.mapID)
        if n then
          row._wq = true
          wqTxt = "   "..(n>0 and ("|cFF99CCFF"..string.format(L.WQ_AVAIL, n).."|r") or ("|cFF666677"..L.WQ_NONE.."|r"))
        end
      end

      row.repStr:SetSize(textW*0.72,14)
      if done then row.repStr:SetText("|cFF555555"..L.REP.." +"..(quest.rep or 0).."|r"..wqTxt)
      else row.repStr:SetText(string.format("|cFF888888"..L.REP.."|r |cFF%02X%02X%02X+%d|r",math.floor(fc.r*255),math.floor(fc.g*255),math.floor(fc.b*255),quest.rep or 0)..wqTxt) end

      row.zStr:SetText(done and "|cFF444455"..quest.zone.."|r" or "|cFF555577"..quest.zone.."|r")

      -- Hauteur reelle du conseil (mesuree, et non estimee sur les octets)
      local tipText = quest.tip or ""
      local tipH = 14
      if tipText~="" then
        row.tipStr:Show()
        row.tipStr:SetWidth(textW)
        row.tipStr:SetText(done and "|cFF444455"..tipText.."|r" or "|cFF777777"..tipText.."|r")
        tipH = math.max(14, math.ceil(row.tipStr:GetStringHeight() or 14))
        row.tipStr:SetHeight(tipH)
      else
        row.tipStr:Hide()
      end
      local rowH = 64 + tipH + 6
      row:SetSize(qcW,rowH)

      row._quest=quest ; row._fac=facRef ; row._done=done ; row._tc=tc ; row._tipText=tipText ; row._yOff=yOff
      return rowH
    end

    local groups = {
      {key="weekly",  label=L.SEC_WEEKLY,  quests={}},
      {key="onetime", label=L.SEC_ONETIME, quests={}},
      {key="daily",   label=L.SEC_DAILY,   quests={}},
    }
    for _, quest in ipairs(questsFiltered) do
      for _, g in ipairs(groups) do
        if quest.type==g.key then table.insert(g.quests,quest) end
      end
    end

    for _, grp in ipairs(groups) do
      if #grp.quests>0 then
        local tc=TYPE_COLORS[grp.key] or {r=1,g=1,b=1}
        local isOpen=DailyTrackerDB.sections[grp.key]
        -- Compte par unite : un groupe « au choix » = une activite
        local grpDone, grpTotal, seenU = 0, 0, {}
        for _, q in ipairs(grp.quests) do
          local k = UnitKey(extKey, fac, q)
          if not seenU[k] then
            seenU[k] = true ; grpTotal = grpTotal + 1
            if IsQuestComplete(extKey, fac, q) then grpDone = grpDone + 1 end
          end
        end
        local allDone=(grpDone==grpTotal)

        local header=AcquireWidget("questHeader")
        header:SetPoint("TOPLEFT",self.questContent,"TOPLEFT",2,-y)
        header:SetSize(qcW,26)
        if allDone then header:SetBackdropColor(0.05,0.10,0.05,0.95); header:SetBackdropBorderColor(0.3,0.6,0.3,0.7)
        else header:SetBackdropColor(tc.r*0.15,tc.g*0.15,tc.b*0.15,0.95); header:SetBackdropBorderColor(tc.r*0.5,tc.g*0.5,tc.b*0.5,0.7) end

        header.arrow:SetText(isOpen and "|cFFFFD700-|r" or "|cFF888888+|r")
        if allDone then header.label:SetText(string.format("|cFF4DCC72%s  (%d/%d)|r",grp.label,grpDone,grpTotal))
        else header.label:SetText(string.format("|cFF%02X%02X%02X%s|r  |cFF888888(%d/%d)|r",math.floor(tc.r*255),math.floor(tc.g*255),math.floor(tc.b*255),grp.label,grpDone,grpTotal)) end
        header._sectionKey=grp.key ; header._tc=tc

        if isOpen then
          local curRowY=y+28
          for _, quest in ipairs(grp.quests) do
            if not (hideDone and IsQuestComplete(extKey, fac, quest)) then
              local rH=PopulateQuestRow(quest,curRowY,fac)
              curRowY=curRowY+rH+2
            end
          end
          y=curRowY+4
        else
          y=y+28+4
        end
      end
    end

    ApplyScrollLayout(self, qScrollY, y, viewportW)
  end -- RefreshContent

  -- Fait defiler jusqu'a une quete (recherche globale) et la met en relief.
  mainFrame.ScrollToQuest = function(self, questName)
    local pool = self._pools and self._pools.questRow
    local used = self._poolUsed and self._poolUsed.questRow or 0
    if not pool then return end
    for i = 1, used do
      local row = pool[i]
      if row and row._quest and row._quest.name == questName then
        local off = math.max(0, math.min(self._scrollMax or 0, (row._yOff or 0) - 4))
        self._scrollOffset = off
        self.scrollFrame:SetVerticalScroll(off)
        self.scrollBar:SetValue(off)
        row:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
        return
      end
    end
  end

  -- Ticker des timers de reset : demarre par RefreshContent (donc a chaque
  -- ouverture) et s'arrete tout seul des que la fenetre est cachee. Aucun
  -- hook OnHide : DTMainFrame est dans UISpecialFrames, et ce melange
  -- contamine ToggleGameMenu (piege documente dans CLAUDE.md).
  mainFrame.EnsureTicker = function(s)
    if s._ticker then return end
    s._ticker = C_Timer.NewTicker(30, function(t)
      if not s:IsShown() then t:Cancel(); s._ticker = nil; return end
      if s._resetInfo then s._resetInfo:SetText(FormatResetInfo()) end
    end)
  end

  mainFrame:Hide()
end -- BuildUI

-- ================================================================
-- MINIMAP
-- ================================================================
local minimapBtn

local function GetMinimapRadius()
  return (Minimap:GetWidth() / 2) + 10
end

local function SetMinimapPos(angle)
  if DailyTrackerDB then DailyTrackerDB.mmAngle = angle end
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

  minimapBtn = CreateFrame("Button", "DTMinimapBtn", Minimap)
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
  icon:SetTexture("Interface\\AddOns\\DailyTracker\\medias\\DailyTracker")
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

  local savedAngle = (DailyTrackerDB and DailyTrackerDB.mmAngle) or 220
  SetMinimapPos(savedAngle)

  minimapBtn:SetScript("OnShow", function()
    SetMinimapPos((DailyTrackerDB and DailyTrackerDB.mmAngle) or 220)
  end)

  minimapBtn:RegisterForDrag("LeftButton")

  minimapBtn:SetScript("OnDragStart", function(s)
    s:SetScript("OnUpdate", function()
      local mx, my  = Minimap:GetCenter()
      local uiScale = UIParent:GetEffectiveScale()
      local cx, cy  = GetCursorPosition()
      local angle   = math.deg(math.atan2(
        (cy / uiScale) - my,
        (cx / uiScale) - mx
      ))
      SetMinimapPos(angle)
    end)
  end)

  minimapBtn:SetScript("OnDragStop", function(s)
    s:SetScript("OnUpdate", nil)
  end)

  local resizeWatcher = CreateFrame("Frame")
  resizeWatcher:RegisterEvent("MINIMAP_UPDATE_ZOOM")
  resizeWatcher:SetScript("OnEvent", function()
    SetMinimapPos((DailyTrackerDB and DailyTrackerDB.mmAngle) or 220)
  end)

  minimapBtn:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
      if mainFrame:IsShown() then
        mainFrame:Hide()
        DailyTrackerDB.open = false
      else
        mainFrame:Show()
        mainFrame:RefreshContent()
        DailyTrackerDB.open = true
      end
    end
  end)

  minimapBtn:SetScript("OnEnter", function(s)
    if s._hl then s._hl:SetAlpha(1) end
    local ext = DailyTrackerDB.extension or "Midnight"
    InvalidateCache()
    local d, t = GetExtStats(ext)
    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
    GameTooltip:AddLine(ACCENT_HEX.."DailyTracker|r")
    GameTooltip:AddLine(EXT_FULLNAMES[ext] or ext, 0.9, 0.9, 0.9)
    GameTooltip:AddLine(string.format(L.ACT_COUNT, d, t), 0.3, 0.9, 0.5)
    GameTooltip:AddLine(string.format("%s: %s   %s: %s",
      L.RESET_DAILY, FormatDuration(SecUntilDailyReset()),
      L.RESET_WEEKLY, FormatDuration(SecUntilWeeklyReset())), 0.7,0.7,0.7)
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("|cFFFFD700"..L.MM_LEFT.."|r", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("|cFFFFD700"..L.MM_DRAG.."|r", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)

  minimapBtn:SetScript("OnLeave", function(s)
    if s._hl then s._hl:SetAlpha(0) end
    GameTooltip:Hide()
  end)
end

-- ================================================================
-- COMPARTIMENT
-- ================================================================
function DailyTracker_OnAddonCompartmentClick()
  if not mainFrame then return end
  if mainFrame:IsShown() then mainFrame:Hide(); DailyTrackerDB.open=false
  else mainFrame:Show(); mainFrame:RefreshContent(); DailyTrackerDB.open=true end
end
function DailyTracker_OnAddonCompartmentEnter()
  GameTooltip:SetOwner(AddonCompartmentFrame,"ANCHOR_BOTTOMRIGHT")
  GameTooltip:AddLine(ACCENT_HEX.."DailyTracker|r")
  GameTooltip:AddLine(L.COMPART_SUB,0.8,0.8,0.9) ; GameTooltip:Show()
end
function DailyTracker_OnAddonCompartmentLeave() GameTooltip:Hide() end

-- ================================================================
-- OUVERTURE CIBLEE (recherche globale, liste « A faire »)
-- Ouvre la fenetre sur une faction, et optionnellement defile jusqu'a
-- une quete precise.
-- ================================================================
function DailyTracker_ShowFaction(extKey, facName, questName)
  if not mainFrame then return end
  extKey = extKey or DailyTrackerDB.extension or CURRENT_EXT
  local fac = FindFaction(extKey, facName)
  if not fac then return end
  DailyTrackerDB.extension = extKey
  DailyTrackerDB.view = nil
  local cat = fac.category or "secondaire"
  SetSelectedFac(cat, fac.name)
  DailyTrackerDB.groups = DailyTrackerDB.groups or {}
  DailyTrackerDB.groups[cat] = true
  if questName then
    DailyTrackerDB.filter = "all"
    for _, q in ipairs(fac.quests or {}) do
      if q.name == questName then DailyTrackerDB.sections[q.type] = true end
    end
  end
  mainFrame._scrollOffset = 0
  mainFrame:Show(); DailyTrackerDB.open = true
  mainFrame:RefreshContent()
  if questName then mainFrame:ScrollToQuest(questName) end
end

-- ================================================================
-- LISTE « A FAIRE » COMPACTE (DTTodoFrame)
-- Petite fenetre a epingler a l'ecran : activites hebdo (et, en option,
-- quotidiennes) restantes du personnage, pour l'extension courante.
-- Clic sur une ligne : ouvre DailyTracker sur la faction.
-- ================================================================
local todoFrame
local TODO_MAX = 16
local TODO_W   = 250

local function TodoDB()
  if type(DailyTrackerDB.todo)~="table" then DailyTrackerDB.todo = {} end
  return DailyTrackerDB.todo
end

local function BuildTodo()
  if todoFrame then return todoFrame end
  local f = CreateFrame("Frame","DTTodoFrame",UIParent,"BackdropTemplate")
  f:SetSize(TODO_W, 60)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) if not TodoDB().locked then s:StartMoving() end end)
  f:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local point,_,_,x,y = s:GetPoint()
    TodoDB().pos = {point=point, x=x, y=y}
  end)
  local ui = _G.TibiMidnight
  if ui and ui.SkinFrame then
    ui.SkinFrame(f, ACCENT)
  else
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
    f:SetBackdropColor(0.05,0.05,0.07,0.92)
    f:SetBackdropBorderColor(0,0,0,1)
  end

  f.title = f:CreateFontString(nil,"OVERLAY","GameFontNormal")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
  f.count = f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  f.count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -22, -9)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetSize(20, 20)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  close:SetScript("OnClick", function()
    TodoDB().shown = false
    f:Hide()
    if mainFrame and mainFrame:IsShown() then mainFrame:RefreshContent() end
  end)

  f.lines = {}
  for i = 1, TODO_MAX + 1 do
    local b = CreateFrame("Button", nil, f)
    b:SetHeight(14)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -24 - (i-1)*14)
    b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -24 - (i-1)*14)
    b.fs = b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    b.fs:SetAllPoints(b) ; b.fs:SetJustifyH("LEFT") ; b.fs:SetWordWrap(false)
    b:SetScript("OnClick", function(s)
      if s._fac then DailyTracker_ShowFaction(s._ext, s._fac.name, s._q and s._q.name) end
    end)
    b:SetScript("OnEnter", function(s)
      if not s._fac then return end
      GameTooltip:SetOwner(s, "ANCHOR_LEFT")
      GameTooltip:AddLine(s._q and DisplayName(s._q) or "", 1, 1, 1)
      GameTooltip:AddLine(s._fac.name, 0.8, 0.8, 0.8)
      if s._q and s._q.tip then GameTooltip:AddLine(s._q.tip, 0.7, 0.7, 0.7, true) end
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(L.TODO_HINT, 0.6, 0.6, 0.6)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    f.lines[i] = b
  end

  local p = TodoDB().pos
  if p and p.x then f:SetPoint(p.point or "CENTER", UIParent, p.point or "CENTER", p.x, p.y)
  else f:SetPoint("RIGHT", UIParent, "RIGHT", -220, 120) end
  f:Hide()
  todoFrame = f
  return f
end

RefreshTodo = function()
  if not (todoFrame and todoFrame:IsShown()) then return end
  local f = todoFrame
  local ext = (DailyTrackerDB.view ~= "alts" and DailyTrackerDB.extension) or CURRENT_EXT
  local items = GetRemaining(ext, TodoDB().daily)
  f.title:SetText(ACCENT_HEX..L.TODO_TITLE.."|r |cFF888888"..(EXT_LABELS[ext] or ext).."|r")
  f.count:SetText("|cFFFFD700"..#items.."|r")
  local n = 0
  if #items == 0 then
    n = 1
    local b = f.lines[1]
    b._fac = nil ; b._q = nil
    b.fs:SetText("|cFF4DCC72"..L.TODO_EMPTY.."|r")
    b:Show()
  else
    for i, it in ipairs(items) do
      if i > TODO_MAX then break end
      n = i
      local b = f.lines[i]
      local tc = TYPE_COLORS[it.q.type] or {r=1,g=1,b=1}
      b._fac = it.fac ; b._q = it.q ; b._ext = ext
      b.fs:SetText(string.format("|cFF%02X%02X%02X-|r %s", math.floor(tc.r*255), math.floor(tc.g*255), math.floor(tc.b*255),
        UnitLabel(it.fac, it.q)))
      b:Show()
    end
    if #items > TODO_MAX then
      n = n + 1
      local b = f.lines[n]
      b._fac = nil ; b._q = nil
      b.fs:SetText("|cFF888888"..string.format(L.TODO_MORE, #items - TODO_MAX).."|r")
      b:Show()
    end
  end
  for i = n + 1, #f.lines do f.lines[i]:Hide() end
  f:SetHeight(24 + n*14 + 8)
end

local function SetTodoShown(v)
  TodoDB().shown = v and true or false
  local f = BuildTodo()
  if v then f:Show(); InvalidateCache(); RefreshTodo() else f:Hide() end
end
ToggleTodo = function() SetTodoShown(not TodoDB().shown) end

-- ================================================================
-- INSTANTANE DU PERSONNAGE (vue Alts), BADGE, RAPPEL
-- ================================================================
local function Snapshot()
  if not MY_KEY then return end
  local c = CharData()
  local now = time()
  c.level = UnitLevel and UnitLevel("player") or c.level
  c.seen  = now
  local ws, ds = SecUntilWeeklyReset(), SecUntilDailyReset()
  c.wExp = ws > 0 and (now + ws) or nil
  c.dExp = ds > 0 and (now + ds) or nil
  local done = {}
  for _, extKey in ipairs(EXT_ORDER) do
    ForEachUnit(extKey, nil, function(k, f, q)
      if IsQuestComplete(extKey, f, q) then done[k] = true end
    end)
  end
  c.done = done
end

UpdateBadge = function()
  local TS = _G.TibiSuite
  if not (HasCore() and TS.SetTabBadge) then return end
  if TS.RefreshStatus then TS.RefreshStatus() end
  if DailyTrackerDB.badge == false then TS.SetTabBadge("Daily", 0); return end
  local d, total = GetExtStats(CURRENT_EXT, "weekly")
  TS.SetTabBadge("Daily", math.max(0, total - d))
end

-- Ligne d'etat du Panneau vivant de TibiSuite (statusFn, lue par le core
-- seulement) : hebdomadaires restantes de l'extension suivie, urgente a moins
-- de 24 h du reset. Memes chiffres que le badge.
function DailyTracker_Status()
  if not MY_KEY then return nil end
  local d, total = GetExtStats(CURRENT_EXT, "weekly")
  if not total or total <= 0 then return nil end
  local SL = _G.TibiSuiteL or {}
  local left = math.max(0, total - d)
  if left == 0 then return { text = SL.ST_WEEK_DONE, progress = 1 } end
  local secs = SecUntilWeeklyReset()
  return { text = string.format(SL.ST_WEEK_LEFT_FMT or "%d", left), progress = d / total,
           urgent = secs > 0 and secs < 86400 }
end

-- Rappel avant le reset hebdo : une seule fois par reset et par personnage.
-- verbose=true (bouton « Verifier maintenant ») : repond toujours, meme
-- quand il n'y a rien a rappeler, pour que le test ne paraisse pas muet.
local function CheckReminder(verbose)
  local function say(msg) if verbose then print(ACCENT_HEX.."DailyTracker|r "..msg) end end
  local hours = tonumber(DailyTrackerDB.remindHours)
  if hours == nil then hours = 12 end
  if hours <= 0 then return say(L.REMIND_OFF) end
  if not MY_KEY then return end
  local secs = SecUntilWeeklyReset()
  if secs <= 0 then return end
  local d, t = GetExtStats(CURRENT_EXT, "weekly")
  local left = t - d
  if left <= 0 then return say(L.REMIND_ALLDONE) end
  if secs > hours*3600 then
    return say(string.format(L.REMIND_NOTYET, FormatDuration(secs), hours, left))
  end
  local c = CharData()
  local stamp = math.floor((time() + secs) / 3600)
  if c.remindedFor == stamp and not verbose then return end
  c.remindedFor = stamp
  print(ACCENT_HEX.."DailyTracker|r "..string.format(L.REMIND_MSG, FormatDuration(secs), left))
end

-- Mise a jour d'arriere-plan regroupee (1 s) : meme fenetre fermee.
local _bgPending = false
RequestBackground = function()
  if _bgPending then return end
  _bgPending = true
  C_Timer.After(1, function()
    _bgPending = false
    InvalidateCache()
    Snapshot()
    UpdateBadge()
    RefreshTodo()
    CheckReminder()
  end)
end

-- ================================================================
-- MIGRATION : suivi manuel du compte -> personnage (une seule fois)
-- Avant cette version, les coches manuelles etaient partagees par tous
-- les persos. Elles sont confiees au premier personnage qui se connecte
-- (les autres repartent de zero). Les anciennes cles « donjon hebdo »
-- des differentes factions fusionnent dans la cle partagee.
-- ================================================================
local function MigrateManual()
  if DailyTrackerDB.manualMigrated or not MY_KEY then return end
  local old = DailyTrackerDB.manual
  local c = CharData()
  if type(old) == "table" and next(old) then
    local now = time()
    for extKey, ext in pairs(DailyTrackerData) do
      for _, fac in ipairs(ext.factions or {}) do
        for _, q in ipairs(fac.quests or {}) do
          local oldKey = extKey.."::"..fac.name.."::"..q.name
          local v = old[oldKey]
          if v and not (type(v)=="number" and now >= v) then
            local nk = ManualKey(extKey, fac.name, q)
            local cur = c.manual[nk]
            if cur == nil or (type(v)=="number" and type(cur)=="number" and v > cur) then c.manual[nk] = v end
          end
        end
      end
    end
  end
  DailyTrackerDB.manual = {}
  DailyTrackerDB.manualMigrated = true
end

-- ================================================================
-- DIAGNOSTIC questID (asynchrone)
-- Le client ne connait le titre d'une quete qu'apres l'avoir demandee au
-- serveur : un premier passage immediat affichait donc « non resolu » pour
-- des IDs parfaitement valides. On demande d'abord chaque quete, on attend
-- la reponse (QUEST_DATA_LOAD_RESULT, jusqu'a 6 s), puis on classe :
--   OK          : titre recu (affiche dans la langue du client)
--   CACHEE      : le serveur confirme l'ID mais sans titre (drapeau interne)
--   INTROUVABLE : le serveur repond que l'ID n'existe pas (a corriger)
--   SANS REPONSE: aucune reponse dans le delai (relancer /dt check)
-- N'invente aucune donnee.
-- ================================================================
local ourIDs, loadResult = {}, {}
-- Titre connu du client pour un questID, ou nil s'il n'est pas encore charge.
local function ClientTitle(id) return DisplayName({questID=id, name=false}) or nil end
local function IndexQuestIDs()
  wipe(ourIDs)
  for _, extKey in ipairs(EXT_ORDER) do
    for _, fac in ipairs(GetActiveFactions(extKey)) do
      for _, q in ipairs(fac.quests or {}) do
        if q.questID then ourIDs[q.questID] = true end
      end
    end
  end
end
local function RequestTitles()
  if not (C_QuestLog and C_QuestLog.RequestLoadQuestByID) then return end
  for id in pairs(ourIDs) do
    if not ClientTitle(id) then pcall(C_QuestLog.RequestLoadQuestByID, id) end
  end
end

-- Heuristique « titre suspect » (client francais seulement, les donnees
-- etant en francais) : le titre du jeu et notre nom doivent partager au
-- moins un mot significatif (5 lettres et plus, sans accents). Sinon l'ID
-- pointe tres probablement vers une autre quete (cas reel : les anciens IDs
-- TWW renvoyaient « La Coupe de Kalimdor commence » pour un Pacte).
local function Words(str)
  local out = {}
  local ui = _G.TibiMidnight
  str = (ui and ui.Normalize) and ui.Normalize(str) or tostring(str):lower()
  for w in str:gmatch("%w+") do if #w >= 5 then out[w] = true end end
  return out
end
local function TitleLooksWrong(dataName, title)
  if GetLocale and GetLocale() ~= "frFR" then return false end
  local a, b = Words(dataName), Words(title)
  if not next(a) or not next(b) then return false end
  for w in pairs(a) do if b[w] then return false end end
  return true
end

local checkRunning = false
local function RunQuestIDCheck()
  if checkRunning then return end
  checkRunning = true
  IndexQuestIDs()
  print(ACCENT_HEX.."DailyTracker|r "..L.CHECK_HEADER)
  print("  |cFF888888"..L.CHECK_WAIT.."|r")
  RequestTitles()

  local tries = 0
  local function Report()
    checkRunning = false
    local nOK, nHidden, nBad, nWait, nManual, nSusp = 0, 0, 0, 0, 0, 0
    for _, extKey in ipairs(EXT_ORDER) do
      print(ACCENT_HEX.."== "..(EXT_FULLNAMES[extKey] or extKey).." ==|r")
      for _, fac in ipairs(GetActiveFactions(extKey)) do
        for _, q in ipairs(fac.quests or {}) do
          if q.questID then
            local src = q.fromRT and " |cFF88AADD(RenTracker)|r" or ""
            local title = ClientTitle(q.questID)
            if title and TitleLooksWrong(q.name, title) then
              nSusp = nSusp + 1
              print(string.format("  |cFFFF7733%s|r [%d] %s -> %s%s", L.CHECK_SUSPECT, q.questID, q.name, title, src))
            elseif title then
              nOK = nOK + 1
              print(string.format("  |cFF44CC44%s|r [%d] %s -> %s%s", L.CHECK_OK, q.questID, q.name, title, src))
            elseif loadResult[q.questID] == true then
              nHidden = nHidden + 1
              print(string.format("  |cFF88AADD%s|r [%d] %s%s", L.CHECK_HIDDEN, q.questID, q.name, src))
            elseif loadResult[q.questID] == false then
              nBad = nBad + 1
              print(string.format("  |cFFFF5555%s|r [%d] %s%s", L.CHECK_INVALID, q.questID, q.name, src))
            else
              nWait = nWait + 1
              print(string.format("  |cFFFFAA33%s|r [%d] %s%s", L.CHECK_NORESP, q.questID, q.name, src))
            end
          else
            nManual = nManual + 1
          end
        end
      end
    end
    -- Pont de donnees RenTracker
    if _G.RenTrackerData then
      print(ACCENT_HEX.."== "..L.CHECK_BRIDGE.." ==|r")
      print("  "..string.format(L.BRIDGE_IMPORT, bridge.imported))
      if #bridge.diverge == 0 then
        print("  |cFF44CC44"..L.CHECK_BRIDGE_OK.."|r")
      else
        for _, line in ipairs(bridge.diverge) do print("  |cFFFFAA33"..L.CHECK_DIVERGE.."|r "..line) end
      end
    end
    print(ACCENT_HEX.."DailyTracker|r "..string.format(L.CHECK_SUMMARY, nOK, nHidden, nBad, nWait, nManual))
    if nSusp > 0 then print(ACCENT_HEX.."DailyTracker|r "..string.format(L.CHECK_SUSPECT_SUM, nSusp)) end
  end

  local function Poll()
    tries = tries + 1
    local pending = false
    for id in pairs(ourIDs) do
      if loadResult[id] == nil and not ClientTitle(id) then pending = true; break end
    end
    if pending and tries < 6 then C_Timer.After(1, Poll) else Report() end
  end
  C_Timer.After(1, Poll)
end

-- ================================================================
-- SLASH
-- ================================================================
local function ToggleMain()
  if not mainFrame then return end
  if mainFrame:IsShown() then mainFrame:Hide(); DailyTrackerDB.open=false
  else mainFrame:Show(); mainFrame:RefreshContent(); DailyTrackerDB.open=true end
end

SLASH_DAILYTRACKER1="/dt" ; SLASH_DAILYTRACKER2="/daily"
SlashCmdList["DAILYTRACKER"]=function(msg)
  msg = (msg or ""):lower():gsub("^%s+",""):gsub("%s+$","")
  if msg=="check" or msg=="verify" then
    RunQuestIDCheck() ; return
  elseif msg=="help" then
    print(ACCENT_HEX.."DailyTracker|r "..L.HELP) ; return
  elseif msg=="options" or msg=="config" then
    if DailyTracker_OpenOptions then DailyTracker_OpenOptions() end ; return
  elseif msg=="todo" or msg=="list" or msg=="liste" then
    ToggleTodo()
    if mainFrame and mainFrame:IsShown() then mainFrame:RefreshContent() end
    return
  elseif msg=="alts" then
    if not mainFrame then return end
    DailyTrackerDB.view = "alts"
    mainFrame:Show(); DailyTrackerDB.open=true; mainFrame:RefreshContent()
    return
  end
  ToggleMain()
end

-- ================================================================
-- REFRESH THROTTLE (fenetre ouverte)
-- ================================================================
local _refreshPending=false
local function RequestRefresh()
  if _refreshPending then return end
  _refreshPending=true
  C_Timer.After(0.3,function()
    _refreshPending=false
    if mainFrame and mainFrame:IsShown() and mainFrame.RefreshContent then
      mainFrame:RefreshContent()
    end
    if todoFrame and todoFrame:IsShown() then InvalidateCache(); RefreshTodo() end
  end)
end

-- API interne pour DailyTracker_Suite.lua (options, recherche)
NS.DisplayName = DisplayName
NS.RefreshAll = function()
  InvalidateCache()
  if mainFrame and mainFrame:IsShown() then mainFrame:RefreshContent() end
  RefreshTodo()
  UpdateBadge()
end
NS.SetTodoShown = function(v)
  SetTodoShown(v)
  if mainFrame and mainFrame:IsShown() then mainFrame:RefreshContent() end
end
NS.ApplyTodoLock = function() end   -- verrou lu a chaque glisser, rien a appliquer
NS.CheckReminderNow = function() InvalidateCache(); CheckReminder(true) end

-- ================================================================
-- EVENEMENTS
-- ================================================================
local evFrame=CreateFrame("Frame")
evFrame:RegisterEvent("ADDON_LOADED") ; evFrame:RegisterEvent("PLAYER_LOGIN")
evFrame:RegisterEvent("PLAYER_LOGOUT")
evFrame:RegisterEvent("QUEST_TURNED_IN") ; evFrame:RegisterEvent("QUEST_LOG_UPDATE")
evFrame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED") ; evFrame:RegisterEvent("UPDATE_FACTION")
evFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")

evFrame:SetScript("OnEvent",function(_,event,arg1,arg2)
  if event=="ADDON_LOADED" and arg1==ADDON then
    if not DailyTrackerDB.sections then DailyTrackerDB.sections={weekly=true,daily=true,onetime=false} end
    if not DailyTrackerDB.filter   then DailyTrackerDB.filter="all" end
    if not DailyTrackerDB.groups   then DailyTrackerDB.groups={principale=true,secondaire=true,pvp=false} end
    if DailyTrackerDB.hideCompleted==nil then DailyTrackerDB.hideCompleted=false end
    if type(DailyTrackerDB.manual)~="table" then DailyTrackerDB.manual={} end
    if type(DailyTrackerDB.chars)~="table"  then DailyTrackerDB.chars={} end
    if DailyTrackerDB.remindHours==nil then DailyTrackerDB.remindHours=12 end
    if DailyTrackerData[DailyTrackerDB.extension or ""]==nil then DailyTrackerDB.extension=CURRENT_EXT end

    BuildUI() ; BuildMinimapButton()
    local p=DailyTrackerDB.pos
    if p and p.x then
      mainFrame:ClearAllPoints()
      mainFrame:SetPoint(p.point or "CENTER",UIParent,p.point or "CENTER",p.x,p.y)
    else mainFrame:SetPoint("CENTER",UIParent,"CENTER",0,0) end

  elseif event=="ADDON_LOADED" and arg1=="TibiSuite" then
    if minimapBtn then minimapBtn:Hide() end

  elseif event=="PLAYER_LOGIN" then
    -- Le nom du perso n'est fiable qu'ici : migration, purge et etat ouvert.
    InitCharacter()
    MigrateManual()
    PurgeExpiredManual()
    BridgeRenTracker()
    -- Titres des quetes dans la langue du client : demandes des maintenant.
    IndexQuestIDs()
    RequestTitles()
    InvalidateCache()
    Snapshot()
    if DailyTrackerDB.open and mainFrame then
      mainFrame:Show() ; mainFrame:RefreshContent()
    end
    if TodoDB().shown then SetTodoShown(true) end
    C_Timer.After(3, function()
      -- Message de connexion : en suite, on suit le reglage du core
      -- (TibiSuiteDB.loginMsg : full / one / none) ; seul « full » fait
      -- parler les modules. En autonome, message complet.
      local mode = "full"
      if HasCore() then mode = (TibiSuiteDB and TibiSuiteDB.loginMsg) or "one" end
      InvalidateCache()
      if mode=="full" then
        print(string.format(L.LOGIN_MSG, VERSION))
        local d, t = GetExtStats(CURRENT_EXT, "weekly")
        if t - d > 0 then
          print(ACCENT_HEX.."DailyTracker|r "..string.format(L.RECAP, t - d, FormatDuration(SecUntilWeeklyReset())))
        end
      end
      RequestBackground()
    end)
    -- Le badge d'onglet a besoin de la barre du core, construite apres coup.
    C_Timer.After(8, function() if UpdateBadge then UpdateBadge() end end)
    -- Filet de 5 min : rappel avant reset et passage du reset quotidien.
    C_Timer.NewTicker(300, function() RequestBackground() end)

  elseif event=="PLAYER_LOGOUT" then
    InvalidateCache()
    Snapshot()

  elseif event=="QUEST_DATA_LOAD_RESULT" then
    -- arg1 = questID, 2e argument = succes. Seulement nos quetes.
    if arg1 and ourIDs[arg1] then
      loadResult[arg1] = arg2 and true or false
      if mainFrame and mainFrame:IsShown() then RequestRefresh() end
    end

  elseif event=="QUEST_TURNED_IN" then
    RequestRefresh()
    RequestBackground()

  elseif event=="QUEST_LOG_UPDATE" or event=="MAJOR_FACTION_RENOWN_LEVEL_CHANGED" or event=="UPDATE_FACTION" then
    if mainFrame and mainFrame:IsShown() then RequestRefresh() end
  end
end)

-- ================================================================
-- TOGGLE PUBLIC -- appele par TibiSuite
-- ================================================================
function DailyTracker_Toggle()
  ToggleMain()
end

-- ================================================================
-- API PUBLIQUE (Standby) - lecture seule, depuis 7.1.5.40
-- Lue par la tuile « A faire ce soir » de Standby. Meme calcul que la liste
-- « A faire » et le badge (extension courante, personnage connecte).
-- ================================================================
DailyTrackerAPI = DailyTrackerAPI or {}
DailyTrackerAPI.version = 1

-- Renvoie weeklyLeft, dailyLeft (nombres d'activites restantes).
function DailyTrackerAPI.GetRemaining()
  local weekly = #GetRemaining(CURRENT_EXT, false)
  local all = #GetRemaining(CURRENT_EXT, true)
  return weekly, all - weekly
end
