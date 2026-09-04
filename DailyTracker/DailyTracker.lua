-- ================================================================
-- DailyTracker v7.0
-- Auteur : Tibiscui - Kirin Tor
-- Pool de frames (anti-fuite) + refresh throttlé
-- Scroll réel, i18n FR/EN, suivi manuel, timers de reset,
-- compteur global, filtre "à faire", reduire/deployer, diagnostic questID
-- ================================================================

local ADDON = "DailyTracker"
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

-- ================================================================
-- LOCALISATION (evolution 10) - FR par defaut, EN en fallback
-- Seule l'interface est traduite ; les donnees (noms de quetes,
-- PNJ, zones) restent celles du jeu.
-- ================================================================
local FRFR = {
  DRAG_HINT       = "Glisser pour deplacer  -  /dt",
  BY              = "by Tibiscui",
  F_ALL           = "Tout",
  F_WEEKLY        = "Hebdo",
  F_DAILY         = "Quotidien",
  F_ONETIME       = "Unique",
  TODO            = "A faire",
  COLLAPSE_ALL    = "Reduire tout",
  EXPAND_ALL      = "Deployer tout",
  CAT_PRINCIPALE  = "Factions Principales",
  CAT_SECONDAIRE  = "Factions Secondaires",
  CAT_PVP         = "PvP",
  TAG_WEEKLY      = "[Hebdo]",
  TAG_ONETIME     = "[Unique]",
  TAG_DAILY       = "[Quotidien]",
  SEC_WEEKLY      = "Quetes hebdomadaires",
  SEC_ONETIME     = "Quetes uniques",
  SEC_DAILY       = "Quetes quotidiennes",
  ACTIVITIES      = "Activites : ",
  ACT_COUNT       = "Activites : %d / %d",
  TOTAL           = "Total : %d / %d",
  ZONE            = "Zone : ",
  NPC             = "PNJ :",
  COORDS          = "Coord. :",
  REP             = "Rep. :",
  REP_SUFFIX      = " rep.",
  DONE            = "Complete",
  NOTDONE         = "Non complete",
  NO_QUESTID      = "(Pas de questID - suivi manuel)",
  AUTO_DONE       = "Auto",
  AUTO_TODO       = "Auto",
  MANUAL_DONE     = "Fait",
  MANUAL_TODO     = "A faire",
  MANUAL_HINT     = "Clic : marquer fait / a faire",
  WAYPOINT_HINT   = "[Clic] Waypoint TomTom",
  RESET_DAILY     = "Quotidien",
  RESET_WEEKLY    = "Hebdo",
  MM_LEFT         = "Clic gauche : ouvrir / fermer",
  MM_DRAG         = "Glisser : repositionner l'icone",
  COMPART_SUB     = "Activites quotidiennes & hebdomadaires",
  LOGIN_MSG       = "|cFFFFD700DailyTracker|r v7.0 - |cFFFFD700/dt|r pour ouvrir.",
  CHECK_HEADER    = "Diagnostic questID (les IDs non resolus sont a verifier) :",
  CHECK_OK        = "OK",
  CHECK_MISSING   = "NON RESOLU",
  CHECK_MANUAL    = "manuel (pas de questID)",
  CHECK_DONE      = "Diagnostic termine. Utilise ces resultats pour corriger les IDs douteux.",
  HELP            = "Commandes : /dt (ouvrir), /dt options (options), /dt check (verifier les questID), /dt help",
}
local ENUS = {
  DRAG_HINT       = "Drag to move  -  /dt",
  BY              = "by Tibiscui",
  F_ALL           = "All",
  F_WEEKLY        = "Weekly",
  F_DAILY         = "Daily",
  F_ONETIME       = "One-time",
  TODO            = "To do",
  COLLAPSE_ALL    = "Collapse all",
  EXPAND_ALL      = "Expand all",
  CAT_PRINCIPALE  = "Main Factions",
  CAT_SECONDAIRE  = "Secondary Factions",
  CAT_PVP         = "PvP",
  TAG_WEEKLY      = "[Weekly]",
  TAG_ONETIME     = "[One-time]",
  TAG_DAILY       = "[Daily]",
  SEC_WEEKLY      = "Weekly quests",
  SEC_ONETIME     = "One-time quests",
  SEC_DAILY       = "Daily quests",
  ACTIVITIES      = "Activities: ",
  ACT_COUNT       = "Activities: %d / %d",
  TOTAL           = "Total: %d / %d",
  ZONE            = "Zone: ",
  NPC             = "NPC:",
  COORDS          = "Coords:",
  REP             = "Rep:",
  REP_SUFFIX      = " rep.",
  DONE            = "Completed",
  NOTDONE         = "Not completed",
  NO_QUESTID      = "(No questID - manual tracking)",
  AUTO_DONE       = "Auto",
  AUTO_TODO       = "Auto",
  MANUAL_DONE     = "Done",
  MANUAL_TODO     = "To do",
  MANUAL_HINT     = "Click: toggle done / to do",
  WAYPOINT_HINT   = "[Click] TomTom waypoint",
  RESET_DAILY     = "Daily",
  RESET_WEEKLY    = "Weekly",
  MM_LEFT         = "Left click: open / close",
  MM_DRAG         = "Drag: reposition icon",
  COMPART_SUB     = "Daily & weekly activities",
  LOGIN_MSG       = "|cFFFFD700DailyTracker|r v7.0 - |cFFFFD700/dt|r to open.",
  CHECK_HEADER    = "questID diagnostic (unresolved IDs need review):",
  CHECK_OK        = "OK",
  CHECK_MISSING   = "UNRESOLVED",
  CHECK_MANUAL    = "manual (no questID)",
  CHECK_DONE      = "Diagnostic done. Use these results to fix doubtful IDs.",
  HELP            = "Commands: /dt (open), /dt options (options), /dt check (verify questIDs), /dt help",
}
local L = FRFR
do
  local loc = (GetLocale and GetLocale()) or "frFR"
  if loc=="enUS" or loc=="enGB" then
    L = setmetatable(ENUS, {__index=FRFR})
  end
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

-- Secondes avant reset (evolution 6). Robuste si l'API manque.
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

-- Suivi manuel persistant (evolution 5) : pour les quetes sans questID.
-- onetime -> true (permanent) ; daily/weekly -> timestamp d'expiration (reset auto).
local function ManualKey(extKey, facName, questName)
  return (extKey or "?").."::"..(facName or "?").."::"..(questName or "?")
end
local function IsManualDone(extKey, fac, quest)
  local db = DailyTrackerDB.manual
  if not db then return false end
  local v = db[ManualKey(extKey, fac.name, quest.name)]
  if not v then return false end
  if quest.type=="onetime" then
    return v==true or type(v)=="number"
  else
    if type(v)=="number" then return time() < v end
    return v==true
  end
end
local function ToggleManual(extKey, fac, quest)
  DailyTrackerDB.manual = DailyTrackerDB.manual or {}
  local key = ManualKey(extKey, fac.name, quest.name)
  if IsManualDone(extKey, fac, quest) then
    DailyTrackerDB.manual[key] = nil
  else
    if quest.type=="onetime" then
      DailyTrackerDB.manual[key] = true
    elseif quest.type=="weekly" then
      DailyTrackerDB.manual[key] = time() + SecUntilWeeklyReset()
    else
      DailyTrackerDB.manual[key] = time() + SecUntilDailyReset()
    end
  end
end
-- Purge des completions manuelles expirees (au chargement).
local function PurgeExpiredManual()
  local db = DailyTrackerDB.manual
  if type(db)~="table" then DailyTrackerDB.manual={}; return end
  local now = time()
  for k,v in pairs(db) do
    if type(v)=="number" and now>=v then db[k]=nil end
  end
end

-- Completion unifiee : questID auto OU suivi manuel.
local function IsQuestComplete(extKey, fac, quest)
  if quest.questID then return IsQuestDone(quest.questID) end
  return IsManualDone(extKey, fac, quest)
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

local function GetFactionsByCategory(cat, extKey)
  local result = {}
  for _, fac in ipairs(GetActiveFactions(extKey)) do
    if (fac.category or "secondaire") == cat then table.insert(result,fac) end
  end
  table.sort(result, function(a,b) return a.name < b.name end)
  return result
end

local function GetSelectedFac()
  local sf = DailyTrackerDB.selectedFac
  if not sf then return nil, nil end
  return sf.cat, sf.name
end
local function SetSelectedFac(cat, name)
  DailyTrackerDB.selectedFac = {cat=cat, name=name}
end

local function GetFactionQuestStats(fac, extKey)
  extKey = extKey or DailyTrackerDB.extension
  local total, done = 0, 0
  for _, q in ipairs(fac.quests or {}) do
    if q.type ~= "onetime" then
      total = total + 1
      if IsQuestComplete(extKey, fac, q) then done = done + 1 end
    end
  end
  return done, total
end

local function GetExtStats(extKey)
  extKey = extKey or DailyTrackerDB.extension
  local total, done = 0, 0
  for _, fac in ipairs(GetActiveFactions(extKey)) do
    local d, t = GetFactionQuestStats(fac, extKey); done=done+d; total=total+t
  end
  return done, total
end

-- Format duree compacte "3j 5h" / "5h 12m" / "12m"
local function FormatDuration(sec)
  sec = math.max(0, math.floor(sec or 0))
  local d = math.floor(sec/86400)
  local h = math.floor((sec%86400)/3600)
  local m = math.floor((sec%3600)/60)
  if d>0 then return string.format("%dj %dh", d, h) end
  if h>0 then return string.format("%dh %dm", h, m) end
  return string.format("%dm", m)
end
local function FormatResetInfo()
  return string.format("|cFF888888%s:|r |cFFCCCCCC%s|r   |cFF888888%s:|r |cFFCCCCCC%s|r",
    L.RESET_DAILY,  FormatDuration(SecUntilDailyReset()),
    L.RESET_WEEKLY, FormatDuration(SecUntilWeeklyReset()))
end

-- ================================================================
-- FRAME PRINCIPALE
-- ================================================================
local mainFrame

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

  -- ----------------------------------------------------------
  -- TITRE FLOTTANT
  -- ----------------------------------------------------------
  local titleBg = CreateFrame("Frame",nil,mainFrame,"BackdropTemplate")
  titleBg:SetPoint("TOP",mainFrame,"TOP",0,14)
  titleBg:SetSize(360,44)
  titleBg:SetFrameLevel(mainFrame:GetFrameLevel()+2)
  titleBg:SetBackdrop({
    bgFile="Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=true,tileSize=32,edgeSize=20,
    insets={left=7,right=7,top=7,bottom=7},
  })
  titleBg:SetBackdropColor(0.04,0.02,0.06,0.97)
  titleBg:SetBackdropBorderColor(0.72,0.60,0.28,1.0)

  local logoL = titleBg:CreateTexture(nil,"OVERLAY")
  logoL:SetSize(20,20)
  logoL:SetTexture("Interface\\AddOns\\DailyTracker\\medias\\DailyTracker")
  local logoR = titleBg:CreateTexture(nil,"OVERLAY")
  logoR:SetSize(20,20)
  logoR:SetTexture("Interface\\AddOns\\DailyTracker\\medias\\DailyTracker")

  local titleStr = titleBg:CreateFontString(nil,"OVERLAY")
  titleStr:SetFont("Fonts\\FRIZQT__.TTF",12,"OUTLINE")
  titleStr:SetPoint("CENTER",titleBg,"CENTER",0,5)
  titleStr:SetText("|cFFFFD700DailyTracker - |r|cFF9480FFMidnight|r")
  logoL:SetPoint("RIGHT",titleStr,"LEFT",-6,0)
  logoR:SetPoint("LEFT",titleStr,"RIGHT",6,0)
  mainFrame._titleStr = titleStr

  local byLine = titleBg:CreateFontString(nil,"OVERLAY")
  byLine:SetFont("Fonts\\FRIZQT__.TTF",9,"OUTLINE")
  byLine:SetPoint("TOP",titleStr,"BOTTOM",0,0)
  byLine:SetText("|cFFF58CBA"..L.BY.."|r")

  -- TibiSuite : en-tête comme WeeklyCompass (titre à l'intérieur, haut-gauche)
  logoL:Hide(); logoR:Hide()
  byLine:Hide()
  titleBg:Hide()
  titleStr:SetParent(mainFrame)
  titleStr:SetFontObject("GameFontNormalLarge")
  titleStr:ClearAllPoints()
  titleStr:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 16, -14)
  titleStr:SetText("|cFF16C4FCDailyTracker|r")

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
    row.nameFS:SetPoint("RIGHT",row,"RIGHT",-105,0)
    row.nameFS:SetJustifyH("LEFT") ; row.nameFS:SetWordWrap(false)
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
      GameTooltip:AddLine(L.ZONE..(s._zone or ""),0.8,0.8,0.8) ; GameTooltip:Show()
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
      GameTooltip:AddLine(quest.name,1,1,1)
      if quest.questID then
        if done then GameTooltip:AddLine(L.DONE.." (ID: "..quest.questID..")",0.3,0.9,0.4)
        else GameTooltip:AddLine(L.NOTDONE.." (ID: "..quest.questID..")",0.8,0.5,0.3) end
      else GameTooltip:AddLine(L.NO_QUESTID,0.5,0.5,0.7) end
      GameTooltip:AddLine(L.ZONE..quest.zone,0.7,0.7,0.7)
      GameTooltip:AddLine("+"..(quest.rep or 0)..L.REP_SUFFIX,tc.r,tc.g,tc.b)
      if s._tipText~="" then GameTooltip:AddLine(" "); GameTooltip:AddLine(s._tipText,0.8,0.8,0.8,true) end
      if quest.mapID and TomTom then GameTooltip:AddLine("|cFFFFD700"..L.WAYPOINT_HINT.."|r") end
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
      if quest.coords and quest.mapID and TomTom then
        local x2,y2=quest.coords:match("([%d%.]+),%s*([%d%.]+)")
        if x2 and y2 then
          TomTom:AddWaypoint(quest.mapID,tonumber(x2)/100,tonumber(y2)/100,{title=quest.name,persistent=false})
          print("|cFFFFD700DailyTracker|r Waypoint : "..quest.name)
        end
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
  -- REFRESH CONTENT
  -- ============================================================
  mainFrame.RefreshContent = function(self)

    ResetPools()

    local extKey  = DailyTrackerDB.extension or "Midnight"
    local extCol  = EXT_TAB_COLORS[extKey] or {r=1,g=0.84,b=0}
    local filter  = DailyTrackerDB.filter or "all"
    local hideDone= DailyTrackerDB.hideCompleted and true or false

    -- Titre : nom seul, sobre, à la couleur d'identité (pas de "- Midnight")
    self._titleStr:SetText("|cFF16C4FCDailyTracker|r")

    -- Compteur global (evolution 2)
    local gDone,gTotal = GetExtStats(extKey)
    self._counter:SetText(string.format("|cFFFFD700"..L.TOTAL.."|r", gDone, gTotal))

    -- Timers reset (evolution 6)
    self._resetInfo:SetText(FormatResetInfo())

    -- Etat bouton reduire/deployer (evolution 3)
    local sdb=DailyTrackerDB.sections
    local allOpen = sdb.weekly and sdb.onetime and sdb.daily
    self._collapseBtn._txt:SetText(string.format("|cFF%02X%02X%02X%s|r",
      math.floor(0.98*255),math.floor(0.95*255),math.floor(0.80*255),
      allOpen and L.COLLAPSE_ALL or L.EXPAND_ALL))

    -- Highlight onglets extension
    for _, eb in ipairs(self.extBtns or {}) do
      local col=eb.col or {r=0.5,g=0.5,b=0.5}
      if eb.extKey==extKey then
        eb:SetBackdropColor(col.r*0.40,col.g*0.40,col.b*0.40,1.0)
        eb:SetBackdropBorderColor(col.r,col.g,col.b,1.0)
        if eb.accent then eb.accent:SetVertexColor(col.r,col.g,col.b,1.0) end
      else
        eb:SetBackdropColor(col.r*0.12,col.g*0.12,col.b*0.12,0.95)
        eb:SetBackdropBorderColor(col.r*0.35,col.g*0.35,col.b*0.35,0.5)
        if eb.accent then eb.accent:SetVertexColor(col.r,col.g,col.b,0.5) end
      end
    end

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

    -- Highlight toggle "A faire" (evolution 4)
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

    -- AUTO-SIZING HORIZONTAL
    local maxNameLen = 0
    for _, q in ipairs(fac.quests) do
      if (filter=="all" or filter==q.type) then
        if not (hideDone and IsQuestComplete(extKey, fac, q)) then
          if #q.name>maxNameLen then maxNameLen=#q.name end
        end
      end
    end
    local neededW  = CX + maxNameLen*7 + 240
    local newW     = math.max(W_MIN, math.min(W_MAX, neededW))
    self:SetWidth(newW)

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

    local function PopulateQuestRow(quest, yOff, facRef)
      local tc   = TYPE_COLORS[quest.type]  or {r=1,g=1,b=1}
      local tlbl = TYPE_LABELS[quest.type]  or ""
      local fc   = (facRef and facRef.color) or {r=0.5,g=0.5,b=0.5}
      local done = IsQuestComplete(extKey, facRef, quest)

      local tipText      = quest.tip or ""
      local charsPerLine = math.max(20, math.floor(textW/7))
      local tipLines     = math.max(1, math.min(math.ceil(#tipText/charsPerLine),6))
      local rowH         = 64 + tipLines*14 + 6

      local row = AcquireWidget("questRow")
      row:SetPoint("TOPLEFT",self.questContent,"TOPLEFT",2,-yOff)
      row:SetSize(qcW,rowH)
      if done then
        row:SetBackdropColor(0.05,0.05,0.05,0.6)
        row:SetBackdropBorderColor(0.3,0.3,0.3,0.4)
      else
        row:SetBackdropColor(tc.r*0.08,tc.g*0.08,tc.b*0.08,0.95)
        row:SetBackdropBorderColor(tc.r*0.4,tc.g*0.4,tc.b*0.4,0.6)
      end

      if quest.questID then
        if done then row.si:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); row.si:SetVertexColor(0.3,1.0,0.4,1)
        else row.si:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady"); row.si:SetVertexColor(0.7,0.3,0.3,0.7) end
      else
        if done then row.si:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); row.si:SetVertexColor(0.3,1.0,0.4,1)
        else row.si:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting"); row.si:SetVertexColor(0.6,0.6,0.6,0.5) end
      end

      if done then row.typeTag:SetText("|cFF555566"..tlbl.." |r")
      else row.typeTag:SetText(string.format("|cFF%02X%02X%02X%s|r",math.floor(tc.r*255),math.floor(tc.g*255),math.floor(tc.b*255),tlbl)) end

      -- Auto vs manuel (evolution 5)
      if quest.questID then
        row.autoLabel:Show()
        row.autoLabel:SetText(done and "|cFF44AA44"..L.AUTO_DONE.."|r" or "|cFF555566"..L.AUTO_TODO.."|r")
        row.manualBtn:Hide()
      else
        row.autoLabel:Hide()
        row.manualBtn:Show()
        row.manualBtn._ext=extKey ; row.manualBtn._fac=facRef ; row.manualBtn._quest=quest
        row.manualBtn._txt:SetText(done and "|cFF44DD66"..L.MANUAL_DONE.."|r" or "|cFFCCAA44"..L.MANUAL_TODO.."|r")
      end

      row.qName:SetSize(textW,16)
      row.qName:SetText(done and "|cFF888888"..quest.name.."|r" or "|cFFEEEEEE"..quest.name.."|r")

      row.npcStr:SetSize(textW,14)
      if done then row.npcStr:SetText("|cFF555555"..L.NPC.." "..quest.npc.."  "..L.COORDS.." "..quest.coords.."|r")
      else row.npcStr:SetText("|cFF888888"..L.NPC.."|r |cFFCCBB88"..quest.npc.."|r  |cFF888888"..L.COORDS.."|r |cFF99CCFF"..quest.coords.."|r") end

      row.repStr:SetSize(textW*0.55,14)
      if done then row.repStr:SetText("|cFF555555"..L.REP.." +"..(quest.rep or 0).."|r")
      else row.repStr:SetText(string.format("|cFF888888"..L.REP.."|r |cFF%02X%02X%02X+%d|r",math.floor(fc.r*255),math.floor(fc.g*255),math.floor(fc.b*255),quest.rep or 0)) end

      row.zStr:SetText(done and "|cFF444455"..quest.zone.."|r" or "|cFF555577"..quest.zone.."|r")

      if tipText~="" then
        row.tipStr:Show()
        row.tipStr:SetSize(textW,tipLines*14)
        row.tipStr:SetText(done and "|cFF444455"..tipText.."|r" or "|cFF777777"..tipText.."|r")
      else
        row.tipStr:Hide()
      end

      row._quest=quest ; row._fac=facRef ; row._done=done ; row._tc=tc ; row._tipText=tipText
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
        local grpDone=0
        for _, q in ipairs(grp.quests) do if IsQuestComplete(extKey, fac, q) then grpDone=grpDone+1 end end
        local allDone=(grpDone==#grp.quests)

        local header=AcquireWidget("questHeader")
        header:SetPoint("TOPLEFT",self.questContent,"TOPLEFT",2,-y)
        header:SetSize(qcW,26)
        if allDone then header:SetBackdropColor(0.05,0.10,0.05,0.95); header:SetBackdropBorderColor(0.3,0.6,0.3,0.7)
        else header:SetBackdropColor(tc.r*0.15,tc.g*0.15,tc.b*0.15,0.95); header:SetBackdropBorderColor(tc.r*0.5,tc.g*0.5,tc.b*0.5,0.7) end

        header.arrow:SetText(isOpen and "|cFFFFD700-|r" or "|cFF888888+|r")
        if allDone then header.label:SetText(string.format("|cFF4DCC72%s  (%d/%d)|r",grp.label,grpDone,#grp.quests))
        else header.label:SetText(string.format("|cFF%02X%02X%02X%s|r  |cFF888888(%d/%d)|r",math.floor(tc.r*255),math.floor(tc.g*255),math.floor(tc.b*255),grp.label,grpDone,#grp.quests)) end
        header._sectionKey=grp.key ; header._tc=tc

        if isOpen then
          local curRowY=y+28
          for _, quest in ipairs(grp.quests) do
            -- evolution 4 : masquer les completees si le mode est actif
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

    -- --------------------------------------------------------
    -- AUTO-SIZING VERTICAL + DEFILEMENT (evolution 1)
    -- --------------------------------------------------------
    local questH = math.max(40, y+12)

    -- Hauteur max de viewport pour rester sous H_MAX
    local maxVP = math.max(60, H_MAX - qScrollY - 12 - MARGIN_BOT - 4)
    local viewportH = math.min(questH, maxVP)
    local scrollBgH = viewportH + 12

    self.questContent:SetSize(viewportW, questH)
    self.scrollFrame:SetSize(viewportW, viewportH)
    self.scrollBg:SetHeight(scrollBgH)

    -- Barre de defilement
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

  end -- RefreshContent

  -- Ticker : rafraichit uniquement le texte des timers de reset (evolution 6)
  C_Timer.NewTicker(30, function()
    if mainFrame and mainFrame:IsShown() and mainFrame._resetInfo then
      mainFrame._resetInfo:SetText(FormatResetInfo())
    end
  end)

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
    local d, t = GetExtStats(ext)
    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cFF40C7EBDailyTracker|r", 0.58, 0.30, 0.95)
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
  GameTooltip:AddLine("|cFFFFD700DailyTracker|r")
  GameTooltip:AddLine(L.COMPART_SUB,0.8,0.8,0.9) ; GameTooltip:Show()
end
function DailyTracker_OnAddonCompartmentLeave() GameTooltip:Hide() end

-- ================================================================
-- DIAGNOSTIC questID (evolution 9)
-- Verifie chaque questID contre les donnees du jeu et signale les
-- IDs non resolus (a corriger a la main). N'invente aucune donnee.
-- ================================================================
local function RunQuestIDCheck()
  print("|cFFFFD700DailyTracker|r "..L.CHECK_HEADER)
  local getTitle = C_QuestLog and C_QuestLog.GetTitleForQuestID
  for _, extKey in ipairs(EXT_ORDER) do
    print("|cFF9480FF== "..(EXT_FULLNAMES[extKey] or extKey).." ==|r")
    for _, fac in ipairs(GetActiveFactions(extKey)) do
      for _, q in ipairs(fac.quests or {}) do
        if q.questID then
          local title = getTitle and getTitle(q.questID) or nil
          if title and title~="" then
            print(string.format("  |cFF44CC44%s|r [%d] %s -> %s", L.CHECK_OK, q.questID, q.name, title))
          else
            print(string.format("  |cFFFF5555%s|r [%d] %s", L.CHECK_MISSING, q.questID, q.name))
          end
        else
          print(string.format("  |cFF888888%s|r %s", L.CHECK_MANUAL, q.name))
        end
      end
    end
  end
  if C_QuestLog and C_QuestLog.RequestLoadQuestByID then
    -- Precharge les titres pour un second passage plus fiable
    for _, extKey in ipairs(EXT_ORDER) do
      for _, fac in ipairs(GetActiveFactions(extKey)) do
        for _, q in ipairs(fac.quests or {}) do
          if q.questID then C_QuestLog.RequestLoadQuestByID(q.questID) end
        end
      end
    end
  end
  print("|cFFFFD700DailyTracker|r "..L.CHECK_DONE)
end

-- ================================================================
-- SLASH
-- ================================================================
SLASH_DAILYTRACKER1="/dt" ; SLASH_DAILYTRACKER2="/daily"
SlashCmdList["DAILYTRACKER"]=function(msg)
  msg = (msg or ""):lower():gsub("^%s+",""):gsub("%s+$","")
  if msg=="check" or msg=="verify" then
    RunQuestIDCheck() ; return
  elseif msg=="help" then
    print("|cFFFFD700DailyTracker|r "..L.HELP) ; return
  elseif msg=="options" or msg=="config" then
    if DailyTracker_OpenOptions then DailyTracker_OpenOptions() end ; return
  end
  if not mainFrame then return end
  if mainFrame:IsShown() then mainFrame:Hide(); DailyTrackerDB.open=false
  else mainFrame:Show(); mainFrame:RefreshContent(); DailyTrackerDB.open=true end
end

-- ================================================================
-- REFRESH THROTTLE
-- ================================================================
local _refreshPending=false
local function RequestRefresh()
  if not (mainFrame and mainFrame:IsShown() and mainFrame.RefreshContent) then return end
  if _refreshPending then return end
  _refreshPending=true
  C_Timer.After(0.3,function()
    _refreshPending=false
    if mainFrame and mainFrame:IsShown() and mainFrame.RefreshContent then
      mainFrame:RefreshContent()
    end
  end)
end

-- ================================================================
-- EVENEMENTS
-- ================================================================
local evFrame=CreateFrame("Frame")
evFrame:RegisterEvent("ADDON_LOADED") ; evFrame:RegisterEvent("PLAYER_LOGIN")
evFrame:RegisterEvent("QUEST_TURNED_IN") ; evFrame:RegisterEvent("QUEST_LOG_UPDATE")
evFrame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED") ; evFrame:RegisterEvent("UPDATE_FACTION")
evFrame:RegisterEvent("ZONE_CHANGED") ; evFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
evFrame:RegisterEvent("ZONE_CHANGED_INDOORS")

evFrame:SetScript("OnEvent",function(_,event,arg1)
  if event=="ADDON_LOADED" and arg1==ADDON then
    if not DailyTrackerDB.sections then DailyTrackerDB.sections={weekly=true,daily=true,onetime=false} end
    if not DailyTrackerDB.filter   then DailyTrackerDB.filter="all" end
    if not DailyTrackerDB.groups   then DailyTrackerDB.groups={principale=true,secondaire=true,pvp=false} end
    if DailyTrackerDB.hideCompleted==nil then DailyTrackerDB.hideCompleted=false end
    if type(DailyTrackerDB.manual)~="table" then DailyTrackerDB.manual={} end
    PurgeExpiredManual()

    BuildUI() ; BuildMinimapButton()
    local p=DailyTrackerDB.pos
    if p and p.x then
      mainFrame:ClearAllPoints()
      mainFrame:SetPoint(p.point or "CENTER",UIParent,p.point or "CENTER",p.x,p.y)
    else mainFrame:SetPoint("CENTER",UIParent,"CENTER",0,0) end

    -- evolution 8 : on respecte l'etat ouvert/ferme memorise
    if DailyTrackerDB.open then
      mainFrame:Show() ; mainFrame:RefreshContent()
    end

  elseif event=="ADDON_LOADED" and arg1=="TibiSuite" then
    if minimapBtn then minimapBtn:Hide() end

  elseif event=="PLAYER_LOGIN" then
    C_Timer.After(2,function()
      print(L.LOGIN_MSG)
      if mainFrame and mainFrame:IsShown() and mainFrame.RefreshContent then mainFrame:RefreshContent() end
    end)

  elseif event=="QUEST_TURNED_IN" or event=="QUEST_LOG_UPDATE"
      or event=="MAJOR_FACTION_RENOWN_LEVEL_CHANGED" or event=="UPDATE_FACTION"
      or event=="ZONE_CHANGED" or event=="ZONE_CHANGED_NEW_AREA" or event=="ZONE_CHANGED_INDOORS" then
    RequestRefresh()
  end
end)

-- ================================================================
-- TOGGLE PUBLIC -- appele par TibiSuite
-- ================================================================
function DailyTracker_Toggle()
  if not mainFrame then return end
  if mainFrame:IsShown() then
    mainFrame:Hide()
    DailyTrackerDB.open = false
  else
    mainFrame:Show()
    mainFrame:RefreshContent()
    DailyTrackerDB.open = true
  end
end
