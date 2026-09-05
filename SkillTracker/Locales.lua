-- ================================================================
--  SkillTracker  -  Locales.lua
--  Chaines de localisation EN (defaut) + FR.
--  On selectionne la table FR uniquement si le client tourne en frFR ;
--  toute chaine manquante retombe automatiquement sur l'anglais.
--  Aucune variable globale : tout vit dans la table privee de l'addon.
-- ================================================================

local _, ST = ...

-- ---------------------------------------------------------------
-- Anglais : table de reference (contient TOUTES les cles).
-- ---------------------------------------------------------------
local enUS = {
  ADDON_NAME        = "SkillTracker",

  -- En-tetes / titres
  TITLE             = "SkillTracker",
  PANEL_SUBTITLE    = "Profession progress by expansion",
  SUMMARY_TITLE     = "Account summary",

  -- Categories de metiers
  PRIMARY           = "Primary professions",
  SECONDARY         = "Secondary professions",
  ARCHAEOLOGY       = "Archaeology",
  OVERALL           = "Overall",
  EXPANSION         = "Expansion",

  -- Etats / messages
  NO_PROFESSIONS    = "No profession known on this character.",
  OPEN_HINT         = "Open a profession window once to load the per-expansion detail.",
  NO_DATA           = "No data yet.",
  CURRENT_CHAR      = "This character",
  MAXED             = "Maxed",
  MAXED_SHORT       = "maxed",

  -- Bascule de vue (onglet Metiers)
  METIER_VIEW_CURRENT = "Current expansion",
  METIER_VIEW_ALL      = "All expansions",
  METIER_VIEW_ACCOUNT  = "Account",

  -- Multi-personnages
  CHARS_ONE         = "%d character",
  CHARS_MANY        = "%d characters",
  KNOWN_BY          = "Known by",
  IMPORTED_TAG      = "imported",
  AVG_PROGRESS      = "avg %d%%",
  PICK_CHARS        = "Pick the characters to display (click to toggle):",

  -- Options
  OPT_TITLE         = "SkillTracker - Options",
  OPT_GENERAL       = "General",
  OPT_ENABLED       = "Module enabled",
  OPT_ENABLED_TT    = "Disable to stop scans and hide the panel.",
  OPT_HIDE_MAXED    = "Hide maxed expansions",
  OPT_HIDE_MAXED_TT = "Only show professions/expansions that are not at 100%.",
  OPT_MINIMAP       = "Show minimap button",
  OPT_DATA          = "Data sharing (multi-account)",
  OPT_EXPORT        = "Export my data",
  OPT_IMPORT        = "Import data",
  OPT_RESCAN        = "Rescan now",
  OPT_WIPE_CHAR     = "Wipe this character's data",

  -- Export / import
  EXPORT_HINT       = "Copy this string (Ctrl+C) and paste it on your other installation.",
  IMPORT_HINT       = "Paste an exported string here, then press Enter.",
  IMPORT_OK         = "Import succeeded: %d character(s) added or updated.",
  IMPORT_FAIL       = "Import failed: the string is invalid or corrupted.",
  EXPORT_EMPTY      = "Nothing to export yet.",

  -- Tooltip / slash
  TT_LEFT           = "Left click: open / close the panel",
  TT_RIGHT          = "Right click: options",
  SLASH_HELP        = "commands:",
  SLASH_TOGGLE      = "show / hide the panel",
  SLASH_CONFIG      = "options panel",
  SLASH_SCAN        = "force a rescan",

  -- A finir (to-do)
  TODO_TITLE        = "To finish",
  TODO_NONE         = "Everything is maxed. Nice work!",
  TODO_MORE         = "... and %d more",
  TODO_COUNT_ONE    = "%d tier to finish",
  TODO_COUNT_MANY   = "%d tiers to finish",
  TODO_EXT_FILTER   = "Filter by expansion (click to toggle):",

  -- Concentration & connaissances
  META_TITLE        = "Concentration & knowledge",
  CONCENTRATION     = "Concentration",
  KP_UNSPENT        = "%d unspent",
  KP_LABEL          = "knowledge",
  CONC_FULL_ALERT   = "%s: concentration is full (%d/%d), spend it!",
  CONC_FULL_TAG     = "FULL",
  OPEN_PROF_HINT    = "Click: open the profession window",
  KP_TIER           = "%d knowledge",

  -- Options (suite)
  OPT_HIDE_MAXPROF  = "Hide fully maxed professions",
  OPT_SHOW_TODO     = "Show the \"to finish\" list",
  OPT_CONC_ALERT    = "Warn when concentration is full",
  OPT_VIEW          = "Display",

  -- Divers
  LOADED_MSG        = "loaded",
  MULTIACC_NOTE     = "Multi-account only syncs automatically on the same WoW installation. For separate installs, use Export / Import.",
}

-- ---------------------------------------------------------------
-- Francais : uniquement les cles traduites (le reste retombe sur enUS).
-- Pas de tiret cadratin, ponctuation naturelle.
-- ---------------------------------------------------------------
local frFR = {
  PANEL_SUBTITLE    = "Progression des metiers par extension",
  SUMMARY_TITLE     = "Recapitulatif du compte",

  PRIMARY           = "Metiers principaux",
  SECONDARY         = "Metiers secondaires",
  ARCHAEOLOGY       = "Archeologie",
  OVERALL           = "Global",
  EXPANSION         = "Extension",

  NO_PROFESSIONS    = "Aucun metier connu sur ce personnage.",
  OPEN_HINT         = "Ouvrez une fenetre de metier une fois pour charger le detail par extension.",
  NO_DATA           = "Aucune donnee pour l'instant.",
  CURRENT_CHAR      = "Ce personnage",
  MAXED             = "Au max",
  MAXED_SHORT       = "au max",

  METIER_VIEW_CURRENT = "Extension en cours",
  METIER_VIEW_ALL      = "Toutes les extensions",
  METIER_VIEW_ACCOUNT  = "Compte",

  CHARS_ONE         = "%d personnage",
  CHARS_MANY        = "%d personnages",
  KNOWN_BY          = "Possede par",
  IMPORTED_TAG      = "importe",
  AVG_PROGRESS      = "moy %d%%",
  PICK_CHARS        = "Choisissez les personnages a afficher (clic pour cocher) :",

  OPT_TITLE         = "SkillTracker - Options",
  OPT_GENERAL       = "General",
  OPT_ENABLED       = "Module actif",
  OPT_ENABLED_TT    = "Desactivez pour stopper les scans et masquer le panneau.",
  OPT_HIDE_MAXED    = "Masquer les extensions au max",
  OPT_HIDE_MAXED_TT = "N'affiche que les metiers ou extensions qui ne sont pas a 100%.",
  OPT_MINIMAP       = "Afficher le bouton minimap",
  OPT_DATA          = "Partage de donnees (multi-comptes)",
  OPT_EXPORT        = "Exporter mes donnees",
  OPT_IMPORT        = "Importer des donnees",
  OPT_RESCAN        = "Rescanner maintenant",
  OPT_WIPE_CHAR     = "Effacer les donnees de ce personnage",

  EXPORT_HINT       = "Copiez cette chaine (Ctrl+C) et collez-la sur votre autre installation.",
  IMPORT_HINT       = "Collez ici une chaine exportee, puis appuyez sur Entree.",
  IMPORT_OK         = "Import reussi : %d personnage(s) ajoute(s) ou mis a jour.",
  IMPORT_FAIL       = "Echec de l'import : la chaine est invalide ou corrompue.",
  EXPORT_EMPTY      = "Rien a exporter pour l'instant.",

  TT_LEFT           = "Clic gauche : ouvrir / fermer le panneau",
  TT_RIGHT          = "Clic droit : options",
  SLASH_HELP        = "commandes :",
  SLASH_TOGGLE      = "afficher / masquer le panneau",
  SLASH_CONFIG      = "panneau d'options",
  SLASH_SCAN        = "forcer un rescan",

  TODO_TITLE        = "A finir",
  TODO_NONE         = "Tout est au max. Beau travail !",
  TODO_MORE         = "... et %d de plus",
  TODO_COUNT_ONE    = "%d palier a finir",
  TODO_COUNT_MANY   = "%d paliers a finir",
  TODO_EXT_FILTER   = "Filtrer par extension (clic pour cocher) :",

  META_TITLE        = "Concentration & connaissances",
  CONCENTRATION     = "Concentration",
  KP_UNSPENT        = "%d non depenses",
  KP_LABEL          = "connaissances",
  CONC_FULL_ALERT   = "%s : concentration au max (%d/%d), pense a l'utiliser !",
  CONC_FULL_TAG     = "PLEINE",
  OPEN_PROF_HINT    = "Clic : ouvrir la fenetre du metier",
  KP_TIER           = "%d connaissances",

  OPT_HIDE_MAXPROF  = "Masquer les metiers entierement au max",
  OPT_SHOW_TODO     = "Afficher la liste \"a finir\"",
  OPT_CONC_ALERT    = "Alerter quand la concentration est pleine",
  OPT_VIEW          = "Affichage",

  LOADED_MSG        = "charge",
  MULTIACC_NOTE     = "Le multi-comptes ne se synchronise automatiquement que sur la meme installation de WoW. Pour des installations separees, utilisez Exporter / Importer.",
}

-- ---------------------------------------------------------------
-- Allemand : uniquement les cles traduites (le reste retombe sur enUS).
-- ---------------------------------------------------------------
local deDE = {
  PANEL_SUBTITLE    = "Berufsfortschritt nach Erweiterung",
  SUMMARY_TITLE     = "Kontouebersicht",

  PRIMARY           = "Hauptberufe",
  SECONDARY         = "Sekundaerberufe",
  ARCHAEOLOGY       = "Archaeologie",
  OVERALL           = "Gesamt",
  EXPANSION         = "Erweiterung",

  NO_PROFESSIONS    = "Kein Beruf auf diesem Charakter bekannt.",
  OPEN_HINT         = "Oeffne einmal ein Berufsfenster, um die Details je Erweiterung zu laden.",
  NO_DATA           = "Noch keine Daten.",
  CURRENT_CHAR      = "Dieser Charakter",
  MAXED             = "Maximiert",
  MAXED_SHORT       = "maximiert",

  METIER_VIEW_CURRENT = "Aktuelle Erweiterung",
  METIER_VIEW_ALL      = "Alle Erweiterungen",
  METIER_VIEW_ACCOUNT  = "Account",

  CHARS_ONE         = "%d Charakter",
  CHARS_MANY        = "%d Charaktere",
  KNOWN_BY          = "Bekannt von",
  IMPORTED_TAG      = "importiert",
  AVG_PROGRESS      = "durchschn. %d%%",
  PICK_CHARS        = "Waehle die anzuzeigenden Charaktere (klicken zum Umschalten):",

  OPT_TITLE         = "SkillTracker - Optionen",
  OPT_GENERAL       = "Allgemein",
  OPT_ENABLED       = "Modul aktiv",
  OPT_ENABLED_TT    = "Deaktivieren, um Scans zu stoppen und das Fenster auszublenden.",
  OPT_HIDE_MAXED    = "Maximierte Erweiterungen ausblenden",
  OPT_HIDE_MAXED_TT = "Zeigt nur Berufe/Erweiterungen, die nicht bei 100% sind.",
  OPT_MINIMAP       = "Minikarten-Button anzeigen",
  OPT_DATA          = "Datenaustausch (mehrere Accounts)",
  OPT_EXPORT        = "Meine Daten exportieren",
  OPT_IMPORT        = "Daten importieren",
  OPT_RESCAN        = "Jetzt neu scannen",
  OPT_WIPE_CHAR     = "Daten dieses Charakters loeschen",

  EXPORT_HINT       = "Kopiere diese Zeichenkette (Strg+C) und fuege sie auf deiner anderen Installation ein.",
  IMPORT_HINT       = "Fuege hier eine exportierte Zeichenkette ein und druecke dann Enter.",
  IMPORT_OK         = "Import erfolgreich: %d Charakter(e) hinzugefuegt oder aktualisiert.",
  IMPORT_FAIL       = "Import fehlgeschlagen: die Zeichenkette ist ungueltig oder beschaedigt.",
  EXPORT_EMPTY      = "Noch nichts zu exportieren.",

  TT_LEFT           = "Linksklick: Fenster oeffnen / schliessen",
  TT_RIGHT          = "Rechtsklick: Optionen",
  SLASH_HELP        = "Befehle:",
  SLASH_TOGGLE      = "Fenster anzeigen / ausblenden",
  SLASH_CONFIG      = "Optionsfenster",
  SLASH_SCAN        = "einen Neuscan erzwingen",

  TODO_TITLE        = "Noch zu erledigen",
  TODO_NONE         = "Alles ist maximiert. Gute Arbeit!",
  TODO_MORE         = "... und %d weitere",
  TODO_COUNT_ONE    = "%d Stufe zu erledigen",
  TODO_COUNT_MANY   = "%d Stufen zu erledigen",
  TODO_EXT_FILTER   = "Nach Erweiterung filtern (klicken zum Umschalten):",

  META_TITLE        = "Konzentration & Kenntnisse",
  CONCENTRATION     = "Konzentration",
  KP_UNSPENT        = "%d ungenutzt",
  KP_LABEL          = "Kenntnisse",
  CONC_FULL_ALERT   = "%s: Konzentration ist voll (%d/%d), gib sie aus!",
  CONC_FULL_TAG     = "VOLL",
  OPEN_PROF_HINT    = "Klick: Berufsfenster oeffnen",
  KP_TIER           = "%d Kenntnisse",

  OPT_HIDE_MAXPROF  = "Vollstaendig maximierte Berufe ausblenden",
  OPT_SHOW_TODO     = "Liste \"noch zu erledigen\" anzeigen",
  OPT_CONC_ALERT    = "Warnen, wenn die Konzentration voll ist",
  OPT_VIEW          = "Anzeige",

  LOADED_MSG        = "geladen",
  MULTIACC_NOTE     = "Der Mehrkonten-Abgleich funktioniert nur automatisch auf derselben WoW-Installation. Fuer getrennte Installationen nutze Export / Import.",
}

-- ---------------------------------------------------------------
-- Espagnol : uniquement les cles traduites (le reste retombe sur enUS).
-- ---------------------------------------------------------------
local esES = {
  PANEL_SUBTITLE    = "Progreso de profesiones por expansion",
  SUMMARY_TITLE     = "Resumen de la cuenta",

  PRIMARY           = "Profesiones principales",
  SECONDARY         = "Profesiones secundarias",
  ARCHAEOLOGY       = "Arqueologia",
  OVERALL           = "General",
  EXPANSION         = "Expansion",

  NO_PROFESSIONS    = "Ninguna profesion conocida en este personaje.",
  OPEN_HINT         = "Abre una ventana de profesion una vez para cargar el detalle por expansion.",
  NO_DATA           = "Todavia no hay datos.",
  CURRENT_CHAR      = "Este personaje",
  MAXED             = "Al maximo",
  MAXED_SHORT       = "al maximo",

  METIER_VIEW_CURRENT = "Expansion actual",
  METIER_VIEW_ALL      = "Todas las expansiones",
  METIER_VIEW_ACCOUNT  = "Cuenta",

  CHARS_ONE         = "%d personaje",
  CHARS_MANY        = "%d personajes",
  KNOWN_BY          = "Conocido por",
  IMPORTED_TAG      = "importado",
  AVG_PROGRESS      = "prom %d%%",
  PICK_CHARS        = "Elige los personajes a mostrar (clic para marcar):",

  OPT_TITLE         = "SkillTracker - Opciones",
  OPT_GENERAL       = "General",
  OPT_ENABLED       = "Modulo activo",
  OPT_ENABLED_TT    = "Desactiva para detener los escaneos y ocultar el panel.",
  OPT_HIDE_MAXED    = "Ocultar expansiones al maximo",
  OPT_HIDE_MAXED_TT = "Solo muestra profesiones/expansiones que no esten al 100%.",
  OPT_MINIMAP       = "Mostrar boton de minimapa",
  OPT_DATA          = "Compartir datos (multi-cuenta)",
  OPT_EXPORT        = "Exportar mis datos",
  OPT_IMPORT        = "Importar datos",
  OPT_RESCAN        = "Reescanear ahora",
  OPT_WIPE_CHAR     = "Borrar los datos de este personaje",

  EXPORT_HINT       = "Copia esta cadena (Ctrl+C) y pegala en tu otra instalacion.",
  IMPORT_HINT       = "Pega aqui una cadena exportada y luego pulsa Intro.",
  IMPORT_OK         = "Importacion exitosa: %d personaje(s) anadido(s) o actualizado(s).",
  IMPORT_FAIL       = "Fallo la importacion: la cadena no es valida o esta corrupta.",
  EXPORT_EMPTY      = "Nada que exportar todavia.",

  TT_LEFT           = "Clic izquierdo: abrir / cerrar el panel",
  TT_RIGHT          = "Clic derecho: opciones",
  SLASH_HELP        = "comandos:",
  SLASH_TOGGLE      = "mostrar / ocultar el panel",
  SLASH_CONFIG      = "panel de opciones",
  SLASH_SCAN        = "forzar un reescaneo",

  TODO_TITLE        = "Por terminar",
  TODO_NONE         = "Todo esta al maximo. Buen trabajo!",
  TODO_MORE         = "... y %d mas",
  TODO_COUNT_ONE    = "%d nivel por terminar",
  TODO_COUNT_MANY   = "%d niveles por terminar",
  TODO_EXT_FILTER   = "Filtrar por expansion (clic para marcar):",

  META_TITLE        = "Concentracion y conocimientos",
  CONCENTRATION     = "Concentracion",
  KP_UNSPENT        = "%d sin gastar",
  KP_LABEL          = "conocimientos",
  CONC_FULL_ALERT   = "%s: la concentracion esta llena (%d/%d), usala!",
  CONC_FULL_TAG     = "LLENA",
  OPEN_PROF_HINT    = "Clic: abrir la ventana de la profesion",
  KP_TIER           = "%d conocimientos",

  OPT_HIDE_MAXPROF  = "Ocultar profesiones totalmente al maximo",
  OPT_SHOW_TODO     = "Mostrar la lista \"por terminar\"",
  OPT_CONC_ALERT    = "Avisar cuando la concentracion este llena",
  OPT_VIEW          = "Visualizacion",

  LOADED_MSG        = "cargado",
  MULTIACC_NOTE     = "El multi-cuenta solo se sincroniza automaticamente en la misma instalacion de WoW. Para instalaciones separadas, usa Exportar / Importar.",
}

-- ---------------------------------------------------------------
-- Construction de la table finale L : copie enUS, puis superpose la
-- langue active. Acces via metatable : une cle absente renvoie la cle
-- elle-meme (jamais nil), ce qui evite toute erreur d'affichage.
-- ---------------------------------------------------------------
local L = {}
for k, v in pairs(enUS) do L[k] = v end
if GetLocale() == "frFR" then
  for k, v in pairs(frFR) do L[k] = v end
elseif GetLocale() == "deDE" then
  for k, v in pairs(deDE) do L[k] = v end
elseif GetLocale() == "esES" or GetLocale() == "esMX" then
  for k, v in pairs(esES) do L[k] = v end
end
setmetatable(L, { __index = function(_, k) return tostring(k) end })

ST.L = L
