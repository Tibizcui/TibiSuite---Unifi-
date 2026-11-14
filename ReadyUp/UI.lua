--[[============================================================================
  ReadyUp - UI.lua
  ---------------------------------------------------------------------------
  Fenetre principale (TibiReadyUpMainFrame) : chaque controle applicable ici,
  son etat, sa valeur et le conseil. Construite au premier besoin.
  Panneau d'options (TibiReadyUpOptions, socle) : moments, controles, seuils.
  NON TESTE EN JEU (2026-11-14).
============================================================================]]

local ADDON, RU = ...
local T = RU.T
local ACCENT = RU.ACCENT

local function GetUI() return _G.TibiMidnight end

local main, optionsPanel
local rows = {}
local ROW_H = 34

-- Masquage des boutons flottants, en suite ET en standalone (socle v21).
local FLOAT_FRAME = "TibiReadyUpMainFrame"
local function FloatUI()
  local u = _G.TibiMidnight
  if u and u.RegisterCtrlStore then u.RegisterCtrlStore(FLOAT_FRAME, function() return _G.TibiReadyUpDB end) end
  return u
end
FloatUI()

local function Window(name, w, h, title)
  local UI = GetUI()
  local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  f:SetSize(w, h)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  UI.SkinFrame(f, ACCENT, UI.C.BG)
  local hdr = f:CreateTexture(nil, "ARTWORK")
  hdr:SetColorTexture(UI.C.HDR[1], UI.C.HDR[2], UI.C.HDR[3], 1)
  hdr:SetPoint("TOPLEFT", 1, -3); hdr:SetPoint("TOPRIGHT", -1, -3); hdr:SetHeight(30)
  if UI.AddHeaderLogo then
    local logo = UI.AddHeaderLogo(f, RU.LOGO, 20)
    if logo then logo:ClearAllPoints(); logo:SetPoint("LEFT", hdr, "LEFT", 10, 0) end
  end
  local tt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  tt:SetPoint("LEFT", hdr, "LEFT", 36, 0)
  tt:SetText(RU.Hex() .. title .. "|r")
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() f:Hide() end)
  f:Hide()
  -- Echap ferme la fenetre (comme Anchor). Aucun crochet OnHide : voir le
  -- piege « Taint / Echap » du CLAUDE.md.
  tinsert(UISpecialFrames, name)
  return f
end

-- ============================================================================
-- LISTE
-- ============================================================================
local function MakeRow(parent)
  local r = CreateFrame("Frame", nil, parent)
  r:SetHeight(ROW_H)
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, 0.03)
  r.bar = r:CreateTexture(nil, "ARTWORK")
  r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(3)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(24, 24); r.icon:SetPoint("LEFT", 10, 0)
  r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  r.label:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 1)
  r.label:SetJustifyH("LEFT")
  r.value = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  r.value:SetPoint("RIGHT", -10, 0); r.value:SetJustifyH("RIGHT")
  r.detail = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  r.detail:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -2)
  r.detail:SetPoint("RIGHT", r.value, "LEFT", -8, 0)
  r.detail:SetJustifyH("LEFT"); r.detail:SetWordWrap(false)
  return r
end

local function Refresh()
  if not (main and main:IsShown()) then return end
  local ev = RU.last
  if not ev or ev.reason == nil then ev = RU.Evaluate("manual") end
  if not ev then
    main.summary:SetText("|cFFFF7F7F" .. T("IN_COMBAT", "En combat : vérification après le combat.") .. "|r")
    return
  end
  local list = ev.results
  for i, it in ipairs(list) do
    local r = rows[i]
    if not r then r = MakeRow(main.content); rows[i] = r end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", main.content, "TOPLEFT", 0, -(i - 1) * (ROW_H + 3))
    r:SetPoint("RIGHT", main.content, "RIGHT", 0, 0)
    local cr, cg, cb = RU.StateColor(it.state)
    r.bar:SetColorTexture(cr, cg, cb, 1)
    r.icon:SetTexture(it.icon or RU.LOGO)
    r.label:SetText(it.label)
    r.value:SetText(tostring(it.value or ""))
    r.value:SetTextColor(cr, cg, cb)
    r.detail:SetText(it.detail or (it.state == "ok" and T("DET_OK", "rien à faire") or ""))
    r:Show()
  end
  for i = #list + 1, #rows do rows[i]:Hide() end
  main.empty:SetShown(#list == 0)
  main.content:SetHeight(math.max(#list * (ROW_H + 3), 10))

  local head
  if ev.issues == 0 then
    head = RU.Hex() .. T("SUM_READY", "Prêt") .. "|r"
  else
    head = string.format("|cFFFFB347" .. T("SUM_ISSUES", "%d point(s) à revoir") .. "|r", ev.issues)
  end
  main.summary:SetText(head .. "  |cFF888888" .. string.format(T("SUM_CTX", "contexte : %s"), RU.ContextLabel(ev.context)) .. "|r")
  main.enabled:SetChecked(TibiReadyUpDB.enabled and true or false)
end
RU.RefreshUI = Refresh
RU.listeners[#RU.listeners + 1] = Refresh

local function BuildMain()
  local UI = GetUI()
  main = Window(FLOAT_FRAME, 460, 400, "ReadyUp")
  local w = TibiReadyUpDB.win
  if type(w) == "table" and w.point then
    main:ClearAllPoints()
    main:SetPoint(w.point, UIParent, w.relPoint or w.point, tonumber(w.x) or 0, tonumber(w.y) or 0)
  end
  main:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local p, _, rp, x, y = s:GetPoint(1)
    TibiReadyUpDB.win = { point = p, relPoint = rp, x = x, y = y }
  end)

  main.enabled = CreateFrame("CheckButton", nil, main, "UICheckButtonTemplate")
  main.enabled:SetSize(24, 24)
  main.enabled:SetPoint("TOPLEFT", 12, -40)
  local et = main.enabled:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  et:SetPoint("LEFT", main.enabled, "RIGHT", 2, 0); et:SetText(T("HDR_ENABLED", "Actif"))
  main.enabled:SetScript("OnClick", function(s)
    TibiReadyUpDB.enabled = s:GetChecked() and true or false
    RU.OnChanged()
  end)
  main.summary = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  main.summary:SetPoint("LEFT", et, "RIGHT", 16, 0)

  local scroll = CreateFrame("ScrollFrame", nil, main, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -72)
  scroll:SetPoint("BOTTOMRIGHT", -32, 48)
  if UI.SkinScrollBar then UI.SkinScrollBar(scroll, ACCENT) end
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(410, 10)
  scroll:SetScrollChild(content)
  main.content = content
  main.empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  main.empty:SetPoint("TOPLEFT", 6, -6); main.empty:SetWidth(400); main.empty:SetJustifyH("LEFT")
  main.empty:SetText(T("EMPTY", "Aucun contrôle ne s'applique ici pour l'instant."))

  local function Btn(text, w, onClick, tip)
    local b = UI.MakeButton(main, w, 24, text)
    b:SetScript("OnClick", onClick)
    if tip then
      b:HookScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:SetText(tip, 1, 1, 1, 1, true); GameTooltip:Show() end)
      b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return b
  end
  local bCheck = Btn(T("BTN_CHECK", "Vérifier"), 110, function() RU.Evaluate("manual") end,
    T("TT_CHECK", "Relance tous les contrôles maintenant."))
  bCheck:SetPoint("BOTTOMLEFT", 12, 12)
  local bTest = Btn(T("BTN_TEST", "Voir l'alerte"), 120, function()
    local ev = RU.Evaluate("manual")
    if ev then RU.ShowToast(ev, true) end
  end, T("TT_TEST", "Affiche l'alerte telle qu'elle apparaît en entrant en instance. Glisse-la pour la déplacer."))
  bTest:SetPoint("LEFT", bCheck, "RIGHT", 6, 0)

  if UI.AddHeaderControls then
    UI.AddHeaderControls(main, { accent = ACCENT, onOptions = function() TibiReadyUp_OpenOptions() end,
      provider = RU.SearchProvider })
  end
  main:SetScript("OnShow", function() RU.Evaluate("manual") end)
end

function RU.ShowMain()
  if not TibiReadyUpDB then return end
  if not main then BuildMain() end
  main:Show()
  Refresh()
end

function TibiReadyUp_Toggle()
  if not TibiReadyUpDB then return end
  if not main then BuildMain() end
  main:SetShown(not main:IsShown())
end

-- ============================================================================
-- OPTIONS (socle)
-- ============================================================================
local function BuildOptions()
  local UI = GetUI()
  local p = UI.CreateOptionsPanel({ name = "TibiReadyUpOptions", title = T("OPT_TITLE", "ReadyUp : options"), accent = ACCENT, logo = RU.LOGO })
  local db = TibiReadyUpDB
  local function chk(label, key, tip)
    p:Check(label, function() return db[key] and true or false end, function(v) db[key] = v; RU.Evaluate("manual") end, tip)
  end

  p:Section(T("OPT_SEC_WHEN", "Quand prévenir"))
  chk(T("OPT_ON_INSTANCE", "En entrant en donjon, raid ou gouffre"), "onInstance",
    T("TT_ON_INSTANCE", "Une seule fois par instance, et seulement s'il manque quelque chose."))
  chk(T("OPT_ON_READY", "À l'appel « Prêt ? » du groupe"), "onReadyCheck")
  chk(T("OPT_OK_READY", "Confirmer « Prêt » quand tout va bien"), "okOnReady")
  chk(T("OPT_ON_MERCHANT", "Chez un marchand qui répare, si l'usure est basse"), "onMerchant")
  chk(T("OPT_ON_SOLO", "En quête, quand un seuil est franchi"), "onSolo",
    T("TT_ON_SOLO", "En solo, hors instance : sacs pleins, usure, familier, munitions ou composants. Une seule fois par problème, jamais en combat."))
  chk(T("OPT_ON_LOGIN", "À la connexion"), "onLogin")

  p:Section(T("OPT_SEC_CHECKS", "Contrôles"))
  chk(T("CHK_DUR", "Usure de l'équipement"), "chkDurability")
  chk(T("CHK_BAGS", "Place dans les sacs"), "chkBags")
  chk(T("CHK_FOOD", "Nourriture"), "chkFood", T("TT_CONSUM", "Au niveau maximum, en raid et en donjon mythique."))
  chk(T("CHK_FLASK", "Flacon ou élixir"), "chkFlask", T("TT_CONSUM", "Au niveau maximum, en raid et en donjon mythique."))
  chk(T("OPT_CONSUM_DUNGEON", "Nourriture et flacon aussi en donjon normal"), "consumInDungeons")
  chk(T("CHK_WEAPON", "Enchantement d'arme"), "chkWeapon",
    T("TT_WEAPON", "Poisons du voleur, et avertissement quand une huile, une pierre ou un poison expire bientôt."))
  chk(T("OPT_WEAPON_ALL", "Exiger un enchantement d'arme pour toutes les classes"), "weaponForAll")
  chk(T("CHK_PET", "Familier"), "chkPet", T("TT_PET", "Chasseur, démoniste et chevalier de la mort impie."))
  chk(T("CHK_AMMO", "Munitions"), "chkAmmo", T("TT_AMMO", "Chasseur, sur les versions du jeu qui ont des munitions."))
  chk(T("CHK_REAGENTS", "Composants"), "chkReagents", T("TT_REAGENTS", "Seulement les composants que tes sorts réclament dans cette version du jeu."))

  p:Section(T("OPT_SEC_LIMITS", "Seuils"))
  p:Slider(T("OPT_DUR", "Usure : prévenir sous (%)"), 10, 90, 5,
    function() return db.durWarn end, function(v) db.durWarn = v; RU.Evaluate("manual") end)
  p:Slider(T("OPT_BAGS", "Sacs : prévenir sous (places)"), 1, 20, 1,
    function() return db.bagWarn end, function(v) db.bagWarn = v; RU.Evaluate("manual") end)
  p:Slider(T("OPT_AMMO", "Munitions : prévenir sous"), 50, 1000, 50,
    function() return db.ammoWarn end, function(v) db.ammoWarn = v; RU.Evaluate("manual") end)
  p:Slider(T("OPT_REAGENTS", "Composants : prévenir sous"), 1, 20, 1,
    function() return db.reagentWarn end, function(v) db.reagentWarn = v; RU.Evaluate("manual") end)
  p:Slider(T("OPT_TOAST_TIME", "Durée de l'alerte (secondes)"), 4, 30, 1,
    function() return db.toastTime end, function(v) db.toastTime = v end)
  p:Button(T("BTN_TOAST_RESET", "Replacer l'alerte en haut de l'écran"), function()
    db.toastPos = nil
    local t = _G.TibiReadyUpToast
    if t then t:ClearAllPoints(); t:SetPoint("TOP", UIParent, "TOP", 0, -160) end
  end)

  -- Section standard, toujours en dernier (socle v22).
  if p.FloatControls then p:FloatControls(FLOAT_FRAME, { search = true }) end
  return p
end

function TibiReadyUp_OpenOptions()
  if not TibiReadyUpDB then return end
  if not optionsPanel then optionsPanel = BuildOptions() end
  optionsPanel:Toggle()
end
