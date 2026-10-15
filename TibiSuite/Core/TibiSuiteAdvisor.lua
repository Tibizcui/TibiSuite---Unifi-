--[[============================================================================
  TibiSuiteAdvisor.lua  -  Fenetre « Tes propositions du jour » (Conseiller)
  ---------------------------------------------------------------------------
  Cinq propositions du Conseiller dans une fenetre soignee, a la connexion et
  a la demande. Survol d'une proposition : infobulle « Ce qu'il reste a
  faire » (contrat suggestFn, champ facultatif steps() -> { { text, done,
  value } } : criteres d'un haut fait, boss et difficultes d'une monture,
  emplacements du Grand coffre...).

  Connexion : une fois par vraie connexion (pas au /reload), quand l'analyse
  des hauts faits est finie (ou 60 s plus tard), hors combat, hors instance,
  sans recouvrir l'installateur, « Quoi de neuf », le Centre ou la palette.
  Rien a proposer = rien ne s'affiche. Reglage TibiSuiteDB.advPopup (nil =
  actif, SET_KEYS), case dans Centre > Suggestions.

  Raccourci : action TIBISUITE_ADVISOR (Bindings.xml), reglable dans les
  raccourcis de Blizzard OU directement dans Centre > Suggestions (bouton de
  capture : SetBinding + SaveBindings, hors combat seulement ; clic droit =
  aucun raccourci).

  Echap : fenetre inscrite dans UISpecialFrames, sans aucun crochet.
  API : TibiSuite.ShowAdvisor(force), ToggleAdvisor(), AdvisorPopupOn(),
        AddSuggestionTooltip(tt, s), SetAdvisorKey(combo), GetAdvisorKeyText(),
        AddAdvisorKeyRow(panel).
  NON TESTE EN JEU (nouveau fichier : redemarrage complet du client).
============================================================================]]

local L = TibiSuiteL or {}
TibiSuiteL = L
local function D(k, v) if L[k] == nil then L[k] = v end end
D("ADV_TITLE",        "Tes propositions du jour")
D("ADV_SUB_FMT",      "%s  ·  reset hebdo dans %s")
D("ADV_SUB_HABITS",   "Choisies d'après ce que tu as joué ces 4 dernières semaines.")
D("ADV_SUB_NOHAB",    "Classées selon ce qui est le plus proche d'être fini.")
D("ADV_EMPTY",        "Rien à te proposer pour l'instant. Reviens un peu plus tard : la suite analyse encore tes hauts faits.")
D("ADV_LOGIN",        "Afficher à chaque connexion")
D("ADV_ALL",          "Toutes les suggestions")
D("ADV_CLOSE",        "C'est noté")
D("ADV_KEY_FMT",      "Raccourci : %s")
D("ADV_KEY_UNSET",    "Raccourci : à choisir dans Centre > Suggestions")
D("ADV_TT_TODO",      "Ce qu'il reste à faire")
D("ADV_TT_HINT",      "Clic : y aller.  Clic droit : plus tard ou pas intéressé.")
D("ADV_TT_COUNT_FMT", "%d / %d")
D("ADV_TT_PTS",       "points")
D("ADV_K_ach",        "HAUT FAIT")
D("ADV_K_coll",       "MONTURE")
D("ADV_K_rare",       "MONDE")
D("ADV_K_renown",     "RENOM")
D("ADV_K_weekly",     "GRAND COFFRE")
D("ADV_KEY_LABEL",    "Raccourci de la fenêtre")
D("ADV_KEY_NONE",     "Aucun")
D("ADV_KEY_PRESS",    "Appuie sur une touche...")
D("ADV_KEY_HINT",     "Clic : choisir.  Clic droit : retirer.")
D("ADV_KEY_HINT_CAP", "Échap : annuler.")
D("ADV_KEY_SET_FMT",  "Raccourci des propositions : %s")
D("ADV_KEY_REPL_FMT", " (remplace « %s »)")
D("ADV_KEY_CLEARED",  "Raccourci des propositions retiré.")
D("ADV_KEY_COMBAT",   "Impossible de changer un raccourci en combat.")
D("BIND_ADVISOR",     "Propositions du jour (Conseiller)")
D("SUG_ST_PROGRESS_FMT", "Progression : %s")
D("SUG_ST_MORE_FMT",  "... et %d autres")
D("SUG_ST_DONE_FMT",  "%d déjà faits")
D("SUG_ST_DIFFS_FMT", "Encore possible cette semaine : %s")
D("SUG_ST_RATE_FMT",  "Chance de butin estimée : %s (sources communautaires)")
D("SUG_ST_ZONE_FMT",  "Zone : %s")
D("SUG_ST_TIME_FMT",  "Temps restant : %s")
D("SUG_ST_KILLS_FMT", "Déjà vaincu %d fois")
D("SUG_ST_REP_FMT",   "%s : %d / %d")
D("SUG_ST_REP_LEFT_FMT", "Encore %d points de réputation")
D("SUG_ST_SLOT_FMT",  "Emplacement %d : %d / %d")

BINDING_NAME_TIBISUITE_ADVISOR = L.BIND_ADVISOR

local ACTION = "TIBISUITE_ADVISOR"
local W, CARD_H, GAP, MAX = 540, 64, 8, 5
local REAL_PROGRESS = { ach = true, renown = true }   -- jauge = vrai avancement

local K, UI
local f
local cards = {}

local function Kit()
  K = K or TibiSuite._kit
  UI = UI or _G.TibiMidnight
  return K ~= nil
end

local function Acc() return TibiSuite.ACCENT or (K and K.ACC) or { 0.769, 0.122, 0.231 } end

local function ModColor(key)
  for _, mod in ipairs(TibiSuite.GetCatalog()) do
    if mod.key == key and mod.col then return { mod.col.r, mod.col.g, mod.col.b } end
  end
  return Acc()
end

function TibiSuite.AdvisorPopupOn() return TibiSuiteDB == nil or TibiSuiteDB.advPopup ~= false end

-- ── Raccourci ──────────────────────────────────────────────────────
function TibiSuite.GetAdvisorKeyText()
  local k = GetBindingKey and GetBindingKey(ACTION)
  if not k then return nil end
  return (GetBindingText and GetBindingText(k, "KEY_")) or k
end

-- combo = "CTRL-J" (ordre ALT-CTRL-SHIFT-touche), nil = retirer. Renvoie
-- ok, message.
function TibiSuite.SetAdvisorKey(combo)
  if InCombatLockdown() then return false, L.ADV_KEY_COMBAT end
  if not (SetBinding and GetBindingKey) then return false end
  local old = { GetBindingKey(ACTION) }
  for _, k in ipairs(old) do pcall(SetBinding, k) end
  local msg
  if combo then
    local prev = GetBindingAction and GetBindingAction(combo)
    pcall(SetBinding, combo, ACTION)
    msg = string.format(L.ADV_KEY_SET_FMT, (GetBindingText and GetBindingText(combo, "KEY_")) or combo)
    if prev and prev ~= "" and prev ~= ACTION then
      msg = msg .. string.format(L.ADV_KEY_REPL_FMT, _G["BINDING_NAME_" .. prev] or prev)
    end
  else
    msg = L.ADV_KEY_CLEARED
  end
  if SaveBindings and GetCurrentBindingSet then pcall(SaveBindings, GetCurrentBindingSet()) end
  if f and f:IsShown() and f.keyTxt then f.keyTxt:SetText(TibiSuite.GetAdvisorKeyText()
    and string.format(L.ADV_KEY_FMT, TibiSuite.GetAdvisorKeyText()) or L.ADV_KEY_UNSET) end
  return true, msg
end

local MODIFIER = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
                   LMETA = true, RMETA = true, UNKNOWN = true }

-- Ligne « Raccourci de la fenetre » posee dans un panneau socle (Centre >
-- Suggestions), a la position courante du panneau (meme facon que le champ
-- de note des Rappels).
function TibiSuite.AddAdvisorKeyRow(P)
  if not (Kit() and P and P.content) then return end
  local row = CreateFrame("Frame", nil, P.content)
  row:SetSize(520, 26)
  row:SetPoint("TOPLEFT", P.content, "TOPLEFT", 6, P._y)
  local lbl = K.Text(row, "GameFontHighlight", L.ADV_KEY_LABEL, K.COL.TXT)
  lbl:SetPoint("LEFT", 0, 0)
  local b = K.Btn(row, 180, 24, "")
  b:SetPoint("LEFT", lbl, "RIGHT", 12, 0)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local hint = K.Text(row, "GameFontDisableSmall", "", K.COL.DIM)
  hint:SetPoint("LEFT", b, "RIGHT", 10, 0)
  local function paint()
    if b.capturing then b._label:SetText(K.HX.GOLD .. L.ADV_KEY_PRESS .. "|r")
    else b._label:SetText(TibiSuite.GetAdvisorKeyText() or L.ADV_KEY_NONE) end
    hint:SetText(b.capturing and L.ADV_KEY_HINT_CAP or L.ADV_KEY_HINT)
  end
  local function stop() b.capturing = false; b:EnableKeyboard(false); paint() end
  local function toast(msg) if msg and TibiSuite.ShowToast then TibiSuite.ShowToast(msg) end end
  b:SetScript("OnClick", function(s, btn)
    if btn == "RightButton" then
      stop()
      local _, msg = TibiSuite.SetAdvisorKey(nil); toast(msg); paint()
      return
    end
    if InCombatLockdown() then toast(L.ADV_KEY_COMBAT); return end
    s.capturing = not s.capturing
    s:EnableKeyboard(s.capturing)
    paint()
  end)
  b:SetScript("OnKeyDown", function(s, key)
    if not s.capturing then return end
    if key == "ESCAPE" then stop(); return end
    if MODIFIER[key] then return end
    local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
      .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
    stop()
    local _, msg = TibiSuite.SetAdvisorKey(combo); toast(msg); paint()
  end)
  b:SetScript("OnHide", function() if b.capturing then stop() end end)
  if P._refresh then P._refresh[#P._refresh + 1] = paint end
  P._y = P._y - 32
  P.content:SetHeight(math.max(-(P._y + (P._shift or 0)) + 10, 10))
  paint()
end

-- ── Infobulle commune (fenetre et lignes du Centre) ────────────────
function TibiSuite.AddSuggestionTooltip(tt, s, col)
  if not (tt and type(s) == "table") then return end
  Kit()
  local c = col or ModColor(s.key)
  tt:AddLine(s.text, c[1], c[2], c[3])
  if s.reason and s.reason ~= "" then tt:AddLine(s.reason, 0.92, 0.92, 0.90, true) end
  local steps
  if type(s.steps) == "function" then
    local ok, v = pcall(s.steps)
    if ok and type(v) == "table" and #v > 0 then steps = v end
  end
  if steps then
    tt:AddLine(" ")
    tt:AddLine(L.ADV_TT_TODO, 1, 0.82, 0)
    local OK = K and K.ICON_OK or ""
    local WAIT = "|cFF7D7A85-|r"   -- pas l'icone d'attente (un « ? » en jeu)
    for _, st in ipairs(steps) do
      local icon = (st.done == true and OK) or (st.done == false and WAIT) or "|cFF8F8C98·|r"
      local r, g, b = 0.95, 0.95, 0.95
      if st.done == true then r, g, b = 0.55, 0.75, 0.60 elseif st.done == nil then r, g, b = 0.70, 0.70, 0.75 end
      local left = icon .. " " .. tostring(st.text or "")
      if st.value then tt:AddDoubleLine(left, tostring(st.value), r, g, b, 1, 1, 1)
      else tt:AddLine(left, r, g, b, true) end
    end
  end
  if s.note and s.note ~= "" and (not steps or s.kind == "ach") then
    tt:AddLine(s.note, 0.70, 0.70, 0.75, true)
  end
  tt:AddLine(" ")
  tt:AddLine(L.ADV_TT_HINT, 0.55, 0.55, 0.60, true)
end

-- ── Fiche au survol (facon fenetre des hauts faits de Blizzard) ─────
-- Icone, titre, points, raison, description, puis TOUS les criteres en
-- colonnes : coche verte + texte clair = fait, tiret gris + texte gris = a
-- faire (vu en jeu le 2026-10-15 : la liste « ? Malus » ne ressemblait pas
-- au haut fait officiel). Nombre de colonnes choisi selon la longueur des
-- textes (1 a 5). Partagee par la fenetre et les lignes du Centre.
local tip
local TIP_MIN, TIP_MAX, PAD = 340, 560, 14
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:13:13|t"

local function BuildTip()
  if tip or not Kit() then return tip end
  tip = CreateFrame("Frame", "TibiSuiteAdvisorTip", UIParent, "BackdropTemplate")
  tip:SetFrameStrata("TOOLTIP")
  tip:SetClampedToScreen(true)
  tip:SetBackdrop(K.FLAT)
  tip:SetBackdropColor(0.035, 0.040, 0.055, 0.97)
  tip.wash = tip:CreateTexture(nil, "BACKGROUND", nil, 1)
  tip.wash:SetPoint("TOPLEFT", 1, -1); tip.wash:SetPoint("TOPRIGHT", -1, -1); tip.wash:SetHeight(64)
  tip.wash:SetColorTexture(1, 1, 1, 1)
  tip.iconBg = tip:CreateTexture(nil, "ARTWORK"); tip.iconBg:SetSize(46, 46); tip.iconBg:SetPoint("TOPLEFT", PAD, -PAD)
  tip.iconBg:SetColorTexture(0, 0, 0, 1)
  tip.icon = tip:CreateTexture(nil, "ARTWORK", nil, 1); tip.icon:SetSize(44, 44); tip.icon:SetPoint("CENTER", tip.iconBg)
  tip.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  tip.pts = K.Text(tip, "GameFontNormalLarge", "", { 1, 0.82, 0 })
  tip.pts:SetPoint("TOPRIGHT", -PAD, -PAD - 2)
  tip.ptsLbl = K.Text(tip, "GameFontDisableSmall", "", K.COL.DIM)
  tip.ptsLbl:SetPoint("TOP", tip.pts, "BOTTOM", 0, -1)
  tip.title = K.Text(tip, "GameFontNormalLarge", "", K.COL.TXT)
  tip.title:SetPoint("TOPLEFT", tip.iconBg, "TOPRIGHT", 12, -2)
  tip.title:SetJustifyH("LEFT")
  tip.reason = K.Text(tip, "GameFontHighlightSmall", "", K.COL.MUT)
  tip.reason:SetPoint("TOPLEFT", tip.title, "BOTTOMLEFT", 0, -4)
  tip.reason:SetJustifyH("LEFT"); tip.reason:SetWordWrap(true)
  tip.desc = K.Text(tip, "GameFontHighlight", "", K.COL.TXT)
  tip.desc:SetJustifyH("CENTER"); tip.desc:SetWordWrap(true)
  tip.head = K.Text(tip, "GameFontNormalSmall", "", { 1, 0.82, 0 })
  tip.head:SetJustifyH("LEFT")
  tip.count = K.Text(tip, "GameFontNormalSmall", "", K.COL.MUT)
  tip.sep = tip:CreateTexture(nil, "ARTWORK"); tip.sep:SetHeight(1); tip.sep:SetColorTexture(1, 1, 1, 0.10)
  tip.cells = {}
  tip.note = K.Text(tip, "GameFontHighlightSmall", "", K.COL.MUT)
  tip.note:SetJustifyH("LEFT"); tip.note:SetWordWrap(true)
  tip.hint = K.Text(tip, "GameFontDisableSmall", L.ADV_TT_HINT, K.COL.DIM)
  tip.hint:SetJustifyH("LEFT"); tip.hint:SetWordWrap(true)
  tip:Hide()
  return tip
end

local function Cell(i)
  local c = tip.cells[i]
  if not c then
    c = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    c:SetJustifyH("LEFT"); c:SetWordWrap(false)
    tip.cells[i] = c
  end
  return c
end

local function CellText(st, withValue)
  local txt = tostring(st.text or "")
  if withValue and st.value then txt = txt .. "  |cFFFFFFFF" .. tostring(st.value) .. "|r" end
  if st.done == true then return CHECK .. " |cFFE8E6E0" .. txt .. "|r" end
  if st.done == false then return "|cFF7D7A85-|r |cFF8F8C98" .. txt .. "|r" end
  return "|cFF8F8C98·|r |cFFB8B6BE" .. txt .. "|r"
end

function TibiSuite.HideSuggestionTip() if tip then tip:Hide() end end

function TibiSuite.ShowSuggestionTip(owner, s, col)
  if not (owner and type(s) == "table" and BuildTip()) then return end
  local m = col or ModColor(s.key)
  tip:SetBackdropBorderColor(m[1], m[2], m[3], 0.9)
  if tip.wash.SetGradient and CreateColor then
    pcall(tip.wash.SetGradient, tip.wash, "VERTICAL", CreateColor(m[1], m[2], m[3], 0), CreateColor(m[1], m[2], m[3], 0.14))
  else tip.wash:SetColorTexture(m[1], m[2], m[3], 0.05) end
  local steps, extra = nil, nil
  if type(s.steps) == "function" then
    local ok, v, x = pcall(s.steps)
    if ok and type(v) == "table" then steps, extra = v, type(x) == "table" and x or nil end
  end
  steps = steps or {}

  -- Colonnes : largeur du plus long critere (valeurs seulement en 1 colonne).
  local hasValue, maxW = false, 0
  for i, st in ipairs(steps) do
    if st.value then hasValue = true end
    local c = Cell(i); c:SetText(CellText(st, false))
    maxW = math.max(maxW, c:GetStringWidth() or 0)
  end
  local cols = 1
  if #steps >= 6 and not hasValue then
    cols = math.max(1, math.min(5, math.floor((TIP_MAX - 2 * PAD) / (maxW + 18))))
  end
  local w = TIP_MIN
  if cols > 1 then w = math.max(TIP_MIN, math.min(TIP_MAX, cols * (maxW + 18) + 2 * PAD)) end
  tip:SetWidth(w)
  local inner = w - 2 * PAD

  tip.icon:SetTexture(s.icon or (TibiSuite.MODULE_LOGO and TibiSuite.MODULE_LOGO[s.key]) or K.LOGO)
  local pts = extra and tonumber(extra.points)
  tip.pts:SetText(pts and pts > 0 and tostring(pts) or "")
  tip.ptsLbl:SetText(pts and pts > 0 and L.ADV_TT_PTS or "")
  tip.title:SetText(s.text)
  tip.title:SetTextColor(m[1], m[2], m[3])
  tip.title:SetWidth(inner - 58 - (pts and 40 or 0))
  tip.reason:SetText(s.reason or "")
  -- Laisse la place des points a droite (la raison passait dessous, vu en jeu).
  tip.reason:SetWidth(inner - 58 - ((pts and pts > 0) and 52 or 0))

  local y = -PAD - math.max(46, 2 + (tip.title:GetStringHeight() or 16) + 4 + (tip.reason:GetStringHeight() or 12)) - 10
  local desc = extra and extra.desc
  tip.desc:SetShown(desc ~= nil)
  if desc then
    tip.desc:SetWidth(inner); tip.desc:SetText(desc)
    tip.desc:ClearAllPoints(); tip.desc:SetPoint("TOP", tip, "TOP", 0, y)
    y = y - (tip.desc:GetStringHeight() or 14) - 10
  end

  for _, c in ipairs(tip.cells) do c:Hide() end
  local hasSteps = #steps > 0
  tip.head:SetShown(hasSteps); tip.count:SetShown(hasSteps); tip.sep:SetShown(hasSteps)
  if hasSteps then
    tip.sep:ClearAllPoints(); tip.sep:SetPoint("TOPLEFT", PAD, y); tip.sep:SetPoint("TOPRIGHT", -PAD, y)
    y = y - 8
    tip.head:SetText(L.ADV_TT_TODO)
    tip.head:ClearAllPoints(); tip.head:SetPoint("TOPLEFT", PAD, y)
    local done, total = 0, 0
    for _, st in ipairs(steps) do
      if st.done ~= nil then total = total + 1; if st.done then done = done + 1 end end
    end
    tip.count:SetText(total > 1 and string.format(L.ADV_TT_COUNT_FMT, done, total) or "")
    tip.count:ClearAllPoints(); tip.count:SetPoint("TOPRIGHT", -PAD, y)
    y = y - 18
    local colW = math.floor(inner / cols)
    local rows = math.ceil(#steps / cols)
    for i, st in ipairs(steps) do
      local c = Cell(i)
      c:SetText(CellText(st, cols == 1))
      c:SetWidth(colW - 6)
      -- Remplissage par lignes, comme la fenetre de Blizzard.
      local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
      c:ClearAllPoints(); c:SetPoint("TOPLEFT", PAD + col * colW, y - row * 17)
      c:Show()
    end
    y = y - rows * 17 - 6
  end

  local note = s.note
  if note == "" or (hasSteps and s.kind ~= "ach") then note = nil end
  tip.note:SetShown(note ~= nil)
  if note then
    tip.note:SetWidth(inner); tip.note:SetText(note)
    tip.note:ClearAllPoints(); tip.note:SetPoint("TOPLEFT", PAD, y - 2)
    y = y - (tip.note:GetStringHeight() or 12) - 8
  end
  tip.hint:SetWidth(inner)
  tip.hint:ClearAllPoints(); tip.hint:SetPoint("TOPLEFT", PAD, y - 4)
  y = y - (tip.hint:GetStringHeight() or 12) - 6
  tip:SetHeight(-y + PAD - 4)

  if TibiSuite.ApplyUIScaleTo then TibiSuite.ApplyUIScaleTo(tip) end
  tip:ClearAllPoints()
  -- A droite de la ligne survolee, a gauche si elle colle au bord droit.
  local right = owner.GetRight and owner:GetRight()
  local sw = UIParent.GetWidth and UIParent:GetWidth()
  if right and sw and right + w + 12 > sw then tip:SetPoint("TOPRIGHT", owner, "TOPLEFT", -8, 0)
  else tip:SetPoint("TOPLEFT", owner, "TOPRIGHT", 8, 0) end
  tip:Show()
end

-- ── Fenetre ─────────────────────────────────────────────────────────
local Refresh

local function MakeCard(i)
  local c = CreateFrame("Button", nil, f, "BackdropTemplate")
  c:SetSize(W - 32, CARD_H)
  c:SetBackdrop(K.FLAT)
  c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local function paint(hover)
    local b = K.COL.CARD2 or { 0.106, 0.118, 0.153 }
    c:SetBackdropColor(b[1] + (hover and 0.03 or 0), b[2] + (hover and 0.03 or 0), b[3] + (hover and 0.035 or 0), 0.98)
    local m = c.col or Acc()
    if hover then c:SetBackdropBorderColor(m[1], m[2], m[3], 0.85) else c:SetBackdropBorderColor(0, 0, 0, 1) end
  end
  c.Paint = paint
  c.stripe = c:CreateTexture(nil, "ARTWORK"); c.stripe:SetPoint("TOPLEFT", 1, -1); c.stripe:SetPoint("BOTTOMLEFT", 1, 1); c.stripe:SetWidth(3)
  c.wash = c:CreateTexture(nil, "BACKGROUND", nil, 1)   -- leger degrade de la couleur du module
  c.wash:SetPoint("TOPLEFT", 4, -1); c.wash:SetPoint("BOTTOMLEFT", 4, 1); c.wash:SetWidth(160)
  c.wash:SetColorTexture(1, 1, 1, 1)
  c.rank = K.Text(c, "GameFontDisableLarge", tostring(i), K.COL.DIM)
  c.rank:SetPoint("LEFT", 14, 0)
  c.iconBg = c:CreateTexture(nil, "ARTWORK"); c.iconBg:SetSize(42, 42); c.iconBg:SetPoint("LEFT", 34, 0)
  c.iconBg:SetColorTexture(0, 0, 0, 1)
  c.icon = c:CreateTexture(nil, "ARTWORK", nil, 1); c.icon:SetSize(40, 40); c.icon:SetPoint("CENTER", c.iconBg)
  c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  c.chip = c:CreateTexture(nil, "ARTWORK"); c.chip:SetHeight(16)
  c.chipTxt = K.Text(c, "GameFontNormalSmall", "", K.COL.TXT)
  c.chipTxt:SetPoint("TOPRIGHT", -14, -10)
  c.chip:SetPoint("TOPLEFT", c.chipTxt, "TOPLEFT", -6, 2); c.chip:SetPoint("BOTTOMRIGHT", c.chipTxt, "BOTTOMRIGHT", 6, -2)
  c.title = K.Text(c, "GameFontHighlight", "", K.COL.TXT)
  c.title:SetPoint("TOPLEFT", c.iconBg, "TOPRIGHT", 12, -2)
  c.title:SetPoint("RIGHT", c.chipTxt, "LEFT", -14, 0)
  c.title:SetJustifyH("LEFT"); c.title:SetWordWrap(false)
  c.reason = K.Text(c, "GameFontHighlightSmall", "", K.COL.MUT)
  c.reason:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -4)
  c.reason:SetPoint("RIGHT", -14, 0)
  c.reason:SetJustifyH("LEFT"); c.reason:SetWordWrap(false)
  c.pbg = c:CreateTexture(nil, "ARTWORK"); c.pbg:SetHeight(3)
  c.pbg:SetPoint("BOTTOMLEFT", c.iconBg, "BOTTOMRIGHT", 12, 1); c.pbg:SetPoint("RIGHT", -58, 0)
  c.pbg:SetColorTexture(1, 1, 1, 0.08)
  c.pfill = c:CreateTexture(nil, "ARTWORK", nil, 1); c.pfill:SetHeight(3)
  c.pfill:SetPoint("TOPLEFT", c.pbg); c.pfill:SetPoint("BOTTOMLEFT", c.pbg)
  c.pct = K.Text(c, "GameFontNormalSmall", "", K.COL.TXT)
  c.pct:SetPoint("LEFT", c.pbg, "RIGHT", 8, 0)
  c:SetScript("OnEnter", function(s)
    s:Paint(true)
    if s.sug then TibiSuite.ShowSuggestionTip(s, s.sug, s.col) end
  end)
  c:SetScript("OnLeave", function(s) s:Paint(false); TibiSuite.HideSuggestionTip() end)
  c:SetScript("OnClick", function(s, btn)
    if not s.sug then return end
    if btn == "RightButton" then
      TibiSuite.ShowSuggestionMenu(s, s.sug, function() if Refresh then Refresh() end end)
      return
    end
    TibiSuite.HideSuggestionTip()
    f:Hide()
    TibiSuite.OpenSuggestion(s.sug)
  end)
  paint(false)
  cards[i] = c
  return c
end

local function FillCard(c, s)
  local m = ModColor(s.key)
  c.sug, c.col = s, m
  c.stripe:SetColorTexture(m[1], m[2], m[3], 1)
  if c.wash.SetGradient and CreateColor then
    pcall(c.wash.SetGradient, c.wash, "HORIZONTAL", CreateColor(m[1], m[2], m[3], 0.16), CreateColor(m[1], m[2], m[3], 0))
  else
    c.wash:SetColorTexture(m[1], m[2], m[3], 0.06)
  end
  c.icon:SetTexture(s.icon or (TibiSuite.MODULE_LOGO and TibiSuite.MODULE_LOGO[s.key]) or K.LOGO)
  c.title:SetText(s.text)
  c.reason:SetText(s.reason or "")
  c.chipTxt:SetText(L["ADV_K_" .. tostring(s.kind)] or "")
  c.chipTxt:SetTextColor(m[1], m[2], m[3])
  c.chip:SetColorTexture(m[1], m[2], m[3], 0.14)
  c.chip:SetShown(c.chipTxt:GetText() ~= "")
  local prox = tonumber(s.proximity)
  if REAL_PROGRESS[s.kind] and prox then
    c.pbg:Show(); c.pfill:Show(); c.pct:Show()
    local w = math.max(1, (c.pbg:GetWidth() or (W - 160)) * math.max(0, math.min(1, prox)))
    c.pfill:SetWidth(w)
    c.pfill:SetColorTexture(m[1], m[2], m[3], 1)
    c.pct:SetText(math.floor(prox * 100) .. " %")
    c.reason:ClearAllPoints()
    c.reason:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -4); c.reason:SetPoint("RIGHT", -14, 0)
  else
    c.pbg:Hide(); c.pfill:Hide(); c.pct:Hide()
  end
  c:Paint(false)
  c:Show()
end

local function Build()
  if f or not Kit() then return f end
  f = CreateFrame("Frame", "TibiSuiteAdvisor", UIParent, "BackdropTemplate")
  f:SetSize(W, 300)
  f:SetPoint("CENTER", 0, 80)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if K.SkinLikeSuite then K.SkinLikeSuite(f, K.ACC) end
  if K.AddFadeIn then K.AddFadeIn(f, 0.25) end
  table.insert(UISpecialFrames, "TibiSuiteAdvisor")

  -- Halo d'accent en haut de la fenetre.
  f.glow = f:CreateTexture(nil, "BACKGROUND", nil, 2)
  f.glow:SetPoint("TOPLEFT", 1, -2); f.glow:SetPoint("TOPRIGHT", -1, -2); f.glow:SetHeight(90)
  f.glow:SetColorTexture(1, 1, 1, 1)
  local function glow()
    local a = Acc()
    if f.glow.SetGradient and CreateColor then
      pcall(f.glow.SetGradient, f.glow, "VERTICAL", CreateColor(a[1], a[2], a[3], 0), CreateColor(a[1], a[2], a[3], 0.16))
    else f.glow:SetColorTexture(a[1], a[2], a[3], 0.06) end
  end
  glow()
  if TibiSuite.OnAccentChanged then TibiSuite.OnAccentChanged(glow) end

  f.logo = f:CreateTexture(nil, "ARTWORK"); f.logo:SetSize(38, 38); f.logo:SetPoint("TOPLEFT", 18, -16)
  f.logo:SetTexture(K.LOGO)
  f.title = K.Text(f, "GameFontNormalLarge", L.ADV_TITLE, Acc())
  f.title:SetPoint("TOPLEFT", f.logo, "TOPRIGHT", 12, -1)
  f.sub = K.Text(f, "GameFontHighlightSmall", "", K.COL.TXT)
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
  f.sub2 = K.Text(f, "GameFontDisableSmall", "", K.COL.MUT)
  f.sub2:SetPoint("TOPLEFT", f.sub, "BOTTOMLEFT", 0, -3)
  f.close = K.Btn(f, 26, 26, "X", "ghost")
  f.close:SetPoint("TOPRIGHT", -10, -10)
  f.close:SetScript("OnClick", function() TibiSuite.HideSuggestionTip(); f:Hide() end)
  f.sep = f:CreateTexture(nil, "ARTWORK"); f.sep:SetHeight(1)
  f.sep:SetPoint("TOPLEFT", 16, -82); f.sep:SetPoint("TOPRIGHT", -16, -82)
  f.sep:SetColorTexture(1, 1, 1, 0.10)

  f.empty = K.Text(f, "GameFontHighlight", L.ADV_EMPTY, K.COL.MUT, W - 48)
  f.empty:SetPoint("TOPLEFT", 24, -100)

  -- Pied : case « a chaque connexion », raccourci, boutons.
  f.login = K.Btn(f, 220, 24, "", "ghost")
  f.login:SetPoint("BOTTOMLEFT", 12, 14)
  f.login._label:ClearAllPoints(); f.login._label:SetPoint("LEFT", 6, 0)
  local function paintLogin()
    local on = TibiSuite.AdvisorPopupOn()
    local box = on and "|TInterface\\Buttons\\UI-CheckBox-Check:16:16|t" or "|TInterface\\Buttons\\UI-CheckBox-Up:16:16|t"
    f.login._label:SetText(box .. " " .. L.ADV_LOGIN)
  end
  f.login:SetScript("OnClick", function()
    TibiSuiteDB.advPopup = (TibiSuite.AdvisorPopupOn()) and false or nil
    paintLogin()
  end)
  f.PaintLogin = paintLogin
  f.keyTxt = K.Text(f, "GameFontDisableSmall", "", K.COL.DIM)
  f.keyTxt:SetPoint("BOTTOMLEFT", 20, 42)
  f.ok = K.Btn(f, 130, 28, L.ADV_CLOSE, "pri")
  f.ok:SetPoint("BOTTOMRIGHT", -16, 12)
  f.ok:SetScript("OnClick", function() f:Hide() end)
  f.all = K.Btn(f, 170, 28, L.ADV_ALL)
  f.all:SetPoint("RIGHT", f.ok, "LEFT", -10, 0)
  f.all:SetScript("OnClick", function() f:Hide(); if TibiSuite.OpenCentre then TibiSuite.OpenCentre("suggest") end end)
  f:Hide()
  return f
end

function Refresh()
  if not f then return end
  local name = UnitName("player") or ""
  if TibiSuite.SafeName then name = TibiSuite.SafeName(name) end
  local wk
  if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
    local ok, s = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
    if ok and type(s) == "number" and s > 0 and TibiSuite.FmtDuration then wk = TibiSuite.FmtDuration(s) end
  end
  f.sub:SetText(wk and string.format(L.ADV_SUB_FMT, name, wk) or name)
  local habits = TibiSuite.GetAffinity and TibiSuite.GetAffinity()
  f.sub2:SetText(habits and L.ADV_SUB_HABITS or L.ADV_SUB_NOHAB)
  f.title:SetTextColor(Acc()[1], Acc()[2], Acc()[3])

  local list = {}
  if TibiSuite.SuggestOn and TibiSuite.SuggestOn() and TibiSuite.GetSuggestions then
    list = TibiSuite.GetSuggestions(MAX, true) or {}
  end
  local y = -96
  for i, s in ipairs(list) do
    local c = cards[i] or MakeCard(i)
    c:ClearAllPoints(); c:SetPoint("TOPLEFT", 16, y)
    FillCard(c, s)
    y = y - CARD_H - GAP
  end
  for i = #list + 1, #cards do cards[i]:Hide() end
  f.empty:SetShown(#list == 0)
  if #list == 0 then y = y - (f.empty:GetStringHeight() or 30) - 16 end
  local key = TibiSuite.GetAdvisorKeyText()
  f.keyTxt:SetText(key and string.format(L.ADV_KEY_FMT, key) or L.ADV_KEY_UNSET)
  f.PaintLogin()
  f:SetHeight(-y + 70)
  -- Les jauges dependent de la largeur reelle : seconde passe.
  for i, s in ipairs(list) do
    local c = cards[i]
    if c.pfill:IsShown() then
      c.pfill:SetWidth(math.max(1, (c.pbg:GetWidth() or (W - 160)) * math.max(0, math.min(1, tonumber(s.proximity) or 0))))
    end
  end
  return #list
end

-- force = true : s'ouvre meme sans proposition (message d'attente).
function TibiSuite.ShowAdvisor(force)
  if not Build() then return false end
  local n = Refresh()
  if (n or 0) == 0 and not force then return false end
  if TibiSuite.ApplyUIScaleTo then TibiSuite.ApplyUIScaleTo(f) end
  f:Show()
  return true
end

function TibiSuite.ToggleAdvisor()
  if f and f:IsShown() then f:Hide() else TibiSuite.ShowAdvisor(true) end
end

if TibiSuite.OnSuggestionsChanged then
  TibiSuite.OnSuggestionsChanged(function() if f and f:IsShown() then Refresh() end end)
end

-- ── A la connexion ─────────────────────────────────────────────────
local function Shown(name) local x = _G[name]; return x and x.IsShown and x:IsShown() or false end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, _, isLogin)
  ev:UnregisterEvent("PLAYER_ENTERING_WORLD")
  if not isLogin then return end              -- vraie connexion seulement, pas /reload
  local tries = 0
  local function try()
    tries = tries + 1
    if not (TibiSuite.AdvisorPopupOn() and TibiSuite.SuggestOn and TibiSuite.SuggestOn()) then return end
    local busy = InCombatLockdown() or (IsInInstance and IsInInstance())
      or Shown("TibiSuiteSetupWizard") or Shown("TibiSuiteWhatsNew") or Shown("TibiSuitePalette")
      or (TibiSuite.IsCentreShown and TibiSuite.IsCentreShown())
    if not busy then
      local list, pending = TibiSuite.GetSuggestions(MAX, true)
      -- Attendre la fin de l'analyse des hauts faits (lancee 30 s apres le
      -- chargement), 60 s au plus ; rien a proposer = rien ne s'affiche.
      if (not pending or tries >= 20) and type(list) == "table" and #list > 0 then
        TibiSuite.ShowAdvisor()
        return
      end
    end
    if tries < 40 then C_Timer.After(3, try) end
  end
  C_Timer.After(35, try)
end)
