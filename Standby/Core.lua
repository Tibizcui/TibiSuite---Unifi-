--[[============================================================================
  Standby - Core.lua
  ---------------------------------------------------------------------------
  Ecran d'absence. Ce fichier porte la logique : sauvegarde, detection du
  drapeau Absent, garde-fous, entree / sortie, alertes, journal des messages
  et cumul du temps d'absence par personnage.

  Regles (voir CLAUDE.md, pieges connus) :
    - JAMAIS d'entree en combat ; sortie immediate a PLAYER_REGEN_DISABLED.
    - Pas de sortie par Echap captee par nous : ni UISpecialFrames + OnHide,
      ni OnKeyDown. On sort quand le jeu leve le drapeau (mouvement, chat),
      sur un clic, sur une alerte, ou quand Echap a deja fait reapparaitre
      l'interface (le jeu le fait lui-meme quand UIParent est masquee :
      Tick() le constate et sort proprement).
    - Toute modification (CVars, camera, interface) est notee dans
      StandbyDB.restore AVANT d'etre faite, et rejouee au login suivant si la
      sortie n'a pas eu lieu (crash, deconnexion brutale).
    - On ne lit que les donnees des autres modules (APIs publiques), jamais
      leurs bases.

  NON TESTE EN JEU : tout ce fichier est a valider par Tibiscui (redemarrage
  complet du client pour le nouveau dossier, puis /standby test et /afk).
============================================================================]]

local ADDON, SB = ...

SB.ACCENT = { 0.949, 0.471, 0.624 }   -- rose aube #F2789F (identite Standby)
SB.LOGO   = "Interface\\AddOns\\Standby\\medias\\Logo"
SB.KEY    = "Standby"

SB.L = SB.L or {}
function SB.T(key, fr) return SB.L[key] or fr end
local T = SB.T

local function Hex(c)
  c = c or SB.ACCENT
  return string.format("|cFF%02X%02X%02X", math.floor(c[1]*255+0.5), math.floor(c[2]*255+0.5), math.floor(c[3]*255+0.5))
end
SB.Hex = Hex
function SB.Print(msg) print(Hex() .. "Standby|r : " .. tostring(msg)) end

-- ============================================================================
-- SAUVEGARDE
-- ============================================================================
SB.LAYOUTS     = { "vitrine", "fiche", "epure", "eco" }
SB.BACKGROUNDS = { "scene", "art", "black" }
SB.TILE_ORDER  = { "vault", "todo", "rest", "conc", "key", "rep", "reset", "mail", "alts" }

local DEFAULTS = {
  enabled      = true,
  layout       = "vitrine",  -- vitrine | fiche | epure | eco
  background   = "scene",    -- scene (monde + camera) | art (illustration d'extension) | black
  artTier      = 0,          -- 0 = extension actuelle, -1 = aleatoire, n = palier du journal
  hideUI       = true,       -- fond "scene" : masquer l'interface Blizzard
  spin         = true,
  spinSpeed    = 4,          -- 1..10
  delay        = 1,          -- secondes d'absence avant l'ecran (0..300) ; 1 s demande le 2026-10-04
  skipInstance = true,
  skipRaid     = true,
  skipGroup    = false,
  showModel    = true,       -- fonds "art" et "black" : personnage en 3D
  showTitle    = true,       -- titre sous le nom
  slideshow    = false,      -- diaporama : alternance Vitrine / Fiche
  slideSec     = 45,         -- secondes entre deux mises en page (10..600)
  artEvery     = 3,          -- fond Illustration : nouvelle image toutes les N min (0 = jamais)
  showSheet    = true,       -- Vitrine : specialisation, niveau d'objet, stats sous le nom
  privacy      = false,      -- masque nom, guilde, royaume, or
  classColor   = false,
  messages     = true,
  recap        = true,
  ecoAll       = false,      -- economie dans toutes les mises en page
  ecoFPS       = 15,
  ecoAmbience  = true,
  tiles        = { vault = true, todo = true, rest = true, conc = true, key = true, rep = true, reset = true, mail = true, alts = true },
  minimapAngle = 200,
}

local function CopyDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      CopyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

local function OneOf(v, list, def)
  for _, x in ipairs(list) do if v == x then return v end end
  return def
end

local function Num(v, def, lo, hi)
  v = tonumber(v)
  if not v or v ~= v then return def end
  if v < lo then return lo elseif v > hi then return hi end
  return v
end

function SB.InitDB()
  if type(StandbyDB) ~= "table" then StandbyDB = {} end
  local db = StandbyDB
  CopyDefaults(db, DEFAULTS)
  db.layout     = OneOf(db.layout, SB.LAYOUTS, "vitrine")
  db.background = OneOf(db.background, SB.BACKGROUNDS, "scene")
  db.artTier    = math.floor(Num(db.artTier, 0, -1, 99))
  db.spinSpeed  = math.floor(Num(db.spinSpeed, 4, 1, 10))
  -- Ancien defaut 10 s -> 1 s (une seule fois, un reglage choisi reste).
  if db.delayV ~= 2 then
    if db.delay == 10 then db.delay = 1 end
    db.delayV = 2
  end
  db.delay      = math.floor(Num(db.delay, 1, 0, 300))
  db.ecoFPS     = math.floor(Num(db.ecoFPS, 15, 5, 60))
  db.slideSec   = math.floor(Num(db.slideSec, 45, 10, 600))
  db.artEvery   = math.floor(Num(db.artEvery, 3, 0, 60))
  if type(db.chars) ~= "table" then db.chars = {} end
  if type(db.restore) ~= "table" then db.restore = {} end
  SB.db = db
end

function SB.CharKey()
  local name, realm = UnitFullName("player")
  realm = (realm and realm ~= "") and realm or GetRealmName() or "?"
  return (name or UnitName("player") or "?") .. "-" .. realm
end

function SB.CharRec()
  if not SB.db then return nil end
  local k = SB.CharKey()
  local r = SB.db.chars[k]
  if type(r) ~= "table" then r = { count = 0, total = 0, longest = 0 }; SB.db.chars[k] = r end
  return r
end

-- ============================================================================
-- ACTIVATION (case TibiSuite + case du module)
-- ============================================================================
-- Decision validee (2026-10-04) : actif pour une nouvelle installation,
-- decoche pour les joueurs existants a la mise a jour. Pas de migration
-- ponctuelle dans le core : une cle absente de enabledModules = decoche.
-- enabledModules == nil (suite jamais configuree) = tout est actif.
function SB.SuiteDisabled()
  local TS = _G.TibiSuite
  if not (TS and TS.RegisterModule) then return false end
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return false end
  return not TibiSuiteDB.enabledModules[SB.KEY]
end

function SB.IsOn()
  return SB.db and SB.db.enabled and not SB.SuiteDisabled() and true or false
end

-- ElvUI a son propre ecran d'absence : jamais deux ecrans superposes.
function SB.ElvUIAFK()
  local ok, on = pcall(function()
    local E = _G.ElvUI and _G.ElvUI[1]
    return E and E.db and E.db.general and E.db.general.afk
  end)
  return ok and on and true or false
end

-- ============================================================================
-- ETAT
-- ============================================================================
SB.active   = false   -- ecran affiche
SB.preview  = false   -- ecran affiche par /standby test
SB.wasAFK   = false   -- dernier etat lu du drapeau
SB.suppress = false   -- sorti sur alerte / clic : pas de retour avant que le drapeau tombe
SB.messages = {}      -- messages recus pendant l'ecran (memoire seulement, jamais sauvegardes)
SB.counts   = {}

local enterTimer, previewTimer, ticker
local waitCombat = false

-- Fenetres dont l'apparition doit faire sortir (scrutees a chaque seconde) :
-- c'est le filet de securite sans crochet, donc sans taint. Les evenements
-- ci-dessous couvrent l'essentiel ; ceci attrape le reste.
local WATCH_FRAMES = {
  "GameMenuFrame", "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4",
  "LFGDungeonReadyPopup", "LFGDungeonReadyDialog", "PVPReadyDialog", "ReadyCheckFrame",
  "LFGListInviteDialog", "CinematicFrame", "MovieFrame",
}

local function FrameShown(name)
  local f = _G[name]
  if type(f) ~= "table" or type(f.IsShown) ~= "function" then return false end
  local ok, forbidden = pcall(f.IsForbidden, f)
  if ok and forbidden then return false end
  local ok2, shown = pcall(f.IsShown, f)
  return ok2 and shown and true or false
end

-- Vraiment visible a l'ecran : affichee, parents compris, et pas
-- transparente. Constate en jeu (2026-10-04) : une des fenetres surveillees
-- reste IsShown() alors qu'on ne voit rien, ce qui bloquait toute entree.
local function FrameVisible(name)
  if not FrameShown(name) then return false end
  local f = _G[name]
  local ok, vis = pcall(f.IsVisible, f)
  if not (ok and vis) then return false end
  local okA, a = pcall(f.GetEffectiveAlpha or f.GetAlpha, f)
  if okA and type(a) == "number" and a < 0.05 then return false end
  return true
end

-- Etat des fenetres au moment d'entrer. Pendant l'ecran, UIParent peut etre
-- masquee (IsVisible devient faux pour tout le monde) : on ne sort donc que
-- sur une fenetre qui PASSE a l'etat affiche apres l'entree.
local baseline = {}
function SB.SnapshotFrames()
  wipe(baseline)
  for _, n in ipairs(WATCH_FRAMES) do baseline[n] = FrameShown(n) end
end

-- sinceEntry = false : avant l'entree (fenetre reellement visible).
-- sinceEntry = true  : pendant l'ecran (fenetre apparue depuis l'entree).
function SB.BlockingFrame(sinceEntry)
  for _, n in ipairs(WATCH_FRAMES) do
    if sinceEntry then
      local shown = FrameShown(n)
      if shown and not baseline[n] then return n end
      if not shown then baseline[n] = false end
    elseif FrameVisible(n) then
      return n
    end
  end
  return nil
end

-- Garde-fous d'entree. Renvoie ok, raison.
function SB.CanEnter()
  local db = SB.db
  if InCombatLockdown() or UnitAffectingCombat("player") then return false, "combat" end
  if SB.ElvUIAFK() then return false, "elvui" end
  local inInst = IsInInstance()
  if inInst and db.skipInstance then return false, "instance" end
  if IsInRaid() then
    if db.skipRaid then return false, "raid" end
  elseif IsInGroup() and db.skipGroup then
    return false, "group"
  end
  if UnitInVehicle and UnitInVehicle("player") then return false, "vehicle" end
  if C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() then return false, "petbattle" end
  if SB.cinematic then return false, "cinematic" end
  local blocking = SB.BlockingFrame(false)
  if blocking then return false, "popup", blocking end
  return true
end

-- ============================================================================
-- ENTREE / SORTIE
-- ============================================================================
local function CancelEnter()
  if enterTimer then enterTimer:Cancel(); enterTimer = nil end
end

local function StopTicker()
  if ticker then ticker:Cancel(); ticker = nil end
end

function SB.Tick()
  if not SB.active then StopTicker(); return end
  -- Echap avec l'interface masquee : le jeu la fait reapparaitre lui-meme.
  if SB.Scene.uiHidden and UIParent:IsShown() then SB.Scene.uiHidden = false; SB.Exit("esc"); return end
  local blocking = SB.BlockingFrame(true)
  if blocking then SB.Exit("popup", blocking); return end
  if SB.Screen and SB.Screen.Tick then SB.Screen.Tick() end
end

function SB.Enter(isPreview)
  if SB.active then return end
  if not SB.Screen or not SB.Scene then return end
  CancelEnter()
  SB.active   = true
  SB.preview  = isPreview and true or false
  SB.enteredAt = GetTime()
  -- Debut affiche par le minuteur (l'apercu simule 4 min 12 d'absence).
  SB.shownStart = isPreview and (GetTime() - 252) or (SB.afkStart or GetTime())
  wipe(SB.messages); wipe(SB.counts)
  -- Verrous de raid a jour pour LegTrackerAPI.GetFarmRaids (tuile A faire).
  if RequestRaidInfo then pcall(RequestRaidInfo) end
  if isPreview then SB.SampleMessages() end

  SB.SnapshotFrames()
  SB.Scene.Enter()
  SB.Screen.Show()
  StopTicker()
  ticker = C_Timer.NewTicker(1, SB.Tick)

  if isPreview then
    if previewTimer then previewTimer:Cancel() end
    previewTimer = C_Timer.NewTimer(15, function() previewTimer = nil; SB.Exit("preview") end)
  end
end

local function Plural(n, one, many) return n .. " " .. (n > 1 and many or one) end

function SB.FormatDuration(sec)
  sec = math.max(0, math.floor(sec or 0))
  local d, h, m = math.floor(sec / 86400), math.floor(sec / 3600) % 24, math.floor(sec / 60) % 60
  if d > 0 then return string.format(T("DUR_DH", "%d j %d h"), d, h) end
  if h > 0 then return string.format(T("DUR_HM", "%d h %02d"), h, m) end
  if m > 0 then return string.format(T("DUR_M", "%d min"), m) end
  return string.format(T("DUR_S", "%d s"), sec)
end

function SB.Exit(reason, detail)
  if not SB.active then return end
  local wasPreview = SB.preview
  SB.active, SB.preview = false, false
  StopTicker()
  if previewTimer then previewTimer:Cancel(); previewTimer = nil end
  if SB.Screen then SB.Screen.Hide() end
  if SB.Scene then SB.Scene.Exit() end

  if wasPreview then return end

  local dur = GetTime() - (SB.afkStart or SB.enteredAt or GetTime())
  local rec = SB.CharRec()
  if rec then
    rec.count   = (rec.count or 0) + 1
    rec.total   = (rec.total or 0) + dur
    rec.longest = math.max(rec.longest or 0, dur)
    rec.last    = { at = time(), dur = math.floor(dur), msgs = #SB.messages }
  end
  SB.lastReason = reason

  -- Sortie forcee (alerte, clic, combat...) alors que le drapeau est encore
  -- pose : pas de retour automatique tant que le joueur n'est pas revenu.
  if reason ~= "back" and UnitIsAFK("player") then SB.suppress = true end
  if reason == "alert" or reason == "popup" then
    if FlashClientIcon then pcall(FlashClientIcon) end
  end

  if SB.db.recap and dur >= 10 then
    local parts = { string.format(T("RECAP_AWAY", "absent %s"), SB.FormatDuration(dur)) }
    local n = #SB.messages
    if n > 0 then parts[#parts + 1] = Plural(n, T("RECAP_MSG1", "message"), T("RECAP_MSGN", "messages")) end
    if reason == "alert" and detail then parts[#parts + 1] = tostring(detail) end
    SB.Print(table.concat(parts, ", ") .. ".")
  end
end

-- Programme l'entree apres le delai de grace.
function SB.TryEnter()
  enterTimer = nil
  if SB.active or SB.suppress or not SB.IsOn() then return end
  if not UnitIsAFK("player") then return end
  local ok, why, detail = SB.CanEnter()
  if ok then SB.lastRefusal = nil; SB.Enter(false); return end
  if why == "combat" then waitCombat = true
  elseif why == "popup" or why == "cinematic" or why == "vehicle" or why == "petbattle" then
    enterTimer = C_Timer.NewTimer(5, SB.TryEnter)
  else
    -- Refus durable (instance, raid, groupe, ElvUI) : on le dit UNE fois par
    -- absence (vu en jeu le 2026-10-04 : /afk en instance, rien, aucun
    -- message), puis on reessaie de temps en temps au cas ou l'option change
    -- ou le joueur sort de l'instance.
    if not SB.refusalNotified then
      SB.refusalNotified = true
      local REASONS = {
        instance = T("WHY_INSTANCE", "vous êtes en instance (option « Pas en instance »)."),
        raid     = T("WHY_RAID", "vous êtes en raid (option « Pas en raid »)."),
        group    = T("WHY_GROUP", "vous êtes en groupe (option « Pas en groupe »)."),
        elvui    = T("WHY_ELVUI", "l'écran d'absence d'ElvUI est actif."),
      }
      SB.Print(T("WHY_HEAD", "pas d'écran d'absence ici : ") .. (REASONS[why] or tostring(why)))
    end
    enterTimer = C_Timer.NewTimer(15, SB.TryEnter)
  end
  SB.lastRefusal = why
  SB.lastRefusalDetail = detail
end

local function ScheduleEnter()
  CancelEnter()
  if not SB.IsOn() then return end
  local delay = SB.db.delay or 0
  if delay <= 0 then SB.TryEnter() else enterTimer = C_Timer.NewTimer(delay, SB.TryEnter) end
end

function SB.OnFlags()
  local afk = UnitIsAFK("player") and true or false
  if afk and not SB.wasAFK then
    SB.wasAFK = true
    SB.refusalNotified = false
    SB.afkStart = GetTime()
    ScheduleEnter()
  elseif (not afk) and SB.wasAFK then
    SB.wasAFK, SB.suppress, waitCombat = false, false, false
    CancelEnter()
    if SB.active and not SB.preview then SB.Exit("back") end
    SB.afkStart = nil
  end
end

-- Clic sur l'ecran : revient, et leve aussi le drapeau (le clic est une action
-- materielle du joueur). NON TESTE EN JEU sous 12.1 : si l'envoi est refuse,
-- l'ecran se ferme quand meme et le drapeau tombera au premier mouvement.
function SB.OnScreenClick()
  local wasPreview = SB.preview
  SB.Exit("click")
  if not wasPreview and UnitIsAFK("player") then
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if send then pcall(send, "", "AFK") end
  end
end

-- ============================================================================
-- MESSAGES RECUS PENDANT L'ABSENCE
-- ============================================================================
local CHAT = {
  CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_BN_WHISPER = "BN_WHISPER",
  CHAT_MSG_GUILD = "GUILD", CHAT_MSG_OFFICER = "OFFICER",
  CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY_LEADER",
  CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID_LEADER",
  CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT", CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT_LEADER",
}
SB.CHAT_EVENTS = CHAT
local MAX_MSG = 40

-- Valeurs « secretes » de Midnight : en instance ou en rencontre, une partie
-- des donnees de chat arrive masquee aux addons. Toute operation sur une
-- telle valeur leve une erreur : on la remplace par nil avant de la toucher.
local function Clean(v)
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, v)
    if not ok or secret then return nil end
  end
  if type(v) ~= "string" then return nil end
  return v
end

function SB.OnChat(event, text, sender)
  if not SB.active or SB.preview or not SB.db.messages then return end
  local ct = CHAT[event]
  if not ct then return end
  local ok = pcall(function()
    local from = Clean(sender)
    if from and Ambiguate then from = Ambiguate(from, "short") end
    local m = { t = time(), type = ct, text = Clean(text), from = from }
    table.insert(SB.messages, m)
    while #SB.messages > MAX_MSG do table.remove(SB.messages, 1) end
    SB.counts[ct] = (SB.counts[ct] or 0) + 1
  end)
  if ok and SB.Screen and SB.Screen.RefreshMessages then SB.Screen.RefreshMessages() end
end

function SB.SampleMessages()
  local now = time()
  SB.messages = {
    { t = now - 360, type = "WHISPER", from = "Lyanna", text = T("SAMPLE_1", "tu viens pour la clé +12 ?") },
    { t = now - 240, type = "BN_WHISPER", from = "Max", text = T("SAMPLE_2", "je lance dans 10 min") },
    { t = now - 120, type = "GUILD", from = "Orik", text = T("SAMPLE_3", "raid ce soir 21h30, invitations ouvertes") },
  }
end

-- ============================================================================
-- STATISTIQUES (lues par StandbyAPI, Bridge.lua)
-- ============================================================================
function SB.Totals(key)
  local rec = SB.db and SB.db.chars[key or SB.CharKey()]
  if type(rec) ~= "table" then return { count = 0, total = 0, longest = 0 } end
  return { count = rec.count or 0, total = math.floor(rec.total or 0), longest = math.floor(rec.longest or 0), last = rec.last }
end

-- ============================================================================
-- EVENEMENTS
-- ============================================================================
-- Evenements qui font sortir de l'ecran (le jeu a besoin du joueur).
local ALERTS = {
  LFG_PROPOSAL_SHOW = "ALERT_LFG", READY_CHECK = "ALERT_READY", CONFIRM_SUMMON = "ALERT_SUMMON",
  PARTY_INVITE_REQUEST = "ALERT_INVITE", DUEL_REQUESTED = "ALERT_DUEL", TRADE_SHOW = "ALERT_TRADE",
  PLAYER_DEAD = "ALERT_DEAD", PET_BATTLE_OPENING_START = "ALERT_PETBATTLE",
  LFG_LIST_APPLICATION_STATUS_UPDATED = "ALERT_LFGLIST",
}
local ALERT_TEXT = {
  ALERT_LFG = "file prête", ALERT_READY = "appel", ALERT_SUMMON = "convocation", ALERT_INVITE = "invitation de groupe",
  ALERT_DUEL = "duel", ALERT_TRADE = "échange", ALERT_DEAD = "mort", ALERT_PETBATTLE = "combat de mascottes",
  ALERT_LFGLIST = "candidature", ALERT_PVP = "champ de bataille prêt",
}

local ev = CreateFrame("Frame")
SB.eventFrame = ev
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")

local function RegisterRuntime()
  for _, e in ipairs({
    "PLAYER_FLAGS_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "LOADING_SCREEN_ENABLED", "PLAYER_LEAVING_WORLD", "CINEMATIC_START", "CINEMATIC_STOP",
    "PLAY_MOVIE", "STOP_MOVIE", "UNIT_ENTERED_VEHICLE", "UPDATE_BATTLEFIELD_STATUS",
    "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
  }) do pcall(ev.RegisterEvent, ev, e) end
  for e in pairs(ALERTS) do pcall(ev.RegisterEvent, ev, e) end
  for e in pairs(CHAT) do pcall(ev.RegisterEvent, ev, e) end
end

ev:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... == ADDON then SB.InitDB() end
    return
  elseif event == "PLAYER_LOGIN" then
    if not SB.db then SB.InitDB() end
    -- Sortie qui n'a pas eu lieu la derniere fois (crash) : on rejoue la
    -- restauration AVANT tout, meme si le module est decoche.
    SB.Scene.RecoverAtLogin()
    ev:UnregisterEvent("ADDON_LOADED")
    -- Un tick plus tard : le core a pose enabledModules.
    -- On ecoute TOUJOURS, meme decoche : la case TibiSuite est relue a chaque
    -- declenchement (ScheduleEnter / TryEnter -> SB.IsOn), donc cocher pendant
    -- la session prend effet tout de suite, sans /reload. (Constate en jeu le
    -- 2026-10-04 : ecoute branchee seulement si coche au login, /afk inerte.)
    C_Timer.After(0, function()
      RegisterRuntime()
      SB.wasAFK = UnitIsAFK("player") and true or false
      if SB.wasAFK then SB.afkStart = GetTime(); ScheduleEnter() end
    end)
    return
  elseif event == "PLAYER_LOGOUT" then
    if SB.active then SB.Exit("logout") end
    if SB.Scene then SB.Scene.Exit() end
    return
  end

  if event == "PLAYER_FLAGS_CHANGED" then
    if ... == "player" then SB.OnFlags() end
  elseif event == "PLAYER_REGEN_DISABLED" then
    if SB.active then SB.Exit("combat") end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if SB.Scene.pendingShowUI then SB.Scene.ShowUI() end
    if waitCombat then waitCombat = false; if UnitIsAFK("player") and not SB.suppress then ScheduleEnter() end end
  elseif event == "LOADING_SCREEN_ENABLED" or event == "PLAYER_LEAVING_WORLD" then
    if SB.active then SB.Exit("zone") end
  elseif event == "CINEMATIC_START" or event == "PLAY_MOVIE" then
    SB.cinematic = true
    if SB.active then SB.Exit("cinematic") end
  elseif event == "CINEMATIC_STOP" or event == "STOP_MOVIE" then
    SB.cinematic = false
  elseif event == "UNIT_ENTERED_VEHICLE" then
    if ... == "player" and SB.active then SB.Exit("vehicle") end
  elseif event == "UPDATE_BATTLEFIELD_STATUS" then
    if SB.active and GetBattlefieldStatus then
      local idx = ...
      local ok, status = pcall(GetBattlefieldStatus, idx or 1)
      if ok and status == "confirm" then SB.Exit("alert", T("ALERT_PVP", ALERT_TEXT.ALERT_PVP)) end
    end
  elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    local who, fn = ...
    if who == ADDON then
      -- Le client refuse une de nos actions : on passe en mode sur (voile,
      -- interface jamais masquee) et on le dit une seule fois.
      if not SB.db.safeMode then
        SB.db.safeMode = true
        SB.Print(string.format(T("MSG_SAFEMODE", "le jeu a refusé une action (%s). Passage en mode sûr : l'interface ne sera plus masquée, un voile la recouvre."), tostring(fn)))
      end
      if SB.Scene.uiHidden then SB.Scene.pendingShowUI = true end
    end
  elseif ALERTS[event] then
    if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
      local _, newStatus = ...
      if newStatus ~= "invited" then return end
    end
    if SB.active then SB.Exit("alert", T(ALERTS[event], ALERT_TEXT[ALERTS[event]])) end
  elseif CHAT[event] then
    SB.OnChat(event, ...)
  end
end)

-- Appele par l'interface quand la case est (de)cochee.
function SB.SetEnabled(on)
  SB.db.enabled = on and true or false
  if not on then CancelEnter(); if SB.active then SB.Exit("off") end end
end

-- Apercu : /standby test
function SB.Preview()
  if SB.active then SB.Exit("preview"); return end
  if InCombatLockdown() then SB.Print(T("MSG_COMBAT", "pas en combat.")); return end
  if SB.SuiteDisabled() then
    SB.Print(T("MSG_PREVIEW_OFF", "aperçu seulement : Standby est décoché dans TibiSuite, /afk ne déclenchera rien. Cochez-le dans /ts modules."))
  elseif SB.db and not SB.db.enabled then
    SB.Print(T("MSG_PREVIEW_DISABLED", "aperçu seulement : l'écran est désactivé dans les options de Standby."))
  end
  SB.Enter(true)
end

-- /standby status : pourquoi l'ecran s'affiche ou non (diagnostic en jeu).
function SB.PrintStatus()
  local G, R, Y = "|cFF66D98A", "|cFFFF7F7F", "|cFFFFD700"
  local function B(v) return v and (G .. T("YES", "oui") .. "|r") or (R .. T("NO", "non") .. "|r") end
  local db = SB.db or {}
  SB.Print(T("STATUS_HEAD", "état :"))
  print("  " .. T("STATUS_SUITE", "Coché dans TibiSuite : ") .. B(not SB.SuiteDisabled()))
  print("  " .. T("STATUS_ENABLED", "Activé dans les options : ") .. B(db.enabled))
  print("  " .. T("STATUS_LISTEN", "Écoute du statut Absent : ") .. B(SB.eventFrame:IsEventRegistered("PLAYER_FLAGS_CHANGED")))
  print("  " .. T("STATUS_AFK", "Absent en ce moment : ") .. B(UnitIsAFK("player")))
  print("  " .. T("STATUS_ELVUI", "Écran d'absence ElvUI actif : ") .. B(SB.ElvUIAFK()))
  local ok, why, detail = SB.CanEnter()
  print("  " .. T("STATUS_CAN", "Peut s'afficher ici : ") .. (ok and (G .. T("YES", "oui") .. "|r")
    or (R .. tostring(why) .. (detail and (" (" .. tostring(detail) .. ")") or "") .. "|r")))
  print("  " .. T("STATUS_DELAY", "Délai : ") .. Y .. tostring(db.delay) .. " s|r"
    .. (SB.suppress and ("  ·  " .. T("STATUS_SUPPRESS", "en attente de votre retour (sortie forcée)")) or "")
    .. (SB.lastRefusal and ("  ·  " .. T("STATUS_LAST", "dernier refus : ") .. tostring(SB.lastRefusal)) or ""))

  -- Sources des tuiles « A faire ce soir » / « Mes personnages » : ce que
  -- chaque module renvoie (diagnostic en jeu, /run pouvant etre indisponible).
  print("  " .. T("STATUS_SOURCES", "Sources de la suite :"))
  local function Show(label, api, fnName, ...)
    if not (api and api[fnName]) then print("    " .. label .. " : " .. R .. T("STATUS_NOAPI", "absent") .. "|r"); return end
    local res = { pcall(api[fnName], ...) }
    if not res[1] then print("    " .. label .. " : " .. R .. tostring(res[2]) .. "|r"); return end
    local parts = {}
    for i = 2, #res do
      local v = res[i]
      parts[#parts + 1] = type(v) == "table" and ("{" .. #v .. "}") or tostring(v)
    end
    print("    " .. label .. " : " .. Y .. table.concat(parts, " ") .. "|r")
  end
  Show("DailyTracker", _G.DailyTrackerAPI, "GetRemaining")
  local ext = RenTrackerDB and RenTrackerDB.extension
  Show("RenTracker (" .. tostring(ext or "Midnight") .. ")", _G.RenTrackerAPI, "GetWeeklyRemaining")
  Show("LegTracker", _G.LegTrackerAPI, "GetFarmRaids")
  Show("WeeklyCompass", _G.WeeklyCompassAPI, "GetAlts")
  Show("SkillTracker", _G.SkillTrackerAPI, "GetFullConcentrations")
  Show("LvlHistory", _G.LvlHistoryAPI, "ListChars")
end
