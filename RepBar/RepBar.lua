-- RepBar.lua v7.1.5.41
-- Barre de reputation avancee - Tibiscui
-- Remplace la barre de reputation native, suit la faction par zone (via
-- RenTracker) et bascule a la validation d'une quete.
-- Maj+Drag pour deplacer | Maj+Clic droit pour les options
--
-- Refonte 12.1 (trois lots, meme demarche qu'XPBar 7.1.5.30) :
--   Lot 1 : barre native 12.x (conteneurs du mode Edition), coordination fine
--           avec XPBar, suivi du combat, rafraichissements regroupes, index des
--           factions complet, garde contre les valeurs secretes de Midnight.
--   Lot 2 : un seul panneau d'options (socle), 10 langues.
--   Lot 3 : rythme et estimation, texte flottant, coffres de Parangon,
--           recompense du prochain renom, factions epinglees, historique au
--           clic, graduations, styles, badge Bataillon, aimantation sous XPBar.

local ADDON = "RepBar"

-- ══════════════════════════════════════════════════
-- LOCALISATION
-- Le francais reste le defaut embarque directement ici (via l'operateur
-- "or"). Les fichiers Locale\ se chargent AVANT ce fichier (voir RepBar.toc) :
-- enUS.lua sert de base a tout client non francais, puis le fichier de la
-- langue du client (deDE, esES...) surcharge. Une cle absente d'une langue
-- retombe donc sur l'anglais, et seulement en dernier recours sur le francais.
-- ══════════════════════════════════════════════════
RepBarL = RepBarL or {}
local L = RepBarL
local function D(k, v) if L[k] == nil then L[k] = v end end
-- Barre et infobulle
D("FACTION",        "Faction")
D("STANDING",       "Attitude")
D("PROGRESS",       "Progression")
D("REMAINING",      "Restant")
D("ZONE",           "Zone")
D("RENOWN",         "Renom")
D("PARAGON",        "Parangon")
D("NO_FACTION",     "Aucune faction suivie")
D("MAX",            "Max")
D("WARBAND",        "Réputation de bataillon")
D("WARBAND_SHORT",  "Bataillon")
D("SESSION_GAIN",   "Gagné cette session")
D("REP_PER_HOUR",   "Réputation par heure")
D("PER_HOUR",       "/h")
D("TIME_LEFT",      "Prochain palier dans")
D("GAINS_LEFT",     "Gains restants (estimation)")
D("NEXT_RANK",      "Rang %d :")
D("CHEST_READY",    "Coffre prêt !")
D("CHEST_READY_TT", "Coffre de Parangon à récupérer")
D("CHESTS_HEADER",  "Coffres de Parangon en attente :")
D("CHEST_ALERT",    "Coffre de Parangon prêt : %s")
D("CHEST_CLICK",    "|cffFFD700Clic|r itinéraire vers le premier quartier-maître")
D("QM",             "Quartier-maître")
D("WAYPOINT_SET",   "Point de passage : %s (%.1f, %.1f)")
D("NO_WAYPOINT",    "Aucun quartier-maître connu pour cette faction (données RenTracker).")
D("RECENT_HEADER",  "Dernières factions :")
D("CURRENT",        "suivie")
D("NO_RECENT",      "Aucune autre faction récente : gagnez de la réputation ailleurs pour remplir la liste.")
D("PINNED_ADD",     "Faction épinglée : %s")
D("PINNED_DEL",     "Faction retirée des épingles : %s")
D("PINNED_FULL",    "Déjà %d factions épinglées : retirez-en une (Alt+clic sur sa barre).")
D("PIN_HINT",       "|cffFFD700Clic|r suivre  ·  |cffFFD700Alt+Clic|r retirer")
D("HINT",           "|cffFFD700Maj+Drag|r déplacer  ·  |cffFFD700Maj+Clic droit|r options")
D("HINT_CLICK",     "|cffFFD700Clic|r faction suivante  ·  |cffFFD700Clic droit|r précédente")
D("HINT_ALT",       "|cffFFD700Alt+Clic|r épingler  ·  |cffFFD700Ctrl+Clic|r itinéraire du quartier-maître")
D("POS_SAVED",      "Position sauvegardée.")
D("POS_RESET",      "Position réinitialisée.")
D("SESSION_RESET",  "Session réinitialisée.")
D("SWITCH_QUEST",   "Faction suivie : ")
D("SNAP_OFF",       "Aimantation sous XPBar désactivée (barre déplacée à la main).")
-- Slash / login
D("SLASH_HIDDEN",   "Masqué. /repbar show pour ré-afficher.")
D("SLASH_HELP",     " /repbar - options  |  /repbar hide/show  |  /repbar pin/unpin  |  /repbar session  |  /repbar reset")
D("LOGIN_LOADED",   "chargé -- tapez")
D("LOGIN_TO_OPEN",  "pour les options.")
D("NO_SOCLE",       "Panneau d'options indisponible : le socle TibiSuite n'est pas chargé.")
D("MM_TT_LEFT",     "Clic gauche : afficher/masquer")
D("MM_TT_RIGHT",    "Clic droit : options")
-- Panneau d'options
D("OPT_TITLE",          "RepBar - Options")
D("OPT_HINT",           "|cffFFD700Maj+Drag|r sur la barre pour la déplacer, |cffFFD700Maj+Clic droit|r pour ouvrir ou fermer ce panneau.")
D("OPT_SEC_PRESETS",    "Styles prêts à l'emploi")
D("OPT_PRESET_THIN",    "Style Fine (8 px)")
D("OPT_PRESET_CLASSIC", "Style Classique")
D("OPT_PRESET_VERTICAL","Style Verticale")
D("OPT_SEC_DIMENSIONS", "Dimensions")
D("OPT_WIDTH",          "Largeur")
D("OPT_HEIGHT",         "Hauteur")
D("OPT_SEC_APPEARANCE", "Apparence")
D("OPT_OPACITY",        "Opacité du fond (%)")
D("OPT_FONTSIZE",       "Taille du texte")
D("OPT_COL_BAR",        "Couleur fixe de la barre")
D("OPT_STANDCOL",       "Couleur selon l'attitude")
D("OPT_TICKS",          "Graduations tous les 10 %")
D("OPT_SEC_DISPLAY",    "Affichage")
D("OPT_SHOWZONE",       "Zone de la faction (ligne du bas)")
D("OPT_SHOWNUM",        "Valeurs (x / y)")
D("OPT_SHOWPCT",        "Pourcentage")
D("OPT_RATE",           "Réputation par heure et temps restant")
D("OPT_FLOAT",          "Texte flottant à chaque gain")
D("OPT_WARBAND",        "Badge Bataillon")
D("OPT_RENOWN_REWARD",  "Récompense du prochain rang de renom (infobulle)")
D("OPT_SEC_PARAGON",    "Parangon")
D("OPT_PARAGON_ALERT",  "Signaler les coffres à récupérer")
D("OPT_PARAGON_ALL",    "Surveiller toutes les extensions")
D("OPT_PARAGON_ALL_TT", "Par défaut : extension actuelle, faction suivie et factions épinglées. Les anciennes extensions gardent parfois un coffre en attente depuis des années.")
D("OPT_SEC_PINS",       "Factions épinglées")
D("OPT_PINS_NOTE",      "Jusqu'à 3 factions, en fines barres sous la barre principale. Alt+clic sur la barre principale pour épingler la faction suivie, Alt+clic sur une barre épinglée pour la retirer.")
D("OPT_SHOWPINS",       "Afficher les barres épinglées")
D("OPT_PINHEIGHT",      "Hauteur des barres épinglées")
D("OPT_PIN_CURRENT",    "Épingler / retirer la faction suivie")
D("OPT_PIN_CLEAR",      "Retirer toutes les épingles")
D("OPT_SEC_BEHAVIOR",   "Comportement")
D("OPT_SWITCHQ",        "Basculer à la validation d'une quête")
D("OPT_CLICKCYCLE",     "Clic sur la barre : parcourir les dernières factions")
D("OPT_SNAP",           "Coller sous XPBar")
D("OPT_SNAP_TT",        "La barre se place sous XPBar et la suit. La déplacer à la main (Maj+Drag) désactive l'aimantation.")
D("OPT_SEC_VISIBILITY", "Visibilité")
D("OPT_HIDENOFAC",      "Masquer si aucune faction suivie")
D("OPT_HIDENATIVE",     "Masquer la barre de réputation native")
D("OPT_HIDENATIVE_TT",  "Au niveau maximum, la réputation occupe l'emplacement principal de Blizzard : il est alors masqué aussi. Si XPBar masque déjà les barres natives, RepBar le laisse faire.")
D("OPT_HIDECOMBAT",     "Masquer en combat")
D("OPT_MOUSEOVER",      "Afficher au survol seulement")
D("OPT_SEC_ORIENTATION","Orientation")
D("OPT_VERTBAR",        "Barre verticale")
D("OPT_VERTTEXT",       "Texte à côté de la barre (vertical)")
D("OPT_VTHICK",         "Épaisseur (vertical)")
D("OPT_VLENGTH",        "Longueur (vertical)")
D("OPT_SEC_SESSION",    "Session et position")
D("OPT_RESETSESS",      "Réinitialiser la session")
D("OPT_RESETPOS",       "Réinitialiser la position")
D("OPT_SEC_FLOATING",   "Bouton flottant")
D("OPT_HIDE_OPTIONS_BTN","Masquer le bouton Options")

-- ══════════════════════════════════════════════════
-- DEFAULTS
-- ══════════════════════════════════════════════════
local MAX_PINS = 3
local DEFAULTS = {
    posX = 0, posY = -146, anchor = "TOP",   -- juste sous la barre XP (-120)
    width = 600, height = 22,           -- dimensions en mode HORIZONTAL
    orientation  = "HORIZONTAL",        -- "HORIZONTAL" (defaut) ou "VERTICAL"
    vWidth  = 24,                       -- epaisseur en mode VERTICAL
    vHeight = 300,                      -- longueur en mode VERTICAL
    verticalText = false,               -- afficher le texte a cote de la barre en vertical
    useStandingColor = true,    -- barre coloree selon l'attitude
    showZone         = true,    -- afficher la zone de la faction (issue de RenTracker)
    showNumbers      = true,    -- valeurs x / y
    showPercent      = true,
    switchOnQuest    = true,    -- basculer sur validation de quete
    hideNativeRepBar = true,    -- masquer la barre de reputation native
    hideWhenNoFaction= true,    -- se cacher si aucune faction suivie
    hideInCombat     = false,
    mouseoverOnly    = false,
    manuallyHidden   = false,   -- retient un clic gauche (RepBar_Toggle) d'une session a l'autre
    bgA      = 0.85,
    fontSize = 0,
    -- couleur fixe (utilisee si useStandingColor est faux) : azur d'identite RepBar
    barR = 0.36, barG = 0.68, barB = 0.96, barA = 1.0,
    -- Lot 3
    showTicks        = true,    -- graduations tous les 10 %
    showFloating     = true,    -- "+250" a chaque gain
    showRate         = true,    -- reputation/heure + temps estime (ligne du bas, infobulle)
    showWarband      = true,    -- badge Bataillon
    showRenownReward = true,    -- prochaine recompense de renom (infobulle)
    paragonAlert     = true,    -- halo + icone de coffre
    paragonAllExp    = false,   -- surveiller toutes les extensions (sinon l'actuelle)
    showPins         = true,
    pinHeight        = 12,
    clickCycle       = true,    -- clic = faction recente suivante
    snapToXPBar      = false,
    -- tables : creees a part dans InitDB (jamais partagees avec DEFAULTS)
    -- pinned = { factionID, ... }        (compte)
    -- recent = { ["Nom-Royaume"] = { factionID, ... } }
}

-- ══════════════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════════════
local db
local mainBar, bgTexture, glowTex, glowAnim, chestBtn
local labelLeft, labelCenter, labelRight, labelBottom
local containerFrame, dragFrame
local ticks, floatPool, pinFrames = {}, {}, {}
local mouseIsOver  = false
local inCombat     = false       -- PLAYER_REGEN_DISABLED arrive AVANT InCombatLockdown()
local isMoving     = false
local lastMoveAt   = 0
local updatePending, scanPending = false, false
local questArmed   = 0           -- GetTime() de la derniere validation de quete
local QUEST_WINDOW = 6           -- secondes : fenetre pendant laquelle un gain = bascule
local nameToID, nameIndexAt = nil, 0
local dataIndex    = nil         -- factionID -> entree RenTrackerData
local snap         = {}          -- factionID -> derniere lecture (calcul des gains)
local sess         = {}          -- factionID -> { gain, count, start }
local pendingChests = {}         -- { { id=, name= }, ... }
local chestKnown   = {}          -- factionID -> true (deja annonce dans le chat)
local snapApplied  = nil         -- dernier etat d'aimantation applique

-- Forward declarations
local UpdateBar, RequestUpdate
local ApplySize, ApplyAppearance, ApplyFont, ApplyVisibility, EnforceNativeRepBar
local ApplyOrientation, LayoutLabels, LayoutTicks, ApplyPosition, UpdateChestIcon

-- ══════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════
local function HasCore() return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false end

local function IsLoaded(name)
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) and true or false
end

-- XPBar masque-t-il deja les barres natives ? (option cochee par defaut chez
-- lui). Dans ce cas il est proprietaire des conteneurs : RepBar n'y ecrit rien.
-- Case decochee chez XPBar : RepBar gere seul l'emplacement de la reputation.
local function XPBarOwnsNative()
    if not IsLoaded("XPBar") then return false end
    return not (type(XPBarDB) == "table" and XPBarDB.hideDefaultXPBar == false)
end

local function IsSecret(v)
    return _G.issecretvalue and _G.issecretvalue(v) and true or false
end

local function IsAtMaxLevel()
    local maxLvl = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 999
    return UnitLevel("player") >= maxLvl
end

local function CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "?")
end

-- Orientation courante et dimensions actives selon celle-ci.
local function IsVertical() return db and db.orientation == "VERTICAL" end
local function ActiveSize()
    if IsVertical() then return db.vWidth or 24, db.vHeight or 300 end
    return db.width or 600, db.height or 22
end
-- Barre fine : les textes ne tiennent plus dedans, ils passent dessous.
-- (Au-dessus, le bouton flottant Options du socle les chevaucherait.)
local function IsThin() return not IsVertical() and (db.height or 22) < 14 end

local function N(v)
    v = math.floor((v or 0) + 0.5)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(v) or tostring(v)
end

local function FormatDuration(sec)
    sec = math.max(0, math.floor((sec or 0) + 0.5))
    if SecondsToTime then return SecondsToTime(sec, sec >= 60, false, 2) end
    if sec >= 3600 then return string.format("%dh%02d", math.floor(sec / 3600), math.floor(sec % 3600 / 60)) end
    return string.format("%d min", math.max(1, math.floor(sec / 60)))
end

-- ══════════════════════════════════════════════════
-- DONNEES RENTRACKER (lien souple : zone, quartier-maitre, extension)
-- ══════════════════════════════════════════════════
local currentExt = nil
local function BuildDataIndex()
    dataIndex = {}
    local data = _G.RenTrackerData
    if type(data) ~= "table" then return end
    local best = -1
    for key, ext in pairs(data) do
        if type(ext) == "table" and type(ext.factions) == "table" then
            for _, fac in ipairs(ext.factions) do
                if type(fac) == "table" and fac.id and not dataIndex[fac.id] then
                    dataIndex[fac.id] = fac
                end
            end
            local toc = tonumber(ext.tocLabel or "")
            if toc and toc > best then best, currentExt = toc, key end
        end
    end
end

local function FacData(factionID)
    if not factionID then return nil end
    if not dataIndex then BuildDataIndex() end
    return dataIndex[factionID]
end

-- Point de passage vers le quartier-maitre : TomTom si present, sinon le
-- point natif de la carte (meme logique que RenTracker).
local function PlaceWaypoint(mapID, coords, title)
    local x, y = (coords or ""):match("([%d%.]+)%s*,%s*([%d%.]+)")
    x, y = tonumber(x), tonumber(y)
    if not (mapID and x and y) then return false end
    if TomTom and TomTom.AddWaypoint then
        TomTom:AddWaypoint(mapID, x / 100, y / 100, { title = title, persistent = false })
        return true
    end
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false
    end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then return false end
    local ok = pcall(function()
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end)
    if ok then print("|cffFFD700[RepBar]|r " .. string.format(L.WAYPOINT_SET, title or "", x, y)) end
    return ok
end

local function WaypointFor(factionID)
    local fac = FacData(factionID)
    if not (fac and fac.qm_mapID and fac.qm_coord and PlaceWaypoint(fac.qm_mapID, fac.qm_coord, fac.qm_name)) then
        print("|cffFFD700[RepBar]|r " .. L.NO_WAYPOINT)
    end
end

-- ══════════════════════════════════════════════════
-- LECTURE UNIVERSELLE DE LA REPUTATION (API natives uniquement)
-- Supporte : amitie, renom (Major Factions), paragon, systeme classique.
-- Retourne { name, label, cur, max, pct, color, system, maxed, paragon,
-- pending, rank, kind, raw, warband } ou nil. kind/raw/rank servent au calcul
-- des gains : "s" = valeur absolue croissante (classique, amitie), "p" =
-- total Parangon croissant, "r" = rang + progression dans le rang (renom).
-- ══════════════════════════════════════════════════
local function ApplyParagon(factionID, o)
    if not (C_Reputation and C_Reputation.IsFactionParagon and C_Reputation.GetFactionParagonInfo) then return false end
    local pok, isP = pcall(C_Reputation.IsFactionParagon, factionID)
    if not (pok and isP) then return false end
    local gok, val, thr, _, pending = pcall(C_Reputation.GetFactionParagonInfo, factionID)
    if not (gok and val and thr and thr > 0) then return false end
    o.paragon = true
    o.system  = "paragon"
    o.label   = L.PARAGON
    o.cur     = val % thr
    o.max     = thr
    o.pending = pending and true or false
    -- Coffre en attente : Blizzard affiche la barre pleine, on fait pareil.
    o.pct     = o.pending and 1 or (o.cur / thr)
    o.maxed   = false
    o.kind, o.raw = "p", val
    o.color   = { 1.00, 0.85, 0.40 }   -- ambre paragon
    return true
end

local function ReadReputation(factionID)
    if not factionID or factionID == 0 then return nil end
    local out = { factionID = factionID }
    if C_Reputation and C_Reputation.IsAccountWideReputation then
        local ok, w = pcall(C_Reputation.IsAccountWideReputation, factionID)
        out.warband = ok and w and true or false
    end

    -- 1) AMITIE (reputations a paliers personnalises) --------------------
    if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
        local ok, fr = pcall(C_GossipInfo.GetFriendshipReputation, factionID)
        if ok and fr and fr.friendshipFactionID and fr.friendshipFactionID ~= 0 then
            out.system = "friendship"
            out.name   = fr.name
            out.label  = fr.reaction or ""
            out.color  = { 0.25, 0.80, 0.45 }
            local cur  = fr.standing          or 0
            local minv = fr.reactionThreshold or 0
            local maxv = fr.nextThreshold     or 0
            out.kind, out.raw = "s", cur
            if maxv and maxv > minv then
                out.cur = cur - minv
                out.max = maxv - minv
                out.pct = out.max > 0 and (out.cur / out.max) or 1
            else
                out.cur, out.max, out.pct, out.maxed = 1, 1, 1, true
            end
            return out
        end
    end

    -- 2) RENOM (Major Factions : SL / DF / TWW / Midnight) --------------
    if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
        local ok, d = pcall(C_MajorFactions.GetMajorFactionData, factionID)
        if ok and d and (d.renownLevel or d.renownLevelThreshold) then
            out.system = "renown"
            out.name   = d.name
            out.rank   = d.renownLevel or 0
            out.cur    = d.renownReputationEarned or 0
            out.max    = d.renownLevelThreshold   or 1
            out.pct    = (out.max > 0) and math.min(1, out.cur / out.max) or 0
            out.label  = L.RENOWN .. " " .. tostring(out.rank)
            out.color  = { 0.36, 0.68, 0.96 }   -- azur renom
            out.kind   = "r"
            local isCap = false
            if C_MajorFactions.HasMaximumRenown then
                local cok, c = pcall(C_MajorFactions.HasMaximumRenown, factionID)
                isCap = cok and c
            end
            if isCap then
                out.maxed = true
                if not ApplyParagon(factionID, out) then
                    out.cur, out.pct = out.max, 1
                end
            end
            return out
        end
    end

    -- 3) SYSTEME CLASSIQUE (BfA et avant) -------------------------------
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, d = pcall(C_Reputation.GetFactionDataByID, factionID)
        if ok and d then
            out.system   = "classic"
            out.name     = d.name
            local reaction = d.reaction or 4
            out.reaction = reaction
            out.label    = _G["FACTION_STANDING_LABEL" .. reaction] or ""
            local c = _G.FACTION_BAR_COLORS and _G.FACTION_BAR_COLORS[reaction]
            out.color    = c and { c.r, c.g, c.b } or { 0.6, 0.6, 0.6 }
            local minv = d.currentReactionThreshold or 0
            local maxv = d.nextReactionThreshold     or 0
            local val  = d.currentStanding           or 0
            out.kind, out.raw = "s", val
            if maxv and maxv > minv then
                out.cur = val - minv
                out.max = maxv - minv
                out.pct = out.max > 0 and (out.cur / out.max) or 1
            else
                out.cur, out.max, out.pct, out.maxed = 1, 1, 1, true
            end
            if reaction >= 8 then
                out.maxed = true
                out.pct   = 1
                ApplyParagon(factionID, out)  -- Legion / BfA ont du paragon
            end
            return out
        end
    end

    return nil
end

-- Faction actuellement suivie par le jeu (celle qu'affiche la barre native).
local function GetWatchedFactionID()
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local ok, d = pcall(C_Reputation.GetWatchedFactionData)
        if ok and d and d.factionID and d.factionID ~= 0 then return d.factionID end
    end
    if GetWatchedFactionInfo then
        local ok, _, _, _, _, _, factionID = pcall(GetWatchedFactionInfo)
        if ok and factionID and factionID ~= 0 then return factionID end
    end
    return nil
end

local function FactionName(factionID)
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, d = pcall(C_Reputation.GetFactionDataByID, factionID)
        if ok and d and d.name and d.name ~= "" then return d.name end
    end
    if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
        local ok, d = pcall(C_MajorFactions.GetMajorFactionData, factionID)
        if ok and d and d.name then return d.name end
    end
    local fac = FacData(factionID)
    return fac and fac.name or ("#" .. tostring(factionID))
end

local function SetWatched(factionID)
    if not (factionID and C_Reputation and C_Reputation.SetWatchedFactionByID) then return false end
    local ok = pcall(C_Reputation.SetWatchedFactionByID, factionID)
    if ok then RequestUpdate() end
    return ok
end

-- ══════════════════════════════════════════════════
-- HISTORIQUE, EPINGLES, SESSION (lot 3)
-- ══════════════════════════════════════════════════
local function RecentList()
    db.recent = db.recent or {}
    local key = CharKey()
    db.recent[key] = db.recent[key] or {}
    return db.recent[key]
end

local function PushRecent(factionID)
    if not (db and factionID) then return end
    local list = RecentList()
    if list[1] == factionID then return end
    for i = #list, 1, -1 do if list[i] == factionID then table.remove(list, i) end end
    table.insert(list, 1, factionID)
    while #list > 5 do table.remove(list) end
end

local function CycleRecent(dir)
    local list = RecentList()
    local cur = GetWatchedFactionID()
    local idx
    for i, id in ipairs(list) do if id == cur then idx = i ; break end end
    local nxt
    if idx then
        nxt = list[((idx - 1 + dir) % #list) + 1]
    else
        nxt = list[1]
    end
    if not nxt or nxt == cur then
        print("|cffFFD700[RepBar]|r " .. L.NO_RECENT)
        return
    end
    SetWatched(nxt)
end

local function IsPinned(factionID)
    for i, id in ipairs(db.pinned) do if id == factionID then return i end end
end

local function TogglePin(factionID)
    if not (db and factionID) then return end
    local i = IsPinned(factionID)
    if i then
        table.remove(db.pinned, i)
        print("|cffFFD700[RepBar]|r " .. string.format(L.PINNED_DEL, FactionName(factionID)))
    elseif #db.pinned >= MAX_PINS then
        print("|cffFFD700[RepBar]|r " .. string.format(L.PINNED_FULL, MAX_PINS))
        return
    else
        table.insert(db.pinned, factionID)
        print("|cffFFD700[RepBar]|r " .. string.format(L.PINNED_ADD, FactionName(factionID)))
    end
    RequestUpdate()
end

-- Gain depuis la derniere lecture de cette faction (0 si inconnu/perte).
local function Delta(prev, r)
    if not prev or prev.kind ~= r.kind or not r.kind then return 0 end
    local d
    if r.kind == "r" then
        if r.rank == prev.rank then
            d = (r.cur or 0) - (prev.cur or 0)
        elseif (r.rank or 0) > (prev.rank or 0) then
            d = ((prev.max or 0) - (prev.cur or 0)) + (r.cur or 0)
        else
            d = 0
        end
    else
        d = (r.raw or 0) - (prev.raw or 0)
    end
    return d > 0 and d or 0
end

-- Enregistre la lecture, cumule la session, renvoie le gain constate.
local function TrackGain(factionID, r)
    local prev = snap[factionID]
    snap[factionID] = { kind = r.kind, raw = r.raw, rank = r.rank, cur = r.cur, max = r.max }
    if not sess[factionID] then sess[factionID] = { gain = 0, count = 0, start = GetTime() } end
    local d = Delta(prev, r)
    if d > 0 then
        local s = sess[factionID]
        s.gain, s.count = s.gain + d, s.count + 1
        PushRecent(factionID)
    end
    return d
end

-- Reputation par heure depuis que la faction est observee cette session.
local function RateFor(factionID)
    local s = sess[factionID]
    if not (s and s.gain > 0) then return nil end
    return s.gain / math.max(GetTime() - s.start, 60) * 3600
end

local function ResetSession()
    wipe(sess) ; wipe(snap)
end

-- ══════════════════════════════════════════════════
-- INIT DB
-- ══════════════════════════════════════════════════
local function InitDB()
    RepBarDB = RepBarDB or {}
    db = RepBarDB
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    if type(db.pinned) ~= "table" then db.pinned = {} end
    if type(db.recent) ~= "table" then db.recent = {} end
end

-- ══════════════════════════════════════════════════
-- POSITION (sauvegarde + aimantation sous XPBar)
-- ══════════════════════════════════════════════════
local function SavePosition()
    if not containerFrame then return end
    local point, rel, _, x, y = containerFrame:GetPoint()
    if rel and rel ~= UIParent then
        -- Secours : ancre relative a une autre frame (aimantation) -> on
        -- convertit en coordonnees absolues du coin haut-gauche.
        local l, t = containerFrame:GetLeft(), containerFrame:GetTop()
        if not (l and t) then return end
        point, x, y = "TOPLEFT", l, t - UIParent:GetTop()
    end
    db.anchor = point
    db.posX   = math.floor((x or 0) + 0.5)
    db.posY   = math.floor((y or 0) + 0.5)
end

local function SnapTarget()
    if not db.snapToXPBar then return nil end
    local x = _G.XPBarContainer
    if x and x ~= containerFrame and x:IsShown() then return x end
end

ApplyPosition = function()
    if not containerFrame or isMoving then return end
    local target = SnapTarget()
    containerFrame:ClearAllPoints()
    if target then
        containerFrame:SetPoint("TOP", target, "BOTTOM", 0, -2)
    else
        containerFrame:SetPoint(db.anchor, UIParent, db.anchor, db.posX, db.posY)
    end
    snapApplied = target and true or false
end

local function CheckSnap()
    local want = SnapTarget() and true or false
    if want ~= snapApplied then ApplyPosition() end
end

local function StartMove()
    if not IsShiftKeyDown() or isMoving then return end
    if db.snapToXPBar then
        db.snapToXPBar = false
        print("|cffFFD700[RepBar]|r " .. L.SNAP_OFF)
    end
    isMoving = true
    containerFrame:StartMoving()
    mainBar:SetAlpha(0.6)
end

local function StopMove()
    if not isMoving then return end
    isMoving = false
    lastMoveAt = GetTime()
    containerFrame:StopMovingOrSizing()
    mainBar:SetAlpha(1.0)
    SavePosition()
    snapApplied = false
    print("|cffFFD700[RepBar]|r " .. L.POS_SAVED)
end

-- ══════════════════════════════════════════════════
-- APPLY SIZE / FONT / APPARENCE
-- ══════════════════════════════════════════════════
ApplySize = function()
    if not containerFrame then return end
    local w, h = ActiveSize()
    local extra = 0
    if not IsVertical() then extra = 20 + (IsThin() and 16 or 0) end
    containerFrame:SetSize(w, h + extra)
    mainBar:SetSize(w, h)
    dragFrame:SetSize(w, h + extra)
    if LayoutTicks then LayoutTicks() end
end

-- Replace les 4 labels selon l'orientation (et l'option "texte a cote").
LayoutLabels = function()
    if not labelLeft then return end
    for _, fs in ipairs({ labelLeft, labelCenter, labelRight, labelBottom }) do
        fs:ClearAllPoints() ; fs:Show()
    end
    if not IsVertical() then
        if IsThin() then
            labelLeft:SetPoint("TOPLEFT", mainBar, "BOTTOMLEFT", 2, -2)
            labelCenter:SetPoint("TOP", mainBar, "BOTTOM", 0, -2)
            labelRight:SetPoint("TOPRIGHT", mainBar, "BOTTOMRIGHT", -2, -2)
            labelBottom:SetPoint("TOP", mainBar, "BOTTOM", 0, -18)
        else
            labelLeft:SetPoint("LEFT", mainBar, "LEFT", 8, 0)
            labelCenter:SetPoint("CENTER", mainBar, "CENTER", 0, 0)
            labelRight:SetPoint("RIGHT", mainBar, "RIGHT", -8, 0)
            labelBottom:SetPoint("TOP", mainBar, "BOTTOM", 0, -2)
        end
        labelLeft:SetJustifyH("LEFT") ; labelCenter:SetJustifyH("CENTER") ; labelRight:SetJustifyH("RIGHT")
    elseif db.verticalText then
        -- Texte a droite de la colonne, ecrit a l'horizontale (lisible).
        labelLeft:SetPoint("BOTTOMLEFT", mainBar, "TOPRIGHT", 6, -2) ; labelLeft:SetJustifyH("LEFT")
        labelCenter:SetPoint("LEFT", mainBar, "RIGHT", 6, 0)         ; labelCenter:SetJustifyH("LEFT")
        labelRight:SetPoint("TOPLEFT", mainBar, "BOTTOMRIGHT", 6, 2) ; labelRight:SetJustifyH("LEFT")
        labelBottom:Hide()
    else
        -- Jauge pure : tout dans l'infobulle.
        labelLeft:Hide() ; labelCenter:Hide() ; labelRight:Hide() ; labelBottom:Hide()
    end
end

-- Graduations tous les 10 %. Appelee au changement de taille/orientation.
LayoutTicks = function()
    if not ticks[1] then return end
    local w0, h0 = ActiveSize()
    local vert = IsVertical()
    local len  = (vert and h0 or w0)
    for i = 1, 9 do
        local t = ticks[i]
        t:ClearAllPoints()
        if db.showTicks then
            if vert then
                t:SetSize(math.max(1, w0 - 2), 1)
                t:SetPoint("BOTTOM", mainBar, "BOTTOM", 0, i / 10 * len)
            else
                t:SetSize(1, math.max(1, h0 - 2))
                t:SetPoint("LEFT", mainBar, "LEFT", i / 10 * len, 0)
            end
            t:Show()
        else
            t:Hide()
        end
    end
end

-- Applique l'orientation a la barre puis reajuste taille et labels.
ApplyOrientation = function()
    if not mainBar then return end
    mainBar:SetOrientation(IsVertical() and "VERTICAL" or "HORIZONTAL")
    ApplySize()
    LayoutLabels()
end

ApplyFont = function()
    if not labelLeft then return end
    for _, fs in ipairs({ labelLeft, labelCenter, labelRight, labelBottom }) do
        local path, size, flags = fs:GetFont()
        fs._baseSize = fs._baseSize or size
        local newSize = (db.fontSize and db.fontSize > 0) and db.fontSize or fs._baseSize
        if path and newSize then fs:SetFont(path, newSize, flags) end
    end
end

ApplyAppearance = function()
    if bgTexture then bgTexture:SetColorTexture(0.05, 0.05, 0.05, db.bgA or 0.85) end
    ApplyFont()
end

-- Le module a-t-il ete decoche dans le panneau Modules du core ? (meme
-- convention que RepBar_Module.lua : table absente = jamais configure =
-- actif par defaut ; table presente = seule la cle explicite [KEY]=true
-- active).
local function IsEnabledByCore()
    if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
    return TibiSuiteDB.enabledModules.RepBar == true
end

-- ══════════════════════════════════════════════════
-- VISIBILITE CONTEXTUELLE
-- Retourne true si la barre reste visible, false si masquee.
-- ══════════════════════════════════════════════════
ApplyVisibility = function()
    if not containerFrame or not db then return false end

    if not IsEnabledByCore() then
        containerFrame:Hide() ; return false
    end
    -- Fermeture manuelle (clic gauche du bouton minimap / onglet) : persiste
    -- a travers /reload et redemarrage.
    if db.manuallyHidden then
        containerFrame:Hide() ; return false
    end
    -- inCombat : PLAYER_REGEN_DISABLED se declenche AVANT que
    -- InCombatLockdown() ne renvoie true, d'ou l'indicateur maison.
    if db.hideInCombat and (inCombat or InCombatLockdown()) then
        containerFrame:Hide() ; return false
    end
    if db.hideWhenNoFaction and not GetWatchedFactionID() then
        containerFrame:Hide() ; return false
    end

    containerFrame:Show()
    if db.mouseoverOnly and not mouseIsOver then
        containerFrame:SetAlpha(0)
    else
        containerFrame:SetAlpha(1)
    end
    return true
end

-- ══════════════════════════════════════════════════
-- BARRE DE REPUTATION NATIVE (12.x)
--
-- Depuis Dragonflight, les barres visibles vivent dans deux conteneurs du
-- mode Edition : MainStatusTrackingBarContainer (priorite haute : XP, ou la
-- reputation au niveau maximum) et SecondaryStatusTrackingBarContainer (la
-- reputation sous le niveau maximum). L'ancien code ne visait que
-- StatusTrackingBarManager, qui ne les porte plus forcement.
--
-- Regles (pieges connus, a respecter) :
--   * JAMAIS de Show/Hide ni de hook de script sur ces frames (taint
--     "action reservee a l'IU de Blizzard") : seulement SetAlpha, reaffirme
--     sur nos evenements insecures.
--   * La souris est coupee (sinon l'infobulle native reste sur une zone
--     invisible), hors combat uniquement, et rendue a l'identique.
--   * Option decochee : une seule restauration, et seulement si c'est
--     RepBar qui avait masque (sinon on ecraserait Opacity, EllesmereUI ou
--     un fondu de Blizzard).
--   * XPBar masque deja tout (option par defaut) : RepBar n'ecrit rien.
-- ══════════════════════════════════════════════════
local NATIVE_MAIN, NATIVE_SEC = "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer"
local nativeAlphaByUs, nativeMouseByUs, mouseSaved = {}, {}, {}

local function NativeFrame(name)
    local f = _G[name]
    if f and f.SetAlpha and not (f.IsForbidden and f:IsForbidden()) then return f end
end

local function ForEachDeep(f, fn)
    fn(f)
    local n = f.GetNumChildren and f:GetNumChildren() or 0
    for i = 1, n do
        local child = select(i, f:GetChildren())
        if child and not (child.IsForbidden and child:IsForbidden()) then fn(child) end
    end
end

local function SetNativeAlpha(f, a)
    ForEachDeep(f, function(fr) if fr.SetAlpha then fr:SetAlpha(a) end end)
end

local function SetNativeMouse(f, on)
    ForEachDeep(f, function(fr)
        if not (fr.EnableMouse and fr.IsMouseEnabled) then return end
        if on then
            if mouseSaved[fr] ~= nil then
                if mouseSaved[fr] then pcall(fr.EnableMouse, fr, true) end
                mouseSaved[fr] = nil
            end
        else
            if mouseSaved[fr] == nil then mouseSaved[fr] = fr:IsMouseEnabled() and true or false end
            pcall(fr.EnableMouse, fr, false)
        end
    end)
end

EnforceNativeRepBar = function()
    if not db then return end
    local combat = inCombat or InCombatLockdown()
    if XPBarOwnsNative() then
        -- XPBar gere : on lui rend la souris telle qu'on l'avait trouvee (hors
        -- combat), puis on oublie notre etat. L'alpha n'est pas touche : XPBar
        -- le pose lui-meme.
        if not combat then
            for name in pairs(nativeMouseByUs) do
                local f = NativeFrame(name)
                if f then SetNativeMouse(f, true) end
            end
            wipe(nativeMouseByUs) ; wipe(mouseSaved)
        end
        wipe(nativeAlphaByUs)
        return
    end
    local want = {}
    if db.hideNativeRepBar then
        want[NATIVE_SEC] = true
        if IsAtMaxLevel() then want[NATIVE_MAIN] = true end
    end
    for _, name in ipairs({ NATIVE_MAIN, NATIVE_SEC }) do
        local f = NativeFrame(name)
        if f then
            if want[name] then
                SetNativeAlpha(f, 0) ; nativeAlphaByUs[name] = true
                if not nativeMouseByUs[name] and not combat then
                    SetNativeMouse(f, false) ; nativeMouseByUs[name] = true
                end
            else
                if nativeAlphaByUs[name] then SetNativeAlpha(f, 1) ; nativeAlphaByUs[name] = nil end
                if nativeMouseByUs[name] and not combat then
                    SetNativeMouse(f, true) ; nativeMouseByUs[name] = nil
                end
            end
        end
    end
end

-- ══════════════════════════════════════════════════
-- INFOBULLE (barre principale et barres epinglees)
-- ══════════════════════════════════════════════════
local function AddRenownRewards(r)
    if not (db.showRenownReward and r.system == "renown" and not r.maxed) then return end
    if not (C_MajorFactions and C_MajorFactions.GetRenownRewardsForLevel) then return end
    local nextRank = (r.rank or 0) + 1
    local ok, rewards = pcall(C_MajorFactions.GetRenownRewardsForLevel, r.factionID, nextRank)
    if not (ok and type(rewards) == "table" and #rewards > 0) then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(string.format(L.NEXT_RANK, nextRank), 0.36, 0.68, 0.96)
    for i = 1, math.min(3, #rewards) do
        local rw = rewards[i]
        local name = rw.name
        if (not name or name == "") and rw.itemID and C_Item and C_Item.GetItemNameByID then
            name = C_Item.GetItemNameByID(rw.itemID)
        end
        if not name or name == "" then name = rw.description end
        if name and name ~= "" then
            local icon = rw.icon and ("|T" .. tostring(rw.icon) .. ":14:14|t ") or ""
            GameTooltip:AddLine(icon .. name, 1, 1, 1, true)
        end
    end
    if #rewards > 3 then GameTooltip:AddLine("+" .. (#rewards - 3), 0.7, 0.7, 0.7) end
end

local function AddChestList()
    if not (db.paragonAlert and #pendingChests > 0) then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.CHESTS_HEADER, 1, 0.85, 0.4)
    for _, c in ipairs(pendingChests) do
        local fac = FacData(c.id)
        local where = fac and fac.qm_name and (fac.qm_name .. (fac.qm_zone and (", " .. fac.qm_zone) or "")) or ""
        GameTooltip:AddDoubleLine(c.name, where, 1, 1, 1, 0.7, 0.7, 0.7)
    end
end

local function ShowRepTooltip(owner, id, isPin)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("RepBar", 0.36, 0.68, 0.96)
    GameTooltip:AddLine(" ")
    local r = id and ReadReputation(id)
    if not r then
        GameTooltip:AddLine(L.NO_FACTION, 0.8, 0.8, 0.8)
    else
        GameTooltip:AddDoubleLine(L.FACTION, r.name or "?", 1,.82,0, 1,1,1)
        if r.warband and db.showWarband then GameTooltip:AddLine(L.WARBAND, 0.56, 0.83, 1) end
        GameTooltip:AddDoubleLine(L.STANDING, r.label or "-", 1,.82,0, r.color[1], r.color[2], r.color[3])
        if r.pending then
            GameTooltip:AddLine(L.CHEST_READY_TT, 1, 0.85, 0.4)
        elseif r.max and r.max > 1 and not r.maxed then
            GameTooltip:AddDoubleLine(L.PROGRESS,
                string.format("%s / %s (%.1f%%)", N(r.cur), N(r.max), (r.pct or 0) * 100), 1,.82,0, 1,1,1)
            GameTooltip:AddDoubleLine(L.REMAINING, N(math.max(0, r.max - r.cur)), 1,.82,0, 1,1,1)
        end
        -- Rythme et estimation
        local s = sess[id]
        if s and s.gain > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(L.SESSION_GAIN, "+" .. N(s.gain), 1,.82,0, 0.5,1,0.5)
            local rate = RateFor(id)
            if rate then
                GameTooltip:AddDoubleLine(L.REP_PER_HOUR, N(rate), 1,.82,0, 1,1,1)
                if not r.maxed and not r.pending and r.max and r.max > 1 then
                    local left = math.max(0, r.max - r.cur)
                    GameTooltip:AddDoubleLine(L.TIME_LEFT, FormatDuration(left / rate * 3600), 1,.82,0, 1,1,1)
                    if s.count > 0 then
                        local avg = s.gain / s.count
                        GameTooltip:AddDoubleLine(L.GAINS_LEFT, "~" .. math.ceil(left / avg), 1,.82,0, 1,1,1)
                    end
                end
            end
        end
        AddRenownRewards(r)
        local fac = FacData(id)
        if fac and fac.zone then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(L.ZONE, fac.zone, 1,.82,0, .8,.8,.8)
        end
        if fac and fac.qm_name then
            GameTooltip:AddDoubleLine(L.QM, fac.qm_name, 1,.82,0, .8,.8,.8)
        end
    end
    if not isPin then
        AddChestList()
        local list = RecentList()
        if #list > 1 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.RECENT_HEADER, 1, .82, 0)
            for i, fid in ipairs(list) do
                local tag = (fid == id) and ("  |cff66b3ff(" .. L.CURRENT .. ")|r") or ""
                GameTooltip:AddLine(i .. ". " .. FactionName(fid) .. tag, .9, .9, .9)
            end
        end
        GameTooltip:AddLine(" ")
        if db.clickCycle then GameTooltip:AddLine(L.HINT_CLICK, .8, .8, .8) end
        GameTooltip:AddLine(L.HINT_ALT, .8, .8, .8)
        GameTooltip:AddLine(L.HINT, .8, .8, .8)
    else
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.PIN_HINT, .8, .8, .8)
    end
    GameTooltip:Show()
end

-- ══════════════════════════════════════════════════
-- CREATION UI
-- ══════════════════════════════════════════════════
local function CreateMainBar()
    containerFrame = CreateFrame("Frame", "RepBarContainer", UIParent)
    containerFrame:SetFrameStrata("MEDIUM")
    containerFrame:SetSize(db.width, db.height + 20)
    containerFrame:SetMovable(true)
    containerFrame:SetClampedToScreen(true)

    -- Frame invisible pour le drag / les clics
    dragFrame = CreateFrame("Button", "RepBarDragFrame", containerFrame)
    dragFrame:SetPoint("TOP", containerFrame, "TOP", 0, 0)
    dragFrame:SetFrameStrata("HIGH")
    dragFrame:EnableMouse(true)
    dragFrame:RegisterForDrag("LeftButton")
    dragFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    dragFrame:SetAlpha(0)

    dragFrame:SetScript("OnDragStart", StartMove)
    dragFrame:SetScript("OnDragStop", StopMove)
    -- Maj+clic droit : ouvert ICI (le dragFrame capte la souris, le raccourci
    -- pose par le socle sur le conteneur ne se declenche donc jamais : pas de
    -- double bascule). Meme panneau que partout ailleurs.
    dragFrame:SetScript("OnClick", function(_, button)
        if (GetTime() - lastMoveAt) < 0.3 then return end
        if IsShiftKeyDown() then
            if button == "RightButton" then RepBar_OpenOptions() end
            return
        end
        if button == "LeftButton" and IsAltKeyDown() then
            TogglePin(GetWatchedFactionID()) ; return
        end
        if button == "LeftButton" and IsControlKeyDown() then
            WaypointFor(GetWatchedFactionID()) ; return
        end
        if db.clickCycle then CycleRecent(button == "LeftButton" and 1 or -1) end
    end)

    dragFrame:SetScript("OnEnter", function(self)
        mouseIsOver = true
        ApplyVisibility()
        ShowRepTooltip(self, GetWatchedFactionID(), false)
    end)
    dragFrame:SetScript("OnLeave", function()
        mouseIsOver = false
        ApplyVisibility()
        GameTooltip:Hide()
    end)

    -- Barre principale
    mainBar = CreateFrame("StatusBar", "RepBarMain", containerFrame)
    mainBar:SetSize(db.width, db.height)
    mainBar:SetPoint("TOP", containerFrame, "TOP", 0, 0)
    mainBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    mainBar:SetStatusBarColor(db.barR, db.barG, db.barB, db.barA)
    mainBar:SetMinMaxValues(0, 1)
    mainBar:SetValue(0)

    -- Fond sombre
    bgTexture = containerFrame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetPoint("TOPLEFT",     mainBar, "TOPLEFT",     0, 0)
    bgTexture:SetPoint("BOTTOMRIGHT", mainBar, "BOTTOMRIGHT", 0, 0)
    bgTexture:SetColorTexture(0.05, 0.05, 0.05, db.bgA or 0.85)

    -- Bordure fine
    local border = CreateFrame("Frame", nil, mainBar, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 6,
        insets   = { left=1, right=1, top=1, bottom=1 },
    })
    border:SetBackdropBorderColor(0, 0, 0, 0.7)

    -- Graduations
    for i = 1, 9 do
        local t = mainBar:CreateTexture(nil, "OVERLAY", nil, -1)
        t:SetColorTexture(0, 0, 0, 0.45)
        ticks[i] = t
    end

    -- Halo de coffre de Parangon (pulsation, moteur d'animation de WoW :
    -- aucun OnUpdate, s'arrete seul avec :Stop()).
    glowTex = mainBar:CreateTexture(nil, "OVERLAY", nil, -2)
    glowTex:SetAllPoints()
    glowTex:SetColorTexture(1, 0.85, 0.4, 1)
    glowTex:SetBlendMode("ADD")
    glowTex:SetAlpha(0)
    glowAnim = glowTex:CreateAnimationGroup()
    local a = glowAnim:CreateAnimation("Alpha")
    a:SetFromAlpha(0.05) ; a:SetToAlpha(0.35) ; a:SetDuration(0.8) ; a:SetSmoothing("IN_OUT")
    glowAnim:SetLooping("BOUNCE")
    glowAnim:SetScript("OnStop", function() glowTex:SetAlpha(0) end)

    -- Icone de coffre (a droite de la barre, hors de la zone du dragFrame)
    chestBtn = CreateFrame("Button", "RepBarChestButton", containerFrame)
    chestBtn:SetFrameStrata("HIGH")
    chestBtn:SetSize(20, 20)
    local ct = chestBtn:CreateTexture(nil, "ARTWORK")
    ct:SetAllPoints()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("ParagonReputation_Bag") then
        ct:SetAtlas("ParagonReputation_Bag")
    else
        ct:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
    end
    local cag = ct:CreateAnimationGroup()
    local ca = cag:CreateAnimation("Alpha")
    ca:SetFromAlpha(1) ; ca:SetToAlpha(0.45) ; ca:SetDuration(0.7)
    cag:SetLooping("BOUNCE")
    chestBtn.anim = cag
    chestBtn:SetScript("OnEnter", function(self)
        mouseIsOver = true ; ApplyVisibility()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("RepBar", 0.36, 0.68, 0.96)
        AddChestList()
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.CHEST_CLICK, .8, .8, .8)
        GameTooltip:Show()
    end)
    chestBtn:SetScript("OnLeave", function() mouseIsOver = false ; ApplyVisibility() ; GameTooltip:Hide() end)
    chestBtn:SetScript("OnClick", function()
        for _, c in ipairs(pendingChests) do
            local fac = FacData(c.id)
            if fac and fac.qm_mapID and fac.qm_coord then WaypointFor(c.id) ; return end
        end
        print("|cffFFD700[RepBar]|r " .. L.NO_WAYPOINT)
    end)
    chestBtn:Hide()

    -- Labels
    labelLeft = mainBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelLeft:SetTextColor(1, 1, 1, 1)
    labelCenter = mainBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelCenter:SetTextColor(1, 1, 1, 1)
    labelRight = mainBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelRight:SetTextColor(1, 1, 1, 1)
    labelBottom = containerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelBottom:SetTextColor(0.7, 0.7, 0.7, 1)

    ApplyPosition()
    ApplyAppearance()
    ApplyOrientation()   -- fixe l'orientation, la taille, les graduations et les labels
end

-- ══════════════════════════════════════════════════
-- TEXTE FLOTTANT "+250" (lot 3)
-- Petit pool de FontStrings recycles, animation montee + fondu geree par
-- WoW (aucun OnUpdate). Le texte part de l'extremite de la zone remplie.
-- ══════════════════════════════════════════════════
local FLOAT_POOL = 4
local function AcquireFloat()
    for i = 1, #floatPool do
        local fs = floatPool[i]
        if not fs.anim:IsPlaying() then return fs end
    end
    if #floatPool < FLOAT_POOL then
        local fs = containerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local ag = fs:CreateAnimationGroup()
        local up = ag:CreateAnimation("Translation")
        up:SetOffset(0, 28) ; up:SetDuration(1.6) ; up:SetSmoothing("OUT")
        local fade = ag:CreateAnimation("Alpha")
        fade:SetFromAlpha(1) ; fade:SetToAlpha(0)
        fade:SetStartDelay(0.7) ; fade:SetDuration(0.9)
        ag:SetScript("OnFinished", function() fs:Hide() end)
        fs.anim = ag
        floatPool[#floatPool + 1] = fs
        return fs
    end
    local fs = table.remove(floatPool, 1)
    fs.anim:Stop()
    floatPool[#floatPool + 1] = fs
    return fs
end

local function ShowFloating(amount, color)
    if not (db.showFloating and containerFrame:IsShown()) then return end
    if amount <= 0 or containerFrame:GetAlpha() == 0 then return end
    local fs = AcquireFloat()
    fs:ClearAllPoints()
    local w0, h0 = ActiveSize()
    local pct = mainBar:GetValue() or 0
    if IsVertical() then
        fs:SetPoint("LEFT", mainBar, "BOTTOMRIGHT", 6, pct * h0)
    else
        fs:SetPoint("BOTTOM", mainBar, "TOPLEFT", math.max(30, math.min(w0 - 30, pct * w0)), 4)
    end
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetText("+" .. N(amount))
    fs:SetAlpha(1)
    fs:Show()
    fs.anim:Play()
end

-- ══════════════════════════════════════════════════
-- BARRES EPINGLEES (lot 3)
-- Hors de la zone du dragFrame (sous la barre en horizontal, a gauche en
-- vertical) : elles ont leurs propres infobulle, clics et Maj+Drag.
-- ══════════════════════════════════════════════════
local function CreatePin(i)
    local p = CreateFrame("StatusBar", "RepBarPin" .. i, containerFrame)
    p:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    p:SetMinMaxValues(0, 1)
    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.85)
    p.bg = bg
    p.left = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.left:SetPoint("LEFT", p, "LEFT", 4, 0)
    p.right = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.right:SetPoint("RIGHT", p, "RIGHT", -4, 0)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", StartMove)
    p:SetScript("OnDragStop", StopMove)
    p:SetScript("OnMouseUp", function(self, button)
        if (GetTime() - lastMoveAt) < 0.3 or not self.factionID then return end
        if IsShiftKeyDown() then
            if button == "RightButton" then RepBar_OpenOptions() end
        elseif button == "LeftButton" and IsAltKeyDown() then
            TogglePin(self.factionID)
        elseif button == "LeftButton" and IsControlKeyDown() then
            WaypointFor(self.factionID)
        elseif button == "LeftButton" then
            SetWatched(self.factionID)
        end
    end)
    p:SetScript("OnEnter", function(self)
        mouseIsOver = true ; ApplyVisibility()
        ShowRepTooltip(self, self.factionID, true)
    end)
    p:SetScript("OnLeave", function() mouseIsOver = false ; ApplyVisibility() ; GameTooltip:Hide() end)
    pinFrames[i] = p
    return p
end

local function UpdatePins(watchedID, bottomShown)
    local shown = 0
    if db.showPins then
        local w0, h0 = ActiveSize()
        local vert, thin = IsVertical(), IsThin()
        local ph = math.max(4, db.pinHeight or 12)
        local pw = math.max(6, math.floor((db.vWidth or 24) * 0.5))
        local below = (thin and 16 or 0) + (bottomShown and 18 or 3)
        for _, fid in ipairs(db.pinned) do
            if fid ~= watchedID and shown < MAX_PINS then
                local r = ReadReputation(fid)
                if r then
                    shown = shown + 1
                    TrackGain(fid, r)
                    local p = pinFrames[shown] or CreatePin(shown)
                    p.factionID = fid
                    p:ClearAllPoints()
                    if vert then
                        p:SetOrientation("VERTICAL")
                        p:SetSize(pw, h0)
                        p:SetPoint("TOPRIGHT", mainBar, "TOPLEFT", -3 - (shown - 1) * (pw + 3), 0)
                    else
                        p:SetOrientation("HORIZONTAL")
                        p:SetSize(w0, ph)
                        p:SetPoint("TOPLEFT", mainBar, "BOTTOMLEFT", 0, -(below + (shown - 1) * (ph + 2)))
                    end
                    local c = (db.useStandingColor and r.color) or { db.barR, db.barG, db.barB }
                    p:SetStatusBarColor(c[1], c[2], c[3], 1)
                    p:SetValue(math.max(0, math.min(1, r.pct or 0)))
                    if not vert and ph >= 10 then
                        local path, _, flags = p.left:GetFont()
                        local size = math.min(10, ph - 1)
                        if path then p.left:SetFont(path, size, flags) ; p.right:SetFont(path, size, flags) end
                        p.left:SetText((r.name or "") .. ((r.warband and db.showWarband) and " |cff8fd3ff·B|r" or ""))
                        if r.pending then
                            p.right:SetText("|cffffd966" .. L.CHEST_READY .. "|r")
                        elseif r.maxed and not r.paragon then
                            p.right:SetText("|cff66b3ff" .. L.MAX .. "|r")
                        else
                            p.right:SetText(string.format("%s  %.0f%%", r.label or "", (r.pct or 0) * 100))
                        end
                        p.left:Show() ; p.right:Show()
                    else
                        p.left:Hide() ; p.right:Hide()
                    end
                    p:Show()
                end
            end
        end
    end
    for i = shown + 1, #pinFrames do pinFrames[i]:Hide() ; pinFrames[i].factionID = nil end
end

-- ══════════════════════════════════════════════════
-- COFFRES DE PARANGON (lot 3)
-- Balayage regroupe (au plus un par seconde) : extension actuelle (donnees
-- RenTracker), faction suivie, factions epinglees ; toutes les extensions si
-- l'option est cochee. Le halo ne concerne que la faction suivie ; l'icone
-- signale n'importe quel coffre en attente.
-- ══════════════════════════════════════════════════
local function ScanParagon()
    scanPending = false
    wipe(pendingChests)
    if not (db and db.paragonAlert and C_Reputation and C_Reputation.GetFactionParagonInfo) then
        if UpdateChestIcon then UpdateChestIcon() end
        return
    end
    if not dataIndex then BuildDataIndex() end
    local ids, seen = {}, {}
    local function add(id) if id and not seen[id] then seen[id] = true ; ids[#ids + 1] = id end end
    add(GetWatchedFactionID())
    for _, id in ipairs(db.pinned) do add(id) end
    local data = _G.RenTrackerData
    if type(data) == "table" then
        for key, ext in pairs(data) do
            if type(ext) == "table" and type(ext.factions) == "table"
               and (db.paragonAllExp or key == currentExt) then
                for _, fac in ipairs(ext.factions) do add(fac.id) end
            end
        end
    end
    local announce = not IsLoaded("RenTracker")   -- RenTracker alerte deja de son cote
    local now = {}
    for _, id in ipairs(ids) do
        local pok, isP = pcall(C_Reputation.IsFactionParagon, id)
        if pok and isP then
            local ok, _, _, _, pending = pcall(C_Reputation.GetFactionParagonInfo, id)
            if ok and pending then
                local name = FactionName(id)
                pendingChests[#pendingChests + 1] = { id = id, name = name }
                now[id] = true
                if announce and not chestKnown[id] then
                    print("|cffFFD700[RepBar]|r " .. string.format(L.CHEST_ALERT, name))
                end
            end
        end
    end
    chestKnown = now
    UpdateChestIcon()
end

local function RequestParagonScan()
    if scanPending then return end
    scanPending = true
    C_Timer.After(1, ScanParagon)
end

UpdateChestIcon = function()
    if not chestBtn then return end
    if db.paragonAlert and #pendingChests > 0 then
        local w0, h0 = ActiveSize()
        chestBtn:ClearAllPoints()
        if IsVertical() then
            local s = math.max(14, math.min(22, w0))
            chestBtn:SetSize(s, s)
            chestBtn:SetPoint("BOTTOM", mainBar, "TOP", 0, 4)
        else
            local s = math.max(14, math.min(22, h0))
            chestBtn:SetSize(s, s)
            chestBtn:SetPoint("LEFT", mainBar, "RIGHT", 4, 0)
        end
        chestBtn:Show()
        if not chestBtn.anim:IsPlaying() then chestBtn.anim:Play() end
    else
        chestBtn.anim:Stop()
        chestBtn:Hide()
    end
end

-- ══════════════════════════════════════════════════
-- UPDATE BAR
-- ══════════════════════════════════════════════════
UpdateBar = function()
    if not mainBar or not db then return end

    EnforceNativeRepBar()
    CheckSnap()
    if not ApplyVisibility() then return end

    local id = GetWatchedFactionID()
    local r = id and ReadReputation(id)
    if not r then
        labelLeft:SetText("")
        labelCenter:SetText(id and "?" or L.NO_FACTION)
        labelRight:SetText("")
        labelBottom:Hide()
        mainBar:SetValue(0)
        glowAnim:Stop()
        UpdatePins(id, false)
        return
    end

    -- Gain depuis la derniere lecture : session, historique, texte flottant.
    local gain = TrackGain(id, r)

    -- Couleur de la barre
    if db.useStandingColor and r.color then
        mainBar:SetStatusBarColor(r.color[1], r.color[2], r.color[3], db.barA or 1)
    else
        mainBar:SetStatusBarColor(db.barR, db.barG, db.barB, db.barA)
    end
    mainBar:SetValue(math.max(0, math.min(1, r.pct or 0)))
    if gain > 0 then ShowFloating(gain, r.color) end

    -- Halo : coffre de la faction suivie
    if db.paragonAlert and r.pending then
        if not glowAnim:IsPlaying() then glowAnim:Play() end
    else
        glowAnim:Stop()
    end

    local cr, cg, cb = r.color[1], r.color[2], r.color[3]
    local maxedPlain = r.maxed and not r.paragon

    -- Mode vertical : texte compact a cote (si demande) ou masque.
    if IsVertical() then
        if db.verticalText then
            labelLeft:SetText(r.label or "")
            labelLeft:SetTextColor(cr, cg, cb, 1)
            if r.pending then
                labelCenter:SetText("|cffffd966" .. L.CHEST_READY .. "|r")
            elseif db.showNumbers and r.max and r.max > 1 and not r.maxed then
                labelCenter:SetText(string.format("|cffffff99%s/%s|r", N(r.cur), N(r.max)))
            else
                labelCenter:SetText("")
            end
            if db.showPercent and not maxedPlain and not r.pending then
                labelRight:SetText(string.format("%.0f%%", (r.pct or 0) * 100))
            elseif maxedPlain then
                labelRight:SetText("|cff66b3ff" .. L.MAX .. "|r")
            else
                labelRight:SetText("")
            end
        end
        UpdatePins(id, false)
        UpdateChestIcon()
        return
    end

    -- Nom (gauche), colore selon l'attitude, + badge Bataillon
    local name = r.name or ""
    if r.warband and db.showWarband then name = name .. " |cff8fd3ff· " .. L.WARBAND_SHORT .. "|r" end
    labelLeft:SetText(name)
    labelLeft:SetTextColor(cr, cg, cb, 1)

    -- Attitude + valeurs (centre)
    local center = r.label or ""
    if r.pending then
        center = center .. "  |cffffd966" .. L.CHEST_READY .. "|r"
    elseif db.showNumbers and r.max and r.max > 1 and not r.maxed then
        center = center .. string.format("  |cffffff99%s / %s|r", N(r.cur), N(r.max))
    end
    labelCenter:SetText(center)

    -- Pourcentage (droite)
    if db.showPercent and not maxedPlain and not r.pending then
        labelRight:SetText(string.format("|cffffffff%.1f%%|r", (r.pct or 0) * 100))
    elseif maxedPlain then
        labelRight:SetText("|cff66b3ff" .. L.MAX .. "|r")
    else
        labelRight:SetText("")
    end

    -- Ligne du bas : zone, rythme, temps estime
    local parts = {}
    if db.showZone then
        local fac = FacData(id)
        if fac and fac.zone then parts[#parts + 1] = L.ZONE .. " : " .. fac.zone end
    end
    if db.showRate then
        local rate = RateFor(id)
        if rate then
            parts[#parts + 1] = "|cff80ff80+" .. N(rate) .. L.PER_HOUR .. "|r"
            if not r.maxed and not r.pending and r.max and r.max > 1 then
                parts[#parts + 1] = "~" .. FormatDuration(math.max(0, r.max - r.cur) / rate * 3600)
            end
        end
    end
    if #parts > 0 then
        labelBottom:SetText("|cffcccccc" .. table.concat(parts, "  ·  ") .. "|r")
        labelBottom:Show()
    else
        labelBottom:Hide()
    end

    UpdatePins(id, #parts > 0)
    UpdateChestIcon()
end

-- Rafraichissement regroupe : UPDATE_FACTION arrive en rafale (une quete
-- peut toucher plusieurs factions) ; un seul UpdateBar a l'image suivante.
RequestUpdate = function()
    if updatePending then return end
    updatePending = true
    C_Timer.After(0, function()
        updatePending = false
        UpdateBar()
    end)
end

-- ══════════════════════════════════════════════════
-- BASCULE PAR QUETE
-- Sur QUEST_TURNED_IN on arme une fenetre ; le message de gain de reputation
-- (CHAT_MSG_COMBAT_FACTION_CHANGE) nous donne le NOM de la faction gagnee ->
-- on la resout en factionID et on la suit. Locale-safe : le motif est derive
-- des chaines globales du client. Le meme message alimente l'historique.
-- ══════════════════════════════════════════════════
local function ToPattern(base)
    base = base:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    base = base:gsub("%%%%s", "(.-)")   -- %s -> nom de faction
    base = base:gsub("%%%%d", "%%d+")   -- %d -> nombre
    return base
end

local GAIN_PATTERNS = nil
local function BuildGainPatterns()
    local seen, list = {}, {}
    local keys = {
        "FACTION_STANDING_INCREASED_ACCOUNT_WIDE",
        "FACTION_STANDING_INCREASED_DOUBLE_BONUS",
        "FACTION_STANDING_INCREASED_BONUS",
        "FACTION_STANDING_INCREASED_ACH_BONUS",
        "FACTION_STANDING_INCREASED",
    }
    for _, k in ipairs(keys) do
        local s = _G[k]
        if type(s) == "string" and s:find("%%s") and not seen[s] then
            seen[s] = true
            list[#list + 1] = ToPattern(s)
        end
    end
    if #list == 0 then
        list[1] = ToPattern("Reputation with %s increased by %d.")
    end
    return list
end

-- Index nom(minuscule) -> factionID. La liste de la fenetre Reputation ne
-- montre QUE les categories depliees : on complete avec les ID connus de
-- RenTracker et les factions de renom de chaque extension, par ID (aucune
-- categorie du joueur n'est depliee ou modifiee).
local function BuildNameIndex()
    nameToID, nameIndexAt = {}, GetTime()
    local function add(id)
        if not id or id == 0 then return end
        local n = FactionName(id)
        if n and n:sub(1, 1) ~= "#" then nameToID[n:lower()] = id end
    end
    if C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
        local n = C_Reputation.GetNumFactions() or 0
        for i = 1, n do
            local ok, d = pcall(C_Reputation.GetFactionDataByIndex, i)
            if ok and d and not d.isHeader and d.name and d.factionID and d.factionID ~= 0 then
                nameToID[d.name:lower()] = d.factionID
            end
        end
    end
    if not dataIndex then BuildDataIndex() end
    for id in pairs(dataIndex) do add(id) end
    if C_MajorFactions and C_MajorFactions.GetMajorFactionIDs then
        local top = (LE_EXPANSION_LEVEL_CURRENT or GetExpansionLevel and GetExpansionLevel() or 11) + 1
        for exp = 0, top do
            local ok, list = pcall(C_MajorFactions.GetMajorFactionIDs, exp)
            if ok and type(list) == "table" then for _, id in ipairs(list) do add(id) end end
        end
    end
end

local function ResolveFactionID(name)
    if not name then return nil end
    local key = name:lower()
    if nameToID and nameToID[key] then return nameToID[key] end
    -- Reconstruction (faction nouvelle), au plus une fois toutes les 10 s.
    if not nameToID or (GetTime() - nameIndexAt) > 10 then BuildNameIndex() end
    return nameToID and nameToID[key] or nil
end

local function OnGainMessage(msg)
    if not db or not msg then return end
    -- Midnight : en instance, le texte du chat peut etre une valeur secrete ;
    -- toute operation de chaine dessus leverait une erreur Lua.
    if IsSecret(msg) or type(msg) ~= "string" then return end
    GAIN_PATTERNS = GAIN_PATTERNS or BuildGainPatterns()
    local fname
    for _, pat in ipairs(GAIN_PATTERNS) do
        fname = msg:match(pat)
        if fname and fname ~= "" then break end
    end
    if not fname or fname == "" then return end
    local id = ResolveFactionID(fname)
    if not id then return end
    PushRecent(id)

    if not db.switchOnQuest or (GetTime() - questArmed) > QUEST_WINDOW then return end
    if GetWatchedFactionID() == id then RequestUpdate() ; return end
    if SetWatched(id) then
        questArmed = 0   -- consomme : une seule bascule par quete
        print("|cffFFD700[RepBar]|r " .. L.SWITCH_QUEST .. fname)
    end
end

-- ══════════════════════════════════════════════════
-- STYLES PRETS A L'EMPLOI (lot 3)
-- Ne touchent qu'a la forme : couleurs et contenu restent ceux du joueur.
-- ══════════════════════════════════════════════════
local PRESETS = {
    thin     = { orientation = "HORIZONTAL", width = 600, height = 8,  fontSize = 9 },
    classic  = { orientation = "HORIZONTAL", width = 600, height = 22, fontSize = 0 },
    vertical = { orientation = "VERTICAL",   vWidth = 24, vHeight = 300, verticalText = true },
}

local function ApplyPreset(name)
    local p = PRESETS[name]
    if not (p and db) then return end
    for k, v in pairs(p) do db[k] = v end
    ApplyOrientation()
    ApplyFont()
    UpdateBar()
end

-- ══════════════════════════════════════════════════
-- PANNEAU D'OPTIONS UNIQUE (socle TibiSuite, mode suite comme autonome)
-- ══════════════════════════════════════════════════
local ACCENT_REP = { 0.36, 0.68, 0.96 }   -- azur d'identite RepBar
local function TibiUI() return _G.TibiMidnight end

function RepBar_Toggle()
    if not containerFrame then return end
    if containerFrame:IsShown() then
        containerFrame:Hide()
        if db then db.manuallyHidden = true end
    else
        if db then db.manuallyHidden = false end
        containerFrame:Show() ; UpdateBar()
    end
end

local midnightPanel
local function BuildMidnightOptions()
    local ui = TibiUI() ; if not (ui and ui.CreateOptionsPanel) then return nil end
    if midnightPanel then return midnightPanel end
    local P = ui.CreateOptionsPanel({
        name = "RepBarOptionsMidnight",
        title = L.OPT_TITLE, accent = ACCENT_REP })
    midnightPanel = P
    P:Note(L.OPT_HINT)

    local function check(label, key, after, tooltip)
        P:Check(label,
            function() return db and db[key] end,
            function(v) if db then db[key] = v end ; if after then after() end ; UpdateBar() end,
            tooltip)
    end

    -- Styles
    P:Section(L.OPT_SEC_PRESETS)
    local function preset(label, name)
        P:Button(label, function() ApplyPreset(name) ; P:Refresh() end)
    end
    preset(L.OPT_PRESET_THIN,     "thin")
    preset(L.OPT_PRESET_CLASSIC,  "classic")
    preset(L.OPT_PRESET_VERTICAL, "vertical")

    -- Dimensions (minimum 4 px : le style Fine doit rester dans la plage)
    P:Section(L.OPT_SEC_DIMENSIONS)
    P:Slider(L.OPT_WIDTH, 200, 1200, 10,
        function() return db and db.width or 600 end,
        function(v) if db then db.width = v end ; ApplySize() ; LayoutLabels() ; UpdateBar() end)
    P:Slider(L.OPT_HEIGHT, 4, 60, 1,
        function() return db and db.height or 22 end,
        function(v) if db then db.height = v end ; ApplySize() ; LayoutLabels() ; UpdateBar() end)

    -- Apparence
    P:Section(L.OPT_SEC_APPEARANCE)
    P:Slider(L.OPT_OPACITY, 0, 100, 5,
        function() return math.floor(((db and db.bgA) or 0.85) * 100 + 0.5) end,
        function(v) if db then db.bgA = v / 100 end ; ApplyAppearance() end)
    P:Slider(L.OPT_FONTSIZE, 8, 20, 1,
        function() return (db and db.fontSize and db.fontSize > 0) and db.fontSize or 10 end,
        function(v) if db then db.fontSize = v end ; ApplyFont() end)
    P:Color(L.OPT_COL_BAR,
        function() return { db.barR, db.barG, db.barB, db.barA } end,
        function(r, g, b, a) db.barR, db.barG, db.barB, db.barA = r, g, b, a ; UpdateBar() end)
    check(L.OPT_STANDCOL, "useStandingColor")
    check(L.OPT_TICKS,    "showTicks", function() LayoutTicks() end)

    -- Affichage
    P:Section(L.OPT_SEC_DISPLAY)
    check(L.OPT_SHOWZONE,      "showZone")
    check(L.OPT_SHOWNUM,       "showNumbers")
    check(L.OPT_SHOWPCT,       "showPercent")
    check(L.OPT_RATE,          "showRate")
    check(L.OPT_FLOAT,         "showFloating")
    check(L.OPT_WARBAND,       "showWarband")
    check(L.OPT_RENOWN_REWARD, "showRenownReward")

    -- Parangon
    P:Section(L.OPT_SEC_PARAGON)
    check(L.OPT_PARAGON_ALERT, "paragonAlert", RequestParagonScan)
    check(L.OPT_PARAGON_ALL,   "paragonAllExp", RequestParagonScan, L.OPT_PARAGON_ALL_TT)

    -- Factions epinglees
    P:Section(L.OPT_SEC_PINS)
    P:Note(L.OPT_PINS_NOTE)
    check(L.OPT_SHOWPINS, "showPins")
    P:Slider(L.OPT_PINHEIGHT, 4, 24, 1,
        function() return db and db.pinHeight or 12 end,
        function(v) if db then db.pinHeight = v end ; UpdateBar() end)
    P:Button(L.OPT_PIN_CURRENT, function() TogglePin(GetWatchedFactionID()) end)
    P:Button(L.OPT_PIN_CLEAR, function() if db then wipe(db.pinned) end ; UpdateBar() end)

    -- Comportement
    P:Section(L.OPT_SEC_BEHAVIOR)
    check(L.OPT_SWITCHQ,    "switchOnQuest")
    check(L.OPT_CLICKCYCLE, "clickCycle")
    check(L.OPT_SNAP,       "snapToXPBar", function() ApplyPosition() end, L.OPT_SNAP_TT)

    -- Visibilite
    P:Section(L.OPT_SEC_VISIBILITY)
    check(L.OPT_HIDENOFAC,  "hideWhenNoFaction")
    check(L.OPT_HIDENATIVE, "hideNativeRepBar", nil, L.OPT_HIDENATIVE_TT)
    check(L.OPT_HIDECOMBAT, "hideInCombat")
    check(L.OPT_MOUSEOVER,  "mouseoverOnly")

    -- Orientation
    P:Section(L.OPT_SEC_ORIENTATION)
    P:Check(L.OPT_VERTBAR,
        function() return db and db.orientation == "VERTICAL" end,
        function(v)
            if db then db.orientation = v and "VERTICAL" or "HORIZONTAL" end
            ApplyOrientation() ; UpdateBar()
        end)
    check(L.OPT_VERTTEXT, "verticalText", function() LayoutLabels() end)
    P:Slider(L.OPT_VTHICK, 8, 60, 1,
        function() return db and db.vWidth or 24 end,
        function(v) if db then db.vWidth = v end
            if IsVertical() then ApplySize() end ; UpdateBar() end)
    P:Slider(L.OPT_VLENGTH, 100, 900, 10,
        function() return db and db.vHeight or 300 end,
        function(v) if db then db.vHeight = v end
            if IsVertical() then ApplySize() end ; UpdateBar() end)

    -- Session et position
    P:Section(L.OPT_SEC_SESSION)
    P:Button(L.OPT_RESETSESS, function()
        ResetSession() ; UpdateBar()
        print("|cffFFD700[RepBar]|r " .. L.SESSION_RESET)
    end)
    P:Button(L.OPT_RESETPOS, function()
        if not (db and containerFrame) then return end
        db.posX, db.posY, db.anchor = DEFAULTS.posX, DEFAULTS.posY, DEFAULTS.anchor
        db.snapToXPBar = false
        ApplyPosition()
        P:Refresh()
        print("|cffFFD700[RepBar]|r " .. L.POS_RESET)
    end)

    -- Bouton flottant (mode suite uniquement : l'etat vit dans TibiSuiteDB)
    if _G.TibiSuite and _G.TibiSuite.SetCtrlHidden then
        P:Section(L.OPT_SEC_FLOATING)
        P:Check(L.OPT_HIDE_OPTIONS_BTN,
            function() return TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("RepBarContainer", "options") end,
            function(v) TibiSuite.SetCtrlHidden("RepBarContainer", "options", v) end)
    end

    return midnightPanel
end

function RepBar_OpenOptions()
    local p = BuildMidnightOptions()
    if p then p:Toggle() else print("|cffFFD700[RepBar]|r " .. L.NO_SOCLE) end
end

-- Bouton texte "Options" sur la barre. Idempotente (_tibiControls) : aussi
-- appelee par RepBar_Module.lua.
function RepBar_Decorate()
    local ui = TibiUI()
    if not (ui and ui.AddHeaderControls and containerFrame) then return end
    if containerFrame._tibiControls then return end
    ui.AddHeaderControls(containerFrame, {
        accent = ACCENT_REP,
        onOptions = function() RepBar_OpenOptions() end,
    })
end

-- ══════════════════════════════════════════════════
-- SLASH
-- ══════════════════════════════════════════════════
SLASH_REPBAR1 = "/repbar"
SlashCmdList["REPBAR"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" or msg == "config" or msg == "options" then
        RepBar_OpenOptions()
    elseif msg == "hide" then
        if containerFrame then containerFrame:Hide() end
        if db then db.manuallyHidden = true end
        print("|cffFFD700[RepBar]|r " .. L.SLASH_HIDDEN)
    elseif msg == "show" then
        if db then db.manuallyHidden = false end
        if containerFrame then containerFrame:Show() ; UpdateBar() end
    elseif msg == "pin" or msg == "unpin" then
        TogglePin(GetWatchedFactionID())
    elseif msg == "session" then
        ResetSession() ; UpdateBar()
        print("|cffFFD700[RepBar]|r " .. L.SESSION_RESET)
    elseif msg == "reset" then
        RepBarDB = nil ; ReloadUI()
    else
        print("|cffFFD700[RepBar]|r " .. L.SLASH_HELP)
    end
end

-- ══════════════════════════════════════════════════
-- EVENTS
-- ══════════════════════════════════════════════════
local evFrame = CreateFrame("Frame")
evFrame:RegisterEvent("ADDON_LOADED")
evFrame:RegisterEvent("PLAYER_LOGIN")
evFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evFrame:RegisterEvent("UPDATE_FACTION")
evFrame:RegisterEvent("QUEST_TURNED_IN")
evFrame:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
evFrame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
evFrame:RegisterEvent("ZONE_CHANGED")
evFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
evFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
evFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
evFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evFrame:RegisterEvent("PLAYER_LEVEL_UP")

local function AfterLogin()
    ApplyPosition()   -- XPBar (charge apres RepBar) existe maintenant : aimantation
    RequestUpdate()
    RequestParagonScan()
    RepBar_Decorate()
end

evFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 and string.lower(arg1) == string.lower(ADDON) then
            InitDB()
            CreateMainBar()
            if IsLoggedIn() then
                EnforceNativeRepBar()
                -- Laisse RenTracker positionner la faction de zone avant le 1er rendu.
                C_Timer.After(0.5, UpdateBar)
                C_Timer.After(1.0, AfterLogin)
            end
        end

    elseif event == "PLAYER_LOGIN" then
        if not db then InitDB() end
        EnforceNativeRepBar()
        C_Timer.After(0.5, UpdateBar)
        C_Timer.After(1.0, AfterLogin)
        -- En mode suite, c'est le core qui annonce la suite (reglage
        -- « Messages de connexion ») : pas de ligne par module.
        if not HasCore() then
            local ver = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or ""
            print("|cFF5CADF5RepBar|r v" .. ver .. " " .. L.LOGIN_LOADED .. " |cFFFFD700/repbar|r " .. L.LOGIN_TO_OPEN)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        RequestUpdate()

    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED_INDOORS" then
        -- RenTracker change la faction suivie sur ces memes evenements ; on
        -- rafraichit apres lui (leger differe pour laisser passer son handler).
        C_Timer.After(0.15, RequestUpdate)

    elseif event == "QUEST_TURNED_IN" then
        questArmed = GetTime()   -- arme la fenetre de bascule par quete
        RequestUpdate()
        RequestParagonScan()

    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        OnGainMessage(arg1)

    elseif event == "UPDATE_FACTION" or event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" then
        RequestUpdate()
        RequestParagonScan()

    elseif event == "PLAYER_LEVEL_UP" then
        -- Au niveau max, la reputation passe dans l'emplacement principal.
        C_Timer.After(0.5, RequestUpdate)

    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        ApplyVisibility()

    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        ApplyVisibility()
        EnforceNativeRepBar()   -- rend ou coupe la souris native reportee pendant le combat
    end
end)
