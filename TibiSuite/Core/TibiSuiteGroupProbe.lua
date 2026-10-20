--[[============================================================================
  TibiSuiteGroupProbe.lua  -  Sonde du partage en groupe (7.3, lot C)
  ---------------------------------------------------------------------------
  AVANT tout code de partage (qui est deja sauvegarde, qui farme quoi...),
  on mesure ce que Midnight laisse passer entre addons selon le contexte :
  groupe en monde, donjon, raid, Mythique+, rencontre de boss, combat.

  /ts sonde groupe        active la sonde 2 h (ou la coupe si active)
  /ts sonde groupe report resume par contexte dans la discussion
  /ts sonde groupe clear  efface le releve

  Sonde active : un petit message « ping » part sur le canal du groupe a
  chaque changement de contexte (groupe, zone, debut / fin de rencontre,
  debut de clé, entree / sortie de combat), 10 s au moins entre deux envois.
  Un autre joueur qui a la sonde active repond « pong » (une fois par ping).
  Chaque envoi (avec le code de retour du client) et chaque reception est
  note dans TibiSuiteDB.groupProbe.log (300 lignes au plus) :
    { t, d = "tx"|"rx", ch, ctx, res, from, kind }
  ctx = type d'instance + "+enc" (rencontre) + "+mplus" (clé) + "+combat".
  Prefixe a part (TibiSuiteGP) : l'alerte de nouvelle version n'est pas
  touchee. Rien n'est envoye si la sonde est coupee.
  NON TESTE EN JEU (nouveau fichier : redemarrage complet du client).
============================================================================]]

local PREFIX = "TibiSuiteGP"
local DURATION = 2 * 3600
local MIN_GAP = 10
local MAX_LOG = 300
local TAG = "|cFFC41F3BTibiSuite|r [sonde groupe] "

local lastTx = 0
local registered

local function DB()
  TibiSuiteDB.groupProbe = TibiSuiteDB.groupProbe or { log = {} }
  local p = TibiSuiteDB.groupProbe
  p.log = p.log or {}
  return p
end

local function Active()
  local p = TibiSuiteDB and TibiSuiteDB.groupProbe
  return p and p.on and (p.untilT or 0) > time()
end

local function Channel()
  if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
  if IsInRaid and IsInRaid() then return "RAID" end
  if IsInGroup and IsInGroup() then return "PARTY" end
  return nil
end

local function Context()
  local _, itype = IsInInstance()
  local ctx = tostring(itype or "none")
  if IsEncounterInProgress and IsEncounterInProgress() then ctx = ctx .. "+enc" end
  if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
    local ok, on = pcall(C_ChallengeMode.IsChallengeModeActive)
    if ok and on then ctx = ctx .. "+mplus" end
  end
  if InCombatLockdown() then ctx = ctx .. "+combat" end
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    local ok, lock = pcall(C_ChatInfo.InChatMessagingLockdown)
    if ok and lock then ctx = ctx .. "+lockdown" end
  end
  return ctx
end

local function Log(e)
  local p = DB()
  e.t = time()
  p.log[#p.log + 1] = e
  while #p.log > MAX_LOG do table.remove(p.log, 1) end
end

local function Register()
  if registered or not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
  local ok, res = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
  registered = true
  DB().reg = ok and tostring(res) or "error"
end

local function Send(kind, force)
  if not Active() then return end
  local ch = Channel()
  if not ch then return end
  local now = time()
  if not force and now - lastTx < MIN_GAP then return end
  lastTx = now
  Register()
  local ctx = Context()
  local msg = "P1:" .. kind .. ":" .. now .. ":" .. ctx
  local ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, ch)
  Log({ d = "tx", ch = ch, ctx = ctx, kind = kind, res = ok and tostring(res) or ("error " .. tostring(res)) })
end

local function OnMessage(prefix, msg, ch, sender)
  if prefix ~= PREFIX or not Active() then return end
  if issecretvalue and (issecretvalue(msg) or issecretvalue(sender)) then
    Log({ d = "rx", ch = tostring(ch), ctx = Context(), kind = "secret" })
    return
  end
  local me = UnitName("player")
  local who = tostring(sender or "")
  if me and (who == me or who:match("^" .. me .. "%-")) then return end   -- notre propre echo
  local kind, _, theirCtx = tostring(msg):match("^P1:(%a+):(%d+):(.*)$")
  Log({ d = "rx", ch = tostring(ch), ctx = Context(), kind = kind or "?", from = who, theirs = theirCtx })
  if kind == "ping" then C_Timer.After(1 + math.random() * 2, function() Send("pong", true) end) end
end

local function Report()
  local p = DB()
  local by = {}
  for _, e in ipairs(p.log) do
    local k = e.ctx or "?"
    local b = by[k] or { tx = 0, ok = 0, rx = 0, res = {} }
    by[k] = b
    if e.d == "tx" then
      b.tx = b.tx + 1
      b.res[e.res or "?"] = (b.res[e.res or "?"] or 0) + 1
    else b.rx = b.rx + 1 end
  end
  print(TAG .. string.format("%d lignes, prefixe %s (enregistrement : %s), %s.", #p.log, PREFIX, tostring(p.reg or "-"),
    Active() and ("active encore " .. math.floor(((p.untilT or 0) - time()) / 60) .. " min") or "coupee"))
  for ctx, b in pairs(by) do
    local parts = {}
    for r, n in pairs(b.res) do parts[#parts + 1] = r .. " x" .. n end
    print(string.format("  %s : envoyes %d (%s), recus %d", ctx, b.tx, table.concat(parts, ", "), b.rx))
  end
  print("  Detail complet dans TibiSuite.lua (SavedVariables) apres /reload ou deconnexion.")
end

function TibiSuite.GroupProbe(arg)
  arg = arg or ""
  if arg == "report" then Report(); return end
  if arg == "clear" then TibiSuiteDB.groupProbe = nil; print(TAG .. "releve efface."); return end
  local p = DB()
  if Active() then
    p.on = nil
    print(TAG .. "coupee.")
    return
  end
  p.on, p.untilT = true, time() + DURATION
  Register()
  print(TAG .. "active pour 2 h. Joue normalement en groupe (monde, donjon, raid, clé) ; un autre joueur avec la sonde active rend le test complet. /ts sonde groupe report pour le resume.")
  Send("ping", true)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_START",
  "ENCOUNTER_END", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "PLAYER_ENTERING_WORLD" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, ...)
  if e == "CHAT_MSG_ADDON" then OnMessage(...); return end
  if not Active() then return end
  if e == "PLAYER_ENTERING_WORLD" then Register() end
  -- Rencontre et combat : envoi immediat (c'est ce qu'on veut mesurer).
  local force = (e == "ENCOUNTER_START" or e == "PLAYER_REGEN_DISABLED" or e == "CHALLENGE_MODE_START")
  C_Timer.After(force and 0.5 or 2, function() Send("ping", force) end)
end)
