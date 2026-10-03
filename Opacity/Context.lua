--[[============================================================================
  Opacity - Context.lua
  ---------------------------------------------------------------------------
  Determine le contexte de jeu actif. Un contexte coche REMPLACE l'opacite
  reglee de chaque frame qui "suit les contextes" (case par frame), puis le
  curseur maitre s'applique par-dessus. Si plusieurs contextes sont vrais en
  meme temps, le premier dans cet ordre l'emporte :
      ABS > combat > vehicule > combat de mascottes > raid > instance
          > cible > vol > monture > groupe > repos
  (voir OP.CONTEXT_ORDER dans Core.lua). Un contexte decoche est ignore et on
  passe au suivant.

  VOL : il n'existe pas d'evenement "debut / fin de vol". Tant que le joueur
  est en monture ET que le contexte Vol est coche, une petite minuterie relit
  IsFlying() deux fois par seconde ; elle s'arrete des qu'on met pied a terre.

  Lecteur pur : aucune fonction protegee, uniquement des lectures d'etat.
  Les API de lecture des nouveaux contextes (IsResting, IsFlying,
  UnitInVehicle, C_PetBattles.IsInBattle, IsInGroup) existent depuis
  longtemps, mais leur comportement sous 12.1 n'est PAS VERIFIE EN JEU.
============================================================================]]

local ADDON, OP = ...
local T = OP.T

OP.CONTEXT_LABELS = {
  afk       = T("CTX_AFK",       "Absent (ABS)"),
  combat    = T("CTX_COMBAT",    "En combat"),
  vehicle   = T("CTX_VEHICLE",   "En véhicule"),
  petbattle = T("CTX_PETBATTLE", "Combat de mascottes"),
  raid      = T("CTX_RAID",      "En raid"),
  instance  = T("CTX_INSTANCE",  "En instance (donjon, gouffre, scénario, JcJ)"),
  target    = T("CTX_TARGET",    "Une cible est sélectionnée"),
  flying    = T("CTX_FLYING",    "En vol"),
  mount     = T("CTX_MOUNT",     "En monture"),
  group     = T("CTX_GROUP",     "En groupe"),
  rest      = T("CTX_REST",      "Au repos (ville, auberge)"),
}

local inCombat = false

local function Call(fn, ...)
  if type(fn) ~= "function" then return false end
  local ok, v = pcall(fn, ...)
  return ok and v and true or false
end

local function IsTrue(key)
  if key == "afk" then
    return Call(UnitIsAFK, "player")
  elseif key == "combat" then
    return inCombat
  elseif key == "vehicle" then
    return Call(UnitInVehicle, "player")
  elseif key == "petbattle" then
    return C_PetBattles and Call(C_PetBattles.IsInBattle) or false
  elseif key == "raid" then
    local inInst, kind = IsInInstance()
    return inInst and kind == "raid" or false
  elseif key == "instance" then
    local inInst, kind = IsInInstance()
    return inInst and kind ~= "raid" and kind ~= "none" or false
  elseif key == "target" then
    return Call(UnitExists, "target") and not Call(UnitIsDeadOrGhost, "target")
  elseif key == "flying" then
    return Call(IsFlying)
  elseif key == "mount" then
    return Call(IsMounted)
  elseif key == "group" then
    return Call(IsInGroup)
  elseif key == "rest" then
    return Call(IsResting)
  end
  return false
end

-- Minuterie de vol : active seulement en monture avec le contexte Vol coche.
local flyTicker
local function UpdateFlyWatch()
  local p = OP.Profile()
  local want = p and p.contexts.flying and p.contexts.flying.on and Call(IsMounted)
  if want and not flyTicker then
    flyTicker = C_Timer.NewTicker(0.5, function() OP.UpdateContext() end)
  elseif not want and flyTicker then
    flyTicker:Cancel(); flyTicker = nil
  end
end

function OP.UpdateContext()
  local p = OP.Profile()
  if not p then return end
  local found
  for _, key in ipairs(OP.CONTEXT_ORDER) do
    local c = p.contexts[key]
    if c and c.on and IsTrue(key) then found = key; break end
  end
  OP.SetContext(found)
  UpdateFlyWatch()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({
  "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_FLAGS_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_UPDATE_RESTING",
  "GROUP_ROSTER_UPDATE", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
  "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE",
}) do pcall(ev.RegisterEvent, ev, e) end

ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_REGEN_DISABLED" then inCombat = true
  elseif event == "PLAYER_REGEN_ENABLED" then inCombat = false
  elseif (event == "PLAYER_FLAGS_CHANGED" or event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE")
         and unit ~= "player" then return
  elseif event == "PLAYER_ENTERING_WORLD" then inCombat = InCombatLockdown() and true or false
  elseif event == "PET_BATTLE_CLOSE" then
    -- Le combat de mascottes se declare encore "en cours" au premier signal
    -- de fermeture : on relit une demi-seconde plus tard.
    C_Timer.After(0.5, function() if OpacityDB and OP.Profile() then OP.UpdateContext() end end)
  end
  if OpacityDB and OP.Profile() then OP.UpdateContext() end
end)
