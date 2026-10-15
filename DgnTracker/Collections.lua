-- ================================================================
-- DgnTracker - Collections.lua (7.1.5.45, feuille de route lot 8)
-- Montures, mascottes et jouets du butin des donjons et raids, et ce qui
-- reste faisable cette semaine. Constats des sondes /dg loot (2026-10-12) :
--   * le journal d'aventure donne le butin de 213 instances (13 paliers),
--     chaque objet avec son boss (encounterID), par difficulte ;
--   * GetMountFromItem / GetPetInfoByItemID / GetToyInfo ne reconnaissent un
--     objet qu'une fois charge : on demande le chargement des objets hors
--     equipement (slot vide) et on reclasse a ITEM_DATA_LOAD_RESULT ;
--   * GetSavedInstanceEncounterInfo donne les boss tues par verrou.
-- Catalogue construit en arriere-plan, une fois par version du jeu, garde dans
-- DgnTrackerDB.coll = { build, locale, at, inst = { [jid] = { name, tier,
--   raid, map, items = { [itemID] = { k = "mount"|"pet"|"toy", n = nom,
--   ic = icone, m = mountID, s = speciesID, e = encounterID, en = nom du
--   boss, d = { difficultes } } } } } }.
-- Etat (obtenu, boss tue cette semaine) lu en direct, jamais stocke.
-- Rien ne tourne au chargement : la construction part a la premiere ouverture
-- de la vue Collections (ou /dg collections rebuild).
-- NON TESTE EN JEU (nouveau fichier : redemarrage complet du client).
-- ================================================================
DgnTrackerColl = DgnTrackerColl or {}
local C = DgnTrackerColl

local DIFFS = { 1, 2, 23, 3, 4, 5, 6, 9, 14, 15, 16, 17, 7, 33, 24 }
local TIMEWALK = { [24] = true, [33] = true }

local function T(key, default) local L = DgnTrackerL; return (L and L[key]) or default end

local function Build()
  local v, b = GetBuildInfo()
  return tostring(v) .. "." .. tostring(b)
end
local function Locale() return GetLocale and GetLocale() or "" end
local function DB()
  DgnTrackerDB = DgnTrackerDB or {}
  return DgnTrackerDB
end
local function Norm(s)
  s = tostring(s or ""):gsub("\226\128\153", "'"):gsub("\226\128\152", "'")
  return s:lower()
end

-- ----------------------------------------------------------------
-- Classement d'un objet (charge) : monture, mascotte ou jouet
-- ----------------------------------------------------------------
local function Classify(itemID)
  if C_MountJournal and C_MountJournal.GetMountFromItem then
    local ok, mountID = pcall(C_MountJournal.GetMountFromItem, itemID)
    if ok and mountID then
      local okI, name, _, icon = pcall(C_MountJournal.GetMountInfoByID, mountID)
      return { k = "mount", m = mountID, n = okI and name or nil, ic = okI and icon or nil }
    end
  end
  if C_PetJournal and C_PetJournal.GetPetInfoByItemID then
    local ok, name, icon, _, _, _, _, _, _, _, _, _, _, speciesID = pcall(C_PetJournal.GetPetInfoByItemID, itemID)
    if ok and speciesID then return { k = "pet", s = speciesID, n = name, ic = icon } end
  end
  if C_ToyBox and C_ToyBox.GetToyInfo then
    local ok, toyID, name, icon = pcall(C_ToyBox.GetToyInfo, itemID)
    if ok and toyID then return { k = "toy", n = name, ic = icon } end
  end
  return nil
end

-- Deja obtenu ? (lu en direct ; pas de cache d'objet necessaire)
function C.Owned(itemID, r)
  if r.k == "mount" and r.m then
    local ok, _, _, _, _, _, _, _, _, _, _, collected = pcall(C_MountJournal.GetMountInfoByID, r.m)
    return ok and collected and true or false
  elseif r.k == "pet" and r.s then
    local ok, n = pcall(C_PetJournal.GetNumCollectedInfo, r.s)
    return ok and (tonumber(n) or 0) > 0 or false
  elseif r.k == "toy" then
    return PlayerHasToy and PlayerHasToy(itemID) and true or false
  end
  return false
end

-- ----------------------------------------------------------------
-- Construction du catalogue
-- ----------------------------------------------------------------
C.state = nil   -- { phase = "scan"|"load", done, total } pendant la construction

function C.Catalog()
  local c = DB().coll
  if type(c) == "table" and c.build == Build() and c.locale == Locale() and type(c.inst) == "table" then return c end
  return nil
end
function C.IsBuilding() return C.state ~= nil end

local onChange
function C.SetOnChange(fn) onChange = fn end
local function Changed() if onChange then pcall(onChange) end end

local loadFrame
function C.Start(force)
  if C.state then return true end
  if not force and C.Catalog() then return true end
  if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_SelectInstance and EJ_GetNumLoot
          and C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex) then return false, "api" end
  if EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown() then return false, "open" end
  local before = { tier = EJ_GetCurrentTier and EJ_GetCurrentTier() }
  if EJ_GetLootFilter then before.class, before.spec = EJ_GetLootFilter() end

  -- Liste des instances, tous paliers (dedoublonnees par jid)
  local list, seen = {}, {}
  local okT, nT = pcall(EJ_GetNumTiers)
  for tier = 1, (okT and nT or 0) do
    pcall(EJ_SelectTier, tier)
    local tierName = EJ_GetTierInfo and EJ_GetTierInfo(tier) or tostring(tier)
    for _, isRaid in ipairs({ true, false }) do
      for i = 1, 60 do
        local ok, jid, name = pcall(EJ_GetInstanceByIndex, i, isRaid)
        if not ok or not jid then break end
        if not seen[jid] then
          seen[jid] = true
          list[#list + 1] = { jid = jid, name = name, tier = tier, tierName = tierName, raid = isRaid }
        end
      end
    end
  end

  local cat = { build = Build(), locale = Locale(), inst = {} }
  local pending, pendingN = {}, 0    -- itemID -> { {jid, rec} }
  local encName = {}
  C.state = { phase = "scan", done = 0, total = #list }
  Changed()

  local function restore()
    pcall(function()
      if EJ_ResetLootFilter then EJ_ResetLootFilter() end
      if before.class and EJ_SetLootFilter then EJ_SetLootFilter(before.class, before.spec or 0) end
      if before.tier then EJ_SelectTier(before.tier) end
    end)
  end

  local function finish()
    if loadFrame then loadFrame:UnregisterAllEvents() end
    -- Objets restes sans classement : pas une collection, on les retire.
    for jid, inst in pairs(cat.inst) do
      for id, r in pairs(inst.items) do if not r.k then inst.items[id] = nil end end
      if not next(inst.items) then cat.inst[jid] = nil end
    end
    cat.at = time()
    DB().coll = cat
    C.state = nil
    C.index = nil
    Changed()
  end

  -- Phase 2 : chargement des objets hors equipement, par paquets.
  local function loadPhase()
    restore()
    local ids = {}
    for id in pairs(pending) do ids[#ids + 1] = id end
    C.state = { phase = "load", done = 0, total = #ids }
    Changed()
    if #ids == 0 then finish(); return end
    loadFrame = loadFrame or CreateFrame("Frame")
    local left = #ids
    local lastAnswer = GetTime()
    local function answer(id)
      local recs = pending[id]
      if not recs then return end
      pending[id] = nil
      left = left - 1
      lastAnswer = GetTime()
      C.state.done = C.state.done + 1
      local cl = Classify(id)
      if cl then
        for _, x in ipairs(recs) do
          local r = x.rec
          r.k, r.n, r.ic, r.m, r.s = cl.k, cl.n or r.n, cl.ic, cl.m, cl.s
        end
      end
    end
    loadFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    loadFrame:SetScript("OnEvent", function(_, _, id) answer(id) end)
    local req = C_Item and C_Item.RequestLoadItemDataByID
    local i = 0
    local function sendBatch()
      for _ = 1, 60 do
        i = i + 1
        local id = ids[i]
        if not id then break end
        -- Deja en cache : classe tout de suite (pas d'evenement dans ce cas).
        if C_Item and C_Item.IsItemDataCachedByID and C_Item.IsItemDataCachedByID(id) then answer(id)
        elseif req then pcall(req, id) end
      end
      Changed()
      if i < #ids then C_Timer.After(0.1, sendBatch) end
    end
    sendBatch()
    -- Fin : tout est arrive, ou plus de reponse depuis 10 s.
    local function watch()
      if left <= 0 or GetTime() - lastAnswer > 10 then finish() else C_Timer.After(1, watch) end
    end
    C_Timer.After(1, watch)
  end

  -- Phase 1 : une instance par image.
  local idx = 0
  local function step()
    idx = idx + 1
    local e = list[idx]
    if not e then loadPhase(); return end
    C.state.done = idx
    pcall(function()
      EJ_SelectInstance(e.jid)
      if EJ_ResetLootFilter then EJ_ResetLootFilter() end
      if C_EncounterJournal.SetSlotFilter and Enum and Enum.ItemSlotFilterType then
        pcall(C_EncounterJournal.SetSlotFilter, Enum.ItemSlotFilterType.NoFilter)
      end
      local instMap
      if EJ_GetInstanceInfo then instMap = select(10, EJ_GetInstanceInfo(e.jid)) end
      local inst
      for _, d in ipairs(DIFFS) do
        if not EJ_IsValidInstanceDifficulty or EJ_IsValidInstanceDifficulty(d) then
          EJ_SetDifficulty(d)
          for i = 1, (EJ_GetNumLoot() or 0) do
            local info = C_EncounterJournal.GetLootInfoByIndex(i)
            local id = type(info) == "table" and info.itemID
            if id and (info.slot == nil or info.slot == "") then
              inst = inst or { name = e.name, tier = e.tier, tierName = e.tierName, raid = e.raid, map = tonumber(instMap), items = {} }
              local r = inst.items[id]
              if not r then
                r = { e = info.encounterID, d = {}, n = info.name }
                if info.encounterID and EJ_GetEncounterInfo then
                  local en = encName[info.encounterID]
                  if en == nil then en = EJ_GetEncounterInfo(info.encounterID) or false; encName[info.encounterID] = en end
                  r.en = en or nil
                end
                inst.items[id] = r
                local cl = Classify(id)
                if cl then
                  r.k, r.n, r.ic, r.m, r.s = cl.k, cl.n or r.n, cl.ic, cl.m, cl.s
                else
                  if not pending[id] then pending[id] = {}; pendingN = pendingN + 1 end
                  table.insert(pending[id], { jid = e.jid, rec = r })
                end
              end
              local has = false
              for _, x in ipairs(r.d) do if x == d then has = true break end end
              if not has then r.d[#r.d + 1] = d end
            end
          end
        end
      end
      if inst then cat.inst[e.jid] = inst end
    end)
    if idx % 10 == 0 then Changed() end
    C_Timer.After(0, step)
  end
  step()
  return true
end

-- ----------------------------------------------------------------
-- Verrous : boss tues par instance (carte) et difficulte
-- ----------------------------------------------------------------
local function ReadLocks()
  local locks = {}
  if not (GetNumSavedInstances and GetSavedInstanceInfo and GetSavedInstanceEncounterInfo) then return locks end
  local okN, n = pcall(GetNumSavedInstances)
  for i = 1, (okN and n or 0) do
    local ok, _, _, reset, diffID, locked, extended, _, _, _, _, numEnc, _, _, instID = pcall(GetSavedInstanceInfo, i)
    if ok and (locked or extended) and (tonumber(reset) or 0) > 0 and instID then
      local l = { killed = {}, reset = reset }
      for b = 1, (tonumber(numEnc) or 0) do
        local okB, bname, _, killed = pcall(GetSavedInstanceEncounterInfo, i, b)
        if okB and bname and killed then l.killed[Norm(bname)] = true end
      end
      locks[instID] = locks[instID] or {}
      locks[instID][tonumber(diffID) or 0] = l
    end
  end
  return locks
end

-- Etat d'un objet pour le personnage :
--   "owned"  deja obtenu ;
--   "tw"     seulement en Marcheurs du temps (pendant l'evenement) ;
--   "done"   boss deja tue cette semaine dans toutes les difficultes utiles ;
--   "avail"  faisable cette semaine (diffs = difficultes encore ouvertes).
function C.ItemState(itemID, r, inst, locks)
  if C.Owned(itemID, r) then return "owned" end
  local useful, open = 0, {}
  local reset
  for _, d in ipairs(r.d or {}) do
    if not TIMEWALK[d] then
      useful = useful + 1
      local l = inst.map and locks[inst.map] and locks[inst.map][d]
      if l and r.en and l.killed[Norm(r.en)] then
        reset = reset and math.min(reset, l.reset) or l.reset
      else
        open[#open + 1] = d
      end
    end
  end
  if useful == 0 then return "tw" end
  if #open == 0 then return "done", nil, reset end
  return "avail", open
end

-- ----------------------------------------------------------------
-- Taux de drop estimes des montures (7.1.5.45). Le jeu n'en donne aucun :
-- estimations communautaires relevees le 2026-10-12 (missingmounts.com,
-- Wowhead via guides wow.gg / warcraft.wiki.gg / Icy Veins), jamais
-- officielles. Cle = mountID (r.m). p = pourcentage par tentative ;
-- lt = true : « moins de 1 % » ; note = condition particuliere.
-- Monture absente = taux non documente : on n'affiche rien (aucune valeur
-- inventee). A completer au fil des sources.
-- ----------------------------------------------------------------
local RATES = {
  [168] = { p = 1 },    -- Cheval de guerre embrase (Attumen, Karazhan)
  [183] = { p = 2 },    -- Cendres d'Al'ar (Kael'thas, L'Oeil)
  [185] = { p = 1 },    -- Seigneur corbeau (Anzu, Sethekk heroique)
  [213] = { p = 4 },    -- Faucon-peregrin blanc rapide (Kael'thas, Terrasse heroique)
  [250] = { p = 100, note = "3d" },  -- Drake du Crepuscule (Sartharion 25, 3 drakes)
  [253] = { p = 100, note = "3d" },  -- Drake noir (Sartharion 10, 3 drakes)
  [264] = { p = 1 },    -- Proto-drake bleu (Skadi, Cime d'Utgarde heroique)
  [304] = { p = 1, note = "keepers" }, -- Tete de Mimiron (Yogg-Saron sans gardiens)
  [349] = { p = 1 },    -- Drake onyxien (Onyxia)
  [363] = { p = 1 },    -- Invincible (Roi-liche 25 heroique)
  [395] = { p = 1 },    -- Drake du vent du Nord (Altairus)
  [396] = { p = 1 },    -- Drake du vent du Sud (Al'Akir)
  [397] = { p = 1 },    -- Drake de pierre vitrifiee (Peau-de-Pierre)
  [411] = { p = 1 },    -- Panthere zulienne rapide (Kilnara)
  [415] = { p = 1 },    -- Faucon de feu sang-pur (Ragnaros, Terres de Feu)
  [425] = { lt = true },-- Serres-de-Flammes d'Alysrazor
  [442] = { p = 1 },    -- Drake flamboyant (Folie d'Aile de mort)
  [444] = { p = 1 },    -- Suivante de la Lieuse-de-Vie (Folie d'Aile de mort heroique)
  [445] = { lt = true },-- Experience 12-B (Ultraxion)
  [559] = { p = 1 },    -- Mastodonte kor'kron (Garrosh mythique)
  [613] = { p = 1 },    -- Destructeur sabot-de-fer (Main-Noire mythique)
  [633] = { p = 1 },    -- Infernal des Flammes infernales (Gul'dan mythique)
  [634] = { p = 1 },    -- Faucon des fleches solaire (Rukhmar, 1 essai par semaine)
  [751] = { p = 1 },    -- Annihilateur en gangracier (Archimonde mythique)
  [954] = { p = 1 },    -- Ur'zul entrave (Argus mythique)
  [995] = { p = 1 },    -- Jacasse (Port-Liberte mythique)
  [1040] = { p = 1 },   -- Traqueur des tombes (Repos des rois mythique)
  [1053] = { p = 1 },   -- Crogg des trefonds Putrides (mythique)
  [1217] = { p = 1 },   -- M.E.G.A. (Mekkanivelle)
  [1219] = { p = 1 },   -- Vaguerage glaciaire (Jaina mythique)
  [1252] = { p = 1 },   -- Garde-paix de Mecagone (mythique)
  [1293] = { p = 1 },   -- Omnivoyant de Ny'alotha (N'Zoth)
  [1406] = { p = 1 },   -- Croc-de-Moelle (Sillage necrotique mythique)
  [1471] = { p = 1 },   -- Vengeance (Sylvanas mythique)
  [1481] = { p = 1 },   -- Mecaplaneur de maitre de cartel (So'leah mythique)
  [1500] = { p = 1 },   -- Destrier sinistre du sanctum (Les Neuf)
  [1587] = { p = 1 },   -- Surveillant de Zereth (Le Geolier mythique)
  [1818] = { p = 1 },   -- Anu'relos, Guide de la Flamme (Fyrakka mythique)
  -- The War Within (sources Icy Veins / wow.gg, 2026-10-12) : les 3 montures
  -- Mythiques de fin de raid ne sont plus garanties depuis Midnight (~1 %).
  [2219] = { lt = true },   -- Rasoir-celeste sureki (Reine Ansurek, ~0,65 %)
  [2223] = { p = 1 },       -- Rasoir-celeste ascendant (Reine Ansurek mythique)
  [2487] = { p = 1 },       -- Le G-neral (Gallywix mythique)
  [2569] = { p = 1 },       -- Devoreur d'etoiles delie (Dimensius mythique)
  -- Midnight (wow.gg, 2026-10-12)
  [2805] = { p = 1 },       -- Faucon-peregrin spectral (Fleche de Coursevent mythique)
  [2607] = { note = "x3" }, -- Cendres de Belo'ren : 3 exemplaires par kill mythique tant que le raid est actuel
}

local NOTE = {
  ["3d"] = function() return T("COLL_NOTE_3D", "seulement si les 3 drakes sont encore en vie") end,
  keepers = function() return T("COLL_NOTE_KEEPERS", "Yogg-Saron vaincu sans l'aide des gardiens") end,
  x3 = function() return T("COLL_NOTE_X3", "3 exemplaires par victoire en Mythique tant que le raid est actuel (ensuite environ 1 %)") end,
}

-- Taux d'un objet du catalogue : texte court (« ~1 % »), valeur pour le tri
-- (0 si inconnu), note longue (ou nil). Montures seulement.
function C.Rate(r)
  if r.k ~= "mount" or not r.m then return nil, 0, nil end
  local e = RATES[r.m]
  if not e then return nil, 0, nil end
  local note = e.note and NOTE[e.note] and NOTE[e.note]() or nil
  if e.note == "x3" then return T("COLL_RATE_X3", "x3 / kill"), 300, note end
  if e.lt then return T("COLL_RATE_LT1", "< 1 %"), 0.5, note end
  if e.p then return string.format(T("COLL_RATE_FMT", "~%d %%"), e.p), e.p, note end
  return nil, 0, note
end

function C.DiffName(d)
  if GetDifficultyInfo then
    local ok, n = pcall(GetDifficultyInfo, d)
    if ok and n then return n end
  end
  return tostring(d)
end

-- Liste filtree, rangee par palier (extension) puis instance.
-- opts = { kind = "all"|"mount"|"pet"|"toy", hideOwned, weekOnly, search }
-- -> { { tierName, tier, list = { { jid, inst, items = { {id, r, state, open, reset} } } } } }
function C.List(opts)
  local cat = C.Catalog()
  if not cat then return {} end
  local locks = ReadLocks()
  local byTier, tiers = {}, {}
  local q = opts.search and opts.search ~= "" and Norm(opts.search) or nil
  for jid, inst in pairs(cat.inst) do
    local rows = {}
    for id, r in pairs(inst.items) do
      if opts.kind == "all" or opts.kind == r.k then
        local st, open, reset = C.ItemState(id, r, inst, locks)
        local keep = not (opts.hideOwned and st == "owned") and not (opts.weekOnly and st ~= "avail")
        if keep and q then keep = Norm((r.n or "") .. " " .. (inst.name or "") .. " " .. (r.en or "")):find(q, 1, true) ~= nil end
        if keep then rows[#rows + 1] = { id = id, r = r, state = st, open = open, reset = reset } end
      end
    end
    if #rows > 0 then
      local ORDER = { avail = 1, tw = 2, done = 3, owned = 4 }
      local KIND = { mount = 1, pet = 2, toy = 3 }
      table.sort(rows, function(a, b)
        if ORDER[a.state] ~= ORDER[b.state] then return ORDER[a.state] < ORDER[b.state] end
        if KIND[a.r.k] ~= KIND[b.r.k] then return KIND[a.r.k] < KIND[b.r.k] end
        local _, ra = C.Rate(a.r)
        local _, rb = C.Rate(b.r)
        if ra ~= rb then return ra > rb end
        return tostring(a.r.n) < tostring(b.r.n)
      end)
      local g = byTier[inst.tier]
      if not g then g = { tier = inst.tier, tierName = inst.tierName, list = {} }; byTier[inst.tier] = g; tiers[#tiers + 1] = g end
      g.list[#g.list + 1] = { jid = jid, inst = inst, items = rows }
    end
  end
  table.sort(tiers, function(a, b) return (a.tier or 0) > (b.tier or 0) end)
  for _, g in ipairs(tiers) do
    table.sort(g.list, function(a, b) return tostring(a.inst.name) < tostring(b.inst.name) end)
  end
  return tiers
end

-- Lien de l'objet (cache) ; nil tant que le jeu ne l'a pas charge.
function C.ItemLink(itemID)
  local link
  if C_Item and C_Item.GetItemInfo then link = select(2, C_Item.GetItemInfo(itemID)) end
  if not link and GetItemInfo then link = select(2, GetItemInfo(itemID)) end
  if not link and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
  return link
end

-- Insere un lien dans la discussion : dans la saisie ouverte, sinon ouvre
-- la saisie avec le lien (ChatEdit_InsertLink seul ne fait rien quand la
-- saisie est fermee).
function C.LinkToChat(link)
  if not link then return false end
  if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return true end
  if ChatFrameUtil and ChatFrameUtil.OpenChat then ChatFrameUtil.OpenChat(link); return true end
  if ChatFrame_OpenChat then ChatFrame_OpenChat(link); return true end
  return false
end

-- Comment obtenir l'objet : notre lecture (boss, instance, difficultes) et
-- le texte de source du jeu (journal des montures / mascottes).
-- -> lignes de texte (sans couleur), texte de source du jeu (ou nil)
function C.HowTo(r, instName)
  local lines = {}
  local diffs = {}
  for _, d in ipairs(r.d or {}) do diffs[#diffs + 1] = C.DiffName(d) end
  if r.en and instName then
    lines[#lines + 1] = string.format(T("COLL_HOW_KILL_FMT", "Vaincre %s dans %s."), r.en, instName)
  elseif instName then
    lines[#lines + 1] = string.format(T("COLL_HOW_INST_FMT", "Butin de %s."), instName)
  end
  if #diffs > 0 then lines[#lines + 1] = string.format(T("COLL_HOW_DIFF_FMT", "Difficultés : %s."), table.concat(diffs, ", ")) end
  local src
  if r.k == "mount" and r.m and C_MountJournal and C_MountJournal.GetMountInfoExtraByID then
    local ok, _, desc, source = pcall(C_MountJournal.GetMountInfoExtraByID, r.m)
    if ok and type(source) == "string" and source ~= "" then src = source end
  elseif r.k == "pet" and r.s and C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
    local ok, _, _, _, _, source = pcall(C_PetJournal.GetPetInfoBySpeciesID, r.s)
    if ok and type(source) == "string" and source ~= "" then src = source end
  end
  return lines, src
end

-- Montures d'une instance (fiche de DgnTracker) : { { id, r, state, open,
-- reset } }, faisables d'abord puis meilleur taux. nil = pas de catalogue.
function C.ForInstance(jid)
  local cat = C.Catalog()
  if not cat or not jid then return nil end
  local inst = cat.inst[jid]
  if not inst then return {} end
  local locks = ReadLocks()
  local out = {}
  for id, r in pairs(inst.items) do
    if r.k == "mount" then
      local st, open, reset = C.ItemState(id, r, inst, locks)
      out[#out + 1] = { id = id, r = r, state = st, open = open, reset = reset }
    end
  end
  local ORDER = { avail = 1, tw = 2, done = 3, owned = 4 }
  table.sort(out, function(a, b)
    if ORDER[a.state] ~= ORDER[b.state] then return ORDER[a.state] < ORDER[b.state] end
    local _, ra = C.Rate(a.r)
    local _, rb = C.Rate(b.r)
    if ra ~= rb then return ra > rb end
    return tostring(a.r.n) < tostring(b.r.n)
  end)
  return out
end

-- Resume pour l'apercu : objets faisables cette semaine par type, et les
-- instances qui en offrent le plus (montures d'abord).
function C.Summary()
  local cat = C.Catalog()
  if not cat then return nil end
  local locks = ReadLocks()
  local out = { mount = 0, pet = 0, toy = 0, top = {} }
  for jid, inst in pairs(cat.inst) do
    local m, any = 0, 0
    for id, r in pairs(inst.items) do
      if C.ItemState(id, r, inst, locks) == "avail" then
        out[r.k] = (out[r.k] or 0) + 1
        any = any + 1
        if r.k == "mount" then m = m + 1 end
      end
    end
    if m > 0 then out.top[#out.top + 1] = { jid = jid, name = inst.name, mounts = m, map = inst.map, locked = locks[inst.map] ~= nil } end
  end
  -- Instances deja entamees cette semaine en tete (on y est deja), puis le
  -- plus de montures.
  table.sort(out.top, function(a, b)
    if a.locked ~= b.locked then return a.locked end
    if a.mounts ~= b.mounts then return a.mounts > b.mounts end
    return tostring(a.name) < tostring(b.name)
  end)
  return out
end

-- Conseiller de TibiSuite (lot 3) : montures faisables cette semaine.
-- Proximite (« facilite ») 0,4 de base, +0,2 instance deja entamee cette
-- semaine, +0,1 contenu d'une extension passee, +0,1 taux documente d'au
-- moins 1 % ; poids 0,75 (un butin a 1 % ne doit pas passer devant un haut
-- fait presque fini). Les mascottes et jouets ne sont pas proposes (trop
-- nombreux).
-- nil = catalogue pas encore construit (jamais lance ici : il part a la
-- premiere ouverture de la vue Collections).
function C.Suggestions(max)
  local cat = C.Catalog()
  if not cat then return nil end
  local locks = ReadLocks()
  local SL = _G.TibiSuiteL or {}
  local maxTier = 0
  for _, inst in pairs(cat.inst) do if (inst.tier or 0) > maxTier then maxTier = inst.tier end end
  local out = {}
  for _, inst in pairs(cat.inst) do
    for id, r in pairs(inst.items) do
      local st, open
      if r.k == "mount" then st, open = C.ItemState(id, r, inst, locks) end
      if st == "avail" then
        local rtxt, rval, rnote = C.Rate(r)
        local locked = inst.map and locks[inst.map] ~= nil or false
        local old = (inst.tier or 0) < maxTier
        local why = (r.en and SL.SUG_C_MOUNT_FMT) and string.format(SL.SUG_C_MOUNT_FMT, r.en, tostring(inst.name))
          or (SL.SUG_C_MOUNT_INST_FMT and string.format(SL.SUG_C_MOUNT_INST_FMT, tostring(inst.name))) or nil
        if why and locked and SL.SUG_C_LOCKED then why = why .. " " .. SL.SUG_C_LOCKED end
        out[#out + 1] = {
          id = "coll:" .. id, kind = "coll", text = r.n or ("#" .. id), icon = r.ic,
          tag = inst.raid and "raid" or "dungeon", group = (inst.raid and not old) and true or false,
          proximity = 0.4 + (locked and 0.2 or 0) + (old and 0.1 or 0) + ((rval or 0) >= 1 and 0.1 or 0),
          why = why, note = rtxt, target = "coll", rate = rval or 0, weight = 0.75,
          -- Infobulle du Conseiller : boss, instance, difficultes encore
          -- ouvertes cette semaine, chance estimee, source du journal.
          steps = function()
            local out = {}
            local okH, lines, src = pcall(C.HowTo, r, inst.name)
            if okH then for _, l in ipairs(lines or {}) do out[#out + 1] = { text = l } end end
            if open and #open > 0 and SL.SUG_ST_DIFFS_FMT then
              local names = {}
              for _, d in ipairs(open) do names[#names + 1] = C.DiffName(d) end
              out[#out + 1] = { text = string.format(SL.SUG_ST_DIFFS_FMT, table.concat(names, ", ")), done = false }
            end
            if rtxt and SL.SUG_ST_RATE_FMT then out[#out + 1] = { text = string.format(SL.SUG_ST_RATE_FMT, rtxt) } end
            if rnote then out[#out + 1] = { text = rnote } end
            if okH and type(src) == "string" and src ~= "" then out[#out + 1] = { text = src } end
            return out
          end,
        }
      end
    end
  end
  table.sort(out, function(a, b)
    if a.proximity ~= b.proximity then return a.proximity > b.proximity end
    if a.rate ~= b.rate then return a.rate > b.rate end
    return tostring(a.text) < tostring(b.text)
  end)
  while #out > (max or 6) do table.remove(out) end
  return out
end

-- ----------------------------------------------------------------
-- Nom et icone d'affichage. Certains objets (jouets surtout) sont classes
-- sans nom ni icone : on lit l'icone (connue sans cache), on demande le
-- chargement du nom, et on l'inscrit dans le catalogue a son arrivee.
-- ----------------------------------------------------------------
local nameWait = {}
function C.Display(itemID, r)
  if not r.ic then
    local ic = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)) or (GetItemIcon and GetItemIcon(itemID))
    if ic then r.ic = ic end
  end
  if not r.n then
    local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if n then r.n = n
    elseif not nameWait[itemID] and C_Item and C_Item.RequestLoadItemDataByID then
      nameWait[itemID] = r
      pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
  end
  return r.n, r.ic
end
local nameFrame = CreateFrame("Frame")
pcall(nameFrame.RegisterEvent, nameFrame, "ITEM_DATA_LOAD_RESULT")
nameFrame:SetScript("OnEvent", function(_, _, id)
  local r = nameWait[id]
  if not r then return end
  nameWait[id] = nil
  local n = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  if n then r.n = n end
  if not r.ic and C_Item.GetItemIconByID then r.ic = C_Item.GetItemIconByID(id) end
  Changed()
end)

-- ----------------------------------------------------------------
-- Fil d'activite : objet du catalogue obtenu
-- ----------------------------------------------------------------
local function Index()
  if C.index then return C.index end
  local cat = C.Catalog()
  local ix = { mount = {}, pet = {}, toy = {} }
  if cat then
    for _, inst in pairs(cat.inst) do
      for id, r in pairs(inst.items) do
        if r.k == "mount" and r.m then ix.mount[r.m] = { r = r, inst = inst }
        elseif r.k == "pet" and r.s then ix.pet[r.s] = { r = r, inst = inst }
        elseif r.k == "toy" then ix.toy[id] = { r = r, inst = inst } end
      end
    end
  end
  C.index = ix
  return ix
end

local function Announce(hit)
  if not hit then return end
  local text = string.format(T("COLL_GOT_FMT", "Collection obtenue : %s (%s)"), tostring(hit.r.n), tostring(hit.inst.name))
  local TS = _G.TibiSuite
  if TS and TS.Notify then TS.Notify("Dgn", text, { toast = false })
  else print("|cFF4D99FFDgnTracker|r : " .. text) end
  Changed()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "NEW_TOY_ADDED", "UPDATE_INSTANCE_INFO" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, arg)
  if event == "UPDATE_INSTANCE_INFO" then Changed(); return end
  if not C.Catalog() then return end
  local ix = Index()
  if event == "NEW_MOUNT_ADDED" then Announce(ix.mount[arg])
  elseif event == "NEW_TOY_ADDED" then Announce(ix.toy[arg])
  elseif event == "NEW_PET_ADDED" and C_PetJournal and C_PetJournal.GetPetInfoByPetID then
    local ok, speciesID = pcall(C_PetJournal.GetPetInfoByPetID, arg)
    if ok then Announce(ix.pet[speciesID]) end
  end
end)
