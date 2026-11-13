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

-- Bouton construit par le socle v23 (UI.MinimapButton, audit poids
-- 2026-11-13, lot 5) : position, glisser (OnUpdate seulement pendant le
-- deplacement), zoom et collecteurs au meme endroit. Nom, sauvegarde
-- (db.global.minimap.angle / hidden), icone et rayon d'origine conserves.
local function buildButton()
    if button then return button end
    local UIm = _G.TibiMidnight
    if not (Minimap and UIm and UIm.MinimapButton) then return end
    button = UIm.MinimapButton({
        name = "WeeklyCompassMinimapButton", style = "compact", default = 220,
        radiusPad = 5,
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        texCoord = { 0.08, 0.92, 0.08, 0.92 },
        getAngle = function() local pos = minimapPos(); return pos and pos.angle end,
        setAngle = function(a) local pos = minimapPos(); if pos then pos.angle = a end end,
        onClick = function(btn)
            if btn == "LeftButton" and ns.UI and ns.UI.Toggle then ns.UI:Toggle() end
        end,
        tooltip = function(tt)
            tt:AddLine("WeeklyCompass")
            tt:AddLine(L["MINIMAP_HINT_TOGGLE"], 0.8, 0.8, 0.8)
            tt:AddLine(L["MINIMAP_HINT_DRAG"], 0.8, 0.8, 0.8)
        end,
    })
    if not button then return end
    local pos = minimapPos()
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
-- encore sa source (ex : Repaires), pour que l'etat de l'addon soit clair des la connexion.
local function announce()
    local g = ns.DB and ns.DB:GetGlobal()
    if g and g.login == false then return end
    -- 7.3 : en suite, seul TibiSuite annonce la connexion.
    if _G.TibiSuite and _G.TibiSuite.RegisterModule then return end

    local active, pending = 0, 0
    local modules, order = ns.Registry:GetAll()
    for _, key in ipairs(order) do
        if ns.Registry:IsHidden(modules[key]) then
            -- retiree du tableau : ni suivie, ni en attente
        elseif ns.Registry:IsActive(modules[key]) then
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
