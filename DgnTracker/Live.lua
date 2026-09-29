-- ================================================================
-- DgnTracker - Live.lua
-- Donnees lues dans le jeu, en complement des fichiers data\ :
--   - noms d'instances dans la langue du client et coordonnees exactes
--     (C_EncounterJournal.GetDungeonEntrancesForMap, C_AreaPoiInfo.GetDelvesForMap) ;
--   - instances absentes de data\ ajoutees automatiquement (extensions detect=true) ;
--   - boss du Journal d'aventure (EJ_GetInstanceInfo / EJ_GetEncounterInfoByIndex) ;
--   - verrouillages (GetSavedInstanceInfo), saison Mythique+ (C_ChallengeMode),
--     gouffres abondants du jour (atlas "bountiful" du POI) ;
--   - position du joueur pour la vue "Pres de moi".
-- Tout est paresseux : rien ne tourne tant que la fenetre n'est pas ouverte,
-- aucun OnUpdate, et chaque appel au client est protege par pcall (une API
-- absente ou modifiee par un patch ne casse jamais la fenetre, on retombe
-- simplement sur data\). Rien de tout cela n'est ecrit dans DgnTrackerDB, sauf
-- la sonde /dg probe, a la demande.
-- NON TESTE EN JEU : a valider par Tibiscui (redemarrage complet du client,
-- nouveau fichier).
-- ================================================================

DgnTrackerLive = DgnTrackerLive or {}
local Live = DgnTrackerLive

-- Infos d'execution par instance (table faible : n'alourdit ni data\ ni la SV)
local rt = setmetatable({}, { __mode = "k" })

-- ----------------------------------------------------------------
-- Outils texte
-- ----------------------------------------------------------------
local ACC = {
  ["à"]="a",["â"]="a",["ä"]="a",["á"]="a",["À"]="a",["Â"]="a",["Ä"]="a",
  ["é"]="e",["è"]="e",["ê"]="e",["ë"]="e",["É"]="e",["È"]="e",["Ê"]="e",
  ["î"]="i",["ï"]="i",["í"]="i",["Î"]="i",["Ï"]="i",
  ["ô"]="o",["ö"]="o",["ó"]="o",["Ô"]="o",["Ö"]="o",["œ"]="oe",["Œ"]="oe",
  ["û"]="u",["ü"]="u",["ú"]="u",["ù"]="u",["Û"]="u",["Ü"]="u",
  ["ç"]="c",["Ç"]="c",["ñ"]="n",["ß"]="ss",
}

-- Minuscules sans accents (meme principe que UI.Normalize du socle, dispo
-- meme sans socle).
function Live.Norm(s)
  if not s then return "" end
  s = tostring(s):lower()
  s = s:gsub("[\192-\255][\128-\191]*", function(ch) return ACC[ch] or ch end)
  return s
end

-- Cle de comparaison de noms : sans accents, sans article initial, sans
-- ponctuation ni espaces ("La Flèche du Vide" == "fleche du vide").
local function Key(s)
  -- Le jeu ecrit l'apostrophe typographique (’ ou ‘) : "L’Œil d’Azshara" ne
  -- trouvait jamais "L'Œil d'Azshara" (constate a la sonde du 2026-09-29).
  s = tostring(s or ""):gsub("\226\128\153", "'"):gsub("\226\128\152", "'")
  s = Live.Norm(s)
  s = s:gsub("^les? ", ""):gsub("^la ", ""):gsub("^l'", ""):gsub("^the ", "")
  s = s:gsub("[%s%p]", "")
  return s
end
Live.Key = Key

-- "La Flèche du Vide (6 boss)" -> "La Flèche du Vide", "6 boss"
function Live.SplitName(name)
  if not name then return "?", nil end
  local base, note = name:match("^(.-)%s*%((.+)%)%s*$")
  if base and base ~= "" then return base, note end
  return name, nil
end

local IS_FR = (GetLocale and GetLocale() == "frFR") and true or false
Live.IS_FR = IS_FR

-- ----------------------------------------------------------------
-- Index : chaque instance connait son extension (vues virtuelles)
-- ----------------------------------------------------------------
local indexed = false
-- jid / poi deja portes par une fiche (toutes extensions) : jamais "detectes"
Live.knownJid, Live.knownPoi = {}, {}
function Live.Index()
  if indexed then return end
  indexed = true
  for extKey, ext in pairs(DgnTrackerData or {}) do
    if type(ext) == "table" and ext.instances then
      for _, inst in ipairs(ext.instances) do
        inst._ext = extKey
        if inst.jid then Live.knownJid[inst.jid] = true end
        if inst.poi then Live.knownPoi[inst.poi] = true end
      end
    end
  end
end

function Live.Info(inst)
  local i = rt[inst]
  if not i then i = {}; rt[inst] = i end
  return i
end

-- Cle de comparaison du nom de data\ (calculee une fois par instance)
local function NameKey(inst)
  local i = Live.Info(inst)
  if not i.k then i.k = Key((Live.SplitName(inst.name))) end
  return i.k
end
Live.NameKey = NameKey

-- Nom a afficher : nom du jeu (langue du client) si connu, sinon data\.
-- En francais, on garde la precision entre parentheses de data\ (6 boss...).
function Live.DisplayName(inst)
  local base, note = Live.SplitName(inst.name)
  local i = rt[inst]
  if i and i.name and i.name ~= "" then
    if IS_FR then return i.name, note end
    return i.name, nil
  end
  return base, note
end

-- ----------------------------------------------------------------
-- Journal d'aventure (cache par journalInstanceID)
-- ----------------------------------------------------------------
local ejCache = {}
function Live.EJ(jid)
  if not jid or not EJ_GetInstanceInfo then return nil end
  local c = ejCache[jid]
  if c ~= nil then return c or nil end
  local ok, name, _, _, _, _, _, _, link, _, instMapID, _, isRaid = pcall(EJ_GetInstanceInfo, jid)
  if not ok or not name then ejCache[jid] = false; return nil end
  c = { name = name, instMapID = tonumber(instMapID), isRaid = isRaid and true or false, link = link }
  ejCache[jid] = c
  return c
end

function Live.Bosses(jid)
  local c = Live.EJ(jid)
  if not c then return nil end
  if c.bosses then return c.bosses end
  local list = {}
  if EJ_GetEncounterInfoByIndex then
    for i = 1, 25 do
      local ok, bname = pcall(EJ_GetEncounterInfoByIndex, i, jid)
      if not ok or not bname then break end
      list[#list + 1] = bname
    end
  end
  c.bosses = list
  return list
end

-- ----------------------------------------------------------------
-- Lecture des cartes (entrees + gouffres), cache par carte
-- ----------------------------------------------------------------
local mapCache = {}
local DELVE_TTL = 600   -- l'etat "abondant" change chaque jour : relu toutes les 10 min

local function ReadMap(mapID)
  local now = GetTime and GetTime() or 0
  local c = mapCache[mapID]
  if c and (now - c.t) < DELVE_TTL then return c end
  c = { t = now, list = {} }
  if C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap then
    local ok, ents = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, mapID)
    if ok and type(ents) == "table" then
      for _, e in ipairs(ents) do
        local pos = e.position
        if pos and e.name then
          local atlas = tostring(e.atlasName or "")
          local kind
          if atlas:find("[Rr]aid") then kind = "raid"
          elseif atlas:find("[Dd]ungeon") then kind = "dungeon" end
          if not kind then
            local ej = Live.EJ(e.journalInstanceID)
            kind = (ej and ej.isRaid) and "raid" or "dungeon"
          end
          c.list[#c.list + 1] = { kind = kind, name = e.name, x = pos.x * 100, y = pos.y * 100,
            map = mapID, jid = e.journalInstanceID, poi = e.areaPoiID, atlas = atlas }
        end
      end
    end
  end
  if C_AreaPoiInfo and C_AreaPoiInfo.GetDelvesForMap and C_AreaPoiInfo.GetAreaPOIInfo then
    local ok, pois = pcall(C_AreaPoiInfo.GetDelvesForMap, mapID)
    if ok and type(pois) == "table" then
      for _, poiID in ipairs(pois) do
        local ok2, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, poiID)
        if ok2 and type(info) == "table" and info.position and info.name then
          local atlas = tostring(info.atlasName or "")
          c.list[#c.list + 1] = { kind = "delve", name = info.name, x = info.position.x * 100,
            y = info.position.y * 100, map = mapID, poi = poiID, atlas = atlas,
            bountiful = atlas:lower():find("bountiful", 1, true) and true or false }
        end
      end
    end
  end
  mapCache[mapID] = c
  return c
end
Live.ReadMap = ReadMap

local function MapName(mapID)
  if not (C_Map and C_Map.GetMapInfo) then return nil end
  local ok, info = pcall(C_Map.GetMapInfo, mapID)
  return ok and info and info.name or nil
end
Live.MapName = MapName

-- ----------------------------------------------------------------
-- Rapprochement data\ <-> jeu, par extension
-- ----------------------------------------------------------------
local function Compatible(instType, kind)
  if kind == "delve" then return instType == "delve" end
  return instType == "dungeon" or instType == "raid"
end

local function Apply(inst, cand)
  local i = Live.Info(inst)
  i.name, i.nk = cand.name, nil
  i.x, i.y, i.mapID = cand.x, cand.y, cand.map
  i.jid = cand.jid or i.jid
  i.poi = cand.poi
  i.bountiful = cand.bountiful
  i.matched = true
  cand.used = inst
end

local resolved = {}
local stats = {}   -- par extension : reconnues / ajoutees / sans correspondance

function Live.ResolveExt(extKey, force)
  local ext = DgnTrackerData and DgnTrackerData[extKey]
  if type(ext) ~= "table" or not ext.instances then return end
  local now = GetTime and GetTime() or 0
  if resolved[extKey] and not force and (now - resolved[extKey]) < DELVE_TTL then return end
  resolved[extKey] = now
  Live.Index()

  -- 1) cartes a interroger
  local maps, order = {}, {}
  local function addMap(m) if m and not maps[m] then maps[m] = true; order[#order + 1] = m end end
  for _, inst in ipairs(ext.instances) do
    if inst.type ~= "torghast" and not inst.detected then
      addMap(inst.mapID)
      for _, m in ipairs(inst.altMaps or {}) do addMap(m) end
    end
  end
  for _, m in ipairs(ext.scanMaps or {}) do addMap(m) end

  local cands = {}
  for _, m in ipairs(order) do
    local c = ReadMap(m)
    for _, e in ipairs(c.list) do e.used = nil; cands[#cands + 1] = e end
  end

  -- instances a rapprocher (hors Torghast et hors ajouts precedents)
  local pending = {}
  for _, inst in ipairs(ext.instances) do
    if inst.type ~= "torghast" then
      if inst.detected then
        -- ajout d'une passe precedente : on le recale sur sa source
        for _, e in ipairs(cands) do
          if not e.used and e.map == inst.mapID and Key(e.name) == Key(inst.name) then Apply(inst, e); break end
        end
      else
        local i = Live.Info(inst); i.matched = nil
        pending[#pending + 1] = inst
      end
    end
  end

  local function onMap(inst, e)
    if e.map == inst.mapID then return true end
    for _, m in ipairs(inst.altMaps or {}) do if e.map == m then return true end end
    return false
  end

  -- 1) passe Journal d'aventure : jid= dans data\ (identique dans toutes les
  -- langues, pose d'apres la sonde /dg probe). Le plus fiable.
  for _, inst in ipairs(pending) do
    if inst.jid or inst.poi then
      -- Une meme entree peut figurer sur plusieurs cartes (Calamite
      -- Universitaire : Lune-d'Argent ET Bois des Chants Eternels) : on
      -- prend d'abord celle de la carte de la fiche, sinon n'importe laquelle.
      local pick
      for _, e in ipairs(cands) do
        if not e.used and ((inst.jid and e.jid == inst.jid) or (inst.poi and e.poi == inst.poi)) then
          if e.map == inst.mapID then pick = e; break end
          pick = pick or e
        end
      end
      if pick then Apply(inst, pick) end
    end
  end

  -- 2) passe nom (fiable en francais, et pour les noms propres dans toutes les
  -- langues), sur TOUTES les cartes de l'extension : corrige aussi une carte
  -- fausse dans data\. Ordre : nom identique + meme type (donjon/raid), puis
  -- nom identique, puis nom contenu dans l'autre ("(5j)" et "(ICC)" ne se
  -- volent plus l'entree du raid).
  local function namePass(mode)
    for _, inst in ipairs(pending) do
      local k = NameKey(inst)
      if not Live.Info(inst).matched and #k >= 4 then
        for _, e in ipairs(cands) do
          if not e.used and Compatible(inst.type, e.kind) then
            local ek = Key(e.name)
            local hit
            if mode == 1 then hit = (ek == k and e.kind == inst.type)
            elseif mode == 2 then hit = (ek == k)
            else hit = (#ek >= 6 and #k >= 6 and (ek:find(k, 1, true) or k:find(ek, 1, true))) end
            if hit then Apply(inst, e); break end
          end
        end
      end
    end
  end
  namePass(1); namePass(2); namePass(3)

  -- 3) passe distance : paires les plus proches d'abord, en refusant les cas
  -- ambigus (Grottes du temps : plusieurs entrees presque au meme point).
  local pairs_ = {}
  for _, inst in ipairs(pending) do
    local i = Live.Info(inst)
    if not i.matched and inst.coords then
      local best, bestD, second = nil, math.huge, math.huge
      for _, e in ipairs(cands) do
        if not e.used and Compatible(inst.type, e.kind) and onMap(inst, e) then
          local dx, dy = (e.x - inst.coords.x) / 100, (e.y - inst.coords.y) / 100
          local d = math.sqrt(dx * dx + dy * dy)
          if d < bestD then second = bestD; best, bestD = e, d
          elseif d < second then second = d end
        end
      end
      local limit = inst.approx and 0.30 or 0.06
      if best and bestD < limit and (second == math.huge or second > bestD * 1.5 + 0.01) then
        pairs_[#pairs_ + 1] = { inst = inst, e = best, d = bestD }
      end
    end
  end
  table.sort(pairs_, function(a, b) return a.d < b.d end)
  for _, p in ipairs(pairs_) do
    if not p.e.used and not Live.Info(p.inst).matched then Apply(p.inst, p.e) end
  end

  -- 4) ajout des instances trouvees en jeu et absentes de data\
  local st = { matched = 0, added = 0, missing = {} }
  for _, inst in ipairs(pending) do
    if Live.Info(inst).matched then st.matched = st.matched + 1
    else st.missing[#st.missing + 1] = inst.name end
  end
  local allowDetect = ext.detect and not (DgnTrackerDB and DgnTrackerDB.detect == false)
  if allowDetect then
    for _, e in ipairs(cands) do
      if not e.used and not (e.jid and Live.knownJid[e.jid]) and not (e.poi and Live.knownPoi[e.poi]) then
        local zone = MapName(e.map) or ""
        local inst = {
          name = e.name, type = e.kind, zone = zone, mapID = e.map,
          coords = { x = e.x, y = e.y }, tomtom = { mapID = e.map, x = e.x, y = e.y },
          detected = true, _ext = extKey,
        }
        ext.instances[#ext.instances + 1] = inst
        Apply(inst, e)
        st.added = st.added + 1
      end
    end
  end
  stats[extKey] = st
end

function Live.ResolveAll(force)
  for extKey in pairs(DgnTrackerData or {}) do Live.ResolveExt(extKey, force) end
end

function Live.Stats(extKey) return stats[extKey] end

-- Coordonnees effectives (jeu si connu, sinon data\)
function Live.Coords(inst)
  local i = rt[inst]
  if i and i.x and i.mapID then return i.mapID, i.x, i.y, true end
  local m = (inst.tomtom and inst.tomtom.mapID) or inst.accessMapID or inst.mapID
  local x = inst.tomtom and inst.tomtom.x or (inst.coords and inst.coords.x)
  local y = inst.tomtom and inst.tomtom.y or (inst.coords and inst.coords.y)
  return m, x, y, false
end

function Live.InstMapID(inst)
  local i = rt[inst]
  if not (i and i.jid) then return nil end
  local ej = Live.EJ(i.jid)
  return ej and ej.instMapID or nil
end

-- ----------------------------------------------------------------
-- Verrouillages
-- ----------------------------------------------------------------
local lockByMap, lockByKey = {}, {}
local lockAsked = 0

function Live.RequestLockouts()
  local now = GetTime and GetTime() or 0
  if now - lockAsked < 20 then return end
  lockAsked = now
  if RequestRaidInfo then pcall(RequestRaidInfo) end
end

local function ReadLockouts()
  lockByMap, lockByKey = {}, {}
  if not (GetNumSavedInstances and GetSavedInstanceInfo) then return end
  local okN, n = pcall(GetNumSavedInstances)
  local now = GetServerTime and GetServerTime() or time()
  for i = 1, (okN and tonumber(n) or 0) do
    local ok, name, _, reset, diffID, locked, extended, _, isRaid, _, diffName, numEnc, encProg, _, instID =
      pcall(GetSavedInstanceInfo, i)
    reset = ok and tonumber(reset) or 0
    if ok and name and (locked or extended) and reset > 0 then
      local l = { diff = diffName or "", diffID = tonumber(diffID), killed = tonumber(encProg) or 0,
        total = tonumber(numEnc) or 0, expires = now + reset, isRaid = isRaid and true or false }
      local id = tonumber(instID)
      if id then lockByMap[id] = lockByMap[id] or {}; table.insert(lockByMap[id], l) end
      local k = Key(name)
      lockByKey[k] = lockByKey[k] or {}; table.insert(lockByKey[k], l)
    end
  end
end

function Live.GetLockouts(inst)
  local id = Live.InstMapID(inst)
  if id and lockByMap[id] then return lockByMap[id] end
  local name = Live.DisplayName(inst)
  return lockByKey[Key(name)] or lockByKey[Key((Live.SplitName(inst.name)))]
end

function Live.HasAnyLockout() return next(lockByKey) ~= nil end

-- Difficulte courte + couleur (memes couleurs que WeeklyCompass)
local DIFF = {}
for _, id in ipairs({ 8, 16, 23 })          do DIFF[id] = { "M", "FF8000" } end
for _, id in ipairs({ 2, 5, 6, 15 })        do DIFF[id] = { "H", "B266FF" } end
for _, id in ipairs({ 1, 3, 4, 9, 14, 33 }) do DIFF[id] = { "N", "59A6FF" } end
for _, id in ipairs({ 7, 17 })              do DIFF[id] = { "LFR", "4DE64D" } end
function Live.DiffTag(l)
  local d = DIFF[l.diffID]
  if d then return d[1], d[2] end
  return (l.diff ~= "" and l.diff:sub(1, 3) or "?"), "999999"
end

-- ----------------------------------------------------------------
-- Saison Mythique+
-- ----------------------------------------------------------------
local season   -- { {cmid=, name=, instMapID=, texture=} }
local mpAsked = 0

function Live.RequestSeason()
  local now = GetTime and GetTime() or 0
  if now - mpAsked < 30 then return end
  mpAsked = now
  if C_MythicPlus and C_MythicPlus.RequestMapInfo then pcall(C_MythicPlus.RequestMapInfo) end
end

function Live.Season(force)
  if season and not force then return season end
  local list = {}
  if C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo then
    local ok, ids = pcall(C_ChallengeMode.GetMapTable)
    if ok and type(ids) == "table" then
      for _, cmid in ipairs(ids) do
        local ok2, name, _, timeLimit, texture, _, instMapID = pcall(C_ChallengeMode.GetMapUIInfo, cmid)
        if ok2 and name then
          list[#list + 1] = { cmid = cmid, name = name, instMapID = tonumber(instMapID),
            timeLimit = timeLimit, texture = texture }
        end
      end
    end
  end
  if #list > 0 then season = list end
  return list
end

-- Meilleure cle de la saison + score pour un donjon M+
function Live.MPlusFor(cmid)
  if not cmid then return nil end
  local r = { cmid = cmid }
  if C_MythicPlus and C_MythicPlus.GetSeasonBestForMap then
    local ok, inTime, overTime = pcall(C_MythicPlus.GetSeasonBestForMap, cmid)
    if ok then
      if type(inTime) == "table" and (inTime.level or 0) > 0 then
        r.level, r.sec = inTime.level, inTime.durationSec
      elseif type(overTime) == "table" and (overTime.level or 0) > 0 then
        r.level, r.sec, r.over = overTime.level, overTime.durationSec, true
      end
    end
  end
  if C_MythicPlus and C_MythicPlus.GetSeasonBestAffixScoreInfoForMap then
    local ok, _, score = pcall(C_MythicPlus.GetSeasonBestAffixScoreInfoForMap, cmid)
    if ok and tonumber(score) and score > 0 then r.score = math.floor(score + 0.5) end
  end
  return r
end

function Live.OverallScore()
  if C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
    local ok, s = pcall(C_ChallengeMode.GetOverallDungeonScore)
    if ok and tonumber(s) then return math.floor(s + 0.5) end
  end
  return nil
end

-- Donjon de la saison correspondant a une instance (par mapID d'instance, puis par nom)
function Live.SeasonEntryFor(inst)
  if inst.type ~= "dungeon" then return nil end
  local list = Live.Season()
  if #list == 0 then return nil end
  local id = Live.InstMapID(inst)
  local k1 = Key((Live.DisplayName(inst)))
  local k2 = Key((Live.SplitName(inst.name)))
  for _, s in ipairs(list) do
    if (id and s.instMapID == id) or Key(s.name) == k1 or Key(s.name) == k2 then return s end
  end
  return nil
end

-- ----------------------------------------------------------------
-- Recherche d'une instance (API publique, vues virtuelles)
-- ----------------------------------------------------------------
function Live.ForEach(fn)
  Live.Index()
  for extKey, ext in pairs(DgnTrackerData or {}) do
    if type(ext) == "table" and ext.instances then
      for _, inst in ipairs(ext.instances) do
        if fn(inst, extKey) then return inst, extKey end
      end
    end
  end
end

-- q : nom (n'importe quelle langue connue), ou table
--     { name=, instMapID=, challengeMapID=, jid=, type= }
function Live.Find(q)
  if type(q) ~= "table" then q = { name = q } end
  if q.challengeMapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
    local ok, name, _, _, _, _, instMapID = pcall(C_ChallengeMode.GetMapUIInfo, q.challengeMapID)
    if ok then q.name = q.name or name; q.instMapID = q.instMapID or tonumber(instMapID) end
  end
  local key = q.name and Key((Live.SplitName(q.name))) or nil
  local function test(inst)
    if q.type and inst.type ~= q.type then return false end
    local i = rt[inst]
    if q.jid and i and i.jid == q.jid then return true end
    if key and key ~= "" then
      if NameKey(inst) == key then return true end
      if i and i.name then
        if not i.nk then i.nk = Key(i.name) end
        if i.nk == key then return true end
      end
    end
    return false
  end
  local inst, extKey = Live.ForEach(test)
  if inst then return inst, extKey end
  -- pas trouve tel quel : on interroge le jeu (noms localises), puis mapID d'instance
  Live.ResolveAll()
  inst, extKey = Live.ForEach(test)
  if inst then return inst, extKey end
  if q.instMapID then
    return Live.ForEach(function(i) return Live.InstMapID(i) == q.instMapID end)
  end
  return nil
end

-- Recherche partielle (/dg <morceau de nom>) : premiere instance dont le nom
-- (data\ ou traduit) contient le texte, sans accents.
function Live.FindLoose(text)
  local k = Key(text)
  if #k < 3 then return nil end
  return Live.ForEach(function(inst)
    if NameKey(inst):find(k, 1, true) then return true end
    local i = rt[inst]
    return i and i.name and Key(i.name):find(k, 1, true) and true or false
  end)
end

-- ----------------------------------------------------------------
-- Position du joueur / distance
-- ----------------------------------------------------------------
function Live.PlayerPos()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local okM, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  if not okM or not mapID then return nil end
  local okP, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
  if not okP or not pos then return mapID end   -- en instance : pas de position
  return mapID, pos.x * 100, pos.y * 100
end

local function World(mapID, x, y)
  if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
  local ok, cont, wp = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x / 100, y / 100))
  if ok and cont and wp then return cont, wp.x, wp.y end
  return nil
end

-- Le joueur est-il sur le meme continent que ce point ? (nil = inconnu)
-- Les points de route du jeu et de TomTom ne guident que sur le continent
-- courant : on le signale au joueur au lieu de le laisser chercher la fleche.
function Live.SameContinent(mapID, x, y)
  local pMap, px, py = Live.PlayerPos()
  if not (pMap and px and mapID and x) then return nil end
  local c1 = World(pMap, px, py)
  local c2 = World(mapID, x, y)
  if not (c1 and c2) then return nil end
  return c1 == c2
end

-- Distance en metres/yards du jeu (nil si incalculable : autre continent...)
function Live.Distance(pMap, px, py, inst)
  local m, x, y = Live.Coords(inst)
  if not (pMap and px and m and x) then return nil end
  local c1, x1, y1 = World(pMap, px, py)
  local c2, x2, y2 = World(m, x, y)
  if c1 and c2 and c1 == c2 then
    return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
  end
  return nil
end

-- Instances de la zone du joueur (et de sa zone parente si rien), triees par distance
function Live.Nearby()
  local pMap, px, py = Live.PlayerPos()
  if not pMap then return {}, nil end
  Live.ResolveAll()
  local function collect(mapID)
    local out = {}
    Live.ForEach(function(inst)
      if inst.type ~= "torghast" then
        local m = Live.Coords(inst)
        if m == mapID or inst.mapID == mapID then out[#out + 1] = inst end
      end
    end)
    return out
  end
  local list = collect(pMap)
  local shownMap = pMap
  if #list == 0 and C_Map and C_Map.GetMapInfo then
    local ok, info = pcall(C_Map.GetMapInfo, pMap)
    if ok and info and info.parentMapID and info.parentMapID > 0 then
      list = collect(info.parentMapID)
      shownMap = info.parentMapID
    end
  end
  for _, inst in ipairs(list) do
    Live.Info(inst).dist = Live.Distance(pMap, px, py, inst)
  end
  table.sort(list, function(a, b)
    local da, db = Live.Info(a).dist or math.huge, Live.Info(b).dist or math.huge
    if da ~= db then return da < db end
    return (a.name or "") < (b.name or "")
  end)
  return list, shownMap
end

-- ----------------------------------------------------------------
-- Sonde /dg probe : ecrit ce que renvoie le jeu dans DgnTrackerDB.probe
-- (a envoyer a Tibiscui pour corriger data\ ; /dg probe clear pour effacer)
-- ----------------------------------------------------------------
-- ----------------------------------------------------------------
-- Controle /dg check : compare chaque fiche a l'entree renvoyee par le jeu.
-- Renvoie { moved = { {inst, fromMap, fx, fy, toMap, tx, ty} }, missing = {inst}, ok = n }
-- "moved" : carte differente, ou ecart > 2 % de la carte. Le point de route
-- utilise deja la position du jeu ; la liste sert a corriger data\.
-- ----------------------------------------------------------------
function Live.Check()
  for k in pairs(mapCache) do mapCache[k] = nil end
  Live.ResolveAll(true)
  local r = { moved = {}, missing = {}, ok = 0 }
  Live.ForEach(function(inst)
    if inst.type == "torghast" or inst.detected then return end
    local i = rt[inst]
    if not (i and i.matched) then
      r.missing[#r.missing + 1] = inst
      return
    end
    local m = (inst.tomtom and inst.tomtom.mapID) or inst.mapID
    local x = inst.tomtom and inst.tomtom.x or (inst.coords and inst.coords.x)
    local y = inst.tomtom and inst.tomtom.y or (inst.coords and inst.coords.y)
    local same = (m == i.mapID)
    local far = not (x and y) or math.abs(x - i.x) > 2 or math.abs(y - i.y) > 2
    if not same or far then
      r.moved[#r.moved + 1] = { inst = inst, fromMap = m, fx = x, fy = y, toMap = i.mapID, tx = i.x, ty = i.y }
    else
      r.ok = r.ok + 1
    end
  end)
  -- Trace pour Tibiscui (ecrite a /reload), sans alourdir : texte seulement
  local lines = {}
  for _, e in ipairs(r.moved) do
    lines[#lines + 1] = string.format("%s|%s|%s %.2f,%.2f -> %s %.2f,%.2f|jid=%s", tostring(e.inst._ext), e.inst.name,
      tostring(e.fromMap), e.fx or 0, e.fy or 0, tostring(e.toMap), e.tx or 0, e.ty or 0, tostring(rt[e.inst].jid))
  end
  for _, inst in ipairs(r.missing) do
    lines[#lines + 1] = string.format("%s|%s|NON TROUVE (carte %s)", tostring(inst._ext), inst.name, tostring(inst.mapID))
  end
  if DgnTrackerDB then DgnTrackerDB.check = { date = date and date("%Y-%m-%d %H:%M") or "", locale = GetLocale and GetLocale() or "", lines = lines } end
  return r
end

function Live.Probe()
  local out = { date = date and date("%Y-%m-%d %H:%M") or "", locale = GetLocale and GetLocale() or "",
    build = select(4, GetBuildInfo()), maps = {}, exts = {}, season = {}, lockouts = {} }
  for k in pairs(mapCache) do mapCache[k] = nil end
  Live.ResolveAll(true)
  for mapID, c in pairs(mapCache) do
    local m = { name = MapName(mapID), list = {} }
    for _, e in ipairs(c.list) do
      m.list[#m.list + 1] = string.format("%s|%s|%.2f|%.2f|jid=%s|poi=%s|%s",
        e.kind, e.name, e.x, e.y, tostring(e.jid), tostring(e.poi), e.atlas or "")
    end
    out.maps[mapID] = m
  end
  local tm, ta, tx = 0, 0, 0
  for extKey, st in pairs(stats) do
    out.exts[extKey] = { matched = st.matched, added = st.added, missing = st.missing }
    tm, ta, tx = tm + st.matched, ta + st.added, tx + #st.missing
  end
  for _, s in ipairs(Live.Season(true)) do
    out.season[#out.season + 1] = string.format("%d|%s|inst=%s", s.cmid, s.name, tostring(s.instMapID))
  end
  if GetNumSavedInstances and GetSavedInstanceInfo then
    for i = 1, (tonumber(GetNumSavedInstances()) or 0) do
      local r = { pcall(GetSavedInstanceInfo, i) }
      if r[1] then
        local parts = {}
        for j = 2, #r do parts[#parts + 1] = tostring(r[j]) end
        out.lockouts[#out.lockouts + 1] = table.concat(parts, "|")
      end
    end
  end
  if DgnTrackerDB then DgnTrackerDB.probe = out end
  return tm, ta, tx
end

-- ----------------------------------------------------------------
-- Evenements : on previent l'interface (Live.onChange), avec un petit delai
-- pour regrouper les rafales.
-- ----------------------------------------------------------------
local pending = false
local function Notify()
  if pending then return end
  pending = true
  C_Timer.After(0.3, function()
    pending = false
    if Live.onChange then pcall(Live.onChange) end
  end)
end
Live.Notify = Notify

local ev = CreateFrame("Frame")
ev:RegisterEvent("UPDATE_INSTANCE_INFO")
ev:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
ev:RegisterEvent("BOSS_KILL")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:SetScript("OnEvent", function(_, event)
  if event == "UPDATE_INSTANCE_INFO" then
    ReadLockouts(); Notify()
  elseif event == "CHALLENGE_MODE_MAPS_UPDATE" then
    Live.Season(true); Notify()
  elseif event == "BOSS_KILL" then
    C_Timer.After(2, function() lockAsked = 0; Live.RequestLockouts() end)
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    Notify()
  end
end)
