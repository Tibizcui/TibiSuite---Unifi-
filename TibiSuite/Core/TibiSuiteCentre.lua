--[[============================================================================
  TibiSuiteCentre.lua  -  Centre TibiSuite (fenetre unique de reglages)
  ---------------------------------------------------------------------------
  Une seule fenetre, facon EllesmereUI : barre laterale (General + un
  interrupteur par module), page de droite, pied de fenetre avec le
  rechargement de l'interface quand il est necessaire.

  La page d'un module affiche SON PROPRE panneau d'options, ancre ici grace
  au socle v13 (panel:Dock). Aucun module n'a ete modifie : le Centre ouvre
  le panneau par la voie habituelle (onOptions ou <Addon>_OpenOptions), le
  recupere dans UI.lastShownPanel puis l'ancre.

  Depuis le socle v14, c'est le chemin par defaut : toute ouverture flottante
  d'un panneau de module (roue, Maj+clic droit, clic droit sur l'onglet,
  commande du module) passe par UI.PanelRedirect, qui ouvre le Centre sur la
  page du module (table PANEL_PAGE). Reglage « Ouvrir les options des modules
  dans le Centre » (TibiSuiteDB.optionsInCentre, nil = actif) dans Barre et
  acces ; decoche, ou sans le core, les fenetres flottantes reviennent.

  Aucun crochet Blizzard : la fenetre est seulement inscrite dans
  UISpecialFrames (Echap natif, sans OnHide), comme les fenetres escClose.

  API : TibiSuite.OpenCentre(pageId), TibiSuite.ToggleCentre(),
        TibiSuite.IsCentreShown(). pageId = "home" | "bar" | "doctor" |
        "maint" | cle de module ("Stats", "Daily"...).
============================================================================]]

local L = TibiSuiteL or {}
TibiSuiteL = L

-- Textes (francais par defaut ; Locale\enUS.lua peut les ecraser).
local function D(k, v) if L[k] == nil then L[k] = v end end
D("CTR_FILTER",        "Filtrer...")
D("CTR_GENERAL",       "GÉNÉRAL")
D("CTR_MODULES",       "MODULES")
D("CTR_HOME",          "Accueil")
D("CTR_BAR",           "Barre et accès")
D("CTR_DOCTOR",        "Diagnostic")
D("CTR_MAINT",         "Maintenance")
D("CTR_HOME_DESC",     "Vue d'ensemble de la suite et accès rapides.")
D("CTR_BAR_DESC",      "Barre d'onglets, bouton de la minicarte, ligne du menu Échap et messages de connexion.")
D("CTR_DOCTOR_DESC",   "État de chaque module, versions, mémoire et temps CPU.")
D("CTR_MAINT_DESC",    "Installateur, profils, réinstallation d'un module et code du Dashboard.")
D("CTR_ST_ON",         "Actif")
D("CTR_ST_OFF",        "Désactivé")
D("CTR_ST_LOAD",       "Chargé au prochain rechargement")
D("CTR_ST_UNLOAD",     "Arrêté au prochain rechargement")
D("CTR_ST_ABSENT",     "Non installé")
D("CTR_SLASH",         "Commande : ")
D("CTR_RELOAD",        "Recharger l'interface")
D("CTR_CLOSE",         "Fermer")
D("CTR_PENDING_1",     "1 changement attend un rechargement")
D("CTR_PENDING_N",     " changements attendent un rechargement")
D("CTR_OPEN_MOD",      "Ouvrir le module")
D("CTR_REINSTALL",     "Réinstaller")
D("CTR_CURSE",         "Page CurseForge")
D("CTR_ENABLE",        "Activer le module")
D("CTR_NOTE_OFF",      "Ce module est désactivé : WoW ne le charge pas du tout. Active-le pour retrouver sa fenêtre et ses réglages.")
D("CTR_NOTE_LOAD",     "Ce module est activé. Il sera chargé au prochain rechargement de l'interface, ses réglages apparaîtront alors ici.")
D("CTR_NOTE_ABSENT",   "Ce module n'est pas installé. Tu peux le télécharger gratuitement sur CurseForge, il rejoindra la suite tout seul.")
D("CTR_NOTE_NOPANEL",  "Ce module n'a pas de panneau de réglages à afficher ici. Ouvre-le pour accéder à ses options.")
D("CTR_TOAST_ON",      " activé.")
D("CTR_TOAST_RELOAD",  " : rechargement nécessaire pour l'activer.")
D("CTR_TOAST_OFF",     " sera arrêté au prochain rechargement.")
D("CTR_TOAST_OFF_NOW", " désactivé.")
D("CTR_CARD_MODULES",  "Modules actifs")
D("CTR_CARD_RELOAD",   "Rechargement")
D("CTR_CARD_VERSION",  "Version")
D("CTR_RELOAD_NONE",   "Aucun")
D("CTR_RELOAD_WAIT",   " en attente")
D("CTR_QUICK",         "ACCÈS RAPIDE")
D("CTR_Q_BAR",         "Afficher la barre")
D("CTR_Q_SETUP",       "Installateur")
D("CTR_Q_NEWS",        "Quoi de neuf")
D("CTR_Q_PROFILE",     "Profils")
D("CTR_Q_EXPORT",      "Code du Dashboard")
D("CTR_Q_DOCTOR",      "Diagnostic")
D("CTR_HOME_TIP",      "Astuce : la roue d'options d'un module, Maj + clic droit sur sa fenêtre ou clic droit sur son onglet ouvrent directement sa page ici.")
D("CTR_WEEK_TITLE",    "Ma semaine")
D("CTR_ACTIVITY",      "Fil d'activité")
D("CTR_ACTIVITY_DESC", "Tout ce qui s'est passé dans la suite : butin, records, paliers, courrier, semaine terminée. Clic sur une ligne : ouvrir le module.")
D("CTR_ACT_ALL",       "Tout")
D("CTR_ACT_EMPTY",     "Rien pour l'instant. Les événements de tes modules apparaîtront ici au fil du jeu.")
D("CTR_ACT_TODAY",     "AUJOURD'HUI")
D("CTR_ACT_YESTERDAY", "HIER")
D("CTR_ACT_CLEAR",     "Effacer l'historique")
D("CTR_ACT_CLEAR_ASK", "Effacer tout le fil d'activité ?\n\nLes notifications passées disparaissent. Rien d'autre n'est touché.")
D("CTR_BAR_SEC_NOTIF", "Notifications")
D("CTR_BAR_NOTIF_NOTE","Les événements arrivent toujours dans le Fil d'activité. Ici, tu choisis s'ils s'affichent aussi à l'écran, et pour quels modules.")
D("CTR_BAR_NOTIF_TOAST","Afficher les notifications à l'écran")
D("CTR_BAR_NOTIF_SOUND","Jouer un son")
D("CTR_BAR_NOTIF_COMBAT","Attendre la fin du combat pour les afficher")
D("CTR_BAR_NOTIF_MOD_FMT","Notifications de %s")
D("CTR_WEEK_DESC_FMT", "%s : ce qui presse, où en sont tes modules et le temps avant le prochain reset.")
D("CTR_WEEK_DAILY",    "RESET QUOTIDIEN DANS")
D("CTR_WEEK_WEEKLY",   "RESET HEBDO DANS")
D("CTR_WEEK_URGENT",   "À TRAITER")
D("CTR_WEEK_NONE",     "Rien d'urgent")
D("CTR_WEEK_EMPTY",    "Aucun module actif ne donne encore son état. Active DailyTracker, WeeklyCompass, RenTracker ou SkillTracker pour remplir cette page.")
D("CTR_WEEK_CARD_TT",  "Clic : ouvrir le module. Clic droit : ses options.")
D("CTR_WEEK_INFO_FMT", "%d / %d modules actifs")
D("CTR_Q_PALETTE",     "Palette de commandes")
D("CTR_BAR_SEC_LOOK",  "Couleur d'accent")
D("CTR_BAR_LOOK_NOTE", "Couleur des liserés, sélections et boutons de la barre, du Centre et des fenêtres de la suite. Le nom TibiSuite et les pastilles d'alerte restent rouges. La couleur de classe suit le personnage connecté.")
D("CTR_BAR_ACC_SUITE", "Rouge TibiSuite")
D("CTR_BAR_ACC_CLASS", "Couleur de ta classe")
D("CTR_BAR_SEC_OPT",   "Options des modules")
D("CTR_BAR_OPTCENTRE", "Ouvrir les options des modules dans le Centre")
D("CTR_BAR_OPT_NOTE",  "Clic droit sur un onglet, roue d'options d'une fenêtre, Maj + clic droit ou commande du module : tout ouvre la page du module dans ce Centre. Décoche pour retrouver les petites fenêtres d'options flottantes. Standby garde sa propre fenêtre.")
D("CTR_DOC_RERUN",     "Relancer le diagnostic")
D("CTR_BAR_SEC_STYLE", "Style de la barre")
D("CTR_BAR_STYLE_NOTE","Classique : la grille d'onglets texte. Dock : une rangée d'icônes, discrète. Panneau vivant : chaque module affiche son état du moment (quêtes restantes, concentration, réputation...). Le changement est immédiat, sans rechargement.")
D("CTR_BAR_STYLE_CLASSIC", "Classique (grille d'onglets)")
D("CTR_BAR_STYLE_DOCK",    "Dock (icônes)")
D("CTR_BAR_STYLE_PANEL",   "Panneau vivant (état des modules)")
D("CTR_BAR_DOCKLBL",   "Noms courts sous les icônes du Dock")
D("CTR_BAR_GRID_NOTE", "Colonnes de la grille : style Classique seulement. Le Dock suit l'orientation (une rangée ou une colonne), le Panneau est toujours vertical.")
D("CTR_BAR_SEC_LAYOUT","Disposition")
D("CTR_BAR_VERTICAL",  "Barre verticale")
D("CTR_BAR_LOCKED",    "Verrouiller la barre")
D("CTR_BAR_OPEN",      "Barre affichée")
D("CTR_BAR_SCALE",     "Échelle (%)")
D("CTR_BAR_COLS",      "Colonnes de la grille")
D("CTR_BAR_LOGO",      "Taille du logo")
D("CTR_BAR_SEC_POS",   "Position")
D("CTR_BAR_POS_NOTE",  "La barre se déplace à la souris quand elle n'est pas verrouillée. Les curseurs la placent au pixel près, à partir de son point d'ancrage.")
D("CTR_BAR_X",         "Position horizontale (X)")
D("CTR_BAR_Y",         "Position verticale (Y)")
D("CTR_BAR_RECENTER",  "Recentrer la barre")
D("CTR_BAR_SEC_TABS",  "Onglets affichés dans la barre")
D("CTR_BAR_TABS_NOTE", "Masquer un onglet ne désactive pas le module : il reste chargé et accessible depuis le Centre.")
D("CTR_BAR_HIDE_MISSING", "Masquer les onglets des modules non chargés")
D("CTR_BAR_SEC_WIN",   "Fenêtres des modules")
D("CTR_BAR_OPENALL",   "Tout ouvrir")
D("CTR_BAR_CLOSEALL",  "Tout fermer")
D("CTR_BAR_SEC_MM",    "Minicarte")
D("CTR_BAR_MMHIDE",    "Masquer le bouton de la minicarte")
D("CTR_BAR_SEC_LOGIN", "Messages de connexion")
D("CTR_BAR_LOGIN_FULL","Complets")
D("CTR_BAR_LOGIN_ONE", "Une seule ligne")
D("CTR_BAR_LOGIN_NONE","Aucun")
D("CTR_BAR_SEC_GM",    "Menu Échap")
D("CTR_BAR_GM",        "Ligne TibiSuite dans le menu Échap")
D("CTR_BAR_GM_NOTE",   "Placée sous EllesmereUI quand il est présent, sinon sous « Boutique ». Elle ouvre ce Centre. Pris en compte à la prochaine ouverture du menu.")
D("CTR_BAR_SEC_STREAM","Mode streaming")
D("CTR_BAR_STREAM",    "Masquer le nom du personnage et les montants d'or")
D("CTR_BAR_STREAM_NOTE","Pour diffuser ou faire des captures : dans la barre, Ma semaine et le fil d'activité, le nom devient « Personnage » et l'or « *** ». Les fenêtres propres des modules (Stats, PostBox...) ne sont pas concernées. Raccourci et palette : « Mode streaming ».")
D("CTR_BAR_SEC_AUTO",  "Masquage automatique")
D("CTR_BAR_AUTO_NOTE", "La barre s'efface d'elle-même dans les situations cochées, puis revient exactement comme tu l'avais laissée. Estompée : elle reste visible en transparence et se rallume au survol.")
D("CTR_BAR_AUTO_COMBAT","En combat")
D("CTR_BAR_AUTO_INST", "En instance (donjon, raid, champ de bataille, gouffre)")
D("CTR_BAR_AUTO_MOUNT","Sur une monture")
D("CTR_BAR_AUTO_VEH",  "Dans un véhicule")
D("CTR_BAR_AUTO_PET",  "En combat de mascottes")
D("CTR_BAR_AUTO_FADE", "Estomper (revient au survol)")
D("CTR_BAR_AUTO_HIDE", "Masquer complètement")
D("CTR_BAR_AUTO_ALPHA","Opacité estompée (%)")
D("CTR_NEXT",          "PROCHAINE ACTION")
D("CTR_NEXT_DONE",     "Tout est à jour. Rien ne presse pour l'instant.")
D("CTR_NEXT_TT",       "Clic : ouvrir le module concerné.")
D("CTR_BAR_SEC_WID",   "Widgets épinglés")
D("CTR_BAR_WID_NOTE",  "Épingle la ligne d'état d'un module à l'écran : une petite carte toujours à jour, que tu places où tu veux. Aussi depuis Ma semaine (Maj + clic sur une carte) ou la palette. Ils suivent le masquage automatique ci-dessus.")
D("CTR_BAR_WID_FMT",   "Épingler %s")
D("CTR_BAR_WID_LOCK",  "Verrouiller les widgets (plus de déplacement à la souris)")
D("CTR_BAR_WID_SCALE", "Taille des widgets (%)")
D("CTR_BAR_WID_NONE",  "Tout désépingler")
D("CTR_WEEK_PIN_TT",   "Punaise en haut à droite (ou Maj + clic) : épingler à l'écran.")
D("CTR_DISPLAY",       "Lisibilité")
D("CTR_DISPLAY_DESC",  "Taille des fenêtres de la suite, contraste élevé et couleurs adaptées au daltonisme.")
D("CTR_DSP_SEC_SIZE",  "Taille")
D("CTR_DSP_SIZE",      "Taille des fenêtres de la suite (%)")
D("CTR_DSP_SIZE_NOTE", "Centre, palette, installateur, notifications et widgets. Les fenêtres propres des modules gardent leur taille (beaucoup ont leur propre réglage d'échelle).")
D("CTR_DSP_SEC_COL",   "Contraste et couleurs")
D("CTR_DSP_CONTRAST",  "Contraste élevé (textes plus clairs, fonds opaques)")
D("CTR_DSP_CVD",       "Couleurs adaptées au daltonisme (bleu, vermillon, jaune)")
D("CTR_DSP_COL_NOTE",  "Le mode daltonien remplace le vert « terminé » par du bleu et l'orange d'alerte par du jaune, dans la suite et dans les fenêtres de modules qui utilisent la palette commune. Une partie des fenêtres déjà dessinées n'est mise à jour qu'après un rechargement.")
D("CTR_REMIND",        "Rappels")
D("CTR_REMIND_DESC",   "Avant les resets, une note pour chaque personnage, et tes événements du calendrier. Les rappels arrivent dans le Fil d'activité et à l'écran.")
D("CTR_REM_SEC_RESET", "Resets")
D("CTR_REM_WEEKLY",    "Rappel avant le reset hebdomadaire")
D("CTR_REM_WEEKLY_H",  "Heures avant le reset hebdo")
D("CTR_REM_DAILY",     "Rappel avant le reset quotidien")
D("CTR_REM_DAILY_M",   "Minutes avant le reset quotidien")
D("CTR_REM_RESET_NOTE","Le rappel hebdo indique combien de modules « À faire » ne sont pas terminés. Une seule fois par reset et par personnage.")
D("CTR_REM_SEC_CAL",   "Calendrier")
D("CTR_REM_CAL",       "Rappel 15 minutes avant un événement du calendrier")
D("CTR_REM_CAL_NOTE",  "Événements de guilde et invitations du jour. Les fêtes et réinitialisations de raid sont ignorées.")
D("CTR_REM_SEC_NOTE",  "Note pour ce personnage")
D("CTR_REM_NOTE_ON",   "Afficher la note à la connexion")
D("CTR_REM_NOTE_HINT", "Écris ta note puis Entrée (par exemple « Vendre les composants à l'HV »). Vide = aucune note.")
D("CTR_REM_TEST",      "Afficher un rappel d'essai")
D("CTR_REM_TEST_TXT",  "Rappel d'essai : voici à quoi ressemblent les rappels TibiSuite.")
D("CTR_PROFILES",      "Profils et restauration")
D("CTR_PROFILES_DESC", "Plusieurs jeux de réglages de la suite, choisis tout seuls selon le personnage, la spécialisation ou la montée de niveau. Et des points de restauration pour revenir en arrière.")
D("CTR_PRF_SEC_SETUPS","PROFILS DE SUITE")
D("CTR_PRF_NAME",      "Nom du profil...")
D("CTR_PRF_SAVE",      "Enregistrer les réglages actuels")
D("CTR_PRF_APPLY",     "Appliquer")
D("CTR_PRF_UPDATE",    "Mettre à jour")
D("CTR_PRF_DELETE",    "Supprimer")
D("CTR_PRF_ACTIVE",    "actif")
D("CTR_PRF_NONE",      "Aucun profil enregistré. Règle la suite comme tu l'aimes, donne un nom puis « Enregistrer ». Le profil actif retient tes changements quand tu passes à un autre.")
D("CTR_PRF_SEC_RULES", "CHOIX AUTOMATIQUE")
D("CTR_PRF_RULES_NOTE","Clic sur un bouton pour changer de profil (Aucun = ne rien changer). Priorité : spécialisation, puis personnage, puis montée de niveau. Un module à activer ou couper demande un rechargement : il est proposé, jamais imposé.")
D("CTR_PRF_R_CHAR_FMT","Ce personnage (%s)")
D("CTR_PRF_R_SPEC_FMT","Spécialisation actuelle (%s)")
D("CTR_PRF_R_LVL",     "Personnages en montée de niveau")
D("CTR_PRF_R_NONE",    "Aucun")
D("CTR_PRF_SEC_RP",    "POINTS DE RESTAURATION")
D("CTR_PRF_RP_NOTE",   "Créés tout seuls à la connexion (si quelque chose a changé), avant un profil ou une restauration. Seuls les réglages de la suite sont concernés, jamais la progression des modules.")
D("CTR_PRF_RP_NEW",    "Créer un point maintenant")
D("CTR_PRF_RP_RESTORE","Restaurer")
D("CTR_PRF_RP_ASK",    "Revenir aux réglages de la suite de ce point ?\n\nUn point « Avant restauration » est créé d'abord : tu pourras revenir ici.")
D("CTR_PRF_DEL_ASK_FMT","Supprimer le profil « %s » ?\n\nLes règles qui l'utilisent repassent à « Aucun ».")
D("CTR_PRF_RP_NONE",   "Aucun point pour l'instant.")
D("CTR_UNDO_FMT",      "Annuler : %s")
D("CTR_UNDO_TT",       "Annule le dernier réglage changé, dans la suite ou dans un module (30 derniers, jusqu'au rechargement).")
D("CTR_WIDGETS",       "Widgets")
D("CTR_WIDGETS_DESC",  "Épingle à l'écran la ligne d'état d'un module : une petite carte toujours à jour, que tu déplaces à la souris. Elles suivent le masquage automatique de la barre (combat, instance...).")
D("CTR_WID_PIN",       "Épingler")
D("CTR_WID_UNPIN",     "Désépingler")
D("CTR_WID_LOCK",      "Verrouiller les widgets")
D("CTR_WID_UNLOCK",    "Déverrouiller les widgets")
D("CTR_WID_SIZE_FMT",  "Taille : %d %%")
D("CTR_WID_NONE",      "Aucun module actif ne donne de ligne d'état. Active DailyTracker, WeeklyCompass, RenTracker, SkillTracker... pour pouvoir les épingler.")
D("CTR_WID_TIP",       "Aussi : la punaise des cartes de Ma semaine, le clic droit sur un module de la barre (Dock, Panneau vivant) et la palette de commandes.")
D("CTR_WID_PINNED",    "À L'ÉCRAN")
D("CTR_WID_TT_PIN",    "Épingler à l'écran")
D("CTR_WID_TT_UNPIN",  "Désépingler de l'écran")
D("CTR_SOCLE",         "socle v")
D("CTR_UNAVAIL",       "Centre indisponible (socle v13 requis).")
D("CTR_SET_DESC",     "Tous les réglages de la suite et de ses modules sont réunis dans le Centre TibiSuite.")
D("CTR_SET_OPEN",      "Ouvrir le Centre TibiSuite")
D("CTR_SET_HINT",      "Raccourcis : /ts, clic droit sur le bouton de la minicarte, ou la ligne TibiSuite du menu Échap.")

-- ── Dimensions ─────────────────────────────────────────────────────
local W, H        = 860, 580
local HDR, FOOT   = 48, 44
local SIDE        = 214
local ROW_W, ROW_H = SIDE - 26, 24
local PANE_X      = SIDE + 1 + 20          -- marge gauche de la page
local BODY_TOP    = 62                     -- en-tete de page
local PAGE_FOOT   = 36                     -- boutons de page

local GENERAL = {
  { id = "home",   label = "CTR_HOME"   },
  { id = "activity", label = "CTR_ACTIVITY" },
  { id = "bar",    label = "CTR_BAR"    },
  { id = "widgets", label = "CTR_WIDGETS" },
  { id = "display", label = "CTR_DISPLAY" },
  { id = "reminders", label = "CTR_REMIND" },
  { id = "profiles", label = "CTR_PROFILES" },
  { id = "doctor", label = "CTR_DOCTOR" },
  { id = "maint",  label = "CTR_MAINT"  },
}

local K, UI, ACC
local frame, listC, search
local rows, labels = {}, {}
local pages = {}                -- id -> frame
local panelCache = {}           -- id -> panneau socle ancre
local hdr = {}                  -- elements de l'en-tete de page
local foot = {}                 -- boutons de page
local note                      -- message (module non charge, etc.)
local pendingTxt, reloadBtn
local current = "home"
local byKey = {}
local docked                    -- panneau socle actuellement ancre dans la page
local barPanel                  -- page Barre et acces (panneau socle)
local dspPanel, remPanel        -- pages Lisibilite et Rappels (panneaux socle)
local undoBtn                   -- bouton Annuler du pied de fenetre

-- Taille variable (poignee bas-droit) : largeurs calculees a la volee.
local MIN_W, MIN_H = 760, 480
local function PaneW() return math.floor((frame and frame:GetWidth() or W) - PANE_X - 20) end
local function DockW() return PaneW() - 24 end

local function Hex(c)
  return string.format("|cFF%02X%02X%02X", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end
local function ModCol(mod) local c = mod.col or { r = 0.6, g = 0.6, b = 0.6 }; return { c.r, c.g, c.b } end

-- ── Etat d'un module ───────────────────────────────────────────────
local function ModState(mod)
  if not TibiSuite.ModuleExists(mod.addonName) then return "absent" end
  local loaded = C_AddOns.IsAddOnLoaded(mod.addonName)
  local on = TibiSuite.IsModuleEnabled(mod.key)
  if on and loaded then return "on" end
  if on then return "load" end
  if loaded then return "unload" end
  return "off"
end

local STATE_TXT = {
  on     = function() return K.ICON_OK .. " " .. K.HX.OK .. L.CTR_ST_ON .. "|r" end,
  load   = function() return K.ICON_WAIT .. " " .. K.HX.GOLD .. L.CTR_ST_LOAD .. "|r" end,
  unload = function() return K.ICON_WAIT .. " " .. K.HX.WARN .. L.CTR_ST_UNLOAD .. "|r" end,
  off    = function() return K.HX.DIM .. L.CTR_ST_OFF .. "|r" end,
  absent = function() return K.HX.DIM .. L.CTR_ST_ABSENT .. "|r" end,
}

local function PendingCount()
  local n = 0
  for _ in pairs(TibiSuite.pendingReload or {}) do n = n + 1 end
  return n
end

-- ── Recuperation du panneau d'options d'un module ──────────────────
-- On ouvre le panneau par la voie habituelle du module, puis on lit le
-- dernier panneau affiche dans le registre du socle. Si l'appel a referme
-- un panneau deja ouvert (bascule), un second appel le rouvre.
local function GrabPanel(id, opener)
  if panelCache[id] then return panelCache[id] end
  if not (UI and UI.panels) then return nil end
  UI.lastShownPanel = nil
  -- Pendant la recuperation, le panneau s'ouvre en flottant comme avant :
  -- sans ce drapeau, la redirection (socle v14) rouvrirait le Centre en boucle.
  UI._noRedirect = true
  pcall(opener)
  local p = UI.lastShownPanel
  if not p then pcall(opener); p = UI.lastShownPanel end
  UI._noRedirect = nil
  if p and p.Dock then panelCache[id] = p; return p end
  return nil
end

local function ModuleOpener(mod)
  return function()
    local reg = TibiSuite.registered and TibiSuite.registered[mod.key]
    if reg and type(reg.onOptions) == "function" then reg.onOptions(); return end
    local fn = mod.optionsFn and _G[mod.optionsFn]
    if type(fn) == "function" then fn() end
  end
end

-- ── Briques ────────────────────────────────────────────────────────
local function Page(id)
  local p = pages[id]
  if not p then
    p = CreateFrame("Frame", nil, frame.body)
    p:SetAllPoints(frame.body)
    p:Hide()
    pages[id] = p
  end
  return p
end

local function SetFooter(list)
  for i, b in ipairs(foot) do
    local spec = list and list[i]
    if spec then
      b._label:SetText(spec[1])
      b:SetScript("OnClick", spec[2])
      b:Show()
    else
      b:Hide()
    end
  end
end

local function SetHeader(logo, title, col, desc, status)
  hdr.logo:SetTexture(logo or K.LOGO)
  hdr.title:SetText(title or "")
  local c = col or ACC
  hdr.title:SetTextColor(c[1], c[2], c[3])
  hdr.desc:SetText(desc or "")
  hdr.status:SetText(status or "")
end

local function ShowNote(text, btnLabel, onClick)
  note.text:SetText(text or "")
  if btnLabel then
    note.btn._label:SetText(btnLabel)
    note.btn:SetScript("OnClick", onClick)
    note.btn:Show()
  else
    note.btn:Hide()
  end
  note:Show()
end

local Select, RefreshAll

-- ── Interrupteur d'un module ───────────────────────────────────────
local function ToggleModule(mod)
  local wasLoaded = C_AddOns.IsAddOnLoaded(mod.addonName)
  local on = not TibiSuite.IsModuleEnabled(mod.key)
  local st = TibiSuite.SetModuleEnabled(mod.key, on)
  local name = Hex(ModCol(mod)) .. mod.addonName .. "|r"
  local msg
  if st == "loaded" then msg = L.CTR_TOAST_ON
  elseif st == "reload" then msg = L.CTR_TOAST_RELOAD
  elseif st == "off" then msg = wasLoaded and L.CTR_TOAST_OFF or L.CTR_TOAST_OFF_NOW end
  if msg and TibiSuite.ShowToast then TibiSuite.ShowToast(name .. msg) end
  RefreshAll()
  if current == mod.key then Select(mod.key) end
end

-- ── Barre laterale ─────────────────────────────────────────────────
local function MakeRow(id, text, mod)
  local r = CreateFrame("Button", nil, listC)
  r:SetSize(ROW_W, ROW_H)
  r.sel = r:CreateTexture(nil, "BACKGROUND")
  r.sel:SetAllPoints()
  r.sel:SetColorTexture(ACC[1], ACC[2], ACC[3], 0.18)
  r.bar = r:CreateTexture(nil, "ARTWORK")
  r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(3)
  r.bar:SetColorTexture(ACC[1], ACC[2], ACC[3], 1)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.05)
  local x = 12
  if mod then
    local c = ModCol(mod)
    local dot = r:CreateTexture(nil, "ARTWORK")
    dot:SetSize(8, 8); dot:SetPoint("LEFT", 12, 0)
    dot:SetColorTexture(c[1], c[2], c[3], 1)
    r.dot = dot
    x = 26
  end
  r.txt = K.Text(r, "GameFontHighlightSmall", text)
  r.txt:SetPoint("LEFT", x, 0)
  r.txt:SetWidth(ROW_W - x - (mod and 64 or 8))
  r.txt:SetJustifyH("LEFT")
  r.txt:SetWordWrap(false)
  if mod then
    r.wait = r:CreateTexture(nil, "OVERLAY")
    r.wait:SetSize(13, 13)
    r.wait:SetPoint("RIGHT", -46, 0)
    r.wait:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
    r.sw = K.makeSwitch(r, ModCol(mod))
    r.sw:SetPoint("RIGHT", -4, 0)
    r.sw:SetScript("OnClick", function() ToggleModule(mod) end)
  end
  r:SetScript("OnClick", function() Select(id) end)
  r.id, r.mod, r.search = id, mod, UI.Normalize(text)
  rows[#rows + 1] = r
  return r
end

local function LayoutList()
  local q = UI.Normalize(search and search:GetText() or "")
  local y = -4
  local function place(lbl, group)
    local any = false
    for _, r in ipairs(rows) do
      if r.group == group and (q == "" or r.search:find(q, 1, true)) then any = true; break end
    end
    lbl:SetShown(any)
    if not any then
      for _, r in ipairs(rows) do if r.group == group then r:Hide() end end
      return
    end
    lbl:ClearAllPoints(); lbl:SetPoint("TOPLEFT", listC, "TOPLEFT", 12, y - 6)
    y = y - 24
    for _, r in ipairs(rows) do
      if r.group == group then
        local show = (q == "" or r.search:find(q, 1, true))
        r:SetShown(show)
        if show then
          r:ClearAllPoints(); r:SetPoint("TOPLEFT", listC, "TOPLEFT", 4, y)
          y = y - ROW_H - 2
        end
      end
    end
    y = y - 8
  end
  place(labels.general, "general")
  place(labels.modules, "modules")
  listC:SetHeight(math.max(-y + 6, 10))
end

local function RefreshRows()
  for _, r in ipairs(rows) do
    local sel = (r.id == current)
    r.sel:SetShown(sel); r.bar:SetShown(sel)
    if r.mod then
      local st = ModState(r.mod)
      if st == "absent" then
        r.txt:SetTextColor(K.COL.DIM[1], K.COL.DIM[2], K.COL.DIM[3])
        r.sw:Hide()
      else
        local c = sel and K.COL.TXT or K.COL.MUT
        r.txt:SetTextColor(c[1], c[2], c[3])
        r.sw:Show()
        r.sw._set(TibiSuite.IsModuleEnabled(r.mod.key))
      end
      r.wait:SetShown(st == "load" or st == "unload")
    else
      local c = sel and K.COL.TXT or K.COL.MUT
      r.txt:SetTextColor(c[1], c[2], c[3])
      if r.id == "activity" then
        local n = TibiSuite.UnreadCount and TibiSuite.UnreadCount() or 0
        r.txt:SetText(L.CTR_ACTIVITY .. (n > 0 and ("  " .. K.HX.WARN .. "(" .. n .. ")|r") or ""))
      end
    end
  end
end

local function RefreshFooter()
  local n = PendingCount()
  if n > 0 then
    pendingTxt:SetText(K.ICON_WAIT .. " " .. K.HX.GOLD .. (n == 1 and L.CTR_PENDING_1 or (n .. L.CTR_PENDING_N)) .. "|r")
    reloadBtn:Show()
  else
    pendingTxt:SetText("")
    reloadBtn:Hide()
  end
end

-- ── Pages generales ────────────────────────────────────────────────
-- ACCUEIL = « Ma semaine » : tableau de bord de la semaine en cours.
--   1. trois tuiles : reset quotidien, reset hebdomadaire, points a traiter ;
--   2. une carte par module qui fournit une ligne d'etat (statusFn), par
--      groupe (A faire, Progression), ce qui presse en tete ;
--   3. acces rapides, puis une ligne d'informations sur la suite.
-- Tout est dans une zone defilante. Clic sur une carte = fenetre du module,
-- clic droit = sa page d'options ici.
local function ResetIn(kind)
  local f = C_DateAndTime and (kind == "week" and C_DateAndTime.GetSecondsUntilWeeklyReset
    or C_DateAndTime.GetSecondsUntilDailyReset)
  if f then
    local ok, s = pcall(f)
    if ok and tonumber(s) then return tonumber(s) end
  end
  if kind == "day" and GetQuestResetTime then
    local ok, s = pcall(GetQuestResetTime)
    if ok and tonumber(s) then return tonumber(s) end
  end
  return nil
end

local CARD_H = 58
local RefreshHome   -- definie plus bas (le ticker de BuildHome l'appelle)

-- Prochaine action : ce qui presse d'abord, puis le premier « A faire »
-- incomplet, puis la progression la plus basse. nil = tout est a jour.
function TibiSuite.GetNextAction()
  local cat = {}
  for _, mod in ipairs(TibiSuite.GetCatalog()) do cat[mod.key] = mod end
  local best, bestScore
  for gi, g in ipairs(TibiSuite.PANEL_GROUPS or {}) do
    if not g.icons then
      for ki, key in ipairs(g.keys) do
        local st = cat[key] and TibiSuite.GetModuleStatus and TibiSuite.GetModuleStatus(key)
        if st then
          local prog = tonumber(st.progress)
          local score
          if st.urgent then score = ki
          elseif gi == 1 and (prog == nil or prog < 1) then score = 100 + ki
          elseif prog and prog < 1 then score = 200 + math.floor(prog * 100)
          end
          if score and (not bestScore or score < bestScore) then
            best, bestScore = { key = key, mod = cat[key], text = st.text, urgent = st.urgent and true or false, progress = prog }, score
          end
        end
      end
    end
  end
  return best
end

-- Ouvre le module de la prochaine action, sinon Ma semaine.
function TibiSuite.RunNextAction()
  local na = TibiSuite.GetNextAction()
  if na then TibiSuite.OpenModule(na.key) else TibiSuite.OpenCentre("home") end
end

local function MakeStatusCard(parent)
  local c = K.Card(parent)
  c:SetHeight(CARD_H)
  c:EnableMouse(true)
  c.bar = c:CreateTexture(nil, "OVERLAY")
  c.bar:SetPoint("TOPLEFT"); c.bar:SetPoint("BOTTOMLEFT"); c.bar:SetWidth(3)
  c.edge = c:CreateTexture(nil, "OVERLAY")       -- liseré d'urgence (haut)
  c.edge:SetPoint("TOPLEFT", 1, -1); c.edge:SetPoint("TOPRIGHT", -1, -1); c.edge:SetHeight(2)
  c.ico = c:CreateTexture(nil, "ARTWORK")
  c.ico:SetSize(26, 26); c.ico:SetPoint("TOPLEFT", 12, -9)
  c.name = K.Text(c, "GameFontNormal", "", K.COL.TXT)
  c.name:SetPoint("TOPLEFT", c.ico, "TOPRIGHT", 8, 1)
  c.flag = K.Text(c, "GameFontNormalSmall", "", K.COL.WARN)
  c.flag:SetPoint("TOPRIGHT", -32, -9)
  -- Punaise : epingler la carte a l'ecran (widget). Toujours visible,
  -- discrete tant que la carte n'est pas epinglee.
  local pin = CreateFrame("Button", nil, c)
  pin:SetSize(18, 18); pin:SetPoint("TOPRIGHT", -7, -6)
  pin.tex = pin:CreateTexture(nil, "ARTWORK"); pin.tex:SetAllPoints()
  local atlas
  for _, name in ipairs({ "Waypoint-MapPin-Untracked", "Waypoint-MapPin-Tracked", "Waypoint-MapPin-ChatIcon" }) do
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) then atlas = name; break end
  end
  if atlas then pin.tex:SetAtlas(atlas) else pin.tex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check") end
  function pin:Paint(hover)
    local on = c.mod and TibiSuite.IsWidgetPinned and TibiSuite.IsWidgetPinned(c.mod.key)
    if on then pin.tex:SetVertexColor(ACC[1], ACC[2], ACC[3]); pin:SetAlpha(1)
    else pin.tex:SetVertexColor(0.85, 0.85, 0.85); pin:SetAlpha(hover and 1 or 0.35) end
  end
  pin:SetScript("OnClick", function()
    if c.mod and TibiSuite.ToggleWidget then TibiSuite.ToggleWidget(c.mod.key) end
    pin:Paint(true)
  end)
  pin:SetScript("OnEnter", function(s)
    s:Paint(true)
    local on = c.mod and TibiSuite.IsWidgetPinned and TibiSuite.IsWidgetPinned(c.mod.key)
    GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:AddLine(on and L.CTR_WID_TT_UNPIN or L.CTR_WID_TT_PIN, 1, 1, 1); GameTooltip:Show()
  end)
  pin:SetScript("OnLeave", function(s) s:Paint(false); GameTooltip:Hide() end)
  pin:SetShown(TibiSuite.ToggleWidget ~= nil)
  c.pin = pin
  c.txt = K.Text(c, "GameFontHighlightSmall", "", K.COL.MUT)
  c.txt:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
  c.txt:SetJustifyH("LEFT"); c.txt:SetWordWrap(false)
  c.pbg = c:CreateTexture(nil, "ARTWORK")
  c.pbg:SetPoint("BOTTOMLEFT", 12, 9); c.pbg:SetPoint("BOTTOMRIGHT", -12, 9); c.pbg:SetHeight(4)
  c.pbg:SetColorTexture(1, 1, 1, 0.07)
  c.pfill = c:CreateTexture(nil, "ARTWORK", nil, 1)
  c.pfill:SetPoint("TOPLEFT", c.pbg, "TOPLEFT"); c.pfill:SetPoint("BOTTOMLEFT", c.pbg, "BOTTOMLEFT")
  local hl = c:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.04)
  c:SetScript("OnMouseUp", function(s, btn)
    if not s.mod then return end
    if btn == "RightButton" then Select(s.mod.key)
    elseif IsShiftKeyDown() and TibiSuite.ToggleWidget then
      TibiSuite.ToggleWidget(s.mod.key)
      if barPanel then barPanel:Refresh() end
    else frame:Hide(); TibiSuite.OpenModule(s.mod.key) end
  end)
  c:SetScript("OnEnter", function(s)
    if not s.mod then return end
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    local mc = ModCol(s.mod)
    GameTooltip:AddLine(s.mod.addonName, mc[1], mc[2], mc[3])
    if s.stText and s.stText ~= "" then GameTooltip:AddLine(s.stText, 1, 1, 1, true) end
    GameTooltip:AddLine(L.CTR_WEEK_CARD_TT, 0.6, 0.6, 0.65, true)
    if TibiSuite.ToggleWidget then GameTooltip:AddLine(L.CTR_WEEK_PIN_TT, 0.6, 0.6, 0.65, true) end
    GameTooltip:Show()
  end)
  c:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return c
end

local function BuildHome(p)
  local sc = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
  sc:SetPoint("TOPLEFT", 0, 0); sc:SetPoint("BOTTOMRIGHT", -24, 0)
  if UI.SkinScrollBar then UI.SkinScrollBar(sc, ACC) end
  local c = CreateFrame("Frame", nil, sc)
  c:SetSize(DockW(), 10)
  sc:SetScrollChild(c)
  p.scroll, p.child = sc, c

  -- Tuiles du haut
  p.tiles = {}
  for i, lbl in ipairs({ L.CTR_WEEK_DAILY, L.CTR_WEEK_WEEKLY, L.CTR_WEEK_URGENT }) do
    local t = K.Card(c)
    t:SetHeight(58)
    local l = K.Label(t, lbl); l:SetPoint("TOPLEFT", 12, -10)
    local v = K.Text(t, "GameFontHighlightLarge", "", K.COL.TXT); v:SetPoint("TOPLEFT", 12, -28)
    t.value = v
    p.tiles[i] = t
  end

  -- Bandeau « prochaine action ».
  local nx = CreateFrame("Button", nil, c)
  nx:SetHeight(40)
  nx.bg = nx:CreateTexture(nil, "BACKGROUND"); nx.bg:SetAllPoints(); nx.bg:SetColorTexture(1, 1, 1, 0.04)
  nx.bar = nx:CreateTexture(nil, "ARTWORK"); nx.bar:SetPoint("TOPLEFT"); nx.bar:SetPoint("BOTTOMLEFT"); nx.bar:SetWidth(3)
  nx.ico = nx:CreateTexture(nil, "ARTWORK"); nx.ico:SetSize(24, 24); nx.ico:SetPoint("LEFT", 12, 0)
  nx.lbl = K.Label(nx, L.CTR_NEXT); nx.lbl:SetPoint("TOPLEFT", 44, -6)
  nx.txt = K.Text(nx, "GameFontHighlight", "", K.COL.TXT); nx.txt:SetPoint("TOPLEFT", nx.lbl, "BOTTOMLEFT", 0, -2)
  nx.txt:SetJustifyH("LEFT"); nx.txt:SetWordWrap(false)
  local nhl = nx:CreateTexture(nil, "HIGHLIGHT"); nhl:SetAllPoints(); nhl:SetColorTexture(1, 1, 1, 0.04)
  nx:SetScript("OnClick", function(s) if s.key then frame:Hide(); TibiSuite.OpenModule(s.key) end end)
  nx:SetScript("OnEnter", function(s)
    if not s.key then return end
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM"); GameTooltip:AddLine(L.CTR_NEXT_TT, 1, 1, 1); GameTooltip:Show()
  end)
  nx:SetScript("OnLeave", function() GameTooltip:Hide() end)
  p.next = nx

  -- Groupes de cartes (memes groupes que le Panneau vivant, sans la rangee
  -- Interface : ces modules n'ont pas de ligne d'etat).
  p.groups = {}
  for gi, g in ipairs(TibiSuite.PANEL_GROUPS or {}) do
    if not g.icons then
      local head = K.Label(c, L[g.label] or g.label)
      p.groups[#p.groups + 1] = { head = head, keys = g.keys, cards = {} }
    end
  end
  p.empty = K.Text(c, "GameFontHighlight", L.CTR_WEEK_EMPTY, K.COL.DIM)

  -- Acces rapides
  p.quickHead = K.Label(c, L.CTR_QUICK)
  p.quickBtns = {}
  local function hideThen(fn) return function() frame:Hide(); fn() end end
  local quick = {
    { L.CTR_Q_BAR,     function() SlashCmdList["TIBISUITE"]("bar") end },
    { L.CTR_Q_PALETTE, hideThen(function() if TibiSuite.OpenPalette then TibiSuite.OpenPalette() end end) },
    { L.CTR_Q_SETUP,   hideThen(function() if TibiSuite.RunSetup then TibiSuite.RunSetup() end end) },
    { L.CTR_Q_NEWS,    hideThen(function() if TibiSuite.ShowWhatsNew then TibiSuite.ShowWhatsNew(true) end end) },
    { L.CTR_Q_PROFILE, hideThen(function() if TibiSuite.OpenProfileWindow then TibiSuite.OpenProfileWindow() end end) },
    { L.CTR_Q_EXPORT,  function()
        if _G.Stats and _G.Stats.ShowExportPopup then frame:Hide(); _G.Stats.ShowExportPopup()
        elseif TibiSuite.ShowToast then TibiSuite.ShowToast(L.TOAST_NEED_STATS or "Stats") end
      end },
  }
  for i, spec in ipairs(quick) do
    local b = K.Btn(c, 100, 30, spec[1])
    b:SetScript("OnClick", spec[2])
    p.quickBtns[i] = b
  end
  p.info = K.Text(c, "GameFontHighlightSmall", "", K.COL.DIM)
  p.tip = K.Text(c, "GameFontDisableSmall", L.CTR_HOME_TIP, K.COL.DIM)
  p.cards = p.tiles       -- marqueur « page construite » (RefreshAll)
  p.cardFrames = p.tiles  -- marqueur « mise en page » (Relayout)

  -- Comptes a rebours : rafraichis toutes les 30 s, page affichee seulement.
  p:SetScript("OnShow", function(s)
    if s.ticker then s.ticker:Cancel() end
    s.ticker = C_Timer.NewTicker(30, function() if s:IsVisible() then RefreshHome(s) end end)
  end)
  p:SetScript("OnHide", function(s) if s.ticker then s.ticker:Cancel(); s.ticker = nil end end)
end

-- Place tuiles, cartes et boutons selon la largeur courante, puis remplit.
local function LayoutHome(p)
  if not p.child then return end
  local w = DockW()
  local c = p.child
  c:SetWidth(w)
  local tw = math.floor((w - 20) / 3)
  for i, t in ipairs(p.tiles) do
    t:SetWidth(tw)
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", (i - 1) * (tw + 10), -2)
  end
  p.next:SetWidth(w)
  p.next.txt:SetWidth(w - 60)
  p.next:ClearAllPoints(); p.next:SetPoint("TOPLEFT", 0, -70)
  local y = -120
  local cols = (w >= 600) and 3 or 2
  local cw = math.floor((w - (cols - 1) * 10) / cols)
  local shown = 0
  for _, g in ipairs(p.groups) do
    local n = 0
    for _, card in ipairs(g.cards) do if card:IsShown() then n = n + 1 end end
    g.head:SetShown(n > 0)
    if n > 0 then
      g.head:ClearAllPoints(); g.head:SetPoint("TOPLEFT", 2, y - 4)
      y = y - 22
      local i = 0
      for _, card in ipairs(g.cards) do
        if card:IsShown() then
          card:SetWidth(cw)
          card.txt:SetWidth(cw - 60)
          card:ClearAllPoints()
          card:SetPoint("TOPLEFT", (i % cols) * (cw + 10), y - math.floor(i / cols) * (CARD_H + 8))
          i = i + 1
        end
      end
      y = y - math.ceil(n / cols) * (CARD_H + 8) - 6
      shown = shown + n
    end
  end
  p.empty:SetShown(shown == 0)
  if shown == 0 then
    p.empty:ClearAllPoints(); p.empty:SetPoint("TOPLEFT", 2, y - 4); p.empty:SetWidth(w - 4)
    y = y - 34
  end
  p.quickHead:ClearAllPoints(); p.quickHead:SetPoint("TOPLEFT", 2, y - 8)
  y = y - 28
  local qw = math.floor((w - 20) / 3)
  for i, b in ipairs(p.quickBtns) do
    b:SetSize(qw, 30)
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", ((i - 1) % 3) * (qw + 10), y - math.floor((i - 1) / 3) * 40)
  end
  y = y - math.ceil(#p.quickBtns / 3) * 40 - 6
  p.info:ClearAllPoints(); p.info:SetPoint("TOPLEFT", 2, y); p.info:SetWidth(w - 4)
  y = y - 22
  p.tip:ClearAllPoints(); p.tip:SetPoint("TOPLEFT", 2, y); p.tip:SetWidth(w - 4)
  y = y - (p.tip:GetStringHeight() or 14) - 10
  c:SetHeight(-y)
end

function RefreshHome(p)
  if not p.child then return end
  -- Tuiles
  local d, wk = ResetIn("day"), ResetIn("week")
  p.tiles[1].value:SetText(d and TibiSuite.FmtDuration(d) or "-")
  p.tiles[2].value:SetText(wk and TibiSuite.FmtDuration(wk) or "-")
  local urgent = 0

  -- Cartes : creees a la demande, une par module present dans le groupe.
  local cat = {}
  for _, mod in ipairs(TibiSuite.GetCatalog()) do cat[mod.key] = mod end
  for _, g in ipairs(p.groups) do
    local list = {}
    for _, key in ipairs(g.keys) do
      local mod = cat[key]
      local st = mod and TibiSuite.GetModuleStatus and TibiSuite.GetModuleStatus(key)
      if st then list[#list + 1] = { mod = mod, st = st } end
    end
    -- Ce qui presse en tete, puis l'ordre du groupe.
    table.sort(list, function(a, b)
      if (a.st.urgent and true or false) ~= (b.st.urgent and true or false) then return a.st.urgent and true or false end
      return false
    end)
    for i, e in ipairs(list) do
      local card = g.cards[i]
      if not card then card = MakeStatusCard(p.child); g.cards[i] = card end
      local mod, st = e.mod, e.st
      local mc = ModCol(mod)
      card.mod, card.stText, card.stProgress = mod, st.text, st.progress
      if card.pin then card.pin:Paint(false) end
      card.bar:SetColorTexture(mc[1], mc[2], mc[3], 1)
      card.ico:SetTexture(K.MODULE_LOGO and K.MODULE_LOGO[mod.key] or K.LOGO)
      card.name:SetText(mod.addonName)
      card.name:SetTextColor(mc[1], mc[2], mc[3])
      local sc = st.color or K.COL.TXT
      card.txt:SetText(st.text or "")
      card.txt:SetTextColor(sc[1] or 1, sc[2] or 1, sc[3] or 1)
      if st.urgent then
        urgent = urgent + 1
        card.edge:SetColorTexture(K.COL.WARN[1], K.COL.WARN[2], K.COL.WARN[3], 1); card.edge:Show()
        card.flag:SetText("!")
      else
        card.edge:Hide(); card.flag:SetText("")
      end
      if st.progress then
        card.pbg:Show(); card.pfill:Show()
        local pw = math.max(1, (card.pbg:GetWidth() or 100) * st.progress)
        card.pfill:SetWidth(pw)
        local done = st.progress >= 1
        local fc = done and K.COL.OK or mc
        card.pfill:SetColorTexture(fc[1], fc[2], fc[3], 1)
      else
        card.pbg:Hide(); card.pfill:Hide()
      end
      card:Show()
    end
    for i = #list + 1, #g.cards do g.cards[i]:Hide() end
  end
  p.tiles[3].value:SetText(urgent > 0 and (K.HX.WARN .. urgent .. "|r") or (K.HX.OK .. L.CTR_WEEK_NONE .. "|r"))

  -- Prochaine action
  local na = TibiSuite.GetNextAction()
  local nx = p.next
  if na then
    local mc = ModCol(na.mod)
    nx.key = na.key
    nx.bar:SetColorTexture(mc[1], mc[2], mc[3], 1)
    nx.ico:SetTexture(K.MODULE_LOGO and K.MODULE_LOGO[na.key] or K.LOGO); nx.ico:Show()
    nx.txt:SetText(Hex(mc) .. na.mod.addonName .. "|r  " .. (na.urgent and (K.HX.WARN .. "! |r") or "") .. (na.text or ""))
  else
    nx.key = nil
    nx.bar:SetColorTexture(K.COL.OK[1], K.COL.OK[2], K.COL.OK[3], 1)
    nx.ico:SetTexture(K.LOGO); nx.ico:Show()
    nx.txt:SetText(K.HX.OK .. L.CTR_NEXT_DONE .. "|r")
  end

  -- Ligne d'informations (anciennes tuiles de l'Accueil).
  local on, present = 0, 0
  for _, mod in ipairs(TibiSuite.GetCatalog()) do
    if TibiSuite.ModuleExists(mod.addonName) then
      present = present + 1
      if C_AddOns.IsAddOnLoaded(mod.addonName) then on = on + 1 end
    end
  end
  local n = PendingCount()
  p.info:SetText(string.format(L.CTR_WEEK_INFO_FMT, on, present)
    .. "   " .. (n == 0 and L.CTR_RELOAD_NONE or (K.HX.GOLD .. n .. L.CTR_RELOAD_WAIT .. "|r"))
    .. "   v" .. (TibiSuite.VERSION or "?") .. "  " .. L.CTR_SOCLE .. tostring(UI._version))
  LayoutHome(p)
  -- La largeur des barres de progression depend de la mise en page : seconde passe.
  for _, g in ipairs(p.groups) do
    for _, card in ipairs(g.cards) do
      if card:IsShown() and card.pbg:IsShown() and card.stProgress then
        card.pfill:SetWidth(math.max(1, (card.pbg:GetWidth() or 100) * card.stProgress))
      end
    end
  end
end

-- ── Fil d'activite ─────────────────────────────────────────────────
local actFilter = nil      -- cle de module filtree, nil = tout

local function DayLabel(t)
  local today = date("*t")
  local d = date("*t", t)
  if d.year == today.year and d.yday == today.yday then return L.CTR_ACT_TODAY end
  local y = date("*t", time() - 86400)
  if d.year == y.year and d.yday == y.yday then return L.CTR_ACT_YESTERDAY end
  return date("%d/%m/%Y", t)
end

local function ActOwner(key)
  for _, m in ipairs(TibiSuite.GetCatalog()) do
    if m.key == key then return m end
  end
end

local function BuildActivity(p)
  p.chipsHost = CreateFrame("Frame", nil, p)
  p.chipsHost:SetPoint("TOPLEFT", 0, 0); p.chipsHost:SetPoint("TOPRIGHT", -24, 0); p.chipsHost:SetHeight(24)
  p.chips = {}
  local sc = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
  sc:SetPoint("TOPLEFT", 0, -34); sc:SetPoint("BOTTOMRIGHT", -24, 0)
  if UI.SkinScrollBar then UI.SkinScrollBar(sc, ACC) end
  local c = CreateFrame("Frame", nil, sc)
  c:SetSize(DockW(), 10)
  sc:SetScrollChild(c)
  p.scroll, p.child = sc, c
  p.rows, p.heads = {}, {}
  p.empty = K.Text(c, "GameFontHighlight", L.CTR_ACT_EMPTY, K.COL.DIM)
end

local function ActRow(p, i)
  local r = p.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, p.child)
  r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetPoint("TOPLEFT", 0, -3); r.bar:SetPoint("BOTTOMLEFT", 0, 3); r.bar:SetWidth(2)
  local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.04)
  r.time = K.Text(r, "GameFontHighlightSmall", "", K.COL.DIM); r.time:SetPoint("TOPLEFT", 10, -6)
  r.ico = r:CreateTexture(nil, "ARTWORK"); r.ico:SetSize(18, 18); r.ico:SetPoint("TOPLEFT", 52, -3)
  r.name = K.Text(r, "GameFontNormalSmall", "", K.COL.TXT); r.name:SetPoint("TOPLEFT", 78, -6)
  r.who = K.Text(r, "GameFontHighlightSmall", "", K.COL.DIM); r.who:SetPoint("TOPRIGHT", -8, -6)
  r.txt = K.Text(r, "GameFontHighlightSmall", "", K.COL.TXT); r.txt:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
  r.txt:SetJustifyH("LEFT")
  r:SetScript("OnClick", function(s)
    if s.key and s.key ~= "Suite" and ActOwner(s.key) then frame:Hide(); TibiSuite.OpenModule(s.key) end
  end)
  p.rows[i] = r
  return r
end

local function RefreshActivity(p)
  if not p.child then return end
  local feed = TibiSuite.GetFeed and TibiSuite.GetFeed() or {}
  local w = DockW()
  p.child:SetWidth(w)
  -- Filtres : Tout + un par module present dans le fil.
  local keys, seen = {}, {}
  for _, e in ipairs(feed) do if not seen[e.k] then seen[e.k] = true; keys[#keys + 1] = e.k end end
  table.sort(keys)
  for _, ch in ipairs(p.chips) do ch:Hide() end
  local x = 0
  local function chip(i, label, key, col)
    local b = p.chips[i]
    if not b then b = K.Btn(p.chipsHost, 60, 22, ""); p.chips[i] = b end
    b._label:SetText(label)
    b:SetWidth(b._label:GetStringWidth() + 22)
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", x, 0)
    x = x + b:GetWidth() + 6
    local on = (actFilter == key)
    local c = on and (col or ACC) or K.COL.MUT
    b._label:SetTextColor(c[1], c[2], c[3])
    b:SetScript("OnClick", function() actFilter = key; RefreshActivity(p) end)
    b:Show()
  end
  chip(1, L.CTR_ACT_ALL, nil)
  for i, k in ipairs(keys) do
    local m = ActOwner(k)
    chip(i + 1, m and m.addonName or (L.ACT_SUITE or "TibiSuite"), k, m and ModCol(m))
  end
  -- Lignes, de la plus recente a la plus ancienne, groupees par jour.
  for _, r in ipairs(p.rows) do r:Hide() end
  for _, h in ipairs(p.heads) do h:Hide() end
  local y, n, hn, lastDay = -2, 0, 0, nil
  for i = #feed, 1, -1 do
    local e = feed[i]
    if actFilter == nil or e.k == actFilter then
      local day = DayLabel(e.t or 0)
      if day ~= lastDay then
        hn = hn + 1
        local h = p.heads[hn]
        if not h then h = K.Label(p.child, ""); p.heads[hn] = h end
        h:SetText(day); h:ClearAllPoints(); h:SetPoint("TOPLEFT", 4, y - 4); h:Show()
        y = y - 22
        lastDay = day
      end
      n = n + 1
      local r = ActRow(p, n)
      local m = ActOwner(e.k)
      local col = m and ModCol(m) or ACC
      r.key = e.k
      r.bar:SetColorTexture(col[1], col[2], col[3], 1)
      r.time:SetText(date("%H:%M", e.t or 0))
      r.ico:SetTexture(m and K.MODULE_LOGO and K.MODULE_LOGO[m.key] or K.LOGO)
      r.name:SetText(m and m.addonName or (L.ACT_SUITE or "TibiSuite"))
      r.name:SetTextColor(col[1], col[2], col[3])
      r.who:SetText((TibiSuite.IsStreaming and TibiSuite.IsStreaming()) and "" or (e.c or ""))
      r.txt:SetWidth(w - 90)
      r.txt:SetText((e.u and (K.HX.WARN .. "! |r") or "") .. (e.x or ""))
      if e.u then r.txt:SetTextColor(K.COL.TXT[1], K.COL.TXT[2], K.COL.TXT[3]) else r.txt:SetTextColor(K.COL.MUT[1], K.COL.MUT[2], K.COL.MUT[3]) end
      local h = math.max(34, (r.txt:GetStringHeight() or 12) + 24)
      r:SetSize(w, h)
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y)
      r:Show()
      y = y - h - 2
    end
  end
  p.empty:SetShown(n == 0)
  if n == 0 then p.empty:ClearAllPoints(); p.empty:SetPoint("TOPLEFT", 4, -6); p.empty:SetWidth(w - 8); y = -40 end
  p.child:SetHeight(-y + 6)
end

local function BuildBarPanel()
  if barPanel then return barPanel end
  local P = UI.CreateOptionsPanel({ name = "TibiSuiteCentreBar", title = L.CTR_BAR, accent = ACC })
  local function apply(t) if TibiSuite.ApplyBarSettings then TibiSuite.ApplyBarSettings(t) end end

  -- Couleur d'accent de la suite : rouge TibiSuite ou couleur de classe.
  P:Section(L.CTR_BAR_SEC_LOOK)
  P:Note(L.CTR_BAR_LOOK_NOTE)
  local className, classToken = UnitClass("player")
  local cc = classToken and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classToken))
    or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]))
  local classLbl = L.CTR_BAR_ACC_CLASS
  if className and cc and cc.r then
    classLbl = classLbl .. "  " .. Hex({ cc.r, cc.g, cc.b }) .. "(" .. className .. ")|r"
  end
  P:Check("|cFFC41F3B" .. L.CTR_BAR_ACC_SUITE .. "|r",
    function() return TibiSuite.GetAccentMode() == "suite" end,
    function() TibiSuite.SetAccentMode("suite"); P:Refresh() end)
  P:Check(classLbl,
    function() return TibiSuite.GetAccentMode() == "class" end,
    function() TibiSuite.SetAccentMode("class"); P:Refresh() end)

  P:Section(L.CTR_BAR_SEC_STREAM)
  P:Note(L.CTR_BAR_STREAM_NOTE)
  P:Check(L.CTR_BAR_STREAM, function() return TibiSuite.IsStreaming and TibiSuite.IsStreaming() end,
    function(v) if TibiSuite.SetStreaming then TibiSuite.SetStreaming(v) end end)

  P:Section(L.CTR_BAR_SEC_AUTO)
  P:Note(L.CTR_BAR_AUTO_NOTE)
  local function autoApply() if TibiSuite.ApplyAutoBar then TibiSuite.ApplyAutoBar() end end
  for _, o in ipairs({ { "autoCombat", L.CTR_BAR_AUTO_COMBAT }, { "autoInstance", L.CTR_BAR_AUTO_INST },
    { "autoMount", L.CTR_BAR_AUTO_MOUNT }, { "autoVehicle", L.CTR_BAR_AUTO_VEH }, { "autoPet", L.CTR_BAR_AUTO_PET } }) do
    P:Check(o[2], function() return TibiSuiteDB[o[1]] == true end,
      function(v) TibiSuiteDB[o[1]] = v and true or nil; autoApply() end)
  end
  P:Check(L.CTR_BAR_AUTO_FADE, function() return TibiSuiteDB.autoMode ~= "hide" end,
    function() TibiSuiteDB.autoMode = nil; autoApply(); P:Refresh() end)
  P:Check(L.CTR_BAR_AUTO_HIDE, function() return TibiSuiteDB.autoMode == "hide" end,
    function() TibiSuiteDB.autoMode = "hide"; autoApply(); P:Refresh() end)
  P:Slider(L.CTR_BAR_AUTO_ALPHA, 0, 60, 5,
    function() return tonumber(TibiSuiteDB.autoFade) or 20 end,
    function(v) if (tonumber(TibiSuiteDB.autoFade) or 20) ~= v then TibiSuiteDB.autoFade = v; autoApply() end end)

  P:Section(L.CTR_BAR_SEC_STYLE)
  P:Note(L.CTR_BAR_STYLE_NOTE)
  for _, o in ipairs({ { "classic", L.CTR_BAR_STYLE_CLASSIC }, { "dock", L.CTR_BAR_STYLE_DOCK }, { "panel", L.CTR_BAR_STYLE_PANEL } }) do
    P:Check(o[2], function() return (TibiSuite.GetBarStyle and TibiSuite.GetBarStyle() or "classic") == o[1] end,
      function() apply({ style = o[1] }); P:Refresh() end)
  end
  P:Check(L.CTR_BAR_DOCKLBL, function() return TibiSuiteDB.dockLabels ~= false end,
    function(v) apply({ dockLabels = v }) end)
  P:Section(L.CTR_BAR_SEC_LAYOUT)
  P:Check(L.CTR_BAR_OPEN,     function() return TibiSuiteCharDB and TibiSuiteCharDB.barOpen end, function(v) apply({ open = v }) end)
  P:Check(L.CTR_BAR_VERTICAL, function() return TibiSuiteDB.vertical end, function(v) apply({ vertical = v }) end)
  P:Check(L.CTR_BAR_LOCKED,   function() return TibiSuiteDB.locked end,   function(v) apply({ locked = v }) end)
  P:Slider(L.CTR_BAR_SCALE, 70, 150, 5,
    function() return math.floor((TibiSuiteDB.scale or 1) * 100 + 0.5) end,
    function(v) if math.abs((TibiSuiteDB.scale or 1) * 100 - v) > 0.5 then apply({ scale = v / 100 }) end end)
  P:Note(L.CTR_BAR_GRID_NOTE)
  P:Slider(L.CTR_BAR_COLS, 1, #TibiSuite.GetCatalog(), 1,
    function() return TibiSuiteDB.cols or 2 end,
    function(v) if (TibiSuiteDB.cols or 2) ~= v then apply({ cols = v }) end end)
  P:Slider(L.CTR_BAR_LOGO, 16, 64, 2,
    function() return TibiSuiteDB.logoSize or 22 end,
    function(v) if (TibiSuiteDB.logoSize or 22) ~= v then apply({ logoSize = v }) end end)
  P:Section(L.CTR_BAR_SEC_POS)
  P:Note(L.CTR_BAR_POS_NOTE)
  local function posX() local x = TibiSuite.GetBarPos(); return x end
  local function posY() local _, y = TibiSuite.GetBarPos(); return y end
  P:Slider(L.CTR_BAR_X, -1500, 1500, 1, posX,
    function(v) if posX() ~= v then TibiSuite.SetBarPos(v, posY()) end end)
  P:Slider(L.CTR_BAR_Y, -1500, 1500, 1, posY,
    function(v) if posY() ~= v then TibiSuite.SetBarPos(posX(), v) end end)
  P:Button(L.CTR_BAR_RECENTER, function() SlashCmdList["TIBISUITE"]("reset"); P:Refresh() end)

  -- Onglets affiches dans la barre (le module reste charge : seul son
  -- onglet disparait de la barre).
  P:Section(L.CTR_BAR_SEC_TABS)
  P:Note(L.CTR_BAR_TABS_NOTE)
  for _, mod in ipairs(TibiSuite.GetCatalog()) do
    local label = Hex(ModCol(mod)) .. tostring(mod.label) .. "|r"
    if mod.label ~= mod.addonName then label = label .. K.HX.DIM .. "  (" .. mod.addonName .. ")|r" end
    P:Check(label, function() return TibiSuite.IsTabShown(mod.key) end,
      function(v) TibiSuite.SetTabShown(mod.key, v) end)
  end
  P:Button(L.OPT_HIDE_MISSING_BTN or L.CTR_BAR_HIDE_MISSING, function()
    for _, mod in ipairs(TibiSuite.GetCatalog()) do
      if not C_AddOns.IsAddOnLoaded(mod.addonName) then TibiSuite.SetTabShown(mod.key, false) end
    end
    P:Refresh()
  end)

  -- Notifications (fil d'activite).
  P:Section(L.CTR_BAR_SEC_NOTIF)
  P:Note(L.CTR_BAR_NOTIF_NOTE)
  P:Check(L.CTR_BAR_NOTIF_TOAST, function() return TibiSuiteDB.notifToasts ~= false end,
    function(v) if v then TibiSuiteDB.notifToasts = nil else TibiSuiteDB.notifToasts = false end end)
  P:Check(L.CTR_BAR_NOTIF_SOUND, function() return TibiSuiteDB.notifSound ~= false end,
    function(v) if v then TibiSuiteDB.notifSound = nil else TibiSuiteDB.notifSound = false end end)
  P:Check(L.CTR_BAR_NOTIF_COMBAT, function() return TibiSuiteDB.notifCombat ~= false end,
    function(v) if v then TibiSuiteDB.notifCombat = nil else TibiSuiteDB.notifCombat = false end end)
  P:Check(string.format(L.CTR_BAR_NOTIF_MOD_FMT, "|cFFC41F3BTibiSuite|r"),
    function() return not (TibiSuite.IsNotifMuted and TibiSuite.IsNotifMuted("Suite")) end,
    function(v) if TibiSuite.SetNotifMuted then TibiSuite.SetNotifMuted("Suite", not v) end end)
  for _, mod in ipairs(TibiSuite.GetCatalog()) do
    if TibiSuite.ModuleExists(mod.addonName) then
      P:Check(string.format(L.CTR_BAR_NOTIF_MOD_FMT, Hex(ModCol(mod)) .. mod.addonName .. "|r"),
        function() return not (TibiSuite.IsNotifMuted and TibiSuite.IsNotifMuted(mod.key)) end,
        function(v) if TibiSuite.SetNotifMuted then TibiSuite.SetNotifMuted(mod.key, not v) end end)
    end
  end

  -- Ou s'ouvrent les options des modules (nil = dans le Centre).
  P:Section(L.CTR_BAR_SEC_OPT)
  P:Note(L.CTR_BAR_OPT_NOTE)
  P:Check(L.CTR_BAR_OPTCENTRE, function() return TibiSuiteDB.optionsInCentre ~= false end,
    function(v) if v then TibiSuiteDB.optionsInCentre = nil else TibiSuiteDB.optionsInCentre = false end end)

  P:Section(L.CTR_BAR_SEC_WIN)
  P:Button(L.CTR_BAR_OPENALL,  function() TibiSuite.SetAllModulesShown(true) end)
  P:Button(L.CTR_BAR_CLOSEALL, function() TibiSuite.SetAllModulesShown(false) end)
  P:Section(L.CTR_BAR_SEC_GM)
  P:Note(L.CTR_BAR_GM_NOTE)
  P:Check(L.CTR_BAR_GM, function() return TibiSuite.IsGameMenuEntryOn and TibiSuite.IsGameMenuEntryOn() end,
    function(v) if TibiSuite.SetGameMenuEntry then TibiSuite.SetGameMenuEntry(v) end end)
  P:Section(L.CTR_BAR_SEC_MM)
  P:Check(L.CTR_BAR_MMHIDE, function() return TibiSuiteDB.mmHidden end,
    function(v) if TibiSuite.SetMinimapHidden then TibiSuite.SetMinimapHidden(v) end end)
  P:Section(L.CTR_BAR_SEC_LOGIN)
  for _, o in ipairs({ { "full", L.CTR_BAR_LOGIN_FULL }, { "one", L.CTR_BAR_LOGIN_ONE }, { "none", L.CTR_BAR_LOGIN_NONE } }) do
    P:Check(o[2], function() return (TibiSuiteDB.loginMsg or "one") == o[1] end,
      function() TibiSuiteDB.loginMsg = o[1]; P:Refresh() end)
  end
  barPanel = P
  return P
end

local function BuildDisplayPanel()
  if dspPanel then return dspPanel end
  local P = UI.CreateOptionsPanel({ name = "TibiSuiteCentreDisplay", title = L.CTR_DISPLAY, accent = ACC })
  P:Section(L.CTR_DSP_SEC_SIZE)
  P:Note(L.CTR_DSP_SIZE_NOTE)
  P:Slider(L.CTR_DSP_SIZE, 90, 130, 5,
    function() return tonumber(TibiSuiteDB.uiScale) or 100 end,
    function(v)
      if (tonumber(TibiSuiteDB.uiScale) or 100) == v then return end
      TibiSuiteDB.uiScale = (v ~= 100) and v or nil
      if TibiSuite.ApplyReadability then TibiSuite.ApplyReadability() end
    end)
  P:Section(L.CTR_DSP_SEC_COL)
  P:Note(L.CTR_DSP_COL_NOTE)
  P:Check(L.CTR_DSP_CONTRAST, function() return TibiSuiteDB.highContrast == true end,
    function(v) TibiSuiteDB.highContrast = v and true or nil; if TibiSuite.ApplyReadability then TibiSuite.ApplyReadability() end end)
  P:Check(L.CTR_DSP_CVD, function() return TibiSuiteDB.cvd == true end,
    function(v) TibiSuiteDB.cvd = v and true or nil; if TibiSuite.ApplyReadability then TibiSuite.ApplyReadability() end end)
  P:Button(L.CTR_RELOAD, function() TibiSuite.Reload() end)
  dspPanel = P
  return P
end

local function BuildRemindPanel()
  if remPanel then return remPanel end
  local P = UI.CreateOptionsPanel({ name = "TibiSuiteCentreRemind", title = L.CTR_REMIND, accent = ACC })
  P:Section(L.CTR_REM_SEC_RESET)
  P:Note(L.CTR_REM_RESET_NOTE)
  P:Check(L.CTR_REM_WEEKLY, function() return TibiSuiteDB.remindWeekly ~= false end,
    function(v) TibiSuiteDB.remindWeekly = (not v) and false or nil end)
  P:Slider(L.CTR_REM_WEEKLY_H, 1, 24, 1, function() return tonumber(TibiSuiteDB.remindWeeklyH) or 3 end,
    function(v) TibiSuiteDB.remindWeeklyH = (v ~= 3) and v or nil end)
  P:Check(L.CTR_REM_DAILY, function() return TibiSuiteDB.remindDaily == true end,
    function(v) TibiSuiteDB.remindDaily = v and true or nil end)
  P:Slider(L.CTR_REM_DAILY_M, 15, 180, 15, function() return tonumber(TibiSuiteDB.remindDailyMin) or 60 end,
    function(v) TibiSuiteDB.remindDailyMin = (v ~= 60) and v or nil end)
  P:Section(L.CTR_REM_SEC_CAL)
  P:Note(L.CTR_REM_CAL_NOTE)
  P:Check(L.CTR_REM_CAL, function() return TibiSuiteDB.remindCal ~= false end,
    function(v) TibiSuiteDB.remindCal = (not v) and false or nil end)
  P:Section(L.CTR_REM_SEC_NOTE)
  P:Check(L.CTR_REM_NOTE_ON, function() return TibiSuiteDB.remindNote ~= false end,
    function(v) TibiSuiteDB.remindNote = (not v) and false or nil end)
  P:Note(L.CTR_REM_NOTE_HINT)
  -- Champ libre (le socle n'a qu'un champ en lecture seule) : pose a la main
  -- a la position courante du panneau, elargi avec lui (_boxes).
  local box = CreateFrame("EditBox", nil, P.content, "BackdropTemplate")
  box:SetSize(258, 22)
  box:SetPoint("TOPLEFT", P.content, "TOPLEFT", 6, P._y)
  box:SetBackdrop(K.FLAT)
  box:SetBackdropColor(0.02, 0.02, 0.03, 0.9)
  box:SetBackdropBorderColor(1, 1, 1, 0.18)
  box:SetAutoFocus(false)
  box:SetMaxLetters(200)
  box:SetFontObject("GameFontHighlightSmall")
  box:SetTextInsets(6, 6, 0, 0)
  local function save(s) if TibiSuite.SetCharNote then TibiSuite.SetCharNote(s:GetText()) end end
  box:SetScript("OnEnterPressed", function(s) save(s); s:ClearFocus() end)
  box:SetScript("OnEditFocusLost", save)
  box:SetScript("OnEscapePressed", function(s) s:SetText(TibiSuite.GetCharNote and TibiSuite.GetCharNote() or ""); s:ClearFocus() end)
  P._boxes[#P._boxes + 1] = box
  P._refresh[#P._refresh + 1] = function() if not box:HasFocus() then box:SetText(TibiSuite.GetCharNote and TibiSuite.GetCharNote() or "") end end
  P._y = P._y - 32
  P.content:SetHeight(math.max(-(P._y + (P._shift or 0)) + 10, 10))
  P:Button(L.CTR_REM_TEST, function()
    if TibiSuite.Notify then TibiSuite.Notify("Suite", L.CTR_REM_TEST_TXT, { sound = true }) end
  end)
  remPanel = P
  return P
end

-- ── Profils et restauration ────────────────────────────────────────
local RefreshProfiles

local function ProfRow(p, i)
  local r = p.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, p.child)
  r:SetHeight(30)
  r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, 0.03)
  r.txt = K.Text(r, "GameFontHighlight", "", K.COL.TXT); r.txt:SetPoint("LEFT", 10, 0)
  r.txt:SetJustifyH("LEFT"); r.txt:SetWordWrap(false)
  r.b = {}
  for j = 1, 3 do
    local b = K.Btn(r, 96, 22, "")
    r.b[j] = b
  end
  p.rows[i] = r
  return r
end

local function BuildProfiles(p)
  local sc = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
  sc:SetPoint("TOPLEFT", 0, 0); sc:SetPoint("BOTTOMRIGHT", -24, 0)
  if UI.SkinScrollBar then UI.SkinScrollBar(sc, ACC) end
  local c = CreateFrame("Frame", nil, sc)
  c:SetSize(DockW(), 10)
  sc:SetScrollChild(c)
  p.scroll, p.child = sc, c
  p.rows = {}
  p.h1 = K.Label(c, L.CTR_PRF_SEC_SETUPS)
  local name = CreateFrame("EditBox", nil, c, "BackdropTemplate")
  name:SetSize(220, 26)
  name:SetBackdrop(K.FLAT)
  name:SetBackdropColor(1, 1, 1, 0.05)
  name:SetBackdropBorderColor(1, 1, 1, 0.14)
  name:SetFontObject("GameFontHighlightSmall")
  name:SetTextInsets(8, 8, 0, 0)
  name:SetAutoFocus(false)
  name:SetMaxLetters(32)
  local ph = K.Text(name, "GameFontDisableSmall", L.CTR_PRF_NAME, K.COL.DIM); ph:SetPoint("LEFT", 9, 0)
  name:SetScript("OnTextChanged", function(s) ph:SetShown(s:GetText() == "") end)
  name:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  local function saveNew()
    TibiSuite.SaveSetup(name:GetText()); name:SetText(""); name:ClearFocus(); RefreshProfiles(p)
  end
  name:SetScript("OnEnterPressed", saveNew)
  p.name = name
  p.save = K.Btn(c, 230, 26, L.CTR_PRF_SAVE, "pri")
  p.save:SetScript("OnClick", saveNew)
  p.none = K.Text(c, "GameFontHighlightSmall", L.CTR_PRF_NONE, K.COL.DIM)
  p.h2 = K.Label(c, L.CTR_PRF_SEC_RULES)
  p.rulesNote = K.Text(c, "GameFontDisableSmall", L.CTR_PRF_RULES_NOTE, K.COL.DIM)
  p.rules = {}
  for i, kind in ipairs({ "spec", "char", "leveling" }) do
    local r = CreateFrame("Frame", nil, c)
    r:SetHeight(30)
    r.kind = kind
    r.txt = K.Text(r, "GameFontHighlight", "", K.COL.TXT); r.txt:SetPoint("LEFT", 10, 0)
    r.btn = K.Btn(r, 200, 24, "")
    r.btn:SetPoint("RIGHT", -4, 0)
    r.btn:SetScript("OnClick", function()
      local names = TibiSuite.GetSetupNames()
      local cur = TibiSuite.GetSetupRule(kind)
      local nxt
      if not cur then nxt = names[1]
      else
        for j, n in ipairs(names) do if n == cur then nxt = names[j + 1]; break end end
      end
      TibiSuite.SetSetupRule(kind, nxt)
      TibiSuite.CheckAutoSetup()
      RefreshProfiles(p)
    end)
    p.rules[i] = r
  end
  p.h3 = K.Label(c, L.CTR_PRF_SEC_RP)
  p.rpNote = K.Text(c, "GameFontDisableSmall", L.CTR_PRF_RP_NOTE, K.COL.DIM)
  p.rpNew = K.Btn(c, 230, 26, L.CTR_PRF_RP_NEW)
  p.rpNew:SetScript("OnClick", function()
    local ok = TibiSuite.CreateRestorePoint(L.RP_MANUAL)
    if TibiSuite.ShowToast then TibiSuite.ShowToast(ok and L.RP_CREATED or L.RP_SAME) end
    RefreshProfiles(p)
  end)
  p.rpNone = K.Text(c, "GameFontHighlightSmall", L.CTR_PRF_RP_NONE, K.COL.DIM)
end

function RefreshProfiles(p)
  if not p or not p.child then return end
  local w = DockW()
  local c = p.child
  c:SetWidth(w)
  for _, r in ipairs(p.rows) do r:Hide() end
  local n, y = 0, -2
  local function row(text, btns)
    n = n + 1
    local r = ProfRow(p, n)
    r:SetWidth(w)
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y)
    r.txt:SetText(text)
    r.txt:SetWidth(w - 330)
    for j, b in ipairs(r.b) do
      local spec = btns[j]
      if spec then
        b._label:SetText(spec[1])
        b:SetScript("OnClick", spec[2])
        b:ClearAllPoints(); b:SetPoint("RIGHT", -4 - (#btns - j) * 102, 0)
        b:Show()
      else b:Hide() end
    end
    r:Show()
    y = y - 34
  end

  -- Profils
  p.h1:ClearAllPoints(); p.h1:SetPoint("TOPLEFT", 2, y - 4); y = y - 24
  p.name:ClearAllPoints(); p.name:SetPoint("TOPLEFT", 0, y)
  p.save:ClearAllPoints(); p.save:SetPoint("LEFT", p.name, "RIGHT", 10, 0)
  y = y - 36
  local names = TibiSuite.GetSetupNames()
  local active = TibiSuite.GetActiveSetup()
  p.none:SetShown(#names == 0)
  if #names == 0 then
    p.none:ClearAllPoints(); p.none:SetPoint("TOPLEFT", 4, y); p.none:SetWidth(w - 8)
    y = y - (p.none:GetStringHeight() or 14) - 10
  end
  for _, nm in ipairs(names) do
    local label = nm .. ((nm == active) and ("  " .. K.HX.OK .. L.CTR_PRF_ACTIVE .. "|r") or "")
    row(label, {
      { L.CTR_PRF_APPLY, function() TibiSuite.ApplySetup(nm); RefreshProfiles(p) end },
      { L.CTR_PRF_UPDATE, function() TibiSuite.SaveSetup(nm); RefreshProfiles(p) end },
      { L.CTR_PRF_DELETE, function()
          TibiSuite.ShowConfirm(string.format(L.CTR_PRF_DEL_ASK_FMT, nm), function() TibiSuite.DeleteSetup(nm); RefreshProfiles(p) end)
        end },
    })
  end

  -- Regles
  y = y - 8
  p.h2:ClearAllPoints(); p.h2:SetPoint("TOPLEFT", 2, y - 4); y = y - 24
  p.rulesNote:ClearAllPoints(); p.rulesNote:SetPoint("TOPLEFT", 4, y); p.rulesNote:SetWidth(w - 8)
  y = y - (p.rulesNote:GetStringHeight() or 14) - 10
  local who = UnitName("player") or "?"
  if TibiSuite.SafeName then who = TibiSuite.SafeName(who) end
  local specName = "?"
  local idx = GetSpecialization and GetSpecialization()
  if idx and GetSpecializationInfo then
    local _, sn = GetSpecializationInfo(idx); specName = sn or specName
  end
  for _, r in ipairs(p.rules) do
    local lbl = (r.kind == "spec" and string.format(L.CTR_PRF_R_SPEC_FMT, specName))
      or (r.kind == "char" and string.format(L.CTR_PRF_R_CHAR_FMT, who)) or L.CTR_PRF_R_LVL
    r.txt:SetText(lbl)
    local cur = TibiSuite.GetSetupRule(r.kind)
    r.btn._label:SetText(cur or (K.HX.DIM .. L.CTR_PRF_R_NONE .. "|r"))
    r:SetWidth(w)
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y)
    r:SetShown(#names > 0)
    if #names > 0 then y = y - 34 end
  end

  -- Points de restauration
  y = y - 8
  p.h3:ClearAllPoints(); p.h3:SetPoint("TOPLEFT", 2, y - 4); y = y - 24
  p.rpNote:ClearAllPoints(); p.rpNote:SetPoint("TOPLEFT", 4, y); p.rpNote:SetWidth(w - 8)
  y = y - (p.rpNote:GetStringHeight() or 14) - 10
  p.rpNew:ClearAllPoints(); p.rpNew:SetPoint("TOPLEFT", 0, y); y = y - 36
  local pts = TibiSuite.GetRestorePoints()
  p.rpNone:SetShown(#pts == 0)
  if #pts == 0 then p.rpNone:ClearAllPoints(); p.rpNone:SetPoint("TOPLEFT", 4, y); y = y - 22 end
  for i = #pts, 1, -1 do
    local pt = pts[i]
    row(K.HX.DIM .. date("%d/%m %H:%M", pt.t or 0) .. "|r   " .. tostring(pt.why or ""), {
      { L.CTR_PRF_RP_RESTORE, function()
          TibiSuite.ShowConfirm(L.CTR_PRF_RP_ASK, function() TibiSuite.RestorePoint(i); RefreshProfiles(p) end)
        end },
      { L.CTR_PRF_DELETE, function() TibiSuite.DeleteRestorePoint(i); RefreshProfiles(p) end },
    })
  end
  c:SetHeight(-y + 10)
end

-- ── Widgets ────────────────────────────────────────────────────────
local RefreshWidgetsPage
local TILE_H = 104

local function BuildWidgetsPage(p)
  local sc = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
  sc:SetPoint("TOPLEFT", 0, 0); sc:SetPoint("BOTTOMRIGHT", -24, 0)
  if UI.SkinScrollBar then UI.SkinScrollBar(sc, ACC) end
  local c = CreateFrame("Frame", nil, sc)
  c:SetSize(DockW(), 10)
  sc:SetScrollChild(c)
  p.scroll, p.child = sc, c
  p.lock = K.Btn(c, 210, 26, "")
  p.lock:SetScript("OnClick", function()
    TibiSuite.SetWidgetsLocked(not TibiSuiteDB.widgetsLocked); RefreshWidgetsPage(p)
  end)
  local function size(d)
    local v = math.max(70, math.min(150, (tonumber(TibiSuiteDB.widgetScale) or 100) + d))
    TibiSuiteDB.widgetScale = (v ~= 100) and v or nil
    TibiSuite.ApplyWidgets(); RefreshWidgetsPage(p)
  end
  p.minus = K.Btn(c, 30, 26, "-"); p.minus:SetScript("OnClick", function() size(-10) end)
  p.size = K.Text(c, "GameFontHighlight", "", K.COL.TXT)
  p.plus = K.Btn(c, 30, 26, "+"); p.plus:SetScript("OnClick", function() size(10) end)
  p.none = K.Btn(c, 170, 26, L.CTR_BAR_WID_NONE or "Tout désépingler")
  p.none:SetScript("OnClick", function() TibiSuite.UnpinAllWidgets(); RefreshWidgetsPage(p) end)
  p.empty = K.Text(c, "GameFontHighlight", L.CTR_WID_NONE, K.COL.DIM)
  p.tip = K.Text(c, "GameFontDisableSmall", L.CTR_WID_TIP, K.COL.DIM)
  p.tiles = {}
end

local function WidgetTile(p, i)
  local t = p.tiles[i]
  if t then return t end
  t = K.Card(p.child)
  t:SetHeight(TILE_H)
  t.state = K.Label(t, L.CTR_WID_PINNED)
  t.state:SetPoint("TOPRIGHT", -10, -10)
  t.btn = K.Btn(t, 120, 24, "")
  t.btn:SetPoint("BOTTOMRIGHT", -10, 10)
  p.tiles[i] = t
  return t
end

function RefreshWidgetsPage(p)
  if not (p and p.child) then return end
  local w = DockW()
  local c = p.child
  c:SetWidth(w)
  local y = -2
  p.lock._label:SetText(TibiSuiteDB.widgetsLocked and L.CTR_WID_UNLOCK or L.CTR_WID_LOCK)
  p.lock:ClearAllPoints(); p.lock:SetPoint("TOPLEFT", 0, y)
  p.minus:ClearAllPoints(); p.minus:SetPoint("LEFT", p.lock, "RIGHT", 16, 0)
  p.size:SetText(string.format(L.CTR_WID_SIZE_FMT, tonumber(TibiSuiteDB.widgetScale) or 100))
  p.size:ClearAllPoints(); p.size:SetPoint("LEFT", p.minus, "RIGHT", 10, 0)
  p.plus:ClearAllPoints(); p.plus:SetPoint("LEFT", p.size, "RIGHT", 10, 0)
  p.none:ClearAllPoints(); p.none:SetPoint("TOPRIGHT", 0, y)
  y = y - 40
  local mods = TibiSuite.PinnableModules()
  for _, t in ipairs(p.tiles) do t:Hide() end
  p.empty:SetShown(#mods == 0)
  if #mods == 0 then
    p.empty:ClearAllPoints(); p.empty:SetPoint("TOPLEFT", 4, y); p.empty:SetWidth(w - 8)
    y = y - 40
  end
  local cols = (w >= 620) and 2 or 1
  local tw = math.floor((w - (cols - 1) * 10) / cols)
  for i, mod in ipairs(mods) do
    local t = WidgetTile(p, i)
    t:SetWidth(tw)
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", ((i - 1) % cols) * (tw + 10), y - math.floor((i - 1) / cols) * (TILE_H + 10))
    if t.preview and t.preview.key ~= mod.key then t.preview:Hide(); t.preview = nil end
    if not t.preview then
      t.preview = TibiSuite.MakeWidgetPreview(t, mod.key)
      t.preview:SetPoint("TOPLEFT", 10, -10)
    end
    t.preview:SetWidth(math.min(260, tw - 20))
    t.preview:Refresh()
    local on = TibiSuite.IsWidgetPinned(mod.key)
    t.state:SetShown(on)
    t.state:SetTextColor(ACC[1], ACC[2], ACC[3])
    t.btn._label:SetText(on and L.CTR_WID_UNPIN or L.CTR_WID_PIN)
    t.btn:SetScript("OnClick", function() TibiSuite.PinWidget(mod.key, not on); RefreshWidgetsPage(p) end)
    t:Show()
  end
  y = y - math.ceil(#mods / cols) * (TILE_H + 10)
  p.tip:ClearAllPoints(); p.tip:SetPoint("TOPLEFT", 4, y - 4); p.tip:SetWidth(w - 8)
  y = y - (p.tip:GetStringHeight() or 14) - 14
  c:SetHeight(-y)
end

-- Bouton Annuler du pied de fenetre : visible tant qu'il y a quelque chose a annuler.
local function RefreshUndo()
  if not undoBtn then return end
  local lbl = TibiSuite.GetUndoLabel and TibiSuite.GetUndoLabel()
  if lbl then
    if #lbl > 26 then lbl = lbl:sub(1, 24):gsub("[\128-\191]*$", ""):gsub("[\192-\255]$", "") .. "..." end
    undoBtn._label:SetText(string.format(L.CTR_UNDO_FMT, lbl))
    undoBtn:Show()
  else
    undoBtn:Hide()
  end
end

local function BuildDoctor(p)
  local sc = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
  sc:SetPoint("TOPLEFT", 0, 0)
  sc:SetPoint("BOTTOMRIGHT", -24, 0)
  if UI.SkinScrollBar then UI.SkinScrollBar(sc, ACC) end
  local c = CreateFrame("Frame", nil, sc)
  c:SetSize(DockW(), 10)
  sc:SetScrollChild(c)
  local fs = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", 4, -4)
  fs:SetWidth(DockW() - 10)
  fs:SetJustifyH("LEFT")
  fs:SetSpacing(4)
  p.fs, p.child = fs, c
end

local function RunDoctorInto(p)
  local lines = {}
  local function emit(s) lines[#lines + 1] = s end
  if TibiSuite.RunDoctor then pcall(TibiSuite.RunDoctor, emit) end
  lines[#lines + 1] = " "
  if TibiSuite.RunPerf then pcall(TibiSuite.RunPerf, emit) end
  p.fs:SetText(table.concat(lines, "\n"))
  p.child:SetHeight((p.fs:GetStringHeight() or 100) + 12)
end

local function LayoutDoctor(p)
  p.child:SetWidth(DockW())
  p.fs:SetWidth(DockW() - 10)
  p.child:SetHeight((p.fs:GetStringHeight() or 100) + 12)
end

-- Recalcule tout ce qui depend de la largeur (poignee de redimensionnement).
local function Relayout()
  if not frame then return end
  local pw = PaneW()
  hdr.desc:SetWidth(pw - 44)
  note.text:SetWidth(pw - 20)
  if pages.home and pages.home.cardFrames then LayoutHome(pages.home) end
  if pages.doctor and pages.doctor.fs then LayoutDoctor(pages.doctor) end
  if pages.profiles and pages.profiles.child and pages.profiles:IsShown() then RefreshProfiles(pages.profiles) end
  if pages.widgets and pages.widgets.child and pages.widgets:IsShown() then RefreshWidgetsPage(pages.widgets) end
  if docked and docked:IsDocked() then docked:SetContentWidth(DockW()) end
end

-- ── Selection d'une page ───────────────────────────────────────────
function Select(id)
  current = id
  docked = nil
  for _, pg in pairs(pages) do pg:Hide() end
  note:Hide()
  SetFooter(nil)
  RefreshRows()

  if id == "home" then
    local p = Page("home")
    if not p.cards then BuildHome(p) end
    local who = UnitName("player")
    if who and TibiSuite.SafeName then who = TibiSuite.SafeName(who) end
    SetHeader(K.LOGO, L.CTR_WEEK_TITLE, ACC,
      who and string.format(L.CTR_WEEK_DESC_FMT, who) or L.CTR_HOME_DESC)
    p:Show()
    RefreshHome(p)
    return
  elseif id == "bar" then
    local p = Page("bar")
    SetHeader(K.LOGO, L.CTR_BAR, ACC, L.CTR_BAR_DESC)
    p:Show()
    docked = BuildBarPanel(); docked:Dock(p, DockW())
    return
  elseif id == "widgets" then
    local p = Page("widgets")
    if not p.child then BuildWidgetsPage(p) end
    SetHeader(K.LOGO, L.CTR_WIDGETS, ACC, L.CTR_WIDGETS_DESC)
    p:Show()
    RefreshWidgetsPage(p)
    return
  elseif id == "display" then
    local p = Page("display")
    SetHeader(K.LOGO, L.CTR_DISPLAY, ACC, L.CTR_DISPLAY_DESC)
    p:Show()
    docked = BuildDisplayPanel(); docked:Dock(p, DockW())
    return
  elseif id == "reminders" then
    local p = Page("reminders")
    SetHeader(K.LOGO, L.CTR_REMIND, ACC, L.CTR_REMIND_DESC)
    p:Show()
    docked = BuildRemindPanel(); docked:Dock(p, DockW())
    return
  elseif id == "profiles" then
    local p = Page("profiles")
    if not p.child then BuildProfiles(p) end
    SetHeader(K.LOGO, L.CTR_PROFILES, ACC, L.CTR_PROFILES_DESC)
    p:Show()
    RefreshProfiles(p)
    SetFooter({ { L.CTR_Q_PROFILE, function() frame:Hide(); if TibiSuite.OpenProfileWindow then TibiSuite.OpenProfileWindow() end end } })
    return
  elseif id == "activity" then
    local p = Page("activity")
    if not p.child then BuildActivity(p) end
    SetHeader(K.LOGO, L.CTR_ACTIVITY, ACC, L.CTR_ACTIVITY_DESC)
    p:Show()
    RefreshActivity(p)
    if TibiSuite.MarkFeedSeen then TibiSuite.MarkFeedSeen() end
    SetFooter({ { L.CTR_ACT_CLEAR, function()
      if TibiSuite.ShowConfirm then
        TibiSuite.ShowConfirm(L.CTR_ACT_CLEAR_ASK, function() if TibiSuite.ClearFeed then TibiSuite.ClearFeed() end end)
      end
    end } })
    return
  elseif id == "doctor" then
    local p = Page("doctor")
    if not p.fs then BuildDoctor(p) end
    SetHeader(K.LOGO, L.CTR_DOCTOR, ACC, L.CTR_DOCTOR_DESC)
    p:Show()
    RunDoctorInto(p)
    SetFooter({ { L.CTR_DOC_RERUN, function() RunDoctorInto(p) end } })
    return
  elseif id == "maint" then
    local p = Page("maint")
    SetHeader(K.LOGO, L.CTR_MAINT, ACC, L.CTR_MAINT_DESC)
    p:Show()
    local panel = GrabPanel("maint", function() TibiSuite.OpenModulePanel() end)
    if panel then docked = panel; panel:Dock(p, DockW()) else ShowNote(L.CTR_NOTE_NOPANEL) end
    return
  end

  local mod = byKey[id]
  if not mod then return Select("home") end
  local st = ModState(mod)
  local slash = K.MODULE_SLASH[mod.key]
  local desc = (L["DESC_" .. mod.key] or "") .. (slash and ("\n" .. K.HX.DIM .. L.CTR_SLASH .. slash .. "|r") or "")
  SetHeader(K.MODULE_LOGO[mod.key], mod.addonName, ModCol(mod), desc, STATE_TXT[st]())

  local name = Hex(ModCol(mod)) .. mod.addonName .. "|r"
  local footer = {}
  if st == "on" or st == "unload" then
    footer[#footer + 1] = { L.CTR_OPEN_MOD, function() frame:Hide(); TibiSuite.OpenModule(mod.key) end }
  end
  if st ~= "absent" then
    footer[#footer + 1] = { L.CTR_REINSTALL, function()
      TibiSuite.ShowConfirm((L.CONFIRM_REINSTALL_MOD_FMT1 or "") .. name .. (L.CONFIRM_REINSTALL_MOD_FMT2 or ""),
        function() TibiSuite.ReinstallModule(mod.key) end)
    end }
  end
  if mod.curseUrl then
    footer[#footer + 1] = { L.CTR_CURSE, function() K.ShowURL(mod.curseUrl) end }
  end
  SetFooter(footer)

  if st == "absent" then
    ShowNote(L.CTR_NOTE_ABSENT)
  elseif st == "off" then
    ShowNote(L.CTR_NOTE_OFF, L.CTR_ENABLE, function() ToggleModule(mod) end)
  elseif st == "load" then
    ShowNote(L.CTR_NOTE_LOAD, L.CTR_RELOAD, function() TibiSuite.Reload() end)
  else
    local p = Page(mod.key)
    p:Show()
    local panel = GrabPanel(mod.key, ModuleOpener(mod))
    if panel then docked = panel; panel:Dock(p, DockW()) else ShowNote(L.CTR_NOTE_NOPANEL) end
  end
end

function RefreshAll()
  if not frame then return end
  RefreshRows()
  RefreshFooter()
  if current == "home" and pages.home and pages.home.cards then RefreshHome(pages.home) end
end

if TibiSuite.OnDisplayChanged then
  TibiSuite.OnDisplayChanged(function()
    if frame and frame:IsShown() and (current == "home" or current == "activity") then Select(current) end
  end)
end

-- ── Construction de la fenetre ─────────────────────────────────────
local function Build()
  if frame then return true end
  K, UI = TibiSuite._kit, _G.TibiMidnight
  if not (K and UI and UI.CreateOptionsPanel and (UI._version or 0) >= 13) then return false end
  ACC = K.ACC

  local f = CreateFrame("Frame", "TibiSuiteCentre", UIParent, "BackdropTemplate")
  -- Taille memorisee (poignee bas-droit), bornee a l'ecran.
  local maxW = math.max(MIN_W, math.floor(UIParent:GetWidth() or W))
  local maxH = math.max(MIN_H, math.floor(UIParent:GetHeight() or H))
  local sw, sh = TibiSuiteDB.centreW or W, TibiSuiteDB.centreH or H
  f:SetSize(math.min(math.max(sw, MIN_W), maxW), math.min(math.max(sh, MIN_H), maxH))
  f:SetResizable(true)
  if f.SetResizeBounds then f:SetResizeBounds(MIN_W, MIN_H, maxW, maxH)
  elseif f.SetMinResize then f:SetMinResize(MIN_W, MIN_H); f:SetMaxResize(maxW, maxH) end
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:Hide()
  K.SkinLikeSuite(f, ACC)
  tinsert(UISpecialFrames, "TibiSuiteCentre")
  frame = f

  -- En-tete (zone de deplacement)
  local head = CreateFrame("Frame", nil, f)
  head:SetPoint("TOPLEFT", 1, -3)
  head:SetPoint("TOPRIGHT", -1, -3)
  head:SetHeight(HDR)
  head:EnableMouse(true)
  head:RegisterForDrag("LeftButton")
  head:SetScript("OnDragStart", function() f:StartMoving() end)
  head:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
  local hbg = head:CreateTexture(nil, "BACKGROUND")
  hbg:SetAllPoints()
  hbg:SetColorTexture(UI.C.HDR[1], UI.C.HDR[2], UI.C.HDR[3], 1)
  local logo = head:CreateTexture(nil, "ARTWORK")
  logo:SetSize(28, 28); logo:SetPoint("LEFT", 14, 0); logo:SetTexture(K.LOGO)
  local title = head:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
  title:SetText("TibiSuite")
  title:SetTextColor(ACC[1], ACC[2], ACC[3])
  local ver = K.Text(head, "GameFontDisableSmall", "v" .. tostring(TibiSuite.VERSION or "?"), K.COL.DIM)
  ver:SetPoint("LEFT", title, "RIGHT", 10, -1)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 0, -10)
  close:SetScript("OnClick", function() f:Hide() end)

  -- Barre laterale
  local side = CreateFrame("Frame", nil, f)
  side:SetPoint("TOPLEFT", 1, -(HDR + 3))
  side:SetPoint("BOTTOMLEFT", 1, FOOT + 1)
  side:SetWidth(SIDE)
  local sbg = side:CreateTexture(nil, "BACKGROUND")
  sbg:SetAllPoints(); sbg:SetColorTexture(0, 0, 0, 0.22)
  local sline = side:CreateTexture(nil, "ARTWORK")
  sline:SetPoint("TOPRIGHT"); sline:SetPoint("BOTTOMRIGHT"); sline:SetWidth(1)
  sline:SetColorTexture(1, 1, 1, 0.08)

  search = CreateFrame("EditBox", nil, side, "BackdropTemplate")
  search:SetSize(SIDE - 20, 24)
  search:SetPoint("TOPLEFT", 10, -10)
  search:SetBackdrop(K.FLAT)
  search:SetBackdropColor(1, 1, 1, 0.05)
  search:SetBackdropBorderColor(1, 1, 1, 0.12)
  search:SetFontObject("GameFontHighlightSmall")
  search:SetTextInsets(8, 8, 0, 0)
  search:SetAutoFocus(false)
  local ph = K.Text(search, "GameFontDisableSmall", L.CTR_FILTER, K.COL.DIM)
  ph:SetPoint("LEFT", 9, 0)
  search:SetScript("OnTextChanged", function(s) ph:SetShown(s:GetText() == ""); LayoutList() end)
  search:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)
  search:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)

  local sc = CreateFrame("ScrollFrame", nil, side, "UIPanelScrollFrameTemplate")
  sc:SetPoint("TOPLEFT", 0, -42)
  sc:SetPoint("BOTTOMRIGHT", -20, 6)
  if UI.SkinScrollBar then UI.SkinScrollBar(sc, ACC) end
  listC = CreateFrame("Frame", nil, sc)
  listC:SetSize(SIDE - 22, 10)
  sc:SetScrollChild(listC)

  labels.general = K.Label(listC, L.CTR_GENERAL)
  labels.modules = K.Label(listC, L.CTR_MODULES)
  for _, g in ipairs(GENERAL) do
    MakeRow(g.id, L[g.label]).group = "general"
  end
  for _, mod in ipairs(TibiSuite.GetCatalog()) do
    byKey[mod.key] = mod
    MakeRow(mod.key, mod.addonName, mod).group = "modules"
  end
  LayoutList()

  -- Page : en-tete, corps, boutons
  local pane = CreateFrame("Frame", nil, f)
  pane:SetPoint("TOPLEFT", PANE_X, -(HDR + 3 + 14))
  pane:SetPoint("BOTTOMRIGHT", -20, FOOT + 1 + 10)
  hdr.logo = pane:CreateTexture(nil, "ARTWORK")
  hdr.logo:SetSize(30, 30); hdr.logo:SetPoint("TOPLEFT", 0, 0)
  hdr.title = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  hdr.title:SetPoint("TOPLEFT", hdr.logo, "TOPRIGHT", 10, 0)
  hdr.status = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hdr.status:SetPoint("TOPRIGHT", 0, -2)
  hdr.desc = K.Text(pane, "GameFontDisableSmall", "", K.COL.MUT, PaneW() - 44)
  hdr.desc:SetPoint("TOPLEFT", hdr.title, "BOTTOMLEFT", 0, -4)
  local psep = pane:CreateTexture(nil, "ARTWORK")
  psep:SetColorTexture(UI.C.SEP[1], UI.C.SEP[2], UI.C.SEP[3], UI.C.SEP[4])
  psep:SetPoint("TOPLEFT", 0, -(BODY_TOP - 8)); psep:SetPoint("TOPRIGHT", 0, -(BODY_TOP - 8)); psep:SetHeight(1)

  local body = CreateFrame("Frame", nil, pane)
  body:SetPoint("TOPLEFT", 0, -BODY_TOP)
  body:SetPoint("BOTTOMRIGHT", 0, PAGE_FOOT + 6)
  f.body = body

  note = CreateFrame("Frame", nil, body)
  note:SetAllPoints(body)
  note:Hide()
  note.text = K.Text(note, "GameFontHighlight", "", K.COL.MUT, PaneW() - 20)
  note.text:SetPoint("TOPLEFT", 4, -10)
  note.btn = K.Btn(note, 200, 28, "", "pri")
  note.btn:SetPoint("TOPLEFT", note.text, "BOTTOMLEFT", 0, -16)

  for i = 1, 3 do
    local b = K.Btn(pane, 180, 28, "")
    b:SetPoint("BOTTOMLEFT", (i - 1) * 190, 0)
    b:Hide()
    foot[i] = b
  end

  -- Pied de fenetre
  local fsep = f:CreateTexture(nil, "ARTWORK")
  fsep:SetColorTexture(UI.C.SEP[1], UI.C.SEP[2], UI.C.SEP[3], UI.C.SEP[4])
  fsep:SetPoint("BOTTOMLEFT", 1, FOOT); fsep:SetPoint("BOTTOMRIGHT", -1, FOOT); fsep:SetHeight(1)
  local closeBtn = K.Btn(f, 100, 26, L.CTR_CLOSE)
  closeBtn:SetPoint("BOTTOMRIGHT", -26, 9)

  -- Poignee de redimensionnement (coin bas-droit). Pendant le glissement,
  -- la mise en page suit (au plus une passe toutes les 0,05 s) ; au
  -- relachement, la taille est memorisee dans TibiSuiteDB.
  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -3, 3)
  grip:SetFrameLevel(f:GetFrameLevel() + 20)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function(_, btn) if btn == "LeftButton" then f:StartSizing("BOTTOMRIGHT") end end)
  grip:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    TibiSuiteDB.centreW = math.floor(f:GetWidth() + 0.5)
    TibiSuiteDB.centreH = math.floor(f:GetHeight() + 0.5)
    Relayout()
  end)
  local layoutPending = false
  f:SetScript("OnSizeChanged", function()
    if layoutPending then return end
    layoutPending = true
    C_Timer.After(0.05, function() layoutPending = false; Relayout() end)
  end)
  closeBtn:SetScript("OnClick", function() f:Hide() end)
  reloadBtn = K.Btn(f, 190, 26, L.CTR_RELOAD, "pri")
  reloadBtn:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
  reloadBtn:SetScript("OnClick", function() TibiSuite.Reload() end)
  pendingTxt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pendingTxt:SetPoint("BOTTOMLEFT", 16, 16)
  undoBtn = K.Btn(f, 220, 26, "")
  undoBtn:SetPoint("BOTTOMLEFT", PANE_X, 9)
  undoBtn:SetScript("OnClick", function() if TibiSuite.Undo then TibiSuite.Undo() end end)
  undoBtn:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:AddLine(L.CTR_UNDO_TT, 1, 1, 1, true); GameTooltip:Show()
  end)
  undoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  undoBtn:Hide()
  if TibiSuite.OnUndoChanged then TibiSuite.OnUndoChanged(RefreshUndo) end
  if TibiSuite.ApplyUIScaleTo then TibiSuite.ApplyUIScaleTo(f) end
  local function refreshProf()
    local pp = pages.profiles
    if pp and pp.child and pp:IsVisible() then RefreshProfiles(pp) end
  end
  if TibiSuite.OnSetupsChanged then TibiSuite.OnSetupsChanged(refreshProf) end
  local function refreshWid()
    local wp = pages.widgets
    if wp and wp.child and wp:IsVisible() then RefreshWidgetsPage(wp) end
    local hp = pages.home
    if hp and hp.groups and hp:IsVisible() then
      for _, g in ipairs(hp.groups) do for _, card in ipairs(g.cards) do if card.pin then card.pin:Paint(false) end end end
    end
  end
  if TibiSuite.OnWidgetsChanged then TibiSuite.OnWidgetsChanged(refreshWid) end
  if TibiSuite.OnStatusChanged then TibiSuite.OnStatusChanged(refreshWid) end
  if TibiSuite.OnRestorePointsChanged then TibiSuite.OnRestorePointsChanged(refreshProf) end

  if K.AddFadeIn then K.AddFadeIn(f, 0.15) end

  -- Couleur d'accent changee (Barre et acces) : le liseré suit deja (socle),
  -- on rafraichit le titre, la barre laterale et la page ouverte.
  if TibiSuite.OnAccentChanged then
    TibiSuite.OnAccentChanged(function()
      title:SetTextColor(ACC[1], ACC[2], ACC[3])
      -- La page Barre et acces colore ses titres de section a la creation :
      -- on la reconstruit (l'ancienne est rendue a sa fenetre, masquee).
      for _, which in ipairs({ "bar", "dsp", "rem" }) do
        local old = (which == "bar" and barPanel) or (which == "dsp" and dspPanel) or remPanel
        if old then
          if which == "bar" then barPanel = nil elseif which == "dsp" then dspPanel = nil else remPanel = nil end
          pcall(old.Undock, old)
          if old.frame then old.frame:Hide() end
        end
      end
      if f:IsShown() then RefreshAll(); Select(current) end
    end)
  end
  if TibiSuite.OnFeedChanged then
    TibiSuite.OnFeedChanged(function()
      RefreshRows()
      local ap = pages.activity
      if ap and ap.child and ap:IsVisible() then RefreshActivity(ap) end
    end)
  end
  -- Un module signale un changement d'etat : « Ma semaine » suit, si affichee.
  if TibiSuite.OnStatusChanged then
    TibiSuite.OnStatusChanged(function()
      local hp = pages.home
      if hp and hp.child and hp:IsVisible() then RefreshHome(hp) end
    end)
  end
  return true
end

-- ── API ────────────────────────────────────────────────────────────
function TibiSuite.OpenCentre(pageId)
  if not Build() then
    print("|cFFC41F3BTibiSuite|r : " .. L.CTR_UNAVAIL)
    return
  end
  if pageId then current = pageId end
  frame:Show()
  frame:Raise()
  RefreshAll()
  Select(current)
end

-- ── Options des modules dans le Centre (socle v14) ─────────────────
-- Nom du panneau d'options (cfg.name du socle) -> page du Centre. Standby est
-- volontairement absent : son panneau est aussi sa fenetre principale (son
-- onglet), il reste donc flottant. Un module ajoute a la suite et absent de
-- cette table garde simplement sa fenetre flottante.
local PANEL_PAGE = {
  DailyTrackerOptionsMidnight  = "Daily",
  DgnTrackerOptionsMidnight    = "Dgn",
  LegTrackerOptionsMidnight    = "Leg",
  RenTrackerOptionsMidnight    = "Rep",
  LvlHistoryOptionsMidnight    = "Lvl",
  WeeklyCompassOptionsMidnight = "Weekly",
  MiniHubOptionsMidnight       = "MiniHub",
  XPBarOptionsMidnight         = "XPBar",
  RepBarOptionsMidnight        = "RepBar",
  LairLensOptionsMidnight      = "Lair",
  SkillTrackerOptions          = "Skill",
  PostBoxOptionsFrame          = "Post",
  StatsOptions                 = "Stats",
  OpacityOptions               = "Opacity",
  TibiSuiteModulesPanel        = "maint",
}
TibiSuite.PANEL_PAGE = PANEL_PAGE

-- Construit (sans les afficher) les panneaux d'options des modules charges,
-- pour que la palette de commandes connaisse tous leurs reglages. Le panneau
-- s'ouvre puis se referme dans la meme image : rien n'apparait a l'ecran.
function TibiSuite.PrebuildPanels()
  if not Build() then return end
  local pageHas = {}
  for _, page in pairs(PANEL_PAGE) do pageHas[page] = true end
  for _, mod in ipairs(TibiSuite.GetCatalog()) do
    if pageHas[mod.key] and not panelCache[mod.key] and C_AddOns.IsAddOnLoaded(mod.addonName) then
      local p = GrabPanel(mod.key, ModuleOpener(mod))
      if p and not p:IsDocked() and p.frame then p.frame:Hide() end
    end
  end
  BuildBarPanel()
  BuildDisplayPanel()
  BuildRemindPanel()
end

function TibiSuite.OptionsInCentre()
  return not (TibiSuiteDB and TibiSuiteDB.optionsInCentre == false)
end

-- Appele par panel:Show() du socle quand un panneau veut s'ouvrir en
-- flottant. true = le Centre a pris la main (le panneau sera ancre dans la
-- page du module par Select), false = comportement d'origine.
local function PanelRedirect(panel)
  if not TibiSuite.OptionsInCentre() then return false end
  local id = panel and panel._name and PANEL_PAGE[panel._name]
  if not id then return false end
  -- Le Centre recupere ce panneau la premiere fois par la voie du module :
  -- on le memorise tout de suite pour eviter un second aller-retour.
  if not panelCache[id] and panel.Dock then panelCache[id] = panel end
  TibiSuite.OpenCentre(id)
  return true
end

do
  local S = _G.TibiMidnight
  if S then S.PanelRedirect = PanelRedirect end
end

function TibiSuite.ToggleCentre(pageId)
  if frame and frame:IsShown() then frame:Hide() else TibiSuite.OpenCentre(pageId) end
end

function TibiSuite.IsCentreShown() return frame and frame:IsShown() or false end

-- Resynchronise la page « Barre et acces » si elle est a l'ecran (appele par
-- RefreshOptions du core : /ts lock, barre deplacee a la souris, profils...).
function TibiSuite.RefreshCentreBar()
  if barPanel and barPanel:IsDocked() and barPanel:IsShown() then barPanel:Refresh() end
end

-- ── Page dans Options > AddOns de Blizzard ─────────────────────────
-- Simple vitrine avec un bouton vers le Centre. On ne referme PAS la
-- fenetre d'options de Blizzard depuis notre code (aucun risque de taint) :
-- le Centre (strate DIALOG) s'ouvre par-dessus, Echap le referme d'abord.
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local kit = TibiSuite._kit or {}
    local p = CreateFrame("Frame", "TibiSuiteSettingsPage", UIParent)
    p:Hide()
    local logo = p:CreateTexture(nil, "ARTWORK")
    logo:SetSize(48, 48); logo:SetPoint("TOPLEFT", 16, -16)
    logo:SetTexture(kit.LOGO or "Interface\\AddOns\\TibiSuite\\medias\\TibiSuite")
    local t = p:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    t:SetPoint("LEFT", logo, "RIGHT", 12, 6)
    t:SetText("|cFFC41F3BTibiSuite|r")
    local v = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    v:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
    v:SetText("v" .. tostring(TibiSuite.VERSION or "?"))
    local d = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    d:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -16)
    d:SetWidth(520); d:SetJustifyH("LEFT")
    d:SetText(L.CTR_SET_DESC)
    local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    b:SetSize(260, 28); b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -14)
    b:SetText(L.CTR_SET_OPEN)
    b:SetScript("OnClick", function()
      C_Timer.After(0, function() if TibiSuite.OpenCentre then TibiSuite.OpenCentre() end end)
    end)
    local h = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    h:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -12)
    h:SetWidth(520); h:SetJustifyH("LEFT")
    h:SetText(L.CTR_SET_HINT)
    local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, p, "TibiSuite")
    if ok and cat then pcall(Settings.RegisterAddOnCategory, cat); TibiSuite.settingsCategory = cat end
  end)
end
