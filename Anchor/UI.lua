--[[============================================================================
  Anchor - UI.lua
  ---------------------------------------------------------------------------
  Fenetre principale (TibiAnchorMainFrame) : etat de chaque fenetre du catalogue
  (deplacee, d'origine, pas encore chargee, geree par un autre addon,
  protegee), bouton pour la remettre a sa place, actions globales.
  Panneau d'options (TibiAnchorOptions, socle) : comportement, magnetisme,
  dispositions, cohabitation.
  Valide en jeu par Tibiscui le 2026-11-10 (7.5.0).
============================================================================]]

local ADDON, AN = ...
local T = AN.T
local ACCENT = AN.ACCENT

local function GetUI() return _G.TibiMidnight end

local main, optionsPanel
local rows = {}
local ROW_H = 22

local function AccentText(s) return AN.Hex() .. s .. "|r" end

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
    local logo = UI.AddHeaderLogo(f, AN.LOGO, 20)
    if logo then logo:ClearAllPoints(); logo:SetPoint("LEFT", hdr, "LEFT", 10, 0) end
  end
  local tt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  tt:SetPoint("LEFT", hdr, "LEFT", 36, 0)
  tt:SetText(AccentText(title))
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() f:Hide() end)
  f:Hide()
  tinsert(UISpecialFrames, name)
  return f
end

-- ============================================================================
-- ETAT D'UNE ENTREE DU CATALOGUE
-- Renvoie : texte d'etat, rang de tri (0 = deplacee ... 4 = absente), nom.
-- ============================================================================
local function Fmt(v) return string.format("%d", math.floor((v or 0) + 0.5)) end

local function StatusOf(e)
  local name = AN.NameOf(e) or e.names[1]
  local f = _G[name]
  local pos = AN.GetPos(name)
  local conflict = AN.Conflict()
  if conflict and not TibiAnchorDB.force then
    return "|cFFFF7F7F" .. T("TAG_MANAGED", "gérée par ") .. conflict .. "|r", 3, name
  end
  if type(f) ~= "table" then
    if pos then return AccentText(T("TAG_MOVED_PENDING", "déplacée, appliquée à l'ouverture")), 0, name end
    return "|cFF888888" .. T("TAG_PENDING", "pas encore chargée (ou absente de cette version)") .. "|r", 4, name
  end
  if AN.Refused(f) then return "|cFFFFB347" .. T("TAG_PROTECTED", "protégée : non prise en charge") .. "|r", 3, name end
  local by = AN.ManagedBy(name, f)
  if by then return "|cFFFF7F7F" .. T("TAG_MANAGED", "gérée par ") .. by .. "|r", 3, name end
  if pos then
    local s = pos.s and (", " .. math.floor(pos.s * 100 + 0.5) .. " %") or ""
    return AccentText(T("TAG_MOVED", "déplacée")) .. "  |cFFAAAAAA" .. pos.p .. " " .. Fmt(pos.x) .. ", " .. Fmt(pos.y) .. s .. "|r", 0, name
  end
  if e.place == "proxy" then return "|cFFCCCCCC" .. T("TAG_PROXY", "d'origine (mode Placement)") .. "|r", 1, name end
  return "|cFFCCCCCC" .. T("TAG_DEFAULT", "d'origine") .. "|r", 2, name
end

-- ============================================================================
-- LISTE
-- ============================================================================
local function MakeRow(parent)
  local UI = GetUI()
  local r = CreateFrame("Frame", nil, parent)
  r:SetHeight(ROW_H)
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, 0.03)
  r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.label:SetPoint("LEFT", 8, 0); r.label:SetWidth(230); r.label:SetJustifyH("LEFT")
  r.status = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.status:SetPoint("LEFT", r.label, "RIGHT", 6, 0); r.status:SetWidth(290); r.status:SetJustifyH("LEFT")
  r.reset = UI.MakeButton(r, 70, 18, T("BTN_RESET", "Origine"))
  r.reset:SetPoint("RIGHT", -6, 0)
  r.reset:SetScript("OnClick", function() if r.name then AN.Reset(r.name, true) end end)
  r.reset:HookScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
    GameTooltip:SetText(T("TT_RESET", "Remet cette fenêtre à la place et à la taille choisies par le jeu."), 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  r.reset:HookScript("OnLeave", function() GameTooltip:Hide() end)
  return r
end

local function RefreshList()
  if not (main and main:IsShown()) then return end
  local list = {}
  for _, e in ipairs(AN.CATALOG) do
    local text, rank, name = StatusOf(e)
    if rank < 4 or main.showAll then
      list[#list + 1] = { e = e, text = text, rank = rank, name = name }
    end
  end
  table.sort(list, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    if a.e.cat ~= b.e.cat then return a.e.cat == "loot" end
    return a.e.label < b.e.label
  end)
  local content = main.content
  for i, it in ipairs(list) do
    local r = rows[i]
    if not r then r = MakeRow(content); rows[i] = r end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * (ROW_H + 2))
    r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    r.name = it.name
    local tag = it.e.cat == "loot" and ("|cFFFFD100" .. T("CAT_LOOT", "Butin") .. "|r  ") or ""
    r.label:SetText(tag .. it.e.label)
    r.status:SetText(it.text)
    r.reset:SetShown(AN.GetPos(it.name) ~= nil)
    r:Show()
  end
  for i = #list + 1, #rows do rows[i]:Hide() end
  content:SetHeight(math.max(#list * (ROW_H + 2), 10))

  local n = 0
  for _ in pairs(AN.Positions()) do n = n + 1 end
  local lk = AN.LayoutKey() == "*" and T("LAYOUT_ACCOUNT", "compte") or T("LAYOUT_CHAR", "ce personnage")
  main.summary:SetText(string.format(T("SUMMARY", "Disposition : %s  |  écran : %s  |  %d fenêtre(s) déplacée(s)"),
    lk, AN.ResKey() == "*" and T("RES_ANY", "toutes résolutions") or AN.ResKey(), n))
  main.enabled:SetChecked(TibiAnchorDB.enabled)
end
AN.RefreshUI = RefreshList

-- Masquage des boutons flottants, en suite ET en standalone (socle v21) :
-- l'etat est aussi garde dans TibiAnchorDB.floatHidden.
local FLOAT_FRAME = "TibiAnchorMainFrame"
local function FloatUI()
  local u = _G.TibiMidnight
  if u and u.RegisterCtrlStore then u.RegisterCtrlStore(FLOAT_FRAME, function() return _G.TibiAnchorDB end) end
  return u
end
FloatUI()

local function BuildMain()
  local UI = GetUI()
  main = Window("TibiAnchorMainFrame", 680, 520, "Anchor")
  local w = TibiAnchorDB.win
  if type(w) == "table" and w.point then
    main:ClearAllPoints()
    main:SetPoint(w.point, UIParent, w.relPoint or w.point, tonumber(w.x) or 0, tonumber(w.y) or 0)
  end
  main:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local p, _, rp, x, y = s:GetPoint(1)
    TibiAnchorDB.win = { point = p, relPoint = rp, x = x, y = y }
  end)

  main.enabled = CreateFrame("CheckButton", nil, main, "UICheckButtonTemplate")
  main.enabled:SetSize(24, 24)
  main.enabled:SetPoint("TOPLEFT", 12, -40)
  local et = main.enabled:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  et:SetPoint("LEFT", main.enabled, "RIGHT", 2, 0); et:SetText(T("HDR_ENABLED", "Actif"))
  main.enabled:SetScript("OnClick", function(s)
    AN.SetEnabled(s:GetChecked())
    RefreshList()
  end)

  main.summary = main:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  main.summary:SetPoint("LEFT", et, "RIGHT", 16, 0)

  local hint = main:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 16, -68); hint:SetWidth(650); hint:SetJustifyH("LEFT")
  hint:SetText(T("HINT", "Glisse une fenêtre du jeu pour la déplacer (Alt : sans aimant). Maj + clic droit : position d'origine. "
    .. "Ctrl + molette : taille. Ctrl + clic droit : taille d'origine."))

  -- Liste defilante
  local scroll = CreateFrame("ScrollFrame", nil, main, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -96)
  scroll:SetPoint("BOTTOMRIGHT", -32, 48)
  if UI.SkinScrollBar then UI.SkinScrollBar(scroll, ACCENT) end
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(630, 10)
  scroll:SetScrollChild(content)
  main.content = content

  -- Pied : actions
  local function Btn(text, w, onClick, tip)
    local b = UI.MakeButton(main, w, 24, text)
    b:SetScript("OnClick", onClick)
    if tip then
      b:HookScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:SetText(tip, 1, 1, 1, 1, true); GameTooltip:Show() end)
      b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return b
  end
  local bLoot = Btn(T("BTN_LOOT", "Placer le butin"), 130, function() AN.Loot.Toggle() end,
    T("TT_LOOT", "Affiche des cadres à placer pour les lancers de dés et le jet de bonus, qui n'apparaissent que quelques secondes."))
  bLoot:SetPoint("BOTTOMLEFT", 12, 12)
  local bUndo = Btn(T("BTN_UNDO", "Annuler"), 90, function() AN.Undo() end,
    T("TT_UNDO", "Annule le dernier déplacement (20 pas, pendant la session)."))
  bUndo:SetPoint("LEFT", bLoot, "RIGHT", 6, 0)
  local bAll = Btn(T("BTN_RESET_ALL", "Tout remettre"), 120, function()
    local TS = _G.TibiSuite
    local msg = T("ASK_RESET_ALL", "Remettre toutes les fenêtres de cette disposition à leur place d'origine ?")
    if TS and TS.ShowConfirm then TS.ShowConfirm(msg, function() AN.ResetAll() end) else AN.ResetAll() end
  end)
  bAll:SetPoint("LEFT", bUndo, "RIGHT", 6, 0)
  local bShowAll = Btn(T("BTN_SHOW_ALL", "Tout le catalogue"), 130, function()
    main.showAll = not main.showAll; RefreshList()
  end, T("TT_SHOW_ALL", "Affiche aussi les fenêtres pas encore chargées par le jeu ou absentes de cette version."))
  bShowAll:SetPoint("LEFT", bAll, "RIGHT", 6, 0)

  if UI.AddHeaderControls then
    UI.AddHeaderControls(main, { accent = ACCENT, onOptions = function() TibiAnchor_OpenOptions() end,
      provider = AN.SearchProvider })
  end
  main:SetScript("OnShow", RefreshList)
end

function AN.ShowMain()
  if not TibiAnchorDB then return end
  if not main then BuildMain() end
  main:Show()
  RefreshList()
end

function TibiAnchor_Toggle()
  if not TibiAnchorDB then return end
  if not main then BuildMain() end
  main:SetShown(not main:IsShown())
end

-- ============================================================================
-- OPTIONS (socle)
-- ============================================================================
local function BuildOptions()
  local UI = GetUI()
  local p = UI.CreateOptionsPanel({ name = "TibiAnchorOptions", title = T("OPT_TITLE", "Anchor : options"), accent = ACCENT, logo = AN.LOGO })
  local db = TibiAnchorDB

  p:Section(T("OPT_SEC_MOVE", "Déplacement"))
  p:Check(T("OPT_SHIFT", "Tenir Maj pour déplacer"),
    function() return db.modifier == "shift" end,
    function(v) db.modifier = v and "shift" or "none" end,
    T("TT_SHIFT", "Évite de déplacer une fenêtre par erreur en cliquant dessus."))
  p:Check(T("OPT_CLAMP", "Garder les fenêtres dans l'écran"),
    function() return db.clamp end, function(v) db.clamp = v end)
  p:Check(T("OPT_WHEEL", "Ctrl + molette : taille de la fenêtre"),
    function() return db.wheelScale end, function(v) db.wheelScale = v; AN.ReapplyAll() end,
    T("TT_WHEEL", "Décoché : les tailles enregistrées ne sont plus appliquées (elles restent en mémoire)."))

  p:Section(T("OPT_SEC_SNAP", "Magnétisme"))
  p:Check(T("OPT_SNAP", "Aimanter aux bords et au centre de l'écran"),
    function() return db.snap end, function(v) db.snap = v end,
    T("TT_SNAP", "Tenir Alt pendant le déplacement pour poser librement."))
  p:Check(T("OPT_SNAP_WIN", "Aimanter aussi aux autres fenêtres ouvertes"),
    function() return db.snapWindows end, function(v) db.snapWindows = v end)
  p:Check(T("OPT_GUIDES", "Afficher les repères d'alignement"),
    function() return db.guides end, function(v) db.guides = v end)
  p:Slider(T("OPT_SNAP_DIST", "Distance d'aimantation (px)"), 4, 32, 1,
    function() return db.snapDist end, function(v) db.snapDist = v end)
  p:Check(T("OPT_GRID", "Afficher une grille pendant le déplacement"),
    function() return db.grid end, function(v) db.grid = v end)
  p:Slider(T("OPT_GRID_SIZE", "Pas de la grille (px)"), 16, 96, 8,
    function() return db.gridSize end, function(v) db.gridSize = v end)

  p:Section(T("OPT_SEC_LAYOUT", "Dispositions"))
  p:Check(T("OPT_PER_RES", "Une disposition par résolution d'écran"),
    function() return db.perResolution end, function(v) db.perResolution = v; AN.ReapplyAll(); AN.OnChanged() end,
    T("TT_PER_RES", "Portable et écran de bureau gardent chacun leurs positions. Changer d'écran applique la bonne disposition."))
  p:Check(T("OPT_CHAR", "Disposition propre à ce personnage"),
    function() return db.charLayout[AN.CharKey()] and true or false end,
    function(v) db.charLayout[AN.CharKey()] = v or nil; AN.ReapplyAll(); AN.OnChanged() end,
    T("TT_CHAR", "Décoché : ce personnage utilise la disposition commune au compte."))
  p:Button(T("BTN_COPY_ACCOUNT", "Copier la disposition du compte ici"), function()
    if AN.LayoutKey() == "*" then AN.Print(T("MSG_COPY_SAME", "ce personnage utilise déjà la disposition du compte.")); return end
    local src = db.layouts["*"] and db.layouts["*"][AN.ResKey()]
    if not src then AN.Print(T("MSG_COPY_EMPTY", "la disposition du compte est vide pour cet écran.")); return end
    local dst = AN.Positions()
    for k, v in pairs(src) do dst[k] = AN.CopyPos(v) end
    AN.ReapplyAll(); AN.OnChanged()
    AN.Print(T("MSG_COPY_DONE", "disposition du compte copiée sur ce personnage."))
  end)

  p:Section(T("OPT_SEC_COMPAT", "Cohabitation"))
  p:Note(T("NOTE_COMPAT", "Anchor laisse la main à BlizzMove et MoveAny s'ils sont chargés, au Shifter d'EllesmereUI pour les fenêtres de sa liste, "
    .. "et à ElvUI pour son butin, ses lancers de dés, ses sacs et ses « movers »."))
  p:Check(T("OPT_FORCE", "Forcer (déconseillé)"),
    function() return db.force end, function(v) db.force = v; AN.Scan(); AN.ReapplyAll(); AN.OnChanged() end,
    T("TT_FORCE", "Anchor agit même sur les fenêtres gérées par un autre addon : les deux se disputeront la position."))

  -- Section standard, toujours en dernier (socle v22).
  if p.FloatControls then p:FloatControls(FLOAT_FRAME, { search = true }) end
  return p
end

function TibiAnchor_OpenOptions()
  if not TibiAnchorDB then return end
  if not optionsPanel then optionsPanel = BuildOptions() end
  optionsPanel:Toggle()
end
