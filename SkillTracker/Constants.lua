-- ================================================================
--  SkillTracker  -  Constants.lua
--  Couleurs, identite des extensions, et resolution "palier de metier ->
--  index d'extension".
--
--  Patch cible : Interface 120100 (Midnight 12.1) + retro 12.0.x.
--  Fonctions de jeu utilisees par le module :
--    - GetProfessions() / GetProfessionInfo(index)     (grimoire, sans fenetre)
--    - C_TradeSkillUI.GetChildProfessionInfos()        (paliers du metier ouvert)
--    - C_TradeSkillUI.GetAllProfessionTradeSkillLines() + GetProfessionInfoBySkillLineID
--
--  Resolution de l'extension d'un palier (ST.ResolveLineIndexes), dans
--  l'ordre, sans jamais inventer :
--    1) le nom d'extension fourni par le jeu (champ expansionName, ex :
--       "Khaz Algar", "Îles aux Dragons") traduit via ST.EXP_NAME_INDEX
--       (10 langues, comparaison tolerante casse / accents) ;
--    2) un skillLineID deja resolu une fois (table apprise SkillTrackerDB.tierIndex,
--       plus les ID Dragonflight connus ci-dessous) ;
--    3) deduction par rang, marquee "inferred" : les paliers modernes
--       (ID >= 2750 : Shadowlands, Dragonflight, TWW, Midnight...) ont des ID
--       croissants par extension.
--  Le libelle affiche reste toujours le nom fourni par le jeu quand il existe.
-- ================================================================

local _, ST = ...

-- Couleur d'identite du module : Emeraude Monk #00FF98 (RGB 0.0, 1.0, 0.596)
ST.COLOR = { 0.0, 1.0, 0.596 }

-- Nom de la texture du logo (WoW resout .blp/.tga automatiquement, PAS .png)
ST.LOGO = "Interface\\AddOns\\SkillTracker\\media\\Logo"

-- Seuil des paliers "modernes" (Shadowlands et apres) : ID croissants.
ST.MODERN_TIER_ID = 2750
ST.MODERN_FIRST_INDEX = 8   -- Shadowlands

-- skillLineID -> index d'extension, pour les seuls ID surs (Dragonflight).
-- Le reste est appris a l'execution (SkillTrackerDB.tierIndex).
ST.EXP_INDEX = {
  [2823] = 9, [2822] = 9, [2825] = 9, [2827] = 9, [2832] = 9, [2828] = 9,
  [2829] = 9, [2830] = 9, [2833] = 9, [2834] = 9, [2831] = 9, [2824] = 9,
  [2826] = 9,
}

-- ================================================================
-- IDENTITE DES EXTENSIONS (sigles, noms, couleurs), identique a RenTracker
-- ================================================================
ST.EXT_KEY = {
  [0]  = "Vanilla",
  [1]  = "TheBurningCrusade",
  [2]  = "WrathOfTheLichKing",
  [3]  = "Cataclysme",
  [4]  = "MistsOfPandaria",
  [5]  = "WarlordsOfDraenor",
  [6]  = "Legion",
  [7]  = "BattleForAzeroth",
  [8]  = "Shadowlands",
  [9]  = "Dragonflight",
  [10] = "TheWarWithin",
  [11] = "Midnight",
}

ST.EXT_LABELS = {
  Vanilla            = "CLA",
  TheBurningCrusade  = "TBC",
  WrathOfTheLichKing = "WotLK",
  Cataclysme         = "CATA",
  MistsOfPandaria    = "MoP",
  WarlordsOfDraenor  = "WoD",
  Legion             = "LEG",
  BattleForAzeroth   = "BfA",
  Shadowlands        = "SL",
  Dragonflight       = "DF",
  TheWarWithin       = "TWW",
  Midnight           = "MID",
}

ST.EXT_FULLNAMES = {
  Vanilla            = "Classic (1.0)",
  TheBurningCrusade  = "The Burning Crusade (2.0)",
  WrathOfTheLichKing = "Wrath of the Lich King (3.0)",
  Cataclysme         = "Cataclysm (4.0)",
  MistsOfPandaria    = "Mists of Pandaria (5.0)",
  WarlordsOfDraenor  = "Warlords of Draenor (6.0)",
  Legion             = "Legion (7.0)",
  BattleForAzeroth   = "Battle for Azeroth (8.0)",
  Shadowlands        = "Shadowlands (9.0)",
  Dragonflight       = "Dragonflight (10.0)",
  TheWarWithin       = "The War Within (11.0)",
  Midnight           = "Midnight (12.0)",
}

ST.EXT_COLORS = {
  Vanilla            = { r=0.75, g=0.72, b=0.55 },
  TheBurningCrusade  = { r=0.20, g=0.75, b=0.28 },
  WrathOfTheLichKing = { r=0.65, g=0.85, b=1.00 },
  Cataclysme         = { r=0.95, g=0.35, b=0.10 },
  MistsOfPandaria    = { r=0.20, g=0.65, b=0.45 },
  WarlordsOfDraenor  = { r=0.85, g=0.50, b=0.10 },
  Legion             = { r=0.60, g=0.15, b=0.85 },
  BattleForAzeroth   = { r=0.85, g=0.25, b=0.25 },
  Shadowlands        = { r=0.45, g=0.55, b=0.95 },
  Dragonflight       = { r=0.95, g=0.45, b=0.10 },
  TheWarWithin       = { r=0.55, g=0.75, b=0.95 },
  Midnight           = { r=0.58, g=0.30, b=0.95 },
}

-- ================================================================
-- NOM D'EXTENSION (fourni par le jeu) -> INDEX
-- Ce sont surtout des noms de REGION ("Khaz Algar", "Îles aux Dragons").
-- FR/EN confirmes en jeu ; DE/ES/IT/PT/RU a confirmer (un nom absent ne
-- casse rien : on retombe sur l'ID appris puis sur la deduction par rang).
-- ================================================================
ST.EXP_NAME_INDEX = {
  -- 0 Classic
  ["Classic"] = 0, ["Classique"] = 0, ["Vanilla"] = 0, ["Klassisch"] = 0,
  ["Clásico"] = 0, ["Classico"] = 0, ["Clássico"] = 0, ["Классика"] = 0,
  -- 1 The Burning Crusade
  ["Outland"] = 1, ["Outreterre"] = 1, ["Scherbenwelt"] = 1, ["Terrallende"] = 1,
  ["Terre Esterne"] = 1, ["Terralém"] = 1, ["Запределье"] = 1,
  -- 2 Wrath of the Lich King
  ["Northrend"] = 2, ["Norfendre"] = 2, ["Nordend"] = 2, ["Rasganorte"] = 2,
  ["Nordania"] = 2, ["Nortúndria"] = 2, ["Нордскол"] = 2,
  -- 3 Cataclysm
  ["Cataclysm"] = 3, ["Cataclysme"] = 3, ["Kataklysmus"] = 3, ["Cataclisma"] = 3,
  ["Cataclismo"] = 3, ["Катаклизм"] = 3,
  -- 4 Mists of Pandaria
  ["Pandaria"] = 4, ["Pandarie"] = 4, ["Pandária"] = 4, ["Пандария"] = 4,
  -- 5 Warlords of Draenor
  ["Draenor"] = 5, ["Дренор"] = 5,
  -- 6 Legion
  ["Legion"] = 6, ["Légion"] = 6, ["Legión"] = 6, ["Legione"] = 6,
  ["Legião"] = 6, ["Легион"] = 6,
  -- 7 Battle for Azeroth
  ["Zandalar"] = 7, ["Kul Tiras"] = 7, ["Kul Tiran"] = 7, ["Battle for Azeroth"] = 7,
  ["Кул-Тирас"] = 7, ["Зандалар"] = 7,
  -- 8 Shadowlands
  ["Shadowlands"] = 8, ["Ombreterre"] = 8, ["Schattenlande"] = 8,
  ["Tierras Sombrías"] = 8, ["Terretetre"] = 8, ["Terras Sombrias"] = 8,
  ["Темные Земли"] = 8, ["Тёмные Земли"] = 8,
  -- 9 Dragonflight
  ["Dragon Isles"] = 9, ["Îles aux Dragons"] = 9, ["Dragonflight"] = 9,
  ["Dracheninseln"] = 9, ["Islas Dragón"] = 9, ["Isole dei Draghi"] = 9,
  ["Ilhas do Dragão"] = 9, ["Драконьи острова"] = 9,
  -- 10 The War Within
  ["Khaz Algar"] = 10, ["The War Within"] = 10, ["Каз Алгар"] = 10,
  -- 11 Midnight
  ["Midnight"] = 11, ["Medianoche"] = 11, ["Mezzanotte"] = 11,
  ["Meia-noite"] = 11, ["Полночь"] = 11,
}

-- Index normalise construit a la premiere demande (casse / accents ignores).
local normIndex
local function Norm(s)
  local UI = _G.TibiMidnight
  if UI and UI.Normalize then return UI.Normalize(s) end
  return tostring(s):lower()
end

-- Traduit un nom d'extension (fourni par le jeu) en index. nil si inconnu.
function ST.NameToIndex(name)
  if type(name) ~= "string" or name == "" then return nil end
  local idx = ST.EXP_NAME_INDEX[name]
  if idx ~= nil then return idx end
  if not normIndex then
    normIndex = {}
    for k, v in pairs(ST.EXP_NAME_INDEX) do normIndex[Norm(k)] = v end
  end
  return normIndex[Norm(name)]
end

-- Index d'extension courant du client, borne par celui du serveur (un compte
-- qui a precommande l'extension suivante ne doit pas sauter a 12 trop tot).
function ST.CurrentExpIndex()
  local lvl = (GetExpansionLevel and GetExpansionLevel()) or 11
  local srv = GetServerExpansionLevel and GetServerExpansionLevel()
  if type(srv) == "number" and srv < lvl then lvl = srv end
  return lvl
end

-- Renvoie le nom localise d'une extension a partir de son index, ou nil.
function ST.ExpansionNameByIndex(idx)
  if type(idx) ~= "number" then return nil end
  local name = _G["EXPANSION_NAME" .. idx]
  if type(name) == "string" and name ~= "" then return name end
  return nil
end

-- Metadonnees d'un "bucket" d'extension : renvoie sigle, nom complet, couleur.
--   bucket : un index numerique, ou la chaine "other" (paliers non identifies).
function ST.BucketMeta(bucket)
  if bucket == "other" or type(bucket) ~= "number" then
    local w = (ST.L and ST.L.EXPANSION) or "Expansion"
    return "???", w, { 0.55, 0.57, 0.60 }
  end
  local key   = ST.EXT_KEY[bucket]
  local label = (key and ST.EXT_LABELS[key]) or ST.ExpansionNameByIndex(bucket) or tostring(bucket)
  local full  = (key and ST.EXT_FULLNAMES[key]) or ST.ExpansionNameByIndex(bucket) or label
  local c     = (key and ST.EXT_COLORS[key]) or { r = 0.6, g = 0.6, b = 0.6 }
  return label, full, { c.r, c.g, c.b }
end

-- Resout (et stocke dans ln.idx) l'index d'extension de chaque palier d'un
-- metier. learn : table apprise id -> index (SkillTrackerDB.tierIndex), ou nil.
function ST.ResolveLineIndexes(prof, learn)
  if type(prof) ~= "table" or type(prof.lines) ~= "table" then return end
  local unresolved = {}
  for id, ln in pairs(prof.lines) do
    local idx = ST.NameToIndex(ln.exp)
    if idx ~= nil then
      ln.idx, ln.inferred = idx, nil
      if learn then learn[id] = idx end
    else
      idx = ST.EXP_INDEX[id] or (learn and learn[id])
      if idx ~= nil then
        ln.idx, ln.inferred = idx, nil
      else
        ln.idx = nil
        unresolved[#unresolved + 1] = id
      end
    end
  end
  if #unresolved == 0 then return end

  -- Deduction par rang sur les paliers modernes : on range tous les paliers
  -- modernes du metier par ID croissant, a partir de Shadowlands.
  local modern = {}
  for id in pairs(prof.lines) do
    if id >= ST.MODERN_TIER_ID then modern[#modern + 1] = id end
  end
  table.sort(modern)
  local cur = ST.CurrentExpIndex()
  for rank, id in ipairs(modern) do
    local ln = prof.lines[id]
    local guess = ST.MODERN_FIRST_INDEX + rank - 1
    if ln.idx == nil and guess <= cur then
      ln.idx, ln.inferred = guess, true
    end
  end
end

-- Index d'un palier deja resolu (repli : nom du jeu).
function ST.LineIndex(ln)
  if type(ln) ~= "table" then return nil end
  if ln.idx ~= nil then return ln.idx end
  return ST.NameToIndex(ln.exp)
end

-- Libelle d'affichage d'un palier : le nom du jeu s'il existe, sinon le nom
-- localise de l'extension deduite, sinon "Extension".
function ST.LineLabel(ln)
  if type(ln) == "table" and type(ln.exp) == "string" and ln.exp ~= "" then return ln.exp end
  local idx = ST.LineIndex(ln)
  return ST.ExpansionNameByIndex(idx) or ((ST.L and ST.L.EXPANSION) or "Expansion")
end
