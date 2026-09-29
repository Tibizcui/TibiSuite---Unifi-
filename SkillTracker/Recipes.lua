-- ================================================================
--  SkillTracker  -  Recipes.lua
--  « Qui sait crafter ça ? » : recettes apprises par chaque personnage,
--  recherche (vue Recettes, loupe de la suite, /skt recipe) et ligne
--  « Tes personnages savent le fabriquer » dans l'info-bulle des objets.
--
--  Releve : UNIQUEMENT quand le joueur ouvre SON propre metier (jamais un
--  metier en lien, de guilde ou d'un PNJ). Lecture en paquets de 150
--  recettes par image pour ne pas figer le jeu. Par defaut, seules les
--  recettes de l'extension en cours sont gardees (option : toutes).
--
--  Stockage :
--    SkillTrackerDB.recipeCache[recipeID] = { n = nom, i = icone, o = objet produit, p = metier, t = palier }
--    rec.recipes[metier] = { ids = { [recipeID] = true }, t = date }
--  Le releve fusionne PAR PALIER : si le jeu ne renvoie que les recettes du
--  palier affiche, les recettes des autres paliers deja connues sont gardees.
-- ================================================================

local _, ST = ...
local L = ST.L

local BATCH = 150

-- ================================================================
-- INDEX (construit a la demande, invalide a chaque releve)
-- ================================================================
local ownersByRecipe, recipesByItem

function ST.InvalidateRecipeIndex()
  ownersByRecipe, recipesByItem = nil, nil
end

local function BuildIndex()
  ownersByRecipe, recipesByItem = {}, {}
  if not ST.db then return end
  local curRealm, curName = ST.CurrentCharKey()
  local cache = ST.db.recipeCache or {}
  for realm, list in pairs(ST.db.chars) do
    for name, rec in pairs(list) do
      for parent, r in pairs(type(rec) == "table" and rec.recipes or {}) do
        local prof = rec.professions and rec.professions[parent]
        local owner = {
          name = name, realm = realm, class = rec.class,
          prof = (prof and prof.name) or "?",
          current = (realm == curRealm and name == curName),
        }
        for id in pairs(r.ids or {}) do
          local o = ownersByRecipe[id]
          if not o then o = {}; ownersByRecipe[id] = o end
          o[#o + 1] = owner
          local c = cache[id]
          if c and c.o then
            local l = recipesByItem[c.o]
            if not l then l = {}; recipesByItem[c.o] = l end
            l[#l + 1] = id
          end
        end
      end
    end
  end
  -- Perso connecte en tete, puis ordre alphabetique.
  for _, o in pairs(ownersByRecipe) do
    table.sort(o, function(a, b)
      if a.current ~= b.current then return a.current end
      return a.name < b.name
    end)
  end
end

function ST.RecipeOwners(id)
  if not ownersByRecipe then BuildIndex() end
  return ownersByRecipe[id]
end

-- Proprietaires (sans doublon) des recettes qui produisent un objet.
function ST.OwnersForItem(itemID)
  if not recipesByItem then BuildIndex() end
  local ids = recipesByItem[itemID]
  if not ids then return nil end
  local seen, out = {}, {}
  for _, id in ipairs(ids) do
    for _, ow in ipairs(ownersByRecipe[id] or {}) do
      local k = ow.realm .. "\t" .. ow.name .. "\t" .. ow.prof
      if not seen[k] then seen[k] = true; out[#out + 1] = ow end
    end
  end
  return (#out > 0) and out or nil
end

-- Recherche par nom de recette. Renvoie (liste triee, total trouve).
function ST.RecipeSearch(query, limit)
  local UI = _G.TibiMidnight
  if not ownersByRecipe then BuildIndex() end
  local out = {}
  if not (UI and UI.Match) or type(query) ~= "string" or query == "" then return out, 0 end
  local cache = ST.db.recipeCache or {}
  for id, owners in pairs(ownersByRecipe) do
    local c = cache[id]
    if c and c.n and UI.Match(c.n, query) then
      out[#out + 1] = { id = id, name = c.n, icon = c.i, item = c.o, owners = owners }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  local total = #out
  if limit and total > limit then
    for i = total, limit + 1, -1 do out[i] = nil end
  end
  return out, total
end

-- Totaux pour l'ecran d'accueil de la vue : par perso, nombre de recettes.
function ST.RecipeTotals()
  local perChar, unique, nChars = {}, {}, 0
  for realm, list in pairs(ST.db.chars) do
    for name, rec in pairs(list) do
      local n = 0
      for _, r in pairs(type(rec) == "table" and rec.recipes or {}) do
        for id in pairs(r.ids or {}) do n = n + 1; unique[id] = true end
      end
      if n > 0 then
        nChars = nChars + 1
        perChar[#perChar + 1] = { name = name, realm = realm, class = rec.class, n = n }
      end
    end
  end
  local nUnique = 0
  for _ in pairs(unique) do nUnique = nUnique + 1 end
  table.sort(perChar, function(a, b) return a.n > b.n end)
  return nUnique, nChars, perChar
end

-- Texte court "Tibiscui (Alchimie), Tibizcui +2" aux couleurs de classe.
function ST.OwnersText(owners, max)
  max = max or 4
  local parts = {}
  for i, ow in ipairs(owners or {}) do
    if i > max then
      parts[#parts + 1] = "|cFF888888" .. string.format(L.RECIPE_MORE_OWNERS, #owners - max) .. "|r"
      break
    end
    local cc = RAID_CLASS_COLORS and ow.class and RAID_CLASS_COLORS[ow.class]
    local nm = cc and string.format("|cFF%02X%02X%02X%s|r", cc.r * 255, cc.g * 255, cc.b * 255, ow.name) or ow.name
    parts[#parts + 1] = nm .. " |cFF888888(" .. (ow.prof or "?") .. ")|r"
  end
  return table.concat(parts, ", ")
end

-- ================================================================
-- RELEVE DES RECETTES DU METIER OUVERT
-- ================================================================
local function IsOwnTradeSkill(api)
  local function yes(fn) return fn and select(2, pcall(fn)) == true end
  if yes(api.IsTradeSkillLinked) or yes(api.IsTradeSkillGuild) or yes(api.IsNPCCrafting)
    or yes(api.IsRuneforging) or yes(api.IsTradeSkillGuildMember) then
    return false
  end
  return true
end

local function TierOf(api, id)
  if not api.GetTradeSkillLineForRecipe then return nil end
  local ok, tsl = pcall(api.GetTradeSkillLineForRecipe, id)
  if ok and type(tsl) == "number" then return tsl end
  return nil
end

function ST.ScanRecipes()
  if not (ST.settings and ST.settings.recipes and ST.settings.enabled ~= false) then return end
  local api = C_TradeSkillUI
  if not (api and api.GetAllRecipeIDs and api.GetRecipeInfo and api.GetBaseProfessionInfo) then return end
  if not IsOwnTradeSkill(api) then return end
  local okB, base = pcall(api.GetBaseProfessionInfo)
  local parent = okB and base and base.professionID
  local rec = ST.CurrentRec()
  local prof = rec and parent and rec.professions and rec.professions[parent]
  if not prof then return end
  local okI, ids = pcall(api.GetAllRecipeIDs)
  if not okI or type(ids) ~= "table" or #ids == 0 then return end

  local token = {}
  ST.runtime.recipeScan = token
  local cache = ST.db.recipeCache
  local onlyCur = ST.settings.recipeScope ~= "all"
  local cur = ST.CurrentExpIndex()
  local found, seenTiers = {}, {}
  local i, n = 1, #ids

  local function finish()
    rec.recipes = rec.recipes or {}
    local old = rec.recipes[parent]
    local merged = {}
    local before = 0
    if old and type(old.ids) == "table" then
      for id in pairs(old.ids) do
        before = before + 1
        local c = cache[id]
        local tier = c and c.t or parent
        -- On garde une ancienne recette si son palier n'a pas ete relu cette
        -- fois, et si elle reste dans la portee choisie.
        if not seenTiers[tier] then
          local ln = prof.lines and prof.lines[tier]
          local idx = ln and ST.LineIndex(ln)
          if not (onlyCur and idx and idx ~= cur) then merged[id] = true end
        end
      end
    end
    local count = 0
    for id in pairs(found) do merged[id] = true end
    for _ in pairs(merged) do count = count + 1 end
    rec.recipes[parent] = { ids = merged, t = time() }
    ST.InvalidateRecipeIndex()
    if count ~= before then
      print(ST.TAG .. " " .. string.format(L.RECIPE_SCANNED, prof.name or "?", count))
    end
    if ST.RefreshUI then ST.RefreshUI() end
  end

  local function step()
    if ST.runtime.recipeScan ~= token then return end   -- fenetre fermee / releve plus recent
    local stop = math.min(n, i + BATCH - 1)
    for k = i, stop do
      local id = ids[k]
      local ok, info = pcall(api.GetRecipeInfo, id)
      if ok and type(info) == "table" and info.learned
        and not info.isDummyRecipe and not info.isGatheringRecipe and not info.isRecraft then
        local tier = TierOf(api, id) or parent
        seenTiers[tier] = true
        local ln = prof.lines and prof.lines[tier]
        local idx = ln and ST.LineIndex(ln)
        if not (onlyCur and idx and idx ~= cur) then
          found[id] = true
          local c = cache[id]
          if not c or c.n ~= info.name then
            local out
            if api.GetRecipeSchematic then
              local okS, sch = pcall(api.GetRecipeSchematic, id, false)
              out = okS and type(sch) == "table" and sch.outputItemID or nil
            end
            cache[id] = { n = info.name, i = info.icon, o = out, p = parent, t = tier }
          end
        end
      end
    end
    i = stop + 1
    if i <= n then C_Timer.After(0, step) else finish() end
  end
  step()
end

-- Differe et coalesce (TRADE_SKILL_LIST_UPDATE arrive en rafale a l'ouverture).
function ST.RequestRecipeScan(delay)
  if ST.runtime.recipePending then return end
  ST.runtime.recipePending = true
  C_Timer.After(delay or 2.0, function()
    ST.runtime.recipePending = false
    local ok, err = pcall(ST.ScanRecipes)
    if not ok and ST.runtime.debug then print(ST.TAG .. " recipes: " .. tostring(err)) end
  end)
end

function ST.CancelRecipeScan() ST.runtime.recipeScan = nil end

-- Nouvelle recette apprise (fenetre de metier fermee possible) : ajout direct.
function ST.OnRecipeLearned(id)
  if not (ST.settings and ST.settings.recipes) or type(id) ~= "number" then return end
  local api = C_TradeSkillUI
  local rec = ST.CurrentRec()
  if not (api and rec) then return end
  local okI, info = pcall(api.GetRecipeInfo, id)
  if not okI or type(info) ~= "table" or not info.name then return end
  local tier = TierOf(api, id)
  local parent
  for p, prof in pairs(rec.professions or {}) do
    if p == tier or (tier and prof.lines and prof.lines[tier]) then parent = p break end
  end
  if not parent then return end
  local out
  if api.GetRecipeSchematic then
    local okS, sch = pcall(api.GetRecipeSchematic, id, false)
    out = okS and type(sch) == "table" and sch.outputItemID or nil
  end
  ST.db.recipeCache[id] = { n = info.name, i = info.icon, o = out, p = parent, t = tier or parent }
  rec.recipes = rec.recipes or {}
  rec.recipes[parent] = rec.recipes[parent] or { ids = {} }
  rec.recipes[parent].ids[id] = true
  ST.InvalidateRecipeIndex()
end

-- Efface toutes les recettes (tous persos) et le cache des noms.
function ST.WipeRecipes()
  for _, list in pairs(ST.db.chars) do
    for _, rec in pairs(list) do if type(rec) == "table" then rec.recipes = nil end end
  end
  ST.db.recipeCache = {}
  ST.InvalidateRecipeIndex()
end

-- ================================================================
-- INFO-BULLE DES OBJETS : « Tes personnages savent le fabriquer »
-- Passe par TooltipDataProcessor (API prevue pour les addons, aucune
-- ecriture dans les frames Blizzard). Tout est sous pcall.
-- ================================================================
local tooltipHooked = false
function ST.HookItemTooltips()
  if tooltipHooked then return end
  if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType) then
    return
  end
  tooltipHooked = true
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
    pcall(function()
      if not (ST.settings and ST.settings.recipeTooltip and ST.settings.recipes) then return end
      if ST.runtime.inRecipeTip then return end   -- deja liste par la vue Recettes
      if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
      local id = data and data.id
      if issecretvalue and issecretvalue(id) then return end
      if type(id) ~= "number" then return end
      local owners = ST.OwnersForItem(id)
      if not owners then return end
      tt:AddLine(" ")
      tt:AddLine(ST.TAG .. " " .. L.RECIPE_TT_HEAD)
      tt:AddLine(ST.OwnersText(owners, 6), 1, 1, 1, true)
    end)
  end)
end
