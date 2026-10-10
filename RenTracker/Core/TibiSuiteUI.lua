--[[============================================================================
  TibiSuiteUI  -  Socle d'interface commun de la suite TibiSuite (ex TibiMidnightUI)
  ---------------------------------------------------------------------------
  IMPORTANT : ce fichier est desormais charge UNE SEULE FOIS, par le core
  TibiSuite (fini le copier-coller dans chaque module). Le nom du global reste
  volontairement _G.TibiMidnight pour ne casser aucun module existant qui lit
  GetUI() = _G.TibiMidnight ; un alias _G.TibiSuiteUI est ajoute en fin de
  fichier pour le code a venir. Le numero de version (NS_VERSION) protege
  toujours le chargement : si une copie plus ancienne trainait encore dans un
  module non converti, la meilleure version gagne.

  Identite visuelle unique : fond plat sombre, bordure fine quasi noire,
  separateurs discrets, EN-TETE avec logo, et un LISERE fin a la couleur
  d'identite du module. Fournit aussi les briques reutilisables : boutons
  d'en-tete (roue + loupe), champ de recherche, fabriques de widgets, un
  constructeur de panneau d'Options flottant et un popup de recherche.

  Protege par un numero de version : si une version identique ou plus recente
  est deja chargee par un autre addon, on garde la meilleure.

  Auteur : Tibiscui - Kirin Tor

  COPIE EMBARQUEE (module RenTracker) : identique octet pour octet a
  TibiSuite/Core/TibiSuiteUI.lua. NE JAMAIS diverger : si le core TibiSuite
  est present et charge une version egale ou superieure (NS_VERSION), le
  garde ci-dessous fait de ce fichier un no-op (le core garde la main sur
  _G.TibiMidnight). En mode standalone (core absent), c'est CETTE copie qui
  cree _G.TibiMidnight pour RenTracker. A resynchroniser manuellement si
  le socle du core evolue (bump NS_VERSION cote core -> reporter ici).
============================================================================]]

local NS_VERSION = 16

if _G.TibiMidnight and (_G.TibiMidnight._version or 0) >= NS_VERSION then
  return
end

local UI = _G.TibiMidnight or {}
_G.TibiMidnight = UI
UI._version = NS_VERSION
UI.panels = UI.panels or {}  -- registre des panneaux d'options (v13, rempli par CreateOptionsPanel)

-- ============================================================================
-- PALETTE PLATE  (facon WeeklyCompass) - valeurs 0-1, r,g,b,a
-- ============================================================================
UI.C = {
  BG      = { 0.060, 0.070, 0.090, 0.98 },  -- fond principal  #0F1217
  PANEL   = { 0.055, 0.063, 0.082, 0.99 },  -- fond des panneaux
  HDR     = { 0.078, 0.090, 0.114, 1.00 },  -- bandeau d'en-tete  #141922
  SEP     = { 1.000, 1.000, 1.000, 0.10 },  -- separateurs discrets (blanc 10%)
  BORDER  = { 0.000, 0.000, 0.000, 1.00 },  -- bordure fine quasi noire
  GOLD    = { 1.000, 0.843, 0.000, 1.00 },  -- accent doux pour les valeurs
  LAV     = { 0.580, 0.502, 1.000, 1.00 },  -- lavande (liens divers)
  TXT     = { 0.902, 0.910, 0.941, 1.00 },  -- texte principal
  DIM     = { 0.620, 0.650, 0.710, 1.00 },  -- texte attenue
  MUTED   = { 0.420, 0.450, 0.510, 1.00 },  -- sous-texte
  OK      = { 0.400, 0.851, 0.541, 1.00 },  -- vert "oui"
  NO      = { 0.898, 0.420, 0.420, 1.00 },  -- rouge "non"
  WARN    = { 1.000, 0.549, 0.000, 1.00 },  -- orange d'alerte (ex: concentration pleine)
}

-- Lisibilite (v15) : modifie UI.C SUR PLACE (les fenetres creees ensuite en
-- profitent, celles deja dessinees apres un /reload). contrast = textes plus
-- clairs, fonds opaques, separateurs plus visibles ; cvd = palette sure pour
-- les daltonismes rouge-vert (bleu au lieu de vert, vermillon, jaune).
-- Appele par le core TibiSuite ; sans lui, rien ne change.
local C_BASE
function UI.ApplyReadability(opts)
  opts = opts or {}
  if not C_BASE then
    C_BASE = {}
    for k, v in pairs(UI.C) do C_BASE[k] = { v[1], v[2], v[3], v[4] } end
  end
  local function set(k, r, g, b, a) local t = UI.C[k]; if t then t[1], t[2], t[3], t[4] = r, g, b, a end end
  for k, v in pairs(C_BASE) do set(k, v[1], v[2], v[3], v[4]) end
  if opts.contrast then
    set("BG", 0.030, 0.035, 0.045, 1); set("PANEL", 0.028, 0.032, 0.042, 1)
    set("SEP", 1, 1, 1, 0.24)
    set("TXT", 1, 1, 1, 1); set("DIM", 0.820, 0.840, 0.880, 1); set("MUTED", 0.690, 0.715, 0.765, 1)
  end
  if opts.cvd then
    set("OK", 0.337, 0.706, 0.914, 1)     -- bleu ciel
    set("NO", 0.835, 0.369, 0.000, 1)     -- vermillon
    set("WARN", 0.941, 0.894, 0.259, 1)   -- jaune
  end
  UI._readability = { contrast = opts.contrast and true or false, cvd = opts.cvd and true or false }
end

function UI.Hex(r, g, b)
  return string.format("|cFF%02X%02X%02X",
    math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- ============================================================================
-- NORMALISATION DE TEXTE (recherche insensible casse + accents)
-- ============================================================================
local ACCENTS = {
  ["à"]="a",["â"]="a",["ä"]="a",["á"]="a",["ã"]="a",["À"]="a",["Â"]="a",["Ä"]="a",
  ["é"]="e",["è"]="e",["ê"]="e",["ë"]="e",["É"]="e",["È"]="e",["Ê"]="e",["Ë"]="e",
  ["î"]="i",["ï"]="i",["í"]="i",["ì"]="i",["Î"]="i",["Ï"]="i",
  ["ô"]="o",["ö"]="o",["ó"]="o",["ò"]="o",["õ"]="o",["Ô"]="o",["Ö"]="o",
  ["û"]="u",["ü"]="u",["ú"]="u",["ù"]="u",["Û"]="u",["Ü"]="u",
  ["ç"]="c",["Ç"]="c",["ñ"]="n",["Ñ"]="n",
}
function UI.Normalize(s)
  if not s then return "" end
  s = tostring(s):lower()
  s = s:gsub("[\192-\255][\128-\191]*", function(ch) return ACCENTS[ch] or ch end)
  return s
end

function UI.Match(haystack, needle)
  if needle == "" then return true end
  local h = UI.Normalize(haystack)
  if h:find(needle, 1, true) then return true end
  -- Tolérance singulier/pluriel : « fragments » doit trouver « fragment ».
  -- On retire un « s » ou « x » final de la requête et on réessaie.
  if #needle > 3 then
    local last = needle:sub(-1)
    if last == "s" or last == "x" then
      if h:find(needle:sub(1, -2), 1, true) then return true end
    end
  end
  return false
end

-- ============================================================================
-- ECHAP EN SECURITE : le joueur est-il en train de lancer un sort, de
-- canaliser, ou en mode de ciblage (reticule) ?
-- ----------------------------------------------------------------
-- PIEGE REEL, CONFIRME EN JEU (/etrace -> ADDON_ACTION_FORBIDDEN "TibiSuite",
-- "SpellStopCasting()" / "SpellStopTargeting()") : si une fenetre de la
-- suite intercepte Echap (SetPropagateKeyboardInput(false)) PENDANT que le
-- joueur lance un sort ou est en mode de ciblage, Echap doit normalement
-- annuler ce sort/ciblage via le systeme natif de Blizzard. En consommant la
-- touche nous-memes a ce moment-la, on contamine cette annulation native et
-- Blizzard bloque l'action ("reservee a l'IU de Blizzard"). Solution : ne
-- JAMAIS consommer Echap dans ce cas precis, on laisse simplement propager
-- pour que Blizzard annule normalement, sans qu'on y touche.
-- A appeler AVANT tout SetPropagateKeyboardInput(false) sur Echap, partout
-- dans la suite (socle et modules).
-- ============================================================================
function UI.IsCastingOrTargeting()
  if SpellIsTargeting and SpellIsTargeting() then return true end
  if UnitCastingInfo and UnitCastingInfo("player") then return true end
  if UnitChannelInfo and UnitChannelInfo("player") then return true end
  return false
end

-- ============================================================================
-- CADRE PLAT (bordure 1 px) + LISERE d'accent + LOGO d'en-tete
-- ============================================================================
-- Backdrop plat : fond uni + bordure fine de 1 pixel (comme WeeklyCompass).
function UI.FlatBackdrop()
  return {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  }
end

-- Alias de compatibilité : d'anciens appels utilisent UI.Backdrop(...)
function UI.Backdrop() return UI.FlatBackdrop() end

-- Ajoute (ou met a jour) le fin liseré colore en haut de la frame.
function UI.SetLisere(f, accent)
  if not f or not f.CreateTexture then return end
  if not f._tibiLisere then
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    t:SetHeight(2)
    f._tibiLisere = t
  end
  if accent then
    f._tibiLisere:SetColorTexture(accent[1], accent[2], accent[3], 1)
    f._tibiLisere:Show()
  else
    f._tibiLisere:Hide()
  end
end

-- Applique le fond plat + bordure fine + liseré d'accent.
--   accent  : {r,g,b} couleur d'identite (liseré). nil = pas de liseré.
--   bgTable : fond a utiliser (defaut : UI.C.BG)
function UI.SkinFrame(f, accent, bgTable)
  if f.SetBackdrop then
    f:SetBackdrop(UI.FlatBackdrop())
    local bg = bgTable or UI.C.BG
    f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 0.98)
    f:SetBackdropBorderColor(UI.C.BORDER[1], UI.C.BORDER[2], UI.C.BORDER[3], 1)
  end
  UI.SetLisere(f, accent)
end

-- ============================================================================
-- AUTO-HAUTEUR D'UNE FENETRE (centralise le calcul jusque-la recopie inline)
-- La fenetre grandit pour epouser son contenu, plancher a `min`, plafonnee a
-- (hauteur ecran - `margin`). Au-dela, le module gere son propre defilement.
--   UI.FitHeight(frame, contentHeight, { chrome=, min=, margin=, apply= })
--     contentHeight : hauteur utile du contenu mesure
--     chrome        : hauteur du cadre autour (en-tete, onglets, pied...) - defaut 0
--     min           : hauteur plancher - defaut 0
--     margin        : marge sous le bord bas de l'ecran - defaut 80
--     apply         : mettre false pour calculer sans appeler SetHeight - defaut true
--   Renvoie la hauteur cible calculee.
-- ============================================================================
function UI.FitHeight(frame, contentHeight, opts)
  opts = opts or {}
  local chrome  = opts.chrome or 0
  local minH    = opts.min or 0
  local margin  = opts.margin or 80
  local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 768
  local target  = (contentHeight or 0) + chrome
  if target < minH then target = minH end
  local cap = screenH - margin
  if cap < minH then cap = minH end            -- ecran minuscule : le plancher prime
  if target > cap then target = cap end
  if frame and frame.SetHeight and opts.apply ~= false then frame:SetHeight(target) end
  return target
end

-- Ajoute un petit logo en haut a gauche (une seule fois).
--   path : chemin de texture WoW SANS extension (WoW resout .tga/.blp)
function UI.AddHeaderLogo(f, path, size)
  if not f or not f.CreateTexture or f._tibiLogo or not path then return f and f._tibiLogo end
  local t = f:CreateTexture(nil, "OVERLAY")
  t:SetSize(size or 18, size or 18)
  t:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
  t:SetTexture(path)
  f._tibiLogo = t
  return t
end

-- ============================================================================
-- BOUTON GENERIQUE (texte) - style plat
-- ============================================================================
function UI.MakeButton(parent, w, h, text)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h)
  b:SetBackdrop(UI.FlatBackdrop())
  b:SetBackdropColor(1, 1, 1, 0.05)
  b:SetBackdropBorderColor(1, 1, 1, 0.12)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetAllPoints()
  fs:SetText(text or "")
  b._label = fs
  b:SetScript("OnEnter", function(s) s:SetBackdropColor(1, 1, 1, 0.10); s:SetBackdropBorderColor(1, 1, 1, 0.25) end)
  b:SetScript("OnLeave", function(s) s:SetBackdropColor(1, 1, 1, 0.05); s:SetBackdropBorderColor(1, 1, 1, 0.12) end)
  return b
end

-- ============================================================================
-- BARRE DE DEFILEMENT PLATE
-- Habille la barre du modele Blizzard UIPanelScrollFrameTemplate (fleches
-- grises carrees, texture de fond) sans toucher a son fonctionnement : la
-- molette, le glisser et les clics restent geres par Blizzard. On masque
-- seulement ses textures et on dessine par-dessus : rail fin, curseur a la
-- couleur d'accent, chevrons traces avec deux traits (aucune texture externe).
--   UI.SkinScrollBar(scrollFrame, accent)   -- accent {r,g,b} ou nil
-- ============================================================================
local function Chevron(btn, up)
  local holder = {}
  for i = 1, 2 do
    local t = btn:CreateTexture(nil, "OVERLAY")
    t:SetSize(6, 1.5)
    t:SetColorTexture(1, 1, 1, 1)
    local sign = (i == 1) and -1 or 1
    t:SetPoint("CENTER", btn, "CENTER", sign * 2, 0)
    -- « ^ » : trait gauche monte vers la droite (+45 deg), trait droit descend.
    local rot = math.rad(45) * (i == 1 and 1 or -1) * (up and 1 or -1)
    if t.SetRotation then t:SetRotation(rot) end
    holder[i] = t
  end
  return holder
end

function UI.SkinScrollBar(scroll, accent)
  if not scroll or scroll._tibiScrollSkinned then return end
  local name = scroll.GetName and scroll:GetName()
  local bar = scroll.ScrollBar or (name and _G[name .. "ScrollBar"])
  if type(bar) ~= "table" or not bar.GetRegions then return end
  scroll._tibiScrollSkinned = true
  accent = accent or UI.C.GOLD

  local thumb = (bar.GetThumbTexture and bar:GetThumbTexture()) or bar.ThumbTexture
  -- Textures d'origine de la barre (fond, bords) : effacees.
  for _, r in ipairs({ bar:GetRegions() }) do
    if r ~= thumb and r.SetAlpha then r:SetAlpha(0) end
  end

  -- Rail fin
  local rail = bar:CreateTexture(nil, "BACKGROUND")
  rail:SetColorTexture(1, 1, 1, 0.06)
  rail:SetWidth(4)
  rail:SetPoint("TOP", bar, "TOP", 0, 0)
  rail:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)

  -- Curseur a la couleur d'accent
  if thumb and thumb.SetColorTexture then
    thumb:SetColorTexture(accent[1], accent[2], accent[3], 0.85)
    thumb:SetWidth(4)
    if thumb:GetHeight() < 16 then thumb:SetHeight(24) end
  end

  -- Fleches : on vide les textures du modele et on trace un chevron plat.
  local function skinArrow(btn, up)
    if type(btn) ~= "table" or not btn.GetRegions then return end
    for _, r in ipairs({ btn:GetRegions() }) do if r.SetAlpha then r:SetAlpha(0) end end
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 2, -2); bg:SetPoint("BOTTOMRIGHT", -2, 2)
    bg:SetColorTexture(1, 1, 1, 0.05)
    local lines = Chevron(btn, up)
    local function paint(hover)
      local on = (not btn.IsEnabled) or btn:IsEnabled()
      local a = on and (hover and 1 or 0.75) or 0.20
      for _, t in ipairs(lines) do
        if hover and on then t:SetVertexColor(accent[1], accent[2], accent[3], a)
        else t:SetVertexColor(0.90, 0.91, 0.94, a) end
      end
      bg:SetColorTexture(1, 1, 1, (hover and on) and 0.10 or 0.05)
    end
    paint(false)
    btn:HookScript("OnEnter", function() paint(true) end)
    btn:HookScript("OnLeave", function() paint(false) end)
    btn:HookScript("OnEnable", function() paint(false) end)
    btn:HookScript("OnDisable", function() paint(false) end)
  end
  local upBtn = bar.ScrollUpButton or (bar.GetName and bar:GetName() and _G[bar:GetName() .. "ScrollUpButton"])
  local dnBtn = bar.ScrollDownButton or (bar.GetName and bar:GetName() and _G[bar:GetName() .. "ScrollDownButton"])
  skinArrow(upBtn, true)
  skinArrow(dnBtn, false)
end

-- ============================================================================
-- BOUTON D'EN-TETE (roue, loupe, croix...) - plat, sans bordure
-- ============================================================================
function UI.HeaderIcon(parent, glyph, tooltip, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(22, 22)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("CENTER", 0, 0)
  fs:SetText(glyph)
  b._label = fs
  fs:SetAlpha(0.75)
  b:SetScript("OnEnter", function(s)
    s._label:SetAlpha(1)
    if tooltip then
      GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(tooltip, 0.9, 0.9, 0.95)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(s) s._label:SetAlpha(0.75); GameTooltip:Hide() end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

-- ============================================================================
-- CONTROLES D'EN-TETE LISIBLES : case "Rechercher..." + bouton "Options"
-- Remplace les glyphes Unicode (carres vides en jeu) par du texte lisible et
-- une vraie texture de loupe Blizzard. Ancres au-dessus du coin haut-droit.
--   cfg = { accent={r,g,b}, onOptions=fn, onSearch=fn }
-- ============================================================================
-- Champ de recherche INLINE : on tape dedans, les resultats apparaissent en
-- direct dans un popup deroulant juste en dessous (pas de fenetre separee).
--   cfg = { accent={r,g,b}, provider=fn, width=, placeholder= }
--   provider(requeteNormalisee) -> { {text=, onClick=}, ... }
--   Renvoie { box, drop, Show, Hide, Toggle, SetFocus }
function UI.MakeSearchField(parent, cfg)
  cfg = cfg or {}
  local W = cfg.width or 150
  local DW = cfg.dropWidth or math.max(W, 260)  -- largeur du popup de résultats
  local accent = cfg.accent or UI.C.LAV

  local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  box:SetSize(W, 20)
  box:SetBackdrop(UI.FlatBackdrop())
  box:SetBackdropColor(0.02, 0.01, 0.04, 0.95)
  box:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.8)
  box:SetAutoFocus(false)
  box:SetFontObject("GameFontHighlightSmall")
  box:SetTextInsets(6, 18, 0, 0)

  local mag = box:CreateTexture(nil, "OVERLAY")
  mag:SetSize(12, 12); mag:SetPoint("RIGHT", -4, 0)
  mag:SetTexture("Interface\\Common\\UI-Searchbox-Icon")

  local ph = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ph:SetPoint("LEFT", 6, 0); ph:SetText(cfg.placeholder or "Rechercher...")

  -- Popup de resultats (deroulant)
  local drop = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  drop:SetFrameStrata("FULLSCREEN_DIALOG")
  UI.SkinFrame(drop, accent, UI.C.PANEL)
  drop:Hide()

  -- Place le popup (largeur fixe DW) : sous le champ ou au-dessus si pas la place,
  -- et aligné du côté où il reste de la place à l'écran (jamais coupé par un bord).
  local function placeDrop(h)
    drop:ClearAllPoints()
    drop:SetWidth(DW)
    local up = false
    local roomBelow = box:GetBottom()
    if roomBelow and roomBelow < (h + 10) then up = true end
    local cx = box:GetCenter()
    local scx = (UIParent:GetWidth() or 1024) / 2
    local rightSide = (cx and cx > scx)  -- champ à droite -> popup vers la gauche
    local vA = up and "BOTTOM" or "TOP"
    local vR = up and "TOP" or "BOTTOM"
    local vy = up and 2 or -2
    if rightSide then
      drop:SetPoint(vA .. "RIGHT", box, vR .. "RIGHT", 0, vy)
    else
      drop:SetPoint(vA .. "LEFT", box, vR .. "LEFT", 0, vy)
    end
  end

  local scroll = CreateFrame("ScrollFrame", nil, drop, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -4)
  scroll:SetPoint("BOTTOMRIGHT", -24, 4)
  UI.SkinScrollBar(scroll, cfg and cfg.accent)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(DW - 30, 10)
  scroll:SetScrollChild(content)

  local rows = {}
  local empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  empty:SetPoint("TOPLEFT", 4, -4); empty:SetText("Aucun résultat.")

  local function render(qraw)
    for _, r in ipairs(rows) do r:Hide() end
    local q = UI.Normalize(qraw or "")
    if q == "" then drop:Hide(); return end
    local results = {}
    if cfg.provider then
      local ok, res = pcall(cfg.provider, q)
      if ok and type(res) == "table" then results = res end
    end
    empty:SetShown(#results == 0)
    local y = -4
    for i, item in ipairs(results) do
      local r = rows[i]
      if not r then
        r = UI.MakeButton(content, DW - 34, 34, "")
        r._label:ClearAllPoints()
        r._label:SetPoint("LEFT", 6, 0); r._label:SetPoint("RIGHT", -6, 0); r._label:SetJustifyH("LEFT")
        if r._label.SetWordWrap then r._label:SetWordWrap(true) end
        rows[i] = r
      end
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
      r._label:SetText(item.text or "")
      r:SetScript("OnClick", function()
        if item.onClick then pcall(item.onClick) end
        box:SetText(""); drop:Hide(); box:ClearFocus()
      end)
      r:Show(); y = y - 36
    end
    content:SetHeight(math.max(-y + 4, 24))
    local visH = math.min(math.max(#results, 1), 8) * 36 + 12
    drop:SetHeight(visH)
    placeDrop(visH)
    drop:Show()
  end

  box:SetScript("OnTextChanged", function(s) ph:SetShown(s:GetText() == "") render(s:GetText()) end)
  box:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus(); drop:Hide() end)
  box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
  box:SetScript("OnEditFocusLost", function()
    -- Quitter le champ (clic dans le jeu, etc.) efface la recherche et ferme le popup.
    C_Timer.After(0.20, function()
      if not box:HasFocus() then
        box:SetText(""); ph:SetShown(true); drop:Hide()
      end
    end)
  end)

  local h = { box = box, drop = drop }
  h.Show = function() box:Show() end
  h.Hide = function() box:Hide(); drop:Hide() end
  h.Toggle = function() if box:IsShown() then h.Hide() else box:Show(); box:SetFocus() end end
  h.SetFocus = function() box:SetFocus() end
  return h
end

function UI.AddHeaderControls(frame, cfg)
  cfg = cfg or {}
  if frame._tibiControls then return frame._tibiControls end
  local accent = cfg.accent or UI.C.LAV
  local ctrls = {}

  -- Bouton Options (texte lisible)
  local opt = UI.MakeButton(frame, 66, 20, "")
  opt._label:SetText(UI.Hex(accent[1], accent[2], accent[3]) .. "Options|r")
  opt:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -2, 3)
  if cfg.onOptions then opt:SetScript("OnClick", cfg.onOptions) end
  ctrls.options = opt

  -- Champ de recherche inline (resultats en popup en direct)
  if cfg.provider then
    local field = UI.MakeSearchField(frame, { accent = accent, provider = cfg.provider, width = 150 })
    field.box:SetPoint("RIGHT", opt, "LEFT", -4, 0)
    ctrls.search = field
  end

  -- Masquage persistant des controles (Options / Recherche). L'etat par fenetre
  -- vit dans le core (TibiSuite.IsCtrlHidden, cle = nom global de la fenetre) ;
  -- on l'applique des la creation, donc sans clignotement. ctrls.ApplyHidden
  -- permet de reappliquer apres coup (le core l'appelle aussi via SetCtrlHidden).
  local frameName = frame.GetName and frame:GetName()
  ctrls.ApplyHidden = function()
    local TS = _G.TibiSuite
    if not (TS and TS.IsCtrlHidden and frameName) then return end
    if ctrls.options and ctrls.options.SetShown then
      ctrls.options:SetShown(not TS.IsCtrlHidden(frameName, "options"))
    end
    if ctrls.search then
      if TS.IsCtrlHidden(frameName, "search") then
        if ctrls.search.Hide then ctrls.search.Hide() end
      else
        if ctrls.search.Show then ctrls.search.Show() end
      end
    end
  end
  ctrls.ApplyHidden()

  -- Maj+clic droit sur la fenetre -> ouvre le panneau d'options du module.
  -- Place au socle (une seule fois, effet immediat) ; additif (HookScript),
  -- n'ecrase aucun gestionnaire OnMouseUp existant de la fenetre.
  if cfg.onOptions and frame.HookScript and not frame.__tibiOptShortcut then
    frame.__tibiOptShortcut = true
    if frame.EnableMouse then frame:EnableMouse(true) end
    frame:HookScript("OnMouseUp", function(_, button)
      if button == "RightButton" and IsShiftKeyDown() then pcall(cfg.onOptions) end
    end)
  end

  frame._tibiControls = ctrls
  return ctrls
end

-- ============================================================================
-- CHAMP DE RECHERCHE (loupe qui ouvre/ferme une EditBox) - usage libre
-- ============================================================================
function UI.AttachSearch(parent, anchorTo, onChanged)
  local icon = UI.HeaderIcon(parent, "\226\140\149", "Rechercher")
  if anchorTo then icon:SetPoint("RIGHT", anchorTo, "LEFT", -4, 0)
  else icon:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -34, -8) end

  local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  box:SetSize(150, 22)
  box:SetPoint("RIGHT", icon, "LEFT", -4, 0)
  box:SetBackdrop(UI.FlatBackdrop())
  box:SetBackdropColor(1, 1, 1, 0.06)
  box:SetBackdropBorderColor(1, 1, 1, 0.15)
  box:SetAutoFocus(false)
  box:SetFontObject("GameFontHighlightSmall")
  box:SetTextInsets(6, 6, 0, 0)
  box:Hide()

  box:SetScript("OnTextChanged", function(self) if onChanged then onChanged(UI.Normalize(self:GetText())) end end)
  box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); self:Hide(); if onChanged then onChanged("") end end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  local handle = { icon = icon, box = box }
  handle.Toggle = function()
    if box:IsShown() then box:SetText(""); box:Hide(); if onChanged then onChanged("") end
    else box:Show(); box:SetFocus() end
  end
  icon:SetScript("OnClick", handle.Toggle)
  return handle
end

-- ============================================================================
-- REGISTRE DE RECHERCHE GLOBALE
-- ============================================================================
UI.searchProviders = UI.searchProviders or {}
function UI.RegisterSearch(key, label, fn) UI.searchProviders[key] = { label = label, fn = fn } end

-- Recherche globale : interroge TOUS les modules inscrits et ENTRELACE leurs
-- résultats (un de chaque module à tour de rôle), pour qu'aucun addon ne
-- monopolise la liste et que tout le contenu de la suite soit représenté.
function UI.RunGlobalSearch(query)
  local q = UI.Normalize(query)
  if q == "" then return {} end

  local perModule, keys = {}, {}
  for key, prov in pairs(UI.searchProviders) do
    local ok, res = pcall(prov.fn, q)
    if ok and type(res) == "table" and #res > 0 then
      for _, item in ipairs(res) do item._module = prov.label or key end
      perModule[key] = res
      keys[#keys + 1] = key
    end
  end
  table.sort(keys)  -- ordre stable des modules

  local out, i, added = {}, 1, true
  while added and #out < 300 do
    added = false
    for _, key in ipairs(keys) do
      local item = perModule[key][i]
      if item then out[#out + 1] = item; added = true end
    end
    i = i + 1
  end
  return out
end

-- ============================================================================
-- EN-TETE COMMUN (bandeau + logo + titre a l'accent + bouton fermer)
-- Utilise par les panneaux d'options et les popups de recherche.
-- ============================================================================
local function BuildHeader(f, cfg)
  UI.SkinFrame(f, cfg.accent, cfg.bg or UI.C.PANEL)

  local hdr = f:CreateTexture(nil, "ARTWORK")
  hdr:SetColorTexture(UI.C.HDR[1], UI.C.HDR[2], UI.C.HDR[3], 1)
  hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -3)
  hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -3)
  hdr:SetHeight(32)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  if cfg.logo then
    local logo = f:CreateTexture(nil, "OVERLAY")
    logo:SetSize(20, 20)
    logo:SetPoint("LEFT", hdr, "LEFT", 10, 0)
    logo:SetTexture(cfg.logo)
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
  else
    title:SetPoint("LEFT", hdr, "LEFT", 12, 0)
  end
  title:SetText(cfg.title or "")
  if cfg.accent then title:SetTextColor(cfg.accent[1], cfg.accent[2], cfg.accent[3]) end

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() f:Hide() end)
  return hdr
end

-- ============================================================================
-- CONSTRUCTEUR DE PANNEAU D'OPTIONS FLOTTANT
--   UI.CreateOptionsPanel{ name=, title=, accent={r,g,b}, logo="chemin" }
--   Methodes : :Section :Note :Check :Slider :Color :Button :Show :Hide :Toggle
-- ============================================================================
function UI.CreateOptionsPanel(cfg)
  cfg = cfg or {}
  local accent = cfg.accent

  local f = CreateFrame("Frame", cfg.name, UIParent, "BackdropTemplate")
  f:SetSize(320, 460)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:Hide()

  BuildHeader(f, cfg)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 10, -42)
  scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  UI.SkinScrollBar(scroll, accent)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(280, 10)
  scroll:SetScrollChild(content)

  -- _seps / _notes / _boxes : elements dont la largeur suit la colonne en mode
  -- ancre (v13). _shift : hauteur gagnee par le re-calage des notes elargies.
  local panel = { frame = f, content = content, scroll = scroll, _y = -6, _refresh = {},
                  _seps = {}, _notes = {}, _boxes = {}, _shift = 0, _width = 280,
                  _name = cfg.name,    -- v14 : le Centre retrouve le module par ce nom
                  _items = {} }        -- v14 : reglages indexes (palette de commandes)
  -- Chaque reglage cree est note : libelle, section courante, objet a l'ecran.
  -- La palette de commandes du core cherche dedans, puis panel:Reveal(item).
  local function index(kind, label, obj, getFn, setFn)
    if type(label) ~= "string" or label == "" then return end
    local it = { kind = kind, label = label, section = panel._section, obj = obj, get = getFn, set = setFn }
    panel._items[#panel._items + 1] = it
    return it
  end
  -- Annuler (v15) : juste AVANT d'appliquer un changement venu de la souris,
  -- le socle confie a UI.RecordUndo (fourni par le core TibiSuite) une
  -- fonction qui photographie toutes les cases et curseurs du panneau. Rien
  -- n'est enregistre pendant un Refresh ni pendant une annulation.
  local function snapshot()
    local t = {}
    for i, it in ipairs(panel._items) do
      if it.get then
        local ok, v = pcall(it.get)
        if ok then t[i] = (v == nil) and false or v end
      end
    end
    return t
  end
  local function beforeChange(it)
    if panel._muted or not it or not UI.RecordUndo then return end
    pcall(UI.RecordUndo, panel, it, snapshot)
  end
  local function advance(h) panel._y = panel._y - h end
  local function fit() content:SetHeight(math.max(-(panel._y + panel._shift) + 10, 10)) end

  local function accentText(txt)
    if accent then return UI.Hex(accent[1], accent[2], accent[3]) .. txt .. "|r" end
    return UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. txt .. "|r"
  end

  function panel:Section(text)
    local s = content:CreateTexture(nil, "ARTWORK")
    s:SetColorTexture(UI.C.SEP[1], UI.C.SEP[2], UI.C.SEP[3], UI.C.SEP[4])
    s:SetSize(264, 1)
    s:SetPoint("TOPLEFT", content, "TOPLEFT", 4, panel._y - 4)
    panel._seps[#panel._seps + 1] = s
    local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", 4, panel._y - 10)
    fs:SetText(accentText(text))
    panel._section = text
    index("section", text, fs)
    advance(30); fit(); return self
  end

  function panel:Note(text)
    local fs = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", 6, panel._y)
    fs:SetWidth(260); fs:SetJustifyH("LEFT"); fs:SetText(text)
    local h = fs:GetStringHeight() or 12
    panel._notes[#panel._notes + 1] = { fs = fs, y = panel._y, h = h }
    advance(h + 10); fit(); return self
  end

  -- Champ texte en lecture seule mais SELECTIONNABLE (Ctrl+C) : un EditBox
  -- qui réécrit son propre texte si l'utilisateur tente de le modifier.
  -- Utile pour une URL ou un code a copier depuis un panneau d'options.
  function panel:SelectableText(label, text)
    if label then
      local cap = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      cap:SetPoint("TOPLEFT", content, "TOPLEFT", 6, panel._y)
      cap:SetText(label)
      advance(16)
    end
    local box = CreateFrame("EditBox", nil, content, "BackdropTemplate")
    box:SetSize(258, 20)
    box:SetPoint("TOPLEFT", content, "TOPLEFT", 6, panel._y)
    panel._boxes[#panel._boxes + 1] = box
    box:SetBackdrop(UI.FlatBackdrop())
    box:SetBackdropColor(0.02, 0.02, 0.03, 0.9)
    box:SetBackdropBorderColor(1, 1, 1, 0.15)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(6, 6, 0, 0)
    box:SetText(text or "")
    box:SetCursorPosition(0)
    box:SetScript("OnEditFocusGained", function(s) s:HighlightText() end)
    box:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    box:SetScript("OnTextChanged", function(s)
      if s:GetText() ~= (text or "") then s:SetText(text or ""); s:HighlightText() end
    end)
    advance(28); fit()
    return box
  end

  function panel:Check(label, getFn, setFn, tooltip)
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", content, "TOPLEFT", 4, panel._y)
    local t = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", cb, "RIGHT", 4, 0); t:SetText(label)
    cb:SetChecked(getFn())
    local it
    cb:SetScript("OnClick", function(s) beforeChange(it); setFn(s:GetChecked() and true or false) end)
    if tooltip then
      cb:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(tooltip, nil, nil, nil, nil, true); GameTooltip:Show() end)
      cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    panel._refresh[#panel._refresh + 1] = function() cb:SetChecked(getFn()) end
    it = index("check", label, cb, getFn, setFn)
    advance(28); fit(); return self
  end

  function panel:Slider(label, minV, maxV, step, getFn, setFn)
    local cap = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cap:SetPoint("TOPLEFT", content, "TOPLEFT", 6, panel._y)
    local function setCap(v) cap:SetText(label .. " : " .. UI.Hex(UI.C.GOLD[1],UI.C.GOLD[2],UI.C.GOLD[3]) .. tostring(v) .. "|r") end
    setCap(getFn())
    local sl = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    sl:SetWidth(250)
    sl:SetPoint("TOPLEFT", content, "TOPLEFT", 10, panel._y - 18)
    sl:SetMinMaxValues(minV, maxV); sl:SetValueStep(step); sl:SetObeyStepOnDrag(true)
    sl:SetValue(getFn())
    if sl.Low then sl.Low:SetText("") end
    if sl.High then sl.High:SetText("") end
    if sl.Text then sl.Text:SetText("") end
    local it
    sl:SetScript("OnValueChanged", function(_, v)
      v = math.floor(v / step + 0.5) * step; setCap(v)
      local ok, cur = pcall(getFn)
      if not (ok and cur == v) then beforeChange(it) end
      setFn(v)
    end)
    panel._refresh[#panel._refresh + 1] = function() sl:SetValue(getFn()); setCap(getFn()) end
    it = index("slider", label, cap, function() return getFn() end, function(v) sl:SetValue(v); setFn(v) end)
    -- v16 : bornes et pas (palette de commandes : Gauche / Droite).
    if it then it.min, it.max, it.step = minV, maxV, step end
    advance(52); fit(); return self
  end

  function panel:Color(label, getFn, setFn)
    local b = UI.MakeButton(content, 250, 22, label)
    b:SetPoint("TOPLEFT", content, "TOPLEFT", 6, panel._y)
    local sw = b:CreateTexture(nil, "OVERLAY")
    sw:SetSize(14, 14); sw:SetPoint("RIGHT", -6, 0)
    local function refresh() local c = getFn(); sw:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
    refresh()
    b:SetScript("OnClick", function()
      local c = getFn(); local r, g, bl, a = c[1], c[2], c[3], c[4] or 1
      local function apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = a; if ColorPickerFrame.GetColorAlpha then na = ColorPickerFrame:GetColorAlpha() end
        setFn(nr, ng, nb, na); refresh()
      end
      local info = { swatchFunc = apply, opacityFunc = apply, hasOpacity = true, r = r, g = g, b = bl, opacity = a,
        cancelFunc = function() setFn(r, g, bl, a); refresh() end }
      if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow(info)
      else ColorPickerFrame.func = apply; ColorPickerFrame.opacityFunc = apply; ColorPickerFrame.cancelFunc = info.cancelFunc
        ColorPickerFrame.hasOpacity = true; ColorPickerFrame.opacity = a; ColorPickerFrame:SetColorRGB(r, g, bl); ColorPickerFrame:Show() end
    end)
    panel._refresh[#panel._refresh + 1] = refresh
    index("color", label, b)
    advance(28); fit(); return self
  end

  function panel:Button(label, onClick)
    local b = UI.MakeButton(content, 250, 24, label)
    b:SetPoint("TOPLEFT", content, "TOPLEFT", 6, panel._y)
    b:SetScript("OnClick", onClick)
    index("button", label, b)
    advance(30); fit(); return self
  end

  -- ── Largeur de colonne (v13) ─────────────────────────────────────
  -- Elargit separateurs, notes et champs texte. Une note plus large prend
  -- moins de lignes : tout objet ancre en TOPLEFT sur `content` SOUS cette
  -- note remonte d'autant (y compris les widgets poses a la main par un
  -- module via panel._y, ex. MiniHub et Standby). Les objets ancres sur un
  -- autre objet (libelle d'une case...) suivent leur ancre. Revenir a 280
  -- restaure exactement la mise en page d'origine. A appeler une fois le
  -- panneau entierement construit.
  function panel:SetContentWidth(w)
    w = math.max(280, math.floor(w or 280))
    local d = w - 280
    panel._width = w
    content:SetWidth(w)
    for _, s in ipairs(panel._seps) do s:SetWidth(264 + d) end
    for _, b in ipairs(panel._boxes) do b:SetWidth(258 + d) end
    local total = 0
    for _, n in ipairs(panel._notes) do
      n.fs:SetWidth(260 + d)
      n.delta = n.h - (n.fs:GetStringHeight() or n.h)
      total = total + n.delta
    end
    local function recale(obj)
      if not (obj and obj.GetNumPoints and obj:GetNumPoints() == 1) then return end
      local p, rel, rp, x, y = obj:GetPoint(1)
      if rel ~= content or p ~= "TOPLEFT" or rp ~= "TOPLEFT" then return end
      local y0 = obj._tsBaseY
      if not y0 then y0 = y; obj._tsBaseY = y end
      local s = 0
      for _, n in ipairs(panel._notes) do
        if obj ~= n.fs and y0 < n.y then s = s + n.delta end
      end
      obj:SetPoint("TOPLEFT", content, "TOPLEFT", x, y0 + s)
    end
    for _, c in ipairs({ content:GetChildren() }) do recale(c) end
    for _, r in ipairs({ content:GetRegions() }) do recale(r) end
    panel._shift = total
    fit()
  end

  -- ── Mode ancre (v13) : le panneau s'affiche DANS un cadre hote ──────
  -- Seule la zone defilante change de parent : en-tete, fond et bouton
  -- fermer restent sur la fenetre flottante, qui est masquee. Le module
  -- n'a rien a changer : ses cases, son Refresh et ses widgets maison
  -- suivent. panel:Undock() rend le panneau flottant tel qu'avant.
  function panel:Dock(host, width)
    if not host then return end
    f:Hide()
    scroll:SetParent(host)
    scroll:SetFrameStrata(host:GetFrameStrata())
    scroll:SetFrameLevel(host:GetFrameLevel() + 2)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -24, 0)
    scroll:Show()
    panel._host = host
    panel:SetContentWidth(width or ((host:GetWidth() or 304) - 24))
    panel:Refresh()
  end

  function panel:Undock()
    if not panel._host then return end
    panel._host = nil
    scroll:SetParent(f)
    scroll:SetFrameStrata(f:GetFrameStrata())
    scroll:SetFrameLevel(f:GetFrameLevel() + 2)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", 10, -42)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    panel:SetContentWidth(280)
  end

  function panel:IsDocked() return panel._host ~= nil end

  -- Reveal (v14) : amene un reglage indexe a l'ecran et le surligne 1,5 s a
  -- la couleur d'accent du panneau. A appeler une fois le panneau affiche.
  function panel:Reveal(item)
    local obj = item and item.obj
    if not (obj and obj.GetTop) then return end
    local top, ot = content:GetTop(), obj:GetTop()
    if not (top and ot) then return end
    local off = top - ot
    local range = scroll:GetVerticalScrollRange() or 0
    scroll:SetVerticalScroll(math.max(0, math.min(range, off - 40)))
    if not panel._flash then
      local fl = content:CreateTexture(nil, "BACKGROUND")
      fl:SetHeight(28)
      local ag = fl:CreateAnimationGroup()
      local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0.45); a:SetToAlpha(0); a:SetDuration(1.5)
      a:SetSmoothing("IN")
      ag:SetScript("OnFinished", function() fl:Hide() end)
      panel._flash, panel._flashAG = fl, ag
    end
    local c = accent or UI.C.GOLD
    local fl = panel._flash
    fl:SetColorTexture(c[1], c[2], c[3], 1)
    fl:ClearAllPoints()
    fl:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -off + 4)
    fl:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    fl:Show()
    panel._flashAG:Stop(); panel._flashAG:Play()
  end

  -- Ancre ET hote visible : le panneau est deja a l'ecran, dans le Centre.
  -- Ancre mais hote ferme : on le rend flottant pour que la roue d'un module
  -- (ou Maj+clic droit) ouvre toujours ses options.
  local function dockedVisible() return panel._host and panel._host:IsVisible() end

  function panel:Refresh()
    local was = panel._muted
    panel._muted = true
    for _, fn in ipairs(panel._refresh) do pcall(fn) end
    panel._muted = was
  end

  -- Remet le panneau dans l'etat d'une photo (v15, Annuler). Les cases
  -- cochees sur la photo sont restaurees d'abord : une case « radio » dont
  -- le setter ignore la valeur reselectionne ainsi l'ancien choix, et les
  -- autres retrouvent d'elles-memes leur etat. Puis le reste, un par un, en
  -- relisant la valeur courante juste avant (aucun appel inutile).
  function panel:ApplySnapshot(snap)
    if type(snap) ~= "table" then return 0 end
    panel._muted = true
    local n = 0
    local function pass(onlyTrue)
      for i, it in ipairs(panel._items) do
        local old = snap[i]
        if old ~= nil and it.get and it.set and (not onlyTrue or old == true) then
          local ok, cur = pcall(it.get)
          if ok and ((cur == nil) and false or cur) ~= old then
            pcall(it.set, old); n = n + 1
          end
        end
      end
    end
    pass(true); pass(false)
    panel._muted = false
    panel:Refresh()
    return n
  end
  -- Redirection vers le Centre (v14) : quand le core TibiSuite est present,
  -- toute demande d'affichage FLOTTANT (roue d'un module, Maj+clic droit,
  -- clic droit sur un onglet, commande slash) ouvre le Centre sur la page du
  -- module. UI.PanelRedirect(panel) est fourni par le core et renvoie true
  -- s'il a pris la main ; absent (mode autonome) = comportement d'origine.
  -- UI._noRedirect est leve par le Centre pendant qu'il recupere un panneau,
  -- sinon il se rappellerait lui-meme.
  function panel:Show()
    UI.lastShownPanel = panel
    if dockedVisible() then panel:Refresh(); return end
    local redirect = UI.PanelRedirect
    if redirect and not UI._noRedirect then
      local ok, handled = pcall(redirect, panel)
      if ok and handled then return end
    end
    panel:Undock(); panel:Refresh(); f:Show()
  end
  function panel:Hide() f:Hide() end
  function panel:IsShown() return f:IsShown() or (dockedVisible() and true or false) end
  function panel:Toggle()
    if dockedVisible() then return end
    if f:IsShown() then f:Hide() else panel:Show() end
  end
  f:SetScript("OnShow", function() panel:Refresh() end)
  -- Registre (v13) : le Centre TibiSuite retrouve ici le panneau d'un module.
  UI.panels = UI.panels or {}
  UI.panels[#UI.panels + 1] = panel
  if cfg.name then UI.panels[cfg.name] = panel end
  return panel
end

-- ============================================================================
-- POPUP DE RECHERCHE  (recherche locale d'un module, ou globale)
--   UI.CreateSearchPopup{ name=, title=, accent={r,g,b}, logo=, provider=fn }
-- ============================================================================
function UI.CreateSearchPopup(cfg)
  cfg = cfg or {}
  local f = CreateFrame("Frame", cfg.name, UIParent, "BackdropTemplate")
  f:SetSize(360, 400)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:Hide()

  BuildHeader(f, cfg)

  local box = CreateFrame("EditBox", nil, f, "BackdropTemplate")
  box:SetSize(330, 26)
  box:SetPoint("TOP", 0, -42)
  box:SetBackdrop(UI.FlatBackdrop())
  box:SetBackdropColor(1, 1, 1, 0.06)
  box:SetBackdropBorderColor(1, 1, 1, 0.15)
  box:SetAutoFocus(true)
  box:SetFontObject("GameFontHighlight")
  box:SetTextInsets(8, 8, 0, 0)
  box:SetScript("OnEscapePressed", function(s) s:ClearFocus(); f:Hide() end)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -78)
  scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  UI.SkinScrollBar(scroll, cfg.accent)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(300, 10)
  scroll:SetScrollChild(content)

  local rows = {}
  local empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  empty:SetPoint("TOPLEFT", 4, -6)
  empty:SetText("Tapez pour rechercher.")

  local function render(query)
    for _, r in ipairs(rows) do r:Hide() end
    local q = UI.Normalize(query or "")
    local results = {}
    if q ~= "" and cfg.provider then
      local ok, res = pcall(cfg.provider, q)
      if ok and type(res) == "table" then results = res end
    end
    empty:SetShown(#results == 0)
    empty:SetText(q == "" and "Tapez pour rechercher." or "Aucun résultat.")
    local y = -6
    for i, item in ipairs(results) do
      local r = rows[i]
      if not r then
        r = UI.MakeButton(content, 290, 24, "")
        r._label:ClearAllPoints(); r._label:SetPoint("LEFT", 8, 0); r._label:SetPoint("RIGHT", -8, 0); r._label:SetJustifyH("LEFT")
        rows[i] = r
      end
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
      r._label:SetText(item.text or "")
      r:SetScript("OnClick", function() if item.onClick then pcall(item.onClick) end end)
      r:Show(); y = y - 28
    end
    content:SetHeight(math.max(-y + 10, 10))
  end

  box:SetScript("OnTextChanged", function(s) render(s:GetText()) end)
  f:SetScript("OnShow", function() box:SetFocus(); render(box:GetText() or "") end)

  local handle = { frame = f }
  handle.Show = function() f:Show() end
  handle.Hide = function() f:Hide() end
  handle.Toggle = function() if f:IsShown() then f:Hide() else f:Show() end end
  return handle
end

-- ============================================================================
-- BANDEAU PERSONNAGE COMMUN
--   Format : [niveau] Nom (couleur de classe) [ilvl] - Spécialisation - Royaume
--   UI.CharBannerText(data) -> chaîne coloree prête pour un FontString
--   UI.CharBanner(parent, data) -> FontString déjà créée et remplie
--   data = { name=, realm=, class=, level=, ilvl=, spec= } pour un personnage
--   hors-ligne (ex: liste Stats). data=nil ou omis -> lit le joueur connecté.
-- ============================================================================
function UI.ClassColor(classToken)
  local c = classToken and (
    (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classToken)) or
    (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken])
  )
  if c then return { c.r, c.g, c.b } end
  return { 0.85, 0.85, 0.90 }
end

local function liveCharData()
  local name  = UnitName("player")
  local realm = GetRealmName()
  local class = select(2, UnitClass("player"))
  local level = UnitLevel("player")
  local spec
  local specIndex = GetSpecialization and GetSpecialization()
  if specIndex then
    local _, specName = GetSpecializationInfo(specIndex)
    spec = specName
  end
  local ilvl
  if GetAverageItemLevel then
    local _, avgEquipped = GetAverageItemLevel()
    if avgEquipped then ilvl = math.floor(avgEquipped + 0.5) end
  end
  return { name = name, realm = realm, class = class, level = level, ilvl = ilvl, spec = spec }
end

function UI.CharBannerText(data)
  data = data or liveCharData()
  local cc = UI.ClassColor(data.class)
  local parts = {}
  parts[#parts + 1] = UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. "[" .. tostring(data.level or "?") .. "]|r"
  parts[#parts + 1] = UI.Hex(cc[1], cc[2], cc[3]) .. (data.name or "?") .. "|r"
  if data.ilvl then
    parts[#parts + 1] = UI.Hex(UI.C.MUTED[1], UI.C.MUTED[2], UI.C.MUTED[3]) .. "[" .. tostring(data.ilvl) .. "]|r"
  end
  local tail = {}
  if data.spec and data.spec ~= "" then tail[#tail + 1] = data.spec end
  if data.realm and data.realm ~= "" then tail[#tail + 1] = data.realm end
  local line = table.concat(parts, " ")
  if #tail > 0 then
    local sep = "  " .. UI.Hex(UI.C.MUTED[1], UI.C.MUTED[2], UI.C.MUTED[3]) .. "-|r  "
    line = line .. sep .. table.concat(tail, sep)
  end
  return line
end

function UI.CharBanner(parent, data)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetJustifyH("LEFT")
  fs:SetText(UI.CharBannerText(data))
  return fs
end

-- Alias tourne vers l'avenir : le meme socle est aussi accessible via
-- _G.TibiSuiteUI. Le global historique _G.TibiMidnight reste la reference
-- utilisee par les modules existants (ne pas le retirer).
_G.TibiSuiteUI = UI

-- Fin de TibiSuiteUI (ex TibiMidnightUI)
