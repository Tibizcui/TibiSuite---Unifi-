--[[----------------------------------------------------------------------------
    MiniHub - Panneau d'options (bilingue, defilant)
    ------------------------------------------------------------------------
    Panneau "canvas" enregistre via l'API Settings moderne, place dans un
    ScrollFrame pour tout afficher sans debordement. Toutes les chaines passent
    par la table de localisation MiniHub.L (EN par defaut, FR si client frFR).
------------------------------------------------------------------------------]]

local MiniHub = MiniHub
local L = MiniHub.L or setmetatable({}, { __index = function(_, k) return k end })

--------------------------------------------------------------------------------
-- Fabriques de controles
--------------------------------------------------------------------------------

local function MakeCheckbox(parent, label, tooltip, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb.text = cb.text or cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.text:SetText(label)
    cb:SetChecked(getter())
    cb:SetScript("OnClick", function(self) setter(self:GetChecked()) end)
    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    cb.Refresh = function() cb:SetChecked(getter()) end
    return cb
end

local sliderCount = 0
local function MakeSlider(parent, label, minV, maxV, step, getter, setter)
    sliderCount = sliderCount + 1
    local s = CreateFrame("Slider", "MiniHubSlider" .. sliderCount, parent, "OptionsSliderTemplate")
    s:SetWidth(240)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetValue(getter())

    local low  = s.Low  or _G[(s:GetName() or "") .. "Low"]
    local high = s.High or _G[(s:GetName() or "") .. "High"]
    local text = s.Text or _G[(s:GetName() or "") .. "Text"]
    if low  then low:SetText(tostring(minV)) end
    if high then high:SetText(tostring(maxV)) end
    if text then text:SetText(label .. " : " .. tostring(getter())) end

    s:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        if text then text:SetText(label .. " : " .. tostring(value)) end
        setter(value)
    end)
    s.Refresh = function()
        s:SetValue(getter())
        if text then text:SetText(label .. " : " .. tostring(getter())) end
    end
    s.SetLabelText = function(newLabel)
        label = newLabel
        if text then text:SetText(label .. " : " .. tostring(getter())) end
    end
    return s
end

local function MakeButton(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 140, 22)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

-- Selecteur de couleur (bouton avec pastille) ouvrant le ColorPicker Blizzard.
local function ShowColorPicker(color, onChange)
    local r, g, b, a = color[1], color[2], color[3], color[4] or 1
    local function apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = a
        if ColorPickerFrame.GetColorAlpha then na = ColorPickerFrame:GetColorAlpha()
        elseif OpacitySliderFrame then na = OpacitySliderFrame:GetValue() end
        color[1], color[2], color[3], color[4] = nr, ng, nb, na
        onChange()
    end
    local info = {
        swatchFunc = apply, opacityFunc = apply, hasOpacity = true,
        r = r, g = g, b = b, opacity = a,
        cancelFunc = function()
            color[1], color[2], color[3], color[4] = r, g, b, a
            onChange()
        end,
    }
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow(info)
    else
        ColorPickerFrame.func = info.swatchFunc
        ColorPickerFrame.opacityFunc = info.opacityFunc
        ColorPickerFrame.cancelFunc = info.cancelFunc
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = a
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Show()
    end
end

local function MakeColorButton(parent, label, colorGetter, onChange)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(150, 22)
    b:SetText(label)
    local sw = b:CreateTexture(nil, "OVERLAY")
    sw:SetSize(14, 14)
    sw:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    b.swatch = sw
    b.Refresh = function()
        local c = colorGetter()
        sw:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end
    b:SetScript("OnClick", function()
        pcall(ShowColorPicker, colorGetter(), function()
            b.Refresh(); onChange()
        end)
    end)
    b.Refresh()
    return b
end

--------------------------------------------------------------------------------
-- Listes dynamiques (exclusions + non reconnus)
--------------------------------------------------------------------------------

local exclusionRows = {}
local function RefreshExclusionList(scrollChild)
    for _, row in ipairs(exclusionRows) do row:Hide() end
    local names, seen = {}, {}
    for _, btn in ipairs(MiniHub.order or {}) do
        local n = btn.GetName and btn:GetName()
        if n and not seen[n] then seen[n] = true; names[#names + 1] = n end
    end
    for n in pairs(MiniHubDB.exclusions) do
        if not seen[n] then seen[n] = true; names[#names + 1] = n end
    end
    table.sort(names)

    local y = -4
    for i, name in ipairs(names) do
        local row = exclusionRows[i]
        if not row then
            row = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
            row:SetSize(24, 24)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", row, "RIGHT", 2, 0)
            exclusionRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, y)
        row.text:SetText(name)
        row:SetChecked(MiniHubDB.exclusions[name] and true or false)
        row:SetScript("OnClick", function(self)
            if self:GetChecked() then
                MiniHubDB.exclusions[name] = true
                for _, btn in ipairs(MiniHub.order) do
                    if btn.GetName and btn:GetName() == name then MiniHub.Release(btn) break end
                end
            else
                MiniHubDB.exclusions[name] = nil
            end
            MiniHub.Scan()
        end)
        row:Show()
        y = y - 26
    end
    scrollChild:SetHeight(math.max(-y + 10, 10))
end

local unknownRows = {}
local function RefreshUnknownList(scrollChild, emptyFS)
    for _, row in ipairs(unknownRows) do row:Hide() end
    local names = MiniHub.GetUnrecognized and MiniHub.GetUnrecognized() or {}
    emptyFS:SetShown(#names == 0)

    local y = -4
    for i, name in ipairs(names) do
        local row = unknownRows[i]
        if not row then
            row = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
            row:SetSize(24, 24)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", row, "RIGHT", 2, 0)
            unknownRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, y)
        row.text:SetText(name)
        row:SetChecked(false)
        row:SetScript("OnClick", function()
            MiniHubDB.whitelist[name] = true
            MiniHub.Scan()
        end)
        row:Show()
        y = y - 26
    end
    scrollChild:SetHeight(math.max(-y + 10, 10))
end

--------------------------------------------------------------------------------
-- Construction du panneau
--------------------------------------------------------------------------------

local panel

local function BuildPanel()
    if panel then return panel end

    panel = CreateFrame("Frame", "MiniHubOptionsPanel", UIParent)
    panel:Hide()

    -- Zone defilante englobant tout le contenu.
    local scroll = CreateFrame("ScrollFrame", "MiniHubOptionsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(560, 940)
    scroll:SetScrollChild(content)

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -4)
    title:SetText("MiniHub")

    local sub = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText(L["ADDON_SUBTITLE"])
    sub:SetTextColor(0.8, 0.8, 0.8)

    ---------------------------------------------------------------- Colonne gauche
    local function GridLabel()
        return (MiniHubDB.orientation == "VERTICAL") and L["OPT_COLUMNS"] or L["OPT_ROWS"]
    end
    local function OrientLabel()
        return string.format(L["OPT_ORIENTATION"],
            (MiniHubDB.orientation == "VERTICAL") and L["OPT_VERTICAL"] or L["OPT_HORIZONTAL"])
    end
    local function ThemeName(key)
        local map = { dark = L["THEME_DARK"], gold = L["THEME_GOLD"], glass = L["THEME_GLASS"], minimal = L["THEME_MINIMAL"] }
        return map[key] or key
    end

    local perLine

    local orientBtn = MakeButton(content, "", 240, function(self)
        MiniHubDB.orientation = (MiniHubDB.orientation == "VERTICAL") and "HORIZONTAL" or "VERTICAL"
        self:SetText(OrientLabel())
        if perLine and perLine.SetLabelText then perLine.SetLabelText(GridLabel()) end
        MiniHub.Layout()
    end)
    orientBtn:SetText(OrientLabel())
    orientBtn:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -16)

    perLine = MakeSlider(content, GridLabel(), 1, 12, 1,
        function() return MiniHubDB.perLine end,
        function(v) MiniHubDB.perLine = v; MiniHub.Layout() end)
    perLine:SetPoint("TOPLEFT", orientBtn, "BOTTOMLEFT", 4, -24)

    local sizeS = MakeSlider(content, L["OPT_BUTTON_SIZE"], 20, 48, 1,
        function() return MiniHubDB.buttonSize end,
        function(v) MiniHubDB.buttonSize = v; MiniHub.Layout() end)
    sizeS:SetPoint("TOPLEFT", perLine, "BOTTOMLEFT", 0, -34)

    local spaceS = MakeSlider(content, L["OPT_SPACING"], 0, 12, 1,
        function() return MiniHubDB.spacing end,
        function(v) MiniHubDB.spacing = v; MiniHub.Layout() end)
    spaceS:SetPoint("TOPLEFT", sizeS, "BOTTOMLEFT", 0, -34)

    -- Theme (bouton de cycle) + couleurs
    local themeBtn = MakeButton(content, "", 240, function(self)
        local order = MiniHub.THEME_ORDER or { "dark" }
        local cur = MiniHubDB.theme or "dark"
        local idx = 1
        for i, k in ipairs(order) do if k == cur then idx = i break end end
        local nextKey = order[(idx % #order) + 1]
        if MiniHub.ApplyTheme then MiniHub.ApplyTheme(nextKey) end
        self:SetText(string.format(L["OPT_THEME"], ThemeName(MiniHubDB.theme)))
        if self._bgc then self._bgc.Refresh() end
        if self._bdc then self._bdc.Refresh() end
    end)
    themeBtn:SetText(string.format(L["OPT_THEME"], ThemeName(MiniHubDB.theme)))
    themeBtn:SetPoint("TOPLEFT", spaceS, "BOTTOMLEFT", -4, -30)

    local bgColorBtn = MakeColorButton(content, L["OPT_BG_COLOR"],
        function() return MiniHubDB.bgColor end,
        function() MiniHub.ApplySkin() end)
    bgColorBtn:SetSize(240, 22)
    bgColorBtn:SetPoint("TOPLEFT", themeBtn, "BOTTOMLEFT", 0, -8)

    local bdColorBtn = MakeColorButton(content, L["OPT_BORDER_COLOR"],
        function() return MiniHubDB.borderColor end,
        function() MiniHub.ApplySkin() end)
    bdColorBtn:SetSize(240, 22)
    bdColorBtn:SetPoint("TOPLEFT", bgColorBtn, "BOTTOMLEFT", 0, -6)
    themeBtn._bgc, themeBtn._bdc = bgColorBtn, bdColorBtn

    local alphaS = MakeSlider(content, L["OPT_BG_OPACITY"], 0, 100, 5,
        function() return math.floor((MiniHubDB.bgColor[4] or 0.92) * 100) end,
        function(v) MiniHubDB.bgColor[4] = v / 100; MiniHub.ApplySkin(); bgColorBtn.Refresh() end)
    alphaS:SetPoint("TOPLEFT", bdColorBtn, "BOTTOMLEFT", 4, -30)

    local mainSizeS = MakeSlider(content, L["OPT_MAIN_SIZE"], 28, 64, 2,
        function() return MiniHubDB.mainButtonSize or 40 end,
        function(v) MiniHubDB.mainButtonSize = v
            if MiniHub.ApplyMainButtonStyle then MiniHub.ApplyMainButtonStyle() end end)
    mainSizeS:SetPoint("TOPLEFT", alphaS, "BOTTOMLEFT", 0, -34)

    local mainAlphaS = MakeSlider(content, L["OPT_MAIN_OPACITY"], 20, 100, 5,
        function() return math.floor((MiniHubDB.mainButtonAlpha or 1.0) * 100) end,
        function(v) MiniHubDB.mainButtonAlpha = v / 100
            if MiniHub.ApplyMainButtonStyle then MiniHub.ApplyMainButtonStyle() end end)
    mainAlphaS:SetPoint("TOPLEFT", mainSizeS, "BOTTOMLEFT", 0, -34)

    -- Cases a cocher (general)
    local cbTitle = MakeCheckbox(content, L["OPT_SHOW_TITLE"], nil,
        function() return MiniHubDB.showTitle end,
        function(v) MiniHubDB.showTitle = v; MiniHub.Layout() end)
    cbTitle:SetPoint("TOPLEFT", mainAlphaS, "BOTTOMLEFT", -4, -18)

    local cbLock = MakeCheckbox(content, L["OPT_LOCK"], nil,
        function() return MiniHubDB.locked end,
        function(v) MiniHubDB.locked = v end)
    cbLock:SetPoint("TOPLEFT", cbTitle, "BOTTOMLEFT", 0, -2)

    local cbMinimap = MakeCheckbox(content, L["OPT_SHOW_MINIMAP"], nil,
        function() return not MiniHubDB.minimap.hide end,
        function(v) MiniHub.SetMasterShown(v) end)
    cbMinimap:SetPoint("TOPLEFT", cbLock, "BOTTOMLEFT", 0, -2)

    local cbMain = MakeCheckbox(content, L["OPT_SHOW_MAIN"], L["OPT_SHOW_MAIN_TT"],
        function() return MiniHubDB.showMainButton end,
        function(v)
            MiniHubDB.showMainButton = v
            if MiniHub.UpdateMainButtonVisibility then MiniHub.UpdateMainButtonVisibility()
            elseif MiniHub.mainButton then MiniHub.mainButton:SetShown(v) end
        end)
    cbMain:SetPoint("TOPLEFT", cbMinimap, "BOTTOMLEFT", 0, -2)

    local cbZoom = MakeCheckbox(content, L["OPT_HIDE_ZOOM"], L["OPT_HIDE_ZOOM_TT"],
        function() return MiniHubDB.hideZoomButtons end,
        function(v) MiniHubDB.hideZoomButtons = v; MiniHub.ApplyBlizzardHiding() end)
    cbZoom:SetPoint("TOPLEFT", cbMain, "BOTTOMLEFT", 0, -2)

    -- Cases a cocher (comportement)
    local cbHover = MakeCheckbox(content, L["OPT_HOVER_OPEN"], L["OPT_HOVER_OPEN_TT"],
        function() return MiniHubDB.hoverOpen end,
        function(v) MiniHubDB.hoverOpen = v end)
    cbHover:SetPoint("TOPLEFT", cbZoom, "BOTTOMLEFT", 0, -2)

    local cbAuto = MakeCheckbox(content, L["OPT_AUTO_CLOSE"], nil,
        function() return MiniHubDB.autoClose end,
        function(v) MiniHubDB.autoClose = v end)
    cbAuto:SetPoint("TOPLEFT", cbHover, "BOTTOMLEFT", 0, -2)

    local cbAnim = MakeCheckbox(content, L["OPT_ANIMATE"], nil,
        function() return MiniHubDB.animate end,
        function(v) MiniHubDB.animate = v end)
    cbAnim:SetPoint("TOPLEFT", cbAuto, "BOTTOMLEFT", 0, -2)

    local cbCombat = MakeCheckbox(content, L["OPT_HIDE_COMBAT"], nil,
        function() return MiniHubDB.hideInCombat end,
        function(v) MiniHubDB.hideInCombat = v; MiniHub.UpdateContextVisibility() end)
    cbCombat:SetPoint("TOPLEFT", cbAnim, "BOTTOMLEFT", 0, -2)

    local cbInst = MakeCheckbox(content, L["OPT_HIDE_INSTANCE"], nil,
        function() return MiniHubDB.hideInInstance end,
        function(v) MiniHubDB.hideInInstance = v; MiniHub.UpdateContextVisibility() end)
    cbInst:SetPoint("TOPLEFT", cbCombat, "BOTTOMLEFT", 0, -2)

    local cbPet = MakeCheckbox(content, L["OPT_HIDE_PETBATTLE"], nil,
        function() return MiniHubDB.hideInPetBattle end,
        function(v) MiniHubDB.hideInPetBattle = v; MiniHub.UpdateContextVisibility() end)
    cbPet:SetPoint("TOPLEFT", cbInst, "BOTTOMLEFT", 0, -2)

    local rescan = MakeButton(content, L["OPT_RESCAN"], 120, function() MiniHub.Scan() end)
    rescan:SetPoint("TOPLEFT", cbPet, "BOTTOMLEFT", 4, -12)
    local resetPos = MakeButton(content, L["OPT_RECENTER"], 120, function()
        MiniHubDB.point = { "CENTER", "UIParent", "CENTER", 0, 0 }
        MiniHubDB.mainPoint = { "CENTER", "UIParent", "CENTER", 200, 0 }
        MiniHub.RestorePosition()
    end)
    resetPos:SetPoint("LEFT", rescan, "RIGHT", 8, 0)

    ---------------------------------------------------------------- Colonne droite
    local RX = 300
    local exTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    exTitle:SetPoint("TOPLEFT", content, "TOPLEFT", RX, -54)
    exTitle:SetText(L["OPT_EXCL_TITLE"])
    local exHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    exHint:SetPoint("TOPLEFT", exTitle, "BOTTOMLEFT", 0, -2)
    exHint:SetText(L["OPT_EXCL_HINT"])

    local exScroll = CreateFrame("ScrollFrame", "MiniHubExclusionScroll", content, "UIPanelScrollFrameTemplate")
    exScroll:SetPoint("TOPLEFT", exHint, "BOTTOMLEFT", 0, -6)
    exScroll:SetSize(230, 150)
    local exChild = CreateFrame("Frame", nil, exScroll)
    exChild:SetSize(230, 150)
    exScroll:SetScrollChild(exChild)

    local unTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    unTitle:SetPoint("TOPLEFT", exScroll, "BOTTOMLEFT", 0, -18)
    unTitle:SetText(L["OPT_UNKNOWN_TITLE"])
    local unHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    unHint:SetPoint("TOPLEFT", unTitle, "BOTTOMLEFT", 0, -2)
    unHint:SetText(L["OPT_UNKNOWN_HINT"])
    unHint:SetWidth(230); unHint:SetJustifyH("LEFT")

    local unScroll = CreateFrame("ScrollFrame", "MiniHubUnknownScroll", content, "UIPanelScrollFrameTemplate")
    unScroll:SetPoint("TOPLEFT", unHint, "BOTTOMLEFT", 0, -6)
    unScroll:SetSize(230, 120)
    local unChild = CreateFrame("Frame", nil, unScroll)
    unChild:SetSize(230, 120)
    unScroll:SetScrollChild(unChild)
    local unEmpty = unChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    unEmpty:SetPoint("TOPLEFT", 4, -4)
    unEmpty:SetText(L["OPT_NONE_UNKNOWN"])

    -- Partage de profil
    local pfTitle = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pfTitle:SetPoint("TOPLEFT", unScroll, "BOTTOMLEFT", 0, -18)
    pfTitle:SetText(L["OPT_PROFILE_TITLE"])

    local pfBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    pfBox:SetSize(230, 22)
    pfBox:SetPoint("TOPLEFT", pfTitle, "BOTTOMLEFT", 6, -6)
    pfBox:SetAutoFocus(false)
    pfBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local exportB = MakeButton(content, L["OPT_EXPORT"], 110, function()
        pfBox:SetText(MiniHub.ExportProfile and MiniHub.ExportProfile() or "")
        pfBox:HighlightText()
        pfBox:SetFocus()
    end)
    exportB:SetPoint("TOPLEFT", pfBox, "BOTTOMLEFT", -4, -6)
    local importB = MakeButton(content, L["OPT_IMPORT"], 110, function()
        local ok = MiniHub.ImportProfile and MiniHub.ImportProfile(pfBox:GetText())
        if ok then
            print("|cffffd200MiniHub|r : " .. L["MSG_IMPORT_OK"])
            if panel.refreshControls then panel.refreshControls() end
        else
            print("|cffffd200MiniHub|r : " .. L["MSG_IMPORT_FAIL"])
        end
    end)
    importB:SetPoint("LEFT", exportB, "RIGHT", 8, 0)

    ---------------------------------------------------------------- Rafraichissement
    panel.refreshControls = function()
        perLine.Refresh(); sizeS.Refresh(); spaceS.Refresh(); alphaS.Refresh()
        mainSizeS.Refresh(); mainAlphaS.Refresh()
        cbTitle.Refresh(); cbLock.Refresh(); cbMinimap.Refresh(); cbMain.Refresh(); cbZoom.Refresh()
        cbHover.Refresh(); cbAuto.Refresh(); cbAnim.Refresh(); cbCombat.Refresh(); cbInst.Refresh(); cbPet.Refresh()
        orientBtn:SetText(OrientLabel())
        if perLine.SetLabelText then perLine.SetLabelText(GridLabel()) end
        themeBtn:SetText(string.format(L["OPT_THEME"], ThemeName(MiniHubDB.theme)))
        bgColorBtn.Refresh(); bdColorBtn.Refresh()
        MiniHub.Scan()
        RefreshExclusionList(exChild)
        RefreshUnknownList(unChild, unEmpty)
    end
    panel:SetScript("OnShow", panel.refreshControls)

    return panel
end

--------------------------------------------------------------------------------
-- Enregistrement dans l'API Settings (autonome ou sous-categorie TibiSuite)
--------------------------------------------------------------------------------

function MiniHub.SetupOptions()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return end

    local frame = BuildPanel()

    local parentCategory
    local suite = _G.TibiSuite
    if suite then
        parentCategory = suite.settingsCategory or (suite.GetSettingsCategory and suite:GetSettingsCategory())
    end

    local category
    if parentCategory and Settings.RegisterCanvasLayoutSubcategory then
        category = Settings.RegisterCanvasLayoutSubcategory(parentCategory, frame, "MiniHub")
    else
        category = Settings.RegisterCanvasLayoutCategory(frame, "MiniHub")
        Settings.RegisterAddOnCategory(category)
    end

    MiniHub.settingsCategory = category

    MiniHub.OpenSettings = function()
        if InCombatLockdown and InCombatLockdown() then
            print("|cffffd200MiniHub|r : " .. L["MSG_COMBAT_OPTIONS"])
            return
        end
        if Settings and Settings.OpenToCategory and MiniHub.settingsCategory then
            Settings.OpenToCategory(MiniHub.settingsCategory:GetID())
        end
    end
end
