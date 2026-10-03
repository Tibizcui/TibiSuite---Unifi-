--[[============================================================================
  Opacity - Bridge.lua
  ---------------------------------------------------------------------------
  Tout ce qui relie Opacity au reste de la suite (et aux autres addons) :
    - OpacityAPI (globale publique) : un addon declare ses frames pour
      qu'elles apparaissent proprement nommees dans "Ajouter", et peut
      demander si Opacity controle une de ses fenetres ;
    - fournisseur de la recherche globale TibiSuite (loupe de la barre) ;
    - ligne de sante pour /ts doctor (Opacity_DoctorNote, lue par le core) ;
    - sonde /opa probe : verifie en jeu ce qui n'a pas pu l'etre hors client
      (noms du catalogue Blizzard sous 12.1, detection du proprietaire d'une
      frame). Resultat imprime ET garde dans OpacityDB.probe.
============================================================================]]

local ADDON, OP = ...
local T = OP.T

local function Pct(v) return math.floor((v or 0) * 100 + 0.5) .. " %" end

-- ============================================================================
-- OpacityAPI
-- ============================================================================
OpacityAPI = OpacityAPI or {}
OpacityAPI.version = 1

-- Declare une frame (par son nom global) : libelle lisible et addon
-- proprietaire, affiches dans la fenetre "Ajouter" et dans la liste.
-- N'ajoute PAS la frame au profil : c'est toujours le joueur qui choisit.
function OpacityAPI.RegisterFrame(name, label, owner)
  if not OP.ValidName(name) then return false end
  OP.declared[name] = { label = tostring(label or name), owner = tostring(owner or T("G_UNKNOWN", "Addon inconnu")) }
  return true
end

-- Opacity agit-il sur cette frame en ce moment ?
function OpacityAPI.IsControlled(name)
  local f = name and OP.byName[name]
  local st = f and OP.state[f]
  return st and st.active and OP.IsRunning() and true or false
end

-- Facteurs de la frame : notre facteur, l'opacite "de base" posee par son
-- proprietaire, et le produit affiche. nil si Opacity ne la connait pas.
function OpacityAPI.GetFactor(name)
  local f = name and OP.byName[name]
  local st = f and OP.state[f]
  if not st then return nil end
  local cur = st.active and (st.cur or 1) or 1
  return cur, st.base or 1, (st.base or 1) * cur
end

function OpacityAPI.IsRunning() return OP.IsRunning() and true or false end

-- ============================================================================
-- RECHERCHE GLOBALE TibiSuite
-- ============================================================================
function OP.SearchProvider(query)
  local UI = _G.TibiMidnight
  if not (UI and OpacityDB and OP.Profile()) then return {} end
  local out = {}
  local p = OP.Profile()

  -- Commandes
  local cmds = {
    { T("BTN_PICK", "Pipette"), function() OP.StartPicker() end },
    { T("BTN_TUNE", "Réglage direct"), function() OP.StartTuner() end },
    { T("BTN_SHOT", "Capture"), function() Opacity_ToggleScreenshot() end },
  }
  for _, c in ipairs(cmds) do
    if UI.Match(c[1] .. " opacity", query) then out[#out + 1] = { text = "Opacity : " .. c[1], onClick = c[2] } end
  end

  -- Fenetres deja reglees
  for name, e in pairs(p.frames) do
    local label = OP.LabelOf(name)
    if UI.Match(label .. " " .. name, query) then
      out[#out + 1] = { text = label .. "  |cFF888888" .. Pct(e.alpha) .. "|r", onClick = function() OP.ShowMain() end }
    end
  end

  -- Catalogue Blizzard : ajouter d'un clic
  for _, e in ipairs(OP.BLIZZARD) do
    local name = e.names[1]
    for _, n in ipairs(e.names) do if OP.IsUsableFrame(_G[n]) then name = n; break end end
    if not p.frames[name] and UI.Match(e.label .. " " .. name, query) then
      out[#out + 1] = {
        text = T("SEARCH_ADD", "Ajouter à Opacity : ") .. e.label,
        onClick = function() OP.AddFrame(name); OP.ShowMain() end,
      }
    end
  end

  -- Prereglages et profils
  for _, pre in ipairs(OP.PRESETS) do
    if UI.Match(pre.label .. " " .. pre.desc, query) then
      out[#out + 1] = { text = T("SEARCH_PRESET", "Préréglage Opacity : ") .. pre.label, onClick = function() OP.ApplyPreset(pre.key) end }
    end
  end
  for _, name in ipairs(OP.ProfileNames()) do
    if UI.Match(name, query) then
      out[#out + 1] = { text = T("SEARCH_PROFILE", "Profil Opacity : ") .. name, onClick = function() OP.SwitchProfile(name) end }
    end
  end
  return out
end

-- ============================================================================
-- /ts doctor : une ligne d'etat (appelee par TibiSuite.RunDoctor)
-- Renvoie : texte, probleme (booleen).
-- ============================================================================
function Opacity_DoctorNote()
  if not (OpacityDB and OP.Profile()) then return T("DOC_NODB", "sauvegarde pas encore chargée"), true end
  local nFrames, nPending, nChildren = 0, 0, 0
  for _ in pairs(OP.Profile().frames) do nFrames = nFrames + 1 end
  for _ in pairs(OP.pending) do nPending = nPending + 1 end
  for _, f in pairs(OP.byName) do
    local st = OP.state[f]
    if st and st.mode == "children" then nChildren = nChildren + 1 end
  end
  local parts = {
    string.format(T("DOC_PROFILE", "profil « %s »"), OpacityDB.current or "?"),
    string.format(T("DOC_FRAMES", "%d fenêtre(s)"), nFrames),
  }
  if nPending > 0 then parts[#parts + 1] = string.format(T("DOC_PENDING", "%d en attente"), nPending) end
  if nChildren > 0 then parts[#parts + 1] = string.format(T("DOC_CHILDREN", "%d en mode enfants"), nChildren) end
  if not OpacityDB.enabled then parts[#parts + 1] = T("HDR_PAUSED", "suspendu") end
  if OP.blockedInCombat then parts[#parts + 1] = T("DOC_BLOCKED", "cadres protégés différés en combat") end
  return table.concat(parts, ", "), false
end

-- ============================================================================
-- /opa probe : verification en jeu
-- ============================================================================
function OP.RunProbe()
  local db = OpacityDB
  local res = { when = date and date("%Y-%m-%d %H:%M") or "?", missing = {}, found = 0, total = 0 }
  for _, e in ipairs(OP.BLIZZARD) do
    res.total = res.total + 1
    local ok = false
    for _, n in ipairs(e.names) do
      if OP.IsUsableFrame(_G[n]) then ok = true; break end
    end
    if ok then res.found = res.found + 1 else res.missing[#res.missing + 1] = table.concat(e.names, "/") end
  end

  -- Detection du proprietaire : une frame Blizzard doit etre "securisee",
  -- une globale d'Opacity doit renvoyer "Opacity".
  local okB, secureB = pcall(issecurevariable, "PlayerFrame")
  local okO, secureO, taintO = pcall(issecurevariable, "Opacity_Toggle")
  res.ownerBlizzard = okB and secureB == true
  res.ownerAddon = okO and secureO == false and taintO == ADDON

  res.children = {}
  for name, f in pairs(OP.byName) do
    local st = OP.state[f]
    if st and st.mode == "children" then res.children[#res.children + 1] = name end
  end
  res.pending = {}
  for name in pairs(OP.pending) do res.pending[#res.pending + 1] = name end
  table.sort(res.missing); table.sort(res.children); table.sort(res.pending)
  res.blockedInCombat = OP.blockedInCombat and true or false
  res.spec = OP.SpecName and OP.SpecName() or nil
  db.probe = res

  local Y, G, R = "|cFFFFD700", "|cFF66D98A", "|cFFFF7F7F"
  OP.Print(T("PROBE_HEAD", "sonde (résultat aussi gardé dans la sauvegarde OpacityDB.probe) :"))
  print(string.format("  " .. T("PROBE_CATALOG", "Catalogue Blizzard : %s%d / %d|r fenêtres présentes."), Y, res.found, res.total))
  if #res.missing > 0 then
    print("  " .. T("PROBE_MISSING", "Absentes (normal pour une fenêtre jamais ouverte depuis la connexion ; ouvrez-la puis relancez) :"))
    print("    |cFFAAAAAA" .. table.concat(res.missing, ", ") .. "|r")
  end
  print("  " .. T("PROBE_OWNER", "Détection du propriétaire : ")
    .. ((res.ownerBlizzard and res.ownerAddon) and (G .. "OK|r") or (R .. T("PROBE_OWNER_KO", "ne marche pas (groupe « Addon inconnu » attendu)") .. "|r")))
  print("  " .. T("PROBE_SPEC", "Spécialisation lue : ") .. Y .. tostring(res.spec or "?") .. "|r")
  if #res.children > 0 then print("  " .. T("PROBE_CHILDREN", "Mode enfants (fondu externe détecté) : ") .. table.concat(res.children, ", ")) end
  if #res.pending > 0 then print("  " .. T("PROBE_PENDING", "En attente : ") .. table.concat(res.pending, ", ")) end
  if res.blockedInCombat then print("  " .. R .. T("PROBE_BLOCKED", "Le client a refusé un SetAlpha protégé en combat (file d'attente active).") .. "|r") end
end
