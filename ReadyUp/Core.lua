--[[============================================================================
  ReadyUp - Core.lua
  ---------------------------------------------------------------------------
  « Suis-je pret ? » : verifie, hors combat, ce qui manque avant un pull.
  Ce fichier : espace de noms, sauvegarde TibiReadyUpDB, activation, et la
  couche de compatibilite des API (Midnight, WoW Forever, Classic).

  REGLES :
    - aucune lecture en combat : sous Midnight et Forever, certaines valeurs
      sont « secretes » en combat. Tout se lit hors combat, et toute valeur
      secrete rend le controle « inconnu » (jamais une fausse alerte) ;
    - API choisie par PRESENCE de la fonction, jamais par numero de version ;
    - aucun code securise, aucune ecriture dans une frame Blizzard.
  NON TESTE EN JEU (2026-11-14) : a valider par Tibiscui avec un /reload sur
  Midnight, Forever et Classic Era.
============================================================================]]

local ADDON, RU = ...

RU.ACCENT = { 0.298, 0.851, 0.392 }   -- vert « feu vert » #4CD964 (identite ReadyUp)
RU.LOGO   = "Interface\\AddOns\\ReadyUp\\medias\\Logo"
RU.KEY    = "ReadyUp"

RU.L = RU.L or {}
function RU.T(key, fr) return RU.L[key] or fr end

local function Hex()
  local a = RU.ACCENT
  return string.format("|cFF%02X%02X%02X", math.floor(a[1]*255+0.5), math.floor(a[2]*255+0.5), math.floor(a[3]*255+0.5))
end
RU.Hex = Hex
function RU.Print(msg) print(Hex() .. "ReadyUp|r : " .. tostring(msg)) end

-- ============================================================================
-- VALEURS SECRETES (12.x)
-- ============================================================================
local issecret = _G.issecretvalue or function() return false end
function RU.Safe(...)
  for i = 1, select("#", ...) do
    if issecret((select(i, ...))) then return false end
  end
  return true
end

-- ============================================================================
-- COMPATIBILITE DES API
-- Chaque fonction renvoie nil si l'API est absente ou si la lecture echoue.
-- ============================================================================
local A = {}
RU.API = A

-- Nombre d'objets dans les sacs (C_Item sous Midnight, global ailleurs).
function A.ItemCount(id)
  local fn = (C_Item and C_Item.GetItemCount) or _G.GetItemCount
  if not fn then return nil end
  local ok, n = pcall(fn, id)
  if ok and RU.Safe(n) then return tonumber(n) end
  return nil
end

-- L'objet existe-t-il dans cette version du jeu ?
function A.ItemExists(id)
  local fn = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
  if not fn then return true end
  local ok, itemID = pcall(fn, id)
  return ok and itemID ~= nil
end

function A.ItemIcon(id)
  local fn = (C_Item and C_Item.GetItemIconByID) or _G.GetItemIcon
  if not fn then return nil end
  local ok, icon = pcall(fn, id)
  if ok then return icon end
end

function A.ItemName(id)
  local fn = (C_Item and C_Item.GetItemNameByID) or (_G.GetItemInfo and function(i) return (GetItemInfo(i)) end)
  if not fn then return nil end
  local ok, name = pcall(fn, id)
  if ok then return name end
end

-- Sort connu du personnage (rang 1 compris sur Classic).
function A.SpellKnown(id)
  if _G.IsPlayerSpell then
    local ok, v = pcall(IsPlayerSpell, id)
    if ok and v then return true end
  end
  if C_SpellBook and C_SpellBook.IsSpellKnown then
    local ok, v = pcall(C_SpellBook.IsSpellKnown, id)
    if ok and v then return true end
  end
  if _G.IsSpellKnown then
    local ok, v = pcall(IsSpellKnown, id)
    if ok and v then return true end
  end
  return false
end

function A.SpellName(id)
  if C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and n then return n end
  end
  if _G.GetSpellInfo then
    local ok, n = pcall(GetSpellInfo, id)
    if ok and n then return n end
  end
end

-- Parcourt les ameliorations du joueur : fn(nom, spellId, icone, expiration).
-- Renvoie false si une valeur secrete a ete rencontree (lecture incomplete).
function A.ForEachBuff(fn)
  local clean = true
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    for i = 1, 255 do
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
      if not ok or not aura then break end
      if not RU.Safe(aura.name, aura.spellId, aura.icon) then
        clean = false
      elseif fn(aura.name, aura.spellId, aura.icon, aura.expirationTime) then
        break
      end
    end
    return clean
  end
  if _G.UnitBuff then
    for i = 1, 255 do
      local ok, name, icon, _, _, _, expires, _, _, _, spellId = pcall(UnitBuff, "player", i)
      if not ok or not name then break end
      if not RU.Safe(name, icon, spellId) then
        clean = false
      elseif fn(name, spellId, icon, expires) then
        break
      end
    end
  end
  return clean
end

-- Places libres dans les sacs ordinaires (famille 0 : pas les sacs de
-- metier ni le sac de composants).
function A.FreeBagSlots()
  local getFree = (C_Container and C_Container.GetContainerNumFreeSlots) or _G.GetContainerNumFreeSlots
  local getSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
  if not (getFree and getSlots) then return nil end
  local last = _G.NUM_BAG_SLOTS or 4
  local free, total = 0, 0
  for bag = 0, last do
    local ok, n, family = pcall(getFree, bag)
    local ok2, size = pcall(getSlots, bag)
    if ok and ok2 and RU.Safe(n, family, size) and (family == 0 or family == nil) then
      free = free + (tonumber(n) or 0)
      total = total + (tonumber(size) or 0)
    end
  end
  return free, total
end

-- Emplacement des munitions : seulement sur les clients qui en ont un.
function A.AmmoSlot()
  if not _G.GetInventorySlotInfo then return nil end
  local ok, slot = pcall(GetInventorySlotInfo, "AmmoSlot")
  if ok and slot then return slot end
  return nil
end

function A.Spec()
  local fn = _G.GetSpecialization or (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization)
  if not fn then return nil end
  local ok, s = pcall(fn)
  if ok then return s end
end

-- Contexte : "raid", "keystone" (M+ ou mythique), "dungeon" ou "solo".
function A.Context()
  local inInst, iType = false, "none"
  if _G.IsInInstance then
    local ok, a, b = pcall(IsInInstance)
    if ok then inInst, iType = a, b end
  end
  if inInst and iType == "raid" then return "raid" end
  if inInst and (iType == "party" or iType == "scenario") then
    if _G.GetInstanceInfo then
      local ok, _, _, diff = pcall(GetInstanceInfo)
      if ok and (diff == 8 or diff == 23) then return "keystone" end
    end
    return "dungeon"
  end
  if _G.IsInRaid and IsInRaid() then return "raid" end
  return "solo"
end

function A.AtMaxLevel()
  local lvl = UnitLevel("player") or 0
  local max = _G.GetMaxLevelForPlayerExpansion or _G.GetMaxPlayerLevel
  if not max then return true end
  local ok, m = pcall(max)
  if not ok or not m then return true end
  return lvl >= m
end

-- ============================================================================
-- SAUVEGARDE
-- ============================================================================
local DEFAULTS = {
  enabled      = true,
  -- moments ou ReadyUp previent
  onInstance   = true,   -- entree en donjon, raid, gouffre
  onReadyCheck = true,   -- appel « Pret ? » du groupe
  onMerchant   = true,   -- chez un marchand qui repare, si l'usure est basse
  onLogin      = false,
  onSolo       = true,   -- en quete (solo, hors instance) : quand un seuil est franchi
  okOnReady    = true,   -- afficher « Pret » au ready check si tout va bien
  -- controles
  chkDurability = true,
  chkBags       = true,
  chkFood       = true,
  chkFlask      = true,
  chkWeapon     = true,
  chkPet        = true,
  chkAmmo       = true,
  chkReagents   = true,
  consumInDungeons = false,  -- nourriture et flacon aussi en donjon normal / heroique
  weaponForAll     = false,  -- exiger un enchantement d'arme pour toutes les classes
  -- seuils
  durWarn    = 30,   -- pourcentage
  bagWarn    = 4,    -- places libres
  ammoWarn   = 200,
  reagentWarn = 5,
  toastTime  = 12,   -- secondes
  minimapAngle = 215,
}

function RU.InitDB()
  TibiReadyUpDB = type(TibiReadyUpDB) == "table" and TibiReadyUpDB or {}
  for k, v in pairs(DEFAULTS) do
    if TibiReadyUpDB[k] == nil then TibiReadyUpDB[k] = v end
  end
  TibiReadyUpDB.version = 1
end

-- Meme regle que Standby et Anchor : decoche dans TibiSuite = inactif ;
-- table absente (premiere installation ou mode autonome) = actif.
function RU.SuiteDisabled()
  local TS = _G.TibiSuite
  if not (TS and TS.RegisterModule) then return false end
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return false end
  return not TibiSuiteDB.enabledModules[RU.KEY]
end

function RU.IsRunning()
  return TibiReadyUpDB and TibiReadyUpDB.enabled and not RU.SuiteDisabled()
end

-- Prevenir les autres fichiers apres un changement (fenetre, badge, Centre).
RU.listeners = {}
function RU.OnChanged()
  for _, fn in ipairs(RU.listeners) do pcall(fn) end
end
