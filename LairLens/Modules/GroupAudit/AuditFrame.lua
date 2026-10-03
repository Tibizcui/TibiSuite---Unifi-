-- =============================================================================
-- LairLens - Modules/GroupAudit/AuditFrame.lua
-- Panneau d'audit : deplacable, sobre, non intrusif, mis a jour en direct.
-- Consomme uniquement les couches d'abstraction (Detection, Roster) et la
-- logique (AuditLogic). Aucun appel a l'API d'instance directement.
--
-- 7.1.5.37 : lignes ilvl moyen et taille du groupe ; en difficulte Monde (file
-- solo, scenario en 2 parties) le panneau suit l'etape du scenario au lieu
-- d'auditer un groupe forme par le jeu ; boutons Annoncer (chat du groupe,
-- sur clic uniquement, jamais en combat) et Fiche du Repaire.
-- =============================================================================

local ADDON, LL = ...
local C = LL.const
local U = LL.util
local A = LL.AuditLogic

local Audit = {}
LL:RegisterModule("groupAudit", Audit)

local frame          -- cadre principal
local rows = {}      -- lignes label/valeur reutilisees
local rowOrder = {}  -- ordre d'affichage des lignes d'audit
local scenRows = {}  -- lignes du mode scenario
local headline       -- FontString du verdict
local titleFS        -- titre (nom du Repaire ou libelle par defaut)
local subtitleFS     -- sous-titre (difficulte)
local separator      -- filet entre audit et recompense
local rewardLabel    -- libelle "Pertinence des recompenses"
local rewardValue    -- verdict du module 2
local announceBtn, infoBtn
local lastReport     -- dernier rapport rendu (pour Annoncer)
local lastHeader
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
local ROW_STEP = 17       -- hauteur d'une ligne (texte + espacement)

local function makeRow(parent)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetJustifyH("LEFT")
    value:SetJustifyH("RIGHT")
    label:SetWordWrap(false)
    return { label = label, value = value }
end

local function placeRow(row, y)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, y)
    row.label:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
    row.value:ClearAllPoints()
    row.value:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, y)
    row.label:Show(); row.value:Show()
end

local function hideRow(row) row.label:Hide(); row.value:Hide() end

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

local function smallButton(parent, text, onClick, tooltip)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetHeight(18)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b:SetBackdropColor(0.10, 0.11, 0.14, 0.95)
    b:SetBackdropBorderColor(0, 0, 0, 1)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    b:SetWidth(math.max(60, fs:GetStringWidth() + 16))
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(s)
        s:SetBackdropBorderColor(1, 1, 1, 0.6)
        if tooltip then
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(text, 1, 1, 1)
            GameTooltip:AddLine(tooltip, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(0, 0, 0, 1); GameTooltip:Hide() end)
    return b
end

-- Annonce le verdict dans le chat du groupe. Sur clic uniquement, hors combat.
local function announce()
    local L = LL.L
    if not lastReport then return end
    if InCombatLockdown() then U.Print(L["ANNOUNCE_COMBAT"]) return end
    local title = (lastHeader and lastHeader.title) or "LairLens"
    local sub = lastHeader and lastHeader.subtitle or ""
    local text = "[LairLens] " .. title .. (sub ~= "" and (" (" .. sub .. ")") or "") .. " : "
    if lastReport.verdict == C.VERDICT.VIABLE then
        text = text .. L["VERDICT_VIABLE"]
    else
        text = text .. string.format(L["ANNOUNCE_MISSING"], table.concat(lastReport.reasons or {}, ", "))
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local channel
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        channel = "INSTANCE_CHAT"
    elseif IsInRaid and IsInRaid() then
        channel = "RAID"
    elseif IsInGroup and IsInGroup() then
        channel = "PARTY"
    end
    if not channel then U.Print(text) return end
    local sender = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    local ok = sender and pcall(sender, text, channel)
    if not ok then U.Print(text) end
end

local function build()
    frame = CreateFrame("Frame", "LairLensAuditFrame", UIParent, "BackdropTemplate")
    frame:SetSize(236, 250)
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
    -- voir note detaillee dans TibiSuiteCore.lua (WireEscapeFor).
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

    titleFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOPLEFT", 12, -11)
    titleFS:SetPoint("RIGHT", -58, 0)
    titleFS:SetJustifyH("LEFT")
    titleFS:SetWordWrap(false)
    U.SetTextColor(titleFS, C.COLOR.ACCENT)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function() forcedShow = false; frame:Hide() end)

    -- Bouton d'acces direct au tableau de bord (historique des runs).
    local dashBtn = CreateFrame("Button", nil, frame)
    dashBtn:SetSize(18, 18)
    dashBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -9)
    local dashIcon = dashBtn:CreateTexture(nil, "ARTWORK")
    dashIcon:SetAllPoints()
    dashIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    dashIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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

    subtitleFS = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subtitleFS:SetPoint("TOPLEFT", 12, -27)
    subtitleFS:SetJustifyH("LEFT")

    headline = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headline:SetPoint("TOPLEFT", 12, -41)
    headline:SetPoint("RIGHT", -12, 0)
    headline:SetJustifyH("LEFT")

    rowOrder = { "tanks", "healers", "combatRez", "lust", "interrupts", "dispels", "ilvl", "size" }
    for _, key in ipairs(rowOrder) do rows[key] = makeRow(frame) end
    for i = 1, 5 do scenRows[i] = makeRow(frame) end

    separator = frame:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(1, 1, 1, 0.08)
    separator:SetHeight(1)

    rewardLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rewardLabel:SetJustifyH("LEFT")
    rewardLabel:SetText(LL.L["REWARD_TITLE"])
    U.SetTextColor(rewardLabel, C.COLOR.MUTED)

    rewardValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rewardValue:SetJustifyH("LEFT")

    announceBtn = smallButton(frame, LL.L["BTN_ANNOUNCE"], announce, LL.L["BTN_ANNOUNCE_TT"])
    infoBtn = smallButton(frame, LL.L["BTN_INFO"], function()
        if LL.modules.lairInfo then LL.modules.lairInfo:Toggle() end
    end, LL.L["BTN_INFO_TT"])

    restorePoint()
    frame:Hide()
end

-- Pose la section basse (recompense + boutons) sous `y` et ajuste la hauteur.
local function layoutFooter(y)
    separator:ClearAllPoints()
    separator:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, y - 2)
    separator:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    rewardLabel:ClearAllPoints()
    rewardLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, y - 9)
    rewardValue:ClearAllPoints()
    rewardValue:SetPoint("TOPLEFT", rewardLabel, "BOTTOMLEFT", 0, -3)
    rewardValue:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    local rh = math.max(12, rewardValue:GetStringHeight() or 12)
    local by = y - 9 - 14 - rh - 8
    announceBtn:ClearAllPoints()
    announceBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, by)
    infoBtn:ClearAllPoints()
    infoBtn:SetPoint("LEFT", announceBtn, "RIGHT", 6, 0)
    frame:SetHeight(-(by - 18 - 10))
end

-- -----------------------------------------------------------------------------
-- Rendu d'un rapport.
-- -----------------------------------------------------------------------------
local function colorForCount(current, target, needed)
    if needed and current == 0 then return C.COLOR[C.VERDICT.MISSING] end
    if target and current < target then return C.COLOR[C.VERDICT.RISKY] end
    return C.COLOR[C.VERDICT.VIABLE]
end

local function renderHeader(header)
    titleFS:SetText(header.title or LL.L["AUDIT_TITLE"])
    subtitleFS:SetText(header.subtitle or "")
    rewardValue:SetText(header.rewardText or "")
    U.SetTextColor(rewardValue, header.rewardColor or C.COLOR.MUTED)
end

local function render(report, header)
    local L = LL.L
    lastReport, lastHeader = report, header
    renderHeader(header)
    for _, r in ipairs(scenRows) do hideRow(r) end
    announceBtn:Show()

    headline:SetText(report.headline)
    U.SetTextColor(headline, C.COLOR[report.verdict])

    rows.tanks.label:SetText(L["TANKS"])
    rows.tanks.value:SetText(report.tanks .. " / " .. report.targets.tanks)
    U.SetTextColor(rows.tanks.value,
        colorForCount(report.tanks, report.targets.tanks, report.tanks == 0))

    rows.healers.label:SetText(L["HEALERS"])
    rows.healers.value:SetText(report.healers .. " / " .. report.targets.healers)
    U.SetTextColor(rows.healers.value,
        colorForCount(report.healers, report.targets.healers,
            report.targets.healers > 0 and report.healers == 0))

    rows.combatRez.label:SetText(L["COMBAT_REZ"])
    rows.combatRez.value:SetText(tostring(report.combatRezCount))
    local rezNeeded = report.expectation.needCombatRez
    U.SetTextColor(rows.combatRez.value,
        colorForCount(report.combatRezCount, rezNeeded and 1 or nil,
            rezNeeded and report.combatRezCount == 0))

    rows.lust.label:SetText(L["LUST"])
    if report.hasLust then
        rows.lust.value:SetText(L["PRESENT"])
        U.SetTextColor(rows.lust.value, C.COLOR[C.VERDICT.VIABLE])
    else
        rows.lust.value:SetText(L["ABSENT"])
        U.SetTextColor(rows.lust.value,
            report.expectation.needLust and C.COLOR[C.VERDICT.RISKY] or C.COLOR.MUTED)
    end

    rows.interrupts.label:SetText(L["INTERRUPTS"])
    rows.interrupts.value:SetText(tostring(report.interruptCount))
    U.SetTextColor(rows.interrupts.value,
        (report.expectation.needInterrupt and report.interruptCount == 0)
            and C.COLOR[C.VERDICT.RISKY] or C.COLOR[C.VERDICT.VIABLE])

    rows.dispels.label:SetText(L["DISPELS"])
    local tags = {}
    local shortLabel = {
        [C.DISPEL.MAGIC]   = L["DISPEL_MAGIC_SHORT"],
        [C.DISPEL.CURSE]   = L["DISPEL_CURSE_SHORT"],
        [C.DISPEL.POISON]  = L["DISPEL_POISON_SHORT"],
        [C.DISPEL.DISEASE] = L["DISPEL_DISEASE_SHORT"],
    }
    for _, dtype in ipairs(C.DISPEL_ORDER) do
        local n = report.dispels[dtype]
        tags[#tags + 1] = U.Colorize(shortLabel[dtype], n > 0 and C.COLOR[C.VERDICT.VIABLE] or C.COLOR.MUTED)
    end
    rows.dispels.value:SetText(table.concat(tags, " "))

    -- ilvl moyen connu / recommande.
    rows.ilvl.label:SetText(L["GROUP_ILVL"])
    if report.ilvl then
        local txt = tostring(math.floor(report.ilvl + 0.5))
        if report.recIlvl then txt = txt .. " / " .. report.recIlvl end
        if report.ilvlKnown and report.ilvlTotal and report.ilvlKnown < report.ilvlTotal then
            txt = txt .. U.Colorize(string.format(" (%d/%d)", report.ilvlKnown, report.ilvlTotal), C.COLOR.MUTED)
        end
        rows.ilvl.value:SetText(txt)
        U.SetTextColor(rows.ilvl.value, (report.recIlvl and report.ilvl < report.recIlvl)
            and C.COLOR[C.VERDICT.RISKY] or C.COLOR[C.VERDICT.VIABLE])
    else
        rows.ilvl.value:SetText(report.recIlvl and ("? / " .. report.recIlvl) or "?")
        U.SetTextColor(rows.ilvl.value, C.COLOR.MUTED)
    end

    -- Taille du groupe / bornes de la difficulte.
    rows.size.label:SetText(L["GROUP_SIZE"])
    local sizeTxt = tostring(report.size)
    if report.minSize and report.maxSize then
        sizeTxt = sizeTxt .. U.Colorize(string.format("  (%d-%d)", report.minSize, report.maxSize), C.COLOR.MUTED)
    end
    rows.size.value:SetText(sizeTxt)
    local bad = report.minSize and report.size < report.minSize
    U.SetTextColor(rows.size.value, bad and C.COLOR[C.VERDICT.MISSING] or C.COLOR.TEXT)

    local y = ROWS_START_Y
    for _, key in ipairs(rowOrder) do
        placeRow(rows[key], y)
        y = y - ROW_STEP
    end
    layoutFooter(y)
end

-- Mode scenario (difficulte Monde) : etape courante + objectifs.
local function renderScenario(header)
    local L = LL.L
    lastReport, lastHeader = nil, header
    renderHeader(header)
    for _, key in ipairs(rowOrder) do hideRow(rows[key]) end
    announceBtn:Hide()

    local info = C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo and select(2, pcall(C_ScenarioInfo.GetScenarioInfo))
    local step = C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo and select(2, pcall(C_ScenarioInfo.GetScenarioStepInfo))
    info = type(info) == "table" and info or {}
    step = type(step) == "table" and step or {}

    local stage, numStages = tonumber(info.currentStage), tonumber(info.numStages)
    local title = step.title or info.name or ""
    if stage and numStages and numStages > 0 then
        headline:SetText(string.format(L["SCEN_STAGE"], stage, numStages) .. (title ~= "" and (" : " .. title) or ""))
    else
        headline:SetText(L["SCEN_WORLD"])
    end
    U.SetTextColor(headline, C.COLOR.ACCENT)

    local y = ROWS_START_Y
    local n = math.min(#scenRows, tonumber(step.numCriteria) or 0)
    for i = 1, n do
        local ok, crit = false, nil
        if C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo then
            ok, crit = pcall(C_ScenarioInfo.GetCriteriaInfo, i)
        end
        local r = scenRows[i]
        if ok and type(crit) == "table" then
            r.label:SetText(crit.description or "?")
            local q, tq = tonumber(crit.quantity), tonumber(crit.totalQuantity)
            if crit.completed then
                r.value:SetText(L["SCEN_DONE"])
                U.SetTextColor(r.value, C.COLOR[C.VERDICT.VIABLE])
            elseif crit.quantityString and crit.quantityString ~= "" then
                r.value:SetText(crit.quantityString)
                U.SetTextColor(r.value, C.COLOR.TEXT)
            elseif q and tq and tq > 0 then
                r.value:SetText(q .. " / " .. tq)
                U.SetTextColor(r.value, C.COLOR.TEXT)
            else
                r.value:SetText("")
            end
            placeRow(r, y)
            y = y - ROW_STEP
        end
    end
    if n == 0 then
        local r = scenRows[1]
        r.label:SetText(L["SCEN_HINT"])
        r.value:SetText("")
        U.SetTextColor(r.label, C.COLOR.MUTED)
        placeRow(r, y)
        y = y - ROW_STEP
    else
        U.SetTextColor(scenRows[1].label, C.COLOR.TEXT)
    end
    layoutFooter(y)
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
Audit.DifficultyName = difficultyName

-- Construit l'en-tete (titre + sous-titre) et la ligne recompense du module 2.
local function buildHeader(instanceKey, difficultyKey, demo)
    local L = LL.L

    local title = L["AUDIT_TITLE"]
    if instanceKey then title = LL.Data:GetLairName(instanceKey) end

    local subtitle = difficultyName(difficultyKey)
    if demo then
        subtitle = (subtitle ~= "" and (subtitle .. "  ") or "") .. L["DEMO_TAG"]
    end

    local rewardText, rewardColor = L["REWARD_NO_DATA"], C.COLOR.MUTED
    local mod = LL.modules.rewardRelevance
    if mod and instanceKey and difficultyKey then
        local status, detail = mod:Evaluate(instanceKey, difficultyKey)
        rewardText, rewardColor = mod:Describe(status, detail)
    elseif not instanceKey then
        rewardText = L["REWARD_OUTSIDE"]
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
    if simMode then
        local demoKey = LL.Data:GetSingleLair() or "tidebound_grotto"
        local header = buildHeader(demoKey, C.DIFF.MYTHIC, true)
        render(A:Run(DEMO_MEMBERS, C.DIFF.MYTHIC, #DEMO_MEMBERS), header)
        frame:Show()
        return
    end

    local ctx = LL.Detection:GetContext()
    local header = buildHeader(ctx.instanceKey, ctx.difficultyKey, false)

    -- Scenario actif : on suit ses etapes. VU EN JEU (2026-10-03) : la
    -- difficulte Monde est une instance "raid" sans scenario (groupe de file de
    -- 5 a 40) ; elle garde donc l'audit classique tant qu'aucun scenario n'existe.
    if ctx.inLair and ctx.scenario then
        renderScenario(header)
        frame:Show()
        return
    end

    local members = LL.Roster:GetMembers()
    local size = LL.Roster:GetSize()

    if size <= 1 and not forcedShow and not ctx.inLair then
        frame:Hide()
        return
    end

    local report = A:Run(members, ctx.difficultyKey, ctx.inLair and ctx.groupSize > 0 and ctx.groupSize or size)
    render(report, header)
    frame:Show()
end

function Audit:Toggle()
    forcedShow = not forcedShow
    if not forcedShow and frame and frame:IsShown() and not LL.Detection:IsInLair() then
        frame:Hide()
        return
    end
    self:Update()
end

function Audit:SetSim(on)
    simMode = on and true or false
    self:Update()
end
function Audit:IsSim() return simMode end

local function applyCombatFade(inCombat)
    if not frame or not LL.db.audit.fadeInCombat then
        if frame then frame:SetAlpha(1) end
        return
    end
    frame:SetAlpha(inCombat and 0.35 or 1)
end

function Audit:ApplyScale()
    if frame then frame:SetScale(LL.db.audit.scale or 1.0) end
end

function Audit:ResetPosition()
    LL.db.audit.point = { "CENTER", nil, "CENTER", 0, 120 }
    LL.db.audit.scale = 1.0
    if frame then restorePoint() end
end

-- -----------------------------------------------------------------------------
-- Commandes /ll.
-- -----------------------------------------------------------------------------
local function handleSlash(msg)
    local cmd = (msg or ""):lower():gsub("%s+", "")
    if cmd == "show" or cmd == "" then
        Audit:Toggle()
    elseif cmd == "config" or cmd == "options" then
        if _G.LairLens_OpenOptions then _G.LairLens_OpenOptions() end
    elseif cmd == "dash" or cmd == "history" or cmd == "historique" then
        if LL.modules.dashboard then LL.modules.dashboard:Toggle() end
    elseif cmd == "info" or cmd == "fiche" then
        if LL.modules.lairInfo then LL.modules.lairInfo:Toggle() end
    elseif cmd == "probe" or cmd == "sonde" then
        if LL.Probe then LL.Probe:Run() end
    elseif cmd == "sim" or cmd == "demo" then
        Audit:SetSim(not simMode)
        U.Print("demo =", tostring(simMode))
    elseif cmd == "lock" then
        LL.db.audit.locked = not LL.db.audit.locked
        U.Print(LL.db.audit.locked and LL.L["FRAME_LOCKED"] or LL.L["FRAME_UNLOCKED"])
    elseif cmd == "reset" then
        Audit:ResetPosition()
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

    local update = U.Debounce(0.2, function() Audit:Update() end)
    LL:On("ROSTER_CHANGED", update)
    LL:On("LAIR_CONTEXT_CHANGED", update)
    LL:On("LOCKOUTS_CHANGED", update)
    LL:On("WEEKLY_RESET", update)
    LL:On("JOURNAL_READY", update)

    local cf = CreateFrame("Frame", "LairLensAuditCombatFrame")
    cf:RegisterEvent("PLAYER_REGEN_DISABLED")
    cf:RegisterEvent("PLAYER_REGEN_ENABLED")
    pcall(cf.RegisterEvent, cf, "SCENARIO_CRITERIA_UPDATE")
    pcall(cf.RegisterEvent, cf, "SCENARIO_UPDATE")
    pcall(cf.RegisterEvent, cf, "INSPECT_READY")
    cf:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            applyCombatFade(event == "PLAYER_REGEN_DISABLED")
        else
            update()
        end
    end)

    SLASH_LAIRLENS1 = "/lairlens"
    SLASH_LAIRLENS2 = "/ll"
    SlashCmdList["LAIRLENS"] = handleSlash

    LL:On("READY", function() Audit:Update() end)
end

LL:On("DB_READY", wire)
