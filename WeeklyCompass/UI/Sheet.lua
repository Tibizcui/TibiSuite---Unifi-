local addonName, ns = ...
local L = ns.L
local C = ns.Const

local Sheet = {}
ns.Sheet = Sheet

-- ===========================================================================
-- Fiche detaillee d'un personnage : clic gauche sur un nom du tableau.
-- Panneau accole au tableau (a droite, ou a gauche s'il n'y a pas la place),
-- fleches precedent / suivant dans l'ordre du tableau, Echap pour fermer.
--
--   En-tete : modele 3D anime (glisser pour tourner) si c'est le perso
--             connecte ; sinon un bandeau classe / race. Un reroll deconnecte
--             ne peut pas etre reconstruit en 3D : le jeu ne permet ni de
--             choisir la race d'un modele ni de lire sa transmogrification
--             (sonde TibiProbe 0.5, piste A ecartee).
--   Gauche  : equipement, niveau d'objet colore par piste, enchantement
--             manquant et chasse vide signales.
--   Droite  : ensemble de raid (raid, saison, bonus), statistiques, grille
--             du Grand Coffre, verrouillages de raid, monnaies de la saison.
-- ===========================================================================

local W        = 668
local HEADER_H = 138
local PAD      = 14
local COL_L_W  = 330
local COL_R_X  = 362
local COL_R_W  = 292
local ROW_H    = 22
local ACCENT   = { 0.039, 1.000, 0.745 }
local GREY     = { 0.55, 0.55, 0.58 }
local RED      = { 1.00, 0.35, 0.35 }
local GREEN    = { 0.42, 0.85, 0.48 }
local ORANGE   = { 1.00, 0.70, 0.30 }

-- Noms d'emplacements Blizzard, pour l'icone d'emplacement vide.
local SLOT_NAME = {
    [1] = "HEADSLOT", [2] = "NECKSLOT", [3] = "SHOULDERSLOT", [15] = "BACKSLOT", [5] = "CHESTSLOT",
    [9] = "WRISTSLOT", [16] = "MAINHANDSLOT", [17] = "SECONDARYHANDSLOT", [10] = "HANDSSLOT",
    [6] = "WAISTSLOT", [7] = "LEGSSLOT", [8] = "FEETSLOT", [11] = "FINGER0SLOT", [12] = "FINGER1SLOT",
    [13] = "TRINKET0SLOT", [14] = "TRINKET1SLOT",
}

local frame
local currentKey
local ui = {}   -- widgets construits une fois, remplis a chaque Refresh

local function classRGB(token)
    local t = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if t then return t.r, t.g, t.b end
    return 0.90, 0.90, 0.92
end

local function newFS(parent, template, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
end

local function setColor(fs, c, a)
    fs:SetTextColor(c[1], c[2], c[3], a or 1)
end

local function fmtTime(ts)
    return (type(ts) == "number" and ts > 0) and date("%d/%m %H:%M", ts) or "?"
end

local function hideTip()
    if GameTooltip then GameTooltip:Hide() end
end

-- Titre de section : texte d'accent + trait fin.
local function newSection(parent)
    local s = {}
    s.fs = newFS(parent, "GameFontNormal")
    setColor(s.fs, ACCENT)
    s.line = parent:CreateTexture(nil, "ARTWORK")
    s.line:SetColorTexture(1, 1, 1, 0.10)
    s.line:SetHeight(1)
    return s
end

local function placeSection(s, text, x, y, width)
    s.fs:ClearAllPoints()
    s.fs:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    s.fs:SetText(text)
    s.fs:Show()
    s.line:Show()
    s.line:ClearAllPoints()
    s.line:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y - 16)
    s.line:SetWidth(width)
    return y - 22
end

-- Ligne "texte a gauche / valeur a droite" de la colonne de droite.
local function newPair(parent)
    local p = {}
    p.left = newFS(parent, "GameFontHighlightSmall")
    p.right = newFS(parent, "GameFontHighlightSmall", "RIGHT")
    return p
end

local function placePair(p, x, y, width, left, right, lc, rc, font)
    p.left:SetFontObject(font or "GameFontHighlightSmall")
    p.right:SetFontObject(font or "GameFontHighlightSmall")
    p.left:ClearAllPoints()
    p.left:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    p.left:SetWidth(right and (width - 70) or width)
    p.left:SetText(left or "")
    setColor(p.left, lc or { 0.85, 0.85, 0.85 })
    p.right:ClearAllPoints()
    p.right:SetPoint("TOPRIGHT", frame, "TOPLEFT", x + width, y)
    p.right:SetWidth(70)
    p.right:SetText(right or "")
    setColor(p.right, rc or { 1, 1, 1 })
    p.left:Show()
    p.right:Show()
end

local function hidePair(p) p.left:Hide(); p.right:Hide() end

local function hideSection(s) s.fs:Hide(); s.line:Hide() end

-- ---------------------------------------------------------------------------
-- Talents : infobulle et fenetre "Copier le build". Fenetre maison (pas de
-- StaticPopup, qui provoque lui aussi du taint) : le code est deja
-- selectionne, Ctrl+C suffit. Un addon ne peut pas ecrire directement dans
-- le presse-papiers.
-- ---------------------------------------------------------------------------
local copyDlg

local function readOnlyBox(parent, y)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(446, 20)
    eb:SetPoint("TOPLEFT", 20, y)
    eb:SetAutoFocus(false)
    if eb.SetMaxLetters then eb:SetMaxLetters(0) end
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetScript("OnEscapePressed", function() parent:Hide() end)
    -- Tout le texte est toujours selectionne, curseur ramene au debut : on
    -- voit le debut du lien et Ctrl+C copie le texte entier (constate en jeu :
    -- la fin seule etait visible, d'ou une copie partielle possible).
    local function selectAll(self)
        if self.SetCursorPosition then self:SetCursorPosition(0) end
        self:HighlightText()
    end
    eb.selectAll = selectAll
    eb:SetScript("OnEditFocusGained", selectAll)
    eb:SetScript("OnMouseUp", selectAll)
    -- Lecture seule : toute frappe remet le texte d'origine, selectionne.
    eb:SetScript("OnTextChanged", function(self, userInput)
        if userInput and self.value then
            self:SetText(self.value)
            self.selectAll(self)
        end
    end)
    return eb
end

local function buildCopy()
    if copyDlg then return end
    copyDlg = CreateFrame("Frame", "WeeklyCompassBuildCopy", UIParent, "BackdropTemplate")
    copyDlg:SetSize(486, 150)
    copyDlg:SetPoint("CENTER", 0, 120)
    copyDlg:SetFrameStrata("DIALOG")
    copyDlg:SetMovable(true)
    copyDlg:EnableMouse(true)
    copyDlg:RegisterForDrag("LeftButton")
    copyDlg:SetScript("OnDragStart", copyDlg.StartMoving)
    copyDlg:SetScript("OnDragStop", copyDlg.StopMovingOrSizing)
    copyDlg:SetClampedToScreen(true)
    if copyDlg.SetBackdrop then
        copyDlg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        copyDlg:SetBackdropColor(0.06, 0.07, 0.09, 0.98)
        copyDlg:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.6)
    end
    copyDlg.title = newFS(copyDlg, "GameFontNormal")
    copyDlg.title:SetPoint("TOPLEFT", 16, -12)
    setColor(copyDlg.title, ACCENT)
    local close = CreateFrame("Button", nil, copyDlg, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    copyDlg.code = readOnlyBox(copyDlg, -36)
    copyDlg.hint = newFS(copyDlg, "GameFontDisableSmall")
    copyDlg.hint:SetPoint("TOPLEFT", 16, -62)
    copyDlg.hint:SetWidth(454)
    if copyDlg.hint.SetWordWrap then copyDlg.hint:SetWordWrap(true) end
    copyDlg.whLabel = newFS(copyDlg, "GameFontHighlightSmall")
    copyDlg.whLabel:SetPoint("TOPLEFT", 16, -92)
    copyDlg.wh = readOnlyBox(copyDlg, -106)
    tinsert(UISpecialFrames, "WeeklyCompassBuildCopy")
    copyDlg:Hide()
end

local function openCopy()
    local t = ui.talent and ui.talent.talents
    if not (t and t.code) then return end
    buildCopy()
    copyDlg.title:SetText(L["SHEET_COPY_TITLE"]:format(ui.talent.charName or "?"))
    copyDlg.hint:SetText(L["SHEET_COPY_HINT"])
    copyDlg.whLabel:SetText(L["SHEET_WOWHEAD"])
    copyDlg.code.value = t.code
    copyDlg.code:SetText(t.code)
    local url = L["SHEET_WOWHEAD_BASE"] .. t.code
    copyDlg.wh.value = url
    copyDlg.wh:SetText(url)
    copyDlg.wh.selectAll(copyDlg.wh)
    copyDlg:Show()
    copyDlg.code:SetFocus()
    copyDlg.code.selectAll(copyDlg.code)
end

local function showTalentTip(self)
    local t = self.talents
    if not (t and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    local title = t.hero and t.hero.name or L["SHEET_HERO_TALENTS"]
    if t.hero and t.hero.atlas then title = ("|A:%s:18:18|a %s"):format(t.hero.atlas, title) end
    GameTooltip:AddLine(title, ACCENT[1], ACCENT[2], ACCENT[3])
    if t.heroTalents and #t.heroTalents > 0 then
        GameTooltip:AddLine(L["SHEET_HERO_TALENTS"], 0.85, 0.85, 0.85)
        for _, h in ipairs(t.heroTalents) do
            local line = h.icon and ("|T%s:0|t %s"):format(tostring(h.icon), h.name or "?") or (h.name or "?")
            if (h.max or 1) > 1 then line = line .. (" |cff8a8a8a%d/%d|r"):format(h.rank or 0, h.max) end
            GameTooltip:AddLine(line, 1, 1, 1)
        end
    end
    if t.otherCount and t.otherCount > 0 then
        GameTooltip:AddLine(L["SHEET_OTHER_TALENTS"]:format(t.otherCount), GREY[1], GREY[2], GREY[3])
    end
    if t.modified then
        GameTooltip:AddLine(L["SHEET_MODIFIED_TIP"], ORANGE[1], ORANGE[2], ORANGE[3], true)
    end
    if t.code then GameTooltip:AddLine(L["SHEET_TALENT_CLICK"], GREY[1], GREY[2], GREY[3]) end
    GameTooltip:Show()
end

-- ---------------------------------------------------------------------------
-- Construction (une fois)
-- ---------------------------------------------------------------------------
local function buildHeader()
    ui.band = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    ui.band:SetPoint("TOPLEFT", 1, -1)
    ui.band:SetPoint("TOPRIGHT", -1, -1)
    ui.band:SetHeight(HEADER_H)
    ui.bandLine = frame:CreateTexture(nil, "ARTWORK")
    ui.bandLine:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.55)
    ui.bandLine:SetPoint("TOPLEFT", 1, -HEADER_H)
    ui.bandLine:SetPoint("TOPRIGHT", -1, -HEADER_H)
    ui.bandLine:SetHeight(1)

    -- Modele 3D du perso connecte, tournable a la souris.
    ui.model = CreateFrame("PlayerModel", nil, frame)
    ui.model:SetSize(96, 112)
    ui.model:SetPoint("TOPLEFT", PAD, -6)
    ui.model:EnableMouse(true)
    ui.model:SetScript("OnMouseDown", function(self)
        self.dragging = true
        self.startX = GetCursorPosition()
        self.startFacing = (self.GetFacing and self:GetFacing()) or 0
    end)
    ui.model:SetScript("OnMouseUp", function(self) self.dragging = false end)
    ui.model:SetScript("OnUpdate", function(self)
        if not self.dragging or not self.SetFacing then return end
        local x = GetCursorPosition()
        self:SetFacing(self.startFacing + (x - self.startX) / 80)
    end)
    ui.model:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L["SHEET_ROTATE"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    ui.model:SetScript("OnLeave", hideTip)

    -- Bandeau d'un reroll : grande icone de classe et petite icone de race.
    ui.classIcon = frame:CreateTexture(nil, "ARTWORK")
    ui.classIcon:SetSize(72, 72)
    ui.classIcon:SetPoint("CENTER", ui.model, "CENTER", 0, 4)
    ui.raceIcon = frame:CreateTexture(nil, "OVERLAY")
    ui.raceIcon:SetSize(28, 28)
    ui.raceIcon:SetPoint("BOTTOMRIGHT", ui.model, "BOTTOMRIGHT", -2, 8)

    ui.name = newFS(frame, "GameFontNormalHuge")
    ui.name:SetPoint("TOPLEFT", PAD + 108, -16)
    ui.realm = newFS(frame, "GameFontDisableSmall")
    ui.realm:SetPoint("TOPLEFT", ui.name, "BOTTOMLEFT", 0, -2)
    ui.line = newFS(frame, "GameFontHighlight")
    ui.line:SetPoint("TOPLEFT", ui.realm, "BOTTOMLEFT", 0, -8)
    -- Talents : arbre heroique, build charge, bouton de copie.
    ui.talent = CreateFrame("Button", nil, frame)
    ui.talent:SetSize(200, 18)
    ui.talent:SetPoint("TOPLEFT", ui.line, "BOTTOMLEFT", 0, -6)
    ui.talentIcon = ui.talent:CreateTexture(nil, "ARTWORK")
    ui.talentIcon:SetSize(18, 18)
    ui.talentIcon:SetPoint("LEFT", 0, 0)
    ui.talentText = newFS(ui.talent, "GameFontHighlightSmall")
    ui.talentText:SetPoint("LEFT", ui.talentIcon, "RIGHT", 5, 0)
    ui.talent:SetScript("OnEnter", showTalentTip)
    ui.talent:SetScript("OnLeave", hideTip)
    ui.talent:SetScript("OnClick", openCopy)
    ui.copy = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    ui.copy:SetSize(126, 20)
    ui.copy:SetPoint("LEFT", ui.talent, "RIGHT", 10, 0)
    ui.copy:SetText(L["SHEET_COPY_BUILD"])
    ui.copy:SetScript("OnClick", openCopy)

    ui.updated = newFS(frame, "GameFontDisableSmall")
    ui.updated:SetPoint("TOPLEFT", ui.talent, "BOTTOMLEFT", 0, -6)

    ui.ilvl = newFS(frame, "GameFontNormalHuge", "RIGHT")
    ui.ilvl:SetPoint("TOPRIGHT", -PAD - 8, -44)
    ui.ilvlLabel = newFS(frame, "GameFontDisableSmall", "RIGHT")
    ui.ilvlLabel:SetPoint("TOPRIGHT", ui.ilvl, "BOTTOMRIGHT", 0, -2)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    local function navButton(dir)
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(24, 24)
        local tex = dir < 0 and "PrevPage" or "NextPage"
        b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. tex .. "-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. tex .. "-Down")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        b:SetScript("OnClick", function() Sheet:Step(dir) end)
        b:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(dir < 0 and L["SHEET_PREV"] or L["SHEET_NEXT"], 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", hideTip)
        return b
    end
    ui.next = navButton(1)
    ui.next:SetPoint("RIGHT", close, "LEFT", -2, 0)
    ui.prev = navButton(-1)
    ui.prev:SetPoint("RIGHT", ui.next, "LEFT", 2, 0)
end

local function buildGear()
    ui.gearTitle = newSection(frame)
    ui.gear = {}
    for i, s in ipairs(ns.SHEET_SLOTS) do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(COL_L_W, ROW_H)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 0, 0)
        if row.icon.SetTexCoord then row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        row.ilvl = newFS(row, "GameFontNormalSmall", "RIGHT")
        row.ilvl:SetPoint("LEFT", row.icon, "RIGHT", 2, 0)
        row.ilvl:SetWidth(30)
        row.name = newFS(row, "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", row.ilvl, "RIGHT", 8, 0)
        row.name:SetWidth(COL_L_W - 150)
        row.warn = newFS(row, "GameFontNormalSmall", "RIGHT")
        row.warn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.warn:SetWidth(100)
        setColor(row.warn, RED)
        row.slotID = s.id
        row:SetScript("OnEnter", function(self)
            if not (GameTooltip and self.data) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.data.link then GameTooltip:SetHyperlink(self.data.link) end
            if self.data.missingEnchant then GameTooltip:AddLine(L["SHEET_TIP_ENCHANT"], RED[1], RED[2], RED[3]) end
            if self.data.emptySockets then
                GameTooltip:AddLine(L["SHEET_TIP_SOCKET"]:format(self.data.emptySockets), RED[1], RED[2], RED[3])
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", hideTip)
        ui.gear[i] = row
    end
end

local function buildRight()
    ui.setTitle = newSection(frame)
    ui.setPairs = { newPair(frame), newPair(frame), newPair(frame) }

    ui.statsTitle = newSection(frame)
    ui.stats = {}
    for i = 1, 4 do
        local st = newPair(frame)
        st.bg = frame:CreateTexture(nil, "ARTWORK")
        st.bg:SetColorTexture(1, 1, 1, 0.08)
        st.bar = frame:CreateTexture(nil, "OVERLAY")
        ui.stats[i] = st
    end

    ui.vaultTitle = newSection(frame)
    ui.vaultNote = newFS(frame, "GameFontDisableSmall")
    ui.vault = {}
    for r = 1, 3 do
        local row = { label = newFS(frame, "GameFontHighlightSmall"), boxes = {} }
        for b = 1, 3 do
            local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
            box:SetSize(62, 20)
            if box.SetBackdrop then
                box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            end
            box.fs = newFS(box, "GameFontHighlightSmall", "CENTER")
            box.fs:SetPoint("CENTER")
            row.boxes[b] = box
        end
        ui.vault[r] = row
    end

    ui.raidsTitle = newSection(frame)
    ui.raids = {}
    for i = 1, 7 do ui.raids[i] = newPair(frame) end

    ui.curTitle = newSection(frame)
    ui.cur = {}
    for i = 1, 5 do ui.cur[i] = newPair(frame) end
end

local function build()
    if frame then return end
    frame = CreateFrame("Frame", "WeeklyCompassSheet", UIParent, "BackdropTemplate")
    frame:SetSize(W, 560)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        frame:SetBackdropColor(0.06, 0.07, 0.09, 0.97)
        frame:SetBackdropBorderColor(0, 0, 0, 1)
    end
    -- Echap : meme mecanisme que la fenetre du tableau (UISpecialFrames).
    tinsert(UISpecialFrames, "WeeklyCompassSheet")
    frame:Hide()

    ui.empty = newFS(frame, "GameFontDisable")
    if ui.empty.SetWordWrap then ui.empty:SetWordWrap(true) end
    buildHeader()
    buildGear()
    buildRight()
end

-- ---------------------------------------------------------------------------
-- Remplissage
-- ---------------------------------------------------------------------------
local function charData(key)
    local char = ns.DB:GetAllChars()[key]
    if not char then return nil end
    local by = {}
    for _, e in ipairs(ns.Journal:GetEntries(char)) do by[e.key] = e end
    local stale = not ns.Reset:IsSamePeriod(char.periodId, ns.Reset:GetCurrentPeriodId())
    return char, by, stale
end

local function fillHeader(key, char, by, sheet)
    local cr, cg, cb = classRGB(char.class)
    ui.band:SetColorTexture(cr, cg, cb, 0.14)
    ui.name:SetText(char.name or "?")
    ui.name:SetTextColor(cr, cg, cb)
    ui.realm:SetText(char.realm or "")

    local parts = {}
    local level = by["profile:level"] and by["profile:level"].detail
    if level then parts[#parts + 1] = L["SHEET_LEVEL"]:format(tostring(level)) end
    if by["profile:spec"] and by["profile:spec"].detail then parts[#parts + 1] = by["profile:spec"].detail end
    local className = sheet and sheet.className
        or (LOCALIZED_CLASS_NAMES_MALE and char.class and LOCALIZED_CLASS_NAMES_MALE[char.class])
    if className then parts[#parts + 1] = className end
    if sheet and sheet.race and sheet.race.name then parts[#parts + 1] = sheet.race.name end
    ui.line:SetText(table.concat(parts, "  |cff8a8a8a·|r  "))
    ui.updated:SetText(sheet and L["SHEET_UPDATED"]:format(fmtTime(sheet.updatedAt))
        or L["TIP_LAST_SEEN"]:format(fmtTime(char.lastSeen)))

    -- Ligne des talents.
    local t = sheet and sheet.talents
    ui.talent.talents = t
    ui.talent.charName = char.name
    if t and (t.hero or t.build or t.code) then
        local tp = {}
        if t.hero and t.hero.name then tp[#tp + 1] = "|cff0affbe" .. t.hero.name .. "|r" end
        if t.starter then
            tp[#tp + 1] = L["SHEET_STARTER"]
        elseif t.build then
            tp[#tp + 1] = L["SHEET_BUILD"]:format(t.build)
                .. (t.modified and (" |cffffb34d" .. L["SHEET_BUILD_MODIFIED"] .. "|r") or "")
        end
        ui.talentText:SetText(table.concat(tp, "  |cff8a8a8a·|r  "))
        local atlas = t.hero and t.hero.atlas
        if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
            ui.talentIcon:SetAtlas(atlas)
            ui.talentIcon:Show()
        else
            ui.talentIcon:Hide()
        end
        ui.talent:SetWidth(24 + (ui.talentText:GetStringWidth() or 150))
        ui.talent:Show()
        ui.copy:SetShown(t.code ~= nil)
    elseif sheet then
        ui.talentText:SetText(L["SHEET_NO_TALENTS"])
        ui.talentIcon:Hide()
        ui.talent:SetWidth(24 + (ui.talentText:GetStringWidth() or 150))
        ui.talent:Show()
        ui.copy:Hide()
    else
        ui.talentText:SetText("")
        ui.talentIcon:Hide()
        ui.talent:Hide()
        ui.copy:Hide()
    end

    local ilvl = by["profile:ilvl"]
    ui.ilvl:SetText(ilvl and ilvl.detail or "-")
    ui.ilvlLabel:SetText(L["SHEET_ILVL_LABEL"])

    -- Perso connecte : vrai modele 3D. Reroll : bandeau classe / race.
    local isMe = key == ns.charKey()
    if isMe and ui.model.SetUnit then
        ui.model:Show()
        pcall(ui.model.SetUnit, ui.model, "player")
        if ui.model.SetPortraitZoom then pcall(ui.model.SetPortraitZoom, ui.model, 0) end
        ui.classIcon:Hide()
        ui.raceIcon:Hide()
    else
        ui.model:Hide()
        local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[char.class or ""]
        if coords then
            ui.classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            ui.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            ui.classIcon:Show()
        else
            ui.classIcon:Hide()
        end
        -- Icone de race : atlas du jeu, verifie avant usage (noms variables).
        local shown = false
        local race = sheet and sheet.race and sheet.race.file
        if race and C_Texture and C_Texture.GetAtlasInfo then
            local file = race:lower():gsub("scourge", "undead")
            local sex = (sheet.sex == 3) and "female" or "male"
            -- Le nom de l'atlas a change selon les versions du jeu : on essaie
            -- les formes connues, la premiere qui existe gagne.
            for _, fmt in ipairs({ "raceicon128-%s-%s", "raceicon-%s-%s", "raceicon64-%s-%s" }) do
                local atlas = fmt:format(file, sex)
                if C_Texture.GetAtlasInfo(atlas) then
                    ui.raceIcon:SetAtlas(atlas)
                    shown = true
                    break
                end
            end
        end
        if shown then ui.raceIcon:Show() else ui.raceIcon:Hide() end
    end
end

local function fillGear(y, sheet)
    y = placeSection(ui.gearTitle, L["SHEET_EQUIPMENT"], PAD, y, COL_L_W)
    local slots = sheet and sheet.slots or {}
    for i, row in ipairs(ui.gear) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y - (i - 1) * ROW_H)
        local d = slots[row.slotID] or slots[tostring(row.slotID)]
        row.data = d
        if d then
            row.icon:SetTexture(d.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.icon:SetDesaturated(false)
            row.ilvl:SetText(d.ilvl and tostring(math.floor(d.ilvl)) or "")
            local tc = d.trackColor or { 1, 1, 1 }
            setColor(row.ilvl, tc)
            row.name:SetText(d.name or "")
            local qc = ITEM_QUALITY_COLORS and d.quality and ITEM_QUALITY_COLORS[d.quality]
            if qc then row.name:SetTextColor(qc.r, qc.g, qc.b) else row.name:SetTextColor(0.9, 0.9, 0.9) end
            local warns = {}
            if d.missingEnchant then warns[#warns + 1] = L["SHEET_WARN_ENCHANT"] end
            if d.emptySockets then warns[#warns + 1] = L["SHEET_WARN_SOCKET"] end
            row.warn:SetText(table.concat(warns, " · "))
            -- La zone d'alerte prend la largeur de son texte, le nom se
            -- raccourcit d'autant (icone 18 + ilvl 30 + marges = 58).
            local ww = #warns > 0 and (row.warn:GetStringWidth() or 0) or 0
            row.warn:SetWidth(ww + 2)
            row.name:SetWidth(COL_L_W - 58 - (ww > 0 and ww + 10 or 0))
        else
            local tex = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
            if GetInventorySlotInfo and SLOT_NAME[row.slotID] then
                local ok, _, slotTex = pcall(GetInventorySlotInfo, SLOT_NAME[row.slotID])
                if ok and slotTex then tex = slotTex end
            end
            row.icon:SetTexture(tex)
            row.icon:SetDesaturated(true)
            row.ilvl:SetText("")
            row.name:SetText(sheet and "-" or "")
            row.name:SetTextColor(GREY[1], GREY[2], GREY[3])
            row.name:SetWidth(COL_L_W - 58)
            row.warn:SetText("")
        end
        row:Show()
    end
    return y - #ui.gear * ROW_H
end

-- Saison d'un ensemble : "en cours" si son patch majeur.mineur n'est pas
-- anterieur a celui du client (12.1 : un ensemble 12.0 est d'une saison
-- precedente). Regle automatique, a verifier a chaque nouvelle saison.
local function seasonOf(patchID)
    if not patchID then return nil end
    local version = GetBuildInfo and GetBuildInfo() or ""
    local major, minor = version:match("^(%d+)%.(%d+)")
    major, minor = tonumber(major), tonumber(minor)
    local patchText = ("%d.%d"):format(math.floor(patchID / 10000), math.floor(patchID / 100) % 100)
    if not major then return nil, patchText end
    return math.floor(patchID / 100) >= major * 100 + minor, patchText
end

local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t"
local CROSS = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:0|t"

local function fillSet(y, set)
    y = placeSection(ui.setTitle, L["SHEET_SET"], COL_R_X, y, COL_R_W)
    local p1, p2, p3 = ui.setPairs[1], ui.setPairs[2], ui.setPairs[3]
    if not set then
        placePair(p1, COL_R_X, y, COL_R_W, L["SHEET_NO_SET"], nil, GREY)
        hidePair(p2); hidePair(p3)
        return y - 20
    end
    local countColor = set.count >= 4 and GREEN or ORANGE
    placePair(p1, COL_R_X, y, COL_R_W, set.name or "?", ("%d/%d"):format(set.count, set.total or 5),
        { 1, 1, 1 }, countColor, "GameFontNormal")
    p1.right:SetWidth(40)
    p1.left:SetWidth(COL_R_W - 44)
    local where = {}
    if set.raid then where[#where + 1] = set.raid end
    local exp = set.expansionID and _G["EXPANSION_NAME" .. set.expansionID]
    if exp then where[#where + 1] = exp end
    local isCurrent, patchText = seasonOf(set.patchID)
    local badge, badgeColor
    if isCurrent == true then
        badge, badgeColor = L["SHEET_SET_CURRENT"], ACCENT
    elseif isCurrent == false then
        badge, badgeColor = L["SHEET_SET_PREVIOUS"]:format(patchText), ORANGE
    end
    placePair(p2, COL_R_X, y - 18, COL_R_W, table.concat(where, " · "), nil, { 0.85, 0.85, 0.85 })
    local bonus = ("%s %s    %s %s"):format(set.count >= 2 and CHECK or CROSS, L["SHEET_BONUS"]:format(2),
        set.count >= 4 and CHECK or CROSS, L["SHEET_BONUS"]:format(4))
    placePair(p3, COL_R_X, y - 36, COL_R_W, bonus, badge, { 0.9, 0.9, 0.9 }, badgeColor)
    p3.right:SetWidth(150)
    p3.left:SetWidth(COL_R_W - 150)
    return y - 56
end

local STAT_KEYS = { { "crit", "STAT_CRIT" }, { "haste", "STAT_HASTE" }, { "mastery", "STAT_MASTERY" }, { "versa", "STAT_VERSA" } }

local function fillStats(y, sheet, classToken)
    y = placeSection(ui.statsTitle, L["SHEET_STATS"], COL_R_X, y, COL_R_W)
    local stats = sheet and sheet.stats or {}
    local cr, cg, cb = classRGB(classToken)
    local scale = 40
    for _, def in ipairs(STAT_KEYS) do
        local v = tonumber(stats[def[1]])
        if v and v > scale then scale = v end
    end
    for i, def in ipairs(STAT_KEYS) do
        local st = ui.stats[i]
        local v = tonumber(stats[def[1]])
        local yy = y - (i - 1) * 16
        placePair(st, COL_R_X, yy, 150, L[def[2]], v and (ns.FormatDecimal(v) .. " %") or "-")
        st.right:ClearAllPoints()
        st.right:SetPoint("TOPRIGHT", frame, "TOPLEFT", COL_R_X + 150, yy)
        local barX, barW = COL_R_X + 160, COL_R_W - 160
        st.bg:ClearAllPoints()
        st.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", barX, yy - 4)
        st.bg:SetSize(barW, 6)
        st.bg:Show()
        local frac = math.min(1, math.max(0, (v or 0) / scale))   -- pleine a la plus haute stat
        st.bar:SetColorTexture(cr, cg, cb, 0.85)
        st.bar:ClearAllPoints()
        st.bar:SetPoint("TOPLEFT", st.bg, "TOPLEFT", 0, 0)
        st.bar:SetSize(math.max(1, barW * frac), 6)
        if v then st.bar:Show() else st.bar:Hide() end
    end
    return y - 4 * 16 - 4
end

local function vaultRows()
    local E = Enum and Enum.WeeklyRewardChestThresholdType
    return {
        { type = E and E.Raid or 3,       label = L["VAULT_SLOT_RAID"] },
        { type = E and E.Activities or 1, label = L["VAULT_SLOT_DUNGEONS"] },
        { type = E and E.World or 6,      label = L["VAULT_SLOT_WORLD"] },
    }
end

local function fillVault(y, by, stale)
    y = placeSection(ui.vaultTitle, L["SHEET_VAULT"], COL_R_X, y, COL_R_W)
    if stale then
        ui.vaultNote:ClearAllPoints()
        ui.vaultNote:SetPoint("TOPLEFT", frame, "TOPLEFT", COL_R_X, y)
        ui.vaultNote:SetText(L["UI_STALE"])
        ui.vaultNote:Show()
        y = y - 16
    else
        ui.vaultNote:Hide()
    end
    for r, def in ipairs(vaultRows()) do
        local row = ui.vault[r]
        local yy = y - (r - 1) * 24
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", frame, "TOPLEFT", COL_R_X, yy - 4)
        row.label:SetText(def.label)
        row.label:Show()
        local e = by["greatVault:" .. def.type]
        local slots = e and e.slots
        for b, box in ipairs(row.boxes) do
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", frame, "TOPLEFT", COL_R_X + 84 + (b - 1) * 68, yy)
            local s = slots and slots[b]
            local unlocked, txt, color
            if s then
                unlocked = (s.threshold or 0) > 0 and (s.progress or 0) >= s.threshold
                if unlocked then
                    txt, color = s.ilvl and tostring(s.ilvl) or CHECK, s.color or GREEN
                else
                    txt, color = ("%d/%d"):format(math.min(s.progress or 0, s.threshold or 0), s.threshold or 0), GREY
                end
            elseif e and e.progress then
                -- Entree d'avant la 7.1.5.22 (sans detail par emplacement).
                unlocked = b <= (e.progress.current or 0)
                txt, color = unlocked and CHECK or "-", unlocked and GREEN or GREY
            else
                txt, color = "-", GREY
            end
            if box.SetBackdropColor then
                if unlocked then
                    box:SetBackdropColor(GREEN[1], GREEN[2], GREEN[3], 0.12)
                    box:SetBackdropBorderColor(GREEN[1], GREEN[2], GREEN[3], 0.8)
                else
                    box:SetBackdropColor(1, 1, 1, 0.04)
                    box:SetBackdropBorderColor(1, 1, 1, 0.15)
                end
            end
            box.fs:SetText(txt)
            setColor(box.fs, color)
            box:Show()
        end
    end
    return y - 3 * 24 - 2
end

local function fillRaids(y, by)
    y = placeSection(ui.raidsTitle, L["SHEET_RAIDS"], COL_R_X, y, COL_R_W)
    for _, p in ipairs(ui.raids) do hidePair(p) end
    local e = by["lockouts:raids"]
    local items = {}
    if e and e.items then
        local now = GetServerTime()
        for _, it in ipairs(e.items) do
            if (tonumber(it.expiresAt) or 0) > now then items[#items + 1] = it end
        end
    end
    if #items == 0 then
        placePair(ui.raids[1], COL_R_X, y, COL_R_W, L["SHEET_NO_RAIDS"], nil, GREY)
        return y - 18
    end
    local shown = math.min(#items, 5)
    for i = 1, shown do
        local it = items[i]
        local full = it.total > 0 and it.killed >= it.total
        placePair(ui.raids[i], COL_R_X, y - (i - 1) * 16, COL_R_W, it.name,
            ("%d/%d"):format(it.killed, it.total), { 1, 1, 1 }, full and GREEN or ORANGE)
    end
    local n = shown
    if #items > shown then
        n = n + 1
        placePair(ui.raids[n], COL_R_X, y - (n - 1) * 16, COL_R_W, L["SHEET_MORE"]:format(#items - shown), nil, GREY)
    end
    n = n + 1
    placePair(ui.raids[n], COL_R_X, y - (n - 1) * 16, COL_R_W,
        L["LOCKOUTS_RESET"]:format(ns.FormatDelay(items[1].expiresAt - GetServerTime())), nil, ACCENT)
    return y - n * 16 - 2
end

local function fillCurrencies(y, sheet)
    local list = sheet and sheet.currencies or {}
    for _, p in ipairs(ui.cur) do hidePair(p) end
    if #list == 0 then
        ui.curTitle.fs:Hide(); ui.curTitle.line:Hide()
        return y
    end
    ui.curTitle.fs:Show(); ui.curTitle.line:Show()
    y = placeSection(ui.curTitle, L["SHEET_CURRENCIES"], COL_R_X, y, COL_R_W)
    for i = 1, math.min(#list, #ui.cur) do
        local c = list[i]
        local name = c.icon and ("|T%s:0|t %s"):format(tostring(c.icon), c.name) or c.name
        local right = tostring(c.quantity)
        if (c.max or 0) > 0 then
            right = right .. (" |cff8a8a8a(%d/%d)|r"):format(c.useEarned and c.earned or c.quantity, c.max)
        end
        placePair(ui.cur[i], COL_R_X, y - (i - 1) * 16, COL_R_W, name, right)
        ui.cur[i].right:SetWidth(110)
        ui.cur[i].left:SetWidth(COL_R_W - 110)
    end
    return y - math.min(#list, #ui.cur) * 16
end

-- Place la fiche contre le tableau : a droite s'il y a la place, sinon a gauche.
local function anchor()
    frame:ClearAllPoints()
    local main = _G["WeeklyCompassFrame"]
    if main and main:IsShown() and main.GetRight and main:GetRight() then
        local screenW = UIParent:GetRight() or UIParent:GetWidth()
        if main:GetRight() + 6 + W <= screenW then
            frame:SetPoint("TOPLEFT", main, "TOPRIGHT", 6, 0)
        else
            frame:SetPoint("TOPRIGHT", main, "TOPLEFT", -6, 0)
        end
    else
        frame:SetPoint("CENTER")
    end
end

function Sheet:Refresh()
    if not frame or not frame:IsShown() or not currentKey then return end
    local char, by, stale = charData(currentKey)
    if not char then
        frame:Hide()
        return
    end
    local sheet = by["sheet:data"]
    fillHeader(currentKey, char, by, sheet)

    local top = -(HEADER_H + 12)
    local leftBottom
    if sheet then
        ui.empty:Hide()
        leftBottom = fillGear(top, sheet)
    else
        -- Pas encore de fiche : message dans la colonne Equipement, sans
        -- emplacements vides ; ensemble et statistiques n'ont rien a montrer.
        for _, row in ipairs(ui.gear) do row:Hide() end
        local ly = placeSection(ui.gearTitle, L["SHEET_EQUIPMENT"], PAD, top, COL_L_W)
        ui.empty:ClearAllPoints()
        ui.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, ly)
        ui.empty:SetWidth(COL_L_W)
        ui.empty:SetText(L["SHEET_NO_DATA"])
        ui.empty:Show()
        leftBottom = ly - (ui.empty:GetStringHeight() or 40) - 8
    end
    local y = top
    if sheet then
        y = fillSet(y, sheet.set) - 6
        y = fillStats(y, sheet, char.class) - 6
    else
        hideSection(ui.setTitle)
        for _, p in ipairs(ui.setPairs) do hidePair(p) end
        hideSection(ui.statsTitle)
        for _, st in ipairs(ui.stats) do hidePair(st); st.bg:Hide(); st.bar:Hide() end
    end
    y = fillVault(y, by, stale) - 6
    y = fillRaids(y, by) - 6
    y = fillCurrencies(y, sheet)
    local bottom = math.min(leftBottom, y)
    frame:SetHeight(-bottom + PAD)

    local order = ns.UI and ns.UI.order or {}
    local many = #order > 1
    ui.prev:SetShown(many)
    ui.next:SetShown(many)
end

function Sheet:Open(key)
    build()
    currentKey = key
    anchor()
    frame:Show()
    self:Refresh()
end

-- Perso precedent / suivant, dans l'ordre affiche par le tableau.
function Sheet:Step(dir)
    local order = ns.UI and ns.UI.order or {}
    if #order == 0 then return end
    local idx = 1
    for i, k in ipairs(order) do
        if k == currentKey then idx = i break end
    end
    idx = ((idx - 1 + dir) % #order) + 1
    currentKey = order[idx]
    self:Refresh()
end

function Sheet:IsShown() return frame and frame:IsShown() end

ns:OnMessage("WC_JOURNAL_UPDATED", function() Sheet:Refresh() end)
