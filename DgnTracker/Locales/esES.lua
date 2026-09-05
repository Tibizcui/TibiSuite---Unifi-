-- =============================================================================
-- DgnTracker - Locales/esES.lua
-- Surcharge ES. Ne s'applique que si le client tourne en espagnol.
-- =============================================================================

if GetLocale() ~= "esES" and GetLocale() ~= "esMX" then return end
DgnTrackerL = DgnTrackerL or {}
local L = DgnTrackerL

L["WP_NO_COORDS"]        = "coordenadas no disponibles para"
L["WP_TOMTOM_LABEL"]     = "waypoint"
L["WP_MAP_LABEL"]        = "waypoint"
L["WP_MAP_WORD"]         = "mapa"
L["WP_OPEN_MAP_HINT"]    = "(abre el mapa para verlo)"
L["WP_NATIVE_FAIL"]      = "no se pudo colocar un waypoint nativo en esta zona. Instala |cFFFFD700TomTom|r para un puntero completo."
L["WP_NONE_AVAILABLE"]   = "ningun sistema de waypoint disponible. Instala |cFFFFD700TomTom|r."
L["DRAG_HINT"]           = "Arrastrar para mover"
L["INSTANCES_WORD"]      = "instancia(s)"
L["SEARCH_PLACEHOLDER"]  = "Buscar..."
L["EXTENSION_LABEL"]     = "Expansion:"
L["LEFT_CLICK_LABEL"]    = "Clic izquierdo"
L["CLOSE_WORD"]          = "cerrar"
L["SHOW_PATH_WORD"]      = "mostrar el camino"
L["RIGHT_CLICK_LABEL"]   = "Clic derecho"
L["SET_WAYPOINT_HINT"]   = "colocar un waypoint"
L["NO_RESULT_FOR"]       = "Ningun resultado para"
L["NO_INSTANCE_CATEGORY"]= "Ninguna instancia disponible para esta categoria."
L["ACCESS_HEADER"]       = "-- Acceso (camino mas corto):"
L["TIPS_HEADER"]         = "-- Consejos:"
L["MM_TT_SUBTITLE"]      = "Seguimiento de mazmorras y bandas"
L["TOGGLE_HINT"]         = "abrir / cerrar"
L["DRAG_LABEL"]          = "Arrastrar"
L["REPOSITION_HINT"]     = "reposicionar el icono"
L["CLICK_LABEL"]         = "Clic"

L["HELP_COMMANDS_LABEL"] = "comandos:"
L["HELP_TOGGLE"]         = "Abrir/cerrar la ventana"
L["HELP_OPTIONS"]        = "Abrir las opciones"
L["HELP_MAP_ON"]         = "Waypoint automatico al abrir una instancia"
L["HELP_MAP_OFF"]        = "Desactivar el waypoint automatico"
L["HELP_EXTENSION"]      = "Ir a una expansion (ej.: tww, df, sl, van)"
L["HELP_EXPAND"]         = "Expandir todo (expansion activa)"
L["HELP_RESET"]          = "Contraer todo (acordeon)"
L["HELP_TIP"]            = "Consejo: clic derecho en una instancia para colocar un waypoint."

L["ACCORDION_RESET"]     = "acordeon reiniciado."
L["EXPANDED_ALL_FOR"]    = "todo expandido para"
L["AUTO_WAYPOINT_LABEL"] = "waypoint automatico"
L["ENABLED_WORD"]        = "activado"
L["ON_INSTANCE_OPEN"]    = "(al abrir una instancia)"
L["DISABLED_WORD"]       = "desactivado"
L["EXTENSION_ARROW"]     = "expansion ->"
L["UNKNOWN_COMMAND"]     = "comando desconocido. Escribe |cFFFFD700/dg help|r."
L["LOGIN_LOADED"]        = "cargado --"
L["LOGIN_TO_OPEN"]       = "para abrir."

-- Opciones (DgnTracker_Suite.lua) y nombre del modulo
L["OPT_SEC_WINDOW"]      = "Ventana"
L["OPT_TOGGLE"]          = "Abrir / cerrar"
L["OPT_RECENTER"]        = "Recentrar la ventana"
L["OPT_SEC_BEHAVIOR"]    = "Comportamiento"
L["OPT_AUTO_WAYPOINT"]   = "Waypoint automatico al abrir una instancia"
L["OPT_SEC_FLOATING"]    = "Botones flotantes (barra TibiSuite)"
L["OPT_HIDE_OPTIONS_BTN"]= "Ocultar el boton Opciones"
L["OPT_HIDE_SEARCH_BTN"] = "Ocultar el campo de busqueda"
L["OPT_FLOATING_NOTE"]   = "El boton Opciones y el campo de busqueda sobresalen encima de la ventana. Aunque esten ocultos, Mayus+clic derecho en la ventana abre estas opciones."
L["OPT_NOTE"]            = "Consejo: clic derecho en la pestana Mazmorras de la barra TibiSuite tambien abre estas opciones."
L["SEARCH_TITLE"]        = "Busqueda"
L["MODULE_LABEL"]        = "Mazmorras"
