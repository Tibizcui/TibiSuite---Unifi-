-- ================================================================
--  SkillTracker  -  UI.lua
--  Panneau principal (liinnere emeraude #00FF98), barres de progression
--  regroupees par metier puis par extension, tooltip enrichi multi-perso,
--  panneau recapitulatif du compte, bouton minimap, options, export/import.
--
--  Reutilise integralement les helpers de TibiMidnightUI (_G.TibiMidnight) :
--  SkinFrame, SetLisere, FlatBackdrop, MakeButton, CreateOptionsPanel, la
--  palette UI.C, Hex, Normalize. Aucune dependance externe supplementaire.
-- ================================================================

local ADDON, ST = ...
local L  = ST.L
local UI = _G.TibiMidnight   -- garanti : TibiMidnightUI.lua se charge avant

-- Raccourcis couleur
local ACC = ST.COLOR                          -- emeraude #00FF98
local function accHex() return UI.Hex(ACC[1], ACC[2], ACC[3]) end

-- Couleur de classe d'un perso (jeton "MAGE", "WARRIOR"...). Repli gris clair.
local function ClassColor(classToken)
  if classToken then
    local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classToken))
      or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken])
    if c then return { c.r, c.g, c.b } end
  end
  return { 0.85, 0.85, 0.90 }
end

-- ================================================================
-- BARRE DE PROGRESSION REUTILISABLE
-- ================================================================
local function MakeBar(parent, w, h)
  local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  bar:SetSize(w, h)
  bar:SetBackdrop(UI.FlatBackdrop())
  bar:SetBackdropColor(0.03, 0.05, 0.05, 0.95)
  bar:SetBackdropBorderColor(0, 0, 0, 1)

  local fill = bar:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMLEFT", 1, 1)
  fill:SetColorTexture(ACC[1], ACC[2], ACC[3], 1)
  bar._fill = fill

  local txt = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  txt:SetPoint("CENTER", 0, 0)
  bar._txt = txt

  -- Surbrillance au survol (visible seulement quand la barre est cliquable)
  local hl = bar:CreateTexture(nil, "OVERLAY")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  hl:Hide()
  bar._hl = hl

  bar._w = w
  return bar
end

-- Applique cur/max a une barre. 100% : emeraude pleine + libelle "au max".
-- En cours : emeraude attenuee. Jamais de division par zero.
local function SetBar(bar, cur, max, label)
  local pct = ST.Percent(cur, max)
  local usable = (bar._w - 2)
  local wfill = math.max(1, math.floor(usable * pct / 100 + 0.5))
  bar._fill:SetWidth(wfill)
  if pct >= 100 then
    bar._fill:SetColorTexture(ACC[1], ACC[2], ACC[3], 1.0)
    bar:SetBackdropBorderColor(ACC[1] * 0.9, ACC[2] * 0.9, ACC[3] * 0.9, 0.9)
  else
    bar._fill:SetColorTexture(ACC[1] * 0.55, ACC[2] * 0.55, ACC[3] * 0.55, 0.95)
    bar:SetBackdropBorderColor(0, 0, 0, 1)
  end
  local right = (pct >= 100)
    and ("|cFF00FF98" .. L.MAXED .. "|r")
    or (cur .. "/" .. max .. "  " .. pct .. "%")
  bar._txt:SetText((label and (label .. "   ") or "") .. right)
end

-- ================================================================
-- POOL DE LIGNES (evite les fuites : on reutilise, on ne recree jamais)
-- ================================================================
local mainFrame, content
local pools = { header = {}, bar = {}, note = {}, tab = {} }
local used  = { header = {}, bar = {}, note = {}, tab = {} }

local function resetPools()
  for kind, list in pairs(used) do
    for _, w in ipairs(list) do w:Hide() end
    pools[kind] = pools[kind]
    -- renvoyer au pool
    for _, w in ipairs(list) do pools[kind][#pools[kind] + 1] = w end
    used[kind] = {}
  end
end

-- Ligne "titre de section / metier" cliquable (pour le tooltip enrichi).
local function acquireHeaderRow()
  local w = table.remove(pools.header)
  if not w then
    w = UI.MakeButton(content, 300, 22, "")
    w._label:ClearAllPoints()
    w._label:SetPoint("LEFT", 8, 0)
    w._label:SetPoint("RIGHT", -8, 0)
    w._label:SetJustifyH("LEFT")
  end
  used.header[#used.header + 1] = w
  w:SetScript("OnEnter", nil)
  w:SetScript("OnLeave", nil)
  w:SetScript("OnClick", nil)   -- une ligne recyclee ne garde pas un ancien clic
  w:Show()
  return w
end

local function acquireBar()
  local w = table.remove(pools.bar)
  if not w then w = MakeBar(content, 300, 16) end
  -- Reinitialise l'interactivite (les barres sont mutualisees).
  w:EnableMouse(false)
  w:SetScript("OnMouseUp", nil)
  w:SetScript("OnEnter", nil)
  w:SetScript("OnLeave", nil)
  if w._hl then w._hl:Hide() end
  used.bar[#used.bar + 1] = w
  w:Show()
  return w
end

-- Onglet d'extension du selecteur (bouton colore + accent + sigle).
local function acquireTab()
  local w = table.remove(pools.tab)
  if not w then
    w = CreateFrame("Button", nil, content, "BackdropTemplate")
    w:SetBackdrop(UI.FlatBackdrop())
    local acc = w:CreateTexture(nil, "OVERLAY")
    acc:SetPoint("TOPLEFT", 1, -1)
    acc:SetPoint("BOTTOMLEFT", 1, 1)
    acc:SetWidth(3)
    acc:SetTexture("Interface\\Buttons\\WHITE8X8")
    w._acc = acc
    local fs = w:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER", 0, 0)
    w._label = fs
  end
  used.tab[#used.tab + 1] = w
  w:SetScript("OnEnter", nil)
  w:SetScript("OnLeave", nil)
  w:SetScript("OnClick", nil)
  w:Show()
  return w
end

local function acquireNote(fontObj)
  local w = table.remove(pools.note)
  if not w then
    w = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    w:SetJustifyH("LEFT")
  end
  w:SetFontObject(fontObj or "GameFontDisableSmall")
  used.note[#used.note + 1] = w
  w:Show()
  return w
end

-- ================================================================
-- CONSTRUCTION DU CONTENU (appelee a chaque refresh)
-- ================================================================
local yTop = -6
local Y

local function line(h) Y = Y - h end

local function placeHeader(text, x)
  local w = acquireHeaderRow()
  w:ClearAllPoints()
  w:SetPoint("TOPLEFT", content, "TOPLEFT", (x or 4), Y)
  w:SetWidth(300 - (x or 4))
  w._label:SetText(text)
  line(24)
  return w
end

local function placeNote(text, indent)
  local w = acquireNote("GameFontDisableSmall")
  w:ClearAllPoints()
  w:SetPoint("TOPLEFT", content, "TOPLEFT", (indent or 8), Y)
  w:SetWidth(300 - (indent or 8))
  w:SetText(text)
  line((w:GetStringHeight() or 12) + 8)
  return w
end

local function placeBar(cur, max, label, indent, onClick)
  local w = acquireBar()
  local x = indent or 16
  w:ClearAllPoints()
  w:SetPoint("TOPLEFT", content, "TOPLEFT", x, Y)
  w:SetWidth(300 - x - 6)
  w._w = 300 - x - 6
  SetBar(w, cur, max, label)
  if onClick then
    w:EnableMouse(true)
    w:SetScript("OnMouseUp", function() onClick() end)
    w:SetScript("OnEnter", function(s)
      if s._hl then s._hl:Show() end
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
      GameTooltip:AddLine(L.OPEN_PROF_HINT, 0.8, 0.85, 0.9)
      GameTooltip:Show()
    end)
    w:SetScript("OnLeave", function(s)
      if s._hl then s._hl:Hide() end
      GameTooltip:Hide()
    end)
  end
  line(20)
  return w
end

-- Tri des paliers d'un metier par skillLineID croissant (ancien -> recent).
local function sortedLineIDs(prof)
  local ids = {}
  for id in pairs(prof.lines or {}) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

-- ================================================================
-- BASCULE DE VUE : Extension en cours / Toutes les extensions / Compte
-- ================================================================
local METIER_VIEWS = { "current", "all", "account" }
local function metierViewLabel(v)
  if v == "current" then return L.METIER_VIEW_CURRENT
  elseif v == "all" then return L.METIER_VIEW_ALL
  else return L.METIER_VIEW_ACCOUNT end
end

-- Largeur auto (mesuree au texte, meme principe que placeTodoChips) : ces 3
-- libelles sont trop longs pour un partage a largeur fixe sur les 300px du
-- panneau ("Toutes les extensions" deborderait un bouton de largeur fixe et
-- chevaucherait son voisin). Passe a la ligne si la largeur cumulee depasse
-- le panneau.
local function placeMetierViewSwitch()
  local sel = ST.settings.metierView or "current"
  local rowH, gap, maxW = 24, 4, 292
  local x, rowY = 4, Y
  for _, v in ipairs(METIER_VIEWS) do
    local tab = acquireTab()
    local text = metierViewLabel(v)
    local selected = (v == sel)
    tab._label:SetText(text)
    local w = math.min(maxW, math.max(60, (tab._label:GetStringWidth() or 60) + 20))
    if x + w > maxW + 4 and x > 4 then
      rowY = rowY - (rowH + gap)
      x = 4
    end
    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT", content, "TOPLEFT", x, rowY)
    tab:SetSize(w, rowH)
    if selected then
      tab:SetBackdropColor(ACC[1] * 0.30, ACC[2] * 0.30, ACC[3] * 0.30, 0.95)
      tab:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 1.0)
      tab._acc:SetVertexColor(ACC[1], ACC[2], ACC[3], 1.0)
      tab._label:SetText(accHex() .. text .. "|r")
    else
      tab:SetBackdropColor(0.05, 0.05, 0.06, 0.85)
      tab:SetBackdropBorderColor(0.25, 0.25, 0.28, 0.5)
      tab._acc:SetVertexColor(0.3, 0.3, 0.3, 0.4)
      tab._label:SetText("|cFF999999" .. text .. "|r")
    end
    tab:SetScript("OnClick", function()
      ST.settings.metierView = v
      ST.RefreshUI()
    end)
    x = x + w + gap
  end
  Y = rowY - (rowH + gap)
end

-- Detail "X <extension>, Y <extension>..." quand le total de connaissances
-- non depensees vient de PLUSIEURS extensions a la fois - evite de confondre
-- ce total (une monnaie a depenser) avec le "X/40" d'un arbre de
-- specialisation (qui est la progression DEJA allouee dans cet arbre, un
-- nombre totalement different). Confirme via /skt kpdump : numAvailable est
-- bien la bonne donnee, juste ambigue sans ce detail.
local function KPBreakdown(prof)
  local parts = {}
  for id, ln in pairs(prof.lines or {}) do
    if ln.kp and ln.kp > 0 then
      local idx = ST.NameToIndex(ln.exp)
      local label = ST.BucketMeta(idx or "other")
      parts[#parts + 1] = { idx = idx or -1, text = ln.kp .. " " .. label }
    end
  end
  if #parts <= 1 then return nil end
  table.sort(parts, function(a, b) return a.idx > b.idx end)
  local strs = {}
  for _, p in ipairs(parts) do strs[#strs + 1] = p.text end
  return table.concat(strs, ", ")
end

-- ================================================================
-- VUE "EXTENSION EN COURS" (tache 4.2) : une barre cur/max par metier
-- pour l'extension active du client (Midnight par defaut, calcule via
-- GetExpansionLevel - jamais code en dur : suit automatiquement le client),
-- points de connaissance non depenses, alerte visuelle si la concentration
-- d'un metier principal est pleine.
-- ================================================================
local function renderCurrentExtension(rec)
  local curIdx = (GetExpansionLevel and GetExpansionLevel()) or 11
  local _, full, col = ST.BucketMeta(curIdx)
  placeHeader(UI.Hex(col[1], col[2], col[3]) .. full .. "|r", 6)

  local profs = {}
  if rec and type(rec.professions) == "table" then
    for _, p in pairs(rec.professions) do profs[#profs + 1] = p end
  end
  local hasArch = rec and rec.archaeology ~= nil
  if #profs == 0 and not hasArch then
    placeNote(L.NO_PROFESSIONS, 10)
    return
  end
  table.sort(profs, function(a, b)
    local ap, bp = a.isPrimary and true or false, b.isPrimary and true or false
    if ap ~= bp then return ap end
    return (a.name or "") < (b.name or "")
  end)

  for _, prof in ipairs(profs) do
    local curLine
    for _, ln in pairs(prof.lines or {}) do
      if ST.NameToIndex(ln.exp) == curIdx then curLine = ln; break end
    end
    if curLine then
      placeBar(curLine.cur, curLine.max, prof.name or "?", 12, function() ST.OpenProfession(prof) end)
      -- Detail du palier courant, seulement s'il differe du total (evite de
      -- repeter le meme nombre deux fois quand tout le kp vient de ce palier).
      if curLine.kp and curLine.kp > 0 and curLine.kp ~= prof.kp then
        placeNote("|cFFFFD700" .. string.format(L.KP_TIER, curLine.kp) .. "|r", 18)
      end
    elseif prof.base then
      placeBar(prof.base.cur, prof.base.max, prof.name or "?", 12, function() ST.OpenProfession(prof) end)
      placeNote(L.OPEN_HINT, 18)
    else
      placeNote((prof.name or "?") .. "  " .. L.NO_DATA, 12)
    end
    -- Points de connaissance non depenses (acquis), cumules sur TOUTES les
    -- extensions du metier - pas seulement le palier courant. Detail par
    -- extension affiche quand plusieurs y contribuent (evite la confusion
    -- avec le "X/40" d'un arbre de specialisation, qui est un tout autre
    -- nombre : la progression deja allouee, pas la reserve non depensee).
    if prof.kp and prof.kp > 0 then
      local txt = "|cFFFFD700" .. string.format(L.KP_UNSPENT, prof.kp) .. " " .. L.KP_LABEL .. "|r"
      local breakdown = KPBreakdown(prof)
      if breakdown then txt = txt .. "  |cFF888888(" .. breakdown .. ")|r" end
      placeNote(txt, 18)
    end
    if prof.isPrimary and prof.conc and prof.conc.max and prof.conc.max > 0 then
      local capped = prof.conc.cur >= prof.conc.max
      local wc = capped and UI.C.WARN or UI.C.OK
      placeNote(UI.Hex(wc[1], wc[2], wc[3]) .. L.CONCENTRATION .. " " .. prof.conc.cur .. "/" .. prof.conc.max
        .. (capped and (" " .. L.CONC_FULL_TAG) or "") .. "|r", 18)
    end
  end

  if hasArch then
    local a = rec.archaeology
    placeNote("|cFFAAAAAA" .. L.ARCHAEOLOGY .. "|r", 6)
    placeBar(a.cur, a.max, a.name or L.ARCHAEOLOGY, 12)
  end
end

-- ================================================================
-- VUE "TOUTES LES EXTENSIONS" (tache 4.3) : une ligne compacte par metier
-- (barre de completion globale + "X/N au max"), depliable au clic pour
-- montrer le detail par extension (vert = maxe, or = en cours). Pas de
-- frise de micro-barres : une barre par extension possedee, au pire une
-- douzaine de lignes.
-- ================================================================
local EXT_TOTAL = 0
for _ in pairs(ST.EXT_KEY) do EXT_TOTAL = EXT_TOTAL + 1 end

local function professionMaxedCount(prof)
  local n = 0
  for _, ln in pairs(prof.lines or {}) do
    if ST.Percent(ln.cur, ln.max) >= 100 then n = n + 1 end
  end
  return n
end

local expandedProfs = {}  -- etat d'UI local (non persiste) : nom de metier -> deplie ?

local function renderProfessionAllExpansions(prof)
  local overall = ST.ProfessionOverallPercent(prof)
  local maxedN = professionMaxedCount(prof)
  local name = prof.name or "?"
  local isOpen = expandedProfs[name]
  local bar = placeBar(overall, 100, nil, 12, function()
    expandedProfs[name] = not isOpen
    ST.RefreshUI()
  end)
  local glyph = isOpen and "-" or "+"
  local kpTag = (prof.kp and prof.kp > 0)
    and ("   |cFFFFD700" .. string.format(L.KP_UNSPENT, prof.kp) .. "|r") or ""
  bar._txt:SetText(glyph .. " " .. accHex() .. name .. "|r   |cFFBBBBBB" .. overall .. "%|r   |cFF888888"
    .. maxedN .. "/" .. EXT_TOTAL .. " " .. L.MAXED_SHORT .. "|r" .. kpTag)

  if isOpen then
    local hideMaxed = ST.settings.hideMaxed
    local ids = sortedLineIDs(prof)
    local shownAny = false
    for i, id in ipairs(ids) do
      local ln = prof.lines[id]
      local pct = ST.Percent(ln.cur, ln.max)
      if not (hideMaxed and pct >= 100) then
        shownAny = true
        local label = ST.ExpansionLabel(id, i, i == #ids)
        local w = placeBar(ln.cur, ln.max, label, 24)
        local c = (pct >= 100) and UI.C.OK or UI.C.GOLD
        w._fill:SetColorTexture(c[1], c[2], c[3], (pct >= 100) and 1.0 or 0.85)
        w:SetBackdropBorderColor(c[1] * 0.9, c[2] * 0.9, c[3] * 0.9, 0.9)
      end
    end
    if not shownAny then placeNote(L.NO_DATA, 24) end
  end
end

local function renderAllExtensions(rec)
  local profs = {}
  if rec and type(rec.professions) == "table" then
    for _, p in pairs(rec.professions) do profs[#profs + 1] = p end
  end
  if #profs == 0 then
    placeNote(L.NO_PROFESSIONS, 10)
    return
  end
  table.sort(profs, function(a, b)
    local ap, bp = a.isPrimary and true or false, b.isPrimary and true or false
    if ap ~= bp then return ap end
    return (a.name or "") < (b.name or "")
  end)
  local hideMaxProf = ST.settings.hideMaxProf
  local shownAny = false
  for _, prof in ipairs(profs) do
    if not (hideMaxProf and professionMaxedCount(prof) == EXT_TOTAL) then
      shownAny = true
      renderProfessionAllExpansions(prof)
    end
  end
  if not shownAny then placeNote(L.NO_DATA, 10) end
end

-- Puces de filtre par EXTENSION pour la section "A finir" (multi-selection,
-- meme convention que le filtre personnage : aucune puce active = tout
-- affiche). N'affiche que les extensions qui ont reellement des paliers non
-- finis - pas la liste complete des 12, pour rester utile plutot qu'un mur
-- de puces. Largeur auto (meme principe que la bascule de vue plus haut).
local CHIP_H, CHIP_GAP = 22, 4
local function placeExtFilterChips(buckets, sel)
  local anySel = next(sel) ~= nil
  local rowStartY = Y
  local x, rowIdx = 4, 0
  for _, bucket in ipairs(buckets) do
    local label, full, c = ST.BucketMeta(bucket)
    local chip = acquireTab()
    chip._label:SetText(label)
    local w = math.min(90, math.max(44, (chip._label:GetStringWidth() or 30) + 18))
    if x + w > 296 and x > 4 then rowIdx = rowIdx + 1; x = 4 end
    chip:ClearAllPoints()
    chip:SetPoint("TOPLEFT", content, "TOPLEFT", x, rowStartY - rowIdx * (CHIP_H + CHIP_GAP))
    chip:SetSize(w, CHIP_H)

    local active = (not anySel) or sel[bucket]
    if active then
      chip:SetBackdropColor(c[1] * 0.30, c[2] * 0.30, c[3] * 0.30, 0.95)
      chip:SetBackdropBorderColor(c[1], c[2], c[3], 1.0)
      chip._acc:SetVertexColor(c[1], c[2], c[3], 1.0)
      chip._label:SetText(UI.Hex(c[1], c[2], c[3]) .. label .. "|r")
    else
      chip:SetBackdropColor(0.05, 0.05, 0.06, 0.85)
      chip:SetBackdropBorderColor(0.25, 0.25, 0.28, 0.5)
      chip._acc:SetVertexColor(0.3, 0.3, 0.3, 0.4)
      chip._label:SetText("|cFF777777" .. label .. "|r")
    end

    chip:SetScript("OnClick", function()
      sel[bucket] = (not sel[bucket]) or nil
      ST.RefreshUI()
    end)
    chip:SetScript("OnEnter", function(s)
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
      GameTooltip:AddLine(full, c[1], c[2], c[3])
      GameTooltip:Show()
    end)
    chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    x = x + w + CHIP_GAP
  end
  Y = rowStartY - (rowIdx + 1) * (CHIP_H + CHIP_GAP) - 4
end

-- ================================================================
-- VUE MULTI-PERSONNAGE : liste deroulante FILTRE (triee par royaume)
-- ----------------------------------------------------------------
-- Un bouton ouvre une liste deroulante flottante, scrollable, groupee par
-- royaume, avec une case a cocher par perso. C'est un FILTRE : seuls les
-- persos coches sont affiches en dessous. Theme emeraude conserve ; seul le
-- NOM du perso prend la couleur de sa classe. Concu pour tenir des dizaines
-- de personnages sur plusieurs royaumes sans devenir illisible.
-- ================================================================
local charFilter   -- frame flottante PARTAGEE par les deux filtres (construite une fois)

local function BuildCharFilter()
  if charFilter then return charFilter end
  local f = CreateFrame("Frame", "SkillTrackerCharFilter", UIParent, "BackdropTemplate")
  f:SetSize(262, 404)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:Hide()
  UI.SkinFrame(f, ACC, UI.C.PANEL)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOPLEFT", 10, -8)
  title:SetText(accHex() .. "Filtre|r")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() f:Hide() end)

  -- Champ de recherche (meme design que la loupe de la suite) : filtre la liste
  -- en direct pendant la frappe. Precieux quand on a des dizaines de persos.
  local box = CreateFrame("EditBox", nil, f, "BackdropTemplate")
  box:SetSize(240, 22)
  box:SetPoint("TOPLEFT", 10, -28)
  box:SetBackdrop(UI.FlatBackdrop())
  box:SetBackdropColor(0.02, 0.01, 0.04, 0.95)
  box:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 0.8)
  box:SetAutoFocus(false)
  box:SetFontObject("GameFontHighlightSmall")
  box:SetTextInsets(6, 18, 0, 0)
  local mag = box:CreateTexture(nil, "OVERLAY")
  mag:SetSize(12, 12); mag:SetPoint("RIGHT", -4, 0)
  mag:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
  local ph = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ph:SetPoint("LEFT", 6, 0); ph:SetText("Rechercher...")

  local allB = UI.MakeButton(f, 62, 18, "Tout")
  allB:SetPoint("TOPLEFT", 10, -56)
  local noneB = UI.MakeButton(f, 62, 18, "Aucun")
  noneB:SetPoint("LEFT", allB, "RIGHT", 6, 0)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -80)
  scroll:SetPoint("BOTTOMRIGHT", -28, 10)
  local scont = CreateFrame("Frame", nil, scroll)
  scont:SetSize(220, 10)
  scroll:SetScrollChild(scont)

  -- sel = jeu de selection courant (viewChars ou todoChars). query = recherche.
  charFilter = { frame = f, content = scont, cb = {}, hdr = {}, title = title,
                 box = box, ph = ph, sel = nil, query = "" }

  local function rebuild()
    for _, w in ipairs(charFilter.cb) do w:Hide() end
    for _, w in ipairs(charFilter.hdr) do w:Hide() end
    local sel = charFilter.sel or {}
    local q   = charFilter.query or ""
    local chars = ST.BuildCharList()
    -- Regroupement par royaume (royaume du perso courant en tete), filtre recherche.
    local order, byRealm, curRealm = {}, {}, (GetRealmName() or "")
    for _, c in ipairs(chars) do
      if q == "" or UI.Match((c.name or "") .. " " .. (c.realm or ""), q) then
        local r = c.realm or "?"
        if not byRealm[r] then byRealm[r] = {}; order[#order + 1] = r end
        byRealm[r][#byRealm[r] + 1] = c
      end
    end
    table.sort(order, function(a, b)
      if (a == curRealm) ~= (b == curRealm) then return a == curRealm end
      return a < b
    end)
    local y, ci, hi = -4, 0, 0
    for _, realm in ipairs(order) do
      hi = hi + 1
      local h = charFilter.hdr[hi]
      if not h then h = scont:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); charFilter.hdr[hi] = h end
      h:ClearAllPoints(); h:SetPoint("TOPLEFT", 2, y)
      h:SetText(accHex() .. realm .. "|r")
      h:Show(); y = y - 18
      local list = byRealm[realm]
      table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
      for _, c in ipairs(list) do
        ci = ci + 1
        local cb = charFilter.cb[ci]
        if not cb then
          cb = CreateFrame("CheckButton", nil, scont, "UICheckButtonTemplate")
          cb:SetSize(20, 20)
          cb.txt = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
          cb.txt:SetPoint("LEFT", cb, "RIGHT", 2, 0)
          charFilter.cb[ci] = cb
        end
        cb:ClearAllPoints(); cb:SetPoint("TOPLEFT", 12, y)
        local cc = ClassColor(c.class)
        cb.txt:SetText(UI.Hex(cc[1], cc[2], cc[3]) .. (c.name or "?") .. "|r"
          .. (c.imported and ("  |cFF888888(" .. L.IMPORTED_TAG .. ")|r") or ""))
        cb:SetChecked(sel[c.key] and true or false)
        local key = c.key
        cb:SetScript("OnClick", function(s)
          local t = charFilter.sel; if not t then return end
          t[key] = s:GetChecked() and true or nil
          ST.RefreshUI()
        end)
        cb:Show(); y = y - 22
      end
      y = y - 4
    end
    scont:SetHeight(math.max(-y + 6, 10))
  end
  charFilter.rebuild = rebuild

  box:SetScript("OnTextChanged", function(s)
    ph:SetShown(s:GetText() == "")
    charFilter.query = UI.Normalize(s:GetText() or "")
    rebuild()
  end)
  box:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)

  allB:SetScript("OnClick", function()
    local t = charFilter.sel
    if t then for _, c in ipairs(ST.BuildCharList()) do t[c.key] = true end end
    rebuild(); ST.RefreshUI()
  end)
  noneB:SetScript("OnClick", function()
    local t = charFilter.sel
    if t then for k in pairs(t) do t[k] = nil end end
    rebuild(); ST.RefreshUI()
  end)

  -- La liste se ferme avec la fenetre principale du module.
  if mainFrame then mainFrame:HookScript("OnHide", function() f:Hide() end) end
  return charFilter
end

-- Ouvre/ferme la liste, liee au jeu de selection "sel" et au titre voulu.
local function ToggleCharFilter(anchor, sel, titleText)
  local cf = BuildCharFilter()
  if cf.frame:IsShown() and cf.sel == sel then cf.frame:Hide(); return end
  cf.sel = sel
  cf.query = ""
  if cf.box then cf.box:SetText("") end
  if cf.ph then cf.ph:Show() end
  if titleText and cf.title then cf.title:SetText(accHex() .. titleText .. "|r") end
  cf.rebuild()
  cf.frame:ClearAllPoints()
  cf.frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  cf.frame:Show()
end

-- Bouton-filtre place dans le contenu. sel = table de selection persistee.
local function placeCharFilter(chars, sel, titleText, label)
  local nSel = 0
  for _, c in ipairs(chars) do if sel[c.key] then nSel = nSel + 1 end end
  local b = acquireHeaderRow()
  b:ClearAllPoints(); b:SetPoint("TOPLEFT", content, "TOPLEFT", 4, Y); b:SetWidth(292)
  b._label:SetText(accHex() .. (label or "Filtrer les personnages") .. "|r  |cFFCCCCCC(" .. nSel
    .. ")|r   |cFF888888cliquer pour choisir|r")
  b:SetScript("OnClick", function(s) ToggleCharFilter(s, sel, titleText) end)
  line(26)
end

-- Rendu d'UN personnage : en-tete a la couleur de classe + une barre par
-- metier (teintee classe), plus l'archeologie si apprise. Rien n'est fondu.
local function renderCharSummary(c)
  local rec = c.rec
  local cc  = ClassColor(c.class)
  placeHeader(UI.Hex(cc[1], cc[2], cc[3]) .. (c.name or "?") .. "|r  |cFF888888" .. (c.realm or "")
    .. (c.imported and ("  (" .. L.IMPORTED_TAG .. ")") or "") .. "|r", 6)

  local profs = {}
  if rec and type(rec.professions) == "table" then
    for _, prof in pairs(rec.professions) do profs[#profs + 1] = prof end
  end
  if #profs == 0 then
    placeNote(L.NO_PROFESSIONS, 16)
    return
  end
  table.sort(profs, function(a, b)
    local ap, bp = a.isPrimary and true or false, b.isPrimary and true or false
    if ap ~= bp then return ap end
    return (a.name or "") < (b.name or "")
  end)
  for _, prof in ipairs(profs) do
    local cur, max
    if prof.base and (prof.base.max or 0) > 0 then
      cur, max = prof.base.cur or 0, prof.base.max
    else
      cur, max = ST.ProfessionOverallPercent(prof), 100
    end
    -- Barre au theme emeraude de l'addon (inchangee) : seul le NOM du perso,
    -- dans l'en-tete ci-dessus, prend la couleur de classe.
    placeBar(cur, max, prof.name or "?", 16)
  end
  if rec and rec.archaeology then
    local a = rec.archaeology
    placeBar(a.cur, a.max, a.name or L.ARCHAEOLOGY, 16)
  end
end

function ST.RefreshUI()
  if not mainFrame or not mainFrame:IsShown() then return end
  resetPools()
  Y = yTop

  local realm = GetRealmName() or "?"
  local name  = UnitName("player") or "?"
  local rec = ST.db.chars[realm] and ST.db.chars[realm][name]

  -- ---- Bandeau personnage commun (tache 2) + bascule de vue (tache 4.1) ----
  placeHeader(UI.CharBannerText(), 4)
  placeMetierViewSwitch()

  local metierView = ST.settings.metierView or "current"
  if metierView == "current" then
    renderCurrentExtension(rec)
  elseif metierView == "all" then
    renderAllExtensions(rec)
  else -- "account"
    local chars = ST.BuildCharList()
    if #chars == 0 then
      placeNote(L.NO_DATA, 8)
    else
      -- Selection persistante des persos affiches. Chaque perso a sa couleur
      -- de classe. Defaut : le personnage courant coche.
      ST.settings.viewChars = ST.settings.viewChars or {}
      local selV = ST.settings.viewChars
      -- Purge des cles de persos disparus (donnees effacees, etc.).
      local live = {}
      for _, c in ipairs(chars) do live[c.key] = true end
      for k in pairs(selV) do if not live[k] then selV[k] = nil end end
      -- Rien de coche : on preselectionne le perso courant (sinon le premier).
      local anyV = false
      for _, c in ipairs(chars) do if selV[c.key] then anyV = true break end end
      if not anyV then
        for _, c in ipairs(chars) do
          if c.current then selV[c.key] = true; anyV = true; break end
        end
        if not anyV and chars[1] then selV[chars[1].key] = true end
      end

      -- Filtre : liste deroulante scrollable, triee par royaume, avec recherche.
      -- Seuls les persos coches sont affiches en dessous.
      placeNote("|cFFAAAAAA" .. L.PICK_CHARS .. "|r", 6)
      placeCharFilter(chars, selV, "Filtre : personnages", "Filtrer les personnages")

      -- Rendu personnage par personnage (jamais fondu en une moyenne).
      local shownAny = false
      for _, c in ipairs(chars) do
        if selV[c.key] then shownAny = true; renderCharSummary(c) end
      end
      if not shownAny then placeNote(L.NO_DATA, 8) end
    end
  end

  -- ---- Section : "A finir" (paliers non maxes de tous les persos locaux) ----
  if ST.settings.showTodo then
    line(6)
    local todoAll = ST.BuildTodo()

    -- Filtre par personnage : MEME liste deroulante que la vue multi-perso,
    -- mais liee a son propre jeu de selection (todoChars). Comportement par
    -- defaut : on suit le personnage courant ; le joueur ajuste ensuite.
    ST.settings.todoChars = ST.settings.todoChars or {}
    local sel = ST.settings.todoChars
    -- Purge des cles de persos disparus (donnees effacees, etc.).
    local allChars = ST.BuildCharList()
    local live = {}
    for _, c in ipairs(allChars) do live[c.key] = true end
    for k in pairs(sel) do if not live[k] then sel[k] = nil end end
    -- Initialisation unique : au premier affichage, on coche le perso courant.
    if not ST.settings.todoInit then
      ST.settings.todoInit = true
      if next(sel) == nil then
        sel[(GetRealmName() or "") .. "\t" .. (UnitName("player") or "")] = true
      end
    end

    -- Application du filtre : uniquement les paliers des persos coches.
    local todoByChar = {}
    for _, t in ipairs(todoAll) do
      local key = (t.realm or "") .. "\t" .. (t.char or "")
      if sel[key] then todoByChar[#todoByChar + 1] = t end
    end

    -- Filtre par extension (multi-selection, aucune case cochee = tout
    -- affiche) : evite le mur de 18 paliers toutes extensions melangees.
    -- Seules les extensions reellement presentes dans la liste sont
    -- proposees, dans l'ordre le plus recent -> le plus ancien.
    ST.settings.todoExtFilter = ST.settings.todoExtFilter or {}
    local extSel = ST.settings.todoExtFilter
    local bucketSeen, buckets = {}, {}
    for _, t in ipairs(todoByChar) do
      local b = t.idx or "other"
      if not bucketSeen[b] then bucketSeen[b] = true; buckets[#buckets + 1] = b end
    end
    table.sort(buckets, function(a, b)
      local na = (a == "other") and -1 or a
      local nb = (b == "other") and -1 or b
      return na > nb
    end)
    -- Purge des extensions qui ne sont plus proposees (donnees changees).
    for b in pairs(extSel) do if not bucketSeen[b] then extSel[b] = nil end end

    local todo = {}
    local anyExtSel = next(extSel) ~= nil
    for _, t in ipairs(todoByChar) do
      local b = t.idx or "other"
      if (not anyExtSel) or extSel[b] then todo[#todo + 1] = t end
    end

    placeHeader(accHex() .. L.TODO_TITLE .. "|r"
      .. "  |cFF888888" .. string.format(#todo == 1 and L.TODO_COUNT_ONE or L.TODO_COUNT_MANY, #todo) .. "|r", 4)

    -- Bouton-filtre (meme composant, avec recherche et tri par royaume).
    placeCharFilter(allChars, sel, "A finir : personnages", "Personnages suivis")

    if #buckets > 1 then
      placeNote("|cFFAAAAAA" .. L.TODO_EXT_FILTER .. "|r", 6)
      placeExtFilterChips(buckets, extSel)
    end

    if #todo == 0 then
      placeNote("|cFF66FF98" .. L.TODO_NONE .. "|r", 8)
    else
      -- Si un seul perso est suivi, inutile de repeter son nom sur chaque ligne.
      local nShown = 0; for _ in pairs(sel) do nShown = nShown + 1 end
      local hideName = (nShown == 1)
      -- Plus de troncature : on affiche TOUS les paliers a finir. La fenetre
      -- s'ajuste en hauteur pour tout montrer (auto-hauteur ci-dessous) et
      -- reste defilante si le contenu depasse la hauteur de l'ecran.
      for i = 1, #todo do
        local t = todo[i]
        local expLbl = ST.BucketMeta(t.idx or "other")
        local suffix = " |cFF888888" .. (expLbl or "")
          .. (hideName and "" or (" " .. (t.char or ""))) .. "|r"
        placeBar(t.cur, t.max, (t.prof or "?") .. suffix, 12)
      end
    end
  end

  -- Hauteur du contenu defilant, puis auto-hauteur de la fenetre (regle
  -- uniforme de la suite : haut 52 + contenu + bas 12, bornee a l'ecran ;
  -- au-dela, la zone interne reste defilante). Calcul autonome (aucune
  -- dependance externe), identique a RenTracker / DgnTracker / DailyTracker.
  local contentH = math.max(-Y + 10, 10)
  content:SetHeight(contentH)
  if mainFrame then
    -- Auto-hauteur centralisee dans le socle : chrome 64 (haut 52 + bas 12),
    -- plancher 300, plafond ecran-80. Remplace le calcul inline.
    _G.TibiMidnight.FitHeight(mainFrame, contentH, { chrome = 64, min = 300 })
  end
end

-- ================================================================
-- FRAME PRINCIPALE
-- ================================================================
local function BuildMainFrame()
  if mainFrame then return end

  local f = CreateFrame("Frame", "SkillTrackerMainFrame", UIParent, "BackdropTemplate")
  mainFrame = f
  f:SetSize(340, 460)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)

  -- Fermeture par Echap via UISpecialFrames (mecanisme natif Blizzard) : voir
  -- note detaillee dans TibiSuiteCore.lua (WireEscapeFor) - piege reel
  -- confirme en jeu quand un autre addon intercepte lui aussi Echap.
  tinsert(UISpecialFrames, "SkillTrackerMainFrame")

  f:Hide()

  -- Peau plate + liseré émeraude (#00FF98) : identite visuelle demandee.
  UI.SkinFrame(f, ACC, UI.C.BG)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -14)
  title:SetText(accHex() .. L.TITLE .. "|r")

  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("TOP", title, "BOTTOM", 0, -2)
  sub:SetText(L.PANEL_SUBTITLE)

  -- Bouton Options : meme convention que le reste de la suite (bouton texte
  -- flottant au-dessus de la fenetre, pose par le socle UI.AddHeaderControls).
  UI.AddHeaderControls(f, {
    accent = ACC,
    onOptions = function() ST.OpenOptions() end,
  })

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() f:Hide() end)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -52)
  scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(300, 10)
  scroll:SetScrollChild(content)

  f:SetScript("OnShow", function() ST.RequestScan(0.05); ST.RefreshUI() end)
end

-- Ouvre la fenetre officielle du metier en jeu. Depuis un clic (evenement
-- materiel), lancer le sort du metier est autorise. Plusieurs voies, protegees.
function ST.OpenProfession(prof)
  if not prof then return end
  -- 1) API dediee si presente (selon version).
  if C_TradeSkillUI and type(C_TradeSkillUI.OpenTradeSkill) == "function" and prof.parent then
    if pcall(C_TradeSkillUI.OpenTradeSkill, prof.parent) then return end
  end
  -- 2) Lancer le sort du metier par son nom (ouvre la fenetre).
  if prof.name and type(CastSpellByName) == "function" then
    pcall(CastSpellByName, prof.name)
  end
end

-- Bascule l'affichage. forceShow=true : force l'ouverture.
function ST.Toggle(forceShow)
  if ST.settings and ST.settings.enabled == false then
    print("|cFF00FF98SkillTracker|r " .. L.OPT_ENABLED .. " : |cFFFF7777off|r  (/skt config)")
    return
  end
  BuildMainFrame()
  if forceShow then
    mainFrame:Show(); ST.RefreshUI(); return
  end
  if mainFrame:IsShown() then mainFrame:Hide() else mainFrame:Show(); ST.RefreshUI() end
end

-- ================================================================
-- TOOLTIP RESUME (bouton minimap + objet LibDataBroker)
-- Liste les metiers du perso courant avec leur progression globale, puis
-- le nombre de paliers a finir sur le compte.
-- ================================================================
function ST.FillSummaryTooltip(tt)
  tt:AddLine("|cFF00FF98SkillTracker|r")
  local realm = GetRealmName() or "?"
  local name  = UnitName("player") or "?"
  local rec = ST.db and ST.db.chars[realm] and ST.db.chars[realm][name]
  local any = false
  if rec and type(rec.professions) == "table" then
    local list = {}
    for _, p in pairs(rec.professions) do list[#list + 1] = p end
    table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
    for _, p in ipairs(list) do
      any = true
      tt:AddDoubleLine(p.name or "?", ST.ProfessionOverallPercent(p) .. "%",
        0.9, 0.9, 0.9, ST.COLOR[1], ST.COLOR[2], ST.COLOR[3])
      if p.conc then
        local capped = (p.conc.max > 0) and (p.conc.cur >= p.conc.max)
        local rr, gg, bb = 0.4, 0.85, 0.6
        if capped then rr, gg, bb = 1.0, 0.4, 0.4 end
        tt:AddDoubleLine("   " .. L.CONCENTRATION, p.conc.cur .. "/" .. p.conc.max
          .. (capped and ("  " .. L.CONC_FULL_TAG) or ""), 0.6, 0.6, 0.65, rr, gg, bb)
      end
      if p.kp and p.kp > 0 then
        tt:AddDoubleLine("   " .. L.KP_LABEL, string.format(L.KP_UNSPENT, p.kp), 0.6, 0.6, 0.65, 1.0, 0.84, 0.0)
      end
    end
    if rec.archaeology then
      any = true
      tt:AddDoubleLine(L.ARCHAEOLOGY, ST.Percent(rec.archaeology.cur, rec.archaeology.max) .. "%",
        0.9, 0.9, 0.9, ST.COLOR[1], ST.COLOR[2], ST.COLOR[3])
    end
  end
  if not any then
    tt:AddLine(L.NO_PROFESSIONS, 0.7, 0.7, 0.7)
  end
  local todo = (ST.BuildTodo and ST.BuildTodo()) or {}
  tt:AddLine(" ")
  tt:AddLine(string.format(#todo == 1 and L.TODO_COUNT_ONE or L.TODO_COUNT_MANY, #todo), 0.7, 0.75, 0.82)
  tt:AddLine(L.TT_LEFT, 0.55, 0.55, 0.6)
  tt:AddLine(L.TT_RIGHT, 0.55, 0.55, 0.6)
end

-- ================================================================
-- BOUTON MINIMAP (orbital, style suite)
-- ================================================================
local mmBtn
local function GetMinimapRadius() return (Minimap:GetWidth() / 2) + 10 end
local function SetMMPos(angle)
  ST.settings.mmAngle = angle
  local rad = math.rad(angle)
  local r = GetMinimapRadius()
  mmBtn:ClearAllPoints()
  mmBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * r, math.sin(rad) * r)
end

local function BuildMinimapButton()
  if mmBtn then return end
  mmBtn = CreateFrame("Button", "SkillTrackerMinimapBtn", Minimap)
  mmBtn:SetSize(32, 32)
  mmBtn:SetFrameStrata("MEDIUM")
  mmBtn:SetFrameLevel(8)
  mmBtn:EnableMouse(true)
  mmBtn:SetClampedToScreen(true)

  local icon = mmBtn:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER", 0, 0)
  icon:SetSize(20, 20)
  icon:SetTexture(ST.LOGO)
  local mask = mmBtn:CreateMaskTexture()
  mask:SetAllPoints(icon)
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  icon:AddMaskTexture(mask)

  local ring = mmBtn:CreateTexture(nil, "OVERLAY")
  ring:SetSize(52, 52)
  ring:SetPoint("TOPLEFT", 0, 0)
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  SetMMPos(ST.settings.mmAngle or 210)

  mmBtn:RegisterForDrag("LeftButton")
  mmBtn:RegisterForClicks("AnyUp")
  mmBtn:SetScript("OnDragStart", function(s)
    s:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local sc = UIParent:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      SetMMPos(math.deg(math.atan2((cy / sc) - my, (cx / sc) - mx)))
    end)
  end)
  mmBtn:SetScript("OnDragStop", function(s) s:SetScript("OnUpdate", nil) end)
  mmBtn:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then ST.OpenOptions() else ST.Toggle() end
  end)
  mmBtn:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
    ST.FillSummaryTooltip(GameTooltip)
    GameTooltip:Show()
  end)
  mmBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  if not ST.settings.minimap then mmBtn:Hide() end
end

function ST.UpdateMinimap()
  if not mmBtn then return end
  if ST.settings.minimap then mmBtn:Show() else mmBtn:Hide() end
end

-- ================================================================
-- EXPORT / IMPORT : petites fenetres a EditBox
-- ================================================================
local function ShowStringPopup(titleText, hintText, initialText, editable, onAccept)
  local p = _G["SkillTrackerStringPopup"]
  if not p then
    p = CreateFrame("Frame", "SkillTrackerStringPopup", UIParent, "BackdropTemplate")
    p:SetSize(420, 150)
    p:SetPoint("CENTER", 0, 60)
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetMovable(true); p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", p.StopMovingOrSizing)
    UI.SkinFrame(p, ACC, UI.C.PANEL)

    p._title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p._title:SetPoint("TOP", 0, -12)

    p._hint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    p._hint:SetPoint("TOP", p._title, "BOTTOM", 0, -6)
    p._hint:SetWidth(390); p._hint:SetJustifyH("CENTER")

    local box = CreateFrame("EditBox", nil, p, "BackdropTemplate")
    box:SetSize(390, 24)
    box:SetPoint("TOP", p._hint, "BOTTOM", 0, -10)
    box:SetBackdrop(UI.FlatBackdrop())
    box:SetBackdropColor(0.02, 0.03, 0.03, 0.95)
    box:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 0.7)
    box:SetAutoFocus(true)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(6, 6, 0, 0)
    box:SetScript("OnEscapePressed", function(s) s:ClearFocus(); p:Hide() end)
    p._box = box

    local msg = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    msg:SetPoint("TOP", box, "BOTTOM", 0, -8)
    msg:SetWidth(390); msg:SetJustifyH("CENTER")
    p._msg = msg

    local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() p:Hide() end)
  end

  p._title:SetText(accHex() .. titleText .. "|r")
  p._hint:SetText(hintText)
  p._msg:SetText("")
  local box = p._box
  box:SetText(initialText or "")
  box:SetCursorPosition(0)
  if editable then
    box:SetScript("OnEnterPressed", function(s)
      local txt = s:GetText()
      if onAccept then onAccept(txt, p._msg) end
    end)
    box:EnableKeyboard(true)
    box:SetAutoFocus(true)
  else
    box:SetScript("OnEnterPressed", function(s) s:HighlightText() end)
    box:HighlightText()
  end
  p:Show()
  box:SetFocus()
  if not editable then box:HighlightText() end
end

local function DoExport()
  local s = ST.ExportString()
  if not s then
    print("|cFF00FF98SkillTracker|r " .. L.EXPORT_EMPTY)
    return
  end
  ShowStringPopup(L.OPT_EXPORT, L.EXPORT_HINT, s, false, nil)
end

local function DoImport()
  ShowStringPopup(L.OPT_IMPORT, L.IMPORT_HINT, "", true, function(txt, msgFS)
    local ok, count = ST.ImportString(txt)
    if ok then
      msgFS:SetText("|cFF00FF98" .. string.format(L.IMPORT_OK, count or 0) .. "|r")
    else
      msgFS:SetText("|cFFFF7777" .. L.IMPORT_FAIL .. "|r")
    end
  end)
end

-- ================================================================
-- PANNEAU D'OPTIONS (via UI.CreateOptionsPanel)
-- ================================================================
local optPanel
local function BuildOptions()
  if optPanel then return end
  optPanel = UI.CreateOptionsPanel({
    name = "SkillTrackerOptions", title = L.OPT_TITLE, accent = ACC,
  })

  optPanel:Section(L.OPT_GENERAL)
  optPanel:Check(L.OPT_ENABLED,
    function() return ST.settings.enabled end,
    function(v)
      ST.settings.enabled = v
      if v then ST.RequestScan(0.1) elseif mainFrame then mainFrame:Hide() end
    end, L.OPT_ENABLED_TT)
  optPanel:Check(L.OPT_MINIMAP,
    function() return ST.settings.minimap end,
    function(v) ST.settings.minimap = v; ST.UpdateMinimap() end)

  optPanel:Section(L.OPT_VIEW)
  optPanel:Check(L.OPT_HIDE_MAXED,
    function() return ST.settings.hideMaxed end,
    function(v) ST.settings.hideMaxed = v; ST.RefreshUI() end, L.OPT_HIDE_MAXED_TT)
  optPanel:Check(L.OPT_HIDE_MAXPROF,
    function() return ST.settings.hideMaxProf end,
    function(v) ST.settings.hideMaxProf = v; ST.RefreshUI() end)
  optPanel:Check(L.OPT_SHOW_TODO,
    function() return ST.settings.showTodo end,
    function(v) ST.settings.showTodo = v; ST.RefreshUI() end)
  optPanel:Check(L.OPT_CONC_ALERT,
    function() return ST.settings.concAlert end,
    function(v) ST.settings.concAlert = v end)

  optPanel:Button(L.OPT_RESCAN, function() ST.RequestScan(0.1) end)

  optPanel:Section(L.OPT_DATA)
  optPanel:Note(L.MULTIACC_NOTE)
  optPanel:Button(L.OPT_EXPORT, DoExport)
  optPanel:Button(L.OPT_IMPORT, DoImport)
  optPanel:Button(L.OPT_WIPE_CHAR, function()
    ST.WipeCurrentChar()
  end)
end

function ST.OpenOptions()
  BuildOptions()
  optPanel:Toggle()
end

-- ================================================================
-- HOOKS D'INITIALISATION (appeles depuis Core.lua)
-- ================================================================
function ST.OnDBReady()
  -- rien de lourd ici : la frame se construit paresseusement a l'ouverture
end

function ST.OnPlayerLogin()
  BuildMinimapButton()
end
