-- XPBar - Locale/ptBR.lua : surcharge portugais du Bresil (base anglaise dans enUS.lua).
-- Traduction non relue par un joueur natif : a faire valider.
if GetLocale() ~= "ptBR" then return end
XPBarL = XPBarL or {}
local L = XPBarL

for k, v in pairs({
    LEVEL = "Nível", LEVEL_SHORT = "Nv", XP = "XP",
    PROGRESS = "Progresso", REMAINING = "Restante", RESTED = "Descansado",
    QUESTS = "Missões", QUESTS_DONE = "Missões concluídas", SESSION = "Sessão",
    XP_PER_HOUR = "XP/hora", XP_PER_HOUR_ROLL = "XP/h (recente)",
    TIME_LEFT = "Tempo restante", PLAYED = "Jogado",
    LEVELS_GAINED = "Níveis ganhos", QUESTS_TURNED = "Missões entregues",
    HINT = "|cffFFD700Shift+Arrastar|r mover  ·  |cffFFD700Shift+Clique direito|r opções",
    POS_SAVED = "Posição salva.", POS_RESET = "Posição redefinida.",
    SESSION_RESET = "Sessão reiniciada.", XP_DISABLED = "XP bloqueada",

    OPT_TITLE = "XPBar - Opções",
    OPT_HINT = "|cffFFD700Shift+Arrastar|r na barra para movê-la, |cffFFD700Shift+Clique direito|r para abrir ou fechar este painel.",
    OPT_SEC_DIMENSIONS = "Dimensões", OPT_WIDTH_2 = "Largura", OPT_HEIGHT_2 = "Altura",
    OPT_SEC_APPEARANCE = "Aparência", OPT_OPACITY_2 = "Opacidade do fundo (%)",
    OPT_FONTSIZE_2 = "Tamanho do texto",
    OPT_COL_BAR = "Cor da barra de XP", OPT_COL_QUEST = "Cor das missões concluídas",
    OPT_COL_RESTED = "Cor do descanso", OPT_COL_INC = "Cor das missões incompletas",
    OPT_DISPLAY = "Exibição", OPT_PLAYED_2 = "Tempo total jogado", OPT_SESSION = "Tempo de sessão",
    OPT_XPPERHOUR = "XP por hora", OPT_LEVELING_2 = "Tempo estimado até o próximo nível",
    OPT_ROLLING_2 = "XP/h dos últimos 15 minutos", OPT_COMPLETED_2 = "Missões concluídas (%)",
    OPT_RESTED_TXT = "XP de descanso (%)", OPT_INCBAR_2 = "Barra de missões incompletas",
    OPT_SEC_VISIBILITY = "Visibilidade", OPT_SHOWBAR = "Mostrar a barra",
    OPT_MAXLEVEL = "Mostrar no nível máximo",
    OPT_HIDENATIVE = "Ocultar as barras nativas (XP e reputação)",
    OPT_HIDECOMBAT = "Ocultar em combate", OPT_HIDEVEHICLE = "Ocultar em veículo",
    OPT_MOUSEOVER = "Mostrar só ao passar o mouse",
    OPT_SEC_ORIENTATION = "Orientação", OPT_VERTBAR = "Barra vertical",
    OPT_VERTTEXT_2 = "Texto ao lado da barra (vertical)",
    OPT_VTHICK_2 = "Espessura (vertical)", OPT_VLENGTH_2 = "Comprimento (vertical)",
    OPT_SEC_SESSION = "Sessão", OPT_RESETRELOAD = "Reiniciar a sessão a cada /reload",
    OPT_RESETSESS = "Reiniciar a sessão", OPT_RESETPOS = "Redefinir a posição",
    OPT_SEC_FLOATING = "Botão flutuante", OPT_HIDE_OPTIONS_BTN = "Ocultar o botão Opções",

    SLASH_HIDDEN = "Oculta. /xpbar show para mostrá-la de novo.",
    SLASH_HELP = " /xpbar - opções  |  /xpbar hide/show  |  /xpbar session  |  /xpbar reset",
    SLASH_HELP_DBG = "  /xpbar debug - inspecionar os quadros de XP nativos",
    LOGIN_LOADED = "carregado -- digite", LOGIN_TO_OPEN = "para as opções.",
    DEBUG_HEADER = "Quadros de XP nativos:", DEBUG_HIDDEN = "oculto", DEBUG_MISSING = "inexistente",
    MM_TT_LEFT = "Clique esquerdo: mostrar/ocultar", MM_TT_RIGHT = "Clique direito: opções",
}) do L[k] = v end

-- Lot 3 : progression enrichie, historique, reputation au niveau max, styles
for k, v in pairs({
    QUEST_XP = "XP das missões concluídas", PROJ_XP = "XP das missões em andamento",
    QUEST_LEVELUP = "Entregar suas missões concluídas basta para subir de nível!",
    LEVEL_TIME = "Tempo neste nível", PREV_LEVEL = "Nível %d concluído em",
    KILLS_LEFT = "Inimigos restantes (estimativa)", QUESTS_LEFT = "Missões restantes (estimativa)",
    LEVEL_REACHED = "Nível %d alcançado: o nível %d levou %s de jogo.",
    HISTORY_HEADER = "Tempo de jogo por nível (%s):",
    HISTORY_EMPTY = "Nenhum nível registrado para este personagem ainda (suba um nível com o XPBar ativo).",
    NO_WATCHED_REP = "Nenhuma reputação acompanhada", PARAGON = "Paragão", RENOWN = "Renome",
    OPT_SEC_PROGRESS = "Progresso",
    OPT_QUESTXP = "XP real das missões concluídas (laranja)",
    OPT_PROJECTION = "Projeção das missões em andamento",
    OPT_RESTZONE = "Zona e marcador do bônus de descanso",
    OPT_TICKS = "Marcas a cada 10 %", OPT_FLOATXP = "Texto flutuante a cada ganho de XP",
    OPT_ESTIMATES = "Inimigos e missões restantes (dica)",
    OPT_REPATMAX = "Reputação acompanhada no nível máximo",
    OPT_REPATMAX_TT = "No nível máximo, a barra mostra a reputação acompanhada (a marcada no painel de Reputação) em vez de sumir.",
    OPT_CLASSCOLOR = "Barra na cor da classe",
    OPT_SEC_PRESETS = "Estilos prontos", OPT_PRESET_THIN = "Estilo Fino (8 px)",
    OPT_PRESET_CLASSIC = "Estilo Clássico", OPT_PRESET_VERTICAL = "Estilo Vertical",
    OPT_COL_INC = "Cor das missões em andamento",
    SLASH_HELP = " /xpbar - opções  |  /xpbar hide/show  |  /xpbar session  |  /xpbar history  |  /xpbar reset",
}) do L[k] = v end
