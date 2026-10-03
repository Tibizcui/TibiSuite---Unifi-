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
        (issecurevariable) ET des frames interdites (IsForbidden, 12.x) :
        jamais de frame native capturee, jamais d'erreur sur une frame
        qu'on n'a pas le droit de lire.
      - Collecte directe via LibDBIcon:GetButtonList() (rattrape tous les
        boutons LibDBIcon, meme parentes ailleurs).
      - Disposition qui ne place QUE les boutons affiches (les masques ne
        laissent pas de trou dans la grille), a taille de cellule uniforme.
      - Blocage du deplacement des boutons collectes (certains addons
        repositionnent leur bouton en continu).

    Performance (12.1) : la grille n'est recalculee qu'une fois par image au
    plus (RequestLayout), jamais tant que rien n'est visible, et les scans
    declenches par ADDON_LOADED sont regroupes (RequestScan).

    Fonctions : grille ou liste, tri par categorie, ordre manuel, favoris
    dans une barre rapide, mode tiroir accroche a la minicarte, addons du
    compartiment Blizzard, bouton TibiSuite rangeable dans le hub.

    Fonctionne en autonome OU comme module de la famille TibiSuite.
    Auteur : Tibiscui  -  https://tibiscui.fr
------------------------------------------------------------------------------]]

local ADDON_NAME, ns = ...

MiniHub = MiniHub or {}
local MiniHub = MiniHub
MiniHub._ns = ns

-- Table de localisation (Locale.lua + Locales\*.lua sont charges avant).
local L = MiniHub.L or setmetatable({}, { __index = function(_, k) return k end })

-- Libelles localises du raccourci clavier (lus par l'interface Blizzard).
_G["BINDING_HEADER_MINIHUB"]      = L["BINDING_HEADER"]
_G["BINDING_NAME_MINIHUB_TOGGLE"] = L["BINDING_TOGGLE"]

-- Version lue dans le .toc (plus de numero code en dur a oublier).
local function ReadVersion()
    local ok, v = pcall(function()
        return C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
    end)
    return (ok and v) or "?"
end
MiniHub.version = ReadVersion()

-- Bibliotheques (optionnelles : l'addon degrade proprement si absentes).
local LibStub = _G.LibStub
local LDB     = LibStub and LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

-- Raccourcis.
local CreateFrame, UIParent = CreateFrame, UIParent
local pairs, ipairs, next, type = pairs, ipairs, next, type
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local tinsert, tremove, tsort = table.insert, table.remove, table.sort
local strmatch, strlower = string.match, string.lower
local hooksecurefunc = hooksecurefunc

-- Methodes "brutes" recuperees sur UIParent : elles permettent de positionner
-- et redimensionner les boutons collectes MEME apres avoir neutralise leurs
-- propres methodes (anti-deplacement).
local rawSetPoint       = UIParent.SetPoint
local rawClearAllPoints = UIParent.ClearAllPoints
local rawSetScale       = UIParent.SetScale
local rawSetParent      = UIParent.SetParent

local LOGO = "Interface\\AddOns\\MiniHub\\media\\Logo_MiniHub.png"
local ACCENT = { 0.988, 0.843, 0.282 }   -- or vif (logo #FCD748)
local HEADER_H = 22
local CORE_BUTTON = "TibiSuiteMinimapBtn"

local function HasCore()
    return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end
MiniHub.HasCore = HasCore

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
local function getName(f)
    if type(f) ~= "table" or not f.GetName then return nil end
    local ok, n = pcall(f.GetName, f)
    return ok and n or nil
end

local function Print(msg) print("|cFFFCD748MiniHub|r : " .. tostring(msg)) end
MiniHub.Print = Print

--------------------------------------------------------------------------------
-- 1. Valeurs par defaut des SavedVariables
--------------------------------------------------------------------------------

local DEFAULTS = {
    point        = { "TOPRIGHT", "UIParent", "TOPRIGHT", -16, -260 }, -- position du conteneur (zone minicarte, pas au centre)
    mainPoint    = { "TOPRIGHT", "UIParent", "TOPRIGHT", -16, -220 }, -- position du bouton principal (sous la minicarte)
    quickPoint   = { "TOPRIGHT", "UIParent", "TOPRIGHT", -200, -16 }, -- position de la barre rapide
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

    -- Affichage (7.1.5.37)
    viewMode        = "GRID",     -- "GRID" (icones) ou "LIST" (icone + nom)
    listRows        = 10,         -- lignes par colonne en mode liste
    groupByCategory = false,      -- tri par categorie d'addon (## Category du .toc)

    -- Favoris / barre rapide (7.1.5.37)
    favorites    = {},            -- [nom] = true : boutons favoris
    customOrder  = {},            -- ordre manuel [nom] = index
    quickBar     = true,          -- les favoris vivent dans une barre toujours visible
    quickBarVertical = false,

    -- Mode tiroir (7.1.5.37)
    drawer       = false,         -- le hub sort du bord de la minicarte au survol
    drawerSide   = "LEFT",        -- "LEFT" / "BOTTOM" / "RIGHT"

    -- Sources supplementaires (7.1.5.37)
    compartment      = false,     -- addons presents seulement dans le compartiment Blizzard
    collectTibiSuite = false,     -- ranger le bouton TibiSuite dans le hub
    ignoreConflict   = false,     -- passer outre la pause (EllesmereUI / ElvUI / Tukui)

    bgColor      = { 0.045, 0.045, 0.055, 0.94 },
    borderColor  = { 0.18, 0.18, 0.20, 1.0 },

    exclusions   = {},            -- [nom] = true : boutons a laisser sur la minicarte
    whitelist    = {},            -- [nom] = true : boutons a collecter manuellement

    minimap      = { hide = false, minimapPos = 220, showInCompartment = true },
}
MiniHub.DEFAULTS = DEFAULTS

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

-- Frames a ne jamais collecter par le scan generique.
local BLIZZARD_EXACT = {
    ["LibDBIcon10_MiniHub"] = true,
    ["MiniHubMainButton"]   = true,
    [CORE_BUTTON]           = true,   -- gere a part (option collectTibiSuite)
}

-- Motifs de noms des VRAIS boutons d'addon (liste blanche).
local BUTTON_PATTERNS = {
    "^LibDBIcon10_",
    "MinimapButton",
    "MinimapBtn$",          -- convention des modules TibiSuite en autonome (DTMinimapBtn...)
    "MinimapFrame",
    "MinimapIcon",
    "[-_]Minimap[-_]",
    "Minimap$",
}

-- Motifs des addons de "pins" / points d'interet (a NE PAS collecter).
local PIN_PATTERNS = {
    "^HandyNotes", "^TomTom", "^HereBeDragons", "^Questie",
    "^GatherMate", "^Gatherer", "^RareScanner", "^WorldQuest",
    "^pin", "^Pin", "^MiniHub",
}

local function matchesAny(name, patterns)
    for _, p in ipairs(patterns) do
        if strmatch(name, p) then return true end
    end
    return false
end

-- 12.x : certains enfants de la minicarte sont des frames INTERDITES. Les lire
-- (GetName, IsObjectType...) leve une erreur. On les ecarte toujours en premier.
local function isForbidden(f)
    if type(f) ~= "table" then return true end
    if f.IsForbidden then
        local ok, forb = pcall(f.IsForbidden, f)
        if not ok or forb then return true end
    end
    return false
end
MiniHub.IsForbidden = isForbidden

-- Enfants d'une frame, sans les frames interdites, sans jamais lever d'erreur.
local function SafeChildren(parent)
    if type(parent) ~= "table" or not parent.GetChildren or isForbidden(parent) then return {} end
    local ok, res = pcall(function() return { parent:GetChildren() } end)
    if not ok or type(res) ~= "table" then return {} end
    local out = {}
    for _, c in ipairs(res) do
        if not isForbidden(c) then out[#out + 1] = c end
    end
    return out
end
MiniHub.SafeChildren = SafeChildren

-- Parents scannes : la minicarte et ses deux cadres voisins, ou certains
-- addons posent leur bouton.
local function ScanParents()
    return { _G.Minimap, _G.MinimapBackdrop, _G.MinimapCluster }
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

local function isMinimapButtonRaw(frame)
    if not frame.IsObjectType or not frame:IsObjectType("Frame") then return false end
    local name = getName(frame)
    if not name then return false end
    if BLIZZARD_EXACT[name] then return false end
    if isSecureName(name) then return false end           -- frame Blizzard protegee
    if isTomCatsButton(name) then return true end
    if strmatch(name, "%d$") then return false end         -- ecarte les pins numerotes
    return matchesAny(name, BUTTON_PATTERNS) and not matchesAny(name, PIN_PATTERNS)
end

-- Un enfant de la minicarte est-il un vrai bouton d'addon a collecter ?
local function isMinimapButton(frame)
    if isForbidden(frame) then return false end
    local ok, res = pcall(isMinimapButtonRaw, frame)
    return ok and res == true
end

--------------------------------------------------------------------------------
-- 3. Identite des boutons (nom lisible, addon, categorie, icone)
--------------------------------------------------------------------------------

-- Boutons des modules TibiSuite (mode autonome) et du core.
local SUITE_ADDON = {
    DTMinimapBtn = "DailyTracker", DGNMinimapBtn = "DgnTracker",
    LegTrackerMinimapBtn = "LegTracker", RNTMinimapBtn = "RenTracker",
    LvlHistoryMinimapButton = "LvlHistory", WeeklyCompassMinimapButton = "WeeklyCompass",
    SkillTrackerMinimapBtn = "SkillTracker", PostBoxMinimapBtn = "PostBox",
    RepBarMinimapBtn = "RepBar", LairLensMinimapBtn = "LairLens",
    OpacityMinimapBtn = "Opacity", LibDBIcon10_XPBar = "XPBar",
    [CORE_BUTTON] = "TibiSuite",
}

local function StripCodes(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    s = s:gsub("|T.-|t", "")
    s = s:gsub("|A.-|a", "")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    if s == "" then return nil end
    return s
end
MiniHub.StripCodes = StripCodes

-- Renvoie (nomInterne, titreLisible) si un addon de ce nom existe.
local function AddonLookup(name)
    if type(name) ~= "string" or name == "" or not C_AddOns then return nil end
    local ok, n, title = pcall(function()
        if C_AddOns.DoesAddOnExist and not C_AddOns.DoesAddOnExist(name) then return nil end
        return C_AddOns.GetAddOnInfo(name)
    end)
    if ok and type(n) == "string" then return n, StripCodes(title) end
    return nil
end

local function AddonCategory(addon)
    if not (addon and C_AddOns and C_AddOns.GetAddOnMetadata) then return nil end
    local locale = GetLocale and GetLocale() or "enUS"
    for _, field in ipairs({ "Category-" .. locale, "Category", "X-Category" }) do
        local ok, v = pcall(C_AddOns.GetAddOnMetadata, addon, field)
        v = ok and StripCodes(v) or nil
        if v then return v end
    end
    return nil
end

local infoCache = setmetatable({}, { __mode = "k" })

-- Infos d'affichage d'un bouton collecte : { name, label, addon, category }.
function MiniHub.GetInfo(button)
    local c = infoCache[button]
    if c then return c end
    local gname = getName(button) or "?"
    local label, addon
    if button._mhVirtual then
        label = button._mhLabel or gname
    else
        addon = SUITE_ADDON[gname]
        local short = gname:match("^LibDBIcon10_(.+)$")
        local base
        if short then
            base = short
            local obj = LDB and LDB.GetDataObjectByName and LDB:GetDataObjectByName(short)
            if obj and type(obj.label) == "string" then base = StripCodes(obj.label) or short end
            if not addon and AddonLookup(short) then addon = short end
        elseif isTomCatsButton(gname) then
            base = "TomCats"
        else
            base = (gname:gsub("[_%-]?[Mm]ini[Mm]ap.*$", ""))
            if base == "" then base = gname end
            if not addon and AddonLookup(base) then addon = base end
        end
        label = base
        if addon then
            local _, title = AddonLookup(addon)
            if title then label = title end
        end
    end
    c = { name = gname, label = label or gname, addon = addon, category = AddonCategory(addon) }
    infoCache[button] = c
    return c
end

-- Texture representative d'un bouton (pour le gestionnaire).
function MiniHub.GetIcon(button)
    local function texOf(t)
        if type(t) == "table" and t.GetTexture then
            local ok, tex = pcall(t.GetTexture, t)
            if ok and tex then return tex end
        end
    end
    local direct = texOf(button.icon) or texOf(button.Icon)
    if direct then return direct end
    local ok, regions = pcall(function() return { button:GetRegions() } end)
    if ok then
        for _, layer in ipairs({ "ARTWORK", "BACKGROUND", "OVERLAY" }) do
            for _, r in ipairs(regions) do
                if r.IsObjectType and r:IsObjectType("Texture") and r:GetDrawLayer() == layer then
                    local tex = texOf(r)
                    if tex and not (type(tex) == "string" and (tex:find("Border") or tex:find("Highlight") or tex:find("Background"))) then
                        return tex
                    end
                end
            end
        end
    end
    return 134400   -- point d'interrogation
end

--------------------------------------------------------------------------------
-- 4. Collecte
--------------------------------------------------------------------------------

MiniHub.order     = MiniHub.order or {}     -- liste ordonnee des boutons collectes
MiniHub.collected = MiniHub.collected or {} -- [button] = etat affiche (bool)

local container      -- panneau conteneur
local mainButton     -- bouton logo deplacable
local quickBar       -- barre rapide des favoris
local glow           -- surbrillance (recherche)
local masterCreated  -- bouton maitre LibDBIcon enregistre
local labelPool = {} -- noms affiches en mode liste
local contextHidden = false
local pinnedOpen = false   -- ouvert volontairement (clic, slash) en mode tiroir

-- ---------------------------------------------------------------- Planification
-- Grille : au plus un recalcul par image, et seulement si quelque chose est
-- visible (sinon on note qu'il faudra le faire a la prochaine ouverture).
local layoutDirty, layoutScheduled = true, false
local layoutErrShown = false

local function SafeLayout()
    layoutScheduled = false
    local ok, err = pcall(MiniHub.Layout)
    if not ok and not layoutErrShown then
        layoutErrShown = true
        Print(err)
    end
end

local function QuickBarWanted()
    return MiniHubDB and MiniHubDB.quickBar and next(MiniHubDB.favorites) ~= nil
end

function MiniHub.RequestLayout()
    layoutDirty = true
    if layoutScheduled or not container then return end
    if not container:IsShown() and not QuickBarWanted() then
        -- Plus rien a montrer : la barre rapide vide disparait tout de suite.
        if quickBar and quickBar:IsShown() then quickBar:Hide() end
        return
    end
    layoutScheduled = true
    C_Timer.After(0, SafeLayout)
end

-- Scans : les rafales d'ADDON_LOADED (des dizaines au login) n'en declenchent
-- qu'un seul.
local scanTimer
function MiniHub.RequestScan(delay)
    if scanTimer then return end
    scanTimer = C_Timer.NewTimer(delay or 0.5, function()
        scanTimer = nil
        MiniHub.Collect()
    end)
end

-- Relance la disposition si la visibilite d'un bouton a change.
local function OnButtonVisibilityChanged(frame)
    local shown = frame:IsShown()
    if MiniHub.collected[frame] ~= nil and MiniHub.collected[frame] ~= shown then
        MiniHub.collected[frame] = shown
        MiniHub.RequestLayout()
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

local function UnlockButton(button)
    button.ClearAllPoints = nil
    button.SetPoint       = nil
    button.SetParent      = nil
    button.SetScale       = nil
end

local function IsCollected(button)
    return MiniHub.collected[button] ~= nil
end
MiniHub.IsCollected = IsCollected

-- Collecte effective d'un bouton.
local function CollectButton(button)
    if type(button) ~= "table" or IsCollected(button) or isForbidden(button) then return false end
    local name = getName(button)
    if name and isBlacklistedByUser(name) then return false end
    if not container then return false end

    local ok = pcall(function()
        rawSetParent(button, container.content)
        if button.SetFrameStrata then button:SetFrameStrata("MEDIUM") end
        -- On memorise les scripts de glisser d'origine pour pouvoir les rendre
        -- a la liberation (avant : perdus jusqu'au /reload).
        if button._mhDrag == nil and button.GetScript and button.HasScript and button:HasScript("OnDragStart") then
            button._mhDrag = { button:GetScript("OnDragStart") or false, button:GetScript("OnDragStop") or false }
        end
        if button.SetScript and button.HasScript and button:HasScript("OnDragStart") then
            button:SetScript("OnDragStart", nil)
            button:SetScript("OnDragStop", nil)
        end
        rawSetScale(button, 1)
    end)
    if not ok then return false end

    -- Suivi de la visibilite (sans OnUpdate), pose une seule fois par bouton.
    if not button._mhHooked then
        button._mhHooked = true
        if type(button.Show) == "function" then pcall(hooksecurefunc, button, "Show", OnButtonVisibilityChanged) end
        if type(button.Hide) == "function" then pcall(hooksecurefunc, button, "Hide", OnButtonVisibilityChanged) end
    end

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

-- Collecte les enfants directs de la minicarte (et voisins) qui ressemblent a
-- des boutons.
local function ScanMinimapChildren()
    for _, parent in ipairs(ScanParents()) do
        for _, child in ipairs(SafeChildren(parent)) do
            if not IsCollected(child) and isMinimapButton(child) then
                CollectButton(child)
            end
        end
    end
end

-- Collecte les boutons ajoutes manuellement (liste blanche par nom global).
local function CollectWhitelisted()
    for name in pairs(MiniHubDB.whitelist) do
        local button = _G[name]
        if type(button) == "table" and not isForbidden(button) and button.IsObjectType
            and button:IsObjectType("Frame") and not IsCollected(button) then
            CollectButton(button)
        end
    end
end

-- Bouton TibiSuite : range dans le hub seulement si l'option est cochee.
local function CollectCoreButton()
    local btn = _G[CORE_BUTTON]
    if not btn then return end
    if MiniHubDB.collectTibiSuite then
        if not IsCollected(btn) then CollectButton(btn) end
    elseif IsCollected(btn) then
        MiniHub.Release(btn)
    end
end

local function SortCollected()
    local db = MiniHubDB
    local co, favs = db.customOrder, db.favorites
    local group = db.groupByCategory
    tsort(MiniHub.order, function(a, b)
        local ia, ib = MiniHub.GetInfo(a), MiniHub.GetInfo(b)
        local fa, fb = favs[ia.name] and true or false, favs[ib.name] and true or false
        if fa ~= fb then return fa end
        if group then
            local ca, cb = ia.category or "\255", ib.category or "\255"
            if ca ~= cb then return ca < cb end
        end
        local oa, ob = co[ia.name], co[ib.name]
        if oa and ob then
            if oa ~= ob then return oa < ob end
        elseif oa then return true
        elseif ob then return false end
        local la, lb = strlower(ia.label), strlower(ib.label)
        if la ~= lb then return la < lb end
        return ia.name < ib.name
    end)
end
MiniHub.SortCollected = SortCollected

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
-- Resultat mis en cache (invalide a chaque ADDON_LOADED).
local CONFLICTING_COLLECTORS = { "EllesmereUIMinimap", "ElvUI", "Tukui" }
local conflictCache
local function HasConflictingCollector()
    if conflictCache == nil then
        conflictCache = false
        for _, name in ipairs(CONFLICTING_COLLECTORS) do
            if C_AddOns.IsAddOnLoaded(name) then conflictCache = name break end
        end
    end
    return conflictCache or nil
end
MiniHub.GetConflict = HasConflictingCollector

-- MODE PAUSE : un autre addon range deja les boutons. CORRECTIF (confirme en
-- jeu avec EllesmereUI) : avant, seul le scan de la minicarte etait coupe,
-- la collecte LibDBIcon continuait. MiniHub prenait donc les boutons ET
-- neutralisait leur SetParent, si bien qu'EllesmereUI ne pouvait plus les
-- ranger dans son propre panneau et les masquait : hub plein de boutons
-- invisibles, boutons perdus des deux cotes. Desormais MiniHub ne touche plus
-- a RIEN (ni boutons, ni zoom, ni barre rapide, ni tiroir), sauf si le
-- joueur coche explicitement "utiliser MiniHub quand meme" (ignoreConflict).
local function IsPaused()
    local c = HasConflictingCollector()
    if c and not (MiniHubDB and MiniHubDB.ignoreConflict) then return true, c end
    return false, c
end
MiniHub.IsPaused = IsPaused

-- Rend tous les boutons collectes a leur proprietaire (entree en pause).
local function ReleaseAll()
    local copy = {}
    for i, b in ipairs(MiniHub.order) do copy[i] = b end
    for _, b in ipairs(copy) do MiniHub.Release(b) end
end

-- Point d'entree : collecte toutes les sources puis met a jour la grille.
-- Tout le cycle est protege par un pcall (ElvUI/EllesmereUI peuvent laisser
-- sur la minicarte des frames inhabituelles, confirme en jeu).
function MiniHub.Collect()
    if not container then return end
    local ok, err = pcall(function()
        if IsPaused() then
            if #MiniHub.order > 0 then ReleaseAll() end
            MiniHub.RequestLayout()
            return
        end
        local before = #MiniHub.order
        CollectLibDBIconButtons()
        CollectWhitelisted()
        CollectCoreButton()
        ScanMinimapChildren()
        if MiniHub.CollectCompartment then MiniHub.CollectCompartment() end
        if #MiniHub.order ~= before then
            SortCollected()
            MiniHub.RequestLayout()
        elseif layoutDirty then
            MiniHub.RequestLayout()
        end
    end)
    if not ok then Print(err) end
end

-- Alias historique utilise par les options / slash.
MiniHub.Scan = MiniHub.Collect

-- Libere un bouton collecte (retour a la minicarte), sans /reload.
function MiniHub.Release(button)
    if not IsCollected(button) then return end
    MiniHub.collected[button] = nil
    for i, b in ipairs(MiniHub.order) do
        if b == button then tremove(MiniHub.order, i) break end
    end
    UnlockButton(button)

    -- Scripts de glisser d'origine.
    if type(button._mhDrag) == "table" then
        pcall(button.SetScript, button, "OnDragStart", button._mhDrag[1] or nil)
        pcall(button.SetScript, button, "OnDragStop", button._mhDrag[2] or nil)
    end
    button._mhDrag = nil

    local name = getName(button)
    local shortName = name and name:match("^LibDBIcon10_(.+)$")
    local lib = LDBIcon or (LibStub and LibStub("LibDBIcon-1.0", true))

    if button._mhVirtual then
        -- Bouton cree par MiniHub (compartiment) : simplement range.
        pcall(function() button:Hide(); button:SetParent(UIParent); button:ClearAllPoints() end)
    elseif name == CORE_BUTTON then
        -- Bouton TibiSuite : on le replace a son angle sauvegarde, comme le core.
        pcall(function()
            local angle = math.rad((TibiSuiteDB and TibiSuiteDB.mmAngle) or 200)
            local radius = (Minimap:GetWidth() / 2) + 10
            button:SetParent(Minimap)
            button:SetFrameStrata("MEDIUM")
            button:ClearAllPoints()
            button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
        end)
    elseif shortName and lib and lib.GetMinimapButton and lib:GetMinimapButton(shortName) then
        -- Bouton LibDBIcon : on laisse la lib le replacer proprement sur le
        -- bord de la minicarte (a son angle sauvegarde).
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
    MiniHub.RequestLayout()
end

-- Exclusion immediate (plus besoin de /reload).
function MiniHub.SetExcluded(name, excluded)
    if not name then return end
    MiniHubDB.exclusions[name] = excluded and true or nil
    if excluded then
        for _, b in ipairs(MiniHub.order) do
            if getName(b) == name then MiniHub.Release(b) break end
        end
    else
        MiniHub.Collect()
    end
end

function MiniHub.SetFavorite(name, fav)
    if not name then return end
    MiniHubDB.favorites[name] = fav and true or nil
    SortCollected()
    MiniHub.RequestLayout()
end

-- Ordre manuel : echange le bouton avec son voisin (delta = -1 ou +1).
function MiniHub.MoveButton(name, delta)
    SortCollected()
    local names, idx = {}, nil
    for i, b in ipairs(MiniHub.order) do
        names[i] = getName(b)
        if names[i] == name then idx = i end
    end
    if not idx then return false end
    local j = idx + delta
    if j < 1 or j > #names then return false end
    names[idx], names[j] = names[j], names[idx]
    for i, n in ipairs(names) do
        if n then MiniHubDB.customOrder[n] = i end
    end
    SortCollected()
    MiniHub.RequestLayout()
    return true
end

function MiniHub.ResetOrder()
    wipe(MiniHubDB.customOrder)
    SortCollected()
    MiniHub.RequestLayout()
end

--------------------------------------------------------------------------------
-- 5. Addons du compartiment Blizzard (boutons virtuels)
--------------------------------------------------------------------------------
-- Certains addons n'existent QUE dans le menu du compartiment d'addons (le
-- bouton en haut de la minicarte). Option : MiniHub leur cree un bouton.
-- Les entrees suivent la convention de Blizzard reprise par LibDBIcon :
--   func(bouton, { buttonName = clic }, entree), funcOnEnter(bouton, entree).
-- NON TESTE EN JEU : structure interne de Blizzard, tout est sous pcall.

local virtualPool = {}
local COMPARTMENT_SKIP = { MiniHub = true, TibiSuite = true }

local function VirtualName(text)
    local s = text:gsub("[^%w]", "")
    if s == "" then return nil end
    return "MiniHubCompartment_" .. s
end

local function UpdateVirtualIcon(b)
    local e = b._mhEntry
    local tex = e and e.icon
    local ok = false
    if tex then ok = pcall(b.icon.SetTexture, b.icon, tex) end
    if not ok then b.icon:SetTexture(134400) end
end

local function CreateVirtual(name)
    local b = CreateFrame("Button", name, UIParent)
    b:SetSize(31, 31)
    b:RegisterForClicks("AnyUp")
    b._mhVirtual = true
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.icon = icon
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(icon)
    hl:SetColorTexture(1, 1, 1, 0.15)
    b:SetScript("OnClick", function(self, mouse)
        local e = self._mhEntry
        if not (e and type(e.func) == "function") then return end
        local ok, err = pcall(e.func, self, { buttonName = mouse }, e)
        if not ok then Print(string.format(L["MSG_COMPARTMENT_FAIL"], self._mhLabel or "?") .. " " .. tostring(err)) end
    end)
    b:SetScript("OnEnter", function(self)
        local e = self._mhEntry
        if e and type(e.funcOnEnter) == "function" and pcall(e.funcOnEnter, self, e) then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(self._mhLabel or "?")
        GameTooltip:AddLine(L["TT_COMPARTMENT"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        local e = self._mhEntry
        if e and type(e.funcOnLeave) == "function" then pcall(e.funcOnLeave, self, e) end
        GameTooltip:Hide()
    end)
    b:Hide()
    virtualPool[name] = b
    return b
end

function MiniHub.CollectCompartment()
    local want = {}
    local acf = _G.AddonCompartmentFrame
    if MiniHubDB.compartment and acf and type(acf.registeredAddons) == "table" then
        -- Noms deja presents dans le hub : pas de doublon.
        local known = {}
        for _, b in ipairs(MiniHub.order) do
            if not b._mhVirtual then
                local i = MiniHub.GetInfo(b)
                known[strlower(i.label)] = true
                if i.addon then known[strlower(i.addon)] = true end
            end
        end
        local objects = LDBIcon and LDBIcon.objects or {}
        for _, entry in ipairs(acf.registeredAddons) do
            if type(entry) == "table" and type(entry.text) == "string" then
                local text = StripCodes(entry.text)
                if text and not COMPARTMENT_SKIP[text] and not objects[entry.text]
                    and not text:find("^TibiSuite") and not known[strlower(text)] then
                    local name = VirtualName(text)
                    if name and not want[name] then want[name] = { entry = entry, text = text } end
                end
            end
        end
    end
    for name, w in pairs(want) do
        local b = virtualPool[name] or CreateVirtual(name)
        b._mhEntry = w.entry
        b._mhLabel = w.text
        UpdateVirtualIcon(b)
        if not IsCollected(b) and not isBlacklistedByUser(name) then
            b:Show()
            CollectButton(b)
        end
    end
    for name, b in pairs(virtualPool) do
        if not want[name] and IsCollected(b) then MiniHub.Release(b) end
    end
end

--------------------------------------------------------------------------------
-- 6. Disposition (grille, liste, barre rapide)
--------------------------------------------------------------------------------

local function PlaceButton(b, parent, x, y)
    if b:GetParent() ~= parent then rawSetParent(b, parent) end
    local scale = (b.GetScale and b:GetScale()) or 1
    rawClearAllPoints(b)
    rawSetPoint(b, "CENTER", parent, "TOPLEFT", x / scale, -y / scale)
end

-- Libelle cliquable du mode liste : transmet clic et survol au vrai bouton.
local function GetLabel(i)
    local lb = labelPool[i]
    if lb then return lb end
    lb = CreateFrame("Button", nil, container.content)
    lb:SetHeight(18)
    lb:RegisterForClicks("AnyUp")
    lb.text = lb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lb.text:SetPoint("LEFT")
    lb.text:SetPoint("RIGHT")
    lb.text:SetJustifyH("LEFT")
    lb.text:SetWordWrap(false)
    lb:SetScript("OnClick", function(self, mouse)
        local t = self.target
        if not t then return end
        local fn = t.GetScript and t:GetScript("OnClick")
        if fn then pcall(fn, t, mouse, false) return end
        fn = t.GetScript and t:GetScript("OnMouseUp")
        if fn then pcall(fn, t, mouse) end
    end)
    lb:SetScript("OnEnter", function(self)
        local t = self.target
        local fn = t and t.GetScript and t:GetScript("OnEnter")
        if fn then pcall(fn, t) end
        self.text:SetTextColor(1, 1, 1)
    end)
    lb:SetScript("OnLeave", function(self)
        local t = self.target
        local fn = t and t.GetScript and t:GetScript("OnLeave")
        if fn then pcall(fn, t) end
        if self.isHeader then self.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
        else self.text:SetTextColor(0.9, 0.9, 0.9) end
    end)
    labelPool[i] = lb
    return lb
end

local function LayoutHub(list, cell)
    local db = MiniHubDB
    local sp, pad = db.spacing, db.padding
    local headerH = db.showTitle and HEADER_H or 0
    local isList = db.viewMode == "LIST"

    -- Elements a placer : boutons, plus des en-tetes de categorie en mode
    -- liste quand le tri par categorie est actif.
    local items = {}
    local lastCat
    for _, b in ipairs(list) do
        if isList and db.groupByCategory then
            local cat = MiniHub.GetInfo(b).category or L["CAT_OTHER"]
            if db.favorites[getName(b)] then cat = L["CAT_FAVORITES"] end
            if cat ~= lastCat then items[#items + 1] = { header = cat }; lastCat = cat end
        end
        items[#items + 1] = { button = b }
    end
    local n = #items
    local nButtons = #list

    local cols, rows, colW
    if isList then
        rows = max(1, min(n, db.listRows or 10))
        cols = max(1, ceil(n / rows))
        colW = cell + 6 + 150
    elseif db.orientation == "HORIZONTAL" then
        cols = max(ceil(n / max(1, db.perLine)), 1)
        rows = max(ceil(n / cols), 1)
        colW = cell
    else
        rows = max(ceil(n / max(1, db.perLine)), 1)
        cols = max(ceil(n / rows), 1)
        colW = cell
    end

    -- Largeur reelle des libelles en mode liste (mesuree, plafonnee).
    local used = 0
    if isList then
        local maxW = 40
        for i, it in ipairs(items) do
            local lb = GetLabel(i)
            lb.text:SetText(it.header or MiniHub.GetInfo(it.button).label)
            local w = lb.text.GetUnboundedStringWidth and lb.text:GetUnboundedStringWidth() or lb.text:GetStringWidth()
            maxW = max(maxW, min(w or 0, 170))
        end
        colW = cell + 6 + maxW
    end

    for i, it in ipairs(items) do
        local idx = i - 1
        local cx, cy
        if isList or db.orientation ~= "HORIZONTAL" then
            cx = floor(idx / rows); cy = idx % rows
        else
            cy = floor(idx / cols); cx = idx % cols
        end
        local left = pad + cx * (colW + sp)
        local y = headerH + pad + cy * (cell + sp) + cell / 2
        if it.button then
            PlaceButton(it.button, container.content, left + cell / 2, y)
        end
        if isList then
            used = i
            local lb = GetLabel(i)
            lb:ClearAllPoints()
            lb.target = it.button
            lb.isHeader = it.header and true or false
            if it.header then
                lb:SetPoint("LEFT", container.content, "TOPLEFT", left + 2, -y)
                lb.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
                lb:EnableMouse(false)
            else
                lb:SetPoint("LEFT", container.content, "TOPLEFT", left + cell + 6, -y)
                lb.text:SetTextColor(0.9, 0.9, 0.9)
                lb:EnableMouse(true)
            end
            lb:SetWidth(colW - (it.header and 0 or (cell + 6)))
            lb:Show()
        end
    end
    for i = used + 1, #labelPool do labelPool[i]:Hide() end

    local width  = pad * 2 + cols * colW + (cols - 1) * sp
    local height = headerH + pad * 2 + rows * cell + (rows - 1) * sp
    if nButtons == 0 then
        width  = max(width, 130)
        height = headerH + 30
    end
    container.title:SetShown(db.showTitle)
    if container.header then container.header:SetShown(db.showTitle) end
    if container.sep then container.sep:SetShown(db.showTitle) end

    local empty = container.empty
    empty:ClearAllPoints()
    local paused, conflict = IsPaused()
    if paused then
        -- Carte "en pause" : explication lisible + bouton pour passer outre.
        local W = 240
        empty:SetPoint("TOPLEFT", container, "TOPLEFT", 10, -(headerH + 10))
        empty:SetWidth(W - 20)
        empty:SetJustifyH("LEFT")
        empty:SetText(string.format(L["PAUSED_TEXT"], conflict))
        local th = empty:GetStringHeight() or 24
        local ob = container.override
        ob:ClearAllPoints()
        ob:SetPoint("TOPLEFT", empty, "BOTTOMLEFT", 0, -8)
        ob:SetWidth(W - 20)
        ob:Show()
        container:SetSize(W, headerH + 10 + th + 8 + 22 + 10)
    else
        container.override:Hide()
        empty:SetPoint("BOTTOM", container, "BOTTOM", 0, 6)
        empty:SetWidth(0)
        empty:SetJustifyH("CENTER")
        empty:SetText(L["EMPTY"])
        container:SetSize(max(width, 40), max(height, headerH + 22))
    end
    empty:SetShown(nButtons == 0)
end

local function LayoutQuick(list, cell)
    if not quickBar then return end
    local n = #list
    if n == 0 or not MiniHubDB.quickBar then
        quickBar:Hide()
        return
    end
    local pad, sp = 4, MiniHubDB.spacing
    local vertical = MiniHubDB.quickBarVertical
    for i, b in ipairs(list) do
        local idx = i - 1
        local x, y
        if vertical then x = pad + cell / 2; y = pad + idx * (cell + sp) + cell / 2
        else x = pad + idx * (cell + sp) + cell / 2; y = pad + cell / 2 end
        PlaceButton(b, quickBar, x, y)
    end
    local long = pad * 2 + n * cell + (n - 1) * sp
    local short = pad * 2 + cell
    if vertical then quickBar:SetSize(short, long) else quickBar:SetSize(long, short) end
    quickBar:SetShown(not contextHidden)
end

function MiniHub.Layout()
    if not container then return end
    layoutDirty = false
    local db = MiniHubDB

    local hub, quick = {}, {}
    local useQuick = db.quickBar
    for _, b in ipairs(MiniHub.order) do
        if b.IsShown and b:IsShown() then
            if useQuick and db.favorites[getName(b)] then quick[#quick + 1] = b
            else hub[#hub + 1] = b end
        end
    end

    -- Taille de cellule uniforme = plus grand bouton affiche (mini = buttonSize).
    local cell = db.buttonSize or 32
    local function grow(list)
        for _, b in ipairs(list) do
            local s = (b.GetScale and b:GetScale()) or 1
            cell = max(cell, ((b.GetWidth and b:GetWidth()) or 0) * s, ((b.GetHeight and b:GetHeight()) or 0) * s)
        end
    end
    grow(hub); grow(quick)

    LayoutHub(hub, cell)
    LayoutQuick(quick, cell)
    if MiniHub.ApplySkin then MiniHub.ApplySkin() end
    if MiniHub.OnLayout then pcall(MiniHub.OnLayout) end   -- gestionnaire ouvert
end

--------------------------------------------------------------------------------
-- 7. Conteneur, barre rapide, surbrillance, bouton principal
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

-- Deplacement manuel d'un cadre a la souris (sauf verrouillage / tiroir).
local function MakeDraggable(f, dbKey, canDrag)
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
        if canDrag and not canDrag() then return end
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
        if p then MiniHubDB[dbKey] = { p, "UIParent", rp, x, y } end
    end
    f:SetScript("OnMouseUp", function(self, b) if b == "LeftButton" then stop(self) end end)
end

local function SkinPlate(f)
    if f.SetBackdrop then
        f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    end
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    f.bg:SetColorTexture(0.045, 0.045, 0.055, 0.94)
end

local function CreateContainer()
    local f = CreateFrame("Frame", "MiniHubContainer", UIParent, "BackdropTemplate")
    f:SetSize(60, 60)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    SkinPlate(f)

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
    f.title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.empty:SetPoint("BOTTOM", f, "BOTTOM", 0, 6)
    f.empty:SetText(L["EMPTY"])
    f.empty:Hide()

    -- Bouton "utiliser MiniHub quand meme" (carte en pause seulement).
    local ui = _G.TibiMidnight
    local ob
    if ui and ui.MakeButton then
        ob = ui.MakeButton(f, 200, 22, L["PAUSED_OVERRIDE"])
    else
        ob = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        ob:SetSize(200, 22); ob:SetText(L["PAUSED_OVERRIDE"])
    end
    ob:SetScript("OnClick", function() MiniHub.SetIgnoreConflict(true) end)
    ob:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["PAUSED_OVERRIDE_TT"], nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    ob:HookScript("OnLeave", function() GameTooltip:Hide() end)
    ob:Hide()
    f.override = ob

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

    -- Deplacement manuel (impossible en mode tiroir : accroche a la minicarte).
    MakeDraggable(f, "point", function() return not MiniHubDB.drawer end)

    -- Fermeture automatique quand la souris quitte l'ensemble.
    f:HookScript("OnLeave", function() MiniHub.ScheduleAutoClose() end)

    return f
end

local function CreateQuickBar()
    local f = CreateFrame("Frame", "MiniHubQuickBar", UIParent, "BackdropTemplate")
    f:SetSize(40, 40)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    SkinPlate(f)
    MakeDraggable(f, "quickPoint")
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L["QB_TITLE"], ACCENT[1], ACCENT[2], ACCENT[3])
        GameTooltip:AddLine(L["QB_HINT"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:Hide()
    return f
end

-- Surbrillance animee autour d'un bouton (resultat de recherche).
local function CreateGlow()
    local g = CreateFrame("Frame", nil, UIParent)
    g:SetFrameStrata("HIGH")
    local function edge(p1, p2, w, h)
        local t = g:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
        t:SetPoint(p1); t:SetPoint(p2)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
    end
    edge("TOPLEFT", "TOPRIGHT", nil, 2)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
    edge("TOPLEFT", "BOTTOMLEFT", 2, nil)
    edge("TOPRIGHT", "BOTTOMRIGHT", 2, nil)
    g.anim = g:CreateAnimationGroup()
    g.anim:SetLooping("BOUNCE")
    local a = g.anim:CreateAnimation("Alpha")
    a:SetFromAlpha(1); a:SetToAlpha(0.2); a:SetDuration(0.35)
    g:Hide()
    return g
end

function MiniHub.Highlight(button)
    if not (button and IsCollected(button) and glow) then return end
    if button:GetParent() ~= quickBar then MiniHub.Open() end
    if layoutDirty then SafeLayout() end
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", button, "TOPLEFT", -4, 4)
    glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, -4)
    glow:Show()
    glow.anim:Stop(); glow.anim:Play()
    glow._token = (glow._token or 0) + 1
    local token = glow._token
    C_Timer.After(2.5, function()
        if glow._token == token then glow.anim:Stop(); glow:Hide() end
    end)
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

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(b)
    icon:SetTexture(LOGO)
    SmoothTexture(icon)
    b.icon = icon

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture(LOGO)
    hl:SetVertexColor(1, 1, 1, 0.25)
    SmoothTexture(hl)

    -- Un simple clic (souris quasi immobile) NE compte PAS comme un deplacement :
    -- on n'active le glissement qu'au-dela d'un petit seuil.
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
    for _, f in ipairs({ container, quickBar }) do
        if f then
            if f.bg then f.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4]) end
            if f.SetBackdropBorderColor then f:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4]) end
        end
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

-- Applique taille et opacite au bouton principal.
function MiniHub.ApplyMainButtonStyle()
    if not mainButton then return end
    local size  = MiniHubDB.mainButtonSize or 40
    local alpha = MiniHubDB.mainButtonAlpha or 1.0
    mainButton:SetSize(size, size)
    if mainButton.icon then SmoothTexture(mainButton.icon) end
    mainButton:SetAlpha(alpha)
end

local DRAWER_ANCHORS = {
    LEFT   = { "TOPRIGHT", "TOPLEFT", -8, 0 },
    RIGHT  = { "TOPLEFT", "TOPRIGHT", 8, 0 },
    BOTTOM = { "TOP", "BOTTOM", 0, -8 },
}

local function SetPointFromDB(f, p, fallback)
    f:ClearAllPoints()
    if p and p[1] then
        f:SetPoint(p[1], UIParent, p[3] or p[1], p[4] or 0, p[5] or 0)
    else
        f:SetPoint(fallback[1], UIParent, fallback[3], fallback[4], fallback[5])
    end
end

function MiniHub.RestorePosition()
    if container then
        if MiniHubDB.drawer and _G.Minimap then
            local a = DRAWER_ANCHORS[MiniHubDB.drawerSide] or DRAWER_ANCHORS.LEFT
            container:ClearAllPoints()
            container:SetPoint(a[1], _G.Minimap, a[2], a[3], a[4])
        else
            SetPointFromDB(container, MiniHubDB.point, DEFAULTS.point)
        end
    end
    if quickBar then SetPointFromDB(quickBar, MiniHubDB.quickPoint, DEFAULTS.quickPoint) end
    if mainButton then
        SetPointFromDB(mainButton, MiniHubDB.mainPoint, DEFAULTS.mainPoint)
        MiniHub.ApplyMainButtonStyle()
        MiniHub.UpdateMainButtonVisibility()
    end
end

-- Remet tout a sa place par defaut, sous la minicarte (et non plus au centre
-- de l'ecran comme avant).
function MiniHub.ResetPositions()
    local function copy(t) return { t[1], t[2], t[3], t[4], t[5] } end
    MiniHubDB.point      = copy(DEFAULTS.point)
    MiniHubDB.mainPoint  = copy(DEFAULTS.mainPoint)
    MiniHubDB.quickPoint = copy(DEFAULTS.quickPoint)
    MiniHub.RestorePosition()
    if not MiniHubDB.drawer then MiniHub.SnapToMinimap("BOTTOM") end
end

-- Place le hub contre la minicarte (dessous, a gauche ou a droite) A SA
-- POSITION REELLE (EllesmereUI, ElvUI ou le mode Edition peuvent l'avoir
-- deplacee), puis le laisse FLOTTANT : c'est une position libre sur UIParent,
-- que le joueur peut ensuite deplacer a la souris. Le point d'ancrage suit le
-- cote choisi (TOP / TOPRIGHT / TOPLEFT) pour que le hub grandisse en
-- s'eloignant de la minicarte, jamais par-dessus.
local SNAP = {
    BOTTOM = { anchor = "TOP" },
    LEFT   = { anchor = "TOPRIGHT" },
    RIGHT  = { anchor = "TOPLEFT" },
}
function MiniHub.SnapToMinimap(side)
    local mm = _G.Minimap
    local s = SNAP[side or "BOTTOM"] or SNAP.BOTTOM
    if not (mm and container and MiniHubDB) then return false end
    local ok, l, r, t, b = pcall(function() return mm:GetLeft(), mm:GetRight(), mm:GetTop(), mm:GetBottom() end)
    if not (ok and l and r and t and b) then return false end
    local k = (mm:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    l, r, t, b = l * k, r * k, t * k, b * k
    local x, y
    if side == "LEFT" then x, y = l - 6, t
    elseif side == "RIGHT" then x, y = r + 6, t
    else x, y = (l + r) / 2, b - 6 end
    MiniHubDB.point = { s.anchor, "UIParent", "BOTTOMLEFT", floor(x + 0.5), floor(y + 0.5) }
    MiniHubDB.drawer = false
    MiniHubDB.autoPlaced = true
    MiniHub.ApplyDrawer()
    return true
end

-- Le bouton principal disparait si MiniHub tourne comme module de TibiSuite
-- (seule l'icone de minicarte reste), ou selon l'option showMainButton.
function MiniHub.UpdateMainButtonVisibility()
    if not mainButton then return end
    if MiniHub.isTibiSuiteModule or contextHidden then
        mainButton:Hide()
    else
        mainButton:SetShown(MiniHubDB.showMainButton)
    end
end

--------------------------------------------------------------------------------
-- 8. Ouverture / fermeture
--------------------------------------------------------------------------------

-- transient = ouverture automatique du tiroir (non memorisee).
function MiniHub.Open(transient)
    if not container then return end
    if not transient then
        pinnedOpen = true
        if not MiniHubDB.drawer then MiniHubDB.isOpen = true end
    end
    MiniHub.Collect()
    container:Show()
    if layoutDirty then SafeLayout() end
    if MiniHubDB.animate then
        container:SetAlpha(0)
        if container.fadeIn then container.fadeIn:Stop(); container.fadeIn:Play() else container:SetAlpha(1) end
    else
        container:SetAlpha(1)
    end
end

function MiniHub.Close(transient)
    if not container then return end
    if not transient then
        pinnedOpen = false
        if not MiniHubDB.drawer then MiniHubDB.isOpen = false end
    end
    container:Hide()
end

function MiniHub.Toggle()
    if not container then return end
    if container:IsShown() then MiniHub.Close() else MiniHub.Open() end
end

-- Fonction globale de bascule, exposee pour TibiSuite (champ toggleFn du
-- module) et le raccourci clavier.
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

-- Passer outre la pause (ou y revenir). Revenir en pause rend les boutons
-- tout de suite ; l'autre addon les reprend a son prochain passage (un
-- /reload garantit un etat propre).
function MiniHub.SetIgnoreConflict(v)
    MiniHubDB.ignoreConflict = v and true or false
    MiniHub.Collect()
    MiniHub.ApplyBlizzardHiding()
    MiniHub.RequestLayout()
    if MiniHub.RefreshManager then pcall(MiniHub.RefreshManager) end
    local c = HasConflictingCollector()
    if c then Print(string.format(v and L["MSG_OVERRIDE_ON"] or L["MSG_OVERRIDE_OFF"], c)) end
end

-- Un seul panneau d'options : celui du socle (Options.lua).
function MiniHub.OpenOptions()
    if _G.MiniHub_OpenOptions then _G.MiniHub_OpenOptions() end
end

--------------------------------------------------------------------------------
-- 9. Mode tiroir
--------------------------------------------------------------------------------
-- Le hub reste accroche au bord de la minicarte (il suit donc la minicarte si
-- le mode Edition ou EllesmereUI la deplace) et sort au survol. Detection par
-- un petit minuteur (0,15 s) actif UNIQUEMENT quand le tiroir est coche :
-- aucun hook sur la minicarte de Blizzard (pas de risque de contamination).

local drawerTicker
local lastOver = 0

local function DrawerTick()
    if not (MiniHubDB.drawer and container) or contextHidden or IsPaused() then return end
    local mm = _G.Minimap
    local over = (mm and mm:IsVisible() and mm:IsMouseOver())
        or (container:IsShown() and container:IsMouseOver())
    if over then
        lastOver = GetTime()
        if not container:IsShown() then MiniHub.Open(true) end
    elseif container:IsShown() and not pinnedOpen and (GetTime() - lastOver) > 0.8 then
        MiniHub.Close(true)
    end
end

function MiniHub.ApplyDrawer()
    if drawerTicker then drawerTicker:Cancel(); drawerTicker = nil end
    MiniHub.RestorePosition()
    if MiniHubDB.drawer then
        pinnedOpen = false
        if container then container:Hide() end
        drawerTicker = C_Timer.NewTicker(0.15, DrawerTick)
    end
end

--------------------------------------------------------------------------------
-- 10. Bouton maitre LibDBIcon (autour de la minicarte) + AddonCompartment
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
        if MiniHub.masterButton and MiniHub.masterButton.icon then
            SmoothTexture(MiniHub.masterButton.icon)
        end
        -- En suite, le core cree deja l'unique entree du compartiment :
        -- pas de seconde ligne "MiniHub" dans ce menu.
        if HasCore() and LDBIcon.RemoveButtonFromCompartment then
            pcall(LDBIcon.RemoveButtonFromCompartment, LDBIcon, "MiniHub")
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
-- 11. Masquage des boutons de zoom Blizzard
--------------------------------------------------------------------------------

local zoomFrames
local function CollectZoomFrames()
    if zoomFrames then return zoomFrames end
    zoomFrames = {}
    local function add(f) if type(f) == "table" and f.Hide and not isForbidden(f) then zoomFrames[#zoomFrames + 1] = f end end
    add(_G.MinimapZoomIn); add(_G.MinimapZoomOut)
    if _G.Minimap then add(_G.Minimap.ZoomIn); add(_G.Minimap.ZoomOut) end
    local mc = _G.MinimapCluster
    if mc then add(mc.ZoomIn); add(mc.ZoomOut) end
    return zoomFrames
end

-- PIEGE POTENTIEL (voir ADDON_ACTION_FORBIDDEN "SpellStopCasting"/
-- "SpellStopTargeting" trace via /etrace) : MinimapCluster fait partie du meme
-- groupe de gestion de fenetres que la zone de file d'attente. Appeler
-- self:Hide() DIRECTEMENT depuis le hook OnShow execute notre code de facon
-- synchrone dans la pile d'appels de Blizzard. On differe donc l'appel via
-- C_Timer.After(0, ...) pour agir dans un tick propre.
function MiniHub.ApplyBlizzardHiding()
    -- En pause, la minicarte appartient a l'autre addon : on n'y touche pas.
    if IsPaused() then return end
    local hide = MiniHubDB.hideZoomButtons
    for _, f in ipairs(CollectZoomFrames()) do
        if not f._minihubHooked and f.HookScript then
            f:HookScript("OnShow", function(self)
                if MiniHubDB.hideZoomButtons and not IsPaused() then
                    C_Timer.After(0, function() self:Hide() end)
                end
            end)
            f._minihubHooked = true
        end
        if hide then if f.Hide then f:Hide() end else if f.Show then f:Show() end end
    end
end

--------------------------------------------------------------------------------
-- 12. Regles contextuelles
--------------------------------------------------------------------------------

-- Masque le conteneur, la barre rapide et le bouton principal en combat, en
-- donjon/raid ou pendant un combat de mascottes, selon les options.
function MiniHub.UpdateContextVisibility()
    if not container then return end
    local hide = false
    if MiniHubDB.hideInCombat and InCombatLockdown() then hide = true end
    if MiniHubDB.hideInInstance and IsInInstance() then hide = true end
    if MiniHubDB.hideInPetBattle and C_PetBattles and C_PetBattles.IsInBattle() then hide = true end
    contextHidden = hide

    if hide then
        container:Hide()
        if quickBar then quickBar:Hide() end
    else
        if MiniHubDB.drawer then
            if not pinnedOpen then container:Hide() end
        elseif MiniHubDB.isOpen and (pinnedOpen or not IsPaused()) then
            container:Show()
            if layoutDirty then SafeLayout() end
        else
            container:Hide()
        end
        if QuickBarWanted() then MiniHub.RequestLayout() elseif quickBar then quickBar:Hide() end
    end
    MiniHub.UpdateMainButtonVisibility()
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
-- 13. Scan differe et evenements (sans OnUpdate permanent)
--------------------------------------------------------------------------------

local function ScheduleDeferredScans()
    -- Addons lents a creer leur bouton : trois rattrapages suffisent, le
    -- callback LibDBIcon et ADDON_LOADED couvrent le reste.
    for _, delay in ipairs({ 2, 8, 20 }) do
        C_Timer.After(delay, function() MiniHub.Collect() end)
    end
    if LDBIcon and LDBIcon.RegisterCallback then
        pcall(function()
            LDBIcon.RegisterCallback(MiniHub, "LibDBIcon_IconCreated", function(_, button, name)
                if name == "MiniHub" then return end
                C_Timer.After(0.1, function()
                    if IsPaused() then return end
                    if CollectButton(button) then SortCollected(); MiniHub.RequestLayout() end
                end)
            end)
        end)
    end
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function()
        conflictCache = nil
        MiniHub.RequestScan(0.5)
    end)
end

--------------------------------------------------------------------------------
-- 14. Assistant boutons non reconnus + profils
--------------------------------------------------------------------------------

-- Renvoie la liste des noms de boutons qui ressemblent a des boutons d'addon
-- mais n'ont pas ete collectes (nom non conforme aux motifs).
function MiniHub.GetUnrecognized()
    local list, seen = {}, {}
    for _, parent in ipairs(ScanParents()) do
        for _, child in ipairs(SafeChildren(parent)) do
            local ok, name = pcall(function()
                if IsCollected(child) or not child.GetObjectType then return nil end
                local otype = child:GetObjectType()
                if otype ~= "Button" and otype ~= "Frame" then return nil end
                local n = getName(child)
                if not n or isSecureName(n) or BLIZZARD_EXACT[n] or matchesAny(n, PIN_PATTERNS)
                    or MiniHubDB.whitelist[n] or isMinimapButton(child) then return nil end
                local w = child:GetWidth() or 0
                local hasClick = child.HasScript and (
                    (child:HasScript("OnClick") and child:GetScript("OnClick")) or
                    (child:HasScript("OnMouseUp") and child:GetScript("OnMouseUp")) or
                    (child:HasScript("OnMouseDown") and child:GetScript("OnMouseDown")))
                local regions = (child.GetNumRegions and child:GetNumRegions()) or 0
                if child:IsShown() and w >= 15 and w <= 60 and hasClick and regions > 0 then return n end
                return nil
            end)
            if ok and name and not seen[name] then seen[name] = true; list[#list + 1] = name end
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
    "viewMode", "listRows", "groupByCategory", "quickBar", "quickBarVertical",
    "drawer", "drawerSide", "compartment", "collectTibiSuite",
}
local EXPORT_BOOL = {
    showTitle = true, locked = true, showMainButton = true, hideZoomButtons = true,
    hoverOpen = true, autoClose = true, animate = true,
    hideInCombat = true, hideInInstance = true, hideInPetBattle = true,
    groupByCategory = true, quickBar = true, quickBarVertical = true,
    drawer = true, compartment = true, collectTibiSuite = true,
}
local EXPORT_NUM = {
    perLine = { 1, 12 }, buttonSize = { 20, 48 }, spacing = { 0, 12 }, padding = { 0, 20 },
    mainButtonSize = { 28, 64 }, mainButtonAlpha = { 0.2, 1 }, listRows = { 4, 20 },
}
local EXPORT_ENUM = {
    orientation = { VERTICAL = true, HORIZONTAL = true },
    viewMode    = { GRID = true, LIST = true },
    drawerSide  = { LEFT = true, RIGHT = true, BOTTOM = true },
    theme       = THEMES,
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
    local body = str:gsub("^%s+", ""):match("^MH1:(.+)$")
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
            elseif EXPORT_ENUM[k] then
                if EXPORT_ENUM[k][v] then db[k] = v end
            elseif EXPORT_BOOL[k] then
                db[k] = (v == "1")
            elseif EXPORT_NUM[k] then
                local n = tonumber(v)
                if n then db[k] = max(EXPORT_NUM[k][1], min(EXPORT_NUM[k][2], n)) end
            end
        end
    end
    -- Application immediate (plus besoin de /reload).
    MiniHub.ApplySkin()
    MiniHub.ApplyMainButtonStyle()
    MiniHub.ApplyBlizzardHiding()
    MiniHub.ApplyDrawer()
    MiniHub.Collect()
    SortCollected()
    MiniHub.RequestLayout()
    MiniHub.UpdateContextVisibility()
    return true
end

--------------------------------------------------------------------------------
-- 15. Diagnostic + commandes slash
--------------------------------------------------------------------------------

function MiniHub.Dump()
    Print(L["DUMP_HEADER"])
    for _, parent in ipairs(ScanParents()) do
        for _, child in ipairs(SafeChildren(parent)) do
            local name    = getName(child) or "<?>"
            local shown   = (child.IsShown and child:IsShown()) and L["DUMP_SHOWN"] or L["DUMP_HIDDEN"]
            local coll    = IsCollected(child) and "|cff40ff40OK|r" or "-"
            local verdict = isMinimapButton(child) and "|cff40ff40" .. L["DUMP_BUTTON"] .. "|r" or "|cffff8040" .. L["DUMP_IGNORED"] .. "|r"
            print(string.format("  %s | %s | %s | %s", name, shown, coll, verdict))
        end
    end
    Print(string.format(L["MSG_RESCAN"], #MiniHub.order))
end

local function HandleSlash(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S+)%s*(.-)$")
    cmd = strlower(cmd or "")
    if msg == "" or cmd == "toggle" then
        MiniHub.Toggle()
    elseif cmd == "open" then MiniHub.Open()
    elseif cmd == "close" then MiniHub.Close()
    elseif cmd == "scan" then
        MiniHub.Collect()
        Print(string.format(L["MSG_RESCAN"], #MiniHub.order))
    elseif cmd == "reset" then
        MiniHub.ResetPositions()
        Print(L["MSG_RESET"])
    elseif cmd == "config" or cmd == "options" then MiniHub.OpenOptions()
    elseif cmd == "manage" or cmd == "buttons" then
        if MiniHub.OpenManager then MiniHub.OpenManager() end
    elseif cmd == "debug" then MiniHub.Dump()
    elseif cmd == "block" and arg ~= "" then
        MiniHub.SetExcluded(arg, true)
        Print(string.format(L["MSG_BLOCK"], arg))
    elseif cmd == "unblock" and arg ~= "" then
        MiniHub.SetExcluded(arg, false)
        Print(string.format(L["MSG_UNBLOCK"], arg))
    elseif cmd == "add" and arg ~= "" then
        MiniHubDB.whitelist[arg] = true
        MiniHub.Collect()
        Print(string.format(L["MSG_ADD"], arg))
    else
        Print(L["SLASH_HELP"])
        print("  /mh            " .. L["SLASH_TOGGLE"])
        print("  /mh manage     " .. L["SLASH_MANAGE"])
        print("  /mh scan       " .. L["SLASH_SCAN"])
        print("  /mh reset      " .. L["SLASH_RESET"])
        print("  /mh config     " .. L["SLASH_CONFIG"])
        print("  /mh debug      " .. L["SLASH_DEBUG"])
        print("  /mh block <nom>    " .. L["SLASH_BLOCK"])
        print("  /mh unblock <nom>  " .. L["SLASH_UNBLOCK"])
        print("  /mh add <nom>      " .. L["SLASH_ADD"])
    end
end

SLASH_MINIHUB1 = "/minihub"
SLASH_MINIHUB2 = "/mh"
SlashCmdList["MINIHUB"] = HandleSlash

--------------------------------------------------------------------------------
-- 16. Initialisation
--------------------------------------------------------------------------------

local SETTINGS_VERSION = 4

local function LoginMessage(conflict)
    -- En suite, on suit le reglage du core (TibiSuiteDB.loginMsg) : seul
    -- "full" fait parler les modules. En autonome, message complet.
    local mode = "full"
    if HasCore() then mode = (TibiSuiteDB and TibiSuiteDB.loginMsg) or "one" end
    if conflict then
        -- Prevenu une seule fois par addon concurrent (plus de rappel a
        -- chaque connexion) ; la carte du hub et /mh l'expliquent ensuite.
        if mode ~= "none" and MiniHubDB.conflictNotified ~= conflict then
            Print(string.format(L["MSG_CONFLICT_LOGIN"], conflict))
            MiniHubDB.conflictNotified = conflict
        end
    elseif mode == "full" then
        print("|cFFFCD748MiniHub|r v" .. MiniHub.version .. " " .. L["LOGIN_LOADED"])
    end
end

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

    MiniHub.isTibiSuiteModule = _G.TibiSuite and true or false

    container  = CreateContainer()
    quickBar   = CreateQuickBar()
    mainButton = CreateMainButton()
    glow       = CreateGlow()
    MiniHub.container  = container
    MiniHub.quickBar   = quickBar
    MiniHub.mainButton = mainButton
    MiniHub.ApplySkin()
    MiniHub.RestorePosition()

    CreateMasterButton()
    if MiniHubDB.minimap.hide and LDBIcon then LDBIcon:Hide("MiniHub") end

    if MiniHub.SetupOptions then MiniHub.SetupOptions() end
    MiniHub.ApplyBlizzardHiding()
    SetupContextRules()

    MiniHub.Collect()
    SortCollected()
    -- ElvUI / Tukui / EllesmereUI gerent deja eux-memes les boutons de la
    -- minicarte : on ne rouvre pas automatiquement un conteneur qui n'aura
    -- rien a montrer. Reste ouvrable manuellement via /minihub.
    local paused, conflict = IsPaused()
    if paused or MiniHubDB.drawer or not MiniHubDB.isOpen then
        container:Hide()
    else
        container:Show()
    end
    MiniHub.ApplyDrawer()
    MiniHub.UpdateContextVisibility()
    MiniHub.RequestLayout()

    -- Premiere installation (ou position jamais touchee) : le hub se cale
    -- sous la minicarte une fois celle-ci placee par son addon (2 s).
    if not MiniHubDB.autoPlaced then
        C_Timer.After(2, function()
            local p, d = MiniHubDB.point, DEFAULTS.point
            if MiniHubDB.autoPlaced then return end
            if p and p[1] == d[1] and p[3] == d[3] and p[4] == d[4] and p[5] == d[5] then
                MiniHub.SnapToMinimap("BOTTOM")
            else
                MiniHubDB.autoPlaced = true   -- deja deplace par le joueur
            end
        end)
    end

    ScheduleDeferredScans()
    LoginMessage(paused and conflict or nil)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    Initialize()
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- Rattrapage chargement tardif : si PLAYER_LOGIN est deja passe (chargement a
-- la demande par le core), on initialise tout de suite.
if IsLoggedIn() then
    loader:UnregisterEvent("PLAYER_LOGIN")
    Initialize()
end
