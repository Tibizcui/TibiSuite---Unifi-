-- XPBar.lua v7.1.5.43
-- Barre XP avancée - Tibiscui
-- Maj+Drag pour déplacer | Maj+Clic droit pour les options

local ADDON = "XPBar"

-- ══════════════════════════════════════════════════
-- LOCALISATION
-- Le francais reste le defaut embarque directement ici (via l'operateur
-- "or"). Les fichiers Locale\ se chargent AVANT ce fichier (voir XPBar.toc) :
-- enUS.lua sert de base a tout client non francais, puis le fichier de la
-- langue du client (deDE, esES...) surcharge. Une cle absente d'une langue
-- retombe donc sur l'anglais, et seulement en dernier recours sur le francais.
-- ══════════════════════════════════════════════════
XPBarL = XPBarL or {}
local L = XPBarL
L.LEVEL            = L.LEVEL            or "Niveau"
L.XP               = L.XP               or "XP"
L.PROGRESS         = L.PROGRESS         or "Progression"
L.REMAINING        = L.REMAINING        or "Restant"
L.RESTED           = L.RESTED           or "Repos"
L.QUESTS           = L.QUESTS           or "Quêtes"
L.QUESTS_DONE      = L.QUESTS_DONE      or "Quêtes terminées"
L.SESSION          = L.SESSION          or "Session"
L.XP_PER_HOUR      = L.XP_PER_HOUR      or "XP/heure"
L.XP_PER_HOUR_ROLL = L.XP_PER_HOUR_ROLL or "XP/h (récent)"
L.TIME_LEFT        = L.TIME_LEFT        or "Temps restant"
L.PLAYED           = L.PLAYED           or "Joué"
L.LEVELS_GAINED    = L.LEVELS_GAINED    or "Niveaux gagnés"
L.QUESTS_TURNED    = L.QUESTS_TURNED    or "Quêtes rendues"
L.HINT             = L.HINT             or "|cffFFD700Maj+Drag|r déplacer  ·  |cffFFD700Maj+Clic droit|r options"
L.POS_SAVED        = L.POS_SAVED        or "Position sauvegardée."
L.POS_RESET        = L.POS_RESET        or "Position réinitialisée."
L.SESSION_RESET    = L.SESSION_RESET    or "Session réinitialisée."
L.XP_DISABLED      = L.XP_DISABLED      or "XP bloquée"
-- Options (panneau standalone)
L.OPT_TITLE       = L.OPT_TITLE       or "XPBar - Options"
L.OPT_TAB         = L.OPT_TAB         or "Options"
L.OPT_HINT        = L.OPT_HINT        or "|cffFFD700Maj+Drag|r sur la barre pour la déplacer, |cffFFD700Maj+Clic droit|r pour ouvrir ou fermer ce panneau."
L.OPT_WIDTH       = L.OPT_WIDTH       or "Largeur :"
L.OPT_HEIGHT      = L.OPT_HEIGHT      or "Hauteur :"
L.OPT_COLORS      = L.OPT_COLORS      or "Couleurs"
L.OPT_COL_BAR     = L.OPT_COL_BAR     or "Couleur de la barre XP"
L.OPT_COL_QUEST   = L.OPT_COL_QUEST   or "Couleur des quêtes terminées"
L.OPT_COL_RESTED  = L.OPT_COL_RESTED  or "Couleur du repos"
L.OPT_COL_INC     = L.OPT_COL_INC     or "Couleur des quêtes en cours"
L.OPT_OPACITY     = L.OPT_OPACITY     or "Opacité fond :"
L.OPT_FONTSIZE    = L.OPT_FONTSIZE    or "Taille texte :"
L.OPT_DISPLAY     = L.OPT_DISPLAY     or "Affichage"
L.OPT_PLAYED      = L.OPT_PLAYED      or "Temps joué"
L.OPT_SESSION     = L.OPT_SESSION     or "Temps de session"
L.OPT_LEVELING    = L.OPT_LEVELING    or "Temps restant & XP/heure"
L.OPT_COMPLETED   = L.OPT_COMPLETED   or "Quêtes terminées & Repos"
L.OPT_ROLLING     = L.OPT_ROLLING     or "XP/h sur période récente"
L.OPT_INCBAR      = L.OPT_INCBAR      or "Barre des quêtes incomplètes"
L.OPT_MAXLEVEL    = L.OPT_MAXLEVEL    or "Afficher au niveau max"
L.OPT_RESETRELOAD = L.OPT_RESETRELOAD or "Réinitialiser la session à chaque /reload"
L.OPT_HIDENATIVE  = L.OPT_HIDENATIVE  or "Masquer les barres natives (XP et réputation)"
L.OPT_HIDECOMBAT  = L.OPT_HIDECOMBAT  or "Masquer en combat"
L.OPT_HIDEVEHICLE = L.OPT_HIDEVEHICLE or "Masquer en véhicule"
L.OPT_MOUSEOVER   = L.OPT_MOUSEOVER   or "Afficher au survol seulement"
L.OPT_CLOSE       = L.OPT_CLOSE       or "Fermer"
L.OPT_RESETPOS    = L.OPT_RESETPOS    or "Réinitialiser la position"
L.OPT_RESETSESS   = L.OPT_RESETSESS   or "Réinitialiser la session"
L.OPT_SEC_ORIENTATION = L.OPT_SEC_ORIENTATION or "Orientation"
L.OPT_VERTBAR         = L.OPT_VERTBAR         or "Barre verticale"
L.OPT_VERTTEXT        = L.OPT_VERTTEXT        or "Texte a cote (vertical)"
L.OPT_VTHICK          = L.OPT_VTHICK          or "Epaisseur :"
L.OPT_VLENGTH         = L.OPT_VLENGTH         or "Longueur :"
-- Slash / login / debug
L.SLASH_HIDDEN   = L.SLASH_HIDDEN   or "Masqué. /xpbar show pour ré-afficher."
L.SLASH_HELP     = L.SLASH_HELP     or " /xpbar - options  |  /xpbar hide/show  |  /xpbar session  |  /xpbar history  |  /xpbar reset"
L.SLASH_HELP_DBG = L.SLASH_HELP_DBG or "  /xpbar debug - identifier les frames XP natifs"
L.LOGIN_LOADED   = L.LOGIN_LOADED   or "chargé -- tapez"
L.LOGIN_TO_OPEN  = L.LOGIN_TO_OPEN  or "pour les options."
L.DEBUG_HEADER   = L.DEBUG_HEADER   or "Frames XP détectés :"
L.DEBUG_HIDDEN   = L.DEBUG_HIDDEN   or "caché"
L.DEBUG_MISSING  = L.DEBUG_MISSING  or "inexistant"
L.DEBUG_CHILDREN = L.DEBUG_CHILDREN or "Enfants de MainMenuBar :"
-- Options (panneau integre TibiSuite "Midnight") - wording parfois different
-- du panneau standalone, d'ou les cles distinctes suffixees _2.
L.OPT_SEC_DIMENSIONS = L.OPT_SEC_DIMENSIONS or "Dimensions"
L.OPT_WIDTH_2        = L.OPT_WIDTH_2        or "Largeur"
L.OPT_HEIGHT_2       = L.OPT_HEIGHT_2       or "Hauteur"
L.OPT_PLAYED_2       = L.OPT_PLAYED_2       or "Temps de jeu total"
L.OPT_LEVELING_2     = L.OPT_LEVELING_2     or "Temps estimé avant le niveau suivant"
L.OPT_COMPLETED_2    = L.OPT_COMPLETED_2    or "Quêtes terminées (%)"
L.OPT_ROLLING_2      = L.OPT_ROLLING_2      or "XP/h sur les 15 dernières minutes"
L.OPT_INCBAR_2       = L.OPT_INCBAR_2       or "Barre des quêtes incomplètes"
L.OPT_SEC_VISIBILITY = L.OPT_SEC_VISIBILITY or "Visibilité"
L.OPT_VERTTEXT_2     = L.OPT_VERTTEXT_2     or "Texte à côté de la barre (vertical)"
L.OPT_VTHICK_2       = L.OPT_VTHICK_2       or "Épaisseur (vertical)"
L.OPT_VLENGTH_2      = L.OPT_VLENGTH_2      or "Longueur (vertical)"
L.OPT_SEC_FLOATING   = L.OPT_SEC_FLOATING   or "Bouton flottant"
L.OPT_HIDE_OPTIONS_BTN= L.OPT_HIDE_OPTIONS_BTN or "Masquer le bouton Options"
-- Panneau unifie (lot 2) : reglages auparavant reserves a l'ancien panneau.
L.OPT_SEC_APPEARANCE = L.OPT_SEC_APPEARANCE or "Apparence"
L.OPT_OPACITY_2      = L.OPT_OPACITY_2      or "Opacité du fond (%)"
L.OPT_FONTSIZE_2     = L.OPT_FONTSIZE_2     or "Taille du texte"
L.OPT_XPPERHOUR      = L.OPT_XPPERHOUR      or "XP par heure"
L.OPT_RESTED_TXT     = L.OPT_RESTED_TXT     or "XP de repos (%)"
L.OPT_SHOWBAR        = L.OPT_SHOWBAR        or "Afficher la barre"
L.OPT_SEC_SESSION    = L.OPT_SEC_SESSION    or "Session"
-- Lot 3 : progression enrichie, historique, reputation au niveau max, styles
L.QUEST_XP           = L.QUEST_XP           or "XP des quêtes terminées"
L.PROJ_XP            = L.PROJ_XP            or "XP des quêtes en cours"
L.QUEST_LEVELUP      = L.QUEST_LEVELUP      or "Rendre les quêtes terminées suffit pour passer de niveau !"
L.LEVEL_TIME         = L.LEVEL_TIME         or "Temps sur ce niveau"
L.PREV_LEVEL         = L.PREV_LEVEL         or "Niveau %d bouclé en"
L.KILLS_LEFT         = L.KILLS_LEFT         or "Monstres restants (estimation)"
L.QUESTS_LEFT        = L.QUESTS_LEFT        or "Quêtes restantes (estimation)"
L.LEVEL_REACHED      = L.LEVEL_REACHED      or "Niveau %d atteint : niveau %d bouclé en %s de jeu."
L.HISTORY_HEADER     = L.HISTORY_HEADER     or "Temps de jeu par niveau (%s) :"
L.HISTORY_EMPTY      = L.HISTORY_EMPTY      or "Aucun niveau enregistré pour ce personnage (il faut passer un niveau avec XPBar actif)."
L.NO_WATCHED_REP     = L.NO_WATCHED_REP     or "Aucune réputation suivie"
L.PARAGON            = L.PARAGON            or "Parangon"
L.RENOWN             = L.RENOWN             or "Renom"
L.OPT_SEC_PROGRESS   = L.OPT_SEC_PROGRESS   or "Progression"
L.OPT_QUESTXP        = L.OPT_QUESTXP        or "XP réelle des quêtes terminées (orange)"
L.OPT_PROJECTION     = L.OPT_PROJECTION     or "Projection des quêtes en cours"
L.OPT_RESTZONE       = L.OPT_RESTZONE       or "Zone et repère du bonus de repos"
L.OPT_TICKS          = L.OPT_TICKS          or "Graduations tous les 10 %"
L.OPT_FLOATXP        = L.OPT_FLOATXP        or "Texte flottant à chaque gain d'XP"
L.OPT_ESTIMATES      = L.OPT_ESTIMATES      or "Monstres et quêtes restants (infobulle)"
L.OPT_REPATMAX       = L.OPT_REPATMAX       or "Réputation suivie au niveau max"
L.OPT_REPATMAX_TT    = L.OPT_REPATMAX_TT    or "Au niveau maximum, la barre affiche la réputation suivie (celle cochée dans le panneau Réputation) au lieu de disparaître."
L.OPT_CLASSCOLOR     = L.OPT_CLASSCOLOR     or "Barre à la couleur de la classe"
L.OPT_SEC_PRESETS    = L.OPT_SEC_PRESETS    or "Styles prêts à l'emploi"
L.OPT_PRESET_THIN    = L.OPT_PRESET_THIN    or "Style Fine (8 px)"
L.OPT_PRESET_CLASSIC = L.OPT_PRESET_CLASSIC or "Style Classique"
L.OPT_PRESET_VERTICAL= L.OPT_PRESET_VERTICAL or "Style Verticale"
-- Textes de la barre
L.LEVEL_SHORT        = L.LEVEL_SHORT        or "Nv"
L.COLON              = L.COLON              or " : "   -- espace avant les deux-points en francais

-- ══════════════════════════════════════════════════
-- DEFAULTS
-- ══════════════════════════════════════════════════
local DEFAULTS = {
    posX   = 0, posY = -120, anchor = "TOP",
    width  = 600, height = 22,           -- dimensions en mode HORIZONTAL
    orientation  = "HORIZONTAL",         -- "HORIZONTAL" (defaut) ou "VERTICAL"
    vWidth  = 24,                        -- epaisseur en mode VERTICAL
    vHeight = 300,                       -- longueur en mode VERTICAL
    verticalText = false,                -- afficher le texte a cote de la barre en vertical
    showPlayedTime       = true,
    showSessionTime      = true,
    showLevelingTime     = true,
    showXPPerHour        = true,
    showRollingXP        = true,   -- XP/h sur fenêtre glissante plutôt que moyenne de session
    showCompletedQuests  = true,
    showRestedText       = true,
    showIncompleteBar    = false,
    showAtMaxLevel       = false,
    resetSessionOnReload = false,
    hideDefaultXPBar     = true,   -- masquée par défaut dès l'installation
    hideInCombat         = false,
    hideInVehicle        = false,
    mouseoverOnly        = false,
    hidden               = false,  -- masquee a la main (/xpbar hide, onglet de la suite), persiste
    sessionStartTime    = 0,      -- epoch (time()) du début de session, persiste entre /reload
    sessionXPGained      = 0,      -- XP cumulée depuis sessionStartTime, persiste entre /reload
    sessionLevels        = 0,      -- niveaux gagnés dans la session
    sessionQuests        = 0,      -- quêtes rendues dans la session
    lastLogout           = 0,      -- epoch de la dernière déconnexion, distingue /reload et vraie session
    bgA        = 0.85,             -- opacité du fond sombre
    fontSize   = 0,                -- 0 = taille par défaut du modèle
    barR = 0.55, barG = 0.27, barB = 0.80, barA = 1.0,
    qR   = 1.00, qG   = 0.65, qB   = 0.00, qA   = 1.0,
    rR   = 0.40, rG   = 0.70, rB   = 1.00, rA   = 1.0,
    incR = 0.60, incG = 0.60, incB = 0.60, incA = 0.4,
    -- Lot 3 : progression enrichie
    showQuestXP     = true,    -- segment orange = XP reelle des quetes terminees
    showProjection  = true,    -- segment translucide = XP des quetes en cours
    showRestedZone  = true,    -- zone du bonus de repos + repere de fin
    showTicks       = true,    -- graduations tous les 10 %
    showFloatingXP  = true,    -- texte "+1 234 XP" a chaque gain
    showEstimates   = true,    -- monstres / quetes restants (infobulle)
    repAtMaxLevel   = false,   -- au niveau max : reputation suivie a la place de l'XP
    classColorBar   = false,   -- barre a la couleur de la classe
    -- levelLog (table, creee dans InitDB) : [ "Nom-Royaume" ] = { [niveau] = secondes jouees sur ce niveau }
}

-- ══════════════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════════════
local db
local mainBar, questSegment, restedSegment, incompleteBar, bgTexture
local projSegment, restMarker        -- lot 3 : projection des quetes en cours, fin du repos
local ticks          = {}            -- lot 3 : 9 graduations (10 % a 90 %)
local floatPool      = {}            -- lot 3 : textes flottants "+XP" recycles
local killGains      = {}            -- lot 3 : derniers gains hors quetes (runtime)
local questGains     = {}            -- lot 3 : derniers gains de quetes (runtime)
local lastKillGain                   -- { t, amount } : dernier gain classe "hors quete"
local pendingQuestXP  = 0            -- recompense annoncee par QUEST_TURNED_IN, pas encore vue
local pendingQuestAt  = 0            -- GetTime() de cette annonce
local playedLevelBase      = 0       -- temps joue sur le niveau (TIME_PLAYED_MSG arg2)
local playedLevelQueryTime = 0
local labelLeft, labelCenter, labelRight, labelBottom
local containerFrame, dragFrame, optionsFrame
local playedTimeBase      = 0   -- /played total au dernier RequestTimePlayed()
local playedTimeQueryTime = 0   -- time() epoch au moment de la requête
local mouseIsOver         = false
local xpSamples           = {}  -- échantillons {t, total} pour l'XP/h glissant (runtime, non sauvegardé)
local ROLLING_WINDOW      = 900 -- fenêtre glissante : 15 minutes
local SESSION_GRACE       = 300 -- 5 min : en deca, un retour en jeu prolonge la session (/reload)
local questCache          = { 0, 0, 0, 0, 0, 0 }  -- completedPct, incompletePct, completed, total, completeXP, incompleteXP
local questDirty          = true  -- journal a relire (QUEST_LOG_UPDATE, QUEST_TURNED_IN)
local updatePending       = false -- un UpdateBar est deja programme pour la prochaine image
local nativeHiddenByUs    = false -- les barres natives ont ete masquees par XPBar
local inCombat            = false -- suivi via PLAYER_REGEN_* (voir EVENTS)

-- Forward declarations (évite les nil au moment des scripts / captures d'upvalues)
local UpdateBar, RequestUpdate, CreateOptionsPanel
local ApplySize, ApplyAppearance, ApplyFont, ApplyVisibility, EnforceNativeBar
local ApplyOrientation, LayoutLabels, LayoutTicks

-- ══════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════

-- Orientation courante et dimensions actives selon celle-ci.
local function IsVertical() return db and db.orientation == "VERTICAL" end
-- Barre horizontale trop basse pour y ecrire (moins de 14 px) : textes dessous.
local function IsThin() return db and not IsVertical() and (db.height or 22) < 14 end
local function ActiveSize()
    if IsVertical() then return db.vWidth or 24, db.vHeight or 300 end
    return db.width or 600, db.height or 22
end

local function FormatTime(seconds)
    seconds = math.floor(seconds or 0)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return string.format("%dh%02dm", h, m)
    elseif m > 0 then return string.format("%dm%02ds", m, s)
    else return string.format("%ds", s) end
end

-- Durée de session en secondes, basée sur l'horloge réelle (time()) pour
-- survivre aux /reload, contrairement à GetTime() qui repart de zéro.
local function GetSessionElapsed()
    if not db or not db.sessionStartTime or db.sessionStartTime == 0 then return 0 end
    return time() - db.sessionStartTime
end

-- XP/heure : moyenne sur toute la session
local function GetXPPerHour()
    local elapsed = GetSessionElapsed()
    local gained  = (db and db.sessionXPGained) or 0
    if elapsed > 60 and gained > 0 then
        return gained / elapsed * 3600
    end
    return 0
end

-- Enregistre un échantillon (temps, XP cumulée) pour l'XP/h glissant,
-- et purge ceux qui sortent de la fenêtre.
local function PushXPSample()
    local now = time()
    xpSamples[#xpSamples + 1] = { t = now, total = (db and db.sessionXPGained) or 0 }
    local cutoff = now - ROLLING_WINDOW
    while xpSamples[1] and xpSamples[1].t < cutoff do
        table.remove(xpSamples, 1)
    end
end

-- XP/heure sur la fenêtre glissante récente (plus réactif que la moyenne de session)
local function GetRollingXPPerHour()
    local n = #xpSamples
    if n < 2 then return 0 end
    local first, last = xpSamples[1], xpSamples[n]
    local span = last.t - first.t
    local gain = last.total - first.total
    if span >= 60 and gain > 0 then
        return gain / span * 3600
    end
    return 0
end

-- XP/heure « effectif » : privilégie le glissant s'il est disponible, sinon la moyenne de session
local function GetEffectiveXPPerHour()
    if db and db.showRollingXP then
        local r = GetRollingXPPerHour()
        if r > 0 then return r end
    end
    return GetXPPerHour()
end

local function GetPlayedTime()
    -- Avant la réception de TIME_PLAYED_MSG, playedTimeQueryTime vaut 0 :
    -- sans ce garde, la formule renverrait l'epoch courant (~1,7 milliard de s).
    if playedTimeQueryTime == 0 then return 0 end
    return playedTimeBase + (time() - playedTimeQueryTime)
end

local function GetXPData()
    local cur  = UnitXP("player")
    local max  = UnitXPMax("player")
    local rest = GetXPExhaustion() or 0
    local pct     = max > 0 and (cur / max)  or 0
    local restPct = max > 0 and (rest / max) or 0
    return cur, max, rest, pct, restPct
end

-- XP bloquee volontairement (PNJ de verrouillage d'XP) : la barre reste figee,
-- on l'indique au lieu de laisser croire a un bug.
local function IsXPLocked()
    return IsXPUserDisabled and IsXPUserDisabled() and true or false
end

-- Lecture du journal de quetes, mise en cache : le parcours complet n'a lieu
-- que si le journal a change depuis (questDirty), et non plus a chaque
-- rafraichissement de la barre ou a chaque survol.
local function GetQuestData()
    if not questDirty then
        return questCache[1], questCache[2], questCache[3], questCache[4]
    end
    questDirty = false
    local completed, total = 0, 0
    local completeXP, incompleteXP = 0, 0
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local n = C_QuestLog.GetNumQuestLogEntries()
        for i = 1, n do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and not info.isHidden and info.questID then
                total = total + 1
                -- isComplete sur info peut être nil en Retail 12.x
                -- C_QuestLog.IsComplete() détecte les quêtes avec objectifs remplis
                -- même si elles ne sont pas encore rendues au PNJ
                local isComplete = info.isComplete
                    or (C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID))
                -- XP de recompense (lot 3). Peut valoir 0 tant que le client n'a
                -- pas recu les donnees de la quete : QUEST_LOG_UPDATE suivra.
                local xp = 0
                if GetQuestLogRewardXP then
                    local ok, v = pcall(GetQuestLogRewardXP, info.questID)
                    if ok and type(v) == "number" then xp = v end
                end
                if isComplete then
                    completed = completed + 1
                    completeXP = completeXP + xp
                else
                    incompleteXP = incompleteXP + xp
                end
            end
        end
    end
    local completedPct  = total > 0 and (completed / total * 100) or 0
    local incompletePct = total > 0 and ((total - completed) / total) or 0
    questCache[1], questCache[2], questCache[3], questCache[4] = completedPct, incompletePct, completed, total
    questCache[5], questCache[6] = completeXP, incompleteXP
    return completedPct, incompletePct, completed, total
end

-- XP en attente dans le journal : quetes terminees (a rendre) et en cours.
local function GetQuestXP()
    GetQuestData()   -- relit le journal seulement s'il a change
    return questCache[5], questCache[6]
end

-- Temps joue sur le niveau courant (TIME_PLAYED_MSG arg2), nil si inconnu.
local function GetLevelPlayed()
    if playedLevelQueryTime == 0 then return nil end
    return playedLevelBase + (time() - playedLevelQueryTime)
end

local function CharKey()
    local name  = UnitName("player") or "?"
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or "?"
    return name .. "-" .. realm
end

-- ── Estimations "monstres / quetes restants" ────────────────────────────
-- On garde les 20 derniers gains de chaque type ; la MEDIANE resiste aux
-- valeurs extremes (exploration, bonus ponctuels) mieux que la moyenne.
local GAIN_KEEP = 20
local function PushGain(list, amount)
    list[#list + 1] = amount
    if #list > GAIN_KEEP then table.remove(list, 1) end
end
local function Median(list)
    local n = #list
    if n == 0 then return 0 end
    local s = {}
    for i = 1, n do s[i] = list[i] end
    table.sort(s)
    if n % 2 == 1 then return s[(n + 1) / 2] end
    return (s[n / 2] + s[n / 2 + 1]) / 2
end

-- ── Reputation suivie (mode "niveau max") ───────────────────────────────
-- Reprise de RepBar (ReadReputation / GetWatchedFactionID, validees en jeu),
-- reduite a ce dont XPBar a besoin. Retourne { name, label, cur, max, pct,
-- color } ou nil si aucune faction n'est suivie.
local function ApplyParagon(factionID, o)
    if not (C_Reputation and C_Reputation.IsFactionParagon and C_Reputation.GetFactionParagonInfo) then return false end
    local pok, isP = pcall(C_Reputation.IsFactionParagon, factionID)
    if not (pok and isP) then return false end
    local gok, val, thr = pcall(C_Reputation.GetFactionParagonInfo, factionID)
    if not (gok and val and thr and thr > 0) then return false end
    o.label, o.cur, o.max = L.PARAGON, val % thr, thr
    o.pct   = o.cur / thr
    o.color = { 1.00, 0.85, 0.40 }
    return true
end

local function ReadWatchedReputation()
    local factionID
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local ok, d = pcall(C_Reputation.GetWatchedFactionData)
        if ok and d and d.factionID and d.factionID ~= 0 then factionID = d.factionID end
    end
    if not factionID then return nil end
    local out = {}

    if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
        local ok, fr = pcall(C_GossipInfo.GetFriendshipReputation, factionID)
        if ok and fr and fr.friendshipFactionID and fr.friendshipFactionID ~= 0 then
            out.name, out.label, out.color = fr.name, fr.reaction or "", { 0.25, 0.80, 0.45 }
            local minv, maxv = fr.reactionThreshold or 0, fr.nextThreshold or 0
            if maxv > minv then
                out.cur, out.max = (fr.standing or 0) - minv, maxv - minv
                out.pct = out.cur / out.max
            else
                out.cur, out.max, out.pct = 1, 1, 1
            end
            return out
        end
    end

    if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
        local ok, d = pcall(C_MajorFactions.GetMajorFactionData, factionID)
        if ok and d and (d.renownLevel or d.renownLevelThreshold) then
            out.name  = d.name
            out.label = L.RENOWN .. " " .. tostring(d.renownLevel or 0)
            out.cur   = d.renownReputationEarned or 0
            out.max   = d.renownLevelThreshold or 1
            out.pct   = out.max > 0 and math.min(1, out.cur / out.max) or 0
            out.color = { 0.36, 0.68, 0.96 }
            local isCap = false
            if C_MajorFactions.HasMaximumRenown then
                local cok, c = pcall(C_MajorFactions.HasMaximumRenown, factionID)
                isCap = cok and c
            end
            if isCap and not ApplyParagon(factionID, out) then out.cur, out.pct = out.max, 1 end
            return out
        end
    end

    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, d = pcall(C_Reputation.GetFactionDataByID, factionID)
        if ok and d then
            local reaction = d.reaction or 4
            out.name  = d.name
            out.label = _G["FACTION_STANDING_LABEL" .. reaction] or ""
            local c = _G.FACTION_BAR_COLORS and _G.FACTION_BAR_COLORS[reaction]
            out.color = c and { c.r, c.g, c.b } or { 0.6, 0.6, 0.6 }
            local minv, maxv = d.currentReactionThreshold or 0, d.nextReactionThreshold or 0
            if maxv > minv then
                out.cur, out.max = (d.currentStanding or 0) - minv, maxv - minv
                out.pct = out.cur / out.max
            else
                out.cur, out.max, out.pct = 1, 1, 1
            end
            if reaction >= 8 then out.pct = 1; ApplyParagon(factionID, out) end
            return out
        end
    end
    return nil
end

local function IsAtMaxLevel()
    local maxLvl = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 999
    return UnitLevel("player") >= maxLvl
end

-- Mode reputation actif : niveau max ET option cochee.
local function InRepMode()
    return db and db.repAtMaxLevel and IsAtMaxLevel()
end

-- Couleur de la barre : couleur de classe si l'option est cochee.
local function BarColor()
    if db.classColorBar then
        local _, class = UnitClass("player")
        local c = class and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
            or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
        if c then return c.r, c.g, c.b, db.barA or 1 end
    end
    return db.barR, db.barG, db.barB, db.barA
end

-- ══════════════════════════════════════════════════
-- INIT DB
-- ══════════════════════════════════════════════════
local function InitDB()
    XPBarDB = XPBarDB or {}
    db = XPBarDB
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    -- Table creee a part (et non dans DEFAULTS) pour ne jamais partager une
    -- meme table entre les valeurs par defaut et la sauvegarde.
    if type(db.levelLog) ~= "table" then db.levelLog = {} end
end

-- Point de reference pour le calcul des gains d'XP : XP courante ET plafond
-- du niveau courant (le plafond sert a compter le reste de l'ancien niveau
-- lors d'un passage de niveau).
local function SnapshotXP()
    db.lastXP    = UnitXP("player")
    db.lastXPMax = UnitXPMax("player")
end

-- Remet a zero les compteurs de session (bouton, /xpbar session, nouvelle session).
local function ResetSession()
    db.sessionStartTime = time()
    db.sessionXPGained  = 0
    db.sessionLevels    = 0
    db.sessionQuests    = 0
    wipe(xpSamples)
    SnapshotXP()
    PushXPSample()
end

-- Au login (ou au chargement tardif) : on distingue un /reload d'une vraie
-- nouvelle session de jeu. PLAYER_LOGOUT (declenche aussi par /reload)
-- horodate db.lastLogout. Au-dela de SESSION_GRACE, nouvelle session ; en
-- deca (typiquement un /reload de quelques secondes), on conserve la session.
local function StartOrResumeSession()
    local isNewSession = (db.sessionStartTime == 0)
        or (db.lastLogout > 0 and (time() - db.lastLogout) > SESSION_GRACE)
    if db.resetSessionOnReload or isNewSession then
        ResetSession()
    else
        wipe(xpSamples)
        SnapshotXP()
        PushXPSample()   -- point de depart pour l'XP/h glissant
    end
    if RequestTimePlayed then RequestTimePlayed() end
end

-- ══════════════════════════════════════════════════
-- SAVE POSITION
-- ══════════════════════════════════════════════════
local function SavePosition()
    if not containerFrame then return end
    local point, _, _, x, y = containerFrame:GetPoint()
    db.anchor = point
    db.posX   = math.floor(x + 0.5)
    db.posY   = math.floor(y + 0.5)
end

-- ══════════════════════════════════════════════════
-- APPLY SIZE (redimensionnement à chaud)
-- ══════════════════════════════════════════════════
ApplySize = function()
    if not containerFrame then return end
    local w, h = ActiveSize()
    -- Hauteur sous la barre : ligne de stats (20) en horizontal, plus la
    -- ligne des trois labels (14) en barre fine ; rien en vertical.
    local extra = IsVertical() and 0 or (IsThin() and 34 or 20)
    containerFrame:SetSize(w, h + extra)
    mainBar:SetSize(w, h)
    incompleteBar:SetSize(w, h)
    dragFrame:SetSize(w, h + extra)
    -- La taille transversale des segments est fixee dans UpdateBar selon
    -- l'orientation (largeur en horizontal, hauteur en vertical).
    if LayoutTicks then LayoutTicks() end
    if LayoutLabels then LayoutLabels() end   -- une barre fine deplace ses labels
end

-- Replace les 4 labels selon l'orientation (et l'option "texte a cote").
LayoutLabels = function()
    if not labelLeft then return end
    for _, fs in ipairs({ labelLeft, labelCenter, labelRight, labelBottom }) do
        fs:ClearAllPoints() ; fs:Show()
    end
    if IsThin() then
        -- Barre fine (style "Fine") : trop basse pour du texte, les trois
        -- labels passent SOUS la barre, et la ligne de stats d'un cran plus
        -- bas. Pas au-dessus : le socle y pose le bouton flottant "Options"
        -- (BOTTOMRIGHT sur le coin haut-droit), qui recouvrait le pourcentage.
        labelLeft:SetPoint("TOPLEFT", mainBar, "BOTTOMLEFT", 2, -2)     ; labelLeft:SetJustifyH("LEFT")
        labelCenter:SetPoint("TOP", mainBar, "BOTTOM", 0, -2)           ; labelCenter:SetJustifyH("CENTER")
        labelRight:SetPoint("TOPRIGHT", mainBar, "BOTTOMRIGHT", -2, -2) ; labelRight:SetJustifyH("RIGHT")
        labelBottom:SetPoint("TOP", mainBar, "BOTTOM", 0, -16)
    elseif not IsVertical() then
        labelLeft:SetPoint("LEFT", mainBar, "LEFT", 8, 0)      ; labelLeft:SetJustifyH("LEFT")
        labelCenter:SetPoint("CENTER", mainBar, "CENTER", 0, 0); labelCenter:SetJustifyH("CENTER")
        labelRight:SetPoint("RIGHT", mainBar, "RIGHT", -8, 0)  ; labelRight:SetJustifyH("RIGHT")
        labelBottom:SetPoint("TOP", mainBar, "BOTTOM", 0, -2)
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

-- Applique l'orientation a la barre (et a la barre des quetes incompletes)
-- puis reajuste taille et labels.
ApplyOrientation = function()
    if not mainBar then return end
    local o = IsVertical() and "VERTICAL" or "HORIZONTAL"
    mainBar:SetOrientation(o)
    if incompleteBar then incompleteBar:SetOrientation(o) end
    ApplySize()
    LayoutLabels()
end

-- ══════════════════════════════════════════════════
-- APPLY FONT / APPARENCE
-- ══════════════════════════════════════════════════
ApplyFont = function()
    if not labelLeft then return end
    for _, fs in ipairs({ labelLeft, labelCenter, labelRight, labelBottom }) do
        local path, size, flags = fs:GetFont()
        -- Taille d'origine du modele memorisee au premier passage : "0 = par
        -- defaut" doit y revenir, et non garder la derniere taille appliquee.
        fs._xpbBaseSize = fs._xpbBaseSize or size
        local newSize = (db.fontSize and db.fontSize > 0) and db.fontSize or fs._xpbBaseSize
        if path then fs:SetFont(path, newSize, flags) end
    end
end

ApplyAppearance = function()
    if bgTexture then bgTexture:SetColorTexture(0.05, 0.05, 0.05, db.bgA or 0.85) end
    ApplyFont()
end

-- Le module a-t-il ete decoche dans le panneau Modules du core ? Meme
-- convention que XPBar_Module.lua. BUG CORRIGE ICI : rien dans ce fichier ne
-- consultait ce flag auparavant - la barre s'affichait toujours, meme
-- decochee, a chaque /reload ou demarrage de session (meme bug que RepBar).
local function IsEnabledByCore()
    if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
    return TibiSuiteDB.enabledModules.XPBar == true
end

-- ══════════════════════════════════════════════════
-- VISIBILITÉ CONTEXTUELLE (combat / véhicule / survol / niveau max)
-- Retourne true si la barre reste visible, false si masquée.
-- ══════════════════════════════════════════════════
ApplyVisibility = function()
    if not containerFrame or not db then return false end

    if not IsEnabledByCore() or db.hidden then
        containerFrame:Hide() ; return false
    end

    if IsAtMaxLevel() and not db.showAtMaxLevel and not db.repAtMaxLevel then
        containerFrame:Hide() ; return false
    end
    if db.hideInCombat and (inCombat or InCombatLockdown()) then
        containerFrame:Hide() ; return false
    end
    if db.hideInVehicle and UnitInVehicle and UnitInVehicle("player") then
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
-- BARRE XP NATIVE (Retail 12.x = StatusTrackingBarManager)
--
-- IMPORTANT (piege reel, corrige) : NE JAMAIS faire SetScript("OnShow", ...)
-- sur ce frame (ni sur ses enfants). SetScript REMPLACE le gestionnaire
-- existant au lieu de s'y ajouter (contrairement a HookScript) : si Blizzard
-- affiche ce frame depuis un contexte qu'on ne maitrise pas (gain de
-- reputation/XP, etc.) et que notre propre gestionnaire ecrase le sien,
-- c'est exactement le genre d'action qui declenche "action reservee a l'IU
-- de Blizzard". On ne touche donc plus JAMAIS a Show/Hide/SetScript sur ce
-- frame : seule l'opacite (SetAlpha) est modifiee, reaffirmee a chaque appel
-- de UpdateBar() (deja declenche sur tous les evenements XP/quete/repos
-- pertinents), jamais via un hook.
--
-- 12.x : depuis Dragonflight, les barres VISIBLES vivent dans deux conteneurs
-- du mode Edition (MainStatusTrackingBarContainer, SecondaryStatusTrackingBar-
-- Container), pas forcement enfants de StatusTrackingBarManager. On les vise
-- donc directement, en plus du manager (compatibilite). Masquer ces conteneurs
-- masque AUSSI la reputation / l'honneur : c'est dit dans le libelle.
--
-- Une frame a alpha 0 capte encore la souris (infobulle native sur une zone
-- invisible) : on coupe la souris des conteneurs masques, hors combat
-- uniquement, et on la rend quand l'option est decochee.
--
-- Option decochee : on n'ecrit PLUS rien a chaque rafraichissement (sinon
-- l'alpha 1 ecraserait EllesmereUI, Opacity ou un fondu de Blizzard). Une
-- seule restauration, et seulement si c'est XPBar qui avait masque.
-- ══════════════════════════════════════════════════
local NATIVE_BARS = { "StatusTrackingBarManager", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }

local function NativeFrame(name)
    local f = _G[name]
    if f and f.SetAlpha and not (f.IsForbidden and f:IsForbidden()) then return f end
end

local function SetNativeAlpha(alpha)
    for _, name in ipairs(NATIVE_BARS) do
        local f = NativeFrame(name)
        if f then
            f:SetAlpha(alpha)
            local n = f.GetNumChildren and f:GetNumChildren() or 0
            for i = 1, n do
                local child = select(i, f:GetChildren())
                if child and child.SetAlpha then child:SetAlpha(alpha) end
            end
        end
    end
end

-- Hors combat uniquement (l'appelant verifie). Le manager n'est pas touche :
-- seuls les conteneurs visibles et leurs barres (qui portent l'infobulle
-- native) sont concernes.
-- A la coupure, l'etat d'origine de chaque frame est memorise ; a la
-- restauration, on ne rend la souris qu'a celles qui l'avaient.
local mouseSaved = {}
local function SetNativeMouse(on)
    local function apply(fr)
        if not (fr and fr.EnableMouse and fr.IsMouseEnabled) then return end
        if fr.IsForbidden and fr:IsForbidden() then return end
        if on then
            if mouseSaved[fr] then pcall(fr.EnableMouse, fr, true) end
        else
            mouseSaved[fr] = fr:IsMouseEnabled() and true or false
            pcall(fr.EnableMouse, fr, false)
        end
    end
    for i = 2, #NATIVE_BARS do
        local f = NativeFrame(NATIVE_BARS[i])
        if f then
            apply(f)
            local n = f.GetNumChildren and f:GetNumChildren() or 0
            for j = 1, n do apply((select(j, f:GetChildren()))) end
        end
    end
    if on then wipe(mouseSaved) end
end

local nativeMouseOff = false  -- souris des conteneurs natifs coupee par XPBar

EnforceNativeBar = function()
    local combat = InCombatLockdown()
    if db.hideDefaultXPBar then
        -- L'alpha est reaffirme a chaque fois (Blizzard le remet en fondu) ;
        -- la souris n'est coupee qu'une fois, des qu'on est hors combat.
        SetNativeAlpha(0)
        nativeHiddenByUs = true
        if not nativeMouseOff and not combat then
            SetNativeMouse(false) ; nativeMouseOff = true
        end
    else
        if nativeHiddenByUs then
            SetNativeAlpha(1) ; nativeHiddenByUs = false
        end
        if nativeMouseOff and not combat then
            SetNativeMouse(true) ; nativeMouseOff = false
        end
    end
end

-- ══════════════════════════════════════════════════
-- CRÉATION UI
-- ══════════════════════════════════════════════════
local function CreateMainBar()
    -- Conteneur principal
    containerFrame = CreateFrame("Frame", "XPBarContainer", UIParent)
    containerFrame:SetFrameStrata("MEDIUM")
    containerFrame:SetSize(db.width, db.height + 20)
    containerFrame:SetPoint(db.anchor, UIParent, db.anchor, db.posX, db.posY)
    containerFrame:SetMovable(true)
    containerFrame:SetClampedToScreen(true)

    -- ── Frame invisible pour le drag (Button = supporte RegisterForDrag) ──
    dragFrame = CreateFrame("Button", "XPBarDragFrame", containerFrame)
    dragFrame:SetAllPoints(containerFrame)
    dragFrame:SetFrameStrata("HIGH")
    dragFrame:EnableMouse(true)
    dragFrame:RegisterForDrag("LeftButton")
    dragFrame:RegisterForClicks("RightButtonUp")
    dragFrame:SetAlpha(0)   -- invisible (l'alpha n'affecte pas la capture souris)

    local isMoving = false
    dragFrame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            isMoving = true
            containerFrame:StartMoving()
            mainBar:SetAlpha(0.6)
        end
    end)
    dragFrame:SetScript("OnDragStop", function(self)
        -- Ne rien faire si le déplacement n'avait pas été initié (drag sans Maj) :
        -- évite un faux message « Position sauvegardée ».
        if not isMoving then return end
        isMoving = false
        containerFrame:StopMovingOrSizing()
        mainBar:SetAlpha(1.0)
        SavePosition()
        print("|cffFFD700[XPBar]|r " .. L.POS_SAVED)
    end)
    dragFrame:SetScript("OnClick", function(self, button)
        if button == "RightButton" and IsShiftKeyDown() then
            XPBar_ToggleOptions()
        end
    end)

    -- Tooltip + gestion du survol (mouseoverOnly)
    dragFrame:SetScript("OnEnter", function(self)
        mouseIsOver = true
        ApplyVisibility()

        -- Mode reputation (niveau max) : infobulle dediee, courte.
        if InRepMode() then
            local rep = ReadWatchedReputation()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("XPBar", 0.55, 0.27, 0.80)
            GameTooltip:AddLine(" ")
            if rep then
                GameTooltip:AddLine(rep.name or "?", 1, 1, 1)
                GameTooltip:AddDoubleLine(rep.label or "", string.format("%d / %d (%.1f%%)", rep.cur, rep.max, rep.pct * 100), 1,.82,0, 1,1,1)
            else
                GameTooltip:AddLine(L.NO_WATCHED_REP, .8, .8, .8)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.HINT, .8,.8,.8)
            GameTooltip:Show()
            return
        end

        local cur, max, rest, pct, restPct = GetXPData()
        local elapsed   = GetSessionElapsed()
        local xpPerHour = GetXPPerHour()
        local rolling   = GetRollingXPPerHour()
        local effective = GetEffectiveXPPerHour()
        local timeToLvl = effective > 0 and ((max - cur) / effective * 3600) or 0
        local _, _, completed, total = GetQuestData()
        local questXP, projXP = GetQuestXP()
        local remaining = max - cur

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("XPBar", 0.55, 0.27, 0.80)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L.XP,        string.format("%d / %d", cur, max), 1,.82,0, 1,1,1)
        GameTooltip:AddDoubleLine(L.PROGRESS,  string.format("%.1f%%", pct*100),   1,.82,0, 1,1,1)
        GameTooltip:AddDoubleLine(L.REMAINING, string.format("%d XP", remaining),  1,.82,0, 1,1,1)
        if IsXPLocked() then
            GameTooltip:AddLine(L.XP_DISABLED, 1, .4, .4)
        end
        local lvlTime = GetLevelPlayed()
        if lvlTime then
            GameTooltip:AddDoubleLine(L.LEVEL_TIME, FormatTime(lvlTime), 1,.82,0, 1,1,1)
        end
        local log  = db.levelLog and db.levelLog[CharKey()]
        local prev = UnitLevel("player") - 1
        if log and log[prev] then
            GameTooltip:AddDoubleLine(string.format(L.PREV_LEVEL, prev), FormatTime(log[prev]), 1,.82,0, .8,.8,.8)
        end
        if rest > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(L.RESTED, string.format("%d XP (%.1f%%)", rest, restPct*100), 1,.82,0, .6,.8,1)
        end
        if total > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(L.QUESTS, string.format("%d / %d", completed, total), 1,.82,0, 1,.6,0)
            if questXP > 0 then
                GameTooltip:AddDoubleLine(L.QUEST_XP, string.format("%d XP (%.1f%%)", questXP, max > 0 and questXP / max * 100 or 0), 1,.82,0, 1,.6,0)
                if questXP >= remaining and remaining > 0 then
                    GameTooltip:AddLine(L.QUEST_LEVELUP, 1, .82, 0)
                end
            end
            if projXP > 0 then
                GameTooltip:AddDoubleLine(L.PROJ_XP, string.format("%d XP (%.1f%%)", projXP, max > 0 and projXP / max * 100 or 0), 1,.82,0, .7,.7,.7)
            end
        end
        -- Estimations : combien de gains "typiques" (mediane des 20 derniers)
        -- pour finir le niveau. Indicatif : l'exploration ou la recolte
        -- comptent comme des gains hors quetes.
        if db.showEstimates and remaining > 0 then
            local k, q = Median(killGains), Median(questGains)
            if k > 0 or q > 0 then GameTooltip:AddLine(" ") end
            if k > 0 then
                GameTooltip:AddDoubleLine(L.KILLS_LEFT, string.format("~%d  (%d XP)", math.ceil(remaining / k), k), 1,.82,0, 1,1,1)
            end
            if q > 0 then
                GameTooltip:AddDoubleLine(L.QUESTS_LEFT, string.format("~%d  (%d XP)", math.ceil(remaining / q), q), 1,.82,0, 1,1,1)
            end
        end
        if elapsed > 60 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(L.SESSION,     FormatTime(elapsed),                1,.82,0, 1,1,1)
            GameTooltip:AddDoubleLine(L.XP_PER_HOUR, string.format("%.0f", xpPerHour),   1,.82,0, 1,1,1)
            if rolling > 0 then
                GameTooltip:AddDoubleLine(L.XP_PER_HOUR_ROLL, string.format("%.0f", rolling), 1,.82,0, .7,1,.7)
            end
            if timeToLvl > 0 then
                GameTooltip:AddDoubleLine(L.TIME_LEFT, FormatTime(timeToLvl), 1,.82,0, 1,1,1)
            end
            GameTooltip:AddDoubleLine(L.LEVELS_GAINED, tostring(db.sessionLevels or 0), 1,.82,0, 1,1,1)
            GameTooltip:AddDoubleLine(L.QUESTS_TURNED, tostring(db.sessionQuests or 0), 1,.82,0, 1,1,1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.HINT, .8,.8,.8)
        GameTooltip:Show()
    end)
    dragFrame:SetScript("OnLeave", function()
        mouseIsOver = false
        ApplyVisibility()
        GameTooltip:Hide()
    end)

    -- ── Barre principale XP ───────────────────────
    mainBar = CreateFrame("StatusBar", "XPBarMain", containerFrame)
    mainBar:SetSize(db.width, db.height)
    mainBar:SetPoint("TOP", containerFrame, "TOP", 0, 0)
    mainBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    mainBar:SetStatusBarColor(db.barR, db.barG, db.barB, db.barA)
    mainBar:SetMinMaxValues(0, 1)
    mainBar:SetValue(0)

    -- Fond sombre posé sur le CONTENEUR (et non sur mainBar) afin de rester
    -- SOUS la barre des quêtes incomplètes. S'il était opaque sur mainBar,
    -- il masquerait entièrement incompleteBar, rendant l'option invisible.
    bgTexture = containerFrame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetPoint("TOPLEFT",     mainBar, "TOPLEFT",     0, 0)
    bgTexture:SetPoint("BOTTOMRIGHT", mainBar, "BOTTOMRIGHT", 0, 0)
    bgTexture:SetColorTexture(0.05, 0.05, 0.05, db.bgA or 0.85)

    local border = CreateFrame("Frame", nil, mainBar, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 6,
        insets   = { left=1, right=1, top=1, bottom=1 },
    })
    border:SetBackdropBorderColor(0, 0, 0, 0.7)

    -- ── Barre quêtes incomplètes ──────────────────
    incompleteBar = CreateFrame("StatusBar", nil, containerFrame)
    incompleteBar:SetSize(db.width, db.height)
    incompleteBar:SetPoint("TOP", containerFrame, "TOP", 0, 0)
    incompleteBar:SetFrameLevel(mainBar:GetFrameLevel() - 1)
    incompleteBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    incompleteBar:SetStatusBarColor(db.incR, db.incG, db.incB, db.incA)
    incompleteBar:SetMinMaxValues(0, 1)
    incompleteBar:SetValue(0)
    incompleteBar:Hide()

    -- ── Segments (lot 3 : proportionnels a l'XP reelle) ───
    -- Ordre d'empilement (sous-niveaux OVERLAY) : zone de repos (0) sous la
    -- projection des quetes en cours (1), sous l'XP des quetes terminees (2),
    -- puis repere de fin du repos (3), graduations (4), textes (7).
    local function seg(sub)
        local t = mainBar:CreateTexture(nil, "OVERLAY", nil, sub)
        t:SetTexture("Interface/TargetingFrame/UI-StatusBar")
        t:Hide()
        return t
    end
    restedSegment = seg(0)
    projSegment   = seg(1)
    questSegment  = seg(2)
    restMarker    = mainBar:CreateTexture(nil, "OVERLAY", nil, 3)
    restMarker:SetColorTexture(1, 1, 1, 1)
    restMarker:Hide()
    for i = 1, 9 do
        local t = mainBar:CreateTexture(nil, "OVERLAY", nil, 4)
        t:SetColorTexture(1, 1, 1, 0.22)
        ticks[i] = t
    end

    -- ── Labels ────────────────────────────────────
    labelLeft = mainBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelLeft:SetDrawLayer("OVERLAY", 7)
    labelLeft:SetPoint("LEFT", mainBar, "LEFT", 8, 0)
    labelLeft:SetTextColor(1, 1, 1, 1)

    labelCenter = mainBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelCenter:SetDrawLayer("OVERLAY", 7)
    labelCenter:SetPoint("CENTER", mainBar, "CENTER", 0, 0)
    labelCenter:SetTextColor(1, 1, 1, 1)

    labelRight = mainBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelRight:SetDrawLayer("OVERLAY", 7)
    labelRight:SetPoint("RIGHT", mainBar, "RIGHT", -8, 0)
    labelRight:SetTextColor(1, 1, 1, 1)

    labelBottom = containerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelBottom:SetPoint("TOP", mainBar, "BOTTOM", 0, -2)
    labelBottom:SetTextColor(0.7, 0.7, 0.7, 1)

    ApplyAppearance()
    ApplyOrientation()   -- fixe l'orientation, la taille et l'ancrage des labels
end

-- ══════════════════════════════════════════════════
-- UPDATE BAR
-- ══════════════════════════════════════════════════
-- Place une texture sur la plage [from, to] (fractions 0..1) le long de la
-- barre : gauche->droite en horizontal, bas->haut en vertical, avec un
-- retrait de 2 px sur chaque bord (cadre de la bordure).
local function PlaceRange(tex, from, to)
    from = math.max(0, math.min(1, from))
    to   = math.max(0, math.min(1, to))
    if to <= from then tex:Hide() ; return end
    local w0, h0 = ActiveSize()
    local vert   = IsVertical()
    local len    = (vert and h0 or w0) - 4
    local thick  = math.max(1, (vert and w0 or h0) - 4)
    local size   = math.max(1, (to - from) * len)
    tex:ClearAllPoints()
    if vert then
        tex:SetSize(thick, size)
        tex:SetPoint("BOTTOM", mainBar, "BOTTOM", 0, 2 + from * len)
    else
        tex:SetSize(size, thick)
        tex:SetPoint("LEFT", mainBar, "LEFT", 2 + from * len, 0)
    end
    tex:Show()
end

-- Repere fin (2 px) a la position frac, pleine epaisseur de la barre.
local function PlaceMarker(tex, frac)
    local w0, h0 = ActiveSize()
    local vert   = IsVertical()
    local len    = (vert and h0 or w0) - 4
    tex:ClearAllPoints()
    if vert then
        tex:SetSize(math.max(1, w0 - 2), 2)
        tex:SetPoint("BOTTOM", mainBar, "BOTTOM", 0, 2 + frac * len - 1)
    else
        tex:SetSize(2, math.max(1, h0 - 2))
        tex:SetPoint("LEFT", mainBar, "LEFT", 2 + frac * len - 1, 0)
    end
    tex:Show()
end

-- Graduations tous les 10 %. Appelee au changement de taille/orientation.
LayoutTicks = function()
    if not ticks[1] then return end
    local w0, h0 = ActiveSize()
    local vert   = IsVertical()
    local len    = (vert and h0 or w0) - 4
    for i = 1, 9 do
        local t = ticks[i]
        t:ClearAllPoints()
        if db.showTicks and not InRepMode() then
            if vert then
                t:SetSize(math.max(1, w0 - 4), 1)
                t:SetPoint("BOTTOM", mainBar, "BOTTOM", 0, 2 + i / 10 * len)
            else
                t:SetSize(1, math.max(1, h0 - 4))
                t:SetPoint("LEFT", mainBar, "LEFT", 2 + i / 10 * len, 0)
            end
            t:Show()
        else
            t:Hide()
        end
    end
end

local function HideProgressExtras()
    questSegment:Hide() ; projSegment:Hide() ; restedSegment:Hide() ; restMarker:Hide()
    incompleteBar:Hide()
end

-- Mode reputation (niveau max + option) : la barre suit la faction surveillee.
local function UpdateRepMode()
    HideProgressExtras()
    local rep = ReadWatchedReputation()
    if not rep then
        mainBar:SetValue(0)
        labelLeft:SetText("") ; labelRight:SetText("")
        labelCenter:SetText("|cffaaaaaa" .. L.NO_WATCHED_REP .. "|r")
        labelBottom:Hide()
        return
    end
    mainBar:SetValue(rep.pct or 0)
    mainBar:SetStatusBarColor(rep.color[1], rep.color[2], rep.color[3], db.barA or 1)
    if IsVertical() then
        if db.verticalText then
            labelLeft:SetText(rep.label or "")
            labelCenter:SetText("")
            labelRight:SetText(string.format("%.0f%%", (rep.pct or 0) * 100))
        end
        labelBottom:Hide()
        return
    end
    labelLeft:SetText(" " .. (rep.name or ""))
    labelCenter:SetText(string.format("|cffffff99%d|r / |cffffff99%d|r", rep.cur or 0, rep.max or 0))
    labelRight:SetText(string.format("%s  |cffffffff%.1f%%|r", rep.label or "", (rep.pct or 0) * 100))
    labelBottom:Hide()
end

UpdateBar = function()
    if not mainBar or not db then return end

    EnforceNativeBar()
    if not ApplyVisibility() then return end

    if InRepMode() then
        LayoutTicks()
        UpdateRepMode()
        return
    end

    local cur, max, rest, pct, restPct              = GetXPData()
    local questPct, incompletePct, completed, total  = GetQuestData()
    local questXP, projXP                            = GetQuestXP()
    local lvl = UnitLevel("player")
    local questFrac = max > 0 and questXP / max or 0
    local projFrac  = max > 0 and projXP / max or 0

    mainBar:SetValue(pct)
    mainBar:SetStatusBarColor(BarColor())
    questSegment:SetVertexColor(db.qR, db.qG, db.qB, db.qA)
    projSegment:SetVertexColor(db.incR, db.incG, db.incB, math.max(0.25, db.incA or 0.4))
    restedSegment:SetVertexColor(db.rR, db.rG, db.rB, (db.rA or 1) * 0.45)
    restMarker:SetVertexColor(db.rR, db.rG, db.rB, 1)

    -- Barre quêtes incomplètes
    if db.showIncompleteBar and incompletePct > 0 then
        incompleteBar:SetStatusBarColor(db.incR, db.incG, db.incB, db.incA)
        incompleteBar:SetValue(incompletePct)
        incompleteBar:Show()
    else
        incompleteBar:Hide()
    end

    -- Labels selon l'orientation
    if IsVertical() then
        if db.verticalText then
            labelLeft:SetText(string.format("|cffddbbff%s %d|r", L.LEVEL_SHORT, lvl))
            labelCenter:SetText("")
            labelRight:SetText(string.format("%.0f%%", pct * 100))
        end
    else
        labelLeft:SetText(string.format("|cffddbbff %s %d|r", L.LEVEL, lvl))
        if max > 0 then
            labelCenter:SetText(string.format("|cffffff99%d|r / |cffffff99%d|r", cur, max))
        else
            labelCenter:SetText("")
        end
        local rightTxt = string.format("|cffffffff%.1f%%|r", pct * 100)
        if IsXPLocked() then
            rightTxt = string.format("|cffff6666%s|r  ", L.XP_DISABLED) .. rightTxt
        else
            -- XP des quetes a rendre, en orange (et en or si elle boucle le niveau).
            if db.showQuestXP and questFrac > 0 then
                local col = (pct + questFrac >= 1) and "ffd100" or "ff9900"
                rightTxt = rightTxt .. string.format(" |cff%s+%.1f%%|r", col, questFrac * 100)
            end
            if restPct > 0 then
                rightTxt = rightTxt .. string.format(" |cff99ccff(%.1f%%)|r", (pct + restPct) * 100)
            end
        end
        labelRight:SetText(rightTxt)
    end

    -- Segments proportionnels (lot 3), tous partant de la fin de l'XP
    -- actuelle : quetes terminees (a rendre), puis projection des quetes en
    -- cours a la suite ; la zone de repos court en dessous depuis le meme
    -- point, avec un repere a sa fin.
    local questEnd = pct
    if db.showQuestXP and questFrac > 0 then
        questEnd = math.min(1, pct + questFrac)
        PlaceRange(questSegment, pct, questEnd)
    else
        questSegment:Hide()
    end
    if db.showProjection and projFrac > 0 then
        PlaceRange(projSegment, questEnd, questEnd + projFrac)
    else
        projSegment:Hide()
    end
    if db.showRestedZone and restPct > 0 then
        local restEnd = math.min(1, pct + restPct)
        PlaceRange(restedSegment, pct, restEnd)
        if restEnd < 1 then PlaceMarker(restMarker, restEnd) else restMarker:Hide() end
    else
        restedSegment:Hide() ; restMarker:Hide()
    end

    -- Ligne du bas (uniquement en horizontal ; masquee en vertical)
    if IsVertical() then
        labelBottom:Hide()
        return
    end
    local parts = {}
    local C = L.COLON   -- " : " en francais, ": " ailleurs, "：" en chinois
    if db.showCompletedQuests and total > 0 then
        table.insert(parts, string.format("%s%s|cffff9900%.1f%%|r", L.QUESTS_DONE, C, questPct))
    end
    if db.showRestedText and restPct > 0 then
        table.insert(parts, string.format("%s%s|cff66b3ff%.1f%%|r", L.RESTED, C, restPct * 100))
    end
    if db.showPlayedTime then
        table.insert(parts, string.format("|cffcccccc%s%s%s|r", L.PLAYED, C, FormatTime(GetPlayedTime())))
    end
    if db.showSessionTime then
        table.insert(parts, string.format("|cffcccccc%s%s%s|r", L.SESSION, C, FormatTime(GetSessionElapsed())))
    end
    if db.showXPPerHour or db.showLevelingTime then
        local perHour = GetEffectiveXPPerHour()
        if db.showXPPerHour and perHour > 0 then
            table.insert(parts, string.format("|cffaaffaa%s%s%.0f|r", L.XP_PER_HOUR, C, perHour))
        end
        if db.showLevelingTime and perHour > 0 and max > cur then
            table.insert(parts, string.format("|cffaaffaa~%s|r", FormatTime((max - cur) / perHour * 3600)))
        end
    end

    if #parts > 0 then
        labelBottom:SetText(table.concat(parts, " - "))
        labelBottom:Show()
    else
        labelBottom:Hide()
    end
end

-- Rafraichissement regroupe : plusieurs evenements dans la meme image
-- (QUEST_LOG_UPDATE arrive souvent en rafale avec PLAYER_XP_UPDATE) ne
-- declenchent qu'un seul UpdateBar, a l'image suivante.
RequestUpdate = function()
    if updatePending then return end
    updatePending = true
    C_Timer.After(0, function()
        updatePending = false
        UpdateBar()
    end)
end

-- ══════════════════════════════════════════════════
-- TEXTE FLOTTANT "+XP" (lot 3)
-- Petit pool de FontStrings recycles, chacune avec son animation (montee +
-- fondu). Aucun OnUpdate : le moteur d'animation de WoW fait le travail et
-- s'arrete seul. Le texte part de l'extremite de la zone remplie.
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
    -- Pool plein : on recycle le plus ancien.
    local fs = table.remove(floatPool, 1)
    fs.anim:Stop()
    floatPool[#floatPool + 1] = fs
    return fs
end

local function ShowFloatingXP(amount, isQuest)
    if not (db and db.showFloatingXP and containerFrame and containerFrame:IsShown()) then return end
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
    if isQuest then fs:SetTextColor(1, 0.65, 0) else fs:SetTextColor(0.87, 0.73, 1) end
    fs:SetText(string.format("+%s XP", BreakUpLargeNumbers and BreakUpLargeNumbers(amount) or tostring(amount)))
    fs:SetAlpha(1)
    fs:Show()
    fs.anim:Play()
end

-- ══════════════════════════════════════════════════
-- STYLES PRETS A L'EMPLOI (lot 3)
-- Ne touchent qu'a la forme (taille, orientation, police, ligne du bas) :
-- couleurs et options de contenu restent celles du joueur.
-- ══════════════════════════════════════════════════
local PRESETS = {
    thin     = { orientation = "HORIZONTAL", width = 600, height = 8,  fontSize = 9,
                 showPlayedTime = false, showSessionTime = false },
    classic  = { orientation = "HORIZONTAL", width = 600, height = 22, fontSize = 0,
                 showPlayedTime = true,  showSessionTime = true },
    vertical = { orientation = "VERTICAL",   vWidth = 24, vHeight = 300, verticalText = true },
}

local function ApplyPreset(name)
    local p = PRESETS[name]
    if not (p and db) then return end
    for k, v in pairs(p) do db[k] = v end
    ApplyOrientation()   -- enchaine ApplySize, graduations et labels
    ApplyFont()
    UpdateBar()
end

-- ══════════════════════════════════════════════════
-- PANEL D'OPTIONS - widgets réutilisables
-- ANCIEN PANNEAU, CONSERVE EN SECOURS UNIQUEMENT : depuis le lot 2, toutes
-- les entrees (Maj+clic droit, /xpbar, menu des addons) ouvrent le panneau
-- unifie (BuildMidnightOptions, plus bas). Ce code ne sert que si le socle
-- TibiMidnight etait absent, ce qui ne devrait jamais arriver.
-- ══════════════════════════════════════════════════
local function MakeCheckbox(parent, lbl, x, y, getF, setF)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetChecked(getF())
    cb:SetScript("OnClick", function(self)
        setF(self:GetChecked() and true or false)
        UpdateBar()
    end)
    local txt = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    txt:SetText(lbl)
    return cb
end

local function MakeSlider(parent, label, x, y, minV, maxV, step, getV, applyV)
    local cap = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cap:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cap:SetText(label)
    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val:SetPoint("LEFT", cap, "RIGHT", 8, 0)
    val:SetTextColor(1, 0.82, 0)

    local sl = CreateFrame("Slider", nil, parent)
    sl:SetSize(200, 16)
    sl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 18)
    sl:SetOrientation("HORIZONTAL")
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    sl:SetObeyStepOnDrag(true)
    sl:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")
    sl:GetThumbTexture():SetSize(16, 16)
    local tr = sl:CreateTexture(nil, "BACKGROUND")
    tr:SetTexture("Interface/Buttons/UI-SliderBar-Background")
    tr:SetPoint("TOPLEFT", sl, "TOPLEFT", 0, -4)
    tr:SetPoint("BOTTOMRIGHT", sl, "BOTTOMRIGHT", 0, 4)
    tr:SetHorizTile(true)

    local function fmt(v)
        if step < 1 then return string.format("%.2f", v) else return tostring(math.floor(v + 0.5)) end
    end
    sl:SetValue(getV())
    val:SetText(fmt(getV()))
    sl:SetScript("OnValueChanged", function(self, v)
        if step >= 1 then v = math.floor(v / step + 0.5) * step end
        val:SetText(fmt(v))
        applyV(v)
    end)
    return sl
end

-- Sélecteur de couleur (bouton coloré ouvrant le ColorPickerFrame)
local function MakeColorSwatch(parent, label, x, y, getFn, setFn)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(18, 18)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local bord = btn:CreateTexture(nil, "BACKGROUND")
    bord:SetPoint("TOPLEFT", -1, 1)
    bord:SetPoint("BOTTOMRIGHT", 1, -1)
    bord:SetColorTexture(0, 0, 0, 1)

    local swatch = btn:CreateTexture(nil, "OVERLAY")
    swatch:SetAllPoints()
    local function refresh()
        local r, g, b, a = getFn()
        swatch:SetColorTexture(r, g, b, a or 1)
    end
    refresh()

    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("LEFT", btn, "RIGHT", 6, 0)
    txt:SetText(label)

    btn:SetScript("OnClick", function()
        local r, g, b, a = getFn()
        local function apply()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local na = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or a
            setFn(nr, ng, nb, na)
            refresh()
            UpdateBar()
        end
        local info = {
            swatchFunc  = apply,
            opacityFunc = apply,
            hasOpacity  = true,
            opacity     = a,      -- API moderne : 0..1, 1 = opaque
            r = r, g = g, b = b,
            cancelFunc  = function()
                setFn(r, g, b, a) ; refresh() ; UpdateBar()
            end,
        }
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            -- Repli ancien client
            ColorPickerFrame.func         = apply
            ColorPickerFrame.opacityFunc  = apply
            ColorPickerFrame.hasOpacity   = true
            ColorPickerFrame.opacity      = 1 - (a or 1)
            ColorPickerFrame.cancelFunc   = info.cancelFunc
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame:Show()
        end
    end)
    return btn
end

-- ══════════════════════════════════════════════════
-- PANEL D'OPTIONS
-- ══════════════════════════════════════════════════
CreateOptionsPanel = function()
    if optionsFrame then
        optionsFrame:Show()
        return
    end

    optionsFrame = CreateFrame("Frame", "XPBarOptions", UIParent, "BackdropTemplate")
    optionsFrame:SetSize(520, 640)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetClampedToScreen(true)
    optionsFrame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    optionsFrame:SetScript("OnDragStop",  function(f) f:StopMovingOrSizing() end)
    optionsFrame:SetBackdrop({
        bgFile   = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        edgeSize = 24,
        insets   = { left=6, right=6, top=6, bottom=6 },
    })
    optionsFrame:SetBackdropColor(0.1, 0.1, 0.15, 0.97)

    -- ── Titre ─────────────────────────────────────
    local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", optionsFrame, "TOP", 0, -16)
    title:SetText(L.OPT_TITLE)

    -- ── Bandeau ───────────────────────────────────
    local tabBg = optionsFrame:CreateTexture(nil, "BACKGROUND")
    tabBg:SetColorTexture(0.15, 0.10, 0.25, 0.8)
    tabBg:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  10, -44)
    tabBg:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -10, -44)
    tabBg:SetHeight(20)
    local tabLbl = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tabLbl:SetPoint("CENTER", tabBg, "CENTER")
    tabLbl:SetText(L.OPT_TAB)
    tabLbl:SetTextColor(1, 0.82, 0)

    -- ── Hint raccourcis ───────────────────────────
    local hint = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 14, -70)
    hint:SetText(L.OPT_HINT)
    hint:SetTextColor(0.75, 0.75, 0.75)

    local function Sep(y)
        local s = optionsFrame:CreateTexture(nil, "BACKGROUND")
        s:SetColorTexture(0.4, 0.4, 0.4, 0.4)
        s:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  10, y)
        s:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -10, y)
        s:SetHeight(1)
    end
    local function Header(text, x, y)
        local h = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", x, y)
        h:SetText(text) ; h:SetTextColor(1, 0.82, 0)
        return h
    end

    local C1, C2 = 16, 272

    -- ── Dimensions ────────────────────────────────
    Sep(-84)
    MakeSlider(optionsFrame, L.OPT_WIDTH, C1, -96, 200, 1200, 10,
        function() return db.width end,
        function(v) db.width = v ; ApplySize() ; UpdateBar() end)
    MakeSlider(optionsFrame, L.OPT_HEIGHT, C2, -96, 10, 60, 1,
        function() return db.height end,
        function(v) db.height = v ; ApplySize() ; UpdateBar() end)

    -- ── Couleurs ──────────────────────────────────
    Sep(-140)
    Header(L.OPT_COLORS, C1, -148)
    MakeColorSwatch(optionsFrame, L.OPT_COL_BAR, C1, -170,
        function() return db.barR, db.barG, db.barB, db.barA end,
        function(r,g,b,a) db.barR,db.barG,db.barB,db.barA = r,g,b,a end)
    MakeColorSwatch(optionsFrame, L.OPT_COL_QUEST, C2, -170,
        function() return db.qR, db.qG, db.qB, db.qA end,
        function(r,g,b,a) db.qR,db.qG,db.qB,db.qA = r,g,b,a end)
    MakeColorSwatch(optionsFrame, L.OPT_COL_RESTED, C1, -196,
        function() return db.rR, db.rG, db.rB, db.rA end,
        function(r,g,b,a) db.rR,db.rG,db.rB,db.rA = r,g,b,a end)
    MakeColorSwatch(optionsFrame, L.OPT_COL_INC, C2, -196,
        function() return db.incR, db.incG, db.incB, db.incA end,
        function(r,g,b,a) db.incR,db.incG,db.incB,db.incA = r,g,b,a end)

    -- ── Apparence ─────────────────────────────────
    Sep(-220)
    MakeSlider(optionsFrame, L.OPT_OPACITY, C1, -230, 0, 1, 0.05,
        function() return db.bgA end,
        function(v) db.bgA = v ; ApplyAppearance() end)
    MakeSlider(optionsFrame, L.OPT_FONTSIZE, C2, -230, 8, 20, 1,
        function() return (db.fontSize and db.fontSize > 0) and db.fontSize or 10 end,
        function(v) db.fontSize = v ; ApplyFont() end)

    -- ── Affichage ─────────────────────────────────
    Sep(-268)
    Header(L.OPT_DISPLAY, C1, -276)
    local Y0, DY = -298, -30
    MakeCheckbox(optionsFrame, L.OPT_PLAYED,   C1, Y0,
        function() return db.showPlayedTime end,
        function(v) db.showPlayedTime = v end)
    MakeCheckbox(optionsFrame, L.OPT_SESSION,  C2, Y0,
        function() return db.showSessionTime end,
        function(v) db.showSessionTime = v end)

    MakeCheckbox(optionsFrame, L.OPT_LEVELING, C1, Y0+DY,
        function() return db.showLevelingTime end,
        function(v) db.showLevelingTime = v ; db.showXPPerHour = v end)
    MakeCheckbox(optionsFrame, L.OPT_COMPLETED, C2, Y0+DY,
        function() return db.showCompletedQuests end,
        function(v) db.showCompletedQuests = v ; db.showRestedText = v end)

    MakeCheckbox(optionsFrame, L.OPT_ROLLING, C1, Y0+DY*2,
        function() return db.showRollingXP end,
        function(v) db.showRollingXP = v end)
    MakeCheckbox(optionsFrame, L.OPT_INCBAR, C2, Y0+DY*2,
        function() return db.showIncompleteBar end,
        function(v) db.showIncompleteBar = v end)

    MakeCheckbox(optionsFrame, L.OPT_MAXLEVEL, C1, Y0+DY*3,
        function() return db.showAtMaxLevel end,
        function(v) db.showAtMaxLevel = v end)
    MakeCheckbox(optionsFrame, L.OPT_RESETRELOAD, C2, Y0+DY*3,
        function() return db.resetSessionOnReload end,
        function(v) db.resetSessionOnReload = v end)

    MakeCheckbox(optionsFrame, L.OPT_HIDENATIVE, C1, Y0+DY*4,
        function() return db.hideDefaultXPBar end,
        function(v) db.hideDefaultXPBar = v ; UpdateBar() end)
    MakeCheckbox(optionsFrame, L.OPT_HIDECOMBAT, C2, Y0+DY*4,
        function() return db.hideInCombat end,
        function(v) db.hideInCombat = v end)

    MakeCheckbox(optionsFrame, L.OPT_HIDEVEHICLE, C1, Y0+DY*5,
        function() return db.hideInVehicle end,
        function(v) db.hideInVehicle = v end)
    MakeCheckbox(optionsFrame, L.OPT_MOUSEOVER, C2, Y0+DY*5,
        function() return db.mouseoverOnly end,
        function(v) db.mouseoverOnly = v end)

    -- ── Orientation ───────────────────────────────
    Sep(-462)
    Header(L.OPT_SEC_ORIENTATION, C1, -470)
    MakeCheckbox(optionsFrame, L.OPT_VERTBAR, C1, -490,
        function() return IsVertical() end,
        function(v)
            db.orientation = v and "VERTICAL" or "HORIZONTAL"
            ApplyOrientation() ; UpdateBar()
        end)
    MakeCheckbox(optionsFrame, L.OPT_VERTTEXT, C2, -490,
        function() return db.verticalText end,
        function(v) db.verticalText = v ; LayoutLabels() ; UpdateBar() end)
    MakeSlider(optionsFrame, L.OPT_VTHICK, C1, -524, 8, 60, 1,
        function() return db.vWidth end,
        function(v) db.vWidth = v ; if IsVertical() then ApplySize() end ; UpdateBar() end)
    MakeSlider(optionsFrame, L.OPT_VLENGTH, C2, -524, 100, 900, 10,
        function() return db.vHeight end,
        function(v) db.vHeight = v ; if IsVertical() then ApplySize() end ; UpdateBar() end)

    -- ── Boutons bas ───────────────────────────────
    local closeBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    closeBtn:SetSize(110, 26)
    closeBtn:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 14)
    closeBtn:SetText(L.OPT_CLOSE)
    closeBtn:SetScript("OnClick", function() optionsFrame:Hide() end)

    local resetBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    resetBtn:SetSize(140, 26)
    resetBtn:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 16, 14)
    resetBtn:SetText(L.OPT_RESETPOS)
    resetBtn:SetScript("OnClick", function()
        db.posX = 0 ; db.posY = -120 ; db.anchor = "TOP"
        containerFrame:ClearAllPoints()
        containerFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
        SavePosition()
        print("|cffFFD700[XPBar]|r " .. L.POS_RESET)
    end)

    local sessBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    sessBtn:SetSize(140, 26)
    sessBtn:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 14)
    sessBtn:SetText(L.OPT_RESETSESS)
    sessBtn:SetScript("OnClick", function()
        ResetSession()
        UpdateBar()
        print("|cffFFD700[XPBar]|r " .. L.SESSION_RESET)
    end)

    -- Fermeture via la touche Échap (standard Blizzard)
    tinsert(UISpecialFrames, "XPBarOptions")

    optionsFrame:Show()
end

-- ══════════════════════════════════════════════════
-- POINT D'ENTREE UNIQUE DES OPTIONS
-- Panneau unifie (socle TibiSuite, toujours embarque par XPBar.toc, donc
-- present en suite comme en autonome). L'ancien panneau ci-dessus
-- (CreateOptionsPanel) n'est plus qu'un secours si le socle manquait.
-- ══════════════════════════════════════════════════
function XPBar_ToggleOptions()
    if _G.TibiMidnight and XPBar_OpenOptions then
        XPBar_OpenOptions()
    elseif optionsFrame and optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        CreateOptionsPanel()
    end
end

-- ══════════════════════════════════════════════════
-- ADDON COMPARTMENT (menu addons Retail)
-- ══════════════════════════════════════════════════
function XPBar_OnAddonCompartmentClick()
    XPBar_ToggleOptions()
end

-- ══════════════════════════════════════════════════
-- SLASH  →  /xpbar  ouvre les options
-- ══════════════════════════════════════════════════
SLASH_XPBAR1 = "/xpbar"
SLASH_XPBAR2 = "/xpbardebug"
SlashCmdList["XPBAR"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" or msg == "config" or msg == "options" then
        XPBar_ToggleOptions()
    elseif msg == "hide" then
        db.hidden = true
        containerFrame:Hide()
        print("|cffFFD700[XPBar]|r " .. L.SLASH_HIDDEN)
    elseif msg == "show" then
        db.hidden = false
        UpdateBar()
    elseif msg == "session" then
        ResetSession()
        UpdateBar()
        print("|cffFFD700[XPBar]|r " .. L.SESSION_RESET)
    elseif msg == "history" or msg == "histo" then
        -- Temps joue sur chaque niveau de CE personnage (15 derniers).
        local log = db.levelLog and db.levelLog[CharKey()]
        local levels = {}
        if log then for lvl in pairs(log) do levels[#levels + 1] = lvl end end
        if #levels == 0 then
            print("|cffFFD700[XPBar]|r " .. L.HISTORY_EMPTY)
        else
            table.sort(levels, function(a, b) return a > b end)
            print("|cffFFD700[XPBar]|r " .. string.format(L.HISTORY_HEADER, UnitName("player") or "?"))
            for i = 1, math.min(15, #levels) do
                local lvl = levels[i]
                print(string.format("  %s %d%s|cffffffff%s|r", L.LEVEL, lvl, L.COLON, FormatTime(log[lvl])))
            end
        end
    elseif msg == "reset" then
        XPBarDB = nil ; ReloadUI()
    elseif msg == "debug" then
        -- Frames 12.x de la barre native : visibilite, alpha, alpha effectif
        -- (ce que le joueur voit vraiment), souris et parent. Sert a verifier
        -- que "Masquer les barres natives" agit bien sur ce qui s'affiche.
        print("|cffFFD700[XPBar DEBUG]|r " .. L.DEBUG_HEADER)
        for _, name in ipairs(NATIVE_BARS) do
            local f = _G[name]
            if f and not (f.IsForbidden and f:IsForbidden()) then
                local shown = f:IsShown() and "|cff00ff00VISIBLE|r" or ("|cffff4444" .. L.DEBUG_HIDDEN .. "|r")
                local eff   = f.GetEffectiveAlpha and f:GetEffectiveAlpha() or f:GetAlpha()
                local mouse = (f.IsMouseEnabled and f:IsMouseEnabled()) and "on" or "off"
                local par   = f:GetParent()
                par = par and (par:GetName() or "?") or "-"
                print(string.format("  |cffffff99%s|r : %s alpha=%.2f eff=%.2f mouse=%s parent=%s",
                    name, shown, f:GetAlpha(), eff, mouse, par))
                local n = f.GetNumChildren and f:GetNumChildren() or 0
                for i = 1, n do
                    local c = select(i, f:GetChildren())
                    if c and not (c.IsForbidden and c:IsForbidden()) then
                        local ce = c.GetEffectiveAlpha and c:GetEffectiveAlpha() or c:GetAlpha()
                        local cm = (c.IsMouseEnabled and c:IsMouseEnabled()) and "on" or "off"
                        print(string.format("      %s : %s eff=%.2f mouse=%s",
                            c:GetName() or ("#" .. i), c:IsShown() and "VISIBLE" or L.DEBUG_HIDDEN, ce, cm))
                    end
                end
            else
                print(string.format("  |cff888888%s|r : %s", name, L.DEBUG_MISSING))
            end
        end
    else
        print("|cffFFD700[XPBar]|r " .. L.SLASH_HELP)
        print(L.SLASH_HELP_DBG)
    end
end

-- ══════════════════════════════════════════════════
-- EVENTS
-- ══════════════════════════════════════════════════
local function HasCore()
    return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end

local evFrame = CreateFrame("Frame")
evFrame:RegisterEvent("ADDON_LOADED")
evFrame:RegisterEvent("PLAYER_LOGIN")
evFrame:RegisterEvent("PLAYER_LOGOUT")
evFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evFrame:RegisterEvent("PLAYER_XP_UPDATE")
evFrame:RegisterEvent("PLAYER_LEVEL_UP")
evFrame:RegisterEvent("UPDATE_EXHAUSTION")
evFrame:RegisterEvent("QUEST_LOG_UPDATE")
evFrame:RegisterEvent("QUEST_TURNED_IN")
evFrame:RegisterEvent("TIME_PLAYED_MSG")
evFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
evFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
-- Mode reputation au niveau max (lot 3) : ignores hors de ce mode.
evFrame:RegisterEvent("UPDATE_FACTION")
evFrame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
-- Filtre au niveau du client : seuls les vehicules du joueur nous reveillent.
evFrame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
evFrame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")

evFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 and string.lower(arg1) == string.lower(ADDON) then
        InitDB()
        CreateMainBar()

        -- Rattrapage LoadOnDemand : en module a la demande, PLAYER_LOGIN est
        -- deja passe quand XPBar se charge, donc le handler ci-dessous ne se
        -- declenchera plus. Si le joueur est deja connecte, on refait ici le
        -- meme travail de session.
        if IsLoggedIn() then
            StartOrResumeSession()
            UpdateBar()
        end

    elseif event == "PLAYER_LOGIN" then
        if not db then InitDB() end
        StartOrResumeSession()
        UpdateBar()
        -- En mode suite, c'est le core qui annonce la suite : pas de ligne par module.
        if not HasCore() then
            local ver = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or ""
            print("|cFFBC38FAXPBar|r v" .. ver .. " " .. L.LOGIN_LOADED .. " |cFFFFD700/xpbar|r " .. L.LOGIN_TO_OPEN)
        end

    elseif event == "PLAYER_LOGOUT" then
        -- Declenche aussi par /reload : horodate la deconnexion pour permettre,
        -- a la prochaine connexion, de distinguer un /reload d'une vraie session.
        if db then db.lastLogout = time() end

    elseif event == "PLAYER_ENTERING_WORLD" then
        questDirty = true
        RequestUpdate()

    elseif event == "PLAYER_XP_UPDATE" then
        if db then
            local newXP = UnitXP("player")
            local last  = db.lastXP or newXP
            local delta = newXP - last
            local gain  = 0
            if delta > 0 then
                gain = delta
            elseif delta < 0 then
                -- Passage de niveau : l'XP repart de 0. Gain reel = reste de
                -- l'ancien niveau (plafond memorise avant le passage) + XP deja
                -- acquise dans le nouveau. Sans plafond connu, repli prudent
                -- sur l'ancienne approximation (XP du nouveau niveau seule).
                local lastMax = db.lastXPMax or 0
                local carry   = (lastMax >= last) and (lastMax - last) or 0
                gain = carry + newXP
            end
            db.sessionXPGained = (db.sessionXPGained or 0) + gain
            SnapshotXP()
            PushXPSample()
            if gain > 0 then
                -- Classement du gain (lot 3) : quete si un QUEST_TURNED_IN vient
                -- d'annoncer une recompense en attente, sinon "hors quete"
                -- (monstres surtout, mais aussi exploration, recolte...).
                local now, isQuest = GetTime(), false
                if pendingQuestXP > 0 and (now - pendingQuestAt) < 2
                    and gain <= pendingQuestXP * 1.25 then
                    PushGain(questGains, gain)
                    pendingQuestXP, isQuest = 0, true
                else
                    PushGain(killGains, gain)
                    lastKillGain = { t = now, amount = gain }
                end
                ShowFloatingXP(gain, isQuest)
            end
        end
        RequestUpdate()

    elseif event == "PLAYER_LEVEL_UP" then
        -- Le comptage d'XP est gere par PLAYER_XP_UPDATE (branche delta < 0).
        if db then
            db.sessionLevels = (db.sessionLevels or 0) + 1
            -- Historique par niveau (lot 3) : temps joue sur le niveau qu'on
            -- vient de boucler, connu seulement si /played a repondu.
            local newLevel = tonumber(arg1) or UnitLevel("player")
            local spent    = GetLevelPlayed()
            if spent and newLevel and newLevel > 1 then
                local key = CharKey()
                db.levelLog[key] = db.levelLog[key] or {}
                db.levelLog[key][newLevel - 1] = spent
                print("|cFFBC38FA[XPBar]|r " .. string.format(L.LEVEL_REACHED, newLevel, newLevel - 1, FormatTime(spent)))
                playedLevelBase, playedLevelQueryTime = 0, time()
            end
        end
        RequestUpdate()

    elseif event == "QUEST_TURNED_IN" then
        if db then db.sessionQuests = (db.sessionQuests or 0) + 1 end
        -- arg2 = XP de recompense. L'ordre QUEST_TURNED_IN / PLAYER_XP_UPDATE
        -- n'est pas garanti : si le gain vient d'etre classe "hors quete" et
        -- correspond a cette recompense (a 25 % pres, bonus compris), on le
        -- reclasse ; sinon la recompense attend le prochain gain (2 s max).
        local xp = tonumber(arg2) or 0
        if xp > 0 then
            local now = GetTime()
            if lastKillGain and (now - lastKillGain.t) < 1
                and math.abs(lastKillGain.amount - xp) <= math.max(2, xp * 0.25) then
                if killGains[#killGains] == lastKillGain.amount then table.remove(killGains) end
                PushGain(questGains, lastKillGain.amount)
                lastKillGain = nil
            else
                pendingQuestXP, pendingQuestAt = xp, now
            end
        end
        questDirty = true
        RequestUpdate()

    elseif event == "UPDATE_FACTION" or event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" then
        if InRepMode() then RequestUpdate() end

    elseif event == "QUEST_LOG_UPDATE" then
        questDirty = true
        RequestUpdate()

    elseif event == "TIME_PLAYED_MSG" then
        -- arg1 = temps de jeu total (secondes), arg2 = temps sur le niveau actuel
        playedTimeBase      = arg1 or playedTimeBase
        playedTimeQueryTime = time()
        if arg2 then playedLevelBase, playedLevelQueryTime = arg2, time() end
        RequestUpdate()

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- InCombatLockdown() renvoie encore false pendant cet evenement : on
        -- suit donc le combat nous-memes pour que "Masquer en combat" agisse
        -- des l'entree en combat.
        inCombat = true
        ApplyVisibility()

    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        if db then EnforceNativeBar() end   -- coupure souris differee du combat
        ApplyVisibility()

    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        ApplyVisibility()

    elseif event == "UPDATE_EXHAUSTION" then
        RequestUpdate()
    end
end)

-- ══════════════════════════════════════════════════
-- INTEGRATION TibiSuite "Midnight"
-- Panneau d'options flottant Midnight + fonctions publiques attendues par
-- la barre TibiSuite (Toggle, OpenOptions). Ajout non destructif : le code
-- ci-dessus (dont le panneau d'options natif) reste disponible.
-- ══════════════════════════════════════════════════
local ACCENT_XP = { 0.737, 0.220, 0.980 }   -- violet (logo #BC38FA)
local function TibiUI() return _G.TibiMidnight end

-- Fonction publique Toggle (afficher / masquer la barre). L'etat est
-- memorise (db.hidden) : une barre masquee le reste apres /reload.
function XPBar_Toggle()
    if not containerFrame or not db then return end
    if containerFrame:IsShown() then
        db.hidden = true
        containerFrame:Hide()
    else
        db.hidden = false
        UpdateBar()
    end
end

-- Panneau d'options flottant Midnight
local midnightPanel
local function BuildMidnightOptions()
    local ui = TibiUI(); if not ui then return nil end
    if midnightPanel then return midnightPanel end
    -- Panneau UNIQUE (lot 2) : il reprend tous les reglages de l'ancien
    -- panneau (couleurs, opacite, police, boutons de reinitialisation) et
    -- separe les options qui etaient couplees (XP/h et temps restant, quetes
    -- terminees et repos).
    local P = ui.CreateOptionsPanel({
        name = "XPBarOptionsMidnight",
        title = L.OPT_TITLE, accent = ACCENT_XP })
    midnightPanel = P
    P:Note(L.OPT_HINT)

    -- ── Dimensions ─────────────────────────────────
    P:Section(L.OPT_SEC_DIMENSIONS)
    P:Slider(L.OPT_WIDTH_2, 200, 1200, 10,
        function() return db and db.width or 600 end,
        function(v) if db then db.width = v end; ApplySize(); UpdateBar() end)
    -- Minimum 4 px : le style "Fine" (8 px) doit rester dans la plage, sinon
    -- le rafraichissement du panneau le ramenerait au minimum du curseur.
    P:Slider(L.OPT_HEIGHT_2, 4, 60, 1,
        function() return db and db.height or 22 end,
        function(v) if db then db.height = v end; ApplySize(); UpdateBar() end)

    -- ── Apparence ──────────────────────────────────
    P:Section(L.OPT_SEC_APPEARANCE)
    -- Opacite affichee en pourcentage (0-100), stockee en 0-1 comme avant.
    P:Slider(L.OPT_OPACITY_2, 0, 100, 5,
        function() return math.floor(((db and db.bgA) or 0.85) * 100 + 0.5) end,
        function(v) if db then db.bgA = v / 100 end; ApplyAppearance() end)
    P:Slider(L.OPT_FONTSIZE_2, 8, 20, 1,
        function() return (db and db.fontSize and db.fontSize > 0) and db.fontSize or 10 end,
        function(v) if db then db.fontSize = v end; ApplyFont() end)
    -- Couleurs : le socle attend une table {r,g,b,a} en lecture.
    local function color(label, kr, kg, kb, ka)
        P:Color(label,
            function() return { db[kr], db[kg], db[kb], db[ka] } end,
            function(r, g, b, a) db[kr], db[kg], db[kb], db[ka] = r, g, b, a; UpdateBar() end)
    end
    color(L.OPT_COL_BAR,    "barR", "barG", "barB", "barA")
    color(L.OPT_COL_QUEST,  "qR",   "qG",   "qB",   "qA")
    color(L.OPT_COL_RESTED, "rR",   "rG",   "rB",   "rA")
    color(L.OPT_COL_INC,    "incR", "incG", "incB", "incA")
    P:Check(L.OPT_CLASSCOLOR,
        function() return db and db.classColorBar end,
        function(v) if db then db.classColorBar = v end; UpdateBar() end)

    -- ── Styles prets a l'emploi (lot 3) ─────────────
    P:Section(L.OPT_SEC_PRESETS)
    local function preset(label, name)
        P:Button(label, function() ApplyPreset(name); P:Refresh() end)
    end
    preset(L.OPT_PRESET_THIN,     "thin")
    preset(L.OPT_PRESET_CLASSIC,  "classic")
    preset(L.OPT_PRESET_VERTICAL, "vertical")

    -- ── Progression (lot 3) ─────────────────────────
    P:Section(L.OPT_SEC_PROGRESS)
    local function prog(label, key, relayout)
        P:Check(label,
            function() return db and db[key] end,
            function(v) if db then db[key] = v end
                if relayout then LayoutTicks() end
                UpdateBar() end)
    end
    prog(L.OPT_QUESTXP,    "showQuestXP")
    prog(L.OPT_PROJECTION, "showProjection")
    prog(L.OPT_RESTZONE,   "showRestedZone")
    prog(L.OPT_TICKS,      "showTicks", true)
    prog(L.OPT_FLOATXP,    "showFloatingXP")
    prog(L.OPT_ESTIMATES,  "showEstimates")

    -- ── Affichage (ligne du bas et barre des quetes) ──
    P:Section(L.OPT_DISPLAY)
    local function disp(label, key)
        P:Check(label,
            function() return db and db[key] end,
            function(v) if db then db[key] = v end; UpdateBar() end)
    end
    disp(L.OPT_PLAYED_2,    "showPlayedTime")
    disp(L.OPT_SESSION,     "showSessionTime")
    disp(L.OPT_XPPERHOUR,   "showXPPerHour")
    disp(L.OPT_LEVELING_2,  "showLevelingTime")
    disp(L.OPT_ROLLING_2,   "showRollingXP")
    disp(L.OPT_COMPLETED_2, "showCompletedQuests")
    disp(L.OPT_RESTED_TXT,  "showRestedText")
    disp(L.OPT_INCBAR_2,    "showIncompleteBar")

    -- ── Visibilite ─────────────────────────────────
    P:Section(L.OPT_SEC_VISIBILITY)
    P:Check(L.OPT_SHOWBAR,
        function() return db and not db.hidden end,
        function(v) if db then db.hidden = not v end; UpdateBar() end)
    disp(L.OPT_MAXLEVEL,   "showAtMaxLevel")
    P:Check(L.OPT_REPATMAX,
        function() return db and db.repAtMaxLevel end,
        function(v) if db then db.repAtMaxLevel = v end; LayoutTicks(); UpdateBar() end,
        L.OPT_REPATMAX_TT)
    disp(L.OPT_HIDENATIVE, "hideDefaultXPBar")
    local function vis(label, key)
        P:Check(label,
            function() return db and db[key] end,
            function(v) if db then db[key] = v end; ApplyVisibility() end)
    end
    vis(L.OPT_HIDECOMBAT, "hideInCombat")
    vis(L.OPT_HIDEVEHICLE, "hideInVehicle")
    vis(L.OPT_MOUSEOVER, "mouseoverOnly")

    -- ── Orientation ────────────────────────────────
    P:Section(L.OPT_SEC_ORIENTATION)
    P:Check(L.OPT_VERTBAR,
        function() return db and db.orientation == "VERTICAL" end,
        function(v)
            if db then db.orientation = v and "VERTICAL" or "HORIZONTAL" end
            ApplyOrientation(); UpdateBar()
        end)
    P:Check(L.OPT_VERTTEXT_2,
        function() return db and db.verticalText end,
        function(v) if db then db.verticalText = v end; LayoutLabels(); UpdateBar() end)
    P:Slider(L.OPT_VTHICK_2, 8, 60, 1,
        function() return db and db.vWidth or 24 end,
        function(v) if db then db.vWidth = v end
            if IsVertical() then ApplySize() end; UpdateBar() end)
    P:Slider(L.OPT_VLENGTH_2, 100, 900, 10,
        function() return db and db.vHeight or 300 end,
        function(v) if db then db.vHeight = v end
            if IsVertical() then ApplySize() end; UpdateBar() end)

    -- ── Session ────────────────────────────────────
    P:Section(L.OPT_SEC_SESSION)
    P:Check(L.OPT_RESETRELOAD,
        function() return db and db.resetSessionOnReload end,
        function(v) if db then db.resetSessionOnReload = v end end)
    P:Button(L.OPT_RESETSESS, function()
        if not db then return end
        ResetSession(); UpdateBar()
        print("|cffFFD700[XPBar]|r " .. L.SESSION_RESET)
    end)
    P:Button(L.OPT_RESETPOS, function()
        if not (db and containerFrame) then return end
        db.posX, db.posY, db.anchor = DEFAULTS.posX, DEFAULTS.posY, DEFAULTS.anchor
        containerFrame:ClearAllPoints()
        containerFrame:SetPoint(db.anchor, UIParent, db.anchor, db.posX, db.posY)
        print("|cffFFD700[XPBar]|r " .. L.POS_RESET)
    end)

    -- ── Bouton flottant (mode suite uniquement : l'etat vit dans TibiSuiteDB,
    -- absent en autonome, ou la case n'aurait aucun effet) ──
    if _G.TibiSuite and _G.TibiSuite.SetCtrlHidden then
        P:Section(L.OPT_SEC_FLOATING)
        P:Check(L.OPT_HIDE_OPTIONS_BTN,
            function() return TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("XPBarContainer", "options") end,
            function(v) TibiSuite.SetCtrlHidden("XPBarContainer", "options", v) end)
    end

    return midnightPanel
end

function XPBar_OpenOptions()
    local p = BuildMidnightOptions(); if p then p:Toggle() end
end

-- Bouton texte "Options" sur la barre + harmonisation (pas de recherche pour
-- XPBar). Fonction unique, aussi appelee par XPBar_Module.lua : idempotente
-- grace a _tibiControls, donc sans risque d'etre appelee plusieurs fois.
function XPBar_Decorate()
    local ui = TibiUI()
    if not (ui and ui.AddHeaderControls and containerFrame) then return end
    if containerFrame._tibiControls then return end
    ui.AddHeaderControls(containerFrame, {
        accent = ACCENT_XP,
        onOptions = function() XPBar_OpenOptions() end,
    })
end

local tibiEv = CreateFrame("Frame")
tibiEv:RegisterEvent("PLAYER_LOGIN")
tibiEv:SetScript("OnEvent", function()
    C_Timer.After(1.0, XPBar_Decorate)
end)

-- API publique minimale pour la suite (lecture seule). LvlHistory y lit
-- l'XP/h "en direct" (fenetre glissante) au lieu de le recalculer.
_G.XPBarAPI = _G.XPBarAPI or {}
XPBarAPI.GetXPPerHour        = function() return GetEffectiveXPPerHour() end
XPBarAPI.GetRollingXPPerHour = function() return GetRollingXPPerHour() end
XPBarAPI.GetSessionXPPerHour = function() return GetXPPerHour() end
