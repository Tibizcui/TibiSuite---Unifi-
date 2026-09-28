-- XPBar - Locale/zhCN.lua : surcharge chinois simplifie (base anglaise dans enUS.lua).
-- Traduction non relue par un joueur natif : a faire valider.
if GetLocale() ~= "zhCN" then return end
XPBarL = XPBarL or {}
local L = XPBarL

for k, v in pairs({
    LEVEL = "等级", LEVEL_SHORT = "等级", XP = "经验",
    PROGRESS = "进度", REMAINING = "剩余", RESTED = "休息",
    QUESTS = "任务", QUESTS_DONE = "已完成任务", SESSION = "本次游戏",
    XP_PER_HOUR = "经验/小时", XP_PER_HOUR_ROLL = "经验/小时（近期）",
    TIME_LEFT = "剩余时间", PLAYED = "游戏时间",
    LEVELS_GAINED = "已升级数", QUESTS_TURNED = "已交任务",
    HINT = "|cffFFD700Shift+拖动|r 移动  ·  |cffFFD700Shift+右键|r 选项",
    POS_SAVED = "位置已保存。", POS_RESET = "位置已重置。",
    SESSION_RESET = "本次游戏统计已重置。", XP_DISABLED = "经验已锁定",
    COLON = "：",

    OPT_TITLE = "XPBar - 选项",
    OPT_HINT = "在经验条上 |cffFFD700Shift+拖动|r 可移动，|cffFFD700Shift+右键|r 打开或关闭此面板。",
    OPT_SEC_DIMENSIONS = "尺寸", OPT_WIDTH_2 = "宽度", OPT_HEIGHT_2 = "高度",
    OPT_SEC_APPEARANCE = "外观", OPT_OPACITY_2 = "背景不透明度 (%)",
    OPT_FONTSIZE_2 = "文字大小",
    OPT_COL_BAR = "经验条颜色", OPT_COL_QUEST = "已完成任务颜色",
    OPT_COL_RESTED = "休息经验颜色", OPT_COL_INC = "未完成任务颜色",
    OPT_DISPLAY = "显示", OPT_PLAYED_2 = "总游戏时间", OPT_SESSION = "本次游戏时间",
    OPT_XPPERHOUR = "每小时经验", OPT_LEVELING_2 = "预计升级时间",
    OPT_ROLLING_2 = "最近15分钟的经验/小时", OPT_COMPLETED_2 = "已完成任务 (%)",
    OPT_RESTED_TXT = "休息经验 (%)", OPT_INCBAR_2 = "未完成任务条",
    OPT_SEC_VISIBILITY = "可见性", OPT_SHOWBAR = "显示经验条",
    OPT_MAXLEVEL = "满级时仍显示",
    OPT_HIDENATIVE = "隐藏系统自带的条（经验和声望）",
    OPT_HIDECOMBAT = "战斗中隐藏", OPT_HIDEVEHICLE = "载具中隐藏",
    OPT_MOUSEOVER = "仅在鼠标悬停时显示",
    OPT_SEC_ORIENTATION = "方向", OPT_VERTBAR = "竖向经验条",
    OPT_VERTTEXT_2 = "文字显示在条旁（竖向）",
    OPT_VTHICK_2 = "粗细（竖向）", OPT_VLENGTH_2 = "长度（竖向）",
    OPT_SEC_SESSION = "本次游戏", OPT_RESETRELOAD = "每次 /reload 时重置统计",
    OPT_RESETSESS = "重置本次统计", OPT_RESETPOS = "重置位置",
    OPT_SEC_FLOATING = "浮动按钮", OPT_HIDE_OPTIONS_BTN = "隐藏选项按钮",

    SLASH_HIDDEN = "已隐藏。输入 /xpbar show 重新显示。",
    SLASH_HELP = " /xpbar - 选项  |  /xpbar hide/show  |  /xpbar session  |  /xpbar reset",
    SLASH_HELP_DBG = "  /xpbar debug - 检查系统经验条框体",
    LOGIN_LOADED = "已加载 -- 输入", LOGIN_TO_OPEN = "打开选项。",
    DEBUG_HEADER = "系统经验条框体：", DEBUG_HIDDEN = "隐藏", DEBUG_MISSING = "不存在",
    MM_TT_LEFT = "左键：显示/隐藏", MM_TT_RIGHT = "右键：选项",
}) do L[k] = v end

-- Lot 3 : progression enrichie, historique, reputation au niveau max, styles
for k, v in pairs({
    QUEST_XP = "已完成任务经验", PROJ_XP = "进行中任务经验",
    QUEST_LEVELUP = "交付已完成的任务就足以升级！",
    LEVEL_TIME = "本级已用时间", PREV_LEVEL = "%d级用时",
    KILLS_LEFT = "剩余怪物（估算）", QUESTS_LEFT = "剩余任务（估算）",
    LEVEL_REACHED = "已达到%d级：%d级用时 %s。",
    HISTORY_HEADER = "每级游戏时间（%s）：",
    HISTORY_EMPTY = "该角色尚无等级记录（需在启用 XPBar 时升一级）。",
    NO_WATCHED_REP = "未追踪声望", PARAGON = "巅峰", RENOWN = "名望",
    OPT_SEC_PROGRESS = "进度",
    OPT_QUESTXP = "已完成任务的实际经验（橙色）",
    OPT_PROJECTION = "进行中任务预估",
    OPT_RESTZONE = "休息奖励区域与标记",
    OPT_TICKS = "每 10% 刻度", OPT_FLOATXP = "获得经验时显示浮动文字",
    OPT_ESTIMATES = "剩余怪物与任务（提示）",
    OPT_REPATMAX = "满级时显示追踪的声望",
    OPT_REPATMAX_TT = "满级时，经验条会显示追踪的声望（在声望面板中勾选的那个），而不是消失。",
    OPT_CLASSCOLOR = "经验条使用职业颜色",
    OPT_SEC_PRESETS = "预设样式", OPT_PRESET_THIN = "纤细样式（8 像素）",
    OPT_PRESET_CLASSIC = "经典样式", OPT_PRESET_VERTICAL = "竖向样式",
    OPT_COL_INC = "进行中任务颜色",
    SLASH_HELP = " /xpbar - 选项  |  /xpbar hide/show  |  /xpbar session  |  /xpbar history  |  /xpbar reset",
}) do L[k] = v end
