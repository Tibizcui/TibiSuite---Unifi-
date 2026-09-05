--[[----------------------------------------------------------------------------
    MiniHub - Localisation / Localization
    ------------------------------------------------------------------------
    Anglais par defaut, francais si le client est en frFR. Toute chaine
    manquante retombe sur sa cle (jamais de "nil" affiche).

    English by default, French when the client runs frFR. Any missing string
    falls back to its key (never displays "nil").
------------------------------------------------------------------------------]]

local ADDON_NAME, ns = ...

MiniHub = MiniHub or {}

--------------------------------------------------------------------------------
-- English (base)
--------------------------------------------------------------------------------
local enUS = {
    ADDON_SUBTITLE   = "Gathers your addon minimap icons into a single, tidy, collapsible container.",
    EMPTY            = "No button collected",
    EMPTY_CONFLICT   = "%s already manages minimap buttons on its own - MiniHub steps aside.",
    MSG_CONFLICT_LOGIN = "%s already manages minimap buttons - MiniHub stays out of the way (container hidden). Type /minihub to open it manually if you still want to use it.",

    -- Tooltips
    TT_LEFT_TOGGLE   = "Left-click: open / close",
    TT_RIGHT_OPTIONS = "Right-click: options",
    TT_MIDDLE_RESCAN = "Middle-click: rescan buttons",
    TT_DRAG_MOVE     = "Drag: move the button",

    -- Messages
    MSG_COMBAT_OPTIONS = "cannot open options in combat. Try again after combat.",
    MSG_RESCAN       = "rescan done (%d buttons collected).",
    MSG_RESET        = "container and main button positions reset.",
    MSG_BLOCK        = "\"%s\" is now ignored (type /reload).",
    MSG_UNBLOCK      = "\"%s\" is no longer ignored.",
    MSG_ADD          = "\"%s\" added manually.",
    MSG_IMPORT_OK    = "profile imported. Type /reload to apply.",
    MSG_IMPORT_FAIL  = "import failed: invalid string.",

    -- Slash help
    SLASH_HELP       = "commands:",
    SLASH_TOGGLE     = "open / close the container",
    SLASH_SCAN       = "rescan minimap buttons",
    SLASH_RESET      = "recenter the container and the main button",
    SLASH_CONFIG     = "open the options",
    SLASH_DEBUG      = "list the minimap children (diagnostic)",
    SLASH_BLOCK      = "ignore a button",
    SLASH_ADD        = "force-collect a button by name",

    -- Options: sections & labels
    OPT_GENERAL      = "General",
    OPT_LAYOUT       = "Layout",
    OPT_APPEARANCE   = "Appearance",
    OPT_BEHAVIOR     = "Behavior",
    OPT_ORIENTATION  = "Orientation: %s",
    OPT_VERTICAL     = "Vertical",
    OPT_HORIZONTAL   = "Horizontal",
    OPT_COLUMNS      = "Number of columns",
    OPT_ROWS         = "Number of rows",
    OPT_BUTTON_SIZE  = "Cell size",
    OPT_SPACING      = "Spacing",
    OPT_BG_OPACITY   = "Background opacity (%)",
    OPT_MAIN_SIZE    = "Main button size",
    OPT_MAIN_OPACITY = "Main button opacity (%)",
    OPT_SHOW_TITLE   = "Show the title bar",
    OPT_LOCK         = "Lock the container position",
    OPT_SHOW_MINIMAP = "Show the minimap button",
    OPT_HIDE_ZOOM    = "Hide Blizzard zoom buttons (+/-)",
    OPT_HIDE_ZOOM_TT = "Zoom stays available via the mouse wheel.",
    OPT_SHOW_MAIN    = "Show the movable main button (logo)",
    OPT_SHOW_MAIN_TT = "A logo button, movable anywhere in the UI, that opens/closes the container.",
    OPT_RESCAN       = "Rescan",
    OPT_RECENTER     = "Recenter",
    OPT_EXCL_TITLE   = "Leave on the minimap",
    OPT_EXCL_HINT    = "Tick a button to exclude it from the container.",

    -- Theme
    OPT_THEME        = "Theme: %s",
    THEME_DARK       = "WeeklyCompass dark",
    THEME_GOLD       = "TibiSuite gold",
    THEME_GLASS      = "Frosted glass",
    THEME_MINIMAL    = "Minimal",
    OPT_BG_COLOR     = "Background color",
    OPT_BORDER_COLOR = "Border color",

    -- Behavior
    OPT_HOVER_OPEN   = "Open on hover",
    OPT_HOVER_OPEN_TT= "Open the container when hovering the main button.",
    OPT_AUTO_CLOSE   = "Auto-close when the mouse leaves",
    OPT_ANIMATE      = "Fade animation on open",
    OPT_HIDE_COMBAT  = "Hide in combat",
    OPT_HIDE_INSTANCE= "Hide in dungeons/raids",
    OPT_HIDE_PETBATTLE = "Hide during pet battles",

    -- Assistant / profiles
    OPT_UNKNOWN_TITLE = "Unrecognized buttons",
    OPT_UNKNOWN_HINT  = "Buttons found on the minimap that were not collected. Tick to collect them.",
    OPT_NONE_UNKNOWN  = "None detected.",
    OPT_PROFILE_TITLE = "Profile sharing",
    OPT_EXPORT        = "Export",
    OPT_IMPORT        = "Import",
    OPT_EXPORT_HINT   = "Copy this string to share your configuration.",
    OPT_IMPORT_HINT   = "Paste a string then click Import.",

    -- Keybinding
    BINDING_HEADER    = "MiniHub",
    BINDING_TOGGLE    = "Open / close the container",
}

--------------------------------------------------------------------------------
-- Francais
--------------------------------------------------------------------------------
local frFR = {
    ADDON_SUBTITLE   = "Regroupe les icones d'addon de la minicarte dans un conteneur unique, propre et retractable.",
    EMPTY            = "Aucun bouton collecte",
    EMPTY_CONFLICT   = "%s gere deja les boutons de la minicarte - MiniHub s'efface.",
    MSG_CONFLICT_LOGIN = "%s gere deja les boutons de la minicarte - MiniHub reste en retrait (conteneur masque). Tape /minihub pour l'ouvrir manuellement si tu veux quand meme l'utiliser.",

    TT_LEFT_TOGGLE   = "Clic gauche : ouvrir / fermer",
    TT_RIGHT_OPTIONS = "Clic droit : options",
    TT_MIDDLE_RESCAN = "Clic milieu : rescanner",
    TT_DRAG_MOVE     = "Glisser : deplacer le bouton",

    MSG_COMBAT_OPTIONS = "impossible d'ouvrir les options en combat. Reessaie apres le combat.",
    MSG_RESCAN       = "rescan effectue (%d boutons collectes).",
    MSG_RESET        = "positions du conteneur et du bouton principal reinitialisees.",
    MSG_BLOCK        = "\"%s\" est desormais ignore (fais /reload).",
    MSG_UNBLOCK      = "\"%s\" n'est plus ignore.",
    MSG_ADD          = "\"%s\" ajoute manuellement.",
    MSG_IMPORT_OK    = "profil importe. Fais /reload pour appliquer.",
    MSG_IMPORT_FAIL  = "import echoue : chaine invalide.",

    SLASH_HELP       = "commandes :",
    SLASH_TOGGLE     = "ouvrir / fermer le conteneur",
    SLASH_SCAN       = "rescanner les boutons de la minicarte",
    SLASH_RESET      = "recentrer le conteneur et le bouton principal",
    SLASH_CONFIG     = "ouvrir les options",
    SLASH_DEBUG      = "lister les enfants de la minicarte (diagnostic)",
    SLASH_BLOCK      = "ignorer un bouton",
    SLASH_ADD        = "forcer la collecte d'un bouton par son nom",

    OPT_GENERAL      = "General",
    OPT_LAYOUT       = "Disposition",
    OPT_APPEARANCE   = "Apparence",
    OPT_BEHAVIOR     = "Comportement",
    OPT_ORIENTATION  = "Orientation : %s",
    OPT_VERTICAL     = "Verticale",
    OPT_HORIZONTAL   = "Horizontale",
    OPT_COLUMNS      = "Nombre de colonnes",
    OPT_ROWS         = "Nombre de lignes",
    OPT_BUTTON_SIZE  = "Taille de cellule",
    OPT_SPACING      = "Espacement",
    OPT_BG_OPACITY   = "Opacite du fond (%)",
    OPT_MAIN_SIZE    = "Taille du bouton principal",
    OPT_MAIN_OPACITY = "Opacite du bouton principal (%)",
    OPT_SHOW_TITLE   = "Afficher la barre de titre",
    OPT_LOCK         = "Verrouiller la position du conteneur",
    OPT_SHOW_MINIMAP = "Afficher le bouton sur la minicarte",
    OPT_HIDE_ZOOM    = "Masquer les boutons de zoom Blizzard (+/-)",
    OPT_HIDE_ZOOM_TT = "Le zoom reste accessible a la molette de la souris.",
    OPT_SHOW_MAIN    = "Afficher le bouton principal deplacable (logo)",
    OPT_SHOW_MAIN_TT = "Un bouton logo, deplacable partout dans l'interface, qui ouvre/ferme le conteneur.",
    OPT_RESCAN       = "Rescanner",
    OPT_RECENTER     = "Recentrer",
    OPT_EXCL_TITLE   = "Laisser sur la minicarte",
    OPT_EXCL_HINT    = "Cochez un bouton pour l'exclure du conteneur.",

    OPT_THEME        = "Theme : %s",
    THEME_DARK       = "WeeklyCompass sombre",
    THEME_GOLD       = "TibiSuite dore",
    THEME_GLASS      = "Verre depoli",
    THEME_MINIMAL    = "Minimal",
    OPT_BG_COLOR     = "Couleur du fond",
    OPT_BORDER_COLOR = "Couleur de la bordure",

    OPT_HOVER_OPEN   = "Ouvrir au survol",
    OPT_HOVER_OPEN_TT= "Ouvre le conteneur au survol du bouton principal.",
    OPT_AUTO_CLOSE   = "Fermeture auto quand la souris quitte",
    OPT_ANIMATE      = "Animation de fondu a l'ouverture",
    OPT_HIDE_COMBAT  = "Masquer en combat",
    OPT_HIDE_INSTANCE= "Masquer en donjon/raid",
    OPT_HIDE_PETBATTLE = "Masquer pendant les combats de mascottes",

    OPT_UNKNOWN_TITLE = "Boutons non reconnus",
    OPT_UNKNOWN_HINT  = "Boutons trouves sur la minicarte mais non collectes. Cochez pour les collecter.",
    OPT_NONE_UNKNOWN  = "Aucun detecte.",
    OPT_PROFILE_TITLE = "Partage de profil",
    OPT_EXPORT        = "Exporter",
    OPT_IMPORT        = "Importer",
    OPT_EXPORT_HINT   = "Copiez cette chaine pour partager votre configuration.",
    OPT_IMPORT_HINT   = "Collez une chaine puis cliquez sur Importer.",

    BINDING_HEADER    = "MiniHub",
    BINDING_TOGGLE    = "Ouvrir / fermer le conteneur",
}

--------------------------------------------------------------------------------
-- Deutsch
--------------------------------------------------------------------------------
local deDE = {
    ADDON_SUBTITLE   = "Sammelt deine Addon-Minikarten-Symbole in einem einzigen, aufgeraeumten, einklappbaren Behaelter.",
    EMPTY            = "Kein Button gesammelt",
    EMPTY_CONFLICT   = "%s verwaltet die Minikarten-Buttons bereits selbst - MiniHub tritt zurueck.",
    MSG_CONFLICT_LOGIN = "%s verwaltet die Minikarten-Buttons bereits - MiniHub bleibt im Hintergrund (Behaelter ausgeblendet). Tippe /minihub, um ihn manuell zu oeffnen, falls du ihn trotzdem nutzen willst.",

    TT_LEFT_TOGGLE   = "Linksklick: oeffnen / schliessen",
    TT_RIGHT_OPTIONS = "Rechtsklick: Optionen",
    TT_MIDDLE_RESCAN = "Mittelklick: neu scannen",
    TT_DRAG_MOVE     = "Ziehen: Button verschieben",

    MSG_COMBAT_OPTIONS = "kann die Optionen im Kampf nicht oeffnen. Versuche es nach dem Kampf erneut.",
    MSG_RESCAN       = "Neuscan abgeschlossen (%d Buttons gesammelt).",
    MSG_RESET        = "Positionen von Behaelter und Hauptbutton zurueckgesetzt.",
    MSG_BLOCK        = "\"%s\" wird jetzt ignoriert (/reload ausfuehren).",
    MSG_UNBLOCK      = "\"%s\" wird nicht mehr ignoriert.",
    MSG_ADD          = "\"%s\" manuell hinzugefuegt.",
    MSG_IMPORT_OK    = "Profil importiert. /reload ausfuehren, um es anzuwenden.",
    MSG_IMPORT_FAIL  = "Import fehlgeschlagen: ungueltige Zeichenkette.",

    SLASH_HELP       = "Befehle:",
    SLASH_TOGGLE     = "Behaelter oeffnen / schliessen",
    SLASH_SCAN       = "Minikarten-Buttons neu scannen",
    SLASH_RESET      = "Behaelter und Hauptbutton zentrieren",
    SLASH_CONFIG     = "Optionen oeffnen",
    SLASH_DEBUG      = "Minikarten-Elemente auflisten (Diagnose)",
    SLASH_BLOCK      = "einen Button ignorieren",
    SLASH_ADD        = "einen Button per Name erzwingen",

    OPT_GENERAL      = "Allgemein",
    OPT_LAYOUT       = "Layout",
    OPT_APPEARANCE   = "Erscheinungsbild",
    OPT_BEHAVIOR     = "Verhalten",
    OPT_ORIENTATION  = "Ausrichtung: %s",
    OPT_VERTICAL     = "Vertikal",
    OPT_HORIZONTAL   = "Horizontal",
    OPT_COLUMNS      = "Anzahl Spalten",
    OPT_ROWS         = "Anzahl Reihen",
    OPT_BUTTON_SIZE  = "Zellengroesse",
    OPT_SPACING      = "Abstand",
    OPT_BG_OPACITY   = "Hintergrund-Deckkraft (%)",
    OPT_MAIN_SIZE    = "Groesse des Hauptbuttons",
    OPT_MAIN_OPACITY = "Deckkraft des Hauptbuttons (%)",
    OPT_SHOW_TITLE   = "Titelleiste anzeigen",
    OPT_LOCK         = "Position des Behaelters sperren",
    OPT_SHOW_MINIMAP = "Minikarten-Button anzeigen",
    OPT_HIDE_ZOOM    = "Blizzard-Zoombuttons ausblenden (+/-)",
    OPT_HIDE_ZOOM_TT = "Zoom bleibt ueber das Mausrad verfuegbar.",
    OPT_SHOW_MAIN    = "Beweglichen Hauptbutton anzeigen (Logo)",
    OPT_SHOW_MAIN_TT = "Ein Logo-Button, der frei in der Oberflaeche platziert werden kann und den Behaelter oeffnet/schliesst.",
    OPT_RESCAN       = "Neu scannen",
    OPT_RECENTER     = "Zentrieren",
    OPT_EXCL_TITLE   = "Auf der Minikarte belassen",
    OPT_EXCL_HINT    = "Haken setzen, um einen Button vom Behaelter auszuschliessen.",

    OPT_THEME        = "Motiv: %s",
    THEME_DARK       = "WeeklyCompass dunkel",
    THEME_GOLD       = "TibiSuite gold",
    THEME_GLASS      = "Milchglas",
    THEME_MINIMAL    = "Minimal",
    OPT_BG_COLOR     = "Hintergrundfarbe",
    OPT_BORDER_COLOR = "Rahmenfarbe",

    OPT_HOVER_OPEN   = "Beim Ueberfahren oeffnen",
    OPT_HOVER_OPEN_TT= "Oeffnet den Behaelter, wenn der Hauptbutton ueberfahren wird.",
    OPT_AUTO_CLOSE   = "Automatisch schliessen, wenn die Maus den Bereich verlaesst",
    OPT_ANIMATE      = "Einblendanimation beim Oeffnen",
    OPT_HIDE_COMBAT  = "Im Kampf ausblenden",
    OPT_HIDE_INSTANCE= "In Dungeons/Schlachtzuegen ausblenden",
    OPT_HIDE_PETBATTLE = "Waehrend Gefaehrtenkaempfen ausblenden",

    OPT_UNKNOWN_TITLE = "Nicht erkannte Buttons",
    OPT_UNKNOWN_HINT  = "Auf der Minikarte gefundene, aber nicht gesammelte Buttons. Ankreuzen, um sie zu sammeln.",
    OPT_NONE_UNKNOWN  = "Keine erkannt.",
    OPT_PROFILE_TITLE = "Profil teilen",
    OPT_EXPORT        = "Exportieren",
    OPT_IMPORT        = "Importieren",
    OPT_EXPORT_HINT   = "Kopiere diese Zeichenkette, um deine Konfiguration zu teilen.",
    OPT_IMPORT_HINT   = "Zeichenkette einfuegen, dann auf Importieren klicken.",

    BINDING_HEADER    = "MiniHub",
    BINDING_TOGGLE    = "Behaelter oeffnen / schliessen",
}

--------------------------------------------------------------------------------
-- Espanol
--------------------------------------------------------------------------------
local esES = {
    ADDON_SUBTITLE   = "Agrupa los iconos de minimapa de tus addons en un unico contenedor ordenado y plegable.",
    EMPTY            = "Ningun boton recogido",
    EMPTY_CONFLICT   = "%s ya gestiona los botones del minimapa por su cuenta - MiniHub se aparta.",
    MSG_CONFLICT_LOGIN = "%s ya gestiona los botones del minimapa - MiniHub se mantiene al margen (contenedor oculto). Escribe /minihub para abrirlo manualmente si aun quieres usarlo.",

    TT_LEFT_TOGGLE   = "Clic izquierdo: abrir / cerrar",
    TT_RIGHT_OPTIONS = "Clic derecho: opciones",
    TT_MIDDLE_RESCAN = "Clic central: volver a escanear",
    TT_DRAG_MOVE     = "Arrastrar: mover el boton",

    MSG_COMBAT_OPTIONS = "no se pueden abrir las opciones en combate. Intentalo de nuevo despues del combate.",
    MSG_RESCAN       = "reescaneo completado (%d botones recogidos).",
    MSG_RESET        = "posiciones del contenedor y del boton principal reiniciadas.",
    MSG_BLOCK        = "\"%s\" ahora se ignora (usa /reload).",
    MSG_UNBLOCK      = "\"%s\" ya no se ignora.",
    MSG_ADD          = "\"%s\" anadido manualmente.",
    MSG_IMPORT_OK    = "perfil importado. Usa /reload para aplicarlo.",
    MSG_IMPORT_FAIL  = "error de importacion: cadena invalida.",

    SLASH_HELP       = "comandos:",
    SLASH_TOGGLE     = "abrir / cerrar el contenedor",
    SLASH_SCAN       = "volver a escanear los botones del minimapa",
    SLASH_RESET      = "recentrar el contenedor y el boton principal",
    SLASH_CONFIG     = "abrir las opciones",
    SLASH_DEBUG      = "listar los elementos del minimapa (diagnostico)",
    SLASH_BLOCK      = "ignorar un boton",
    SLASH_ADD        = "forzar la recogida de un boton por nombre",

    OPT_GENERAL      = "General",
    OPT_LAYOUT       = "Disposicion",
    OPT_APPEARANCE   = "Apariencia",
    OPT_BEHAVIOR     = "Comportamiento",
    OPT_ORIENTATION  = "Orientacion: %s",
    OPT_VERTICAL     = "Vertical",
    OPT_HORIZONTAL   = "Horizontal",
    OPT_COLUMNS      = "Numero de columnas",
    OPT_ROWS         = "Numero de filas",
    OPT_BUTTON_SIZE  = "Tamano de celda",
    OPT_SPACING      = "Espaciado",
    OPT_BG_OPACITY   = "Opacidad del fondo (%)",
    OPT_MAIN_SIZE    = "Tamano del boton principal",
    OPT_MAIN_OPACITY = "Opacidad del boton principal (%)",
    OPT_SHOW_TITLE   = "Mostrar la barra de titulo",
    OPT_LOCK         = "Bloquear la posicion del contenedor",
    OPT_SHOW_MINIMAP = "Mostrar el boton del minimapa",
    OPT_HIDE_ZOOM    = "Ocultar los botones de zoom de Blizzard (+/-)",
    OPT_HIDE_ZOOM_TT = "El zoom sigue disponible con la rueda del raton.",
    OPT_SHOW_MAIN    = "Mostrar el boton principal movible (logo)",
    OPT_SHOW_MAIN_TT = "Un boton con logo, que se puede mover por toda la interfaz, para abrir/cerrar el contenedor.",
    OPT_RESCAN       = "Reescanear",
    OPT_RECENTER     = "Recentrar",
    OPT_EXCL_TITLE   = "Dejar en el minimapa",
    OPT_EXCL_HINT    = "Marca un boton para excluirlo del contenedor.",

    OPT_THEME        = "Tema: %s",
    THEME_DARK       = "WeeklyCompass oscuro",
    THEME_GOLD       = "TibiSuite dorado",
    THEME_GLASS      = "Cristal esmerilado",
    THEME_MINIMAL    = "Minimal",
    OPT_BG_COLOR     = "Color de fondo",
    OPT_BORDER_COLOR = "Color del borde",

    OPT_HOVER_OPEN   = "Abrir al pasar el raton",
    OPT_HOVER_OPEN_TT= "Abre el contenedor al pasar el raton sobre el boton principal.",
    OPT_AUTO_CLOSE   = "Cierre automatico cuando el raton sale",
    OPT_ANIMATE      = "Animacion de fundido al abrir",
    OPT_HIDE_COMBAT  = "Ocultar en combate",
    OPT_HIDE_INSTANCE= "Ocultar en mazmorras/bandas",
    OPT_HIDE_PETBATTLE = "Ocultar durante combates de mascotas",

    OPT_UNKNOWN_TITLE = "Botones no reconocidos",
    OPT_UNKNOWN_HINT  = "Botones encontrados en el minimapa que no fueron recogidos. Marcalos para recogerlos.",
    OPT_NONE_UNKNOWN  = "Ninguno detectado.",
    OPT_PROFILE_TITLE = "Compartir perfil",
    OPT_EXPORT        = "Exportar",
    OPT_IMPORT        = "Importar",
    OPT_EXPORT_HINT   = "Copia esta cadena para compartir tu configuracion.",
    OPT_IMPORT_HINT   = "Pega una cadena y luego haz clic en Importar.",

    BINDING_HEADER    = "MiniHub",
    BINDING_TOGGLE    = "Abrir / cerrar el contenedor",
}

--------------------------------------------------------------------------------
-- Construction de la table L
--------------------------------------------------------------------------------
local L = {}
for k, v in pairs(enUS) do L[k] = v end
if GetLocale() == "frFR" then
    for k, v in pairs(frFR) do L[k] = v end
elseif GetLocale() == "deDE" then
    for k, v in pairs(deDE) do L[k] = v end
elseif GetLocale() == "esES" or GetLocale() == "esMX" then
    for k, v in pairs(esES) do L[k] = v end
end
-- Chaine manquante -> on renvoie la cle (jamais nil).
setmetatable(L, { __index = function(_, k) return k end })

MiniHub.L = L
ns.L = L

-- Libelles localises du raccourci clavier (lus par l'interface Blizzard).
_G["BINDING_HEADER_MINIHUB"]      = L["BINDING_HEADER"]
_G["BINDING_NAME_MINIHUB_TOGGLE"] = L["BINDING_TOGGLE"]
