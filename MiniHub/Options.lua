--[[----------------------------------------------------------------------------
    MiniHub - Options (panneau unique du socle) + gestionnaire de boutons
    ------------------------------------------------------------------------
    Un seul point d'entree Options, comme toute la suite : le panneau flottant
    du socle (UI.CreateOptionsPanel). Il remplace l'ancien panneau des
    Reglages Blizzard ET l'ancien panneau socle partiel de MiniHub_Suite.lua.
    En autonome seulement, une petite entree dans Reglages > AddOns renvoie
    vers ce panneau (les joueurs sans TibiSuite y cherchent les options).

    Le gestionnaire (fenetre MiniHubManager) liste tous les boutons : favori
    (barre rapide), ordre manuel (fleches), laisser sur la minicarte, et les
    boutons non reconnus a ajouter en un clic.
------------------------------------------------------------------------------]]

local MiniHub = MiniHub
local L = MiniHub.L or setmetatable({}, { __index = function(_, k) return k end })

local ACCENT = { 0.988, 0.843, 0.282 }
local FRAME  = "MiniHubContainer"

local function GetUI() return _G.TibiMidnight end
local function DB() return _G.MiniHubDB end
local function Relayout()
    if MiniHub.SortCollected then MiniHub.SortCollected() end
    if MiniHub.RequestLayout then MiniHub.RequestLayout() end
end

--------------------------------------------------------------------------------
-- Petits controles en plus de ceux du socle (cycle, saisie)
--------------------------------------------------------------------------------

local function Advance(panel, h)
    panel._y = panel._y - h
    panel.content:SetHeight(math.max(-panel._y + 10, 10))
end

-- Bouton dont le texte reflete une valeur et qui la fait tourner au clic.
local function AddCycle(panel, textFn, onClick)
    local ui = GetUI()
    local b = ui.MakeButton(panel.content, 250, 24, "")
    b:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 6, panel._y)
    local function upd() b._label:SetText(textFn()) end
    b:SetScript("OnClick", function() onClick(); upd() end)
    upd()
    panel._refresh[#panel._refresh + 1] = upd
    Advance(panel, 30)
    return b
end

local function AddEditBox(panel)
    local box = CreateFrame("EditBox", nil, panel.content, "BackdropTemplate")
    box:SetSize(250, 22)
    box:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 6, panel._y)
    box:SetBackdrop(GetUI().FlatBackdrop())
    box:SetBackdropColor(0.02, 0.02, 0.03, 0.9)
    box:SetBackdropBorderColor(1, 1, 1, 0.15)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(6, 6, 0, 0)
    box:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    Advance(panel, 30)
    return box
end

--------------------------------------------------------------------------------
-- Panneau d'options
--------------------------------------------------------------------------------

local panel

local function ThemeName(key)
    local map = { dark = L["THEME_DARK"], gold = L["THEME_GOLD"], glass = L["THEME_GLASS"], minimal = L["THEME_MINIMAL"] }
    return map[key] or key
end

local function NextIn(list, cur)
    for i, v in ipairs(list) do
        if v == cur then return list[(i % #list) + 1] end
    end
    return list[1]
end

local SIDE_NAMES = { LEFT = "SIDE_LEFT", BOTTOM = "SIDE_BOTTOM", RIGHT = "SIDE_RIGHT" }

local function BuildOptions()
    local ui = GetUI(); if not ui then return nil end
    if panel then return panel end
    panel = ui.CreateOptionsPanel({
        name = "MiniHubOptionsMidnight",
        title = "MiniHub - " .. L["OPT_TITLE"], accent = ACCENT })

    -- ------------------------------------------------------------ Boutons
    panel:Section(L["SEC_BUTTONS"])
    panel:Button(L["OPT_MANAGE"], function() MiniHub.OpenManager() end)
    panel:Note(L["OPT_MANAGE_NOTE"])
    panel:Button(L["OPT_RESCAN"], function()
        MiniHub.Collect()
        MiniHub.Print(string.format(L["MSG_RESCAN"], #MiniHub.order))
    end)

    -- ------------------------------------------------------------ Affichage
    panel:Section(L["SEC_DISPLAY"])
    AddCycle(panel,
        function() return string.format(L["OPT_VIEW"], DB().viewMode == "LIST" and L["VIEW_LIST"] or L["VIEW_GRID"]) end,
        function() DB().viewMode = (DB().viewMode == "LIST") and "GRID" or "LIST"; Relayout() end)
    AddCycle(panel,
        function() return string.format(L["OPT_ORIENTATION"], DB().orientation == "VERTICAL" and L["OPT_VERTICAL"] or L["OPT_HORIZONTAL"]) end,
        function() DB().orientation = (DB().orientation == "VERTICAL") and "HORIZONTAL" or "VERTICAL"; Relayout() end)
    panel:Slider(L["OPT_PER_LINE"], 1, 12, 1,
        function() return DB().perLine or 6 end,
        function(v) DB().perLine = v; Relayout() end)
    panel:Slider(L["OPT_LIST_ROWS"], 4, 20, 1,
        function() return DB().listRows or 10 end,
        function(v) DB().listRows = v; Relayout() end)
    panel:Slider(L["OPT_BUTTON_SIZE"], 20, 48, 1,
        function() return DB().buttonSize or 32 end,
        function(v) DB().buttonSize = v; Relayout() end)
    panel:Slider(L["OPT_SPACING"], 0, 12, 1,
        function() return DB().spacing or 4 end,
        function(v) DB().spacing = v; Relayout() end)
    panel:Check(L["OPT_GROUP"],
        function() return DB().groupByCategory end,
        function(v) DB().groupByCategory = v; Relayout() end, L["OPT_GROUP_TT"])
    panel:Check(L["OPT_SHOW_TITLE"],
        function() return DB().showTitle end,
        function(v) DB().showTitle = v; Relayout() end)
    panel:Check(L["OPT_HIDE_ZOOM"],
        function() return DB().hideZoomButtons end,
        function(v) DB().hideZoomButtons = v; MiniHub.ApplyBlizzardHiding() end, L["OPT_HIDE_ZOOM_TT"])

    -- ------------------------------------------------------------ Apparence
    panel:Section(L["OPT_APPEARANCE"])
    AddCycle(panel,
        function() return string.format(L["OPT_THEME"], ThemeName(DB().theme)) end,
        function()
            MiniHub.ApplyTheme(NextIn(MiniHub.THEME_ORDER, DB().theme or "dark"))
            panel:Refresh()
        end)
    panel:Color(L["OPT_BG_COLOR"],
        function() return DB().bgColor end,
        function(r, g, b, a) DB().bgColor = { r, g, b, a }; MiniHub.ApplySkin() end)
    panel:Color(L["OPT_BORDER_COLOR"],
        function() return DB().borderColor end,
        function(r, g, b, a) DB().borderColor = { r, g, b, a }; MiniHub.ApplySkin() end)
    panel:Slider(L["OPT_BG_OPACITY"], 0, 100, 5,
        function() return math.floor(((DB().bgColor[4]) or 0.94) * 100 + 0.5) end,
        function(v) DB().bgColor[4] = v / 100; MiniHub.ApplySkin() end)
    panel:Check(L["OPT_ANIMATE"],
        function() return DB().animate end,
        function(v) DB().animate = v end)

    -- ------------------------------------------------------------ Favoris
    panel:Section(L["SEC_QUICKBAR"])
    panel:Check(L["OPT_QUICKBAR"],
        function() return DB().quickBar end,
        function(v) DB().quickBar = v; Relayout(); MiniHub.UpdateContextVisibility() end, L["OPT_QUICKBAR_TT"])
    panel:Check(L["OPT_QUICKBAR_VERTICAL"],
        function() return DB().quickBarVertical end,
        function(v) DB().quickBarVertical = v; Relayout() end)
    panel:Note(L["OPT_QUICKBAR_NOTE"])

    -- ------------------------------------------------------------ Position
    panel:Section(L["SEC_POSITION"])
    panel:Button(L["OPT_SNAP_BOTTOM"], function() MiniHub.SnapToMinimap("BOTTOM"); panel:Refresh() end)
    panel:Button(L["OPT_SNAP_LEFT"], function() MiniHub.SnapToMinimap("LEFT"); panel:Refresh() end)
    panel:Button(L["OPT_SNAP_RIGHT"], function() MiniHub.SnapToMinimap("RIGHT"); panel:Refresh() end)
    panel:Note(L["OPT_POSITION_NOTE"])

    -- ------------------------------------------------------------ Tiroir
    panel:Section(L["SEC_DRAWER"])
    panel:Check(L["OPT_DRAWER"],
        function() return DB().drawer end,
        function(v) DB().drawer = v; MiniHub.ApplyDrawer(); MiniHub.UpdateContextVisibility() end, L["OPT_DRAWER_TT"])
    AddCycle(panel,
        function() return string.format(L["OPT_DRAWER_SIDE"], L[SIDE_NAMES[DB().drawerSide] or "SIDE_LEFT"]) end,
        function()
            DB().drawerSide = NextIn({ "LEFT", "BOTTOM", "RIGHT" }, DB().drawerSide or "LEFT")
            MiniHub.RestorePosition()
        end)

    -- ------------------------------------------------------------ Comportement
    panel:Section(L["OPT_BEHAVIOR"])
    panel:Check(L["OPT_LOCK"],
        function() return DB().locked end,
        function(v) DB().locked = v end)
    panel:Check(L["OPT_AUTO_CLOSE"],
        function() return DB().autoClose end,
        function(v) DB().autoClose = v end)
    panel:Check(L["OPT_HIDE_COMBAT"],
        function() return DB().hideInCombat end,
        function(v) DB().hideInCombat = v; MiniHub.UpdateContextVisibility() end)
    panel:Check(L["OPT_HIDE_INSTANCE"],
        function() return DB().hideInInstance end,
        function(v) DB().hideInInstance = v; MiniHub.UpdateContextVisibility() end)
    panel:Check(L["OPT_HIDE_PETBATTLE"],
        function() return DB().hideInPetBattle end,
        function(v) DB().hideInPetBattle = v; MiniHub.UpdateContextVisibility() end)

    -- ------------------------------------------------------------ Sources
    panel:Section(L["SEC_SOURCES"])
    panel:Check(L["OPT_COLLECT_TS"],
        function() return DB().collectTibiSuite end,
        function(v) DB().collectTibiSuite = v; MiniHub.Collect() end, L["OPT_COLLECT_TS_TT"])
    panel:Check(L["OPT_COMPARTMENT"],
        function() return DB().compartment end,
        function(v) DB().compartment = v; MiniHub.Collect() end, L["OPT_COMPARTMENT_TT"])
    panel:Check(L["OPT_IGNORE_CONFLICT"],
        function() return DB().ignoreConflict end,
        function(v) MiniHub.SetIgnoreConflict(v) end, L["OPT_IGNORE_CONFLICT_TT"])

    -- ------------------------------------------------------------ Suite / autonome
    if _G.TibiSuite and _G.TibiSuite.SetCtrlHidden then
        panel:Section(L["SEC_FLOATING"])
        panel:Check(L["OPT_HIDE_FLOAT_OPTIONS"],
            function() return _G.TibiSuite.IsCtrlHidden(FRAME, "options") end,
            function(v) _G.TibiSuite.SetCtrlHidden(FRAME, "options", v) end)
        panel:Check(L["OPT_HIDE_FLOAT_SEARCH"],
            function() return _G.TibiSuite.IsCtrlHidden(FRAME, "search") end,
            function(v) _G.TibiSuite.SetCtrlHidden(FRAME, "search", v) end)
    else
        panel:Section(L["SEC_MAIN_BUTTON"])
        panel:Check(L["OPT_SHOW_MINIMAP"],
            function() return not DB().minimap.hide end,
            function(v) MiniHub.SetMasterShown(v) end)
        panel:Check(L["OPT_SHOW_MAIN"],
            function() return DB().showMainButton end,
            function(v) DB().showMainButton = v; MiniHub.UpdateMainButtonVisibility() end, L["OPT_SHOW_MAIN_TT"])
        panel:Check(L["OPT_HOVER_OPEN"],
            function() return DB().hoverOpen end,
            function(v) DB().hoverOpen = v end, L["OPT_HOVER_OPEN_TT"])
        panel:Slider(L["OPT_MAIN_SIZE"], 28, 64, 2,
            function() return DB().mainButtonSize or 40 end,
            function(v) DB().mainButtonSize = v; MiniHub.ApplyMainButtonStyle() end)
        panel:Slider(L["OPT_MAIN_OPACITY"], 20, 100, 5,
            function() return math.floor((DB().mainButtonAlpha or 1) * 100 + 0.5) end,
            function(v) DB().mainButtonAlpha = v / 100; MiniHub.ApplyMainButtonStyle() end)
    end

    -- ------------------------------------------------------------ Profil
    panel:Section(L["OPT_PROFILE_TITLE"])
    panel:Note(L["OPT_PROFILE_NOTE"])
    local box = AddEditBox(panel)
    panel:Button(L["OPT_EXPORT"], function()
        box:SetText(MiniHub.ExportProfile())
        box:HighlightText(); box:SetFocus()
    end)
    panel:Button(L["OPT_IMPORT"], function()
        if MiniHub.ImportProfile(box:GetText()) then
            MiniHub.Print(L["MSG_IMPORT_OK"])
            panel:Refresh()
        else
            MiniHub.Print(L["MSG_IMPORT_FAIL"])
        end
    end)

    -- ------------------------------------------------------------ Actions
    panel:Section(L["SEC_ACTIONS"])
    panel:Button(L["OPT_RECENTER"], function()
        MiniHub.ResetPositions()
        MiniHub.Print(L["MSG_RESET"])
    end)
    panel:Button(L["OPT_RESET_ORDER"], function() MiniHub.ResetOrder() end)

    return panel
end

function MiniHub_OpenOptions()
    local p = BuildOptions(); if p then p:Toggle() end
end

--------------------------------------------------------------------------------
-- Gestionnaire de boutons
--------------------------------------------------------------------------------

local manager
local rows, unknownRows = {}, {}
local ROW_H = 26

local function SmallIconButton(parent, tex, size, tooltip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    if type(tex) == "string" and tex:find("^atlas:") then
        if not pcall(t.SetAtlas, t, tex:sub(7)) then t:SetColorTexture(1, 0.82, 0, 1) end
    else
        t:SetTexture(tex)
    end
    b.tex = t
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.15)
    if tooltip then
        b:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(tooltip, nil, nil, nil, nil, true); GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return b
end

local function GetRow(i, parent)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW_H)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20); r.icon:SetPoint("LEFT", 4, 0)
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.label:SetPoint("LEFT", r.icon, "RIGHT", 6, 5)
    r.label:SetWidth(170); r.label:SetJustifyH("LEFT"); r.label:SetWordWrap(false)
    r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.sub:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -1)
    r.sub:SetWidth(170); r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false)

    r.keep = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
    r.keep:SetSize(22, 22); r.keep:SetPoint("RIGHT", -4, 0)
    r.keep:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(L["MGR_KEEP_TT"], nil, nil, nil, nil, true); GameTooltip:Show()
    end)
    r.keep:SetScript("OnLeave", function() GameTooltip:Hide() end)

    r.down = SmallIconButton(r, "Interface\\Buttons\\Arrow-Down-Up", 18, L["MGR_DOWN"])
    r.down:SetPoint("RIGHT", r.keep, "LEFT", -10, -3)
    r.up = SmallIconButton(r, "Interface\\Buttons\\Arrow-Up-Up", 18, L["MGR_UP"])
    r.up:SetPoint("RIGHT", r.down, "LEFT", -2, 6)
    r.fav = SmallIconButton(r, "atlas:auctionhouse-icon-favorite", 18, L["MGR_FAV_TT"])
    r.fav:SetPoint("RIGHT", r.up, "LEFT", -8, -3)
    rows[i] = r
    return r
end

local function GetUnknownRow(i, parent)
    local r = unknownRows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW_H)
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.label:SetPoint("LEFT", 6, 0)
    r.label:SetWidth(250); r.label:SetJustifyH("LEFT"); r.label:SetWordWrap(false)
    r.add = GetUI().MakeButton(r, 80, 20, L["MGR_ADD"])
    r.add:SetPoint("RIGHT", -4, 0)
    unknownRows[i] = r
    return r
end

local function RefreshManager()
    if not (manager and manager:IsShown()) then return end
    local content = manager.content
    local db = DB()
    MiniHub.SortCollected()

    -- Boutons collectes, puis boutons laisses sur la minicarte.
    local entries, seen = {}, {}
    for _, b in ipairs(MiniHub.order) do
        local info = MiniHub.GetInfo(b)
        seen[info.name] = true
        entries[#entries + 1] = { button = b, info = info }
    end
    local excluded = {}
    for name in pairs(db.exclusions) do
        if not seen[name] then excluded[#excluded + 1] = name end
    end
    table.sort(excluded)
    for _, name in ipairs(excluded) do entries[#entries + 1] = { name = name } end

    local y = -4
    local lastCat
    for _, r in ipairs(rows) do r:Hide() end
    for i, e in ipairs(entries) do
        local r = GetRow(i, content)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        if e.button then
            local info, name = e.info, e.info.name
            r.icon:SetTexture(MiniHub.GetIcon(e.button))
            r.icon:SetDesaturated(not e.button:IsShown())
            r.label:SetText(info.label)
            local sub = info.category and (info.category .. "  -  " .. name) or name
            if not e.button:IsShown() then sub = L["MGR_HIDDEN_BY_ADDON"] .. "  -  " .. sub end
            r.sub:SetText(sub)
            local fav = db.favorites[name] and true or false
            r.fav.tex:SetDesaturated(not fav)
            r.fav.tex:SetAlpha(fav and 1 or 0.45)
            r.fav:SetScript("OnClick", function() MiniHub.SetFavorite(name, not fav); RefreshManager() end)
            r.up:SetScript("OnClick", function() MiniHub.MoveButton(name, -1); RefreshManager() end)
            r.down:SetScript("OnClick", function() MiniHub.MoveButton(name, 1); RefreshManager() end)
            r.fav:Show(); r.up:Show(); r.down:Show()
            r.keep:SetChecked(false)
            r.keep:SetScript("OnClick", function() MiniHub.SetExcluded(name, true); RefreshManager() end)
        else
            r.icon:SetTexture(134400); r.icon:SetDesaturated(true)
            r.label:SetText(e.name)
            r.sub:SetText(L["MGR_ON_MINIMAP"])
            r.fav:Hide(); r.up:Hide(); r.down:Hide()
            r.keep:SetChecked(true)
            r.keep:SetScript("OnClick", function() MiniHub.SetExcluded(e.name, false); RefreshManager() end)
        end
        r:Show()
        y = y - ROW_H
    end
    if #entries == 0 then
        manager.empty:ClearAllPoints()
        manager.empty:SetPoint("TOPLEFT", content, "TOPLEFT", 6, y - 4)
        manager.empty:Show()
        y = y - 22
    else
        manager.empty:Hide()
    end

    -- Non reconnus.
    y = y - 10
    manager.unTitle:ClearAllPoints()
    manager.unTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
    y = y - 16
    manager.unHint:ClearAllPoints()
    manager.unHint:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
    y = y - (manager.unHint:GetStringHeight() or 12) - 6
    for _, r in ipairs(unknownRows) do r:Hide() end
    local unknown = MiniHub.GetUnrecognized()
    for i, name in ipairs(unknown) do
        local r = GetUnknownRow(i, content)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        r.label:SetText(name)
        r.add:SetScript("OnClick", function()
            DB().whitelist[name] = true
            MiniHub.Collect()
            MiniHub.Print(string.format(L["MSG_ADD"], name))
            RefreshManager()
        end)
        r:Show()
        y = y - ROW_H
    end
    if #unknown == 0 then
        manager.unNone:ClearAllPoints()
        manager.unNone:SetPoint("TOPLEFT", content, "TOPLEFT", 6, y)
        manager.unNone:Show()
        y = y - 18
    else
        manager.unNone:Hide()
    end
    content:SetHeight(math.max(-y + 10, 10))
    manager.count:SetText(string.format(L["MGR_COUNT"], #MiniHub.order))
end
MiniHub.RefreshManager = RefreshManager

local function BuildManager()
    if manager then return manager end
    local ui = GetUI()
    local f = CreateFrame("Frame", "MiniHubManager", UIParent, "BackdropTemplate")
    f:SetSize(420, 480)
    f:SetPoint("CENTER", UIParent, "CENTER", -180, 40)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()
    if ui then ui.SkinFrame(f, ACCENT) end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText("MiniHub - " .. L["MGR_TITLE"])
    title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.count:SetPoint("LEFT", title, "RIGHT", 8, 0)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide() end)

    local legend = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    legend:SetPoint("TOPLEFT", 12, -32); legend:SetPoint("RIGHT", -12, 0)
    legend:SetJustifyH("LEFT")
    legend:SetText(L["MGR_LEGEND"])

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -58)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    if ui and ui.SkinScrollBar then ui.SkinScrollBar(scroll, ACCENT) end
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(376, 10)
    scroll:SetScrollChild(content)
    f.content = content

    f.empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.empty:SetText(L["EMPTY"])
    f.unTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.unTitle:SetText(L["OPT_UNKNOWN_TITLE"])
    f.unTitle:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    f.unHint = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.unHint:SetWidth(360); f.unHint:SetJustifyH("LEFT")
    f.unHint:SetText(L["OPT_UNKNOWN_HINT"])
    f.unNone = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.unNone:SetText(L["OPT_NONE_UNKNOWN"])

    -- Echap : mecanisme natif de Blizzard UNIQUEMENT (aucun hook OnHide ni
    -- OnKeyDown, voir les pieges Echap/taint du core).
    tinsert(UISpecialFrames, "MiniHubManager")
    f:SetScript("OnShow", function() RefreshManager() end)
    manager = f
    return f
end

function MiniHub.OpenManager()
    local f = BuildManager()
    if f:IsShown() then f:Hide() else f:Show() end
end

-- Le gestionnaire suit les changements faits ailleurs (hub, slash).
local pendingRefresh = false
MiniHub.OnLayout = function()
    if not (manager and manager:IsShown()) or pendingRefresh then return end
    pendingRefresh = true
    C_Timer.After(0.1, function() pendingRefresh = false; RefreshManager() end)
end

--------------------------------------------------------------------------------
-- Entree dans Reglages > AddOns (mode autonome seulement)
--------------------------------------------------------------------------------

function MiniHub.SetupOptions()
    if _G.TibiSuite then return end   -- en suite : la barre TibiSuite suffit
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local f = CreateFrame("Frame", "MiniHubSettingsStub", UIParent)
    f:Hide()
    local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16); t:SetText("MiniHub")
    local s = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6); s:SetText(L["ADDON_SUBTITLE"])
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(220, 24); b:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -14)
    b:SetText(L["OPT_OPEN_PANEL"])
    b:SetScript("OnClick", function()
        MiniHub_OpenOptions()
    end)
    local b2 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b2:SetSize(220, 24); b2:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -6)
    b2:SetText(L["OPT_MANAGE"])
    b2:SetScript("OnClick", function()
        MiniHub.OpenManager()
    end)
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, f, "MiniHub")
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
        MiniHub.settingsCategory = category
    end
end
