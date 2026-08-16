-- XPBar.lua v2.6
-- Barre XP avancée — Tibiscui
-- Maj+Drag pour déplacer | Maj+Clic droit pour les options

local ADDON = "XPBar"

-- ══════════════════════════════════════════════════
-- LOCALISATION (structure prête pour d'autres langues)
-- ══════════════════════════════════════════════════
local L = {
    LEVEL           = "Niveau",
    XP              = "XP",
    PROGRESS        = "Progression",
    REMAINING       = "Restant",
    RESTED          = "Repos",
    QUESTS          = "Quêtes",
    QUESTS_DONE     = "Quêtes terminées",
    SESSION         = "Session",
    XP_PER_HOUR     = "XP/heure",
    XP_PER_HOUR_ROLL= "XP/h (récent)",
    TIME_LEFT       = "Temps restant",
    PLAYED          = "Joué",
    LEVELS_GAINED   = "Niveaux gagnés",
    QUESTS_TURNED   = "Quêtes rendues",
    HINT            = "|cffFFD700Maj+Drag|r déplacer  ·  |cffFFD700Maj+Clic droit|r options",
    POS_SAVED       = "Position sauvegardée.",
    POS_RESET       = "Position réinitialisée.",
    SESSION_RESET   = "Session réinitialisée.",
    -- Options
    OPT_TITLE       = "|cffddbbffXPBar|r — Options",
    OPT_TAB         = "Options",
    OPT_HINT        = "|cffFFD700Maj+Drag|r pour déplacer   |cffFFD700Maj+Clic droit|r pour ouvrir/fermer",
    OPT_WIDTH       = "Largeur :",
    OPT_HEIGHT      = "Hauteur :",
    OPT_COLORS      = "Couleurs",
    OPT_COL_BAR     = "Barre XP",
    OPT_COL_QUEST   = "Quêtes",
    OPT_COL_RESTED  = "Repos",
    OPT_COL_INC     = "Incomplètes",
    OPT_OPACITY     = "Opacité fond :",
    OPT_FONTSIZE    = "Taille texte :",
    OPT_DISPLAY     = "Affichage",
    OPT_PLAYED      = "Temps joué",
    OPT_SESSION     = "Temps de session",
    OPT_LEVELING    = "Temps restant & XP/heure",
    OPT_COMPLETED   = "Quêtes terminées & Repos",
    OPT_ROLLING     = "XP/h sur période récente",
    OPT_INCBAR      = "Barre des quêtes incomplètes",
    OPT_MAXLEVEL    = "Afficher au niveau max",
    OPT_RESETRELOAD = "Réinit. session au /reload",
    OPT_HIDENATIVE  = "Masquer la barre d'XP native",
    OPT_HIDECOMBAT  = "Masquer en combat",
    OPT_HIDEVEHICLE = "Masquer en véhicule",
    OPT_MOUSEOVER   = "Afficher au survol seulement",
    OPT_CLOSE       = "Fermer",
    OPT_RESETPOS    = "Réinit. position",
    OPT_RESETSESS   = "Réinit. session",
}

-- ══════════════════════════════════════════════════
-- DEFAULTS
-- ══════════════════════════════════════════════════
local DEFAULTS = {
    posX   = 0, posY = -120, anchor = "TOP",
    width  = 600, height = 22,           -- dimensions en mode HORIZONTAL
    orientation  = "HORIZONTAL",         -- "HORIZONTAL" (defaut) ou "VERTICAL"
    vWidth  = 24,                        -- epaisseur en mode VERTICAL
    vHeight = 300,                       -- longueur en mode VERTICAL
    verticalText = false,                -- afficher le texte a cote de la barre en vertical
    showPlayedTime       = true,
    showSessionTime      = true,
    showLevelingTime     = true,
    showXPPerHour        = true,
    showRollingXP        = true,   -- XP/h sur fenêtre glissante plutôt que moyenne de session
    showCompletedQuests  = true,
    showRestedText       = true,
    showIncompleteBar    = false,
    showAtMaxLevel       = false,
    resetSessionOnReload = false,
    hideDefaultXPBar     = true,   -- masquée par défaut dès l'installation
    hideInCombat         = false,
    hideInVehicle        = false,
    mouseoverOnly        = false,
    sessionStartTime     = 0,      -- epoch (time()) du début de session — persiste entre /reload
    sessionXPGained      = 0,      -- XP cumulée depuis sessionStartTime — persiste entre /reload
    sessionLevels        = 0,      -- niveaux gagnés dans la session
    sessionQuests        = 0,      -- quêtes rendues dans la session
    lastLogout           = 0,      -- epoch de la dernière déconnexion — distingue /reload et vraie session
    bgA        = 0.85,             -- opacité du fond sombre
    fontSize   = 0,                -- 0 = taille par défaut du modèle
    barR = 0.55, barG = 0.27, barB = 0.80, barA = 1.0,
    qR   = 1.00, qG   = 0.65, qB   = 0.00, qA   = 1.0,
    rR   = 0.40, rG   = 0.70, rB   = 1.00, rA   = 1.0,
    incR = 0.60, incG = 0.60, incB = 0.60, incA = 0.4,
}

-- ══════════════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════════════
local db
local mainBar, questSegment, restedSegment, incompleteBar, bgTexture
local labelLeft, labelCenter, labelRight, labelBottom
local containerFrame, dragFrame, optionsFrame
local playedTimeBase      = 0   -- /played total au dernier RequestTimePlayed()
local playedTimeQueryTime = 0   -- time() epoch au moment de la requête
local mouseIsOver         = false
local xpSamples           = {}  -- échantillons {t, total} pour l'XP/h glissant (runtime, non sauvegardé)
local ROLLING_WINDOW      = 900 -- fenêtre glissante : 15 minutes

-- Forward declarations (évite les nil au moment des scripts / captures d'upvalues)
local UpdateBar, CreateOptionsPanel
local ApplySize, ApplyAppearance, ApplyFont, ApplyVisibility, EnforceNativeBar
local ApplyOrientation, LayoutLabels

-- ══════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════

-- Orientation courante et dimensions actives selon celle-ci.
local function IsVertical() return db and db.orientation == "VERTICAL" end
local function ActiveSize()
    if IsVertical() then return db.vWidth or 24, db.vHeight or 300 end
    return db.width or 600, db.height or 22
end

local function FormatTime(seconds)
    seconds = math.floor(seconds or 0)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return string.format("%dh%02dm", h, m)
    elseif m > 0 then return string.format("%dm%02ds", m, s)
    else return string.format("%ds", s) end
end

-- Durée de session en secondes, basée sur l'horloge réelle (time()) pour
-- survivre aux /reload — contrairement à GetTime() qui repart de zéro.
local function GetSessionElapsed()
    if not db or not db.sessionStartTime or db.sessionStartTime == 0 then return 0 end
    return time() - db.sessionStartTime
end

-- XP/heure : moyenne sur toute la session
local function GetXPPerHour()
    local elapsed = GetSessionElapsed()
    local gained  = (db and db.sessionXPGained) or 0
    if elapsed > 60 and gained > 0 then
        return gained / elapsed * 3600
    end
    return 0
end

-- Enregistre un échantillon (temps, XP cumulée) pour l'XP/h glissant,
-- et purge ceux qui sortent de la fenêtre.
local function PushXPSample()
    local now = time()
    xpSamples[#xpSamples + 1] = { t = now, total = (db and db.sessionXPGained) or 0 }
    local cutoff = now - ROLLING_WINDOW
    while xpSamples[1] and xpSamples[1].t < cutoff do
        table.remove(xpSamples, 1)
    end
end

-- XP/heure sur la fenêtre glissante récente (plus réactif que la moyenne de session)
local function GetRollingXPPerHour()
    local n = #xpSamples
    if n < 2 then return 0 end
    local first, last = xpSamples[1], xpSamples[n]
    local span = last.t - first.t
    local gain = last.total - first.total
    if span >= 60 and gain > 0 then
        return gain / span * 3600
    end
    return 0
end

-- XP/heure « effectif » : privilégie le glissant s'il est disponible, sinon la moyenne de session
local function GetEffectiveXPPerHour()
    if db and db.showRollingXP then
        local r = GetRollingXPPerHour()
        if r > 0 then return r end
    end
    return GetXPPerHour()
end

local function GetPlayedTime()
    -- Avant la réception de TIME_PLAYED_MSG, playedTimeQueryTime vaut 0 :
    -- sans ce garde, la formule renverrait l'epoch courant (~1,7 milliard de s).
    if playedTimeQueryTime == 0 then return 0 end
    return playedTimeBase + (time() - playedTimeQueryTime)
end

local function GetXPData()
    local cur  = UnitXP("player")
    local max  = UnitXPMax("player")
    local rest = GetXPExhaustion() or 0
    local pct     = max > 0 and (cur / max)  or 0
    local restPct = max > 0 and (rest / max) or 0
    return cur, max, rest, pct, restPct
end

local function GetQuestData()
    local completed, total = 0, 0
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local n = C_QuestLog.GetNumQuestLogEntries()
        for i = 1, n do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID then
                total = total + 1
                -- isComplete sur info peut être nil en Retail 12.x
                -- C_QuestLog.IsComplete() détecte les quêtes avec objectifs remplis
                -- même si elles ne sont pas encore rendues au PNJ
                local isComplete = info.isComplete
                    or (C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID))
                if isComplete then completed = completed + 1 end
            end
        end
    end
    local completedPct  = total > 0 and (completed / total * 100) or 0
    local incompletePct = total > 0 and ((total - completed) / total) or 0
    return completedPct, incompletePct, completed, total
end

-- ══════════════════════════════════════════════════
-- INIT DB
-- ══════════════════════════════════════════════════
local function InitDB()
    XPBarDB = XPBarDB or {}
    db = XPBarDB
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
end

-- ══════════════════════════════════════════════════
-- SAVE POSITION
-- ══════════════════════════════════════════════════
local function SavePosition()
    if not containerFrame then return end
    local point, _, _, x, y = containerFrame:GetPoint()
    db.anchor = point
    db.posX   = math.floor(x + 0.5)
    db.posY   = math.floor(y + 0.5)
end

-- ══════════════════════════════════════════════════
-- APPLY SIZE (redimensionnement à chaud)
-- ══════════════════════════════════════════════════
ApplySize = function()
    if not containerFrame then return end
    local w, h = ActiveSize()
    local extra = IsVertical() and 0 or 20   -- ligne du bas : seulement en horizontal
    containerFrame:SetSize(w, h + extra)
    mainBar:SetSize(w, h)
    incompleteBar:SetSize(w, h)
    dragFrame:SetSize(w, h + extra)
    -- La taille transversale des segments est fixee dans UpdateBar selon
    -- l'orientation (largeur en horizontal, hauteur en vertical).
end

-- Replace les 4 labels selon l'orientation (et l'option "texte a cote").
LayoutLabels = function()
    if not labelLeft then return end
    for _, fs in ipairs({ labelLeft, labelCenter, labelRight, labelBottom }) do
        fs:ClearAllPoints() ; fs:Show()
    end
    if not IsVertical() then
        labelLeft:SetPoint("LEFT", mainBar, "LEFT", 8, 0)      ; labelLeft:SetJustifyH("LEFT")
        labelCenter:SetPoint("CENTER", mainBar, "CENTER", 0, 0); labelCenter:SetJustifyH("CENTER")
        labelRight:SetPoint("RIGHT", mainBar, "RIGHT", -8, 0)  ; labelRight:SetJustifyH("RIGHT")
        labelBottom:SetPoint("TOP", mainBar, "BOTTOM", 0, -2)
    elseif db.verticalText then
        -- Texte a droite de la colonne, ecrit a l'horizontale (lisible).
        labelLeft:SetPoint("BOTTOMLEFT", mainBar, "TOPRIGHT", 6, -2) ; labelLeft:SetJustifyH("LEFT")
        labelCenter:SetPoint("LEFT", mainBar, "RIGHT", 6, 0)         ; labelCenter:SetJustifyH("LEFT")
        labelRight:SetPoint("TOPLEFT", mainBar, "BOTTOMRIGHT", 6, 2) ; labelRight:SetJustifyH("LEFT")
        labelBottom:Hide()
    else
        -- Jauge pure : tout dans l'infobulle.
        labelLeft:Hide() ; labelCenter:Hide() ; labelRight:Hide() ; labelBottom:Hide()
    end
end

-- Applique l'orientation a la barre (et a la barre des quetes incompletes)
-- puis reajuste taille et labels.
ApplyOrientation = function()
    if not mainBar then return end
    local o = IsVertical() and "VERTICAL" or "HORIZONTAL"
    mainBar:SetOrientation(o)
    if incompleteBar then incompleteBar:SetOrientation(o) end
    ApplySize()
    LayoutLabels()
end

-- ══════════════════════════════════════════════════
-- APPLY FONT / APPARENCE
-- ══════════════════════════════════════════════════
ApplyFont = function()
    if not labelLeft then return end
    for _, fs in ipairs({ labelLeft, labelCenter, labelRight, labelBottom }) do
        local path, size, flags = fs:GetFont()
        local newSize = (db.fontSize and db.fontSize > 0) and db.fontSize or size
        if path then fs:SetFont(path, newSize, flags) end
    end
end

ApplyAppearance = function()
    if bgTexture then bgTexture:SetColorTexture(0.05, 0.05, 0.05, db.bgA or 0.85) end
    ApplyFont()
end

-- ══════════════════════════════════════════════════
-- VISIBILITÉ CONTEXTUELLE (combat / véhicule / survol / niveau max)
-- Retourne true si la barre reste visible, false si masquée.
-- ══════════════════════════════════════════════════
ApplyVisibility = function()
    if not containerFrame or not db then return false end

    local lvl    = UnitLevel("player")
    local maxLvl = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 999
    if lvl >= maxLvl and not db.showAtMaxLevel then
        containerFrame:Hide() ; return false
    end
    if db.hideInCombat and InCombatLockdown() then
        containerFrame:Hide() ; return false
    end
    if db.hideInVehicle and UnitInVehicle and UnitInVehicle("player") then
        containerFrame:Hide() ; return false
    end

    containerFrame:Show()
    if db.mouseoverOnly and not mouseIsOver then
        containerFrame:SetAlpha(0)
    else
        containerFrame:SetAlpha(1)
    end
    return true
end

-- ══════════════════════════════════════════════════
-- BARRE XP NATIVE (Retail 12.x = StatusTrackingBarManager)
-- ══════════════════════════════════════════════════
EnforceNativeBar = function()
    if not StatusTrackingBarManager then return end
    if db.hideDefaultXPBar then
        StatusTrackingBarManager:Hide()
        StatusTrackingBarManager:SetAlpha(0)
        StatusTrackingBarManager:SetScript("OnShow", function(self)
            self:Hide() ; self:SetAlpha(0)
        end)
        for i = 1, StatusTrackingBarManager:GetNumChildren() do
            local child = select(i, StatusTrackingBarManager:GetChildren())
            if child then
                child:Hide()
                child:SetScript("OnShow", function(self) self:Hide() end)
            end
        end
    else
        StatusTrackingBarManager:SetScript("OnShow", nil)
        StatusTrackingBarManager:SetAlpha(1)
        StatusTrackingBarManager:Show()
        for i = 1, StatusTrackingBarManager:GetNumChildren() do
            local child = select(i, StatusTrackingBarManager:GetChildren())
            if child then
                child:SetScript("OnShow", nil)
                child:Show()
            end
        end
    end
end

-- ══════════════════════════════════════════════════
-- CRÉATION UI
-- ══════════════════════════════════════════════════
local function CreateMainBar()
    -- Conteneur principal
    containerFrame = CreateFrame("Frame", "XPBarContainer", UIParent)
    containerFrame:SetFrameStrata("MEDIUM")
    containerFrame:SetSize(db.width, db.height + 20)
    containerFrame:SetPoint(db.anchor, UIParent, db.anchor, db.posX, db.posY)
    containerFrame:SetMovable(true)
    containerFrame:SetClampedToScreen(true)

    -- ── Frame invisible pour le drag (Button = supporte RegisterForDrag) ──
    dragFrame = CreateFrame("Button", "XPBarDragFrame", containerFrame)
    dragFrame:SetAllPoints(containerFrame)
    dragFrame:SetFrameStrata("HIGH")
    dragFrame:EnableMouse(true)
    dragFrame:RegisterForDrag("LeftButton")
    dragFrame:RegisterForClicks("RightButtonUp")
    dragFrame:SetAlpha(0)   -- invisible (l'alpha n'affecte pas la capture souris)

    local isMoving = false
    dragFrame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            isMoving = true
            containerFrame:StartMoving()
            mainBar:SetAlpha(0.6)
        end
    end)
    dragFrame:SetScript("OnDragStop", function(self)
        -- Ne rien faire si le déplacement n'avait pas été initié (drag sans Maj) :
        -- évite un faux message « Position sauvegardée ».
        if not isMoving then return end
        isMoving = false
        containerFrame:StopMovingOrSizing()
        mainBar:SetAlpha(1.0)
        SavePosition()
        print("|cffFFD700[XPBar]|r " .. L.POS_SAVED)
    end)
    dragFrame:SetScript("OnClick", function(self, button)
        if button == "RightButton" and IsShiftKeyDown() then
            if optionsFrame and optionsFrame:IsShown() then
                optionsFrame:Hide()
            else
                CreateOptionsPanel()
            end
        end
    end)

    -- Tooltip + gestion du survol (mouseoverOnly)
    dragFrame:SetScript("OnEnter", function(self)
        mouseIsOver = true
        ApplyVisibility()

        local cur, max, rest, pct, restPct = GetXPData()
        local elapsed   = GetSessionElapsed()
        local xpPerHour = GetXPPerHour()
        local rolling   = GetRollingXPPerHour()
        local effective = GetEffectiveXPPerHour()
        local timeToLvl = effective > 0 and ((max - cur) / effective * 3600) or 0
        local _, _, completed, total = GetQuestData()

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("XPBar", 0.55, 0.27, 0.80)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L.XP,        string.format("%d / %d", cur, max), 1,.82,0, 1,1,1)
        GameTooltip:AddDoubleLine(L.PROGRESS,  string.format("%.1f%%", pct*100),   1,.82,0, 1,1,1)
        GameTooltip:AddDoubleLine(L.REMAINING, string.format("%d XP", max-cur),    1,.82,0, 1,1,1)
        if rest > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(L.RESTED, string.format("%d XP (%.1f%%)", rest, restPct*100), 1,.82,0, .6,.8,1)
        end
        if total > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(L.QUESTS, string.format("%d / %d", completed, total), 1,.82,0, 1,.6,0)
        end
        if elapsed > 60 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(L.SESSION,     FormatTime(elapsed),                1,.82,0, 1,1,1)
            GameTooltip:AddDoubleLine(L.XP_PER_HOUR, string.format("%.0f", xpPerHour),   1,.82,0, 1,1,1)
            if rolling > 0 then
                GameTooltip:AddDoubleLine(L.XP_PER_HOUR_ROLL, string.format("%.0f", rolling), 1,.82,0, .7,1,.7)
            end
            if timeToLvl > 0 then
                GameTooltip:AddDoubleLine(L.TIME_LEFT, FormatTime(timeToLvl), 1,.82,0, 1,1,1)
            end
            GameTooltip:AddDoubleLine(L.LEVELS_GAINED, tostring(db.sessionLevels or 0), 1,.82,0, 1,1,1)
            GameTooltip:AddDoubleLine(L.QUESTS_TURNED, tostring(db.sessionQuests or 0), 1,.82,0, 1,1,1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.HINT, .8,.8,.8)
        GameTooltip:Show()
    end)
    dragFrame:SetScript("OnLeave", function()
        mouseIsOver = false
        ApplyVisibility()
        GameTooltip:Hide()
    end)

    -- ── Barre principale XP ───────────────────────
    mainBar = CreateFrame("StatusBar", "XPBarMain", containerFrame)
    mainBar:SetSize(db.width, db.height)
    mainBar:SetPoint("TOP", containerFrame, "TOP", 0, 0)
    mainBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    mainBar:SetStatusBarColor(db.barR, db.barG, db.barB, db.barA)
    mainBar:SetMinMaxValues(0, 1)
    mainBar:SetValue(0)

    -- Fond sombre posé sur le CONTENEUR (et non sur mainBar) afin de rester
    -- SOUS la barre des quêtes incomplètes. S'il était opaque sur mainBar,
    -- il masquerait entièrement incompleteBar, rendant l'option invisible.
    bgTexture = containerFrame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetPoint("TOPLEFT",     mainBar, "TOPLEFT",     0, 0)
    bgTexture:SetPoint("BOTTOMRIGHT", mainBar, "BOTTOMRIGHT", 0, 0)
    bgTexture:SetColorTexture(0.05, 0.05, 0.05, db.bgA or 0.85)

    local border = CreateFrame("Frame", nil, mainBar, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 6,
        insets   = { left=1, right=1, top=1, bottom=1 },
    })
    border:SetBackdropBorderColor(0, 0, 0, 0.7)

    -- ── Barre quêtes incomplètes ──────────────────
    incompleteBar = CreateFrame("StatusBar", nil, containerFrame)
    incompleteBar:SetSize(db.width, db.height)
    incompleteBar:SetPoint("TOP", containerFrame, "TOP", 0, 0)
    incompleteBar:SetFrameLevel(mainBar:GetFrameLevel() - 1)
    incompleteBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    incompleteBar:SetStatusBarColor(db.incR, db.incG, db.incB, db.incA)
    incompleteBar:SetMinMaxValues(0, 1)
    incompleteBar:SetValue(0)
    incompleteBar:Hide()

    -- ── Segments orange (quêtes) / bleu (repos) ───
    questSegment = mainBar:CreateTexture(nil, "OVERLAY")
    questSegment:SetTexture("Interface/TargetingFrame/UI-StatusBar")
    questSegment:SetVertexColor(db.qR, db.qG, db.qB, db.qA)
    questSegment:SetHeight(db.height - 4)
    questSegment:Hide()

    restedSegment = mainBar:CreateTexture(nil, "OVERLAY")
    restedSegment:SetTexture("Interface/TargetingFrame/UI-StatusBar")
    restedSegment:SetVertexColor(db.rR, db.rG, db.rB, db.rA)
    restedSegment:SetHeight(db.height - 4)
    restedSegment:Hide()

    -- ── Labels ────────────────────────────────────
    labelLeft = mainBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelLeft:SetPoint("LEFT", mainBar, "LEFT", 8, 0)
    labelLeft:SetTextColor(1, 1, 1, 1)

    labelCenter = mainBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelCenter:SetPoint("CENTER", mainBar, "CENTER", 0, 0)
    labelCenter:SetTextColor(1, 1, 1, 1)

    labelRight = mainBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelRight:SetPoint("RIGHT", mainBar, "RIGHT", -8, 0)
    labelRight:SetTextColor(1, 1, 1, 1)

    labelBottom = containerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelBottom:SetPoint("TOP", mainBar, "BOTTOM", 0, -2)
    labelBottom:SetTextColor(0.7, 0.7, 0.7, 1)

    ApplyAppearance()
    ApplyOrientation()   -- fixe l'orientation, la taille et l'ancrage des labels
end

-- ══════════════════════════════════════════════════
-- UPDATE BAR
-- ══════════════════════════════════════════════════
UpdateBar = function()
    if not mainBar or not db then return end

    EnforceNativeBar()
    if not ApplyVisibility() then return end

    local cur, max, rest, pct, restPct              = GetXPData()
    local questPct, incompletePct, completed, total  = GetQuestData()
    local lvl = UnitLevel("player")

    mainBar:SetValue(pct)
    mainBar:SetStatusBarColor(db.barR, db.barG, db.barB, db.barA)
    questSegment:SetVertexColor(db.qR, db.qG, db.qB, db.qA)
    restedSegment:SetVertexColor(db.rR, db.rG, db.rB, db.rA)

    -- Barre quêtes incomplètes
    if db.showIncompleteBar and incompletePct > 0 then
        incompleteBar:SetStatusBarColor(db.incR, db.incG, db.incB, db.incA)
        incompleteBar:SetValue(incompletePct)
        incompleteBar:Show()
    else
        incompleteBar:Hide()
    end

    -- Labels selon l'orientation
    if IsVertical() then
        if db.verticalText then
            labelLeft:SetText(string.format("|cffddbbffNv %d|r", lvl))
            labelCenter:SetText("")
            labelRight:SetText(string.format("%.0f%%", pct * 100))
        end
    else
        labelLeft:SetText(string.format("|cffddbbff %s %d|r", L.LEVEL, lvl))
        if max > 0 then
            labelCenter:SetText(string.format("|cffffff99%d|r / |cffffff99%d|r", cur, max))
        else
            labelCenter:SetText("")
        end
        local rightTxt = string.format("|cffffffff%.1f%%|r", pct * 100)
        if restPct > 0 then
            rightTxt = rightTxt .. string.format(" |cff99ccff(%.1f%%)|r", (pct + restPct) * 100)
        end
        labelRight:SetText(rightTxt)
    end

    -- Segments visuels (quetes / repos), places le long de la barre selon
    -- l'orientation : gauche->droite en horizontal, bas->haut en vertical.
    local SEG    = 14
    local vert   = IsVertical()
    local w0, h0 = ActiveSize()
    local barLen = (vert and h0 or w0) - 4
    local thick  = (vert and w0 or h0)
    local offset = math.floor(pct * barLen) + 2
    local function placeSeg(seg, show)
        if not show then seg:Hide() ; return end
        seg:ClearAllPoints()
        if vert then
            seg:SetWidth(math.max(1, thick)) ; seg:SetHeight(SEG)
            seg:SetPoint("BOTTOM", mainBar, "BOTTOM", 0, offset)
        else
            seg:SetWidth(SEG) ; seg:SetHeight(math.max(1, thick - 4))
            seg:SetPoint("LEFT", mainBar, "LEFT", offset, 0)
        end
        seg:Show()
        offset = offset + SEG + 2
    end
    placeSeg(questSegment,  questPct > 0)
    placeSeg(restedSegment, restPct > 0)

    -- Ligne du bas (uniquement en horizontal ; masquee en vertical)
    if IsVertical() then
        labelBottom:Hide()
        return
    end
    local parts = {}
    if db.showCompletedQuests and total > 0 then
        table.insert(parts, string.format("%s : |cffff9900%.1f%%|r", L.QUESTS_DONE, questPct))
    end
    if db.showRestedText and restPct > 0 then
        table.insert(parts, string.format("%s : |cff66b3ff%.1f%%|r", L.RESTED, restPct * 100))
    end
    if db.showPlayedTime then
        table.insert(parts, string.format("|cffcccccc%s : %s|r", L.PLAYED, FormatTime(GetPlayedTime())))
    end
    if db.showSessionTime then
        table.insert(parts, string.format("|cffcccccc%s : %s|r", L.SESSION, FormatTime(GetSessionElapsed())))
    end
    if db.showXPPerHour or db.showLevelingTime then
        local perHour = GetEffectiveXPPerHour()
        if db.showXPPerHour and perHour > 0 then
            table.insert(parts, string.format("|cffaaffaaXP/h: %.0f|r", perHour))
        end
        if db.showLevelingTime and perHour > 0 and max > cur then
            table.insert(parts, string.format("|cffaaffaa~%s|r", FormatTime((max - cur) / perHour * 3600)))
        end
    end

    if #parts > 0 then
        labelBottom:SetText(table.concat(parts, " - "))
        labelBottom:Show()
    else
        labelBottom:Hide()
    end
end

-- ══════════════════════════════════════════════════
-- PANEL D'OPTIONS — widgets réutilisables
-- ══════════════════════════════════════════════════
local function MakeCheckbox(parent, lbl, x, y, getF, setF)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetChecked(getF())
    cb:SetScript("OnClick", function(self)
        setF(self:GetChecked() and true or false)
        UpdateBar()
    end)
    local txt = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    txt:SetText(lbl)
    return cb
end

local function MakeSlider(parent, label, x, y, minV, maxV, step, getV, applyV)
    local cap = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cap:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cap:SetText(label)
    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val:SetPoint("LEFT", cap, "RIGHT", 8, 0)
    val:SetTextColor(1, 0.82, 0)

    local sl = CreateFrame("Slider", nil, parent)
    sl:SetSize(200, 16)
    sl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 18)
    sl:SetOrientation("HORIZONTAL")
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    sl:SetObeyStepOnDrag(true)
    sl:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")
    sl:GetThumbTexture():SetSize(16, 16)
    local tr = sl:CreateTexture(nil, "BACKGROUND")
    tr:SetTexture("Interface/Buttons/UI-SliderBar-Background")
    tr:SetPoint("TOPLEFT", sl, "TOPLEFT", 0, -4)
    tr:SetPoint("BOTTOMRIGHT", sl, "BOTTOMRIGHT", 0, 4)
    tr:SetHorizTile(true)

    local function fmt(v)
        if step < 1 then return string.format("%.2f", v) else return tostring(math.floor(v + 0.5)) end
    end
    sl:SetValue(getV())
    val:SetText(fmt(getV()))
    sl:SetScript("OnValueChanged", function(self, v)
        if step >= 1 then v = math.floor(v / step + 0.5) * step end
        val:SetText(fmt(v))
        applyV(v)
    end)
    return sl
end

-- Sélecteur de couleur (bouton coloré ouvrant le ColorPickerFrame)
local function MakeColorSwatch(parent, label, x, y, getFn, setFn)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(18, 18)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local bord = btn:CreateTexture(nil, "BACKGROUND")
    bord:SetPoint("TOPLEFT", -1, 1)
    bord:SetPoint("BOTTOMRIGHT", 1, -1)
    bord:SetColorTexture(0, 0, 0, 1)

    local swatch = btn:CreateTexture(nil, "OVERLAY")
    swatch:SetAllPoints()
    local function refresh()
        local r, g, b, a = getFn()
        swatch:SetColorTexture(r, g, b, a or 1)
    end
    refresh()

    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("LEFT", btn, "RIGHT", 6, 0)
    txt:SetText(label)

    btn:SetScript("OnClick", function()
        local r, g, b, a = getFn()
        local function apply()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local na = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or a
            setFn(nr, ng, nb, na)
            refresh()
            UpdateBar()
        end
        local info = {
            swatchFunc  = apply,
            opacityFunc = apply,
            hasOpacity  = true,
            opacity     = a,      -- API moderne : 0..1, 1 = opaque
            r = r, g = g, b = b,
            cancelFunc  = function()
                setFn(r, g, b, a) ; refresh() ; UpdateBar()
            end,
        }
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            -- Repli ancien client
            ColorPickerFrame.func         = apply
            ColorPickerFrame.opacityFunc  = apply
            ColorPickerFrame.hasOpacity   = true
            ColorPickerFrame.opacity      = 1 - (a or 1)
            ColorPickerFrame.cancelFunc   = info.cancelFunc
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame:Show()
        end
    end)
    return btn
end

-- ══════════════════════════════════════════════════
-- PANEL D'OPTIONS
-- ══════════════════════════════════════════════════
CreateOptionsPanel = function()
    if optionsFrame then
        optionsFrame:Show()
        return
    end

    optionsFrame = CreateFrame("Frame", "XPBarOptions", UIParent, "BackdropTemplate")
    optionsFrame:SetSize(520, 640)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetClampedToScreen(true)
    optionsFrame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    optionsFrame:SetScript("OnDragStop",  function(f) f:StopMovingOrSizing() end)
    optionsFrame:SetBackdrop({
        bgFile   = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        edgeSize = 24,
        insets   = { left=6, right=6, top=6, bottom=6 },
    })
    optionsFrame:SetBackdropColor(0.1, 0.1, 0.15, 0.97)

    -- ── Titre ─────────────────────────────────────
    local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", optionsFrame, "TOP", 0, -16)
    title:SetText(L.OPT_TITLE)

    -- ── Bandeau ───────────────────────────────────
    local tabBg = optionsFrame:CreateTexture(nil, "BACKGROUND")
    tabBg:SetColorTexture(0.15, 0.10, 0.25, 0.8)
    tabBg:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  10, -44)
    tabBg:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -10, -44)
    tabBg:SetHeight(20)
    local tabLbl = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tabLbl:SetPoint("CENTER", tabBg, "CENTER")
    tabLbl:SetText(L.OPT_TAB)
    tabLbl:SetTextColor(1, 0.82, 0)

    -- ── Hint raccourcis ───────────────────────────
    local hint = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 14, -70)
    hint:SetText(L.OPT_HINT)
    hint:SetTextColor(0.75, 0.75, 0.75)

    local function Sep(y)
        local s = optionsFrame:CreateTexture(nil, "BACKGROUND")
        s:SetColorTexture(0.4, 0.4, 0.4, 0.4)
        s:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  10, y)
        s:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -10, y)
        s:SetHeight(1)
    end
    local function Header(text, x, y)
        local h = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", x, y)
        h:SetText(text) ; h:SetTextColor(1, 0.82, 0)
        return h
    end

    local C1, C2 = 16, 272

    -- ── Dimensions ────────────────────────────────
    Sep(-84)
    MakeSlider(optionsFrame, L.OPT_WIDTH, C1, -96, 200, 1200, 10,
        function() return db.width end,
        function(v) db.width = v ; ApplySize() ; UpdateBar() end)
    MakeSlider(optionsFrame, L.OPT_HEIGHT, C2, -96, 10, 60, 1,
        function() return db.height end,
        function(v) db.height = v ; ApplySize() ; UpdateBar() end)

    -- ── Couleurs ──────────────────────────────────
    Sep(-140)
    Header(L.OPT_COLORS, C1, -148)
    MakeColorSwatch(optionsFrame, L.OPT_COL_BAR, C1, -170,
        function() return db.barR, db.barG, db.barB, db.barA end,
        function(r,g,b,a) db.barR,db.barG,db.barB,db.barA = r,g,b,a end)
    MakeColorSwatch(optionsFrame, L.OPT_COL_QUEST, C2, -170,
        function() return db.qR, db.qG, db.qB, db.qA end,
        function(r,g,b,a) db.qR,db.qG,db.qB,db.qA = r,g,b,a end)
    MakeColorSwatch(optionsFrame, L.OPT_COL_RESTED, C1, -196,
        function() return db.rR, db.rG, db.rB, db.rA end,
        function(r,g,b,a) db.rR,db.rG,db.rB,db.rA = r,g,b,a end)
    MakeColorSwatch(optionsFrame, L.OPT_COL_INC, C2, -196,
        function() return db.incR, db.incG, db.incB, db.incA end,
        function(r,g,b,a) db.incR,db.incG,db.incB,db.incA = r,g,b,a end)

    -- ── Apparence ─────────────────────────────────
    Sep(-220)
    MakeSlider(optionsFrame, L.OPT_OPACITY, C1, -230, 0, 1, 0.05,
        function() return db.bgA end,
        function(v) db.bgA = v ; ApplyAppearance() end)
    MakeSlider(optionsFrame, L.OPT_FONTSIZE, C2, -230, 8, 20, 1,
        function() return (db.fontSize and db.fontSize > 0) and db.fontSize or 10 end,
        function(v) db.fontSize = v ; ApplyFont() end)

    -- ── Affichage ─────────────────────────────────
    Sep(-268)
    Header(L.OPT_DISPLAY, C1, -276)
    local Y0, DY = -298, -30
    MakeCheckbox(optionsFrame, L.OPT_PLAYED,   C1, Y0,
        function() return db.showPlayedTime end,
        function(v) db.showPlayedTime = v end)
    MakeCheckbox(optionsFrame, L.OPT_SESSION,  C2, Y0,
        function() return db.showSessionTime end,
        function(v) db.showSessionTime = v end)

    MakeCheckbox(optionsFrame, L.OPT_LEVELING, C1, Y0+DY,
        function() return db.showLevelingTime end,
        function(v) db.showLevelingTime = v ; db.showXPPerHour = v end)
    MakeCheckbox(optionsFrame, L.OPT_COMPLETED, C2, Y0+DY,
        function() return db.showCompletedQuests end,
        function(v) db.showCompletedQuests = v ; db.showRestedText = v end)

    MakeCheckbox(optionsFrame, L.OPT_ROLLING, C1, Y0+DY*2,
        function() return db.showRollingXP end,
        function(v) db.showRollingXP = v end)
    MakeCheckbox(optionsFrame, L.OPT_INCBAR, C2, Y0+DY*2,
        function() return db.showIncompleteBar end,
        function(v) db.showIncompleteBar = v end)

    MakeCheckbox(optionsFrame, L.OPT_MAXLEVEL, C1, Y0+DY*3,
        function() return db.showAtMaxLevel end,
        function(v) db.showAtMaxLevel = v end)
    MakeCheckbox(optionsFrame, L.OPT_RESETRELOAD, C2, Y0+DY*3,
        function() return db.resetSessionOnReload end,
        function(v) db.resetSessionOnReload = v end)

    MakeCheckbox(optionsFrame, L.OPT_HIDENATIVE, C1, Y0+DY*4,
        function() return db.hideDefaultXPBar end,
        function(v) db.hideDefaultXPBar = v ; UpdateBar() end)
    MakeCheckbox(optionsFrame, L.OPT_HIDECOMBAT, C2, Y0+DY*4,
        function() return db.hideInCombat end,
        function(v) db.hideInCombat = v end)

    MakeCheckbox(optionsFrame, L.OPT_HIDEVEHICLE, C1, Y0+DY*5,
        function() return db.hideInVehicle end,
        function(v) db.hideInVehicle = v end)
    MakeCheckbox(optionsFrame, L.OPT_MOUSEOVER, C2, Y0+DY*5,
        function() return db.mouseoverOnly end,
        function(v) db.mouseoverOnly = v end)

    -- ── Orientation ───────────────────────────────
    Sep(-462)
    Header("Orientation", C1, -470)
    MakeCheckbox(optionsFrame, "Barre verticale", C1, -490,
        function() return IsVertical() end,
        function(v)
            db.orientation = v and "VERTICAL" or "HORIZONTAL"
            ApplyOrientation() ; UpdateBar()
        end)
    MakeCheckbox(optionsFrame, "Texte a cote (vertical)", C2, -490,
        function() return db.verticalText end,
        function(v) db.verticalText = v ; LayoutLabels() ; UpdateBar() end)
    MakeSlider(optionsFrame, "Epaisseur :", C1, -524, 8, 60, 1,
        function() return db.vWidth end,
        function(v) db.vWidth = v ; if IsVertical() then ApplySize() end ; UpdateBar() end)
    MakeSlider(optionsFrame, "Longueur :", C2, -524, 100, 900, 10,
        function() return db.vHeight end,
        function(v) db.vHeight = v ; if IsVertical() then ApplySize() end ; UpdateBar() end)

    -- ── Boutons bas ───────────────────────────────
    local closeBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    closeBtn:SetSize(110, 26)
    closeBtn:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 14)
    closeBtn:SetText(L.OPT_CLOSE)
    closeBtn:SetScript("OnClick", function() optionsFrame:Hide() end)

    local resetBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    resetBtn:SetSize(140, 26)
    resetBtn:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 16, 14)
    resetBtn:SetText(L.OPT_RESETPOS)
    resetBtn:SetScript("OnClick", function()
        db.posX = 0 ; db.posY = -120 ; db.anchor = "TOP"
        containerFrame:ClearAllPoints()
        containerFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
        SavePosition()
        print("|cffFFD700[XPBar]|r " .. L.POS_RESET)
    end)

    local sessBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    sessBtn:SetSize(140, 26)
    sessBtn:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 14)
    sessBtn:SetText(L.OPT_RESETSESS)
    sessBtn:SetScript("OnClick", function()
        db.sessionStartTime = time()
        db.sessionXPGained  = 0
        db.sessionLevels    = 0
        db.sessionQuests    = 0
        wipe(xpSamples)
        db.lastXP = UnitXP("player")
        PushXPSample()
        UpdateBar()
        print("|cffFFD700[XPBar]|r " .. L.SESSION_RESET)
    end)

    -- Fermeture via la touche Échap (standard Blizzard)
    tinsert(UISpecialFrames, "XPBarOptions")

    optionsFrame:Show()
end

-- ══════════════════════════════════════════════════
-- ADDON COMPARTMENT (menu addons Retail)
-- ══════════════════════════════════════════════════
function XPBar_OnAddonCompartmentClick()
    CreateOptionsPanel()
end

-- ══════════════════════════════════════════════════
-- SLASH  →  /xpbar  ouvre les options
-- ══════════════════════════════════════════════════
SLASH_XPBAR1 = "/xpbar"
SLASH_XPBAR2 = "/xpbardebug"
SlashCmdList["XPBAR"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" or msg == "config" or msg == "options" then
        CreateOptionsPanel()
    elseif msg == "hide" then
        containerFrame:Hide()
        print("|cffFFD700[XPBar]|r Masqué. /xpbar show pour ré-afficher.")
    elseif msg == "show" then
        containerFrame:Show() ; UpdateBar()
    elseif msg == "session" then
        db.sessionStartTime = time() ; db.sessionXPGained = 0
        db.sessionLevels = 0 ; db.sessionQuests = 0
        wipe(xpSamples) ; db.lastXP = UnitXP("player") ; PushXPSample()
        UpdateBar()
        print("|cffFFD700[XPBar]|r " .. L.SESSION_RESET)
    elseif msg == "reset" then
        XPBarDB = nil ; ReloadUI()
    elseif msg == "debug" then
        local candidates = {
            "MainMenuExpBar", "ExhaustionTick", "MainMenuBarMaxLevelBar",
            "StatusTrackingBarManager", "MainMenuBar",
            "MainMenuBarArtFrame", "ReputationWatchBar",
            "MainMenuExpBar_ExhaustionTick",
        }
        print("|cffFFD700[XPBar DEBUG]|r Frames XP détectés :")
        for _, name in ipairs(candidates) do
            local f = _G[name]
            if f then
                local shown = f:IsShown() and "|cff00ff00VISIBLE|r" or "|cffff4444caché|r"
                local alpha = string.format("alpha=%.1f", f:GetAlpha())
                print(string.format("  |cffffff99%s|r : %s %s", name, shown, alpha))
            else
                print(string.format("  |cff888888%s|r : inexistant", name))
            end
        end
        if MainMenuBar then
            print("|cffFFD700Enfants de MainMenuBar :|r")
            local i = 1
            local child = select(i, MainMenuBar:GetChildren())
            while child do
                local n = child:GetName() or ("(sans nom) "..tostring(child))
                local shown = child:IsShown() and "VISIBLE" or "caché"
                print(string.format("  %s : %s", n, shown))
                i = i + 1
                child = select(i, MainMenuBar:GetChildren())
            end
        end
    else
        print("|cffFFD700[XPBar]|r  /xpbar — options  |  /xpbar hide/show  |  /xpbar session  |  /xpbar reset")
        print("  /xpbar debug — identifier les frames XP natifs")
    end
end

-- ══════════════════════════════════════════════════
-- EVENTS
-- ══════════════════════════════════════════════════
local evFrame = CreateFrame("Frame")
evFrame:RegisterEvent("ADDON_LOADED")
evFrame:RegisterEvent("PLAYER_LOGIN")
evFrame:RegisterEvent("PLAYER_LOGOUT")
evFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evFrame:RegisterEvent("PLAYER_XP_UPDATE")
evFrame:RegisterEvent("PLAYER_LEVEL_UP")
evFrame:RegisterEvent("UPDATE_EXHAUSTION")
evFrame:RegisterEvent("QUEST_LOG_UPDATE")
evFrame:RegisterEvent("QUEST_TURNED_IN")
evFrame:RegisterEvent("QUEST_COMPLETE")
evFrame:RegisterEvent("TIME_PLAYED_MSG")
evFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
evFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
evFrame:RegisterEvent("UNIT_EXITED_VEHICLE")

evFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 and string.lower(arg1) == string.lower(ADDON) then
        InitDB()
        CreateMainBar()

        -- Rattrapage LoadOnDemand : en module a la demande, PLAYER_LOGIN est
        -- deja passe quand XPBar se charge, donc le handler ci-dessous ne se
        -- declenchera plus. Si le joueur est deja connecte, on refait ici le
        -- meme travail de session (distinction /reload vs nouvelle session,
        -- init XP/h glissant, requete du temps joue).
        if IsLoggedIn() then
            local SESSION_GRACE = 300  -- 5 min
            local isNewSession = (db.sessionStartTime == 0)
                or (db.lastLogout > 0 and (time() - db.lastLogout) > SESSION_GRACE)
            if db.resetSessionOnReload or isNewSession then
                db.sessionStartTime = time()
                db.sessionXPGained  = 0
                db.sessionLevels    = 0
                db.sessionQuests    = 0
            end
            db.lastXP = UnitXP("player")
            wipe(xpSamples)
            PushXPSample()   -- point de depart pour l'XP/h glissant
            if RequestTimePlayed then RequestTimePlayed() end
            UpdateBar()
        end

    elseif event == "PLAYER_LOGIN" then
        -- Session : on distingue un /reload d'une vraie nouvelle session de jeu.
        -- PLAYER_LOGOUT (déclenché aussi par /reload) horodate db.lastLogout.
        -- Si l'écart depuis la dernière déconnexion dépasse SESSION_GRACE, c'est
        -- une nouvelle session → on repart de zéro. En deçà (typiquement un /reload
        -- de quelques secondes), on conserve la session en cours.
        if not db then InitDB() end
        local SESSION_GRACE = 300  -- 5 min
        local isNewSession = (db.sessionStartTime == 0)
            or (db.lastLogout > 0 and (time() - db.lastLogout) > SESSION_GRACE)
        if db.resetSessionOnReload or isNewSession then
            db.sessionStartTime = time()
            db.sessionXPGained  = 0
            db.sessionLevels    = 0
            db.sessionQuests    = 0
        end
        db.lastXP = UnitXP("player")
        wipe(xpSamples)
        PushXPSample()   -- point de départ pour l'XP/h glissant
        if RequestTimePlayed then RequestTimePlayed() end
        UpdateBar()

    elseif event == "PLAYER_LOGOUT" then
        -- Déclenché aussi par /reload : horodate la déconnexion pour permettre,
        -- à la prochaine connexion, de distinguer un /reload d'une vraie session.
        if db then db.lastLogout = time() end

    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateBar()

    elseif event == "PLAYER_XP_UPDATE" then
        if db then
            local newXP = UnitXP("player")
            local last  = db.lastXP or newXP
            local delta = newXP - last
            if delta > 0 then
                db.sessionXPGained = (db.sessionXPGained or 0) + delta
            elseif delta < 0 then
                -- Passage de niveau : l'XP repart de 0 et « déborde » dans le
                -- nouveau niveau. On compte l'XP acquise dans ce nouveau niveau
                -- (approximation prudente : n'induit jamais de double comptage).
                db.sessionXPGained = (db.sessionXPGained or 0) + newXP
            end
            db.lastXP = newXP
            PushXPSample()
        end
        UpdateBar()

    elseif event == "PLAYER_LEVEL_UP" then
        -- Le comptage d'XP est géré par PLAYER_XP_UPDATE (branche delta < 0).
        if db then db.sessionLevels = (db.sessionLevels or 0) + 1 end
        UpdateBar()

    elseif event == "QUEST_TURNED_IN" then
        if db then db.sessionQuests = (db.sessionQuests or 0) + 1 end
        UpdateBar()

    elseif event == "TIME_PLAYED_MSG" then
        -- arg1 = temps de jeu total (secondes), arg2 = temps sur le niveau actuel
        playedTimeBase      = arg1 or playedTimeBase
        playedTimeQueryTime = time()
        UpdateBar()

    elseif event == "PLAYER_REGEN_DISABLED"
        or  event == "PLAYER_REGEN_ENABLED"
        or  event == "UNIT_ENTERED_VEHICLE"
        or  event == "UNIT_EXITED_VEHICLE"
    then
        ApplyVisibility()

    elseif event == "UPDATE_EXHAUSTION"
        or  event == "QUEST_LOG_UPDATE"
        or  event == "QUEST_COMPLETE"
    then
        UpdateBar()
    end
end)

-- ══════════════════════════════════════════════════
-- INTEGRATION TibiSuite "Midnight"
-- Panneau d'options flottant Midnight + fonctions publiques attendues par
-- la barre TibiSuite (Toggle, OpenOptions). Ajout non destructif : le code
-- ci-dessus (dont le panneau d'options natif) reste disponible.
-- ══════════════════════════════════════════════════
local ACCENT_XP = { 0.737, 0.220, 0.980 }   -- violet (logo #BC38FA)
local function TibiUI() return _G.TibiMidnight end

-- Fonction publique Toggle (afficher / masquer la barre)
function XPBar_Toggle()
    if not containerFrame then return end
    if containerFrame:IsShown() then containerFrame:Hide()
    else containerFrame:Show(); UpdateBar() end
end

-- Panneau d'options flottant Midnight
local midnightPanel
local function BuildMidnightOptions()
    local ui = TibiUI(); if not ui then return nil end
    if midnightPanel then return midnightPanel end
    midnightPanel = ui.CreateOptionsPanel({
        name = "XPBarOptionsMidnight",
        title = "|cFF9480FFXPBar|r  Options", accent = ACCENT_XP })

    midnightPanel:Section("Dimensions")
    midnightPanel:Slider("Largeur", 200, 1200, 10,
        function() return db and db.width or 400 end,
        function(v) if db then db.width = v end; ApplySize(); UpdateBar() end)
    midnightPanel:Slider("Hauteur", 10, 60, 1,
        function() return db and db.height or 20 end,
        function(v) if db then db.height = v end; ApplySize(); UpdateBar() end)

    midnightPanel:Section("Affichage")
    local function disp(label, key)
        midnightPanel:Check(label,
            function() return db and db[key] end,
            function(v) if db then db[key] = v end; UpdateBar() end)
    end
    disp("Temps de jeu total", "showPlayedTime")
    disp("Temps de session", "showSessionTime")
    disp("Temps estimé de niveau", "showLevelingTime")
    disp("Quêtes complétées", "showCompletedQuests")
    disp("XP/h glissant", "showRollingXP")
    disp("Barre d'XP incomplète", "showIncompleteBar")
    disp("Afficher au niveau max", "showAtMaxLevel")
    disp("Masquer la barre d'XP native", "hideDefaultXPBar")

    midnightPanel:Section("Visibilité")
    local function vis(label, key)
        midnightPanel:Check(label,
            function() return db and db[key] end,
            function(v) if db then db[key] = v end; if ApplyVisibility then ApplyVisibility() end end)
    end
    vis("Masquer en combat", "hideInCombat")
    vis("Masquer en véhicule", "hideInVehicle")
    vis("Afficher au survol seulement", "mouseoverOnly")

    midnightPanel:Section("Orientation")
    midnightPanel:Check("Barre verticale",
        function() return db and db.orientation == "VERTICAL" end,
        function(v)
            if db then db.orientation = v and "VERTICAL" or "HORIZONTAL" end
            ApplyOrientation(); UpdateBar()
        end)
    midnightPanel:Check("Texte a cote (mode vertical)",
        function() return db and db.verticalText end,
        function(v) if db then db.verticalText = v end; LayoutLabels(); UpdateBar() end)
    midnightPanel:Slider("Epaisseur (vertical)", 8, 60, 1,
        function() return db and db.vWidth or 24 end,
        function(v) if db then db.vWidth = v end
            if IsVertical() then ApplySize() end; UpdateBar() end)
    midnightPanel:Slider("Longueur (vertical)", 100, 900, 10,
        function() return db and db.vHeight or 300 end,
        function(v) if db then db.vHeight = v end
            if IsVertical() then ApplySize() end; UpdateBar() end)

    midnightPanel:Section("Bouton flottant")
    midnightPanel:Check("Masquer le bouton Options",
        function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("XPBarContainer", "options") end,
        function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("XPBarContainer", "options", v) end end)

    return midnightPanel
end

function XPBar_OpenOptions()
    local p = BuildMidnightOptions(); if p then p:Toggle() end
end

-- Roue crantée sur la barre + harmonisation (pas de recherche pour XPBar)
local tibiEv = CreateFrame("Frame")
tibiEv:RegisterEvent("PLAYER_LOGIN")
tibiEv:SetScript("OnEvent", function()
    C_Timer.After(1.0, function()
        local ui = TibiUI()
        if not (ui and containerFrame) then return end
        if containerFrame._tibiControls then return end
        ui.AddHeaderControls(containerFrame, {
            accent = ACCENT_XP,
            onOptions = function() XPBar_OpenOptions() end,
        })
    end)
end)
