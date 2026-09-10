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
  detailMetric = nil,  -- nil = vue d'ensemble ; sinon "quests"/"gold"/"dungeons"/"played"/"__overlay__"/"__pvp__"
  detailGranularity = "day",
  -- "semaine" par defaut (pas "jour" comme detailGranularity) : 7-8
  -- metriques normalisees independamment, superposees en granularite jour,
  -- produisent un zigzag illisible des que le joueur est actif chaque jour
  -- sur plusieurs categories (constat utilisateur, capture d'ecran en jeu -
  -- le lissage Catmull-Rom seul ne suffisait pas). L'agregation par semaine
  -- lisse le bruit quotidien a la source, pas juste visuellement.
  overlayGranularity = "week",
  pvpChartGranularity = "day",
  -- Legende cliquable des graphiques superposes : cle metrique -> false
  -- veut dire "courbe cachee" (absent/true = visible). Meme constat que
  -- overlayGranularity : trop de courbes normalisees independamment
  -- superposees reste illisible quelle que soit la granularite/le lissage -
  -- laisser choisir lesquelles afficher regle le probleme a la racine.
  overlayEnabledMetrics = {},
  pvpEnabledMetrics = {},
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

-- Superpose N series (une par metrique de CARD_METRICS) sur le meme axe -
-- seriesList = liste de { key, color={r,g,b}, points } ou points est deja
-- normalise 0-100 (cf. NormalizeSeries). Une seule zone de survol par
-- abscisse (pas une par serie) : fmtFn recoit { index, seriesList } et
-- compose une infobulle listant la valeur REELLE de chaque metrique a cette
-- date (points[i].actual, pas la valeur normalisee tracee a l'ecran).
local function RenderOverlayChart(container, seriesList, showLabels, fmtFn, granularity)
  WipeChart(container)
  local cw, ch = container:GetWidth(), container:GetHeight()
  if not seriesList or #seriesList == 0 or cw <= 0 then return end
  local n = 0
  for _, s in ipairs(seriesList) do n = math.max(n, #s.points) end
  if n == 0 then return end

  local labelH = showLabels and 14 or 0
  local plotH = ch - labelH
  local function yFor(v) return (v / 100) * (plotH - 4) end
  local stepX = n > 1 and (cw / (n - 1)) or 0

  -- Pas de puces par point ici (contrairement a drawLine/RenderChart) :
  -- avec 5-8 series superposees, une puce a chaque point (x7-8) ajoutait
  -- surtout du bruit visuel sans lisibilite en plus - le detail exact par
  -- date reste accessible via l'infobulle (fmtFn/AttachHitTooltip
  -- ci-dessous). Lignes plus fines et plus transparentes pour la meme
  -- raison (constat utilisateur : chevauchement illisible avec des
  -- puces pleines, capture d'ecran en jeu).
  --
  -- Granularite "jour" = barres, pas de lignes (meme convention que
  -- RenderChart plus haut : "barres pour jour, ligne pour semaine/mois/
  -- annee"). Les metriques suivies (quetes, donjons, gouffres...) sont des
  -- COMPTEURS journaliers epars - beaucoup de jours a 0, quelques pics -
  -- relier ces valeurs par des segments diagonaux cree un zigzag illisible
  -- meme avec une seule courbe selectionnee (constat utilisateur : la
  -- legende cliquable filtre bien les courbes, mais celle qui reste est
  -- "zigzag / illisible" a la granularite Jour). Une interpolation
  -- Catmull-Rom testee avant ca a empire les choses (une spline peut
  -- largement depasser/overshoot la plage locale quand la valeur change
  -- brusquement de direction) - le vrai probleme n'etait pas le lissage
  -- mais le style "ligne" applique a une donnee ponctuelle/eparse.
  if granularity == "day" then
    local barW = math.max((cw / n) * 0.55, 2)
    for _, s in ipairs(seriesList) do
      for i, p in ipairs(s.points) do
        local x = (i - 1) * stepX
        local y = math.max(yFor(p.value), 1)
        local bar = AcquireBar(container)
        bar:ClearAllPoints()
        -- AcquireBar recycle le meme pool de textures que le style "ligne"
        -- ci-dessous (SetRotation pour orienter un segment diagonal) : sans
        -- remise a zero explicite, une texture reutilisee garde l'angle de
        -- son precedent rendu (ex. bascule Semaine -> Jour) et une "barre"
        -- s'affiche encore penchee en diagonale (constat utilisateur,
        -- capture d'ecran en jeu apres /reload confirme).
        bar:SetRotation(0)
        bar:SetColorTexture(s.color[1], s.color[2], s.color[3], 0.8)
        bar:SetSize(barW, y)
        bar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", x - barW / 2, labelH)
      end
    end
  else
    -- Semaine/Mois/Annee : donnees deja agregees, une ligne reste lisible.
    -- Segments DROITS entre points reels (pas de lissage courbe, cf. le
    -- constat Catmull-Rom ci-dessus).
    for _, s in ipairs(seriesList) do
      local prevX, prevY
      for i, p in ipairs(s.points) do
        local x, y = (i - 1) * stepX, yFor(p.value)
        if prevX then
          local seg = AcquireBar(container)
          seg:ClearAllPoints()
          seg:SetColorTexture(s.color[1], s.color[2], s.color[3], 0.7)
          local dx, dy = x - prevX, y - prevY
          local len = math.sqrt(dx * dx + dy * dy)
          seg:SetSize(math.max(len, 0.01), 1.5)
          seg:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", prevX, labelH + prevY - 0.75)
          seg:SetRotation(math.atan2(dy, dx))
        end
        prevX, prevY = x, y
      end
    end
  end

  if fmtFn then
    for i = 1, n do
      local x = (i - 1) * stepX
      local hitW = math.max(stepX, 10)
      local hit = AcquireHit(container)
      hit:ClearAllPoints()
      hit:SetSize(hitW, ch)
      hit:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", x - hitW / 2, 0)
      AttachHitTooltip(hit, { index = i, seriesList = seriesList }, fmtFn)
    end
  end

  if showLabels then
    local first = seriesList[1]
    for i, p in ipairs(first.points) do
      local x = (i - 1) * stepX
      local lbl = AcquireLabel(container)
      lbl:ClearAllPoints()
      lbl:SetPoint("TOP", container, "BOTTOMLEFT", x, labelH - ch)
      lbl:SetWidth(stepX > 0 and stepX or 40)
      lbl:SetText(p.label)
    end
  end
end

-- ============================================================================
-- CARTES DE LA VUE D'ENSEMBLE
-- ============================================================================
-- Ordre : stats generales d'abord (quetes/or/temps/donjons), puis une carte
-- par categorie DANS LE MEME ORDRE que les tuiles resume plus bas
-- (Gouffres/PVP/Tourments/Reputations) - facilite le repere visuel entre
-- les deux sections.
-- PVP (adversaires tues/champs de bataille/arenes) vit dans son propre
-- graphique dedie (bouton "Graphique PVP" du panneau PVP) plutot qu'ici -
-- cf. PVP_CHART_METRICS plus bas.
local CARD_METRICS = { "quests", "gold", "played", "dungeons", "delves", "repGained", "profGained" }
local cards = {}

-- Couleurs fixes pour la superposition multi-metriques (graphique "Toutes les
-- metriques") - une couleur par entree de CARD_METRICS, memes teintes que le
-- site/Tibi Companion (dashboard-shared.js, OVERLAY_COLORS) pour rester
-- coherent entre les deux interfaces.
local OVERLAY_COLORS = {
  quests = { 0.310, 0.816, 0.773 }, gold = { 0.957, 0.839, 0.541 }, played = { 0.486, 0.620, 1.000 },
  dungeons = { 1.000, 0.541, 0.541 }, delves = { 0.702, 0.537, 0.957 },
  repGained = { 0.431, 0.906, 0.718 }, profGained = { 1.000, 0.706, 0.329 },
}

-- Graphique PVP dedie ("Graphique PVP") : adversaires tues + champs de
-- bataille + arenes, toujours superposes (pas de mode une-seule-metrique,
-- 5 courbes restent lisibles sans le detour par une grille de cartes).
local PVP_CHART_METRICS = { "pvpKillsGained", "bgPlayedGained", "bgWonGained", "arenaPlayedGained", "arenaWonGained" }
local PVP_OVERLAY_COLORS = {
  pvpKillsGained = { 1.000, 0.431, 0.780 }, bgPlayedGained = { 0.486, 0.620, 1.000 }, bgWonGained = { 0.431, 0.906, 0.718 },
  arenaPlayedGained = { 1.000, 0.706, 0.329 }, arenaWonGained = { 0.702, 0.537, 0.957 },
}

local function CardLabel(metric)
  if metric == "quests" then return L["CARD_QUESTS"]
  elseif metric == "gold" then
    return (view.period == "week") and L["CARD_GOLD_WEEK"] or L["CARD_GOLD"]
  elseif metric == "dungeons" then return L["CARD_DUNGEONS"]
  elseif metric == "played" then return L["CARD_PLAYED"]
  elseif metric == "delves" then return L["CARD_DELVES"]
  elseif metric == "repGained" then return L["CARD_REP_GAINED"]
  elseif metric == "pvpKillsGained" then return L["CARD_PVP_KILLS_GAINED"]
  elseif metric == "profGained" then return L["CARD_PROF_GAINED"]
  elseif metric == "bgPlayedGained" then return L["CARD_BG_PLAYED_GAINED"]
  elseif metric == "bgWonGained" then return L["CARD_BG_WON_GAINED"]
  elseif metric == "arenaPlayedGained" then return L["CARD_ARENA_PLAYED_GAINED"]
  elseif metric == "arenaWonGained" then return L["CARD_ARENA_WON_GAINED"]
  end
end

-- Legende cliquable pour les graphiques superposes : un petit bouton-texte
-- par metrique (couleur pleine si visible, gris si cachee via stateTable),
-- flux gauche-a-droite avec largeur mesuree (pas de layout automatique en
-- UI WoW). pool est une table persistante (ex. overlayWidgets.legendButtons)
-- pour reutiliser les memes boutons d'un rafraichissement a l'autre. Repond
-- au constat utilisateur : trop de courbes superposees reste illisible
-- quels que soient granularite/lissage - laisser choisir lesquelles
-- afficher regle le probleme a la racine plutot que d'ajuster le rendu.
local function BuildLegendToggles(container, pool, metricKeys, colorOf, stateTable, top)
  local x = 0
  for _, key in ipairs(metricKeys) do
    local btn = pool[key]
    if not btn then
      btn = CreateFrame("Button", nil, container)
      local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      fs:SetPoint("LEFT", 0, 0)
      btn._label = fs
      pool[key] = btn
    end
    btn:SetScript("OnClick", function()
      stateTable[key] = (stateTable[key] == false) and true or false
      SX.RefreshDashboard()
    end)
    local enabled = stateTable[key] ~= false
    local c = colorOf(key) or ACCENT
    local text = CardLabel(key)
    btn._label:SetText(enabled and (UI.Hex(c[1], c[2], c[3]) .. text .. "|r") or ("|cFF555555" .. text .. "|r"))
    local w = btn._label:GetStringWidth() + 4
    btn:SetSize(w, 16)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", container, "TOPLEFT", x, top)
    x = x + w + 18
    btn:Show()
  end
end

-- Filtre les series dont l'utilisateur a decoche la courbe (legende
-- interactive ci-dessus) - stateTable[key] == false = cachee.
local function FilterEnabledSeries(seriesList, stateTable)
  local out = {}
  for _, s in ipairs(seriesList) do
    if stateTable[s.key] ~= false then out[#out + 1] = s end
  end
  return out
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

-- Normalise une serie sur 0-100 (min-max de la serie elle-meme) pour rendre
-- des metriques d'echelles tres differentes (quetes ~100, or ~milliers,
-- temps joue en heures...) comparables visuellement sur un meme axe -
-- utilise par le graphique "Toutes les metriques". La valeur reelle est
-- conservee dans `actual` pour l'infobulle.
local function NormalizeSeries(series)
  local minV, maxV
  for _, p in ipairs(series) do
    if not minV or p.value < minV then minV = p.value end
    if not maxV or p.value > maxV then maxV = p.value end
  end
  minV, maxV = minV or 0, maxV or 0
  local span = maxV - minV
  local out = {}
  for i, p in ipairs(series) do
    -- Serie plate (aucune variation, cas courant : 0 activite toute la
    -- periode) -> 0%, pas 50% - eviterait de laisser croire a une valeur a
    -- mi-chemin de quelque chose alors qu'il n'y a rien a etaler entre un
    -- min et un max identiques.
    out[i] = { label = p.label, actual = p.value, value = span > 0 and ((p.value - minV) / span) * 100 or 0 }
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
    elseif metric == "delves" then
      -- Palier max/compagnon : snapshot du personnage principal uniquement,
      -- pas de sens en mode Cumule (deux personnages, deux compagnons).
      local rec = (view.char ~= "__account__") and StatsDB[view.char]
      local subParts = {}
      if rec and rec.delveHighestTier then subParts[#subParts + 1] = L["DELVES_TIER"] .. " " .. rec.delveHighestTier end
      if rec and rec.delveCompanionLevel then subParts[#subParts + 1] = L["DELVES_COMPANION"] .. " " .. rec.delveCompanionLevel end
      card.sub:SetText(table.concat(subParts, "  /  "))
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
-- GOUFFRES / PVP / TOURMENTS - presentation en 3 tuiles resume (chiffres cle
-- cote a cote) + tableaux de detail en dessous, plutot que 3 gros panneaux
-- empiles en texte. Snapshots cumules, pas un historique jour par jour comme
-- les cartes de la grille du dessus (aucune donnee equivalente jour par jour
-- n'existe cote client pour ces compteurs).
-- ============================================================================
local PVP_BRACKET_ORDER = { "2v2", "3v3", "rbg", "shuffle", "blitz" }
local PVP_BRACKET_LABEL_KEYS = {
  ["2v2"] = "PVP_BRACKET_2V2", ["3v3"] = "PVP_BRACKET_3V3",
  rbg = "PVP_BRACKET_RBG", shuffle = "PVP_BRACKET_SHUFFLE", blitz = "PVP_BRACKET_BLITZ",
}

-- Petit "chip" statistique (libelle discret en haut, valeur mise en avant en
-- dessous, sur 2 lignes dans une seule FontString).
local function SetChip(fs, label, value)
  fs:SetText(UI.Hex(UI.C.MUTED[1], UI.C.MUTED[2], UI.C.MUTED[3]) .. label .. "|r\n"
    .. UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. tostring(value) .. "|r")
end

local function PctText(wins, total)
  if not total or total == 0 then return 0 end
  return math.floor(wins / total * 100 + 0.5)
end

-- Positionne une FontString dans une colonne de tableau a largeur fixe (x
-- constant d'une ligne a l'autre) : c'est ce qui garde les colonnes alignees
-- quelle que soit la longueur du texte de chaque ligne.
local function PlaceCol(fs, col, y, justify)
  fs:ClearAllPoints()
  fs:SetPoint("TOPLEFT", col.x, y)
  fs:SetWidth(col.w)
  fs:SetJustifyH(justify or "LEFT")
end

-- ----------------------------------------------------------------------------
-- TUILES RESUME
-- ----------------------------------------------------------------------------
local summaryTiles
local SUMMARY_TILE_H = 96

local function BuildTile(parent, title)
  local tile = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  UI.SkinFrame(tile, ACCENT, UI.C.PANEL)
  tile.title = tile:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  tile.title:SetPoint("TOPLEFT", 14, -12)
  tile.title:SetText(title)
  tile.stats = {}
  for i = 1, 3 do
    tile.stats[i] = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  end
  tile.sub = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  tile.sub:SetPoint("BOTTOMLEFT", 14, 12)
  tile.sub:SetPoint("BOTTOMRIGHT", -14, 12)
  tile.sub:SetJustifyH("LEFT")

  -- Zone invisible superposee a la ligne "sub" : donne l'infobulle native du
  -- haut fait au survol et l'ouvre au clic quand tile.subHit.achievementID
  -- est renseigne (une FontString seule n'est pas interactive en WoW).
  tile.subHit = CreateFrame("Button", nil, tile)
  tile.subHit:SetPoint("BOTTOMLEFT", tile.sub, "BOTTOMLEFT", 0, -2)
  tile.subHit:SetPoint("TOPRIGHT", tile.sub, "TOPRIGHT", 0, 2)
  tile.subHit:SetScript("OnEnter", function(self)
    if not self.achievementID then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetAchievementByID(self.achievementID)
    GameTooltip:Show()
  end)
  tile.subHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
  tile.subHit:SetScript("OnMouseUp", function(self)
    if not self.achievementID then return end
    pcall(function()
      if not AchievementFrame and AchievementFrame_LoadUI then AchievementFrame_LoadUI() end
      if AchievementFrame_SelectAchievement then AchievementFrame_SelectAchievement(self.achievementID) end
      if ShowUIPanel and AchievementFrame then ShowUIPanel(AchievementFrame) end
    end)
  end)
  return tile
end

-- 5 tuiles, disposees en 2 lignes (3 puis 2) plutot que 5 en largeur -
-- une seule ligne de 5 rendrait chaque tuile trop etroite pour ses 3
-- chiffres (retour utilisateur sur les Metiers : ne pas re-tomber dans
-- "tout est melange" en serrant trop d'elements sur une meme ligne).
local SUMMARY_ROWS = {
  { "delves", "pvp", "torghast" },
  { "reputations", "professions" },
}

local function BuildSummaryTiles(content, top)
  if not summaryTiles then
    summaryTiles = {
      delves = BuildTile(content, L["CARD_DELVES"]),
      pvp = BuildTile(content, L["PVP_SECTION_TITLE"]),
      torghast = BuildTile(content, L["TORGHAST_SECTION_TITLE"]),
      reputations = BuildTile(content, L["REPUTATION_SECTION_TITLE"]),
      professions = BuildTile(content, L["PROFESSIONS_SECTION_TITLE"]),
    }
  end

  local gap = 14
  local tileW = (W - 60 - 2 * gap) / 3
  for r, row in ipairs(SUMMARY_ROWS) do
    for c, key in ipairs(row) do
      local tile = summaryTiles[key]
      tile:ClearAllPoints()
      tile:SetPoint("TOPLEFT", content, "TOPLEFT", (c - 1) * (tileW + gap), top - (r - 1) * (SUMMARY_TILE_H + gap))
      tile:SetSize(tileW, SUMMARY_TILE_H)
      local statW = (tileW - 28) / 3
      for s = 1, 3 do
        tile.stats[s]:ClearAllPoints()
        tile.stats[s]:SetPoint("TOPLEFT", 14 + (s - 1) * statW, -34)
        tile.stats[s]:SetWidth(statW)
      end
      tile:Show()
    end
  end

  local rec = (view.char ~= "__account__") and StatsDB[view.char]

  local delveTypes = rec and rec.delveTypes
  local delveTypesTotal = 0
  if delveTypes then for _, e in pairs(delveTypes) do delveTypesTotal = delveTypesTotal + (e.count or 0) end end
  -- "Detail par gouffre" (delveTypes) ne compte qu'a partir du moment ou
  -- l'addon a commence a suivre (aucune API retroactive par NOM de gouffre) ;
  -- delveCompletedLifetime vient des Statistiques Blizzard (a vie, toutes
  -- saisons) et peut donc etre superieur - on prend toujours le plus grand
  -- des deux pour ne jamais afficher un total qui recule.
  local delveTotal = math.max(delveTypesTotal, (rec and rec.delveCompletedLifetime) or 0)
  SetChip(summaryTiles.delves.stats[1], L["DELVES_TOTAL"], delveTotal)
  SetChip(summaryTiles.delves.stats[2], L["TILE_TIER"], (rec and rec.delveHighestTier) or "-")
  SetChip(summaryTiles.delves.stats[3], L["TILE_COMPANION"], (rec and rec.delveCompanionLevel) or "-")
  local delveAchID = rec and rec.delveTierAchievementID
  local delveAchName = rec and rec.delveTierAchievementName
  if delveAchName then
    summaryTiles.delves.sub:SetText(UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. delveAchName .. "|r")
  elseif rec and SX.DelveAllMaxed(rec) then
    summaryTiles.delves.sub:SetText(UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. L["DELVE_ALL_MAXED"] .. "|r")
  elseif delveTotal == 0 then
    summaryTiles.delves.sub:SetText(L["DELVE_TYPES_NO_DATA"])
  else
    summaryTiles.delves.sub:SetText("")
  end
  summaryTiles.delves.subHit.achievementID = delveAchID

  local pvp = rec and rec.pvp
  SetChip(summaryTiles.pvp.stats[1], L["TILE_KILLS"], pvp and pvp.honorableKills or 0)
  SetChip(summaryTiles.pvp.stats[2], L["PVP_HONOR"], pvp and pvp.honor or 0)
  SetChip(summaryTiles.pvp.stats[3], L["PVP_CONQUEST"], pvp and pvp.conquest or 0)
  summaryTiles.pvp.sub:SetText((pvp and pvp.brackets and next(pvp.brackets)) and "" or L["PVP_NO_DATA"])

  local t = rec and rec.torghast
  SetChip(summaryTiles.torghast.stats[1], L["TILE_TIER"], (t and t.highestLayer) or "-")
  SetChip(summaryTiles.torghast.stats[2], L["TILE_ASH"], (t and t.soulAsh) or 0)
  SetChip(summaryTiles.torghast.stats[3], L["TILE_CINDERS"], (t and t.soulCinders) or 0)
  summaryTiles.torghast.sub:SetText((t and (t.highestLayer or t.soulAsh or t.soulCinders)) and "" or L["TORGHAST_NO_DATA"])

  local repSummary = rec and rec.reputations and rec.reputations.summary
  SetChip(summaryTiles.reputations.stats[1], L["REP_TRACKED"], (repSummary and repSummary.tracked) or 0)
  SetChip(summaryTiles.reputations.stats[2], L["REP_MAX_RANK"], (repSummary and repSummary.highestRenownRank) or "-")
  SetChip(summaryTiles.reputations.stats[3], L["REP_MAXED"], (repSummary and repSummary.maxedCount) or 0)
  if repSummary and repSummary.paragonReady and repSummary.paragonReady > 0 then
    summaryTiles.reputations.sub:SetText(UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3])
      .. string.format(L["REP_PARAGON_FMT"], repSummary.paragonReady) .. "|r")
  elseif repSummary and repSummary.tracked > 0 and repSummary.maxedCount == repSummary.tracked then
    summaryTiles.reputations.sub:SetText(UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. L["REP_ALL_MAXED"] .. "|r")
  elseif not repSummary or repSummary.tracked == 0 then
    summaryTiles.reputations.sub:SetText(L["REP_NO_DATA"])
  else
    summaryTiles.reputations.sub:SetText("")
  end

  local profSummary = rec and rec.professionsNative and rec.professionsNative.summary
  local profInProgress = profSummary and (profSummary.tracked - profSummary.maxedCount) or 0
  SetChip(summaryTiles.professions.stats[1], L["PROF_TRACKED"], (profSummary and profSummary.tracked) or 0)
  SetChip(summaryTiles.professions.stats[2], L["PROF_MAXED"], (profSummary and profSummary.maxedCount) or 0)
  SetChip(summaryTiles.professions.stats[3], L["PROF_IN_PROGRESS"], profInProgress)
  -- Ligne : nom du metier le plus recemment progresse (le plus recent parmi
  -- ceux non-maxes), sinon tous au max, sinon aucun metier suivi.
  local mostRecentProf, mostRecentAt
  local profList = rec and rec.professionsNative and rec.professionsNative.list
  if profList then
    for _, p in ipairs(profList) do
      if not p.maxed and p.lastGainAt and (not mostRecentAt or p.lastGainAt > mostRecentAt) then
        mostRecentProf, mostRecentAt = p.name, p.lastGainAt
      end
    end
  end
  if mostRecentProf then
    summaryTiles.professions.sub:SetText(UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. mostRecentProf .. "|r")
  elseif profSummary and profSummary.tracked > 0 and profSummary.maxedCount == profSummary.tracked then
    summaryTiles.professions.sub:SetText(UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. L["PROF_ALL_MAXED"] .. "|r")
  elseif not profSummary or profSummary.tracked == 0 then
    summaryTiles.professions.sub:SetText(L["PROF_NO_DATA"])
  else
    summaryTiles.professions.sub:SetText("")
  end

  return 2 * SUMMARY_TILE_H + gap
end

local function HideSummaryTiles()
  if summaryTiles then for _, tile in pairs(summaryTiles) do tile:Hide() end end
end

-- ----------------------------------------------------------------------------
-- DETAIL PVP : bilan par bracket + detail par champ de bataille, en tableaux.
-- ----------------------------------------------------------------------------
local pvpDetailPanel
local PVP_MAX_BG_ROWS = 6
local PVP_COLS = { name = { x = 14, w = 210 }, rating = { x = 224, w = 90 }, best = { x = 314, w = 110 }, record = { x = 424, w = 442 } }
local BG_COLS = { name = { x = 14, w = 600 }, wins = { x = 614, w = 252 } }

local function BuildPvPDetail(content, top)
  if not pvpDetailPanel then
    pvpDetailPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    UI.SkinFrame(pvpDetailPanel, ACCENT, UI.C.PANEL)
    pvpDetailPanel.title = pvpDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pvpDetailPanel.title:SetPoint("TOPLEFT", 14, -12)
    pvpDetailPanel.title:SetText(L["PVP_SECTION_TITLE"])

    -- Ouvre le graphique PVP dedie (adversaires tues + champs de bataille +
    -- arenes dans le temps). A VERIFIER EN JEU : place juste a droite du
    -- titre "PVP" (texte court), suppose sans chevauchement avec les puces
    -- de morts en haut a droite du panneau - pas confirme en jeu.
    pvpDetailPanel.chartBtn = UI.MakeButton(pvpDetailPanel, 130, 20, L["PVP_CHART_BUTTON"])
    pvpDetailPanel.chartBtn:SetPoint("LEFT", pvpDetailPanel.title, "RIGHT", 16, 0)
    pvpDetailPanel.chartBtn:SetScript("OnClick", function()
      view.detailMetric = "__pvp__"
      SX.RefreshDashboard()
    end)

    pvpDetailPanel.deathsEnemyChip = pvpDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pvpDetailPanel.deathsEnemyChip:SetJustifyH("RIGHT")
    pvpDetailPanel.deathsEnemyChip:SetPoint("TOPRIGHT", -14, -8)
    pvpDetailPanel.deathsPlayersChip = pvpDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pvpDetailPanel.deathsPlayersChip:SetJustifyH("RIGHT")
    pvpDetailPanel.deathsPlayersChip:SetPoint("TOPRIGHT", pvpDetailPanel.deathsEnemyChip, "TOPLEFT", -26, 0)

    pvpDetailPanel.arenaLine = pvpDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pvpDetailPanel.arenaLine:SetPoint("TOPLEFT", 14, -40)
    pvpDetailPanel.bgLine = pvpDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pvpDetailPanel.bgLine:SetJustifyH("RIGHT")
    pvpDetailPanel.bgLine:SetPoint("TOPRIGHT", -14, -40)

    pvpDetailPanel.bracketHead = {}
    for key in pairs(PVP_COLS) do
      pvpDetailPanel.bracketHead[key] = pvpDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    end
    pvpDetailPanel.bracketRows = {}
    for i = 1, #PVP_BRACKET_ORDER do
      local row = {}
      for key in pairs(PVP_COLS) do row[key] = pvpDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") end
      pvpDetailPanel.bracketRows[i] = row
    end
    pvpDetailPanel.noData = pvpDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    pvpDetailPanel.noData:SetText(L["PVP_NO_DATA"])

    pvpDetailPanel.bgSep = pvpDetailPanel:CreateTexture(nil, "ARTWORK")
    pvpDetailPanel.bgSep:SetColorTexture(1, 1, 1, 0.08)
    pvpDetailPanel.bgSep:SetHeight(1)
    pvpDetailPanel.bgHead = {}
    for key in pairs(BG_COLS) do
      pvpDetailPanel.bgHead[key] = pvpDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    end
    pvpDetailPanel.bgRows = {}
    for i = 1, PVP_MAX_BG_ROWS do
      local row = {}
      for key in pairs(BG_COLS) do row[key] = pvpDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") end
      pvpDetailPanel.bgRows[i] = row
    end
    pvpDetailPanel.bgNoData = pvpDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    pvpDetailPanel.bgNoData:SetText(L["PVP_BG_NO_DATA"])
  end

  pvpDetailPanel:ClearAllPoints()
  pvpDetailPanel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
  pvpDetailPanel:SetWidth(W - 60)

  local rec = (view.char ~= "__account__") and StatsDB[view.char]
  local pvp = rec and rec.pvp

  SetChip(pvpDetailPanel.deathsEnemyChip, L["PVP_DEATHS_BY_ENEMY"], pvp and pvp.deathsByEnemyFaction or 0)
  SetChip(pvpDetailPanel.deathsPlayersChip, L["PVP_DEATHS_BY_PLAYERS"], pvp and pvp.deathsByPlayers or 0)

  local arena = pvp and pvp.arena
  pvpDetailPanel.arenaLine:SetText(UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. L["PVP_ARENA_TITLE"] .. "|r  "
    .. (arena and string.format(L["PVP_ARENA_SUMMARY_FMT"], arena.played or 0, arena.won or 0, PctText(arena.won or 0, arena.played or 0)) or "-"))
  local bgParticipation = pvp and pvp.bgParticipation
  pvpDetailPanel.bgLine:SetText(UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. L["PVP_BG_TITLE"] .. "|r  "
    .. ((bgParticipation and bgParticipation > 0) and string.format(L["PVP_BG_SUMMARY_FMT"], bgParticipation, (pvp and pvp.bgWinsTotal) or 0, PctText((pvp and pvp.bgWinsTotal) or 0, bgParticipation)) or "-"))

  local headY = -66
  PlaceCol(pvpDetailPanel.bracketHead.name, PVP_COLS.name, headY, "LEFT")
  pvpDetailPanel.bracketHead.name:SetText(L["TABLE_BRACKET"])
  PlaceCol(pvpDetailPanel.bracketHead.rating, PVP_COLS.rating, headY, "RIGHT")
  pvpDetailPanel.bracketHead.rating:SetText(L["TABLE_RATING"])
  PlaceCol(pvpDetailPanel.bracketHead.best, PVP_COLS.best, headY, "RIGHT")
  pvpDetailPanel.bracketHead.best:SetText(L["TABLE_BEST"])
  PlaceCol(pvpDetailPanel.bracketHead.record, PVP_COLS.record, headY, "RIGHT")
  pvpDetailPanel.bracketHead.record:SetText(L["TABLE_RECORD"])

  local shown = 0
  if pvp and pvp.brackets then
    for _, key in ipairs(PVP_BRACKET_ORDER) do
      local b = pvp.brackets[key]
      if b then
        shown = shown + 1
        local y = headY - 20 - 22 * (shown - 1)
        local row = pvpDetailPanel.bracketRows[shown]
        local wins, losses = b.seasonWon or 0, math.max(0, (b.seasonPlayed or 0) - (b.seasonWon or 0))
        PlaceCol(row.name, PVP_COLS.name, y, "LEFT")
        row.name:SetText(L[PVP_BRACKET_LABEL_KEYS[key]])
        PlaceCol(row.rating, PVP_COLS.rating, y, "RIGHT")
        row.rating:SetText(UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. tostring(b.rating or 0) .. "|r")
        PlaceCol(row.best, PVP_COLS.best, y, "RIGHT")
        row.best:SetText(tostring(b.seasonBest or b.rating or 0))
        PlaceCol(row.record, PVP_COLS.record, y, "RIGHT")
        row.record:SetText(string.format(L["PVP_RECORD_FMT"], wins, losses, PctText(wins, wins + losses)))
        for _, fs in pairs(row) do fs:Show() end
      end
    end
  end
  for i = shown + 1, #PVP_BRACKET_ORDER do
    for _, fs in pairs(pvpDetailPanel.bracketRows[i]) do fs:Hide() end
  end
  for _, fs in pairs(pvpDetailPanel.bracketHead) do fs:SetShown(shown > 0) end
  pvpDetailPanel.noData:ClearAllPoints()
  pvpDetailPanel.noData:SetPoint("TOPLEFT", 14, headY)
  pvpDetailPanel.noData:SetShown(shown == 0)

  local bracketsBottom = (shown > 0) and (headY - 20 - shown * 22) or (headY - 20)

  local sortedBg = {}
  if pvp and pvp.bgWinsByName then
    for name, wins in pairs(pvp.bgWinsByName) do sortedBg[#sortedBg + 1] = { name = name, wins = wins } end
    table.sort(sortedBg, function(a, b) return a.wins > b.wins end)
  end
  local bgShown = math.min(#sortedBg, PVP_MAX_BG_ROWS)

  local bgTop = bracketsBottom - 16
  pvpDetailPanel.bgSep:ClearAllPoints()
  pvpDetailPanel.bgSep:SetPoint("TOPLEFT", 14, bgTop)
  pvpDetailPanel.bgSep:SetPoint("TOPRIGHT", -14, bgTop)
  pvpDetailPanel.bgSep:SetShown(bgShown > 0)

  local bottomDepth
  if bgShown > 0 then
    local bgHeadY = bgTop - 12
    PlaceCol(pvpDetailPanel.bgHead.name, BG_COLS.name, bgHeadY, "LEFT")
    pvpDetailPanel.bgHead.name:SetText(L["TABLE_NAME"])
    PlaceCol(pvpDetailPanel.bgHead.wins, BG_COLS.wins, bgHeadY, "RIGHT")
    pvpDetailPanel.bgHead.wins:SetText(L["TABLE_WINS"])
    for _, fs in pairs(pvpDetailPanel.bgHead) do fs:Show() end
    for i = 1, bgShown do
      local y = bgHeadY - 20 - 22 * (i - 1)
      local row = pvpDetailPanel.bgRows[i]
      PlaceCol(row.name, BG_COLS.name, y, "LEFT")
      row.name:SetText(sortedBg[i].name)
      PlaceCol(row.wins, BG_COLS.wins, y, "RIGHT")
      row.wins:SetText(tostring(sortedBg[i].wins))
      row.name:Show()
      row.wins:Show()
    end
    bottomDepth = bgHeadY - 20 - bgShown * 22
  else
    for _, fs in pairs(pvpDetailPanel.bgHead) do fs:Hide() end
    pvpDetailPanel.bgNoData:ClearAllPoints()
    pvpDetailPanel.bgNoData:SetPoint("TOPLEFT", 14, bgTop - 12)
    bottomDepth = bgTop - 12 - 20
  end
  for i = bgShown + 1, PVP_MAX_BG_ROWS do
    pvpDetailPanel.bgRows[i].name:Hide()
    pvpDetailPanel.bgRows[i].wins:Hide()
  end
  pvpDetailPanel.bgNoData:SetShown(bgShown == 0)

  local height = -bottomDepth + 12
  pvpDetailPanel:SetHeight(height)
  pvpDetailPanel:Show()
  return height
end

local function HidePvPDetail()
  if pvpDetailPanel then pvpDetailPanel:Hide() end
end

-- ----------------------------------------------------------------------------
-- DETAIL GOUFFRES : tableau par type (nom / nombre de fois / palier max).
-- ----------------------------------------------------------------------------
local delveDetailPanel
local DELVE_MAX_TYPE_ROWS = 8
local DELVE_COLS = { name = { x = 14, w = 440 }, count = { x = 454, w = 210 }, tier = { x = 664, w = 202 } }

local function BuildDelveDetail(content, top)
  if not delveDetailPanel then
    delveDetailPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    UI.SkinFrame(delveDetailPanel, ACCENT, UI.C.PANEL)
    delveDetailPanel.title = delveDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    delveDetailPanel.title:SetPoint("TOPLEFT", 14, -12)
    delveDetailPanel.title:SetText(L["DELVE_TYPES_TITLE"])
    delveDetailPanel.head = {}
    for key in pairs(DELVE_COLS) do
      delveDetailPanel.head[key] = delveDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    end
    delveDetailPanel.rows = {}
    for i = 1, DELVE_MAX_TYPE_ROWS do
      local row = {}
      for key in pairs(DELVE_COLS) do row[key] = delveDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") end
      delveDetailPanel.rows[i] = row
    end
    delveDetailPanel.noData = delveDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    delveDetailPanel.noData:SetPoint("TOPLEFT", 14, -38)
    delveDetailPanel.noData:SetText(L["DELVE_TYPES_NO_DATA"])
  end

  delveDetailPanel:ClearAllPoints()
  delveDetailPanel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
  delveDetailPanel:SetWidth(W - 60)

  local rec = (view.char ~= "__account__") and StatsDB[view.char]
  local types = rec and rec.delveTypes
  local sorted = {}
  if types then
    for name, entry in pairs(types) do
      sorted[#sorted + 1] = { name = name, count = entry.count, tier = entry.highestTier }
    end
    table.sort(sorted, function(a, b) return (a.count or 0) > (b.count or 0) end)
  end
  local shown = math.min(#sorted, DELVE_MAX_TYPE_ROWS)

  local headY = -38
  PlaceCol(delveDetailPanel.head.name, DELVE_COLS.name, headY, "LEFT")
  delveDetailPanel.head.name:SetText(L["TABLE_NAME"])
  PlaceCol(delveDetailPanel.head.count, DELVE_COLS.count, headY, "RIGHT")
  delveDetailPanel.head.count:SetText(L["TABLE_COUNT"])
  PlaceCol(delveDetailPanel.head.tier, DELVE_COLS.tier, headY, "RIGHT")
  delveDetailPanel.head.tier:SetText(L["DELVES_TIER"])
  for _, fs in pairs(delveDetailPanel.head) do fs:SetShown(shown > 0) end

  for i = 1, shown do
    local y = headY - 20 - 22 * (i - 1)
    local row = delveDetailPanel.rows[i]
    PlaceCol(row.name, DELVE_COLS.name, y, "LEFT")
    row.name:SetText(sorted[i].name)
    PlaceCol(row.count, DELVE_COLS.count, y, "RIGHT")
    row.count:SetText(tostring(sorted[i].count or 0))
    PlaceCol(row.tier, DELVE_COLS.tier, y, "RIGHT")
    row.tier:SetText(UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. tostring(sorted[i].tier or 0) .. "|r")
    for _, fs in pairs(row) do fs:Show() end
  end
  for i = shown + 1, DELVE_MAX_TYPE_ROWS do
    for _, fs in pairs(delveDetailPanel.rows[i]) do fs:Hide() end
  end
  delveDetailPanel.noData:SetShown(shown == 0)

  local height = (shown == 0) and 60 or (-(headY - 20 - shown * 22) + 12)
  delveDetailPanel:SetHeight(height)
  delveDetailPanel:Show()
  return height
end

local function HideDelveDetail()
  if delveDetailPanel then delveDetailPanel:Hide() end
end

-- ----------------------------------------------------------------------------
-- DETAIL TOURMENT : tableau par donjon (nom / nombre de fois / echelon max),
-- distinct de la tour Torghast/Ombreterre (tuile resume plus haut) malgre le
-- meme mot "Tourment" pour les deux systemes.
-- ----------------------------------------------------------------------------
local torghastDetailPanel
local TORGHAST_MAX_TYPE_ROWS = 10
local TORGHAST_COLS = {
  name = { x = 14, w = 260 },
  count = { x = 274, w = 90 },
  echelon = { x = 364, w = 90 },
  achievement = { x = 484, w = 382 },
}

local function BuildTorghastDetail(content, top)
  if not torghastDetailPanel then
    torghastDetailPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    UI.SkinFrame(torghastDetailPanel, ACCENT, UI.C.PANEL)
    torghastDetailPanel.title = torghastDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    torghastDetailPanel.title:SetPoint("TOPLEFT", 14, -12)
    torghastDetailPanel.title:SetText(L["TORGHAST_TYPES_TITLE"])
    torghastDetailPanel.head = {}
    for key in pairs(TORGHAST_COLS) do
      torghastDetailPanel.head[key] = torghastDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    end
    torghastDetailPanel.rows = {}
    for i = 1, TORGHAST_MAX_TYPE_ROWS do
      local row = {}
      for key in pairs(TORGHAST_COLS) do row[key] = torghastDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") end
      row.achievement:SetJustifyH("LEFT")
      row.achievement:SetWordWrap(false)
      -- Zone invisible superposee a la colonne "echelon max" : la FontString
      -- affiche deja le lien colore (texte), ce bouton transparent lui donne
      -- l'infobulle native du haut fait au survol et l'ouvre au clic - une
      -- FontString seule n'est pas interactive en WoW.
      local hit = CreateFrame("Button", nil, torghastDetailPanel)
      hit:SetScript("OnEnter", function(self)
        if not self.achievementID then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetAchievementByID(self.achievementID)
        GameTooltip:Show()
      end)
      hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
      hit:SetScript("OnMouseUp", function(self)
        if not self.achievementID then return end
        pcall(function()
          if not AchievementFrame and AchievementFrame_LoadUI then AchievementFrame_LoadUI() end
          if AchievementFrame_SelectAchievement then AchievementFrame_SelectAchievement(self.achievementID) end
          if ShowUIPanel and AchievementFrame then ShowUIPanel(AchievementFrame) end
        end)
      end)
      row.hit = hit
      torghastDetailPanel.rows[i] = row
    end
    torghastDetailPanel.noData = torghastDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    torghastDetailPanel.noData:SetPoint("TOPLEFT", 14, -38)
    torghastDetailPanel.noData:SetText(L["TORGHAST_TYPES_NO_DATA"])
  end

  torghastDetailPanel:ClearAllPoints()
  torghastDetailPanel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
  torghastDetailPanel:SetWidth(W - 60)

  local rec = (view.char ~= "__account__") and StatsDB[view.char]
  local types = rec and rec.torghastByDungeon
  local sorted = {}
  if types then
    for name, entry in pairs(types) do
      sorted[#sorted + 1] = { name = name, count = entry.count, echelon = entry.highestEchelon, achievementID = entry.highestAchievementID, achievementName = entry.highestAchievementName }
    end
    table.sort(sorted, function(a, b) return (a.count or 0) > (b.count or 0) end)
  end
  local shown = math.min(#sorted, TORGHAST_MAX_TYPE_ROWS)

  local headY = -38
  PlaceCol(torghastDetailPanel.head.name, TORGHAST_COLS.name, headY, "LEFT")
  torghastDetailPanel.head.name:SetText(L["TABLE_NAME"])
  PlaceCol(torghastDetailPanel.head.count, TORGHAST_COLS.count, headY, "RIGHT")
  torghastDetailPanel.head.count:SetText(L["TABLE_COUNT"])
  PlaceCol(torghastDetailPanel.head.echelon, TORGHAST_COLS.echelon, headY, "RIGHT")
  torghastDetailPanel.head.echelon:SetText(L["TABLE_ECHELON"])
  PlaceCol(torghastDetailPanel.head.achievement, TORGHAST_COLS.achievement, headY, "LEFT")
  torghastDetailPanel.head.achievement:SetText(L["TABLE_ACHIEVEMENT"])
  for _, fs in pairs(torghastDetailPanel.head) do fs:SetShown(shown > 0) end

  for i = 1, shown do
    local y = headY - 20 - 22 * (i - 1)
    local row = torghastDetailPanel.rows[i]
    PlaceCol(row.name, TORGHAST_COLS.name, y, "LEFT")
    row.name:SetText(sorted[i].name)
    PlaceCol(row.count, TORGHAST_COLS.count, y, "RIGHT")
    row.count:SetText(tostring(sorted[i].count or 0))
    PlaceCol(row.echelon, TORGHAST_COLS.echelon, y, "RIGHT")
    row.echelon:SetText(UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. tostring(sorted[i].echelon or 0) .. "|r")
    PlaceCol(row.achievement, TORGHAST_COLS.achievement, y, "LEFT")
    local achID = sorted[i].achievementID
    local achName = sorted[i].achievementName
    if achName then
      row.achievement:SetText(UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. achName .. "|r")
    else
      row.achievement:SetText("")
    end
    row.hit:ClearAllPoints()
    row.hit:SetPoint("TOPLEFT", TORGHAST_COLS.echelon.x, y)
    row.hit:SetSize((TORGHAST_COLS.achievement.x + TORGHAST_COLS.achievement.w) - TORGHAST_COLS.echelon.x, 20)
    row.hit.achievementID = achID
    for _, fs in pairs(row) do fs:Show() end
  end
  for i = shown + 1, TORGHAST_MAX_TYPE_ROWS do
    for _, fs in pairs(torghastDetailPanel.rows[i]) do fs:Hide() end
  end
  torghastDetailPanel.noData:SetShown(shown == 0)

  local height = (shown == 0) and 60 or (-(headY - 20 - shown * 22) + 12)
  torghastDetailPanel:SetHeight(height)
  torghastDetailPanel:Show()
  return height
end

local function HideTorghastDetail()
  if torghastDetailPanel then torghastDetailPanel:Hide() end
end

-- ----------------------------------------------------------------------------
-- DETAIL REPUTATIONS : tableau par faction (nom / systeme / progression).
-- ----------------------------------------------------------------------------
local reputationDetailPanel
local REP_MAX_ROWS = 10
local REP_COLS = { name = { x = 14, w = 440 }, system = { x = 454, w = 210 }, progress = { x = 664, w = 202 } }

local function RepSystemLabel(info)
  if info.system == "renown" then return L["REP_RENOWN"] .. " " .. tostring(info.rank or 0)
  elseif info.system == "friendship" or info.system == "classic" then return info.label or ""
  end
  return ""
end

local function BuildReputationDetail(content, top)
  if not reputationDetailPanel then
    reputationDetailPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    UI.SkinFrame(reputationDetailPanel, ACCENT, UI.C.PANEL)
    reputationDetailPanel.title = reputationDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reputationDetailPanel.title:SetPoint("TOPLEFT", 14, -12)
    reputationDetailPanel.title:SetText(L["REP_TYPES_TITLE"])
    reputationDetailPanel.head = {}
    for key in pairs(REP_COLS) do
      reputationDetailPanel.head[key] = reputationDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    end
    reputationDetailPanel.rows = {}
    for i = 1, REP_MAX_ROWS do
      local row = {}
      for key in pairs(REP_COLS) do row[key] = reputationDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") end
      reputationDetailPanel.rows[i] = row
    end
    reputationDetailPanel.noData = reputationDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    reputationDetailPanel.noData:SetPoint("TOPLEFT", 14, -38)
    reputationDetailPanel.noData:SetText(L["REP_NO_DATA"])
  end

  reputationDetailPanel:ClearAllPoints()
  reputationDetailPanel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
  reputationDetailPanel:SetWidth(W - 60)

  local rec = (view.char ~= "__account__") and StatsDB[view.char]
  local list = rec and rec.reputations and rec.reputations.list
  -- Uniquement les factions avec une progression RECENTE constatee
  -- (lastGainAt present) - pas un tri par % avec repli, un vrai filtre : les
  -- factions jamais touchees depuis que ce suivi existe n'apparaissent pas
  -- du tout (demande explicite : "uniquement les 10 dernieres reputations
  -- sur lesquelles le joueur a fait progresser la completion recemment").
  local sorted = {}
  if list then
    for _, info in ipairs(list) do
      if not info.maxed and info.lastGainAt then sorted[#sorted + 1] = info end
    end
    table.sort(sorted, function(a, b) return a.lastGainAt > b.lastGainAt end)
  end
  local shown = math.min(#sorted, REP_MAX_ROWS)
  reputationDetailPanel.noData:SetText(L["REP_NO_RECENT_DATA"])

  local headY = -38
  PlaceCol(reputationDetailPanel.head.name, REP_COLS.name, headY, "LEFT")
  reputationDetailPanel.head.name:SetText(L["TABLE_NAME"])
  PlaceCol(reputationDetailPanel.head.system, REP_COLS.system, headY, "LEFT")
  reputationDetailPanel.head.system:SetText(L["TABLE_SYSTEM"])
  PlaceCol(reputationDetailPanel.head.progress, REP_COLS.progress, headY, "RIGHT")
  reputationDetailPanel.head.progress:SetText(L["TABLE_PROGRESS"])
  for _, fs in pairs(reputationDetailPanel.head) do fs:SetShown(shown > 0) end

  for i = 1, shown do
    local y = headY - 20 - 22 * (i - 1)
    local row = reputationDetailPanel.rows[i]
    local info = sorted[i]
    PlaceCol(row.name, REP_COLS.name, y, "LEFT")
    row.name:SetText(info.name or "?")
    PlaceCol(row.system, REP_COLS.system, y, "LEFT")
    row.system:SetText(RepSystemLabel(info))
    PlaceCol(row.progress, REP_COLS.progress, y, "RIGHT")
    local pctText = tostring(math.floor((info.pct or 0) * 100 + 0.5)) .. "%"
    row.progress:SetText(UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. pctText .. "|r")
    for _, fs in pairs(row) do fs:Show() end
  end
  for i = shown + 1, REP_MAX_ROWS do
    for _, fs in pairs(reputationDetailPanel.rows[i]) do fs:Hide() end
  end
  reputationDetailPanel.noData:SetShown(shown == 0)

  local height = (shown == 0) and 60 or (-(headY - 20 - shown * 22) + 12)
  reputationDetailPanel:SetHeight(height)
  reputationDetailPanel:Show()
  return height
end

local function HideReputationDetail()
  if reputationDetailPanel then reputationDetailPanel:Hide() end
end

-- ----------------------------------------------------------------------------
-- DETAIL METIERS : tableau des metiers les plus RECEMMENT progresses (meme
-- principe strict que reputation - un vrai filtre sur lastGainAt, pas un
-- tri par % avec repli, et exclut les metiers deja a 100%).
-- ----------------------------------------------------------------------------
local professionDetailPanel
local PROF_MAX_ROWS = 10
local PROF_COLS = { name = { x = 14, w = 440 }, level = { x = 454, w = 210 }, progress = { x = 664, w = 202 } }

local function BuildProfessionDetail(content, top)
  if not professionDetailPanel then
    professionDetailPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    UI.SkinFrame(professionDetailPanel, ACCENT, UI.C.PANEL)
    professionDetailPanel.title = professionDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    professionDetailPanel.title:SetPoint("TOPLEFT", 14, -12)
    professionDetailPanel.title:SetText(L["PROF_TYPES_TITLE"])
    professionDetailPanel.head = {}
    for key in pairs(PROF_COLS) do
      professionDetailPanel.head[key] = professionDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    end
    professionDetailPanel.rows = {}
    for i = 1, PROF_MAX_ROWS do
      local row = {}
      for key in pairs(PROF_COLS) do row[key] = professionDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") end
      professionDetailPanel.rows[i] = row
    end
    professionDetailPanel.noData = professionDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    professionDetailPanel.noData:SetPoint("TOPLEFT", 14, -38)
    professionDetailPanel.noData:SetText(L["PROF_NO_RECENT_DATA"])
  end

  professionDetailPanel:ClearAllPoints()
  professionDetailPanel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
  professionDetailPanel:SetWidth(W - 60)

  local rec = (view.char ~= "__account__") and StatsDB[view.char]
  local list = rec and rec.professionsNative and rec.professionsNative.list
  local sorted = {}
  if list then
    for _, info in ipairs(list) do
      if not info.maxed and info.lastGainAt then sorted[#sorted + 1] = info end
    end
    table.sort(sorted, function(a, b) return a.lastGainAt > b.lastGainAt end)
  end
  local shown = math.min(#sorted, PROF_MAX_ROWS)

  local headY = -38
  PlaceCol(professionDetailPanel.head.name, PROF_COLS.name, headY, "LEFT")
  professionDetailPanel.head.name:SetText(L["TABLE_NAME"])
  PlaceCol(professionDetailPanel.head.level, PROF_COLS.level, headY, "LEFT")
  professionDetailPanel.head.level:SetText(L["TABLE_LEVEL"])
  PlaceCol(professionDetailPanel.head.progress, PROF_COLS.progress, headY, "RIGHT")
  professionDetailPanel.head.progress:SetText(L["TABLE_PROGRESS"])
  for _, fs in pairs(professionDetailPanel.head) do fs:SetShown(shown > 0) end

  for i = 1, shown do
    local y = headY - 20 - 22 * (i - 1)
    local row = professionDetailPanel.rows[i]
    local info = sorted[i]
    PlaceCol(row.name, PROF_COLS.name, y, "LEFT")
    row.name:SetText(info.name or "?")
    PlaceCol(row.level, PROF_COLS.level, y, "LEFT")
    row.level:SetText(tostring(info.cur or 0) .. " / " .. tostring(info.max or 0))
    PlaceCol(row.progress, PROF_COLS.progress, y, "RIGHT")
    -- Plafonne a 100% (jamais au-dela), meme si cur venait a depasser max.
    local pctText = tostring(math.min(100, math.floor((info.pct or 0) * 100 + 0.5))) .. "%"
    row.progress:SetText(UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. pctText .. "|r")
    for _, fs in pairs(row) do fs:Show() end
  end
  for i = shown + 1, PROF_MAX_ROWS do
    for _, fs in pairs(professionDetailPanel.rows[i]) do fs:Hide() end
  end
  professionDetailPanel.noData:SetShown(shown == 0)

  local height = (shown == 0) and 60 or (-(headY - 20 - shown * 22) + 12)
  professionDetailPanel:SetHeight(height)
  professionDetailPanel:Show()
  return height
end

local function HideProfessionDetail()
  if professionDetailPanel then professionDetailPanel:Hide() end
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
  local leftmostBtn
  for _, g in ipairs(SX.GRANULARITIES) do
    local b = d.granButtons[g]
    b:ClearAllPoints()
    b:SetPoint("TOPRIGHT", content, "TOPRIGHT", -gx, -30)
    gx = gx + 64
    leftmostBtn = b
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
  -- Ancre AU BOUT DE LA RANGEE (le dernier bouton positionne = le plus a
  -- gauche, gx croissant) - pas SX.GRANULARITIES[1] ("jour", le plus a
  -- DROITE) : ce dernier chevauchait "Semaine" avec "Stats par :", le
  -- libelle debordant largement a gauche de son ancre (constat utilisateur,
  -- capture d'ecran en jeu - texte "Semaine"/"Stats par :" mele).
  d.granLabel:SetText(L["GRANULARITY_LABEL"])
  d.granLabel:ClearAllPoints()
  d.granLabel:SetPoint("RIGHT", leftmostBtn, "LEFT", -8, 0)

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

-- ============================================================================
-- SUPERPOSITION DE TOUTES LES METRIQUES ("Superposer les courbes") : meme
-- chrome que BuildDetail (retour, granularite Jour/Semaine/Mois) mais un
-- graphique multi-courbes (RenderOverlayChart) a la place du graphique/
-- min-max-moyenne d'une seule metrique, plus une legende couleur.
-- ============================================================================
local overlayWidgets = {}

local function BuildOverlayDetail(content)
  local d = overlayWidgets
  if not d.built then
    d.back = UI.MakeButton(content, 160, 22, L["DETAIL_BACK"])
    d.back:SetPoint("TOPLEFT", 0, 0)
    d.back:SetScript("OnClick", function() view.detailMetric = nil; SX.RefreshDashboard() end)

    d.title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    d.title:SetPoint("TOPLEFT", 0, -34)
    d.title:SetText(L["OVERLAY_TITLE"])

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

    d.legendHint = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d.legendHint:SetPoint("TOPLEFT", d.chart, "BOTTOMLEFT", 0, -14)
    d.legendHint:SetText(L["OVERLAY_LEGEND_HINT"])

    d.legendButtons = {}

    d.built = true
  end

  -- Granularite INDEPENDANTE de detailGranularity (single-metrique) :
  -- demarre en "semaine", pas "jour" (cf. view.overlayGranularity). Meme
  -- verrouillage granularite/periode que BuildDetail.
  local lockMap = { day = { day = false, week = view.period == "day", month = true },
                     week = { day = false, week = false, month = view.period == "week" },
                     month = { day = true, week = false, month = false },
                     year = { day = true, week = true, month = false } }
  local locks = lockMap[view.period] or {}
  local gx = 0
  local leftmostBtn
  for _, g in ipairs(SX.GRANULARITIES) do
    local b = d.granButtons[g]
    b:ClearAllPoints()
    b:SetPoint("TOPRIGHT", content, "TOPRIGHT", -gx, -30)
    gx = gx + 64
    leftmostBtn = b
    local locked = locks[g]
    if locked and view.overlayGranularity == g then view.overlayGranularity = "week" end
    b:SetEnabled(not locked)
    local gLabel = L["GRANULARITY_" .. g:upper()]
    local labelText
    if locked then
      labelText = "|cFF555555" .. gLabel .. "|r"
    elseif view.overlayGranularity == g then
      labelText = UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. gLabel .. "|r"
    else
      labelText = gLabel
    end
    b._label:SetText(labelText)
    b:SetScript("OnClick", function() if not locked then view.overlayGranularity = g; SX.RefreshDashboard() end end)
  end
  -- Ancre AU BOUT DE LA RANGEE (le dernier bouton positionne = le plus a
  -- gauche, gx croissant) - pas SX.GRANULARITIES[1] ("jour", le plus a
  -- DROITE) : ce dernier chevauchait "Semaine" avec "Stats par :", le
  -- libelle debordant largement a gauche de son ancre (constat utilisateur,
  -- capture d'ecran en jeu - texte "Semaine"/"Stats par :" mele).
  d.granLabel:SetText(L["GRANULARITY_LABEL"])
  d.granLabel:ClearAllPoints()
  d.granLabel:SetPoint("RIGHT", leftmostBtn, "LEFT", -8, 0)

  local bucketCount = (view.overlayGranularity == "day") and 30 or 12
  local seriesList = {}
  for _, metric in ipairs(CARD_METRICS) do
    local raw = SX.BuildSeries(view.char, metric, view.overlayGranularity, bucketCount)
    seriesList[#seriesList + 1] = { key = metric, color = OVERLAY_COLORS[metric] or ACCENT, points = NormalizeSeries(raw) }
  end

  -- Legende cliquable construite sur la liste COMPLETE (pas filtree) pour
  -- pouvoir re-cocher une courbe cachee ; le graphique lui-meme n'utilise
  -- que les courbes cochees (visibleSeries).
  BuildLegendToggles(content, d.legendButtons, CARD_METRICS, function(k) return OVERLAY_COLORS[k] end, view.overlayEnabledMetrics, -(66 + 300 + 14 + 16))
  local visibleSeries = FilterEnabledSeries(seriesList, view.overlayEnabledMetrics)

  local fmtFn = function(point)
    local first = point.seriesList[1]
    local p1 = first and first.points[point.index]
    local lines = { p1 and p1.label or "" }
    for _, s in ipairs(point.seriesList) do
      local p = s.points[point.index]
      if p then
        lines[#lines + 1] = UI.Hex(s.color[1], s.color[2], s.color[3]) .. CardLabel(s.key) .. ": " .. fmtMetric(s.key, p.actual) .. "|r"
      end
    end
    return table.concat(lines, "\n")
  end
  RenderOverlayChart(d.chartInner, visibleSeries, true, fmtFn, view.overlayGranularity)

  for _, w in pairs(d) do if type(w) == "table" and w.Show then w:Show() end end
  for g, b in pairs(d.granButtons) do b:Show() end
end

local function HideOverlayDetail()
  local d = overlayWidgets
  if not d.built then return end
  for _, w in pairs(d) do if type(w) == "table" and w.Hide then w:Hide() end end
  for g, b in pairs(d.granButtons) do b:Hide() end
  for k, b in pairs(d.legendButtons) do b:Hide() end
end

-- ============================================================================
-- GRAPHIQUE PVP DEDIE ("Graphique PVP" du panneau PVP) : adversaires tues +
-- champs de bataille joues/gagnes + arenes jouees/gagnees, toujours
-- superposes (PVP_CHART_METRICS). Meme chrome que BuildOverlayDetail, mais
-- sa propre granularite (view.pvpChartGranularity) et pas de verrouillage
-- lie a view.period : c'est une vue dediee, pas imbriquee dans les cartes.
-- ============================================================================
local pvpChartWidgets = {}

local function BuildPvPChartDetail(content)
  local d = pvpChartWidgets
  if not d.built then
    d.back = UI.MakeButton(content, 160, 22, L["DETAIL_BACK"])
    d.back:SetPoint("TOPLEFT", 0, 0)
    d.back:SetScript("OnClick", function() view.detailMetric = nil; SX.RefreshDashboard() end)

    d.title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    d.title:SetPoint("TOPLEFT", 0, -34)
    d.title:SetText(L["PVP_CHART_TITLE"])

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

    d.legendHint = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d.legendHint:SetPoint("TOPLEFT", d.chart, "BOTTOMLEFT", 0, -14)
    d.legendHint:SetText(L["OVERLAY_LEGEND_HINT"])

    d.legendButtons = {}

    d.built = true
  end

  local gx = 0
  local leftmostBtn
  for _, g in ipairs(SX.GRANULARITIES) do
    local b = d.granButtons[g]
    b:ClearAllPoints()
    b:SetPoint("TOPRIGHT", content, "TOPRIGHT", -gx, -30)
    gx = gx + 64
    leftmostBtn = b
    local gLabel = L["GRANULARITY_" .. g:upper()]
    b._label:SetText(view.pvpChartGranularity == g
      and (UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. gLabel .. "|r") or gLabel)
    b:SetScript("OnClick", function() view.pvpChartGranularity = g; SX.RefreshDashboard() end)
  end
  -- Ancre au bout de la rangee (le plus a gauche), pas [1] ("jour", le plus
  -- a droite) - meme correctif que BuildDetail/BuildOverlayDetail.
  d.granLabel:SetText(L["GRANULARITY_LABEL"])
  d.granLabel:ClearAllPoints()
  d.granLabel:SetPoint("RIGHT", leftmostBtn, "LEFT", -8, 0)

  local bucketCount = (view.pvpChartGranularity == "day") and 30 or 12
  local seriesList = {}
  for _, metric in ipairs(PVP_CHART_METRICS) do
    local raw = SX.BuildSeries(view.char, metric, view.pvpChartGranularity, bucketCount)
    seriesList[#seriesList + 1] = { key = metric, color = PVP_OVERLAY_COLORS[metric] or ACCENT, points = NormalizeSeries(raw) }
  end

  BuildLegendToggles(content, d.legendButtons, PVP_CHART_METRICS, function(k) return PVP_OVERLAY_COLORS[k] end, view.pvpEnabledMetrics, -(66 + 300 + 14 + 16))
  local visibleSeries = FilterEnabledSeries(seriesList, view.pvpEnabledMetrics)

  local fmtFn = function(point)
    local first = point.seriesList[1]
    local p1 = first and first.points[point.index]
    local lines = { p1 and p1.label or "" }
    for _, s in ipairs(point.seriesList) do
      local p = s.points[point.index]
      if p then
        lines[#lines + 1] = UI.Hex(s.color[1], s.color[2], s.color[3]) .. CardLabel(s.key) .. ": " .. fmtMetric(s.key, p.actual) .. "|r"
      end
    end
    return table.concat(lines, "\n")
  end
  RenderOverlayChart(d.chartInner, visibleSeries, true, fmtFn, view.pvpChartGranularity)

  for _, w in pairs(d) do if type(w) == "table" and w.Show then w:Show() end end
  for g, b in pairs(d.granButtons) do b:Show() end
end

local function HidePvPChartDetail()
  local d = pvpChartWidgets
  if not d.built then return end
  for _, w in pairs(d) do if type(w) == "table" and w.Hide then w:Hide() end end
  for g, b in pairs(d.granButtons) do b:Hide() end
  for k, b in pairs(d.legendButtons) do b:Hide() end
end

local function HideOverview()
  for _, card in pairs(cards) do card:Hide() end
  HideSummaryTiles()
  HidePvPDetail()
  HideDelveDetail()
  HideTorghastDetail()
  HideReputationDetail()
  HideProfessionDetail()
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

  -- Superposition de toutes les metriques : meme ligne que Comparer, cale a
  -- droite (espace libre confirme par lecture du code, PAS teste en jeu -
  -- A VERIFIER : chevauchement eventuel avec Comparer/Cumule sur une petite
  -- resolution ou une langue au texte plus long).
  mainFrame.overlayBtn = UI.MakeButton(mainFrame, 220, 22, L["OVERLAY_BUTTON"])
  mainFrame.overlayBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -14, -94)
  mainFrame.overlayBtn:SetScript("OnClick", function()
    view.detailMetric = (view.detailMetric == "__overlay__") and nil or "__overlay__"
    SX.RefreshDashboard()
  end)

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

  do
    local bannerText = UI.CharBannerText(view.char == "__account__" and nil or SX.CharBannerData(view.char))
    local rec = (view.char ~= "__account__") and StatsDB[view.char]
    local pts = rec and rec.achievementPoints
    if pts then
      -- Icone officielle des hauts faits (texture native, meme icone que
      -- l'onglet Hauts faits/le bouton du menu principal) devant le total.
      bannerText = bannerText .. "  |cFF888899-|r |TInterface\\Icons\\Achievement_General:14:14:0:-1|t "
        .. UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. tostring(pts) .. "|r " .. L["ACHIEV_POINTS_SUFFIX"]
    end
    mainFrame.banner:SetText(bannerText)
  end
  if mainFrame.charDD.Refresh then mainFrame.charDD.Refresh() end
  if mainFrame.compareDD.Refresh then mainFrame.compareDD.Refresh() end
  mainFrame.compareDD:SetShown(view.compareChar ~= nil)
  mainFrame.cumulativeCB:SetShown(view.compareChar ~= nil)
  mainFrame.compareBtn._label:SetText(view.compareChar and L["COMPARE_STOP"] or L["COMPARE_BUTTON"])
  mainFrame.overlayBtn._label:SetText(view.detailMetric == "__overlay__"
    and (UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. L["OVERLAY_BUTTON"] .. "|r") or L["OVERLAY_BUTTON"])

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

  if view.detailMetric == "__overlay__" then
    HideOverview()
    HideDetail()
    HidePvPChartDetail()
    BuildOverlayDetail(mainFrame.content)
    mainFrame.content:SetHeight(420)
  elseif view.detailMetric == "__pvp__" then
    HideOverview()
    HideDetail()
    HideOverlayDetail()
    BuildPvPChartDetail(mainFrame.content)
    mainFrame.content:SetHeight(420)
  elseif view.detailMetric then
    HideOverview()
    HideOverlayDetail()
    HidePvPChartDetail()
    BuildDetail(mainFrame.content, view.detailMetric)
    mainFrame.content:SetHeight(420)
  else
    HideDetail()
    HideOverlayDetail()
    HidePvPChartDetail()
    BuildOverview(mainFrame.content)
    local gridRows = math.ceil(#CARD_METRICS / 2)
    local gridDepth = gridRows * 190 + (gridRows - 1) * 16 + 10
    local tilesHeight = BuildSummaryTiles(mainFrame.content, -(gridDepth + 6))
    local pvpHeight = BuildPvPDetail(mainFrame.content, -(gridDepth + 6 + tilesHeight + 16))
    local delveHeight = BuildDelveDetail(mainFrame.content, -(gridDepth + 6 + tilesHeight + 16 + pvpHeight + 16))
    local torghastDetailHeight = BuildTorghastDetail(mainFrame.content, -(gridDepth + 6 + tilesHeight + 16 + pvpHeight + 16 + delveHeight + 16))
    local reputationDetailHeight = BuildReputationDetail(mainFrame.content, -(gridDepth + 6 + tilesHeight + 16 + pvpHeight + 16 + delveHeight + 16 + torghastDetailHeight + 16))
    local professionDetailHeight = BuildProfessionDetail(mainFrame.content, -(gridDepth + 6 + tilesHeight + 16 + pvpHeight + 16 + delveHeight + 16 + torghastDetailHeight + 16 + reputationDetailHeight + 16))
    mainFrame.content:SetHeight(gridDepth + 16 + tilesHeight + 16 + pvpHeight + 16 + delveHeight + 16 + torghastDetailHeight + 16 + reputationDetailHeight + 16 + professionDetailHeight + 10)
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
