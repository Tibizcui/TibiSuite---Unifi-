-- ================================================================
--  SkillTracker  -  Gathering.lua  (7.1.5.45, lot A : sonde + prix)
--  Prepare les prix sur les gisements et herbes (minicarte et monde).
--
--  1. SONDE  /skt probe : note ce que contiennent les infobulles des noeuds
--     de recolte sous le client actuel (texte, proprietaire, valeurs
--     secretes de Midnight, type et GUID des donnees d'infobulle). Rien n'est
--     modifie a l'ecran. Resultat imprime ET garde dans SkillTrackerDB.probe.
--  2. PRIX  ST.Prices : prix au vendeur (GetItemInfo, toujours dispo) et
--     prix de l'hotel des ventes lu dans Auctionator ou TradeSkillMaster
--     s'ils sont installes. Sans eux, l'usager est invite a en installer un.
--  Lecture seule : aucune requete a l'hotel des ventes, aucune ecriture
--  dans les sauvegardes d'Auctionator ou de TSM.
--  NON TESTE EN JEU : a valider par Tibiscui (nouveau fichier : redemarrage
--  complet du client).
-- ================================================================

local _, ST = ...

-- Textes (FR + EN ; les autres langues tombent sur l'anglais : outil de
-- diagnostic et d'information, relu seulement en FR et EN).
local FR = (GetLocale and GetLocale() == "frFR")
local function T(fr, en) return FR and fr or en end

local URL_AUCTIONATOR = "https://www.curseforge.com/wow/addons/auctionator"
local URL_TSM         = "https://www.curseforge.com/wow/addons/tradeskill-master"
ST.PRICE_URLS = { auctionator = URL_AUCTIONATOR, tsm = URL_TSM }

-- ================================================================
-- PRIX
-- ================================================================
ST.Prices = ST.Prices or {}
local Prices = ST.Prices

local function AuctionatorAPI()
  local A = _G.Auctionator
  local v1 = A and A.API and A.API.v1
  if v1 and type(v1.GetAuctionPriceByItemID) == "function" then return v1 end
end
local function TSMAPI()
  local api = _G.TSM_API
  if api and type(api.GetCustomPriceValue) == "function" then return api end
end

-- Addons de prix presents et utilisables : { auctionator = bool, tsm = bool }
function Prices.Providers()
  return { auctionator = AuctionatorAPI() ~= nil, tsm = TSMAPI() ~= nil }
end
function Prices.HasProvider()
  local p = Prices.Providers()
  return p.auctionator or p.tsm
end

-- Prix au vendeur d'un objet (cuivre) ; nil tant que le client ne connait
-- pas encore l'objet (premier appel : le cache se remplit tout seul).
function Prices.Vendor(itemID)
  local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not get then return nil end
  local ok, _, _, _, _, _, _, _, _, _, _, sell = pcall(get, itemID)
  if ok and type(sell) == "number" then return sell end
end

-- Prix de l'hotel des ventes : cuivre, source ("Auctionator" | "TSM"),
-- age en jours (Auctionator seulement). Source choisie : reglage
-- ST.settings.priceSource ("auto" = Auctionator puis TSM).
function Prices.AH(itemID)
  local pref = ST.settings and ST.settings.priceSource or "auto"
  local function fromAuctionator()
    local v1 = AuctionatorAPI()
    if not v1 then return nil end
    local ok, price = pcall(v1.GetAuctionPriceByItemID, "SkillTracker", itemID)
    if ok and type(price) == "number" and price > 0 then
      local age
      if type(v1.GetAuctionAgeByItemID) == "function" then
        local okA, a = pcall(v1.GetAuctionAgeByItemID, "SkillTracker", itemID)
        if okA and type(a) == "number" then age = a end
      end
      return price, "Auctionator", age
    end
  end
  local function fromTSM()
    local api = TSMAPI()
    if not api then return nil end
    for _, src in ipairs({ "dbmarket", "dbminbuyout", "dbrecent" }) do
      local ok, price = pcall(api.GetCustomPriceValue, src, "i:" .. itemID)
      if ok and type(price) == "number" and price > 0 then return price, "TSM" end
    end
  end
  local order
  if pref == "tsm" then order = { fromTSM }
  elseif pref == "auctionator" then order = { fromAuctionator }
  else order = { fromAuctionator, fromTSM } end
  for _, fn in ipairs(order) do
    local p, s, a = fn()
    if p then return p, s, a end
  end
end

-- Message affiche quand aucun addon de prix n'est installe.
function Prices.MissingText()
  return T("Prix de l'hôtel des ventes : installe |cFFFFD100Auctionator|r ou |cFFFFD100TradeSkillMaster (TSM)|r (gratuits, sur CurseForge). Sans eux, seul le prix au vendeur peut être affiché.",
    "Auction House prices: install |cFFFFD100Auctionator|r or |cFFFFD100TradeSkillMaster (TSM)|r (free, on CurseForge). Without them, only the vendor price can be shown.")
end

-- Ligne d'etat lisible des addons de prix (panneau d'options, sonde).
function Prices.StatusText()
  local p = Prices.Providers()
  local ok, no = "|cFF4FD16B", "|cFF8F8C98"
  local a = (p.auctionator and ok or no) .. "Auctionator : " .. (p.auctionator and T("détecté", "detected") or T("absent", "missing")) .. "|r"
  local t = (p.tsm and ok or no) .. "TSM : " .. (p.tsm and T("détecté", "detected") or T("absent", "missing")) .. "|r"
  return a .. "     " .. t
end

local function Money(c)
  if not c then return "-" end
  -- 12.1.5 : C_CurrencyInfo en priorite, le global n'est plus qu'un alias.
  local fn = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or _G.GetCoinTextureString
  if fn then return fn(math.max(0, math.floor(c))) end
  return string.format("%d po %02d pa", math.floor(c / 10000), math.floor(c / 100) % 100)
end
Prices.Money = Money

-- ================================================================
-- SONDE DES INFOBULLES DE RECOLTE
-- ================================================================
local probing = false
local hooked = false
local MAX_ENTRIES = 60

local function Secret(v) return issecretvalue and issecretvalue(v) or false end

local function ProbeDB()
  SkillTrackerDB.probe = SkillTrackerDB.probe or {}
  local p = SkillTrackerDB.probe
  p.entries = p.entries or {}
  return p
end

-- "GameObject-0-3133-2552-12345-503031-0000ABCDEF" -> 503031 (5e champ apres le type)
local function ObjectIDFromGUID(guid)
  if type(guid) ~= "string" or Secret(guid) then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "GameObject" then return tonumber(id) end
end

local function NodeKeyLate(s) return ST.NodeKey and ST.NodeKey(s) end

local function Capture(tt)
  if not probing or not tt or not tt.IsShown or not tt:IsShown() then return end
  -- Unites, objets et sorts ont leurs propres infobulles : on les ignore.
  if tt.GetUnit then local _, u = tt:GetUnit(); if u then return end end
  if tt.GetItem then local _, link = tt:GetItem(); if link then return end end
  local owner = tt.GetOwner and tt:GetOwner()
  local ownerName = owner and owner.GetName and owner:GetName() or nil
  local where = "world"
  if owner == Minimap or (ownerName and ownerName:find("Minimap", 1, true)) then where = "minimap"
  elseif owner and owner ~= UIParent and owner ~= WorldFrame then where = "ui" end
  if where == "ui" then return end
  local lines, secret = {}, false
  for i = 1, math.min(8, tt:NumLines() or 0) do
    local fs = _G[tt:GetName() .. "TextLeft" .. i]
    local txt = fs and fs:GetText()
    if txt ~= nil then
      if Secret(txt) then secret = true; lines[#lines + 1] = "<secret>"
      else lines[#lines + 1] = txt end
    end
  end
  if #lines == 0 then return end
  local dType, guid, objID, dataID, guidState, keys
  if tt.GetTooltipData then
    local ok, data = pcall(tt.GetTooltipData, tt)
    if ok and type(data) == "table" then
      dType = data.type
      if not Secret(data.id) then dataID = data.id end
      if data.guid == nil then guidState = "absent"
      elseif Secret(data.guid) then guidState = "secret"
      else guid = data.guid; guidState = "ok" end
      objID = ObjectIDFromGUID(guid)
      -- Champs fournis par le client (diagnostic : y a-t-il un identifiant ?).
      keys = {}
      for k, v in pairs(data) do
        if type(k) == "string" and k ~= "lines" then
          local shown = (type(v) == "string" or type(v) == "number") and not Secret(v) and tostring(v) or type(v)
          keys[#keys + 1] = k .. "=" .. shown
        end
      end
      table.sort(keys)
    end
  end
  if dType == 21 then where = "minimap" elseif dType == 4 then where = "world" end
  local p = ProbeDB()
  local key = where .. "|" .. (NodeKeyLate(lines[1]) or lines[1] or "")
  for _, e in ipairs(p.entries) do if e.key == key then e.n = (e.n or 1) + 1; return end end
  local e = { key = key, at = time(), where = where, owner = ownerName or (owner == UIParent and "UIParent") or "?",
              lines = lines, secret = secret or nil, dataType = dType, dataID = dataID, guid = guid, objectID = objID, n = 1,
              guidState = guidState, keys = keys,
              zone = GetZoneText and GetZoneText() or nil }
  table.insert(p.entries, e)
  while #p.entries > MAX_ENTRIES do table.remove(p.entries, 1) end
  print(ST.TAG .. " " .. T("Sonde", "Probe") .. " [" .. where .. "] |cFFFFFFFF" .. tostring(lines[1]) .. "|r"
    .. (#lines > 1 and ("  |cFF8F8C98" .. tostring(lines[2]) .. "|r") or "")
    .. (objID and ("  objet " .. objID) or "") .. (dataID and ("  id " .. tostring(dataID)) or "")
    .. (dType and ("  type " .. tostring(dType)) or "") .. (guidState and ("  guid " .. guidState) or "")
    .. (secret and "  |cFFFF9A3C(secret)|r" or ""))
end

local function Hook()
  if hooked or not GameTooltip then return end
  hooked = true
  -- Le texte est pose juste apres l'affichage : lecture a l'image suivante.
  local function later(self)
    if probing then C_Timer.After(0, function() pcall(Capture, self) end) end
  end
  GameTooltip:HookScript("OnShow", later)
  -- L'infobulle de la minicarte change de texte sans se refermer : on suit
  -- aussi SetText, et les donnees d'infobulle quand le client les fournit.
  pcall(hooksecurefunc, GameTooltip, "SetText", later)
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and TooltipDataProcessor.AllTypes then
    pcall(TooltipDataProcessor.AddTooltipPostCall, TooltipDataProcessor.AllTypes, function(tt)
      if tt == GameTooltip then later(tt) end
    end)
  end
end

function ST.ProbeStart()
  Hook()
  probing = true
  local p = ProbeDB()
  p.at = time()
  p.build = select(4, GetBuildInfo())
  p.locale = GetLocale and GetLocale()
  print(ST.TAG .. " " .. T("Sonde des récoltes ACTIVE : survole des gisements et des plantes, sur la minicarte puis dans le monde. |cFFFFD100/skt probe|r pour arrêter, |cFFFFD100/skt probe report|r pour le bilan.",
    "Gathering probe ON: hover ore and herb nodes, on the minimap then in the world. |cFFFFD100/skt probe|r to stop, |cFFFFD100/skt probe report|r for the summary."))
end

function ST.ProbeStop()
  probing = false
  print(ST.TAG .. " " .. T("Sonde arrêtée. Résultat gardé dans SkillTrackerDB.probe (fichier écrit au /reload).",
    "Probe stopped. Result kept in SkillTrackerDB.probe (file written on /reload)."))
end

-- Bilan : addons de prix, essai de lecture d'un prix, infobulles notees.
function ST.ProbeReport()
  local p = ProbeDB()
  print(ST.TAG .. " " .. T("Bilan de la sonde des récoltes", "Gathering probe summary"))
  print("  " .. Prices.StatusText())
  if not Prices.HasProvider() then print("  " .. Prices.MissingText()) end
  -- Essai sur le minerai de cuivre (2770), connu de tous les clients.
  local vendor = Prices.Vendor(2770)
  if not vendor and C_Item and C_Item.RequestLoadItemDataByID then
    -- Objet pas encore en cache : on le demande, il sera la au prochain bilan.
    pcall(C_Item.RequestLoadItemDataByID, 2770)
  end
  local ah, src, age = Prices.AH(2770)
  p.priceTest = { item = 2770, vendor = vendor, ah = ah, source = src, age = age, at = time() }
  print("  " .. T("Essai (minerai de cuivre) : vendeur ", "Test (copper ore): vendor ") .. Money(vendor)
    .. T(", hôtel des ventes ", ", Auction House ") .. (ah and (Money(ah) .. " (" .. src .. (age and (", " .. age .. T(" j", " d")) or "") .. ")") or "-"))
  local mm, w, sec, guid = 0, 0, 0, 0
  for _, e in ipairs(p.entries) do
    if e.where == "minimap" then mm = mm + 1 else w = w + 1 end
    if e.secret then sec = sec + 1 end
    if e.objectID then guid = guid + 1 end
  end
  print("  " .. string.format(T("Infobulles notées : %d minicarte, %d monde, %d avec identifiant d'objet, %d avec texte secret.",
    "Tooltips recorded: %d minimap, %d world, %d with an object ID, %d with secret text."), mm, w, guid, sec))
  for i = math.max(1, #p.entries - 7), #p.entries do
    local e = p.entries[i]
    print("   - [" .. e.where .. "] " .. tostring(e.lines[1]) .. (e.objectID and ("  #" .. e.objectID) or "")
      .. (e.dataType and ("  type " .. tostring(e.dataType)) or "") .. (e.dataID and ("  id " .. tostring(e.dataID)) or "")
      .. (e.guidState and ("  guid " .. e.guidState) or ""))
    if e.keys and #e.keys > 0 then print("       |cFF8F8C98" .. table.concat(e.keys, "  ") .. "|r") end
  end
end

function ST.ProbeClear()
  SkillTrackerDB.probe = nil
  print(ST.TAG .. " " .. T("Sonde effacée.", "Probe cleared."))
end

function ST.ProbeCommand(arg)
  arg = arg or ""
  if arg == "report" or arg == "bilan" then ST.ProbeReport()
  elseif arg == "clear" or arg == "effacer" then ST.ProbeClear()
  elseif probing then ST.ProbeStop() else ST.ProbeStart() end
end

-- ================================================================
-- LOT B : PRIX DANS L'INFOBULLE DES NOEUDS (minicarte et monde)
-- ----------------------------------------------------------------
-- La sonde (2026-10-11) a montre que le client ne donne AUCUN identifiant
-- pour un noeud : seulement son nom. Type 21 = survol de la minicarte (le
-- texte peut lister plusieurs noeuds), type 4 = objet du monde (2e ligne =
-- metier requis). On reconnait donc les noeuds par leur nom :
--   1. une petite table de depart (FR + EN), limitee aux noms surs ;
--   2. l'apprentissage : a chaque recolte, le nom du noeud (cible de
--      l'incantation) et les objets de metier ramasses sont retenus, dans
--      toutes les langues et pour toutes les extensions.
--      SkillTrackerDB.nodes[langue][nom normalise] = { items = { [id] = n },
--      n = recoltes, at = derniere fois }. L'appris passe devant la table.
-- ================================================================
local TYPE_OBJECT = (Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object) or 4
local TYPE_MINIMAP = (Enum and Enum.TooltipDataType and Enum.TooltipDataType.MinimapMouseover) or 21

-- Nom affiche -> cle : sans codes de couleur, d'icone ni d'atlas, minuscules,
-- apostrophe typographique ramenee a l'apostrophe simple.
local function NodeKey(s)
  if type(s) ~= "string" or Secret(s) then return nil end
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
  s = s:gsub("\226\128\153", "'"):gsub("^%s+", ""):gsub("%s+$", "")
  if s == "" then return nil end
  return s:lower()
end
ST.NodeKey = NodeKey

-- Table de depart : noms verifies en jeu (sonde) ou classiques surs.
-- Une erreur ici est corrigee par la premiere recolte (l'appris gagne).
local SEED = {
  -- Minerais
  ["copper vein"] = { 2770 }, ["filon de cuivre"] = { 2770 },
  ["tin vein"] = { 2771 }, ["filon d'étain"] = { 2771 },
  ["iron deposit"] = { 2772 }, ["gisement de fer"] = { 2772 },
  ["silver vein"] = { 2775 }, ["gold vein"] = { 2776 },
  ["mithril deposit"] = { 3858 }, ["gisement de mithril"] = { 3858 },
  ["truesilver deposit"] = { 7911 },
  ["small thorium vein"] = { 10620 }, ["rich thorium vein"] = { 10620 },
  -- Plantes
  ["peacebloom"] = { 2447 }, ["pacifique"] = { 2447 },
  ["silverleaf"] = { 765 }, ["feuillargent"] = { 765 },
  ["earthroot"] = { 2449 }, ["terrestrine"] = { 2449 },
  ["mageroyal"] = { 785 }, ["mage royal"] = { 785 },
  ["briarthorn"] = { 2450 }, ["bruiseweed"] = { 2453 },
  ["grave moss"] = { 3369 }, ["tombeline"] = { 3369 },
}

local function Learned()
  SkillTrackerDB.nodes = SkillTrackerDB.nodes or {}
  local loc = (GetLocale and GetLocale()) or "enUS"
  SkillTrackerDB.nodes[loc] = SkillTrackerDB.nodes[loc] or {}
  return SkillTrackerDB.nodes[loc]
end

-- Objets d'un noeud, du plus frequent au moins frequent (2 au plus).
function ST.NodeItems(name)
  local key = NodeKey(name)
  if not key then return nil end
  local rec = Learned()[key]
  if rec and rec.items and next(rec.items) then
    local list = {}
    for id, n in pairs(rec.items) do list[#list + 1] = { id = tonumber(id), n = n } end
    table.sort(list, function(a, b) return a.n > b.n end)
    local out = {}
    for i = 1, math.min(2, #list) do out[i] = list[i].id end
    return out, "learned"
  end
  if SEED[key] then return SEED[key], "seed" end
end

function ST.ForgetNodes()
  if SkillTrackerDB.nodes then SkillTrackerDB.nodes[(GetLocale and GetLocale()) or "enUS"] = nil end
end

function ST.LearnedNodeCount()
  local n = 0
  for _ in pairs(Learned()) do n = n + 1 end
  return n
end

-- ── Apprentissage a la recolte ────────────────────────────────────
local pending          -- { name, t } : cible de la derniere incantation
local function IsTradeGood(itemID)
  local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if not getInstant then return false end
  local ok, _, _, _, _, _, classID, subID = pcall(getInstant, itemID)
  -- 7 = Marchandises, et seulement ce qui sort d'un gisement ou d'une plante :
  -- 4 joaillerie (gemmes), 7 metal et pierre, 9 plantes, 10 elements. Le
  -- tissu (5) ou les cuirs (6) ramasses juste apres une incantation viennent
  -- d'ailleurs (coffre, objet) et ne comptent pas (constate en jeu).
  local GATHER_SUB = { [4] = true, [7] = true, [9] = true, [10] = true }
  return ok and classID == 7 and (subID == nil or GATHER_SUB[subID] == true)
end

local learnFrame = CreateFrame("Frame")
learnFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
learnFrame:RegisterEvent("LOOT_READY")
local FarmRecord   -- defini plus bas (session de recolte)
learnFrame:SetScript("OnEvent", function(_, event, a1, a2)
  if not ST.settings then return end
  local learnOn = ST.settings.priceLearn ~= false
  local farmOn = ST.settings.farm ~= false
  if not (learnOn or farmOn) then return end
  if event == "UNIT_SPELLCAST_SENT" then
    if a1 == "player" and type(a2) == "string" and a2 ~= "" and not Secret(a2) then
      pending = { name = a2, t = GetTime() }
    end
    return
  end
  -- LOOT_READY : seulement juste apres une incantation sur une cible nommee,
  -- et seulement le butin venu d'un objet du monde (pas d'une creature).
  if not pending or GetTime() - pending.t > 10 then return end
  local key = NodeKey(pending.name)
  pending = nil
  if not key or not GetNumLootItems then return end
  local found, qty = {}, {}
  for slot = 1, GetNumLootItems() do
    local link = GetLootSlotLink and GetLootSlotLink(slot)
    local fromObject = false
    if GetLootSourceInfo then
      local guid = GetLootSourceInfo(slot)
      fromObject = type(guid) == "string" and not Secret(guid) and guid:find("^GameObject") ~= nil
    end
    local id = link and not Secret(link) and tonumber(link:match("item:(%d+)"))
    if id and fromObject and IsTradeGood(id) then
      found[id] = true
      local q = GetLootSlotInfo and select(3, GetLootSlotInfo(slot))
      q = (type(q) == "number" and not Secret(q)) and q or 1
      qty[id] = (qty[id] or 0) + math.max(1, q)
    end
  end
  if not next(found) then return end
  if farmOn and FarmRecord then pcall(FarmRecord, qty) end
  if not learnOn then return end
  local L = Learned()
  local rec = L[key] or { items = {}, n = 0 }
  rec.n = (rec.n or 0) + 1
  rec.at = time()
  for id in pairs(found) do rec.items[id] = (rec.items[id] or 0) + 1 end
  L[key] = rec
end)

-- ================================================================
-- SESSION DE RECOLTE (7.1.5.45, feuille de route lot 1)
-- ----------------------------------------------------------------
-- Demarre a la premiere recolte (ou /skt farm), se termine apres 10 min
-- sans recolte (ou /skt farm). Meme source que l'apprentissage : butin d'un
-- objet du monde juste apres une incantation de recolte, objets de metier.
--   SkillTrackerDB.farm = { cur = session, sessions = { 20 dernieres },
--                           total = { [itemID] = quantite depuis toujours } }
--   session = { start, last, nodes, items = { [id] = qte }, zones = { [nom] = noeuds } }
-- La valeur est calculee a l'affichage (prix du moment : Auctionator ou
-- TSM, sinon vendeur), jamais figee.
-- ================================================================
local FARM_IDLE = 600
local MAX_SESSIONS = 20

local function FarmDB()
  SkillTrackerDB.farm = SkillTrackerDB.farm or {}
  local f = SkillTrackerDB.farm
  f.sessions = f.sessions or {}
  f.total = f.total or {}
  return f
end
ST.FarmDB = FarmDB

-- Prix unitaire retenu pour un objet : HV si connu, sinon vendeur.
function ST.UnitPrice(id)
  local ah, src = Prices.AH(id)
  if ah then return ah, src end
  local v = Prices.Vendor(id)
  if v and v > 0 then return v, "vendor" end
  return 0, nil
end

-- Valeur d'une table { [id] = qte } : cuivre total.
function ST.ItemsValue(items)
  local total = 0
  for id, q in pairs(items or {}) do total = total + (ST.UnitPrice(tonumber(id)) or 0) * q end
  return total
end

local function TopZone(s)
  local best, bn
  for z, n in pairs(s.zones or {}) do if not bn or n > bn then best, bn = z, n end end
  return best
end
ST.FarmTopZone = TopZone

function ST.FarmActive()
  local f = FarmDB().cur
  if f and time() - (f.last or 0) <= FARM_IDLE then return f end
end

-- Duree utile d'une session (au moins une minute, pour le po/h).
function ST.FarmDuration(s)
  return math.max(60, (s.last or s.start) - s.start)
end

-- Rythme en po/h, seulement apres 5 minutes (avant, l'extrapolation trompe).
function ST.FarmRate(s, value)
  local dur = (s.last or s.start) - s.start
  if dur < 300 then return nil end
  return (value or ST.ItemsValue(s.items)) / dur * 3600
end

local function FarmClose(quiet)
  local db = FarmDB()
  local s = db.cur
  db.cur = nil
  if not s or (s.nodes or 0) == 0 then return end
  s.zone = TopZone(s)
  table.insert(db.sessions, 1, s)
  while #db.sessions > MAX_SESSIONS do table.remove(db.sessions) end
  if not quiet and _G.TibiSuite and TibiSuite.Notify then
    local v = ST.ItemsValue(s.items)
    TibiSuite.Notify("Skill", string.format(T("Session de récolte terminée : %d nœuds, %s en %s.",
      "Gathering session ended: %d nodes, %s in %s."), s.nodes, Prices.Money(v), ST.FormatDuration(ST.FarmDuration(s))),
      { sound = false })
  end
  if ST.RefreshUI then ST.RefreshUI() end
end
ST.FarmClose = FarmClose

function FarmRecord(qty)
  local db = FarmDB()
  local now = time()
  if db.cur and now - (db.cur.last or 0) > FARM_IDLE then FarmClose() end
  if not db.cur then db.cur = { start = now, last = now, nodes = 0, items = {}, zones = {} } end
  local s = db.cur
  s.nodes = (s.nodes or 0) + 1
  s.last = now
  local zone = GetZoneText and GetZoneText()
  if zone and zone ~= "" then s.zones[zone] = (s.zones[zone] or 0) + 1 end
  for id, q in pairs(qty) do
    s.items[id] = (s.items[id] or 0) + q
    db.total[id] = (db.total[id] or 0) + q
  end
  if _G.TibiSuite and TibiSuite.RefreshStatus then TibiSuite.RefreshStatus() end
  if ST.RefreshUI then ST.RefreshUI() end
end

-- /skt farm : demarre une session vide, ou termine la session en cours.
function ST.FarmToggle()
  local db = FarmDB()
  if ST.FarmActive() then FarmClose()
  else
    if db.cur then FarmClose(true) end
    local now = time()
    db.cur = { start = now, last = now, nodes = 0, items = {}, zones = {} }
    print(ST.TAG .. " " .. T("Session de récolte démarrée.", "Gathering session started."))
    if ST.RefreshUI then ST.RefreshUI() end
  end
end

function ST.FarmResetTotal()
  FarmDB().total = {}
  if ST.RefreshUI then ST.RefreshUI() end
end

-- Quantite recoltee depuis `since` (horodatage), d'un objet (itemID) ou de
-- tout (nil). Lu par les objectifs de TibiSuite. Une session est comptee
-- entiere si elle a commence apres `since`.
function SkillTracker_GatheredSince(since, itemID)
  local db = FarmDB()
  local n = 0
  local function add(items)
    for id, q in pairs(items or {}) do
      if not itemID or tonumber(id) == itemID then n = n + q end
    end
  end
  for _, s in ipairs(db.sessions) do if (s.start or 0) >= (since or 0) then add(s.items) end end
  if db.cur and (db.cur.start or 0) >= (since or 0) then add(db.cur.items) end
  return n
end

-- Nettoyage : retire ce qui n'est pas une vraie recolte (tissu, poudres
-- d'enchanteur...) compte par les premieres versions, du cumul, des sessions
-- et des noeuds appris. Sans risque : relance a chaque connexion.
ST.IsGatherItem = IsTradeGood
function ST.FarmCleanup()
  local function clean(t)
    for id in pairs(t or {}) do
      local n = tonumber(id)
      if n and not IsTradeGood(n) then t[id] = nil end
    end
  end
  local db = FarmDB()
  clean(db.total)
  if db.cur then clean(db.cur.items) end
  for _, s in ipairs(db.sessions) do clean(s.items) end
  for _, byLoc in pairs(SkillTrackerDB.nodes or {}) do
    for key, rec in pairs(byLoc) do
      clean(rec.items)
      if not next(rec.items or {}) then byLoc[key] = nil end
    end
  end
end

-- Fin automatique apres 10 min d'inactivite (et session perimee au login).
local farmFrame = CreateFrame("Frame")
farmFrame:RegisterEvent("PLAYER_LOGIN")
farmFrame:SetScript("OnEvent", function()
  C_Timer.After(5, function()
    pcall(ST.FarmCleanup)
    local db = FarmDB()
    if db.cur and time() - (db.cur.last or 0) > FARM_IDLE then FarmClose(true) end
  end)
  C_Timer.NewTicker(30, function()
    local db = SkillTrackerDB and SkillTrackerDB.farm
    if db and db.cur and time() - (db.cur.last or 0) > FARM_IDLE then FarmClose() end
  end)
end)

-- Textes de la vue Recolte (UI.lua).
ST.FarmText = {
  view = T("Récolte", "Gathering"),
  scopeCur = T("Session", "Session"), scopeHist = T("Historique", "History"), scopeAll = T("Cumul", "All time"),
  sortName = T("Objet", "Item"), sortQty = T("Quantité", "Quantity"), sortValue = T("Valeur", "Value"), sortExt = T("Extension", "Expansion"),
  sortBy = T("Trier par :", "Sort by:"), extFilter = T("Filtrer par extension :", "Filter by expansion:"),
  active = T("Session en cours", "Session in progress"),
  idle = T("Aucune session en cours : elle démarre toute seule à ta première récolte.", "No session in progress: it starts on its own with your first harvest."),
  start = T("Démarrer une session", "Start a session"), stop = T("Terminer la session", "End the session"),
  statsFmt = T("%d nœuds  ·  %s  ·  %s / h", "%d nodes  ·  %s  ·  %s / h"),
  totalFmt = T("%d objets  ·  valeur %s", "%d items  ·  value %s"),
  totalCap = T("VALEUR TOTALE", "TOTAL VALUE"),
  countFmt = T("|cFFFFFFFF%d|r objets  ·  |cFFFFFFFF%d|r sortes", "|cFFFFFFFF%d|r items  ·  |cFFFFFFFF%d|r kinds"),
  each = T("l'unité", "each"),
  none = T("Rien de récolté pour l'instant.", "Nothing gathered yet."),
  noHist = T("Aucune session terminée.", "No finished session."),
  back = T("< Retour à l'historique", "< Back to history"),
  reset = T("Remettre le cumul à zéro", "Reset the all-time total"),
  priceNote = T("Valeur au prix du moment : hôtel des ventes (Auctionator ou TSM), sinon vendeur.", "Value at current prices: Auction House (Auctionator or TSM), otherwise vendor."),
  unitFmt = T("Prix à l'unité : %s (%s)", "Unit price: %s (%s)"),
  vendor = T("vendeur", "vendor"),
  slash = T("démarrer / terminer une session de récolte", "start / end a gathering session"),
  opt = T("Suivre les sessions de récolte", "Track gathering sessions"),
}
if ST.L then ST.L.METIER_VIEW_FARM = ST.FarmText.view end

-- ================================================================
-- VALEUR DES SACS ET DES BANQUES (7.1.5.45, feuille de route lot 2)
-- ----------------------------------------------------------------
-- Releve par personnage : sacs (a chaque changement, regroupe a 2 s) et
-- banque (seulement banque ouverte : le client ne la donne pas ailleurs).
-- Banque de bataillon : commune au compte, relevee a son ouverture.
--   SkillTrackerDB.wealth = { chars = { ["Nom-Royaume"] = { class, bags =
--     { at, items, bound }, bank = { at, items, bound } } }, warband = { at, items, bound } }
--   items / bound = { [itemID] = quantite } (objets lies : prix vendeur seul).
-- Valeur calculee a l'affichage, au prix du moment.
-- ================================================================
local function WealthDB()
  SkillTrackerDB.wealth = SkillTrackerDB.wealth or {}
  local w = SkillTrackerDB.wealth
  w.chars = w.chars or {}
  return w
end
ST.WealthDB = WealthDB

local function MyKey()
  -- Attention : « x and f() » ne garde que la 1re valeur de f().
  if not ST.CurrentCharKey then return nil end
  local realm, name = ST.CurrentCharKey()
  if not name then return nil end
  return name .. "-" .. tostring(realm or "")
end

-- Index des sacs, selon ce que le client expose (12.x : onglets de banque).
local function BagRange(kind)
  local out = {}
  local B = Enum and Enum.BagIndex
  if kind == "bags" then
    for i = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) do out[#out + 1] = i end
  elseif kind == "bank" then
    if B and B.CharacterBankTab_1 then
      for i = 1, 6 do local v = B["CharacterBankTab_" .. i]; if v then out[#out + 1] = v end end
    else
      out[#out + 1] = BANK_CONTAINER or -1
      local first = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) + 1
      for i = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do out[#out + 1] = i end
      if REAGENTBANK_CONTAINER then out[#out + 1] = REAGENTBANK_CONTAINER end
    end
  elseif kind == "warband" then
    if B and B.AccountBankTab_1 then
      for i = 1, 5 do local v = B["AccountBankTab_" .. i]; if v then out[#out + 1] = v end end
    end
  end
  return out
end

local function ScanBags(list)
  local C = C_Container
  if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return nil end
  local items, bound, any = {}, {}, false
  for _, bag in ipairs(list) do
    local ok, n = pcall(C.GetContainerNumSlots, bag)
    if ok and type(n) == "number" and n > 0 then
      any = true
      for slot = 1, n do
        local okI, info = pcall(C.GetContainerItemInfo, bag, slot)
        if okI and type(info) == "table" and info.itemID and not Secret(info.itemID) then
          local t = info.isBound and bound or items
          t[info.itemID] = (t[info.itemID] or 0) + (info.stackCount or 1)
        end
      end
    end
  end
  if not any then return nil end
  return { at = time(), items = items, bound = bound }
end

function ST.WealthScan(kind)
  local w = WealthDB()
  local snap = ScanBags(BagRange(kind))
  if not snap then return end
  if kind == "warband" then w.warband = snap; return end
  local key = MyKey()
  if not key then return end
  local c = w.chars[key] or {}
  local _, class = UnitClass("player")
  c.class = class or c.class
  c[kind] = snap
  w.chars[key] = c
end

-- Valeur d'un releve : vendable (HV sinon vendeur) + lie (vendeur).
function ST.SnapValue(snap)
  if not snap then return 0 end
  local v = ST.ItemsValue(snap.items)
  for id, q in pairs(snap.bound or {}) do v = v + (Prices.Vendor(id) or 0) * q end
  return v
end

-- Objets les plus precieux du compte (vendables seulement) : { {id, q, value} }.
function ST.WealthTop(n)
  local w = WealthDB()
  local sum = {}
  local function add(snap) for id, q in pairs(snap and snap.items or {}) do sum[id] = (sum[id] or 0) + q end end
  for _, c in pairs(w.chars) do add(c.bags); add(c.bank) end
  add(w.warband)
  local list = {}
  for id, q in pairs(sum) do
    local unit = ST.UnitPrice(id)
    if unit and unit > 0 then list[#list + 1] = { id = id, q = q, value = unit * q } end
  end
  table.sort(list, function(a, b) return a.value > b.value end)
  while #list > (n or 10) do table.remove(list) end
  return list
end

local bankOpen = false
local pendingBags = false
local wealthFrame = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
  "PLAYERBANKSLOTS_CHANGED", "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" }) do
  pcall(wealthFrame.RegisterEvent, wealthFrame, e)
end
wealthFrame:SetScript("OnEvent", function(_, event)
  if not (ST.settings and ST.settings.wealth ~= false) then return end
  if event == "BANKFRAME_OPENED" then
    bankOpen = true
    C_Timer.After(0.5, function() pcall(ST.WealthScan, "bank"); pcall(ST.WealthScan, "warband") end)
    return
  elseif event == "BANKFRAME_CLOSED" then
    bankOpen = false
    return
  end
  if pendingBags then return end
  pendingBags = true
  C_Timer.After((event == "PLAYER_LOGIN") and 5 or 2, function()
    pendingBags = false
    pcall(ST.WealthScan, "bags")
    if bankOpen then pcall(ST.WealthScan, "bank"); pcall(ST.WealthScan, "warband") end
  end)
end)

ST.WealthText = {
  view = T("Valeur", "Value"),
  account = T("Valeur du compte", "Account value"),
  bags = T("sacs", "bags"), bank = T("banque", "bank"), warband = T("Banque de bataillon", "Warband bank"),
  never = T("banque jamais ouverte", "bank never opened"),
  seenFmt = T("relevé %s", "read %s"),
  top = T("Les objets qui valent le plus", "Most valuable items"),
  none = T("Aucun relevé pour l'instant : il se fait tout seul à la connexion et à chaque ouverture de banque.", "No reading yet: it happens on its own at login and every time you open a bank."),
  note = T("Sacs relevés à chaque changement, banques à leur ouverture. Objets vendables au prix de l'hôtel des ventes (sinon vendeur), objets liés au prix vendeur.", "Bags read on every change, banks when opened. Tradable items at Auction House price (otherwise vendor), bound items at vendor price."),
  opt = T("Relever la valeur des sacs et des banques", "Track the value of bags and banks"),
  agoFmt = T("il y a %s", "%s ago"),
}
if ST.L then ST.L.METIER_VIEW_WEALTH = ST.WealthText.view end

-- ── Lignes ajoutees a l'infobulle ─────────────────────────────────
local function ItemName(id)
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  if not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  local q = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
  local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  return name or ("#" .. id), c and c.r or 1, c and c.g or 1, c and c.b or 1
end

local function AddItemLines(tt, id)
  local name, r, g, b = ItemName(id)
  local ah, src, age = Prices.AH(id)
  local vendor = Prices.Vendor(id)
  tt:AddDoubleLine("  " .. name, ah and Money(ah) or (vendor and Money(vendor)) or "-", r, g, b, 1, 1, 1)
  local info
  if ah then
    info = T("    hôtel des ventes", "    auction house") .. " (" .. src .. (age and (", " .. string.format(T("%d j", "%d d"), age)) or "") .. ")"
      .. (vendor and ("  ·  " .. T("vendeur ", "vendor ") .. Money(vendor)) or "")
  elseif vendor then
    info = T("    vendeur", "    vendor")
  end
  if info then tt:AddLine(info, 0.56, 0.55, 0.60) end
end

local function Augment(tt, data)
  if not (tt and data and ST.settings) then return end
  local t = data.type
  if t == TYPE_MINIMAP and ST.settings.priceMinimap == false then return end
  if t == TYPE_OBJECT and ST.settings.priceWorld == false then return end
  if t ~= TYPE_MINIMAP and t ~= TYPE_OBJECT then return end
  -- Noms candidats : la 1re ligne pour un objet du monde ; toutes les lignes
  -- (et chaque ligne coupee aux retours) pour la minicarte.
  local names = {}
  local maxLines = (t == TYPE_OBJECT) and 1 or math.min(10, tt:NumLines() or 0)
  for i = 1, maxLines do
    local fs = _G[tt:GetName() .. "TextLeft" .. i]
    local txt = fs and fs:GetText()
    if type(txt) == "string" and not Secret(txt) then
      for part in (txt .. "\n"):gmatch("(.-)\n") do
        if part ~= "" then names[#names + 1] = part end
      end
    end
  end
  local shown, unknownGather = 0, false
  local multi = #names > 1
  for _, nm in ipairs(names) do
    local items = ST.NodeItems(nm)
    if items then
      if shown == 0 then tt:AddLine(" ") end
      if multi then tt:AddLine((nm:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), 0.85, 0.85, 0.88) end
      for _, id in ipairs(items) do AddItemLines(tt, id) end
      shown = shown + 1
    end
  end
  -- Objet du monde inconnu mais qui demande un metier de recolte du perso :
  -- on annonce que le prix sera appris.
  if shown == 0 and t == TYPE_OBJECT and ST.settings.priceLearn ~= false then
    local fs2 = _G[tt:GetName() .. "TextLeft2"]
    local l2 = fs2 and fs2:GetText()
    if type(l2) == "string" and not Secret(l2) and GetProfessions and GetProfessionInfo then
      local p1, p2 = GetProfessions()
      for _, idx in ipairs({ p1, p2 }) do
        local pname = idx and GetProfessionInfo(idx)
        if pname and l2:find(pname, 1, true) then unknownGather = true end
      end
    end
    if unknownGather then
      tt:AddLine(" ")
      tt:AddLine(T("Prix appris à la première récolte de ce nœud.", "Price learned on your first harvest of this node."), 0.56, 0.55, 0.60, true)
      shown = 1
    end
  end
  if shown > 0 then
    if not Prices.HasProvider() then
      tt:AddLine(T("Prix HV : installe Auctionator ou TSM.", "AH price: install Auctionator or TSM."), 1, 0.82, 0)
    end
    tt:Show()
  end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
  for _, ty in ipairs({ TYPE_OBJECT, TYPE_MINIMAP }) do
    pcall(TooltipDataProcessor.AddTooltipPostCall, ty, function(tt, data)
      if tt == GameTooltip then pcall(Augment, tt, data) end
    end)
  end
end
ST._GatherAugment = Augment   -- pour les tests

-- Textes du panneau d'options (UI.lua).
ST.GatherText = {
  section = T("Prix des récoltes", "Gathering prices"),
  note = T("Le prix au vendeur et à l'hôtel des ventes (à l'unité) dans l'infobulle des gisements et des plantes, sur la minicarte et dans le monde. Le jeu ne donne que le nom du nœud : SkillTracker retient ce que chaque nœud donne à ta première récolte, dans toutes les langues.",
    "Vendor and Auction House prices (per unit) in ore and herb tooltips, on the minimap and in the world. The game only gives the node's name: SkillTracker remembers what each node gives on your first harvest, in every language."),
  minimap = T("Prix sur les nœuds de la minicarte", "Prices on minimap nodes"),
  world = T("Prix sur les nœuds dans le monde", "Prices on nodes in the world"),
  learn = T("Apprendre ce que donne chaque nœud à la récolte", "Learn what each node gives when harvesting"),
  forget = T("Oublier les nœuds appris", "Forget learned nodes"),
  forgot = T("Nœuds appris oubliés.", "Learned nodes forgotten."),
  learnedFmt = T("%d nœud(s) appris dans cette langue.", "%d node(s) learned in this language."),
  sourceAuto = T("Source : automatique (Auctionator puis TSM)", "Source: automatic (Auctionator then TSM)"),
  sourceAuc = T("Source : Auctionator seulement", "Source: Auctionator only"),
  sourceTSM = T("Source : TSM seulement", "Source: TSM only"),
  probe = T("Lancer / arrêter la sonde des récoltes", "Start / stop the gathering probe"),
  report = T("Bilan de la sonde", "Probe summary"),
  urlAuc = T("Auctionator sur CurseForge", "Auctionator on CurseForge"),
  urlTSM = T("TradeSkillMaster sur CurseForge", "TradeSkillMaster on CurseForge"),
  slash = T("sonde des infobulles de récolte (report : bilan)", "gathering tooltip probe (report: summary)"),
}
