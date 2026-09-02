--[[============================================================================
  Stats - UI.lua
  ---------------------------------------------------------------------------
  Fenetre tableau de bord : vue d'ensemble (grille 2x2), detail par metrique,
  comparaison entre personnages. Gabarit large et aere (dashboard), pas un
  popup a l'etroit - Stats est l'experience principale de la suite.
============================================================================]]

local ADDON, SX = ...
local L = SX.L
local UI = _G.TibiMidnight

local ACCENT = SX.ACCENT
local W, H = 940, 660

local mainFrame

-- ============================================================================
-- ETAT DE LA VUE (non persiste - reinitialise a chaque ouverture)
-- ============================================================================
local view = {
  char = nil,          -- charKey selectionne ("__account__" = compte)
  compareChar = nil,   -- charKey secondaire (mode Comparer), nil = pas de comparaison
  cumulative = false,
  period = "week",
  detailMetric = nil,  -- nil = vue d'ensemble ; sinon "quests"/"gold"/"dungeons"/"played"
  detailGranularity = "day",
}

local function fmtGold(copper)
  local sign = copper < 0 and "-" or ""
  copper = math.abs(math.floor(copper or 0))
  local g = math.floor(copper / 10000)
  return sign .. g .. "|cFFFFD700g|r"
end

local function fmtHours(seconds)
  seconds = math.floor(seconds or 0)
  local h = math.floor(seconds / 3600)
  local m = math.floor((seconds % 3600) / 60)
  return string.format("%dh%02d", h, m)
end

local function fmtMetric(metric, value)
  if metric == "gold" then return fmtGold(value) end
  if metric == "played" then return fmtHours(value) end
  return tostring(math.floor(value + 0.5))
end

-- ============================================================================
-- SELECTEUR DE PERSONNAGE (liste des perso avec donnees + "Compte")
-- ============================================================================
local function GetCharChoices()
  local choices = {}
  for _, key in ipairs(SX.GetCharKeys()) do
    choices[#choices + 1] = key
  end
  return choices
end

-- Libelle compact "[niveau] Nom (couleur classe) - Royaume", utilise pour le
-- bouton ferme du selecteur ET les lignes de la liste deroulante (tache 3.3).
-- Le bandeau complet (ilvl/spe) est deja affiche au-dessus : pas de raison de
-- le repeter ici, et une chaine plus courte evite tout risque de retour a la
-- ligne qui deborderait la hauteur fixe d'un bouton/ligne.
local function ShortCharLabel(charKey)
  if charKey == "__account__" or not charKey then
    return UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. L["CHAR_ACCOUNT"] .. "|r"
  end
  local data = SX.CharBannerData(charKey)
  if not data then return charKey end
  local cc = UI.ClassColor(data.class)
  return "|cFFFFD700[" .. tostring(data.level or "?") .. "]|r " .. UI.Hex(cc[1], cc[2], cc[3])
    .. (data.name or "?") .. "|r  |cFF888899-|r  |cFFAAAAAA" .. (data.realm or "") .. "|r"
end

-- Selecteur de personnage "maison", au theme plat de la suite (pas le
-- dropdown natif Blizzard, dont le chrome orne tranche avec le reste de la
-- fenetre) : un bouton qui ouvre une liste flottante juste en dessous.
local function BuildFlatDropdown(parent, width, getFn, setFn)
  local btn = UI.MakeButton(parent, width, 24, "")
  btn._label:ClearAllPoints()
  btn._label:SetPoint("LEFT", 10, 0)
  btn._label:SetPoint("RIGHT", -22, 0)
  btn._label:SetJustifyH("LEFT")
  -- Fleche en texte ASCII simple (PAS un glyphe Unicode "▾" : la police par
  -- defaut de WoW ne le contient pas et l'affiche en carre vide - piege deja
  -- documente ailleurs dans ce socle, cf. UI.AddHeaderControls). Un chemin de
  -- texture non verifiable en jeu aurait le meme risque en sens inverse
  -- (rien du tout si le chemin est faux) ; l'ASCII colore est garanti visible.
  local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  arrow:SetPoint("RIGHT", -8, 0)
  arrow:SetText("|cFF8888AAv|r")

  local popup, rows
  local function buildPopup()
    if popup then return popup end
    popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetToplevel(true)
    UI.SkinFrame(popup, ACCENT, UI.C.PANEL)
    popup:SetWidth(width)
    popup:Hide()
    local scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -22, 4)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width - 30, 10)
    scroll:SetScrollChild(content)
    popup.content = content
    rows = {}
    return popup
  end

  local function rebuild()
    local p = buildPopup()
    local choices = { "__account__" }
    for _, key in ipairs(GetCharChoices()) do choices[#choices + 1] = key end
    local y = -4
    for i, key in ipairs(choices) do
      local row = rows[i]
      if not row then
        row = UI.MakeButton(p.content, width - 34, 26, "")
        row._label:ClearAllPoints()
        row._label:SetPoint("LEFT", 8, 0)
        row._label:SetPoint("RIGHT", -8, 0)
        row._label:SetJustifyH("LEFT")
        rows[i] = row
      end
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", p.content, "TOPLEFT", 0, y)
      row._label:SetText(ShortCharLabel(key))
      row:SetScript("OnClick", function()
        setFn(key)
        p:Hide()
      end)
      row:Show()
      y = y - 28
    end
    for i = #choices + 1, #rows do rows[i]:Hide() end
    p.content:SetHeight(math.max(-y + 4, 10))
    p:SetHeight(math.min(math.max(#choices, 1) * 28 + 10, 280))
  end

  btn:SetScript("OnClick", function()
    local p = buildPopup()
    if p:IsShown() then p:Hide(); return end
    rebuild()
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    p:Show()
  end)
  btn:SetScript("OnHide", function() if popup then popup:Hide() end end)

  btn.Refresh = function() btn._label:SetText(ShortCharLabel(getFn())) end
  btn.Refresh()
  return btn
end

-- ============================================================================
-- MINI-GRAPHIQUE (barres pour "jour", ligne pour semaine/mois/annee)
-- Widgets recycles dans un pool attache au container.
-- ============================================================================
local function WipeChart(c)
  for _, t in ipairs(c._pool or {}) do t:Hide() end
  for _, fs in ipairs(c._labelPool or {}) do fs:Hide() end
  for _, h in ipairs(c._hitPool or {}) do h:Hide() end
  for _, fs in ipairs(c._valPool or {}) do fs:Hide() end
  c._used, c._labelUsed, c._hitUsed, c._valUsed = 0, 0, 0, 0
end

local function AcquireBar(c)
  c._pool = c._pool or {}
  c._used = (c._used or 0) + 1
  local t = c._pool[c._used]
  if not t then
    t = c:CreateTexture(nil, "ARTWORK")
    c._pool[c._used] = t
  end
  t:Show()
  return t
end

-- Zone invisible cliquable-au-survol : les barres/points sont des Textures
-- (pas de OnEnter natif), donc le detail au survol passe par un Button
-- transparent superpose plutot que par les barres elles-memes.
local function AcquireHit(c)
  c._hitPool = c._hitPool or {}
  c._hitUsed = (c._hitUsed or 0) + 1
  local h = c._hitPool[c._hitUsed]
  if not h then
    h = CreateFrame("Button", nil, c)
    c._hitPool[c._hitUsed] = h
  end
  h:Show()
  return h
end

local function AcquireLabel(c)
  c._labelPool = c._labelPool or {}
  c._labelUsed = (c._labelUsed or 0) + 1
  local fs = c._labelPool[c._labelUsed]
  if not fs then
    fs = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    c._labelPool[c._labelUsed] = fs
  end
  fs:Show()
  return fs
end

-- Tooltip au survol d'une zone de detail : evite d'avoir des chiffres en
-- permanence affiches (encombrant sur une petite carte) tout en gardant le
-- detail exact accessible a la demande.
local function AttachHitTooltip(hit, point, fmtFn)
  if not fmtFn then return end
  hit:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_TOP")
    GameTooltip:SetText(fmtFn(point), 1, 1, 1)
    GameTooltip:Show()
  end)
  hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Dessine series (liste de {label,value}) dans le container (largeur/hauteur
-- deja fixees). style = "bar" ou "line". series2 (optionnel) = second perso
-- en mode Comparer, meme abscisses. fmtFn(point) -> texte de tooltip
-- (optionnel) : sans lui, pas de survol interactif, juste le dessin.
local function AcquireValueLabel(c)
  c._valPool = c._valPool or {}
  c._valUsed = (c._valUsed or 0) + 1
  local fs = c._valPool[c._valUsed]
  if not fs then
    fs = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    c._valPool[c._valUsed] = fs
  end
  fs:Show()
  return fs
end

-- valueFn(point) -> texte court affiche EN PERMANENCE au-dessus de chaque
-- point (ecriture fine, pas seulement au survol) ; different de showLabels
-- qui affiche la date EN DESSOUS.
local function RenderChart(container, series, style, color, series2, color2, showLabels, fmtFn, valueFn, valueFn2, stacked)
  valueFn2 = valueFn2 or valueFn
  WipeChart(container)
  local cw, ch = container:GetWidth(), container:GetHeight()
  if not series or #series == 0 or cw <= 0 then return end

  local allValues = {}
  for _, p in ipairs(series) do allValues[#allValues + 1] = p.value end
  if series2 then for _, p in ipairs(series2) do allValues[#allValues + 1] = p.value end end
  local maxV = 0
  for _, v in ipairs(allValues) do if v > maxV then maxV = v end end
  if maxV <= 0 then maxV = 1 end

  local n = #series
  local labelH = showLabels and 14 or 0
  local plotH = ch - labelH

  local function yFor(v) return (v / maxV) * (plotH - 4) end

  if style == "bar" and stacked and series2 then
    -- Comparer ET Cumule : une colonne empilee par emplacement (bas =
    -- principal, haut = compare) plutot que deux demi-largeurs cote a cote -
    -- une seule colonne par jour, plus lisible. Repli sur une barre simple
    -- (couleur principale) si l'une des deux valeurs est negative : empiler
    -- des hauteurs de signes opposes n'a pas de sens visuel (n'arrive que
    -- pour l'or, seule metrique qui peut etre negative).
    local gap = 4
    local slotW = math.max(4, (cw / n) - gap)
    for i, p in ipairs(series) do
      local slotX = (i - 1) * (slotW + gap)
      local p2 = series2[i]
      local v1, v2 = p.value, p2 and p2.value or 0
      if v1 >= 0 and v2 >= 0 then
        -- Segment bas (principal) : hauteur minimale visible de 2px, meme
        -- convention que les barres simples (une journee a 0 reste un trait
        -- fin plutot que de disparaitre completement).
        local h1 = math.max(2, yFor(v1))
        local bar = AcquireBar(container)
        bar:ClearAllPoints()
        bar:SetColorTexture(color[1], color[2], color[3], 0.9)
        bar:SetSize(slotW, h1)
        bar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", slotX, labelH)
        if v2 > 0 then
          local h2 = math.max(2, yFor(v2))
          local bar2 = AcquireBar(container)
          bar2:ClearAllPoints()
          bar2:SetColorTexture(color2[1], color2[2], color2[3], 0.9)
          bar2:SetSize(slotW, h2)
          -- BUG confirme en jeu : ancrage "BOTTOM" (centre) avec un offset X
          -- pense pour un ancrage "BOTTOMLEFT" (bord gauche) - le segment du
          -- haut se retrouvait decale d'un demi-slotW vers la gauche par
          -- rapport au segment du bas, debordant sur la colonne du jour
          -- precedent au lieu de rester empile bord a bord dessus.
          bar2:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", slotX, labelH + h1)
        end
      else
        local bar = AcquireBar(container)
        bar:ClearAllPoints()
        bar:SetColorTexture(color[1], color[2], color[3], 0.85)
        bar:SetSize(slotW, math.max(2, yFor(v1 + v2)))
        bar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", slotX, labelH)
      end
      -- Le chiffre au-dessus n'est utile que s'il y a quelque chose a
      -- montrer : sur 7 jours dont la plupart a 0, l'afficher partout
      -- encombre le bas du graphique de "0" en plus des traits plats des
      -- barres a hauteur minimale - un jour vide reste visible (trait fin),
      -- juste sans etiquette redondante.
      if valueFn and (v1 + v2) ~= 0 then
        local vlbl = AcquireValueLabel(container)
        vlbl:ClearAllPoints()
        vlbl:SetPoint("BOTTOM", container, "BOTTOMLEFT", slotX + slotW / 2, labelH + math.max(2, yFor(v1 + v2)) + 3)
        -- Largeur bornee au pas reel de la grille (slotW+gap), jamais au-dela
        -- : une etiquette plus large que son emplacement empietait sur celle
        -- du jour voisin des que les deux avaient une vraie valeur a afficher
        -- (chevauchement confirme en jeu sur deux jours consecutifs actifs).
        vlbl:SetWidth(slotW + gap - 2)
        vlbl:SetText(valueFn({ label = p.label, value = v1 + v2 }))
      end
      if showLabels then
        local lbl = AcquireLabel(container)
        lbl:ClearAllPoints()
        lbl:SetPoint("TOP", container, "BOTTOMLEFT", slotX + slotW / 2, -1)
        lbl:SetWidth(slotW + gap)
        lbl:SetText(p.label)
      end
      if fmtFn then
        local hit = AcquireHit(container)
        hit:ClearAllPoints()
        hit:SetSize(slotW + gap, ch)
        hit:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", slotX, 0)
        -- v1/v2 transmis en plus du total : permet a fmtFn d'afficher le
        -- detail par personnage dans l'infobulle (pas seulement le total du
        -- jour empile).
        AttachHitTooltip(hit, { label = p.label, value = v1 + v2, v1 = v1, v2 = v2 }, fmtFn)
      end
    end
  elseif style == "bar" then
    local gap = 4
    -- Comparaison : chaque emplacement se coupe en 2 demi-barres cote a cote
    -- (principal a gauche, compare a droite) plutot qu'une seule barre qui
    -- ignorait completement series2 (bug confirme : le mode Comparer/Cumule
    -- n'affichait jamais la 2e serie en colonnes, seulement en courbe).
    local slotW = math.max(4, (cw / n) - gap)
    local barW = series2 and math.max(2, (slotW - 2) / 2) or slotW
    for i, p in ipairs(series) do
      local slotX = (i - 1) * (slotW + gap)
      local bar = AcquireBar(container)
      bar:ClearAllPoints()
      bar:SetColorTexture(color[1], color[2], color[3], 0.85)
      local h = math.max(2, yFor(p.value))
      bar:SetSize(barW, h)
      bar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", slotX, labelH)
      if valueFn and p.value ~= 0 then
        local vlbl = AcquireValueLabel(container)
        vlbl:ClearAllPoints()
        vlbl:SetPoint("BOTTOM", bar, "TOP", 0, 1)
        -- Bornee a la largeur reelle de la demi-barre (+ le petit espace de
        -- 2px qui la separe de sa voisine) : au-dela, l'etiquette empiete sur
        -- celle de la 2e barre du meme jour.
        vlbl:SetWidth(barW + 2)
        vlbl:SetText(valueFn(p))
      end
      if series2 then
        local p2 = series2[i]
        if p2 then
          local bar2 = AcquireBar(container)
          bar2:ClearAllPoints()
          bar2:SetColorTexture(color2[1], color2[2], color2[3], 0.85)
          local h2 = math.max(2, yFor(p2.value))
          bar2:SetSize(barW, h2)
          bar2:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", slotX + barW + 2, labelH)
          if valueFn2 and p2.value ~= 0 then
            local vlbl2 = AcquireValueLabel(container)
            vlbl2:ClearAllPoints()
            vlbl2:SetPoint("BOTTOM", bar2, "TOP", 0, 1)
            vlbl2:SetWidth(barW + 2)
            vlbl2:SetText(valueFn2(p2))
          end
        end
      end
      if showLabels then
        local lbl = AcquireLabel(container)
        lbl:ClearAllPoints()
        lbl:SetPoint("TOP", container, "BOTTOMLEFT", slotX + slotW / 2, -1)
        lbl:SetWidth(slotW + gap)
        lbl:SetText(p.label)
      end
      if fmtFn then
        local hit = AcquireHit(container)
        hit:ClearAllPoints()
        hit:SetSize(slotW + gap, ch)
        hit:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", slotX, 0)
        AttachHitTooltip(hit, p, fmtFn)
      end
    end
  else -- "line"
    local function drawLine(pts, col, addHits)
      local stepX = n > 1 and (cw / (n - 1)) or 0
      local prevX, prevY
      for i, p in ipairs(pts) do
        local x = (i - 1) * stepX
        local y = yFor(p.value)
        -- point (petit carre)
        local dot = AcquireBar(container)
        dot:ClearAllPoints()
        dot:SetColorTexture(col[1], col[2], col[3], 1)
        dot:SetSize(6, 6)
        dot:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", x - 3, labelH + y - 3)
        if prevX then
          local seg = AcquireBar(container)
          seg:ClearAllPoints()
          seg:SetColorTexture(col[1], col[2], col[3], 0.85)
          local dx, dy = x - prevX, y - prevY
          local len = math.sqrt(dx * dx + dy * dy)
          seg:SetSize(math.max(len, 0.01), 2)
          seg:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", prevX, labelH + prevY - 1)
          seg:SetRotation(math.atan2(dy, dx))
        end
        if showLabels then
          local lbl = AcquireLabel(container)
          lbl:ClearAllPoints()
          lbl:SetPoint("TOP", container, "BOTTOMLEFT", x, labelH - ch)
          lbl:SetWidth(stepX > 0 and stepX or 40)
          lbl:SetText(p.label)
        end
        if addHits and fmtFn then
          local hit = AcquireHit(container)
          hit:ClearAllPoints()
          local hitW = math.max(stepX, 10)
          hit:SetSize(hitW, ch)
          hit:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", x - hitW / 2, 0)
          AttachHitTooltip(hit, p, fmtFn)
        end
        if addHits and valueFn then
          local vlbl = AcquireValueLabel(container)
          vlbl:ClearAllPoints()
          vlbl:SetPoint("BOTTOM", container, "BOTTOMLEFT", x, labelH + y + 7)
          vlbl:SetWidth(math.max(stepX, 30) + 10)
          vlbl:SetText(valueFn(p))
        end
        prevX, prevY = x, y
      end
    end
    drawLine(series, color, true)
    if series2 then drawLine(series2, color2, false) end
  end
end

-- ============================================================================
-- CARTES DE LA VUE D'ENSEMBLE
-- ============================================================================
local CARD_METRICS = { "quests", "gold", "dungeons", "played" }
local cards = {}

local function CardLabel(metric)
  if metric == "quests" then return L["CARD_QUESTS"]
  elseif metric == "gold" then
    return (view.period == "week") and L["CARD_GOLD_WEEK"] or L["CARD_GOLD"]
  elseif metric == "dungeons" then return L["CARD_DUNGEONS"]
  elseif metric == "played" then return L["CARD_PLAYED"]
  end
end

-- L'astuce "semaine calee sur le reset" (GoldRangeFor) ne s'applique qu'a la
-- carte Or ; les autres cartes en vue Semaine restent sur la semaine calendaire.
local function CurrentRange(offset)
  return SX.PeriodRange(view.period, offset or 0)
end

local function GoldRangeFor(offset)
  if view.period == "week" then
    if offset == 0 then return SX.WeeklyGoldRange() end
    local from, to = SX.WeeklyGoldRange()
    local shift = offset * (to - from + 1)
    return from + shift, to + shift
  end
  return CurrentRange(offset)
end

-- Couleur d'une serie : la couleur de CLASSE du personnage en mode Comparer/
-- Cumule (bien plus lisible pour associer chaque barre a "qui" que deux
-- teintes arbitraires) ; repli sur l'accent par defaut pour "Compte" (pas de
-- classe unique) ou en l'absence de comparaison.
local function SeriesColor(charKey, fallback)
  if not charKey or charKey == "__account__" then return fallback end
  local data = SX.CharBannerData(charKey)
  if not data or not data.class then return fallback end
  return UI.ClassColor(data.class)
end

-- Nom court affiche pour un charKey ("Compte" pour le compte, sinon le nom du
-- personnage) - utilise pour la legende de comparaison ET le distingo par
-- personnage des cartes en mode Cumule.
local function CharDisplayName(charKey)
  if charKey == "__account__" or not charKey then return L["CHAR_ACCOUNT"] end
  local data = SX.CharBannerData(charKey)
  return data and data.name or charKey
end

-- Additionne deux series point a point (mode "Cumule") - suppose les deux
-- construites avec les memes parametres (meme granularite/nombre de points),
-- ce qui est toujours le cas ici (view.char et view.compareChar partagent
-- la meme fenetre temporelle).
local function CombineSeries(a, b)
  local out = {}
  for i, p in ipairs(a) do
    local bv = (b and b[i] and b[i].value) or 0
    out[i] = { label = p.label, value = p.value + bv, from = p.from, to = p.to }
  end
  return out
end

local function BuildOverview(content)
  local gridTop = -10
  local cardW, cardH = (W - 60) / 2, 190
  local gap = 16
  -- Couleurs de classe des 2 personnages compares - calculees une fois pour
  -- les 4 cartes (pas de raison qu'elles different d'une carte a l'autre).
  local pColor = SeriesColor(view.char, ACCENT)
  local cColor = view.compareChar and SeriesColor(view.compareChar, SX.COMPARE_ACCENT) or SX.COMPARE_ACCENT
  for i, metric in ipairs(CARD_METRICS) do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    local card = cards[metric]
    if not card then
      card = CreateFrame("Button", nil, content, "BackdropTemplate")
      UI.SkinFrame(card, ACCENT, UI.C.PANEL)
      card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      card.title:SetPoint("TOPLEFT", 14, -12)
      card.value = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      card.value:SetPoint("TOPLEFT", 14, -34)
      card.delta = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      card.delta:SetPoint("LEFT", card.value, "RIGHT", 10, 0)
      card.sub = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      card.sub:SetPoint("TOPLEFT", 14, -58)
      -- Deuxieme personnage (mode Comparer, hors Cumule) : valeur cote a cote
      -- avec la principale, dans la teinte de comparaison.
      card.value2 = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      card.value2:SetPoint("LEFT", card.delta, "RIGHT", 14, 0)
      card.delta2 = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      card.delta2:SetPoint("LEFT", card.value2, "RIGHT", 10, 0)
      -- Distingo par personnage en mode Cumule : "Nom1: X  +  Nom2: Y", chaque
      -- nom dans sa couleur de classe - le total au-dessus reste neutre (or),
      -- cette ligne montre QUI a contribue QUOI (repond a la demande "je n'ai
      -- pas les valeurs de chaque perso dans le cumul").
      card.cumulBreakdown = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      card.cumulBreakdown:SetPoint("TOPLEFT", 14, -78)
      card.cumulBreakdown:SetPoint("TOPRIGHT", -14, -78)
      card.cumulBreakdown:SetJustifyH("LEFT")
      card.chart = CreateFrame("Frame", nil, card)
      card.chart:SetPoint("BOTTOMLEFT", 14, 14)
      card.chart:SetPoint("BOTTOMRIGHT", -14, 14)
      card.chart:SetHeight(90)
      card:SetScript("OnClick", function()
        view.detailMetric = metric
        view.detailGranularity = (view.period == "day") and "day" or view.detailGranularity
        SX.RefreshDashboard()
      end)
      cards[metric] = card
    end
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", content, "TOPLEFT", col * (cardW + gap), gridTop - row * (cardH + gap))
    card:SetSize(cardW, cardH)
    card.title:SetText(CardLabel(metric))

    local from, to, pFrom, pTo
    if metric == "gold" then
      from, to = GoldRangeFor(0)
      pFrom, pTo = GoldRangeFor(-1)
    else
      from, to = CurrentRange(0)
      pFrom, pTo = CurrentRange(-1)
    end
    local agg = SX.AggregateFor(view.char, from, to)
    local prevAgg = SX.AggregateFor(view.char, pFrom, pTo)
    local val = SX.MetricValue(agg, metric)
    local prevVal = SX.MetricValue(prevAgg, metric)
    -- Mode Cumule : la valeur affichee et le delta portent sur la somme des
    -- deux personnages, pas seulement le principal.
    if view.cumulative and view.compareChar then
      local agg2 = SX.AggregateFor(view.compareChar, from, to)
      local prevAgg2 = SX.AggregateFor(view.compareChar, pFrom, pTo)
      val = val + SX.MetricValue(agg2, metric)
      prevVal = prevVal + SX.MetricValue(prevAgg2, metric)
      if metric == "dungeons" then
        agg = { dungeons = agg.dungeons + agg2.dungeons, mplusCount = agg.mplusCount + agg2.mplusCount }
      end
    end

    card.value:SetText(fmtMetric(metric, val))
    -- Couleur de classe du personnage principal en comparaison (pas en
    -- Cumule : la valeur y est deja la somme des deux, aucune classe unique
    -- ne s'applique).
    if view.compareChar and not view.cumulative then
      card.value:SetTextColor(pColor[1], pColor[2], pColor[3])
    else
      card.value:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    end
    if metric == "dungeons" then
      card.sub:SetText(agg.dungeons .. " " .. L["DUNGEONS_NORMAL"] .. "  /  " .. agg.mplusCount .. " " .. L["DUNGEONS_MPLUS"])
    else
      card.sub:SetText("")
    end

    local deltaPct = 0
    if prevVal ~= 0 then deltaPct = (val - prevVal) / math.abs(prevVal) * 100 end
    if val ~= 0 or prevVal ~= 0 then
      -- ASCII, pas de glyphe Unicode ▲/▼ (carre vide avec la police par
      -- defaut de WoW - meme piege que la fleche du selecteur, cf. plus haut).
      local arrow = val >= prevVal and "|cFF66D98A+|r" or "|cFFE56B6B-|r"
      card.delta:SetText(arrow .. " " .. string.format("%.0f%%", math.abs(deltaPct)))
    else
      card.delta:SetText("")
    end

    -- Second personnage cote a cote (mode Comparer, hors Cumule - en Cumule
    -- la valeur principale est deja la somme des deux, cf. plus haut).
    if view.compareChar and not view.cumulative then
      local agg2 = SX.AggregateFor(view.compareChar, from, to)
      local prevAgg2 = SX.AggregateFor(view.compareChar, pFrom, pTo)
      local val2 = SX.MetricValue(agg2, metric)
      local prevVal2 = SX.MetricValue(prevAgg2, metric)
      card.value2:SetText(fmtMetric(metric, val2))
      card.value2:SetTextColor(cColor[1], cColor[2], cColor[3])
      card.value2:Show()
      local deltaPct2 = 0
      if prevVal2 ~= 0 then deltaPct2 = (val2 - prevVal2) / math.abs(prevVal2) * 100 end
      if val2 ~= 0 or prevVal2 ~= 0 then
        local arrow2 = val2 >= prevVal2 and "|cFF66D98A+|r" or "|cFFE56B6B-|r"
        card.delta2:SetText(arrow2 .. " " .. string.format("%.0f%%", math.abs(deltaPct2)))
      else
        card.delta2:SetText("")
      end
      card.delta2:Show()
    else
      card.value2:Hide()
      card.delta2:Hide()
    end

    -- Distingo par personnage (mode Cumule) : la valeur en tete est deja la
    -- somme des deux (cf. plus haut), cette ligne montre la repartition par
    -- personnage, nom + couleur de classe, exactement comme la legende du
    -- header mais rappelee sur chaque carte.
    if view.cumulative and view.compareChar then
      local val1 = SX.MetricValue(SX.AggregateFor(view.char, from, to), metric)
      local val2 = SX.MetricValue(SX.AggregateFor(view.compareChar, from, to), metric)
      local pName, cName = CharDisplayName(view.char), CharDisplayName(view.compareChar)
      card.cumulBreakdown:SetText(
        UI.Hex(pColor[1], pColor[2], pColor[3]) .. pName .. "|r " .. UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. fmtMetric(metric, val1) .. "|r"
        .. "  +  "
        .. UI.Hex(cColor[1], cColor[2], cColor[3]) .. cName .. "|r " .. UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. fmtMetric(metric, val2) .. "|r")
      card.cumulBreakdown:Show()
    else
      card.cumulBreakdown:Hide()
    end

    local granularity = (view.period == "day") and "day" or (view.period == "week" and "day" or (view.period == "month" and "week" or "month"))
    local bucketCount = (view.period == "day") and 7 or (view.period == "week" and 7 or (view.period == "month" and 5 or 12))
    -- Retour a SX.BuildSeries pour l'Or aussi (demande explicite : le meme
    -- comportement que les 3 autres cartes) - le calage sur le reset
    -- hebdomadaire rendait la carte Or coherente avec son propre total, mais
    -- visuellement differente des 3 autres cartes (jours couverts differents),
    -- ce qui etait plus genant que l'ecart occasionnel total/graphique.
    local series = SX.BuildSeries(view.char, metric, granularity, bucketCount)
    local series2 = view.compareChar and SX.BuildSeries(view.compareChar, metric, granularity, bucketCount) or nil
    -- Des qu'un 2e personnage est affiche (Comparer OU Cumule), les deux
    -- series restent SEPAREES - RenderChart les empile en une colonne
    -- composite (bas = principal, haut = compare). Le bug d'ancrage qui
    -- decalait le segment du haut (deborde sur le jour voisin) est corrige
    -- dans RenderChart (BOTTOMLEFT au lieu de BOTTOM) - la colonne empilee
    -- peut donc revenir pour le Cumule aussi.
    local stacked = series2 ~= nil

    -- Couleurs de classe des qu'on compare ; le chiffre au-dessus de la
    -- colonne repasse en or (neutre) des qu'elle est empilee puisqu'il
    -- affiche alors le TOTAL des deux, pas la part d'un seul.
    local chartColor1 = view.compareChar and pColor or ACCENT
    local labelColor = stacked and ACCENT or chartColor1
    -- Infobulle : detail par personnage quand la colonne est empilee (le nom
    -- de chacun, dans sa couleur de classe, avec sa propre part du total ce
    -- jour-la) plutot que le seul total - WoW ne permet pas de mettre juste
    -- le nom en italique dans une infobulle simple (police fixe, pas de code
    -- d'echappement italique comme pour les couleurs) ; la couleur de classe
    -- assure deja la distinction, comme partout ailleurs dans cette fenetre.
    local fmtFn
    if stacked then
      local pName, cName = CharDisplayName(view.char), CharDisplayName(view.compareChar)
      fmtFn = function(p)
        return p.label .. "\n" .. UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. fmtMetric(metric, p.value) .. "|r"
          .. "\n" .. UI.Hex(pColor[1], pColor[2], pColor[3]) .. pName .. "|r " .. fmtMetric(metric, p.v1 or 0)
          .. "\n" .. UI.Hex(cColor[1], cColor[2], cColor[3]) .. cName .. "|r " .. fmtMetric(metric, p.v2 or 0)
      end
    else
      fmtFn = function(p) return p.label .. "\n" .. UI.Hex(labelColor[1], labelColor[2], labelColor[3]) .. fmtMetric(metric, p.value) .. "|r" end
    end
    local valueFn = function(p) return UI.Hex(labelColor[1], labelColor[2], labelColor[3]) .. fmtMetric(metric, p.value) .. "|r" end
    local valueFn2 = function(p) return UI.Hex(cColor[1], cColor[2], cColor[3]) .. fmtMetric(metric, p.value) .. "|r" end
    RenderChart(card.chart, series, "bar", chartColor1, series2, cColor, true, fmtFn, valueFn, valueFn2, stacked)

    card:Show()
  end
end

-- ============================================================================
-- VUE DETAIL (une seule metrique)
-- ============================================================================
local detailWidgets = {}

local function BuildDetail(content, metric)
  local d = detailWidgets
  if not d.built then
    d.back = UI.MakeButton(content, 160, 22, L["DETAIL_BACK"])
    d.back:SetPoint("TOPLEFT", 0, 0)
    d.back:SetScript("OnClick", function() view.detailMetric = nil; SX.RefreshDashboard() end)

    d.title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    d.title:SetPoint("TOPLEFT", 0, -34)

    d.granLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    d.granLabel:SetPoint("TOPRIGHT", 0, -8)

    d.granButtons = {}
    for _, g in ipairs(SX.GRANULARITIES) do
      local b = UI.MakeButton(content, 60, 20, "")
      d.granButtons[g] = b
    end

    d.chart = CreateFrame("Frame", nil, content, "BackdropTemplate")
    UI.SkinFrame(d.chart, ACCENT, UI.C.PANEL)
    d.chart:SetPoint("TOPLEFT", 0, -66)
    d.chart:SetSize(W - 60, 300)
    d.chartInner = CreateFrame("Frame", nil, d.chart)
    d.chartInner:SetPoint("TOPLEFT", 16, -16)
    d.chartInner:SetPoint("BOTTOMRIGHT", -16, 30)

    d.minLbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    d.maxLbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    d.avgLbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    d.minLbl:SetPoint("TOPLEFT", d.chart, "BOTTOMLEFT", 0, -14)
    d.maxLbl:SetPoint("LEFT", d.minLbl, "RIGHT", 40, 0)
    d.avgLbl:SetPoint("LEFT", d.maxLbl, "RIGHT", 40, 0)

    d.built = true
  end

  d.title:SetText(CardLabel(metric))

  -- Granularite : verrouille toute unite >= la fenetre affichee
  local lockMap = { day = { day = false, week = view.period == "day", month = true },
                     week = { day = false, week = false, month = view.period == "week" },
                     month = { day = true, week = false, month = false },
                     year = { day = true, week = true, month = false } }
  local locks = lockMap[view.period] or {}
  local gx = 0
  for _, g in ipairs(SX.GRANULARITIES) do
    local b = d.granButtons[g]
    b:ClearAllPoints()
    b:SetPoint("TOPRIGHT", content, "TOPRIGHT", -gx, -30)
    gx = gx + 64
    local locked = locks[g]
    if locked and view.detailGranularity == g then view.detailGranularity = "day" end
    b:SetEnabled(not locked)
    local gLabel = L["GRANULARITY_" .. g:upper()]
    local labelText
    if locked then
      labelText = "|cFF555555" .. gLabel .. "|r"
    elseif view.detailGranularity == g then
      labelText = UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. gLabel .. "|r"
    else
      labelText = gLabel
    end
    b._label:SetText(labelText)
    b:SetScript("OnClick", function() if not locked then view.detailGranularity = g; SX.RefreshDashboard() end end)
  end
  d.granLabel:SetText(L["GRANULARITY_LABEL"])
  d.granLabel:ClearAllPoints()
  d.granLabel:SetPoint("RIGHT", d.granButtons[SX.GRANULARITIES[1]], "LEFT", -8, 0)

  local bucketCount = (view.detailGranularity == "day") and 30 or (view.detailGranularity == "week" and 12 or 12)
  local series = SX.BuildSeries(view.char, metric, view.detailGranularity, bucketCount)
  local series2 = view.compareChar and SX.BuildSeries(view.compareChar, metric, view.detailGranularity, bucketCount) or nil
  if view.cumulative and series2 then
    series = CombineSeries(series, series2)
    series2 = nil
  end
  local style = (view.detailGranularity == "day") and "bar" or "line"
  local fmtFn = function(p) return p.label .. "\n" .. UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. fmtMetric(metric, p.value) .. "|r" end
  RenderChart(d.chartInner, series, style, ACCENT, series2, SX.COMPARE_ACCENT, true, fmtFn)

  local minV, maxV, avgV = SX.MinMaxAvg(series)
  d.minLbl:SetText(L["DETAIL_MIN"] .. " " .. UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. fmtMetric(metric, minV) .. "|r")
  d.maxLbl:SetText(L["DETAIL_MAX"] .. " " .. UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. fmtMetric(metric, maxV) .. "|r")
  d.avgLbl:SetText(L["DETAIL_AVG"] .. " " .. UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. fmtMetric(metric, avgV) .. "|r")

  for _, w in pairs(d) do if type(w) == "table" and w.Show then w:Show() end end
  for g, b in pairs(d.granButtons) do b:Show() end
end

local function HideDetail()
  local d = detailWidgets
  if not d.built then return end
  for _, w in pairs(d) do if type(w) == "table" and w.Hide then w:Hide() end end
  for g, b in pairs(d.granButtons) do b:Hide() end
end

local function HideOverview()
  for _, card in pairs(cards) do card:Hide() end
end

-- ============================================================================
-- CONSTRUCTION DE LA FENETRE
-- ============================================================================
local function BuildMainFrame()
  mainFrame = CreateFrame("Frame", "StatsMainFrame", UIParent, "BackdropTemplate")
  mainFrame:SetSize(W, H)
  mainFrame:SetPoint("CENTER")
  mainFrame:SetFrameStrata("HIGH")
  mainFrame:SetMovable(true)
  mainFrame:EnableMouse(true)
  mainFrame:RegisterForDrag("LeftButton")
  mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
  mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
  mainFrame:SetClampedToScreen(true)
  UI.SkinFrame(mainFrame, ACCENT, UI.C.BG)
  tinsert(UISpecialFrames, "StatsMainFrame")

  local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText(UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. L["WINDOW_TITLE"] .. "|r")

  local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -4, -4)
  closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)

  mainFrame.banner = UI.CharBanner(mainFrame)
  mainFrame.banner:SetPoint("TOPLEFT", 16, -40)

  -- Ligne 1 : selecteur personnage principal (gauche) + periode (droite)
  mainFrame.charDD = BuildFlatDropdown(mainFrame, 260,
    function() return view.char end,
    function(key) view.char = key; SX.RefreshDashboard() end)
  mainFrame.charDD:SetPoint("TOPLEFT", 16, -62)

  -- Selecteur de periode
  mainFrame.periodButtons = {}
  local px = 0
  for _, p in ipairs(SX.PERIODS) do
    local b = UI.MakeButton(mainFrame, 78, 22, L["PERIOD_" .. p:upper()])
    b:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -14 - px, -62)
    px = px + 82
    b:SetScript("OnClick", function()
      if p == "year" and not SX.HasFullYearOfData() then return end
      view.period = p
      view.detailMetric = nil
      SX.RefreshDashboard()
    end)
    if p == "year" then
      b:SetScript("OnEnter", function(s)
        if SX.HasFullYearOfData() then return end
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L["PERIOD_YEAR_LOCKED"], 1, 1, 1, true)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    mainFrame.periodButtons[p] = b
  end

  -- Ligne 2 : Comparer + selecteur secondaire (masques hors mode comparaison)
  mainFrame.compareBtn = UI.MakeButton(mainFrame, 140, 22, L["COMPARE_BUTTON"])
  mainFrame.compareBtn:SetPoint("TOPLEFT", mainFrame.charDD, "BOTTOMLEFT", 0, -8)
  mainFrame.compareBtn:SetScript("OnClick", function()
    if view.compareChar then
      view.compareChar = nil
    else
      -- Choisit un personnage DIFFERENT du principal - sans ca, avec un seul
      -- personnage suivi, "Comparer" comparait silencieusement le perso avec
      -- lui-meme (courbes identiques superposees = rien ne semblait se
      -- passer, confirme en jeu).
      local pick
      for _, key in ipairs(GetCharChoices()) do
        if key ~= view.char then pick = key; break end
      end
      if not pick then
        print("|cFFFFD700Stats|r : " .. L["COMPARE_NO_OTHER"])
        return
      end
      view.compareChar = pick
    end
    SX.RefreshDashboard()
  end)

  mainFrame.compareDD = BuildFlatDropdown(mainFrame, 220,
    function() return view.compareChar end,
    function(key) view.compareChar = key; SX.RefreshDashboard() end)
  mainFrame.compareDD:SetPoint("LEFT", mainFrame.compareBtn, "RIGHT", 8, 0)

  -- Cumule revient dans le sous-bloc "Comparer" : accroche au selecteur
  -- secondaire, masque tant que Comparer n'est pas actif (comme au tout debut).
  mainFrame.cumulativeCB = CreateFrame("CheckButton", nil, mainFrame, "UICheckButtonTemplate")
  mainFrame.cumulativeCB:SetSize(22, 22)
  mainFrame.cumulativeCB:SetPoint("LEFT", mainFrame.compareDD, "RIGHT", 12, 0)
  local cumLbl = mainFrame.cumulativeCB:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cumLbl:SetPoint("LEFT", mainFrame.cumulativeCB, "RIGHT", 2, 0)
  cumLbl:SetText(L["COMPARE_CUMULATIVE"])
  mainFrame.cumulativeCB:SetScript("OnClick", function(s) view.cumulative = s:GetChecked() and true or false; SX.RefreshDashboard() end)

  -- Legende couleur (mode Comparer) : qui est quelle couleur, en un coup
  -- d'oeil, sans avoir a la redeviner sur chaque carte.
  mainFrame.compareLegend = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  mainFrame.compareLegend:SetPoint("TOPLEFT", mainFrame.compareBtn, "BOTTOMLEFT", 0, -8)

  -- Bouton export
  mainFrame.exportBtn = UI.MakeButton(mainFrame, 220, 22, L["EXPORT_BUTTON"])
  mainFrame.exportBtn:SetPoint("BOTTOMRIGHT", -14, 12)
  mainFrame.exportBtn:SetScript("OnClick", function() if SX.ShowExportPopup then SX.ShowExportPopup() end end)

  mainFrame.weeklyNote = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  mainFrame.weeklyNote:SetPoint("BOTTOMLEFT", 16, 16)
  mainFrame.weeklyNote:SetText(L["WEEKLY_GOLD_NOTE"])

  -- Zone de contenu (scroll, pour tolerer un contenu plus grand que la fenetre)
  local scroll = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 16, -148)
  scroll:SetPoint("BOTTOMRIGHT", -30, 40)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(W - 60, 10)
  scroll:SetScrollChild(content)
  mainFrame.content = content

  UI.AddHeaderControls(mainFrame, { accent = ACCENT, onOptions = function() if SX.OpenOptions then SX.OpenOptions() end end })

  mainFrame:Hide()
end

function SX.RefreshDashboard()
  if not mainFrame then return end
  view.char = view.char or SX.CurrentCharKey()

  mainFrame.banner:SetText(UI.CharBannerText(view.char == "__account__" and nil or SX.CharBannerData(view.char)))
  if mainFrame.charDD.Refresh then mainFrame.charDD.Refresh() end
  if mainFrame.compareDD.Refresh then mainFrame.compareDD.Refresh() end
  mainFrame.compareDD:SetShown(view.compareChar ~= nil)
  mainFrame.cumulativeCB:SetShown(view.compareChar ~= nil)
  mainFrame.compareBtn._label:SetText(view.compareChar and L["COMPARE_STOP"] or L["COMPARE_BUTTON"])

  if view.compareChar then
    local pColor = SeriesColor(view.char, ACCENT)
    local cColor = SeriesColor(view.compareChar, SX.COMPARE_ACCENT)
    local pName, cName = CharDisplayName(view.char), CharDisplayName(view.compareChar)
    -- Pas de glyphe Unicode pour la pastille de couleur (meme piege que la
    -- fleche du selecteur / les deltas +/- plus haut) : le NOM colore fait
    -- deja office de pastille, inutile de risquer un carre vide en plus.
    mainFrame.compareLegend:SetText(
      UI.Hex(pColor[1], pColor[2], pColor[3]) .. pName .. "|r    vs    "
      .. UI.Hex(cColor[1], cColor[2], cColor[3]) .. cName .. "|r"
      .. (view.cumulative and ("    |cFF888899(" .. L["COMPARE_CUMULATIVE"] .. ")|r") or ""))
    mainFrame.compareLegend:Show()
  else
    mainFrame.compareLegend:Hide()
  end

  for p, b in pairs(mainFrame.periodButtons) do
    local locked = (p == "year") and not SX.HasFullYearOfData()
    if locked then
      b._label:SetText("|cFF555555" .. L["PERIOD_" .. p:upper()] .. "|r")
    else
      b._label:SetText(p == view.period and (UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. L["PERIOD_" .. p:upper()] .. "|r") or L["PERIOD_" .. p:upper()])
    end
  end
  mainFrame.weeklyNote:SetShown(view.period == "week")

  if view.detailMetric then
    HideOverview()
    BuildDetail(mainFrame.content, view.detailMetric)
    mainFrame.content:SetHeight(420)
  else
    HideDetail()
    BuildOverview(mainFrame.content)
    mainFrame.content:SetHeight(2 * 190 + 16 + 10)
  end
end

function SX.Toggle()
  if not mainFrame then BuildMainFrame() end
  if mainFrame:IsShown() then
    mainFrame:Hide()
  else
    mainFrame:Show()
    SX.RefreshDashboard()
  end
end

function SX.IsShown() return mainFrame and mainFrame:IsShown() end

-- ============================================================================
-- PANNEAU D'OPTIONS (convention commune : bouton "Options" de l'en-tete,
-- clic droit sur la vignette de la barre)
-- ============================================================================
local optPanel
local function BuildOptions()
  if optPanel then return end
  optPanel = UI.CreateOptionsPanel({ name = "StatsOptions", title = L["OPT_TITLE"], accent = ACCENT })
  optPanel:Section(L["WINDOW_TITLE"])
  optPanel:Note(L["EXPORT_HINT"])
  optPanel:Button(L["EXPORT_BUTTON"], function() if SX.ShowExportPopup then SX.ShowExportPopup() end end)
end

function SX.OpenOptions()
  BuildOptions()
  optPanel:Toggle()
end

-- Fonctions globales attendues par le core TibiSuite (fallback + mode standalone)
function Stats_Toggle() SX.Toggle() end
function Stats_OpenOptions() SX.OpenOptions() end
