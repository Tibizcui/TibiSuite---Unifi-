-- RepBar.lua v5.0
-- Barre de reputation avancee - Tibiscui
-- Remplace la barre de reputation native, suit la faction par zone (via
-- RenTracker) et bascule a la validation d'une quete.
-- Maj+Drag pour deplacer | Maj+Clic droit pour les options

local ADDON = "RepBar"

-- ══════════════════════════════════════════════════
-- LOCALISATION
-- ══════════════════════════════════════════════════
local L = {
    FACTION       = "Faction",
    STANDING      = "Attitude",
    PROGRESS      = "Progression",
    REMAINING     = "Restant",
    ZONE          = "Zone",
    RENOWN        = "Renom",
    PARAGON       = "Paragon",
    NO_FACTION    = "Aucune faction suivie",
    HINT          = "|cffFFD700Maj+Drag|r deplacer  ·  |cffFFD700Maj+Clic droit|r options",
    POS_SAVED     = "Position sauvegardee.",
    POS_RESET     = "Position reinitialisee.",
    SWITCH_QUEST  = "Faction suivie : ",
    -- Options
    OPT_TITLE     = "|cffddbbffRepBar|r - Options",
    OPT_TAB       = "Options",
    OPT_HINT      = "|cffFFD700Maj+Drag|r pour deplacer   |cffFFD700Maj+Clic droit|r pour ouvrir/fermer",
    OPT_WIDTH     = "Largeur :",
    OPT_HEIGHT    = "Hauteur :",
    OPT_COLORS    = "Couleurs",
    OPT_COL_BAR   = "Barre (couleur fixe)",
    OPT_OPACITY   = "Opacite fond :",
    OPT_FONTSIZE  = "Taille texte :",
    OPT_DISPLAY   = "Affichage",
    OPT_STANDCOL  = "Couleur selon l'attitude",
    OPT_SHOWZONE  = "Afficher la zone de la faction",
    OPT_SHOWNUM   = "Afficher les valeurs (x / y)",
    OPT_SHOWPCT   = "Afficher le pourcentage",
    OPT_HIDENOFAC = "Masquer si aucune faction suivie",
    OPT_SWITCHQ   = "Basculer a la validation d'une quete",
    OPT_HIDENATIVE= "Masquer la barre de reputation native",
    OPT_HIDECOMBAT= "Masquer en combat",
    OPT_MOUSEOVER = "Afficher au survol seulement",
    OPT_CLOSE     = "Fermer",
    OPT_RESETPOS  = "Reinit. position",
}

-- ══════════════════════════════════════════════════
-- DEFAULTS
-- ══════════════════════════════════════════════════
local DEFAULTS = {
    posX = 0, posY = -146, anchor = "TOP",   -- juste sous la barre XP (-120)
    width = 600, height = 22,           -- dimensions en mode HORIZONTAL
    orientation  = "HORIZONTAL",        -- "HORIZONTAL" (defaut) ou "VERTICAL"
    vWidth  = 24,                       -- epaisseur en mode VERTICAL
    vHeight = 300,                      -- longueur en mode VERTICAL
    verticalText = false,               -- afficher le texte a cote de la barre en vertical
    useStandingColor = true,    -- barre coloree selon l'attitude (rouge->vert->violet)
    showZone         = true,    -- afficher la zone de la faction (issue de RenTracker)
    showNumbers      = true,    -- valeurs x / y
    showPercent      = true,
    switchOnQuest    = true,    -- basculer sur validation de quete
    hideNativeRepBar = true,    -- masquer la barre de reputation native
    hideWhenNoFaction= true,    -- se cacher si aucune faction suivie
    hideInCombat     = false,
    mouseoverOnly    = false,
    bgA      = 0.85,
    fontSize = 0,
    -- couleur fixe (utilisee si useStandingColor est faux) : azur d'identite RepBar
    barR = 0.36, barG = 0.68, barB = 0.96, barA = 1.0,
}

-- ══════════════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════════════
local db
local mainBar, fillBar, bgTexture
local labelLeft, labelCenter, labelRight, labelBottom
local containerFrame, dragFrame, optionsFrame
local mouseIsOver = false
local questArmed  = 0        -- GetTime() de la derniere validation de quete (fenetre de bascule)
local QUEST_WINDOW = 6       -- secondes : fenetre pendant laquelle un gain de rep = bascule
local nameToID    = nil      -- cache nom(minuscule) -> factionID (construit a la demande)
local zoneCache   = {}       -- factionID -> zone (issue de RenTrackerData)

-- Forward declarations
local UpdateBar, CreateOptionsPanel
local ApplySize, ApplyAppearance, ApplyFont, ApplyVisibility, EnforceNativeRepBar
local ApplyOrientation, LayoutLabels

-- ══════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════

-- XPBar est-il charge ? (il masque deja tout le StatusTrackingBarManager,
-- barre de reputation comprise : dans ce cas RepBar n'y touche jamais.)
local function XPBarLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("XPBar")
end

-- Orientation courante et dimensions actives selon celle-ci.
local function IsVertical() return db and db.orientation == "VERTICAL" end
local function ActiveSize()
    if IsVertical() then return db.vWidth or 24, db.vHeight or 300 end
    return db.width or 600, db.height or 22
end

-- ══════════════════════════════════════════════════
-- LECTURE UNIVERSELLE DE LA REPUTATION (API natives uniquement)
-- Supporte : amitie, renom (Major Factions), paragon, systeme classique.
-- Retourne une table { name, label, cur, max, pct, color, system, maxed } ou nil.
-- ══════════════════════════════════════════════════

-- Paragon : commun au renom (au cap) et au classique (exalte). Ecrase la
-- progression par celle du paragon si actif. Retourne true si paragon actif.
local function ApplyParagon(factionID, o)
    if not (C_Reputation and C_Reputation.IsFactionParagon) then return false end
    local pok, isP = pcall(C_Reputation.IsFactionParagon, factionID)
    if not (pok and isP) then return false end
    if not C_Reputation.GetFactionParagonInfo then return false end
    local gok, val, thr = pcall(C_Reputation.GetFactionParagonInfo, factionID)
    if not (gok and val and thr and thr > 0) then return false end
    o.paragon = true
    o.system  = "paragon"
    o.label   = L.PARAGON
    o.cur     = val % thr
    o.max     = thr
    o.pct     = o.cur / thr
    o.maxed   = false
    o.color   = { 1.00, 0.85, 0.40 }   -- ambre paragon
    return true
end

local function ReadReputation(factionID)
    if not factionID or factionID == 0 then return nil end
    local out = { factionID = factionID }

    -- 1) AMITIE (reputations a paliers personnalises) --------------------
    if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
        local ok, fr = pcall(C_GossipInfo.GetFriendshipReputation, factionID)
        if ok and fr and fr.friendshipFactionID and fr.friendshipFactionID ~= 0 then
            out.system = "friendship"
            out.name   = fr.name
            out.label  = fr.reaction or ""
            out.color  = { 0.25, 0.80, 0.45 }
            local cur  = fr.standing        or 0
            local minv = fr.reactionThreshold or 0
            local maxv = fr.nextThreshold     or 0
            if maxv and maxv > minv then
                out.cur = cur - minv
                out.max = maxv - minv
                out.pct = out.max > 0 and (out.cur / out.max) or 1
            else
                out.cur, out.max, out.pct, out.maxed = 1, 1, 1, true
            end
            return out
        end
    end

    -- 2) RENOM (Major Factions : SL / DF / TWW / Midnight) --------------
    if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
        local ok, d = pcall(C_MajorFactions.GetMajorFactionData, factionID)
        if ok and d and (d.renownLevel or d.renownLevelThreshold) then
            out.system = "renown"
            out.name   = d.name
            out.rank   = d.renownLevel or 0
            out.cur    = d.renownReputationEarned or 0
            out.max    = d.renownLevelThreshold   or 1
            out.pct    = (out.max > 0) and math.min(1, out.cur / out.max) or 0
            out.label  = L.RENOWN .. " " .. tostring(out.rank)
            out.color  = { 0.36, 0.68, 0.96 }   -- azur renom
            local isCap = false
            if C_MajorFactions.HasMaximumRenown then
                local cok, c = pcall(C_MajorFactions.HasMaximumRenown, factionID)
                isCap = cok and c
            end
            if isCap then
                out.maxed = true
                if not ApplyParagon(factionID, out) then
                    out.cur, out.pct = out.max, 1
                end
            end
            return out
        end
    end

    -- 3) SYSTEME CLASSIQUE (BfA et avant) -------------------------------
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, d = pcall(C_Reputation.GetFactionDataByID, factionID)
        if ok and d then
            out.system   = "classic"
            out.name     = d.name
            local reaction = d.reaction or 4
            out.reaction = reaction
            out.label    = _G["FACTION_STANDING_LABEL" .. reaction] or ""
            local c = _G.FACTION_BAR_COLORS and _G.FACTION_BAR_COLORS[reaction]
            out.color    = c and { c.r, c.g, c.b } or { 0.6, 0.6, 0.6 }
            local minv = d.currentReactionThreshold or 0
            local maxv = d.nextReactionThreshold     or 0
            local val  = d.currentStanding           or 0
            if maxv and maxv > minv then
                out.cur = val - minv
                out.max = maxv - minv
                out.pct = out.max > 0 and (out.cur / out.max) or 1
            else
                out.cur, out.max, out.pct, out.maxed = 1, 1, 1, true
            end
            if reaction >= 8 then
                out.maxed = true
                out.pct   = 1
                ApplyParagon(factionID, out)  -- Legion / BfA ont du paragon
            end
            return out
        end
    end

    return nil
end

-- Faction actuellement suivie par le jeu (celle qu'affiche la barre native).
local function GetWatchedFactionID()
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local ok, d = pcall(C_Reputation.GetWatchedFactionData)
        if ok and d and d.factionID and d.factionID ~= 0 then return d.factionID end
    end
    if GetWatchedFactionInfo then
        local ok, _, _, _, _, _, factionID = pcall(GetWatchedFactionInfo)
        if ok and factionID and factionID ~= 0 then return factionID end
    end
    return nil
end

-- Zone d'une faction, lue dans RenTrackerData si le module est present (lien
-- souple : purement cosmetique pour le tooltip / la ligne du bas).
local function GetFactionZone(factionID, factionName)
    if factionID and zoneCache[factionID] ~= nil then
        return zoneCache[factionID] or nil
    end
    local data = _G.RenTrackerData
    if type(data) ~= "table" then return nil end
    local found = false
    for _, ext in pairs(data) do
        if type(ext) == "table" and ext.factions then
            for _, fac in ipairs(ext.factions) do
                if (factionID and fac.id == factionID)
                or (factionName and fac.name == factionName) then
                    if factionID then zoneCache[factionID] = fac.zone or false end
                    return fac.zone
                end
            end
        end
    end
    if factionID and not found then zoneCache[factionID] = false end
    return nil
end

-- ══════════════════════════════════════════════════
-- INIT DB
-- ══════════════════════════════════════════════════
local function InitDB()
    RepBarDB = RepBarDB or {}
    db = RepBarDB
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
-- APPLY SIZE / FONT / APPARENCE
-- ══════════════════════════════════════════════════
ApplySize = function()
    if not containerFrame then return end
    local w, h = ActiveSize()
    local extra = IsVertical() and 0 or 20   -- ligne du bas : seulement en horizontal
    containerFrame:SetSize(w, h + extra)
    mainBar:SetSize(w, h)
    dragFrame:SetSize(w, h + extra)
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

-- Applique l'orientation a la barre puis reajuste taille et labels.
ApplyOrientation = function()
    if not mainBar then return end
    mainBar:SetOrientation(IsVertical() and "VERTICAL" or "HORIZONTAL")
    ApplySize()
    LayoutLabels()
end

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
-- VISIBILITE CONTEXTUELLE
-- Retourne true si la barre reste visible, false si masquee.
-- ══════════════════════════════════════════════════
ApplyVisibility = function()
    if not containerFrame or not db then return false end

    if db.hideInCombat and InCombatLockdown() then
        containerFrame:Hide() ; return false
    end
    -- Masquage si aucune faction suivie
    if db.hideWhenNoFaction and not GetWatchedFactionID() then
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
-- BARRE DE REPUTATION NATIVE
-- Coordination stricte avec XPBar : si XPBar est charge, il masque deja tout
-- le StatusTrackingBarManager (XP + reputation) -> RepBar n'y touche JAMAIS
-- (evite deux hooks concurrents sur le meme frame). Sans XPBar, RepBar masque
-- lui-meme le gestionnaire (option desactivable).
-- ══════════════════════════════════════════════════
EnforceNativeRepBar = function()
    if XPBarLoaded() then return end          -- XPBar est proprietaire du manager
    local mgr = StatusTrackingBarManager
    if not mgr then return end
    if db.hideNativeRepBar then
        mgr:Hide() ; mgr:SetAlpha(0)
        if not mgr.__repbarHooked then
            mgr.__repbarHooked = true
            mgr:HookScript("OnShow", function(self)
                if db and db.hideNativeRepBar and not XPBarLoaded() then
                    self:Hide() ; self:SetAlpha(0)
                end
            end)
        end
    else
        mgr:SetAlpha(1) ; mgr:Show()
    end
end

-- ══════════════════════════════════════════════════
-- CREATION UI
-- ══════════════════════════════════════════════════
local function CreateMainBar()
    containerFrame = CreateFrame("Frame", "RepBarContainer", UIParent)
    containerFrame:SetFrameStrata("MEDIUM")
    containerFrame:SetSize(db.width, db.height + 20)
    containerFrame:SetPoint(db.anchor, UIParent, db.anchor, db.posX, db.posY)
    containerFrame:SetMovable(true)
    containerFrame:SetClampedToScreen(true)

    -- Frame invisible pour le drag / clic droit
    dragFrame = CreateFrame("Button", "RepBarDragFrame", containerFrame)
    dragFrame:SetAllPoints(containerFrame)
    dragFrame:SetFrameStrata("HIGH")
    dragFrame:EnableMouse(true)
    dragFrame:RegisterForDrag("LeftButton")
    dragFrame:RegisterForClicks("RightButtonUp")
    dragFrame:SetAlpha(0)

    local isMoving = false
    dragFrame:SetScript("OnDragStart", function()
        if IsShiftKeyDown() then
            isMoving = true
            containerFrame:StartMoving()
            mainBar:SetAlpha(0.6)
        end
    end)
    dragFrame:SetScript("OnDragStop", function()
        if not isMoving then return end
        isMoving = false
        containerFrame:StopMovingOrSizing()
        mainBar:SetAlpha(1.0)
        SavePosition()
        print("|cffFFD700[RepBar]|r " .. L.POS_SAVED)
    end)
    dragFrame:SetScript("OnClick", function(_, button)
        if button == "RightButton" and IsShiftKeyDown() then
            if optionsFrame and optionsFrame:IsShown() then
                optionsFrame:Hide()
            else
                CreateOptionsPanel()
            end
        end
    end)

    -- Tooltip
    dragFrame:SetScript("OnEnter", function(self)
        mouseIsOver = true
        ApplyVisibility()

        local id = GetWatchedFactionID()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("RepBar", 0.36, 0.68, 0.96)
        GameTooltip:AddLine(" ")
        if not id then
            GameTooltip:AddLine(L.NO_FACTION, 0.8, 0.8, 0.8)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.HINT, .8, .8, .8)
            GameTooltip:Show()
            return
        end
        local r = ReadReputation(id)
        if r then
            GameTooltip:AddDoubleLine(L.FACTION,  r.name or "?",  1,.82,0, 1,1,1)
            GameTooltip:AddDoubleLine(L.STANDING, r.label or "-", 1,.82,0,
                r.color[1], r.color[2], r.color[3])
            if r.max and r.max > 1 and not r.maxed then
                GameTooltip:AddDoubleLine(L.PROGRESS,
                    string.format("%d / %d (%.1f%%)", r.cur, r.max, (r.pct or 0) * 100),
                    1,.82,0, 1,1,1)
                GameTooltip:AddDoubleLine(L.REMAINING,
                    string.format("%d", math.max(0, r.max - r.cur)), 1,.82,0, 1,1,1)
            elseif r.paragon then
                GameTooltip:AddDoubleLine(L.PARAGON,
                    string.format("%d / %d", r.cur, r.max), 1,.82,0, 1,.85,.4)
            end
            local zone = GetFactionZone(id, r.name)
            if zone then
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine(L.ZONE, zone, 1,.82,0, .8,.8,.8)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.HINT, .8, .8, .8)
        GameTooltip:Show()
    end)
    dragFrame:SetScript("OnLeave", function()
        mouseIsOver = false
        ApplyVisibility()
        GameTooltip:Hide()
    end)

    -- Barre principale
    mainBar = CreateFrame("StatusBar", "RepBarMain", containerFrame)
    mainBar:SetSize(db.width, db.height)
    mainBar:SetPoint("TOP", containerFrame, "TOP", 0, 0)
    mainBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    mainBar:SetStatusBarColor(db.barR, db.barG, db.barB, db.barA)
    mainBar:SetMinMaxValues(0, 1)
    mainBar:SetValue(0)
    fillBar = mainBar

    -- Fond sombre
    bgTexture = containerFrame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetPoint("TOPLEFT",     mainBar, "TOPLEFT",     0, 0)
    bgTexture:SetPoint("BOTTOMRIGHT", mainBar, "BOTTOMRIGHT", 0, 0)
    bgTexture:SetColorTexture(0.05, 0.05, 0.05, db.bgA or 0.85)

    -- Bordure fine
    local border = CreateFrame("Frame", nil, mainBar, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 6,
        insets   = { left=1, right=1, top=1, bottom=1 },
    })
    border:SetBackdropBorderColor(0, 0, 0, 0.7)

    -- Labels
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
    labelBottom:SetTextColor(0.7, 0.7, 0.7, 1)

    ApplyAppearance()
    ApplyOrientation()   -- fixe l'orientation, la taille et l'ancrage des labels
end

-- ══════════════════════════════════════════════════
-- UPDATE BAR
-- ══════════════════════════════════════════════════
UpdateBar = function()
    if not mainBar or not db then return end

    EnforceNativeRepBar()
    if not ApplyVisibility() then return end

    local id = GetWatchedFactionID()
    if not id then
        labelLeft:SetText("")
        labelCenter:SetText(L.NO_FACTION)
        labelRight:SetText("")
        labelBottom:Hide()
        mainBar:SetValue(0)
        return
    end

    local r = ReadReputation(id)
    if not r then
        labelLeft:SetText("")
        labelCenter:SetText("?")
        labelRight:SetText("")
        labelBottom:Hide()
        mainBar:SetValue(0)
        return
    end

    -- Couleur de la barre
    if db.useStandingColor and r.color then
        mainBar:SetStatusBarColor(r.color[1], r.color[2], r.color[3], db.barA or 1)
    else
        mainBar:SetStatusBarColor(db.barR, db.barG, db.barB, db.barA)
    end
    mainBar:SetValue(math.max(0, math.min(1, r.pct or 0)))

    local cr, cg, cb = r.color[1], r.color[2], r.color[3]

    -- Mode vertical : texte compact a cote (si demande) ou masque, puis stop.
    if IsVertical() then
        if db.verticalText then
            labelLeft:SetText(r.label or "")
            labelLeft:SetTextColor(cr, cg, cb, 1)
            if db.showNumbers and r.max and r.max > 1 and not r.maxed then
                labelCenter:SetText(string.format("|cffffff99%d/%d|r", r.cur, r.max))
            elseif r.paragon then
                labelCenter:SetText(string.format("|cffffe0a0%d/%d|r", r.cur, r.max))
            else
                labelCenter:SetText("")
            end
            if db.showPercent and not (r.maxed and not r.paragon) then
                labelRight:SetText(string.format("%.0f%%", (r.pct or 0) * 100))
            elseif r.maxed and not r.paragon then
                labelRight:SetText("|cff66b3ffMax|r")
            else
                labelRight:SetText("")
            end
        end
        return
    end

    -- Nom (gauche), colore selon l'attitude (mode horizontal)
    labelLeft:SetText(r.name or "")
    labelLeft:SetTextColor(cr, cg, cb, 1)

    -- Attitude + valeurs (centre)
    local center = r.label or ""
    if db.showNumbers and r.max and r.max > 1 and not r.maxed then
        center = center .. string.format("  |cffffff99%d / %d|r", r.cur, r.max)
    elseif r.paragon then
        center = center .. string.format("  |cffffe0a0%d / %d|r", r.cur, r.max)
    end
    labelCenter:SetText(center)

    -- Pourcentage (droite)
    if db.showPercent and not (r.maxed and not r.paragon) then
        labelRight:SetText(string.format("|cffffffff%.1f%%|r", (r.pct or 0) * 100))
    elseif r.maxed and not r.paragon then
        labelRight:SetText("|cff66b3ffMax|r")
    else
        labelRight:SetText("")
    end

    -- Ligne du bas : zone
    if db.showZone then
        local zone = GetFactionZone(id, r.name)
        if zone then
            labelBottom:SetText("|cffcccccc" .. L.ZONE .. " : " .. zone .. "|r")
            labelBottom:Show()
        else
            labelBottom:Hide()
        end
    else
        labelBottom:Hide()
    end
end

-- ══════════════════════════════════════════════════
-- BASCULE PAR QUETE
-- Sur QUEST_TURNED_IN on arme une fenetre ; le message de gain de reputation
-- (CHAT_MSG_COMBAT_FACTION_CHANGE) nous donne le NOM de la faction gagnee ->
-- on la resout en factionID et on la suit. Locale-safe : le motif est derive
-- de FACTION_STANDING_INCREASED.
-- ══════════════════════════════════════════════════

-- Construit un motif Lua depuis une chaine globale localisee (%s -> nom de
-- faction capture, %d -> nombre). Locale-safe.
local function ToPattern(base)
    base = base:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    base = base:gsub("%%%%s", "(.-)")   -- %s -> nom de faction
    base = base:gsub("%%%%d", "%%d+")   -- %d -> nombre
    return base
end

-- Liste des motifs de gain de reputation. On couvre toutes les variantes du
-- jeu : gain simple, bonus, et surtout ACCOUNT_WIDE (reputations de bataillon,
-- devenues la norme en TWW / Midnight) dont la phrase differe.
local GAIN_PATTERNS = nil
local function BuildGainPatterns()
    local seen, list = {}, {}
    local keys = {
        "FACTION_STANDING_INCREASED_ACCOUNT_WIDE",
        "FACTION_STANDING_INCREASED_DOUBLE_BONUS",
        "FACTION_STANDING_INCREASED_BONUS",
        "FACTION_STANDING_INCREASED_ACH_BONUS",
        "FACTION_STANDING_INCREASED",
    }
    for _, k in ipairs(keys) do
        local s = _G[k]
        if type(s) == "string" and s:find("%%s") and not seen[s] then
            seen[s] = true
            list[#list + 1] = ToPattern(s)
        end
    end
    if #list == 0 then
        list[1] = ToPattern("Reputation with %s increased by %d.")
    end
    return list
end

-- Construit (a la demande) le cache nom(minuscule) -> factionID.
local function BuildNameIndex()
    nameToID = {}
    if not (C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex) then
        return
    end
    local n = C_Reputation.GetNumFactions()
    for i = 1, (n or 0) do
        local ok, d = pcall(C_Reputation.GetFactionDataByIndex, i)
        if ok and d and not d.isHeader and d.name and d.factionID and d.factionID ~= 0 then
            nameToID[d.name:lower()] = d.factionID
        end
    end
end

local function ResolveFactionID(name)
    if not name then return nil end
    local key = name:lower()
    if nameToID and nameToID[key] then return nameToID[key] end
    BuildNameIndex()             -- reconstruire : la faction peut etre nouvelle
    return nameToID and nameToID[key] or nil
end

-- Tente de basculer la faction suivie sur celle nommee dans un message de gain.
local function TrySwitchFromGain(msg)
    if not db or not db.switchOnQuest then return end
    if (GetTime() - questArmed) > QUEST_WINDOW then return end
    if not msg then return end
    GAIN_PATTERNS = GAIN_PATTERNS or BuildGainPatterns()
    local fname
    for _, pat in ipairs(GAIN_PATTERNS) do
        fname = msg:match(pat)
        if fname and fname ~= "" then break end
    end
    if not fname or fname == "" then return end
    local id = ResolveFactionID(fname)
    if not id then return end
    if GetWatchedFactionID() == id then UpdateBar() ; return end
    if C_Reputation and C_Reputation.SetWatchedFactionByID then
        pcall(C_Reputation.SetWatchedFactionByID, id)
        questArmed = 0   -- consomme : une seule bascule par quete
        print("|cffFFD700[RepBar]|r " .. L.SWITCH_QUEST .. (fname or ""))
        UpdateBar()
    end
end

-- ══════════════════════════════════════════════════
-- PANEL D'OPTIONS - widgets
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
    sl:SetScript("OnValueChanged", function(_, v)
        if step >= 1 then v = math.floor(v / step + 0.5) * step end
        val:SetText(fmt(v))
        applyV(v)
    end)
    return sl
end

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
            opacity     = a,
            r = r, g = g, b = b,
            cancelFunc  = function() setFn(r, g, b, a) ; refresh() ; UpdateBar() end,
        }
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func        = apply
            ColorPickerFrame.opacityFunc = apply
            ColorPickerFrame.hasOpacity  = true
            ColorPickerFrame.opacity     = 1 - (a or 1)
            ColorPickerFrame.cancelFunc  = info.cancelFunc
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame:Show()
        end
    end)
    return btn
end

-- ══════════════════════════════════════════════════
-- PANEL D'OPTIONS (natif, Maj+Clic droit)
-- ══════════════════════════════════════════════════
CreateOptionsPanel = function()
    if optionsFrame then optionsFrame:Show() ; return end

    optionsFrame = CreateFrame("Frame", "RepBarOptions", UIParent, "BackdropTemplate")
    optionsFrame:SetSize(520, 560)
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

    local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", optionsFrame, "TOP", 0, -16)
    title:SetText(L.OPT_TITLE)

    local hint = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 14, -44)
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

    -- Dimensions
    Sep(-58)
    MakeSlider(optionsFrame, L.OPT_WIDTH, C1, -70, 200, 1200, 10,
        function() return db.width end,
        function(v) db.width = v ; ApplySize() ; UpdateBar() end)
    MakeSlider(optionsFrame, L.OPT_HEIGHT, C2, -70, 10, 60, 1,
        function() return db.height end,
        function(v) db.height = v ; ApplySize() ; UpdateBar() end)

    -- Apparence
    Sep(-112)
    MakeSlider(optionsFrame, L.OPT_OPACITY, C1, -122, 0, 1, 0.05,
        function() return db.bgA end,
        function(v) db.bgA = v ; ApplyAppearance() end)
    MakeSlider(optionsFrame, L.OPT_FONTSIZE, C2, -122, 8, 20, 1,
        function() return (db.fontSize and db.fontSize > 0) and db.fontSize or 10 end,
        function(v) db.fontSize = v ; ApplyFont() end)
    MakeColorSwatch(optionsFrame, L.OPT_COL_BAR, C1, -158,
        function() return db.barR, db.barG, db.barB, db.barA end,
        function(r,g,b,a) db.barR,db.barG,db.barB,db.barA = r,g,b,a end)

    -- Affichage
    Sep(-182)
    Header(L.OPT_DISPLAY, C1, -190)
    local Y0, DY = -212, -30
    MakeCheckbox(optionsFrame, L.OPT_STANDCOL, C1, Y0,
        function() return db.useStandingColor end,
        function(v) db.useStandingColor = v end)
    MakeCheckbox(optionsFrame, L.OPT_SHOWZONE, C2, Y0,
        function() return db.showZone end,
        function(v) db.showZone = v end)

    MakeCheckbox(optionsFrame, L.OPT_SHOWNUM, C1, Y0+DY,
        function() return db.showNumbers end,
        function(v) db.showNumbers = v end)
    MakeCheckbox(optionsFrame, L.OPT_SHOWPCT, C2, Y0+DY,
        function() return db.showPercent end,
        function(v) db.showPercent = v end)

    MakeCheckbox(optionsFrame, L.OPT_SWITCHQ, C1, Y0+DY*2,
        function() return db.switchOnQuest end,
        function(v) db.switchOnQuest = v end)
    MakeCheckbox(optionsFrame, L.OPT_HIDENOFAC, C2, Y0+DY*2,
        function() return db.hideWhenNoFaction end,
        function(v) db.hideWhenNoFaction = v end)

    MakeCheckbox(optionsFrame, L.OPT_HIDENATIVE, C1, Y0+DY*3,
        function() return db.hideNativeRepBar end,
        function(v) db.hideNativeRepBar = v ; EnforceNativeRepBar() ; UpdateBar() end)
    MakeCheckbox(optionsFrame, L.OPT_HIDECOMBAT, C2, Y0+DY*3,
        function() return db.hideInCombat end,
        function(v) db.hideInCombat = v end)

    MakeCheckbox(optionsFrame, L.OPT_MOUSEOVER, C1, Y0+DY*4,
        function() return db.mouseoverOnly end,
        function(v) db.mouseoverOnly = v end)
    MakeCheckbox(optionsFrame, "Barre verticale", C2, Y0+DY*4,
        function() return IsVertical() end,
        function(v)
            db.orientation = v and "VERTICAL" or "HORIZONTAL"
            ApplyOrientation() ; UpdateBar()
        end)

    -- Orientation verticale (dimensions dediees + texte a cote)
    Sep(-352)
    Header("Mode vertical", C1, -360)
    MakeCheckbox(optionsFrame, "Texte a cote de la barre", C1, -380,
        function() return db.verticalText end,
        function(v) db.verticalText = v ; LayoutLabels() ; UpdateBar() end)
    MakeSlider(optionsFrame, "Epaisseur :", C1, -414, 8, 60, 1,
        function() return db.vWidth end,
        function(v) db.vWidth = v ; if IsVertical() then ApplySize() end ; UpdateBar() end)
    MakeSlider(optionsFrame, "Longueur :", C2, -414, 100, 900, 10,
        function() return db.vHeight end,
        function(v) db.vHeight = v ; if IsVertical() then ApplySize() end ; UpdateBar() end)

    -- Boutons bas
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
        db.posX = 0 ; db.posY = -146 ; db.anchor = "TOP"
        containerFrame:ClearAllPoints()
        containerFrame:SetPoint("TOP", UIParent, "TOP", 0, -146)
        SavePosition()
        print("|cffFFD700[RepBar]|r " .. L.POS_RESET)
    end)

    tinsert(UISpecialFrames, "RepBarOptions")
    optionsFrame:Show()
end

-- ══════════════════════════════════════════════════
-- ADDON COMPARTMENT / SLASH
-- ══════════════════════════════════════════════════
function RepBar_OnAddonCompartmentClick()
    CreateOptionsPanel()
end

SLASH_REPBAR1 = "/repbar"
SlashCmdList["REPBAR"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" or msg == "config" or msg == "options" then
        CreateOptionsPanel()
    elseif msg == "hide" then
        containerFrame:Hide()
        print("|cffFFD700[RepBar]|r Masque. /repbar show pour re-afficher.")
    elseif msg == "show" then
        containerFrame:Show() ; UpdateBar()
    elseif msg == "reset" then
        RepBarDB = nil ; ReloadUI()
    else
        print("|cffFFD700[RepBar]|r  /repbar - options  |  /repbar hide/show  |  /repbar reset")
    end
end

-- ══════════════════════════════════════════════════
-- EVENTS
-- ══════════════════════════════════════════════════
local evFrame = CreateFrame("Frame")
evFrame:RegisterEvent("ADDON_LOADED")
evFrame:RegisterEvent("PLAYER_LOGIN")
evFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evFrame:RegisterEvent("UPDATE_FACTION")
evFrame:RegisterEvent("QUEST_TURNED_IN")
evFrame:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
evFrame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
evFrame:RegisterEvent("ZONE_CHANGED")
evFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
evFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
evFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
evFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

evFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 and string.lower(arg1) == string.lower(ADDON) then
        InitDB()
        CreateMainBar()
        if IsLoggedIn() then
            EnforceNativeRepBar()
            -- Laisse RenTracker positionner la faction de zone avant le 1er rendu.
            C_Timer.After(0.5, UpdateBar)
        end

    elseif event == "PLAYER_LOGIN" then
        if not db then InitDB() end
        EnforceNativeRepBar()
        C_Timer.After(0.5, UpdateBar)

    elseif event == "PLAYER_ENTERING_WORLD" then
        EnforceNativeRepBar()
        UpdateBar()

    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED_INDOORS" then
        -- RenTracker change la faction suivie sur ces memes evenements ; on
        -- rafraichit apres lui (leger differe pour laisser passer son handler).
        C_Timer.After(0.15, UpdateBar)

    elseif event == "QUEST_TURNED_IN" then
        questArmed = GetTime()   -- arme la fenetre de bascule par quete
        UpdateBar()

    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        TrySwitchFromGain(arg1)

    elseif event == "UPDATE_FACTION"
        or event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" then
        UpdateBar()

    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        ApplyVisibility()
    end
end)

-- ══════════════════════════════════════════════════
-- INTEGRATION TibiSuite "Midnight"
-- ══════════════════════════════════════════════════
local ACCENT_REP = { 0.36, 0.68, 0.96 }   -- azur d'identite RepBar
local function TibiUI() return _G.TibiMidnight end

function RepBar_Toggle()
    if not containerFrame then return end
    if containerFrame:IsShown() then containerFrame:Hide()
    else containerFrame:Show() ; UpdateBar() end
end

local midnightPanel
local function BuildMidnightOptions()
    local ui = TibiUI() ; if not ui then return nil end
    if midnightPanel then return midnightPanel end
    midnightPanel = ui.CreateOptionsPanel({
        name = "RepBarOptionsMidnight",
        title = "|cFF9480FFRepBar|r  Options", accent = ACCENT_REP })

    midnightPanel:Section("Dimensions")
    midnightPanel:Slider("Largeur", 200, 1200, 10,
        function() return db and db.width or 600 end,
        function(v) if db then db.width = v end ; ApplySize() ; UpdateBar() end)
    midnightPanel:Slider("Hauteur", 10, 60, 1,
        function() return db and db.height or 22 end,
        function(v) if db then db.height = v end ; ApplySize() ; UpdateBar() end)

    midnightPanel:Section("Affichage")
    local function disp(label, key, refreshNative)
        midnightPanel:Check(label,
            function() return db and db[key] end,
            function(v)
                if db then db[key] = v end
                if refreshNative then EnforceNativeRepBar() end
                UpdateBar()
            end)
    end
    disp("Couleur selon l'attitude", "useStandingColor")
    disp("Afficher la zone de la faction", "showZone")
    disp("Afficher les valeurs (x / y)", "showNumbers")
    disp("Afficher le pourcentage", "showPercent")
    disp("Masquer si aucune faction suivie", "hideWhenNoFaction")
    disp("Masquer la barre native", "hideNativeRepBar", true)

    midnightPanel:Section("Comportement")
    midnightPanel:Check("Basculer a la validation d'une quete",
        function() return db and db.switchOnQuest end,
        function(v) if db then db.switchOnQuest = v end end)
    midnightPanel:Check("Masquer en combat",
        function() return db and db.hideInCombat end,
        function(v) if db then db.hideInCombat = v end ; ApplyVisibility() end)
    midnightPanel:Check("Afficher au survol seulement",
        function() return db and db.mouseoverOnly end,
        function(v) if db then db.mouseoverOnly = v end ; ApplyVisibility() end)

    midnightPanel:Section("Orientation")
    midnightPanel:Check("Barre verticale",
        function() return db and db.orientation == "VERTICAL" end,
        function(v)
            if db then db.orientation = v and "VERTICAL" or "HORIZONTAL" end
            ApplyOrientation() ; UpdateBar()
        end)
    midnightPanel:Check("Texte a cote (mode vertical)",
        function() return db and db.verticalText end,
        function(v) if db then db.verticalText = v end ; LayoutLabels() ; UpdateBar() end)
    midnightPanel:Slider("Epaisseur (vertical)", 8, 60, 1,
        function() return db and db.vWidth or 24 end,
        function(v) if db then db.vWidth = v end
            if IsVertical() then ApplySize() end ; UpdateBar() end)
    midnightPanel:Slider("Longueur (vertical)", 100, 900, 10,
        function() return db and db.vHeight or 300 end,
        function(v) if db then db.vHeight = v end
            if IsVertical() then ApplySize() end ; UpdateBar() end)

    midnightPanel:Section("Bouton flottant")
    midnightPanel:Check("Masquer le bouton Options",
        function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("RepBarContainer", "options") end,
        function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("RepBarContainer", "options", v) end end)

    return midnightPanel
end

function RepBar_OpenOptions()
    local p = BuildMidnightOptions() ; if p then p:Toggle() end
end

-- Rattrapage cosmetique : roue crantee sur la barre (le handler ci-dessus
-- s'execute aussi en LoadOnDemand via le module glue).
local tibiEv = CreateFrame("Frame")
tibiEv:RegisterEvent("PLAYER_LOGIN")
tibiEv:SetScript("OnEvent", function()
    C_Timer.After(1.0, function()
        local ui = TibiUI()
        if not (ui and containerFrame) then return end
        if containerFrame._tibiControls then return end
        if ui.AddHeaderControls then
            ui.AddHeaderControls(containerFrame, {
                accent = ACCENT_REP,
                onOptions = function() RepBar_OpenOptions() end,
            })
        end
    end)
end)
