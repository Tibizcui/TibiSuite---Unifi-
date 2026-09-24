--[[============================================================================
  Opacity - Core.lua
  ---------------------------------------------------------------------------
  Moteur d'opacite. Principe central : LIRE ET MULTIPLIER, NE JAMAIS ECRASER.

  Chaque frame controlee a deux composantes :
    - base : l'alpha que "quelqu'un d'autre" lui donne (Blizzard, le mode
             Edition, ElvUI, EllesmereUI, l'addon proprietaire...). On le lit
             via un crochet hooksecurefunc(frame, "SetAlpha") : a chaque fois
             qu'un tiers change l'alpha, on memorise sa valeur comme base.
    - cur  : NOTRE facteur (0..1), anime par Hover.lua vers une cible
             calculee ici (reglage de la frame, contexte, curseur maitre).
  L'alpha reellement affiche vaut base * cur. Le mode Edition et les moteurs
  de fondu d'ElvUI / EllesmereUI gardent donc la main sur LEUR valeur : on ne
  fait que s'ajouter par-dessus. On n'ecrit JAMAIS dans le mode Edition
  (C_EditMode) : decision validee par Tibiscui, pour eviter le taint et le
  conflit avec EllesmereUI_ForeverLayout qui y ecrit deja.

  Frames protegees (barres d'action, cadres d'unite) : SetAlpha n'est pas
  cense etre bloque en combat. NON VERIFIE EN JEU sous 12.x : si le client
  le bloque quand meme (ADDON_ACTION_BLOCKED au nom d'Opacity), on le detecte,
  on previent une seule fois, et a partir de la tout changement sur une frame
  protegee en combat part en file d'attente, applique a PLAYER_REGEN_ENABLED.

  Aucune autre ecriture sur les frames des autres : pas d'EnableMouse, pas de
  Show/Hide, pas de SetParent, pas de hook de fonction globale Blizzard.
============================================================================]]

local ADDON, OP = ...

OP.ACCENT = { 0.498, 0.831, 0.910 }   -- bleu glacier #7FD4E8 (identite Opacity)
OP.LOGO   = "Interface\\AddOns\\Opacity\\medias\\Logo"

OP.L = OP.L or {}
function OP.T(key, fr) return OP.L[key] or fr end
local T = OP.T

local function Hex() local a = OP.ACCENT
  return string.format("|cFF%02X%02X%02X", math.floor(a[1]*255+0.5), math.floor(a[2]*255+0.5), math.floor(a[3]*255+0.5))
end
function OP.Print(msg) print(Hex() .. "Opacity|r : " .. msg) end

-- Petit retour visuel non intrusif (zone des messages d'erreur au centre haut)
function OP.Flash(msg)
  if UIErrorsFrame and UIErrorsFrame.AddMessage then
    local a = OP.ACCENT
    UIErrorsFrame:AddMessage("Opacity : " .. msg, a[1], a[2], a[3])
  end
end

local function Clamp01(v)
  v = tonumber(v) or 1
  if v < 0 then return 0 elseif v > 1 then return 1 end
  return v
end
OP.Clamp01 = Clamp01

-- ============================================================================
-- RACCOURCIS CLAVIER (libelles lus par Bindings.xml)
-- ============================================================================
BINDING_HEADER_OPACITY               = "Opacity"
BINDING_NAME_OPACITY_MASTER_UP       = T("BIND_MASTER_UP",   "Curseur maître : +10 %")
BINDING_NAME_OPACITY_MASTER_DOWN     = T("BIND_MASTER_DOWN", "Curseur maître : -10 %")
BINDING_NAME_OPACITY_SCREENSHOT      = T("BIND_SCREENSHOT",  "Mode capture d'écran (bascule)")
BINDING_NAME_OPACITY_TOGGLE_ENABLED  = T("BIND_ENABLED",     "Activer / suspendre Opacity")
BINDING_NAME_OPACITY_PICKER          = T("BIND_PICKER",      "Pipette : ajouter une fenêtre")
BINDING_NAME_OPACITY_WINDOW          = T("BIND_WINDOW",      "Ouvrir / fermer la fenêtre Opacity")

-- ============================================================================
-- PROFIL : valeurs par defaut + assainissement (partage avec Profiles.lua)
-- ============================================================================
-- Ordre de priorite des contextes : le premier actif l'emporte.
OP.CONTEXT_ORDER = { "afk", "combat", "raid", "instance", "mount" }

local CONTEXT_DEFAULTS = {
  afk      = { on = false, value = 0.20 },
  combat   = { on = false, value = 1.00 },
  raid     = { on = false, value = 1.00 },
  instance = { on = false, value = 1.00 },
  mount    = { on = false, value = 0.40 },
}

function OP.DefaultProfile()
  local p = { master = 1.0, frames = {}, contexts = {}, fade = { fadeIn = 0.15, fadeOut = 0.40, delay = 0.50 } }
  for k, d in pairs(CONTEXT_DEFAULTS) do p.contexts[k] = { on = d.on, value = d.value } end
  return p
end

local MAX_FRAMES = 400
local function ValidName(n)
  return type(n) == "string" and #n > 0 and #n <= 96 and n:match("^[%w_]+$") ~= nil
end
OP.ValidName = ValidName

local function Num(v, def, lo, hi)
  v = tonumber(v)
  if not v or v ~= v then return def end   -- v ~= v : NaN
  if v < lo then return lo elseif v > hi then return hi end
  return v
end

-- Renvoie un profil propre (nouvelle table), quelle que soit l'entree : sert
-- au chargement de la sauvegarde ET a l'import d'un code colle par un joueur.
function OP.SanitizeProfile(p)
  local out = OP.DefaultProfile()
  if type(p) ~= "table" then return out end
  out.master = Num(p.master, 1, 0, 1)
  if type(p.fade) == "table" then
    out.fade.fadeIn  = Num(p.fade.fadeIn,  out.fade.fadeIn,  0, 3)
    out.fade.fadeOut = Num(p.fade.fadeOut, out.fade.fadeOut, 0, 3)
    out.fade.delay   = Num(p.fade.delay,   out.fade.delay,   0, 5)
  end
  if type(p.contexts) == "table" then
    for k, d in pairs(CONTEXT_DEFAULTS) do
      local c = p.contexts[k]
      if type(c) == "table" then
        out.contexts[k] = { on = c.on == true, value = Num(c.value, d.value, 0, 1) }
      end
    end
  end
  if type(p.frames) == "table" then
    local n = 0
    for name, e in pairs(p.frames) do
      if n >= MAX_FRAMES then break end
      if ValidName(name) and type(e) == "table" then
        out.frames[name] = {
          alpha = Num(e.alpha, 1, 0, 1),
          hover = e.hover == true,
          ctx   = e.ctx ~= false,        -- par defaut, la frame suit les contextes
          force = e.force == true,       -- frame geree par ElvUI / EllesmereUI : forcee ?
        }
        n = n + 1
      end
    end
  end
  return out
end

function OP.CopyTable(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = OP.CopyTable(v) end
  return c
end

-- ============================================================================
-- ETAT PAR FRAME (cles faibles : une frame detruite ne reste pas en memoire)
-- ============================================================================
local state  = setmetatable({}, { __mode = "k" })  -- [frame] = { name, base, cur, target, active, hover }
local byName = {}                                   -- [name] = frame actuellement attachee
OP.pending   = {}                                   -- [name] = true : frame pas encore creee
OP.state, OP.byName = state, byName

OP.activeContext   = nil     -- cle de contexte actif (Context.lua) ou nil
OP.screenshot      = false   -- mode capture d'ecran
OP.blockedInCombat = false   -- le client a refuse un SetAlpha protege en combat
local pendingCombat = {}     -- [frame] = true : a pousser a la sortie de combat

function OP.DB() return OpacityDB end
function OP.Profile() return OpacityDB and OpacityDB.profile end

-- La suite a-t-elle desactive Opacity ? (case decochee dans /ts modules)
function OP.SuiteDisabled()
  local TS = _G.TibiSuite
  if not (TS and TS.RegisterModule) then return false end
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return false end
  if TibiSuiteDB.enabledModules.Opacity then return false end
  -- Premier login apres l'ajout du module : le core va l'activer (migration
  -- ponctuelle, voir TibiSuiteCore.lua). On ne le considere pas decoche.
  return TibiSuiteDB.opacityEnableMigrated == true
end

function OP.IsRunning()
  return OpacityDB and OpacityDB.enabled and not OP.SuiteDisabled()
end

-- Sous 12.x, UIParent contient des frames INTERDITES aux addons : le simple
-- acces a une de leurs methodes leve une erreur Lua. Tout test passe donc sous
-- pcall, et IsForbidden est verifie AVANT toute autre lecture.
local function CheckUsable(f)
  if f:IsForbidden() then return false end
  return type(f.SetAlpha) == "function" and type(f.GetAlpha) == "function"
end
local function IsUsableFrame(f)
  if type(f) ~= "table" then return false end
  local ok, usable = pcall(CheckUsable, f)
  return ok and usable or false
end
OP.IsUsableFrame = IsUsableFrame

-- ============================================================================
-- DEUX MODES D'APPLICATION
--   "frame"    : SetAlpha sur la frame elle-meme (base * facteur). Mode par
--                defaut, parfait face a un tiers qui POSE une valeur.
--   "children" : SetAlpha sur ses enfants directs et ses regions (textures,
--                textes). La frame elle-meme est rendue a son proprietaire.
--
-- POURQUOI (bug reel, carte du monde, 2026-09-24) : certains fondus LISENT
-- l'alpha courant a chaque image (GetAlpha), avancent d'un pas vers leur
-- cible et le reecrivent. C'est le cas du fondu "carte en mouvement" de
-- Blizzard, et probablement des fondus d'EllesmereUI / ElvUI. En mode
-- "frame", ils relisaient notre valeur deja reduite, et la multiplication se
-- repetait image apres image : la carte s'enfoncait vers 5 % et ne remontait
-- plus. Des qu'on detecte ce motif (rafale d'ecritures externes pendant qu'on
-- attenue), la frame bascule en mode "children" pour la session : le fondu
-- du proprietaire ne voit plus jamais notre facteur, et l'effet visuel est
-- identique (l'alpha d'un enfant se multiplie par celui de son parent).
--
-- Exception : les frames qui DESSINENT elles-memes leur contenu (minicarte,
-- modeles 3D, champs de saisie...) restent en mode "frame", sinon elles ne
-- seraient plus attenuees du tout.
-- ============================================================================
local applying = false
local objState = setmetatable({}, { __mode = "k" })  -- [enfant/region] = { base, owner }

local STORM_WINDOW, STORM_COUNT = 0.5, 8
local NATIVE_TYPES = {
  Minimap = true, EditBox = true, MessageFrame = true, SimpleHTML = true,
  Model = true, PlayerModel = true, DressUpModel = true, CinematicModel = true,
  TabardModel = true, ModelScene = true, Cooldown = true, MovieFrame = true,
  ColorSelect = true, Browser = true, OffScreenFrame = true,
}

local function SetAlphaRaw(obj, a)
  applying = true
  pcall(obj.SetAlpha, obj, Clamp01(a))
  applying = false
end

local function Blockable(frame)
  return OP.blockedInCombat and InCombatLockdown() and frame.IsProtected and frame:IsProtected()
end

function OP.Push(frame)
  local st = state[frame]
  if not st then return end
  if Blockable(frame) then pendingCombat[frame] = true; return end
  local cur = st.cur or 1
  if st.mode == "children" then
    for obj, os in pairs(st.objs) do SetAlphaRaw(obj, (os.base or 1) * cur) end
  else
    SetAlphaRaw(frame, (st.base or 1) * cur)
  end
end

-- Crochet "lire" sur un enfant / une region d'une frame en mode "children".
local function OnObjSetAlpha(obj, a)
  if applying then return end
  local os = objState[obj]
  if not os then return end
  os.base = tonumber(a) or 1
  local st = os.owner and state[os.owner]
  if st and st.active and st.mode == "children" and st.objs[obj] and (st.cur or 1) ~= 1 then
    if not Blockable(os.owner) then SetAlphaRaw(obj, os.base * st.cur) end
  end
end

-- Recense les enfants directs et les regions (a rappeler quand la frame
-- reapparait : une fenetre peut creer ses elements a sa premiere ouverture).
function OP.CollectObjs(frame)
  local st = state[frame]
  if not (st and st.mode == "children") then return end
  local function Add(obj)
    if st.objs[obj] or not IsUsableFrame(obj) then return end
    local os = objState[obj]
    if not os then
      os = { base = obj:GetAlpha() or 1 }
      objState[obj] = os
      hooksecurefunc(obj, "SetAlpha", OnObjSetAlpha)
    end
    os.owner = frame
    st.objs[obj] = os
  end
  pcall(function() for _, c in ipairs({ frame:GetChildren() }) do Add(c) end end)
  pcall(function() for _, r in ipairs({ frame:GetRegions() }) do Add(r) end end)
end

local function SwitchToChildren(frame, st)
  local okType, kind = pcall(frame.GetObjectType, frame)
  if okType and NATIVE_TYPES[kind] then st.noSwitch = true; return false end
  st.mode, st.objs = "children", {}
  SetAlphaRaw(frame, st.base or 1)   -- la frame retourne a son proprietaire
  OP.CollectObjs(frame)
  OP.Push(frame)
  return true
end

-- Crochet "lire" sur la frame : un tiers vient de changer l'alpha -> nouvelle base.
local function OnExternalSetAlpha(frame, a)
  if applying then return end
  local st = state[frame]
  if not st then return end
  st.base = tonumber(a) or 1
  if st.mode == "children" or not st.active or (st.cur or 1) == 1 then return end
  if not st.noSwitch then
    local now = GetTime()
    if not st.stormStart or now - st.stormStart > STORM_WINDOW then st.stormStart, st.stormCount = now, 0 end
    st.stormCount = st.stormCount + 1
    if st.stormCount >= STORM_COUNT and SwitchToChildren(frame, st) then return end
  end
  OP.Push(frame)
end

local function Attach(name, frame)
  local st = state[frame]
  if not st then
    st = { name = name, base = frame:GetAlpha() or 1, cur = 1, target = 1, mode = "frame" }
    state[frame] = st
    -- hooksecurefunc ne s'enleve jamais : quand la frame n'est plus
    -- controlee, le crochet se contente de memoriser la base (st.active=false).
    hooksecurefunc(frame, "SetAlpha", OnExternalSetAlpha)
  end
  byName[name] = frame
  return st
end

-- Rend la frame a son proprietaire : plus aucun effet d'Opacity (le mode
-- "children" est conserve pour la session : si la frame est reactivee, son
-- fondu ne doit pas retomber dans le piege).
local function Release(frame)
  local st = state[frame]
  if not st then return end
  st.active, st.hover = false, false
  st.cur, st.target = 1, 1
  pendingCombat[frame] = nil
  OP.Push(frame)
end

-- ============================================================================
-- CIBLE D'UNE FRAME
-- ============================================================================
-- Facteur "au repos" (hors survol) d'une entree du profil.
function OP.RestFactor(entry)
  local p = OP.Profile()
  local v = entry.alpha
  local ctx = OP.activeContext
  if ctx and entry.ctx and p.contexts[ctx] and p.contexts[ctx].on then
    v = p.contexts[ctx].value
  end
  return Clamp01(v * p.master)
end

-- La frame est-elle geree par une suite (ElvUI / EllesmereUI) et non forcee ?
local function Blocked(name, entry)
  if entry.force then return false end
  return OP.ManagedBy and OP.ManagedBy(name) ~= nil
end

-- ============================================================================
-- RESOLUTION : relie chaque nom du profil a sa frame (si elle existe deja)
-- ============================================================================
function OP.Resolve()
  local p = OP.Profile()
  if not p then return end
  local running = OP.IsRunning()

  -- Frames qui ne sont plus dans le profil (retirees, import, prereglage) : on rend la main.
  for name, frame in pairs(byName) do
    if not p.frames[name] or not running then
      Release(frame)
      if not p.frames[name] then byName[name] = nil end
    end
  end
  wipe(OP.pending)
  if not running then
    if OP.WakeDriver then OP.WakeDriver() end
    return
  end

  for name, entry in pairs(p.frames) do
    local frame = _G[name]
    if IsUsableFrame(frame) then
      local st = Attach(name, frame)
      if Blocked(name, entry) then
        if st.active then Release(frame) end
      else
        st.active = true
        st.hover  = entry.hover
        st.target = OP.RestFactor(entry)
      end
    else
      OP.pending[name] = true
    end
  end
  if OP.WakeDriver then OP.WakeDriver(true) end
end

-- Recalcule seulement les cibles (contexte, maitre, reglage) sans re-resoudre.
function OP.Refresh()
  local p = OP.Profile()
  if not p then return end
  for name, frame in pairs(byName) do
    local st, entry = state[frame], p.frames[name]
    if st and st.active and entry then
      st.hover  = entry.hover
      st.target = OP.RestFactor(entry)
    end
  end
  if OP.WakeDriver then OP.WakeDriver(true) end
  if OP.OnRefresh then OP.OnRefresh() end
end

-- Remplace tout le profil (import, prereglage) en gardant une copie pour Annuler.
function OP.ReplaceProfile(newProfile, keepUndo)
  local db = OpacityDB
  if keepUndo ~= false then db.undo = OP.CopyTable(db.profile) end
  db.profile = OP.SanitizeProfile(newProfile)
  OP.Resolve()
  if OP.OnRefresh then OP.OnRefresh() end
end

function OP.Undo()
  local db = OpacityDB
  if type(db.undo) ~= "table" then return false end
  local cur = db.profile
  db.profile = OP.SanitizeProfile(db.undo)
  db.undo = cur
  OP.Resolve()
  if OP.OnRefresh then OP.OnRefresh() end
  return true
end

-- ============================================================================
-- API D'EDITION (utilisee par UI.lua, Picker.lua, Profiles.lua)
-- ============================================================================
function OP.AddFrame(name, alpha)
  if not ValidName(name) then return false end
  local p = OP.Profile()
  if p.frames[name] then return false end
  p.frames[name] = { alpha = Clamp01(alpha or 0.7), hover = false, ctx = true, force = false }
  OP.Resolve()
  if OP.OnRefresh then OP.OnRefresh() end
  return true
end

function OP.RemoveFrame(name)
  local p = OP.Profile()
  if not p.frames[name] then return end
  p.frames[name] = nil
  OP.Resolve()
  if OP.OnRefresh then OP.OnRefresh() end
end

-- Modifie un champ d'une entree ; les champs structurels re-resolvent.
function OP.SetFrameField(name, field, value)
  local e = OP.Profile().frames[name]
  if not e then return end
  if field == "alpha" then e.alpha = Clamp01(value) else e[field] = value and true or false end
  if field == "force" then OP.Resolve() else OP.Refresh() end
end

function OP.SetMaster(v)
  local p = OP.Profile()
  p.master = math.floor(Clamp01(v) * 20 + 0.5) / 20   -- pas de 5 %
  OP.Refresh()
end

function OP.SetEnabled(on)
  OpacityDB.enabled = on and true or false
  OP.Resolve()
  if OP.OnRefresh then OP.OnRefresh() end
end

-- MODE CAPTURE D'ECRAN : masque TOUTE l'interface (alpha de UIParent a 0),
-- pas seulement les fenetres de la liste (retour en jeu 2026-09-24 : barres,
-- discussion et compteurs restaient visibles). Rien n'est cache ni detruit :
-- l'alpha d'origine est memorise et rendu au retour. UIParent est une frame
-- protegee : on refuse d'entrer en mode capture en combat, et on en sort de
-- force des l'entree en combat (PLAYER_REGEN_DISABLED), pour ne jamais
-- risquer une interface invisible impossible a rendre pendant un combat.
--
-- Sortie garantie : l'interface invisible masque aussi la fenetre Opacity et
-- son bouton. Echap reaffiche tout, via UISpecialFrames (mecanisme natif, meme
-- patron que la pipette : aucun code a nous sur la touche, pas de OnHide).
local savedUIAlpha
local shotGuard, shotWatch

function OP.SetScreenshot(on)
  on = on and true or false
  if on == OP.screenshot then return true end
  if on then
    if InCombatLockdown() then
      OP.Print(T("MSG_SHOT_COMBAT", "le mode capture d'écran n'est pas disponible en combat."))
      return false
    end
    if not shotGuard then
      shotGuard = CreateFrame("Frame", "OpacityShotGuard", UIParent)
      shotGuard:SetSize(1, 1)
      shotGuard:Hide()
      tinsert(UISpecialFrames, "OpacityShotGuard")
      shotWatch = CreateFrame("Frame")
      shotWatch:Hide()
      shotWatch:SetScript("OnUpdate", function(self)
        if OP.screenshot and not shotGuard:IsShown() then Opacity_ToggleScreenshot() end
        if not OP.screenshot then self:Hide() end
      end)
    end
    savedUIAlpha = UIParent:GetAlpha() or 1
    OP.screenshot = true
    SetAlphaRaw(UIParent, 0)
    shotGuard:Show(); shotWatch:Show()
  else
    OP.screenshot = false
    if shotGuard then shotGuard:Hide() end
    SetAlphaRaw(UIParent, savedUIAlpha or 1)
    savedUIAlpha = nil
  end
  OP.Refresh()
  return true
end

function OP.SetContext(key)
  if OP.activeContext == key then return end
  OP.activeContext = key
  OP.Refresh()
end

-- ============================================================================
-- GLOBALES PUBLIQUES (raccourcis clavier, catalogue TibiSuite)
-- ============================================================================
function Opacity_MasterStep(delta)
  if not OP.Profile() then return end
  OP.SetMaster(OP.Profile().master + (tonumber(delta) or 0))
  OP.Flash(T("FLASH_MASTER", "curseur maître") .. " " .. math.floor(OP.Profile().master * 100 + 0.5) .. " %")
end

function Opacity_ToggleScreenshot()
  if not OP.SetScreenshot(not OP.screenshot) then return end
  OP.Flash(OP.screenshot and T("FLASH_SHOT_ON", "mode capture d'écran activé")
                          or T("FLASH_SHOT_OFF", "mode capture d'écran terminé"))
end

function Opacity_ToggleEnabled()
  if not OpacityDB then return end
  OP.SetEnabled(not OpacityDB.enabled)
  OP.Flash(OpacityDB.enabled and T("FLASH_ON", "activé") or T("FLASH_OFF", "suspendu (fenêtres rendues à leur opacité d'origine)"))
end

-- ============================================================================
-- EVENEMENTS
-- ============================================================================
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("ADDON_ACTION_BLOCKED")
ev:RegisterEvent("SCREENSHOT_SUCCEEDED")
ev:RegisterEvent("SCREENSHOT_FAILED")

local pendingTicker
local function EnsurePendingTicker()
  if pendingTicker then return end
  -- Certaines frames (fenetres Blizzard a la demande, addons qui construisent
  -- leur interface tard) n'existent pas encore : on repasse toutes les 5 s
  -- tant qu'il en reste. Cout : quelques lectures de _G, negligeable.
  pendingTicker = C_Timer.NewTicker(5, function()
    if next(OP.pending) and OP.IsRunning() then OP.Resolve() end
  end)
end

local started = false
ev:SetScript("OnEvent", function(_, event, arg1, arg2)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then
      OpacityDB = type(OpacityDB) == "table" and OpacityDB or {}
      local db = OpacityDB
      db.schema = 1
      if db.enabled  == nil then db.enabled  = true end
      if db.shotAuto == nil then db.shotAuto = true end
      db.profile = OP.SanitizeProfile(db.profile)
    elseif started and next(OP.pending) then
      -- Un addon (ou une fenetre Blizzard a la demande) vient d'arriver :
      -- ses frames existent peut-etre maintenant. Differe d'un tick.
      C_Timer.After(0, OP.Resolve)
    end

  elseif event == "PLAYER_LOGIN" then
    -- Differe d'un tick : laisse le core TibiSuite faire sa migration
    -- d'activation avant qu'on lise son etat (OP.SuiteDisabled).
    C_Timer.After(0, function()
      started = true
      if OP.DetectSuites then OP.DetectSuites() end
      if OP.UpdateContext then OP.UpdateContext() end
      OP.Resolve()
      EnsurePendingTicker()
      -- Deuxieme passe : beaucoup d'addons construisent leur UI sur PLAYER_LOGIN
      -- ou PLAYER_ENTERING_WORLD, apres nous.
      C_Timer.After(3, OP.Resolve)
    end)

  elseif event == "ADDON_ACTION_BLOCKED" then
    if arg1 == ADDON and not OP.blockedInCombat and InCombatLockdown() then
      OP.blockedInCombat = true
      OP.Print(T("MSG_BLOCKED", "le jeu refuse de changer l'opacité des cadres protégés en combat. "
        .. "Ces changements seront appliqués à la sortie du combat (fonction bloquée : ") .. tostring(arg2) .. ").")
    end

  elseif event == "PLAYER_REGEN_ENABLED" then
    for frame in pairs(pendingCombat) do
      pendingCombat[frame] = nil
      OP.Push(frame)
    end

  elseif event == "PLAYER_REGEN_DISABLED" then
    -- Securite : jamais d'interface invisible en combat.
    if OP.screenshot then OP.SetScreenshot(false) end

  elseif event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED" then
    -- Mode capture : la capture est prise (ou a echoue), on reaffiche.
    if OP.screenshot and OpacityDB and (OpacityDB.shotAuto or event == "SCREENSHOT_FAILED") then
      C_Timer.After(0.3, function() if OP.screenshot then Opacity_ToggleScreenshot() end end)
    end
  end
end)
