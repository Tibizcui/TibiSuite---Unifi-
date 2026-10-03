-- ================================================================
-- DgnTracker v7.1.5.38
-- Auteur : Tibiscui - Kirin Tor
-- ================================================================

local ADDON = "DgnTracker"
local L = DgnTrackerL or {}
local function T(key, default) return L[key] or default end
DgnTrackerData = DgnTrackerData or {}
local Live = DgnTrackerLive

-- NB : les SavedVariables arrivent APRES l'execution de ce fichier. Ces
-- defauts ne servent qu'a une toute premiere installation ; les cles
-- manquantes d'une sauvegarde existante sont posees dans ADDON_LOADED.
DgnTrackerDB = DgnTrackerDB or {
  pos        = {point="CENTER", x=0, y=0},
  open       = false,
  extension  = "Midnight",
  mmAngle    = 195,
  activeTab  = "dungeon",   -- onglet actif dans la fenetre (dungeon/raid/delve/torghast)
  expandedInst = {},
  mapPins    = false,       -- pose auto d'un waypoint (TomTom/carte) a l'ouverture d'une instance
}

local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end
local function GetUI() return _G.TibiMidnight end

-- ================================================================
-- CONSTANTES
-- ================================================================
local FRAME_W   = 700
local TAB_COL_W = 96
local TAB_H     = 28
local TAB_GAP   = 2

-- Vues virtuelles (en tete de colonne) puis extensions
local VIRTUAL  = {"Season","Nearby","Favs"}
local IS_VIRTUAL = { Season=true, Nearby=true, Favs=true }
local EXT_ROW1 = {"Midnight","TheWarWithin","Dragonflight","Shadowlands","BattleForAzeroth","Legion"}
local EXT_ROW2 = {"WarlordsOfDraenor","MistsOfPandaria","Cataclysme","WrathOfTheLichKing","TheBurningCrusade","Vanilla"}

local EXT_LABELS = {
  Midnight="MID", TheWarWithin="TWW", Dragonflight="DF",
  Shadowlands="SL", BattleForAzeroth="BfA", Legion="LEG",
  WarlordsOfDraenor="WoD", MistsOfPandaria="MoP", Cataclysme="CATA",
  WrathOfTheLichKing="WotLK", TheBurningCrusade="TBC", Vanilla="VAN",
  Season=T("VT_SEASON", "Saison"), Nearby=T("VT_NEAR", "Près de moi"), Favs=T("VT_FAVS", "Favoris"),
}
-- Alias de /dg <mot> vers une vue ou une extension
local SLASH_ALIAS = {
  saison="Season", season="Season", mplus="Season", ["m+"]="Season",
  proche="Nearby", near="Nearby", nearby="Nearby", ici="Nearby", here="Nearby",
  fav="Favs", favs="Favs", favoris="Favs", favorites="Favs",
  mid="Midnight", tww="TheWarWithin", df="Dragonflight", sl="Shadowlands", bfa="BattleForAzeroth",
  leg="Legion", legion="Legion", wod="WarlordsOfDraenor", mop="MistsOfPandaria", cata="Cataclysme",
  cataclysm="Cataclysme", wotlk="WrathOfTheLichKing", wrath="WrathOfTheLichKing", tbc="TheBurningCrusade",
  bc="TheBurningCrusade", van="Vanilla", vanilla="Vanilla", classic="Vanilla",
}
local EXT_FULLNAMES = {
  Midnight="Midnight (12.0)", TheWarWithin="The War Within (11.0)",
  Dragonflight="Dragonflight (10.0)", Shadowlands="Shadowlands (9.0)",
  BattleForAzeroth="Battle for Azeroth (8.0)", Legion="Legion (7.0)",
  WarlordsOfDraenor="Warlords of Draenor (6.0)", MistsOfPandaria="Mists of Pandaria (5.0)",
  Cataclysme=T("EXT_CATA", "Cataclysme (4.0)"), WrathOfTheLichKing="Wrath of the Lich King (3.0)",
  TheBurningCrusade="The Burning Crusade (2.0)", Vanilla="Vanilla (1.0)",
  Season=T("VT_SEASON_FULL", "Saison en cours"), Nearby=T("VT_NEAR_FULL", "Près de moi"),
  Favs=T("VT_FAVS_FULL", "Mes favoris"),
}
local EXT_TAB_COLORS = {
  Midnight={r=0.58,g=0.30,b=0.95}, TheWarWithin={r=0.55,g=0.75,b=0.95},
  Dragonflight={r=0.95,g=0.45,b=0.10}, Shadowlands={r=0.45,g=0.55,b=0.95},
  BattleForAzeroth={r=0.85,g=0.25,b=0.25}, Legion={r=0.60,g=0.15,b=0.85},
  WarlordsOfDraenor={r=0.85,g=0.50,b=0.10}, MistsOfPandaria={r=0.20,g=0.65,b=0.45},
  Cataclysme={r=0.95,g=0.35,b=0.10}, WrathOfTheLichKing={r=0.65,g=0.85,b=1.00},
  TheBurningCrusade={r=0.20,g=0.75,b=0.28}, Vanilla={r=0.80,g=0.72,b=0.55},
  Season={r=1.00,g=0.82,b=0.20}, Nearby={r=0.35,g=0.85,b=0.55}, Favs={r=1.00,g=0.45,b=0.60},
}

-- Couleurs officielles WoW par type
local TYPE_COLORS = {
  dungeon  = {r=0.30, g=0.70, b=1.00},   -- bleu clair
  raid     = {r=0.10, g=0.85, b=0.20},   -- VERT officiel WoW raids
  delve    = {r=0.90, g=0.65, b=0.10},   -- orange/dore
  torghast = {r=0.70, g=0.25, b=0.90},   -- violet
}
local TAB_ORDER = {"dungeon","raid","delve","torghast"}
local TAB_LABELS = {
  dungeon=T("TAB_DUNGEON", "Donjon"), raid=T("TAB_RAID", "Raid"),
  delve=T("TAB_DELVE", "Gouffre"), torghast=T("TAB_TORGHAST", "Tourment"),
}

local IS_ENGLISH = (GetLocale() == "enUS" or GetLocale() == "enGB")
local FAV_ICON = "|A:PetJournal-FavoritesIcon:14:14|a"

local function hex(c) return math.floor((c or 0)*255) end

-- Cle d'accordeon / favori : le nom seul collisionne entre extensions
-- (Naxxramas existe en Vanilla ET en Wrath). On garde le nom de data\ (jamais
-- le nom traduit) : la cle ne change pas avec la langue du client.
local function InstKey(extKey, inst) return (extKey or "") .. "\31" .. (inst.name or "") end
local function KeyOf(inst) return InstKey(inst._ext, inst) end

-- atan2 securise (math.atan2 est deprecie sur les clients recents)
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function Norm(s)
  local ui = GetUI()
  if ui and ui.Normalize then return ui.Normalize(s) end
  return Live.Norm(s)
end

local function Chat(msg) print("|cFF4D99FFDgnTracker|r : " .. msg) end

local function FmtTime(sec)
  sec = tonumber(sec) or 0
  return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function FmtDelay(sec)
  sec = math.max(0, tonumber(sec) or 0)
  local d = math.floor(sec / 86400)
  local h = math.floor((sec % 86400) / 3600)
  if d > 0 then return string.format(T("DELAY_DH", "%d j %d h"), d, h) end
  return string.format(T("DELAY_H", "%d h %02d"), h, math.floor((sec % 3600) / 60))
end

-- ================================================================
-- WAYPOINT (TomTom si present, sinon waypoint natif Blizzard)
-- ================================================================
local function DgnSetWaypoint(inst)
  if not inst then return end
  local m, x, y = Live.Coords(inst)
  local name = (Live.DisplayName(inst))
  if not (m and x and y) then
    Chat(T("WP_NO_COORDS", "coordonnées indisponibles pour") .. " |cFFFFD700"..name.."|r.")
    return
  end
  local fx, fy = x/100, y/100   -- donnees en % -> fraction 0..1
  -- Zone du point, et rappel si le joueur est sur un autre continent : la
  -- fleche (Blizzard comme TomTom) n'apparait qu'une fois sur ce continent.
  local where = Live.MapName(m)
  local label = "|cFFFFD700" .. name .. "|r" .. (where and (" |cFF999999(" .. where .. ")|r") or "")
  local function Elsewhere()
    if Live.SameContinent(m, x, y) == false then
      Chat("|cFFFFAA44" .. T("WP_OTHER_CONTINENT", "vous n'êtes pas sur le bon continent : la flèche apparaîtra une fois arrivé dans cette zone.") .. "|r")
    end
  end

  if TomTom and TomTom.AddWaypoint then
    TomTom:AddWaypoint(m, fx, fy, {
      title = name, from = "DgnTracker",
      persistent = false, minimap = true, world = true,
    })
    Chat(T("WP_TOMTOM_LABEL", "waypoint") .. " |cFF88DD88TomTom|r -> " .. label)
    Elsewhere()
    return
  end

  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    local ok = pcall(function()
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(m, fx, fy))
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
      end
    end)
    if ok then
      Chat(T("WP_MAP_LABEL", "waypoint") .. " |cFF88DDFF" .. T("WP_MAP_WORD", "carte") .. "|r -> " .. label .. " " .. T("WP_OPEN_MAP_HINT", "(ouvrez la carte pour le voir)"))
      Elsewhere()
    else
      Chat(T("WP_NATIVE_FAIL", "impossible de poser un waypoint natif sur cette zone. Installez |cFFFFD700TomTom|r pour un pointeur complet."))
    end
    return
  end

  Chat(T("WP_NONE_AVAILABLE", "aucun système de waypoint disponible. Installez |cFFFFD700TomTom|r."))
end

-- ================================================================
-- JOURNAL D'AVENTURE
-- ================================================================
local function OpenJournal(inst)
  local jid = Live.Info(inst).jid
  if not jid then Chat(T("EJ_UNKNOWN", "cette instance n'est pas reliée au Journal d'aventure.")); return end
  if InCombatLockdown and InCombatLockdown() then Chat(T("EJ_COMBAT", "impossible en combat.")); return end
  if not EncounterJournal_OpenJournal and C_AddOns and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
  end
  local ok = EncounterJournal_OpenJournal and pcall(EncounterJournal_OpenJournal, nil, jid)
  if not ok and ToggleEncounterJournal then pcall(ToggleEncounterJournal) end
end

-- ================================================================
-- FAVORIS
-- ================================================================
local function IsFav(inst) return DgnTrackerDB.favs and DgnTrackerDB.favs[KeyOf(inst)] == true end
local function ToggleFav(inst)
  DgnTrackerDB.favs = DgnTrackerDB.favs or {}
  local k = KeyOf(inst)
  DgnTrackerDB.favs[k] = (not DgnTrackerDB.favs[k]) or nil
end
local function CountFavs()
  local n = 0
  for _ in pairs(DgnTrackerDB.favs or {}) do n = n + 1 end
  return n
end

-- ================================================================
-- LISTES (extension reelle ou vue virtuelle)
-- ================================================================
local seasonStubs = {}   -- donjons M+ absents de data\ (cmid -> instance minimale)
local seasonFound = {}   -- cmid -> instance de data\ deja retrouvee (cache de session)

local function BuildSeasonList()
  local out = {}
  for _, s in ipairs(Live.Season()) do
    local inst = seasonFound[s.cmid]
    if inst == nil then
      inst = Live.Find({ name = s.name, instMapID = s.instMapID, type = "dungeon" }) or false
      seasonFound[s.cmid] = inst
    end
    if not inst then
      inst = seasonStubs[s.cmid]
      if not inst then
        inst = { name = s.name, type = "dungeon", _ext = "Season", mplusOnly = true }
        seasonStubs[s.cmid] = inst
      end
    end
    Live.Info(inst).cmid = s.cmid
    out[#out + 1] = inst
  end
  table.sort(out, function(a, b) return (Live.DisplayName(a)) < (Live.DisplayName(b)) end)
  local raids, delves = {}, {}
  Live.ForEach(function(inst, extKey)
    local ext = DgnTrackerData[extKey]
    if inst.type == "raid" and (inst.current or Live.GetLockouts(inst)) then
      raids[#raids + 1] = inst
    elseif inst.type == "delve" and ext and ext.live then
      delves[#delves + 1] = inst
    end
  end)
  table.sort(delves, function(a, b)
    local ba, bb = Live.Info(a).bountiful and 1 or 0, Live.Info(b).bountiful and 1 or 0
    if ba ~= bb then return ba > bb end
    return (Live.DisplayName(a)) < (Live.DisplayName(b))
  end)
  for _, i in ipairs(raids) do out[#out + 1] = i end
  for _, i in ipairs(delves) do out[#out + 1] = i end
  return out
end

-- Renvoie la liste complete (tous types) de l'extension ou de la vue, et un
-- libelle d'en-tete optionnel.
local function SourceList(extKey)
  if extKey == "Season" then
    for k, ext in pairs(DgnTrackerData) do if ext.live then Live.ResolveExt(k) end end
    Live.RequestSeason()
    local score = Live.OverallScore()
    return BuildSeasonList(), score and score > 0 and string.format(T("SEASON_SCORE", "score M+ : %d"), score) or nil
  elseif extKey == "Nearby" then
    local list, mapID = Live.Nearby()
    return list, mapID and Live.MapName(mapID) or nil
  elseif extKey == "Favs" then
    local out = {}
    local favs = DgnTrackerDB.favs or {}
    Live.ForEach(function(inst) if favs[KeyOf(inst)] then out[#out + 1] = inst end end)
    for _, inst in pairs(seasonStubs) do if favs[KeyOf(inst)] then out[#out + 1] = inst end end
    table.sort(out, function(a, b) return (Live.DisplayName(a)) < (Live.DisplayName(b)) end)
    return out
  end
  Live.ResolveExt(extKey)
  local ext = DgnTrackerData[extKey]
  return ext and ext.instances or {}
end

local function TabsFor(list)
  local seen = {}
  for _, inst in ipairs(list) do seen[inst.type] = true end
  local out = {}
  for _, t in ipairs(TAB_ORDER) do if seen[t] then out[#out + 1] = t end end
  return out
end

-- ================================================================
-- BADGES (verrous, Mythique+, gouffre abondant, detection)
-- ================================================================
local function LockoutText(locks, long)
  if not locks then return nil end
  local parts = {}
  for _, l in ipairs(locks) do
    local tag, col = Live.DiffTag(l)
    if l.total > 0 then
      parts[#parts + 1] = string.format("|cFF%s%s %d/%d|r", col, long and (l.diff ~= "" and l.diff or tag) or tag, l.killed, l.total)
    else
      parts[#parts + 1] = string.format("|cFF%s%s|r", col, long and (l.diff ~= "" and l.diff or tag) or tag)
    end
  end
  return table.concat(parts, "  ")
end

local function Badges(inst)
  local i = Live.Info(inst)
  if not i.cmid then
    local s = Live.SeasonEntryFor(inst)
    if s then i.cmid = s.cmid end
  end
  if DgnTrackerDB.badges == false then return "" end
  local b = {}
  local lk = LockoutText(Live.GetLockouts(inst))
  if lk then b[#b + 1] = lk end
  if i.cmid then
    local mp = Live.MPlusFor(i.cmid)
    if mp and mp.level then
      b[#b + 1] = string.format("|cFF%s+%d|r", mp.over and "E6664D" or "F0BF40", mp.level)
    else
      b[#b + 1] = "|cFF888888M+|r"
    end
  end
  if i.bountiful then b[#b + 1] = "|cFFFFD700" .. T("BADGE_BOUNTIFUL", "Abondant") .. "|r" end
  if inst.detected then b[#b + 1] = "|cFF7FB2B2" .. T("BADGE_DETECTED", "détecté") .. "|r" end
  -- Repaire (12.1) : badge blanc LairLens + difficultes faites cette semaine
  -- (lues via LairLensAPI si le module est charge, sinon badge seul).
  if inst.lair then
    local txt = T("BADGE_LAIR", "Repaire")
    local api = _G.LairLensAPI
    local ok, w = false, nil
    if api and api.GetWeek then ok, w = pcall(api.GetWeek) end
    if ok and type(w) == "table" then txt = txt .. " " .. (w.count or 0) .. "/4" end
    b[#b + 1] = "|cFFFFFFFF" .. txt .. "|r"
  end
  return table.concat(b, "  ")
end

-- ================================================================
-- CONSTRUCTION DE L'INTERFACE
-- ================================================================
local mainFrame

local function BuildUI()
  local CX  = TAB_COL_W + 18
  local CTW = FRAME_W - CX - 14

  mainFrame = CreateFrame("Frame","DGNMainFrame",UIParent,"BackdropTemplate")
  mainFrame:SetSize(FRAME_W, 600)
  mainFrame:SetFrameStrata("HIGH")
  mainFrame:SetMovable(true)
  mainFrame:SetClampedToScreen(true)
  mainFrame:EnableMouse(true)
  mainFrame:RegisterForDrag("LeftButton")
  mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
  mainFrame:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local point,_,_,x,y = s:GetPoint()
    DgnTrackerDB.pos = {point=point,x=x,y=y}
  end)
  -- Fermeture par Echap via UISpecialFrames (mecanisme natif Blizzard) : voir
  -- note detaillee dans TibiSuiteCore.lua (WireEscapeFor). Aucun hook OnHide.
  tinsert(UISpecialFrames, "DGNMainFrame")
  mainFrame:SetBackdrop({
    bgFile="Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=true, tileSize=32, edgeSize=32,
    insets={left=11,right=12,top=12,bottom=11},
  })
  mainFrame:SetBackdropColor(0.04,0.02,0.06,0.97)
  mainFrame:SetBackdropBorderColor(0.72,0.60,0.28,1.0)

  -- ================================================================
  -- TITRE
  -- ================================================================
  local titleStr = mainFrame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  titleStr:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 16, -14)
  titleStr:SetText("|cFF0267FCDgnTracker|r")

  local closeBtn = CreateFrame("Button",nil,mainFrame,"UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT",-5,-5)
  closeBtn:SetScript("OnClick",function() mainFrame:Hide(); DgnTrackerDB.open=false end)

  local drag = mainFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  drag:SetPoint("TOP",0,-30)
  drag:SetText("|cFF888888" .. T("DRAG_HINT", "Glisser pour déplacer") .. "|r")

  local sepTop = mainFrame:CreateTexture(nil,"ARTWORK")
  sepTop:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepTop:SetPoint("TOPLEFT",12,-45)
  sepTop:SetPoint("TOPRIGHT",-12,-45)
  sepTop:SetHeight(1)
  sepTop:SetVertexColor(0.72,0.60,0.28,0.9)

  -- ================================================================
  -- COLONNE GAUCHE : VUES + EXTENSIONS
  -- ================================================================
  local STEP = TAB_H + TAB_GAP
  local COL_CONTENT_H = 58 + #VIRTUAL*STEP + 8 + #EXT_ROW1*STEP + 8 + #EXT_ROW2*STEP + 10

  local tabColBg = CreateFrame("Frame",nil,mainFrame,"BackdropTemplate")
  tabColBg:SetPoint("TOPLEFT",12,-50)
  tabColBg:SetWidth(TAB_COL_W)
  tabColBg:SetHeight(COL_CONTENT_H)
  tabColBg:SetBackdrop({
    bgFile="Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true, tileSize=8, edgeSize=6,
    insets={left=2,right=2,top=2,bottom=2},
  })
  tabColBg:SetBackdropColor(0.02,0.01,0.04,0.85)
  tabColBg:SetBackdropBorderColor(0.72,0.60,0.28,0.35)
  mainFrame.tabColBg = tabColBg

  local extBtns = {}

  local function BuildExtTab(extKey, yOff)
    local col      = EXT_TAB_COLORS[extKey] or {r=0.5,g=0.5,b=0.5}
    local lbl      = EXT_LABELS[extKey] or extKey
    local fullName = EXT_FULLNAMES[extKey] or extKey
    local eb = CreateFrame("Button",nil,mainFrame,"BackdropTemplate")
    eb:SetPoint("TOPLEFT",14,yOff)
    eb:SetSize(TAB_COL_W-4,TAB_H)
    eb:SetBackdrop({
      bgFile="Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
      tile=true, tileSize=8, edgeSize=6,
      insets={left=2,right=2,top=2,bottom=2},
    })
    eb:SetBackdropColor(col.r*0.12,col.g*0.12,col.b*0.12,0.95)
    eb:SetBackdropBorderColor(col.r*0.35,col.g*0.35,col.b*0.35,0.5)
    local eTxt = eb:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    eTxt:SetPoint("LEFT",eb,"LEFT",8,0)
    eTxt:SetSize(TAB_COL_W-34,TAB_H-4)
    eTxt:SetText(string.format("|cFF%02X%02X%02X%s|r",hex(col.r),hex(col.g),hex(col.b),lbl))
    eTxt:SetWordWrap(false)
    eTxt:SetJustifyH("LEFT")
    local cntLbl = eb:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    cntLbl:SetPoint("RIGHT",eb,"RIGHT",-4,0)
    cntLbl:SetJustifyH("RIGHT")
    eb.cntLbl = cntLbl
    eb.extKey = extKey
    eb.col    = col
    eb:SetScript("OnClick",function()
      DgnTrackerDB.extension = extKey
      DgnTrackerDB.activeTab = "dungeon"
      mainFrame:RefreshContent()
      if mainFrame.scrollFrame then mainFrame.scrollFrame:SetVerticalScroll(0) end
    end)
    eb:SetScript("OnEnter",function(s)
      GameTooltip:SetOwner(s,"ANCHOR_RIGHT")
      GameTooltip:AddLine(fullName,col.r,col.g,col.b)
      if extKey == "Season" then
        GameTooltip:AddLine(T("VT_SEASON_TT", "Donjons Mythique+ de la saison, raid en cours et gouffres (abondants en tête)."),0.75,0.75,0.75,true)
      elseif extKey == "Nearby" then
        GameTooltip:AddLine(T("VT_NEAR_TT", "Les instances de la zone où vous êtes, de la plus proche à la plus lointaine."),0.75,0.75,0.75,true)
      elseif extKey == "Favs" then
        GameTooltip:AddLine(T("VT_FAVS_TT", "Maj+clic sur une instance pour l'ajouter ou la retirer."),0.75,0.75,0.75,true)
      else
        local ed = DgnTrackerData[extKey]
        if ed and ed.instances then
          GameTooltip:AddLine(#ed.instances .. " " .. T("INSTANCES_WORD", "instance(s)"),0.75,0.75,0.75)
        end
      end
      GameTooltip:Show()
    end)
    eb:SetScript("OnLeave",function() GameTooltip:Hide() end)
    table.insert(extBtns,eb)
    return eb
  end

  local function Divider(y)
    local t = mainFrame:CreateTexture(nil,"OVERLAY")
    t:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    t:SetPoint("TOPLEFT",mainFrame,"TOPLEFT",14,y)
    t:SetSize(TAB_COL_W-4, 2)
    t:SetVertexColor(0.72,0.60,0.28,1.0)
  end

  local y = -58
  for _, k in ipairs(VIRTUAL) do BuildExtTab(k, y); y = y - STEP end
  Divider(y - 3); y = y - 8
  for _, k in ipairs(EXT_ROW1) do BuildExtTab(k, y); y = y - STEP end
  Divider(y - 3); y = y - 8
  for _, k in ipairs(EXT_ROW2) do BuildExtTab(k, y); y = y - STEP end

  mainFrame.extBtns = extBtns

  local sepVert = mainFrame:CreateTexture(nil,"ARTWORK")
  sepVert:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepVert:SetPoint("TOPLEFT",TAB_COL_W+13,-50)
  sepVert:SetPoint("BOTTOMLEFT",TAB_COL_W+13,12)
  sepVert:SetWidth(1)
  sepVert:SetVertexColor(0.72,0.60,0.28,0.55)

  -- ================================================================
  -- ZONE CONTENU : en-tete
  -- ================================================================
  mainFrame.extActiveLabel = mainFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
  mainFrame.extActiveLabel:SetPoint("TOPLEFT",CX,-52)
  mainFrame.extActiveLabel:SetWidth(CTW)
  mainFrame.extActiveLabel:SetJustifyH("LEFT")
  mainFrame.extActiveLabel:SetWordWrap(false)

  -- ================================================================
  -- ONGLETS INTERNES (Donjon / Raid / Gouffre / Tourment)
  -- ================================================================
  local innerTabY = -72
  local innerTabW = 90
  local innerTabH = 22
  local innerTabGap = 4
  mainFrame.innerTabBtns = {}

  for _, ttype in ipairs(TAB_ORDER) do
    local tc  = TYPE_COLORS[ttype]
    local itb = CreateFrame("Button",nil,mainFrame,"BackdropTemplate")
    itb:SetSize(innerTabW, innerTabH)
    itb:SetBackdrop({
      bgFile="Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
      tile=true, tileSize=8, edgeSize=4,
      insets={left=1,right=1,top=1,bottom=1},
    })
    local itTxt = itb:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    itTxt:SetPoint("CENTER",itb,"CENTER")
    itb.ttype = ttype
    itb.itTxt = itTxt
    itb.tc    = tc
    itb:SetScript("OnClick",function(s)
      DgnTrackerDB.activeTab = s.ttype
      mainFrame:RefreshContent()
      if mainFrame.scrollFrame then mainFrame.scrollFrame:SetVerticalScroll(0) end
    end)
    itb:SetScript("OnEnter",function(s)
      if DgnTrackerDB.activeTab ~= s.ttype then s:SetBackdropBorderColor(tc.r*0.7,tc.g*0.7,tc.b*0.7,0.9) end
    end)
    itb:SetScript("OnLeave",function(s)
      if DgnTrackerDB.activeTab ~= s.ttype then s:SetBackdropBorderColor(tc.r*0.35,tc.g*0.35,tc.b*0.35,0.55) end
    end)
    itb:Hide()
    table.insert(mainFrame.innerTabBtns, itb)
  end

  -- ================================================================
  -- BARRE DE RECHERCHE (filtre sans accents : nom, nom traduit, zone)
  -- ================================================================
  local searchBox = CreateFrame("EditBox", nil, mainFrame, "InputBoxTemplate")
  searchBox:SetSize(150, 20)
  searchBox:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -30, innerTabY - 1)
  searchBox:SetAutoFocus(false)
  searchBox:SetFontObject("GameFontHighlightSmall")
  searchBox:SetMaxLetters(40)
  mainFrame.searchBox  = searchBox
  mainFrame.searchText = ""
  local searchHint = searchBox:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
  searchHint:SetPoint("LEFT", searchBox, "LEFT", 4, 0)
  searchHint:SetText(T("SEARCH_PLACEHOLDER", "Rechercher..."))
  searchBox.hint = searchHint
  searchBox:SetScript("OnTextChanged", function(s)
    local t = s:GetText() or ""
    s.hint:SetShown(t == "")
    mainFrame.searchText = Norm(t:gsub("^%s*(.-)%s*$","%1"))
    if mainFrame.RefreshContent then mainFrame:RefreshContent() end
  end)
  searchBox:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)
  searchBox:SetScript("OnEnterPressed",  function(s) s:ClearFocus() end)

  local sepInner = mainFrame:CreateTexture(nil,"ARTWORK")
  sepInner:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepInner:SetPoint("TOPLEFT",CX, innerTabY - innerTabH - 2)
  sepInner:SetWidth(CTW - 4)
  sepInner:SetHeight(1)
  sepInner:SetVertexColor(0.72,0.60,0.28,0.35)

  -- ================================================================
  -- SCROLL DES INSTANCES
  -- ================================================================
  local scrollFrame = CreateFrame("ScrollFrame",nil,mainFrame,"UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT",CX, innerTabY - innerTabH - 8)
  scrollFrame:SetPoint("BOTTOMRIGHT",-28,16)
  mainFrame.scrollFrame = scrollFrame

  local scrollChild = CreateFrame("Frame",nil,scrollFrame)
  scrollChild:SetSize(CTW - 24, 1)
  scrollFrame:SetScrollChild(scrollChild)
  mainFrame.scrollChild = scrollChild

  -- ================================================================
  -- HELPER : colorisation des textes de conseils
  -- ================================================================
  local function ColorizeAccess(txt)
    if not txt then return "" end
    txt = txt:gsub("([Pp]ortail[%s%w'éèàâêôû%-]*)", "|cFFCC88FF%1|r")
    txt = txt:gsub("([Mm]a%îtres? des [Vv]ols)", "|cFFFFAA44%1|r")
    txt = txt:gsub("([Ff]ly)", "|cFFFFAA44%1|r")
    txt = txt:gsub("([Vv]olez?%s)", "|cFF88DDFF%1|r")
    txt = txt:gsub("(Dalaran)", "|cFFFFFFFF%1|r")
    txt = txt:gsub("(Shattrath)", "|cFFFFFFFF%1|r")
    txt = txt:gsub("(Dornogal)", "|cFFFFFFFF%1|r")
    txt = txt:gsub("(Valdrakken)", "|cFFFFFFFF%1|r")
    txt = txt:gsub("(Orgrimmar)", "|cFFFFFFFF%1|r")
    txt = txt:gsub("(Boralus)", "|cFFFFFFFF%1|r")
    txt = txt:gsub("(Stormwind)", "|cFFFFFFFF%1|r")
    txt = txt:gsub("(Lune%-d'Argent)", "|cFFFFFFFF%1|r")
    txt = txt:gsub("(Portal to [%w' %-]+)", "|cFFCC88FF%1|r")
    txt = txt:gsub("(Flight Master)", "|cFFFFAA44%1|r")
    txt = txt:gsub("(Silvermoon)", "|cFFFFFFFF%1|r")
    txt = txt:gsub("%[H%]", "|cFFFF6666[H]|r")
    txt = txt:gsub("%[A%]", "|cFFAADDFF[A]|r")
    return txt
  end

  local function ColorizePath(txt)
    if not txt then return "" end
    txt = txt:gsub("([Ee]scaliers?)", "|cFFFFCC44%1|r")
    txt = txt:gsub("([Dd]escendez?)", "|cFF88FFAA%1|r")
    txt = txt:gsub("([Mm]ontez?)", "|cFF88FFAA%1|r")
    txt = txt:gsub("([Ee]ntrez?)", "|cFF88FFAA%1|r")
    txt = txt:gsub("([Cc]herchez?)", "|cFF88FFAA%1|r")
    txt = txt:gsub("([Pp]longez?)", "|cFF88FFAA%1|r")
    txt = txt:gsub("([Nn]agez?)", "|cFF88FFAA%1|r")
    txt = txt:gsub("([Ss]tairs)", "|cFFFFCC44%1|r")
    txt = txt:gsub("(Go down)", "|cFF88FFAA%1|r")
    txt = txt:gsub("(Climb)", "|cFF88FFAA%1|r")
    txt = txt:gsub("(Enter)", "|cFF88FFAA%1|r")
    txt = txt:gsub("(Look for)", "|cFF88FFAA%1|r")
    txt = txt:gsub("(Dive)", "|cFF88FFAA%1|r")
    return "|cFFCCCCCC"..txt.."|r"
  end

  -- ── Pools de widgets recyclables (aucune creation par rafraichissement) ──
  mainFrame.headerPool = {}
  mainFrame.detailPool = {}
  mainFrame.rowY = {}

  local BACKDROP = {
    bgFile="Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true, tileSize=8, edgeSize=5,
    insets={left=1,right=1,top=1,bottom=1},
  }

  local function AcquireHeader(i)
    local h = mainFrame.headerPool[i]
    if h then return h end
    h = CreateFrame("Button",nil,scrollChild,"BackdropTemplate")
    h:SetBackdrop(BACKDROP)
    h:RegisterForClicks("LeftButtonUp","RightButtonUp")
    h.toggle = h:CreateFontString(nil,"OVERLAY")
    h.toggle:SetFont("Fonts\\FRIZQT__.TTF",16,"OUTLINE")
    h.toggle:SetPoint("LEFT",h,"LEFT",8,0)
    h.toggle:SetSize(16,16)
    h.nameFS = h:CreateFontString(nil,"OVERLAY")
    h.nameFS:SetFont("Fonts\\FRIZQT__.TTF",11,"OUTLINE")
    h.nameFS:SetPoint("LEFT",h,"LEFT",28,0)
    h.nameFS:SetPoint("RIGHT",h,"RIGHT",-150,0)
    h.nameFS:SetJustifyH("LEFT")
    h.nameFS:SetWordWrap(false)
    h.badgeFS = h:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    h.badgeFS:SetPoint("TOPRIGHT",h,"TOPRIGHT",-8,-5)
    h.badgeFS:SetJustifyH("RIGHT")
    h.zoneFS = h:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    h.zoneFS:SetPoint("BOTTOMRIGHT",h,"BOTTOMRIGHT",-8,5)
    h.zoneFS:SetJustifyH("RIGHT")
    h:SetScript("OnClick",function(s, button)
      local inst = s.inst
      if not inst then return end
      if button == "RightButton" then DgnSetWaypoint(inst); return end
      if IsShiftKeyDown() then ToggleFav(inst); mainFrame:RefreshContent(); return end
      if IsControlKeyDown() then OpenJournal(inst); return end
      local nowOpen = not DgnTrackerDB.expandedInst[s.instKey]
      DgnTrackerDB.expandedInst[s.instKey] = nowOpen or nil
      if nowOpen and DgnTrackerDB.mapPins and not inst.mplusOnly then DgnSetWaypoint(inst) end
      mainFrame:RefreshContent()
    end)
    h:SetScript("OnEnter",function(s)
      local tc = s.tc or {r=0.5,g=0.5,b=0.5}
      if s.inst and not DgnTrackerDB.expandedInst[s.instKey] then
        s:SetBackdropBorderColor(tc.r*0.7,tc.g*0.7,tc.b*0.7,0.9)
      end
      if not s.inst then return end
      GameTooltip:SetOwner(s,"ANCHOR_BOTTOMRIGHT")
      GameTooltip:AddLine((Live.DisplayName(s.inst)),1,0.84,0)
      GameTooltip:AddLine("|cFFFFD700" .. T("LEFT_CLICK_LABEL", "Clic gauche") .. "|r : "..(DgnTrackerDB.expandedInst[s.instKey] and T("CLOSE_WORD", "fermer") or T("SHOW_PATH_WORD", "afficher le chemin")),0.7,0.7,0.7)
      GameTooltip:AddLine("|cFFFFD700" .. T("RIGHT_CLICK_LABEL", "Clic droit") .. "|r : " .. T("SET_WAYPOINT_HINT", "poser un point de route (waypoint)"),0.7,0.7,0.7)
      GameTooltip:AddLine("|cFFFFD700" .. T("SHIFT_CLICK_LABEL", "Maj+clic") .. "|r : " .. (IsFav(s.inst) and T("FAV_REMOVE_HINT", "retirer des favoris") or T("FAV_ADD_HINT", "ajouter aux favoris")),0.7,0.7,0.7)
      if Live.Info(s.inst).jid then
        GameTooltip:AddLine("|cFFFFD700" .. T("CTRL_CLICK_LABEL", "Ctrl+clic") .. "|r : " .. T("EJ_HINT", "ouvrir le Journal d'aventure"),0.7,0.7,0.7)
      end
      GameTooltip:Show()
    end)
    h:SetScript("OnLeave",function(s)
      local tc = s.tc or {r=0.5,g=0.5,b=0.5}
      if s.inst and not DgnTrackerDB.expandedInst[s.instKey] then
        s:SetBackdropBorderColor(tc.r*0.40,tc.g*0.40,tc.b*0.40,0.65)
      end
      GameTooltip:Hide()
    end)
    mainFrame.headerPool[i] = h
    return h
  end

  local function MakeBtn(parent, w, label)
    local ui = GetUI()
    if ui and ui.MakeButton then return ui.MakeButton(parent, w, 18, label) end
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 18); b:SetText(label)
    b._label = b:GetFontString()
    return b
  end

  local function AcquireDetail(i)
    local d = mainFrame.detailPool[i]
    if d then return d end
    d = CreateFrame("Frame",nil,scrollChild,"BackdropTemplate")
    d:SetBackdrop(BACKDROP)
    local function FS(wrap)
      local fs = d:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
      fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP"); fs:SetWordWrap(wrap and true or false)
      return fs
    end
    d.fsBC = FS(false)
    d.lbA, d.fsA = FS(false), FS(true)
    d.lbP, d.fsP = FS(false), FS(true)
    d.fsX = FS(true)   -- lignes jeu : boss, Mythique+, verrous
    d.btnWP  = MakeBtn(d, 118, T("BTN_WAYPOINT", "Point de route"))
    d.btnEJ  = MakeBtn(d, 118, T("BTN_JOURNAL", "Journal d'aventure"))
    d.btnFav = MakeBtn(d, 118, "")
    d.btnWP:SetScript("OnClick", function() DgnSetWaypoint(d.inst) end)
    d.btnEJ:SetScript("OnClick", function() OpenJournal(d.inst) end)
    d.btnFav:SetScript("OnClick", function() ToggleFav(d.inst); mainFrame:RefreshContent() end)
    mainFrame.detailPool[i] = d
    return d
  end

  -- Place un texte a (x, y) avec une largeur fixe et renvoie sa hauteur reelle
  -- (GetStringHeight : plus d'estimation au nombre de caracteres).
  local function Put(fs, parent, x, y, w, text)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(w)
    fs:SetText(text or "")
    fs:Show()
    local h = fs:GetStringHeight() or 12
    if h < 12 then h = 12 end
    fs:SetHeight(h + 2)
    return h + 2
  end

  -- ================================================================
  -- REFRESH CONTENT
  -- ================================================================
  mainFrame.RefreshContent = function(self)
    local extKey  = DgnTrackerDB.extension or "Midnight"
    if not (IS_VIRTUAL[extKey] or DgnTrackerData[extKey]) then extKey = "Midnight"; DgnTrackerDB.extension = extKey end
    local extCol  = EXT_TAB_COLORS[extKey] or {r=1,g=0.84,b=0}
    local extFull = EXT_FULLNAMES[extKey] or extKey

    local source, sub = SourceList(extKey)

    self.extActiveLabel:SetText(string.format(
      "|cFFFFD700%s|r  |cFF%02X%02X%02X%s|r%s",
      IS_VIRTUAL[extKey] and T("VIEW_LABEL", "Vue :") or T("EXTENSION_LABEL", "Extension :"),
      hex(extCol.r),hex(extCol.g),hex(extCol.b),extFull,
      sub and ("  |cFF999999" .. sub .. "|r") or ""))

    -- ── Colonne : surbrillance + compteurs ─────────────────────────
    for _,eb in ipairs(self.extBtns or {}) do
      local col = eb.col
      if eb.extKey == extKey then
        eb:SetBackdropColor(col.r*0.40,col.g*0.40,col.b*0.40,1.0)
        eb:SetBackdropBorderColor(col.r,col.g,col.b,1.0)
      else
        eb:SetBackdropColor(col.r*0.12,col.g*0.12,col.b*0.12,0.95)
        eb:SetBackdropBorderColor(col.r*0.35,col.g*0.35,col.b*0.35,0.5)
      end
      local n = 0
      if eb.extKey == "Favs" then n = CountFavs()
      elseif not IS_VIRTUAL[eb.extKey] then
        local ed = DgnTrackerData[eb.extKey]
        n = ed and ed.instances and #ed.instances or 0
      end
      eb.cntLbl:SetText(n>0 and string.format("|cFF888888%d|r",n) or "")
    end

    -- ── Onglets internes : selon les types presents ───────────────
    local tabs = TabsFor(source)
    local activeTab = DgnTrackerDB.activeTab or "dungeon"
    local valid = false
    for _, t in ipairs(tabs) do if t == activeTab then valid = true; break end end
    if not valid and #tabs > 0 then activeTab = tabs[1]; DgnTrackerDB.activeTab = activeTab end

    for _,itb in ipairs(self.innerTabBtns) do
      local pos
      for i, t in ipairs(tabs) do if t == itb.ttype then pos = i; break end end
      if pos then
        local tc = itb.tc
        itb:ClearAllPoints()
        itb:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", CX + (pos-1) * (innerTabW + innerTabGap), innerTabY)
        local lbl = TAB_LABELS[itb.ttype]
        if extKey == "Season" and itb.ttype == "dungeon" then lbl = T("TAB_MPLUS", "Mythique+") end
        if itb.ttype == activeTab then
          itb:SetBackdropColor(tc.r*0.35,tc.g*0.35,tc.b*0.35,1.0)
          itb:SetBackdropBorderColor(tc.r,tc.g,tc.b,1.0)
          itb.itTxt:SetText("|cFFFFFFFF" .. lbl .. "|r")
        else
          itb:SetBackdropColor(tc.r*0.08,tc.g*0.08,tc.b*0.08,0.95)
          itb:SetBackdropBorderColor(tc.r*0.35,tc.g*0.35,tc.b*0.35,0.55)
          itb.itTxt:SetText(string.format("|cFF%02X%02X%02X%s|r", hex(tc.r*0.7),hex(tc.g*0.7),hex(tc.b*0.7), lbl))
        end
        itb:Show()
      else
        itb:Hide()
      end
    end

    -- ── Filtre type + recherche ─────────────────────────────────
    local filter = self.searchText or ""
    local instList = {}
    for _, inst in ipairs(source) do
      if inst.type == activeTab then
        if filter == "" then
          instList[#instList + 1] = inst
        else
          local hay = Norm((inst.name or "") .. " " .. ((Live.DisplayName(inst))) .. " " .. (inst.zone or "") .. " " .. (inst.region or ""))
          if hay:find(filter, 1, true) then instList[#instList + 1] = inst end
        end
      end
    end

    DgnTrackerDB.expandedInst = DgnTrackerDB.expandedInst or {}
    wipe(self.rowY)

    -- ── Liste vide ─────────────────────────────────────────────────
    if #instList == 0 then
      for _,h in ipairs(self.headerPool) do h:Hide() end
      for _,d in ipairs(self.detailPool) do d:Hide() end
      if not self.emptyLbl then
        self.emptyLbl = scrollChild:CreateFontString(nil,"OVERLAY","GameFontNormal")
        self.emptyLbl:SetPoint("TOP",scrollChild,"TOP",0,-40)
        self.emptyLbl:SetWidth(CTW - 60)
      end
      local msg
      if filter ~= "" then
        msg = "|cFF666666" .. T("NO_RESULT_FOR", "Aucun résultat pour") .. "|r |cFFFFD700"..filter.."|r|cFF666666.|r"
      elseif extKey == "Season" then
        msg = "|cFF666666" .. T("EMPTY_SEASON", "Données de saison pas encore reçues du serveur. Rouvrez la fenêtre dans quelques secondes.") .. "|r"
      elseif extKey == "Nearby" then
        msg = "|cFF666666" .. T("EMPTY_NEAR", "Aucune instance connue dans cette zone.") .. "|r"
      elseif extKey == "Favs" then
        msg = "|cFF666666" .. T("EMPTY_FAVS", "Aucun favori. Maj+clic sur une instance pour l'ajouter.") .. "|r"
      else
        msg = "|cFF666666" .. T("NO_INSTANCE_CATEGORY", "Aucune instance disponible pour cette catégorie.") .. "|r"
      end
      self.emptyLbl:SetText(msg)
      self.emptyLbl:Show()
      scrollChild:SetHeight(100)
      self:SetHeight(math.max(COL_CONTENT_H + 70, 400))
      self.tabColBg:SetHeight(math.max(COL_CONTENT_H + 70, 400) - 64)
      return
    end
    if self.emptyLbl then self.emptyLbl:Hide() end

    -- ============================================================
    -- ACCORDEON (widgets recycles)
    -- ============================================================
    local rowW   = scrollChild:GetWidth() - 6
    local curY   = 0
    local HEADER_H = 38
    local GAP    = 3
    local hIdx, dIdx = 0, 0
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "Horde"

    for _, inst in ipairs(instList) do
      local tc      = TYPE_COLORS[inst.type] or {r=0.5,g=0.5,b=0.5}
      local instKey = KeyOf(inst)
      local isOpen  = DgnTrackerDB.expandedInst[instKey] == true
      local info    = Live.Info(inst)
      local dname, note = Live.DisplayName(inst)

      -- ── EN-TETE ─────────────────────────────────────────────────
      hIdx = hIdx + 1
      local hdr = AcquireHeader(hIdx)
      hdr.inst, hdr.instKey, hdr.tc = inst, instKey, tc
      hdr:ClearAllPoints()
      hdr:SetPoint("TOPLEFT",0,-curY)
      hdr:SetSize(rowW, HEADER_H)
      self.rowY[instKey] = curY
      if isOpen then
        hdr:SetBackdropColor(tc.r*0.18,tc.g*0.18,tc.b*0.18,0.98)
        hdr:SetBackdropBorderColor(tc.r,tc.g,tc.b,0.95)
      else
        hdr:SetBackdropColor(tc.r*0.07,tc.g*0.07,tc.b*0.07,0.95)
        hdr:SetBackdropBorderColor(tc.r*0.40,tc.g*0.40,tc.b*0.40,0.65)
      end
      hdr.toggle:SetText(string.format("|cFF%02X%02X%02X%s|r", hex(tc.r),hex(tc.g),hex(tc.b), isOpen and "-" or "+"))
      hdr.nameFS:SetText((IsFav(inst) and (FAV_ICON .. " ") or "") ..
        (isOpen and "|cFFFFD700" or "|cFFDDCC88") .. dname .. "|r" ..
        (note and ("  |cFF888888(" .. note .. ")|r") or ""))
      hdr.badgeFS:SetText(Badges(inst))

      -- Hors client francais : nom de zone donne par le jeu (langue du client)
      local zone = inst.zone or ""
      if not Live.IS_FR then zone = Live.MapName(info.mapID or inst.mapID) or zone end
      local m, x, y = Live.Coords(inst)
      local right = "|cFF888888" .. zone .. "|r"
      if x and y then
        right = right .. string.format("  |cFF99CCFF%s%.1f, %.1f|r", (inst.approx and not info.x) and "~" or "", x, y)
      end
      if extKey == "Nearby" and info.dist then
        right = right .. string.format("  |cFF88DD88" .. T("DIST_FMT", "%d m") .. "|r", math.floor(info.dist + 0.5))
      end
      hdr.zoneFS:SetText(right)
      hdr:Show()
      curY = curY + HEADER_H + GAP

      -- ── DETAIL (deplie) ─────────────────────────────────────────
      if isOpen then
        dIdx = dIdx + 1
        local det = AcquireDetail(dIdx)
        det.inst = inst
        det:ClearAllPoints()
        det:SetPoint("TOPLEFT",0,-curY)
        det:SetWidth(rowW)
        det:SetBackdropColor(tc.r*0.05,tc.g*0.05,tc.b*0.05,0.97)
        det:SetBackdropBorderColor(tc.r*0.60,tc.g*0.60,tc.b*0.60,0.7)

        local iX, iY = 14, -6
        local textW = rowW - iX - 20

        -- Fil d'Ariane : Extension > Region > Secteur > Zone > Nom
        local parts = {}
        local srcExt = inst._ext
        parts[#parts + 1] = string.format("|cFF666666%s|r", EXT_FULLNAMES[srcExt] or srcExt or "")
        -- Region et secteur n'existent qu'en francais dans data\ : omis ailleurs
        if Live.IS_FR and inst.region and inst.region ~= "" then parts[#parts + 1] = string.format("|cFFAA8855%s|r", inst.region) end
        if Live.IS_FR and inst.sector and inst.sector ~= "" and inst.sector ~= inst.region then
          parts[#parts + 1] = string.format("|cFFCC9944%s|r", inst.sector)
        end
        if zone ~= "" then parts[#parts + 1] = string.format("|cFF99CCFF%s|r", zone) end
        parts[#parts + 1] = string.format("|cFFDDCC88%s|r", dname)
        iY = iY - Put(det.fsBC, det, iX, iY, textW, table.concat(parts, " |cFF555555>|r ")) - 4

        local hdrCol = string.format("|cFF%02X%02X%02X", hex(tc.r),hex(tc.g),hex(tc.b))
        -- Langue des conseils : francais sur un client francais ; anglais
        -- (data\Access_enUS.lua) sur tous les autres, avec la mention
        -- "(en anglais)" dans la langue du joueur, sauf client anglais.
        -- Une fiche sans traduction retombe sur le francais, mention a l'appui.
        local acc, pathText, langNote = inst.access, inst.path, ""
        if not Live.IS_FR then
          local enExt = DgnTrackerAccessEN and DgnTrackerAccessEN[inst._ext]
          local en = enExt and enExt[inst.name]
          if en then
            acc = { both = en.b, alliance = en.a, horde = en.h }
            pathText = en.p or pathText
            if not IS_ENGLISH then langNote = "  |cFF777777" .. T("TIPS_EN_NOTE", "(in English)") .. "|r" end
          elseif inst.access or inst.path then
            langNote = "  |cFF777777" .. T("TIPS_FR_NOTE", "(en français)") .. "|r"
          end
        end

        -- Acces
        local accessText
        if acc then
          if acc.both then accessText = acc.both
          elseif faction=="Alliance" and acc.alliance then accessText = acc.alliance
          elseif faction=="Horde" and acc.horde then accessText = acc.horde
          elseif acc.alliance then accessText = "[A] "..acc.alliance
          elseif acc.horde then accessText = "[H] "..acc.horde
          end
        end
        if accessText then
          iY = iY - Put(det.lbA, det, iX, iY, textW, hdrCol .. T("ACCESS_HEADER", "-- Accès (chemin le plus court) :") .. "|r" .. langNote)
          iY = iY - Put(det.fsA, det, iX + 6, iY, textW - 6, ColorizeAccess(accessText)) - 6
        elseif inst.detected or inst.mplusOnly then
          det.lbA:Hide()
          iY = iY - Put(det.fsA, det, iX, iY, textW, "|cFF999999" ..
            (inst.detected and T("DETECTED_NOTE", "Instance détectée dans le jeu : pas encore de conseils d'accès. Le point de route utilise la position fournie par le jeu.")
              or T("MPLUS_ONLY_NOTE", "Donjon de la rotation Mythique+ absent des fiches de DgnTracker : pas de conseils d'accès pour l'instant.")) .. "|r") - 6
        else
          det.lbA:Hide(); det.fsA:Hide()
        end

        -- Conseils
        if pathText and pathText ~= "" then
          iY = iY - Put(det.lbP, det, iX, iY, textW, hdrCol .. T("TIPS_HEADER", "-- Conseils :") .. "|r" .. (accessText and "" or langNote))
          iY = iY - Put(det.fsP, det, iX + 6, iY, textW - 6, ColorizePath(pathText)) - 6
        else
          det.lbP:Hide(); det.fsP:Hide()
        end

        -- Lignes jeu : boss, Mythique+, verrous
        local extra = {}
        local bosses = info.jid and Live.Bosses(info.jid)
        if bosses and #bosses > 0 then
          extra[#extra + 1] = hdrCol .. string.format(T("BOSSES_FMT", "Boss (%d) :"), #bosses) .. "|r |cFFCCCCCC" .. table.concat(bosses, ", ") .. "|r"
        end
        if info.cmid then
          local mp = Live.MPlusFor(info.cmid)
          if mp and mp.level then
            local s = string.format(T("MPLUS_BEST_FMT", "Meilleure clé de la saison : %s+%d|r (%s)"),
              mp.over and "|cFFE6664D" or "|cFFF0BF40", mp.level, mp.sec and FmtTime(mp.sec) or "?")
            if mp.over then s = s .. " |cFFE6664D" .. T("MPLUS_OVERTIME", "hors temps") .. "|r" end
            if mp.score then s = s .. "  |cFF999999·|r  " .. string.format(T("MPLUS_SCORE_FMT", "score %d"), mp.score) end
            extra[#extra + 1] = hdrCol .. T("MPLUS_LABEL", "Mythique+") .. "|r  " .. s
          else
            extra[#extra + 1] = hdrCol .. T("MPLUS_LABEL", "Mythique+") .. "|r  |cFF999999" .. T("MPLUS_NONE", "aucune clé terminée cette saison") .. "|r"
          end
        end
        local locks = Live.GetLockouts(inst)
        if locks then
          local reset = locks[1].expires - (GetServerTime and GetServerTime() or time())
          extra[#extra + 1] = hdrCol .. T("LOCKED_LABEL", "Verrouillé") .. "|r  " .. LockoutText(locks, true) ..
            "  |cFF999999" .. string.format(T("RESET_IN_FMT", "reset dans %s"), FmtDelay(reset)) .. "|r"
        end
        if info.bountiful then
          extra[#extra + 1] = "|cFFFFD700" .. T("BOUNTIFUL_LINE", "Gouffre abondant aujourd'hui : coffre bonus avec une clé de coffre.") .. "|r"
        end
        if #extra > 0 then
          iY = iY - Put(det.fsX, det, iX, iY, textW, table.concat(extra, "\n")) - 6
        else
          det.fsX:Hide()
        end

        -- Boutons
        local bx = iX
        det.btnWP:ClearAllPoints(); det.btnWP:SetPoint("TOPLEFT", det, "TOPLEFT", bx, iY)
        det.btnWP:SetShown(not inst.mplusOnly and inst.type ~= "torghast")
        if det.btnWP:IsShown() then bx = bx + 124 end
        det.btnEJ:ClearAllPoints(); det.btnEJ:SetPoint("TOPLEFT", det, "TOPLEFT", bx, iY)
        det.btnEJ:SetShown(info.jid ~= nil)
        if det.btnEJ:IsShown() then bx = bx + 124 end
        det.btnFav:ClearAllPoints(); det.btnFav:SetPoint("TOPLEFT", det, "TOPLEFT", bx, iY)
        det.btnFav._label:SetText(IsFav(inst) and T("BTN_UNFAV", "Retirer des favoris") or T("BTN_FAV", "Ajouter aux favoris"))
        det.btnFav:Show()
        iY = iY - 18 - 8

        local detH = -iY
        det:SetHeight(detH)
        det:Show()
        curY = curY + detH + GAP
      end
    end

    for i = hIdx+1, #self.headerPool do self.headerPool[i]:Hide() end
    for i = dIdx+1, #self.detailPool do self.detailPool[i]:Hide() end

    scrollChild:SetHeight(math.max(curY + 10, 100))

    -- Hauteur auto : contenu + chrome, plafonnee a l'ecran (socle)
    local minH = math.max(COL_CONTENT_H + 70, 400)
    local ui = GetUI()
    local newH
    if ui and ui.FitHeight then
      newH = ui.FitHeight(self, math.min(curY, 700), { chrome = 120, min = minH, margin = 80 })
    else
      newH = math.max(minH, math.min(curY + 120, 820))
      self:SetHeight(newH)
    end
    self.tabColBg:SetHeight(newH - 64)
  end

  -- Fait defiler jusqu'a une instance (API publique)
  mainFrame.ScrollToKey = function(self, key)
    local y = self.rowY[key]
    if not y then return end
    C_Timer.After(0, function()
      local sf = self.scrollFrame
      if sf.UpdateScrollChildRect then sf:UpdateScrollChildRect() end
      local maxS = sf:GetVerticalScrollRange() or 0
      sf:SetVerticalScroll(math.max(0, math.min(y - 4, maxS)))
    end)
  end

  mainFrame:SetScript("OnShow", function()
    Live.RequestLockouts()
    Live.RequestSeason()
  end)

  mainFrame:Hide()
end

-- Rafraichit la fenetre quand le jeu renvoie de nouvelles donnees
Live.onChange = function()
  if mainFrame and mainFrame:IsShown() then mainFrame:RefreshContent() end
end

-- ================================================================
-- OUVERTURE / API
-- ================================================================
local function ShowMain()
  if not mainFrame:IsShown() then mainFrame:Show(); DgnTrackerDB.open = true end
  mainFrame:RefreshContent()
end

function DgnTracker_Toggle()
  if mainFrame:IsShown() then
    mainFrame:Hide()
    DgnTrackerDB.open = false
  else
    ShowMain()
  end
end

-- Ouvre la fenetre directement sur une instance (dans son extension), depliee.
-- q : nom (toute langue connue), instance de DgnTrackerData, ou table
--     { name=, instMapID=, challengeMapID=, jid=, type= }. Renvoie true si trouvee.
function DgnTracker_OpenInstance(q)
  if not mainFrame then return false end
  local inst
  if type(q) == "table" and q.type and q.name and q._ext then inst = q
  else inst = Live.Find(q) end
  if not inst then
    if type(q) == "table" and q.challengeMapID then
      DgnTrackerDB.extension = "Season"; DgnTrackerDB.activeTab = "dungeon"
      ShowMain()
      local key = "Season\31" .. (q.name or "")
      for _, s in pairs(seasonStubs) do
        if Live.Info(s).cmid == q.challengeMapID then key = KeyOf(s) end
      end
      DgnTrackerDB.expandedInst[key] = true
      mainFrame:RefreshContent(); mainFrame:ScrollToKey(key)
      return true
    end
    return false
  end
  local ext = inst._ext
  DgnTrackerDB.extension = (ext and DgnTrackerData[ext]) and ext or "Season"
  DgnTrackerDB.activeTab = inst.type
  if mainFrame.searchBox and mainFrame.searchBox:GetText() ~= "" then mainFrame.searchBox:SetText("") end
  DgnTrackerDB.expandedInst[KeyOf(inst)] = true
  ShowMain()
  mainFrame:ScrollToKey(KeyOf(inst))
  return true
end

-- ================================================================
-- BOUTON MINIMAP (mode autonome uniquement : masque par le core en suite)
-- ================================================================
local minimapBtn

local function GetMinimapRadius()
  return (Minimap:GetWidth()/2) + 10
end

local function SetMinimapPos(angle)
  angle = angle % 360
  if DgnTrackerDB then DgnTrackerDB.mmAngle = angle end
  local r   = GetMinimapRadius()
  local rad = math.rad(angle)
  minimapBtn:ClearAllPoints()
  minimapBtn:SetPoint("CENTER",Minimap,"CENTER",math.cos(rad)*r,math.sin(rad)*r)
end

local function BuildMinimapButton()
  minimapBtn = CreateFrame("Button","DGNMinimapBtn",Minimap)
  minimapBtn:SetSize(32,32)
  minimapBtn:SetFrameStrata("MEDIUM")
  minimapBtn:SetFrameLevel(8)
  minimapBtn:EnableMouse(true)
  minimapBtn:SetClampedToScreen(true)
  minimapBtn:SetToplevel(true)

  local icon = minimapBtn:CreateTexture(nil,"ARTWORK")
  icon:SetPoint("CENTER",0,0)
  icon:SetSize(24,24)
  icon:SetTexture("Interface\\AddOns\\DgnTracker\\medias\\DgnTracker")
  local mask = minimapBtn:CreateMaskTexture()
  mask:SetAllPoints(icon)
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
    "CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
  icon:AddMaskTexture(mask)

  local ring = minimapBtn:CreateTexture(nil,"OVERLAY")
  ring:SetSize(52,52)
  ring:SetPoint("TOPLEFT",minimapBtn,"TOPLEFT",0,0)
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  local hl = minimapBtn:CreateTexture(nil,"ARTWORK")
  hl:SetPoint("CENTER",0,0)
  hl:SetSize(20,20)
  hl:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
  hl:SetVertexColor(1,1,1,0.25)
  hl:SetAlpha(0)
  minimapBtn._hl = hl

  SetMinimapPos((DgnTrackerDB and DgnTrackerDB.mmAngle) or 195)
  minimapBtn:SetScript("OnShow",function()
    SetMinimapPos((DgnTrackerDB and DgnTrackerDB.mmAngle) or 195)
  end)
  minimapBtn:RegisterForDrag("LeftButton")
  minimapBtn:SetScript("OnDragStart",function(s)
    s:SetScript("OnUpdate",function()
      local mx,my = Minimap:GetCenter()
      local sc = UIParent:GetEffectiveScale()
      local cx,cy = GetCursorPosition()
      SetMinimapPos(math.deg(atan2((cy/sc)-my,(cx/sc)-mx)))
    end)
  end)
  minimapBtn:SetScript("OnDragStop",function(s) s:SetScript("OnUpdate",nil) end)

  local rw = CreateFrame("Frame")
  rw:RegisterEvent("MINIMAP_UPDATE_ZOOM")
  rw:SetScript("OnEvent",function()
    SetMinimapPos((DgnTrackerDB and DgnTrackerDB.mmAngle) or 195)
  end)

  minimapBtn:SetScript("OnClick",function(_,btn)
    if btn=="LeftButton" then DgnTracker_Toggle() end
  end)
  minimapBtn:SetScript("OnEnter",function(s)
    if s._hl then s._hl:SetAlpha(1) end
    GameTooltip:SetOwner(s,"ANCHOR_LEFT")
    GameTooltip:AddLine("|cFF0070DEDgnTracker|r",0.30,0.70,1.0)
    GameTooltip:AddLine(T("MM_TT_SUBTITLE", "Tracker des instances & raids"),0.9,0.9,0.9)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cFFFFD700" .. T("LEFT_CLICK_LABEL", "Clic gauche") .. "|r : " .. T("TOGGLE_HINT", "ouvrir / fermer"),0.7,0.7,0.7)
    GameTooltip:AddLine("|cFFFFD700" .. T("DRAG_LABEL", "Glisser") .. "|r : " .. T("REPOSITION_HINT", "repositionner l'icône"),0.7,0.7,0.7)
    GameTooltip:Show()
  end)
  minimapBtn:SetScript("OnLeave",function(s)
    if s._hl then s._hl:SetAlpha(0) end
    GameTooltip:Hide()
  end)
end

-- ================================================================
-- COMMANDES SLASH
-- ================================================================
local function GoTo(target, tab)
  DgnTrackerDB.extension = target
  DgnTrackerDB.activeTab = tab or "dungeon"
  ShowMain()
end

SLASH_DGNTRACKER1 = "/dg"
SLASH_DGNTRACKER2 = "/tibidgn"
SlashCmdList["DGNTRACKER"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s*(.-)%s*$","%1")

  if msg=="help" or msg=="aide" then
    print("|cFF4D99FFDgnTracker|r " .. T("HELP_COMMANDS_LABEL", "commandes :"))
    print("  |cFFFFD700/dg|r           - " .. T("HELP_TOGGLE", "Ouvrir/fermer la fenêtre"))
    print("  |cFFFFD700/dg saison|r    - " .. T("HELP_SEASON", "Saison en cours (Mythique+, raid, gouffres)"))
    print("  |cFFFFD700/dg proche|r    - " .. T("HELP_NEAR", "Instances de la zone où vous êtes"))
    print("  |cFFFFD700/dg fav|r       - " .. T("HELP_FAVS", "Vos favoris"))
    print("  |cFFFFD700/dg <extension>|r - " .. T("HELP_EXTENSION", "Aller à une extension (ex : mid, tww, df, sl, van)"))
    print("  |cFFFFD700/dg <nom>|r     - " .. T("HELP_FIND", "Ouvrir une instance par son nom"))
    print("  |cFFFFD700/dg options|r   - " .. T("HELP_OPTIONS", "Ouvrir les options"))
    print("  |cFFFFD700/dg map on|r    - " .. T("HELP_MAP_ON", "Waypoint auto à l'ouverture d'une instance"))
    print("  |cFFFFD700/dg map off|r   - " .. T("HELP_MAP_OFF", "Désactiver le waypoint auto"))
    print("  |cFFFFD700/dg expand|r    - " .. T("HELP_EXPAND", "Tout déplier (extension active)"))
    print("  |cFFFFD700/dg reset|r     - " .. T("HELP_RESET", "Tout replier (accordéon)"))
    print("  |cFFFFD700/dg check|r     - " .. T("HELP_CHECK", "Contrôle : compare chaque fiche à la position donnée par le jeu"))
    print("  |cFFFFD700/dg probe|r     - " .. T("HELP_PROBE", "Sonde : enregistre ce que renvoie le jeu (pour corriger les données)"))
    print("  |cFF888888" .. T("HELP_TIP", "Astuce : clic droit sur une instance = poser un waypoint.") .. "|r")
    return

  elseif msg=="options" or msg=="config" then
    if DgnTracker_OpenOptions then DgnTracker_OpenOptions() end
    return

  elseif msg=="reset" then
    DgnTrackerDB.expandedInst = {}
    if mainFrame:IsShown() then mainFrame:RefreshContent() end
    Chat(T("ACCORDION_RESET", "accordéon réinitialisé."))
    return

  elseif msg=="expand" or msg=="all" then
    local ext = DgnTrackerDB.extension or "Midnight"
    local ed = DgnTrackerData[ext]
    if ed and ed.instances then
      for _, inst in ipairs(ed.instances) do
        DgnTrackerDB.expandedInst[InstKey(ext, inst)] = true
      end
    end
    ShowMain()
    Chat(T("EXPANDED_ALL_FOR", "tout déplié pour") .. " |cFFFFD700"..(EXT_FULLNAMES[ext] or ext).."|r.")
    return

  elseif msg=="map on" or msg=="mapon" then
    DgnTrackerDB.mapPins = true
    Chat(T("AUTO_WAYPOINT_LABEL", "waypoint auto") .. " |cFF88DD88" .. T("ENABLED_WORD", "activé") .. "|r " .. T("ON_INSTANCE_OPEN", "(à l'ouverture d'une instance)") .. ".")
    return
  elseif msg=="map off" or msg=="mapoff" then
    DgnTrackerDB.mapPins = false
    Chat(T("AUTO_WAYPOINT_LABEL", "waypoint auto") .. " |cFFFF8888" .. T("DISABLED_WORD", "désactivé") .. "|r.")
    return

  elseif msg=="probe" or msg=="sonde" then
    local m, a, x = Live.Probe()
    Chat(string.format(T("PROBE_DONE", "sonde terminée : %d instances reconnues, %d ajoutées depuis le jeu, %d sans correspondance. Faites /reload pour écrire le fichier DgnTracker.lua (SavedVariables)."), m, a, x))
    if mainFrame:IsShown() then mainFrame:RefreshContent() end
    return
  elseif msg=="check" or msg=="controle" or msg=="contrôle" then
    local r = Live.Check()
    Chat(string.format(T("CHECK_DONE", "contrôle : %d fiches au bon endroit, %d corrigées par le jeu, %d introuvables dans le jeu."), r.ok, #r.moved, #r.missing))
    local shown = 0
    for _, e in ipairs(r.moved) do
      if shown >= 15 then break end
      shown = shown + 1
      print(string.format("  |cFFFFD700%s|r  |cFF888888%s %.1f, %.1f|r -> |cFF88DD88%s %.1f, %.1f|r",
        (Live.DisplayName(e.inst)), tostring(e.fromMap), e.fx or 0, e.fy or 0, tostring(e.toMap), e.tx or 0, e.ty or 0))
    end
    for _, inst in ipairs(r.missing) do
      if shown >= 25 then break end
      shown = shown + 1
      print(string.format("  |cFFFF8888%s|r  |cFF888888(%s)|r", (Live.DisplayName(inst)), T("CHECK_NOT_FOUND", "introuvable")))
    end
    local total = #r.moved + #r.missing
    if total > shown then
      print("  |cFF888888" .. string.format(T("CHECK_MORE", "... et %d autres."), total - shown) .. "|r")
    end
    -- La note "les points de route suivent le jeu" ne vaut que pour les
    -- fiches corrigees ; les introuvables gardent la position de data\.
    if #r.missing > 0 then
      print("  |cFF888888" .. T("CHECK_MISSING_NOTE", "Introuvables : entrée absente des cartes du jeu (instance retirée, saisonnière ou ancienne version). Le point de route utilise la position approximative de la fiche.") .. "|r")
    end
    if #r.moved > 0 then
      print("  |cFF888888" .. T("CHECK_NOTE", "Les points de route suivent déjà la position du jeu. Faites /reload et envoyez WTF\\...\\SavedVariables\\DgnTracker.lua à Tibiscui pour corriger les fiches.") .. "|r")
    end
    if mainFrame:IsShown() then mainFrame:RefreshContent() end
    return
  elseif msg=="probe clear" or msg=="sonde clear" then
    DgnTrackerDB.probe = nil
    Chat(T("PROBE_CLEARED", "sonde effacée."))
    return

  elseif msg=="torghast" or msg=="tourment" then
    GoTo("Shadowlands", "torghast")
    return
  end

  if msg ~= "" then
    local target = SLASH_ALIAS[msg]
    if not target then
      for key in pairs(DgnTrackerData) do if msg == key:lower() then target = key end end
    end
    if target then
      GoTo(target)
      Chat(T("EXTENSION_ARROW", "extension ->") .. " |cFFFFD700"..(EXT_FULLNAMES[target] or target).."|r")
      return
    end
    -- Sinon : recherche d'une instance par son nom (exact, puis partiel)
    if DgnTracker_OpenInstance(msg) then return end
    local loose = Live.FindLoose(msg)
    if loose and DgnTracker_OpenInstance(loose) then return end
    Chat(T("UNKNOWN_COMMAND", "commande inconnue. Tapez |cFFFFD700/dg help|r."))
    return
  end

  DgnTracker_Toggle()
end

-- ================================================================
-- EVENEMENTS
-- ================================================================
local evFrame = CreateFrame("Frame")
evFrame:RegisterEvent("ADDON_LOADED")
evFrame:RegisterEvent("PLAYER_LOGIN")
evFrame:SetScript("OnEvent",function(_,event,arg1)
  if event=="ADDON_LOADED" and arg1==ADDON then
    local db = DgnTrackerDB
    db.activeTab = db.activeTab or "dungeon"
    db.expandedInst = db.expandedInst or {}
    db.favs = db.favs or {}
    -- Purge des anciennes cles (nom seul, avant InstKey) et des cles fermees
    for k, v in pairs(db.expandedInst) do
      if v ~= true or not tostring(k):find("\31", 1, true) then db.expandedInst[k] = nil end
    end
    -- Midnight devient l'extension par defaut (une seule fois : un choix fait
    -- ensuite par le joueur est conserve).
    if not db.midnightDefault then
      if db.extension == nil or db.extension == "TheWarWithin" then db.extension = "Midnight" end
      db.midnightDefault = true
    end
    Live.Index()
    BuildUI()
    BuildMinimapButton()
    local p = db.pos
    if p and p.x then
      mainFrame:ClearAllPoints()
      mainFrame:SetPoint(p.point or "CENTER",UIParent,p.point or "CENTER",p.x,p.y)
    else
      mainFrame:SetPoint("CENTER",UIParent,"CENTER",0,0)
    end
    db.open = false  -- ferme automatiquement au login

  elseif event=="PLAYER_LOGIN" then
    -- En suite, on suit le reglage du core (TibiSuiteDB.loginMsg) : seul
    -- "full" fait parler les modules. En autonome, message complet.
    local mode = "full"
    if HasCore() then mode = (TibiSuiteDB and TibiSuiteDB.loginMsg) or "one" end
    if mode == "full" then
      print("|cFF4D99FFDgnTracker|r v7.1.5.38 " .. T("LOGIN_LOADED", "chargé --") .. " |cFFFFD700/dg|r " .. T("LOGIN_TO_OPEN", "pour ouvrir."))
    end
  end
end)
