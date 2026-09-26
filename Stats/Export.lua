--[[============================================================================
  Stats - Export.lua
  ---------------------------------------------------------------------------
  Collecte (Stats + Metiers si charge + reputations),
  serialisation JSON maison (lisible directement en JS cote site, pas de
  mini-interpreteur Lua necessaire), compression LZW (Libs/LZW.lua), encodage
  Base64 imprimable. Meme point d'entree pour le bouton de la fenetre Stats
  et pour le bouton des options du socle TibiSuite.
============================================================================]]

local ADDON, SX = ...
local L = SX.L

SX.Export = SX.Export or {}

-- ============================================================================
-- ENCODEUR JSON (Lua -> texte) - suffisant pour nos donnees (nombres,
-- chaines, booleens, tables sequentielles ou associatives, imbrication).
-- ============================================================================
local function jsonEscape(s)
  return (s:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"'
    elseif c == '\\' then return '\\\\'
    elseif c == '\n' then return '\\n'
    elseif c == '\r' then return '\\r'
    elseif c == '\t' then return '\\t'
    else return string.format('\\u%04x', c:byte()) end
  end))
end

local function isArray(t)
  local n = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then return false end
    n = n + 1
  end
  for i = 1, n do if t[i] == nil then return false end end
  return true, n
end

local function jsonEncode(v)
  local ty = type(v)
  if v == nil then return "null" end
  if ty == "boolean" then return v and "true" or "false" end
  if ty == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "0" end
    return tostring(v)
  end
  if ty == "string" then return '"' .. jsonEscape(v) .. '"' end
  if ty == "table" then
    local arr, n = isArray(v)
    if arr then
      local parts = {}
      for i = 1, n do parts[#parts + 1] = jsonEncode(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local keys = {}
      for k in pairs(v) do keys[#keys + 1] = k end
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
      local parts = {}
      for _, k in ipairs(keys) do
        parts[#parts + 1] = '"' .. jsonEscape(tostring(k)) .. '":' .. jsonEncode(v[k])
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  return "null"
end
SX.JSONEncode = jsonEncode

-- Somme de controle simple (djb2) - detecte un collage corrompu/tronque cote
-- site, sans pretendre a une securite cryptographique.
local function checksum(s)
  local h = 5381
  for i = 1, #s do
    h = (h * 33 + s:byte(i)) % 4294967296
  end
  return string.format("%08x", h)
end

-- ============================================================================
-- COLLECTE CROSS-MODULE (dégradation propre : chaque section est omise si
-- le module correspondant n'est pas charge, jamais d'erreur).
-- ============================================================================
-- Metiers de TOUS les personnages connus de SkillTracker (meme convention de
-- cle "Nom-Royaume" que StatsDB, meme si SkillTrackerDB imbrique par
-- royaume/nom en interne) - permet a l'export compte de reprendre les
-- metiers de chaque personnage, pas seulement celui connecte.
local function collectAllProfessions()
  if not _G.SkillTrackerDB then return nil end
  local ok, result = pcall(function()
    local db = _G.SkillTrackerDB
    local out = {}
    for realm, byName in pairs(db.chars or {}) do
      for name, rec in pairs(byName) do
        if type(rec) == "table" and rec.professions then
          out[name .. "-" .. realm] = rec.professions
        end
      end
    end
    return next(out) and out or nil
  end)
  if ok then return result end
  return nil
end

-- Semaine de TOUS les personnages connus de WeeklyCompass, au meme format de
-- cle "Nom-Royaume" que StatsDB (WeeklyCompassDB range sous "Nom - Royaume",
-- d'ou la reconstruction depuis name/realm). Meme principe que les metiers :
-- ajout purement additif, rien si WeeklyCompass est absent ou desactive.
--
-- resetAt = periodId de WeeklyCompass, c'est-a-dire l'horodatage serveur du
-- PROCHAIN reset hebdo (voir WeeklyCompass/Core/Reset.lua). Le site compare
-- cette valeur a l'heure courante pour griser une semaine deja terminee au
-- lieu d'afficher des compteurs perimes comme s'ils etaient actuels.
local function collectWeekly()
  if not _G.WeeklyCompassDB then return nil end
  local ok, result = pcall(function()
    local out = {}
    for _, char in pairs(_G.WeeklyCompassDB.chars or {}) do
      if type(char) == "table" and char.name and char.realm then
        local entries = {}
        for _, e in pairs(char.entries or {}) do
          if type(e) == "table" and e.key then
            entries[#entries + 1] = {
              key      = e.key,
              label    = e.label,
              short    = e.short,
              category = e.category,
              order    = e.order,
              status   = e.status,
              current  = e.progress and e.progress.current or nil,
              max      = e.progress and e.progress.max or nil,
              ilvl     = e.reward and e.reward.ilvl or nil,
              detail   = e.detail,
              rank     = e.rank,    -- rang d'un renom (Gouffres, Traque), affiche "(R3)"
              slots    = e.slots,   -- Grand Coffre : { index, progress, threshold, ilvl, color }
            }
          end
        end
        table.sort(entries, function(a, b) return tostring(a.key) < tostring(b.key) end)
        out[char.name .. "-" .. char.realm] = {
          resetAt  = char.periodId,
          lastSeen = char.lastSeen,
          entries  = entries,
        }
      end
    end
    return next(out) and out or nil
  end)
  if ok then return result end
  return nil
end

-- Retire les marqueurs d'affichage du jeu (icone |T..|t, atlas |A..|a,
-- couleur |c..|r) : le site n'affiche que du texte.
local function stripMarkup(s)
  if type(s) ~= "string" then return s end
  s = s:gsub("|T.-|t%s*", ""):gsub("|A.-|a%s*", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return s
end

-- Saison d'un ensemble de raid, calculee ICI (le site ne connait pas la
-- version du client) : "en cours" si son patch majeur.mineur n'est pas
-- anterieur a celui du client. Meme regle que WeeklyCompass/UI/Sheet.lua.
local function setSeason(patchID)
  patchID = tonumber(patchID)
  if not patchID then return nil, nil end
  local patchText = ("%d.%d"):format(math.floor(patchID / 10000), math.floor(patchID / 100) % 100)
  local version = GetBuildInfo and GetBuildInfo() or ""
  local major, minor = version:match("^(%d+)%.(%d+)")
  if not major then return nil, patchText end
  return math.floor(patchID / 100) >= tonumber(major) * 100 + tonumber(minor), patchText
end

-- Onglet Personnages et fiche detaillee de WeeklyCompass (phase 4), pour
-- TOUS les personnages connus, au format de cle "Nom-Royaume" de StatsDB.
-- Ajout purement additif (schema inchange) : un site ou un Companion pas
-- encore a jour ignore ce bloc. Lit la SavedVariable directement (comme
-- collectWeekly), jamais le code de WeeklyCompass. Aussi : la banque de
-- Bataillon, commune au compte.
local function collectCompass()
  local db = _G.WeeklyCompassDB
  if not db then return nil, nil end
  local ok, chars, warband = pcall(function()
    local out = {}
    local hidden = (db.global and db.global.hidden) or {}
    for wcKey, char in pairs(db.chars or {}) do
      if type(char) == "table" and char.name and char.realm then
        local snap = char.snapshot or {}
        local function num(k) local e = snap[k]; return e and tonumber(e.sortValue) or nil end
        local c = {
          lastSeen = char.lastSeen,
          hidden = hidden[wcKey] and true or nil,
          profile = {
            level = num("profile:level"),
            spec  = snap["profile:spec"] and stripMarkup(snap["profile:spec"].detail) or nil,
            ilvl  = num("profile:ilvl"),
            gold  = num("profile:gold"),   -- pieces de cuivre
            rest  = num("profile:rest"),   -- % d'un niveau
            updatedAt = snap["profile:level"] and snap["profile:level"].updatedAt or nil,
          },
        }
        local key = snap["keystone:key"]
        if key then
          c.keystone = { text = stripMarkup(key.detail), level = tonumber(key.sortValue), expiresAt = key.expiresAt }
        end
        local score = snap["keystone:score"]
        if score then c.score = { value = tonumber(score.sortValue), color = score.color } end
        local lk = snap["lockouts:raids"]
        if lk and type(lk.items) == "table" then
          local items = {}
          for _, it in ipairs(lk.items) do
            items[#items + 1] = { name = it.name, diff = it.diff, diffID = it.diffID,
              killed = it.killed, total = it.total, expiresAt = it.expiresAt }
          end
          c.lockouts = items
        end
        local sd = snap["sheet:data"]
        if sd then
          local slots = {}
          for slotID, s in pairs(sd.slots or {}) do
            slots[#slots + 1] = {
              slot = tonumber(slotID),
              id = type(s.link) == "string" and tonumber(s.link:match("item:(%d+)")) or nil,
              name = s.name, ilvl = s.ilvl and math.floor(s.ilvl) or nil,
              track = s.trackKey, quality = s.quality,
              missingEnchant = s.missingEnchant, emptySockets = s.emptySockets,
            }
          end
          table.sort(slots, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
          local set
          if sd.set then
            local current, patchText = setSeason(sd.set.patchID)
            set = { name = sd.set.name, count = sd.set.count, total = sd.set.total, raid = sd.set.raid,
              expansion = sd.set.expansionID and _G["EXPANSION_NAME" .. sd.set.expansionID] or nil,
              patch = patchText, current = current }
          end
          local currencies = {}
          for _, cur in ipairs(sd.currencies or {}) do
            currencies[#currencies + 1] = { name = cur.name, quantity = cur.quantity, max = cur.max,
              earned = cur.earned, useEarned = cur.useEarned }
          end
          local talents
          local t = sd.talents
          if t then
            local heroTalents = {}
            for _, h in ipairs(t.heroTalents or {}) do
              heroTalents[#heroTalents + 1] = { name = h.name, rank = h.rank, max = h.max, spellID = h.spellID }
            end
            talents = { code = t.code, build = t.build, modified = t.modified, starter = t.starter,
              hero = t.hero and t.hero.name or nil, heroTalents = heroTalents, otherCount = t.otherCount }
          end
          c.sheet = {
            updatedAt = sd.updatedAt, race = sd.race and sd.race.name or nil, className = sd.className,
            slots = slots, set = set, stats = sd.stats, currencies = currencies, talents = talents,
          }
        end
        out[char.name .. "-" .. char.realm] = c
      end
    end
    local wb = db.global and db.global.warband
    local warbandOut = (wb and tonumber(wb.money)) and { money = tonumber(wb.money), at = wb.at } or nil
    return next(out) and out or nil, warbandOut
  end)
  if ok then return chars, warband end
  return nil, nil
end

local function currentSpecName()
  local si = GetSpecialization and GetSpecialization()
  if not si then return nil end
  local _, specName = GetSpecializationInfo(si)
  return specName
end

-- Export COMPTE (schema 2) : reprend TOUS les personnages connus de
-- StatsDB (pas seulement celui connecte) en un seul code - evite de devoir
-- se reconnecter sur chaque personnage pour copier/coller son export un par
-- un (demande explicite). Le site (dashboard-shared.js) doit lire ce format
-- en un seul code = plusieurs profils affiches ; garder les deux fichiers en
-- phase, cf. l'avertissement en tete de dashboard-shared.js cote site.
function SX.CollectExportData()
  local currentKey = SX.CurrentCharKey()
  local allProfessions = collectAllProfessions()
  local allWeekly = collectWeekly()
  local allCompass, warband = collectCompass()
  local chars = {}
  for _, key in ipairs(SX.GetCharKeys()) do
    local rec = StatsDB[key] or {}
    local name, realm = key:match("^(.-)%-(.+)$")
    local charInfo
    if key == currentKey then
      -- Personnage connecte : valeurs live (toujours a jour), pas le dernier
      -- snapshot enregistre par SX.RefreshCharMeta.
      charInfo = {
        name = UnitName("player"), realm = GetRealmName(),
        class = select(2, UnitClass("player")), level = UnitLevel("player"),
        spec = currentSpecName(), ilvl = rec.ilvl,
        achievementPoints = rec.achievementPoints, pvp = rec.pvp,
        delveHighestTier = rec.delveHighestTier, delveCompanionLevel = rec.delveCompanionLevel,
        delveCompletedLifetime = rec.delveCompletedLifetime,
        delveTierAchievementID = rec.delveTierAchievementID, delveTierAchievementName = rec.delveTierAchievementName,
        delveTypes = rec.delveTypes, delveAllMaxed = SX.DelveAllMaxed(rec),
        torghast = rec.torghast, torghastByDungeon = rec.torghastByDungeon,
        reputations = rec.reputations,
        professionsNative = rec.professionsNative,
      }
    else
      charInfo = {
        name = rec.name or name, realm = rec.realm or realm,
        class = rec.class, level = rec.level, spec = rec.spec, ilvl = rec.ilvl,
        achievementPoints = rec.achievementPoints, pvp = rec.pvp,
        delveHighestTier = rec.delveHighestTier, delveCompanionLevel = rec.delveCompanionLevel,
        delveCompletedLifetime = rec.delveCompletedLifetime,
        delveTierAchievementID = rec.delveTierAchievementID, delveTierAchievementName = rec.delveTierAchievementName,
        delveTypes = rec.delveTypes, delveAllMaxed = SX.DelveAllMaxed(rec),
        torghast = rec.torghast, torghastByDungeon = rec.torghastByDungeon,
        reputations = rec.reputations,
        professionsNative = rec.professionsNative,
      }
    end
    -- days est copie tel quel : chaque entree days[dateKey] porte, en plus
    -- des compteurs agreges (quests/goldGain/...), 9 journaux d'evenements
    -- detailles (mplus, questLog, dungeonLog, delveLog, repLog, raidLog,
    -- goldLog, playtimeLog, profLog - voir SX.EnsureDay/SX.AppendDayEvent
    -- dans Core.lua). Ajout purement additif : aucun changement de schema
    -- necessaire ici, ces champs traversent automatiquement l'export sans
    -- code dedie.
    chars[key] = {
      char = charInfo,
      days = rec.days or {},
      professions = allProfessions and allProfessions[key] or nil,
      weekly = allWeekly and allWeekly[key] or nil,
      compass = allCompass and allCompass[key] or nil,
    }
  end

  return {
    schema = SX.SCHEMA_VERSION,
    generatedAt = time(),
    account = { generatedBy = currentKey },
    data = {
      chars = chars,
      warband = warband,   -- banque de Bataillon (WeeklyCompass), commune au compte
    },
  }
end

-- ============================================================================
-- GENERATION DU CODE D'EXPORT
-- ============================================================================
function SX.Export.Generate()
  local envelope = SX.CollectExportData()
  local dataJSON = jsonEncode(envelope.data)
  envelope.checksum = checksum(dataJSON)
  -- "data" est embarque comme une CHAINE JSON brute (pas un objet imbrique) :
  -- le site peut alors verifier le checksum sur ce texte exact, tel quel,
  -- sans jamais re-serialiser l'objet parse (Lua et JS ne formatent pas les
  -- nombres a virgule flottante de facon identique - une re-serialisation
  -- ferait echouer le checksum sur des donnees pourtant intactes).
  envelope.data = dataJSON
  local fullJSON = jsonEncode(envelope)
  local compressed = SX.LZW.Compress(fullJSON)
  return SX.LZW.Base64Encode(compressed)
end

-- ============================================================================
-- POPUP D'AFFICHAGE (bouton dans la fenetre Stats ET dans les options du socle)
-- ============================================================================
local exportPopup

function SX.ShowExportPopup()
  local UI = _G.TibiMidnight
  local code = SX.Export.Generate()

  if not exportPopup then
    exportPopup = CreateFrame("Frame", "StatsExportPopup", UIParent, "BackdropTemplate")
    exportPopup:SetSize(520, 320)
    exportPopup:SetPoint("CENTER")
    exportPopup:SetFrameStrata("DIALOG")
    UI.SkinFrame(exportPopup, SX.ACCENT, UI.C.PANEL)
    exportPopup:SetMovable(true)
    exportPopup:EnableMouse(true)
    exportPopup:RegisterForDrag("LeftButton")
    exportPopup:SetScript("OnDragStart", exportPopup.StartMoving)
    exportPopup:SetScript("OnDragStop", exportPopup.StopMovingOrSizing)
    exportPopup:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "StatsExportPopup")

    local title = exportPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText(L["EXPORT_TITLE"])

    local closeBtn = CreateFrame("Button", nil, exportPopup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() exportPopup:Hide() end)

    local hint = exportPopup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 14, -36)
    hint:SetText(L["EXPORT_HINT"])

    local scroll = CreateFrame("ScrollFrame", nil, exportPopup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -56)
    scroll:SetPoint("BOTTOMRIGHT", -30, 14)

    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetWidth(460)
    box:SetMaxLetters(0)  -- pas de plafond : le code d'export peut depasser la limite par defaut
    box:SetAutoFocus(true)
    box:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    scroll:SetScrollChild(box)
    exportPopup.box = box
  end

  exportPopup.box:SetText(code)
  exportPopup.box:HighlightText()
  exportPopup.box:SetFocus()
  exportPopup:Show()
end

-- Accessible depuis d'autres addons (ex: TibiSuiteOptions.lua, section
-- "Dashboard web") via le global _G.Stats, expose ici et depuis Core.lua.
_G.Stats = SX
