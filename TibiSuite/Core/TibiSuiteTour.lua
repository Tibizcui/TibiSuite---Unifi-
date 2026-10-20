--[[============================================================================
  TibiSuiteTour.lua  -  Visite guidee du Centre (7.3, lot F)
  ---------------------------------------------------------------------------
  Quelques etapes qui surlignent une zone reelle du Centre (cadre d'accent
  qui pulse) avec une bulle de texte : Ma semaine, palette, widgets, clic
  droit sur la barre, Annuler, Conseiller, session guidee, Patrimoine.
  Une etape dont la fonction n'existe pas (fichier absent, module coupe) est
  sautee.

  Lancee une fois, a la premiere ouverture du Centre apres la mise a jour
  (TibiSuiteDB.tourDone = TOUR_VERSION, pose des le debut : passer la visite
  la marque aussi comme vue). Relancable : /ts visite, palette, Accueil.
  Fin automatique si le Centre se ferme (Echap). Aucune inscription dans
  UISpecialFrames, aucun crochet sur une fenetre de Blizzard.
  API : TibiSuite.StartTour(), StopTour(), IsTourRunning().
  NON TESTE EN JEU (nouveau fichier : redemarrage complet du client).
============================================================================]]

local L = TibiSuiteL or {}
TibiSuiteL = L
local function D(k, v) if L[k] == nil then L[k] = v end end
D("TOUR_STEP_FMT",   "%d / %d")
D("TOUR_NEXT",       "Suivant")
D("TOUR_PREV",       "Précédent")
D("TOUR_SKIP",       "Passer")
D("TOUR_END",        "C'est parti")
D("TOUR_T1",         "Bienvenue dans le Centre")
D("TOUR_X1",         "Tout TibiSuite se règle ici : la suite en haut à gauche, chaque module en dessous, avec son interrupteur. Deux minutes pour voir l'essentiel ?")
D("TOUR_T2",         "Ma semaine")
D("TOUR_X2",         "Ton tableau de bord : resets, ce qui presse, une carte par module. La punaise d'une carte (ou Maj + clic) l'épingle à l'écran comme widget.")
D("TOUR_T3",         "La palette")
D("TOUR_X3",         "Tape |cFFFFD700/ts k|r (ou choisis un raccourci) : une seule zone de recherche pour les commandes, les réglages de tous les modules et leur contenu.")
D("TOUR_T4",         "Widgets")
D("TOUR_X4",         "Les lignes d'état épinglées à l'écran se gèrent ici : taille, verrou, aperçu.")
D("TOUR_T5",         "La barre")
D("TOUR_X5",         "Clic droit sur un module de la barre : ouvrir, options, épingler. Maj + clic droit : ses options directement.")
D("TOUR_T6",         "Annuler")
D("TOUR_X6",         "Un réglage changé par erreur ? Ce bouton annule le dernier, dans la suite comme dans un module.")
D("TOUR_T7",         "Le Conseiller")
D("TOUR_X7",         "Des propositions choisies selon ta façon de jouer : hauts faits presque finis, montures faisables, Grand coffre, clés Mythique+...")
D("TOUR_T8",         "J'ai du temps")
D("TOUR_X8",         "Indique combien de minutes tu as : la suite compose une session qui tient dans ce temps et la coche toute seule (|cFFFFD700/ts temps|r).")
D("TOUR_T9",         "Patrimoine")
D("TOUR_X9",         "Combien vaut ta bande de guerriers : or, banque de Bataillon, objets, et d'où vient l'argent de la semaine.")
D("HELP_TOUR",       "visite guidée du Centre")
D("PAL_C_TOUR",      "Visite guidée du Centre")
D("CTR_Q_TOUR",      "Visite guidée")

local TOUR_VERSION = 1
local BW = 340

local STEPS = {
  { page = "home", anchor = "frame",   t = "TOUR_T1", x = "TOUR_X1", inside = true },
  { page = "home", anchor = "home",    t = "TOUR_T2", x = "TOUR_X2" },
  { page = "home", anchor = "body",    t = "TOUR_T3", x = "TOUR_X3", inside = true, need = function() return TibiSuite.OpenPalette end },
  { page = "widgets", anchor = "widgets", t = "TOUR_T4", x = "TOUR_X4", need = function() return TibiSuite.PinWidget or TibiSuite.ToggleWidget end },
  { page = "home", bar = true,         t = "TOUR_T5", x = "TOUR_X5" },
  { page = "home", anchor = "undo",    t = "TOUR_T6", x = "TOUR_X6", need = function() return TibiSuite.Undo end },
  { page = "suggest", anchor = "suggest", t = "TOUR_T7", x = "TOUR_X7", need = function() return TibiSuite.GetSuggestions end },
  { page = "home", anchor = "body",    t = "TOUR_T8", x = "TOUR_X8", inside = true, need = function() return TibiSuite.ShowSessionWindow end },
  { page = "worth", anchor = "worth",  t = "TOUR_T9", x = "TOUR_X9", need = function() return TibiSuite.GetWorth end },
}

local K
local function Kit() K = K or TibiSuite._kit; return K ~= nil end
local function Acc() return TibiSuite.ACCENT or { 0.769, 0.122, 0.231 } end

local bubble, hl
local list, idx = {}, 0

local function Build()
  if bubble or not Kit() then return bubble end
  bubble = CreateFrame("Frame", "TibiSuiteTour", UIParent, "BackdropTemplate")
  bubble:SetSize(BW, 140)
  bubble:SetFrameStrata("FULLSCREEN_DIALOG")
  bubble:SetClampedToScreen(true)
  bubble:EnableMouse(true)
  if K.SkinLikeSuite then K.SkinLikeSuite(bubble, K.ACC) end
  bubble.step = K.Text(bubble, "GameFontDisableSmall", "", K.COL.DIM)
  bubble.step:SetPoint("TOPRIGHT", -12, -12)
  bubble.title = K.Text(bubble, "GameFontNormalLarge", "", Acc())
  bubble.title:SetPoint("TOPLEFT", 14, -12)
  bubble.text = K.Text(bubble, "GameFontHighlight", "", K.COL.TXT, BW - 28)
  bubble.text:SetPoint("TOPLEFT", bubble.title, "BOTTOMLEFT", 0, -8)
  bubble.text:SetJustifyH("LEFT"); bubble.text:SetSpacing(2)
  bubble.next = K.Btn(bubble, 110, 24, L.TOUR_NEXT, "pri")
  bubble.next:SetPoint("BOTTOMRIGHT", -12, 12)
  bubble.prev = K.Btn(bubble, 100, 24, L.TOUR_PREV, "ghost")
  bubble.prev:SetPoint("RIGHT", bubble.next, "LEFT", -8, 0)
  bubble.skip = K.Btn(bubble, 80, 24, L.TOUR_SKIP, "ghost")
  bubble.skip:SetPoint("BOTTOMLEFT", 12, 12)
  -- Cadre de surlignage : enfant de la bulle (se cache avec elle), ancre
  -- sur la zone visee. Quatre bords, alpha qui pulse.
  hl = CreateFrame("Frame", nil, bubble)
  hl:SetFrameStrata("FULLSCREEN_DIALOG")
  hl.edges = {}
  for i = 1, 4 do hl.edges[i] = hl:CreateTexture(nil, "OVERLAY") end
  local e = hl.edges
  e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(2)
  e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(2)
  e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(2)
  e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(2)
  local t = 0
  bubble:SetScript("OnUpdate", function(s, dt)
    t = t + (dt or 0)
    if hl:IsShown() then hl:SetAlpha(0.55 + 0.45 * math.abs(math.sin(t * 2.4))) end
    -- Le Centre ferme (Echap, croix) : la visite s'arrete.
    if not (TibiSuite.IsCentreShown and TibiSuite.IsCentreShown()) then s:Hide() end
  end)
  bubble:Hide()
  return bubble
end

local Show

local function Paint(anchor)
  local a = Acc()
  for _, tex in ipairs(hl.edges) do tex:SetColorTexture(a[1], a[2], a[3], 1) end
  bubble.title:SetTextColor(a[1], a[2], a[3])
  hl:ClearAllPoints()
  if anchor then
    hl:SetPoint("TOPLEFT", anchor, "TOPLEFT", -3, 3)
    hl:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 3, -3)
    hl:Show()
  else
    hl:Hide()
  end
end

function Show(i)
  local st = list[i]
  if not st then TibiSuite.StopTour(); return end
  idx = i
  if TibiSuite.OpenCentre then TibiSuite.OpenCentre(st.page) end
  local anchor
  if st.bar then
    local b = _G.TibiSuiteBar
    if b and b.IsShown and b:IsShown() then anchor = b end
  elseif st.anchor then
    anchor = TibiSuite.GetCentreAnchor and TibiSuite.GetCentreAnchor(st.anchor)
    if anchor and anchor.IsShown and not anchor:IsShown() then anchor = nil end
  end
  bubble.step:SetText(string.format(L.TOUR_STEP_FMT, i, #list))
  bubble.title:SetText(L[st.t] or "")
  bubble.text:SetText(L[st.x] or "")
  bubble.prev:SetShown(i > 1)
  bubble.next._label:SetText(i == #list and L.TOUR_END or L.TOUR_NEXT)
  bubble:SetHeight(12 + 22 + 8 + (bubble.text:GetStringHeight() or 40) + 12 + 24 + 14)
  Paint(anchor)
  bubble:ClearAllPoints()
  local centre = TibiSuite.GetCentreAnchor and TibiSuite.GetCentreAnchor("frame")
  if anchor and not st.inside then
    bubble:SetPoint("LEFT", anchor, "RIGHT", 16, 0)
  elseif anchor and centre then
    bubble:SetPoint("BOTTOM", anchor, "BOTTOM", 0, 60)
  elseif centre then
    bubble:SetPoint("CENTER", centre, "CENTER", 0, 0)
  else
    bubble:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
  bubble:Show()
end

function TibiSuite.StartTour()
  if InCombatLockdown and InCombatLockdown() then return false end
  if not Build() then return false end
  list = {}
  for _, st in ipairs(STEPS) do
    if not st.need or st.need() then list[#list + 1] = st end
  end
  if TibiSuiteDB then TibiSuiteDB.tourDone = TOUR_VERSION end
  bubble.next:SetScript("OnClick", function() if idx >= #list then TibiSuite.StopTour() else Show(idx + 1) end end)
  bubble.prev:SetScript("OnClick", function() if idx > 1 then Show(idx - 1) end end)
  bubble.skip:SetScript("OnClick", function() TibiSuite.StopTour() end)
  Show(1)
  return true
end

function TibiSuite.StopTour()
  if bubble then bubble:Hide() end
  idx = 0
end

function TibiSuite.IsTourRunning() return bubble and bubble:IsShown() or false end

-- Premiere ouverture du Centre apres la mise a jour : visite proposee une
-- fois (installateur deja passe, hors combat).
if hooksecurefunc and TibiSuite.OpenCentre then
  local starting = false
  hooksecurefunc(TibiSuite, "OpenCentre", function()
    if starting or TibiSuite.IsTourRunning() then return end
    if not TibiSuiteDB or TibiSuiteDB.tourDone == TOUR_VERSION or not TibiSuiteDB.setupDone then return end
    starting = true
    C_Timer.After(0.4, function()
      starting = false
      if TibiSuite.IsCentreShown() and not TibiSuite.IsTourRunning() then TibiSuite.StartTour() end
    end)
  end)
end
