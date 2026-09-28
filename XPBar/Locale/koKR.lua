-- XPBar - Locale/koKR.lua : surcharge coreenne (base anglaise dans enUS.lua).
-- Traduction non relue par un joueur natif : a faire valider.
if GetLocale() ~= "koKR" then return end
XPBarL = XPBarL or {}
local L = XPBarL

for k, v in pairs({
    LEVEL = "레벨", LEVEL_SHORT = "Lv", XP = "경험치",
    PROGRESS = "진행도", REMAINING = "남은 경험치", RESTED = "휴식",
    QUESTS = "퀘스트", QUESTS_DONE = "완료한 퀘스트", SESSION = "세션",
    XP_PER_HOUR = "경험치/시간", XP_PER_HOUR_ROLL = "경험치/시간 (최근)",
    TIME_LEFT = "남은 시간", PLAYED = "플레이 시간",
    LEVELS_GAINED = "오른 레벨", QUESTS_TURNED = "완료 보고한 퀘스트",
    HINT = "|cffFFD700Shift+드래그|r 이동  ·  |cffFFD700Shift+우클릭|r 설정",
    POS_SAVED = "위치가 저장되었습니다.", POS_RESET = "위치가 초기화되었습니다.",
    SESSION_RESET = "세션이 초기화되었습니다.", XP_DISABLED = "경험치 잠김",

    OPT_TITLE = "XPBar - 설정",
    OPT_HINT = "바 위에서 |cffFFD700Shift+드래그|r로 이동하고, |cffFFD700Shift+우클릭|r으로 이 창을 열거나 닫습니다.",
    OPT_SEC_DIMENSIONS = "크기", OPT_WIDTH_2 = "너비", OPT_HEIGHT_2 = "높이",
    OPT_SEC_APPEARANCE = "모양", OPT_OPACITY_2 = "배경 불투명도 (%)",
    OPT_FONTSIZE_2 = "글자 크기",
    OPT_COL_BAR = "경험치 바 색상", OPT_COL_QUEST = "완료한 퀘스트 색상",
    OPT_COL_RESTED = "휴식 경험치 색상", OPT_COL_INC = "미완료 퀘스트 색상",
    OPT_DISPLAY = "표시", OPT_PLAYED_2 = "총 플레이 시간", OPT_SESSION = "세션 시간",
    OPT_XPPERHOUR = "시간당 경험치", OPT_LEVELING_2 = "다음 레벨까지 예상 시간",
    OPT_ROLLING_2 = "최근 15분 기준 경험치/시간", OPT_COMPLETED_2 = "완료한 퀘스트 (%)",
    OPT_RESTED_TXT = "휴식 경험치 (%)", OPT_INCBAR_2 = "미완료 퀘스트 바",
    OPT_SEC_VISIBILITY = "표시 조건", OPT_SHOWBAR = "바 표시",
    OPT_MAXLEVEL = "최고 레벨에서도 표시",
    OPT_HIDENATIVE = "기본 바 숨기기 (경험치 및 평판)",
    OPT_HIDECOMBAT = "전투 중 숨기기", OPT_HIDEVEHICLE = "차량 탑승 중 숨기기",
    OPT_MOUSEOVER = "마우스를 올릴 때만 표시",
    OPT_SEC_ORIENTATION = "방향", OPT_VERTBAR = "세로 바",
    OPT_VERTTEXT_2 = "바 옆에 글자 표시 (세로)",
    OPT_VTHICK_2 = "두께 (세로)", OPT_VLENGTH_2 = "길이 (세로)",
    OPT_SEC_SESSION = "세션", OPT_RESETRELOAD = "/reload 할 때마다 세션 초기화",
    OPT_RESETSESS = "세션 초기화", OPT_RESETPOS = "위치 초기화",
    OPT_SEC_FLOATING = "떠 있는 버튼", OPT_HIDE_OPTIONS_BTN = "설정 버튼 숨기기",

    SLASH_HIDDEN = "숨겨졌습니다. /xpbar show 로 다시 표시합니다.",
    SLASH_HELP = " /xpbar - 설정  |  /xpbar hide/show  |  /xpbar session  |  /xpbar reset",
    SLASH_HELP_DBG = "  /xpbar debug - 기본 경험치 프레임 확인",
    LOGIN_LOADED = "로드됨 -- 입력:", LOGIN_TO_OPEN = "(설정 열기)",
    DEBUG_HEADER = "기본 경험치 프레임:", DEBUG_HIDDEN = "숨김", DEBUG_MISSING = "없음",
    MM_TT_LEFT = "좌클릭: 표시/숨기기", MM_TT_RIGHT = "우클릭: 설정",
}) do L[k] = v end

-- Lot 3 : progression enrichie, historique, reputation au niveau max, styles
for k, v in pairs({
    QUEST_XP = "완료한 퀘스트 경험치", PROJ_XP = "진행 중인 퀘스트 경험치",
    QUEST_LEVELUP = "완료한 퀘스트만 보고해도 레벨업할 수 있습니다!",
    LEVEL_TIME = "현재 레벨 소요 시간", PREV_LEVEL = "%d레벨 소요 시간",
    KILLS_LEFT = "남은 처치 수 (추정)", QUESTS_LEFT = "남은 퀘스트 수 (추정)",
    LEVEL_REACHED = "%d레벨 달성: %d레벨에 %s 플레이했습니다.",
    HISTORY_HEADER = "레벨별 플레이 시간 (%s):",
    HISTORY_EMPTY = "이 캐릭터의 레벨 기록이 아직 없습니다 (XPBar를 켠 상태로 레벨업하세요).",
    NO_WATCHED_REP = "추적 중인 평판 없음", PARAGON = "불멸", RENOWN = "명성",
    OPT_SEC_PROGRESS = "진행",
    OPT_QUESTXP = "완료한 퀘스트의 실제 경험치 (주황색)",
    OPT_PROJECTION = "진행 중인 퀘스트 예상치",
    OPT_RESTZONE = "휴식 보너스 구간 및 표시",
    OPT_TICKS = "10% 단위 눈금", OPT_FLOATXP = "경험치 획득 시 떠오르는 글자",
    OPT_ESTIMATES = "남은 처치 및 퀘스트 수 (툴팁)",
    OPT_REPATMAX = "최고 레벨에서 추적 중인 평판 표시",
    OPT_REPATMAX_TT = "최고 레벨에서는 바가 사라지는 대신 추적 중인 평판(평판 창에서 선택한 것)을 표시합니다.",
    OPT_CLASSCOLOR = "직업 색상으로 바 표시",
    OPT_SEC_PRESETS = "기본 제공 스타일", OPT_PRESET_THIN = "얇은 스타일 (8 px)",
    OPT_PRESET_CLASSIC = "클래식 스타일", OPT_PRESET_VERTICAL = "세로 스타일",
    OPT_COL_INC = "진행 중인 퀘스트 색상",
    SLASH_HELP = " /xpbar - 설정  |  /xpbar hide/show  |  /xpbar session  |  /xpbar history  |  /xpbar reset",
}) do L[k] = v end
