--[[============================================================================
  Opacity - Context.lua
  ---------------------------------------------------------------------------
  Determine le contexte de jeu actif. Un contexte coche REMPLACE l'opacite
  reglee de chaque frame qui "suit les contextes" (case par frame), puis le
  curseur maitre s'applique par-dessus. Si plusieurs contextes sont vrais en
  meme temps, le premier dans cet ordre l'emporte :
      ABS > combat > raid > instance > monture
  (voir OP.CONTEXT_ORDER dans Core.lua). Un contexte decoche est ignore et on
  passe au suivant.

  Lecteur pur : aucune fonction protegee, uniquement des lectures d'etat.
============================================================================]]

local ADDON, OP = ...
local T = OP.T

OP.CONTEXT_LABELS = {
  afk      = T("CTX_AFK",      "Absent (ABS)"),
  combat   = T("CTX_COMBAT",   "En combat"),
  raid     = T("CTX_RAID",     "En raid"),
  instance = T("CTX_INSTANCE", "En instance (donjon, gouffre, scénario, JcJ)"),
  mount    = T("CTX_MOUNT",    "En monture"),
}

local inCombat = false

local function IsTrue(key)
  if key == "afk" then
    return UnitIsAFK and UnitIsAFK("player") or false
  elseif key == "combat" then
    return inCombat
  elseif key == "raid" then
    local inInst, kind = IsInInstance()
    return inInst and kind == "raid" or false
  elseif key == "instance" then
    local inInst, kind = IsInInstance()
    return inInst and kind ~= "raid" and kind ~= "none" or false
  elseif key == "mount" then
    return IsMounted and IsMounted() or false
  end
  return false
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
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
ev:RegisterEvent("PLAYER_FLAGS_CHANGED")
ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_REGEN_DISABLED" then inCombat = true
  elseif event == "PLAYER_REGEN_ENABLED" then inCombat = false
  elseif event == "PLAYER_FLAGS_CHANGED" and unit ~= "player" then return
  elseif event == "PLAYER_ENTERING_WORLD" then inCombat = InCombatLockdown() and true or false end
  if OpacityDB then OP.UpdateContext() end
end)
