--[[============================================================================
  ReadyUp - Toast.lua
  ---------------------------------------------------------------------------
  Les moments ou ReadyUp previent, et l'alerte discrete qui s'affiche alors.
    - entree dans un donjon, un raid ou un gouffre (une fois par instance) ;
    - appel « Pret ? » du groupe (READY_CHECK) ;
    - marchand qui repare, si l'usure est sous le seuil ;
    - connexion (decoche par defaut).
  Rien ne s'affiche si tout va bien, sauf au ready check (option).
  Un evenement recu en combat attend la fin du combat.
  NON TESTE EN JEU (2026-11-14).
============================================================================]]

local ADDON, RU = ...
local T = RU.T

local toast
local TOAST_W, ROW_H, MAX_ROWS = 300, 20, 6

-- ============================================================================
-- ALERTE
-- ============================================================================
local function SavePos(f)
  local p, _, rp, x, y = f:GetPoint(1)
  if p then TibiReadyUpDB.toastPos = { point = p, relPoint = rp, x = x, y = y } end
end

local function BuildToast()
  local UI = _G.TibiMidnight
  local f = CreateFrame("Button", "TibiReadyUpToast", UIParent, "BackdropTemplate")
  f:SetSize(TOAST_W, 40)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); SavePos(s) end)
  local pos = TibiReadyUpDB.toastPos
  if type(pos) == "table" and pos.point then
    f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, tonumber(pos.x) or 0, tonumber(pos.y) or 0)
  else
    f:SetPoint("TOP", UIParent, "TOP", 0, -160)
  end
  if UI and UI.SkinFrame then UI.SkinFrame(f, RU.ACCENT, UI.C.BG) end

  f.logo = f:CreateTexture(nil, "ARTWORK")
  f.logo:SetSize(18, 18); f.logo:SetPoint("TOPLEFT", 10, -9)
  f.logo:SetTexture(RU.LOGO)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("LEFT", f.logo, "RIGHT", 6, 0)
  f.title:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  f.title:SetJustifyH("LEFT")

  f.rows = {}
  for i = 1, MAX_ROWS do
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(TOAST_W - 20, ROW_H)
    r:SetPoint("TOPLEFT", 10, -32 - (i - 1) * ROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16); r.icon:SetPoint("LEFT", 0, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.text:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    f.rows[i] = r
  end

  f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.hint:SetJustifyH("LEFT")
  f.hint:SetText(T("TOAST_HINT", "Clic : détail  |  clic droit : fermer"))

  f:SetScript("OnClick", function(s, button)
    s:Hide()
    if button ~= "RightButton" and RU.ShowMain then RU.ShowMain() end
  end)
  f:SetScript("OnEnter", function(s) s.hold = true end)
  f:SetScript("OnLeave", function(s) s.hold = false; s.left = math.max(s.left or 0, 2) end)
  f:SetScript("OnUpdate", function(s, el)
    if s.hold then s:SetAlpha(1); return end
    s.left = (s.left or 0) - el
    if s.left <= 0 then s:Hide(); return end
    s:SetAlpha(s.left < 1 and s.left or 1)
  end)
  f:Hide()
  return f
end

local function Line(r)
  local cr, cg, cb = RU.StateColor(r.state)
  local col = string.format("|cFF%02X%02X%02X", cr * 255, cg * 255, cb * 255)
  local s = r.label .. " : " .. col .. tostring(r.value or "") .. "|r"
  if r.detail and r.state ~= "ok" then s = s .. "  |cFFAAAAAA" .. r.detail .. "|r" end
  return s
end

-- Affiche l'alerte. onlyIds (facultatif) : ne montrer que ces controles.
function RU.ShowToast(ev, okMessage, onlyIds)
  if not (ev and TibiReadyUpDB) then return end
  toast = toast or BuildToast()
  local shown = {}
  for _, r in ipairs(ev.results) do
    if (r.state == "warn" or r.state == "fail") and (not onlyIds or onlyIds[r.id]) then shown[#shown + 1] = r end
  end
  table.sort(shown, function(a, b) return RU.RANK[a.state] > RU.RANK[b.state] end)
  if #shown == 0 then
    if not okMessage then return end
    toast.title:SetText(RU.Hex() .. T("TOAST_OK", "Prêt : tout est en ordre") .. "|r  |cFF888888(" .. RU.ContextLabel(ev.context) .. ")|r")
  else
    toast.title:SetText(string.format(T("TOAST_ISSUES", "%d point(s) à revoir"), #shown) .. "  |cFF888888(" .. RU.ContextLabel(ev.context) .. ")|r")
  end
  local n = math.min(#shown, MAX_ROWS)
  for i = 1, MAX_ROWS do
    local row, r = toast.rows[i], shown[i]
    if i <= n then
      row.icon:SetTexture(r.icon or RU.LOGO)
      row.text:SetText(Line(r))
      row:Show()
    else
      row:Hide()
    end
  end
  toast.hint:ClearAllPoints()
  toast.hint:SetPoint("TOPLEFT", 10, -34 - n * ROW_H)
  toast:SetHeight(34 + n * ROW_H + 20)
  toast.left = (#shown == 0) and 4 or (TibiReadyUpDB.toastTime or 12)
  toast:SetAlpha(1)
  toast:Show()
end

-- ============================================================================
-- MOMENTS
-- ============================================================================
local pending        -- raison en attente de la fin du combat
local lastInstance   -- instance deja annoncee (session)

local function Run(reason)
  if not RU.IsRunning() then return end
  if InCombatLockdown and InCombatLockdown() then pending = reason; return end
  local db = TibiReadyUpDB
  local ev = RU.Evaluate(reason)
  if not ev then return end
  if reason == "ready" then
    if db.onReadyCheck then RU.ShowToast(ev, db.okOnReady) end
  elseif reason == "merchant" then
    if db.onMerchant then RU.ShowToast(ev, false, { dur = true }) end
  elseif reason == "instance" then
    if db.onInstance then RU.ShowToast(ev, false) end
  elseif reason == "login" then
    if db.onLogin then RU.ShowToast(ev, false) end
  end
end
RU.Run = Run

local function After(sec, fn)
  if C_Timer and C_Timer.After then C_Timer.After(sec, fn) else fn() end
end

local function OnEnteringWorld()
  local ok, inInst, iType = pcall(IsInInstance)
  if not ok or not inInst or (iType ~= "party" and iType ~= "raid" and iType ~= "scenario") then
    lastInstance = nil
    return
  end
  local id = select(8, GetInstanceInfo())
  local diff = select(3, GetInstanceInfo())
  local key = tostring(id) .. ":" .. tostring(diff)
  if key == lastInstance then return end
  lastInstance = key
  -- Laisse le temps au familier, aux ameliorations et aux sacs de se charger.
  After(4, function() Run("instance") end)
end

-- Rafraichissement silencieux (fenetre ouverte, badge), une fois par seconde
-- au plus et jamais en combat.
local dirty = false
local function Touch()
  if dirty then return end
  dirty = true
  After(1, function()
    dirty = false
    if not RU.IsRunning() then return end
    if InCombatLockdown and InCombatLockdown() then return end
    RU.Evaluate("refresh")
  end)
end

-- ============================================================================
-- EVENEMENTS
-- ============================================================================
local ev = CreateFrame("Frame")
local function Reg(e) pcall(ev.RegisterEvent, ev, e) end
Reg("ADDON_LOADED")
Reg("PLAYER_LOGIN")

local function RegisterGameEvents()
  Reg("PLAYER_ENTERING_WORLD")
  Reg("READY_CHECK")
  Reg("MERCHANT_SHOW")
  Reg("PLAYER_REGEN_ENABLED")
  Reg("UPDATE_INVENTORY_DURABILITY")
  Reg("BAG_UPDATE_DELAYED")
  Reg("UNIT_PET")
  Reg("UNIT_INVENTORY_CHANGED")
  if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player") else Reg("UNIT_AURA") end
end

ev:SetScript("OnEvent", function(self, e, arg1)
  if e == "ADDON_LOADED" then
    if arg1 == ADDON then RU.InitDB() end
    return
  end
  if e == "PLAYER_LOGIN" then
    if not TibiReadyUpDB then RU.InitDB() end
    RegisterGameEvents()
    RU.WarmReagents()
    After(10, function() Run("login") end)
    return
  end
  if e == "PLAYER_ENTERING_WORLD" then OnEnteringWorld(); return end
  if e == "READY_CHECK" then Run("ready"); return end
  if e == "MERCHANT_SHOW" then
    if CanMerchantRepair and CanMerchantRepair() then Run("merchant") end
    return
  end
  if e == "PLAYER_REGEN_ENABLED" then
    if pending then local r = pending; pending = nil; After(1, function() Run(r) end) end
    return
  end
  if e == "UNIT_AURA" and arg1 ~= "player" then return end
  if (e == "UNIT_PET" or e == "UNIT_INVENTORY_CHANGED") and arg1 ~= "player" then return end
  Touch()
end)
