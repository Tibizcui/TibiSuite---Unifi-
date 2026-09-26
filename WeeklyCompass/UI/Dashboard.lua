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
-- Deux onglets partagent ce meme tableau :
--   "week"  : Cette semaine (Grand Coffre, Gouffres, Traque), vide au reset ;
--   "chars" : Personnages (niveau, specialisation, niveau d'objet, or, cle,
--             verrouillages), fiche persistante, avec une ligne de total.
-- Clic gauche sur un en-tete : tri. Clic droit : masquer la colonne.
--
-- La largeur est CALCULEE sur le contenu reel (mesure de chaque colonne,
-- en-tete comprise), donc aucun chevauchement. Au-dela d'un certain nombre de
-- persos, le corps du tableau defile dans un ScrollFrame tandis que la ligne
-- d'en-tetes reste fixe.
-- ===========================================================================

local frame
local scrollFrame, scrollChild
local track, thumb
local header      = {}   -- pool d'en-tetes de colonnes (zone fixe) ; [c] = FontString
local headerHits  = {}   -- zones cliquables des en-tetes ; [c] = Button
local rowPool     = {}   -- pool de lignes (dans le scrollChild) ; [r] = { name, cells, hits }
local nameHeader         -- en-tete de la colonne des noms (zone fixe)
local nameHeaderHit

local ACCENT   = { 0.039, 1.000, 0.745 }   -- turquoise (accent WeeklyCompass)
local PAD_X    = 16
local TABS_Y   = 50      -- haut de la rangee d'onglets
local PAD_TOP  = 74      -- reserve titre + sous-titre + onglets
local HEADER_H = 20
local ROW_H    = 20
local GUTTER   = 18
local BOTTOM   = 14
local MIN_W    = 300
local SB_W     = 8       -- largeur de la barre de defilement
local SB_GAP   = 6       -- espace entre le contenu et la barre
local WHEEL_STEP = ROW_H * 3

local TABS = {
    { key = "week",  labelKey = "TAB_WEEK",  subKey = "UI_SUBTITLE" },
    { key = "chars", labelKey = "TAB_CHARS", subKey = "UI_SUBTITLE_CHARS" },
}

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

local function global() return ns.DB:GetGlobal() or {} end

local function currentTab()
    return global().tab == "chars" and "chars" or "week"
end

-- Onglet d'une entree : les entrees de la fiche portent tab = "chars".
local function entryTab(e)
    return e.tab == "chars" and "chars" or "week"
end

-- Texte de detail d'une entree. Une entree est stockee avec son texte deja
-- traduit : un reroll pas reconnecte garderait l'ancien texte (ex. "A recuperer"
-- sans accent, ou la langue d'avant). detailKey le retraduit a l'affichage ;
-- la recompense du Coffre stockee avant la 7.1.5.20 n'a pas de detailKey,
-- d'ou le repli sur sa cle d'entree.
local function detailText(e)
    local key = e.detailKey
    if not key and e.key == "greatVault:claim" and not e.inferred then key = "VAULT_CLAIM_CELL" end
    if key then return L[key] end
    return e.detail
end

-- Meme principe pour l'en-tete de colonne (libelle court).
local function shortText(e)
    local key = e.shortKey
    if not key and e.key == "greatVault:claim" then key = "VAULT_CLAIM_SHORT" end
    if key then return L[key] end
    return e.short or e.label or e.key
end

-- Contenu compact d'une cellule. Le niveau d'objet obtenu (le plus haut deja
-- debloque) est colle apres la progression, comme demande.
local function cellText(e)
    if not e then return "-" end
    if e.status == C.Status.UNKNOWN then return "?" end

    -- Or : formate a l'affichage avec l'icone de piece (e.money, ou la somme
    -- d'une case d'or deja stockee), meme pour une fiche ancienne.
    local money = e.money or (e.sumFormat == "money" and e.sum)
    if tonumber(money) then return ns.FormatGold(money, true) end

    local txt
    if e.progress and e.progress.max and e.progress.max > 0 then
        txt = ("%d/%d"):format(e.progress.current or 0, e.progress.max)
        -- Renom (Gouffres, Traque) : le rang colle a la progression. Une entree
        -- stockee avant la 7.1.5.21 n'a pas de champ rank : on le relit dans
        -- son detail ("Rang 3"), seul texte chiffre d'une case a compteur.
        local rank = tonumber(e.rank) or (type(e.detail) == "string" and tonumber(e.detail:match("(%d+)")))
        if rank then txt = txt .. " " .. L["RANK_SUFFIX"]:format(rank) end
    elseif detailText(e) then
        -- Case sans compteur mais avec un texte court (ex. "A recuperer").
        txt = tostring(detailText(e))
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

-- ---------------------------------------------------------------------------
-- Infobulles et menus. Les cases sont des FontStrings (non cliquables) : chacune
-- recoit une zone de survol invisible calee dessus (SetAllPoints).
-- ---------------------------------------------------------------------------
local STATUS_KEY = {
    [C.Status.DONE]        = "STATUS_DONE",
    [C.Status.IN_PROGRESS] = "STATUS_IN_PROGRESS",
    [C.Status.NOT_STARTED] = "STATUS_NOT_STARTED",
    [C.Status.UNKNOWN]     = "STATUS_UNKNOWN",
}

local function fmtTime(ts)
    return (type(ts) == "number" and ts > 0) and date("%d/%m %H:%M", ts) or "?"
end

-- Une zone survolee hors de la partie visible du tableau defilant ne doit
-- pas ouvrir d'infobulle.
local function visibleHover()
    return not scrollFrame or scrollFrame:IsMouseOver()
end

-- Infobulle PROPRE a WeeklyCompass (et non GameTooltip, partage par tout le
-- jeu) : on peut y changer la police ligne par ligne (gras, petit) sans
-- toucher aux lignes de l'infobulle de Blizzard, donc sans risque de taint.
-- Chaque ligne recoit explicitement sa police a chaque affichage, car les
-- lignes d'une infobulle sont reutilisees d'un affichage a l'autre.
local tip
local FONTS = {}

local function buildFonts()
    if FONTS.normal then return end
    FONTS.normal = GameTooltipText
    FONTS.small  = GameTooltipTextSmall or GameTooltipText
    FONTS.title  = GameTooltipHeaderText or GameTooltipText
    -- "Gras" : la police des titres d'infobulle, a la taille du texte courant.
    local bold = CreateFont and CreateFont("WeeklyCompassTipBold")
    if bold and GameTooltipHeaderText and GameTooltipText then
        bold:CopyFontObject(GameTooltipHeaderText)
        local path = GameTooltipHeaderText:GetFont()
        local _, size = GameTooltipText:GetFont()
        if path and size then bold:SetFont(path, size + 1, "") end
        FONTS.bold = bold
    else
        FONTS.bold = FONTS.title
    end
end

local function getTip()
    if not tip then
        tip = CreateFrame("GameTooltip", "WeeklyCompassTooltip", UIParent, "GameTooltipTemplate")
        buildFonts()
    end
    return tip
end

-- Applique une police aux deux cotes de la derniere ligne ajoutee.
local function styleLast(fontKey)
    local n = tip:NumLines()
    local font = FONTS[fontKey or "normal"] or FONTS.normal
    for _, side in ipairs({ "Left", "Right" }) do
        local fs = _G["WeeklyCompassTooltipText" .. side .. n]
        if fs and font then fs:SetFontObject(font) end
    end
end

-- Une ligne : texte simple (gris clair), ou table
-- { text, right, color = {r,g,b}, rcolor = {r,g,b}, font = "bold"|"small"|"title" }.
local function addLine(line, r, g, b, wrap)
    if type(line) == "table" then
        local c = line.color or { 0.85, 0.85, 0.85 }
        if line.right then
            local rc = line.rcolor or c
            tip:AddDoubleLine(line.text or "", line.right, c[1], c[2], c[3], rc[1], rc[2], rc[3])
        else
            tip:AddLine(line.text or "", c[1], c[2], c[3], line.wrap)
        end
        styleLast(line.font)
    else
        tip:AddLine(tostring(line), r or 0.85, g or 0.85, b or 0.85, wrap)
        styleLast("normal")
    end
end

local function openTip(owner, anchor)
    getTip()
    tip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    tip:ClearLines()
end

local function hideTip()
    if tip then tip:Hide() end
end

local function showEntryTip(owner)
    local e = owner.entry
    if not (e and visibleHover()) then return end
    openTip(owner)
    addLine({ text = e.label or e.key, color = { 1, 1, 1 }, font = "title" })
    -- Une valeur neutre (or, niveau...) n'a pas de statut "fait / a faire".
    if e.status ~= C.Status.INFO then
        local sr, sg, sb = statusRGB(e.status)
        local st = L[STATUS_KEY[e.status] or "STATUS_UNKNOWN"]
        if e.progress and e.progress.max and e.progress.max > 0 then
            st = ("%s  %d/%d"):format(st, e.progress.current or 0, e.progress.max)
        end
        addLine({ text = st, color = { sr, sg, sb }, font = "bold" })
    end
    local detail = detailText(e)
    if detail and not e.hideDetailInTip then addLine(tostring(detail), 0.85, 0.85, 0.85, true) end
    if e.reward and e.reward.text then addLine(e.reward.text) end
    if type(e.lines) == "table" then
        for _, line in ipairs(e.lines) do addLine(line, 0.80, 0.80, 0.80, true) end
    end
    if owner.stale then addLine(L["UI_STALE"], 0.55, 0.55, 0.58, true) end
    if not e.inferred and e.updatedAt then
        addLine({ text = L["TIP_UPDATED"]:format(fmtTime(e.updatedAt)), color = { 0.55, 0.55, 0.58 }, font = "small" })
    end
    tip:Show()
end

local function showCharTip(owner)
    local ch = owner.ch
    if not (ch and visibleHover()) then return end
    openTip(owner)
    local cr, cg, cb = classRGB(ch.class)
    addLine({ text = ("%s - %s"):format(ch.name or "?", ch.realm or "?"), color = { cr, cg, cb }, font = "title" })
    addLine(L["TIP_LAST_SEEN"]:format(fmtTime(ch.lastSeen)), 0.80, 0.80, 0.80)
    if ch.stale and currentTab() == "week" then addLine(L["UI_STALE"], 0.55, 0.55, 0.58, true) end
    if ch.hidden then addLine(L["UI_HIDDEN_TAG"], 0.55, 0.55, 0.58) end
    addLine({ text = L["TIP_RIGHT_CLICK"], color = { 0.55, 0.55, 0.58 }, font = "small" })
    tip:Show()
end

local function hasMenu()
    return MenuUtil and MenuUtil.CreateContextMenu
end

-- Menu clic droit sur un nom : masquer / reafficher, oublier.
local function openCharMenu(owner)
    local ch = owner.ch
    if not ch then return end
    hideTip()
    local function toggleHidden()
        ns.DB:SetHidden(ch.key, not ch.hidden)
        UI:Refresh()
    end
    if not hasMenu() then
        -- Repli si le menu moderne manque : bascule directe du masquage.
        toggleHidden()
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(("%s - %s"):format(ch.name or "?", ch.realm or "?"))
        root:CreateButton(ch.hidden and L["MENU_UNHIDE"] or L["MENU_HIDE"], toggleHidden)
        if ch.key ~= ns.charKey() then
            root:CreateButton(L["MENU_FORGET"], function()
                ns.DB:ForgetChar(ch.key)
                UI:Refresh()
            end)
        end
    end)
end

-- Tri : clic sur l'en-tete deja trie = inverse l'ordre. Une colonne chiffree
-- commence par le plus grand (le meilleur niveau d'objet en haut), les noms
-- par ordre alphabetique.
local function toggleSort(colKey)
    local g = global()
    if not g.sort then return end
    local tab = currentTab()
    local s = g.sort[tab]
    if s and s.key == colKey then
        s.desc = not s.desc
    else
        g.sort[tab] = { key = colKey, desc = colKey ~= "name" }
    end
    UI:Refresh()
end

-- Menu clic droit sur un en-tete : masquer la colonne, tout reafficher.
local function openColMenu(owner)
    local tab = currentTab()
    local nHiddenCols = ns.DB:CountHiddenCols(tab)
    hideTip()
    if not hasMenu() then
        if owner.colKey then
            ns.DB:SetColHidden(tab, owner.colKey, true)
        else
            ns.DB:UnhideAllCols(tab)
        end
        UI:Refresh()
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(owner.title or "")
        if owner.colKey then
            root:CreateButton(L["MENU_HIDE_COL"], function()
                ns.DB:SetColHidden(tab, owner.colKey, true)
                UI:Refresh()
            end)
        end
        if nHiddenCols > 0 then
            root:CreateButton(L["MENU_SHOW_COLS"]:format(nHiddenCols), function()
                ns.DB:UnhideAllCols(tab)
                UI:Refresh()
            end)
        end
    end)
end

local function makeHit(fs)
    local h = CreateFrame("Frame", nil, scrollChild)
    h:SetAllPoints(fs)
    h:EnableMouse(true)
    h:SetScript("OnEnter", showEntryTip)
    h:SetScript("OnLeave", hideTip)
    h:Hide()
    return h
end

local function makeNameHit(fs)
    local h = CreateFrame("Button", nil, scrollChild)
    h:SetAllPoints(fs)
    h:RegisterForClicks("RightButtonUp")
    h:SetScript("OnClick", openCharMenu)
    h:SetScript("OnEnter", showCharTip)
    h:SetScript("OnLeave", hideTip)
    h:Hide()
    return h
end

local function showHeaderTip(owner)
    openTip(owner, "ANCHOR_TOP")
    addLine({ text = owner.title or "", color = { 1, 1, 1 }, font = "bold" })
    addLine({ text = L["TIP_HEADER"], color = { 0.80, 0.80, 0.80 }, font = "small", wrap = true })
    tip:Show()
end

-- En-tete cliquable (colonne ou noms). colKey nil = en-tete des noms.
local function makeHeaderHit(fs)
    local h = CreateFrame("Button", nil, frame)
    h:SetAllPoints(fs)
    h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    h:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            openColMenu(self)
        else
            toggleSort(self.colKey or "name")
        end
    end)
    h:SetScript("OnEnter", showHeaderTip)
    h:SetScript("OnLeave", hideTip)
    return h
end

-- Nom affiche : royaume en gris seulement pour les homonymes, mention des masques.
local function nameText(ch)
    local t = ch.name or "?"
    if ch.dup and ch.realm then t = t .. " |cff8a8a8a- " .. ch.realm .. "|r" end
    if ch.hidden then t = t .. " |cff8a8a8a" .. L["UI_HIDDEN_TAG"] .. "|r" end
    return t
end

-- Indicateur de tri colle a l'en-tete (caracteres ASCII : la police du jeu
-- n'a pas toujours les fleches Unicode).
local function sortMark(tab, colKey)
    local s = global().sort and global().sort[tab]
    if not s or s.key ~= colKey then return "" end
    return s.desc and " v" or " ^"
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

local function buildTabs()
    frame.tabs = {}
    local x = PAD_X
    for i, t in ipairs(TABS) do
        local b = CreateFrame("Button", nil, frame)
        b.key = t.key
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.fs:SetPoint("TOPLEFT", 0, 0)
        b.fs:SetText(L[t.labelKey])
        local w = (b.fs:GetStringWidth() or 60) + 2
        b:SetSize(w, 18)
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -TABS_Y)
        b.line = b:CreateTexture(nil, "ARTWORK")
        b.line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
        b.line:SetPoint("BOTTOMLEFT", 0, 0)
        b.line:SetPoint("BOTTOMRIGHT", 0, 0)
        b.line:SetHeight(2)
        b:SetScript("OnClick", function(self)
            local g = ns.DB:GetGlobal()
            if g then g.tab = self.key end
            scrollOffset = 0
            hideTip()
            UI:Refresh()
        end)
        frame.tabs[i] = b
        x = x + w + 18
    end
    frame.tabsW = x - 18 - PAD_X
end

local function paintTabs(tab)
    for _, b in ipairs(frame.tabs) do
        if b.key == tab then
            b.fs:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
            b.line:Show()
        else
            b.fs:SetTextColor(0.60, 0.60, 0.63)
            b.line:Hide()
        end
    end
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

    -- Fermeture par Echap via UISpecialFrames (mecanisme natif Blizzard) :
    -- voir note detaillee dans TibiSuiteCore.lua (WireEscapeFor) - piege reel
    -- confirme en jeu quand un autre addon intercepte lui aussi Echap.
    tinsert(UISpecialFrames, "WeeklyCompassFrame")

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
    title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    frame.subtitle:SetText(L["UI_SUBTITLE"])

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    buildTabs()

    -- Zone fixe : en-tete des noms + trait de separation.
    nameHeader = makeFS(frame, "GameFontNormalSmall")
    nameHeaderHit = makeHeaderHit(nameHeader)

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

    -- Trait au-dessus de la ligne de total (onglet Personnages).
    frame.totalLine = scrollChild:CreateTexture(nil, "ARTWORK")
    frame.totalLine:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.55)
    frame.totalLine:Hide()
    frame.totalBand = scrollChild:CreateTexture(nil, "BACKGROUND")
    frame.totalBand:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.08)
    frame.totalBand:Hide()

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
        headerHits[c] = makeHeaderHit(fs)
    end
    return fs
end

local function getRow(r)
    local row = rowPool[r]
    if not row then
        row = { name = makeFS(scrollChild, "GameFontNormal"), cells = {}, hits = {} }
        row.nameHit = makeNameHit(row.name)
        rowPool[r] = row
    end
    return row
end

local function getCell(row, c)
    local fs = row.cells[c]
    if not fs then
        fs = makeFS(scrollChild, "GameFontHighlightSmall")
        row.cells[c] = fs
        row.hits[c] = makeHit(fs)
    end
    return fs
end

local function hideRow(row, fromCol)
    if not fromCol then
        row.name:Hide()
        row.nameHit:Hide()
    end
    for c = fromCol or 1, #row.cells do
        row.cells[c]:Hide()
        row.hits[c]:Hide()
    end
end

local function hideEverything()
    nameHeader:Hide()
    nameHeaderHit:Hide()
    frame.headerLine:Hide()
    frame.totalLine:Hide()
    frame.totalBand:Hide()
    if track then track:Hide() end
    if thumb then thumb:Hide() end
    for c, fs in ipairs(header) do
        fs:Hide()
        headerHits[c]:Hide()
    end
    for _, row in ipairs(rowPool) do hideRow(row) end
end

-- ---------------------------------------------------------------------------
-- Donnees du tableau
-- ---------------------------------------------------------------------------

-- Colonnes = union ordonnee des cles d'entrees de l'onglet, sur tous les
-- persos, moins les colonnes masquees. L'en-tete vient de l'entree la plus
-- RECENTE (updatedAt) : un reroll pas reconnecte garde l'ancien libelle et ne
-- doit pas l'imposer a toute la colonne.
local function buildColumns(roster, tab)
    local cols, colByKey = {}, {}
    for _, ch in ipairs(roster) do
        for _, e in ipairs(ch.entries) do
            if entryTab(e) == tab and not ns.DB:IsColHidden(tab, e.key) then
                local rec = colByKey[e.key]
                if not rec then
                    rec = {
                        key      = e.key,
                        headerTx = shortText(e),
                        category = e.category,
                        order    = e.order or 100,
                        seenAt   = e.updatedAt or 0,
                    }
                    cols[#cols + 1] = rec
                    colByKey[e.key] = rec
                elseif (e.updatedAt or 0) > rec.seenAt then
                    rec.headerTx = shortText(e)
                    rec.seenAt   = e.updatedAt or 0
                end
                if e.sumFormat then rec.sumFormat = e.sumFormat end
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
    return cols
end

-- Valeur de tri d'une case : sortValue explicite, sinon la progression.
local function sortValueOf(ch, colKey)
    local e = ch.byKey[colKey]
    if not e then return nil end
    if e.sortValue then return tonumber(e.sortValue) end
    if e.progress and e.progress.current then return tonumber(e.progress.current) end
    return nil
end

local function sortRoster(roster, tab, groupRealm)
    local s = (global().sort or {})[tab] or { key = "name", desc = false }
    table.sort(roster, function(a, b)
        if groupRealm and (a.realm or "") ~= (b.realm or "") then
            return (a.realm or "") < (b.realm or "")
        end
        if s.key ~= "name" then
            local va, vb = sortValueOf(a, s.key), sortValueOf(b, s.key)
            if va ~= vb then
                if va == nil then return false end   -- sans valeur : toujours en bas
                if vb == nil then return true end
                if s.desc then return va > vb end
                return va < vb
            end
        end
        local na, nb = a.name or "", b.name or ""
        if na ~= nb then
            if s.key == "name" and s.desc then return na > nb end
            return na < nb
        end
        return (a.realm or "") < (b.realm or "")
    end)
end

-- Ligne de total (onglet Personnages) : somme des cases qui declarent un
-- sumFormat. L'or ajoute la banque de Bataillon, detaillee dans l'infobulle.
local function buildTotals(cols, chars)
    local totals, any = {}, false
    for _, rec in ipairs(cols) do
        if rec.sumFormat then
            local sum, n = 0, 0
            for _, ch in ipairs(chars) do
                local e = ch.byKey[rec.key]
                if e and tonumber(e.sum) then
                    sum = sum + tonumber(e.sum)
                    n = n + 1
                end
            end
            if n > 0 then
                any = true
                local t = { key = rec.key, label = L["UI_TOTAL"] .. " : " .. rec.headerTx,
                    status = C.Status.INFO, isTotal = true, hideDetailInTip = true }
                local WHITE, GOLD, GREY = { 1, 1, 1 }, { 1, 0.82, 0 }, { 0.55, 0.55, 0.58 }
                if rec.sumFormat == "money" then
                    local lines = {
                        { text = L["TOTAL_CHARS_LABEL"]:format(n), right = ns.FormatGold(sum, true),
                          color = { 0.85, 0.85, 0.85 }, rcolor = WHITE },
                    }
                    local wb = global().warband
                    local total = sum
                    if rec.key == "profile:gold" then
                        -- 0 n'est jamais retenu (voir Profile.lua) : sans releve, on le dit.
                        if wb and (tonumber(wb.money) or 0) > 0 then
                            total = total + tonumber(wb.money)
                            lines[#lines + 1] = { text = L["TOTAL_WARBAND_LABEL"], right = ns.FormatGold(wb.money, true),
                                color = { 0.85, 0.85, 0.85 }, rcolor = WHITE }
                            lines[#lines + 1] = { text = L["TOTAL_WARBAND_READ"]:format(fmtTime(wb.at)), color = GREY, font = "small" }
                        else
                            lines[#lines + 1] = { text = L["TOTAL_WARBAND_UNKNOWN"], color = GREY, font = "small", wrap = true }
                        end
                        lines[#lines + 1] = { text = L["UI_TOTAL"], right = ns.FormatGold(total, true),
                            color = GOLD, rcolor = GOLD, font = "bold" }
                    end
                    t.money = total
                    t.lines = lines
                else
                    t.detail = tostring(sum)
                    t.lines = { { text = L["UI_TOTAL"], right = tostring(sum), color = GOLD, rcolor = GOLD, font = "bold" } }
                end
                totals[rec.key] = t
            end
        end
    end
    return any and totals or nil
end

function UI:Refresh()
    if not frame or not frame:IsShown() then return end

    local tab = currentTab()
    local g = global()
    local groupRealm = g.groupRealm == true
    paintTabs(tab)
    for _, t in ipairs(TABS) do
        if t.key == tab then frame.subtitle:SetText(L[t.subKey]) end
    end

    local roster, nHidden = ns.Journal:GetRoster()

    -- Entrees de l'onglet courant, indexees par colonne, pour chaque perso.
    for _, ch in ipairs(roster) do
        local byKey = {}
        for _, e in ipairs(ch.entries) do
            if entryTab(e) == tab then byKey[e.key] = e end
        end
        ch.byKey = byKey
    end

    -- 1. Colonnes.
    local cols = buildColumns(roster, tab)

    if #roster == 0 or #cols == 0 then
        hideEverything()
        local msg
        if #roster == 0 and (nHidden or 0) > 0 then
            msg = L["UI_ALL_HIDDEN"]
        elseif #roster > 0 and ns.DB:CountHiddenCols(tab) > 0 then
            msg = L["UI_ALL_COLS_HIDDEN"]
        elseif tab == "chars" then
            msg = L["UI_EMPTY_CHARS"]
        else
            msg = L["UI_EMPTY"]
        end
        frame.empty:SetText(msg)
        frame.empty:SetWidth(320)
        frame.empty:Show()
        frame:SetSize(math.max(360, (frame.tabsW or 0) + 2 * PAD_X), PAD_TOP + 70)
        return
    end
    frame.empty:Hide()

    -- 2. Lignes a afficher : persos tries, en-tetes de royaume, total.
    sortRoster(roster, tab, groupRealm)
    local items = {}
    local lastRealm
    for _, ch in ipairs(roster) do
        if groupRealm and ch.realm ~= lastRealm then
            items[#items + 1] = { kind = "group", text = ch.realm or "?" }
            lastRealm = ch.realm
        end
        items[#items + 1] = { kind = "char", ch = ch }
    end
    local totals = (tab == "chars") and buildTotals(cols, roster) or nil
    if totals then items[#items + 1] = { kind = "total", totals = totals } end

    -- 3. Mesure (avant toute contrainte de largeur).
    local colW = {}
    for c, rec in ipairs(cols) do
        local fs = getHeader(c)
        fs:SetText(rec.headerTx .. sortMark(tab, rec.key))
        colW[c] = fs:GetStringWidth() or 0
    end

    nameHeader:SetText(L["UI_HEADER_CHAR"] .. sortMark(tab, "name"))
    local nameW = nameHeader:GetStringWidth() or 0

    for r, it in ipairs(items) do
        local row = getRow(r)
        if it.kind == "char" then
            row.name:SetText(nameText(it.ch))
        elseif it.kind == "group" then
            row.name:SetText(it.text)
        else
            row.name:SetText(L["UI_TOTAL"])
        end
        local w = row.name:GetStringWidth() or 0
        if w > nameW then nameW = w end

        if it.kind ~= "group" then
            for c, rec in ipairs(cols) do
                local cell = getCell(row, c)
                local e
                if it.kind == "char" then e = it.ch.byKey[rec.key] else e = it.totals[rec.key] end
                -- Police AVANT le texte : la mesure de largeur en depend. Les
                -- lignes du pool sont reutilisees, d'ou la police reposee a chaque fois.
                cell:SetFontObject(it.kind == "total" and "GameFontNormal" or "GameFontHighlightSmall")
                cell:SetText((it.kind == "total" and not e) and "" or cellText(e))
                local cw = cell:GetStringWidth() or 0
                if cw > colW[c] then colW[c] = cw end
            end
        end
    end

    -- 4. Offsets horizontaux cumules (relatifs au bloc de contenu).
    local colX = {}
    local cursor = nameW + GUTTER
    for c = 1, #cols do
        colX[c] = cursor
        cursor = cursor + colW[c] + GUTTER
    end
    local gridW = cursor - GUTTER

    -- 5. En-tetes (zone fixe), cliquables pour trier / masquer.
    local sortState = (g.sort or {})[tab]
    nameHeader:ClearAllPoints()
    nameHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, -PAD_TOP)
    nameHeader:SetWidth(nameW + 4)
    if sortState and sortState.key == "name" then
        nameHeader:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    else
        nameHeader:SetTextColor(1, 0.82, 0)
    end
    nameHeader:Show()
    nameHeaderHit.colKey = nil
    nameHeaderHit.title = L["UI_HEADER_CHAR"]
    nameHeaderHit:Show()

    for c = 1, #cols do
        local fs = getHeader(c)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X + colX[c], -PAD_TOP)
        fs:SetWidth(colW[c] + 4)
        if sortState and sortState.key == cols[c].key then
            fs:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
        else
            fs:SetTextColor(1, 0.82, 0)
        end
        fs:Show()
        local hh = headerHits[c]
        hh.colKey = cols[c].key
        hh.title = cols[c].headerTx
        hh:Show()
    end
    for c = #cols + 1, #header do
        header[c]:Hide()
        headerHits[c]:Hide()
    end

    frame.headerLine:ClearAllPoints()
    frame.headerLine:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, -(PAD_TOP + HEADER_H - 4))
    frame.headerLine:SetSize(gridW, 1)
    frame.headerLine:Show()

    -- 6. Dimensions du corps defilant.
    -- Auto-hauteur uniforme : la fenetre grandit pour montrer toutes les lignes
    -- jusqu'a la hauteur de l'ecran (regle commune : ecran - 80) ; au-dela, la
    -- barre de defilement prend le relais.
    local nRows   = #items
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

    -- 7. Lignes (dans le scrollChild, positionnees depuis SON coin haut-gauche).
    frame.totalLine:Hide()
    frame.totalBand:Hide()
    for r, it in ipairs(items) do
        local row = rowPool[r]
        local yy = (r - 1) * ROW_H

        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yy)
        row.name:SetWidth(nameW + 4)
        row.name:Show()

        if it.kind == "group" then
            row.name:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.85)
            row.nameHit:Hide()
            hideRow(row, 1)
        else
            local ch = it.ch
            local alpha = 1
            if it.kind == "char" then
                -- Grise : masque, ou (onglet semaine) donnees d'avant le reset.
                if ch.hidden or (tab == "week" and ch.stale) then alpha = 0.45 end
                local cr, cg, cb = classRGB(ch.class)
                row.name:SetTextColor(cr, cg, cb, alpha)
                row.nameHit.ch = ch
                row.nameHit:Show()
            else
                -- Ligne de total : bandeau teinte, trait d'accent, libelle turquoise.
                row.name:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
                row.nameHit:Hide()
                frame.totalLine:ClearAllPoints()
                frame.totalLine:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", -4, -(yy - 3))
                frame.totalLine:SetSize(gridW + 8, 1)
                frame.totalLine:Show()
                frame.totalBand:ClearAllPoints()
                frame.totalBand:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", -4, -(yy - 3))
                frame.totalBand:SetSize(gridW + 8, ROW_H)
                frame.totalBand:Show()
            end

            for c = 1, #cols do
                local cell = getCell(row, c)
                cell:ClearAllPoints()
                cell:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", colX[c], -yy)
                cell:SetWidth(colW[c] + 4)
                local e
                if it.kind == "char" then e = ch.byKey[cols[c].key] else e = it.totals[cols[c].key] end
                local sr, sg, sb
                if it.kind == "total" then
                    sr, sg, sb = 1, 0.82, 0   -- totaux en or, comme les en-tetes
                elseif e and e.color then
                    sr, sg, sb = e.color[1], e.color[2], e.color[3]
                elseif e then
                    sr, sg, sb = statusRGB(e.status)
                else
                    sr, sg, sb = 0.40, 0.40, 0.42
                end
                -- Deduction (ex. recompense probable) : un cran plus discrete.
                local a = (e and e.inferred) and alpha * 0.75 or alpha
                cell:SetTextColor(sr, sg, sb, a)
                cell:Show()
                local hit = row.hits[c]
                hit.entry = e
                hit.stale = it.kind == "char" and tab == "week" and ch.stale
                if e then hit:Show() else hit:Hide() end
            end
            hideRow(row, #cols + 1)
        end
    end
    for r = nRows + 1, #rowPool do
        hideRow(rowPool[r])
    end

    -- 8. Barre de defilement + largeur reservee si besoin.
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

    -- 9. Taille finale + clamp de l'offset courant.
    local w = PAD_X + gridW + rightPad
    w = math.max(w, MIN_W, (frame.tabsW or 0) + 2 * PAD_X)
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
            elseif e.detail then
                p = " (" .. tostring(e.detail) .. ")"
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

    elseif msg == "options" or msg == "config" then
        if WeeklyCompass_OpenOptions then WeeklyCompass_OpenOptions() end

    elseif msg == "" or msg == "show" then
        UI:Toggle()

    else
        print("|cff8db4e2WeeklyCompass|r " .. L["SLASH_HINT"])
    end
end
