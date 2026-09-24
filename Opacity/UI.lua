--[[============================================================================
  Opacity - UI.lua
  ---------------------------------------------------------------------------
  Fenetre principale (OpacityMainFrame) :
    - en-tete : case Actif, curseur maitre, contexte actif ;
    - barre d'actions : Pipette, Reinitialiser, Ajouter, Prereglages, Capture, Exporter,
      Importer, Annuler ;
    - liste des fenetres controlees : opacite, fondu au survol, suit les
      contextes, Forcer (frames d'ElvUI / EllesmereUI), retirer.
  Fenetres annexes : "Ajouter" (catalogue groupe + filtre), code
  d'export / import, menu des prereglages, et le panneau d'options du socle.

  Echap : UISpecialFrames uniquement (mecanisme natif, cf. TibiSuiteCore.lua),
  jamais de OnKeyDown ni de OnHide sur ces fenetres.
============================================================================]]

local ADDON, OP = ...
local T = OP.T
local ACCENT = OP.ACCENT

local function GetUI() return _G.TibiMidnight end

local main, list, rows = nil, nil, {}
local ROW_H, LIST_W = 28, 678
local refreshing = false

local function AccentText(s)
  return string.format("|cFF%02X%02X%02X%s|r", math.floor(ACCENT[1]*255+0.5), math.floor(ACCENT[2]*255+0.5),
    math.floor(ACCENT[3]*255+0.5), s)
end

local function Pct(v) return math.floor((v or 0) * 100 + 0.5) .. " %" end

-- ============================================================================
-- PETITES BRIQUES
-- ============================================================================
local function Check(parent, label, tooltip)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  if label then
    local t = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    t:SetText(label)
    cb._text = t
  end
  if tooltip then
    cb:SetScript("OnEnter", function(s)
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(tooltip, 1, 1, 1, 1, true); GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return cb
end

local function Slider(parent, w)
  local sl = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  sl:SetWidth(w)
  sl:SetMinMaxValues(0, 100)
  sl:SetValueStep(5)
  sl:SetObeyStepOnDrag(true)
  if sl.Low then sl.Low:SetText("") end
  if sl.High then sl.High:SetText("") end
  if sl.Text then sl.Text:SetText("") end
  return sl
end

local function Button(parent, w, text, tooltip)
  local UI = GetUI()
  local b = UI.MakeButton(parent, w, 22, text)
  if tooltip then
    b:HookScript("OnEnter", function(s)
      GameTooltip:SetOwner(s, "ANCHOR_BOTTOM"); GameTooltip:SetText(tooltip, 1, 1, 1, 1, true); GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return b
end

-- Fenetre plate du socle avec en-tete, titre et croix (sans logo, demande Tibiscui).
local function Window(name, w, h, title, strata)
  local UI = GetUI()
  local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  f:SetSize(w, h)
  f:SetPoint("CENTER")
  f:SetFrameStrata(strata or "HIGH")
  f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  UI.SkinFrame(f, ACCENT, UI.C.BG)
  local hdr = f:CreateTexture(nil, "ARTWORK")
  hdr:SetColorTexture(UI.C.HDR[1], UI.C.HDR[2], UI.C.HDR[3], 1)
  hdr:SetPoint("TOPLEFT", 1, -3); hdr:SetPoint("TOPRIGHT", -1, -3); hdr:SetHeight(30)
  local tt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  tt:SetPoint("LEFT", hdr, "LEFT", 12, 0)
  tt:SetText(AccentText(title))
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() f:Hide() end)
  f:Hide()
  tinsert(UISpecialFrames, name)
  return f
end

-- ============================================================================
-- LIGNES DE LA LISTE
-- ============================================================================
local function StatusTag(name, entry)
  local tags = {}
  local f = _G[name]
  if not OP.IsUsableFrame(f) then
    tags[#tags + 1] = "|cFF888888" .. T("TAG_PENDING", "pas encore créée") .. "|r"
  elseif f.IsProtected and f:IsProtected() then
    tags[#tags + 1] = "|cFFFFB347" .. T("TAG_PROTECTED", "protégée") .. "|r"
  end
  local managed = OP.ManagedBy(name)
  if managed then
    tags[#tags + 1] = (entry.force and "|cFF66D98A" or "|cFFFF7F7F") .. T("TAG_MANAGED", "gérée par ") .. managed .. "|r"
  end
  local owner = OP.OwnerOf(name)
  if owner and owner ~= "Blizzard" then tags[#tags + 1] = "|cFFAAAAAA" .. owner .. "|r" end
  return table.concat(tags, "  ")
end

local function MakeRow(i)
  local r = CreateFrame("Frame", nil, list)
  r:SetSize(LIST_W, ROW_H)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)

  local bg = r:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0)

  r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.label:SetPoint("TOPLEFT", 6, -3)
  r.label:SetWidth(328); r.label:SetJustifyH("LEFT"); r.label:SetWordWrap(false)
  r.tag = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  r.tag:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -1)
  r.tag:SetWidth(328); r.tag:SetJustifyH("LEFT"); r.tag:SetWordWrap(false)
  r.tag:SetFontObject("GameFontDisableSmall")

  r.slider = Slider(r, 150)
  r.slider:SetPoint("LEFT", r, "LEFT", 344, 0)
  r.value = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.value:SetPoint("LEFT", r.slider, "RIGHT", 6, 0)
  r.value:SetWidth(40); r.value:SetJustifyH("LEFT")
  r.slider:SetScript("OnValueChanged", function(s, v)
    v = math.floor(v / 5 + 0.5) * 5
    r.value:SetText(v .. " %")
    if not refreshing and r.name then OP.SetFrameField(r.name, "alpha", v / 100) end
  end)

  r.hover = Check(r, nil, T("TT_HOVER", "Fondu au survol : la fenêtre repasse à 100 % sous la souris."))
  r.hover:SetPoint("LEFT", r, "LEFT", 548, 0)
  r.hover:SetScript("OnClick", function(s) if r.name then OP.SetFrameField(r.name, "hover", s:GetChecked()) end end)

  r.ctx = Check(r, nil, T("TT_CTX", "Suit les contextes (combat, raid, monture...). Décoché : garde toujours son opacité réglée."))
  r.ctx:SetPoint("LEFT", r, "LEFT", 594, 0)
  r.ctx:SetScript("OnClick", function(s) if r.name then OP.SetFrameField(r.name, "ctx", s:GetChecked()) end end)

  r.force = Check(r, nil, T("TT_FORCE", "Cette fenêtre est pilotée par une suite d'interface. Forcer : Opacity s'applique quand même, "
    .. "en multipliant l'opacité que la suite lui donne (leur fondu continue de fonctionner)."))
  r.force:SetPoint("LEFT", r, "LEFT", 624, 0)
  r.force:SetScript("OnClick", function(s) if r.name then OP.SetFrameField(r.name, "force", s:GetChecked()) end end)

  r.remove = CreateFrame("Button", nil, r, "UIPanelCloseButton")
  r.remove:SetSize(22, 22)
  r.remove:SetPoint("LEFT", r, "LEFT", 654, 0)
  r.remove:SetScript("OnClick", function() if r.name then OP.RemoveFrame(r.name) end end)
  r.remove:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(T("TT_REMOVE", "Retirer (la fenêtre retrouve son opacité d'origine)"), 1, 1, 1, 1, true); GameTooltip:Show()
  end)
  r.remove:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return r
end

local function SortedNames()
  local names = {}
  for name in pairs(OP.Profile().frames) do names[#names + 1] = name end
  table.sort(names, function(a, b) return OP.LabelOf(a):lower() < OP.LabelOf(b):lower() end)
  return names
end

local function RefreshList()
  if not (main and main:IsShown()) then return end
  refreshing = true
  local p = OP.Profile()
  local names = SortedNames()
  for i, name in ipairs(names) do
    local r = rows[i] or MakeRow(i)
    rows[i] = r
    local e = p.frames[name]
    r.name = name
    local label = OP.LabelOf(name)
    r.label:SetText(label == name and name or (label .. "  |cFF777777" .. name .. "|r"))
    r.tag:SetText(StatusTag(name, e))
    r.slider:SetValue(math.floor(e.alpha * 100 + 0.5))
    r.value:SetText(Pct(e.alpha))
    r.hover:SetChecked(e.hover)
    r.ctx:SetChecked(e.ctx)
    local managed = OP.ManagedBy(name) ~= nil
    r.force:SetShown(managed)
    r.force:SetChecked(e.force)
    local usable = not managed or e.force
    if usable then r.slider:Enable() else r.slider:Disable() end
    r.slider:SetAlpha(usable and 1 or 0.4)
    r:Show()
  end
  for i = #names + 1, #rows do rows[i]:Hide(); rows[i].name = nil end
  list:SetHeight(math.max(#names * ROW_H, 1))
  main.empty:SetShown(#names == 0)

  -- En-tete
  main.enabled:SetChecked(OpacityDB.enabled)
  main.master:SetValue(math.floor(p.master * 100 + 0.5))
  main.masterValue:SetText(Pct(p.master))
  local ctx = OP.activeContext
  local ctxText
  if OP.SuiteDisabled() then
    ctxText = "|cFFFF7F7F" .. T("HDR_SUITE_OFF", "module décoché dans TibiSuite (/ts modules)") .. "|r"
  elseif not OpacityDB.enabled then
    ctxText = "|cFFFF7F7F" .. T("HDR_PAUSED", "suspendu") .. "|r"
  elseif OP.screenshot then
    ctxText = AccentText(T("HDR_SHOT", "mode capture d'écran"))
  elseif ctx then
    ctxText = AccentText(OP.CONTEXT_LABELS[ctx] .. " (" .. Pct(p.contexts[ctx].value) .. ")")
  else
    ctxText = "|cFF888888" .. T("HDR_NOCTX", "aucun") .. "|r"
  end
  main.ctxText:SetText(T("HDR_CONTEXT", "Contexte : ") .. ctxText)
  main.undo:SetAlpha(type(OpacityDB.undo) == "table" and 1 or 0.4)
  main.shot._label:SetText(OP.screenshot and AccentText(T("BTN_SHOT_OFF", "Réafficher")) or T("BTN_SHOT", "Capture"))
  refreshing = false
end

-- Appele par le moteur apres chaque changement (Core.lua). Differe au tick
-- suivant et regroupe : un glissement de curseur ne reconstruit pas la liste
-- a chaque pixel.
local refreshQueued = false
OP.OnRefresh = function()
  if refreshQueued or not (main and main:IsShown()) then return end
  refreshQueued = true
  C_Timer.After(0, function() refreshQueued = false; RefreshList() end)
end

-- ============================================================================
-- FENETRE "AJOUTER"
-- ============================================================================
local addWin, addContent, addRows, addFilter = nil, nil, {}, ""

local function RefreshAdd()
  if not (addWin and addWin:IsShown()) then return end
  local p = OP.Profile()
  local groups = OP.BuildCatalogGroups()
  local UI = GetUI()
  local needle = UI.Normalize(addFilter)
  local y, n = 0, 0
  local function Row()
    n = n + 1
    local r = addRows[n]
    if not r then
      r = CreateFrame("CheckButton", nil, addContent, "UICheckButtonTemplate")
      r:SetSize(20, 20)
      r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      r.text:SetPoint("LEFT", r, "RIGHT", 2, 0)
      r.text:SetWidth(330); r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
      r.header = addContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      addRows[n] = r
    end
    r.header:Hide(); r:Hide()
    return r
  end
  for _, g in ipairs(groups) do
    local shown = {}
    for _, it in ipairs(g.items) do
      if needle == "" or UI.Match(it.label .. " " .. it.name .. " " .. g.title, needle) then shown[#shown + 1] = it end
    end
    if #shown > 0 then
      local h = Row()
      h.header:ClearAllPoints()
      h.header:SetPoint("TOPLEFT", addContent, "TOPLEFT", 4, -y - 6)
      h.header:SetText(AccentText(g.title) .. (g.addon and ("  |cFF777777" .. T("ADD_ADDON_HINT", "(addon)") .. "|r") or ""))
      h.header:Show()
      y = y + 24
      for _, it in ipairs(shown) do
        local r = Row()
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", addContent, "TOPLEFT", 8, -y)
        local extra = ""
        if not it.exists then extra = extra .. "  |cFF777777" .. T("TAG_PENDING", "pas encore créée") .. "|r" end
        if it.protected then extra = extra .. "  |cFFFFB347" .. T("TAG_PROTECTED", "protégée") .. "|r" end
        if it.managed then extra = extra .. "  |cFFFF7F7F" .. T("TAG_MANAGED", "gérée par ") .. it.managed .. "|r" end
        local label = it.label == it.name and it.name or (it.label .. "  |cFF777777" .. it.name .. "|r")
        r.text:SetText(label .. extra)
        r:SetChecked(p.frames[it.name] ~= nil)
        local itemName = it.name
        r:SetScript("OnClick", function(s)
          if s:GetChecked() then OP.AddFrame(itemName) else OP.RemoveFrame(itemName) end
        end)
        r:Show()
        y = y + 22
      end
      y = y + 4
    end
  end
  for i = n + 1, #addRows do addRows[i]:Hide(); addRows[i].header:Hide() end
  addContent:SetHeight(math.max(y, 1))
end

local function ShowAdd()
  if not addWin then
    addWin = Window("OpacityAddFrame", 420, 520, T("ADD_TITLE", "Ajouter des fenêtres"), "DIALOG")
    local note = addWin:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 12, -40); note:SetWidth(396); note:SetJustifyH("LEFT")
    note:SetText(T("ADD_NOTE", "Cochez pour contrôler une fenêtre. Les addons sont détectés parmi les fenêtres déjà créées : "
      .. "si l'un manque, ouvrez sa fenêtre puis rouvrez cette liste, ou utilisez la Pipette."))
    local UI = GetUI()
    local box = CreateFrame("EditBox", nil, addWin, "BackdropTemplate")
    box:SetSize(396, 20)
    box:SetPoint("TOPLEFT", 12, -76)
    box:SetBackdrop(UI.FlatBackdrop())
    box:SetBackdropColor(0.02, 0.02, 0.03, 0.9)
    box:SetBackdropBorderColor(1, 1, 1, 0.15)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(6, 6, 0, 0)
    local ph = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 6, 0); ph:SetText(T("ADD_FILTER", "Filtrer..."))
    box:SetScript("OnTextChanged", function(s)
      addFilter = s:GetText() or ""
      ph:SetShown(addFilter == "")
      RefreshAdd()
    end)
    box:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)

    local scroll = CreateFrame("ScrollFrame", nil, addWin, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -102)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    addContent = CreateFrame("Frame", nil, scroll)
    addContent:SetSize(370, 10)
    scroll:SetScrollChild(addContent)
    addWin:SetScript("OnShow", RefreshAdd)
  end
  addWin:Show()
end

-- ============================================================================
-- CODE D'EXPORT / IMPORT
-- ============================================================================
local codeWin

local function ShowCode(mode)
  if not codeWin then
    codeWin = Window("OpacityCodeFrame", 460, 300, "Opacity", "DIALOG")
    codeWin.info = codeWin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    codeWin.info:SetPoint("TOPLEFT", 12, -42); codeWin.info:SetWidth(436); codeWin.info:SetJustifyH("LEFT")
    local UI = GetUI()
    local holder = CreateFrame("Frame", nil, codeWin, "BackdropTemplate")
    holder:SetPoint("TOPLEFT", 12, -80); holder:SetPoint("BOTTOMRIGHT", -12, 44)
    holder:SetBackdrop(UI.FlatBackdrop())
    holder:SetBackdropColor(0.02, 0.02, 0.03, 0.9)
    holder:SetBackdropBorderColor(1, 1, 1, 0.15)
    local scroll = CreateFrame("ScrollFrame", nil, holder, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6); scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true); box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetWidth(400)
    box:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    scroll:SetScrollChild(box)
    holder:EnableMouse(true)
    holder:SetScript("OnMouseDown", function() box:SetFocus() end)
    codeWin.box = box
    codeWin.go = Button(codeWin, 140, T("BTN_DO_IMPORT", "Importer ce code"))
    codeWin.go:SetPoint("BOTTOMRIGHT", -12, 12)
    codeWin.go:SetScript("OnClick", function()
      local ok, msg = OP.ImportCode(box:GetText())
      OP.Print(msg)
      if ok then codeWin:Hide() end
    end)
  end
  codeWin.mode = mode
  if mode == "export" then
    codeWin.info:SetText(T("EXP_INFO", "Copiez ce code (Ctrl+A puis Ctrl+C) pour sauvegarder ou partager votre profil. "
      .. "Il contient vos fenêtres, contextes, fondus et le curseur maître."))
    codeWin.box:SetText(OP.ExportCode())
    codeWin.go:Hide()
    codeWin:Show()
    codeWin.box:SetFocus(); codeWin.box:HighlightText()
  else
    codeWin.info:SetText(T("IMP_INFO", "Collez un code Opacity (Ctrl+V) puis validez. Il remplace votre profil actuel ; "
      .. "le bouton « Annuler » de la fenêtre principale restaure l'ancien."))
    codeWin.box:SetText("")
    codeWin.go:Show()
    codeWin:Show()
    codeWin.box:SetFocus()
  end
end

-- ============================================================================
-- MENU DES PREREGLAGES
-- ============================================================================
local presetMenu

local function TogglePresets(anchor)
  if not presetMenu then
    local UI = GetUI()
    presetMenu = CreateFrame("Frame", nil, main, "BackdropTemplate")
    presetMenu:SetFrameStrata("DIALOG")
    UI.SkinFrame(presetMenu, ACCENT, UI.C.PANEL)
    local y = -8
    local entries = {}
    for _, pre in ipairs(OP.PRESETS) do entries[#entries + 1] = pre end
    entries[#entries + 1] = {
      key = "shot", label = T("PRE_SHOT", "Capture d'écran"),
      desc = T("PRE_SHOT_D", "Fait disparaître toute l'interface. Prenez votre capture (Impr. écran) : "
        .. "tout réapparaît automatiquement juste après, ou avec Échap. Aussi disponible en raccourci clavier."),
    }
    -- Sortie de secours, toujours en bas du menu : tout remettre a l'opacite
    -- normale d'un clic (suspend Opacity sans rien effacer), puis reactiver.
    entries[#entries + 1] = {
      key = "restore", label = T("PRE_RESTORE", "Tout réafficher"),
      desc = T("PRE_RESTORE_D", "Remet immédiatement toutes les fenêtres à leur opacité normale, sans perdre vos réglages. "
        .. "Cliquez à nouveau (« Réactiver Opacity ») pour les retrouver."),
    }
    for _, pre in ipairs(entries) do
      local b = Button(presetMenu, 180, pre.label, pre.desc)
      b:SetPoint("TOP", 0, y)
      b:SetScript("OnClick", function()
        presetMenu:Hide()
        if pre.key == "shot" then Opacity_ToggleScreenshot()
        elseif pre.key == "restore" then Opacity_ToggleEnabled()
        else OP.ApplyPreset(pre.key) end
      end)
      if pre.key == "restore" then presetMenu.restore = b end
      y = y - 26
    end
    presetMenu:SetSize(196, -y + 6)
    presetMenu:Hide()
  end
  -- Libelle de l'entree de secours selon l'etat courant.
  presetMenu.restore._label:SetText(OpacityDB.enabled and T("PRE_RESTORE", "Tout réafficher")
    or AccentText(T("PRE_REACTIVATE", "Réactiver Opacity")))
  presetMenu:ClearAllPoints()
  presetMenu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  presetMenu:SetShown(not presetMenu:IsShown())
end

-- ============================================================================
-- FENETRE PRINCIPALE
-- ============================================================================
local function SavePosition()
  local point, _, relPoint, x, y = main:GetPoint(1)
  OpacityDB.win = { point = point, relPoint = relPoint, x = x, y = y }
end

local function BuildMain()
  main = Window("OpacityMainFrame", 720, 500, "Opacity")
  main:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); SavePosition() end)
  local w = OpacityDB.win
  if type(w) == "table" and w.point then
    main:ClearAllPoints()
    main:SetPoint(w.point, UIParent, w.relPoint or w.point, tonumber(w.x) or 0, tonumber(w.y) or 0)
  end

  -- Ligne 1 : actif, curseur maitre, contexte
  main.enabled = Check(main, T("HDR_ENABLED", "Actif"), T("TT_ENABLED", "Décoché : toutes les fenêtres retrouvent leur opacité d'origine, sans perdre vos réglages."))
  main.enabled:SetPoint("TOPLEFT", 12, -42)
  main.enabled:SetScript("OnClick", function(s) OP.SetEnabled(s:GetChecked()) end)

  local mcap = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mcap:SetPoint("LEFT", main.enabled, "RIGHT", 60, 0)
  mcap:SetText(T("HDR_MASTER", "Curseur maître"))
  main.master = Slider(main, 160)
  main.master:SetPoint("LEFT", mcap, "RIGHT", 10, 0)
  main.masterValue = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  main.masterValue:SetPoint("LEFT", main.master, "RIGHT", 6, 0)
  main.master:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v / 5 + 0.5) * 5
    main.masterValue:SetText(v .. " %")
    if not refreshing then OP.SetMaster(v / 100) end
  end)
  main.master:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
    GameTooltip:SetText(T("TT_MASTER", "Multiplie toutes les opacités de la liste. Raccourcis clavier disponibles (+/- 10 %)."), 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  main.master:SetScript("OnLeave", function() GameTooltip:Hide() end)

  main.ctxText = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  main.ctxText:SetPoint("TOPRIGHT", -14, -48)
  main.ctxText:SetJustifyH("RIGHT")

  -- Ligne 2 : actions
  local x = 12
  local function Action(w, text, tip, fn)
    local b = Button(main, w, text, tip)
    b:SetPoint("TOPLEFT", x, -74)
    b:SetScript("OnClick", fn)
    x = x + w + 6
    return b
  end
  Action(76, T("BTN_PICK", "Pipette"), T("TT_PICK", "Survolez n'importe quelle fenêtre du jeu et cliquez pour l'ajouter."), function()
    main:Hide(); OP.StartPicker()
  end)
  Action(96, T("BTN_RESET", "Réinitialiser"), T("TT_RESET", "Vide la liste : toutes les fenêtres retrouvent leur opacité d'origine, "
    .. "contextes et curseur maître reviennent aux valeurs par défaut. « Annuler » restaure le profil précédent."), function()
    OP.ResetProfile()
  end)
  Action(80, T("BTN_ADD", "Ajouter..."), T("TT_ADD", "Choisir dans la liste des fenêtres Blizzard, TibiSuite et des addons détectés."), ShowAdd)
  local pre
  pre = Action(92, T("BTN_PRESETS", "Préréglages"), nil, function() TogglePresets(pre) end)
  main.shot = Action(76, T("BTN_SHOT", "Capture"), T("TT_SHOT", "Mode capture d'écran : fait disparaître toute l'interface jusqu'à votre prochaine capture (ou Échap)."),
    function() Opacity_ToggleScreenshot() end)
  Action(76, T("BTN_EXPORT", "Exporter"), T("TT_EXPORT", "Obtenir un code texte de votre profil."), function() ShowCode("export") end)
  Action(76, T("BTN_IMPORT", "Importer"), T("TT_IMPORT", "Coller un code de profil Opacity."), function() ShowCode("import") end)
  main.undo = Action(76, T("BTN_UNDO", "Annuler"), T("TT_UNDO", "Restaure le profil d'avant le dernier import, préréglage ou réinitialisation."), function()
    if OP.Undo() then OP.Print(T("MSG_UNDO", "profil précédent restauré.")) end
  end)

  -- En-tetes de colonnes
  local UI = GetUI()
  local sep = main:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(UI.C.SEP[1], UI.C.SEP[2], UI.C.SEP[3], UI.C.SEP[4])
  sep:SetPoint("TOPLEFT", 10, -104); sep:SetPoint("TOPRIGHT", -10, -104); sep:SetHeight(1)
  local function Col(text, cx)
    local fs = main:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", 12 + cx, -110)
    fs:SetText(text)
  end
  Col(T("COL_FRAME", "Fenêtre"), 6)
  Col(T("COL_ALPHA", "Opacité"), 344)
  Col(T("COL_HOVER", "Survol"), 542)
  Col(T("COL_CTX", "Ctx"), 594)
  Col(T("COL_FORCE", "Forcer"), 618)

  local scroll = CreateFrame("ScrollFrame", nil, main, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 10, -126)
  scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  list = CreateFrame("Frame", nil, scroll)
  list:SetSize(LIST_W, 1)
  scroll:SetScrollChild(list)

  main.empty = main:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  main.empty:SetPoint("TOP", scroll, "TOP", 0, -40)
  main.empty:SetWidth(460)
  main.empty:SetText(T("EMPTY", "Aucune fenêtre contrôlée pour l'instant.\n\nUtilisez la Pipette pour cliquer sur une fenêtre du jeu, "
    .. "Ajouter... pour choisir dans une liste, ou un Préréglage pour démarrer."))

  main:SetScript("OnShow", RefreshList)

  -- Bouton Options flottant (socle) + Maj+clic droit -> options
  if UI.AddHeaderControls then
    UI.AddHeaderControls(main, { accent = ACCENT, onOptions = function() Opacity_OpenOptions() end })
  end
end

function OP.ShowMain()
  if not OpacityDB then return end
  if not main then BuildMain() end
  main:Show()
end
function OP.HideMain() if main then main:Hide() end end

function Opacity_Toggle()
  if not OpacityDB then return end
  if not main then BuildMain() end
  main:SetShown(not main:IsShown())
end

-- ============================================================================
-- PANNEAU D'OPTIONS (constructeur du socle)
-- ============================================================================
local optionsPanel

local function BuildOptions()
  local UI = GetUI()
  local p = UI.CreateOptionsPanel({ name = "OpacityOptions", title = T("OPT_TITLE", "Opacity : options"), accent = ACCENT })
  local function prof() return OP.Profile() end

  p:Section(T("OPT_SEC_FADE", "Fondu"))
  p:Slider(T("OPT_FADEIN", "Apparition (s)"), 0, 1, 0.05,
    function() return prof().fade.fadeIn end, function(v) prof().fade.fadeIn = v end)
  p:Slider(T("OPT_FADEOUT", "Disparition (s)"), 0, 2, 0.05,
    function() return prof().fade.fadeOut end, function(v) prof().fade.fadeOut = v end)
  p:Slider(T("OPT_DELAY", "Délai avant disparition (s)"), 0, 3, 0.1,
    function() return prof().fade.delay end, function(v) prof().fade.delay = v end)

  p:Section(T("OPT_SEC_CTX", "Contextes (le premier actif l'emporte)"))
  p:Note(T("OPT_CTX_NOTE", "Un contexte coché remplace l'opacité des fenêtres qui le suivent (case Ctx), puis le curseur maître s'applique."))
  for _, key in ipairs(OP.CONTEXT_ORDER) do
    p:Check(OP.CONTEXT_LABELS[key],
      function() return prof().contexts[key].on end,
      function(v) prof().contexts[key].on = v; OP.UpdateContext(); OP.Refresh() end)
    p:Slider(T("OPT_CTX_VALUE", "Opacité"), 0, 100, 5,
      function() return math.floor(prof().contexts[key].value * 100 + 0.5) end,
      function(v) prof().contexts[key].value = v / 100; OP.Refresh() end)
  end

  p:Section(T("OPT_SEC_SHOT", "Capture d'écran"))
  p:Check(T("OPT_SHOT_AUTO", "Réafficher automatiquement après la capture"),
    function() return OpacityDB.shotAuto end, function(v) OpacityDB.shotAuto = v end)

  p:Section(T("OPT_SEC_SUITES", "Suites d'interface"))
  local suites = OP.ActiveSuites()
  if #suites == 0 then
    p:Note(T("OPT_NO_SUITE", "Ni ElvUI ni EllesmereUI détecté."))
  else
    p:Note(string.format(T("OPT_SUITE", "Détecté : %s. Les fenêtres qu'il pilote sont laissées tranquilles, sauf si vous cochez « Forcer » sur leur ligne. "
      .. "Opacity ne modifie jamais le mode Édition de WoW : il multiplie l'opacité existante."), table.concat(suites, ", ")))
  end

  if _G.TibiSuite and _G.TibiSuite.IsCtrlHidden then
    p:Section(T("OPT_SEC_FLOAT", "Boutons flottants"))
    p:Check(T("OPT_HIDE_OPTIONS_BTN", "Masquer le bouton Options (Maj+clic droit reste actif)"),
      function() return _G.TibiSuite.IsCtrlHidden("OpacityMainFrame", "options") end,
      function(v) _G.TibiSuite.SetCtrlHidden("OpacityMainFrame", "options", v) end)
  end

  p:Section(T("OPT_SEC_RESET", "Réinitialiser"))
  p:Button(T("OPT_RESET", "Vider la liste (tout revient à 100 %)"), function() OP.ResetProfile() end)
  return p
end

function Opacity_OpenOptions()
  if not OpacityDB then return end
  if not optionsPanel then optionsPanel = BuildOptions() end
  optionsPanel:Toggle()
end
