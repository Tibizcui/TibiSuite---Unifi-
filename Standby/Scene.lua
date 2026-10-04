--[[============================================================================
  Standby - Scene.lua
  ---------------------------------------------------------------------------
  Tout ce qui touche au jeu autour de l'ecran : interface Blizzard masquee,
  rotation de la camera, mode economie (CVars), catalogue des illustrations
  d'extension.

  Fonds :
    - scene : le monde reste visible, la camera tourne lentement autour du
              personnage, l'interface Blizzard est masquee (UIParent:Hide hors
              combat, methode d'ElvUI). En mode sur (le client a refuse une de
              nos actions) ou si la case est decochee : voile sombre a la place.
    - art   : illustration du journal des aventures d'une extension, en plein
              ecran. On n'embarque AUCUNE image : on lit celles du client
              (droits + poids du paquet). Interface jamais masquee : le voile
              opaque la recouvre deja.
    - black : noir (mise en page Economie).

  Restauration : chaque valeur d'origine est ecrite dans StandbyDB.restore
  AVANT d'etre modifiee, puis rejouee a la sortie, a la deconnexion, et au
  login suivant si la sortie n'a jamais eu lieu.

  NON TESTE EN JEU sous 12.1 : UIParent:Hide/Show depuis un addon, la
  rotation MoveViewLeftStart, le retour d'EJ_GetInstanceByIndex (images),
  les CVars maxFPS / maxFPSBk. A valider par Tibiscui (/standby probe).
============================================================================]]

local ADDON, SB = ...
local T = SB.T

local Scene = {}
SB.Scene = Scene
Scene.uiHidden      = false
Scene.spinning      = false
Scene.pendingShowUI = false

-- ============================================================================
-- CVARS
-- ============================================================================
local function GetCV(name)
  if C_CVar and C_CVar.GetCVar then
    local ok, v = pcall(C_CVar.GetCVar, name)
    if ok then return v end
  end
  if GetCVar then
    local ok, v = pcall(GetCVar, name)
    if ok then return v end
  end
  return nil
end

local function SetCV(name, value)
  value = tostring(value)
  if C_CVar and C_CVar.SetCVar then
    local ok = pcall(C_CVar.SetCVar, name, value)
    if ok then return true end
  end
  if SetCVar then return (pcall(SetCVar, name, value)) end
  return false
end

-- Memorise la valeur d'origine une seule fois (une absence = un instantane).
local function Save(name)
  local r = SB.db.restore
  r.cvars = r.cvars or {}
  if r.cvars[name] == nil then
    local v = GetCV(name)
    if v ~= nil then r.cvars[name] = v end
  end
end

local function RestoreCVars()
  local r = SB.db and SB.db.restore
  if not (r and r.cvars) then return end
  for name, v in pairs(r.cvars) do SetCV(name, v) end
  r.cvars = nil
end

local function EcoWanted()
  local db = SB.db
  return db.layout == "eco" or db.ecoAll
end

local function ApplyEco()
  local db = SB.db
  local target = db.ecoFPS or 15
  -- Garde la limite du joueur si elle est deja plus basse.
  local function Cap(useName, maxName)
    local use, cur = GetCV(useName), tonumber(GetCV(maxName))
    if cur == nil then return end
    local new = target
    if use == "1" and cur > 0 and cur < target then new = cur end
    Save(useName); Save(maxName)
    SetCV(useName, "1"); SetCV(maxName, new)
  end
  Cap("useMaxFPS", "maxFPS")
  Cap("useMaxFPSBk", "maxFPSBk")
  if db.ecoAmbience and GetCV("Sound_EnableAmbience") ~= nil then
    Save("Sound_EnableAmbience")
    SetCV("Sound_EnableAmbience", "0")
  end
end

-- ============================================================================
-- INTERFACE BLIZZARD
-- ============================================================================
function Scene.CanHideUI()
  local db = SB.db
  return db.hideUI and not db.safeMode and not InCombatLockdown()
end

function Scene.HideUI()
  if not Scene.CanHideUI() then return false end
  -- Interface deja masquee par le joueur (Alt+Z) : on n'y touche pas, et on
  -- ne la fera donc pas reapparaitre a la sortie.
  if not UIParent:IsShown() then return false end
  SB.db.restore.ui = true
  local ok = pcall(UIParent.Hide, UIParent)
  if ok and not UIParent:IsShown() then
    Scene.uiHidden = true
  else
    SB.db.restore.ui = nil
  end
  return Scene.uiHidden
end

function Scene.ShowUI()
  Scene.pendingShowUI = false
  if not Scene.uiHidden and not (SB.db and SB.db.restore.ui) then return end
  pcall(UIParent.Show, UIParent)
  if UIParent:IsShown() then
    Scene.uiHidden = false
    SB.db.restore.ui = nil
  else
    -- Refuse (combat) : on reessaie a PLAYER_REGEN_ENABLED.
    Scene.pendingShowUI = true
  end
end

-- ============================================================================
-- CAMERA
-- ============================================================================
local function StartSpin()
  if not SB.db.spin or not MoveViewLeftStart then return end
  SB.db.restore.camera = true
  local ok = pcall(MoveViewLeftStart, (SB.db.spinSpeed or 4) * 0.009)
  Scene.spinning = ok
  if not ok then SB.db.restore.camera = nil end
end

local function StopSpin()
  if (Scene.spinning or (SB.db and SB.db.restore.camera)) and MoveViewLeftStop then pcall(MoveViewLeftStop) end
  Scene.spinning = false
  if SB.db then SB.db.restore.camera = nil end
end

-- ============================================================================
-- ILLUSTRATIONS D'EXTENSION (journal des aventures du client)
-- ============================================================================
-- Catalogue : { { tier=, name=, images={ {file=, inst=}, ... } }, ... }
-- Construit une fois, hors combat, journal ferme (EJ_SelectTier change le
-- palier affiche par le journal : on remet le precedent, comme LairLens).
local function EJBusy()
  local f = _G.EncounterJournal
  return f and f.IsShown and f:IsShown()
end

function Scene.ArtCatalog()
  if Scene.art then return Scene.art end
  if EJBusy() or InCombatLockdown() then return nil end
  if type(EJ_GetNumTiers) ~= "function" or type(EJ_SelectTier) ~= "function"
     or type(EJ_GetInstanceByIndex) ~= "function" then return nil end
  local okN, nTiers = pcall(EJ_GetNumTiers)
  if not okN or not nTiers or nTiers < 1 then return nil end
  local prev = type(EJ_GetCurrentTier) == "function" and EJ_GetCurrentTier() or nil

  local cat = {}
  for tier = 1, nTiers do
    pcall(EJ_SelectTier, tier)
    local okT, tname = pcall(EJ_GetTierInfo, tier)
    local entry = { tier = tier, name = (okT and tname) or ("#" .. tier), images = {} }
    local seen = {}
    for _, isRaid in ipairs({ true, false }) do
      for i = 1, 60 do
        -- instanceID, name, description, bgImage, buttonImage1, loreImage, ...
        local ok, jid, jname, _, bgImage, _, loreImage = pcall(EJ_GetInstanceByIndex, i, isRaid)
        if not ok or not jid then break end
        local img = (loreImage and loreImage ~= 0 and loreImage) or (bgImage and bgImage ~= 0 and bgImage) or nil
        if img and not seen[img] then
          seen[img] = true
          entry.images[#entry.images + 1] = { file = img, inst = jname }
        end
      end
    end
    if #entry.images > 0 then cat[#cat + 1] = entry end
  end
  if prev then pcall(EJ_SelectTier, prev) end
  if #cat == 0 then return nil end
  Scene.art = cat
  return cat
end

-- Palier de l'extension actuelle : niveau d'extension du compte + 1, borne au
-- catalogue (le journal ajoute parfois un palier « Saison actuelle » a la fin).
local function CurrentTierIndex(cat)
  local lvl = (GetExpansionLevel and GetExpansionLevel()) or (#cat - 1)
  local want = lvl + 1
  for i, e in ipairs(cat) do if e.tier == want then return i end end
  return #cat
end

-- Choisit l'image de cette absence. Renvoie { file=, inst=, tierName= } ou nil.
function Scene.PickArt()
  local cat = Scene.ArtCatalog()
  if not cat then return nil end
  local choice = SB.db.artTier or 0
  local entry
  if choice == -1 then
    entry = cat[math.random(#cat)]
  elseif choice == 0 then
    entry = cat[CurrentTierIndex(cat)]
  else
    for _, e in ipairs(cat) do if e.tier == choice then entry = e; break end end
    entry = entry or cat[CurrentTierIndex(cat)]
  end
  local img = entry.images[math.random(#entry.images)]
  return { file = img.file, inst = img.inst, tierName = entry.name }
end

-- ============================================================================
-- ENTREE / SORTIE
-- ============================================================================
function Scene.Background()
  local db = SB.db
  if db.layout == "eco" then return "black" end
  return db.background
end

function Scene.Enter()
  local bg = Scene.Background()
  Scene.mode = bg
  if bg == "scene" then
    Scene.HideUI()
    StartSpin()
  end
  if EcoWanted() then ApplyEco() end
end

function Scene.Exit()
  StopSpin()
  RestoreCVars()
  if Scene.uiHidden or (SB.db and SB.db.restore.ui) then Scene.ShowUI() end
  Scene.mode = nil
end

-- Au login : la sortie precedente n'a pas eu lieu (crash, coupure).
function Scene.RecoverAtLogin()
  local r = SB.db and SB.db.restore
  if not r then return end
  if r.cvars then RestoreCVars() end
  if r.camera then StopSpin() end
  -- UIParent est toujours visible apres un chargement : on oublie la marque.
  r.ui = nil
end
