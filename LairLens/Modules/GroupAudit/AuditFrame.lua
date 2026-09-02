-- =============================================================================
-- LairLens - Modules/GroupAudit/AuditFrame.lua
-- Panneau d'audit : deplacable, sobre, non intrusif, mis a jour en direct.
-- Consomme uniquement les couches d'abstraction (Detection, Roster) et la
-- logique (AuditLogic). Aucun appel a l'API d'instance directement.
-- =============================================================================

local ADDON, LL = ...
local C = LL.const
local U = LL.util
local A = LL.AuditLogic

local Audit = {}
LL:RegisterModule("groupAudit", Audit)

local frame          -- cadre principal
local rows = {}      -- lignes label/valeur reutilisees
local headline       -- FontString du verdict
local titleFS        -- titre (nom du Repaire ou libelle par defaut)
local subtitleFS     -- sous-titre (difficulte)
local separator      -- filet entre audit et recompense
local rewardLabel    -- libelle "Pertinence des recompenses"
local rewardValue    -- verdict du module 2
local forcedShow = false
local simMode = false -- mode demo : affiche un faux groupe pour juger le rendu

-- Faux groupe representatif, pour tester le rendu visuel en solo sur live sans
-- avoir a reunir 15 personnes. Purement cosmetique, jamais actif par defaut.
local DEMO_MEMBERS = {
    { name = "T1", class = "WARRIOR",     role = "TANK" },
    { name = "T2", class = "PALADIN",     role = "TANK" },
    { name = "H1", class = "PRIEST",      role = "HEALER" },
    { name = "H2", class = "DRUID",       role = "HEALER" },
    { name = "H3", class = "SHAMAN",      role = "HEALER" },
    { name = "D1", class = "MAGE",        role = "DAMAGER" },
    { name = "D2", class = "WARLOCK",     role = "DAMAGER" },
    { name = "D3", class = "HUNTER",      role = "DAMAGER" },
    { name = "D4", class = "ROGUE",       role = "DAMAGER" },
    { name = "D5", class = "DEATHKNIGHT", role = "DAMAGER" },
    { name = "D6", class = "EVOKER",      role = "DAMAGER" },
    { name = "D7", class = "DEMONHUNTER", role = "DAMAGER" },
    { name = "D8", class = "MONK",        role = "DAMAGER" },
    { name = "D9", class = "WARRIOR",     role = "DAMAGER" },
    { name = "D10", class = "DRUID",      role = "DAMAGER" },
    { name = "D11", class = "PRIEST",     role = "DAMAGER" },
}

-- -----------------------------------------------------------------------------
-- Construction du cadre (une seule fois).
-- -----------------------------------------------------------------------------
local ROWS_START_Y = -60  -- laisse la place au titre, au sous-titre et au verdict

local function makeRow(parent, previous)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

    label:SetJustifyH("LEFT")
    value:SetJustifyH("RIGHT")

    if previous then
        label:SetPoint("TOPLEFT", previous.label, "BOTTOMLEFT", 0, -6)
    else
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, ROWS_START_Y)
    end
    label:SetPoint("RIGHT", parent, "RIGHT", -12, 0)

    value:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
    value:SetPoint("TOP", label, "TOP", 0, 0)

    return { label = label, value = value }
end

local function savePoint()
    local point, _, relPoint, x, y = frame:GetPoint()
    LL.db.audit.point = { point, nil, relPoint, x, y }
end

local function restorePoint()
    local p = LL.db.audit.point
    frame:ClearAllPoints()
    frame:SetPoint(p[1] or "CENTER", UIParent, p[3] or "CENTER", p[4] or 0, p[5] or 120)
    frame:SetScale(LL.db.audit.scale or 1.0)
end

local function build()
    frame = CreateFrame("Frame", "LairLensAuditFrame", UIParent, "BackdropTemplate")
    frame:SetSize(236, 214)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)

    -- Fond plat sobre.
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.05, 0.06, 0.08, 0.86)
    frame:SetBackdropBorderColor(0, 0, 0, 1)

    -- Fermeture par Echap via UISpecialFrames (mecanisme natif Blizzard) :
    -- voir note detaillee dans TibiSuiteCore.lua (WireEscapeFor) - piege reel
    -- confirme en jeu quand un autre addon intercepte lui aussi Echap.
    tinsert(UISpecialFrames, "LairLensAuditFrame")

    -- Deplacement.
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not LL.db.audit.locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePoint()
    end)

    -- Titre : nom du Repaire quand on y est, sinon libelle par defaut.
    -- On reserve la place a droite (-34) pour le bouton d'acces au dashboard.
    titleFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOPLEFT", 12, -11)
    titleFS:SetPoint("RIGHT", -58, 0)
    titleFS:SetJustifyH("LEFT")
    U.SetTextColor(titleFS, C.COLOR.ACCENT)

    -- Croix de fermeture : jusqu'ici seul Echap (UISpecialFrames) fermait ce
    -- panneau - pas de croix visible, contrairement a toutes les autres
    -- fenetres de la suite. Decalee du coin pour laisser sa place a dashBtn
    -- (raccourci tableau de bord), juste en dessous/a gauche.
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Bouton d'acces direct au tableau de bord (historique des runs), en haut a
    -- droite du panneau. Fonctionne meme sans TibiSuite.
    local dashBtn = CreateFrame("Button", nil, frame)
    dashBtn:SetSize(18, 18)
    dashBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -9)
    local dashIcon = dashBtn:CreateTexture(nil, "ARTWORK")
    dashIcon:SetAllPoints()
    dashIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    dashIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- rogne la bordure de l'icone
    dashBtn:SetScript("OnEnter", function(self)
        dashIcon:SetVertexColor(1.0, 0.9, 0.6)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(LL.L["DASH_TITLE"])
        GameTooltip:AddLine(LL.L["DASH_OPEN_TT"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    dashBtn:SetScript("OnLeave", function()
        dashIcon:SetVertexColor(1.0, 1.0, 1.0)
        GameTooltip:Hide()
    end)
    dashBtn:SetScript("OnClick", function()
        if LL.modules.dashboard then LL.modules.dashboard:Toggle() end
    end)

    -- Sous-titre : difficulte.
    subtitleFS = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subtitleFS:SetPoint("TOPLEFT", 12, -27)
    subtitleFS:SetJustifyH("LEFT")

    -- Verdict.
    headline = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headline:SetPoint("TOPLEFT", 12, -41)
    headline:SetPoint("RIGHT", -12, 0)
    headline:SetJustifyH("LEFT")

    -- Lignes fixes de l'audit.
    local order = { "tanks", "healers", "combatRez", "lust", "interrupts", "dispels" }
    local prev
    for _, key in ipairs(order) do
        local row = makeRow(frame, prev)
        rows[key] = row
        prev = row
    end

    -- Filet de separation avant la section recompense.
    separator = frame:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(1, 1, 1, 0.08)
    separator:SetPoint("TOPLEFT", rows.dispels.label, "BOTTOMLEFT", 0, -8)
    separator:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    separator:SetHeight(1)

    -- Section module 2 : pertinence des recompenses.
    rewardLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rewardLabel:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 0, -7)
    rewardLabel:SetJustifyH("LEFT")
    rewardLabel:SetText(LL.L["REWARD_TITLE"])
    U.SetTextColor(rewardLabel, C.COLOR.MUTED)

    rewardValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rewardValue:SetPoint("TOPLEFT", rewardLabel, "BOTTOMLEFT", 0, -3)
    rewardValue:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    rewardValue:SetJustifyH("LEFT")

    restorePoint()
    frame:Hide()
end

-- -----------------------------------------------------------------------------
-- Rendu d'un rapport.
-- -----------------------------------------------------------------------------
local function colorForCount(current, target, needed)
    if needed and current == 0 then return C.COLOR[C.VERDICT.MISSING] end
    if target and current < target then return C.COLOR[C.VERDICT.RISKY] end
    return C.COLOR[C.VERDICT.VIABLE]
end

local function render(report, header)
    local L = LL.L

    -- En-tete : nom du Repaire, difficulte, et ligne recompense (module 2).
    if header then
        titleFS:SetText(header.title or L["AUDIT_TITLE"])
        subtitleFS:SetText(header.subtitle or "")
        rewardValue:SetText(header.rewardText or "")
        U.SetTextColor(rewardValue, header.rewardColor or C.COLOR.MUTED)
    end

    -- Verdict.
    headline:SetText(report.headline)
    U.SetTextColor(headline, C.COLOR[report.verdict])

    -- Tanks.
    rows.tanks.label:SetText(L["TANKS"])
    rows.tanks.value:SetText(report.tanks .. " / " .. report.targets.tanks)
    U.SetTextColor(rows.tanks.value,
        colorForCount(report.tanks, report.targets.tanks, report.tanks == 0))

    -- Soigneurs.
    rows.healers.label:SetText(L["HEALERS"])
    rows.healers.value:SetText(report.healers .. " / " .. report.targets.healers)
    U.SetTextColor(rows.healers.value,
        colorForCount(report.healers, report.targets.healers,
            report.targets.healers > 0 and report.healers == 0))

    -- Rez de combat.
    rows.combatRez.label:SetText(L["COMBAT_REZ"])
    rows.combatRez.value:SetText(tostring(report.combatRezCount))
    local rezNeeded = report.expectation.needCombatRez
    U.SetTextColor(rows.combatRez.value,
        colorForCount(report.combatRezCount, rezNeeded and 1 or nil,
            rezNeeded and report.combatRezCount == 0))

    -- Lust.
    rows.lust.label:SetText(L["LUST"])
    if report.hasLust then
        rows.lust.value:SetText(L["PRESENT"])
        U.SetTextColor(rows.lust.value, C.COLOR[C.VERDICT.VIABLE])
    else
        rows.lust.value:SetText(L["ABSENT"])
        U.SetTextColor(rows.lust.value,
            report.expectation.needLust and C.COLOR[C.VERDICT.RISKY] or C.COLOR.MUTED)
    end

    -- Interruptions.
    rows.interrupts.label:SetText(L["INTERRUPTS"])
    rows.interrupts.value:SetText(tostring(report.interruptCount))
    U.SetTextColor(rows.interrupts.value,
        (report.expectation.needInterrupt and report.interruptCount == 0)
            and C.COLOR[C.VERDICT.RISKY] or C.COLOR[C.VERDICT.VIABLE])

    -- Dissipations : ligne compacte, type manquant en attenue.
    rows.dispels.label:SetText(L["DISPELS"])
    local tags = {}
    local shortLabel = {
        [C.DISPEL.MAGIC]   = L["DISPEL_MAGIC"],
        [C.DISPEL.CURSE]   = L["DISPEL_CURSE"],
        [C.DISPEL.POISON]  = L["DISPEL_POISON"],
        [C.DISPEL.DISEASE] = L["DISPEL_DISEASE"],
    }
    for _, dtype in ipairs(C.DISPEL_ORDER) do
        local n = report.dispels[dtype]
        local base = string.sub(shortLabel[dtype], 1, 3)
        if n > 0 then
            table.insert(tags, U.Colorize(base, C.COLOR[C.VERDICT.VIABLE]))
        else
            table.insert(tags, U.Colorize(base, C.COLOR.MUTED))
        end
    end
    rows.dispels.value:SetText(table.concat(tags, " "))
end

-- -----------------------------------------------------------------------------
-- Visibilite et rafraichissement.
-- -----------------------------------------------------------------------------
local DIFF_LABEL_KEY = {
    [C.DIFF.WORLD]  = "DIFF_WORLD",
    [C.DIFF.NORMAL] = "DIFF_NORMAL",
    [C.DIFF.HEROIC] = "DIFF_HEROIC",
    [C.DIFF.MYTHIC] = "DIFF_MYTHIC",
}

local function difficultyName(key)
    return key and LL.L[DIFF_LABEL_KEY[key]] or ""
end

-- Construit l'en-tete (titre + sous-titre) et la ligne recompense du module 2.
local function buildHeader(instanceKey, difficultyKey, demo)
    local L = LL.L

    local title = L["AUDIT_TITLE"]
    if instanceKey then
        local inst = LL.Data:GetInstance("lair", instanceKey)
        if inst and inst.name then title = inst.name end
    end

    local subtitle = difficultyName(difficultyKey)
    if demo then
        subtitle = (subtitle ~= "" and (subtitle .. "  ") or "") .. "(demo)"
    end

    -- Module 2 : verdict de pertinence, si le module est present.
    local rewardText, rewardColor = L["REWARD_NO_DATA"], C.COLOR.MUTED
    local mod = LL.modules.rewardRelevance
    if mod and instanceKey and difficultyKey then
        local status, detail = mod:Evaluate(instanceKey, difficultyKey)
        rewardText, rewardColor = mod:Describe(status, detail)
    end

    return {
        title = title, subtitle = subtitle,
        rewardText = rewardText, rewardColor = rewardColor,
    }
end

local function shouldShow()
    if not LL.db.enabled then return false end
    if simMode or forcedShow then return true end
    if LL.Detection:IsInLair() then return true end
    return not LL.db.audit.hideOutOfLair and LL.Roster:GetSize() > 1
end

function Audit:Update()
    if not frame then return end

    if not shouldShow() then
        frame:Hide()
        return
    end
    -- Mode demo : faux groupe + faux contexte de Repaire pour juger le visuel.
    if simMode then
        local header = buildHeader("tidebound_grotto", LL.const.DIFF.MYTHIC, true)
        render(A:Run(DEMO_MEMBERS, LL.const.DIFF.MYTHIC, #DEMO_MEMBERS), header)
        frame:Show()
        return
    end

    local ctx = LL.Detection:GetContext()
    local members = LL.Roster:GetMembers()
    local size = LL.Roster:GetSize()

    if size <= 1 and not forcedShow then
        frame:Hide()
        return
    end

    local report = A:Run(members, ctx.difficultyKey, ctx.inLair and ctx.groupSize or size)
    local header = buildHeader(ctx.instanceKey, ctx.difficultyKey, false)
    render(report, header)
    frame:Show()
end

local function applyCombatFade(inCombat)
    if not frame or not LL.db.audit.fadeInCombat then
        if frame then frame:SetAlpha(1) end
        return
    end
    frame:SetAlpha(inCombat and 0.35 or 1)
end

-- Applique l'echelle courante au panneau (appele depuis les options).
function Audit:ApplyScale()
    if frame then frame:SetScale(LL.db.audit.scale or 1.0) end
end

-- -----------------------------------------------------------------------------
-- Commandes /ll.
-- -----------------------------------------------------------------------------
local function handleSlash(msg)
    local cmd = (msg or ""):lower():gsub("%s+", "")
    if cmd == "show" then
        forcedShow = not forcedShow
        Audit:Update()
    elseif cmd == "config" or cmd == "options" then
        if LL.modules.options then LL.modules.options:Open() end
    elseif cmd == "dash" or cmd == "history" or cmd == "historique" then
        if LL.modules.dashboard then LL.modules.dashboard:Toggle() end
    elseif cmd == "sim" then
        simMode = not simMode
        U.Print("sim =", tostring(simMode))
        Audit:Update()
    elseif cmd == "lock" then
        LL.db.audit.locked = not LL.db.audit.locked
        U.Print(LL.db.audit.locked and LL.L["FRAME_LOCKED"] or LL.L["FRAME_UNLOCKED"])
    elseif cmd == "reset" then
        LL.db.audit.point = { "CENTER", nil, "CENTER", 0, 120 }
        LL.db.audit.scale = 1.0
        restorePoint()
    elseif cmd == "debug" then
        LL.db.debug = not LL.db.debug
        U.Print("debug =", tostring(LL.db.debug))
    else
        U.Print(LL.L["SLASH_HELP"])
    end
end

-- -----------------------------------------------------------------------------
-- Cablage.
-- -----------------------------------------------------------------------------
local function wire()
    build()

    -- Reactions aux couches d'abstraction, avec debounce leger.
    local update = U.Debounce(0.2, function() Audit:Update() end)
    LL:On("ROSTER_CHANGED", update)
    LL:On("LAIR_CONTEXT_CHANGED", update)
    LL:On("LOCKOUTS_CHANGED", update) -- rafraichit la ligne recompense apres un kill
    LL:On("WEEKLY_RESET", update)

    -- Discretion en combat.
    local cf = CreateFrame("Frame", "LairLensAuditCombatFrame")
    cf:RegisterEvent("PLAYER_REGEN_DISABLED")
    cf:RegisterEvent("PLAYER_REGEN_ENABLED")
    cf:SetScript("OnEvent", function(_, event)
        applyCombatFade(event == "PLAYER_REGEN_DISABLED")
    end)

    -- Slash.
    SLASH_LAIRLENS1 = "/lairlens"
    SLASH_LAIRLENS2 = "/ll"
    SlashCmdList["LAIRLENS"] = handleSlash

    LL:On("READY", function() Audit:Update() end)
end

LL:On("DB_READY", wire)
