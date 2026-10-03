--[[============================================================================
  Opacity - Hover.lua
  ---------------------------------------------------------------------------
  UN SEUL moteur d'animation pour toutes les frames controlees (pas un
  OnUpdate par frame). Il fait glisser le facteur "cur" de chaque frame vers
  sa cible :
    - cible au repos = OP.RestFactor (reglage, contexte, curseur maitre) ;
    - si "fondu au survol" est coche et que la souris est sur la frame (ou
      dans la zone elargie autour, reglage "rayon"), la cible devient 100 %,
      puis redescend apres un court delai ;
    - GROUPES LIES : les frames d'un meme groupe (1..6, survol coche)
      reapparaissent ensemble des que l'une d'elles est survolee (toutes les
      barres d'action d'un coup, par exemple).
  Les changements de contexte (entree en combat, monture...) profitent du meme
  fondu.

  RYTHME (optimisation 12.1) : pendant un fondu, le moteur tourne a chaque
  image pour rester fluide. Au repos (rien n'anime, mais des frames en mode
  survol ou "children" a surveiller), il ne fait plus qu'un passage tous les
  1/20 s au lieu d'un a chaque image. Il s'endort completement (frame cachee
  = plus d'OnUpdate) des qu'il n'y a plus rien a animer ni a surveiller.

  La detection du survol est geometrique (IsMouseOver) : elle marche aussi
  sur les frames qui n'acceptent pas la souris, sans rien leur modifier.
============================================================================]]

local ADDON, OP = ...

local driver = CreateFrame("Frame")
driver:Hide()

local MOUSE_STEP = 0.05     -- survol et repos : 20 fois par seconde
local clock, accDt = 0, 0
local wasBusy = true
local overSince  = setmetatable({}, { __mode = "k" })  -- [frame] = derniere fois vue sous la souris
local groupSince = {}                                   -- [groupe] = dernier survol d'un membre

local function Step(cur, target, dt, fade)
  if cur == target then return cur end
  local dur = (target > cur) and fade.fadeIn or fade.fadeOut
  if dur <= 0 then return target end
  local delta = dt / dur
  if target > cur then return math.min(target, cur + delta) end
  return math.max(target, cur - delta)
end

-- IsMouseOver(haut, bas, gauche, droite) : des decalages positifs en haut et
-- a droite, negatifs en bas et a gauche, elargissent la zone testee.
local function Over(frame, r)
  if r > 0 then return frame:IsMouseOver(r, -r, -r, r) end
  return frame:IsMouseOver()
end

driver:SetScript("OnUpdate", function(self, dt)
  local p = OP.Profile()
  if not p then self:Hide(); return end
  accDt = accDt + dt
  clock = clock + dt
  if not wasBusy and clock < MOUSE_STEP then return end   -- repos : 20 Hz
  local checkMouse = clock >= MOUSE_STEP
  if checkMouse then clock = 0 end
  local step = accDt
  accDt = 0

  local fade = p.fade
  local now = GetTime()
  local suppress = OP.screenshot or OP.tuning   -- capture / reglage direct : pas de survol
  local radius = fade.radius or 0

  -- Passe 1 : qui est sous la souris ?
  if checkMouse and not suppress then
    for _, frame in pairs(OP.byName) do
      local st = OP.state[frame]
      if st and st.active and st.hover and frame:IsVisible() and Over(frame, radius) then
        overSince[frame] = now
        if st.group then groupSince[st.group] = now end
      end
    end
  end

  -- Passe 2 : cibles et animation
  local busy, watch = false, false
  for _, frame in pairs(OP.byName) do
    local st = OP.state[frame]
    if st and st.active then
      local target = st.target
      if st.hover and not suppress then
        watch = true
        local t1 = overSince[frame]
        local tg = st.group and groupSince[st.group]
        if (t1 and now - t1 <= fade.delay) or (tg and now - tg <= fade.delay) then target = 1 end
      end
      -- Une frame en mode "children" garde le moteur eveille : il doit voir
      -- ses reapparitions pour recenser les elements crees a l'ouverture.
      if st.mode == "children" then watch = true end
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
        st.cur = Step(st.cur, target, step, fade)
        OP.Push(frame)
        busy = true
      end
    end
  end
  wasBusy = busy
  if not busy and not watch then self:Hide() end
end)

-- Reveille le moteur : il fait au moins un passage complet tout de suite,
-- puis se rendort seul.
function OP.WakeDriver()
  wasBusy = true
  driver:Show()
end
