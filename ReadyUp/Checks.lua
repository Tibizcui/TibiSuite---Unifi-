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
  if pct < 10 then
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
  if ctx == "dungeon" and db.consumInDungeons then return A.AtMaxLevel() end
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
}

local function ScanBuffs()
  local found = { food = false, flask = false, poison = false, sac = false }
  local flaskKw = Keywords("KW_FLASK", { "flacon", "fiole", "élixir" })
  local poisonKw = Keywords("KW_POISON", { "poison" })
  local clean = A.ForEachBuff(function(name, spellId, icon)
    if IsFood(name, icon) then found.food = true end
    if MatchKeywords(name, flaskKw) then found.flask = true end
    if MatchKeywords(name, poisonKw) then found.poison = true end
    if spellId == 196099 or spellId == 108503 then found.sac = true end  -- Grimoire du sacrifice
  end)
  return found, clean
end

local function CheckFood(db, ctx, buffs, clean)
  if not (db.chkFood and ConsumablesWanted(db, ctx)) then return nil end
  local label = T("CHK_FOOD", "Nourriture")
  local icon = "Interface\\Icons\\Spell_Misc_Food"
  if buffs.food then return Res("food", label, "ok", T("VAL_ACTIVE", "active"), nil, icon) end
  if not clean then return Res("food", label, "unknown", "?", T("DET_SECRET", "lecture impossible pour l'instant"), icon) end
  return Res("food", label, "warn", T("VAL_MISSING", "absente"), T("DET_FOOD", "mange un plat avant le pull"), icon)
end

local function CheckFlask(db, ctx, buffs, clean)
  if not (db.chkFlask and ConsumablesWanted(db, ctx)) then return nil end
  local label = T("CHK_FLASK", "Flacon ou élixir")
  local icon = "Interface\\Icons\\INV_Potion_62"
  if buffs.flask then return Res("flask", label, "ok", T("VAL_ACTIVE_M", "actif"), nil, icon) end
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
  if not db.chkWeapon or ctx == "solo" or not _G.GetWeaponEnchantInfo then return nil end
  local ok, hasMain, mainExp, _, _, hasOff, offExp = pcall(GetWeaponEnchantInfo)
  if not ok or not RU.Safe(hasMain, mainExp, hasOff, offExp) then return nil end
  local label = T("CHK_WEAPON", "Enchantement d'arme")
  local icon = "Interface\\Icons\\INV_Stone_SharpeningStone_01"
  local rogue = RogueNeedsPoison()
  local need = rogue or db.weaponForAll
  local has = hasMain or hasOff or (rogue and buffs.poison)
  if has then
    -- Ce qui expire le plus tot (millisecondes).
    local left
    if hasMain and mainExp then left = mainExp end
    if hasOff and offExp and (not left or offExp < left) then left = offExp end
    if left and left < 10 * 60 * 1000 then
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
  local label = T("CHK_AMMO", "Munitions")
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
  { spells = { 697 },   items = { 6265 }, min = 3 },        -- Demoniste : Fragment d'ame
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
        local min = r.min or db.reagentWarn or 5
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
-- EVALUATION
-- ============================================================================
local RANK = { ok = 0, unknown = 1, warn = 2, fail = 3 }
RU.RANK = RANK

-- reason : "manual", "instance", "ready", "merchant", "login". Renvoie la
-- liste des resultats applicables, ou nil en combat (rien n'est lu).
function RU.Evaluate(reason)
  if not TibiReadyUpDB then return nil end
  if InCombatLockdown and InCombatLockdown() then return nil end
  local db = TibiReadyUpDB
  local ctx = A.Context()
  local buffs, clean = ScanBuffs()
  local list = {}
  local function add(r) if r then list[#list + 1] = r end end
  add(CheckDurability(db))
  add(CheckBags(db))
  add(CheckFood(db, ctx, buffs, clean))
  add(CheckFlask(db, ctx, buffs, clean))
  add(CheckWeapon(db, ctx, buffs, clean))
  add(CheckPet(db, ctx, buffs))
  add(CheckAmmo(db))
  add(CheckReagents(db))
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
  return T("CTX_SOLO", "en solo")
end

-- Couleur d'un etat (r, g, b).
function RU.StateColor(state)
  if state == "fail" then return 1, 0.35, 0.35 end
  if state == "warn" then return 1, 0.7, 0.28 end
  if state == "unknown" then return 0.6, 0.6, 0.6 end
  return RU.ACCENT[1], RU.ACCENT[2], RU.ACCENT[3]
end
