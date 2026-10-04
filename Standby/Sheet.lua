--[[============================================================================
  Standby - Sheet.lua
  ---------------------------------------------------------------------------
  Donnees de la fiche du personnage : titre, specialisation, niveau d'objet,
  statistiques et equipement. Lecture seule, APIs Blizzard directes (meme
  principe que la fiche detaillee de WeeklyCompass), rien n'est sauvegarde.

  Utilise par la Vitrine (titre + fiche courte sous le nom) et par la mise en
  page Fiche (equipement complet + panneau de statistiques).

  Valeurs secretes de Midnight : les statistiques peuvent etre masquees aux
  addons en combat. L'ecran n'est jamais affiche en combat, mais tout passe
  quand meme sous pcall + issecretvalue.

  NON TESTE EN JEU : formats de GetSpecializationInfo (primaryStat en 6e
  retour), C_Item.GetCurrentItemLevel, decoupage des liens d'objet (gemmes),
  C_Item.GetItemStats pour les chasses.
============================================================================]]

local ADDON, SB = ...
local T = SB.T

local Sheet = {}
SB.Sheet = Sheet

local function Num(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if not ok or v == nil then return nil end
  if issecretvalue then
    local okS, secret = pcall(issecretvalue, v)
    if not okS or secret then return nil end
  end
  return v
end

-- ----------------------------------------------------------------------------
-- Titre : UnitPVPName donne le nom deja habille (« Sergent Tibiscui »,
-- « Tibiscui le Patient »). On retire le nom pour ne garder que le titre.
-- ----------------------------------------------------------------------------
function Sheet.Title()
  local name = UnitName("player")
  local full = Num(UnitPVPName, "player")
  if type(full) ~= "string" or not name or full == name then return nil end
  local i, j = full:find(name, 1, true)
  if not i then return nil end
  local t = (full:sub(1, i - 1) .. full:sub(j + 1))
  t = t:gsub("^[%s,]+", ""):gsub("[%s,]+$", "")
  if t == "" then return nil end
  return t
end

-- ----------------------------------------------------------------------------
-- Specialisation + niveau d'objet
-- ----------------------------------------------------------------------------
function Sheet.Spec()
  local idx = Num(GetSpecialization)
  if not idx then return nil end
  local ok, id, name, _, icon, role, primaryStat = pcall(GetSpecializationInfo, idx)
  if not ok or not name then return nil end
  return { id = id, name = name, icon = icon, role = role, primaryStat = primaryStat }
end

function Sheet.ItemLevel()
  if type(GetAverageItemLevel) ~= "function" then return nil end
  local ok, overall, equipped = pcall(GetAverageItemLevel)
  if not ok or not overall then return nil end
  return math.floor(overall), equipped and math.floor(equipped) or nil
end

function Sheet.SpecLine()
  local parts = {}
  local spec = Sheet.Spec()
  if spec then
    parts[#parts + 1] = (spec.icon and ("|T" .. spec.icon .. ":14:14:0:0|t ") or "") .. spec.name
  end
  local overall, equipped = Sheet.ItemLevel()
  if overall then
    if equipped and equipped ~= overall then
      parts[#parts + 1] = string.format(T("SHEET_ILVL2", "niveau d'objet %d (équipé %d)"), overall, equipped)
    else
      parts[#parts + 1] = string.format(T("SHEET_ILVL", "niveau d'objet %d"), overall)
    end
  end
  if #parts == 0 then return nil end
  return table.concat(parts, "  ·  ")
end

-- ----------------------------------------------------------------------------
-- Statistiques (libelles localises par Blizzard)
-- ----------------------------------------------------------------------------
local function Pct(v) return string.format("%.1f %%", v) end

function Sheet.Stats()
  local out = {}
  local spec = Sheet.Spec()
  local primary = spec and tonumber(spec.primaryStat) or nil
  if primary and UnitStat then
    local okU, base, effective = pcall(UnitStat, "player", primary)
    effective = okU and (effective or base) or nil
    if effective and not (issecretvalue and issecretvalue(effective)) then
      out[#out + 1] = { label = _G["SPELL_STAT" .. primary .. "_NAME"] or "?", value = tostring(math.floor(effective)) }
    end
  end
  if UnitStat then
    local okU, base, effective = pcall(UnitStat, "player", 3)
    effective = okU and (effective or base) or nil
    if effective and not (issecretvalue and issecretvalue(effective)) then
      out[#out + 1] = { label = _G.SPELL_STAT3_NAME or T("STAT_STA", "Endurance"), value = tostring(math.floor(effective)) }
    end
  end
  local crit = Num(GetCritChance) or 0
  local spellCrit = Num(GetSpellCritChance, 2) or 0
  local rangedCrit = Num(GetRangedCritChance) or 0
  crit = math.max(crit, spellCrit, rangedCrit)
  out[#out + 1] = { label = _G.STAT_CRITICAL_STRIKE or T("STAT_CRIT", "Coup critique"), value = Pct(crit), short = true }
  local haste = Num(GetHaste)
  if haste then out[#out + 1] = { label = _G.STAT_HASTE or T("STAT_HASTE", "Hâte"), value = Pct(haste), short = true } end
  local mastery = Num(GetMasteryEffect)
  if mastery then out[#out + 1] = { label = _G.STAT_MASTERY or T("STAT_MASTERY", "Maîtrise"), value = Pct(mastery), short = true } end
  local cr = _G.CR_VERSATILITY_DAMAGE_DONE or 29
  local vers = (Num(GetCombatRatingBonus, cr) or 0) + (Num(GetVersatilityBonus, cr) or 0)
  out[#out + 1] = { label = _G.STAT_VERSATILITY or T("STAT_VERS", "Polyvalence"), value = Pct(vers), short = true }
  return out
end

-- Ligne courte de la Vitrine : les quatre statistiques secondaires.
function Sheet.StatsLine()
  local parts = {}
  for _, s in ipairs(Sheet.Stats()) do
    if s.short then parts[#parts + 1] = s.label .. " " .. s.value end
  end
  if #parts == 0 then return nil end
  return table.concat(parts, "  ·  ")
end

-- ----------------------------------------------------------------------------
-- Equipement
-- ----------------------------------------------------------------------------
-- Colonnes de la mise en page Fiche (meme disposition que la fenetre
-- Personnage du jeu ; chemise et tabard omis, armes en bas de la colonne
-- gauche pour equilibrer 8 / 8).
Sheet.LEFT  = { 1, 2, 3, 15, 5, 9, 16, 17 }
Sheet.RIGHT = { 10, 6, 7, 8, 11, 12, 13, 14 }

local SLOT_LABEL = {
  [1] = "HEADSLOT", [2] = "NECKSLOT", [3] = "SHOULDERSLOT", [15] = "BACKSLOT", [5] = "CHESTSLOT",
  [9] = "WRISTSLOT", [16] = "MAINHANDSLOT", [17] = "SECONDARYHANDSLOT", [10] = "HANDSSLOT",
  [6] = "WAISTSLOT", [7] = "LEGSSLOT", [8] = "FEETSLOT", [11] = "FINGER0SLOT", [12] = "FINGER1SLOT",
  [13] = "TRINKET0SLOT", [14] = "TRINKET1SLOT",
}
function Sheet.SlotLabel(slot) return _G[SLOT_LABEL[slot] or ""] or ("#" .. slot) end

-- "item:ID:enchant:gem1:gem2:gem3:gem4:..." en gardant les champs vides.
local function Split(s)
  local t, start = {}, 1
  while true do
    local i = s:find(":", start, true)
    if not i then t[#t + 1] = s:sub(start); break end
    t[#t + 1] = s:sub(start, i - 1)
    start = i + 1
  end
  return t
end

local function QualityHex(q)
  if q and C_Item and C_Item.GetItemQualityColor then
    local ok, r, g, b = pcall(C_Item.GetItemQualityColor, q)
    if ok and r then return SB.Hex({ r, g, b }) end
  end
  local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c and c.r then return SB.Hex({ c.r, c.g, c.b }) end
  return "|cFFFFFFFF"
end

local function ItemLevelOf(slot, link)
  if ItemLocation and ItemLocation.CreateFromEquipmentSlot and C_Item and C_Item.GetCurrentItemLevel then
    local okL, loc = pcall(ItemLocation.CreateFromEquipmentSlot, ItemLocation, slot)
    if okL and loc then
      local lvl = Num(C_Item.GetCurrentItemLevel, loc)
      if lvl and lvl > 0 then return lvl end
    end
  end
  local fn = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
  local lvl = Num(fn, link)
  return lvl
end

-- Renvoie nil si l'emplacement est vide, sinon :
-- { icon, name (colore), ilvl, enchanted, gems = {icones}, emptySockets }
function Sheet.Slot(slot)
  local link = Num(GetInventoryItemLink, "player", slot)
  if type(link) ~= "string" then return nil end
  local icon = Num(GetInventoryItemTexture, "player", slot)
  local q = Num(GetInventoryItemQuality, "player", slot)
  local name = link:match("%[(.-)%]") or "?"
  local out = { icon = icon, name = QualityHex(q) .. name .. "|r", ilvl = ItemLevelOf(slot, link), gems = {} }

  local str = link:match("item:([%-%w:]+)")
  if str then
    local f = Split(str)
    out.enchanted = (tonumber(f[2]) or 0) > 0
    local filled = 0
    for k = 3, 6 do
      local gem = tonumber(f[k])
      if gem and gem > 0 then
        filled = filled + 1
        local gi = (C_Item and C_Item.GetItemIconByID and Num(C_Item.GetItemIconByID, gem)) or (GetItemIcon and Num(GetItemIcon, gem))
        if gi then out.gems[#out.gems + 1] = gi end
      end
    end
    -- Chasses de l'objet (comptees sur sa fiche de base).
    local statsFn = (C_Item and C_Item.GetItemStats) or GetItemStats
    local stats = Num(statsFn, link)
    if type(stats) == "table" then
      local sockets = 0
      for k, v in pairs(stats) do
        if type(k) == "string" and k:find("^EMPTY_SOCKET_") then sockets = sockets + (tonumber(v) or 0) end
      end
      if sockets > filled then out.emptySockets = sockets - filled end
    end
  end
  return out
end

-- Ligne d'information sous le nom de l'objet.
function Sheet.SlotInfo(d)
  local parts = {}
  if d.ilvl then parts[#parts + 1] = tostring(math.floor(d.ilvl)) end
  if d.enchanted then parts[#parts + 1] = "|cFF66D98A" .. T("SHEET_ENCHANT", "enchanté") .. "|r" end
  for _, gi in ipairs(d.gems) do parts[#parts + 1] = "|T" .. gi .. ":12:12:0:0|t" end
  if d.emptySockets then
    parts[#parts + 1] = "|cFFFF7F7F" .. string.format(T("SHEET_SOCKET", "%d châsse(s) vide(s)"), d.emptySockets) .. "|r"
  end
  return table.concat(parts, "  ")
end
