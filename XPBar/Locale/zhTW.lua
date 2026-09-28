-- XPBar - Locale/zhTW.lua : surcharge chinois traditionnel (base anglaise dans enUS.lua).
-- Traduction non relue par un joueur natif : a faire valider.
if GetLocale() ~= "zhTW" then return end
XPBarL = XPBarL or {}
local L = XPBarL

for k, v in pairs({
    LEVEL = "等級", LEVEL_SHORT = "等級", XP = "經驗",
    PROGRESS = "進度", REMAINING = "剩餘", RESTED = "休息",
    QUESTS = "任務", QUESTS_DONE = "已完成任務", SESSION = "本次遊戲",
    XP_PER_HOUR = "經驗/小時", XP_PER_HOUR_ROLL = "經驗/小時（近期）",
    TIME_LEFT = "剩餘時間", PLAYED = "遊戲時間",
    LEVELS_GAINED = "已升級數", QUESTS_TURNED = "已交任務",
    HINT = "|cffFFD700Shift+拖曳|r 移動  ·  |cffFFD700Shift+右鍵|r 選項",
    POS_SAVED = "位置已儲存。", POS_RESET = "位置已重置。",
    SESSION_RESET = "本次遊戲統計已重置。", XP_DISABLED = "經驗已鎖定",
    COLON = "：",

    OPT_TITLE = "XPBar - 選項",
    OPT_HINT = "在經驗條上 |cffFFD700Shift+拖曳|r 可移動，|cffFFD700Shift+右鍵|r 開啟或關閉此面板。",
    OPT_SEC_DIMENSIONS = "尺寸", OPT_WIDTH_2 = "寬度", OPT_HEIGHT_2 = "高度",
    OPT_SEC_APPEARANCE = "外觀", OPT_OPACITY_2 = "背景不透明度 (%)",
    OPT_FONTSIZE_2 = "文字大小",
    OPT_COL_BAR = "經驗條顏色", OPT_COL_QUEST = "已完成任務顏色",
    OPT_COL_RESTED = "休息經驗顏色", OPT_COL_INC = "未完成任務顏色",
    OPT_DISPLAY = "顯示", OPT_PLAYED_2 = "總遊戲時間", OPT_SESSION = "本次遊戲時間",
    OPT_XPPERHOUR = "每小時經驗", OPT_LEVELING_2 = "預計升級時間",
    OPT_ROLLING_2 = "最近15分鐘的經驗/小時", OPT_COMPLETED_2 = "已完成任務 (%)",
    OPT_RESTED_TXT = "休息經驗 (%)", OPT_INCBAR_2 = "未完成任務條",
    OPT_SEC_VISIBILITY = "可見性", OPT_SHOWBAR = "顯示經驗條",
    OPT_MAXLEVEL = "滿級時仍顯示",
    OPT_HIDENATIVE = "隱藏內建的條（經驗和聲望）",
    OPT_HIDECOMBAT = "戰鬥中隱藏", OPT_HIDEVEHICLE = "載具中隱藏",
    OPT_MOUSEOVER = "僅在滑鼠懸停時顯示",
    OPT_SEC_ORIENTATION = "方向", OPT_VERTBAR = "直向經驗條",
    OPT_VERTTEXT_2 = "文字顯示在條旁（直向）",
    OPT_VTHICK_2 = "粗細（直向）", OPT_VLENGTH_2 = "長度（直向）",
    OPT_SEC_SESSION = "本次遊戲", OPT_RESETRELOAD = "每次 /reload 時重置統計",
    OPT_RESETSESS = "重置本次統計", OPT_RESETPOS = "重置位置",
    OPT_SEC_FLOATING = "浮動按鈕", OPT_HIDE_OPTIONS_BTN = "隱藏選項按鈕",

    SLASH_HIDDEN = "已隱藏。輸入 /xpbar show 重新顯示。",
    SLASH_HELP = " /xpbar - 選項  |  /xpbar hide/show  |  /xpbar session  |  /xpbar reset",
    SLASH_HELP_DBG = "  /xpbar debug - 檢查內建經驗條框架",
    LOGIN_LOADED = "已載入 -- 輸入", LOGIN_TO_OPEN = "開啟選項。",
    DEBUG_HEADER = "內建經驗條框架：", DEBUG_HIDDEN = "隱藏", DEBUG_MISSING = "不存在",
    MM_TT_LEFT = "左鍵：顯示/隱藏", MM_TT_RIGHT = "右鍵：選項",
}) do L[k] = v end

-- Lot 3 : progression enrichie, historique, reputation au niveau max, styles
for k, v in pairs({
    QUEST_XP = "已完成任務經驗", PROJ_XP = "進行中任務經驗",
    QUEST_LEVELUP = "交付已完成的任務就足以升級！",
    LEVEL_TIME = "本級已用時間", PREV_LEVEL = "%d級用時",
    KILLS_LEFT = "剩餘怪物（估算）", QUESTS_LEFT = "剩餘任務（估算）",
    LEVEL_REACHED = "已達到%d級：%d級用時 %s。",
    HISTORY_HEADER = "每級遊戲時間（%s）：",
    HISTORY_EMPTY = "此角色尚無等級紀錄（需在啟用 XPBar 時升一級）。",
    NO_WATCHED_REP = "未追蹤聲望", PARAGON = "巔峰", RENOWN = "名望",
    OPT_SEC_PROGRESS = "進度",
    OPT_QUESTXP = "已完成任務的實際經驗（橘色）",
    OPT_PROJECTION = "進行中任務預估",
    OPT_RESTZONE = "休息加成區域與標記",
    OPT_TICKS = "每 10% 刻度", OPT_FLOATXP = "獲得經驗時顯示浮動文字",
    OPT_ESTIMATES = "剩餘怪物與任務（提示）",
    OPT_REPATMAX = "滿級時顯示追蹤的聲望",
    OPT_REPATMAX_TT = "滿級時，經驗條會顯示追蹤的聲望（在聲望面板中勾選的那個），而不是消失。",
    OPT_CLASSCOLOR = "經驗條使用職業顏色",
    OPT_SEC_PRESETS = "預設樣式", OPT_PRESET_THIN = "纖細樣式（8 像素）",
    OPT_PRESET_CLASSIC = "經典樣式", OPT_PRESET_VERTICAL = "直向樣式",
    OPT_COL_INC = "進行中任務顏色",
    SLASH_HELP = " /xpbar - 選項  |  /xpbar hide/show  |  /xpbar session  |  /xpbar history  |  /xpbar reset",
}) do L[k] = v end
