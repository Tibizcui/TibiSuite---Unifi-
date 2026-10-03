--[[============================================================================
  Opacity - Profiles.lua
  ---------------------------------------------------------------------------
  Export / import de profil et prereglages en un clic.

  FORMAT DU CODE : "OPA1:<somme de controle>:<base64>"
    - charge utile : le profil serialise par un format maison minimaliste
      (n = nombre, s = chaine avec longueur, T/F = booleen, {} = table) ;
    - compresse en LZW puis encode en Base64 (Libs/LZW.lua, copie de Stats) ;
    - somme djb2 de la charge utile (en decimal) : un collage tronque ou
      abime est refuse proprement au lieu d'appliquer un profil casse.
  Le lecteur n'execute JAMAIS le texte colle (pas de loadstring) : il le
  decode caractere par caractere, puis OP.SanitizeProfile borne chaque valeur.

  Import et prereglages REMPLACENT le profil courant, mais une copie est
  gardee : le bouton "Annuler" la restaure (OP.Undo, Core.lua).

  PROFILS MULTIPLES (schema 2, OpacityDB.profiles) : creer, copier,
  renommer, supprimer, et lier un profil a un personnage ou a une de ses
  specialisations. Au login et a chaque changement de specialisation, le
  profil lie est choisi tout seul (specialisation > personnage > dernier
  profil utilise). Les liens sont stockes dans OpacityDB.assign :
    char["Nom-Royaume"] = profil, spec["Nom-Royaume:idSpe"] = profil.
============================================================================]]

local ADDON, OP = ...
local T = OP.T

local PREFIX = "OPA1"

-- ============================================================================
-- SERIALISATION
-- ============================================================================
local function Ser(v, out)
  local t = type(v)
  if t == "number" then
    out[#out + 1] = "n" .. string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", "") .. ";"
  elseif t == "string" then
    out[#out + 1] = "s" .. #v .. ":" .. v
  elseif t == "boolean" then
    out[#out + 1] = v and "T" or "F"
  elseif t == "table" then
    out[#out + 1] = "{"
    for k, val in pairs(v) do
      local kt = type(k)
      if kt == "string" or kt == "number" then Ser(k, out); Ser(val, out) end
    end
    out[#out + 1] = "}"
  end
end

local MAX_DEPTH, MAX_STR = 8, 200

local function Parse(s, pos, depth)
  local c = s:sub(pos, pos)
  if c == "n" then
    local e = s:find(";", pos, true)
    local v = e and tonumber(s:sub(pos + 1, e - 1))
    if not v then error("nombre") end
    return v, e + 1
  elseif c == "s" then
    local colon = s:find(":", pos, true)
    local len = colon and tonumber(s:sub(pos + 1, colon - 1))
    if not len or len < 0 or len > MAX_STR then error("chaine") end
    local str = s:sub(colon + 1, colon + len)
    if #str ~= len then error("chaine tronquee") end
    return str, colon + len + 1
  elseif c == "T" then return true, pos + 1
  elseif c == "F" then return false, pos + 1
  elseif c == "{" then
    if depth >= MAX_DEPTH then error("profondeur") end
    local t = {}
    pos = pos + 1
    while s:sub(pos, pos) ~= "}" do
      if pos > #s then error("table non fermee") end
      local k, v
      k, pos = Parse(s, pos, depth + 1)
      if type(k) ~= "string" and type(k) ~= "number" then error("cle") end
      v, pos = Parse(s, pos, depth + 1)
      t[k] = v
    end
    return t, pos + 1
  end
  error("jeton inconnu")
end

local function Checksum(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
  return string.format("%.0f", h)   -- decimal : robuste quel que soit le type numerique
end

-- ============================================================================
-- EXPORT / IMPORT
-- ============================================================================
function OP.ExportCode()
  local out = {}
  Ser({ v = 1, profile = OP.Profile() }, out)
  local payload = table.concat(out)
  return PREFIX .. ":" .. Checksum(payload) .. ":" .. OP.LZW.Base64Encode(OP.LZW.Compress(payload))
end

-- Renvoie ok, message.
function OP.ImportCode(text)
  text = tostring(text or ""):gsub("%s+", "")
  local sum, b64 = text:match("^" .. PREFIX .. ":(%d+):(.+)$")
  if not sum then
    return false, T("IMP_FORMAT", "ce n'est pas un code Opacity (il doit commencer par OPA1:).")
  end
  local ok, payload = pcall(function() return OP.LZW.Decompress(OP.LZW.Base64Decode(b64)) end)
  if not ok or not payload or payload == "" then
    return false, T("IMP_DECODE", "code illisible (copie incomplète ?).")
  end
  if Checksum(payload) ~= sum then
    return false, T("IMP_CHECKSUM", "code abîmé ou tronqué (la somme de contrôle ne correspond pas).")
  end
  local okP, data = pcall(Parse, payload, 1, 0)
  if not okP or type(data) ~= "table" or type(data.profile) ~= "table" then
    return false, T("IMP_PARSE", "contenu du code invalide.")
  end
  OP.ReplaceProfile(data.profile)
  local n = 0
  for _ in pairs(OP.Profile().frames) do n = n + 1 end
  return true, string.format(T("IMP_OK", "profil importé : %d fenêtre(s). « Annuler » restaure l'ancien."), n)
end

-- ============================================================================
-- PREREGLAGES
-- Ils partent du profil courant (les fenetres deja reglees sont conservees),
-- ajustent un jeu de frames d'interface et les contextes. Les frames gerees
-- par ElvUI / EllesmereUI sont sautees : c'est la suite qui les pilote.
-- ============================================================================
local function FirstExisting(names)
  for _, n in ipairs(names) do
    if OP.IsUsableFrame(_G[n]) then return n end
  end
  return names[1]
end

-- { nom ou {variantes}, opacite, survol, suit les contextes, groupe lie }
local function SetMany(p, list)
  for _, it in ipairs(list) do
    local name = type(it[1]) == "table" and FirstExisting(it[1]) or it[1]
    if not OP.ManagedBy(name) then
      p.frames[name] = { alpha = it[2], hover = it[3] == true, ctx = it[4] ~= false, force = false, group = it[5] }
    end
  end
end

local function Contexts(p, map)
  for key, c in pairs(p.contexts) do
    local v = map[key]
    if v then p.contexts[key] = { on = true, value = v } else c.on = false end
  end
end

-- Groupes lies des prereglages : 1 = barres d'action, 2 = menus, 3 = discussion.
local G_BARS, G_MENUS, G_CHAT = 1, 2, 3

local BAR1 = { "MainActionBar", "MainMenuBar" }

OP.PRESETS = {
  {
    key = "immersion",
    label = T("PRE_IMMERSION", "Immersion"),
    desc = T("PRE_IMMERSION_D", "Interface discrète hors combat (35 %), elle réapparaît au survol et à 100 % en combat. "
      .. "Très discrète en monture, invisible quand vous êtes ABS."),
    build = function(p)
      SetMany(p, {
        { BAR1, 0.35, true, true, G_BARS }, { "MultiBarBottomLeft", 0.35, true, true, G_BARS },
        { "MultiBarBottomRight", 0.35, true, true, G_BARS },
        { "MultiBarRight", 0.25, true, true, G_BARS }, { "MultiBarLeft", 0.25, true, true, G_BARS },
        { "MinimapCluster", 0.35, true }, { "ObjectiveTrackerFrame", 0.35, true },
        { "ChatFrame1", 0.35, true, true, G_CHAT }, { "GeneralDockManager", 0.35, true, true, G_CHAT },
        { "BuffFrame", 0.50, true }, { "MicroMenuContainer", 0.20, true, true, G_MENUS },
        { "BagsBar", 0.20, true, true, G_MENUS },
        { "MainStatusTrackingBarContainer", 0.35, true },
      })
      p.master = 1
      Contexts(p, { combat = 1.00, mount = 0.15, afk = 0.00 })
    end,
  },
  {
    key = "raid",
    label = T("PRE_RAID", "Raid"),
    desc = T("PRE_RAID_D", "Tout à 100 % en instance, en raid et en combat, sauf la discussion (60 %) et le suivi "
      .. "des objectifs (50 %) qui restent discrets et réapparaissent au survol."),
    build = function(p)
      SetMany(p, {
        { "ChatFrame1", 0.60, true, false }, { "GeneralDockManager", 0.60, true, false },
        { "ObjectiveTrackerFrame", 0.50, true, false }, { "MinimapCluster", 0.80, true },
      })
      p.master = 1
      Contexts(p, { combat = 1.00, raid = 1.00, instance = 1.00 })
    end,
  },
  {
    key = "minimal",
    label = T("PRE_MINIMAL", "Minimaliste"),
    desc = T("PRE_MINIMAL_D", "Écran presque vide : barres, menus et discussion invisibles. Ils réapparaissent par groupes au survol "
      .. "(zone de survol élargie), et tout revient à 100 % en combat ou dès qu'une cible est sélectionnée."),
    build = function(p)
      SetMany(p, {
        { BAR1, 0, true, true, G_BARS }, { "MultiBarBottomLeft", 0, true, true, G_BARS },
        { "MultiBarBottomRight", 0, true, true, G_BARS }, { "MultiBarRight", 0, true, true, G_BARS },
        { "MultiBarLeft", 0, true, true, G_BARS }, { "StanceBar", 0, true, true, G_BARS },
        { "PetActionBar", 0, true, true, G_BARS },
        { "MicroMenuContainer", 0, true, true, G_MENUS }, { "BagsBar", 0, true, true, G_MENUS },
        { "ChatFrame1", 0, true, true, G_CHAT }, { "GeneralDockManager", 0, true, true, G_CHAT },
        { "MinimapCluster", 0.25, true }, { "ObjectiveTrackerFrame", 0.25, true },
        { "BuffFrame", 0.40, true }, { "MainStatusTrackingBarContainer", 0, true },
      })
      p.master = 1
      p.fade.radius = 40
      Contexts(p, { combat = 1.00, target = 1.00, afk = 0.00 })
    end,
  },
  {
    key = "mplus",
    label = T("PRE_MPLUS", "Mythique+"),
    desc = T("PRE_MPLUS_D", "Tout à 100 % en donjon et en combat. La discussion reste à 50 % et le suivi des objectifs (chrono) "
      .. "à 85 %, menus et barre d'expérience discrets, tout réapparaît au survol."),
    build = function(p)
      SetMany(p, {
        { "ChatFrame1", 0.50, true, false, G_CHAT }, { "GeneralDockManager", 0.50, true, false, G_CHAT },
        { "ObjectiveTrackerFrame", 0.85, true, false }, { "MinimapCluster", 0.60, true, false },
        { "MicroMenuContainer", 0.20, true, false, G_MENUS }, { "BagsBar", 0.20, true, false, G_MENUS },
        { "MainStatusTrackingBarContainer", 0, true, false },
      })
      p.master = 1
      Contexts(p, { combat = 1.00, instance = 1.00 })
    end,
  },
  {
    key = "leveling",
    label = T("PRE_LEVELING", "Leveling / quêtes"),
    desc = T("PRE_LEVELING_D", "Suivi des objectifs et barre d'expérience bien visibles, barres d'action à 50 % (réapparaissent ensemble "
      .. "au survol). Discret en monture, très discret en vol, 100 % en combat."),
    build = function(p)
      SetMany(p, {
        { "ObjectiveTrackerFrame", 1.00, false, false }, { "MainStatusTrackingBarContainer", 0.80, true, false },
        { BAR1, 0.50, true, true, G_BARS }, { "MultiBarBottomLeft", 0.50, true, true, G_BARS },
        { "MultiBarBottomRight", 0.50, true, true, G_BARS },
        { "MultiBarRight", 0.30, true, true, G_BARS }, { "MultiBarLeft", 0.30, true, true, G_BARS },
        { "ChatFrame1", 0.60, true, true, G_CHAT }, { "GeneralDockManager", 0.60, true, true, G_CHAT },
        { "MicroMenuContainer", 0.30, true, true, G_MENUS }, { "BagsBar", 0.30, true, true, G_MENUS },
      })
      p.master = 1
      Contexts(p, { combat = 1.00, flying = 0.15, mount = 0.30 })
    end,
  },
  {
    key = "streamer",
    label = T("PRE_STREAMER", "Streamer"),
    desc = T("PRE_STREAMER_D", "Discussion invisible (sauf au survol) pour ne pas montrer vos messages privés à l'écran, "
      .. "menus et sacs masqués. Ces fenêtres ignorent les contextes : rien ne réapparaît par surprise en combat."),
    build = function(p)
      SetMany(p, {
        { "ChatFrame1", 0, true, false, G_CHAT }, { "GeneralDockManager", 0, true, false, G_CHAT },
        { "MicroMenuContainer", 0, true, false, G_MENUS }, { "BagsBar", 0, true, false, G_MENUS },
      })
      p.master = 1
      Contexts(p, { afk = 0.00 })
    end,
  },
  {
    key = "pvp",
    label = T("PRE_PVP", "JcJ"),
    desc = T("PRE_PVP_D", "Champs de bataille et arènes : tout à 100 % en instance et en combat, sauf la discussion (40 %), "
      .. "le suivi des objectifs (30 %) et les menus (20 %), qui réapparaissent au survol."),
    build = function(p)
      SetMany(p, {
        { "ChatFrame1", 0.40, true, false, G_CHAT }, { "GeneralDockManager", 0.40, true, false, G_CHAT },
        { "ObjectiveTrackerFrame", 0.30, true, false },
        { "MicroMenuContainer", 0.20, true, false, G_MENUS }, { "BagsBar", 0.20, true, false, G_MENUS },
      })
      p.master = 1
      Contexts(p, { combat = 1.00, instance = 1.00, mount = 0.40 })
    end,
  },
}

function OP.ApplyPreset(key)
  for _, pre in ipairs(OP.PRESETS) do
    if pre.key == key then
      local p = OP.CopyTable(OP.Profile())
      pre.build(p)
      OP.ReplaceProfile(p)
      OP.Print(string.format(T("MSG_PRESET", "préréglage « %s » appliqué. « Annuler » restaure le profil précédent."), pre.label))
      return true
    end
  end
  return false
end

function OP.ResetProfile()
  OP.ReplaceProfile(OP.DefaultProfile())
  OP.Print(T("MSG_RESET", "liste vidée, toutes les fenêtres sont rendues à leur opacité d'origine. « Annuler » restaure le profil précédent."))
end

-- ============================================================================
-- PROFILS MULTIPLES
-- ============================================================================
local MAX_PROFILES, MAX_NAME = 20, 32

local function CharKey()
  local name = UnitName("player") or "?"
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "?"
  return name .. "-" .. realm
end

-- Identifiant de la specialisation active (nil si indisponible).
local function SpecID()
  if type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function" then return nil end
  local okI, idx = pcall(GetSpecialization)
  if not okI or not idx then return nil end
  local ok, id = pcall(GetSpecializationInfo, idx)
  return ok and tonumber(id) or nil
end

local function SpecName()
  local okI, idx = pcall(GetSpecialization)
  if not okI or not idx then return nil end
  local ok, _, name = pcall(GetSpecializationInfo, idx)
  return ok and name or nil
end
OP.SpecName = SpecName

function OP.ProfileNames()
  local out = {}
  for name in pairs(OpacityDB.profiles) do out[#out + 1] = name end
  table.sort(out, function(a, b) return a:lower() < b:lower() end)
  return out
end

function OP.CurrentProfileName() return OpacityDB and OpacityDB.current end

local function CleanName(name)
  name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("|", "")
  if name == "" or #name > MAX_NAME then return nil end
  return name
end

-- Bascule sur un profil existant. silent : pas de message (login).
function OP.SwitchProfile(name, silent)
  local db = OpacityDB
  if not (db.profiles[name]) or db.current == name then return false end
  db.current = name
  db.undo = nil        -- l'annulation concernait l'ancien profil
  if OP.UpdateContext then OP.UpdateContext() end
  OP.Resolve()
  if OP.OnRefresh then OP.OnRefresh() end
  if not silent then OP.Print(string.format(T("MSG_PROF_SWITCH", "profil « %s » actif."), name)) end
  return true
end

-- Cree un profil (vide, ou copie du profil actif). Renvoie ok, message.
function OP.CreateProfile(name, copy)
  local db = OpacityDB
  name = CleanName(name)
  if not name then return false, T("PROF_ERR_NAME", "nom invalide (1 à 32 caractères).") end
  if db.profiles[name] then return false, T("PROF_ERR_EXISTS", "un profil porte déjà ce nom.") end
  if #OP.ProfileNames() >= MAX_PROFILES then return false, T("PROF_ERR_MAX", "20 profils au maximum.") end
  db.profiles[name] = copy and OP.SanitizeProfile(OP.CopyTable(OP.Profile())) or OP.DefaultProfile()
  OP.SwitchProfile(name, true)
  return true, string.format(T("MSG_PROF_NEW", "profil « %s » créé et activé."), name)
end

function OP.RenameProfile(old, new)
  local db = OpacityDB
  new = CleanName(new)
  if not new then return false, T("PROF_ERR_NAME", "nom invalide (1 à 32 caractères).") end
  if not db.profiles[old] then return false, "?" end
  if new == old then return true, "" end
  if db.profiles[new] then return false, T("PROF_ERR_EXISTS", "un profil porte déjà ce nom.") end
  db.profiles[new], db.profiles[old] = db.profiles[old], nil
  if db.current == old then db.current = new end
  for _, map in pairs({ db.assign.char, db.assign.spec }) do
    for k, v in pairs(map) do if v == old then map[k] = new end end
  end
  if OP.OnRefresh then OP.OnRefresh() end
  return true, string.format(T("MSG_PROF_RENAMED", "profil renommé en « %s »."), new)
end

function OP.DeleteProfile(name)
  local db = OpacityDB
  if not db.profiles[name] then return false, "?" end
  if #OP.ProfileNames() <= 1 then return false, T("PROF_ERR_LAST", "impossible de supprimer le dernier profil.") end
  db.profiles[name] = nil
  for _, map in pairs({ db.assign.char, db.assign.spec }) do
    for k, v in pairs(map) do if v == name then map[k] = nil end end
  end
  if db.current == name then
    db.current = OP.ProfileNames()[1]
    db.undo = nil
    if OP.UpdateContext then OP.UpdateContext() end
    OP.Resolve()
  end
  if OP.OnRefresh then OP.OnRefresh() end
  return true, string.format(T("MSG_PROF_DELETED", "profil « %s » supprimé."), name)
end

-- Liens : ce personnage / cette specialisation -> profil actif.
function OP.IsCharLinked()
  return OpacityDB.assign.char[CharKey()] == OpacityDB.current
end
function OP.IsSpecLinked()
  local spec = SpecID()
  return spec and OpacityDB.assign.spec[CharKey() .. ":" .. spec] == OpacityDB.current or false
end
function OP.SetCharLink(on)
  OpacityDB.assign.char[CharKey()] = on and OpacityDB.current or nil
end
function OP.SetSpecLink(on)
  local spec = SpecID()
  if not spec then return false end
  OpacityDB.assign.spec[CharKey() .. ":" .. spec] = on and OpacityDB.current or nil
  return true
end

-- Choisit le profil lie (specialisation d'abord, puis personnage).
function OP.AutoSelectProfile(silent)
  local db = OpacityDB
  if not (db and db.assign) then return end
  local key, spec = CharKey(), SpecID()
  local want = (spec and db.assign.spec[key .. ":" .. spec]) or db.assign.char[key]
  if want and db.profiles[want] and want ~= db.current then
    OP.SwitchProfile(want, silent)
  end
end

local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "PLAYER_SPECIALIZATION_CHANGED")
pcall(ev.RegisterEvent, ev, "ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
pcall(ev.RegisterEvent, ev, "PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event, unit)
  if not (OpacityDB and OpacityDB.profiles) then return end
  if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then return end
  -- Au login, la specialisation peut ne pas etre connue au premier passage
  -- (PLAYER_LOGIN) : PLAYER_ENTERING_WORLD refait le choix, sans message.
  OP.AutoSelectProfile(event == "PLAYER_ENTERING_WORLD")
end)
