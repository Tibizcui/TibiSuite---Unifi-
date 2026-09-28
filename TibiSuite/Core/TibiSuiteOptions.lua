-- ================================================================
-- TibiSuiteOptions v7.1.5.31
-- Auteur : Tibiscui - Kirin Tor
-- Role   : Tout ce qui est « installation » de la suite :
--          - panneau « Modules » (une case a cocher par module) ;
--          - installateur de premier lancement en 6 etapes (Bienvenue,
--            Modules, Barre et minicarte, Ecosysteme, Recapitulatif,
--            Installation) ;
--          - fenetre « Quoi de neuf » (une fois par version) ;
--          - fenetre des profils de suite (codes TS1:).
--          Construit sur le socle commun (TibiMidnight).
-- Ce fichier ne declare aucune SavedVariables : l'etat vit dans
-- TibiSuiteDB (enabledModules, setupDone, lastSeenVersion, ...), gere par
-- le core (TibiSuite.SetModuleEnabled, ApplyBarSettings, ApplyProfile...).
-- ================================================================

local ACCENT_SUITE = { 0.769, 0.122, 0.231 }   -- rouge TibiSuite (#C41F3B)
local LOGO         = "Interface\\AddOns\\TibiSuite\\medias\\TibiSuite"

-- Logo propre a chaque module (chemins sans extension, WoW resout .tga).
local MODULE_LOGO = {
  Daily   = "Interface\\AddOns\\DailyTracker\\medias\\DailyTracker",
  Dgn     = "Interface\\AddOns\\DgnTracker\\medias\\DgnTracker",
  Leg     = "Interface\\AddOns\\LegTracker\\medias\\LegTracker",
  Rep     = "Interface\\AddOns\\RenTracker\\medias\\RenTracker",
  Lvl     = "Interface\\AddOns\\LvlHistory\\Media\\icon",
  Weekly  = "Interface\\AddOns\\WeeklyCompass\\medias\\logo",
  MiniHub = "Interface\\AddOns\\MiniHub\\media\\Logo_MiniHub",
  XPBar   = "Interface\\AddOns\\XPBar\\medias\\Logo",
  RepBar  = "Interface\\AddOns\\RepBar\\medias\\Logo",
  Lair    = "Interface\\AddOns\\LairLens\\Media\\Logo",
  Skill   = "Interface\\AddOns\\SkillTracker\\media\\Logo",
  Post    = "Interface\\AddOns\\PostBox\\medias\\Logo",
  Stats   = "Interface\\AddOns\\Stats\\medias\\Logo",
  Opacity = "Interface\\AddOns\\Opacity\\medias\\Logo",
  Suite   = LOGO,
}

-- ================================================================
-- LOCALISATION
-- Le francais reste le defaut embarque directement ici (via l'operateur
-- "or") : Locale\enUS.lua ecrase ensuite ces cles si le client est en
-- anglais. Meme table partagee que TibiSuiteCore.lua (TibiSuiteL).
-- ================================================================
TibiSuiteL = TibiSuiteL or {}
local L = TibiSuiteL

-- Presentation de la suite (installateur + panneau des modules).
L.INTRO = L.INTRO or "Tous tes trackers Tibiscui réunis sous un seul bouton de minicarte et une barre d'onglets. Tu choisis les modules à charger : les autres ne sont plus chargés du tout par WoW."

-- Resume court par module.
L.DESC_Daily   = L.DESC_Daily   or "Quêtes quotidiennes et hebdomadaires, cochées automatiquement selon ton historique."
L.DESC_Dgn     = L.DESC_Dgn     or "Entrées d'instances : donjons, raids, gouffres, Torghast, toutes extensions."
L.DESC_Leg     = L.DESC_Leg     or "Légendaires par extension : statut, quêtes, composants, collection et farm."
L.DESC_Rep     = L.DESC_Rep     or "Réputations et Renom de Vanilla à Midnight, checklist hebdo et temps restant."
L.DESC_Lvl     = L.DESC_Lvl     or "Historique de tes sessions de leveling et de farm, avec statistiques."
L.DESC_Weekly  = L.DESC_Weekly  or "Ce qu'il reste à faire cette semaine pour maximiser tes récompenses."
L.DESC_MiniHub = L.DESC_MiniHub or "Range les boutons de la minicarte dans un conteneur rétractable."
L.DESC_XPBar   = L.DESC_XPBar   or "Barre d'XP avancée : XP réelle des quêtes, repos, historique, styles."
L.DESC_Lair    = L.DESC_Lair    or "Audit de groupe et pertinence des récompenses pour les Repaires."
L.DESC_Skill   = L.DESC_Skill   or "Progression des métiers par extension, sur tous tes personnages."
L.DESC_RepBar  = L.DESC_RepBar  or "Barre de réputation qui suit la faction de ta zone et de tes quêtes."
L.DESC_Post    = L.DESC_Post    or "Boîte aux lettres : ouverture en masse, carnet de contacts, statistiques."
L.DESC_Stats   = L.DESC_Stats   or "Quêtes, or, donjons et M+, temps de jeu. Alimente le Dashboard et Tibi-Companion."
L.DESC_Opacity = L.DESC_Opacity or "Transparence des fenêtres, au survol ou en combat, sans toucher au mode Édition."

L.URL_HINT = L.URL_HINT or "Ctrl+C pour copier"

-- Panneau "Modules"
L.PANEL_TITLE      = L.PANEL_TITLE      or "|cFFC41F3BTibiSuite|r  Modules"
L.SEC_MODULES       = L.SEC_MODULES       or "Modules : Chargés / Non chargés"
L.NOTE_MODULES      = L.NOTE_MODULES      or "Coche les modules que tu veux. Un module coché qui était déjà en mémoire fonctionne tout de suite ; sinon il faut un /reload. Un module décoché n'est plus chargé du tout par WoW à partir du /reload suivant."
L.LBL_ABSENT         = L.LBL_ABSENT         or "  |cFF808080(absent)|r"
L.TOAST_ENABLED_FMT  = L.TOAST_ENABLED_FMT  or "activé"
L.TOAST_ENABLED_RELOAD = L.TOAST_ENABLED_RELOAD or "activé - effectif au prochain |cFFFFD700/reload|r"
L.TOAST_DISABLED_FMT = L.TOAST_DISABLED_FMT or "désactivé - effectif au prochain |cFFFFD700/reload|r"
L.CHECK_TOOLTIP_ON   = L.CHECK_TOOLTIP_ON   or "Charger / décharger "
L.CHECK_TOOLTIP_OFF  = L.CHECK_TOOLTIP_OFF  or " n'est pas installé (dossier absent)."
L.SEC_TIP            = L.SEC_TIP            or "Astuce"
L.NOTE_TIP           = L.NOTE_TIP           or "Un module décoché est désactivé dans la liste d'addons de WoW : après le /reload, ses fichiers ne sont plus lus et il ne consomme plus rien. Sa progression reste sauvegardée. /ts doctor vérifie l'état réel de chaque module."
L.SEC_REINSTALL_MOD  = L.SEC_REINSTALL_MOD  or "Réinstaller un module"
L.NOTE_REINSTALL_MOD = L.NOTE_REINSTALL_MOD or "Remet un module à zéro : efface ses réglages et sa progression, puis recharge l'interface. Action irréversible. La barre TibiSuite et les autres modules ne sont pas touchés."
L.BTN_REINSTALL       = L.BTN_REINSTALL       or "|cFFFF6666Réinstaller|r  "
L.CONFIRM_REINSTALL_MOD_FMT1 = L.CONFIRM_REINSTALL_MOD_FMT1 or "Réinstaller "
L.CONFIRM_REINSTALL_MOD_FMT2 = L.CONFIRM_REINSTALL_MOD_FMT2 or " ?\n\nCela efface définitivement ses réglages et sa progression, puis recharge l'interface."
L.SEC_REINSTALL_SUITE  = L.SEC_REINSTALL_SUITE  or "Réinstaller TibiSuite"
L.NOTE_REINSTALL_SUITE = L.NOTE_REINSTALL_SUITE or "Remet à zéro les réglages de la suite (barre, modules actifs, installation) et recharge l'interface. La progression de chaque module est conservée."
L.BTN_REINSTALL_SUITE  = L.BTN_REINSTALL_SUITE  or "|cFFC41F3BRéinstaller TibiSuite|r  |cFF808080(la suite)|r"
L.CONFIRM_REINSTALL_CORE = L.CONFIRM_REINSTALL_CORE or
  "Réinstaller TibiSuite ?\n\nCela remet à zéro les réglages de la suite (barre, modules actifs, installation) puis recharge l'interface. La progression de chaque module est conservée."
L.SEC_SETUP            = L.SEC_SETUP            or "Installation et profil"
L.NOTE_SETUP           = L.NOTE_SETUP           or "Relancer l'installation ne supprime rien : elle repart de tes réglages actuels."
L.BTN_RUN_SETUP        = L.BTN_RUN_SETUP        or "Relancer l'installation"
L.BTN_WHATSNEW         = L.BTN_WHATSNEW         or "Quoi de neuf"
L.BTN_PROFILE          = L.BTN_PROFILE          or "Exporter / importer un profil"
L.SEC_DASHBOARD        = L.SEC_DASHBOARD        or "Dashboard web"
L.NOTE_DASHBOARD       = L.NOTE_DASHBOARD       or "Colle tes statistiques sur le site pour les consulter hors du jeu. Rien n'est envoyé à un serveur : le code est lu localement par ton navigateur."
L.DASHBOARD_URL_LABEL  = L.DASHBOARD_URL_LABEL  or "URL du dashboard (Ctrl+C pour copier) :"
L.BTN_GENERATE_EXPORT  = L.BTN_GENERATE_EXPORT  or "Générer mon code d'export"
L.TOAST_NEED_STATS     = L.TOAST_NEED_STATS     or "Active le module |cFFFFD700Stats|r pour générer un export."
L.NOTE_DASHBOARD_PRIVACY = L.NOTE_DASHBOARD_PRIVACY or "Confidentialité : aucune donnée n'est envoyée à un serveur. Le code d'export est généré et lu entièrement en local (jeu et navigateur)."

-- Installateur : cadre et navigation
L.WIZ_SUBTITLE_FMT = L.WIZ_SUBTITLE_FMT or "Installation  -  v%s  -  patch %s"
L.WIZ_STEP1 = L.WIZ_STEP1 or "Bienvenue"
L.WIZ_STEP2 = L.WIZ_STEP2 or "Modules"
L.WIZ_STEP3 = L.WIZ_STEP3 or "Interface"
L.WIZ_STEP4 = L.WIZ_STEP4 or "Écosystème"
L.WIZ_STEP5 = L.WIZ_STEP5 or "Récap"
L.WIZ_STEP6 = L.WIZ_STEP6 or "Installation"
L.WIZ_SITE     = L.WIZ_SITE     or "Site"
L.WIZ_CURSE    = L.WIZ_CURSE    or "CurseForge"
L.WIZ_PREV     = L.WIZ_PREV     or "Précédent"
L.WIZ_START    = L.WIZ_START    or "Commencer"
L.WIZ_CONTINUE = L.WIZ_CONTINUE or "Continuer"
L.WIZ_INSTALL  = L.WIZ_INSTALL  or "Installer et démarrer"
L.WIZ_FINISH   = L.WIZ_FINISH   or "Terminer"
L.WIZ_RELOAD   = L.WIZ_RELOAD   or "Recharger l'interface"
L.WIZ_CLOSE_TT = L.WIZ_CLOSE_TT or "Fermer = terminer avec la sélection en cours"
-- Etape 1
L.WIZ_HERO_TITLE = L.WIZ_HERO_TITLE or "Bienvenue dans TibiSuite"
L.WIZ_PILL_DETECT = L.WIZ_PILL_DETECT or "modules trouvés"
L.WIZ_PILL_PATCH  = L.WIZ_PILL_PATCH  or "Patch %s  -  Interface %s"
L.WIZ_PILL_LOSS   = L.WIZ_PILL_LOSS   or "perte de progression"
L.WIZ_PILL_LATER  = L.WIZ_PILL_LATER  or "Modifiable à tout moment avec |cFFFFD100/ts modules|r"
L.WIZ_EXPRESS_TAG   = L.WIZ_EXPRESS_TAG   or "RECOMMANDÉ"
L.WIZ_EXPRESS_TITLE = L.WIZ_EXPRESS_TITLE or "Installation express"
L.WIZ_EXPRESS_DESC  = L.WIZ_EXPRESS_DESC  or "Active tous les modules avec les réglages conseillés, puis démarre."
L.WIZ_CUSTOM_TAG    = L.WIZ_CUSTOM_TAG    or "PAS À PAS"
L.WIZ_CUSTOM_TITLE  = L.WIZ_CUSTOM_TITLE  or "Personnalisée"
L.WIZ_CUSTOM_DESC   = L.WIZ_CUSTOM_DESC   or "Choisis tes modules, règle la barre et l'écosystème."
L.WIZ_IMPORT_TAG    = L.WIZ_IMPORT_TAG    or "AUTRE PC"
L.WIZ_IMPORT_TITLE  = L.WIZ_IMPORT_TITLE  or "Importer un profil"
L.WIZ_IMPORT_DESC   = L.WIZ_IMPORT_DESC   or "Colle un code TS1: pour reprendre une configuration existante."
L.WIZ_IMPORT_LABEL  = L.WIZ_IMPORT_LABEL  or "Code de profil (Ctrl+V dans la case) :"
L.WIZ_IMPORT_APPLY  = L.WIZ_IMPORT_APPLY  or "Appliquer ce profil"
-- Etape 2
L.WIZ_PRESETS   = L.WIZ_PRESETS   or "PRÉRÉGLAGES"
L.WIZ_PRESET_ALL     = L.WIZ_PRESET_ALL     or "Tout"
L.WIZ_PRESET_LEVEL   = L.WIZ_PRESET_LEVEL   or "Leveling"
L.WIZ_PRESET_END     = L.WIZ_PRESET_END     or "End-game"
L.WIZ_PRESET_COLLECT = L.WIZ_PRESET_COLLECT or "Collection"
L.WIZ_PRESET_MIN     = L.WIZ_PRESET_MIN     or "Minimaliste"
L.WIZ_COUNTER_FMT = L.WIZ_COUNTER_FMT or "%s / %d actifs"
L.WIZ_CAT_T = L.WIZ_CAT_T or "TRACKERS  -  FENÊTRES"
L.WIZ_CAT_H = L.WIZ_CAT_H or "HUD  -  BARRES PERMANENTES"
L.WIZ_CAT_O = L.WIZ_CAT_O or "OUTILS"
L.WIZ_WOW_DISABLED = L.WIZ_WOW_DISABLED or "désactivé dans WoW, sera réactivé"
-- Etape 3
L.WIZ_ORIENT = L.WIZ_ORIENT or "ORIENTATION"
L.WIZ_HORIZ  = L.WIZ_HORIZ  or "Horizontale"
L.WIZ_VERT   = L.WIZ_VERT   or "Verticale"
L.WIZ_SCALE  = L.WIZ_SCALE  or "ÉCHELLE"
L.WIZ_GRID   = L.WIZ_GRID   or "GRILLE D'ONGLETS"
L.WIZ_COLS_FMT = L.WIZ_COLS_FMT or "%d col."
L.WIZ_ROWS_FMT = L.WIZ_ROWS_FMT or "%d lig."
L.WIZ_CORNER = L.WIZ_CORNER or "POSITION DE DÉPART"
L.WIZ_MM     = L.WIZ_MM     or "Bouton de minicarte"
L.WIZ_OPEN   = L.WIZ_OPEN   or "Barre ouverte à la connexion"
L.WIZ_MSG    = L.WIZ_MSG    or "MESSAGES DE CONNEXION"
L.WIZ_MSG_FULL = L.WIZ_MSG_FULL or "Complet"
L.WIZ_MSG_ONE  = L.WIZ_MSG_ONE  or "Une ligne"
L.WIZ_MSG_NONE = L.WIZ_MSG_NONE or "Aucun"
L.WIZ_PREVIEW_CAP = L.WIZ_PREVIEW_CAP or "Aperçu en direct : la barre suit tes modules actifs"
L.WIZ_IFC_NOTE    = L.WIZ_IFC_NOTE    or "Tout reste réglable ensuite dans |cFFFFD100/ts config|r."
L.WIZ_CORNERS = L.WIZ_CORNERS or { "haut gauche", "haut centre", "haut droite", "milieu gauche", "centre",
  "milieu droite", "bas gauche", "bas centre", "bas droite" }
L.WIZ_CORNER_CUSTOM = L.WIZ_CORNER_CUSTOM or "position actuelle"
-- Etape 4
L.WIZ_DASH_TITLE = L.WIZ_DASH_TITLE or "Dashboard web"
L.WIZ_DASH_DESC  = L.WIZ_DASH_DESC  or "Stats enregistre ton code d'export à chaque déconnexion et à chaque /reload. Le Dashboard le décode dans ton navigateur : rien n'est envoyé à un serveur."
L.WIZ_DASH_EXPORT = L.WIZ_DASH_EXPORT or "Export automatique à la déconnexion"
L.WIZ_DASH_FEEDS  = L.WIZ_DASH_FEEDS  or "Cartes du Dashboard alimentées par tes modules :"
L.WIZ_DASH_COPY   = L.WIZ_DASH_COPY   or "Copier l'adresse du Dashboard"
L.WIZ_FEED_PROFILE = L.WIZ_FEED_PROFILE or "Profil et temps de jeu"
L.WIZ_FEED_QUESTS  = L.WIZ_FEED_QUESTS  or "Quêtes et or"
L.WIZ_FEED_DUNGEON = L.WIZ_FEED_DUNGEON or "Donjons et M+"
L.WIZ_FEED_EXPED   = L.WIZ_FEED_EXPED   or "Expéditions"
L.WIZ_FEED_PVP     = L.WIZ_FEED_PVP     or "PvP, gouffres, Torghast"
L.WIZ_FEED_REP     = L.WIZ_FEED_REP     or "Réputations"
L.WIZ_FEED_LEG     = L.WIZ_FEED_LEG     or "Légendaires"
L.WIZ_FEED_WEEK    = L.WIZ_FEED_WEEK    or "Semaine du Warband"
L.WIZ_FEED_OFF     = L.WIZ_FEED_OFF     or "inactif"
L.COMPANION_TITLE = L.COMPANION_TITLE or "Tibi-Companion"
L.COMPANION_BADGE = L.COMPANION_BADGE or "Gratuit"
L.COMPANION_LINE1 = L.COMPANION_LINE1 or "Tes stats hors du jeu, sans navigateur"
L.COMPANION_LINE2 = L.COMPANION_LINE2 or "Propose de publier ton Dashboard quand WoW se ferme"
L.COMPANION_LINE3 = L.COMPANION_LINE3 or "Raccourci bureau « Publier mon Dashboard »"
L.COMPANION_BTN   = L.COMPANION_BTN   or "Microsoft Store"
L.COMPANION_STORE_NOTE = L.COMPANION_STORE_NOTE or "Via le Store : installation signée, sans blocage de Windows."
L.WIZ_COMMUNITY      = L.WIZ_COMMUNITY      or "Communauté"
L.WIZ_COMMUNITY_DESC = L.WIZ_COMMUNITY_DESC or "Nouveautés, retours de bugs et idées de modules."
-- Etape 5
L.WIZ_RECAP_TITLE = L.WIZ_RECAP_TITLE or "Prêt à installer"
L.WIZ_RECAP_COUNT = L.WIZ_RECAP_COUNT or "modules seront actifs au démarrage."
L.WIZ_SUM_BAR     = L.WIZ_SUM_BAR     or "BARRE"
L.WIZ_SUM_MM      = L.WIZ_SUM_MM      or "MINICARTE"
L.WIZ_SUM_LOGIN   = L.WIZ_SUM_LOGIN   or "CONNEXION"
L.WIZ_SUM_DASH    = L.WIZ_SUM_DASH    or "DASHBOARD"
L.WIZ_SUM_BAR_FMT = L.WIZ_SUM_BAR_FMT or "%s, %d %%, grille %d x %d, %s"
L.WIZ_SUM_CLOSED  = L.WIZ_SUM_CLOSED  or ", fermée à la connexion"
L.WIZ_SUM_MM_ON   = L.WIZ_SUM_MM_ON   or "Un seul bouton TibiSuite"
L.WIZ_SUM_MM_OFF  = L.WIZ_SUM_MM_OFF  or "Bouton masqué (compartiment d'addons et /ts)"
L.WIZ_SUM_MSG_FULL = L.WIZ_SUM_MSG_FULL or "Messages complets"
L.WIZ_SUM_MSG_ONE  = L.WIZ_SUM_MSG_ONE  or "Une ligne"
L.WIZ_SUM_MSG_NONE = L.WIZ_SUM_MSG_NONE or "Aucun message"
L.WIZ_SUM_EXP_ON  = L.WIZ_SUM_EXP_ON  or "Export automatique activé"
L.WIZ_SUM_EXP_OFF = L.WIZ_SUM_EXP_OFF or "Export manuel seulement"
L.WIZ_OFF_NOTE_FMT = L.WIZ_OFF_NOTE_FMT or "%d module(s) décoché(s) (%s) ne seront plus chargés par WoW après le /reload. Leur progression reste sauvegardée."
L.WIZ_REASS1 = L.WIZ_REASS1 or "Aucune progression déplacée : chaque module garde sa propre sauvegarde."
L.WIZ_REASS2 = L.WIZ_REASS2 or "Un module décoché n'est plus chargé par WoW après le /reload."
L.WIZ_REASS3 = L.WIZ_REASS3 or "Tout se règle ensuite avec |cFFFFD100/ts modules|r et |cFFFFD100/ts config|r."
-- Etape 6
L.WIZ_RUNNING    = L.WIZ_RUNNING    or "Installation en cours"
L.WIZ_ST_WAIT    = L.WIZ_ST_WAIT    or "en attente"
L.WIZ_ST_RUN     = L.WIZ_ST_RUN     or "activation..."
L.WIZ_ST_OK      = L.WIZ_ST_OK      or "actif"
L.WIZ_ST_RELOAD  = L.WIZ_ST_RELOAD  or "au /reload"
L.WIZ_ST_OFF     = L.WIZ_ST_OFF     or "décoché"
L.WIZ_ST_FAIL    = L.WIZ_ST_FAIL    or "échec"
L.WIZ_DONE_TITLE = L.WIZ_DONE_TITLE or "C'est prêt"
L.WIZ_DONE_FMT   = L.WIZ_DONE_FMT   or "%d modules actifs."
L.WIZ_DONE_RELOAD_FMT = L.WIZ_DONE_RELOAD_FMT or " Un /reload finalisera %d changement(s) de module."
L.WIZ_G1_T = L.WIZ_G1_T or "/ts"
L.WIZ_G1_D = L.WIZ_G1_D or "Ouvre ou ferme la barre d'onglets."
L.WIZ_G2_T = L.WIZ_G2_T or "Maj + clic droit"
L.WIZ_G2_D = L.WIZ_G2_D or "Sur une fenêtre de module : ses options."
L.WIZ_G3_T = L.WIZ_G3_T or "Onglet Stats"
L.WIZ_G3_D = L.WIZ_G3_D or "Ton code d'export pour le Dashboard."
L.WIZ_FINISH_PRINT = L.WIZ_FINISH_PRINT or "installation terminée. |cFFFFD700/ts modules|r pour ajuster plus tard."
L.WIZ_FINISH_TOAST = L.WIZ_FINISH_TOAST or "|cFFC41F3BTibiSuite|r installé avec succès !"
L.WIZ_IMPORT_OK    = L.WIZ_IMPORT_OK    or "Profil lu : vérifie le récapitulatif puis installe."

-- Quoi de neuf
L.WN_TITLE    = L.WN_TITLE    or "Quoi de neuf"
L.WN_SUBTITLE = L.WN_SUBTITLE or "Affiché une seule fois par version"
L.WN_NEW      = L.WN_NEW      or "NOUVEAU"
L.WN_LOG      = L.WN_LOG      or "Journal complet"
L.WN_SETUP    = L.WN_SETUP    or "Relancer l'installation"
L.WN_OK       = L.WN_OK       or "Compris"
L.WN_NONE     = L.WN_NONE     or "Pas de note pour cette version."
L.WN_32_1 = L.WN_32_1 or "Nouvel installateur en 6 étapes : préréglages, aperçu de la barre, Dashboard et Tibi-Companion."
L.WN_32_2 = L.WN_32_2 or "Un module décoché n'est plus chargé du tout par WoW après /reload : vraie économie de mémoire."
L.WN_32_3 = L.WN_32_3 or "/ts doctor vérifie tes modules, /ts perf affiche leur mémoire, /ts profile exporte ta configuration."
L.WN_32_4 = L.WN_32_4 or "Logos dédiés pour Stats, RepBar, Opacity et PostBox."
L.WN_31_1 = L.WN_31_1 or "Mise à jour 12.1 : données vérifiées en jeu, détection sur tout le compte, collection, farm et alertes."
L.WN_31_2 = L.WN_31_2 or "Nouvelle carte Légendaires sur le Dashboard, alimentée par LegTracker."
L.WN_31_3 = L.WN_31_3 or "Noms français de Le Puits de soleil et d'Aberrus alignés sur le client."

-- Profils
L.PF_TITLE      = L.PF_TITLE      or "Profil de la suite"
L.PF_EXPORT     = L.PF_EXPORT     or "Ton profil actuel (Ctrl+C pour copier) :"
L.PF_IMPORT     = L.PF_IMPORT     or "Importer un profil (Ctrl+V puis Appliquer) :"
L.PF_APPLY      = L.PF_APPLY      or "Appliquer"
L.PF_NOTE       = L.PF_NOTE       or "Le profil contient les modules cochés et les réglages de la barre, jamais la progression des modules."
L.PF_APPLIED    = L.PF_APPLIED    or "Profil appliqué."
L.PF_RELOAD_ASK = L.PF_RELOAD_ASK or "Profil appliqué.\n\nCertains modules ne changeront d'état qu'après un rechargement de l'interface. Recharger maintenant ?"

-- Categorie pour l'installateur : "h" = barre permanente, "o" = outil, sinon
-- "t" (tracker, fenetre).
local GROUP = { XPBar = "h", RepBar = "h", MiniHub = "o", Post = "o", Opacity = "o" }

-- Prereglages de l'etape Modules (cles du catalogue).
local PRESETS = {
  { id = "all",     label = L.WIZ_PRESET_ALL },
  { id = "level",   label = L.WIZ_PRESET_LEVEL,   keys = { "XPBar", "RepBar", "Lvl", "Daily", "Rep", "Stats", "MiniHub" } },
  { id = "end",     label = L.WIZ_PRESET_END,     keys = { "Weekly", "Dgn", "Lair", "Leg", "Stats", "Rep", "Daily", "Skill", "MiniHub" } },
  { id = "collect", label = L.WIZ_PRESET_COLLECT, keys = { "Leg", "Rep", "Dgn", "Skill", "Stats", "Weekly", "MiniHub" } },
  { id = "min",     label = L.WIZ_PRESET_MIN,     keys = { "Stats", "XPBar", "MiniHub" } },
}

-- Cartes du Dashboard web et module qui les alimente.
local FEEDS = {
  { L.WIZ_FEED_PROFILE, "Stats" }, { L.WIZ_FEED_QUESTS, "Stats" }, { L.WIZ_FEED_DUNGEON, "Stats" },
  { L.WIZ_FEED_EXPED, "Stats" },   { L.WIZ_FEED_PVP, "Stats" },    { L.WIZ_FEED_REP, "Rep" },
  { L.WIZ_FEED_LEG, "Leg" },       { L.WIZ_FEED_WEEK, "Weekly" },
}

-- Notes de version affichees par « Quoi de neuf ». A COMPLETER a chaque
-- release : la cle est la version du core (VERSION dans TibiSuiteCore.lua).
-- Sans entree pour la version courante, la fenetre ne s'ouvre pas.
local WHATSNEW = {
  ["7.1.5.32"] = {
    { key = "Suite", title = "TibiSuite", text = L.WN_32_1, new = true },
    { key = "Suite", title = "TibiSuite", text = L.WN_32_2, new = true },
    { key = "Suite", title = "TibiSuite", text = L.WN_32_3, new = true },
    { key = "Stats", title = "Stats, RepBar, Opacity, PostBox", text = L.WN_32_4 },
  },
  ["7.1.5.31"] = {
    { key = "Leg",   title = "LegTracker", text = L.WN_31_1, new = true },
    { key = "Stats", title = "Dashboard",  text = L.WN_31_2, new = true },
    { key = "Leg",   title = "LegTracker", text = L.WN_31_3 },
  },
}

-- Liens officiels (ouverts via une fenetre "copier le lien" : WoW ne peut pas
-- ouvrir un navigateur lui-meme, l'URL est donc presentee prete a copier).
local URL_SITE      = "https://www.tibiscui.fr"
local URL_CURSE     = "https://www.curseforge.com/members/tibiscui/projects"
-- Microsoft Store plutot que l'installeur .exe : CONFIRME le 2026-09-28, le
-- Controle intelligent des applications de Windows 11 bloque l'installeur non
-- signe sans bouton « executer quand meme ». Les apps du Store sont signees.
local URL_COMPANION = "https://apps.microsoft.com/detail/9PBH67800875"
local URL_DASHBOARD = "https://www.tibiscui.fr/Dashboard.html"
local URL_DISCORD   = "https://discord.gg/tibiscui"
local URL_CHANGELOG = "https://www.curseforge.com/wow/addons/tibisuite/files"

local panel   -- construit une seule fois (paresseux)

-- ================================================================
-- FENETRES MAISON (confirmation + copie de lien)
-- ----------------------------------------------------------------
-- PIEGE REEL, CONFIRME EN JEU (ADDON_ACTION_FORBIDDEN "SpellStopCasting" sur
-- ToggleGameMenu/Echap, meme sans jamais afficher le moindre popup) : ecrire
-- des entrees dans StaticPopupDialogs - une table PARTAGEE avec Blizzard -
-- suffit a contaminer l'execution que Blizzard utilise ensuite pour gerer
-- Echap. Isole par bisection complete du code (tout desactive sauf ces 3
-- entrees -> erreur ; ces 3 entrees seules desactivees -> plus d'erreur).
-- SOLUTION : ne plus jamais ecrire dans StaticPopupDialogs. Fenetres 100%
-- maison ci-dessous (meme principe que BuildPlaceholder/TibiSuiteCore.lua),
-- fermables par UISpecialFrames (Echap natif, aucun risque).
-- ================================================================

-- Bouton plat local, meme rendu que UI.MakeButton mais sans en dependre
-- directement (au cas ou TibiMidnight ne serait pas encore charge).
local function MakeThemedButton(parent, w, h, text)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h)
  b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  b:SetBackdropColor(1, 1, 1, 0.05)
  b:SetBackdropBorderColor(1, 1, 1, 0.12)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetAllPoints()
  fs:SetText(text or "")
  b:SetScript("OnEnter", function(s) s:SetBackdropColor(1, 1, 1, 0.10); s:SetBackdropBorderColor(1, 1, 1, 0.25) end)
  b:SetScript("OnLeave", function(s) s:SetBackdropColor(1, 1, 1, 0.05); s:SetBackdropBorderColor(1, 1, 1, 0.12) end)
  return b
end

-- Meme theme graphique que le reste de la suite (fond plat sombre, bordure
-- fine, liseré d'accent) via UI.SkinFrame ; repli local si TibiMidnight
-- n'est pas encore charge (ne devrait pas arriver, mais pas de crash).
local function SkinLikeSuite(f, accent)
  local UI = _G.TibiMidnight
  if UI and UI.SkinFrame then
    UI.SkinFrame(f, accent, UI.C.PANEL)
  else
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.055, 0.063, 0.082, 0.98)
    f:SetBackdropBorderColor(0, 0, 0, 1)
  end
end

local confirmFrame
local function ShowConfirm(text, onAccept)
  if not confirmFrame then
    confirmFrame = CreateFrame("Frame", "TibiSuiteConfirmFrame", UIParent, "BackdropTemplate")
    confirmFrame:SetSize(380, 150)
    confirmFrame:SetPoint("CENTER")
    -- FULLSCREEN_DIALOG (au-dessus de DIALOG) : garantit que la confirmation
    -- s'affiche devant le panneau d'options / l'installateur qui l'a ouverte
    -- (tous en DIALOG), au lieu de se lancer derriere.
    confirmFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    SkinLikeSuite(confirmFrame, ACCENT_SUITE)
    confirmFrame:EnableMouse(true)
    confirmFrame:SetMovable(true)
    confirmFrame:RegisterForDrag("LeftButton")
    confirmFrame:SetScript("OnDragStart", confirmFrame.StartMoving)
    confirmFrame:SetScript("OnDragStop",  confirmFrame.StopMovingOrSizing)
    confirmFrame:Hide()
    tinsert(UISpecialFrames, "TibiSuiteConfirmFrame")

    local closeB = CreateFrame("Button", nil, confirmFrame, "UIPanelCloseButton")
    closeB:SetPoint("TOPRIGHT", confirmFrame, "TOPRIGHT", 2, 2)
    closeB:SetScript("OnClick", function() confirmFrame:Hide() end)

    local msg = confirmFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msg:SetPoint("TOP", 0, -30)
    msg:SetWidth(320)
    msg:SetJustifyH("CENTER")
    confirmFrame._msg = msg

    local yesBtn = MakeThemedButton(confirmFrame, 90, 24, "|cFF66FF66" .. (YES or "Oui") .. "|r")
    yesBtn:SetPoint("BOTTOMRIGHT", confirmFrame, "BOTTOM", -10, 16)
    yesBtn:SetScript("OnClick", function()
      confirmFrame:Hide()
      if confirmFrame._onAccept then confirmFrame._onAccept() end
    end)

    local noBtn = MakeThemedButton(confirmFrame, 90, 24, "|cFFFF7777" .. (NO or "Non") .. "|r")
    noBtn:SetPoint("BOTTOMLEFT", confirmFrame, "BOTTOM", 10, 16)
    noBtn:SetScript("OnClick", function() confirmFrame:Hide() end)
  end

  confirmFrame._msg:SetText(text)
  -- Hauteur adaptee au texte (messages de 2 a 5 lignes).
  confirmFrame:SetHeight(math.max(150, (confirmFrame._msg:GetStringHeight() or 40) + 90))
  confirmFrame._onAccept = onAccept
  confirmFrame:Show()
  confirmFrame:Raise()
end
TibiSuite.ShowConfirm = ShowConfirm

local urlFrame
local function ShowURL(url)
  if not urlFrame then
    urlFrame = CreateFrame("Frame", "TibiSuiteURLFrame", UIParent, "BackdropTemplate")
    urlFrame:SetSize(420, 100)
    urlFrame:SetPoint("CENTER")
    urlFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    SkinLikeSuite(urlFrame, ACCENT_SUITE)
    urlFrame:EnableMouse(true)
    urlFrame:SetMovable(true)
    urlFrame:RegisterForDrag("LeftButton")
    urlFrame:SetScript("OnDragStart", urlFrame.StartMoving)
    urlFrame:SetScript("OnDragStop",  urlFrame.StopMovingOrSizing)
    urlFrame:Hide()
    tinsert(UISpecialFrames, "TibiSuiteURLFrame")

    local hint = urlFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOP", 0, -22)
    hint:SetText(L.URL_HINT)

    local eb = CreateFrame("EditBox", "TibiSuiteURLBox", urlFrame, "InputBoxTemplate")
    eb:SetSize(370, 30)
    eb:SetPoint("TOP", hint, "BOTTOM", 0, -10)
    eb:SetAutoFocus(true)
    eb:SetScript("OnEscapePressed", function(s) s:GetParent():Hide() end)
    eb:SetScript("OnEnterPressed",  function(s) s:GetParent():Hide() end)
    urlFrame._box = eb

    local closeBtn = CreateFrame("Button", nil, urlFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", urlFrame, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() urlFrame:Hide() end)
  end

  urlFrame._box:SetText(url or "")
  urlFrame._box:HighlightText()
  urlFrame:Show()
  urlFrame:Raise()
  urlFrame._box:SetFocus()
end

-- ================================================================
-- TOAST (confirmation courte, auto-disparait) - inspire du "toast" d'ElvUI
-- apres une action appliquee (installation terminee, module bascule...).
-- Pure UI, aucun element partage avec Blizzard.
-- ================================================================
local toastFrame
function TibiSuite.ShowToast(text)
  if not toastFrame then
    toastFrame = CreateFrame("Frame", "TibiSuiteToastFrame", UIParent, "BackdropTemplate")
    toastFrame:SetSize(360, 40)
    toastFrame:SetPoint("TOP", UIParent, "TOP", 0, -140)
    toastFrame:SetFrameStrata("TOOLTIP")
    toastFrame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
    })
    toastFrame:SetBackdropColor(0.06, 0.07, 0.09, 0.95)
    toastFrame:SetBackdropBorderColor(0.769, 0.122, 0.231, 1)
    toastFrame:Hide()

    local msg = toastFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    msg:SetPoint("CENTER")
    msg:SetWidth(340)
    msg:SetJustifyH("CENTER")
    toastFrame._msg = msg

    local ag = toastFrame:CreateAnimationGroup()
    local fadeIn = ag:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0); fadeIn:SetToAlpha(1); fadeIn:SetDuration(0.2); fadeIn:SetOrder(1)
    local hold = ag:CreateAnimation("Alpha")
    hold:SetFromAlpha(1); hold:SetToAlpha(1); hold:SetDuration(2.0); hold:SetOrder(2)
    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0); fadeOut:SetDuration(0.6); fadeOut:SetOrder(3)
    ag:SetScript("OnFinished", function() toastFrame:Hide() end)
    toastFrame._anim = ag
  end

  toastFrame._msg:SetText(text or "")
  toastFrame:SetAlpha(0)
  toastFrame:Show()
  toastFrame._anim:Stop()
  toastFrame._anim:Play()
end

-- Convertit r,g,b [0-1] en code couleur WoW pour teinter le libelle.
local function Hex(c)
  return string.format("|cFF%02X%02X%02X",
    math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
end

-- Toast adapte au resultat de TibiSuite.SetModuleEnabled.
local function ToastModuleStatus(mod, status)
  local name = Hex(mod.col) .. mod.addonName .. "|r "
  if status == "loaded" then TibiSuite.ShowToast(name .. L.TOAST_ENABLED_FMT)
  elseif status == "reload" then TibiSuite.ShowToast(name .. L.TOAST_ENABLED_RELOAD)
  elseif status == "off" then TibiSuite.ShowToast(name .. L.TOAST_DISABLED_FMT) end
end

local function Build()
  local UI = _G.TibiMidnight
  if not UI or not UI.CreateOptionsPanel then return nil end
  if panel then return panel end

  panel = UI.CreateOptionsPanel({
    name  = "TibiSuiteModulesPanel",
    title = L.PANEL_TITLE,
    accent = ACCENT_SUITE,
    logo  = LOGO,
  })

  panel:Section(L.SEC_MODULES)
  panel:Note(L.NOTE_MODULES)

  local catalog = (TibiSuite.GetCatalog and TibiSuite.GetCatalog()) or {}
  for _, mod in ipairs(catalog) do
    local key     = mod.key
    local present = TibiSuite.ModuleExists and TibiSuite.ModuleExists(mod.addonName)
    local label   = Hex(mod.col) .. (mod.addonName or mod.label) .. "|r"
    if not present then
      label = label .. L.LBL_ABSENT
    end
    panel:Check(
      label,
      function() return TibiSuite.IsModuleEnabled and TibiSuite.IsModuleEnabled(key) end,
      function(v)
        local status = TibiSuite.SetModuleEnabled and TibiSuite.SetModuleEnabled(key, v)
        ToastModuleStatus(mod, status)
      end,
      present and (L.CHECK_TOOLTIP_ON .. mod.addonName)
              or (mod.addonName .. L.CHECK_TOOLTIP_OFF)
    )
  end

  panel:Section(L.SEC_TIP)
  panel:Note(L.NOTE_TIP)

  -- ── Installation et profil ─────────────────────────────────────
  panel:Section(L.SEC_SETUP)
  panel:Note(L.NOTE_SETUP)
  panel:Button(L.BTN_RUN_SETUP, function() if TibiSuite.RunSetup then TibiSuite.RunSetup() end end)
  panel:Button(L.BTN_WHATSNEW,  function() if TibiSuite.ShowWhatsNew then TibiSuite.ShowWhatsNew(true) end end)
  panel:Button(L.BTN_PROFILE,   function() if TibiSuite.OpenProfileWindow then TibiSuite.OpenProfileWindow() end end)

  -- ── Reinstallation : un bouton par module present ──────────────
  panel:Section(L.SEC_REINSTALL_MOD)
  panel:Note(L.NOTE_REINSTALL_MOD)
  for _, mod in ipairs(catalog) do
    local present = TibiSuite.ModuleExists and TibiSuite.ModuleExists(mod.addonName)
    if present then
      local addon = mod.addonName
      local key   = mod.key
      panel:Button(
        L.BTN_REINSTALL .. Hex(mod.col) .. addon .. "|r",
        function()
          ShowConfirm(
            L.CONFIRM_REINSTALL_MOD_FMT1 .. addon .. L.CONFIRM_REINSTALL_MOD_FMT2,
            function() if TibiSuite.ReinstallModule then TibiSuite.ReinstallModule(key) end end
          )
        end
      )
    end
  end

  -- Reinstallation de la suite elle-meme (reglages du core), progression conservee.
  panel:Section(L.SEC_REINSTALL_SUITE)
  panel:Note(L.NOTE_REINSTALL_SUITE)
  panel:Button(
    L.BTN_REINSTALL_SUITE,
    function()
      ShowConfirm(L.CONFIRM_REINSTALL_CORE,
        function() if TibiSuite.ReinstallCore then TibiSuite.ReinstallCore() end end
      )
    end
  )

  -- ── Dashboard web (module Stats) ─────────────────────────────────
  panel:Section(L.SEC_DASHBOARD)
  panel:Note(L.NOTE_DASHBOARD)
  if panel.SelectableText then
    panel:SelectableText(L.DASHBOARD_URL_LABEL, URL_DASHBOARD)
  else
    panel:Note(URL_DASHBOARD)
  end
  panel:Button(L.BTN_GENERATE_EXPORT, function()
    if _G.Stats and _G.Stats.ShowExportPopup then
      _G.Stats.ShowExportPopup()
    else
      TibiSuite.ShowToast(L.TOAST_NEED_STATS)
    end
  end)
  panel:Note(L.NOTE_DASHBOARD_PRIVACY)

  return panel
end

-- API publique : ouvrir / fermer le panneau des modules.
function TibiSuite.OpenModulePanel()
  local p = Build()
  if p then p:Toggle() end
end

-- ================================================================
-- BRIQUES D'INTERFACE COMMUNES (installateur, Quoi de neuf, profils)
-- ================================================================
local COL = {
  CARD  = { 0.082, 0.090, 0.118 },
  CARD2 = { 0.106, 0.118, 0.153 },
  TXT   = { 0.925, 0.918, 0.902 },
  MUT   = { 0.627, 0.620, 0.651 },
  DIM   = { 0.384, 0.380, 0.420 },
  ACC   = ACCENT_SUITE,
  ACCHI = { 0.886, 0.204, 0.322 },
  GOLD  = { 1.000, 0.820, 0.000 },
  OK    = { 0.310, 0.820, 0.420 },
  WARN  = { 1.000, 0.604, 0.235 },
}
local HX = {
  TXT = "|cFFECEAE6", MUT = "|cFFA09EA6", DIM = "|cFF62616B", ACC = "|cFFE23452",
  GOLD = "|cFFFFD100", OK = "|cFF4FD16B", WARN = "|cFFFF9A3C",
}
local ICON_OK   = "|TInterface\\RaidFrame\\ReadyCheck-Ready:13:13|t"
local ICON_FAIL = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:13:13|t"
local ICON_WAIT = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:13:13|t"

local FLAT = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

local function Card(parent, col)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetBackdrop(FLAT)
  local c = col or COL.CARD
  f:SetBackdropColor(c[1], c[2], c[3], 0.97)
  f:SetBackdropBorderColor(0, 0, 0, 1)
  return f
end

local function Text(parent, font, text, col, width)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  if col then fs:SetTextColor(col[1], col[2], col[3]) end
  if width then fs:SetWidth(width); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true) end
  fs:SetText(text or "")
  return fs
end

-- Libelle de section en capitales (encode deja en majuscules dans L).
local function Label(parent, text)
  local fs = Text(parent, "GameFontNormalSmall", text, COL.DIM)
  fs:SetJustifyH("LEFT")
  return fs
end

-- Bouton plat ; kind = "pri" (rouge plein) | "ghost" (sans bordure) | nil.
local function Btn(parent, w, h, text, kind)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h)
  b:SetBackdrop(FLAT)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("CENTER")
  fs:SetText(text or "")
  b._label = fs
  local function paint(hover)
    if kind == "pri" then
      local c = hover and COL.ACCHI or COL.ACC
      b:SetBackdropColor(c[1], c[2], c[3], 1)
      b:SetBackdropBorderColor(COL.ACCHI[1], COL.ACCHI[2], COL.ACCHI[3], 1)
    elseif kind == "ghost" then
      b:SetBackdropColor(1, 1, 1, hover and 0.06 or 0)
      b:SetBackdropBorderColor(0, 0, 0, 0)
      fs:SetTextColor(hover and COL.TXT[1] or COL.MUT[1], hover and COL.TXT[2] or COL.MUT[2], hover and COL.TXT[3] or COL.MUT[3])
    else
      b:SetBackdropColor(1, 1, 1, hover and 0.10 or 0.05)
      b:SetBackdropBorderColor(1, 1, 1, hover and 0.30 or 0.18)
    end
  end
  paint(false)
  b:SetScript("OnEnter", function() paint(true) end)
  b:SetScript("OnLeave", function() paint(false) end)
  return b
end

-- Interrupteur on/off (rail + pastille).
local function makeSwitch(parent, col)
  local sw = CreateFrame("Button", nil, parent)
  sw:SetSize(36, 18)
  local track = sw:CreateTexture(nil, "BACKGROUND"); track:SetAllPoints()
  local knob = sw:CreateTexture(nil, "OVERLAY"); knob:SetSize(14, 14)
  sw._set = function(on)
    knob:ClearAllPoints()
    if on then
      track:SetColorTexture(col[1] * 0.55, col[2] * 0.55, col[3] * 0.55, 1)
      knob:SetPoint("RIGHT", -2, 0); knob:SetColorTexture(1, 1, 1, 1)
    else
      track:SetColorTexture(0.14, 0.145, 0.176, 1)
      knob:SetPoint("LEFT", 2, 0); knob:SetColorTexture(0.42, 0.41, 0.45, 1)
    end
  end
  return sw
end

-- Interrupteur + libelle cliquables ensemble.
local function Toggle(parent, label, get, set, col)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(250, 20)
  local sw = makeSwitch(b, col or COL.ACC)
  sw:SetPoint("LEFT", 0, 0)
  sw:EnableMouse(false)
  local t = Text(b, "GameFontHighlight", label, COL.TXT)
  t:SetPoint("LEFT", sw, "RIGHT", 10, 0)
  function b.Refresh() sw._set(get() and true or false) end
  b:SetScript("OnClick", function() set(not get()); b.Refresh() end)
  b.Refresh()
  return b
end

-- Controle segmente : opts = { {valeur, libelle}, ... }.
local function Segmented(parent, w, opts, get, set)
  local f = Card(parent)
  f:SetSize(w, 22)
  local bw = w / #opts
  f.btns = {}
  for i, o in ipairs(opts) do
    local b = CreateFrame("Button", nil, f)
    b:SetSize(bw, 22)
    b:SetPoint("LEFT", (i - 1) * bw, 0)
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetPoint("TOPLEFT", 1, -1); b.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    b.line = b:CreateTexture(nil, "ARTWORK"); b.line:SetHeight(2)
    b.line:SetPoint("BOTTOMLEFT", 1, 1); b.line:SetPoint("BOTTOMRIGHT", -1, 1)
    b.line:SetColorTexture(COL.ACC[1], COL.ACC[2], COL.ACC[3], 1)
    b.t = Text(b, "GameFontHighlightSmall", o[2]); b.t:SetPoint("CENTER")
    b:SetScript("OnClick", function() set(o[1]); f.Refresh() end)
    f.btns[i] = b
  end
  function f.Refresh()
    for i, o in ipairs(opts) do
      local b, on = f.btns[i], (get() == o[1])
      b.bg:SetColorTexture(COL.ACC[1], COL.ACC[2], COL.ACC[3], on and 0.25 or 0)
      b.line:SetShown(on)
      local c = on and COL.TXT or COL.MUT
      b.t:SetTextColor(c[1], c[2], c[3])
    end
  end
  f.Refresh()
  return f
end

-- Place des cadres de largeur connue en lignes qui passent a la ligne.
local function Flow(items, width, gap, rowH)
  local x, y = 0, 0
  for _, it in ipairs(items) do
    local w = it:GetWidth()
    if x > 0 and x + w > width then x = 0; y = y - rowH - gap end
    it:ClearAllPoints()
    it:SetPoint("TOPLEFT", x, y)
    x = x + w + gap
  end
  return (#items > 0) and (-y + rowH) or 0
end

-- Pastille : fond de carte + texte (+ icone et liseré gauche optionnels).
local function Chip(parent, text, opts)
  opts = opts or {}
  local f = Card(parent)
  local x = 8
  if opts.bar then
    local bar = f:CreateTexture(nil, "OVERLAY")
    bar:SetPoint("TOPLEFT", 0, 0); bar:SetPoint("BOTTOMLEFT", 0, 0); bar:SetWidth(3)
    bar:SetColorTexture(opts.bar[1], opts.bar[2], opts.bar[3], 1)
  end
  if opts.icon then
    local ic = f:CreateTexture(nil, "ARTWORK")
    ic:SetSize(16, 16); ic:SetPoint("LEFT", 4, 0); ic:SetTexture(opts.icon)
    x = 24
  end
  local fs = Text(f, opts.font or "GameFontHighlightSmall", text)
  if opts.col then fs:SetTextColor(opts.col[1], opts.col[2], opts.col[3]) end
  fs:SetPoint("LEFT", x, 0)
  f:SetSize((fs:GetStringWidth() or 40) + x + 10, opts.h or 22)
  return f
end

-- Fondu a l'apparition (panneaux de l'installateur, fenetres).
local function AddFadeIn(frame, duration)
  local ag = frame:CreateAnimationGroup()
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(duration or 0.18)
  frame:HookScript("OnShow", function() ag:Stop(); ag:Play() end)
end

local function colOf(m) return m.col or { r = 0.6, g = 0.6, b = 0.6 } end
local function rgb(m) local c = colOf(m); return { c.r, c.g, c.b } end
local function logoOf(key) return MODULE_LOGO[key] or LOGO end

local function PatchLabels()
  local version, _, _, toc = GetBuildInfo()
  return tostring(version or "?"), tostring(toc or "?"), tonumber(toc) or 0
end

-- ================================================================
-- INSTALLATEUR (6 etapes)
-- ----------------------------------------------------------------
-- Premier lancement (TibiSuiteDB.setupDone absent) ou /ts setup. Rien n'est
-- ecrit avant « Installer et démarrer » (ou la croix, qui termine avec la
-- selection en cours : jamais d'etat bloque). L'etape 6 applique les choix
-- pour de vrai, module par module, et affiche le resultat reel de chacun
-- (actif, a charger au /reload, decoche, echec).
-- ================================================================
local W     -- etat + widgets de l'installateur (construit une seule fois)
local STEP_NAMES = { L.WIZ_STEP1, L.WIZ_STEP2, L.WIZ_STEP3, L.WIZ_STEP4, L.WIZ_STEP5, L.WIZ_STEP6 }
local FW, FH = 780, 600          -- taille de la fenetre
local BODY_W = FW - 36           -- largeur utile des panneaux

local function BuildWizard()
  local UI = _G.TibiMidnight
  if not UI then return nil end
  if W then return W end

  W = { step = 0, present = {}, choice = {}, cfg = {}, panes = {}, preset = "all" }
  TibiSuite._wizard = W   -- acces de diagnostic (/dump TibiSuite._wizard.step)

  -- ----- Fenetre -----
  local f = CreateFrame("Frame", "TibiSuiteSetupWizard", UIParent, "BackdropTemplate")
  f:SetSize(FW, FH)
  f:SetPoint("CENTER", 0, 20)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  UI.SkinFrame(f, ACCENT_SUITE, UI.C.PANEL)
  f:Hide()
  AddFadeIn(f, 0.25)
  W.frame = f

  -- ----- En-tete -----
  local logo = f:CreateTexture(nil, "OVERLAY")
  logo:SetSize(42, 42); logo:SetPoint("TOPLEFT", 18, -14); logo:SetTexture(LOGO)
  local title = Text(f, "GameFontNormalLarge", "TibiSuite", COL.ACCHI)
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -4)
  local sub = Text(f, "GameFontHighlightSmall", "", COL.MUT)
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
  W.sub = sub

  local closeB = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  closeB:SetPoint("TOPRIGHT", 2, 2)
  closeB:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_LEFT"); GameTooltip:AddLine(L.WIZ_CLOSE_TT, 0.9, 0.9, 0.9); GameTooltip:Show()
  end)
  closeB:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- ----- Etapes (numerotees : c'est une vraie sequence) -----
  W.steps = {}
  local segW = (BODY_W - 5 * 4) / 6
  for i = 1, 6 do
    -- Textures simples plutot qu'un backdrop : CONFIRME EN JEU, la premiere
    -- couleur posee par SetBackdropColor juste apres l'affichage perdait sa
    -- transparence (onglets blancs / rouge plein jusqu'au premier clic).
    local seg = CreateFrame("Button", nil, f)
    seg:SetSize(segW, 26)
    seg:SetPoint("TOPLEFT", 18 + (i - 1) * (segW + 4), -66)
    local edge = seg:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetAllPoints()
    local fill = seg:CreateTexture(nil, "BACKGROUND", nil, 2)
    fill:SetPoint("TOPLEFT", 1, -1); fill:SetPoint("BOTTOMRIGHT", -1, 1)
    local num = seg:CreateTexture(nil, "ARTWORK")
    num:SetSize(18, 18); num:SetPoint("LEFT", 5, 0)
    local numT = Text(seg, "GameFontNormalSmall", tostring(i)); numT:SetPoint("CENTER", num, "CENTER")
    local lbl = Text(seg, "GameFontHighlightSmall", STEP_NAMES[i]); lbl:SetPoint("LEFT", num, "RIGHT", 6, 0)
    seg:SetScript("OnClick", function() if W.step < 5 and i <= 5 then W.goStep(i - 1) end end)
    W.steps[i] = { frame = seg, edge = edge, fill = fill, num = num, numT = numT, lbl = lbl }
  end

  local progBG = f:CreateTexture(nil, "ARTWORK")
  progBG:SetPoint("TOPLEFT", 18, -96); progBG:SetSize(BODY_W, 3)
  progBG:SetColorTexture(0.11, 0.118, 0.145, 1)
  local prog = CreateFrame("StatusBar", nil, f)
  prog:SetPoint("TOPLEFT", progBG, "TOPLEFT"); prog:SetSize(BODY_W, 3)
  prog:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  prog:SetStatusBarColor(COL.ACCHI[1], COL.ACCHI[2], COL.ACCHI[3], 1)
  prog:SetMinMaxValues(0, 5)
  W.prog = prog

  local sep = f:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(1, 1, 1, 0.10)
  sep:SetPoint("TOPLEFT", 1, -108); sep:SetPoint("TOPRIGHT", -1, -108); sep:SetHeight(1)

  local function NewPane(i)
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", 18, -122); p:SetPoint("BOTTOMRIGHT", -18, 58)
    p:Hide()
    AddFadeIn(p)
    W.panes[i] = p
    return p
  end

  -- ===================== 1. BIENVENUE =====================
  do
    local p = NewPane(0)
    local emb = p:CreateTexture(nil, "ARTWORK")
    emb:SetSize(96, 96); emb:SetPoint("TOPLEFT", 6, -4); emb:SetTexture(LOGO)
    -- Halo rouge qui « respire » : le logo lui-meme, en fusion additive.
    local glow = p:CreateTexture(nil, "BACKGROUND")
    glow:SetSize(150, 150); glow:SetPoint("CENTER", emb, "CENTER"); glow:SetTexture(LOGO)
    glow:SetBlendMode("ADD"); glow:SetVertexColor(COL.ACC[1], COL.ACC[2], COL.ACC[3], 1)
    local ag = glow:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0.15); a:SetToAlpha(0.55); a:SetDuration(1.6)
    a:SetSmoothing("IN_OUT")
    p:HookScript("OnShow", function() ag:Play() end)
    p:HookScript("OnHide", function() ag:Stop() end)

    local h = Text(p, "GameFontNormalHuge", L.WIZ_HERO_TITLE, COL.TXT)
    h:SetPoint("TOPLEFT", emb, "TOPRIGHT", 22, -18)
    local intro = Text(p, "GameFontHighlight", L.INTRO, COL.MUT, BODY_W - 140)
    intro:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -8)

    local pills = CreateFrame("Frame", nil, p)
    pills:SetPoint("TOPLEFT", 6, -122); pills:SetSize(BODY_W - 12, 24)
    W.pillsHost = pills

    local cw = (BODY_W - 12 - 2 * 10) / 3
    local function Choice(i, tag, tagCol, ttl, desc, onClick)
      local c = CreateFrame("Button", nil, p, "BackdropTemplate")
      c:SetSize(cw, 118)
      c:SetPoint("TOPLEFT", 6 + (i - 1) * (cw + 10), -160)
      c:SetBackdrop(FLAT)
      c:SetBackdropColor(COL.CARD[1], COL.CARD[2], COL.CARD[3], 0.97)
      c:SetBackdropBorderColor(0, 0, 0, 1)
      local tg = Text(c, "GameFontNormalSmall", tag, tagCol); tg:SetPoint("TOPLEFT", 14, -14)
      local t = Text(c, "GameFontNormalLarge", ttl, (i == 1) and COL.ACCHI or COL.TXT)
      t:SetPoint("TOPLEFT", tg, "BOTTOMLEFT", 0, -6)
      local d = Text(c, "GameFontHighlightSmall", desc, COL.MUT, cw - 28)
      d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
      c:SetScript("OnEnter", function(s)
        s:SetBackdropColor(COL.CARD2[1], COL.CARD2[2], COL.CARD2[3], 0.97)
        s:SetBackdropBorderColor(COL.ACC[1], COL.ACC[2], COL.ACC[3], 0.8)
      end)
      c:SetScript("OnLeave", function(s)
        s:SetBackdropColor(COL.CARD[1], COL.CARD[2], COL.CARD[3], 0.97)
        s:SetBackdropBorderColor(0, 0, 0, 1)
      end)
      c:SetScript("OnClick", onClick)
    end

    local imp = Card(p)
    imp:SetPoint("TOPLEFT", 6, -290); imp:SetSize(BODY_W - 12, 76)
    imp:Hide()
    local impL = Text(imp, "GameFontHighlightSmall", L.WIZ_IMPORT_LABEL, COL.MUT); impL:SetPoint("TOPLEFT", 12, -10)
    local eb = CreateFrame("EditBox", nil, imp, "InputBoxTemplate")
    eb:SetSize(BODY_W - 200, 24); eb:SetPoint("TOPLEFT", 18, -28)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    local impGo = Btn(imp, 150, 24, L.WIZ_IMPORT_APPLY, "pri")
    impGo:SetPoint("LEFT", eb, "RIGHT", 10, 0)
    local impMsg = Text(imp, "GameFontHighlightSmall", "", COL.WARN)
    impMsg:SetPoint("TOPLEFT", 12, -58)
    impGo:SetScript("OnClick", function()
      local prof, err = TibiSuite.DecodeProfile and TibiSuite.DecodeProfile(eb:GetText())
      if not prof then
        impMsg:SetTextColor(COL.WARN[1], COL.WARN[2], COL.WARN[3])
        impMsg:SetText(L["PROFILE_ERR_" .. tostring(err)] or L.PROFILE_ERR_format)
        return
      end
      W.importProf = prof
      W.choice = {}
      for _, m in ipairs(W.present) do if prof.mods[m.key] then W.choice[m.key] = true end end
      W.preset = nil
      local c = W.cfg
      c.vertical = prof.vertical
      c.scale = math.floor(prof.scale * 100 + 0.5)
      c.cols, c.rows = prof.cols, prof.rows
      c.mm, c.msg, c.exp = not prof.mmHidden, prof.loginMsg, prof.autoExport
      impMsg:SetTextColor(COL.OK[1], COL.OK[2], COL.OK[3])
      impMsg:SetText(L.WIZ_IMPORT_OK)
      W.goStep(4)
    end)

    Choice(1, L.WIZ_EXPRESS_TAG, COL.GOLD, L.WIZ_EXPRESS_TITLE, L.WIZ_EXPRESS_DESC, function()
      W.SetPreset("all"); W.goStep(4)
    end)
    Choice(2, L.WIZ_CUSTOM_TAG, COL.DIM, L.WIZ_CUSTOM_TITLE, L.WIZ_CUSTOM_DESC, function() W.goStep(1) end)
    Choice(3, L.WIZ_IMPORT_TAG, COL.DIM, L.WIZ_IMPORT_TITLE, L.WIZ_IMPORT_DESC, function()
      imp:SetShown(not imp:IsShown())
      if imp:IsShown() then eb:SetFocus() end
    end)
  end

  -- ===================== 2. MODULES =====================
  do
    local p = NewPane(1)
    local pl = Label(p, L.WIZ_PRESETS); pl:SetPoint("TOPLEFT", 2, -6)
    W.presetBtns = {}
    local prev = pl
    for _, pr in ipairs(PRESETS) do
      local b = Btn(p, 0, 22, pr.label)
      b:SetWidth(b._label:GetStringWidth() + 22)
      b:SetPoint("LEFT", prev, "RIGHT", (prev == pl) and 10 or 6, 0)
      b:SetScript("OnClick", function() W.SetPreset(pr.id); W.RefreshCards() end)
      b._id = pr.id
      -- Selection : textures (voir le piege SetBackdropColor des onglets d'etape).
      b._sel = b:CreateTexture(nil, "BORDER")
      b._sel:SetPoint("TOPLEFT", 1, -1); b._sel:SetPoint("BOTTOMRIGHT", -1, 1)
      b._sel:SetColorTexture(0.29, 0.086, 0.122, 1)
      b._selLine = b:CreateTexture(nil, "ARTWORK")
      b._selLine:SetHeight(2); b._selLine:SetPoint("BOTTOMLEFT", 1, 1); b._selLine:SetPoint("BOTTOMRIGHT", -1, 1)
      b._selLine:SetColorTexture(COL.ACCHI[1], COL.ACCHI[2], COL.ACCHI[3], 1)
      W.presetBtns[#W.presetBtns + 1] = b
      prev = b
    end
    local counter = Text(p, "GameFontHighlight", "", COL.MUT)
    counter:SetPoint("TOPRIGHT", -4, -6)
    W.counter = counter

    local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -34); scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(BODY_W - 26, 10)
    scroll:SetScrollChild(content)
    W.cardsHost = content
    W.cards = {}
  end

  -- ===================== 3. BARRE ET MINICARTE =====================
  do
    local p = NewPane(2)
    local c = W.cfg
    local y = 0
    local function lab(t) local l = Label(p, t); l:SetPoint("TOPLEFT", 0, y); y = y - 16; return l end

    lab(L.WIZ_ORIENT)
    local ori = Segmented(p, 240, { { false, L.WIZ_HORIZ }, { true, L.WIZ_VERT } },
      function() return c.vertical end, function(v) c.vertical = v; W.RenderPreview() end)
    ori:SetPoint("TOPLEFT", 0, y); y = y - 34

    lab(L.WIZ_SCALE)
    local sl = CreateFrame("Slider", nil, p, "BackdropTemplate")
    sl:SetOrientation("HORIZONTAL"); sl:SetSize(186, 12); sl:SetPoint("TOPLEFT", 0, y - 4)
    sl:SetBackdrop(FLAT); sl:SetBackdropColor(0.14, 0.145, 0.176, 1); sl:SetBackdropBorderColor(0, 0, 0, 1)
    sl:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local th = sl:GetThumbTexture(); th:SetSize(8, 18); th:SetColorTexture(COL.ACCHI[1], COL.ACCHI[2], COL.ACCHI[3], 1)
    sl:SetMinMaxValues(70, 150); sl:SetValueStep(5); sl:SetObeyStepOnDrag(true)
    local slV = Text(p, "GameFontHighlight", "", COL.GOLD); slV:SetPoint("LEFT", sl, "RIGHT", 12, 0)
    sl:SetScript("OnValueChanged", function(_, v)
      v = math.floor(v / 5 + 0.5) * 5
      c.scale = v; slV:SetText(v .. " %"); W.RenderPreview()
    end)
    y = y - 32

    lab(L.WIZ_GRID)
    local function stepper(x, fmt, get, set)
      local box = Card(p); box:SetSize(116, 24); box:SetPoint("TOPLEFT", x, y)
      local minus = Btn(box, 24, 22, "-", "ghost"); minus:SetPoint("LEFT", 1, 0)
      local plus = Btn(box, 24, 22, "+", "ghost"); plus:SetPoint("RIGHT", -1, 0)
      local v = Text(box, "GameFontHighlight", "", COL.TXT); v:SetPoint("CENTER")
      local function upd() v:SetText(string.format(fmt, get())) end
      minus:SetScript("OnClick", function() set(get() - 1); upd(); W.RenderPreview() end)
      plus:SetScript("OnClick",  function() set(get() + 1); upd(); W.RenderPreview() end)
      box.Refresh = upd
      return box
    end
    local sc = stepper(0, L.WIZ_COLS_FMT, function() return c.cols end,
      function(n) c.cols = math.max(1, math.min(8, n)) end)
    local sr = stepper(124, L.WIZ_ROWS_FMT, function() return c.rows end,
      function(n) c.rows = math.max(1, math.min(14, n)) end)
    y = y - 38

    lab(L.WIZ_CORNER)
    W.cornerBtns = {}
    for i = 1, 9 do
      local b = CreateFrame("Button", nil, p, "BackdropTemplate")
      b:SetSize(40, 16)
      b:SetPoint("TOPLEFT", ((i - 1) % 3) * 44, y - math.floor((i - 1) / 3) * 20)
      b:SetBackdrop(FLAT); b:SetBackdropBorderColor(0, 0, 0, 1)
      b:SetScript("OnClick", function() c.corner = i; W.RefreshCorners(); W.RenderPreview() end)
      b:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:AddLine(L.WIZ_CORNERS[i], 0.9, 0.9, 0.9); GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      W.cornerBtns[i] = b
    end
    function W.RefreshCorners()
      for i, b in ipairs(W.cornerBtns) do
        if c.corner == i then b:SetBackdropColor(COL.ACC[1], COL.ACC[2], COL.ACC[3], 1)
        else b:SetBackdropColor(COL.CARD[1], COL.CARD[2], COL.CARD[3], 1) end
      end
    end
    y = y - 68

    local tMM = Toggle(p, L.WIZ_MM, function() return c.mm end, function(v) c.mm = v; W.RenderPreview() end)
    tMM:SetPoint("TOPLEFT", 0, y); y = y - 26
    local tOpen = Toggle(p, L.WIZ_OPEN, function() return c.open end, function(v) c.open = v; W.RenderPreview() end)
    tOpen:SetPoint("TOPLEFT", 0, y); y = y - 34

    lab(L.WIZ_MSG)
    local msg = Segmented(p, 240, { { "full", L.WIZ_MSG_FULL }, { "one", L.WIZ_MSG_ONE }, { "none", L.WIZ_MSG_NONE } },
      function() return c.msg end, function(v) c.msg = v end)
    msg:SetPoint("TOPLEFT", 0, y)

    W.RefreshIfc = function()
      ori.Refresh(); msg.Refresh(); sc.Refresh(); sr.Refresh(); tMM.Refresh(); tOpen.Refresh()
      sl:SetValue(c.scale); slV:SetText(c.scale .. " %")
      W.RefreshCorners()
    end

    -- ----- Apercu en direct -----
    local PW, PH = 458, 286
    local pv = Card(p, { 0.055, 0.067, 0.075 })
    pv:SetSize(PW, PH); pv:SetPoint("TOPRIGHT", 0, 0)
    local sky = pv:CreateTexture(nil, "BACKGROUND", nil, 1)
    sky:SetPoint("TOPLEFT", 1, -1); sky:SetPoint("BOTTOMRIGHT", -1, 1)
    sky:SetColorTexture(1, 1, 1, 1)
    if sky.SetGradient and CreateColor then
      sky:SetGradient("VERTICAL", CreateColor(0.035, 0.043, 0.055, 1), CreateColor(0.09, 0.118, 0.125, 1))
    else
      sky:SetColorTexture(0.07, 0.085, 0.095, 1)
    end
    -- Minicarte : disque (masque circulaire Blizzard) + bouton TibiSuite.
    local mmRing = pv:CreateTexture(nil, "ARTWORK", nil, 1)
    mmRing:SetSize(58, 58); mmRing:SetPoint("TOPRIGHT", -8, -8)
    mmRing:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask"); mmRing:SetVertexColor(0.23, 0.2, 0.13, 1)
    local mmDisc = pv:CreateTexture(nil, "ARTWORK", nil, 2)
    mmDisc:SetSize(52, 52); mmDisc:SetPoint("CENTER", mmRing, "CENTER")
    mmDisc:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask"); mmDisc:SetVertexColor(0.15, 0.22, 0.16, 1)
    local mmBtn = pv:CreateTexture(nil, "ARTWORK", nil, 3)
    mmBtn:SetSize(18, 18); mmBtn:SetPoint("CENTER", mmRing, "CENTER", -27, -10); mmBtn:SetTexture(LOGO)
    local mmMask = pv:CreateMaskTexture()
    mmMask:SetAllPoints(mmBtn)
    mmMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mmBtn:AddMaskTexture(mmMask)
    local cap = Text(pv, "GameFontHighlightSmall", L.WIZ_PREVIEW_CAP, COL.DIM)
    cap:SetPoint("BOTTOMLEFT", 8, 6)

    -- Mini-barre : en-tete (logo + nom) + grille d'onglets des modules coches.
    local bar = CreateFrame("Frame", nil, pv, "BackdropTemplate")
    bar:SetBackdrop(FLAT); bar:SetBackdropColor(0.055, 0.063, 0.082, 0.97); bar:SetBackdropBorderColor(0, 0, 0, 1)
    local lis = bar:CreateTexture(nil, "OVERLAY"); lis:SetHeight(1)
    lis:SetPoint("TOPLEFT", 1, -1); lis:SetPoint("TOPRIGHT", -1, -1); lis:SetColorTexture(COL.ACC[1], COL.ACC[2], COL.ACC[3], 1)
    local head = CreateFrame("Frame", nil, bar)
    local hLogo = head:CreateTexture(nil, "ARTWORK"); hLogo:SetSize(12, 12); hLogo:SetTexture(LOGO)
    local hTxt = Text(head, "GameFontHighlightSmall", "TibiSuite", COL.ACCHI)
    hTxt:SetFont(STANDARD_TEXT_FONT, 8, "")
    local cells = {}
    local CW, CH, CG = 44, 13, 2
    local function cell(i)
      if cells[i] then return cells[i] end
      local cf = CreateFrame("Frame", nil, bar, "BackdropTemplate")
      cf:SetSize(CW, CH); cf:SetBackdrop(FLAT)
      cf.line = cf:CreateTexture(nil, "OVERLAY"); cf.line:SetHeight(2)
      cf.line:SetPoint("BOTTOMLEFT", 1, 1); cf.line:SetPoint("BOTTOMRIGHT", -1, 1)
      cf.t = cf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      cf.t:SetFont(STANDARD_TEXT_FONT, 6, ""); cf.t:SetPoint("CENTER", 0, 1); cf.t:SetWidth(CW - 2)
      cf.t:SetWordWrap(false)
      cells[i] = cf
      return cf
    end

    function W.RenderPreview()
      local active = {}
      for _, m in ipairs(W.present) do if W.choice[m.key] then active[#active + 1] = m end end
      local n = #active
      local cols = math.max(1, c.cols)
      local rows = math.max(c.rows, math.ceil(n / cols))
      local total = cols * rows
      local gridW = cols * CW + (cols - 1) * CG
      local gridH = rows * CH + (rows - 1) * CG
      for i = 1, math.max(total, #cells) do
        local cf = (i <= total) and cell(i) or cells[i]
        if cf then
          if i <= total then
            local m = active[i]
            cf:ClearAllPoints()
            local cc, rr = (i - 1) % cols, math.floor((i - 1) / cols)
            cf._x, cf._y = cc * (CW + CG), -rr * (CH + CG)
            if m then
              local col = colOf(m)
              cf:SetBackdropColor(0.09, 0.1, 0.13, 1); cf:SetBackdropBorderColor(0, 0, 0, 1)
              cf.line:SetColorTexture(col.r, col.g, col.b, 1); cf.line:Show()
              cf.t:SetText(m.label or m.addonName)
            else
              cf:SetBackdropColor(0, 0, 0, 0); cf:SetBackdropBorderColor(1, 1, 1, 0.07)
              cf.line:Hide(); cf.t:SetText("")
            end
            cf:Show()
          else
            cf:Hide()
          end
        end
      end
      head:ClearAllPoints(); hLogo:ClearAllPoints(); hTxt:ClearAllPoints()
      local bw, bh, gx, gy
      if not c.vertical then
        bw = math.max(gridW, 72) + 8
        bh = 4 + 14 + 3 + gridH + 4
        head:SetSize(bw - 8, 14); head:SetPoint("TOP", 0, -4)
        hTxt:SetPoint("CENTER", 7, 0); hLogo:SetPoint("RIGHT", hTxt, "LEFT", -3, 0)
        gx, gy = 4 + (bw - 8 - gridW) / 2, -21
      else
        bw = 4 + 46 + 4 + gridW + 4
        bh = math.max(gridH, 30) + 8
        head:SetSize(46, bh - 8); head:SetPoint("TOPLEFT", 4, -4)
        hLogo:SetPoint("TOP", 0, -2); hTxt:SetPoint("TOP", hLogo, "BOTTOM", 0, -2)
        gx, gy = 54, -4
      end
      for i = 1, total do
        local cf = cells[i]
        cf:SetPoint("TOPLEFT", bar, "TOPLEFT", gx + cf._x, gy + cf._y)
      end
      bar:SetSize(bw, bh)
      -- Echelle de la barre (95 % pour laisser voir la minicarte a 150 %).
      local k = (c.scale / 100) * 0.95
      bar:SetScale(k)
      local CORNERS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
      local pt = CORNERS[c.corner or 1] or "TOPLEFT"
      local dx = (pt:find("LEFT") and 8) or (pt:find("RIGHT") and -8) or 0
      local dy = (pt:find("TOP") and -8) or (pt:find("BOTTOM") and 22) or 0
      if pt == "TOPRIGHT" then dx = -74 end   -- laisse la minicarte libre
      bar:ClearAllPoints()
      bar:SetPoint(pt, pv, pt, dx / k, dy / k)
      bar:SetAlpha(c.open and 1 or 0.22)
      mmBtn:SetShown(c.mm)
    end
  end

  -- ===================== 4. ECOSYSTEME =====================
  do
    local p = NewPane(3)
    local LW = 420
    local dash = Card(p)
    dash:SetPoint("TOPLEFT", 0, 0); dash:SetSize(LW, 410)
    dash:SetBackdropBorderColor(COL.GOLD[1], COL.GOLD[2], COL.GOLD[3], 0.35)
    local gbar = dash:CreateTexture(nil, "OVERLAY")
    gbar:SetPoint("TOPLEFT", 0, 0); gbar:SetPoint("BOTTOMLEFT", 0, 0); gbar:SetWidth(3)
    gbar:SetColorTexture(COL.GOLD[1], COL.GOLD[2], COL.GOLD[3], 1)
    local dIc = dash:CreateTexture(nil, "ARTWORK"); dIc:SetSize(24, 24); dIc:SetPoint("TOPLEFT", 16, -14)
    dIc:SetTexture(logoOf("Stats"))
    local dT = Text(dash, "GameFontNormalLarge", L.WIZ_DASH_TITLE, COL.GOLD); dT:SetPoint("LEFT", dIc, "RIGHT", 8, 0)
    local dB = Chip(dash, "tibiscui.fr", { col = COL.MUT, h = 16 }); dB:SetPoint("LEFT", dT, "RIGHT", 10, 0)
    local dD = Text(dash, "GameFontHighlightSmall", L.WIZ_DASH_DESC, COL.MUT, LW - 34)
    dD:SetPoint("TOPLEFT", 16, -48)
    local tExp = Toggle(dash, L.WIZ_DASH_EXPORT, function() return W.cfg.exp end,
      function(v) W.cfg.exp = v end, COL.GOLD)
    tExp:SetPoint("TOPLEFT", 16, -104); tExp:SetWidth(LW - 32)
    W.tExp = tExp
    local fl = Text(dash, "GameFontHighlightSmall", L.WIZ_DASH_FEEDS, COL.DIM); fl:SetPoint("TOPLEFT", 16, -136)
    local feedsHost = CreateFrame("Frame", nil, dash)
    feedsHost:SetPoint("TOPLEFT", 16, -154); feedsHost:SetSize(LW - 32, 150)
    W.feedsHost = feedsHost
    local copyD = Btn(dash, 230, 26, L.WIZ_DASH_COPY)
    copyD:SetPoint("BOTTOMLEFT", 16, 16)
    copyD:SetScript("OnClick", function() ShowURL(URL_DASHBOARD) end)

    local RW = BODY_W - LW - 10
    local comp = Card(p)
    comp:SetPoint("TOPRIGHT", 0, 0); comp:SetSize(RW, 212)
    comp:SetBackdropBorderColor(COL.GOLD[1], COL.GOLD[2], COL.GOLD[3], 0.35)
    local cbar = comp:CreateTexture(nil, "OVERLAY")
    cbar:SetPoint("TOPLEFT", 0, 0); cbar:SetPoint("BOTTOMLEFT", 0, 0); cbar:SetWidth(3)
    cbar:SetColorTexture(COL.GOLD[1], COL.GOLD[2], COL.GOLD[3], 1)
    local cIc = comp:CreateTexture(nil, "ARTWORK"); cIc:SetSize(24, 24); cIc:SetPoint("TOPLEFT", 16, -14); cIc:SetTexture(LOGO)
    local cMask = comp:CreateMaskTexture(); cMask:SetAllPoints(cIc)
    cMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    cIc:AddMaskTexture(cMask)
    local cT = Text(comp, "GameFontNormalLarge", L.COMPANION_TITLE, COL.GOLD); cT:SetPoint("LEFT", cIc, "RIGHT", 8, 0)
    local cB = Chip(comp, L.COMPANION_BADGE, { col = COL.OK, h = 16 }); cB:SetPoint("LEFT", cT, "RIGHT", 10, 0)
    local ly = -52
    for _, line in ipairs({ L.COMPANION_LINE1, L.COMPANION_LINE2, L.COMPANION_LINE3 }) do
      local sq = comp:CreateTexture(nil, "ARTWORK"); sq:SetSize(5, 5); sq:SetPoint("TOPLEFT", 18, ly - 5)
      sq:SetColorTexture(COL.GOLD[1], COL.GOLD[2], COL.GOLD[3], 1)
      local t = Text(comp, "GameFontHighlightSmall", line, COL.TXT, RW - 50); t:SetPoint("TOPLEFT", 30, ly)
      ly = ly - math.max(18, (t:GetStringHeight() or 12) + 6)
    end
    local dl = Btn(comp, 140, 26, L.COMPANION_BTN, "pri"); dl:SetPoint("BOTTOMLEFT", 16, 16)
    dl:SetScript("OnClick", function() ShowURL(URL_COMPANION) end)
    local sn = Text(comp, "GameFontHighlightSmall", L.COMPANION_STORE_NOTE, COL.DIM, RW - 32)
    sn:SetPoint("BOTTOMLEFT", dl, "TOPLEFT", 0, 8)

    local com = Card(p)
    com:SetPoint("TOPRIGHT", comp, "BOTTOMRIGHT", 0, -10); com:SetSize(RW, 188)
    local mT = Text(com, "GameFontNormalLarge", L.WIZ_COMMUNITY, COL.TXT); mT:SetPoint("TOPLEFT", 16, -16)
    local mD = Text(com, "GameFontHighlightSmall", L.WIZ_COMMUNITY_DESC, COL.MUT, RW - 32); mD:SetPoint("TOPLEFT", 16, -42)
    local bx = 16
    for _, lk in ipairs({ { L.WIZ_SITE, URL_SITE }, { L.WIZ_CURSE, URL_CURSE }, { "Discord", URL_DISCORD } }) do
      local b = Btn(com, 0, 24, lk[1]); b:SetWidth(b._label:GetStringWidth() + 26)
      b:SetPoint("BOTTOMLEFT", bx, 16); bx = bx + b:GetWidth() + 8
      b:SetScript("OnClick", function() ShowURL(lk[2]) end)
    end
  end

  -- ===================== 5. RECAPITULATIF =====================
  do
    local p = NewPane(4)
    local t = Text(p, "GameFontNormalHuge", L.WIZ_RECAP_TITLE, COL.ACCHI); t:SetPoint("TOPLEFT", 2, -2)
    local s = Text(p, "GameFontHighlight", "", COL.MUT); s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
    W.recapSub = s
    local chips = CreateFrame("Frame", nil, p)
    chips:SetPoint("TOPLEFT", 2, -54); chips:SetSize(BODY_W - 4, 80)
    W.recapChips = chips
    local sum = Card(p)
    sum:SetSize(BODY_W - 4, 100)
    W.recapSum = sum
    W.sumRows = {}
    for i = 1, 4 do
      local k = Label(sum, ""); k:SetPoint("TOPLEFT", 14, -12 - (i - 1) * 21)
      local v = Text(sum, "GameFontHighlight", "", COL.TXT); v:SetPoint("TOPLEFT", 130, -12 - (i - 1) * 21)
      W.sumRows[i] = { k = k, v = v }
    end
    local note = Card(p); note:SetSize(BODY_W - 4, 40)
    note:SetBackdropColor(COL.WARN[1], COL.WARN[2], COL.WARN[3], 0.06)
    local nb = note:CreateTexture(nil, "OVERLAY"); nb:SetPoint("TOPLEFT"); nb:SetPoint("BOTTOMLEFT"); nb:SetWidth(2)
    nb:SetColorTexture(COL.WARN[1], COL.WARN[2], COL.WARN[3], 1)
    local nt = Text(note, "GameFontHighlightSmall", "", COL.MUT, BODY_W - 30); nt:SetPoint("LEFT", 12, 0)
    W.recapNote, W.recapNoteText = note, nt
    local reass = Text(p, "GameFontHighlightSmall",
      HX.ACC .. "+|r " .. L.WIZ_REASS1 .. "\n" .. HX.ACC .. "+|r " .. L.WIZ_REASS2 .. "\n" .. HX.ACC .. "+|r " .. L.WIZ_REASS3,
      COL.MUT, BODY_W - 10)
    reass:SetSpacing(4)
    W.recapReass = reass
  end

  -- ===================== 6. INSTALLATION =====================
  do
    local p = NewPane(5)
    local run = CreateFrame("Frame", nil, p); run:SetAllPoints()
    local t = Text(run, "GameFontNormalLarge", L.WIZ_RUNNING, COL.TXT); t:SetPoint("TOPLEFT", 2, -2)
    local pbBG = run:CreateTexture(nil, "ARTWORK"); pbBG:SetPoint("TOPLEFT", 2, -28); pbBG:SetSize(BODY_W - 4, 6)
    pbBG:SetColorTexture(0.11, 0.118, 0.145, 1)
    local pb = CreateFrame("StatusBar", nil, run)
    pb:SetPoint("TOPLEFT", pbBG, "TOPLEFT"); pb:SetSize(BODY_W - 4, 6)
    pb:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    pb:SetStatusBarColor(COL.ACCHI[1], COL.ACCHI[2], COL.ACCHI[3], 1)
    W.instBar = pb
    W.instHost = run
    W.instRows = {}

    local done = CreateFrame("Frame", nil, p); done:SetAllPoints(); done:Hide()
    AddFadeIn(done, 0.3)
    local dl = done:CreateTexture(nil, "ARTWORK"); dl:SetSize(72, 72); dl:SetPoint("TOP", 0, -10); dl:SetTexture(LOGO)
    local dt = Text(done, "GameFontNormalHuge", L.WIZ_DONE_TITLE, COL.TXT); dt:SetPoint("TOP", dl, "BOTTOM", 0, -8)
    local dx = Text(done, "GameFontHighlight", "", COL.MUT); dx:SetPoint("TOP", dt, "BOTTOM", 0, -8)
    dx:SetWidth(BODY_W - 40); dx:SetJustifyH("CENTER")
    W.doneText = dx
    local gw = (BODY_W - 20) / 3
    for i, g in ipairs({ { L.WIZ_G1_T, L.WIZ_G1_D }, { L.WIZ_G2_T, L.WIZ_G2_D }, { L.WIZ_G3_T, L.WIZ_G3_D } }) do
      local box = Card(done); box:SetSize(gw, 70)
      box:SetPoint("TOPLEFT", (i - 1) * (gw + 10), -210)
      local bt = Text(box, "GameFontNormal", g[1], COL.GOLD); bt:SetPoint("TOPLEFT", 14, -14)
      local bd = Text(box, "GameFontHighlightSmall", g[2], COL.MUT, gw - 28); bd:SetPoint("TOPLEFT", bt, "BOTTOMLEFT", 0, -6)
    end
    W.runView, W.doneView = run, done
  end

  -- ----- Pied -----
  local sep2 = f:CreateTexture(nil, "ARTWORK")
  sep2:SetColorTexture(1, 1, 1, 0.10)
  sep2:SetPoint("BOTTOMLEFT", 1, 50); sep2:SetPoint("BOTTOMRIGHT", -1, 50); sep2:SetHeight(1)
  local siteB = Btn(f, 60, 24, L.WIZ_SITE, "ghost"); siteB:SetPoint("BOTTOMLEFT", 14, 13)
  siteB:SetScript("OnClick", function() ShowURL(URL_SITE) end)
  local curseB = Btn(f, 96, 24, L.WIZ_CURSE, "ghost"); curseB:SetPoint("LEFT", siteB, "RIGHT", 4, 0)
  curseB:SetScript("OnClick", function() ShowURL(URL_CURSE) end)
  local nextB = Btn(f, 190, 26, "", "pri"); nextB:SetPoint("BOTTOMRIGHT", -18, 12)
  local prevB = Btn(f, 110, 26, L.WIZ_PREV); prevB:SetPoint("RIGHT", nextB, "LEFT", -8, 0)
  W.nextB, W.prevB = nextB, prevB

  -- ================= LOGIQUE =================
  local cardsBuilt = false

  function W.SetPreset(id)
    W.preset = id
    wipe(W.choice)
    local keys
    for _, pr in ipairs(PRESETS) do if pr.id == id then keys = pr.keys end end
    if keys then
      for _, k in ipairs(keys) do W.choice[k] = true end
    else
      for _, m in ipairs(W.present) do W.choice[m.key] = true end
    end
  end

  local function CountOn()
    local n = 0
    for _, m in ipairs(W.present) do if W.choice[m.key] then n = n + 1 end end
    return n
  end

  local function BuildCards()
    if cardsBuilt then return end
    cardsBuilt = true
    local host = W.cardsHost
    local CARDW = (BODY_W - 26 - 8) / 2
    local CARDH = 58
    local y = -2
    local cats = { { "t", L.WIZ_CAT_T }, { "h", L.WIZ_CAT_H }, { "o", L.WIZ_CAT_O } }
    for _, cat in ipairs(cats) do
      local list = {}
      for _, m in ipairs(W.present) do if (GROUP[m.key] or "t") == cat[1] then list[#list + 1] = m end end
      if #list > 0 then
        local h = Label(host, cat[2]); h:SetPoint("TOPLEFT", 4, y - 6)
        local rule = host:CreateTexture(nil, "ARTWORK"); rule:SetColorTexture(1, 1, 1, 0.08); rule:SetHeight(1)
        rule:SetPoint("LEFT", h, "RIGHT", 8, 0); rule:SetPoint("RIGHT", host, "RIGHT", -4, 0)
        y = y - 26
        for j, m in ipairs(list) do
          local col = rgb(m)
          local card = CreateFrame("Button", nil, host, "BackdropTemplate")
          card:SetSize(CARDW, CARDH)
          local cc, rr = (j - 1) % 2, math.floor((j - 1) / 2)
          card:SetPoint("TOPLEFT", 2 + cc * (CARDW + 8), y - rr * (CARDH + 8))
          card:SetBackdrop(FLAT)
          local barT = card:CreateTexture(nil, "OVERLAY")
          barT:SetPoint("TOPLEFT", 0, 0); barT:SetPoint("BOTTOMLEFT", 0, 0); barT:SetWidth(3)
          local ico = card:CreateTexture(nil, "ARTWORK")
          ico:SetSize(36, 36); ico:SetPoint("LEFT", 12, 0); ico:SetTexture(logoOf(m.key))
          local sw = makeSwitch(card, col); sw:SetPoint("RIGHT", -10, 0)
          local nm = Text(card, "GameFontNormal", m.addonName, col); nm:SetPoint("TOPLEFT", ico, "TOPRIGHT", 10, 2)
          -- Module desactive dans la liste d'addons de WoW : reactive a l'installation.
          if TibiSuite.IsEnabledInWoW and not TibiSuite.IsEnabledInWoW(m.addonName) then
            local wn = Text(card, "GameFontHighlightSmall", L.WIZ_WOW_DISABLED, COL.WARN)
            wn:SetPoint("LEFT", nm, "RIGHT", 8, 0)
          end
          local ds = Text(card, "GameFontHighlightSmall", L["DESC_" .. m.key] or "", COL.MUT, CARDW - 110)
          ds:SetPoint("TOPLEFT", nm, "BOTTOMLEFT", 0, -3)
          if ds.SetMaxLines then ds:SetMaxLines(2) end
          local function apply()
            local on = W.choice[m.key] and true or false
            sw._set(on)
            if on then
              card:SetBackdropColor(COL.CARD[1], COL.CARD[2], COL.CARD[3], 0.97)
              card:SetBackdropBorderColor(col[1] * 0.45, col[2] * 0.45, col[3] * 0.45, 1)
              barT:SetColorTexture(col[1], col[2], col[3], 1)
              card:SetAlpha(1)
            else
              card:SetBackdropColor(COL.CARD[1], COL.CARD[2], COL.CARD[3], 0.97)
              card:SetBackdropBorderColor(0, 0, 0, 1)
              barT:SetColorTexture(0.16, 0.17, 0.2, 1)
              card:SetAlpha(0.5)
            end
          end
          local function toggle()
            W.choice[m.key] = (not W.choice[m.key]) or nil
            W.preset = nil
            W.RefreshCards()
          end
          card:SetScript("OnClick", toggle)
          sw:SetScript("OnClick", toggle)
          card._apply = apply
          W.cards[#W.cards + 1] = card
        end
        y = y - math.ceil(#list / 2) * (CARDH + 8) - 6
      end
    end
    host:SetHeight(math.max(-y + 6, 10))
  end

  function W.RefreshCards()
    BuildCards()
    for _, cd in ipairs(W.cards) do cd._apply() end
    for _, b in ipairs(W.presetBtns) do
      local on = (b._id == W.preset)
      b._sel:SetShown(on)
      b._selLine:SetShown(on)
    end
    W.counter:SetText(string.format(L.WIZ_COUNTER_FMT, HX.ACC .. CountOn() .. "|r", #W.present))
  end

  local pillFrames = {}
  local function RefreshPills()
    for _, pf in ipairs(pillFrames) do pf:Hide() end
    wipe(pillFrames)
    local ver, toc, tocN = PatchLabels()
    local okDot = (tocN >= 120100) and "|TInterface\\COMMON\\Indicator-Green:12:12|t "
                                    or "|TInterface\\COMMON\\Indicator-Yellow:12:12|t "
    local items = {
      HX.TXT .. #W.present .. "|r " .. L.WIZ_PILL_DETECT,
      okDot .. string.format(L.WIZ_PILL_PATCH, ver, toc),
      HX.TXT .. "0|r " .. L.WIZ_PILL_LOSS,
      L.WIZ_PILL_LATER,
    }
    for _, txt in ipairs(items) do
      local ch = Chip(W.pillsHost, txt, { col = COL.MUT })
      pillFrames[#pillFrames + 1] = ch
    end
    Flow(pillFrames, BODY_W - 12, 6, 22)
  end

  local feedFrames = {}
  local function RefreshFeeds()
    for _, ff in ipairs(feedFrames) do ff:Hide() end
    wipe(feedFrames)
    local cat = TibiSuite.GetCatalog and TibiSuite.GetCatalog() or {}
    local byKey = {}
    for _, m in ipairs(cat) do byKey[m.key] = m end
    for _, fd in ipairs(FEEDS) do
      local m = byKey[fd[2]]
      if m then
        local on = W.choice[m.key] and true or false
        local txt = fd[1] .. "  " .. HX.DIM .. m.addonName .. (on and "" or (", " .. L.WIZ_FEED_OFF)) .. "|r"
        local ch = Chip(W.feedsHost, txt, { bar = on and rgb(m) or { 0.16, 0.17, 0.2 }, col = COL.TXT })
        ch:SetBackdropColor(0.043, 0.047, 0.063, 1)
        ch:SetAlpha(on and 1 or 0.45)
        feedFrames[#feedFrames + 1] = ch
      end
    end
    Flow(feedFrames, W.feedsHost:GetWidth(), 5, 22)
  end

  local recapChips = {}
  local function RefreshRecap()
    local c = W.cfg
    local n = CountOn()
    W.recapSub:SetText(HX.ACC .. n .. "|r " .. L.WIZ_RECAP_COUNT)
    for _, ch in ipairs(recapChips) do ch:Hide() end
    wipe(recapChips)
    local off = {}
    for _, m in ipairs(W.present) do
      if W.choice[m.key] then
        recapChips[#recapChips + 1] = Chip(W.recapChips, m.addonName, { icon = logoOf(m.key), col = rgb(m) })
      else
        off[#off + 1] = m.addonName
      end
    end
    local hChips = Flow(recapChips, BODY_W - 4, 6, 22)
    W.recapSum:ClearAllPoints()
    W.recapSum:SetPoint("TOPLEFT", W.recapChips, "TOPLEFT", 0, -hChips - 14)
    local corner = c.corner and L.WIZ_CORNERS[c.corner] or L.WIZ_CORNER_CUSTOM
    local rows = {
      { L.WIZ_SUM_BAR, string.format(L.WIZ_SUM_BAR_FMT, c.vertical and L.WIZ_VERT or L.WIZ_HORIZ, c.scale, c.cols, c.rows, corner)
          .. (c.open and "" or L.WIZ_SUM_CLOSED) },
      { L.WIZ_SUM_MM, c.mm and L.WIZ_SUM_MM_ON or L.WIZ_SUM_MM_OFF },
      { L.WIZ_SUM_LOGIN, (c.msg == "full" and L.WIZ_SUM_MSG_FULL) or (c.msg == "none" and L.WIZ_SUM_MSG_NONE) or L.WIZ_SUM_MSG_ONE },
      { L.WIZ_SUM_DASH, c.exp and L.WIZ_SUM_EXP_ON or L.WIZ_SUM_EXP_OFF },
    }
    for i, r in ipairs(rows) do W.sumRows[i].k:SetText(r[1]); W.sumRows[i].v:SetText(r[2]) end
    local below = W.recapSum
    if #off > 0 then
      W.recapNoteText:SetText(string.format(L.WIZ_OFF_NOTE_FMT, #off, table.concat(off, ", ")))
      W.recapNote:SetHeight(math.max(34, (W.recapNoteText:GetStringHeight() or 14) + 18))
      W.recapNote:ClearAllPoints()
      W.recapNote:SetPoint("TOPLEFT", W.recapSum, "BOTTOMLEFT", 0, -10)
      W.recapNote:Show()
      below = W.recapNote
    else
      W.recapNote:Hide()
    end
    W.recapReass:ClearAllPoints()
    W.recapReass:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 2, -12)
  end

  local function StyleSteps()
    for i = 1, 6 do
      local s = W.steps[i]
      local active = (i - 1) == W.step
      local done   = (i - 1) < W.step
      if active then
        s.fill:SetColorTexture(0.137, 0.075, 0.094, 1)   -- rouge TibiSuite a 10 % sur le fond
        s.edge:SetColorTexture(COL.ACC[1] * 0.75, COL.ACC[2] * 0.75, COL.ACC[3] * 0.75, 1)
        s.num:SetColorTexture(COL.ACC[1], COL.ACC[2], COL.ACC[3], 1)
        s.numT:SetTextColor(1, 1, 1); s.lbl:SetTextColor(COL.TXT[1], COL.TXT[2], COL.TXT[3])
      else
        s.fill:SetColorTexture(0.078, 0.086, 0.106, 1)   -- blanc a 3 % sur le fond
        s.edge:SetColorTexture(0, 0, 0, 1)
        if done then
          s.num:SetColorTexture(0.23, 0.07, 0.1, 1)
          s.numT:SetTextColor(COL.ACCHI[1], COL.ACCHI[2], COL.ACCHI[3])
          s.lbl:SetTextColor(COL.MUT[1], COL.MUT[2], COL.MUT[3])
        else
          s.num:SetColorTexture(0.11, 0.118, 0.145, 1)
          s.numT:SetTextColor(COL.MUT[1], COL.MUT[2], COL.MUT[3])
          s.lbl:SetTextColor(COL.DIM[1], COL.DIM[2], COL.DIM[3])
        end
      end
    end
  end

  -- Ecrit les reglages de la suite (tout sauf les cases des modules).
  local function CommitSettings()
    local c = W.cfg
    if W.importProf then
      -- Champs du profil importe que l'installateur n'affiche pas.
      TibiSuiteDB.hidden = {}
      for k in pairs(W.importProf.hidden or {}) do TibiSuiteDB.hidden[k] = true end
    end
    TibiSuite.ApplyBarSettings({
      vertical = c.vertical, scale = c.scale / 100, cols = c.cols, rows = c.rows,
      corner = c.corner, open = c.open,
      logoSize = W.importProf and W.importProf.logoSize or nil,
      locked = W.importProf and W.importProf.locked or nil,
    })
    TibiSuite.SetMinimapHidden(not c.mm)
    TibiSuiteDB.loginMsg = c.msg
    TibiSuiteDB.statsAutoExport = c.exp and true or false
    -- Les migrations ponctuelles du core (PostBox, Opacity arrives apres
    -- coup) forcent la case a « coche » tant que leur drapeau est absent.
    -- L'utilisateur vient de choisir lui-meme : on les marque faites, sinon
    -- PostBox / Opacity decoches ici seraient re-coches a la connexion suivante.
    TibiSuiteDB.postBoxEnableMigrated = true
    TibiSuiteDB.opacityEnableMigrated = true
    TibiSuiteDB.setupDone = true
    TibiSuiteDB.lastSeenVersion = TibiSuite.VERSION
  end

  local function Finish()
    print("|cFFC41F3BTibiSuite|r : " .. L.WIZ_FINISH_PRINT)
    TibiSuite.ShowToast(L.WIZ_FINISH_TOAST)
  end

  local function ShowDone()
    W.running = false
    W.runView:Hide(); W.doneView:Show()
    W.prog:SetValue(5)
    local n = CountOn()
    local pending = 0
    for _ in pairs(TibiSuite.pendingReload) do pending = pending + 1 end
    W.doneText:SetText(string.format(L.WIZ_DONE_FMT, n)
      .. ((pending > 0) and string.format(L.WIZ_DONE_RELOAD_FMT, pending) or ""))
    W.nextB._label:SetText(pending > 0 and L.WIZ_RELOAD or L.WIZ_FINISH)
    W.nextB:Show()
    W.finished = true
    Finish()
  end

  -- Etape 6 : applique les cases une par une (resultat reel affiche).
  local function RunInstall()
    CommitSettings()
    W.running, W.finished = true, false
    W.runView:Show(); W.doneView:Hide()
    for _, r in ipairs(W.instRows) do r:Hide() end
    wipe(W.instRows)
    local half = math.ceil(#W.present / 2)
    local colW = (BODY_W - 20) / 2
    for i, m in ipairs(W.present) do
      local r = CreateFrame("Frame", nil, W.instHost)
      r:SetSize(colW, 22)
      local ci, ri = (i <= half) and 0 or 1, (i <= half) and (i - 1) or (i - 1 - half)
      r:SetPoint("TOPLEFT", 2 + ci * (colW + 16), -46 - ri * 25)
      local ic = r:CreateTexture(nil, "ARTWORK"); ic:SetSize(20, 20); ic:SetPoint("LEFT"); ic:SetTexture(logoOf(m.key))
      ic:SetAlpha(0.35)
      local nm = Text(r, "GameFontHighlight", m.addonName, COL.DIM); nm:SetPoint("LEFT", ic, "RIGHT", 8, 0)
      local st = Text(r, "GameFontHighlightSmall", ICON_WAIT .. " " .. L.WIZ_ST_WAIT, COL.DIM); st:SetPoint("RIGHT", -2, 0)
      r.ic, r.nm, r.st = ic, nm, st
      W.instRows[i] = r
    end
    W.instBar:SetMinMaxValues(0, math.max(1, #W.present))
    W.instBar:SetValue(0)
    local i = 0
    local ticker
    ticker = C_Timer.NewTicker(0.15, function()
      i = i + 1
      local m, r = W.present[i], W.instRows[i]
      if not m then
        ticker:Cancel()
        C_Timer.After(0.45, ShowDone)
        return
      end
      local on = W.choice[m.key] and true or false
      local ok, status = pcall(TibiSuite.SetModuleEnabled, m.key, on)
      r.nm:SetTextColor(COL.TXT[1], COL.TXT[2], COL.TXT[3])
      if not ok or status == "absent" then
        r.st:SetText(ICON_FAIL .. " " .. HX.WARN .. L.WIZ_ST_FAIL .. "|r")
      elseif status == "loaded" then
        r.ic:SetAlpha(1); r.st:SetText(ICON_OK .. " " .. HX.OK .. L.WIZ_ST_OK .. "|r")
      elseif status == "reload" then
        r.ic:SetAlpha(1); r.st:SetText(ICON_WAIT .. " " .. HX.GOLD .. L.WIZ_ST_RELOAD .. "|r")
      else
        r.nm:SetTextColor(COL.DIM[1], COL.DIM[2], COL.DIM[3])
        r.st:SetText(HX.DIM .. L.WIZ_ST_OFF .. "|r")
      end
      W.instBar:SetValue(i)
    end)
  end

  -- Croix ou fin sans animation : tout appliquer d'un coup.
  local function CommitAllNow()
    CommitSettings()
    for _, m in ipairs(W.present) do
      pcall(TibiSuite.SetModuleEnabled, m.key, W.choice[m.key] and true or false)
    end
    Finish()
  end

  function W.goStep(s)
    W.step = s
    for i = 0, 5 do W.panes[i]:SetShown(i == s) end
    StyleSteps()
    W.prog:SetValue(s)
    prevB:SetShown(s > 0 and s < 5)
    nextB:Show()
    if s == 0 then nextB._label:SetText(L.WIZ_START); RefreshPills()
    elseif s == 1 then nextB._label:SetText(L.WIZ_CONTINUE); W.RefreshCards()
    elseif s == 2 then nextB._label:SetText(L.WIZ_CONTINUE); W.RefreshIfc(); W.RenderPreview()
    elseif s == 3 then nextB._label:SetText(L.WIZ_CONTINUE); W.tExp.Refresh(); RefreshFeeds()
    elseif s == 4 then nextB._label:SetText(L.WIZ_INSTALL); RefreshRecap()
    else nextB:Hide(); RunInstall() end
  end

  prevB:SetScript("OnClick", function() if W.step > 0 and W.step < 5 then W.goStep(W.step - 1) end end)
  nextB:SetScript("OnClick", function()
    if W.step < 5 then
      W.goStep(W.step + 1)
    elseif W.finished then
      f:Hide()
      if TibiSuite.NeedsReload and TibiSuite.NeedsReload() then TibiSuite.Reload() end
    end
  end)
  closeB:SetScript("OnClick", function()
    if W.running then return end            -- installation en cours : on laisse finir
    if not W.finished then CommitAllNow() end
    f:Hide()
  end)

  return W
end

-- Ouvre l'installateur. Repart toujours de l'etat actuel (modules coches,
-- reglages de la barre) : relancer l'installation n'efface jamais rien.
function TibiSuite.RunSetup()
  local catalog = (TibiSuite.GetCatalog and TibiSuite.GetCatalog()) or {}
  local w = BuildWizard()
  if not w then
    -- Socle absent : repli non destructif (activer tout ce qui est present).
    for _, mod in ipairs(catalog) do
      if TibiSuite.ModuleExists and TibiSuite.ModuleExists(mod.addonName)
         and TibiSuite.SetModuleEnabled then
        TibiSuite.SetModuleEnabled(mod.key, true)
      end
    end
    if TibiSuiteDB then TibiSuiteDB.setupDone = true end
    return
  end
  if w.running then return end
  local first = not TibiSuiteDB.setupDone
  local hasList = type(TibiSuiteDB.enabledModules) == "table"
  wipe(w.present); wipe(w.choice)
  w.importProf, w.finished, w.preset = nil, false, nil
  for _, mod in ipairs(catalog) do
    if TibiSuite.ModuleExists and TibiSuite.ModuleExists(mod.addonName) then
      w.present[#w.present + 1] = mod
      -- Premier lancement : tout coche (non destructif). Sinon : l'etat actuel.
      if first or not hasList or TibiSuite.IsModuleEnabled(mod.key) then w.choice[mod.key] = true end
    end
  end
  if first or not hasList then w.preset = "all" end
  local c = w.cfg
  c.vertical = TibiSuiteDB.vertical and true or false
  c.scale    = math.floor((TibiSuiteDB.scale or 0.9) * 100 + 0.5)
  c.cols     = TibiSuiteDB.cols or 2
  c.rows     = TibiSuiteDB.rows or 5
  c.corner   = TibiSuite.GetBarCorner and TibiSuite.GetBarCorner() or 1
  c.mm       = not TibiSuiteDB.mmHidden
  c.open     = (TibiSuiteCharDB.barOpen ~= false)
  c.msg      = TibiSuiteDB.loginMsg or "one"
  c.exp      = TibiSuiteDB.statsAutoExport ~= false
  local ver = PatchLabels()
  w.sub:SetText(string.format(L.WIZ_SUBTITLE_FMT, TibiSuite.VERSION or "?", ver))
  -- Le recap et l'apercu reconstruisent leurs listes a chaque passage.
  w.frame:Show()
  w.goStep(0)
end

-- Appele par le core au tout premier login (setupDone absent).
function TibiSuite.RunFirstSetup() TibiSuite.RunSetup() end

-- ================================================================
-- QUOI DE NEUF (une fois par version)
-- ================================================================
local wn
function TibiSuite.ShowWhatsNew(force)
  local UI = _G.TibiMidnight
  local ver = TibiSuite.VERSION
  local items = WHATSNEW[ver]
  if not items and not force then
    TibiSuiteDB.lastSeenVersion = ver   -- rien a montrer pour cette version
    return
  end
  if not UI then return end
  -- Ne jamais recouvrir l'installateur.
  if W and W.frame and W.frame:IsShown() then return end

  if not wn then
    local f = CreateFrame("Frame", "TibiSuiteWhatsNew", UIParent, "BackdropTemplate")
    f:SetWidth(560)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.SkinFrame(f, ACCENT_SUITE, UI.C.PANEL)
    AddFadeIn(f, 0.25)
    f:Hide()
    tinsert(UISpecialFrames, "TibiSuiteWhatsNew")

    local lg = f:CreateTexture(nil, "OVERLAY"); lg:SetSize(38, 38); lg:SetPoint("TOPLEFT", 16, -14); lg:SetTexture(LOGO)
    local t = Text(f, "GameFontNormalLarge", L.WN_TITLE, COL.ACCHI); t:SetPoint("TOPLEFT", lg, "TOPRIGHT", 12, -3)
    local s = Text(f, "GameFontHighlightSmall", L.WN_SUBTITLE, COL.MUT); s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -5)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 2, 2)
    local sep = f:CreateTexture(nil, "ARTWORK"); sep:SetColorTexture(1, 1, 1, 0.10); sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 1, -64); sep:SetPoint("TOPRIGHT", -1, -64)
    local verFS = Text(f, "GameFontHighlight", "", COL.MUT); verFS:SetPoint("TOPLEFT", 18, -76)
    local host = CreateFrame("Frame", nil, f); host:SetPoint("TOPLEFT", 18, -100); host:SetSize(524, 10)
    local sep2 = f:CreateTexture(nil, "ARTWORK"); sep2:SetColorTexture(1, 1, 1, 0.10); sep2:SetHeight(1)
    sep2:SetPoint("BOTTOMLEFT", 1, 50); sep2:SetPoint("BOTTOMRIGHT", -1, 50)
    local log = Btn(f, 120, 24, L.WN_LOG, "ghost"); log:SetPoint("BOTTOMLEFT", 14, 13)
    log:SetScript("OnClick", function() ShowURL(URL_CHANGELOG) end)
    local ok = Btn(f, 110, 26, L.WN_OK, "pri"); ok:SetPoint("BOTTOMRIGHT", -16, 12)
    local setup = Btn(f, 170, 26, L.WN_SETUP); setup:SetPoint("RIGHT", ok, "LEFT", -8, 0)
    ok:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnClick", function() f:Hide() end)
    setup:SetScript("OnClick", function() f:Hide(); TibiSuite.RunSetup() end)
    -- PAS de HookScript("OnHide") ici : combine a UISpecialFrames, c'est le
    -- piege de taint documente (Echap / ToggleGameMenu). La version est donc
    -- marquee « vue » des l'affichage, plus bas.
    wn = { frame = f, host = host, ver = verFS, rows = {} }
  end

  for _, r in ipairs(wn.rows) do r:Hide() end
  wipe(wn.rows)
  local prevVer = TibiSuiteDB.lastSeenVersion
  wn.ver:SetText(((prevVer and prevVer ~= ver) and (prevVer .. "  >  ") or "") .. HX.GOLD .. ver .. "|r")
  local cat = TibiSuite.GetCatalog and TibiSuite.GetCatalog() or {}
  local byKey = {}
  for _, m in ipairs(cat) do byKey[m.key] = m end
  local y = 0
  if not items then
    local r = CreateFrame("Frame", nil, wn.host); r:SetSize(524, 24); r:SetPoint("TOPLEFT", 0, 0)
    Text(r, "GameFontHighlight", L.WN_NONE, COL.MUT):SetPoint("LEFT")
    wn.rows[1] = r
    y = -30
  end
  for i, it in ipairs(items or {}) do
    local r = CreateFrame("Frame", nil, wn.host)
    r:SetWidth(524)
    local ic = r:CreateTexture(nil, "ARTWORK"); ic:SetSize(28, 28); ic:SetPoint("TOPLEFT", 0, -4)
    ic:SetTexture(logoOf(it.key))
    local m = byKey[it.key]
    local col = m and rgb(m) or COL.ACCHI
    local tt = Text(r, "GameFontNormal", it.title .. (it.new and ("   " .. HX.OK .. L.WN_NEW .. "|r") or ""), col)
    tt:SetPoint("TOPLEFT", ic, "TOPRIGHT", 10, 0)
    local d = Text(r, "GameFontHighlightSmall", it.text, COL.MUT, 480)
    d:SetPoint("TOPLEFT", tt, "BOTTOMLEFT", 0, -3)
    local h = math.max(36, (d:GetStringHeight() or 12) + 26)
    r:SetHeight(h)
    r:SetPoint("TOPLEFT", 0, y)
    if i < #items then
      local line = r:CreateTexture(nil, "ARTWORK"); line:SetColorTexture(1, 1, 1, 0.08); line:SetHeight(1)
      line:SetPoint("BOTTOMLEFT", 0, 0); line:SetPoint("BOTTOMRIGHT", 0, 0)
    end
    y = y - h - 6
    wn.rows[#wn.rows + 1] = r
  end
  wn.host:SetHeight(-y)
  wn.frame:SetHeight(100 + (-y) + 60)
  wn.frame:Show()
  TibiSuiteDB.lastSeenVersion = ver   -- une seule apparition par version
end

-- ================================================================
-- PROFILS DE SUITE (fenetre /ts profile)
-- ================================================================
local pf
function TibiSuite.OpenProfileWindow()
  local UI = _G.TibiMidnight
  if not UI or not TibiSuite.ExportProfile then return end
  if not pf then
    local f = CreateFrame("Frame", "TibiSuiteProfileFrame", UIParent, "BackdropTemplate")
    f:SetSize(500, 250)
    f:SetPoint("CENTER", 0, 60)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.SkinFrame(f, ACCENT_SUITE, UI.C.PANEL)
    f:Hide()
    tinsert(UISpecialFrames, "TibiSuiteProfileFrame")
    local t = Text(f, "GameFontNormalLarge", L.PF_TITLE, COL.ACCHI); t:SetPoint("TOPLEFT", 18, -16)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide() end)

    local l1 = Text(f, "GameFontHighlightSmall", L.PF_EXPORT, COL.MUT); l1:SetPoint("TOPLEFT", 18, -50)
    local ex = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    ex:SetSize(456, 24); ex:SetPoint("TOPLEFT", 24, -66); ex:SetAutoFocus(false)
    ex:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    ex:SetScript("OnEditFocusGained", function(s) s:HighlightText() end)
    -- Lecture seule : toute frappe restaure le code.
    ex:SetScript("OnTextChanged", function(s, user) if user then s:SetText(pf.code or ""); s:HighlightText() end end)

    local l2 = Text(f, "GameFontHighlightSmall", L.PF_IMPORT, COL.MUT); l2:SetPoint("TOPLEFT", 18, -104)
    local im = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    im:SetSize(340, 24); im:SetPoint("TOPLEFT", 24, -120); im:SetAutoFocus(false)
    im:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    local go = Btn(f, 110, 24, L.PF_APPLY, "pri"); go:SetPoint("LEFT", im, "RIGHT", 10, 0)
    local msg = Text(f, "GameFontHighlightSmall", "", COL.WARN); msg:SetPoint("TOPLEFT", 18, -152)
    local note = Text(f, "GameFontHighlightSmall", L.PF_NOTE, COL.DIM, 464); note:SetPoint("BOTTOMLEFT", 18, 18)

    go:SetScript("OnClick", function()
      local prof, err = TibiSuite.DecodeProfile(im:GetText())
      if not prof then
        msg:SetTextColor(COL.WARN[1], COL.WARN[2], COL.WARN[3])
        msg:SetText(L["PROFILE_ERR_" .. tostring(err)] or L.PROFILE_ERR_format)
        return
      end
      TibiSuite.ApplyProfile(prof)
      pf.code = TibiSuite.ExportProfile(); ex:SetText(pf.code)
      msg:SetTextColor(COL.OK[1], COL.OK[2], COL.OK[3])
      msg:SetText(L.PF_APPLIED)
      if TibiSuite.NeedsReload() then
        ShowConfirm(L.PF_RELOAD_ASK, function() TibiSuite.Reload() end)
      end
    end)
    pf = { frame = f, ex = ex, im = im, msg = msg }
  end
  pf.code = TibiSuite.ExportProfile()
  pf.ex:SetText(pf.code)
  pf.im:SetText("")
  pf.msg:SetText("")
  pf.frame:Show()
  pf.ex:SetFocus()
end
