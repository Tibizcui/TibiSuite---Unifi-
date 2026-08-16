local addonName, ns = ...
local L = ns.L

-- ===========================================================================
-- Points d'entree de demarrage : le bouton de minicarte et le message de
-- chargement dans le chat. Bouton fait maison, sans dependance externe : il se
-- place sur l'anneau de la minicarte, se deplace au glisser, et memorise sa
-- position dans les SavedVariables (db.global.minimap).
-- ===========================================================================

local button

local function minimapPos()
    local g = ns.DB and ns.DB:GetGlobal()
    return g and g.minimap
end

-- Place le bouton sur l'anneau, a l'angle donne (en degres).
local RADIUS_PAD = 5
local function reposition(angle)
    if not button or not Minimap then return end
    local r = (Minimap:GetWidth() / 2) + RADIUS_PAD
    local rad = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * r, math.sin(rad) * r)
end

-- Suit le curseur pendant le glisser et memorise le nouvel angle.
local function onDragUpdate()
    if not Minimap then return end
    local mx, my = Minimap:GetCenter()
    if not mx then return end
    local scale = Minimap:GetEffectiveScale() or 1
    local px, py = GetCursorPosition()
    px, py = px / scale, py / scale
    local angle = math.deg(math.atan2(py - my, px - mx))
    local pos = minimapPos()
    if pos then pos.angle = angle end
    reposition(angle)
end

local function buildButton()
    if button then return button end
    if not Minimap then return end

    button = CreateFrame("Button", "WeeklyCompassMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)

    -- Icone : montre a gousset = theme hebdomadaire. Un seul chemin a changer
    -- si tu veux une autre icone.
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
    icon:SetPoint("TOPLEFT", 7, -6)
    if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT", 0, 0)

    button:SetScript("OnClick", function()
        if ns.UI and ns.UI.Toggle then ns.UI:Toggle() end
    end)

    button:SetScript("OnDragStart", function(self)
        if self.LockHighlight then self:LockHighlight() end
        self:SetScript("OnUpdate", onDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if self.UnlockHighlight then self:UnlockHighlight() end
    end)

    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("WeeklyCompass")
        GameTooltip:AddLine(L["MINIMAP_HINT_TOGGLE"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["MINIMAP_HINT_DRAG"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local pos = minimapPos()
    reposition(pos and pos.angle or 220)
    if pos and pos.hidden then button:Hide() else button:Show() end
    return button
end

-- Affiche / masque le bouton et memorise le choix. Renvoie l'etat visible.
function ns:ToggleMinimap()
    buildButton()
    local pos = minimapPos()
    if not pos or not button then return end
    pos.hidden = not pos.hidden
    if pos.hidden then button:Hide() else button:Show() end
    return not pos.hidden
end

-- Message de chargement dans le chat. Resume ce qui est actif et ce qui attend
-- encore la Saison 2, pour que l'etat de l'addon soit clair des la connexion.
local function announce()
    local g = ns.DB and ns.DB:GetGlobal()
    if g and g.login == false then return end

    local active, pending = 0, 0
    local modules, order = ns.Registry:GetAll()
    for _, key in ipairs(order) do
        if ns.Registry:IsActive(modules[key]) then
            active = active + 1
        else
            pending = pending + 1
        end
    end

    local version = (ns.Addon and ns.Addon.version) or "?"
    print("|cff8db4e2WeeklyCompass|r " .. L["LOGIN_LOADED"]:format(version, active, pending))
end

-- Au login : le registre (charge avant) a deja cable et fait sa premiere
-- collecte, donc les compteurs actif / en attente sont justes ici.
ns:RegisterEvent("PLAYER_LOGIN", function()
    buildButton()
    announce()
end)
