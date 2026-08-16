-- ================================================================
-- DgnTracker v3.0
-- Auteur : Tibiscui - Kirin Tor
-- ================================================================

local ADDON = "DgnTracker"
DgnTrackerData = DgnTrackerData or {}

DgnTrackerDB = DgnTrackerDB or {
  pos        = {point="CENTER", x=0, y=0},
  open       = false,
  extension  = "TheWarWithin",
  mmAngle    = 195,
  activeTab  = "dungeon",   -- onglet actif dans la fenêtre (dungeon/raid/delve/torghast/tourment)
  expandedInst = {},
  mapPins    = false,       -- pose auto d'un waypoint (TomTom/carte) à l'ouverture d'une instance
}

-- ================================================================
-- CONSTANTES
-- ================================================================
local FRAME_W   = 700
local TAB_COL_W = 96
local TAB_H     = 28
local TAB_GAP   = 2

local EXT_ROW1 = {"Midnight","TheWarWithin","Dragonflight","Shadowlands","BattleForAzeroth","Legion"}
local EXT_ROW2 = {"WarlordsOfDraenor","MistsOfPandaria","Cataclysme","WrathOfTheLichKing","TheBurningCrusade","Vanilla"}

local EXT_LABELS = {
  Midnight="MID", TheWarWithin="TWW", Dragonflight="DF",
  Shadowlands="SL", BattleForAzeroth="BfA", Legion="LEG",
  WarlordsOfDraenor="WoD", MistsOfPandaria="MoP", Cataclysme="CATA",
  WrathOfTheLichKing="WotLK", TheBurningCrusade="TBC", Vanilla="VAN",
  Torghast="⚡Torghast",
}
local EXT_FULLNAMES = {
  Midnight="Midnight (12.0)", TheWarWithin="The War Within (11.0)",
  Dragonflight="Dragonflight (10.0)", Shadowlands="Shadowlands (9.0)",
  BattleForAzeroth="Battle for Azeroth (8.0)", Legion="Legion (7.0)",
  WarlordsOfDraenor="Warlords of Draenor (6.0)", MistsOfPandaria="Mists of Pandaria (5.0)",
  Cataclysme="Cataclysme (4.0)", WrathOfTheLichKing="Wrath of the Lich King (3.0)",
  TheBurningCrusade="The Burning Crusade (2.0)", Vanilla="Vanilla (1.0)",
  Torghast="Torghast - Tour des Damnés (SL 9.x)",
}
local EXT_TAB_COLORS = {
  Midnight={r=0.58,g=0.30,b=0.95}, TheWarWithin={r=0.55,g=0.75,b=0.95},
  Dragonflight={r=0.95,g=0.45,b=0.10}, Shadowlands={r=0.45,g=0.55,b=0.95},
  BattleForAzeroth={r=0.85,g=0.25,b=0.25}, Legion={r=0.60,g=0.15,b=0.85},
  WarlordsOfDraenor={r=0.85,g=0.50,b=0.10}, MistsOfPandaria={r=0.20,g=0.65,b=0.45},
  Cataclysme={r=0.95,g=0.35,b=0.10}, WrathOfTheLichKing={r=0.65,g=0.85,b=1.00},
  TheBurningCrusade={r=0.20,g=0.75,b=0.28}, Vanilla={r=0.80,g=0.72,b=0.55},
  Torghast={r=0.75,g=0.20,b=0.85},
}

-- Couleurs officielles WoW par type
local TYPE_COLORS = {
  dungeon  = {r=0.30, g=0.70, b=1.00},   -- bleu clair
  raid     = {r=0.10, g=0.85, b=0.20},   -- VERT officiel WoW raids
  delve    = {r=0.90, g=0.65, b=0.10},   -- orange/doré
  torghast = {r=0.70, g=0.25, b=0.90},   -- violet
  tourment = {r=0.70, g=0.25, b=0.90},   -- violet
}
local TYPE_LABELS = {
  dungeon="Donjon", raid="Raid", delve="Gouffre", torghast="Tourment", tourment="Tourment",
}

-- Onglets internes globaux (Tourment uniquement dans Shadowlands via onglet Torghast)
local INNER_TABS = {"dungeon","raid","delve"}
local INNER_TAB_LABELS = {
  dungeon="Donjon", raid="Raid", delve="Gouffre",
}

local function hex(c) return math.floor((c or 0)*255) end

-- atan2 sécurisé (math.atan2 est déprécié sur les clients récents ;
-- math.atan(y,x) est la forme moderne). On garde une compat sans risque.
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

-- ================================================================
-- WAYPOINT (TomTom si présent, sinon waypoint natif Blizzard)
-- ================================================================
local function DgnSetWaypoint(inst)
  if not inst then return end
  -- Priorité aux coords tomtom dédiées, sinon coords d'affichage
  local m = (inst.tomtom and inst.tomtom.mapID) or inst.accessMapID or inst.mapID
  local x = inst.tomtom and inst.tomtom.x or (inst.coords and inst.coords.x)
  local y = inst.tomtom and inst.tomtom.y or (inst.coords and inst.coords.y)
  if not (m and x and y) then
    print("|cFF4D99FFDgnTracker|r : coordonnées indisponibles pour |cFFFFD700"..(inst.name or "?").."|r.")
    return
  end
  local fx, fy = x/100, y/100   -- données en % -> fraction 0..1

  if TomTom and TomTom.AddWaypoint then
    TomTom:AddWaypoint(m, fx, fy, {
      title = inst.name,
      from  = "DgnTracker",
      persistent = false, minimap = true, world = true,
    })
    print("|cFF4D99FFDgnTracker|r : waypoint |cFF88DD88TomTom|r -> |cFFFFD700"..inst.name.."|r")
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
      print("|cFF4D99FFDgnTracker|r : waypoint |cFF88DDFFcarte|r -> |cFFFFD700"..inst.name.."|r (ouvrez la carte pour le voir)")
    else
      print("|cFF4D99FFDgnTracker|r : impossible de poser un waypoint natif sur cette zone. Installez |cFFFFD700TomTom|r pour un pointeur complet.")
    end
    return
  end

  print("|cFF4D99FFDgnTracker|r : aucun système de waypoint disponible. Installez |cFFFFD700TomTom|r.")
end

-- Torghast virtual tab : pioche les données type=torghast dans Shadowlands
local function GetTorghastInstances()
  local result = {}
  local slData = DgnTrackerData and DgnTrackerData["Shadowlands"]
  if slData and slData.instances then
    for _, inst in ipairs(slData.instances) do
      if inst.type == "torghast" then table.insert(result, inst) end
    end
  end
  return result
end

-- Retourne la liste ordonnée des onglets à afficher pour une extension
local function GetTabsForExt(extKey)
  -- Shadowlands : Donjon + Raid + Tourment (Torghast)
  if extKey == "Shadowlands" then
    return {"dungeon","raid","torghast"}
  end
  -- Torghast virtuel : uniquement Tourment
  if extKey == "Torghast" then
    return {"torghast"}
  end
  -- Autres extensions : Donjon + Raid + Gouffre selon dispo
  local available = {}
  local data = DgnTrackerData[extKey]
  local list = data and data.instances or {}
  local seen = {}
  for _, inst in ipairs(list) do
    seen[inst.type] = true
  end
  for _, t in ipairs({"dungeon","raid","delve"}) do
    if seen[t] then table.insert(available, t) end
  end
  return available
end

-- Labels des onglets (dont Tourment)
local ALL_TAB_LABELS = {
  dungeon="Donjon", raid="Raid", delve="Gouffre", torghast="Tourment",
}

-- ================================================================
-- CONSTRUCTION DE L'INTERFACE
-- ================================================================
local mainFrame

local function BuildUI()
  local CX  = TAB_COL_W + 18
  local CTW = FRAME_W - CX - 14

  -- ================================================================
  -- FENETRE PRINCIPALE
  -- ================================================================
  mainFrame = CreateFrame("Frame","DGNMainFrame",UIParent,"BackdropTemplate")
  mainFrame:SetSize(FRAME_W, 600)
  mainFrame:SetFrameStrata("HIGH")
  mainFrame:SetMovable(true)
  mainFrame:EnableMouse(true)
  mainFrame:RegisterForDrag("LeftButton")
  mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
  mainFrame:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local point,_,_,x,y = s:GetPoint()
    DgnTrackerDB.pos = {point=point,x=x,y=y}
  end)
  mainFrame:SetScript("OnKeyDown", function(self,key)
    if key=="ESCAPE" then
      self:SetPropagateKeyboardInput(false)  -- ESC ne ferme QUE notre fenêtre
      self:Hide(); DgnTrackerDB.open=false
    else
      self:SetPropagateKeyboardInput(true)   -- laisse passer les autres touches
    end
  end)
  mainFrame:EnableKeyboard(true)
  mainFrame:SetPropagateKeyboardInput(true)
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
  local titleBg = CreateFrame("Frame",nil,mainFrame,"BackdropTemplate")
  titleBg:SetPoint("TOP",mainFrame,"TOP",0,14)
  titleBg:SetSize(430,44)
  titleBg:SetFrameLevel(mainFrame:GetFrameLevel()+2)
  titleBg:SetBackdrop({
    bgFile="Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=true, tileSize=32, edgeSize=20,
    insets={left=7,right=7,top=7,bottom=7},
  })
  titleBg:SetBackdropColor(0.04,0.02,0.06,0.97)
  titleBg:SetBackdropBorderColor(0.72,0.60,0.28,1.0)

  local logoL = titleBg:CreateTexture(nil,"OVERLAY")
  logoL:SetSize(22,22)
  logoL:SetTexture("Interface\\AddOns\\DgnTracker\\medias\\DgnTracker")
  local logoR = titleBg:CreateTexture(nil,"OVERLAY")
  logoR:SetSize(22,22)
  logoR:SetTexture("Interface\\AddOns\\DgnTracker\\medias\\DgnTracker")

  local titleStr = titleBg:CreateFontString(nil,"OVERLAY")
  titleStr:SetFont("Fonts\\FRIZQT__.TTF",12,"OUTLINE")
  titleStr:SetPoint("CENTER",titleBg,"CENTER",0,5)
  titleStr:SetText("|cFFFFD700Dgn Tracker|r  |cFF9480FFInstances & Raids|r")
  logoL:SetPoint("RIGHT",titleStr,"LEFT",-6,0)
  logoR:SetPoint("LEFT",titleStr,"RIGHT",6,0)

  local byLine = titleBg:CreateFontString(nil,"OVERLAY")
  byLine:SetFont("Fonts\\FRIZQT__.TTF",9,"OUTLINE")
  byLine:SetPoint("TOP",titleStr,"BOTTOM",0,0)
  byLine:SetText("|cFFF58CBAby Tibiscui|r")

  -- TibiSuite : en-tête comme WeeklyCompass (titre à l'intérieur, haut-gauche)
  logoL:Hide(); logoR:Hide()
  byLine:Hide()
  titleBg:Hide()
  titleStr:SetParent(mainFrame)
  titleStr:SetFontObject("GameFontNormalLarge")
  titleStr:ClearAllPoints()
  titleStr:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 16, -14)
  titleStr:SetText("|cFF0267FCDgnTracker|r")

  local closeBtn = CreateFrame("Button",nil,mainFrame,"UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT",-5,-5)
  closeBtn:SetScript("OnClick",function() mainFrame:Hide(); DgnTrackerDB.open=false end)

  local drag = mainFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  drag:SetPoint("TOP",0,-30)
  drag:SetText("|cFF888888Glisser pour déplacer|r")

  local sepTop = mainFrame:CreateTexture(nil,"ARTWORK")
  sepTop:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepTop:SetPoint("TOPLEFT",12,-45)
  sepTop:SetPoint("TOPRIGHT",-12,-45)
  sepTop:SetHeight(1)
  sepTop:SetVertexColor(0.72,0.60,0.28,0.9)

  -- ================================================================
  -- COLONNE GAUCHE : ONGLETS EXTENSIONS
  -- ================================================================
  -- On calcule la hauteur nécessaire AVANT de créer le frame
  local totalRows = #EXT_ROW1 + #EXT_ROW2 + 1  -- +1 pour Torghast
  -- Hauteur col : 58 (en-tête) + rangées + séparateurs + torghast + marge bas
  local COL_CONTENT_H = 58
    + #EXT_ROW1 * (TAB_H+TAB_GAP)
    + 8   -- séparateur classique
    + #EXT_ROW2 * (TAB_H+TAB_GAP)
    + 10  -- séparateur Torghast
    + TAB_H + 14  -- Torghast + marge

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
  local extTabStartY = -58

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
    -- (accent bar supprimé)
    local eTxt = eb:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    eTxt:SetPoint("LEFT",eb,"LEFT",8,0)
    eTxt:SetSize(TAB_COL_W-40,TAB_H-4)
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
      -- Sélectionner automatiquement l'onglet "Donjon" à l'ouverture d'une ext
      DgnTrackerDB.activeTab = "dungeon"
      mainFrame:RefreshContent()
    end)
    eb:SetScript("OnEnter",function(s)
      GameTooltip:SetOwner(s,"ANCHOR_RIGHT")
      GameTooltip:AddLine(fullName,col.r,col.g,col.b)
      local ed = (extKey=="Torghast") and {instances=GetTorghastInstances()} or DgnTrackerData[extKey]
      if ed and ed.instances then
        GameTooltip:AddLine(#ed.instances.." instance(s)",0.75,0.75,0.75)
      end
      GameTooltip:Show()
    end)
    eb:SetScript("OnLeave",function() GameTooltip:Hide() end)
    table.insert(extBtns,eb)
    return eb
  end

  for i,extKey in ipairs(EXT_ROW1) do
    BuildExtTab(extKey, extTabStartY-(i-1)*(TAB_H+TAB_GAP))
  end

  local divOffsetY = extTabStartY - #EXT_ROW1*(TAB_H+TAB_GAP) - 3
  local sepDiv = mainFrame:CreateTexture(nil,"OVERLAY")
  sepDiv:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepDiv:SetPoint("TOPLEFT",mainFrame,"TOPLEFT",14,divOffsetY)
  sepDiv:SetSize(TAB_COL_W-4, 2)
  sepDiv:SetVertexColor(0.72,0.60,0.28,1.0)

  local classicYBase = divOffsetY - 5
  for i,extKey in ipairs(EXT_ROW2) do
    BuildExtTab(extKey, classicYBase-(i-1)*(TAB_H+TAB_GAP))
  end

  -- (Onglet Torghast supprimé de la colonne gauche - accès via onglet Tourment dans Shadowlands)

  mainFrame.extBtns = extBtns

  -- Séparateur vertical
  local sepVert = mainFrame:CreateTexture(nil,"ARTWORK")
  sepVert:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  sepVert:SetPoint("TOPLEFT",TAB_COL_W+13,-50)
  sepVert:SetPoint("BOTTOMLEFT",TAB_COL_W+13,12)
  sepVert:SetWidth(1)
  sepVert:SetVertexColor(0.72,0.60,0.28,0.55)

  -- ================================================================
  -- ZONE CONTENU : en-tête
  -- ================================================================
  mainFrame.extActiveLabel = mainFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
  mainFrame.extActiveLabel:SetPoint("TOPLEFT",CX,-52)
  mainFrame.extActiveLabel:SetWidth(CTW)
  mainFrame.extActiveLabel:SetJustifyH("LEFT")

  -- ================================================================
  -- ONGLETS INTERNES (Donjon / Raid / Gouffre / Tourment)
  -- Sur une seule ligne horizontale juste sous le label extension
  -- ================================================================
  local innerTabY = -72
  local innerTabW = 90
  local innerTabH = 22
  local innerTabGap = 4
  mainFrame.innerTabBtns = {}
  mainFrame.innerTabFrame = CreateFrame("Frame",nil,mainFrame)
  mainFrame.innerTabFrame:SetPoint("TOPLEFT",CX,innerTabY)
  mainFrame.innerTabFrame:SetSize(CTW, innerTabH+2)

  local function BuildInnerTab(ttype, xOff)
    local tc   = TYPE_COLORS[ttype] or {r=0.5,g=0.5,b=0.5}
    local tlbl = INNER_TAB_LABELS[ttype] or ttype
    local itb  = CreateFrame("Button",nil,mainFrame,"BackdropTemplate")
    itb:SetSize(innerTabW, innerTabH)
    itb:SetPoint("TOPLEFT", CX + xOff, innerTabY)
    itb:SetBackdrop({
      bgFile="Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
      tile=true, tileSize=8, edgeSize=4,
      insets={left=1,right=1,top=1,bottom=1},
    })
    itb:SetBackdropColor(tc.r*0.12,tc.g*0.12,tc.b*0.12,0.95)
    itb:SetBackdropBorderColor(tc.r*0.40,tc.g*0.40,tc.b*0.40,0.65)
    local itTxt = itb:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    itTxt:SetPoint("CENTER",itb,"CENTER")
    itTxt:SetText(string.format("|cFF%02X%02X%02X%s|r",hex(tc.r),hex(tc.g),hex(tc.b),tlbl))
    itb.ttype = ttype
    itb.itTxt = itTxt
    itb.tc    = tc
    itb.tlbl  = tlbl
    itb:SetScript("OnClick",function(s)
      DgnTrackerDB.activeTab = s.ttype
      mainFrame:RefreshContent()
    end)
    itb:SetScript("OnEnter",function(s)
      if DgnTrackerDB.activeTab ~= s.ttype then
        s:SetBackdropBorderColor(tc.r*0.7,tc.g*0.7,tc.b*0.7,0.9)
      end
    end)
    itb:SetScript("OnLeave",function(s)
      if DgnTrackerDB.activeTab ~= s.ttype then
        s:SetBackdropBorderColor(tc.r*0.40,tc.g*0.40,tc.b*0.40,0.65)
      end
    end)
    table.insert(mainFrame.innerTabBtns, itb)
    return itb
  end

  -- Crée les boutons onglets pour TOUS les types possibles
  -- (dungeon, raid, delve, torghast) — affichés/masqués selon l'extension active
  local ALL_POSSIBLE_TABS = {"dungeon","raid","delve","torghast"}
  local ix = 0
  for _, ttype in ipairs(ALL_POSSIBLE_TABS) do
    BuildInnerTab(ttype, ix)
    ix = ix + innerTabW + innerTabGap
  end

  -- ================================================================
  -- BARRE DE RECHERCHE (filtre par nom d'instance)
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
  searchHint:SetText("Rechercher...")
  searchBox.hint = searchHint
  searchBox:SetScript("OnTextChanged", function(s)
    local t = s:GetText() or ""
    s.hint:SetShown(t == "")
    mainFrame.searchText = t:lower():gsub("^%s*(.-)%s*$","%1")
    if mainFrame.RefreshContent then mainFrame:RefreshContent() end
  end)
  searchBox:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)
  searchBox:SetScript("OnEnterPressed",  function(s) s:ClearFocus() end)

  -- Séparateur sous les onglets internes
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
  mainFrame.instanceFrames = {}

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
    return "|cFFCCCCCC"..txt.."|r"
  end

  -- ================================================================
  -- REFRESH CONTENT
  -- ================================================================
  mainFrame.RefreshContent = function(self)
    local extKey  = DgnTrackerDB.extension or "TheWarWithin"
    local extCol  = EXT_TAB_COLORS[extKey] or {r=1,g=0.84,b=0}
    local extFull = EXT_FULLNAMES[extKey] or extKey

    -- Label extension active
    self.extActiveLabel:SetText(string.format(
      "|cFFFFD700Extension :|r  |cFF%02X%02X%02X%s|r",
      hex(extCol.r),hex(extCol.g),hex(extCol.b),extFull))

    -- ── Onglets extension (highlight + compteurs) ──────────────
    for _,eb in ipairs(self.extBtns or {}) do
      local col = eb.col or {r=0.5,g=0.5,b=0.5}
      if eb.extKey == extKey then
        eb:SetBackdropColor(col.r*0.40,col.g*0.40,col.b*0.40,1.0)
        eb:SetBackdropBorderColor(col.r,col.g,col.b,1.0)
        -- (accent supprimé)
      else
        eb:SetBackdropColor(col.r*0.12,col.g*0.12,col.b*0.12,0.95)
        eb:SetBackdropBorderColor(col.r*0.35,col.g*0.35,col.b*0.35,0.5)
        -- (accent supprimé)
      end
      if eb.cntLbl then
        local ed = DgnTrackerData[eb.extKey]
        local n = ed and ed.instances and #ed.instances or 0
        eb.cntLbl:SetText(n>0 and string.format("|cFF888888%d|r",n) or "")
      end
    end

    -- ── Onglets internes : dynamiques selon l'extension ──────────
    local tabsForExt = GetTabsForExt(extKey)
    local activeTab  = DgnTrackerDB.activeTab or "dungeon"

    -- Si l'onglet actif n'est pas dans la liste de cette ext → prendre le 1er dispo
    local activeValid = false
    for _, t in ipairs(tabsForExt) do
      if t == activeTab then activeValid = true; break end
    end
    if not activeValid and #tabsForExt > 0 then
      activeTab = tabsForExt[1]
      DgnTrackerDB.activeTab = activeTab
    end

    -- Repositionner + afficher/masquer les onglets selon la liste ordonnée
    local CX_ref = TAB_COL_W + 18
    local innerTabW = 90
    local innerTabGap = 4
    local innerTabY = -72
    local xOff = 0
    for _,itb in ipairs(self.innerTabBtns or {}) do
      -- Cherche si ce type est dans tabsForExt
      local pos = nil
      for i, t in ipairs(tabsForExt) do
        if t == itb.ttype then pos = i; break end
      end
      if pos then
        -- Recalcule la position X selon l'ordre dans tabsForExt
        local xPos = CX_ref + (pos-1) * (innerTabW + innerTabGap)
        itb:ClearAllPoints()
        itb:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", xPos, innerTabY)
        -- Mise à jour du label (au cas où torghast = "Tourment")
        local tc = itb.tc
        itb:Show()
        local lbl = ALL_TAB_LABELS[itb.ttype] or itb.tlbl
        if itb.ttype == activeTab then
          itb:SetBackdropColor(tc.r*0.35,tc.g*0.35,tc.b*0.35,1.0)
          itb:SetBackdropBorderColor(tc.r,tc.g,tc.b,1.0)
          itb.itTxt:SetText(string.format("|cFFFFFFFF%s|r", lbl))
        else
          itb:SetBackdropColor(tc.r*0.08,tc.g*0.08,tc.b*0.08,0.95)
          itb:SetBackdropBorderColor(tc.r*0.35,tc.g*0.35,tc.b*0.35,0.55)
          itb.itTxt:SetText(string.format("|cFF%02X%02X%02X%s|r",
            hex(tc.r*0.7),hex(tc.g*0.7),hex(tc.b*0.7), lbl))
        end
      else
        itb:Hide()
      end
    end

    -- ── Pools de widgets recyclables (évite la fuite mémoire) ────
    self.headerPool = self.headerPool or {}
    self.detailPool = self.detailPool or {}

    local BACKDROP = {
      bgFile="Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
      tile=true, tileSize=8, edgeSize=5,
      insets={left=1,right=1,top=1,bottom=1},
    }

    local function AcquireHeader(i)
      local h = self.headerPool[i]
      if h then return h end
      h = CreateFrame("Button",nil,self.scrollChild,"BackdropTemplate")
      h:SetBackdrop(BACKDROP)
      h:RegisterForClicks("LeftButtonUp","RightButtonUp")
      h.toggle = h:CreateFontString(nil,"OVERLAY")
      h.toggle:SetFont("Fonts\\FRIZQT__.TTF",16,"OUTLINE")
      h.toggle:SetPoint("LEFT",h,"LEFT",8,0)
      h.toggle:SetSize(16,16)
      h.nameFS = h:CreateFontString(nil,"OVERLAY")
      h.nameFS:SetFont("Fonts\\FRIZQT__.TTF",11,"OUTLINE")
      h.nameFS:SetPoint("LEFT",h,"LEFT",28,0)
      h.nameFS:SetPoint("RIGHT",h,"RIGHT",-90,0)
      h.nameFS:SetJustifyH("LEFT")
      h.nameFS:SetWordWrap(false)
      h.zoneFS = h:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
      h.zoneFS:SetPoint("BOTTOMRIGHT",h,"BOTTOMRIGHT",-8,5)
      h.zoneFS:SetJustifyH("RIGHT")
      h:SetScript("OnClick",function(s, button)
        local inst = s.inst
        if not inst then return end
        if button == "RightButton" then
          DgnSetWaypoint(inst)
          return
        end
        local nowOpen = not DgnTrackerDB.expandedInst[inst.name]
        DgnTrackerDB.expandedInst[inst.name] = nowOpen
        if nowOpen and DgnTrackerDB.mapPins then DgnSetWaypoint(inst) end
        mainFrame:RefreshContent()
      end)
      h:SetScript("OnEnter",function(s)
        local tc = s.tc or {r=0.5,g=0.5,b=0.5}
        if s.inst and not DgnTrackerDB.expandedInst[s.inst.name] then
          s:SetBackdropBorderColor(tc.r*0.7,tc.g*0.7,tc.b*0.7,0.9)
        end
        if not s.inst then return end
        GameTooltip:SetOwner(s,"ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine(s.inst.name,1,0.84,0)
        GameTooltip:AddLine("|cFFFFD700Clic gauche|r : "..(DgnTrackerDB.expandedInst[s.inst.name] and "fermer" or "afficher le chemin"),0.7,0.7,0.7)
        GameTooltip:AddLine("|cFFFFD700Clic droit|r : poser un point de route (waypoint)",0.7,0.7,0.7)
        GameTooltip:Show()
      end)
      h:SetScript("OnLeave",function(s)
        local tc = s.tc or {r=0.5,g=0.5,b=0.5}
        if s.inst and not DgnTrackerDB.expandedInst[s.inst.name] then
          s:SetBackdropBorderColor(tc.r*0.40,tc.g*0.40,tc.b*0.40,0.65)
        end
        GameTooltip:Hide()
      end)
      self.headerPool[i] = h
      return h
    end

    local function AcquireDetail(i)
      local d = self.detailPool[i]
      if d then return d end
      d = CreateFrame("Frame",nil,self.scrollChild,"BackdropTemplate")
      d:SetBackdrop(BACKDROP)
      d.fsBC = d:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
      d.fsBC:SetJustifyH("LEFT"); d.fsBC:SetWordWrap(false); d.fsBC:SetHeight(14)
      d.lbA = d:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
      d.fsA = d:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
      d.fsA:SetJustifyH("LEFT"); d.fsA:SetWordWrap(true)
      d.lbP = d:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
      d.fsP = d:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
      d.fsP:SetJustifyH("LEFT"); d.fsP:SetWordWrap(true)
      self.detailPool[i] = d
      return d
    end

    -- ── Sélection de la liste d'instances ───────────────────────
    local rawList = {}
    if extKey == "Torghast" or (extKey == "Shadowlands" and activeTab == "torghast") then
      rawList = GetTorghastInstances()
    else
      local extD = DgnTrackerData[extKey]
      if extD and extD.instances then
        for _, inst in ipairs(extD.instances) do
          if inst.type == activeTab then
            table.insert(rawList, inst)
          end
        end
      end
    end

    -- ── Filtre de recherche par nom ─────────────────────────────
    local filter = self.searchText or ""
    local instList = {}
    if filter ~= "" then
      for _, inst in ipairs(rawList) do
        if inst.name and inst.name:lower():find(filter, 1, true) then
          table.insert(instList, inst)
        end
      end
    else
      instList = rawList
    end

    if not DgnTrackerDB.expandedInst then
      DgnTrackerDB.expandedInst = {}
    end

    -- ── Cas liste vide ───────────────────────────────────────────
    if #instList == 0 then
      -- Masquer tous les widgets recyclés
      for _,h in ipairs(self.headerPool) do h:Hide() end
      for _,d in ipairs(self.detailPool) do d:Hide() end
      if not self.emptyLbl then
        self.emptyLbl = self.scrollChild:CreateFontString(nil,"OVERLAY","GameFontNormal")
        self.emptyLbl:SetPoint("CENTER",self.scrollChild,"CENTER",0,-30)
      end
      if filter ~= "" then
        self.emptyLbl:SetText("|cFF666666Aucun résultat pour|r |cFFFFD700"..filter.."|r|cFF666666.|r")
      else
        self.emptyLbl:SetText("|cFF666666Aucune instance disponible pour cette catégorie.|r")
      end
      self.emptyLbl:Show()
      self.scrollChild:SetHeight(100)
      self:SetHeight(math.max(COL_CONTENT_H + 70, 400))
      return
    end
    if self.emptyLbl then self.emptyLbl:Hide() end

    -- ============================================================
    -- ACCORDION (widgets recyclés)
    -- ============================================================
    local rowW   = self.scrollChild:GetWidth() - 6
    local curY   = 0
    local HEADER_H = 38
    local GAP    = 3
    local hIdx, dIdx = 0, 0

    for _, inst in ipairs(instList) do
      local tc    = TYPE_COLORS[inst.type] or {r=0.5,g=0.5,b=0.5}
      local isOpen= DgnTrackerDB.expandedInst[inst.name] == true

      -- ── HEADER ──────────────────────────────────────────────
      hIdx = hIdx + 1
      local hdr = AcquireHeader(hIdx)
      hdr.inst = inst
      hdr.tc   = tc
      hdr:ClearAllPoints()
      hdr:SetPoint("TOPLEFT",0,-curY)
      hdr:SetWidth(rowW)
      hdr:SetHeight(HEADER_H)
      if isOpen then
        hdr:SetBackdropColor(tc.r*0.18,tc.g*0.18,tc.b*0.18,0.98)
        hdr:SetBackdropBorderColor(tc.r,tc.g,tc.b,0.95)
      else
        hdr:SetBackdropColor(tc.r*0.07,tc.g*0.07,tc.b*0.07,0.95)
        hdr:SetBackdropBorderColor(tc.r*0.40,tc.g*0.40,tc.b*0.40,0.65)
      end
      hdr.toggle:SetText(string.format("|cFF%02X%02X%02X%s|r",
        hex(tc.r),hex(tc.g),hex(tc.b), isOpen and "-" or "+"))
      hdr.nameFS:SetText((isOpen and "|cFFFFD700" or "|cFFDDCC88")..inst.name.."|r")
      if inst.coords then
        hdr.zoneFS:SetText(string.format("|cFF888888%s|r  |cFF99CCFF%.1f, %.1f|r",
          inst.zone or "", inst.coords.x, inst.coords.y))
      else
        hdr.zoneFS:SetText("|cFF888888"..(inst.zone or "").."|r")
      end
      hdr:Show()
      curY = curY + HEADER_H + GAP

      -- ── DETAIL (déplié) ────────────────────────────────────
      if isOpen then
        local faction = UnitFactionGroup and UnitFactionGroup("player") or "Horde"
        local accessText = ""
        if inst.access then
          if inst.access.both then accessText = inst.access.both
          elseif faction=="Alliance" and inst.access.alliance then accessText = inst.access.alliance
          elseif faction=="Horde" and inst.access.horde then accessText = inst.access.horde
          elseif inst.access.alliance then accessText = "|cFFAADDFF[A]|r "..inst.access.alliance
          elseif inst.access.horde then accessText = "|cFFFF6666[H]|r "..inst.access.horde
          end
        end
        local pathText = inst.path or ""

        local CHARS = math.floor((rowW - 30) / 7.5)
        if CHARS < 30 then CHARS = 60 end
        local function nLines(txt)
          local plain = txt:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|T[^|]+|t","")
          return math.max(1, math.ceil(#plain / CHARS))
        end
        local lA = nLines(accessText)
        local lP = nLines(pathText)
        local detH = 16 + 14 + lA*15 + 8 + 14 + lP*15 + 14

        dIdx = dIdx + 1
        local det = AcquireDetail(dIdx)
        det:ClearAllPoints()
        det:SetPoint("TOPLEFT",0,-curY)
        det:SetWidth(rowW)
        det:SetHeight(detH)
        det:SetBackdropColor(tc.r*0.05,tc.g*0.05,tc.b*0.05,0.97)
        det:SetBackdropBorderColor(tc.r*0.60,tc.g*0.60,tc.b*0.60,0.7)

        local iX,iY = 14,-6

        -- Fil d'Ariane : Extension > Région > Secteur > Zone > Nom
        local parts = {}
        table.insert(parts, string.format("|cFF666666%s|r", EXT_FULLNAMES[extKey] or extKey))
        if inst.region and inst.region ~= "" then
          table.insert(parts, string.format("|cFFAA8855%s|r", inst.region))
        end
        if inst.sector and inst.sector ~= "" and inst.sector ~= inst.region then
          table.insert(parts, string.format("|cFFCC9944%s|r", inst.sector))
        end
        if inst.zone and inst.zone ~= "" then
          table.insert(parts, string.format("|cFF99CCFF%s|r", inst.zone))
        end
        table.insert(parts, string.format("|cFFDDCC88%s|r", inst.name))
        det.fsBC:ClearAllPoints()
        det.fsBC:SetPoint("TOPLEFT",det,"TOPLEFT",iX,iY)
        det.fsBC:SetPoint("TOPRIGHT",det,"TOPRIGHT",-8,iY)
        det.fsBC:SetText(table.concat(parts, " |cFF555555>|r "))
        iY = iY - 18

        -- Accès
        det.lbA:ClearAllPoints()
        det.lbA:SetPoint("TOPLEFT",det,"TOPLEFT",iX,iY)
        det.lbA:SetText(string.format("|cFF%02X%02X%02X-- Accès (chemin le plus court) :|r",
          hex(tc.r),hex(tc.g),hex(tc.b)))
        iY = iY - 15
        det.fsA:ClearAllPoints()
        det.fsA:SetPoint("TOPLEFT",det,"TOPLEFT",iX+6,iY)
        det.fsA:SetPoint("TOPRIGHT",det,"TOPRIGHT",-14,iY)
        det.fsA:SetHeight(lA*15+4)
        det.fsA:SetText(ColorizeAccess(accessText))
        iY = iY - lA*15 - 8

        -- Conseils
        det.lbP:ClearAllPoints()
        det.lbP:SetPoint("TOPLEFT",det,"TOPLEFT",iX,iY)
        det.lbP:SetText(string.format("|cFF%02X%02X%02X-- Conseils :|r",
          hex(tc.r),hex(tc.g),hex(tc.b)))
        iY = iY - 15
        det.fsP:ClearAllPoints()
        det.fsP:SetPoint("TOPLEFT",det,"TOPLEFT",iX+6,iY)
        det.fsP:SetPoint("TOPRIGHT",det,"TOPRIGHT",-14,iY)
        det.fsP:SetHeight(lP*15+4)
        det.fsP:SetText(ColorizePath(pathText))

        det:Show()
        curY = curY + detH + GAP
      end
    end

    -- Masquer les widgets recyclés non utilisés ce cycle
    for i = hIdx+1, #self.headerPool do self.headerPool[i]:Hide() end
    for i = dIdx+1, #self.detailPool do self.detailPool[i]:Hide() end

    self.scrollChild:SetHeight(math.max(curY + 10, 100))

    -- Auto-resize fenêtre
    local newH = math.max(COL_CONTENT_H + 70, math.min(curY + 200, 900), 400)
    self:SetHeight(newH)
    if self.tabColBg then
      self.tabColBg:SetHeight(newH - 64)
    end
  end

  mainFrame:Hide()
end

-- ================================================================
-- BOUTON MINIMAP
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
    if btn=="LeftButton" then
      if mainFrame:IsShown() then
        mainFrame:Hide(); DgnTrackerDB.open=false
      else
        mainFrame:Show(); mainFrame:RefreshContent(); DgnTrackerDB.open=true
      end
    end
  end)
  minimapBtn:SetScript("OnEnter",function(s)
    if s._hl then s._hl:SetAlpha(1) end
    GameTooltip:SetOwner(s,"ANCHOR_LEFT")
    GameTooltip:AddLine("|cFF0070DEDgnTracker|r",0.30,0.70,1.0)
    GameTooltip:AddLine("Tracker des instances & raids",0.9,0.9,0.9)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cFFFFD700Clic gauche|r : ouvrir / fermer",0.7,0.7,0.7)
    GameTooltip:AddLine("|cFFFFD700Glisser|r : repositionner l'icône",0.7,0.7,0.7)
    GameTooltip:Show()
  end)
  minimapBtn:SetScript("OnLeave",function(s)
    if s._hl then s._hl:SetAlpha(0) end
    GameTooltip:Hide()
  end)
end

-- ================================================================
-- ADDON COMPARTMENT
-- ================================================================
function DgnTracker_OnAddonCompartmentClick()
  if mainFrame:IsShown() then
    mainFrame:Hide(); DgnTrackerDB.open=false
  else
    mainFrame:Show(); mainFrame:RefreshContent(); DgnTrackerDB.open=true
  end
end
function DgnTracker_OnAddonCompartmentEnter(btn)
  GameTooltip:SetOwner(btn,"ANCHOR_LEFT")
  GameTooltip:AddLine("DgnTracker",0.30,0.70,1.0)
  GameTooltip:AddLine("Tracker des instances & raids",0.9,0.9,0.9)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("|cFFFFD700Clic|r : ouvrir / fermer",0.7,0.7,0.7)
  GameTooltip:Show()
end
function DgnTracker_OnAddonCompartmentLeave() GameTooltip:Hide() end

-- ================================================================
-- COMMANDES SLASH
-- ================================================================
SLASH_DGNTRACKER1 = "/dg"
SLASH_DGNTRACKER2 = "/tibidgn"
SlashCmdList["DGNTRACKER"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s*(.-)%s*$","%1")

  if msg=="help" or msg=="aide" then
    print("|cFF4D99FFDgnTracker|r commandes :")
    print("  |cFFFFD700/dg|r           - Ouvrir/fermer la fenêtre")
    print("  |cFFFFD700/dg map on|r    - Waypoint auto à l'ouverture d'une instance")
    print("  |cFFFFD700/dg map off|r   - Désactiver le waypoint auto")
    print("  |cFFFFD700/dg <extension>|r - Aller à une extension (ex : tww, df, sl, van)")
    print("  |cFFFFD700/dg expand|r    - Tout déplier (extension active)")
    print("  |cFFFFD700/dg reset|r     - Tout replier (accordéon)")
    print("  |cFF888888Astuce : clic droit sur une instance = poser un waypoint.|r")
    return

  elseif msg=="reset" then
    DgnTrackerDB.expandedInst = {}
    if mainFrame:IsShown() then mainFrame:RefreshContent() end
    print("|cFF4D99FFDgnTracker|r : accordéon réinitialisé.")
    return

  elseif msg=="expand" or msg=="all" then
    local ext = DgnTrackerDB.extension or "TheWarWithin"
    local ed = DgnTrackerData[ext]
    if ed and ed.instances then
      for _, inst in ipairs(ed.instances) do
        DgnTrackerDB.expandedInst[inst.name] = true
      end
    end
    if not mainFrame:IsShown() then mainFrame:Show(); DgnTrackerDB.open=true end
    mainFrame:RefreshContent()
    print("|cFF4D99FFDgnTracker|r : tout déplié pour |cFFFFD700"..(EXT_FULLNAMES[ext] or ext).."|r.")
    return

  elseif msg=="map on" or msg=="mapon" then
    DgnTrackerDB.mapPins = true
    print("|cFF4D99FFDgnTracker|r : waypoint auto |cFF88DD88activé|r (à l'ouverture d'une instance).")
    return
  elseif msg=="map off" or msg=="mapoff" then
    DgnTrackerDB.mapPins = false
    print("|cFF4D99FFDgnTracker|r : waypoint auto |cFFFF8888désactivé|r.")
    return
  end

  -- Saut d'extension : /dg tww, /dg df, /dg sl, /dg van, etc.
  if msg ~= "" then
    local target = nil
    for key, abbr in pairs(EXT_LABELS) do
      if msg == abbr:lower() or msg == key:lower() then target = key; break end
    end
    if target and DgnTrackerData[target] then
      DgnTrackerDB.extension = target
      DgnTrackerDB.activeTab = "dungeon"
      if not mainFrame:IsShown() then mainFrame:Show(); DgnTrackerDB.open=true end
      mainFrame:RefreshContent()
      print("|cFF4D99FFDgnTracker|r : extension -> |cFFFFD700"..(EXT_FULLNAMES[target] or target).."|r")
      return
    elseif not (msg=="map on" or msg=="map off") then
      print("|cFF4D99FFDgnTracker|r : commande inconnue. Tapez |cFFFFD700/dg help|r.")
      return
    end
  end

  -- Sans argument : toggle fenêtre
  if mainFrame:IsShown() then
    mainFrame:Hide(); DgnTrackerDB.open=false
  else
    mainFrame:Show(); mainFrame:RefreshContent(); DgnTrackerDB.open=true
  end
end

-- ================================================================
-- EVENEMENTS
-- ================================================================
local evFrame = CreateFrame("Frame")
evFrame:RegisterEvent("ADDON_LOADED")
evFrame:RegisterEvent("PLAYER_LOGIN")
evFrame:SetScript("OnEvent",function(_,event,arg1)
  if event=="ADDON_LOADED" and arg1==ADDON then
    -- S'assure que l'onglet par défaut est "donjon"
    DgnTrackerDB.activeTab = DgnTrackerDB.activeTab or "dungeon"
    DgnTrackerDB.expandedInst = DgnTrackerDB.expandedInst or {}
    BuildUI()
    BuildMinimapButton()
    local p = DgnTrackerDB.pos
    if p and p.x then
      mainFrame:ClearAllPoints()
      mainFrame:SetPoint(p.point or "CENTER",UIParent,p.point or "CENTER",p.x,p.y)
    else
      mainFrame:SetPoint("CENTER",UIParent,"CENTER",0,0)
    end
    DgnTrackerDB.open = false  -- ferme automatiquement au login
  elseif event=="ADDON_LOADED" and arg1=="TibiSuite" then
    -- TibiSuite est présent : il gère le bouton minimap unifié
    if minimapBtn then minimapBtn:Hide() end

  elseif event=="PLAYER_LOGIN" then
    print("|cFF4D99FFDgnTracker|r v3.0 chargé -- |cFFFFD700/dg|r pour ouvrir.")
  end
end)

-- ================================================================
-- TOGGLE PUBLIC -- appelé par TibiSuite
-- ================================================================
function DgnTracker_Toggle()
  if mainFrame:IsShown() then
    mainFrame:Hide()
    DgnTrackerDB.open = false
  else
    mainFrame:Show()
    mainFrame:RefreshContent()
    DgnTrackerDB.open = true
  end
end
