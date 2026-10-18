-- ================================================================
--  SkillTracker  -  Fishing.lua  (peche, lots 1 et 2)
--  Idees reprises de Fishing Buddy, code ecrit de zero (sa licence
--  CC BY-NC-SA interdit la copie). Lecture seule cote jeu : aucun bouton
--  securise, aucune liaison de touche, aucun changement d'equipement.
--
--  LOT 1. SESSION DE PECHE : chaque butin de peche (IsFishingLoot, sinon
--     butin juste apres une incantation de Peche) est compte, tous objets
--     confondus (poissons, dechets, tresors). Meme forme que la session de
--     recolte (Gathering.lua) pour reutiliser FarmDuration / FarmRate /
--     FarmTopZone et la vue :
--       SkillTrackerDB.fish = { cur, sessions = { 20 dernieres },
--         total = { [itemID] = qte }, spots = { [langue] = { [lieu] =
--         { n, at, items = { [itemID] = qte } } } } }
--       session = { start, last, nodes (= prises), items, zones }
--     Lieu = "Zone · Sous-zone" : ce que l'on peche ou, appris en pechant.
--  LOT 2. SONS DE PECHE : le temps de pecher (de la 1re incantation a
--     90 s sans relancer, ou au combat), musique et ambiance coupees, effets
--     sonores a fond, son garde jeu en arriere-plan, clic pour se deplacer
--     coupe. Chaque valeur d'origine est notee dans SkillTrackerDB.fishRestore
--     AVANT d'etre changee, remise a la fin, a la deconnexion et au login
--     suivant (meme principe que Standby).
--  La tenue de peche de Fishing Buddy n'est pas reprise : depuis
--  Dragonflight, canne et accessoires sont dans les emplacements de metier,
--  rien a echanger.
--  NON TESTE EN JEU : a valider par Tibiscui (nouveau fichier : redemarrage
--  complet du client).
-- ================================================================

local _, ST = ...

local FR = (GetLocale and GetLocale() == "frFR")
local function T(fr, en) return FR and fr or en end

local function Secret(v) return issecretvalue and issecretvalue(v) or false end

local FISH_IDLE    = 600   -- fin de session apres 10 min sans prise
local MODE_IDLE    = 90    -- fin du mode sons apres 90 s sans relancer
local MAX_SESSIONS = 20

-- ================================================================
-- RECONNAITRE LA PECHE
-- ================================================================
-- Sorts de Peche connus (ancien et actuel) ; le nom du sort sert de filet
-- si Blizzard en ajoute un autre.
local FISH_IDS = { [131474] = true, [131476] = true, [131490] = true, [7620] = true }
local fishName

local function SpellName(id)
  if C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok then return n end
  end
  if GetSpellInfo then return (GetSpellInfo(id)) end
end

local function IsFishingSpell(id)
  if type(id) ~= "number" or Secret(id) then return false end
  if FISH_IDS[id] then return true end
  fishName = fishName or SpellName(131474)
  local n = SpellName(id)
  return fishName ~= nil and n ~= nil and not Secret(n) and n == fishName
end

-- ================================================================
-- DONNEES
-- ================================================================
local function FishDB()
  SkillTrackerDB.fish = SkillTrackerDB.fish or {}
  local f = SkillTrackerDB.fish
  f.sessions = f.sessions or {}
  f.total = f.total or {}
  f.spots = f.spots or {}
  return f
end
ST.FishDB = FishDB

local function Spots()
  local f = FishDB()
  local loc = (GetLocale and GetLocale()) or "enUS"
  f.spots[loc] = f.spots[loc] or {}
  return f.spots[loc]
end
ST.FishSpots = Spots

local function Place()
  local z = GetZoneText and GetZoneText()
  if not z or z == "" or Secret(z) then return nil, nil end
  local sz = GetSubZoneText and GetSubZoneText()
  if sz and sz ~= "" and sz ~= z and not Secret(sz) then return z .. " · " .. sz, z end
  return z, z
end

function ST.FishActive()
  local f = FishDB().cur
  if f and time() - (f.last or 0) <= FISH_IDLE then return f end
end

local function FishClose(quiet)
  local db = FishDB()
  local s = db.cur
  db.cur = nil
  if not s or (s.nodes or 0) == 0 then return end
  s.zone = ST.FarmTopZone and ST.FarmTopZone(s) or nil
  table.insert(db.sessions, 1, s)
  while #db.sessions > MAX_SESSIONS do table.remove(db.sessions) end
  if not quiet and _G.TibiSuite and TibiSuite.Notify then
    local v = ST.ItemsValue(s.items)
    TibiSuite.Notify("Skill", string.format(T("Session de pêche terminée : %d prises, %s en %s.",
      "Fishing session ended: %d catches, %s in %s."), s.nodes, ST.Prices.Money(v), ST.FormatDuration(ST.FarmDuration(s))),
      { sound = false })
  end
  if ST.RefreshUI then ST.RefreshUI() end
end
ST.FishClose = FishClose

local function NewSession(now)
  return { start = now, last = now, nodes = 0, items = {}, zones = {} }
end

local function FishRecord(qty)
  local db = FishDB()
  local now = time()
  if db.cur and now - (db.cur.last or 0) > FISH_IDLE then FishClose() end
  if not db.cur then
    db.cur = NewSession(now)
    print(ST.TAG .. " " .. T("Session de pêche démarrée (première prise).", "Fishing session started (first catch)."))
  end
  local s = db.cur
  s.nodes = (s.nodes or 0) + 1
  s.last = now
  local place, zone = Place()
  if zone then s.zones[zone] = (s.zones[zone] or 0) + 1 end
  for id, q in pairs(qty) do
    s.items[id] = (s.items[id] or 0) + q
    db.total[id] = (db.total[id] or 0) + q
  end
  if place and ST.settings.fishSpots ~= false then
    local sp = Spots()
    local rec = sp[place] or { n = 0, items = {} }
    rec.n = (rec.n or 0) + 1
    rec.at = now
    for id, q in pairs(qty) do rec.items[id] = (rec.items[id] or 0) + q end
    sp[place] = rec
  end
  if _G.TibiSuite and TibiSuite.RefreshStatus then TibiSuite.RefreshStatus() end
  if ST.RefreshUI then ST.RefreshUI() end
end

-- /skt peche : demarre une session vide, ou termine la session en cours.
function ST.FishToggle()
  local db = FishDB()
  if ST.FishActive() then FishClose()
  else
    if db.cur then FishClose(true) end
    db.cur = NewSession(time())
    print(ST.TAG .. " " .. T("Session de pêche démarrée.", "Fishing session started."))
    if ST.RefreshUI then ST.RefreshUI() end
  end
end

function ST.FishResetTotal()
  FishDB().total = {}
  if ST.RefreshUI then ST.RefreshUI() end
end

function ST.FishForgetSpots()
  local f = FishDB()
  f.spots[(GetLocale and GetLocale()) or "enUS"] = nil
  if ST.RefreshUI then ST.RefreshUI() end
end

-- Lieux de peche tries par nombre de prises : { name, n, at, items }.
function ST.FishSpotList()
  local out = {}
  for name, rec in pairs(Spots()) do
    out[#out + 1] = { name = name, n = rec.n or 0, at = rec.at, items = rec.items or {} }
  end
  table.sort(out, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.name < b.name end)
  return out
end

-- ================================================================
-- LOT 2 : SONS DE PECHE
-- ================================================================
local function GetCV(name)
  if C_CVar and C_CVar.GetCVar then
    local ok, v = pcall(C_CVar.GetCVar, name)
    if ok then return v end
  end
  if GetCVar then local ok, v = pcall(GetCVar, name); if ok then return v end end
end

local function SetCV(name, value)
  value = tostring(value)
  if C_CVar and C_CVar.SetCVar then
    if pcall(C_CVar.SetCVar, name, value) then return true end
  end
  if SetCVar then return (pcall(SetCVar, name, value)) end
  return false
end

local function RestoreDB()
  SkillTrackerDB.fishRestore = SkillTrackerDB.fishRestore or {}
  return SkillTrackerDB.fishRestore
end

-- Note la valeur d'origine une seule fois, puis la change.
local function Override(name, value)
  local cur = GetCV(name)
  if cur == nil then return end
  local r = RestoreDB()
  r.cvars = r.cvars or {}
  if r.cvars[name] == nil then r.cvars[name] = cur end
  if cur ~= tostring(value) then SetCV(name, value) end
end

local function RestoreCVars()
  local r = SkillTrackerDB and SkillTrackerDB.fishRestore
  if not (r and r.cvars) then return end
  for name, v in pairs(r.cvars) do SetCV(name, v) end
  r.cvars = nil
end

local mode = { on = false, lastCast = 0, pending = 0 }

local function EnterMode()
  if mode.on then return end
  local set = ST.settings
  local any = false
  if set.fishSound then
    Override("Sound_MusicVolume", "0")
    Override("Sound_AmbienceVolume", "0")
    Override("Sound_SFXVolume", "1")
    Override("Sound_EnableSFX", "1")
    if set.fishSoundBG ~= false then Override("Sound_EnableSoundWhenGameIsInBG", "1") end
    any = true
  end
  if set.fishNoCTM ~= false and GetCV("autoInteract") == "1" then
    Override("autoInteract", "0")
    any = true
  end
  mode.on = any
end

local function ExitMode()
  RestoreCVars()
  mode.on = false
end
ST.FishExitMode = ExitMode

function ST.FishModeOn() return mode.on end

-- ================================================================
-- EVENEMENTS
-- ================================================================
-- ── Sonde /skt peche sonde : trace ce que le client renvoie ─────────
-- Chaque incantation du joueur et chaque butin, imprimes dans le chat et
-- gardes dans SkillTrackerDB.fishProbe (40 derniers, relus apres /reload).
local probeOn = false

local function Show(v)
  if v == nil then return "nil" end
  if Secret(v) then return "<secret>" end
  return tostring(v)
end

local function Trace(msg)
  if not probeOn then return end
  print("|cFF7FD4E8[peche]|r " .. msg)
  SkillTrackerDB.fishProbe = SkillTrackerDB.fishProbe or {}
  local p = SkillTrackerDB.fishProbe
  table.insert(p, 1, date("%H:%M:%S") .. " " .. msg)
  while #p > 40 do table.remove(p) end
end

function ST.FishProbe(arg)
  if arg == "clear" then
    SkillTrackerDB.fishProbe = nil
    print(ST.TAG .. " " .. T("Sonde de pêche vidée.", "Fishing probe cleared."))
    return
  end
  probeOn = not probeOn
  print(ST.TAG .. " " .. (probeOn
    and T("Sonde de pêche active : lance ta ligne, chaque événement s'affiche ici. /skt peche sonde pour l'arrêter.",
          "Fishing probe on: cast your line, every event shows here. /skt peche sonde to stop it.")
    or T("Sonde de pêche arrêtée. Fais un /reload pour l'écrire dans la sauvegarde.",
         "Fishing probe off. /reload to write it to the saved variables.")))
  if probeOn then
    Trace("fish=" .. Show(ST.settings and ST.settings.fish) .. " sound=" .. Show(ST.settings and ST.settings.fishSound)
      .. " IsFishingLoot=" .. Show(IsFishingLoot ~= nil) .. " nomPeche=" .. Show(SpellName(131474)))
  end
end

local lastLoot = 0
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("LOOT_READY")
frame:RegisterEvent("LOOT_OPENED")

local function ReadLoot()
  if not GetNumLootItems then return nil end
  local qty, any = {}, false
  for slot = 1, GetNumLootItems() do
    local isItem = true
    if GetLootSlotType and LOOT_SLOT_ITEM then
      local t = GetLootSlotType(slot)
      isItem = (t == LOOT_SLOT_ITEM)
    end
    local link = isItem and GetLootSlotLink and GetLootSlotLink(slot)
    local id = link and not Secret(link) and tonumber(link:match("item:(%d+)"))
    if id then
      local q = GetLootSlotInfo and select(3, GetLootSlotInfo(slot))
      q = (type(q) == "number" and not Secret(q)) and q or 1
      qty[id] = (qty[id] or 0) + math.max(1, q)
      any = true
    end
  end
  return any and qty or nil
end

local function IsFishLoot()
  if IsFishingLoot then
    local ok, v = pcall(IsFishingLoot)
    if ok and v and not Secret(v) then return true end
  end
  -- Filet : butin juste apres une incantation de Peche (canal de 30 s au plus).
  return mode.pending > 0 and GetTime() - mode.pending <= 35
end

frame:SetScript("OnEvent", function(_, event, a1, a2, a3)
  if event == "PLAYER_LOGIN" then
    -- Une fin de peche n'a pas eu lieu (plantage, coupure) : on remet tout.
    C_Timer.After(3, function()
      pcall(RestoreCVars)
      local db = FishDB()
      if db.cur and time() - (db.cur.last or 0) > FISH_IDLE then FishClose(true) end
    end)
    C_Timer.NewTicker(15, function()
      if mode.on and GetTime() - mode.lastCast > MODE_IDLE then ExitMode() end
      local db = SkillTrackerDB and SkillTrackerDB.fish
      if db and db.cur and time() - (db.cur.last or 0) > FISH_IDLE then FishClose() end
    end)
    return
  end
  if event == "PLAYER_LOGOUT" then
    if mode.on then RestoreCVars() end
    return
  end
  if not ST.settings then return end
  if event == "PLAYER_REGEN_DISABLED" then
    if mode.on then ExitMode() end
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
    -- (unit, castGUID, spellID)
    if a1 ~= "player" then return end
    local isFish = IsFishingSpell(a3)
    if probeOn then Trace(event:sub(16) .. " sort=" .. Show(a3) .. " nom=" .. Show(SpellName(a3)) .. " peche=" .. Show(isFish)) end
    if not isFish then return end
    mode.lastCast = GetTime()
    mode.pending = mode.lastCast
    if not mode.on and not InCombatLockdown() then EnterMode() end
  elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
    -- LOOT_READY puis LOOT_OPENED pour le meme butin : un seul passage.
    if GetTime() - lastLoot < 1 then return end
    local raw
    if IsFishingLoot then local ok, v = pcall(IsFishingLoot); if ok then raw = v end end
    local fishLoot = IsFishLoot()
    if probeOn then
      Trace(event .. " IsFishingLoot=" .. Show(raw) .. " lancer=" .. (mode.pending > 0 and string.format("%.0fs", GetTime() - mode.pending) or "aucun")
        .. " objets=" .. Show(GetNumLootItems and GetNumLootItems()) .. " compte=" .. Show(fishLoot and ST.settings.fish ~= false))
    end
    if ST.settings.fish == false or not fishLoot then return end
    local qty = ReadLoot()
    if not qty then return end   -- butin pas encore lisible : on attend LOOT_OPENED
    lastLoot = GetTime()
    mode.pending = 0
    local ok, err = pcall(FishRecord, qty)
    if not ok and probeOn then Trace("erreur " .. Show(err)) end
  end
end)

-- ================================================================
-- TEXTES (vue Peche, options, slash)
-- ================================================================
ST.FishText = {
  view = T("Pêche", "Fishing"),
  scopeCur = T("Session", "Session"), scopeHist = T("Historique", "History"), scopeAll = T("Depuis toujours", "All time"),
  scopeSpots = T("Coins de pêche", "Fishing spots"),
  sortName = T("Objet", "Item"), sortQty = T("Quantité", "Quantity"), sortValue = T("Valeur", "Value"), sortExt = T("Extension", "Expansion"),
  sortBy = T("Trier par :", "Sort by:"), extFilter = T("Filtrer par extension :", "Filter by expansion:"),
  active = T("Session de pêche en cours", "Fishing session in progress"),
  idle = T("Aucune session en cours : elle démarre toute seule à ta première prise.", "No session in progress: it starts on its own with your first catch."),
  start = T("Démarrer une session", "Start a session"), stop = T("Terminer la session", "End the session"),
  statsFmt = T("%d prises  ·  %s  ·  %s / h", "%d catches  ·  %s  ·  %s / h"),
  totalFmt = T("%d objets  ·  valeur %s", "%d items  ·  value %s"),
  totalCap = T("VALEUR TOTALE", "TOTAL VALUE"),
  countFmt = T("|cFFFFFFFF%d|r objets  ·  |cFFFFFFFF%d|r sortes", "|cFFFFFFFF%d|r items  ·  |cFFFFFFFF%d|r kinds"),
  each = T("l'unité", "each"),
  none = T("Rien de pêché pour l'instant.", "Nothing caught yet."),
  noHist = T("Aucune session terminée.", "No finished session."),
  back = T("< Retour à l'historique", "< Back to history"),
  reset = T("Remettre le cumul à zéro", "Reset the all-time total"),
  priceNote = T("Valeur au prix du moment : hôtel des ventes (Auctionator ou TSM), sinon vendeur.", "Value at current prices: Auction House (Auctionator or TSM), otherwise vendor."),
  unitFmt = T("Prix à l'unité : %s (%s)", "Unit price: %s (%s)"),
  vendor = T("vendeur", "vendor"),
  noSpots = T("Aucun coin de pêche appris : pêche un peu, chaque prise note ce que donne l'endroit.", "No fishing spot learned yet: each catch records what the place gives."),
  spotFmt = T("%d prises  ·  vu le %s", "%d catches  ·  seen %s"),
  spotsNote = T("Part de chaque objet dans les prises de l'endroit.", "Share of each item in the catches of the place."),
  forget = T("Oublier les coins de pêche", "Forget fishing spots"),
  slash = T("démarrer / terminer une session de pêche", "start / end a fishing session"),
  probe = T("sonde de pêche : affiche ce que le jeu renvoie quand tu pêches (clear pour vider)", "fishing probe: shows what the game returns while you fish (clear to empty)"),
  section = T("Pêche", "Fishing"),
  note = T("Prises comptées à chaque butin de pêche, valeur au prix du moment. Les réglages de son sont notés avant d'être changés et remis à la fin de la pêche (90 s sans relancer, ou au combat).",
    "Catches counted on every fishing loot, valued at current prices. Sound settings are recorded before being changed and put back when you stop fishing (90 s without casting, or in combat)."),
  opt = T("Suivre les sessions de pêche", "Track fishing sessions"),
  optSpots = T("Apprendre ce que donne chaque coin de pêche", "Learn what each fishing spot gives"),
  optSound = T("Sons de pêche : couper musique et ambiance, effets à fond", "Fishing sounds: mute music and ambience, effects at full volume"),
  optSoundTT = T("Pour bien entendre le bouchon plonger. Tes volumes reviennent dès que tu arrêtes de pêcher.",
    "To clearly hear the bobber splash. Your volumes come back as soon as you stop fishing."),
  optBG = T("Garder le son quand le jeu est en arrière-plan", "Keep sound when the game is in the background"),
  optCTM = T("Couper le clic pour se déplacer pendant la pêche", "Turn off click-to-move while fishing"),
  optCTMTT = T("Sinon un clic droit sur le bouchon peut te faire marcher vers lui. Rien ne change si l'option du jeu est déjà coupée.",
    "Otherwise right-clicking the bobber can make you walk to it. Nothing changes if the game option is already off."),
}
if ST.L then ST.L.METIER_VIEW_FISH = ST.FishText.view end
