--[[============================================================================
  Stats - Export.lua
  ---------------------------------------------------------------------------
  Collecte (Stats + Metiers si charge + reputations si un module en fournit),
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

-- Nom exact du champ a verifier en jeu selon le module de reputation
-- effectivement installe (RepBar ou RenTracker) - best effort, jamais bloquant.
local function collectReputations()
  local ok, result = pcall(function()
    if _G.RepBarDB then return { source = "RepBar", data = _G.RepBarDB } end
    if _G.RenTrackerDB then return { source = "RenTracker", data = _G.RenTrackerDB } end
    return nil
  end)
  if ok then return result end
  return nil
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
      }
    else
      charInfo = {
        name = rec.name or name, realm = rec.realm or realm,
        class = rec.class, level = rec.level, spec = rec.spec, ilvl = rec.ilvl,
      }
    end
    chars[key] = {
      char = charInfo,
      days = rec.days or {},
      professions = allProfessions and allProfessions[key] or nil,
    }
  end

  return {
    schema = SX.SCHEMA_VERSION,
    generatedAt = time(),
    account = { generatedBy = currentKey },
    data = {
      chars = chars,
      reputations = collectReputations(),
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
