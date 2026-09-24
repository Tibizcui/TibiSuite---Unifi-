--[[============================================================================
  Opacity - Hover.lua
  ---------------------------------------------------------------------------
  UN SEUL moteur d'animation pour toutes les frames controlees (pas un
  OnUpdate par frame). Il fait glisser le facteur "cur" de chaque frame vers
  sa cible :
    - cible au repos = OP.RestFactor (reglage, contexte, curseur maitre) ;
    - si "fondu au survol" est coche et que la souris est sur la frame, la
      cible devient 100 %, puis redescend apres un court delai.
  Les changements de contexte (entree en combat, monture...) profitent du meme
  fondu. Le moteur s'endort (frame cachee = plus d'OnUpdate) des qu'il n'y a
  plus rien a animer ni aucune frame en mode survol.

  La detection du survol est geometrique (IsMouseOver) : elle marche aussi
  sur les frames qui n'acceptent pas la souris, sans rien leur modifier.
============================================================================]]

local ADDON, OP = ...

local driver = CreateFrame("Frame")
driver:Hide()

local MOUSE_STEP = 0.05     -- verification du survol : 20 fois par seconde
local mouseClock = 0
local overSince  = setmetatable({}, { __mode = "k" })  -- [frame] = derniere fois vue sous la souris

local function Step(cur, target, dt, fade)
  if cur == target then return cur end
  local dur = (target > cur) and fade.fadeIn or fade.fadeOut
  if dur <= 0 then return target end
  local delta = dt / dur
  if target > cur then return math.min(target, cur + delta) end
  return math.max(target, cur - delta)
end

driver:SetScript("OnUpdate", function(self, dt)
  local p = OP.Profile()
  if not p then self:Hide(); return end
  local fade = p.fade
  local now = GetTime()

  mouseClock = mouseClock + dt
  local checkMouse = mouseClock >= MOUSE_STEP
  if checkMouse then mouseClock = 0 end

  local busy, hovering = false, false
  for _, frame in pairs(OP.byName) do
    local st = OP.state[frame]
    if st and st.active then
      local target = st.target
      if st.hover and not OP.screenshot then
        hovering = true
        if checkMouse and frame:IsVisible() and frame:IsMouseOver() then overSince[frame] = now end
        if overSince[frame] and now - overSince[frame] <= fade.delay then target = 1 end
      end
      -- Une frame en mode "children" garde le moteur eveille : il doit voir
      -- ses reapparitions pour recenser les elements crees a l'ouverture.
      if st.mode == "children" then hovering = true end
      local visible = frame:IsVisible()
      if visible and not st.wasVisible and st.mode == "children" then
        -- La fenetre reapparait : elle a pu creer de nouveaux elements.
        OP.CollectObjs(frame)
        OP.Push(frame)
      end
      st.wasVisible = visible
      if not visible then
        -- Invisible : inutile d'animer, on se cale directement.
        if st.cur ~= target then st.cur = target; OP.Push(frame) end
      elseif st.cur ~= target then
        st.cur = Step(st.cur, target, dt, fade)
        OP.Push(frame)
        busy = true
      end
    end
  end
  if not busy and not hovering then self:Hide() end
end)

-- Reveille le moteur : il fait au moins un passage, puis se rendort seul.
function OP.WakeDriver()
  driver:Show()
end
