--[[============================================================================
  Anchor - Core.lua
  ---------------------------------------------------------------------------
  Deplacer les fenetres d'origine du jeu (Blizzard), avec magnetisme, grille,
  annulation, disposition par resolution d'ecran et par personnage.

  Ce fichier : espace de noms, sauvegarde TibiAnchorDB, dispositions, calcul des
  ancres, garde-fous (frames protegees, interdites, valeurs secretes).

  REGLES DE SURETE (heritees des lectures de BlizzMove, ElvUI, EllesmereUI) :
    - jamais de SetScript sur une frame Blizzard : HookScript et
      hooksecurefunc seulement ;
    - jamais de frame protegee, interdite ou a ancrage restreint : refus net
      (pas de poignee securisee dans ce prototype) ;
    - aucune ecriture a l'interieur d'un appel Blizzard : un crochet sur
      SetPoint ne fait que NOTER la frame, le placement a lieu depuis notre
      propre OnUpdate (Engine.lua) ;
    - jamais de cle maison ecrite sur une frame Blizzard : l'etat vit dans
      des tables externes a cles faibles ;
    - le drapeau SetUserPlaced est remis tel qu'on l'a trouve, pour que le
      jeu ne garde pas la position dans son propre fichier de disposition.
  Valide en jeu par Tibiscui le 2026-11-10 (7.5.0).
============================================================================]]

local ADDON, AN = ...

AN.ACCENT = { 0.431, 0.447, 0.941 }   -- indigo boussole #6E72F0 (identite Anchor)
AN.LOGO   = "Interface\\AddOns\\Anchor\\medias\\Logo"
AN.KEY    = "Anchor"

AN.L = AN.L or {}
function AN.T(key, fr) return AN.L[key] or fr end

local function Hex()
  local a = AN.ACCENT
  return string.format("|cFF%02X%02X%02X", math.floor(a[1]*255+0.5), math.floor(a[2]*255+0.5), math.floor(a[3]*255+0.5))
end
AN.Hex = Hex
function AN.Print(msg) print(Hex() .. "Anchor|r : " .. tostring(msg)) end
function AN.Flash(msg)
  if UIErrorsFrame and UIErrorsFrame.AddMessage then
    local a = AN.ACCENT
    UIErrorsFrame:AddMessage("Anchor : " .. msg, a[1], a[2], a[3])
  end
end

-- ============================================================================
-- VALEURS SECRETES (12.x) ET REFUS
-- Sous Midnight, certaines lectures (GetPoint, IsProtected...) peuvent
-- renvoyer une valeur « secrete » illisible pour un addon. Toute lecture qui
-- sert a un calcul passe par Safe().
-- ============================================================================
local issecret = _G.issecretvalue or function() return false end

function AN.Safe(...)
  for i = 1, select("#", ...) do
    if issecret((select(i, ...))) then return false end
  end
  return true
end
local Safe = AN.Safe

-- Vrai si on ne doit PAS toucher a cette frame : absente, pas une frame,
-- interdite, protegee ou a ancrage restreint. Une reponse secrete vaut oui.
function AN.Refused(f)
  if type(f) ~= "table" or type(f.GetObjectType) ~= "function" then return true end
  local ok, v = pcall(f.IsForbidden, f)
  if not ok or issecret(v) or v then return true end
  ok, v = pcall(f.IsProtected, f)
  if not ok or issecret(v) or v then return true end
  if f.IsAnchoringRestricted then
    ok, v = pcall(f.IsAnchoringRestricted, f)
    if not ok or issecret(v) or v then return true end
  end
  return false
end

-- Etat par frame, hors de la frame (cles faibles : rien n'empeche le ramasse-miettes).
AN.state = setmetatable({}, { __mode = "k" })
function AN.St(f)
  local s = AN.state[f]
  if not s then s = {}; AN.state[f] = s end
  return s
end

-- ============================================================================
-- SAUVEGARDE
-- TibiAnchorDB.layouts[cleDisposition][cleResolution][nomFenetre] = {p, x, y, s}
--   cleDisposition : "*" (tout le compte) ou "Nom-Royaume" (personnage)
--   cleResolution  : "1920x1080" si « une disposition par resolution », sinon "*"
--   p : point d'ancrage (TOPLEFT, CENTER...) sur UIParent, meme point des deux cotes
--   x, y : decalage en unites de UIParent ; s : echelle (nil = celle du jeu)
-- ============================================================================
local DEFAULTS = {
  enabled      = true,
  modifier     = "none",   -- "none" | "shift" | "ctrl" : touche a tenir pour deplacer
  snap         = true,     -- magnetisme
  snapDist     = 12,
  snapWindows  = true,     -- s'aimanter aussi aux autres fenetres
  guides       = true,     -- reperes visuels pendant le deplacement
  grid         = false,    -- grille pendant le deplacement
  gridSize     = 32,
  wheelScale   = true,     -- Ctrl + molette : taille de la fenetre survolee
  clamp        = true,     -- garder les fenetres dans l'ecran
  perResolution = true,
  force        = false,    -- passer outre BlizzMove / MoveAny / Shifter (deconseille)
  minimapAngle = 200,
}

function AN.CharKey()
  local n = UnitName and UnitName("player") or "?"
  local r = GetRealmName and GetRealmName() or "?"
  return tostring(n) .. "-" .. tostring(r)
end

function AN.ResKey()
  if not (TibiAnchorDB and TibiAnchorDB.perResolution) then return "*" end
  if GetPhysicalScreenSize then
    local ok, w, h = pcall(GetPhysicalScreenSize)
    if ok and Safe(w, h) and tonumber(w) and tonumber(h) then
      return string.format("%dx%d", math.floor(w + 0.5), math.floor(h + 0.5))
    end
  end
  return "*"
end

function AN.LayoutKey()
  if TibiAnchorDB and TibiAnchorDB.charLayout and TibiAnchorDB.charLayout[AN.CharKey()] then return AN.CharKey() end
  return "*"
end

-- Table des positions de la disposition active (creee a la demande).
function AN.Positions()
  local db = TibiAnchorDB
  db.layouts = db.layouts or {}
  local lk, rk = AN.LayoutKey(), AN.ResKey()
  db.layouts[lk] = db.layouts[lk] or {}
  db.layouts[lk][rk] = db.layouts[lk][rk] or {}
  return db.layouts[lk][rk]
end

function AN.GetPos(name)
  if not TibiAnchorDB then return nil end
  local p = AN.Positions()[name]
  if type(p) == "table" and p.p then return p end
  return nil
end

function AN.SetPos(name, pos)
  AN.Positions()[name] = pos
end

function AN.CopyPos(p)
  if type(p) ~= "table" then return nil end
  return { p = p.p, x = p.x, y = p.y, s = p.s }
end

function AN.InitDB()
  TibiAnchorDB = type(TibiAnchorDB) == "table" and TibiAnchorDB or {}
  for k, v in pairs(DEFAULTS) do
    if TibiAnchorDB[k] == nil then TibiAnchorDB[k] = v end
  end
  TibiAnchorDB.layouts    = type(TibiAnchorDB.layouts) == "table" and TibiAnchorDB.layouts or {}
  TibiAnchorDB.charLayout = type(TibiAnchorDB.charLayout) == "table" and TibiAnchorDB.charLayout or {}
  TibiAnchorDB.version    = 1
end

-- ============================================================================
-- ACTIVATION
-- Meme regle que Standby : decoche dans TibiSuite = inactif ; table absente
-- (premiere installation ou mode autonome) = actif.
-- ============================================================================
function AN.SuiteDisabled()
  local TS = _G.TibiSuite
  if not (TS and TS.RegisterModule) then return false end
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return false end
  return not TibiSuiteDB.enabledModules[AN.KEY]
end

function AN.IsRunning()
  return TibiAnchorDB and TibiAnchorDB.enabled and not AN.SuiteDisabled()
end

-- ============================================================================
-- GEOMETRIE
-- Rect d'une frame en unites de UIParent : gauche, bas, largeur, hauteur.
-- ============================================================================
function AN.RectOf(f)
  local ok, l, b, w, h = pcall(f.GetRect, f)
  if not ok or not Safe(l, b, w, h) or not (l and b and w and h) then return nil end
  local okS, es = pcall(f.GetEffectiveScale, f)
  if not okS or not Safe(es) or not es then return nil end
  local k = es / UIParent:GetEffectiveScale()
  return l * k, b * k, w * k, h * k
end

-- Ancre la plus robuste pour un rect : le coin ou le bord le plus proche
-- (tiers de l'ecran). Une fenetre posee pres du bord droit reste collee au
-- bord droit si la resolution change.
function AN.AnchorFromRect(l, b, w, h)
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  local cx, cy = l + w / 2, b + h / 2
  local hp, x, vp, y
  if cx < W / 3 then hp, x = "LEFT", l
  elseif cx > W * 2 / 3 then hp, x = "RIGHT", l + w - W
  else hp, x = "", cx - W / 2 end
  if cy < H / 3 then vp, y = "BOTTOM", b
  elseif cy > H * 2 / 3 then vp, y = "TOP", b + h - H
  else vp, y = "", cy - H / 2 end
  local p = vp .. hp
  if p == "" then p = "CENTER" end
  return p, math.floor(x * 10 + 0.5) / 10, math.floor(y * 10 + 0.5) / 10
end

-- Pose une frame sur une position sauvegardee. Renvoie true si c'est fait.
-- Les variantes « Base » (mode Edition) sont preferees quand elles existent.
function AN.Place(f, pos)
  if not (f and pos and pos.p) or AN.Refused(f) then return false end
  local st = AN.St(f)
  st.applying = true
  local ok = pcall(function()
    if pos.s and TibiAnchorDB.wheelScale then
      local setScale = f.SetScaleBase or f.SetScale
      setScale(f, pos.s)
    end
    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local clear = f.ClearAllPointsBase or f.ClearAllPoints
    local setPoint = f.SetPointBase or f.SetPoint
    clear(f)
    setPoint(f, pos.p, UIParent, pos.p, (pos.x or 0) / k, (pos.y or 0) / k)
  end)
  st.applying = false
  return ok
end

-- Note l'ancre que Blizzard a posee (pour la remettre au reset).
function AN.CaptureBlizzAnchor(f)
  local st = AN.St(f)
  if st.applying then return end
  local ok, n = pcall(f.GetNumPoints, f)
  if not ok or not Safe(n) or n ~= 1 then return end
  local ok2, p, r, rp, x, y = pcall(f.GetPoint, f, 1)
  if not ok2 or not Safe(p, r, rp, x, y) then return end
  st.blizz = { p, r or f:GetParent(), rp, x, y }
end

function AN.RestoreBlizzAnchor(f)
  local st = AN.St(f)
  local a = st.blizz
  if not a or AN.Refused(f) then return false end
  st.applying = true
  local ok = pcall(function()
    local clear = f.ClearAllPointsBase or f.ClearAllPoints
    local setPoint = f.SetPointBase or f.SetPoint
    clear(f)
    setPoint(f, a[1], a[2], a[3], a[4], a[5])
  end)
  st.applying = false
  return ok
end
