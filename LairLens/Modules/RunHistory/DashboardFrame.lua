-- =============================================================================
-- LairLens - Modules/RunHistory/DashboardFrame.lua
-- Tableau de bord de l'historique des runs. Style maison "plat" (identique a
-- l'AuditFrame et a la suite TibiMidnight) : fond sombre, bordure fine noire,
-- accent blanc pretre. Autonome : ne depend d'aucune lib externe.
--
-- Contenu : en-tete de stats, filtres cliquables (perso / difficulte / Repaire),
-- recherche, et une liste scrollable de runs. Chaque run se deplie pour montrer
-- le groupe (nom colore par classe, role, ilvl).
-- =============================================================================

local ADDON, LL = ...
local C = LL.const
local U = LL.util

local Dash = {}
LL:RegisterModule("dashboard", Dash)

local RH = nil  -- resolu au premier usage (LL.RunHistory)

local frame              -- fenetre principale
local content            -- enfant scrollable
local headerFS           -- ligne de stats
local ownerBtn, diffBtn, instBtn, searchBox
local emptyFS
local runRows = {}       -- pool de lignes de run
local memberRows = {}    -- pool de lignes de membre
local expanded = {}      -- [run] = true si deplie
local confirmClear = 0   -- horodatage du 1er clic "vider"

local DIFF_LABEL = {
    [C.DIFF.WORLD]  = "DIFF_WORLD",
    [C.DIFF.NORMAL] = "DIFF_NORMAL",
    [C.DIFF.HEROIC] = "DIFF_HEROIC",
    [C.DIFF.MYTHIC] = "DIFF_MYTHIC",
}
local DIFF_CYCLE = { false, C.DIFF.WORLD, C.DIFF.NORMAL, C.DIFF.HEROIC, C.DIFF.MYTHIC }

-- --- Fabriques de widgets plats ---------------------------------------------
local function flatBackdrop(edge)
    return {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = edge or 1,
    }
end

local function makeButton(parent, w, h)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    b:SetBackdrop(flatBackdrop(1))
    b:SetBackdropColor(0.10, 0.11, 0.14, 0.95)
    b:SetBackdropBorderColor(0, 0, 0, 1)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", 8, 0)
    fs:SetPoint("RIGHT", -8, 0)
    fs:SetJustifyH("LEFT")
    b._label = fs
    b:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(1, 1, 1, 0.6) end)
    b:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(0, 0, 0, 1) end)
    return b
end

-- --- Libelles des filtres ----------------------------------------------------
local function ownerLabel()
    local o = LL.db.dashboard.filterOwner
    return U.Colorize(LL.L["DASH_FILTER_OWNER"] .. ": ", C.COLOR.MUTED) .. (o or LL.L["DASH_ALL"])
end
local function diffLabel()
    local d = LL.db.dashboard.filterDiff
    local txt = d and LL.L[DIFF_LABEL[d]] or LL.L["DASH_ALL"]
    return U.Colorize(LL.L["DASH_FILTER_DIFF"] .. ": ", C.COLOR.MUTED) .. txt
end
local function instLabel()
    local k = LL.db.dashboard.filterInstance
    local name = LL.L["DASH_ALL"]
    if k then
        for _, it in ipairs(RH:GetInstances()) do
            if it.key == k then name = it.name break end
        end
    end
    return U.Colorize(LL.L["DASH_FILTER_INSTANCE"] .. ": ", C.COLOR.MUTED) .. name
end

local function refreshFilterLabels()
    ownerBtn._label:SetText(ownerLabel())
    diffBtn._label:SetText(diffLabel())
    instBtn._label:SetText(instLabel())
end

-- Cycle la valeur d'un filtre a partir d'une liste ordonnee de valeurs.
local function cycle(values, current)
    local idx = 1
    for i, v in ipairs(values) do
        if v == current or (v == false and current == nil) then idx = i break end
    end
    local nextV = values[(idx % #values) + 1]
    if nextV == false then return nil end
    return nextV
end

-- --- Une ligne de run --------------------------------------------------------
local function getRunRow(i)
    local r = runRows[i]
    if r then return r end

    r = CreateFrame("Button", nil, content, "BackdropTemplate")
    r:SetBackdrop(flatBackdrop(1))
    r:SetBackdropColor(0.07, 0.08, 0.10, 0.90)
    r:SetBackdropBorderColor(0, 0, 0, 0.8)

    local function col(anchorX, w, justify, font)
        local fs = r:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
        fs:SetPoint("LEFT", r, "LEFT", anchorX, 0)
        fs:SetWidth(w)
        fs:SetJustifyH(justify or "LEFT")
        return fs
    end
    r._date   = col(8, 84, "LEFT", "GameFontNormalSmall")
    r._lair   = col(96, 150, "LEFT")
    r._diff   = col(250, 66, "LEFT")
    r._time   = col(320, 60, "RIGHT")
    r._tries  = col(384, 40, "RIGHT")
    r._result = col(428, 96, "RIGHT")

    r:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(1, 1, 1, 0.5) end)
    r:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(0, 0, 0, 0.8) end)
    runRows[i] = r
    return r
end

local function getMemberRow(i)
    local m = memberRows[i]
    if m then return m end
    m = CreateFrame("Frame", nil, content)
    m._role = m:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    m._role:SetPoint("LEFT", m, "LEFT", 26, 0)
    m._role:SetWidth(70); m._role:SetJustifyH("LEFT")
    m._name = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    m._name:SetPoint("LEFT", m, "LEFT", 100, 0)
    m._name:SetWidth(260); m._name:SetJustifyH("LEFT")
    m._ilvl = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    m._ilvl:SetPoint("LEFT", m, "LEFT", 366, 0)
    m._ilvl:SetWidth(120); m._ilvl:SetJustifyH("LEFT")
    memberRows[i] = m
    return m
end

local function roleShort(role)
    if role == C.ROLE.TANK then return "Tank" end
    if role == C.ROLE.HEALER then return "Heal" end
    if role == C.ROLE.DAMAGER then return "DPS" end
    return "-"
end

-- --- Reconstruction complete de la liste ------------------------------------
local ROW_H, MEMBER_H, GAP = 22, 18, 3

local function rebuild()
    if not frame then return end
    RH = RH or LL.RunHistory

    local filter = {
        owner = LL.db.dashboard.filterOwner,
        diff = LL.db.dashboard.filterDiff,
        instance = LL.db.dashboard.filterInstance,
        search = searchBox and searchBox:GetText() or "",
    }
    local list = RH:Filter(filter)
    local agg = RH:Aggregate(list)

    -- En-tete de stats.
    headerFS:SetText(string.format(
        "%s: |cffffffff%d|r   %s: |cffffffff%s|r   %s: |cffffffff%d|r   %s: |cffffffff%d (%d%%)|r",
        LL.L["DASH_RUNS"], agg.count,
        LL.L["DASH_TIME"], U.FormatDuration(agg.time),
        LL.L["DASH_ATTEMPTS"], agg.attempts,
        LL.L["DASH_KILLS"], agg.kills, math.floor(agg.killRate * 100 + 0.5)))

    refreshFilterLabels()

    -- Cache tout le pool avant de replacer.
    for _, r in ipairs(runRows) do r:Hide() end
    for _, m in ipairs(memberRows) do m:Hide() end

    emptyFS:SetShown(#list == 0)

    local y = -2
    local ri, mi = 0, 0
    local rowW = content:GetWidth() - 4

    for _, run in ipairs(list) do
        ri = ri + 1
        local r = getRunRow(ri)
        r:SetSize(rowW, ROW_H)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)

        r._date:SetText(U.FormatDate(run.startTime))
        r._lair:SetText(run.instanceName or "?")
        U.SetTextColor(r._lair, C.COLOR.ACCENT)
        r._diff:SetText(run.difficulty and LL.L[DIFF_LABEL[run.difficulty]] or "?")
        r._time:SetText(U.FormatDuration(run.duration))
        r._tries:SetText(tostring(run.attempts or 0))

        if run.result == C.RUN.KILL then
            r._result:SetText(LL.L["RUN_KILL"])
            U.SetTextColor(r._result, C.COLOR[C.VERDICT.VIABLE])
        else
            r._result:SetText(LL.L["RUN_INCOMPLETE"])
            U.SetTextColor(r._result, C.COLOR.MUTED)
        end

        local capturedRun = run
        r:SetScript("OnClick", function()
            expanded[capturedRun] = not expanded[capturedRun]
            rebuild()
        end)
        r:Show()
        y = y - (ROW_H + GAP)

        -- Membres si deplie.
        if expanded[run] and type(run.group) == "table" then
            for _, member in ipairs(run.group) do
                mi = mi + 1
                local m = getMemberRow(mi)
                m:SetSize(rowW, MEMBER_H)
                m:ClearAllPoints()
                m:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
                m._role:SetText(roleShort(member.role))
                m._name:SetText(U.Colorize(member.name or "?", U.ClassColor(member.class)))
                m._ilvl:SetText(LL.L["DASH_ILVL"] .. " " ..
                    (member.ilvl and tostring(member.ilvl) or "|cff808080?|r"))
                m:Show()
                y = y - (MEMBER_H + 1)
            end
            y = y - 2
        end
    end

    local contentH = math.max(-y + 6, 10)
    content:SetHeight(contentH)
    -- Auto-hauteur centralisee dans le socle : chrome 156 (haut 116 + bas 40),
    -- plancher 320, plafond ecran-80 ; au-dela, la zone interne reste defilante.
    if frame then
        _G.TibiMidnight.FitHeight(frame, contentH, { chrome = 156, min = 320 })
    end
end

-- --- Position sauvegardee ----------------------------------------------------
local function savePoint()
    local p = { frame:GetPoint() }
    LL.db.dashboard.point = { p[1], nil, p[3], p[4], p[5] }
end
local function restorePoint()
    local p = LL.db.dashboard.point or { "CENTER", nil, "CENTER", 0, 0 }
    frame:ClearAllPoints()
    frame:SetPoint(p[1] or "CENTER", UIParent, p[3] or "CENTER", p[4] or 0, p[5] or 0)
    frame:SetScale(LL.db.dashboard.scale or 1.0)
end

-- --- Construction ------------------------------------------------------------
local function build()
    RH = LL.RunHistory
    frame = CreateFrame("Frame", "LairLensDashboardFrame", UIParent, "BackdropTemplate")
    frame:SetSize(576, 440)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop(flatBackdrop(1))
    frame:SetBackdropColor(0.05, 0.06, 0.08, 0.97)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePoint() end)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("|cffffffffLairLens|r  " .. LL.L["DASH_TITLE"])

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() frame:Hide() end)

    -- Ligne de filtres.
    ownerBtn = makeButton(frame, 150, 22)
    ownerBtn:SetPoint("TOPLEFT", 14, -44)
    ownerBtn:SetScript("OnClick", function()
        local owners = { false }
        for _, o in ipairs(RH:GetOwners()) do owners[#owners + 1] = o end
        LL.db.dashboard.filterOwner = cycle(owners, LL.db.dashboard.filterOwner)
        rebuild()
    end)

    diffBtn = makeButton(frame, 150, 22)
    diffBtn:SetPoint("LEFT", ownerBtn, "RIGHT", 6, 0)
    diffBtn:SetScript("OnClick", function()
        LL.db.dashboard.filterDiff = cycle(DIFF_CYCLE, LL.db.dashboard.filterDiff)
        rebuild()
    end)

    instBtn = makeButton(frame, 150, 22)
    instBtn:SetPoint("LEFT", diffBtn, "RIGHT", 6, 0)
    instBtn:SetScript("OnClick", function()
        local insts = { false }
        for _, it in ipairs(RH:GetInstances()) do insts[#insts + 1] = it.key end
        LL.db.dashboard.filterInstance = cycle(insts, LL.db.dashboard.filterInstance)
        rebuild()
    end)

    -- Recherche.
    searchBox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    searchBox:SetSize(150, 22)
    searchBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -44)
    searchBox:SetBackdrop(flatBackdrop(1))
    searchBox:SetBackdropColor(0.02, 0.02, 0.03, 0.95)
    searchBox:SetBackdropBorderColor(0, 0, 0, 1)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("GameFontHighlightSmall")
    searchBox:SetTextInsets(6, 6, 0, 0)
    local ph = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 6, 0)
    ph:SetText(LL.L["DASH_SEARCH"])
    searchBox:SetScript("OnTextChanged", function(s) ph:SetShown(s:GetText() == ""); rebuild() end)
    searchBox:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)

    -- En-tete de stats.
    headerFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerFS:SetPoint("TOPLEFT", 16, -74)
    headerFS:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    headerFS:SetJustifyH("LEFT")

    -- Separateur.
    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1, 1, 1, 0.10)
    sep:SetPoint("TOPLEFT", 12, -92)
    sep:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    sep:SetHeight(1)

    -- En-tetes de colonnes, alignes sur les colonnes des lignes de run.
    -- Les lignes sont ancrees dans le contenu (scroll a 12px du cadre, +2px) :
    -- un decalage X de colonne tombe donc a ~14+X cote cadre.
    local function colHeader(x, w, justify, key)
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + x, -98)
        fs:SetWidth(w); fs:SetJustifyH(justify or "LEFT")
        fs:SetText(LL.L[key])
        return fs
    end
    colHeader(8, 84, "LEFT", "DASH_COL_DATE")
    colHeader(96, 150, "LEFT", "DASH_COL_LAIR")
    colHeader(250, 66, "LEFT", "DASH_COL_DIFF")
    colHeader(320, 60, "RIGHT", "DASH_COL_TIME")
    colHeader(384, 40, "RIGHT", "DASH_COL_TRIES")
    colHeader(428, 96, "RIGHT", "DASH_COL_RESULT")

    -- Zone scrollable.
    local scroll = CreateFrame("ScrollFrame", "LairLensDashScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -116)
    scroll:SetPoint("BOTTOMRIGHT", -30, 40)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)
    content:SetWidth(530)

    emptyFS = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyFS:SetPoint("TOPLEFT", 6, -8)
    emptyFS:SetText(LL.L["DASH_EMPTY"])

    -- Bouton "vider l'historique" (double clic de confirmation).
    local clearBtn = makeButton(frame, 160, 22)
    clearBtn:SetPoint("BOTTOMLEFT", 14, 12)
    clearBtn._label:SetJustifyH("CENTER")
    clearBtn._label:SetText(U.Colorize(LL.L["DASH_CLEAR"], C.COLOR.MUTED))
    clearBtn:SetScript("OnClick", function(self)
        local now = GetTime and GetTime() or time()
        if confirmClear > 0 and (now - confirmClear) < 4 then
            confirmClear = 0
            self._label:SetText(U.Colorize(LL.L["DASH_CLEAR"], C.COLOR.MUTED))
            RH:Clear()
        else
            confirmClear = now
            self._label:SetText(U.Colorize(LL.L["DASH_CLEAR_CONFIRM"], C.COLOR[C.VERDICT.MISSING]))
            C_Timer.After(4, function()
                if self and self._label then
                    self._label:SetText(U.Colorize(LL.L["DASH_CLEAR"], C.COLOR.MUTED))
                end
            end)
        end
    end)

    restorePoint()
    rebuild()
end

-- --- API publique ------------------------------------------------------------
function Dash:Open()
    if not frame then build() end
    rebuild()
    frame:Show()
end
function Dash:Close()
    if frame then frame:Hide() end
end
function Dash:Toggle()
    if frame and frame:IsShown() then frame:Hide() else self:Open() end
end
function Dash:IsShown()
    return frame and frame:IsShown()
end

-- --- Cablage -----------------------------------------------------------------
local function wire()
    -- On construit paresseusement a la premiere ouverture (economie memoire),
    -- mais on ecoute deja les changements pour rafraichir si la fenetre est ouverte.
    LL:On("HISTORY_CHANGED", function()
        if frame and frame:IsShown() then rebuild() end
    end)
end

LL:On("DB_READY", wire)
