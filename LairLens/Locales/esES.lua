-- =============================================================================
-- LairLens - Locales/esES.lua
-- Surcharge ES. Ne s'applique que si le client tourne en espagnol.
-- =============================================================================

local ADDON, LL = ...
if GetLocale() ~= "esES" and GetLocale() ~= "esMX" then return end
local L = LL.L

L["AUDIT_TITLE"]        = "Auditoria del grupo"
L["AUDIT_NO_GROUP"]     = "No estas en grupo"
L["AUDIT_NO_LAIR"]      = "Fuera de una Guarida"

L["DIFF_WORLD"]         = "Mundo"
L["DIFF_NORMAL"]        = "Normal"
L["DIFF_HEROIC"]        = "Heroica"
L["DIFF_MYTHIC"]        = "Mitica"

L["ROLES"]              = "Roles"
L["TANKS"]              = "Tanques"
L["HEALERS"]            = "Sanadores"
L["COMBAT_REZ"]         = "Resurreccion en combate"
L["LUST"]               = "Lust / Heroismo"
L["INTERRUPTS"]         = "Interrupciones"
L["DISPELS"]            = "Disipaciones"

L["DISPEL_MAGIC"]       = "Magia"
L["DISPEL_CURSE"]       = "Maldicion"
L["DISPEL_POISON"]      = "Veneno"
L["DISPEL_DISEASE"]     = "Enfermedad"

L["PRESENT"]            = "Presente"
L["ABSENT"]             = "Ausente"
L["NONE"]               = "Ninguno"

L["VERDICT_VIABLE"]     = "Grupo viable"
L["VERDICT_RISKY"]      = "Jugable, pero justo"
L["VERDICT_MISSING"]    = "Falta: %s"

L["MISS_TANK"]          = "un tanque"
L["MISS_HEALER"]        = "sanadores (%d/%d)"
L["MISS_COMBAT_REZ"]    = "una resurreccion en combate"
L["MISS_LUST"]          = "el Lust/Heroismo"
L["MISS_INTERRUPT"]     = "interrupciones"

L["REWARD_TITLE"]       = "Relevancia de las recompensas"
L["REWARD_WORTH"]       = "Merece la pena"
L["REWARD_SKIP"]        = "Puedes saltartelo"
L["REWARD_DONE_WEEK"]   = "Ya completado esta semana"
L["REWARD_NO_DATA"]     = "Datos de botin aun no disponibles"

-- Dashboard (historial de carreras)
L["DASH_TITLE"]           = "Historial de Guaridas"
L["DASH_RUNS"]            = "Carreras"
L["DASH_TIME"]            = "Tiempo"
L["DASH_ATTEMPTS"]        = "Intentos"
L["DASH_KILLS"]           = "Muertes"
L["DASH_FILTER_OWNER"]    = "Personaje"
L["DASH_FILTER_DIFF"]     = "Dificultad"
L["DASH_FILTER_INSTANCE"] = "Guarida"
L["DASH_ALL"]             = "Todos"
L["DASH_SEARCH"]          = "Buscar..."
L["DASH_EMPTY"]           = "Todavia no hay ninguna carrera registrada."
L["DASH_COL_DATE"]        = "Fecha"
L["DASH_COL_LAIR"]        = "Guarida"
L["DASH_COL_DIFF"]        = "Dif."
L["DASH_COL_TIME"]        = "Tiempo"
L["DASH_COL_TRIES"]       = "Int."
L["DASH_COL_RESULT"]      = "Resultado"
L["DASH_ILVL"]            = "nivel obj."
L["DASH_OPEN_TT"]         = "Abrir el panel de historial de carreras."
L["DASH_CLEAR"]           = "Borrar historial"
L["DASH_CLEAR_CONFIRM"]   = "Vuelve a hacer clic para confirmar"
L["RUN_KILL"]             = "Muerte"
L["RUN_INCOMPLETE"]       = "Incompleto"

L["SLASH_HELP"]         = "Comandos: /ll config, /ll show, /ll dash, /ll sim, /ll lock, /ll reset, /ll debug"
L["FRAME_LOCKED"]       = "Panel bloqueado."
L["FRAME_UNLOCKED"]     = "Panel desbloqueado (arrastra para mover)."

-- Ajustes
L["OPT_TITLE"]          = "Ajustes"
L["OPT_ENABLED"]        = "Activar LairLens"
L["OPT_ENABLED_TT"]     = "Interruptor principal del addon."
L["OPT_HIDE_OUT"]       = "Ocultar fuera de una Guarida"
L["OPT_HIDE_OUT_TT"]    = "Muestra el panel solo dentro de una Guarida."
L["OPT_FADE_COMBAT"]    = "Atenuar en combate"
L["OPT_FADE_COMBAT_TT"] = "Atenua el panel durante el combate para ser discreto."
L["OPT_LOCK"]           = "Bloquear posicion"
L["OPT_LOCK_TT"]        = "Impide que el panel se pueda arrastrar."
L["OPT_SCALE"]          = "Escala"
L["OPT_UNAVAILABLE"]    = "Panel de ajustes no disponible en este cliente. Usa los comandos de barra."
