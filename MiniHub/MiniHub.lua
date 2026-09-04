--[[----------------------------------------------------------------------------
    MiniHub - Coeur de l'addon
    ------------------------------------------------------------------------
    Regroupe les icones d'addon qui encombrent la minicarte dans un conteneur
    unique, propre et retractable.

    Techniques de robustesse :
      - Detection par liste blanche de motifs de noms (les vrais boutons
        d'addon suivent des conventions : LibDBIcon10_*, *MinimapButton, etc.)
        et exclusion des addons de "pins" (TomTom, HandyNotes, Questie...).
      - Ecart systematique de tout ce qui est protege par Blizzard
        (issecurevariable) : jamais de frame native capturee.
      - Collecte directe via LibDBIcon:GetButtonList() (rattrape tous les
        boutons LibDBIcon, meme parentes ailleurs).
      - Disposition qui ne place QUE les boutons affiches (les masques ne
        laissent pas de trou dans la grille), a taille de cellule uniforme.
      - Blocage du deplacement des boutons collectes (certains addons
        repositionnent leur bouton en continu).

    Fonctionne en autonome OU comme module de la famille TibiSuite.
    Auteur : Tibiscui  -  https://tibiscui.fr
------------------------------------------------------------------------------]]

local ADDON_NAME, ns = ...

MiniHub = MiniHub or {}
local MiniHub = MiniHub
MiniHub.version = "1.2.0"
MiniHub._ns = ns

-- Table de localisation (Locale.lua est charge avant ce fichier).
local L = MiniHub.L or setmetatable({}, { __index = function(_, k) return k end })

-- Bibliotheques (optionnelles : l'addon degrade proprement si absentes).
local LibStub = _G.LibStub
local LDB     = LibStub and LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

-- Raccourcis.
local CreateFrame, UIParent, Minimap = CreateFrame, UIParent, Minimap
local pairs, ipairs, next, type, unpack = pairs, ipairs, next, type, unpack
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local tinsert, tremove, tsort = table.insert, table.remove, table.sort
local strfind, strmatch, strlower = string.find, string.match, string.lower
local hooksecurefunc = hooksecurefunc

-- Methodes "brutes" recuperees sur UIParent : elles permettent de positionner
-- et redimensionner les boutons collectes MEME apres avoir neutralise leurs
-- propres methodes (anti-deplacement).
local rawSetPoint       = UIParent.SetPoint
local rawClearAllPoints = UIParent.ClearAllPoints
local rawSetScale       = UIParent.SetScale
local rawSetParent      = UIParent.SetParent

local LOGO = "Interface\\AddOns\\MiniHub\\media\\Logo_MiniHub.png"
local GOLD = { 1.0, 0.82, 0.0 }
local HEADER_H = 22

-- Themes visuels predefinis (fond + bordure).
local THEMES = {
    dark    = { bg = { 0.045, 0.045, 0.055, 0.94 }, border = { 0.18, 0.18, 0.20, 1.0 } },
    gold    = { bg = { 0.06, 0.05, 0.02, 0.94 },    border = { 0.80, 0.65, 0.10, 0.9 } },
    glass   = { bg = { 0.10, 0.12, 0.16, 0.55 },    border = { 0.45, 0.55, 0.65, 0.6 } },
    minimal = { bg = { 0.00, 0.00, 0.00, 0.0 },     border = { 0.00, 0.00, 0.00, 0.0 } },
}
MiniHub.THEMES = THEMES
MiniHub.THEME_ORDER = { "dark", "gold", "glass", "minimal" }

local function doNothing() end
local function getName(f) return (f and f.GetName and f:GetName()) or nil end

--------------------------------------------------------------------------------
-- 1. Valeurs par defaut des SavedVariables
--------------------------------------------------------------------------------

local DEFAULTS = {
    point        = { "TOPRIGHT", "UIParent", "TOPRIGHT", -16, -260 }, -- position du conteneur (zone minicarte, pas au centre)
    mainPoint    = { "TOPRIGHT", "UIParent", "TOPRIGHT", -16, -220 }, -- position du bouton principal (sous la minicarte)
    isOpen       = false,         -- masqué après l'installation (conteneur fermé) ; rouvrable via l'onglet MiniHub de la barre TibiSuite
    orientation  = "VERTICAL",    -- "VERTICAL" ou "HORIZONTAL"
    perLine      = 6,             -- colonnes (vertical) / lignes (horizontal)
    buttonSize   = 32,            -- taille minimale de cellule
    spacing      = 4,
    padding      = 8,
    locked       = false,
    showTitle    = true,
    showMainButton = false,       -- pas de bouton flottant après l'installation (réactivable dans les options)
    mainButtonSize = 40,          -- taille du bouton principal (px)
    mainButtonAlpha = 1.0,        -- opacite du bouton principal (0-1)
    hideZoomButtons = true,       -- masquer le zoom +/- Blizzard

    -- Apparence / comportement
    theme        = "dark",        -- theme visuel (dark/gold/glass/minimal)
    hoverOpen    = false,         -- ouvrir au survol du bouton principal
    autoClose    = false,         -- fermer quand la souris quitte
    animate      = true,          -- fondu a l'ouverture
    hideInCombat = false,
    hideInInstance = false,
    hideInPetBattle = true,

    favorites    = {},            -- [nom] = true : boutons epingles
    customOrder  = {},            -- ordre manuel [nom] = index (reserve)

    bgColor      = { 0.045, 0.045, 0.055, 0.94 },
    borderColor  = { 0.18, 0.18, 0.20, 1.0 },

    exclusions   = {},            -- [nom] = true : boutons a laisser sur la minicarte
    whitelist    = {},            -- [nom] = true : boutons a collecter manuellement

    minimap      = { hide = false, minimapPos = 220, showInCompartment = true },
}

local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            ApplyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end

--------------------------------------------------------------------------------
-- 2. Detection des boutons d'addon
--------------------------------------------------------------------------------

-- Frames Blizzard nommees a exclure explicitement.
local BLIZZARD_EXACT = {
    ["LibDBIcon10_MiniHub"] = true,
    ["MiniHubMainButton"]   = true,
}

-- Motifs de noms des VRAIS boutons d'addon (liste blanche).
local BUTTON_PATTERNS = {
    "^LibDBIcon10_",
    "MinimapButton",
    "MinimapFrame",
    "MinimapIcon",
    "[-_]Minimap[-_]",
    "Minimap$",
}

-- Motifs des addons de "pins" / points d'interet (a NE PAS collecter).
local PIN_PATTERNS = {
    "^HandyNotes", "^TomTom", "^HereBeDragons", "^Questie",
    "^GatherMate", "^Gatherer", "^RareScanner", "^WorldQuest",
    "^pin", "^Pin",
}

local function matchesAny(name, patterns)
    for _, p in ipairs(patterns) do
        if strmatch(name, p) then return true end
    end
    return false
end

-- Le global de ce nom est-il protege par Blizzard ? (frame native)
local function isSecureName(name)
    local ok, secure = pcall(issecurevariable, _G, name)
    return ok and secure == true
end

local function isBlacklistedByUser(name)
    return name ~= nil and MiniHubDB.exclusions[name] == true
end

-- Les boutons TomCats se terminent par l'annee courante : on les autorise
-- malgre la regle "se termine par un chiffre".
local function isTomCatsButton(name)
    return strmatch(name, "^TomCats%-") ~= nil
end

local function nameEndsWithNumber(name)
    return strmatch(name, "%d$") ~= nil
end

-- Un enfant de la minicarte est-il un vrai bouton d'addon a collecter ?
local function isMinimapButton(frame)
    if type(frame) ~= "table" or not frame.IsObjectType then return false end
    if not frame:IsObjectType("Frame") then return false end

    local name = getName(frame)
    if not name then return false end
    if BLIZZARD_EXACT[name] then return false end
    if isSecureName(name) then return false end           -- frame Blizzard protegee
    if isTomCatsButton(name) then return true end
    if nameEndsWithNumber(name) then return false end      -- ecarte les pins numerotes

    return matchesAny(name, BUTTON_PATTERNS)
        and not matchesAny(name, PIN_PATTERNS)
end

--------------------------------------------------------------------------------
-- 3. Collecte
--------------------------------------------------------------------------------

MiniHub.order     = MiniHub.order or {}     -- liste ordonnee des boutons collectes
MiniHub.collected = MiniHub.collected or {} -- [button] = etat affiche (bool)

local container      -- panneau conteneur
local mainButton     -- bouton logo deplacable
local masterCreated  -- bouton maitre LibDBIcon enregistre

-- Relance la disposition si la visibilite d'un bouton a change.
local function OnButtonVisibilityChanged(frame)
    local shown = frame:IsShown()
    if MiniHub.collected[frame] ~= nil and MiniHub.collected[frame] ~= shown then
        MiniHub.collected[frame] = shown
        MiniHub.Layout()
    end
end

-- Neutralise les methodes qui permettraient a un addon de deplacer/reparenter
-- son bouton hors du conteneur. On repositionne ensuite via les methodes
-- "brutes" (rawSetPoint, etc.). Mettre le champ a nil plus tard restaure la
-- methode d'origine (heritee de la metatable).
local function LockButton(button)
    button.ClearAllPoints = doNothing
    button.SetPoint       = doNothing
    button.SetParent      = doNothing
    button.SetScale       = doNothing
end

local function IsCollected(button)
    return MiniHub.collected[button] ~= nil
end

-- Collecte effective d'un bouton.
local function CollectButton(button)
    if type(button) ~= "table" or IsCollected(button) then return false end
    local name = getName(button)
    if name and isBlacklistedByUser(name) then return false end
    if not container then return false end

    rawSetParent(button, container.content)
    if button.SetFrameStrata then button:SetFrameStrata("MEDIUM") end
    if button.SetScript then
        pcall(button.SetScript, button, "OnDragStart", nil)
        pcall(button.SetScript, button, "OnDragStop", nil)
    end
    rawSetScale(button, 1)

    -- Suivi de la visibilite (sans OnUpdate) : on relance la grille quand le
    -- bouton s'affiche ou se masque de lui-meme.
    if type(button.Show) == "function" then pcall(hooksecurefunc, button, "Show", OnButtonVisibilityChanged) end
    if type(button.Hide) == "function" then pcall(hooksecurefunc, button, "Hide", OnButtonVisibilityChanged) end

    LockButton(button)

    tinsert(MiniHub.order, button)
    MiniHub.collected[button] = button:IsShown()
    return true
end

-- Collecte tous les boutons LibDBIcon (source la plus fiable).
local function CollectLibDBIconButtons()
    local lib = LDBIcon or (LibStub and LibStub("LibDBIcon-1.0", true))
    if not lib or type(lib.GetButtonList) ~= "function" then return end
    for _, buttonName in ipairs(lib:GetButtonList()) do
        if buttonName ~= "MiniHub" then
            local button = lib:GetMinimapButton(buttonName)
            if button then CollectButton(button) end
        end
    end
end

-- Collecte les enfants directs de la minicarte qui ressemblent a des boutons.
local function ScanMinimapChildren()
    local ok, results = pcall(function() return { Minimap:GetChildren() } end)
    if not ok then return end
    for _, child in ipairs(results) do
        if not IsCollected(child) and isMinimapButton(child) then
            CollectButton(child)
        end
    end
end

-- Collecte les boutons ajoutes manuellement (liste blanche par nom global).
local function CollectWhitelisted()
    for name in pairs(MiniHubDB.whitelist) do
        local button = _G[name]
        if type(button) == "table" and button.IsObjectType
            and button:IsObjectType("Frame") and not IsCollected(button) then
            CollectButton(button)
        end
    end
end

local function SortCollected()
    tsort(MiniHub.order, function(a, b)
        return (getName(a) or "") < (getName(b) or "")
    end)
end

-- Addons connus qui font DEJA leur propre balayage generique de
-- Minimap:GetChildren() pour regrouper les boutons tiers (comme MiniHub) :
-- ElvUI et Tukui ont tous les deux un module "bouton minicarte" integre qui
-- reparente/masque les icones d'autres addons exactement comme MiniHub le
-- ferait. Faire tourner les deux en meme temps ne casse rien de grave
-- (reparentage en boucle, scintillement au pire), mais MiniHub se retrouve
-- avec 0 bouton a collecter (l'autre UI les a deja pris) et affiche un
-- conteneur vide et inutile - confirme en jeu par l'utilisateur (testeur
-- ElvUI + EllesmereUI). On laisse donc la priorite a l'autre addon plutot
-- que de rentrer en conflit ou d'afficher un panneau vide.
local CONFLICTING_COLLECTORS = { "EllesmereUIMinimap", "ElvUI", "Tukui" }
local function HasConflictingCollector()
    for _, name in ipairs(CONFLICTING_COLLECTORS) do
        if C_AddOns.IsAddOnLoaded(name) then return name end
    end
    return nil
end

-- Point d'entree : collecte toutes les sources puis met a jour la grille.
-- CORRECTIF : sous ElvUI/EllesmereUI, ces addons reparentent/skinnent deja
-- les boutons de la minicarte avant que MiniHub ne passe - une frame
-- inhabituelle qu'ils y laissent peut faire echouer un GetWidth/GetHeight
-- au milieu de Layout() (aucun pcall avant ce correctif), laissant le
-- conteneur fige a sa taille par defaut (60x60, titre tronque, croix qui
-- deborde) plutot que dans son etat "vide" propre - confirme en jeu. On
-- protege desormais tout le cycle collecte+disposition par un pcall.
function MiniHub.Collect()
    if not container then return end
    local ok, err = pcall(function()
        local before = #MiniHub.order
        CollectLibDBIconButtons()
        CollectWhitelisted()
        if not HasConflictingCollector() then
            ScanMinimapChildren()
        end
        if #MiniHub.order ~= before then
            SortCollected()
        end
        MiniHub.Layout()
    end)
    if not ok then
        print("|cffffd200MiniHub|r : " .. tostring(err))
    end
end

-- Alias historique utilise par les options / slash.
MiniHub.Scan = MiniHub.Collect

-- Libere un bouton collecte (retour a la minicarte). Un /reload est conseille
-- pour un rendu parfait.
function MiniHub.Release(button)
    if not IsCollected(button) then return end
    MiniHub.collected[button] = nil
    for i, b in ipairs(MiniHub.order) do
        if b == button then tremove(MiniHub.order, i) break end
    end
    -- Restaure les methodes neutralisees (nil -> methode heritee de la metatable).
    button.ClearAllPoints = nil
    button.SetPoint       = nil
    button.SetParent      = nil
    button.SetScale       = nil

    local name = getName(button)
    local shortName = name and name:match("^LibDBIcon10_(.+)$")
    local lib = LDBIcon or (LibStub and LibStub("LibDBIcon-1.0", true))

    if shortName and lib and lib.GetMinimapButton and lib:GetMinimapButton(shortName) then
        -- Bouton LibDBIcon : on laisse la lib le replacer proprement sur le
        -- bord de la minicarte (a son angle sauvegarde), sans /reload.
        pcall(function()
            button:SetParent(Minimap)
            button:SetFrameStrata("MEDIUM")
            lib:Refresh(shortName)
        end)
    else
        -- Autre bouton : retour a la minicarte, au mieux.
        pcall(function()
            button:SetParent(Minimap)
            button:ClearAllPoints()
            button:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
        end)
    end
    MiniHub.Layout()
end

--------------------------------------------------------------------------------
-- 4. Disposition en grille (uniquement les boutons affiches)
--------------------------------------------------------------------------------

function MiniHub.Layout()
    if not container then return end
    local db = MiniHubDB

    -- On ne dispose QUE les boutons actuellement affiches.
    local shown = {}
    for _, b in ipairs(MiniHub.order) do
        if b.IsShown and b:IsShown() then shown[#shown + 1] = b end
    end
    local n = #shown

    -- Taille de cellule uniforme = plus grand bouton affiche (mini = buttonSize).
    local cell = db.buttonSize or 32
    for _, b in ipairs(shown) do
        local s = (b.GetScale and b:GetScale()) or 1
        local w = ((b.GetWidth and b:GetWidth()) or 0) * s
        local h = ((b.GetHeight and b:GetHeight()) or 0) * s
        cell = max(cell, w, h)
    end

    local sp      = db.spacing
    local pad     = db.padding
    local perLine = max(1, db.perLine)
    local headerH = db.showTitle and HEADER_H or 0

    -- Nombre de colonnes / lignes reellement utilisees.
    local cols, rows
    if db.orientation == "HORIZONTAL" then
        cols = max(ceil(n / perLine), 1)
        rows = max(ceil(n / cols), 1)
    else
        rows = max(ceil(n / perLine), 1)
        cols = max(ceil(n / rows), 1)
    end

    for i, b in ipairs(shown) do
        local idx = i - 1
        local cx, cy
        if db.orientation == "HORIZONTAL" then
            cy = floor(idx / cols); cx = idx % cols
        else
            cx = floor(idx / rows); cy = idx % rows
        end
        local x = pad + cx * (cell + sp) + cell / 2
        local y = headerH + pad + cy * (cell + sp) + cell / 2
        local scale = (b.GetScale and b:GetScale()) or 1
        rawClearAllPoints(b)
        rawSetPoint(b, "CENTER", container, "TOPLEFT", x / scale, -y / scale)
        if b.Show then b:Show() end
    end

    local width  = pad * 2 + cols * cell + (cols - 1) * sp
    local height = headerH + pad * 2 + rows * cell + (rows - 1) * sp
    if n == 0 then
        width  = max(width, 130)
        height = headerH + 30
    end
    container:SetSize(max(width, 40), max(height, headerH + 22))

    container.title:SetShown(db.showTitle)
    if container.header then container.header:SetShown(db.showTitle) end
    if container.sep then container.sep:SetShown(db.showTitle) end
    local conflict = HasConflictingCollector()
    if n == 0 and conflict then
        container.empty:SetText(string.format(L["EMPTY_CONFLICT"], conflict))
    else
        container.empty:SetText(L["EMPTY"])
    end
    container.empty:SetShown(n == 0)

    if MiniHub.ApplySkin then MiniHub.ApplySkin() end
end

--------------------------------------------------------------------------------
-- 5. Conteneur (panneau theme) et bouton principal deplacable
--------------------------------------------------------------------------------

local function ApplyGradient(tex)
    if tex.SetGradient and CreateColor then
        local ok = pcall(tex.SetGradient, tex, "VERTICAL",
            CreateColor(0.14, 0.14, 0.17, 0.0),
            CreateColor(0.16, 0.16, 0.20, 0.55))
        if ok then return true end
    end
    return false
end

local function CreateContainer()
    local f = CreateFrame("Frame", "MiniHubContainer", UIParent, "BackdropTemplate")
    f:SetSize(60, 60)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)

    if f.SetBackdrop then
        f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    end

    -- Fond plein (toujours rendu).
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    f.bg:SetColorTexture(0.045, 0.045, 0.055, 0.94)

    -- Degrade discret.
    f.grad = f:CreateTexture(nil, "BORDER")
    f.grad:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.grad:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    f.grad:SetHeight(46)
    f.grad:SetColorTexture(1, 1, 1, 1)
    if not ApplyGradient(f.grad) then
        f.grad:SetColorTexture(0.15, 0.15, 0.18, 0.22)
    end

    -- Bandeau de titre + separateur.
    f.header = f:CreateTexture(nil, "ARTWORK")
    f.header:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    f.header:SetHeight(HEADER_H)
    f.header:SetColorTexture(0.09, 0.09, 0.11, 0.55)

    f.sep = f:CreateTexture(nil, "ARTWORK")
    f.sep:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 2, 0)
    f.sep:SetPoint("TOPRIGHT", f.header, "BOTTOMRIGHT", -2, 0)
    f.sep:SetHeight(1)
    f.sep:SetColorTexture(0.30, 0.30, 0.34, 0.55)

    -- Zone de contenu (parent des boutons collectes).
    f.content = CreateFrame("Frame", nil, f)
    f.content:SetAllPoints(f)

    -- Titre dore.
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("LEFT", f.header, "LEFT", 7, 0)
    f.title:SetText("MiniHub")
    f.title:SetTextColor(0.988, 0.843, 0.282)  -- or vif (accent MiniHub)

    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.empty:SetPoint("BOTTOM", f, "BOTTOM", 0, 6)
    f.empty:SetText(L["EMPTY"])
    f.empty:Hide()

    -- Animation de fondu a l'ouverture.
    f.fadeIn = f:CreateAnimationGroup()
    local a = f.fadeIn:CreateAnimation("Alpha")
    a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.18); a:SetOrder(1)
    f.fadeIn:SetScript("OnFinished", function() f:SetAlpha(1) end)

    -- Bouton de fermeture rouge.
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 1, 1)
    close:SetScript("OnClick", function() MiniHub.Close() end)
    f.close = close

    -- Deplacement manuel du conteneur (via le bandeau).
    local function DragUpdate(self)
        local scale = self:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx, cy = cx / scale, cy / scale
        self:ClearAllPoints()
        self:SetPoint(self._dp, UIParent, self._drp,
            self._dx + (cx - self._sx), self._dy + (cy - self._sy))
    end
    f:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or MiniHubDB.locked then return end
        local scale = self:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        self._sx, self._sy = cx / scale, cy / scale
        local p, _, rp, x, y = self:GetPoint()
        self._dp, self._drp, self._dx, self._dy = p or "CENTER", rp or "CENTER", x or 0, y or 0
        self:SetScript("OnUpdate", DragUpdate)
    end)
    local function stop(self)
        if not self:GetScript("OnUpdate") then return end
        self:SetScript("OnUpdate", nil)
        local p, _, rp, x, y = self:GetPoint()
        if p then MiniHubDB.point = { p, "UIParent", rp, x, y } end
    end
    f:SetScript("OnMouseUp", function(self, b) if b == "LeftButton" then stop(self) end end)
    f:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)

    -- Fermeture automatique quand la souris quitte l'ensemble.
    f:HookScript("OnLeave", function() MiniHub.ScheduleAutoClose() end)

    return f
end

-- Ameliore la nettete d'une texture logo (desactive l'accrochage a la grille
-- de pixels qui cree l'aspect "pixelise" aux tailles non entieres).
local function SmoothTexture(tex)
    if not tex then return end
    pcall(function() tex:SetSnapToPixelGrid(false) end)
    pcall(function() tex:SetTexelSnappingBias(0) end)
end
MiniHub.SmoothTexture = SmoothTexture

-- Bouton principal deplacable portant le logo (facon MinimapButton).
local function CreateMainButton()
    -- Pas de BackdropTemplate : le bouton n'a aucun cadre, seul le logo (fond
    -- transparent) est visible.
    local b = CreateFrame("Button", "MiniHubMainButton", UIParent)
    b:SetSize(40, 40)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetClampedToScreen(true)
    b:RegisterForClicks("AnyUp")

    -- Le logo remplit tout le bouton (emblème détouré, sans carré ni bordure).
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(b)
    icon:SetTexture(LOGO)
    SmoothTexture(icon)
    b.icon = icon

    -- Legere surbrillance au survol (sans cadre).
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture(LOGO)
    hl:SetVertexColor(1, 1, 1, 0.25)
    SmoothTexture(hl)

    -- Deplacement : glisser a la souris (bouton gauche) quand non verrouille.
    -- Un simple clic (souris quasi immobile) NE compte PAS comme un deplacement :
    -- on n'active le glissement qu'au-dela d'un petit seuil, sinon OnMouseUp
    -- declenche l'ouverture/fermeture.
    local function DragUpdate(self)
        local scale = self:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx, cy = cx / scale, cy / scale
        local dx, dy = cx - self._sx, cy - self._sy
        if not self._moved and (dx * dx + dy * dy) < 16 then return end -- < 4 px : encore un clic
        self._moved = true
        self:ClearAllPoints()
        self:SetPoint(self._dp, UIParent, self._drp, self._dx + dx, self._dy + dy)
    end
    b:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self._moved = false
        if not MiniHubDB.locked then
            local scale = self:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            self._sx, self._sy = cx / scale, cy / scale
            local p, _, rp, x, y = self:GetPoint()
            self._dp, self._drp, self._dx, self._dy = p or "CENTER", rp or "CENTER", x or 0, y or 0
            self:SetScript("OnUpdate", DragUpdate)
        end
    end)
    b:SetScript("OnMouseUp", function(self, button)
        self:SetScript("OnUpdate", nil)
        if button == "LeftButton" then
            if self._moved then
                local p, _, rp, x, y = self:GetPoint()
                if p then MiniHubDB.mainPoint = { p, "UIParent", rp, x, y } end
            else
                MiniHub.Toggle()
            end
        elseif button == "RightButton" then
            MiniHub.OpenOptions()
        end
    end)
    b:SetScript("OnEnter", function(self)
        if MiniHubDB.hoverOpen and container and not container:IsShown() then
            MiniHub.Open()
        end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("MiniHub")
        GameTooltip:AddLine(L["TT_LEFT_TOGGLE"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["TT_DRAG_MOVE"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["TT_RIGHT_OPTIONS"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
        MiniHub.ScheduleAutoClose()
    end)

    return b
end

function MiniHub.ApplySkin()
    if not container then return end
    local db = MiniHubDB
    local bg, bd = db.bgColor, db.borderColor
    if container.bg then container.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4]) end
    if container.SetBackdropBorderColor then
        container:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
    end
end

-- Applique un theme predefini (ecrase les couleurs de fond/bordure).
function MiniHub.ApplyTheme(name)
    local theme = THEMES[name]
    if not theme then return end
    MiniHubDB.theme = name
    MiniHubDB.bgColor     = { theme.bg[1], theme.bg[2], theme.bg[3], theme.bg[4] }
    MiniHubDB.borderColor = { theme.border[1], theme.border[2], theme.border[3], theme.border[4] }
    MiniHub.ApplySkin()
end

-- Applique taille et opacite au bouton principal. L'icone garde une marge
-- proportionnelle et reste nette a toutes les tailles.
function MiniHub.ApplyMainButtonStyle()
    if not mainButton then return end
    local size  = MiniHubDB.mainButtonSize or 40
    local alpha = MiniHubDB.mainButtonAlpha or 1.0
    -- L'icone remplit le bouton (SetAllPoints) : redimensionner le bouton suffit.
    mainButton:SetSize(size, size)
    if mainButton.icon then SmoothTexture(mainButton.icon) end
    mainButton:SetAlpha(alpha)
end

function MiniHub.RestorePosition()
    if container then
        local p = MiniHubDB.point
        container:ClearAllPoints()
        if p and p[1] then
            container:SetPoint(p[1], UIParent, p[3] or p[1], p[4] or 0, p[5] or 0)
        else
            container:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -260)
        end
    end
    if mainButton then
        local p = MiniHubDB.mainPoint
        mainButton:ClearAllPoints()
        if p and p[1] then
            mainButton:SetPoint(p[1], UIParent, p[3] or p[1], p[4] or 0, p[5] or 0)
        else
            mainButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -220)
        end
        MiniHub.ApplyMainButtonStyle()
        MiniHub.UpdateMainButtonVisibility()
    end
end

-- Le bouton principal disparait si MiniHub tourne comme module de TibiSuite
-- (seule l'icone de minicarte reste), ou selon l'option showMainButton.
function MiniHub.UpdateMainButtonVisibility()
    if not mainButton then return end
    if MiniHub.isTibiSuiteModule then
        mainButton:Hide()
    else
        mainButton:SetShown(MiniHubDB.showMainButton)
    end
end

--------------------------------------------------------------------------------
-- 6. Ouverture / fermeture
--------------------------------------------------------------------------------

function MiniHub.Open()
    if not container then return end
    MiniHubDB.isOpen = true
    MiniHub.Collect()
    container:Show()
    -- Fondu a l'ouverture.
    if MiniHubDB.animate then
        container:SetAlpha(0)
        if container.fadeIn then container.fadeIn:Stop() end
        if container.fadeIn then container.fadeIn:Play() else container:SetAlpha(1) end
    else
        container:SetAlpha(1)
    end
end

function MiniHub.Close()
    if not container then return end
    MiniHubDB.isOpen = false
    container:Hide()
end

function MiniHub.Toggle()
    if not container then return end
    if container:IsShown() then MiniHub.Close() else MiniHub.Open() end
end

-- Fonction globale de bascule, exposee pour TibiSuite (champ toggleFn du
-- module). L'onglet TibiSuite peut ainsi ouvrir/fermer le conteneur MiniHub
-- par la voie officielle, sans manipuler directement la frame.
function MiniHub_Toggle()
    if MiniHub and MiniHub.Toggle then MiniHub.Toggle() end
end

-- Fermeture differee si la souris n'est ni sur le conteneur ni sur le bouton.
local closeTimer
local function IsMouseOverMiniHub()
    if container and container:IsShown() and container:IsMouseOver() then return true end
    if mainButton and mainButton:IsShown() and mainButton:IsMouseOver() then return true end
    return false
end
function MiniHub.ScheduleAutoClose()
    if not MiniHubDB.autoClose then return end
    if closeTimer then closeTimer:Cancel() end
    closeTimer = C_Timer.NewTimer(0.4, function()
        if MiniHubDB.autoClose and not IsMouseOverMiniHub() then
            MiniHub.Close()
        end
    end)
end

function MiniHub.OpenOptions()
    if InCombatLockdown() then
        print("|cffffd200MiniHub|r : " .. L["MSG_COMBAT_OPTIONS"])
        return
    end
    if MiniHub.OpenSettings then MiniHub.OpenSettings() end
end

--------------------------------------------------------------------------------
-- 7. Bouton maitre LibDBIcon (autour de la minicarte) + AddonCompartment
--------------------------------------------------------------------------------

local function CreateMasterButton()
    if masterCreated or not LDB then return end
    local dataobj = LDB:NewDataObject("MiniHub", {
        type  = "launcher",
        icon  = LOGO,
        label = "MiniHub",
        OnClick = function(_, button)
            if button == "LeftButton" then MiniHub.Toggle()
            elseif button == "RightButton" then MiniHub.OpenOptions()
            elseif button == "MiddleButton" then MiniHub.Collect() end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("MiniHub")
            tt:AddLine(L["TT_LEFT_TOGGLE"], 0.8, 0.8, 0.8)
            tt:AddLine(L["TT_RIGHT_OPTIONS"], 0.8, 0.8, 0.8)
            tt:AddLine(L["TT_MIDDLE_RESCAN"], 0.8, 0.8, 0.8)
        end,
    })
    if LDBIcon and dataobj then
        LDBIcon:Register("MiniHub", dataobj, MiniHubDB.minimap, LOGO)
        masterCreated = true
        MiniHub.masterButton = _G["LibDBIcon10_MiniHub"]
        -- Rend l'icone de minicarte nette elle aussi.
        if MiniHub.masterButton and MiniHub.masterButton.icon then
            SmoothTexture(MiniHub.masterButton.icon)
        end
    end
end

function MiniHub.SetMasterShown(shown)
    MiniHubDB.minimap.hide = not shown
    if LDBIcon then
        if shown then LDBIcon:Show("MiniHub") else LDBIcon:Hide("MiniHub") end
    end
end

--------------------------------------------------------------------------------
-- 8. Masquage des boutons de zoom Blizzard
--------------------------------------------------------------------------------

local zoomFrames
local function CollectZoomFrames()
    if zoomFrames then return zoomFrames end
    zoomFrames = {}
    local function add(f) if f and f.Hide then zoomFrames[#zoomFrames + 1] = f end end
    add(_G.MinimapZoomIn); add(_G.MinimapZoomOut)
    if Minimap then add(Minimap.ZoomIn); add(Minimap.ZoomOut) end
    local mc = _G.MinimapCluster
    if mc then add(mc.ZoomIn); add(mc.ZoomOut) end
    return zoomFrames
end

-- PIEGE POTENTIEL (voir ADDON_ACTION_FORBIDDEN "SpellStopCasting"/
-- "SpellStopTargeting" trace via /etrace, table partagee entre
-- GameMenuFrame.Shown et PlunderstormQueueTutorial.Update) : MinimapCluster
-- fait partie du meme groupe de gestion de fenetres que la zone de file
-- d'attente. Appeler self:Hide() DIRECTEMENT depuis le hook OnShow execute
-- notre code de facon synchrone dans la pile d'appels de Blizzard, ce qui
-- peut contaminer ce que Blizzard fait ensuite dans ce meme tick. On differe
-- donc l'appel via C_Timer.After(0, ...) pour sortir de cette pile et agir
-- dans un tick propre, exactement comme UISpecialFrames evite le meme piege
-- sur Echap (voir TibiSuiteCore.lua).
function MiniHub.ApplyBlizzardHiding()
    local hide = MiniHubDB.hideZoomButtons
    for _, f in ipairs(CollectZoomFrames()) do
        if not f._minihubHooked and f.HookScript then
            f:HookScript("OnShow", function(self)
                if MiniHubDB.hideZoomButtons then
                    C_Timer.After(0, function() self:Hide() end)
                end
            end)
            f._minihubHooked = true
        end
        if hide then if f.Hide then f:Hide() end else if f.Show then f:Show() end end
    end
end

-- Regles contextuelles : masque le conteneur et le bouton principal en combat,
-- en donjon/raid ou pendant un combat de mascottes, selon les options.
function MiniHub.UpdateContextVisibility()
    if not container then return end
    local hide = false
    if MiniHubDB.hideInCombat and InCombatLockdown() then hide = true end
    if MiniHubDB.hideInInstance and IsInInstance() then hide = true end
    if MiniHubDB.hideInPetBattle and C_PetBattles and C_PetBattles.IsInBattle() then hide = true end

    if hide then
        container:Hide()
        if mainButton then mainButton:Hide() end
    else
        if MiniHubDB.isOpen then container:Show() else container:Hide() end
        MiniHub.UpdateMainButtonVisibility()
    end
end

local function SetupContextRules()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    if C_PetBattles then
        f:RegisterEvent("PET_BATTLE_OPENING_START")
        f:RegisterEvent("PET_BATTLE_CLOSE")
    end
    f:SetScript("OnEvent", function() MiniHub.UpdateContextVisibility() end)
end

--------------------------------------------------------------------------------
-- 9. Integration TibiSuite (optionnelle, sans dependance dure)
--------------------------------------------------------------------------------

function MiniHub.TryRegisterWithTibiSuite()
    local suite = _G.TibiSuite
    if not suite then
        MiniHub.isTibiSuiteModule = false
        return false
    end
    MiniHub.isTibiSuiteModule = true
    local ok = pcall(function()
        if type(suite.RegisterModule) == "function" then
            suite:RegisterModule("MiniHub", MiniHub)
        elseif type(suite.Register) == "function" then
            suite:Register("MiniHub", MiniHub)
        elseif type(suite.modules) == "table" then
            suite.modules["MiniHub"] = MiniHub
        end
    end)
    -- Sous TibiSuite, on retire le bouton UI : seule l'icone de minicarte reste.
    if MiniHub.UpdateMainButtonVisibility then MiniHub.UpdateMainButtonVisibility() end
    return ok
end

--------------------------------------------------------------------------------
-- 10. Scan differe et evenements (sans OnUpdate permanent)
--------------------------------------------------------------------------------

local function ScheduleDeferredScans()
    for _, delay in ipairs({ 1, 3, 6, 10, 15, 25 }) do
        C_Timer.After(delay, function() MiniHub.Collect() end)
    end
    if LDBIcon and LDBIcon.RegisterCallback then
        pcall(function()
            LDBIcon.RegisterCallback(MiniHub, "LibDBIcon_IconCreated", function(_, button, name)
                if name == "MiniHub" then return end
                C_Timer.After(0.1, function()
                    if CollectButton(button) then SortCollected(); MiniHub.Layout() end
                end)
            end)
        end)
    end
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", function()
        C_Timer.After(0.5, function() MiniHub.Collect() end)
    end)
end

--------------------------------------------------------------------------------
-- 11. Assistant boutons non reconnus + profils
--------------------------------------------------------------------------------

-- Renvoie la liste des noms de boutons qui ressemblent a des boutons d'addon
-- mais n'ont pas ete collectes (nom non conforme aux motifs). L'utilisateur
-- peut les collecter en un clic depuis les options.
function MiniHub.GetUnrecognized()
    local list = {}
    local ok, results = pcall(function() return { Minimap:GetChildren() } end)
    if not ok then return list end
    for _, child in ipairs(results) do
        if not IsCollected(child) and type(child) == "table" and child.GetObjectType then
            local otype = child:GetObjectType()
            if otype == "Button" or otype == "Frame" then
                local name = getName(child)
                if name and not isSecureName(name) and not BLIZZARD_EXACT[name]
                    and not matchesAny(name, PIN_PATTERNS)
                    and not MiniHubDB.whitelist[name]
                    and not isMinimapButton(child) then
                    local w = (child.GetWidth and child:GetWidth()) or 0
                    local shown = child.IsShown and child:IsShown()
                    local hasClick = child.HasScript and (
                        (child:HasScript("OnClick") and child:GetScript("OnClick")) or
                        (child:HasScript("OnMouseUp") and child:GetScript("OnMouseUp")) or
                        (child:HasScript("OnMouseDown") and child:GetScript("OnMouseDown")))
                    local regions = (child.GetNumRegions and child:GetNumRegions()) or 0
                    if shown and w >= 15 and w <= 60 and hasClick and regions > 0 then
                        list[#list + 1] = name
                    end
                end
            end
        end
    end
    tsort(list)
    return list
end

-- Options exportables (visuel + comportement, pas les listes de boutons).
local EXPORT_KEYS = {
    "orientation", "perLine", "buttonSize", "spacing", "padding",
    "showTitle", "locked", "showMainButton", "mainButtonSize", "mainButtonAlpha",
    "hideZoomButtons", "theme", "hoverOpen", "autoClose", "animate",
    "hideInCombat", "hideInInstance", "hideInPetBattle",
}
local EXPORT_BOOL = {
    showTitle = true, locked = true, showMainButton = true, hideZoomButtons = true,
    hoverOpen = true, autoClose = true, animate = true,
    hideInCombat = true, hideInInstance = true, hideInPetBattle = true,
}
local EXPORT_NUM = {
    perLine = true, buttonSize = true, spacing = true, padding = true,
    mainButtonSize = true, mainButtonAlpha = true,
}

function MiniHub.ExportProfile()
    local db = MiniHubDB
    local parts = {}
    for _, k in ipairs(EXPORT_KEYS) do
        local v = db[k]
        if type(v) == "boolean" then v = v and "1" or "0" end
        parts[#parts + 1] = k .. "=" .. tostring(v)
    end
    local function col(c) return string.format("%.3f/%.3f/%.3f/%.3f", c[1], c[2], c[3], c[4]) end
    parts[#parts + 1] = "bg=" .. col(db.bgColor)
    parts[#parts + 1] = "bd=" .. col(db.borderColor)
    return "MH1:" .. table.concat(parts, ";")
end

function MiniHub.ImportProfile(str)
    if type(str) ~= "string" then return false end
    local body = str:match("^MH1:(.+)$")
    if not body then return false end
    local db = MiniHubDB
    for pair in body:gmatch("[^;]+") do
        local k, v = pair:match("^(%w+)=(.+)$")
        if k and v then
            if k == "bg" or k == "bd" then
                local r, g, b, a = v:match("([^/]+)/([^/]+)/([^/]+)/([^/]+)")
                if r then
                    local c = { tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or 1 }
                    if k == "bg" then db.bgColor = c else db.borderColor = c end
                end
            elseif k == "orientation" then
                if v == "VERTICAL" or v == "HORIZONTAL" then db.orientation = v end
            elseif k == "theme" then
                if THEMES[v] then db.theme = v end
            elseif EXPORT_BOOL[k] then
                db[k] = (v == "1")
            elseif EXPORT_NUM[k] then
                local n = tonumber(v); if n then db[k] = n end
            end
        end
    end
    -- Application immediate.
    MiniHub.ApplySkin()
    MiniHub.ApplyMainButtonStyle()
    MiniHub.ApplyBlizzardHiding()
    MiniHub.Layout()
    return true
end

--------------------------------------------------------------------------------
-- 12. Diagnostic + commandes slash
--------------------------------------------------------------------------------

function MiniHub.Dump()
    local ok, results = pcall(function() return { Minimap:GetChildren() } end)
    if not ok then print("|cffffd200MiniHub|r : erreur de lecture des enfants."); return end
    print("|cffffd200MiniHub|r - enfants de la minicarte (nom | affiche | collecte | verdict detection) :")
    for _, child in ipairs(results) do
        local name    = getName(child) or "<anonyme>"
        local shown   = (child.IsShown and child:IsShown()) and "affiche" or "masque"
        local coll    = IsCollected(child) and "|cff40ff40OUI|r" or "non"
        local verdict = isMinimapButton(child) and "|cff40ff40bouton|r" or "|cffff8040ignore|r"
        print(string.format("  %s | %s | %s | %s", name, shown, coll, verdict))
    end
    print("|cffffd200MiniHub|r - " .. #MiniHub.order .. " boutons collectes.")
end

local function HandleSlash(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd or ""
    if msg == "" or cmd == "toggle" then
        MiniHub.Toggle()
    elseif cmd == "open" then MiniHub.Open()
    elseif cmd == "close" then MiniHub.Close()
    elseif cmd == "scan" then
        MiniHub.Collect()
        print("|cffffd200MiniHub|r : " .. string.format(L["MSG_RESCAN"], #MiniHub.order))
    elseif cmd == "reset" then
        MiniHubDB.point = { "CENTER", "UIParent", "CENTER", 0, 0 }
        MiniHubDB.mainPoint = { "CENTER", "UIParent", "CENTER", 200, 0 }
        MiniHub.RestorePosition()
        print("|cffffd200MiniHub|r : " .. L["MSG_RESET"])
    elseif cmd == "config" or cmd == "options" then MiniHub.OpenOptions()
    elseif cmd == "debug" then MiniHub.Dump()
    elseif cmd == "block" and arg ~= "" then
        MiniHubDB.exclusions[arg] = true
        print("|cffffd200MiniHub|r : " .. string.format(L["MSG_BLOCK"], arg))
    elseif cmd == "unblock" and arg ~= "" then
        MiniHubDB.exclusions[arg] = nil
        MiniHub.Collect()
        print("|cffffd200MiniHub|r : " .. string.format(L["MSG_UNBLOCK"], arg))
    elseif cmd == "add" and arg ~= "" then
        MiniHubDB.whitelist[arg] = true
        MiniHub.Collect()
        print("|cffffd200MiniHub|r : " .. string.format(L["MSG_ADD"], arg))
    else
        print("|cffffd200MiniHub|r - " .. L["SLASH_HELP"])
        print("  /mh            " .. L["SLASH_TOGGLE"])
        print("  /mh scan       " .. L["SLASH_SCAN"])
        print("  /mh reset      " .. L["SLASH_RESET"])
        print("  /mh config     " .. L["SLASH_CONFIG"])
        print("  /mh debug      " .. L["SLASH_DEBUG"])
        print("  /mh block <name>  " .. L["SLASH_BLOCK"])
        print("  /mh add <name>    " .. L["SLASH_ADD"])
    end
end

SLASH_MINIHUB1 = "/minihub"
SLASH_MINIHUB2 = "/mh"
SlashCmdList["MINIHUB"] = HandleSlash

--------------------------------------------------------------------------------
-- 12. Initialisation
--------------------------------------------------------------------------------

local SETTINGS_VERSION = 4

local function Initialize()
    MiniHubDB = MiniHubDB or {}
    ApplyDefaults(MiniHubDB, DEFAULTS)

    if (MiniHubDB.settingsVersion or 0) < SETTINGS_VERSION then
        MiniHubDB.orientation = "VERTICAL"
        MiniHubDB.perLine     = 6
        MiniHubDB.buttonSize  = 32
        MiniHubDB.spacing     = 4
        MiniHubDB.padding     = 8
        MiniHubDB.bgColor     = { 0.045, 0.045, 0.055, 0.94 }
        MiniHubDB.borderColor = { 0.18, 0.18, 0.20, 1.0 }
        MiniHubDB.settingsVersion = SETTINGS_VERSION
    end

    container  = CreateContainer()
    mainButton = CreateMainButton()
    MiniHub.container  = container
    MiniHub.mainButton = mainButton
    MiniHub.ApplySkin()
    MiniHub.RestorePosition()

    CreateMasterButton()
    if MiniHubDB.minimap.hide and LDBIcon then LDBIcon:Hide("MiniHub") end

    if MiniHub.SetupOptions then MiniHub.SetupOptions() end
    MiniHub.TryRegisterWithTibiSuite()
    MiniHub.ApplyBlizzardHiding()
    SetupContextRules()

    MiniHub.Collect()
    -- ElvUI / Tukui / EllesmereUI gerent deja eux-memes les boutons de la
    -- minicarte : on ne rouvre pas automatiquement un conteneur qui n'aura
    -- rien a montrer (demande explicite - "autant ne pas l'installer" tant
    -- qu'il s'affichait vide/casse). Reste ouvrable manuellement via /minihub
    -- si l'utilisateur veut quand meme s'en servir (whitelist, etc.).
    local conflict = HasConflictingCollector()
    if conflict then
        container:Hide()
        print("|cFFFCD748MiniHub|r : " .. string.format(L["MSG_CONFLICT_LOGIN"], conflict))
    elseif MiniHubDB.isOpen then
        container:Show()
    else
        container:Hide()
    end
    MiniHub.UpdateContextVisibility()

    ScheduleDeferredScans()
    print("|cFFFCD748MiniHub|r v7.0 chargé -- tapez |cFFFFD700/minihub|r pour ouvrir.")
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    Initialize()
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- Rattrapage LoadOnDemand : quand TibiSuite charge ce module a la demande,
-- PLAYER_LOGIN est deja passe et le handler ci-dessus ne se declenchera plus.
-- On rejoue donc Initialize() (creation du conteneur, bouton principal, scan
-- des boutons de minicarte, restauration de la position) si la connexion est
-- deja effective. En chargement normal, IsLoggedIn() est faux ici et c'est le
-- handler PLAYER_LOGIN ci-dessus qui fait le travail. Aucun impact sur les donnees.
if IsLoggedIn() then
    loader:UnregisterEvent("PLAYER_LOGIN")
    Initialize()
end
