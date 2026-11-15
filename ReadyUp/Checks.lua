--[[============================================================================
  ReadyUp - Checks.lua
  ---------------------------------------------------------------------------
  Les controles. Chacun renvoie nil (sans objet ici : classe, contexte,
  version du jeu) ou un resultat :
    { id, label, state = "ok"|"warn"|"fail"|"unknown", value, detail, icon }
  Rien ne se lit en combat (RU.Evaluate refuse). Toute valeur secrete ou
  lecture impossible donne "unknown", jamais une fausse alerte.

  HYPOTHESES D'API A VERIFIER EN JEU (non testees, 2026-11-14) :
    - nourriture : nom localise du sort 19705 (« Bien nourri ») ou icone
      136000 (spell_misc_food), sur les trois familles de clients ;
    - flacons et elixirs : mots-cles localises (Locales), meilleure approche
      disponible sans liste d'identifiants par extension ;
    - poisons du voleur : enchantement d'arme (Classic) OU amelioration dont
      le nom contient « poison » (Midnight) ;
    - composants : ligne « Composants : » de l'infobulle du sort (Classic).
============================================================================]]

local ADDON, RU = ...
local T, A = RU.T, RU.API

local function Res(id, label, state, value, detail, icon)
  return { id = id, label = label, state = state, value = value, detail = detail, icon = icon }
end

local function Lower(s) return type(s) == "string" and s:lower() or "" end

-- ============================================================================
-- USURE
-- ============================================================================
local SLOT_LABEL = {
  [1] = "HEADSLOT", [3] = "SHOULDERSLOT", [5] = "CHESTSLOT", [6] = "WAISTSLOT",
  [7] = "LEGSSLOT", [8] = "FEETSLOT", [9] = "WRISTSLOT", [10] = "HANDSSLOT",
  [16] = "MAINHANDSLOT", [17] = "SECONDARYHANDSLOT", [18] = "RANGEDSLOT",
}

local function CheckDurability(db)
  if not (db.chkDurability and _G.GetInventoryItemDurability) then return nil end
  local minPct, minSlot, broken, seen = 101, nil, 0, false
  for slot = 1, 19 do
    local ok, cur, max = pcall(GetInventoryItemDurability, slot)
    if ok and RU.Safe(cur, max) and cur and max and max > 0 then
      seen = true
      local pct = cur / max * 100
      if cur == 0 then broken = broken + 1 end
      if pct < minPct then minPct, minSlot = pct, slot end
    end
  end
  local label = T("CHK_DUR", "Usure de l'équipement")
  local icon = "Interface\\Icons\\Trade_BlackSmithing"
  if not seen then return Res("dur", label, "ok", T("VAL_NONE", "rien à réparer"), nil, icon) end
  local pct = math.floor(minPct + 0.5)
  local slotName = minSlot and (_G[SLOT_LABEL[minSlot] or ""] or ("#" .. minSlot)) or ""
  local value = string.format("%d %%", pct)
  if broken > 0 then
    return Res("dur", label, "fail", value, string.format(T("DET_BROKEN", "%d pièce(s) cassée(s) : à réparer d'urgence"), broken), icon)
  end
  if pct < (db.durCrit or 10) then
    return Res("dur", label, "fail", value, string.format(T("DET_DUR_LOW", "%s : presque à zéro, répare avant le pull"), slotName), icon)
  end
  if pct < (db.durWarn or 30) then
    return Res("dur", label, "warn", value, string.format(T("DET_DUR_WARN", "%s : pense à réparer"), slotName), icon)
  end
  return Res("dur", label, "ok", value, nil, icon)
end

-- ============================================================================
-- SACS
-- ============================================================================
local function CheckBags(db)
  if not db.chkBags then return nil end
  local free, total = A.FreeBagSlots()
  local label = T("CHK_BAGS", "Place dans les sacs")
  local icon = "Interface\\Icons\\INV_Misc_Bag_08"
  if not free then return Res("bags", label, "unknown", "?", nil, icon) end
  local value = string.format("%d / %d", free, total)
  if free == 0 then return Res("bags", label, "fail", value, T("DET_BAGS_FULL", "sacs pleins : plus aucun butin ne rentrera"), icon) end
  if free < (db.bagWarn or 4) then return Res("bags", label, "warn", value, T("DET_BAGS_LOW", "presque pleins : vends ou range avant d'entrer"), icon) end
  return Res("bags", label, "ok", value, nil, icon)
end

-- ============================================================================
-- NOURRITURE ET FLACON (raid et donjon mythique, au niveau maximum)
-- ============================================================================
local function ConsumablesWanted(db, ctx)
  if ctx == "raid" or ctx == "keystone" then return A.AtMaxLevel() end
  if (ctx == "dungeon" or ctx == "delve") and db.consumInDungeons then return A.AtMaxLevel() end
  if ctx == "arena" and db.consumInArena then return A.AtMaxLevel() end
  return false
end

local wellFedName
local function IsFood(name, icon)
  wellFedName = wellFedName or A.SpellName(19705)
  if wellFedName and name == wellFedName then return true end
  if icon == 136000 then return true end
  return type(icon) == "string" and Lower(icon):find("spell_misc_food", 1, true) ~= nil
end

local function MatchKeywords(name, list)
  local n = Lower(name)
  for _, kw in ipairs(list or {}) do
    if kw ~= "" and n:find(kw, 1, true) then return true end
  end
  return false
end

-- Mots-cles : ceux de la langue du client plus l'anglais (repli).
local function Keywords(key, fr)
  local out = {}
  for _, w in ipairs(RU.L[key] or fr) do out[#out + 1] = Lower(w) end
  for _, w in ipairs(RU.EN_KEYWORDS[key] or {}) do out[#out + 1] = w end
  return out
end
RU.EN_KEYWORDS = {
  KW_FLASK  = { "flask", "phial", "elixir" },
  KW_POISON = { "poison" },
  KW_POTION = { "potion" },
}

local function ScanBuffs()
  local found = { food = false, flask = false, poison = false, sac = false, names = {}, ids = {} }
  local flaskKw = Keywords("KW_FLASK", { "flacon", "fiole", "élixir" })
  local poisonKw = Keywords("KW_POISON", { "poison" })
  -- Temps restant (secondes) d'une amelioration : expiration absolue sur
  -- l'horloge GetTime() ; 0 ou absent = permanente ou inconnue.
  local now = GetTime and GetTime() or 0
  local function left(expires)
    if type(expires) == "number" and expires > 0 and RU.Safe(expires) then return expires - now end
  end
  local function keepMax(cur, v) if v and (not cur or v > cur) then return v end return cur end
  local clean = A.ForEachBuff(function(name, spellId, icon, expires)
    if name then found.names[name] = true end
    if spellId then found.ids[spellId] = true end
    if IsFood(name, icon) then found.food = true; found.foodLeft = keepMax(found.foodLeft, left(expires)) end
    if MatchKeywords(name, flaskKw) then found.flask = true; found.flaskLeft = keepMax(found.flaskLeft, left(expires)) end
    if MatchKeywords(name, poisonKw) then found.poison = true end
    if spellId == 196099 or spellId == 108503 then found.sac = true end  -- Grimoire du sacrifice
  end)
  return found, clean
end

-- Nourriture et flacon : « expire bientot » sous buffExpireMin minutes.
local function ExpiresSoon(db, secs)
  local min = tonumber(db.buffExpireMin) or 0
  return secs and min > 0 and secs < min * 60
end
local function MinutesLeft(secs)
  return string.format(T("VAL_MIN", "%d min"), math.max(1, math.floor(secs / 60)))
end

local function CheckFood(db, ctx, buffs, clean)
  if not (db.chkFood and ConsumablesWanted(db, ctx)) then return nil end
  local label = T("CHK_FOOD", "Nourriture")
  local icon = "Interface\\Icons\\Spell_Misc_Food"
  if buffs.food then
    if ExpiresSoon(db, buffs.foodLeft) then
      return Res("food", label, "warn", MinutesLeft(buffs.foodLeft), T("DET_BUFF_SOON", "expire bientôt : renouvelle-le avant le pull"), icon)
    end
    return Res("food", label, "ok", T("VAL_ACTIVE", "active"), nil, icon)
  end
  if not clean then return Res("food", label, "unknown", "?", T("DET_SECRET", "lecture impossible pour l'instant"), icon) end
  return Res("food", label, "warn", T("VAL_MISSING", "absente"), T("DET_FOOD", "mange un plat avant le pull"), icon)
end

local function CheckFlask(db, ctx, buffs, clean)
  if not (db.chkFlask and ConsumablesWanted(db, ctx)) then return nil end
  local label = T("CHK_FLASK", "Flacon ou élixir")
  local icon = "Interface\\Icons\\INV_Potion_62"
  if buffs.flask then
    if ExpiresSoon(db, buffs.flaskLeft) then
      return Res("flask", label, "warn", MinutesLeft(buffs.flaskLeft), T("DET_BUFF_SOON", "expire bientôt : renouvelle-le avant le pull"), icon)
    end
    return Res("flask", label, "ok", T("VAL_ACTIVE_M", "actif"), nil, icon)
  end
  if not clean then return Res("flask", label, "unknown", "?", T("DET_SECRET", "lecture impossible pour l'instant"), icon) end
  return Res("flask", label, "warn", T("VAL_MISSING_M", "absent"), T("DET_FLASK", "bois un flacon ou un élixir"), icon)
end

-- ============================================================================
-- ENCHANTEMENT TEMPORAIRE D'ARME (poisons, huiles, pierres, imprégnations)
-- ============================================================================
local POISON_SPELLS = { 2842, 315584, 2823, 8679 }  -- Poisons (Classic), Instantane, Mortel, Douloureux (Midnight)

local function RogueNeedsPoison()
  local _, class = UnitClass("player")
  if class ~= "ROGUE" then return false end
  for _, id in ipairs(POISON_SPELLS) do if A.SpellKnown(id) then return true end end
  return false
end

local function CheckWeapon(db, ctx, buffs, clean)
  if not db.chkWeapon or not _G.GetWeaponEnchantInfo then return nil end
  local rogue = RogueNeedsPoison()
  -- En solo, seulement les poisons du voleur (une huile qui expire en quete
  -- n'interesse personne).
  if ctx == "solo" and not rogue then return nil end
  local ok, hasMain, mainExp, _, _, hasOff, offExp = pcall(GetWeaponEnchantInfo)
  if not ok or not RU.Safe(hasMain, mainExp, hasOff, offExp) then return nil end
  local label = T("CHK_WEAPON", "Enchantement temporaire d'arme")
  local icon = "Interface\\Icons\\INV_Stone_SharpeningStone_01"
  local need = rogue or db.weaponForAll
  local has = hasMain or hasOff or (rogue and buffs.poison)
  if has then
    -- Ce qui expire le plus tot (millisecondes).
    local left
    if hasMain and mainExp then left = mainExp end
    if hasOff and offExp and (not left or offExp < left) then left = offExp end
    local soon = (tonumber(db.weaponMin) or 10) * 60 * 1000
    if left and soon > 0 and left < soon then
      return Res("weapon", label, "warn", string.format(T("VAL_MIN", "%d min"), math.max(1, math.floor(left / 60000))),
        T("DET_WEAPON_SOON", "expire bientôt : renouvelle-le avant le pull"), icon)
    end
    if need or hasMain or hasOff then return Res("weapon", label, "ok", T("VAL_ACTIVE_M", "actif"), nil, icon) end
    return nil
  end
  if not need then return nil end
  if rogue and not clean then return Res("weapon", label, "unknown", "?", T("DET_SECRET", "lecture impossible pour l'instant"), icon) end
  return Res("weapon", label, "warn", T("VAL_MISSING_M", "absent"),
    rogue and T("DET_POISON", "applique tes poisons") or T("DET_WEAPON", "applique une huile, une pierre ou un poison"), icon)
end

-- ============================================================================
-- FAMILIER (chasseur, demoniste, chevalier de la mort impie)
-- ============================================================================
local function CheckPet(db, ctx, buffs)
  if not db.chkPet then return nil end
  local _, class = UnitClass("player")
  local needs = false
  if class == "HUNTER" then
    -- Loup solitaire (Precision, Midnight) : pas de familier par choix.
    needs = A.SpellKnown(883) and not A.SpellKnown(155228)
  elseif class == "WARLOCK" then
    needs = A.SpellKnown(688) and not buffs.sac
  elseif class == "DEATHKNIGHT" then
    needs = A.SpellKnown(52143) or (A.Spec() == 3 and A.SpellKnown(46584))
  end
  if not needs then return nil end
  if (UnitOnTaxi and UnitOnTaxi("player")) or (UnitInVehicle and UnitInVehicle("player")) then return nil end
  local label = T("CHK_PET", "Familier")
  local icon = "Interface\\Icons\\Ability_Hunter_BeastCall"
  local exists = UnitExists("pet")
  if exists and UnitIsDead("pet") then
    return Res("pet", label, "fail", T("VAL_DEAD", "mort"), T("DET_PET_DEAD", "ressuscite ton familier"), icon)
  end
  if not exists then
    return Res("pet", label, "warn", T("VAL_MISSING_M", "absent"), T("DET_PET", "appelle ton familier"), icon)
  end
  return Res("pet", label, "ok", UnitName("pet") or T("VAL_PRESENT", "présent"), nil, icon)
end

-- ============================================================================
-- MUNITIONS (clients qui ont un emplacement de munitions)
-- ============================================================================
local function CheckAmmo(db)
  if not db.chkAmmo then return nil end
  local _, class = UnitClass("player")
  if class ~= "HUNTER" then return nil end
  local slot = A.AmmoSlot()
  if not slot then return nil end
  local label = T("CHK_AMMO", "Flèches ou balles")
  local id = GetInventoryItemID and GetInventoryItemID("player", slot)
  local icon = (id and A.ItemIcon(id)) or "Interface\\Icons\\INV_Ammo_Arrow_02"
  if not id then return Res("ammo", label, "fail", "0", T("DET_AMMO_NONE", "aucune munition équipée"), icon) end
  local ok, n = pcall(GetInventoryItemCount, "player", slot)
  if not ok or not RU.Safe(n) then return Res("ammo", label, "unknown", "?", nil, icon) end
  n = tonumber(n) or 0
  if n == 0 then return Res("ammo", label, "fail", "0", T("DET_AMMO_NONE", "aucune munition équipée"), icon) end
  if n < (db.ammoWarn or 200) then return Res("ammo", label, "warn", tostring(n), T("DET_AMMO_LOW", "achète des munitions"), icon) end
  return Res("ammo", label, "ok", tostring(n), nil, icon)
end

-- ============================================================================
-- COMPOSANTS (Classic : seulement si l'infobulle du sort les reclame)
-- ============================================================================
local REAGENTS = {
  { spells = { 1856 },  items = { 5140 } },                 -- Disparition : Poudre eclipsante
  { spells = { 20608 }, items = { 17030 } },                -- Reincarnation : Ankh
  { spells = { 23028 }, items = { 17020 } },                -- Illumination des Arcanes : Poudre des arcanes
  { spells = { 3561, 3562, 3563, 3565, 3566, 3567 }, items = { 17031 } },  -- Teleportations : Rune de teleportation
  { spells = { 21562 }, items = { 17029 } },                -- Priere de robustesse : Bougie sacree
  { spells = { 21849 }, items = { 17021, 17026 } },         -- Don du fauve : Baies sauvages, Ronceterre
  { spells = { 25898 }, items = { 21177 } },                -- Benediction royale superieure : Symbole des rois
  { spells = { 697 },   items = { 6265 }, minKey = "shardWarn" },  -- Demoniste : Fragment d'ame
}

-- Infobulle cachee : le sort reclame-t-il cet objet ? nil = on ne sait pas.
local scanTip
local needCache = {}
local function SpellNeedsItem(spellId, itemId)
  local key = spellId .. ":" .. itemId
  if needCache[key] ~= nil then return needCache[key] end
  local itemName = A.ItemName(itemId)
  if not itemName then return nil end           -- pas encore en cache : on reessaiera
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "TibiReadyUpScanTip", nil, "GameTooltipTemplate")
  end
  if not scanTip.SetSpellByID then needCache[key] = false; return false end
  scanTip:SetOwner(UIParent, "ANCHOR_NONE")
  local ok = pcall(scanTip.SetSpellByID, scanTip, spellId)
  if not ok then scanTip:Hide(); return nil end
  local found = false
  for i = 1, scanTip:NumLines() do
    local fs = _G["TibiReadyUpScanTipTextLeft" .. i]
    local txt = fs and fs:GetText()
    if type(txt) == "string" and RU.Safe(txt) and txt:find(itemName, 1, true) then found = true; break end
  end
  scanTip:Hide()
  needCache[key] = found
  return found
end

-- Precharge les noms d'objets (Classic les charge en differe).
function RU.WarmReagents()
  for _, r in ipairs(REAGENTS) do for _, id in ipairs(r.items) do A.ItemName(id) end end
end

local function CheckReagents(db)
  if not db.chkReagents then return nil end
  local low, worst, shown, any = {}, "ok", nil, false
  for _, r in ipairs(REAGENTS) do
    local spell
    for _, s in ipairs(r.spells) do if A.SpellKnown(s) then spell = s; break end end
    if spell then
      local needed, count = false, 0
      for _, id in ipairs(r.items) do
        if A.ItemExists(id) and SpellNeedsItem(spell, id) then needed = true end
        count = count + (A.ItemCount(id) or 0)
      end
      if needed then
        any = true
        local min = (r.minKey and tonumber(db[r.minKey])) or db.reagentWarn or 5
        local name = A.ItemName(r.items[1]) or ("#" .. r.items[1])
        if count == 0 then
          worst = "fail"; low[#low + 1] = name .. " : 0"
          shown = shown or A.ItemIcon(r.items[1])
        elseif count < min then
          if worst ~= "fail" then worst = "warn" end
          low[#low + 1] = name .. " : " .. count
          shown = shown or A.ItemIcon(r.items[1])
        end
      end
    end
  end
  if not any then return nil end
  local label = T("CHK_REAGENTS", "Composants")
  local icon = shown or "Interface\\Icons\\INV_Misc_Dust_02"
  if worst == "ok" then return Res("reagents", label, "ok", T("VAL_ENOUGH", "en stock"), nil, icon) end
  return Res("reagents", label, worst, tostring(#low), table.concat(low, ", "), icon)
end

-- ============================================================================
-- EQUIPEMENT : ENCHANTEMENTS, RENFORT D'ARMURE, CHASSES
-- Au niveau maximum, en raid, donjon mythique et arene seulement.
-- HYPOTHESE (non verifiee en jeu) : emplacements enchantables par extension,
-- lus avec GetClassicExpansionLevel (Classic) sinon GetExpansionLevel. La
-- liste de Midnight (11) et le comportement de Forever sont a confirmer :
-- d'ou ces deux controles decoches par defaut.
-- ============================================================================
local ENCHANT_SLOTS = {
  [0]  = { 15, 5, 9, 10, 8, 16 },             -- Classic : dos, torse, poignets, mains, pieds, arme
  [1]  = { 1, 3, 15, 5, 9, 10, 8, 16 },       -- TBC : + tete (arcanum), epaules (inscription)
  [2]  = { 1, 3, 15, 5, 9, 10, 8, 16 },       -- Wrath
  [3]  = { 1, 3, 15, 5, 9, 10, 8, 16 },       -- Cataclysm
  [4]  = { 3, 15, 5, 9, 10, 8, 16 },          -- Mists (plus d'arcanum de tete)
  [10] = { 15, 5, 9, 8, 11, 12, 16 },         -- The War Within : dos, torse, poignets, pieds, anneaux, arme
  [11] = { 1, 3, 5, 8, 11, 12, 16 },          -- Midnight : A VERIFIER EN JEU
}
local LEGS = 7

local function ExpansionLevel()
  local fn = _G.GetClassicExpansionLevel or _G.GetExpansionLevel
  if not fn then return 0 end
  local ok, lvl = pcall(fn)
  return (ok and tonumber(lvl)) or 0
end

local function EnchantSlots()
  local lvl = ExpansionLevel()
  for l = lvl, 0, -1 do
    if ENCHANT_SLOTS[l] then return ENCHANT_SLOTS[l] end
  end
  return ENCHANT_SLOTS[0]
end

-- Champs d'un lien d'objet : item:id:enchant:gemme1:gemme2:gemme3:gemme4
local function LinkFields(slot)
  if not _G.GetInventoryItemLink then return nil end
  local ok, link = pcall(GetInventoryItemLink, "player", slot)
  if not ok or type(link) ~= "string" or not RU.Safe(link) then return nil end
  local body = link:match("item:([%-%d:]+)")
  if not body then return nil end
  local f = {}
  for v in (body .. ":"):gmatch("(%-?%d*):") do f[#f + 1] = tonumber(v) or 0 end
  return f, link
end

local function SlotName(slot)
  return _G[SLOT_LABEL[slot] or ""] or (slot == 15 and _G.BACKSLOT) or (slot == 11 and _G.FINGER0SLOT)
    or (slot == 12 and _G.FINGER1SLOT) or ("#" .. slot)
end
SLOT_LABEL[15] = "BACKSLOT"; SLOT_LABEL[11] = "FINGER0SLOT"; SLOT_LABEL[12] = "FINGER1SLOT"

local function GearWanted(ctx)
  return (ctx == "raid" or ctx == "keystone" or ctx == "arena") and A.AtMaxLevel()
end

local function CheckEnchants(db, ctx)
  if not (db.chkEnchant and GearWanted(ctx)) then return nil end
  local missing = {}
  for _, slot in ipairs(EnchantSlots()) do
    local f = LinkFields(slot)
    if f and (f[2] or 0) == 0 then missing[#missing + 1] = SlotName(slot) end
  end
  local label = T("CHK_ENCHANT", "Enchantements")
  local icon = "Interface\\Icons\\Trade_Engraving"
  if #missing == 0 then return Res("enchant", label, "ok", T("VAL_COMPLETE", "complets"), nil, icon) end
  return Res("enchant", label, "warn", tostring(#missing),
    string.format(T("DET_ENCHANT", "manquant : %s"), table.concat(missing, ", ")), icon)
end

local function CheckArmorKit(db, ctx)
  if not (db.chkArmorKit and GearWanted(ctx)) then return nil end
  local f = LinkFields(LEGS)
  if not f then return nil end
  local label = T("CHK_ARMORKIT", "Renfort d'armure")
  local icon = "Interface\\Icons\\INV_Misc_ArmorKit_17"
  if (f[2] or 0) ~= 0 then return Res("armorkit", label, "ok", T("VAL_ACTIVE_M", "actif"), nil, icon) end
  return Res("armorkit", label, "warn", T("VAL_MISSING_M", "absent"), T("DET_ARMORKIT", "jambes sans renfort ni fil"), icon)
end

local function CheckGems(db, ctx)
  if not (db.chkGems and GearWanted(ctx)) then return nil end
  local getStats = (C_Item and C_Item.GetItemStats) or _G.GetItemStats
  if not getStats then return nil end
  local empty, where = 0, {}
  for slot = 1, 18 do
    local f, link = LinkFields(slot)
    if f then
      local ok, stats = pcall(getStats, link)
      if ok and type(stats) == "table" then
        local sockets = 0
        for k, v in pairs(stats) do
          if type(k) == "string" and k:find("EMPTY_SOCKET_", 1, true) then sockets = sockets + (tonumber(v) or 0) end
        end
        local filled = 0
        for i = 3, 6 do if (f[i] or 0) ~= 0 then filled = filled + 1 end end
        local e = sockets - filled
        if e > 0 then empty = empty + e; where[#where + 1] = SlotName(slot) end
      end
    end
  end
  local label = T("CHK_GEMS", "Châsses vides")
  local icon = "Interface\\Icons\\INV_Misc_Gem_01"
  if empty == 0 then return Res("gems", label, "ok", "0", nil, icon) end
  return Res("gems", label, "warn", tostring(empty),
    string.format(T("DET_GEMS", "%d châsse(s) vide(s) : %s"), empty, table.concat(where, ", ")), icon)
end

-- ============================================================================
-- POTIONS DANS LES SACS (raid, donjon mythique, arene)
-- Potion = objet consommable de sous-classe 1, ou nom contenant le mot-cle
-- localise (repli pour les clients ou la sous-classe differe).
-- ============================================================================
local function ContainerItem(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if ok and type(info) == "table" then return info.itemID, info.stackCount end
    return nil
  end
  if _G.GetContainerItemInfo then
    local ok, _, count, _, _, _, _, _, _, _, id = pcall(GetContainerItemInfo, bag, slot)
    if ok then return id, count end
  end
end

local potionCache = {}
local function IsPotion(id)
  if potionCache[id] ~= nil then return potionCache[id] end
  local fn = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
  local is = false
  if fn then
    local ok, _, _, _, _, _, classID, subID = pcall(fn, id)
    if ok and classID == 0 and subID == 1 then is = true end
  end
  if not is then
    local name = A.ItemName(id)
    if not name then return false end           -- nom pas encore charge : on reessaiera
    is = MatchKeywords(name, Keywords("KW_POTION", { "potion" }))
  end
  potionCache[id] = is
  return is
end

local function CheckPotions(db, ctx)
  if not (db.chkPotion and (ctx == "raid" or ctx == "keystone" or ctx == "arena") and A.AtMaxLevel()) then return nil end
  local getSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
  if not getSlots then return nil end
  local count = 0
  for bag = 0, (_G.NUM_BAG_SLOTS or 4) do
    local ok, n = pcall(getSlots, bag)
    for s = 1, (ok and tonumber(n) or 0) do
      local id, c = ContainerItem(bag, s)
      if id and RU.Safe(id, c) and IsPotion(id) then count = count + (tonumber(c) or 1) end
    end
  end
  local label = T("CHK_POTION", "Potions")
  local icon = "Interface\\Icons\\INV_Potion_54"
  if count == 0 then return Res("potion", label, "warn", "0", T("DET_POTION", "aucune potion dans les sacs"), icon) end
  if count < (db.potionWarn or 1) then return Res("potion", label, "warn", tostring(count), T("DET_POTION_LOW", "peu de potions"), icon) end
  return Res("potion", label, "ok", tostring(count), nil, icon)
end

-- ============================================================================
-- AMELIORATIONS DE CLASSE (sur soi, longue duree)
-- Un groupe s'applique si le personnage connait l'un de ses sorts ; il est
-- satisfait si l'une de ses ameliorations est active (nom ou identifiant).
-- Identifiants : rang 1 sur Classic (les rangs inferieurs restent connus),
-- identifiants actuels sur Midnight. A verifier en jeu.
-- ============================================================================
local SELF_BUFFS = {
  HUNTER  = { { 13165, 13163, 20043, 5118, 13159, 34074, 61846 } },   -- Aspects (Classic a Wrath)
  MAGE    = { { 168, 7302, 6117, 30482 }, { 1459, 23028 } },          -- Armures ; Intelligence des Arcanes
  PRIEST  = { { 588 }, { 1243, 21562 } },                             -- Feu interieur ; Robustesse
  DRUID   = { { 1126, 21849 } },                                      -- Marque du fauve, Don du fauve
  WARLOCK = { { 687, 706, 28176 } },                                  -- Peau, Armure demoniaque, Gangrarmure
  SHAMAN  = { { 324, 192106, 52127 } },                               -- Bouclier de foudre, d'eau
  PALADIN = { { 465, 7294, 19746, 32223, 183435 } },                  -- Auras
  EVOKER  = { { 364342 } },                                           -- Benediction du bronze
}

local function CheckSelfBuff(db, ctx, buffs, clean)
  if not db.chkSelfBuff then return nil end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return nil end
  local _, class = UnitClass("player")
  local groups = SELF_BUFFS[class]
  if not groups then return nil end
  local missing, applies = {}, false
  for _, g in ipairs(groups) do
    local known, active = nil, false
    for _, id in ipairs(g) do
      if not known and A.SpellKnown(id) then known = id end
      local n = A.SpellName(id)
      if buffs.ids[id] or (n and buffs.names[n]) then active = true end
    end
    if known then
      applies = true
      if not active then missing[#missing + 1] = A.SpellName(known) or ("#" .. known) end
    end
  end
  if not applies then return nil end
  local label = T("CHK_SELFBUFF", "Amélioration de classe")
  local icon = "Interface\\Icons\\Spell_Holy_MagicalSentry"
  if #missing == 0 then return Res("selfbuff", label, "ok", T("VAL_ACTIVE", "active"), nil, icon) end
  if not clean then return Res("selfbuff", label, "unknown", "?", T("DET_SECRET", "lecture impossible pour l'instant"), icon) end
  return Res("selfbuff", label, "warn", tostring(#missing),
    string.format(T("DET_SELFBUFF", "lance %s"), table.concat(missing, ", ")), icon)
end

-- ============================================================================
-- CONTEXTES
-- solo, delve (gouffre), dungeon, keystone (mythique), raid, pvp (champ de
-- bataille), arena. Chaque controle n'est montre que dans ses contextes ;
-- nourriture, flacon, potions et equipement filtrent en plus eux-memes
-- (niveau maximum, options).
-- ============================================================================
local ALL = { solo = true, delve = true, dungeon = true, keystone = true, raid = true, pvp = true, arena = true }
local PVE = { solo = true, delve = true, dungeon = true, keystone = true, raid = true }
RU.WANT = {
  dur = ALL, bags = PVE, food = ALL, flask = ALL, weapon = ALL, pet = ALL, ammo = ALL,
  reagents = ALL, enchant = ALL, armorkit = ALL, gems = ALL, potion = ALL, selfbuff = ALL,
}

-- ============================================================================
-- EVALUATION
-- ============================================================================
local RANK = { ok = 0, unknown = 1, warn = 2, fail = 3 }
RU.RANK = RANK

-- reason : "manual", "instance", "ready", "merchant", "refresh". Renvoie la
-- liste des resultats applicables, ou nil en combat (rien n'est lu).
function RU.Evaluate(reason)
  if not TibiReadyUpDB then return nil end
  if InCombatLockdown and InCombatLockdown() then return nil end
  local db = TibiReadyUpDB
  local ctx = A.Context()
  local buffs, clean = ScanBuffs()
  local list = {}
  local function add(r)
    if r and RU.WANT[r.id] and RU.WANT[r.id][ctx] then list[#list + 1] = r end
  end
  add(CheckDurability(db))
  add(CheckBags(db))
  add(CheckFood(db, ctx, buffs, clean))
  add(CheckFlask(db, ctx, buffs, clean))
  add(CheckPotions(db, ctx))
  add(CheckWeapon(db, ctx, buffs, clean))
  add(CheckSelfBuff(db, ctx, buffs, clean))
  add(CheckPet(db, ctx, buffs))
  add(CheckAmmo(db))
  add(CheckReagents(db))
  add(CheckEnchants(db, ctx))
  add(CheckArmorKit(db, ctx))
  add(CheckGems(db, ctx))
  local issues, worst = 0, "ok"
  for _, r in ipairs(list) do
    if r.state == "warn" or r.state == "fail" then issues = issues + 1 end
    if RANK[r.state] > RANK[worst] then worst = r.state end
  end
  RU.last = { at = time(), reason = reason, context = ctx, results = list, issues = issues, worst = worst }
  RU.OnChanged()
  return RU.last
end

function RU.ContextLabel(ctx)
  if ctx == "raid" then return T("CTX_RAID", "raid") end
  if ctx == "keystone" then return T("CTX_KEY", "donjon mythique") end
  if ctx == "dungeon" then return T("CTX_DUNGEON", "donjon") end
  if ctx == "delve" then return T("CTX_DELVE", "gouffre") end
  if ctx == "pvp" then return T("CTX_PVP", "champ de bataille") end
  if ctx == "arena" then return T("CTX_ARENA", "arène") end
  return T("CTX_SOLO", "en solo")
end

-- Titre de l'alerte (« Avant le raid ») et confirmation (« Prêt pour le raid »).
function RU.ContextTitle(ctx)
  if ctx == "raid" then return T("TITLE_RAID", "Avant le raid") end
  if ctx == "keystone" then return T("TITLE_KEY", "Avant la clé") end
  if ctx == "dungeon" then return T("TITLE_DUNGEON", "Avant le donjon") end
  if ctx == "delve" then return T("TITLE_DELVE", "Avant le gouffre") end
  if ctx == "pvp" then return T("TITLE_PVP", "Avant le champ de bataille") end
  if ctx == "arena" then return T("TITLE_ARENA", "Avant l'arène") end
  return T("TITLE_SOLO", "En route")
end

function RU.ContextReady(ctx)
  if ctx == "raid" then return T("READY_RAID", "Prêt pour le raid") end
  if ctx == "keystone" then return T("READY_KEY", "Prêt pour la clé") end
  if ctx == "dungeon" then return T("READY_DUNGEON", "Prêt pour le donjon") end
  if ctx == "delve" then return T("READY_DELVE", "Prêt pour le gouffre") end
  if ctx == "pvp" then return T("READY_PVP", "Prêt pour le champ de bataille") end
  if ctx == "arena" then return T("READY_ARENA", "Prêt pour l'arène") end
  return T("READY_SOLO", "Prêt à repartir")
end

-- Couleur d'un etat (r, g, b).
function RU.StateColor(state)
  if state == "fail" then return 1, 0.35, 0.35 end
  if state == "warn" then return 1, 0.7, 0.28 end
  if state == "unknown" then return 0.6, 0.6, 0.6 end
  return RU.ACCENT[1], RU.ACCENT[2], RU.ACCENT[3]
end
