-- ================================================================
--  SkillTracker  -  Core.lua
--  Detection des metiers, scan par extension, reset au changement de
--  metier, persistance SavedVariables, agregation multi-personnages,
--  export / import, API publique de la suite, evenements et commandes slash.
--
--  Aucune variable globale hormis les points d'entree publics attendus
--  par TibiSuite : SkillTracker_Toggle, SkillTracker_OpenOptions, la
--  frame SkillTrackerMainFrame (creee dans UI.lua), les fonctions du
--  compartiment d'addons et l'API en lecture seule _G.SkillTrackerAPI.
--  Tout le reste vit dans la table privee ST.
-- ================================================================

local ADDON, ST = ...
local L = ST.L

-- Version de schema des donnees sauvegardees (pour migrations futures).
local SCHEMA = 3

ST.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version"))
  or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "?"
ST.TAG = "|cFF00FF98SkillTracker|r"

-- Etat runtime (non sauvegarde)
ST.runtime = ST.runtime or { concAlerted = {}, concCids = {} }

local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end
ST.HasCore = HasCore

-- ================================================================
-- ACCES BASE DE DONNEES
-- ================================================================
local DB_DEFAULTS = {
  enabled      = true,
  minimap      = true,
  hideMaxed    = false,   -- masquer les paliers (extensions) au max
  hideMaxProf  = false,   -- masquer les metiers entierement au max
  showAllChars = true,
  showTodo     = true,    -- afficher la liste "a finir"
  concAlert    = true,    -- alerter quand la concentration du perso connecte est pleine
  concAltAlert = true,    -- au login, signaler les alts dont la concentration est pleine
  badge        = true,    -- pastille sur l'onglet de la suite (concentrations pleines)
  recipes      = true,    -- enregistrer les recettes connues (Recipes.lua)
  recipeScope  = "current", -- "current" (extension en cours) / "all"
  recipeTooltip = true,   -- "Tes personnages savent le fabriquer" dans l'info-bulle des objets
  mmAngle      = 210,
  accountTag   = nil,     -- libelle libre pour distinguer ses comptes a l'import
  metierView   = "current", -- "current" / "all" / "account" / "conc" / "week"
}

local function InitDB()
  SkillTrackerDB = SkillTrackerDB or {}
  local db = SkillTrackerDB

  if db.schema == nil then db.schema = SCHEMA end
  if (db.schema or 0) < 2 then
    -- v1 -> v2 : purge des anciens paliers sans nom d'extension (onglets "???").
    if type(db.chars) == "table" then
      for _, list in pairs(db.chars) do
        if type(list) == "table" then
          for _, c in pairs(list) do
            if type(c) == "table" and type(c.professions) == "table" then
              for _, prof in pairs(c.professions) do
                if type(prof) == "table" then prof.lines = {} end
              end
            end
          end
        end
      end
    end
    db.schema = 2
  end
  if db.schema < 3 then
    -- v2 -> v3 : l'etat "alerte deja affichee" passe en memoire (plus dans
    -- la sauvegarde) ; tout le reste est conserve tel quel.
    if type(db.chars) == "table" then
      for _, list in pairs(db.chars) do
        for _, c in pairs(type(list) == "table" and list or {}) do
          for _, prof in pairs(type(c) == "table" and type(c.professions) == "table" and c.professions or {}) do
            if type(prof) == "table" then prof._concAlerted = nil end
          end
        end
      end
    end
    db.schema = 3
  end
  db.schema = SCHEMA

  db.settings = db.settings or {}
  for k, v in pairs(DB_DEFAULTS) do
    if db.settings[k] == nil then db.settings[k] = v end
  end

  db.chars     = db.chars or {}       -- chars[realm][name] = { ... }
  db.imported  = db.imported or {}    -- imported[accountTag][realm][name] = { ... }
  db.tierIndex = db.tierIndex or {}   -- skillLineID -> index d'extension (appris)
  db.concRate  = db.concRate or {}    -- vitesse de recharge apprise (voir Concentration.lua)
  db.recipeCache = db.recipeCache or {} -- recipeID -> { n, i, o, p, t } (voir Recipes.lua)

  ST.db = db
  ST.settings = db.settings
  return db
end

local function CurrentCharKey()
  return GetRealmName() or "Unknown", UnitName("player") or "Unknown"
end
ST.CurrentCharKey = CurrentCharKey

local function EnsureCurrentChar()
  local realm, name = CurrentCharKey()
  ST.db.chars[realm] = ST.db.chars[realm] or {}
  local c = ST.db.chars[realm][name]
  if not c then
    c = { professions = {} }
    ST.db.chars[realm][name] = c
  end
  c.professions = c.professions or {}
  c.class   = select(2, UnitClass("player")) or c.class
  c.faction = UnitFactionGroup("player") or c.faction
  return c, realm, name
end
ST.EnsureCurrentChar = EnsureCurrentChar

function ST.CurrentRec()
  if not ST.db then return nil end
  local realm, name = CurrentCharKey()
  return ST.db.chars[realm] and ST.db.chars[realm][name]
end

-- ================================================================
-- CALCUL DE PROGRESSION
-- ================================================================
function ST.Percent(cur, max)
  cur = tonumber(cur) or 0
  max = tonumber(max) or 0
  if max <= 0 then return 0 end
  local p = math.floor((cur / max) * 100 + 0.5)
  if p < 0 then p = 0 elseif p > 100 then p = 100 end
  return p
end

-- Palier de l'extension en cours d'un metier (ou nil).
function ST.CurrentLine(prof)
  if type(prof) ~= "table" then return nil end
  local cur = ST.CurrentExpIndex()
  for id, ln in pairs(prof.lines or {}) do
    if ST.LineIndex(ln) == cur then return ln, id end
  end
  return nil
end

-- ================================================================
-- SCAN DES METIERS
-- GetProfessions() dit quels metiers sont connus MAINTENANT (sans fenetre).
-- Le detail par extension vient de C_TradeSkillUI, disponible apres
-- l'ouverture d'une fenetre de metier : on fusionne quand il est la et on
-- conserve le cache sinon (jamais de perte de donnees).
-- ================================================================
local function GatherKnownProfessions()
  local known, arch = {}, nil
  if type(GetProfessions) ~= "function" then return known, arch end
  local p1, p2, archIdx, fishIdx, cookIdx = GetProfessions()

  local function readInto(idx, isPrimary)
    if not idx then return end
    local name, _, cur, max, _, _, skillLine, _, _, _, lineName = GetProfessionInfo(idx)
    if skillLine and name then
      known[skillLine] = { name = name, cur = cur or 0, max = max or 0, isPrimary = isPrimary,
                           lineName = lineName }
    end
  end
  readInto(p1, true)
  readInto(p2, true)
  readInto(fishIdx, false)
  readInto(cookIdx, false)

  if archIdx then
    local name, _, cur, max = GetProfessionInfo(archIdx)
    if name then arch = { name = name, cur = cur or 0, max = max or 0 } end
  end
  return known, arch
end

local function StartsWith(s, prefix)
  return type(s) == "string" and type(prefix) == "string"
    and prefix ~= "" and s:sub(1, #prefix) == prefix
end

-- Fusionne le detail par extension depuis C_TradeSkillUI.
local function MergeExpansionDetail(char, known)
  local api = C_TradeSkillUI
  if not api then return end
  local UNKNOWN = _G.UNKNOWN

  local nameToParent = {}
  for sl, info in pairs(known) do
    if info.name then nameToParent[info.name] = sl end
  end

  local function storeLine(parent, id, cur, max, exp)
    if not parent or not known[parent] then return end
    if (max or 0) <= 0 or not id then return end
    if exp == nil or exp == "" then return end
    if UNKNOWN and exp == UNKNOWN then return end
    local prof = char.professions[parent]
    if not prof then return end
    prof.lines = prof.lines or {}
    local ln = prof.lines[id] or {}
    ln.cur, ln.max, ln.exp = cur or 0, max or 0, exp
    prof.lines[id] = ln   -- on garde ln.kp / ln.idx deja connus
  end

  -- Source 1 : metier actuellement ouvert (inclut Cuisine / Peche).
  if api.GetBaseProfessionInfo and api.GetChildProfessionInfos then
    local ok, base = pcall(api.GetBaseProfessionInfo)
    local ok2, kids = pcall(api.GetChildProfessionInfos)
    if ok and ok2 and base and base.professionID and type(kids) == "table" then
      for _, k in ipairs(kids) do
        storeLine(base.professionID, k.professionID, k.skillLevel, k.maxSkillLevel, k.expansionName)
      end
    end
  end

  -- Source 2 : toutes les lignes de metiers principaux.
  if api.GetAllProfessionTradeSkillLines and api.GetProfessionInfoBySkillLineID then
    local ok, lines = pcall(api.GetAllProfessionTradeSkillLines)
    if ok and type(lines) == "table" then
      for _, id in ipairs(lines) do
        local i = api.GetProfessionInfoBySkillLineID(id)
        if i and (i.maxSkillLevel or 0) > 0 then
          local parent = i.parentProfessionID
          if not (parent and known[parent]) then
            parent = nil
            for pname, psl in pairs(nameToParent) do
              if StartsWith(i.professionName, pname) then parent = psl break end
            end
          end
          storeLine(parent, id, i.skillLevel, i.maxSkillLevel, i.expansionName)
        end
      end
    end
  end
end

-- Palier de l'extension en cours : constate en jeu (2026-10-06), pour un
-- metier de recolte C_TradeSkillUI garde le niveau du palier tant que la
-- fenetre du metier n'a pas ete rouverte (Herboristerie 96 au lieu de 100).
-- GetProfessionInfo (grimoire, celui de la fenetre Metiers de Blizzard) est
-- toujours a jour et decrit ce palier : on le recopie, apres avoir verifie
-- que c'est bien le meme palier (nom du palier, sinon meme maximum).
local function SyncCurrentLine(char, known)
  local api = C_TradeSkillUI
  for parent, kinfo in pairs(known) do
    local prof = char.professions[parent]
    local ln, id = ST.CurrentLine(prof)
    if ln and (kinfo.max or 0) > 0 then
      local same
      if kinfo.lineName and api and api.GetProfessionInfoBySkillLineID then
        local ok, i = pcall(api.GetProfessionInfoBySkillLineID, id)
        if ok and i and i.professionName and i.professionName ~= "" then
          same = (i.professionName == kinfo.lineName)
        end
      end
      if same == nil then same = (kinfo.max == ln.max) end
      if same then ln.cur, ln.max = kinfo.cur or ln.cur, kinfo.max end
    end
  end
end

-- ================================================================
-- CONCENTRATION + POINTS DE CONNAISSANCE (lecture brute)
-- Une lecture absente (fenetre de metier fermee, donnees pas chargees)
-- ne remplace JAMAIS une valeur deja connue : le cache est conserve.
-- ================================================================

-- Concentration : on tente GetConcentrationCurrencyID sur les paliers (le
-- plus recent d'abord), puis la monnaie deja memorisee (prof.concCid), lue
-- directement via C_CurrencyInfo : c'est ce qui permet une lecture a la
-- connexion, sans ouvrir le metier (a confirmer en jeu).
local function ReadConcentration(prof, skillLineIDs)
  if not C_CurrencyInfo then return nil end
  local function read(cid)
    local ci = C_CurrencyInfo.GetCurrencyInfo(cid)
    if ci and (ci.maxQuantity or 0) > 0 then
      return { cur = ci.quantity or 0, max = ci.maxQuantity or 0, currencyID = cid }
    end
  end
  if C_TradeSkillUI and C_TradeSkillUI.GetConcentrationCurrencyID then
    for _, sl in ipairs(skillLineIDs) do
      local ok, cid = pcall(C_TradeSkillUI.GetConcentrationCurrencyID, sl)
      if ok and type(cid) == "number" and cid > 0 then
        local r = read(cid)
        if r then prof.concCid = cid; return r end
      end
    end
  end
  if type(prof.concCid) == "number" then return read(prof.concCid) end
  return nil
end

-- Points de connaissance non depenses pour UN palier (nil si illisible).
local function ReadLineKnowledge(sl)
  if type(C_ProfSpecs) ~= "table" or type(C_ProfSpecs.GetCurrencyInfoForSkillLine) ~= "function" then
    return nil
  end
  local ok, r = pcall(C_ProfSpecs.GetCurrencyInfoForSkillLine, sl)
  if not ok then return nil end
  if type(r) == "table" then
    local q = r.numAvailable or r.quantity or r.amount
    if type(q) == "number" then return q end
    local cid = r.currencyID or r.currencyType
    if type(cid) == "number" and cid > 0 and C_CurrencyInfo then
      local ci = C_CurrencyInfo.GetCurrencyInfo(cid)
      if ci and type(ci.quantity) == "number" then return ci.quantity end
    end
  elseif type(r) == "number" and r > 0 and C_CurrencyInfo then
    local ci = C_CurrencyInfo.GetCurrencyInfo(r)
    if ci and type(ci.quantity) == "number" then return ci.quantity end
  end
  return nil
end

local function ReadProfessionMeta(char, known)
  wipe(ST.runtime.concCids)
  for parent, kinfo in pairs(known) do
    local prof = char.professions[parent]
    if kinfo.isPrimary and prof then
      -- Candidats : palier le plus recent d'abord, puis le parent.
      local ordered = {}
      for id, ln in pairs(prof.lines or {}) do
        ordered[#ordered + 1] = { id = id, idx = ST.LineIndex(ln) or -1 }
      end
      table.sort(ordered, function(a, b) return a.idx > b.idx end)
      local ids = {}
      for _, o in ipairs(ordered) do ids[#ids + 1] = o.id end
      ids[#ids + 1] = parent

      local reading = ReadConcentration(prof, ids)
      if reading and ST.ConcRecord then ST.ConcRecord(prof, reading) end
      if prof.concCid then ST.runtime.concCids[prof.concCid] = true end

      -- Points de connaissance : par palier, total = somme des lisibles.
      -- Palier illisible : on garde la derniere valeur connue.
      local anyRead = false
      for id, ln in pairs(prof.lines or {}) do
        local q = ReadLineKnowledge(id)
        if type(q) == "number" then
          anyRead = true
          ln.kp = (q > 0) and q or nil
        end
      end
      if anyRead then
        local total = 0
        for _, ln in pairs(prof.lines or {}) do total = total + (ln.kp or 0) end
        prof.kp = total
        prof.kpT = time()
      end

      -- Arbres de specialisation du palier courant (Knowledge.lua).
      if ST.ReadSpecTree then
        local _, curID = ST.CurrentLine(prof)
        if curID then
          local spent, max = ST.ReadSpecTree(curID)
          if spent then prof.tree = { spent = spent, max = max, t = time() } end
        end
      end

      -- Alerte concentration pleine du perso connecte : une fois par passage a plein.
      if ST.settings.concAlert and prof.conc and (prof.conc.max or 0) > 0 then
        local key = tostring(parent)
        if prof.conc.cur >= prof.conc.max then
          if not ST.runtime.concAlerted[key] then
            ST.runtime.concAlerted[key] = true
            local msg = string.format(L.CONC_FULL_ALERT, prof.name or "?", prof.conc.cur, prof.conc.max)
            print(ST.TAG .. " " .. msg)
            -- Fil d'activite de TibiSuite (trace seulement : l'alerte est deja dans le chat).
            if _G.TibiSuite and _G.TibiSuite.Notify then
              pcall(_G.TibiSuite.Notify, "Skill", msg, { toast = false })
            end
          end
        else
          ST.runtime.concAlerted[key] = nil
        end
      end
    end
  end
end

function ST.ScanProfessions()
  if not ST.db then return end
  if ST.settings and ST.settings.enabled == false then return end

  local char = EnsureCurrentChar()
  local known, arch = GatherKnownProfessions()

  local knownCount = 0
  for _ in pairs(known) do knownCount = knownCount + 1 end

  if knownCount > 0 then
    -- RESET au changement de metier : un parent stocke mais plus connu est supprime.
    for parent in pairs(char.professions) do
      if not known[parent] then
        char.professions[parent] = nil
        if char.recipes then char.recipes[parent] = nil end
      end
    end
    for parent, kinfo in pairs(known) do
      local p = char.professions[parent]
      if not p then
        p = { lines = {} }
        char.professions[parent] = p
      end
      p.lines     = p.lines or {}
      p.name      = kinfo.name or p.name
      p.parent    = parent
      p.isPrimary = kinfo.isPrimary and true or false
      p.base      = { cur = kinfo.cur or 0, max = kinfo.max or 0 }
    end
  end

  MergeExpansionDetail(char, known)
  for _, p in pairs(char.professions) do ST.ResolveLineIndexes(p, ST.db.tierIndex) end
  SyncCurrentLine(char, known)
  ReadProfessionMeta(char, known)

  if arch then
    char.archaeology = { cur = arch.cur or 0, max = arch.max or 0, name = arch.name }
  else
    char.archaeology = nil
  end

  if ST.UpdateWeeklyAuto then ST.UpdateWeeklyAuto(char) end
  char.lastScan = time()

  if ST.UpdateBadge then ST.UpdateBadge() end
  if ST.RefreshUI then ST.RefreshUI() end
end

-- Scan differe et coalesce (aucun OnUpdate, aucune boucle serree).
function ST.RequestScan(delay)
  if ST.runtime.scanPending then return end
  ST.runtime.scanPending = true
  C_Timer.After(delay or 1.0, function()
    ST.runtime.scanPending = false
    local ok, err = pcall(ST.ScanProfessions)
    if not ok and ST.runtime.debug then
      print(ST.TAG .. " scan error: " .. tostring(err))
    end
  end)
end

-- ================================================================
-- AGREGATION MULTI-PERSONNAGES
-- ================================================================
local function ProfessionOverallPercent(prof)
  if prof.lines then
    local sum, n = 0, 0
    for _, ln in pairs(prof.lines) do
      sum = sum + ST.Percent(ln.cur, ln.max)
      n = n + 1
    end
    if n > 0 then return math.floor(sum / n + 0.5) end
  end
  if prof.base then return ST.Percent(prof.base.cur, prof.base.max) end
  return 0
end
ST.ProfessionOverallPercent = ProfessionOverallPercent

-- Nombre de paliers connus et de paliers au max d'un metier.
function ST.LineCounts(prof)
  local n, maxed = 0, 0
  for _, ln in pairs(prof.lines or {}) do
    n = n + 1
    if ST.Percent(ln.cur, ln.max) >= 100 then maxed = maxed + 1 end
  end
  return n, maxed
end

-- Liste des personnages (locaux + importes), perso courant en tete.
function ST.BuildCharList()
  local out = {}
  local curRealm, curName = CurrentCharKey()
  local function add(realm, name, rec, imported, tag)
    if type(rec) ~= "table" then return end
    out[#out + 1] = {
      key      = (realm or "") .. "\t" .. (name or ""),
      name     = name, realm = realm, class = rec.class,
      imported = imported and true or false, accountTag = tag, rec = rec,
      current  = (not imported) and realm == curRealm and name == curName,
    }
  end
  for realm, list in pairs(ST.db.chars) do
    for name, rec in pairs(list) do add(realm, name, rec, false, nil) end
  end
  for tag, realms in pairs(ST.db.imported) do
    for realm, list in pairs(realms) do
      for name, rec in pairs(list) do add(realm, name, rec, true, tag) end
    end
  end
  table.sort(out, function(a, b)
    if a.current ~= b.current then return a.current end
    if a.imported ~= b.imported then return not a.imported end
    if (a.name or "") ~= (b.name or "") then return (a.name or "") < (b.name or "") end
    return (a.realm or "") < (b.realm or "")
  end)
  return out
end

-- Liste "A finir" : paliers < 100% de tous les persos locaux.
function ST.BuildTodo()
  local out = {}
  for realm, list in pairs(ST.db.chars) do
    for name, rec in pairs(list) do
      if type(rec) == "table" and type(rec.professions) == "table" then
        for _, prof in pairs(rec.professions) do
          for _, ln in pairs(prof.lines or {}) do
            local pct = ST.Percent(ln.cur, ln.max)
            if pct < 100 then
              out[#out + 1] = {
                char = name, realm = realm, prof = prof.name or "?",
                exp = ln.exp, idx = ST.LineIndex(ln),
                cur = ln.cur, max = ln.max, pct = pct,
              }
            end
          end
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.pct ~= b.pct then return a.pct > b.pct end
    if a.prof ~= b.prof then return a.prof < b.prof end
    return (a.char or "") < (b.char or "")
  end)
  return out
end

-- ================================================================
-- EXPORT / IMPORT  (multi-comptes, installations separees)
-- ----------------------------------------------------------------
-- STEXPORT2 : une seule ligne (la zone de saisie du jeu n'accepte pas les
-- retours a la ligne : l'ancien format multi-lignes etait tronque au collage).
-- Enregistrements separes par ";", champs par ",", encodage %XX pour les
-- caracteres reserves. Jamais de "|" (caractere d'echappement du jeu).
-- STEXPORT1 (ancien, multi-lignes) reste lisible a l'import.
-- Aucun loadstring : aucune execution de code importe.
-- ================================================================
local EXPORT_V1, EXPORT_V2 = "STEXPORT1", "STEXPORT2"

local function enc(s)
  s = tostring(s or "")
  return (s:gsub("[%%,;|\n\r~]", function(c) return string.format("%%%02X", c:byte()) end))
end
local function dec(s)
  s = tostring(s or "")
  return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end
local function unescV1(s)
  s = tostring(s or "")
  s = s:gsub("\\n", "\n"):gsub("\\p", "|"):gsub("\\\\", "\\")
  return s
end

function ST.ExportString()
  local tag = (ST.settings.accountTag and ST.settings.accountTag ~= "")
    and ST.settings.accountTag or (GetRealmName() or "account")
  local recs = { EXPORT_V2, "T," .. enc(tag) }
  local any = false
  local function add(...) recs[#recs + 1] = table.concat({ ... }, ",") end

  for realm, list in pairs(ST.db.chars) do
    for name, rec in pairs(list) do
      any = true
      add("C", enc(realm), enc(name), enc(rec.class or ""), enc(rec.faction or ""))
      for parent, prof in pairs(rec.professions or {}) do
        add("P", tostring(parent), enc(prof.name or ""), prof.isPrimary and "1" or "0")
        if prof.base then add("B", tostring(prof.base.cur or 0), tostring(prof.base.max or 0)) end
        for id, ln in pairs(prof.lines or {}) do
          add("L", tostring(id), tostring(ln.cur or 0), tostring(ln.max or 0), enc(ln.exp or ""))
        end
        if prof.conc then
          add("K", tostring(prof.conc.cur or 0), tostring(prof.conc.max or 0), tostring(prof.conc.t or 0))
        end
      end
      if rec.archaeology then
        add("A", tostring(rec.archaeology.cur or 0), tostring(rec.archaeology.max or 0),
          enc(rec.archaeology.name or ""))
      end
    end
  end
  if not any then return nil end
  return table.concat(recs, ";")
end

function ST.ImportString(str)
  if type(str) ~= "string" then return false end
  str = str:gsub("||", "|"):gsub("^%s+", ""):gsub("%s+$", "")

  -- Decoupage selon le format : liste de { kind, fields... } deja decodes.
  local records = {}
  if str:sub(1, #EXPORT_V2) == EXPORT_V2 then
    for rec in (str .. ";"):gmatch("(.-);") do
      if rec ~= "" and rec ~= EXPORT_V2 then
        local f = {}
        for field in (rec .. ","):gmatch("(.-),") do f[#f + 1] = dec(field) end
        records[#records + 1] = f
      end
    end
  elseif str:sub(1, #EXPORT_V1) == EXPORT_V1 then
    for line in (str .. "\n"):gmatch("(.-)\n") do
      if line ~= "" and line ~= EXPORT_V1 then
        local f = {}
        for field in (line .. "|"):gmatch("(.-)|") do f[#f + 1] = unescV1(field) end
        records[#records + 1] = f
      end
    end
  else
    return false
  end

  local tag, dest, curChar, curProf
  local count = 0
  for _, f in ipairs(records) do
    local kind = f[1]
    if kind == "T" then
      tag = f[2]; if not tag or tag == "" then tag = "import" end
      ST.db.imported[tag] = {}   -- remplace l'ancien import de ce tag
      dest = ST.db.imported[tag]
    elseif kind == "C" and dest then
      local realm, name = f[2] or "", f[3] or ""
      if realm ~= "" and name ~= "" then
        dest[realm] = dest[realm] or {}
        curChar = { professions = {}, class = f[4], faction = f[5] }
        dest[realm][name] = curChar
        count = count + 1
      else
        curChar = nil
      end
      curProf = nil
    elseif kind == "P" and curChar then
      local parent = tonumber(f[2])
      if parent then
        curProf = { name = f[3], isPrimary = (f[4] == "1"), lines = {}, parent = parent }
        curChar.professions[parent] = curProf
      else
        curProf = nil
      end
    elseif kind == "B" and curProf then
      curProf.base = { cur = tonumber(f[2]) or 0, max = tonumber(f[3]) or 0 }
    elseif kind == "L" and curProf then
      local id = tonumber(f[2])
      if id then
        local exp = f[5]; if exp == "" then exp = nil end
        curProf.lines[id] = { cur = tonumber(f[3]) or 0, max = tonumber(f[4]) or 0, exp = exp }
      end
    elseif kind == "K" and curProf then
      curProf.conc = { cur = tonumber(f[2]) or 0, max = tonumber(f[3]) or 0, t = tonumber(f[4]) or 0 }
    elseif kind == "A" and curChar then
      curChar.archaeology = { cur = tonumber(f[2]) or 0, max = tonumber(f[3]) or 0, name = f[4] }
    end
  end

  if not tag then return false end
  for _, realms in pairs(ST.db.imported) do
    for _, list in pairs(realms) do
      for _, rec in pairs(list) do
        for _, prof in pairs(rec.professions or {}) do ST.ResolveLineIndexes(prof, ST.db.tierIndex) end
      end
    end
  end
  if ST.RefreshUI then ST.RefreshUI() end
  return true, count
end

function ST.WipeCurrentChar()
  local realm, name = CurrentCharKey()
  if ST.db.chars[realm] then ST.db.chars[realm][name] = nil end
  ST.RequestScan(0.1)
end

-- ================================================================
-- DIAGNOSTIC  /skt dump  et  /skt kpdump
-- Ouvrir un metier en jeu AVANT de lancer la commande.
-- ================================================================
local function p(s) print("|cFF00FF98ST|r " .. tostring(s)) end
ST.p = p

function ST.Dump()
  local api = C_TradeSkillUI or {}
  p("=== DUMP (ouvrez un metier avant) ===")
  if type(GetProfessions) == "function" then
    local p1, p2, arch, fish, cook = GetProfessions()
    for _, idx in ipairs({ p1, p2, arch, fish, cook }) do
      if idx then
        local name, _, cur, max, _, _, skillLine, _, _, _, skillLineName = GetProfessionInfo(idx)
        p(string.format("idx=%s parent=%s skillLine=%s cur=%s/%s tierName=%s",
          tostring(idx), tostring(name), tostring(skillLine),
          tostring(cur), tostring(max), tostring(skillLineName)))
      end
    end
  end
  if api.GetBaseProfessionInfo then
    local b = api.GetBaseProfessionInfo()
    if b then
      p(string.format("BASE profID=%s name=%s exp=%s cur=%s/%s",
        tostring(b.professionID), tostring(b.professionName),
        tostring(b.expansionName), tostring(b.skillLevel), tostring(b.maxSkillLevel)))
    end
  end
  if api.GetChildProfessionInfos then
    local kids = api.GetChildProfessionInfos()
    p("-- GetChildProfessionInfos : " .. (type(kids) == "table" and #kids or "nil") .. " --")
    if type(kids) == "table" then
      for _, k in ipairs(kids) do
        p(string.format("profID=%s name=%s exp=%s idx=%s cur=%s/%s",
          tostring(k.professionID), tostring(k.professionName), tostring(k.expansionName),
          tostring(ST.NameToIndex(k.expansionName)), tostring(k.skillLevel), tostring(k.maxSkillLevel)))
      end
    end
  end
  if api.GetAllProfessionTradeSkillLines then
    local lines = api.GetAllProfessionTradeSkillLines() or {}
    p("-- GetAllProfessionTradeSkillLines : " .. #lines .. " --")
    for _, id in ipairs(lines) do
      local i = api.GetProfessionInfoBySkillLineID and api.GetProfessionInfoBySkillLineID(id)
      if i and (i.maxSkillLevel or 0) > 0 then
        p(string.format("id=%s name=%s exp=%s cur=%s/%s",
          tostring(id), tostring(i.professionName),
          tostring(i.expansionName), tostring(i.skillLevel), tostring(i.maxSkillLevel)))
      end
    end
  end
  p("=== FIN DUMP ===")
end

function ST.KPDump()
  p("=== KP / CONCENTRATION ===")
  if type(C_ProfSpecs) == "table" then
    local names = {}
    for k, v in pairs(C_ProfSpecs) do if type(v) == "function" then names[#names + 1] = k end end
    table.sort(names)
    p("C_ProfSpecs: " .. table.concat(names, ", "))
  else
    p("C_ProfSpecs absent")
  end
  local api = C_TradeSkillUI or {}
  if api.GetBaseProfessionInfo and api.GetChildProfessionInfos then
    local base = api.GetBaseProfessionInfo()
    local kids = api.GetChildProfessionInfos()
    if base and type(kids) == "table" then
      p("Metier ouvert: " .. tostring(base.professionName) .. " (base " .. tostring(base.professionID) .. ")")
      for _, k in ipairs(kids) do
        local id = k.professionID
        local line = "tier " .. tostring(id) .. " [" .. tostring(k.expansionName) .. "]"
        if api.GetConcentrationCurrencyID then
          local ok, cid = pcall(api.GetConcentrationCurrencyID, id)
          line = line .. " | concCid=" .. tostring(ok and cid)
          if ok and type(cid) == "number" and cid > 0 and C_CurrencyInfo then
            local ci = C_CurrencyInfo.GetCurrencyInfo(cid)
            if ci then line = line .. "(" .. tostring(ci.quantity) .. "/" .. tostring(ci.maxQuantity) .. ")" end
          end
        end
        if C_ProfSpecs and C_ProfSpecs.GetCurrencyInfoForSkillLine then
          local ok, r = pcall(C_ProfSpecs.GetCurrencyInfoForSkillLine, id)
          line = line .. " | kp=" .. tostring(ok and r)
          if ok and type(r) == "table" then
            local keys = {}
            for kk, vv in pairs(r) do keys[#keys + 1] = tostring(kk) .. "=" .. tostring(vv) end
            table.sort(keys)
            line = line .. " {" .. table.concat(keys, ",") .. "}"
          end
        end
        if ST.ReadSpecTree then
          local spent, max = ST.ReadSpecTree(id)
          line = line .. " | tree=" .. tostring(spent) .. "/" .. tostring(max)
        end
        p(line)
      end
    end
  else
    p("Ouvrez une fenetre de metier avant /skt kpdump.")
  end
  p("=== FIN KP ===")
end

-- ================================================================
-- SUPPORT LibDataBroker (barre de donnees : Titan, ElvUI, Bazooka...)
-- ================================================================
function ST.SetupLDB()
  if not LibStub then return end
  local LDB = LibStub("LibDataBroker-1.1", true)
  if not LDB then return end
  if LDB:GetDataObjectByName("SkillTracker") then return end
  LDB:NewDataObject("SkillTracker", {
    type  = "launcher",
    icon  = ST.LOGO,
    label = "SkillTracker",
    OnClick = function(_, button)
      if button == "RightButton" then ST.OpenOptions() else ST.Toggle() end
    end,
    OnTooltipShow = function(tt)
      if ST.FillSummaryTooltip then ST.FillSummaryTooltip(tt) end
    end,
  })
end

-- ================================================================
-- RECHERCHE GLOBALE (loupe TibiSuite) : par metier OU par personnage,
-- sur tous les persos locaux. La ligne rappelle la concentration projetee.
-- ================================================================
local function BuildSearchProvider()
  local UI = _G.TibiMidnight
  if not UI or not UI.RegisterSearch then return end
  UI.RegisterSearch("SkillTracker", "SkillTracker", function(q)
    local res = {}
    for realm, list in pairs(ST.db.chars) do
      for name, rec in pairs(list) do
        local charHit = UI.Match(name, q)
        for _, prof in pairs(rec.professions or {}) do
          if charHit or UI.Match(prof.name or "", q) then
            local extra = ""
            local pr = ST.ConcProject and ST.ConcProject(prof)
            if pr then
              extra = "  |cFF888888" .. L.CONCENTRATION .. " " .. pr.cur .. "/" .. pr.max .. "|r"
            end
            res[#res + 1] = {
              text = UI.Hex(ST.COLOR[1], ST.COLOR[2], ST.COLOR[3]) .. (prof.name or "?") .. "|r  "
                .. name .. " |cFF888888" .. realm .. "|r  "
                .. ProfessionOverallPercent(prof) .. "%" .. extra,
              onClick = function() if ST.Toggle then ST.Toggle(true) end end,
            }
          end
        end
      end
    end
    -- Recettes (3 lettres minimum : sinon la liste devient un mur).
    if ST.RecipeSearch and type(q) == "string" and #q >= 3 then
      local found = ST.RecipeSearch(q, 10)
      for _, r in ipairs(found) do
        res[#res + 1] = {
          text = (r.icon and ("|T" .. r.icon .. ":14|t ") or "") .. r.name .. "  " .. ST.OwnersText(r.owners, 3),
          onClick = function() if ST.OpenView then ST.OpenView("recipes", r.name) end end,
        }
      end
    end
    return res
  end)
end

-- ================================================================
-- API PUBLIQUE EN LECTURE SEULE (suite TibiSuite : Stats, WeeklyCompass)
-- Ne renvoie que des copies : aucun appelant ne peut modifier SkillTrackerDB.
-- ================================================================
local function ProfSummary(prof)
  local s = {
    name = prof.name, isPrimary = prof.isPrimary and true or false,
    pct = ProfessionOverallPercent(prof), kp = prof.kp,
  }
  local ln = ST.CurrentLine(prof)
  if ln then s.cur, s.max = ln.cur, ln.max
  elseif prof.base then s.cur, s.max = prof.base.cur, prof.base.max end
  if ST.ConcProject then
    local pr = ST.ConcProject(prof)
    if pr then
      s.conc = { cur = pr.cur, max = pr.max, full = pr.full, fullIn = pr.fullIn,
                 seenAt = prof.conc.t, projected = pr.hasRate }
    end
  end
  if prof.tree then s.tree = { spent = prof.tree.spent, max = prof.tree.max } end
  return s
end

local function FindRec(realm, name)
  if not ST.db or not realm or not name then return nil end
  return ST.db.chars[realm] and ST.db.chars[realm][name]
end

_G.SkillTrackerAPI = {
  version = 1,
  -- Resume des metiers d'un perso local, tries principaux d'abord, ou nil.
  GetCharSummary = function(realm, name)
    local rec = FindRec(realm, name)
    if not rec then return nil end
    local list = {}
    for parent, prof in pairs(rec.professions or {}) do
      local s = ProfSummary(prof)
      if ST.WeeklyCount and prof.isPrimary then
        local done, total = ST.WeeklyCount(rec, parent)
        if total > 0 then s.week = { done = done, total = total } end
      end
      list[#list + 1] = s
    end
    table.sort(list, function(a, b)
      if a.isPrimary ~= b.isPrimary then return a.isPrimary end
      return (a.name or "") < (b.name or "")
    end)
    return list
  end,
  -- Table exportable pour Stats : les metiers d'un perso + concentration
  -- (valeur lue, date de lecture, duree de recharge apprise) + semaine en cours.
  ExportProfessions = function(rec)
    if type(rec) ~= "table" or type(rec.professions) ~= "table" then return nil end
    local out = {}
    for parent, prof in pairs(rec.professions) do
      local e = { name = prof.name, isPrimary = prof.isPrimary, base = prof.base, kp = prof.kp, lines = {} }
      for id, ln in pairs(prof.lines or {}) do
        e.lines[id] = { cur = ln.cur, max = ln.max, exp = ln.exp, kp = ln.kp }
      end
      if prof.conc then
        -- fullSec : duree apprise de vide a plein (s), plus lisible qu'une vitesse.
        local rate = ST.ConcRate and ST.ConcRate()
        e.conc = { cur = prof.conc.cur, max = prof.conc.max, t = prof.conc.t,
                   fullSec = rate and math.floor(1 / rate + 0.5) or nil }
      end
      if prof.tree then e.tree = { spent = prof.tree.spent, max = prof.tree.max } end
      if ST.WeeklyCount and prof.isPrimary then
        local done, total = ST.WeeklyCount(rec, parent)
        if total > 0 then e.week = { done = done, total = total } end
      end
      out[parent] = e
    end
    return out
  end,
  -- Vitesse de recharge apprise (fraction du max par seconde), ou nil.
  GetConcRate = function() return ST.ConcRate and ST.ConcRate() or nil end,
  -- Concentrations pleines de tous les persos connus (metiers principaux),
  -- lue par la tuile « Mes personnages » de Standby (depuis 7.1.5.40) :
  -- { { realm, name, class, prof, current }, ... }
  GetFullConcentrations = function()
    local out = {}
    for _, e in ipairs(ST.ConcList and ST.ConcList() or {}) do
      if e.pr and e.pr.full then
        out[#out + 1] = { realm = e.realm, name = e.name, class = e.class, prof = e.prof, current = e.current }
      end
    end
    return out
  end,
}

-- ================================================================
-- LIGNE D'ETAT DU PANNEAU VIVANT DE TIBISUITE (statusFn, lue par le core)
-- Concentrations pleines (tous persos) d'abord, sinon le prochain plein du
-- perso connecte ; la barre de progression suit ses connaissances hebdo.
-- ================================================================
function SkillTracker_Status()
  if not ST.db or not ST.ConcList then return nil end
  local SL = _G.TibiSuiteL or {}
  local TS = _G.TibiSuite
  local full, nextIn = 0, nil
  for _, e in ipairs(ST.ConcList()) do
    if e.pr.full then
      full = full + 1
    elseif e.current and e.pr.fullIn and (not nextIn or e.pr.fullIn < nextIn) then
      nextIn = e.pr.fullIn
    end
  end
  local out = {}
  if full > 0 then
    out.text = string.format(SL.ST_CONC_FULL_FMT or "%d", full)
    out.color = { 1, 0.82, 0 }
  elseif nextIn and TS and TS.FmtDuration then
    out.text = string.format(SL.ST_CONC_IN_FMT or "%s", TS.FmtDuration(nextIn))
  end
  local rec = ST.CurrentRec()
  if rec and ST.WeeklyCount then
    local d, t = 0, 0
    for parent, prof in pairs(rec.professions or {}) do
      if prof.isPrimary then
        local a, b = ST.WeeklyCount(rec, parent)
        d, t = d + a, t + b
      end
    end
    if t > 0 then
      out.progress = d / t
      if not out.text then out.text = string.format(SL.ST_KNOW_FMT or "%d/%d", d, t) end
    end
  end
  if not out.text and not out.progress then return nil end
  return out
end

-- ================================================================
-- POINTS D'ENTREE PUBLICS (attendus par TibiSuite)
-- ================================================================
function SkillTracker_Toggle()
  if ST.Toggle then ST.Toggle() end
end

function SkillTracker_OpenOptions()
  if ST.OpenOptions then ST.OpenOptions() end
end

function SkillTracker_OnAddonCompartmentClick()
  if ST.Toggle then ST.Toggle() end
end
function SkillTracker_OnAddonCompartmentEnter(btn)
  GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
  GameTooltip:AddLine(ST.TAG)
  GameTooltip:AddLine(L.PANEL_SUBTITLE, 0.9, 0.9, 0.9)
  GameTooltip:Show()
end
function SkillTracker_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end

-- Ouvre le panneau directement sur une vue (query : recherche de recette).
local function OpenView(v, query)
  if not ST.settings then return end
  ST.settings.metierView = v
  if query then ST.runtime.recipeQuery = query end
  if ST.Toggle then ST.Toggle(true) end
end
ST.OpenView = OpenView

-- ================================================================
-- COMMANDES SLASH  /skilltracker  /skt
-- ================================================================
SLASH_SKILLTRACKER1 = "/skilltracker"
SLASH_SKILLTRACKER2 = "/skt"
SlashCmdList["SKILLTRACKER"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "config" or msg == "options" then
    SkillTracker_OpenOptions()
  elseif msg == "scan" or msg == "rescan" then
    ST.RequestScan(0.1)
    print(ST.TAG .. " " .. L.OPT_RESCAN)
  elseif msg == "dump" then
    ST.Dump()
  elseif msg == "kpdump" then
    ST.KPDump()
  elseif msg == "conc" or msg == "concentration" then
    OpenView("conc")
  elseif msg == "week" or msg == "semaine" then
    OpenView("week")
  elseif msg == "recipe" or msg == "recette" or msg:match("^recipe%s") or msg:match("^recette%s") or msg:match("^r%s") then
    OpenView("recipes", msg:match("^%S+%s+(.+)$") or "")
  elseif msg == "check" then
    if ST.RunQuestCheck then ST.RunQuestCheck() end
  elseif msg == "mark" then
    if ST.QuestMark then ST.QuestMark() end
  elseif msg == "diff" then
    if ST.QuestDiff then ST.QuestDiff() end
  elseif msg == "help" or msg == "?" then
    print(ST.TAG .. " " .. L.SLASH_HELP)
    print("  |cFFFFD700/skt|r : " .. L.SLASH_TOGGLE)
    print("  |cFFFFD700/skt config|r : " .. L.SLASH_CONFIG)
    print("  |cFFFFD700/skt scan|r : " .. L.SLASH_SCAN)
    print("  |cFFFFD700/skt conc|r : " .. L.SLASH_CONC)
    print("  |cFFFFD700/skt week|r : " .. L.SLASH_WEEK)
    print("  |cFFFFD700/skt recipe <...>|r : " .. L.SLASH_RECIPE)
    print("  |cFFFFD700/skt check|r : " .. L.SLASH_CHECK)
    print("  |cFFFFD700/skt mark|r, |cFFFFD700/skt diff|r : " .. L.SLASH_DIFF)
    print("  |cFFFFD700/skt dump|r, |cFFFFD700/skt kpdump|r : " .. L.SLASH_DUMP)
  else
    SkillTracker_Toggle()
  end
end

-- ================================================================
-- INITIALISATION ET EVENEMENTS
-- ================================================================
local loginDone = false
local function OnLogin()
  if loginDone then return end
  loginDone = true
  ST.RequestScan(1.0)
  if ST.OnPlayerLogin then ST.OnPlayerLogin() end
  ST.SetupLDB()
  if ST.HookItemTooltips then ST.HookItemTooltips() end
  C_Timer.After(3, function()
    -- En suite, seul le reglage "full" du core fait parler les modules.
    local mode = "full"
    if HasCore() then mode = (TibiSuiteDB and TibiSuiteDB.loginMsg) or "one" end
    if mode == "full" then
      print(ST.TAG .. " v" .. ST.VERSION .. " " .. L.LOADED_MSG
        .. "  -  |cFFFFD700/skt|r, |cFFFFD700/skt help|r.")
    end
  end)
  -- Alts a la concentration pleine + pastille : apres le premier scan, quand
  -- la barre du core est construite.
  C_Timer.After(8, function()
    if ST.AltConcAlert then ST.AltConcAlert() end
    if ST.UpdateBadge then ST.UpdateBadge() end
  end)
  -- La projection avance avec le temps : pastille recalculee toutes les 10 min.
  C_Timer.NewTicker(600, function() if ST.UpdateBadge then ST.UpdateBadge() end end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("TRADE_SKILL_SHOW")
ev:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
ev:RegisterEvent("SKILL_LINES_CHANGED")
ev:RegisterEvent("CHAT_MSG_SKILL")
ev:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
ev:RegisterEvent("TRAIT_CONFIG_UPDATED")
ev:RegisterEvent("QUEST_TURNED_IN")
ev:RegisterEvent("QUEST_DATA_LOAD_RESULT")
ev:RegisterEvent("TRADE_SKILL_CLOSE")
ev:RegisterEvent("NEW_RECIPE_LEARNED")

ev:SetScript("OnEvent", function(_, event, arg1, arg2)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then
      InitDB()
      BuildSearchProvider()
      if ST.OnDBReady then ST.OnDBReady() end
      -- Chargement a la demande par le core : PLAYER_LOGIN est deja passe.
      if IsLoggedIn() then OnLogin() end
    end
    return
  end
  if not ST.db then return end

  if event == "PLAYER_LOGIN" then
    OnLogin()
  elseif event == "PLAYER_ENTERING_WORLD" then
    ST.RequestScan(2.0)
  elseif event == "CURRENCY_DISPLAY_UPDATE" then
    -- Seulement nos monnaies de concentration (sinon on ignore : evenement tres frequent).
    if arg1 and ST.runtime.concCids[arg1] then ST.RequestScan(1.0) end
  elseif event == "QUEST_TURNED_IN" then
    ST.RequestScan(1.5)
  elseif event == "QUEST_DATA_LOAD_RESULT" then
    if ST.OnQuestDataLoad then ST.OnQuestDataLoad(arg1, arg2) end
  elseif event == "TRADE_SKILL_CLOSE" then
    if ST.CancelRecipeScan then ST.CancelRecipeScan() end
  elseif event == "NEW_RECIPE_LEARNED" then
    if ST.OnRecipeLearned then ST.OnRecipeLearned(arg1) end
    ST.RequestScan(0.5)
  else
    if (event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE") and ST.RequestRecipeScan then
      ST.RequestRecipeScan(2.0)
    end
    -- TRADE_SKILL_* / SKILL_LINES_CHANGED / CHAT_MSG_SKILL / TRAIT_CONFIG_UPDATED
    ST.RequestScan(0.5)
  end
end)
