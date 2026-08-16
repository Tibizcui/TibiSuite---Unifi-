local addonName, ns = ...
local L = ns.L
local C = ns.Const

local UI = {}
ns.UI = UI

-- ===========================================================================
-- Vue compte. Chaque personnage connu est une LIGNE (nom en couleur de classe),
-- chaque activite suivie est une COLONNE. Orientation choisie a dessein : le
-- nombre d'activites est petit et fixe, le nombre de rerolls grandit ; empiler
-- les persos en lignes se lit d'un coup d'oeil et defile verticalement sans
-- jamais deborder en largeur.
--
-- La largeur est CALCULEE sur le contenu reel (mesure de chaque colonne,
-- en-tete comprise), donc aucun chevauchement. Au-dela d'un certain nombre de
-- persos, le corps du tableau defile dans un ScrollFrame tandis que la ligne
-- d'en-tetes reste fixe.
-- ===========================================================================

local frame
local scrollFrame, scrollChild
local track, thumb
local header      = {}   -- pool d'en-tetes de colonnes (zone fixe)
local rowPool     = {}   -- pool de lignes (dans le scrollChild) ; [r] = { name, cells }
local nameHeader         -- en-tete de la colonne des noms (zone fixe)

local PAD_X    = 16
local PAD_TOP  = 58      -- reserve titre + sous-titre
local HEADER_H = 20
local ROW_H    = 20
local GUTTER   = 18
local BOTTOM   = 14
local MIN_W    = 260
local MAX_ROWS = 16      -- au-dela, on defile
local SB_W     = 8       -- largeur de la barre de defilement
local SB_GAP   = 6       -- espace entre le contenu et la barre
local WHEEL_STEP = ROW_H * 3

-- Etat de defilement, partage entre le rendu et le glisser de la barre.
local scrollOffset = 0
local vpH, contentH, maxScroll, thumbH, trackX = 0, 0, 0, 0, 0

local function classRGB(token)
    local t = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if t then return t.r, t.g, t.b end
    return 0.90, 0.90, 0.92
end

local function statusRGB(status)
    local c = C.StatusColor[status] or C.StatusColor[C.Status.UNKNOWN]
    return c[1], c[2], c[3]
end

-- {r, g, b} sur 0..1 -> code couleur inline "ffRRGGBB" pour |c...|r.
local function colorCode(c)
    local function b(v) return math.floor((v or 1) * 255 + 0.5) end
    return ("ff%02x%02x%02x"):format(b(c[1]), b(c[2]), b(c[3]))
end

-- Contenu compact d'une cellule. Le niveau d'objet obtenu (le plus haut deja
-- debloque) est colle apres la progression, comme demande.
local function cellText(e)
    if not e then return "-" end
    if e.status == C.Status.UNKNOWN then return "?" end

    local txt
    if e.progress and e.progress.max and e.progress.max > 0 then
        txt = ("%d/%d"):format(e.progress.current or 0, e.progress.max)
    elseif e.status == C.Status.DONE then
        txt = L["STATUS_DONE"]
    elseif e.status == C.Status.NOT_STARTED then
        txt = L["STATUS_NOT_STARTED"]
    else
        txt = "-"
    end

    if e.reward and e.reward.ilvl and e.reward.ilvl > 0 then
        local ilvlStr = tostring(e.reward.ilvl)
        -- Coloration par palier absolu (piste d'amelioration). Le code inline
        -- |c...|r n'habille QUE l'ilevel : la progression garde sa couleur de
        -- statut. Sans palier connu, on laisse l'ilevel dans la couleur du statut.
        local c = e.reward.ilvlColor
        if c then
            ilvlStr = "|c" .. colorCode(c) .. ilvlStr .. "|r"
        end
        txt = txt .. "  " .. ilvlStr
    end
    return txt
end

local function makeFS(parent, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template)
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
end

-- Repositionne le curseur de la barre en fonction de l'offset courant.
local function updateThumb()
    if not thumb then return end
    if maxScroll <= 0 then
        track:Hide()
        thumb:Hide()
        return
    end
    track:Show()
    thumb:Show()
    local trackTop = PAD_TOP + HEADER_H
    local travel = vpH - thumbH
    local y = trackTop + (travel > 0 and (scrollOffset / maxScroll) * travel or 0)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPLEFT", frame, "TOPLEFT", trackX, -y)
    thumb:SetSize(SB_W, thumbH)
end

-- Applique un offset (clampe) au corps du tableau.
function UI:_SetScroll(offset)
    if offset < 0 then offset = 0 end
    if offset > maxScroll then offset = maxScroll end
    scrollOffset = offset
    if scrollFrame then scrollFrame:SetVerticalScroll(offset) end
    updateThumb()
end

local function buildFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "WeeklyCompassFrame", UIParent, "BackdropTemplate")
    frame:SetSize(MIN_W, 160)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        frame:SetBackdropColor(0.06, 0.07, 0.09, 0.96)
        frame:SetBackdropBorderColor(0, 0, 0, 1)
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("WeeklyCompass")
    title:SetTextColor(0.039, 1.000, 0.745)  -- turquoise (accent WeeklyCompass)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetText(L["UI_SUBTITLE"])

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    -- Zone fixe : en-tete des noms + trait de separation.
    nameHeader = makeFS(frame, "GameFontNormalSmall")

    frame.headerLine = frame:CreateTexture(nil, "ARTWORK")
    frame.headerLine:SetColorTexture(1, 1, 1, 0.12)
    frame.headerLine:Hide()

    -- Corps defilant.
    scrollFrame = CreateFrame("ScrollFrame", "WeeklyCompassScroll", frame)
    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        UI:_SetScroll(scrollOffset - (delta or 0) * WHEEL_STEP)
    end)

    -- Barre de defilement : piste + curseur attrapable.
    track = frame:CreateTexture(nil, "ARTWORK")
    track:SetColorTexture(1, 1, 1, 0.07)
    track:Hide()

    thumb = CreateFrame("Frame", nil, frame)
    thumb:EnableMouse(true)
    local ttex = thumb:CreateTexture(nil, "OVERLAY")
    ttex:SetAllPoints(thumb)
    ttex:SetColorTexture(0.85, 0.85, 0.90, 0.35)
    thumb:Hide()
    thumb:SetScript("OnMouseDown", function(self)
        self.dragging = true
        local _, cy = GetCursorPosition()
        self.startCursor = cy
        self.startOffset = scrollOffset
    end)
    thumb:SetScript("OnMouseUp", function(self) self.dragging = false end)
    thumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local travel = vpH - thumbH
        if travel <= 0 or maxScroll <= 0 then return end
        local scale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local _, cy = GetCursorPosition()
        local movedPixels = (self.startCursor - cy) / scale   -- vers le bas => positif
        UI:_SetScroll(self.startOffset + movedPixels * (maxScroll / travel))
    end)

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.empty:SetPoint("TOPLEFT", PAD_X, -PAD_TOP)
    frame.empty:SetJustifyH("LEFT")
    if frame.empty.SetWordWrap then frame.empty:SetWordWrap(true) end
    frame.empty:Hide()

    return frame
end

local function getHeader(c)
    local fs = header[c]
    if not fs then
        fs = makeFS(frame, "GameFontNormalSmall")
        header[c] = fs
    end
    return fs
end

local function getRow(r)
    local row = rowPool[r]
    if not row then
        row = { name = makeFS(scrollChild, "GameFontNormal"), cells = {} }
        rowPool[r] = row
    end
    return row
end

local function getCell(row, c)
    local fs = row.cells[c]
    if not fs then
        fs = makeFS(scrollChild, "GameFontHighlightSmall")
        row.cells[c] = fs
    end
    return fs
end

local function hideEverything()
    nameHeader:Hide()
    frame.headerLine:Hide()
    if track then track:Hide() end
    if thumb then thumb:Hide() end
    for _, fs in ipairs(header) do fs:Hide() end
    for _, row in ipairs(rowPool) do
        row.name:Hide()
        for _, cell in ipairs(row.cells) do cell:Hide() end
    end
end

function UI:Refresh()
    if not frame or not frame:IsShown() then return end

    local roster = ns.Journal:GetRoster()

    -- 1. Colonnes = union ordonnee des cles d'entrees sur tous les persos.
    local cols = {}
    local colByKey = {}
    for _, ch in ipairs(roster) do
        for _, e in ipairs(ch.entries) do
            if not colByKey[e.key] then
                local rec = {
                    key      = e.key,
                    headerTx = e.short or e.label or e.key,
                    category = e.category,
                    order    = e.order or 100,
                }
                cols[#cols + 1] = rec
                colByKey[e.key] = rec
            end
        end
    end
    table.sort(cols, function(a, b)
        local ca = C.CategoryOrder[a.category] or 100
        local cb = C.CategoryOrder[b.category] or 100
        if ca ~= cb then return ca < cb end
        if a.order ~= b.order then return a.order < b.order end
        return (a.headerTx or "") < (b.headerTx or "")
    end)

    if #roster == 0 or #cols == 0 then
        hideEverything()
        frame.empty:SetText(L["UI_EMPTY"])
        frame.empty:SetWidth(300)
        frame.empty:Show()
        frame:SetSize(340, 150)
        return
    end
    frame.empty:Hide()

    -- 2. Mesure (avant toute contrainte de largeur).
    local colW = {}
    for c, rec in ipairs(cols) do
        local fs = getHeader(c)
        fs:SetText(rec.headerTx)
        colW[c] = fs:GetStringWidth() or 0
    end

    nameHeader:SetText(L["UI_HEADER_CHAR"])
    local nameW = nameHeader:GetStringWidth() or 0

    for r, ch in ipairs(roster) do
        local row = getRow(r)
        row.name:SetText(ch.name or "?")
        local w = row.name:GetStringWidth() or 0
        if w > nameW then nameW = w end

        local byKey = {}
        for _, e in ipairs(ch.entries) do byKey[e.key] = e end
        row._byKey = byKey

        for c, rec in ipairs(cols) do
            local cell = getCell(row, c)
            cell:SetText(cellText(byKey[rec.key]))
            local cw = cell:GetStringWidth() or 0
            if cw > colW[c] then colW[c] = cw end
        end
    end

    -- 3. Offsets horizontaux cumules (relatifs au bloc de contenu).
    local colX = {}
    local cursor = nameW + GUTTER
    for c = 1, #cols do
        colX[c] = cursor
        cursor = cursor + colW[c] + GUTTER
    end
    local gridW = cursor - GUTTER

    -- 4. En-tetes (zone fixe).
    nameHeader:ClearAllPoints()
    nameHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, -PAD_TOP)
    nameHeader:Show()

    for c = 1, #cols do
        local fs = getHeader(c)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X + colX[c], -PAD_TOP)
        fs:SetWidth(colW[c] + 4)
        fs:Show()
    end
    for c = #cols + 1, #header do header[c]:Hide() end

    frame.headerLine:ClearAllPoints()
    frame.headerLine:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, -(PAD_TOP + HEADER_H - 4))
    frame.headerLine:SetSize(gridW, 1)
    frame.headerLine:Show()

    -- 5. Dimensions du corps defilant.
    -- Auto-hauteur uniforme : la fenetre grandit pour montrer toutes les lignes
    -- jusqu'a la hauteur de l'ecran (regle commune : ecran - 80) ; au-dela, la
    -- barre de defilement prend le relais. Remplace l'ancien plafond fixe.
    local nRows   = #roster
    local screenH = (UIParent and UIParent:GetHeight()) or 800
    local maxRows = math.max(1, math.floor(((screenH - 80) - (PAD_TOP + HEADER_H + BOTTOM)) / ROW_H))
    local visible = math.min(nRows, maxRows)
    vpH       = visible * ROW_H
    contentH  = nRows * ROW_H
    maxScroll = math.max(0, contentH - vpH)
    local needScroll = maxScroll > 0.5

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, -(PAD_TOP + HEADER_H))
    scrollFrame:SetSize(gridW, vpH)
    scrollChild:SetSize(gridW, math.max(contentH, vpH))

    -- 6. Lignes (dans le scrollChild, positionnees depuis SON coin haut-gauche).
    for r, ch in ipairs(roster) do
        local row = rowPool[r]
        local yy = (r - 1) * ROW_H
        local alpha = ch.stale and 0.45 or 1

        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yy)
        row.name:SetWidth(nameW + 4)
        local cr, cg, cb = classRGB(ch.class)
        row.name:SetTextColor(cr, cg, cb, alpha)
        row.name:Show()

        for c = 1, #cols do
            local cell = getCell(row, c)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", colX[c], -yy)
            cell:SetWidth(colW[c] + 4)
            local e = row._byKey[cols[c].key]
            local sr, sg, sb
            if e then sr, sg, sb = statusRGB(e.status) else sr, sg, sb = 0.40, 0.40, 0.42 end
            cell:SetTextColor(sr, sg, sb, alpha)
            cell:Show()
        end
        for c = #cols + 1, #row.cells do row.cells[c]:Hide() end
    end
    for r = nRows + 1, #rowPool do
        local row = rowPool[r]
        row.name:Hide()
        for _, cell in ipairs(row.cells) do cell:Hide() end
    end

    -- 7. Barre de defilement + largeur reservee si besoin.
    trackX = PAD_X + gridW + SB_GAP
    local rightPad = PAD_X
    if needScroll then
        rightPad = SB_GAP + SB_W + PAD_X
        thumbH = math.max(20, vpH * (vpH / contentH))
        track:ClearAllPoints()
        track:SetPoint("TOPLEFT", frame, "TOPLEFT", trackX, -(PAD_TOP + HEADER_H))
        track:SetSize(SB_W, vpH)
    else
        thumbH = 0
    end

    -- 8. Taille finale + clamp de l'offset courant.
    local w = PAD_X + gridW + rightPad
    if w < MIN_W then w = MIN_W end
    frame:SetSize(w, PAD_TOP + HEADER_H + vpH + BOTTOM)
    UI:_SetScroll(scrollOffset)   -- reclampe et repositionne piste/curseur
end

function UI:Toggle()
    buildFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        ns.Registry:RefreshAll()
        frame:Show()
        self:Refresh()
    end
end

ns:OnMessage("WC_JOURNAL_UPDATED", function()
    UI:Refresh()
end)

-- ---------------------------------------------------------------------------
-- Point d'entree global pour TibiSuite (barre d'onglets unifiee).
-- TibiSuite appelle _G["WeeklyCompass_Toggle"] ; on relaie vers UI:Toggle.
-- ---------------------------------------------------------------------------
function WeeklyCompass_Toggle()
    UI:Toggle()
end

-- ---------------------------------------------------------------------------
-- Slash commands.
--   /wc          ouvre / ferme le tableau de bord (vue compte)
--   /wc dump     imprime le journal du perso courant dans le chat
--   /wc debug    active / desactive les logs de debug
-- ---------------------------------------------------------------------------
SLASH_WEEKLYCOMPASS1 = "/wc"
SLASH_WEEKLYCOMPASS2 = "/weeklycompass"
SlashCmdList["WEEKLYCOMPASS"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "dump" then
        local entries = ns.Journal:GetEntries()
        print(("|cff8db4e2WeeklyCompass|r %d entree(s) :"):format(#entries))
        for _, e in ipairs(entries) do
            local p = ""
            if e.progress and e.progress.max and e.progress.max > 0 then
                p = (" (%d/%d)"):format(e.progress.current or 0, e.progress.max)
            end
            local r = ""
            if e.reward and e.reward.text then r = "  " .. e.reward.text end
            print(("  - %s [%s]%s%s"):format(e.label or e.key, e.status, p, r))
        end

    elseif msg == "debug" then
        local g = ns.DB:GetGlobal()
        if g then
            g.debug = not g.debug
            print("|cff8db4e2WeeklyCompass|r debug = " .. tostring(g.debug))
        end

    elseif msg == "minimap" then
        local shown = ns.ToggleMinimap and ns:ToggleMinimap()
        print(("|cff8db4e2WeeklyCompass|r minimap = %s"):format(shown and "on" or "off"))

    elseif msg == "" or msg == "show" then
        UI:Toggle()

    else
        print("|cff8db4e2WeeklyCompass|r " .. L["SLASH_HINT"])
    end
end
