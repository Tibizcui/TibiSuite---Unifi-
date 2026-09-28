-- XPBar - Locale/ruRU.lua : surcharge russe (base anglaise dans enUS.lua).
-- Traduction non relue par un joueur natif : a faire valider.
if GetLocale() ~= "ruRU" then return end
XPBarL = XPBarL or {}
local L = XPBarL

for k, v in pairs({
    LEVEL = "Уровень", LEVEL_SHORT = "Ур.", XP = "Опыт",
    PROGRESS = "Прогресс", REMAINING = "Осталось", RESTED = "Отдых",
    QUESTS = "Задания", QUESTS_DONE = "Выполненные задания", SESSION = "Сеанс",
    XP_PER_HOUR = "Опыт/час", XP_PER_HOUR_ROLL = "Опыт/ч (недавно)",
    TIME_LEFT = "Осталось времени", PLAYED = "Сыграно",
    LEVELS_GAINED = "Получено уровней", QUESTS_TURNED = "Сдано заданий",
    HINT = "|cffFFD700Shift+перетаскивание|r переместить  ·  |cffFFD700Shift+ПКМ|r настройки",
    POS_SAVED = "Позиция сохранена.", POS_RESET = "Позиция сброшена.",
    SESSION_RESET = "Сеанс сброшен.", XP_DISABLED = "Опыт заблокирован",

    OPT_TITLE = "XPBar - Настройки",
    OPT_HINT = "|cffFFD700Shift+перетаскивание|r полосы, чтобы переместить её, |cffFFD700Shift+ПКМ|r, чтобы открыть или закрыть эту панель.",
    OPT_SEC_DIMENSIONS = "Размеры", OPT_WIDTH_2 = "Ширина", OPT_HEIGHT_2 = "Высота",
    OPT_SEC_APPEARANCE = "Внешний вид", OPT_OPACITY_2 = "Непрозрачность фона (%)",
    OPT_FONTSIZE_2 = "Размер текста",
    OPT_COL_BAR = "Цвет полосы опыта", OPT_COL_QUEST = "Цвет выполненных заданий",
    OPT_COL_RESTED = "Цвет отдыха", OPT_COL_INC = "Цвет невыполненных заданий",
    OPT_DISPLAY = "Отображение", OPT_PLAYED_2 = "Общее время в игре", OPT_SESSION = "Время сеанса",
    OPT_XPPERHOUR = "Опыт в час", OPT_LEVELING_2 = "Примерное время до следующего уровня",
    OPT_ROLLING_2 = "Опыт/ч за последние 15 минут", OPT_COMPLETED_2 = "Выполненные задания (%)",
    OPT_RESTED_TXT = "Опыт отдыха (%)", OPT_INCBAR_2 = "Полоса невыполненных заданий",
    OPT_SEC_VISIBILITY = "Видимость", OPT_SHOWBAR = "Показывать полосу",
    OPT_MAXLEVEL = "Показывать на макс. уровне",
    OPT_HIDENATIVE = "Скрыть стандартные полосы (опыт и репутация)",
    OPT_HIDECOMBAT = "Скрывать в бою", OPT_HIDEVEHICLE = "Скрывать в транспорте",
    OPT_MOUSEOVER = "Показывать только при наведении",
    OPT_SEC_ORIENTATION = "Ориентация", OPT_VERTBAR = "Вертикальная полоса",
    OPT_VERTTEXT_2 = "Текст рядом с полосой (вертикально)",
    OPT_VTHICK_2 = "Толщина (вертикально)", OPT_VLENGTH_2 = "Длина (вертикально)",
    OPT_SEC_SESSION = "Сеанс", OPT_RESETRELOAD = "Сбрасывать сеанс при каждом /reload",
    OPT_RESETSESS = "Сбросить сеанс", OPT_RESETPOS = "Сбросить позицию",
    OPT_SEC_FLOATING = "Плавающая кнопка", OPT_HIDE_OPTIONS_BTN = "Скрыть кнопку настроек",

    SLASH_HIDDEN = "Скрыто. /xpbar show, чтобы показать снова.",
    SLASH_HELP = " /xpbar - настройки  |  /xpbar hide/show  |  /xpbar session  |  /xpbar reset",
    SLASH_HELP_DBG = "  /xpbar debug - проверить стандартные фреймы опыта",
    LOGIN_LOADED = "загружен -- введите", LOGIN_TO_OPEN = "для настроек.",
    DEBUG_HEADER = "Стандартные фреймы опыта:", DEBUG_HIDDEN = "скрыт", DEBUG_MISSING = "отсутствует",
    MM_TT_LEFT = "ЛКМ: показать/скрыть", MM_TT_RIGHT = "ПКМ: настройки",
}) do L[k] = v end

-- Lot 3 : progression enrichie, historique, reputation au niveau max, styles
for k, v in pairs({
    QUEST_XP = "Опыт за выполненные задания", PROJ_XP = "Опыт за текущие задания",
    QUEST_LEVELUP = "Сдачи выполненных заданий хватит для нового уровня!",
    LEVEL_TIME = "Время на этом уровне", PREV_LEVEL = "Уровень %d пройден за",
    KILLS_LEFT = "Осталось противников (оценка)", QUESTS_LEFT = "Осталось заданий (оценка)",
    LEVEL_REACHED = "Достигнут уровень %d: уровень %d занял %s игрового времени.",
    HISTORY_HEADER = "Игровое время по уровням (%s):",
    HISTORY_EMPTY = "Для этого персонажа ещё нет записанных уровней (получите уровень с включённым XPBar).",
    NO_WATCHED_REP = "Репутация не отслеживается", PARAGON = "Идеал", RENOWN = "Известность",
    OPT_SEC_PROGRESS = "Прогресс",
    OPT_QUESTXP = "Реальный опыт за выполненные задания (оранжевый)",
    OPT_PROJECTION = "Прогноз по текущим заданиям",
    OPT_RESTZONE = "Зона и метка бонуса отдыха",
    OPT_TICKS = "Деления каждые 10 %", OPT_FLOATXP = "Всплывающий текст при получении опыта",
    OPT_ESTIMATES = "Осталось противников и заданий (подсказка)",
    OPT_REPATMAX = "Отслеживаемая репутация на макс. уровне",
    OPT_REPATMAX_TT = "На максимальном уровне полоса показывает отслеживаемую репутацию (отмеченную в окне репутации), а не исчезает.",
    OPT_CLASSCOLOR = "Полоса цвета класса",
    OPT_SEC_PRESETS = "Готовые стили", OPT_PRESET_THIN = "Стиль «Тонкий» (8 px)",
    OPT_PRESET_CLASSIC = "Стиль «Классика»", OPT_PRESET_VERTICAL = "Стиль «Вертикальный»",
    OPT_COL_INC = "Цвет текущих заданий",
    SLASH_HELP = " /xpbar - настройки  |  /xpbar hide/show  |  /xpbar session  |  /xpbar history  |  /xpbar reset",
}) do L[k] = v end
