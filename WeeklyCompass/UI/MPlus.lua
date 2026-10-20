local addonName, ns = ...
local L = ns.L

-- ===========================================================================
-- Fenetre Mythique+ de tous les personnages (7.3, lot E).
-- Une ligne par perso (tries par cote) : cote, cle en poche, courses de la
-- semaine et prochain emplacement du Grand coffre, puis la meilleure cle de
-- la saison par donjon (vert = dans les temps, orange = hors temps). La case
-- du donjon de la cle en poche est encadree quand la cle bat la meilleure.
-- Donnees : WeeklyCompassAPI.GetMPlusRoster() (fiches sheet:data.mplus).
-- Ouverture : onglet « Mythique+ » de la fenetre, /wc cles, openTo("mplus").
-- Mode double : socle TibiMidnight seulement, aucun appel au core.
-- NON TESTE EN JEU (nouveau fichier : redemarrage complet du client).
-- ===========================================================================

local ACCENT = { 0.039, 1.000, 0.745 }
local GREEN  = { 0.42, 0.85, 0.48 }
local ORANGE = { 1.00, 0.70, 0.30 }
local GREY   = { 0.55, 0.55, 0.58 }
local PAD, ROW_H, HEAD_H = 14, 26, 86
local NAME_W, SCORE_W, KEY_W, WEEK_W, MAP_W = 150, 60, 150, 110, 46
local MAX_ROWS = 14

local frame
local rows, heads, fixedFs = {}, {}, {}

local function classRGB(token)
    local t = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if t then return t.r, t.g, t.b end
    return 0.9, 0.9, 0.9
end

-- Abreviation d'un nom de donjon : initiales des mots de 3 lettres et plus.
local function Short(name)
    name = tostring(name or "?")
    local s = ""
    for w in name:gmatch("[^%s%-']+") do
        if #w >= 3 then s = s .. w:sub(1, 1):upper() end
    end
    if #s < 2 then s = name:sub(1, 3) end
    return s:sub(1, 4)
end

local function Text(parent, font, col)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    if col then fs:SetTextColor(col[1], col[2], col[3]) end
    return fs
end

local function Build()
    if frame then return frame end
    local UI = _G.TibiMidnight
    frame = CreateFrame("Frame", "WeeklyCompassMPlusFrame", UIParent, "BackdropTemplate")
    frame:SetSize(700, 300)
    frame:SetPoint("CENTER", 0, 40)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if UI and UI.SkinFrame then UI.SkinFrame(frame, ACCENT)
    else
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        frame:SetBackdropColor(0.05, 0.05, 0.07, 0.96); frame:SetBackdropBorderColor(0, 0, 0, 1)
    end
    table.insert(UISpecialFrames, "WeeklyCompassMPlusFrame")
    frame.title = Text(frame, "GameFontNormalLarge", ACCENT)
    frame.title:SetPoint("TOPLEFT", PAD, -12)
    frame.title:SetText(L["MP_TITLE"])
    frame.sub = Text(frame, "GameFontHighlightSmall", GREY)
    frame.sub:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
    frame.sub:SetText(L["MP_SUB"])
    local close = UI and UI.MakeButton and UI.MakeButton(frame, 22, 22, "X") or CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function() frame:Hide() end)
    frame.empty = Text(frame, "GameFontHighlight", GREY)
    frame.empty:SetPoint("TOPLEFT", PAD, -HEAD_H)
    frame.empty:SetText(L["MP_EMPTY"])
    frame.note = Text(frame, "GameFontDisableSmall", GREY)
    frame.note:SetJustifyH("LEFT")
    frame.note:SetText(L["MP_NOTE"])
    frame:Hide()
    return frame
end

local function Cell(row, i)
    row.cells = row.cells or {}
    local c = row.cells[i]
    if c then return c end
    c = CreateFrame("Frame", nil, row)
    c:SetSize(MAP_W - 4, ROW_H - 6)
    c.bg = c:CreateTexture(nil, "BACKGROUND"); c.bg:SetAllPoints()
    c.edge = c:CreateTexture(nil, "BORDER"); c.edge:SetPoint("TOPLEFT", -1, 1); c.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    c.edge:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)
    c.fs = Text(c, "GameFontHighlightSmall"); c.fs:SetPoint("CENTER")
    row.cells[i] = c
    return c
end

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, frame)
    r:SetHeight(ROW_H)
    r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.015)
    r.name = Text(r, "GameFontHighlight"); r.name:SetPoint("LEFT", 6, 0); r.name:SetWidth(NAME_W - 8)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.score = Text(r, "GameFontHighlight"); r.score:SetPoint("LEFT", NAME_W, 0); r.score:SetWidth(SCORE_W)
    r.key = Text(r, "GameFontHighlightSmall"); r.key:SetPoint("LEFT", NAME_W + SCORE_W, 0); r.key:SetWidth(KEY_W - 6)
    r.key:SetJustifyH("LEFT"); r.key:SetWordWrap(false)
    r.week = Text(r, "GameFontHighlightSmall"); r.week:SetPoint("LEFT", NAME_W + SCORE_W + KEY_W, 0); r.week:SetWidth(WEEK_W - 6)
    r.week:SetJustifyH("LEFT")
    rows[i] = r
    return r
end

local function Head(i)
    local h = heads[i]
    if h then return h end
    h = CreateFrame("Frame", nil, frame)
    h:SetSize(MAP_W, 18)
    h.fs = Text(h, "GameFontNormalSmall", GREY); h.fs:SetPoint("CENTER")
    h:EnableMouse(true)
    h:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:AddLine(s.full or "", 1, 1, 1); GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
    heads[i] = h
    return h
end

local function Refresh()
    if not (frame and frame:IsShown()) then return end
    local ok, data = pcall(WeeklyCompassAPI.GetMPlusRoster)
    if not ok or type(data) ~= "table" then data = { chars = {}, maps = {} } end
    local maps = data.maps or {}
    local x0 = PAD + NAME_W + SCORE_W + KEY_W + WEEK_W
    local w = x0 + #maps * MAP_W + PAD
    frame:SetWidth(math.max(560, w))
    -- En-tetes
    local top = -HEAD_H + 22
    local fixed = { { L["MP_COL_CHAR"], 0 }, { L["MP_COL_SCORE"], NAME_W }, { L["MP_COL_KEY"], NAME_W + SCORE_W },
                    { L["MP_COL_WEEK"], NAME_W + SCORE_W + KEY_W } }
    for i, f in ipairs(fixed) do
        local fs = fixedFs[i] or Text(frame, "GameFontNormalSmall", GREY)
        fixedFs[i] = fs
        fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", PAD + f[2] + 6, top); fs:SetText(f[1])
    end
    for _, h in ipairs(heads) do h:Hide() end
    for i, m in ipairs(maps) do
        local h = Head(i)
        h.full = m.name
        h.fs:SetText(Short(m.name))
        h:ClearAllPoints(); h:SetPoint("TOPLEFT", x0 + (i - 1) * MAP_W, top + 3); h:Show()
    end
    -- Lignes
    for _, r in ipairs(rows) do r:Hide() end
    local y = -HEAD_H
    for i, c in ipairs(data.chars) do
        if i > MAX_ROWS then break end
        local r = Row(i)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", PAD, y); r:SetWidth(w - 2 * PAD)
        r.name:SetText(c.name or "?"); r.name:SetTextColor(classRGB(c.class))
        r.score:SetText(c.score and tostring(math.floor(c.score + 0.5)) or "-")
        if c.keyLevel then
            local txt = "+" .. c.keyLevel .. " " .. tostring(c.keyName or "?")
            if c.stale then txt = "|cFF8C8C94" .. txt .. " (" .. L["MP_STALE"] .. ")|r"
            elseif c.improves then txt = "|cFF0AFFBE" .. txt .. "|r" end
            r.key:SetText(txt)
        else
            r.key:SetText("|cFF8C8C94" .. L["MP_NOKEY"] .. "|r")
        end
        local wk = string.format(L["MP_RUNS_FMT"], c.weekRuns or 0)
        if c.nextVault then wk = wk .. "  |cFFFFB34D" .. string.format(L["MP_NEXT_FMT"], c.nextVault) .. "|r"
        else wk = wk .. "  |cFF6BD97A" .. L["MP_VAULT_FULL"] .. "|r" end
        r.week:SetText(wk)
        for _, cell in ipairs(r.cells or {}) do cell:Hide() end
        for j, m in ipairs(maps) do
            local cell = Cell(r, j)
            cell:ClearAllPoints(); cell:SetPoint("LEFT", r, "LEFT", x0 - PAD + (j - 1) * MAP_W + 2, 0)
            local b = c.best[m.map]
            if b and b.level then
                local col = b.timed and GREEN or ORANGE
                cell.fs:SetText("+" .. b.level); cell.fs:SetTextColor(col[1], col[2], col[3])
                cell.bg:SetColorTexture(col[1], col[2], col[3], 0.12)
            else
                cell.fs:SetText("-"); cell.fs:SetTextColor(GREY[1], GREY[2], GREY[3])
                cell.bg:SetColorTexture(1, 1, 1, 0.02)
            end
            cell.edge:SetShown(c.improves and not c.stale and c.keyMap == m.map)
            cell:Show()
        end
        r:Show()
        y = y - ROW_H
    end
    frame.empty:SetShown(#data.chars == 0)
    if #data.chars == 0 then y = y - 30 end
    frame.note:ClearAllPoints(); frame.note:SetPoint("TOPLEFT", PAD, y - 8); frame.note:SetWidth(frame:GetWidth() - 2 * PAD)
    frame:SetHeight(-y + 8 + (frame.note:GetStringHeight() or 24) + PAD)
end

function ns.MPlusShow()
    Build()
    frame:Show()
    Refresh()
end

function ns.MPlusToggle()
    if frame and frame:IsShown() then frame:Hide() else ns.MPlusShow() end
end
