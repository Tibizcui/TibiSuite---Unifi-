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

local function SetMany(p, list)
  for _, it in ipairs(list) do
    local name = type(it[1]) == "table" and FirstExisting(it[1]) or it[1]
    if not OP.ManagedBy(name) then
      p.frames[name] = { alpha = it[2], hover = it[3] == true, ctx = it[4] ~= false, force = false }
    end
  end
end

local BAR1 = { "MainActionBar", "MainMenuBar" }

OP.PRESETS = {
  {
    key = "immersion",
    label = T("PRE_IMMERSION", "Immersion"),
    desc = T("PRE_IMMERSION_D", "Interface discrète hors combat (35 %), elle réapparaît au survol et à 100 % en combat. "
      .. "Très discrète en monture, invisible quand vous êtes ABS."),
    build = function(p)
      SetMany(p, {
        { BAR1, 0.35, true }, { "MultiBarBottomLeft", 0.35, true }, { "MultiBarBottomRight", 0.35, true },
        { "MultiBarRight", 0.25, true }, { "MultiBarLeft", 0.25, true },
        { "MinimapCluster", 0.35, true }, { "ObjectiveTrackerFrame", 0.35, true },
        { "ChatFrame1", 0.35, true }, { "GeneralDockManager", 0.35, true },
        { "BuffFrame", 0.50, true }, { "MicroMenuContainer", 0.20, true }, { "BagsBar", 0.20, true },
        { "MainStatusTrackingBarContainer", 0.35, true },
      })
      p.master = 1
      p.contexts.combat   = { on = true,  value = 1.00 }
      p.contexts.mount    = { on = true,  value = 0.15 }
      p.contexts.afk      = { on = true,  value = 0.00 }
      p.contexts.raid     = { on = false, value = 1.00 }
      p.contexts.instance = { on = false, value = 1.00 }
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
      p.contexts.combat   = { on = true,  value = 1.00 }
      p.contexts.raid     = { on = true,  value = 1.00 }
      p.contexts.instance = { on = true,  value = 1.00 }
      p.contexts.mount    = { on = false, value = 0.40 }
      p.contexts.afk      = { on = false, value = 0.20 }
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
