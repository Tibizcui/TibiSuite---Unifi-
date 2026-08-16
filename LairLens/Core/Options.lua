-- =============================================================================
-- LairLens - Core/Options.lua
-- Panneau de reglages graphique, via l'API Settings moderne (Dragonflight+).
-- Expose ce qui etait derriere les commandes slash. Ecrit defensivement :
-- si l'API Settings n'existe pas (ancien client, ou harnais de test), le fichier
-- se charge sans rien construire plutot que de lever une erreur.
-- =============================================================================

local ADDON, LL = ...
local C = LL.const
local U = LL.util

local Options = {}
LL:RegisterModule("options", Options)

local category  -- categorie Settings, pour l'ouverture

-- Cree une case a cocher avec son libelle propre (on evite les particularites
-- de libelle du template selon les versions).
local function makeCheck(parent, label, tooltip, get, set, anchorTo, dy)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    if anchorTo then
        cb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, dy or -8)
    else
        cb:SetPoint("TOPLEFT", 16, -52)
    end
    cb:SetChecked(get())
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
    end)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)

    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    cb._refresh = function() cb:SetChecked(get()) end
    return cb
end

local function build()
    local L = LL.L
    local panel = CreateFrame("Frame", "LairLensOptionsPanel")
    panel.name = "LairLens"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("LairLens")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText(L["OPT_TITLE"])
    U.SetTextColor(subtitle, C.COLOR.MUTED)

    local checks = {}

    checks[1] = makeCheck(panel, L["OPT_ENABLED"], L["OPT_ENABLED_TT"],
        function() return LL.db.enabled end,
        function(v) LL.db.enabled = v; LL.modules.groupAudit:Update() end)

    checks[2] = makeCheck(panel, L["OPT_HIDE_OUT"], L["OPT_HIDE_OUT_TT"],
        function() return LL.db.audit.hideOutOfLair end,
        function(v) LL.db.audit.hideOutOfLair = v; LL.modules.groupAudit:Update() end,
        checks[1])

    checks[3] = makeCheck(panel, L["OPT_FADE_COMBAT"], L["OPT_FADE_COMBAT_TT"],
        function() return LL.db.audit.fadeInCombat end,
        function(v) LL.db.audit.fadeInCombat = v end,
        checks[2])

    checks[4] = makeCheck(panel, L["OPT_LOCK"], L["OPT_LOCK_TT"],
        function() return LL.db.audit.locked end,
        function(v) LL.db.audit.locked = v end,
        checks[3])

    -- Curseur d'echelle.
    local slider = CreateFrame("Slider", "LairLensScaleSlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", checks[4], "BOTTOMLEFT", 4, -28)
    slider:SetMinMaxValues(0.6, 1.5)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(200)
    slider:SetValue(LL.db.audit.scale or 1.0)

    -- Libelles du template (proteges si absents selon la version).
    local low = _G["LairLensScaleSliderLow"]
    local high = _G["LairLensScaleSliderHigh"]
    local sliderText = _G["LairLensScaleSliderText"]
    if low then low:SetText("60%") end
    if high then high:SetText("150%") end
    if sliderText then sliderText:SetText(L["OPT_SCALE"]) end

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20 -- arrondi au pas de 0.05
        LL.db.audit.scale = value
        if sliderText then sliderText:SetText(L["OPT_SCALE"] .. "  " .. math.floor(value * 100 + 0.5) .. "%") end
        LL.modules.groupAudit:ApplyScale() -- applique l'echelle en direct
    end)

    -- Boutons flottants de la barre TibiSuite (Options / Recherche) qui
    -- debordent au-dessus de la fenetre LairLens : on peut les masquer ici.
    checks[5] = makeCheck(panel, "Masquer le bouton Options",
        "Masque le bouton Options qui deborde au-dessus de la fenetre. Meme masque, Maj+clic droit sur la fenetre ouvre ces options.",
        function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("LairLensAuditFrame", "options") end,
        function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("LairLensAuditFrame", "options", v) end end,
        slider, -24)
    checks[6] = makeCheck(panel, "Masquer le champ Recherche",
        "Masque le champ Recherche qui deborde au-dessus de la fenetre.",
        function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("LairLensAuditFrame", "search") end,
        function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("LairLensAuditFrame", "search", v) end end,
        checks[5])

    -- Rafraichit tout l'etat a l'ouverture du panneau.
    panel:SetScript("OnShow", function()
        for _, cb in ipairs(checks) do cb._refresh() end
        slider:SetValue(LL.db.audit.scale or 1.0)
    end)

    -- Enregistrement dans la fenetre Settings moderne.
    -- NE PAS forcer category.ID a une chaine : Settings.OpenToCategory attend
    -- l'ID NUMERIQUE genere par l'API. Ecraser .ID avec "LairLens" provoquait
    -- l'erreur "bad argument #1 to OpenSettingsPanel (outside of expected range)".
    category = Settings.RegisterCanvasLayoutCategory(panel, "LairLens")
    Settings.RegisterAddOnCategory(category)
end

-- Ouvre le panneau (appele par /ll config).
function Options:Open()
    if category and Settings and Settings.OpenToCategory then
        -- On passe l'ID numerique via GetID() (repli sur category.ID si besoin).
        local id = category.GetID and category:GetID() or category.ID
        Settings.OpenToCategory(id)
    else
        U.Print(LL.L["OPT_UNAVAILABLE"])
    end
end

local function init()
    -- API Settings requise. Sinon (client trop ancien, ou harnais), on n'installe
    -- rien : les commandes slash restent le repli complet.
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local ok, err = pcall(build)
        if not ok and LL.db and LL.db.debug then
            U.Print("Options: build a echoue :", err)
        end
    end
end

LL:On("READY", init)
