-- ================================================================
--  SkillTracker  -  UI.lua
--  Panneau principal (liseré émeraude #00FF98) en 5 vues :
--    Extension en cours / Toutes les extensions / Compte /
--    Concentration (tous les persos, projetee) / Semaine (connaissances).
--  Plus : liste "A finir", tooltip resume, bouton minimap, options,
--  export / import.
--
--  Reutilise les helpers du socle (_G.TibiMidnight) : SkinFrame, SetLisere,
--  FlatBackdrop, MakeButton, SkinScrollBar, CreateOptionsPanel, palette UI.C.
--
--  Taint : la fenetre est dans UISpecialFrames, donc AUCUN hook OnHide sur
--  elle. La liste de filtre est un ENFANT de la fenetre : elle se masque
--  avec elle sans aucun script.
-- ================================================================

local ADDON, ST = ...
local L  = ST.L
local UI = _G.TibiMidnight   -- garanti : TibiSuiteUI.lua se charge avant

local ACC = ST.COLOR
local function accHex() return UI.Hex(ACC[1], ACC[2], ACC[3]) end
local function hex(c) return UI.Hex(c[1], c[2], c[3]) end

local function ClassColor(classToken)
  if classToken then
    local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classToken))
      or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken])
    if c then return { c.r, c.g, c.b } end
  end
  return { 0.85, 0.85, 0.90 }
end

local function sortProfs(list)
  table.sort(list, function(a, b)
    local ap, bp = a.isPrimary and true or false, b.isPrimary and true or false
    if ap ~= bp then return ap end
    return (a.name or "") < (b.name or "")
  end)
  return list
end

local function profList(rec)
  local out = {}
  if rec and type(rec.professions) == "table" then
    for parent, p in pairs(rec.professions) do
      p.parent = p.parent or parent
      out[#out + 1] = p
    end
  end
  return sortProfs(out)
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
  txt:SetPoint("LEFT", 6, 0)
  txt:SetPoint("RIGHT", -6, 0)
  txt:SetJustifyH("CENTER")
  txt:SetWordWrap(false)
  bar._txt = txt

  local hl = bar:CreateTexture(nil, "OVERLAY")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  hl:Hide()
  bar._hl = hl

  bar._w = w
  return bar
end

local function SetBar(bar, cur, max, label)
  local pct = ST.Percent(cur, max)
  local usable = (bar._w - 2)
  bar._fill:SetWidth(math.max(1, math.floor(usable * pct / 100 + 0.5)))
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

local function PaintBar(bar, c, a)
  bar._fill:SetColorTexture(c[1], c[2], c[3], a or 0.9)
  bar:SetBackdropBorderColor(c[1] * 0.9, c[2] * 0.9, c[3] * 0.9, 0.9)
end

-- ================================================================
-- POOL DE WIDGETS (on reutilise, on ne recree jamais)
-- ================================================================
local mainFrame, content
local pools = { header = {}, bar = {}, note = {}, tab = {} }
local used  = { header = {}, bar = {}, note = {}, tab = {} }

local function resetPools()
  for kind, list in pairs(used) do
    for _, w in ipairs(list) do
      w:Hide()
      pools[kind][#pools[kind] + 1] = w
    end
    used[kind] = {}
  end
end

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
  w:SetScript("OnClick", nil)
  w:Show()
  return w
end

local function acquireBar()
  local w = table.remove(pools.bar)
  if not w then w = MakeBar(content, 300, 16) end
  w:EnableMouse(false)
  w:SetScript("OnMouseUp", nil)
  w:SetScript("OnEnter", nil)
  w:SetScript("OnLeave", nil)
  if w._hl then w._hl:Hide() end
  used.bar[#used.bar + 1] = w
  w:Show()
  return w
end

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
-- PLACEMENT
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

local function placeBar(cur, max, label, indent, onClick, tipFn)
  local w = acquireBar()
  local x = indent or 16
  w:ClearAllPoints()
  w:SetPoint("TOPLEFT", content, "TOPLEFT", x, Y)
  w:SetWidth(300 - x - 6)
  w._w = 300 - x - 6
  SetBar(w, cur, max, label)
  if onClick or tipFn then
    w:EnableMouse(true)
    if onClick then w:SetScript("OnMouseUp", function() onClick() end) end
    w:SetScript("OnEnter", function(s)
      if onClick and s._hl then s._hl:Show() end
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
      if tipFn then tipFn(GameTooltip) end
      if onClick then GameTooltip:AddLine(L.OPEN_PROF_HINT, 0.8, 0.85, 0.9) end
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

-- Puce (bouton plat colore). state : "on" / "off" / "dim". Largeur auto.
local function styleChip(chip, text, c, state)
  if state == "on" then
    chip:SetBackdropColor(c[1] * 0.30, c[2] * 0.30, c[3] * 0.30, 0.95)
    chip:SetBackdropBorderColor(c[1], c[2], c[3], 1.0)
    chip._acc:SetVertexColor(c[1], c[2], c[3], 1.0)
    chip._label:SetText(hex(c) .. text .. "|r")
  elseif state == "dim" then
    chip:SetBackdropColor(0.03, 0.03, 0.04, 0.70)
    chip:SetBackdropBorderColor(0.15, 0.15, 0.17, 0.5)
    chip._acc:SetVertexColor(0.2, 0.2, 0.2, 0.3)
    chip._label:SetText("|cFF555555" .. text .. "|r")
  else
    chip:SetBackdropColor(0.05, 0.05, 0.06, 0.85)
    chip:SetBackdropBorderColor(0.25, 0.25, 0.28, 0.5)
    chip._acc:SetVertexColor(0.3, 0.3, 0.3, 0.4)
    chip._label:SetText("|cFF999999" .. text .. "|r")
  end
end

-- Rangee de puces a largeur auto, avec retour a la ligne. items = liste de
-- { text, color, state, onClick, tip(tt) }.
local CHIP_H, CHIP_GAP = 22, 4
local function placeChips(items, x0, minW, maxW)
  x0, minW, maxW = x0 or 4, minW or 44, maxW or 140
  local rowStartY = Y
  local x, rowIdx = x0, 0
  for _, it in ipairs(items) do
    local chip = acquireTab()
    chip._label:SetText(it.text)
    local w = math.min(maxW, math.max(minW, (chip._label:GetStringWidth() or 30) + 18))
    if x + w > 296 and x > x0 then rowIdx = rowIdx + 1; x = x0 end
    chip:ClearAllPoints()
    chip:SetPoint("TOPLEFT", content, "TOPLEFT", x, rowStartY - rowIdx * (CHIP_H + CHIP_GAP))
    chip:SetSize(w, CHIP_H)
    styleChip(chip, it.text, it.color or ACC, it.state)
    if it.onClick then chip:SetScript("OnClick", it.onClick) end
    if it.tip then
      chip:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        it.tip(GameTooltip)
        GameTooltip:Show()
      end)
      chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    x = x + w + CHIP_GAP
  end
  Y = rowStartY - (rowIdx + 1) * (CHIP_H + CHIP_GAP)
end

-- ================================================================
-- BASCULE DE VUE
-- ================================================================
local METIER_VIEWS = { "current", "all", "account", "conc", "week", "recipes" }
local VIEW_LABEL = {
  current = "METIER_VIEW_CURRENT", all = "METIER_VIEW_ALL", account = "METIER_VIEW_ACCOUNT",
  conc = "METIER_VIEW_CONC", week = "METIER_VIEW_WEEK", recipes = "METIER_VIEW_RECIPES",
}

local function placeMetierViewSwitch()
  local sel = ST.settings.metierView or "current"
  if not VIEW_LABEL[sel] then sel = "current"; ST.settings.metierView = sel end
  local items = {}
  for _, v in ipairs(METIER_VIEWS) do
    local text = L[VIEW_LABEL[v]]
    if v == "conc" and ST.ConcFullCount then
      local n = ST.ConcFullCount()
      if n > 0 then text = text .. " (" .. n .. ")" end
    end
    items[#items + 1] = {
      text = text, color = ACC, state = (v == sel) and "on" or "off",
      onClick = function() ST.settings.metierView = v; ST.RefreshUI() end,
    }
  end
  placeChips(items, 4, 60, 200)
end

-- Detail "X TWW, Y MID" quand le total de connaissances vient de plusieurs extensions.
local function KPBreakdown(prof)
  local parts = {}
  for _, ln in pairs(prof.lines or {}) do
    if ln.kp and ln.kp > 0 then
      local idx = ST.LineIndex(ln)
      parts[#parts + 1] = { idx = idx or -1, text = ln.kp .. " " .. ST.BucketMeta(idx or "other") }
    end
  end
  if #parts <= 1 then return nil end
  table.sort(parts, function(a, b) return a.idx > b.idx end)
  local strs = {}
  for _, p in ipairs(parts) do strs[#strs + 1] = p.text end
  return table.concat(strs, ", ")
end

-- Ligne de concentration projetee (vue en cours + resume).
local function ConcNote(prof)
  local pr = ST.ConcProject and ST.ConcProject(prof)
  if not pr then return nil end
  local c = pr.full and UI.C.WARN or UI.C.OK
  return hex(c) .. L.CONCENTRATION .. " " .. pr.cur .. "/" .. pr.max .. "|r  |cFF999999"
    .. ST.ConcStatusText(pr) .. "|r"
end

-- ================================================================
-- VUE "EXTENSION EN COURS"
-- ================================================================
local function renderCurrentExtension(rec)
  local curIdx = ST.CurrentExpIndex()
  local _, full, col = ST.BucketMeta(curIdx)
  placeHeader(hex(col) .. full .. "|r", 6)

  local profs = profList(rec)
  local hasArch = rec and rec.archaeology ~= nil
  if #profs == 0 and not hasArch then
    placeNote(L.NO_PROFESSIONS, 10)
    return
  end

  for _, prof in ipairs(profs) do
    local curLine = ST.CurrentLine(prof)
    if curLine then
      placeBar(curLine.cur, curLine.max, prof.name or "?", 12, function() ST.OpenProfession(prof) end)
      if curLine.kp and curLine.kp > 0 and curLine.kp ~= prof.kp then
        placeNote("|cFFFFD700" .. string.format(L.KP_TIER, curLine.kp) .. "|r", 18)
      end
    elseif prof.base then
      placeBar(prof.base.cur, prof.base.max, prof.name or "?", 12, function() ST.OpenProfession(prof) end)
      placeNote(L.OPEN_HINT, 18)
    else
      placeNote((prof.name or "?") .. "  " .. L.NO_DATA, 12)
    end
    if prof.kp and prof.kp > 0 then
      local txt = "|cFFFFD700" .. string.format(L.KP_UNSPENT, prof.kp) .. " " .. L.KP_LABEL .. "|r"
      local breakdown = KPBreakdown(prof)
      if breakdown then txt = txt .. "  |cFF888888(" .. breakdown .. ")|r" end
      placeNote(txt, 18)
    end
    if prof.isPrimary then
      local cn = ConcNote(prof)
      if cn then placeNote(cn, 18) end
      if prof.tree and (prof.tree.max or 0) > 0 then
        placeNote("|cFFBBBBBB" .. string.format(L.TREE_LINE, prof.tree.spent, prof.tree.max) .. "|r", 18)
      end
      if ST.WeeklyCount and rec then
        local done, total = ST.WeeklyCount(rec, prof.parent)
        if total > 0 then
          local c = (done >= total) and UI.C.OK or UI.C.GOLD
          placeNote(hex(c) .. string.format(L.WEEK_LINE, done, total) .. "|r", 18)
        end
      end
    end
  end

  if hasArch then
    local a = rec.archaeology
    placeNote("|cFFAAAAAA" .. L.ARCHAEOLOGY .. "|r", 6)
    placeBar(a.cur, a.max, a.name or L.ARCHAEOLOGY, 12)
  end
end

-- ================================================================
-- VUE "TOUTES LES EXTENSIONS" : une ligne par metier (moyenne + "X/N au
-- max"), depliable pour le detail par extension, ranges par extension
-- (Classic en haut, la plus recente en bas), libelle = nom du jeu.
-- ================================================================
local expandedProfs = {}

local function sortedLines(prof)
  local list = {}
  for id, ln in pairs(prof.lines or {}) do list[#list + 1] = { id = id, ln = ln, idx = ST.LineIndex(ln) } end
  table.sort(list, function(a, b)
    local ia, ib = a.idx or 99, b.idx or 99
    if ia ~= ib then return ia < ib end
    return a.id < b.id
  end)
  return list
end

local function renderProfessionAllExpansions(prof)
  local overall = ST.ProfessionOverallPercent(prof)
  local n, maxedN = ST.LineCounts(prof)
  local name = prof.name or "?"
  local isOpen = expandedProfs[name]
  local bar = placeBar(overall, 100, nil, 12, function()
    expandedProfs[name] = not isOpen
    ST.RefreshUI()
  end)
  local kpTag = (prof.kp and prof.kp > 0)
    and ("   |cFFFFD700" .. string.format(L.KP_UNSPENT, prof.kp) .. "|r") or ""
  local count = (n > 0) and ("   |cFF888888" .. maxedN .. "/" .. n .. " " .. L.MAXED_SHORT .. "|r") or ""
  bar._txt:SetText((isOpen and "- " or "+ ") .. accHex() .. name .. "|r   |cFFBBBBBB" .. overall .. "%|r"
    .. count .. kpTag)

  if isOpen then
    local hideMaxed = ST.settings.hideMaxed
    local shownAny = false
    for _, e in ipairs(sortedLines(prof)) do
      local ln = e.ln
      local pct = ST.Percent(ln.cur, ln.max)
      if not (hideMaxed and pct >= 100) then
        shownAny = true
        local sigle = ST.BucketMeta(e.idx or "other")
        local label = ST.LineLabel(ln)
        if sigle ~= "???" and sigle ~= label then label = label .. " |cFF888888" .. sigle .. "|r" end
        if ln.inferred then label = label .. " |cFF888888~|r" end
        local w = placeBar(ln.cur, ln.max, label, 24, nil, ln.inferred and function(tt)
          tt:AddLine(L.INFERRED_TT, 0.8, 0.85, 0.9, true)
        end or nil)
        PaintBar(w, (pct >= 100) and UI.C.OK or UI.C.GOLD, (pct >= 100) and 1.0 or 0.85)
      end
    end
    if not shownAny then placeNote(L.NO_DATA, 24) end
  end
end

local function renderAllExtensions(rec)
  local profs = profList(rec)
  if #profs == 0 then
    placeNote(L.NO_PROFESSIONS, 10)
    return
  end
  local hideMaxProf = ST.settings.hideMaxProf
  local shownAny = false
  for _, prof in ipairs(profs) do
    local n, maxedN = ST.LineCounts(prof)
    if not (hideMaxProf and n > 0 and maxedN == n) then
      shownAny = true
      renderProfessionAllExpansions(prof)
    end
  end
  if not shownAny then placeNote(L.NO_DATA, 10) end
end

-- ================================================================
-- FILTRE PERSONNAGES : liste flottante scrollable, groupee par royaume,
-- avec recherche. ENFANT de la fenetre principale (se masque avec elle).
-- ================================================================
local charFilter

local function BuildCharFilter()
  if charFilter then return charFilter end
  local f = CreateFrame("Frame", "SkillTrackerCharFilter", mainFrame, "BackdropTemplate")
  f:SetSize(262, 404)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:Hide()
  UI.SkinFrame(f, ACC, UI.C.PANEL)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOPLEFT", 10, -8)
  title:SetText(accHex() .. L.FILTER_TITLE .. "|r")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() f:Hide() end)

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
  ph:SetPoint("LEFT", 6, 0); ph:SetText(L.SEARCH_PH)

  local allB = UI.MakeButton(f, 62, 18, L.FILTER_ALL)
  allB:SetPoint("TOPLEFT", 10, -56)
  local noneB = UI.MakeButton(f, 62, 18, L.FILTER_NONE)
  noneB:SetPoint("LEFT", allB, "RIGHT", 6, 0)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -80)
  scroll:SetPoint("BOTTOMRIGHT", -28, 10)
  local scont = CreateFrame("Frame", nil, scroll)
  scont:SetSize(220, 10)
  scroll:SetScrollChild(scont)
  if UI.SkinScrollBar then UI.SkinScrollBar(scroll, ACC) end

  charFilter = { frame = f, content = scont, cb = {}, hdr = {}, title = title,
                 box = box, ph = ph, sel = nil, query = "", localOnly = false }

  local function rebuild()
    for _, w in ipairs(charFilter.cb) do w:Hide() end
    for _, w in ipairs(charFilter.hdr) do w:Hide() end
    local sel = charFilter.sel or {}
    local q   = charFilter.query or ""
    local order, byRealm, curRealm = {}, {}, (GetRealmName() or "")
    for _, c in ipairs(ST.BuildCharList()) do
      if (not (charFilter.localOnly and c.imported))
        and (q == "" or UI.Match((c.name or "") .. " " .. (c.realm or ""), q)) then
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
        cb.txt:SetText(hex(cc) .. (c.name or "?") .. "|r"
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
    if t then
      for _, c in ipairs(ST.BuildCharList()) do
        if not (charFilter.localOnly and c.imported) then t[c.key] = true end
      end
    end
    rebuild(); ST.RefreshUI()
  end)
  noneB:SetScript("OnClick", function()
    local t = charFilter.sel
    if t then for k in pairs(t) do t[k] = nil end end
    rebuild(); ST.RefreshUI()
  end)
  return charFilter
end

local function ToggleCharFilter(anchor, sel, titleText, localOnly)
  local cf = BuildCharFilter()
  if cf.frame:IsShown() and cf.sel == sel then cf.frame:Hide(); return end
  cf.sel = sel
  cf.localOnly = localOnly and true or false
  cf.query = ""
  if cf.box then cf.box:SetText("") end
  if cf.ph then cf.ph:Show() end
  if titleText and cf.title then cf.title:SetText(accHex() .. titleText .. "|r") end
  cf.rebuild()
  cf.frame:ClearAllPoints()
  cf.frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  cf.frame:Show()
end

local function placeCharFilter(chars, sel, titleText, label, localOnly)
  local nSel = 0
  for _, c in ipairs(chars) do if sel[c.key] then nSel = nSel + 1 end end
  local b = acquireHeaderRow()
  b:ClearAllPoints(); b:SetPoint("TOPLEFT", content, "TOPLEFT", 4, Y); b:SetWidth(292)
  b._label:SetText(accHex() .. label .. "|r  |cFFCCCCCC(" .. nSel
    .. ")|r   |cFF888888" .. L.FILTER_CLICK .. "|r")
  b:SetScript("OnClick", function(s) ToggleCharFilter(s, sel, titleText, localOnly) end)
  line(26)
end

-- Purge des cles disparues + preselection (perso courant, ou tous si allByDefault).
local function PrepareSelection(sel, chars, initFlag, allByDefault)
  local live = {}
  for _, c in ipairs(chars) do live[c.key] = true end
  for k in pairs(sel) do if not live[k] then sel[k] = nil end end
  if initFlag and not ST.settings[initFlag] then
    ST.settings[initFlag] = true
    if next(sel) == nil then
      for _, c in ipairs(chars) do
        if allByDefault or c.current then sel[c.key] = true end
      end
    end
  end
  if next(sel) == nil then
    for _, c in ipairs(chars) do if c.current then sel[c.key] = true; break end end
    if next(sel) == nil and chars[1] then sel[chars[1].key] = true end
  end
end

-- ================================================================
-- VUE "COMPTE" : un bloc par perso coche
-- ================================================================
local function renderCharSummary(c)
  local rec = c.rec
  local cc  = ClassColor(c.class)
  placeHeader(hex(cc) .. (c.name or "?") .. "|r  |cFF888888" .. (c.realm or "")
    .. (c.imported and ("  (" .. L.IMPORTED_TAG .. ")") or "") .. "|r", 6)

  local profs = profList(rec)
  if #profs == 0 then
    placeNote(L.NO_PROFESSIONS, 16)
    return
  end
  for _, prof in ipairs(profs) do
    local ln = ST.CurrentLine(prof)
    local cur, max
    if ln then cur, max = ln.cur, ln.max
    elseif prof.base and (prof.base.max or 0) > 0 then cur, max = prof.base.cur or 0, prof.base.max
    else cur, max = ST.ProfessionOverallPercent(prof), 100 end
    placeBar(cur, max, prof.name or "?", 16)
    if prof.isPrimary then
      local cn = ConcNote(prof)
      if cn then placeNote(cn, 22) end
    end
  end
  if rec and rec.archaeology then
    local a = rec.archaeology
    placeBar(a.cur, a.max, a.name or L.ARCHAEOLOGY, 16)
  end
end

local function renderAccount(chars)
  if #chars == 0 then placeNote(L.NO_DATA, 8) return end
  ST.settings.viewChars = ST.settings.viewChars or {}
  local selV = ST.settings.viewChars
  PrepareSelection(selV, chars, nil, false)
  placeNote("|cFFAAAAAA" .. L.PICK_CHARS .. "|r", 6)
  placeCharFilter(chars, selV, L.FILTER_TITLE_CHARS, L.FILTER_CHARS)
  local shownAny = false
  for _, c in ipairs(chars) do
    if selV[c.key] then shownAny = true; renderCharSummary(c) end
  end
  if not shownAny then placeNote(L.NO_DATA, 8) end
end

-- ================================================================
-- VUE "CONCENTRATION" : tous les metiers principaux de tous les persos
-- locaux, projetes a l'instant present, les plus urgents en tete.
-- ================================================================
local function renderConc()
  local rate = ST.ConcRate and ST.ConcRate()
  if rate then
    placeNote("|cFFAAAAAA" .. string.format(L.CONC_RATE_KNOWN, ST.FormatDuration(1 / rate)) .. "|r", 6)
  else
    placeNote("|cFFAAAAAA" .. L.CONC_RATE_UNKNOWN .. "|r", 6)
  end
  local list = ST.ConcList and ST.ConcList() or {}
  if #list == 0 then
    placeNote(L.CONC_NONE, 8)
    return
  end
  for _, e in ipairs(list) do
    local pr = e.pr
    local cc = ClassColor(e.class)
    local w = placeBar(pr.cur, pr.max, nil, 6, nil, function(tt)
      tt:AddLine(hex(cc) .. e.name .. "|r  |cFF888888" .. e.realm .. "|r")
      tt:AddLine(e.prof, 0.9, 0.9, 0.9)
      local prof = ST.db.chars[e.realm] and ST.db.chars[e.realm][e.name]
      prof = prof and prof.professions and prof.professions[e.parent]
      if prof and prof.conc then
        tt:AddLine(string.format(L.CONC_LAST_READ, prof.conc.cur, prof.conc.max,
          ST.FormatDuration(pr.age)), 0.7, 0.75, 0.82, true)
      end
      if not pr.hasRate then tt:AddLine(L.CONC_RATE_UNKNOWN, 0.6, 0.6, 0.65, true) end
    end)
    local status = ST.ConcStatusText(pr)
    w._txt:SetText(hex(cc) .. e.name .. "|r " .. (e.current and ("|cFF888888" .. L.CURRENT_TAG .. "|r ") or "")
      .. "|cFFDDDDDD" .. e.prof .. "|r   " .. pr.cur .. "/" .. pr.max
      .. "   " .. (pr.full and hex(UI.C.WARN) or "|cFF999999") .. status .. "|r")
    if pr.full then PaintBar(w, UI.C.WARN, 0.9) end
  end
end

-- ================================================================
-- VUE "SEMAINE" : sources de connaissances par perso et metier principal
-- ================================================================
local SRC_COLORS = {
  quest = { 1.00, 0.84, 0.00 }, treatise = { 0.55, 0.75, 0.95 },
  drops = { 0.40, 0.85, 0.54 }, dmf = { 0.85, 0.45, 0.95 },
}

local function renderWeek(chars)
  local locals = {}
  for _, c in ipairs(chars) do
    if not c.imported then
      local hasPrimary = false
      for _, p in pairs(c.rec.professions or {}) do if p.isPrimary then hasPrimary = true break end end
      if hasPrimary then locals[#locals + 1] = c end
    end
  end
  local left = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
  placeNote("|cFFAAAAAA" .. L.WEEK_INTRO .. "|r"
    .. (left and ("  |cFF888888" .. string.format(L.WEEK_RESET_IN, ST.FormatDuration(left)) .. "|r") or ""), 6)
  if #locals == 0 then placeNote(L.NO_DATA, 8) return end

  ST.settings.weekChars = ST.settings.weekChars or {}
  local sel = ST.settings.weekChars
  PrepareSelection(sel, locals, "weekInit", true)
  placeCharFilter(locals, sel, L.FILTER_TITLE_WEEK, L.FILTER_CHARS, true)

  local dmfActive = ST.DarkmoonState and ST.DarkmoonState()
  for _, c in ipairs(locals) do
    if sel[c.key] then
      local rec = c.rec
      local cc = ClassColor(c.class)
      placeHeader(hex(cc) .. c.name .. "|r  |cFF888888" .. (c.realm or "") .. "|r", 6)
      for _, prof in ipairs(profList(rec)) do
        if prof.isPrimary then
          local parent = prof.parent
          local done, total = ST.WeeklyCount(rec, parent)
          local col = (done >= total) and UI.C.OK or UI.C.GOLD
          placeNote("|cFFDDDDDD" .. (prof.name or "?") .. "|r  " .. hex(col) .. done .. "/" .. total .. "|r", 12)
          local items = {}
          for _, src in ipairs(ST.KNOW_SOURCES) do
            local st = ST.WeeklyState(rec, parent, src.key)
            local auto = ST.SourceIDs(parent, src.key) ~= nil
            local text = L["SRC_" .. src.key:upper()]
            local key = src.key
            items[#items + 1] = {
              text = text, color = SRC_COLORS[key],
              state = (st == "done") and "on" or ((st == "closed") and "dim" or "off"),
              onClick = (st ~= "closed") and function()
                ST.ToggleWeekly(rec, parent, key); ST.RefreshUI()
              end or nil,
              tip = function(tt)
                tt:AddLine(text, SRC_COLORS[key][1], SRC_COLORS[key][2], SRC_COLORS[key][3])
                tt:AddLine(L["SRC_" .. key:upper() .. "_TT"], 0.85, 0.85, 0.9, true)
                if st == "closed" then
                  tt:AddLine(L.WEEK_DMF_CLOSED, 0.6, 0.6, 0.65, true)
                else
                  tt:AddLine(st == "done" and L.WEEK_DONE or L.WEEK_TODO,
                    st == "done" and 0.4 or 1, st == "done" and 0.85 or 0.7, 0.4)
                  tt:AddLine(auto and L.WEEK_AUTO or L.WEEK_MANUAL, 0.6, 0.6, 0.65, true)
                  tt:AddLine(L.WEEK_CLICK, 0.55, 0.55, 0.6)
                end
              end,
            }
          end
          placeChips(items, 18, 44, 110)
        end
      end
    end
  end
  if not dmfActive then placeNote("|cFF777777" .. L.WEEK_DMF_NOTE .. "|r", 6) end
end

-- ================================================================
-- VUE "RECETTES" : qui sait crafter ca ? (donnees : Recipes.lua)
-- Le champ de recherche est un widget unique (hors pool), masque par
-- RefreshUI dans les autres vues.
-- ================================================================
local recipeBox

local function placeRecipeBox()
  if not recipeBox then
    local box = CreateFrame("EditBox", nil, content, "BackdropTemplate")
    box:SetSize(292, 24)
    box:SetBackdrop(UI.FlatBackdrop())
    box:SetBackdropColor(0.02, 0.01, 0.04, 0.95)
    box:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 0.8)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(6, 20, 0, 0)
    local mag = box:CreateTexture(nil, "OVERLAY")
    mag:SetSize(12, 12); mag:SetPoint("RIGHT", -5, 0)
    mag:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    local ph = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 6, 0); ph:SetText(L.RECIPE_SEARCH_PH)
    box._ph = ph
    box:SetScript("OnTextChanged", function(self, userInput)
      ph:SetShown(self:GetText() == "")
      if not userInput then return end
      ST.runtime.recipeQuery = self:GetText() or ""
      ST.RefreshUI()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    recipeBox = box
  end
  local q = ST.runtime.recipeQuery or ""
  if recipeBox:GetText() ~= q then recipeBox:SetText(q) end
  recipeBox._ph:SetShown(q == "")
  recipeBox:ClearAllPoints()
  recipeBox:SetPoint("TOPLEFT", content, "TOPLEFT", 4, Y)
  recipeBox:Show()
  line(30)
end

local function renderRecipes()
  if not ST.settings.recipes then
    placeNote(L.RECIPE_DISABLED, 6)
    return
  end
  placeRecipeBox()
  local q = UI.Normalize(ST.runtime.recipeQuery or "")
  if #q < 2 then
    local nU, nC, per = ST.RecipeTotals()
    placeNote("|cFFAAAAAA" .. string.format(L.RECIPE_INTRO, nU, nC) .. "|r", 6)
    placeNote("|cFF888888" .. L.RECIPE_HOWTO .. "|r", 6)
    for _, c in ipairs(per) do
      placeNote(hex(ClassColor(c.class)) .. c.name .. "|r  |cFF888888" .. (c.realm or "") .. "|r  "
        .. string.format(L.RECIPE_COUNT, c.n), 12)
    end
    return
  end
  local list, total = ST.RecipeSearch(q, 40)
  if total == 0 then
    placeNote(L.RECIPE_NONE, 8)
    return
  end
  for _, r in ipairs(list) do
    local knowsIt = false
    for _, ow in ipairs(r.owners) do if ow.current then knowsIt = true break end end
    local w = acquireHeaderRow()
    w:ClearAllPoints()
    w:SetPoint("TOPLEFT", content, "TOPLEFT", 4, Y)
    w:SetWidth(292)
    w._label:SetText((r.icon and ("|T" .. r.icon .. ":14|t ") or "") .. accHex() .. r.name .. "|r")
    w:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      ST.runtime.inRecipeTip = true
      if r.item then pcall(GameTooltip.SetItemByID, GameTooltip, r.item) else GameTooltip:AddLine(r.name) end
      ST.runtime.inRecipeTip = nil
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(L.RECIPE_KNOWN_BY, ACC[1], ACC[2], ACC[3])
      GameTooltip:AddLine(ST.OwnersText(r.owners, 10), 1, 1, 1, true)
      if knowsIt then GameTooltip:AddLine(L.RECIPE_CLICK_OPEN, 0.55, 0.55, 0.6) end
      if r.item then GameTooltip:AddLine(L.RECIPE_SHIFT_LINK, 0.55, 0.55, 0.6) end
      GameTooltip:Show()
    end)
    w:SetScript("OnLeave", function() GameTooltip:Hide() end)
    w:SetScript("OnClick", function()
      if IsShiftKeyDown() and r.item then
        local link = C_Item and C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(r.item))
        if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        return
      end
      if knowsIt and C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then
        pcall(C_TradeSkillUI.OpenRecipe, r.id)
      end
    end)
    line(24)
    placeNote(ST.OwnersText(r.owners, 4), 14)
  end
  if total > #list then placeNote("|cFF888888" .. string.format(L.RECIPE_MORE, total - #list) .. "|r", 8) end
end

-- ================================================================
-- LISTE "A FINIR"
-- ================================================================
local function placeExtFilterChips(buckets, sel)
  local anySel = next(sel) ~= nil
  local items = {}
  for _, bucket in ipairs(buckets) do
    local label, full, c = ST.BucketMeta(bucket)
    items[#items + 1] = {
      text = label, color = c,
      state = ((not anySel) or sel[bucket]) and "on" or "off",
      onClick = function() sel[bucket] = (not sel[bucket]) or nil; ST.RefreshUI() end,
      tip = function(tt) tt:AddLine(full, c[1], c[2], c[3]) end,
    }
  end
  placeChips(items, 4, 44, 90)
  line(4)
end

local function renderTodo(allChars)
  line(6)
  local todoAll = ST.BuildTodo()
  ST.settings.todoChars = ST.settings.todoChars or {}
  local sel = ST.settings.todoChars
  PrepareSelection(sel, allChars, "todoInit", false)

  local todoByChar = {}
  for _, t in ipairs(todoAll) do
    if sel[(t.realm or "") .. "\t" .. (t.char or "")] then todoByChar[#todoByChar + 1] = t end
  end

  ST.settings.todoExtFilter = ST.settings.todoExtFilter or {}
  local extSel = ST.settings.todoExtFilter
  local bucketSeen, buckets = {}, {}
  for _, t in ipairs(todoByChar) do
    local b = t.idx or "other"
    if not bucketSeen[b] then bucketSeen[b] = true; buckets[#buckets + 1] = b end
  end
  table.sort(buckets, function(a, b)
    return ((a == "other") and -1 or a) > ((b == "other") and -1 or b)
  end)
  for b in pairs(extSel) do if not bucketSeen[b] then extSel[b] = nil end end

  local todo = {}
  local anyExtSel = next(extSel) ~= nil
  for _, t in ipairs(todoByChar) do
    if (not anyExtSel) or extSel[t.idx or "other"] then todo[#todo + 1] = t end
  end

  placeHeader(accHex() .. L.TODO_TITLE .. "|r"
    .. "  |cFF888888" .. string.format(#todo == 1 and L.TODO_COUNT_ONE or L.TODO_COUNT_MANY, #todo) .. "|r", 4)
  placeCharFilter(allChars, sel, L.FILTER_TITLE_TODO, L.FILTER_TRACKED)

  if #buckets > 1 then
    placeNote("|cFFAAAAAA" .. L.TODO_EXT_FILTER .. "|r", 6)
    placeExtFilterChips(buckets, extSel)
  end

  if #todo == 0 then
    placeNote("|cFF66FF98" .. L.TODO_NONE .. "|r", 8)
    return
  end
  local nShown = 0; for _ in pairs(sel) do nShown = nShown + 1 end
  local hideName = (nShown == 1)
  for _, t in ipairs(todo) do
    local suffix = " |cFF888888" .. (ST.BucketMeta(t.idx or "other") or "")
      .. (hideName and "" or (" " .. (t.char or ""))) .. "|r"
    placeBar(t.cur, t.max, (t.prof or "?") .. suffix, 12)
  end
end

-- ================================================================
-- RAFRAICHISSEMENT
-- ================================================================
function ST.RefreshUI()
  if not mainFrame or not mainFrame:IsShown() then return end
  resetPools()
  if recipeBox then recipeBox:Hide() end
  Y = yTop

  local rec = ST.CurrentRec()
  local chars = ST.BuildCharList()

  placeHeader(UI.CharBannerText(), 4)
  placeMetierViewSwitch()

  local v = ST.settings.metierView or "current"
  if v == "current" then renderCurrentExtension(rec)
  elseif v == "all" then renderAllExtensions(rec)
  elseif v == "account" then renderAccount(chars)
  elseif v == "conc" then renderConc()
  elseif v == "week" then renderWeek(chars)
  elseif v == "recipes" then renderRecipes()
  end

  -- La liste "A finir" accompagne les vues de progression, pas Concentration / Semaine.
  if ST.settings.showTodo and (v == "current" or v == "all" or v == "account") then
    renderTodo(chars)
  end

  local contentH = math.max(-Y + 10, 10)
  content:SetHeight(contentH)
  UI.FitHeight(mainFrame, contentH, { chrome = 64, min = 300 })
  if charFilter and charFilter.frame:IsShown() then charFilter.rebuild() end
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

  -- Echap via UISpecialFrames, SANS hook OnHide (voir en-tete et CLAUDE.md).
  tinsert(UISpecialFrames, "SkillTrackerMainFrame")
  f:Hide()

  UI.SkinFrame(f, ACC, UI.C.BG)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -14)
  title:SetText(accHex() .. L.TITLE .. "|r")

  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("TOP", title, "BOTTOM", 0, -2)
  sub:SetText(L.PANEL_SUBTITLE)

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
  if UI.SkinScrollBar then UI.SkinScrollBar(scroll, ACC) end

  f:SetScript("OnShow", function() ST.RequestScan(0.05); ST.RefreshUI() end)
end

-- Ouvre la fenetre officielle du metier (depuis un clic : evenement materiel).
function ST.OpenProfession(prof)
  if not prof then return end
  if C_TradeSkillUI and type(C_TradeSkillUI.OpenTradeSkill) == "function" and prof.parent then
    if pcall(C_TradeSkillUI.OpenTradeSkill, prof.parent) then return end
  end
  if prof.name and type(CastSpellByName) == "function" then
    pcall(CastSpellByName, prof.name)
  end
end

function ST.Toggle(forceShow)
  if ST.settings and ST.settings.enabled == false then
    print(ST.TAG .. " " .. L.OPT_ENABLED .. " : |cFFFF7777off|r  (/skt config)")
    return
  end
  BuildMainFrame()
  if forceShow then
    if mainFrame:IsShown() then ST.RefreshUI() else mainFrame:Show() end
    return
  end
  if mainFrame:IsShown() then mainFrame:Hide() else mainFrame:Show() end
end

-- ================================================================
-- TOOLTIP RESUME (bouton minimap + objet LibDataBroker)
-- ================================================================
function ST.FillSummaryTooltip(tt)
  tt:AddLine(ST.TAG)
  local rec = ST.CurrentRec()
  local any = false
  if rec and type(rec.professions) == "table" then
    for _, p in ipairs(profList(rec)) do
      any = true
      tt:AddDoubleLine(p.name or "?", ST.ProfessionOverallPercent(p) .. "%",
        0.9, 0.9, 0.9, ACC[1], ACC[2], ACC[3])
      local pr = p.isPrimary and ST.ConcProject and ST.ConcProject(p)
      if pr then
        local c = pr.full and UI.C.WARN or UI.C.OK
        tt:AddDoubleLine("   " .. L.CONCENTRATION, pr.cur .. "/" .. pr.max .. "  " .. ST.ConcStatusText(pr),
          0.6, 0.6, 0.65, c[1], c[2], c[3])
      end
      if p.kp and p.kp > 0 then
        tt:AddDoubleLine("   " .. L.KP_LABEL, string.format(L.KP_UNSPENT, p.kp), 0.6, 0.6, 0.65, 1.0, 0.84, 0.0)
      end
    end
    if rec.archaeology then
      any = true
      tt:AddDoubleLine(L.ARCHAEOLOGY, ST.Percent(rec.archaeology.cur, rec.archaeology.max) .. "%",
        0.9, 0.9, 0.9, ACC[1], ACC[2], ACC[3])
    end
  end
  if not any then tt:AddLine(L.NO_PROFESSIONS, 0.7, 0.7, 0.7) end
  tt:AddLine(" ")
  local nFull = ST.ConcFullCount and ST.ConcFullCount() or 0
  if nFull > 0 then
    local c = UI.C.WARN
    tt:AddLine(string.format(L.CONC_FULL_COUNT, nFull), c[1], c[2], c[3])
  end
  local todo = ST.BuildTodo()
  tt:AddLine(string.format(#todo == 1 and L.TODO_COUNT_ONE or L.TODO_COUNT_MANY, #todo), 0.7, 0.75, 0.82)
  tt:AddLine(L.TT_LEFT, 0.55, 0.55, 0.6)
  tt:AddLine(L.TT_RIGHT, 0.55, 0.55, 0.6)
end

-- ================================================================
-- BOUTON MINIMAP (mode autonome ; masque par la glue en mode suite)
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
-- EXPORT / IMPORT : petite fenetre a zone de saisie (une ligne)
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
    box:SetMaxLetters(0)
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
      if onAccept then onAccept(s:GetText(), p._msg) end
    end)
  else
    box:SetScript("OnEnterPressed", function(s) s:HighlightText() end)
  end
  p:Show()
  box:SetFocus()
  if not editable then box:HighlightText() end
end

local function DoExport()
  local s = ST.ExportString()
  if not s then
    print(ST.TAG .. " " .. L.EXPORT_EMPTY)
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
-- PANNEAU D'OPTIONS
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

  optPanel:Section(L.OPT_CONC)
  optPanel:Check(L.OPT_CONC_ALERT,
    function() return ST.settings.concAlert end,
    function(v) ST.settings.concAlert = v end)
  optPanel:Check(L.OPT_CONC_ALT_ALERT,
    function() return ST.settings.concAltAlert end,
    function(v) ST.settings.concAltAlert = v end, L.OPT_CONC_ALT_ALERT_TT)
  optPanel:Check(L.OPT_BADGE,
    function() return ST.settings.badge end,
    function(v) ST.settings.badge = v; ST.UpdateBadge() end, L.OPT_BADGE_TT)
  optPanel:Button(L.OPT_CONC_RESET, function()
    ST.db.concRate = {}
    print(ST.TAG .. " " .. L.CONC_RATE_RESET)
    ST.RefreshUI(); ST.UpdateBadge()
  end)

  optPanel:Section(L.OPT_RECIPES)
  optPanel:Check(L.OPT_RECIPES_ON,
    function() return ST.settings.recipes end,
    function(v) ST.settings.recipes = v; ST.RefreshUI() end, L.OPT_RECIPES_ON_TT)
  optPanel:Check(L.OPT_RECIPES_ALL,
    function() return ST.settings.recipeScope == "all" end,
    function(v) ST.settings.recipeScope = v and "all" or "current" end, L.OPT_RECIPES_ALL_TT)
  optPanel:Check(L.OPT_RECIPES_TT,
    function() return ST.settings.recipeTooltip end,
    function(v) ST.settings.recipeTooltip = v end)
  optPanel:Button(L.OPT_RECIPES_WIPE, function()
    ST.WipeRecipes()
    print(ST.TAG .. " " .. L.RECIPES_WIPED)
    ST.RefreshUI()
  end)

  optPanel:Button(L.OPT_RESCAN, function() ST.RequestScan(0.1) end)

  optPanel:Section(L.OPT_DATA)
  optPanel:Note(L.MULTIACC_NOTE)
  optPanel:Button(L.OPT_EXPORT, DoExport)
  optPanel:Button(L.OPT_IMPORT, DoImport)
  optPanel:Button(L.OPT_WIPE_CHAR, function() ST.WipeCurrentChar() end)
end

function ST.OpenOptions()
  BuildOptions()
  optPanel:Toggle()
end

-- ================================================================
-- HOOKS D'INITIALISATION (appeles depuis Core.lua)
-- ================================================================
function ST.OnDBReady() end

function ST.OnPlayerLogin()
  BuildMinimapButton()
end
