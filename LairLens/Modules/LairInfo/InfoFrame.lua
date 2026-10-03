-- =============================================================================
-- LairLens - Modules/LairInfo/InfoFrame.lua  (7.1.5.37)
-- Fiche du Repaire : entree (point sur la carte, DgnTracker, Journal), etat de
-- la semaine par difficulte (ilvl recommande, ilvl du butin, Ecu de brume),
-- butin de la difficulte choisie filtre pour ta specialisation (Journal des
-- rencontres du client), hauts faits du Repaire, et tes records.
-- Construite paresseusement a la premiere ouverture.
-- NON TESTE EN JEU : a valider par Tibiscui avec un /reload (nouveau fichier :
-- redemarrage complet du client la premiere fois).
-- =============================================================================

local ADDON, LL = ...
local C = LL.const
local U = LL.util
local D = LL.Data

local Info = {}
LL:RegisterModule("lairInfo", Info)

local frame, content
local fsPool, btnPool, itemPool = {}, {}, {}
local fsUsed, btnUsed, itemUsed = 0, 0, 0
local allSpecs = false
-- Cache du butin : on n'interroge le journal que si la liste est vide ou
-- incomplete (objets pas encore charges par le client). Evite une boucle
-- EJ_LOOT_DATA_RECIEVED -> rafraichissement -> nouvelle requete.
local lootCache = {}
local ejRefreshes = 0

local DIFF_LABEL = {
    [C.DIFF.WORLD] = "DIFF_WORLD", [C.DIFF.NORMAL] = "DIFF_NORMAL",
    [C.DIFF.HEROIC] = "DIFF_HEROIC", [C.DIFF.MYTHIC] = "DIFF_MYTHIC",
}
local DIFF_COLOR = {
    [C.DIFF.WORLD]  = { 0.30, 0.90, 0.30 },
    [C.DIFF.NORMAL] = { 0.35, 0.65, 1.00 },
    [C.DIFF.HEROIC] = { 0.70, 0.40, 1.00 },
    [C.DIFF.MYTHIC] = { 1.00, 0.50, 0.00 },
}

local function lairKey()
    local ctx = LL.Detection and LL.Detection:GetContext()
    return (ctx and ctx.instanceKey) or D:GetSingleLair() or "tidebound_grotto"
end

-- --- Pools de widgets (reconstruction a chaque rafraichissement) ---------------
local function resetPools()
    for i = 1, fsUsed do fsPool[i]:Hide() end
    for i = 1, btnUsed do btnPool[i]:Hide() end
    for i = 1, itemUsed do itemPool[i]:Hide() end
    fsUsed, btnUsed, itemUsed = 0, 0, 0
end

local function text(x, y, str, font, color, width, justify)
    fsUsed = fsUsed + 1
    local fs = fsPool[fsUsed]
    if not fs then
        fs = content:CreateFontString(nil, "OVERLAY")
        fsPool[fsUsed] = fs
    end
    fs:SetFontObject(font or "GameFontHighlightSmall")
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    fs:SetWidth(width or 0)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(str or "")
    U.SetTextColor(fs, color or C.COLOR.TEXT)
    fs:Show()
    return fs
end

local function button(x, y, label, onClick, tooltip)
    btnUsed = btnUsed + 1
    local b = btnPool[btnUsed]
    if not b then
        b = CreateFrame("Button", nil, content, "BackdropTemplate")
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        b:SetBackdropColor(0.10, 0.11, 0.14, 0.95)
        b:SetBackdropBorderColor(0, 0, 0, 1)
        b._fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b._fs:SetPoint("CENTER")
        b:SetScript("OnEnter", function(s)
            s:SetBackdropBorderColor(1, 1, 1, 0.6)
            if s._tt then
                GameTooltip:SetOwner(s, "ANCHOR_TOP")
                GameTooltip:SetText(s._fs:GetText(), 1, 1, 1)
                GameTooltip:AddLine(s._tt, 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(0, 0, 0, 1); GameTooltip:Hide() end)
        btnPool[btnUsed] = b
    end
    b._fs:SetText(label)
    b._tt = tooltip
    b:SetSize(math.max(70, b._fs:GetStringWidth() + 18), 20)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    b:SetScript("OnClick", onClick)
    b:Show()
    return b
end

-- Ligne d'objet : icone + lien, infobulle de l'objet au survol, Maj+clic = chat.
local function itemRow(x, y, item, width)
    itemUsed = itemUsed + 1
    local r = itemPool[itemUsed]
    if not r then
        r = CreateFrame("Button", nil, content)
        r._icon = r:CreateTexture(nil, "ARTWORK")
        r._icon:SetSize(16, 16)
        r._icon:SetPoint("LEFT", 0, 0)
        r._fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r._fs:SetPoint("LEFT", r._icon, "RIGHT", 6, 0)
        r._fs:SetPoint("RIGHT", r, "RIGHT", 0, 0)
        r._fs:SetJustifyH("LEFT")
        r._fs:SetWordWrap(false)
        r:SetScript("OnEnter", function(s)
            if s._link then
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                pcall(GameTooltip.SetHyperlink, GameTooltip, s._link)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:SetScript("OnClick", function(s)
            if s._link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
                ChatEdit_InsertLink(s._link)
            end
        end)
        itemPool[itemUsed] = r
    end
    r:SetSize(width, 18)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    r._icon:SetTexture(item.icon or 134400)
    r._fs:SetText(item.link or item.name or ("#" .. tostring(item.itemID)))
    r._link = item.link
    r:Show()
    return r
end

local function section(y, label)
    text(0, y, label, "GameFontNormal", C.COLOR.ACCENT)
    return y - 20
end

-- --- Actions -----------------------------------------------------------------
local function setWaypoint(inst)
    local e = inst and inst.entrance
    if not e then return end
    if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        local ok = pcall(function()
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(e.uiMapID, e.x / 100, e.y / 100))
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
        end)
        if ok then
            U.Print(string.format(LL.L["WAYPOINT_SET"], e.x, e.y))
            return
        end
    end
    U.Print(string.format("/way #%d %.2f %.2f", e.uiMapID, e.x, e.y))
end

local function openJournal(key, diffKey)
    local j = LL.Journal and LL.Journal:Get(key)
    if not (j and j.jid) then U.Print(LL.L["JOURNAL_UNKNOWN"]) return end
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal") end
    local info = D:GetDifficultyInfo(diffKey)
    if EncounterJournal_OpenJournal then
        pcall(EncounterJournal_OpenJournal, info and info.ejDiff or nil, j.jid)
    end
end

local function openDgnTracker(key)
    local api = _G.DgnTrackerAPI
    if not api then return end
    local name = D:GetLairName(key)
    local j = LL.Journal and LL.Journal:Get(key)
    local ok = api.OpenInstance({ name = name, jid = j and j.jid, type = "raid" })
        or api.OpenInstance(name)
    if not ok then
        local inst = D:GetInstance("lair", key)
        for _, n in ipairs(inst and inst.matchNames or {}) do
            if api.OpenInstance(n) then return end
        end
    end
end

-- --- Rendu ---------------------------------------------------------------------
local function chosenLootDiff(week)
    local d = LL.db.info.lootDiff
    if d and D:GetDifficultyInfo(d) then return d end
    -- Par defaut : la plus haute difficulte pas encore faite cette semaine.
    for i = #C.DIFF_ORDER, 1, -1 do
        local k = C.DIFF_ORDER[i]
        if not week[k] then return k end
    end
    return C.DIFF.HEROIC
end

local function rebuild()
    if not (frame and frame:IsShown()) then return end
    local L = LL.L
    resetPools()
    local key = lairKey()
    local inst = D:GetInstance("lair", key)
    local W = (content:GetWidth() or 360)
    local y = 0

    frame._title:SetText(D:GetLairName(key))
    frame._sub:SetText(D:GetBossName(key))

    -- Entree.
    local e = inst and inst.entrance
    local zone
    if e and C_Map and C_Map.GetMapInfo then
        local ok, mi = pcall(C_Map.GetMapInfo, e.uiMapID)
        zone = ok and type(mi) == "table" and mi.name or nil
    end
    if e then
        text(0, y, string.format(L["INFO_ENTRANCE"], zone or ("#" .. e.uiMapID), e.x, e.y), "GameFontHighlightSmall", C.COLOR.MUTED, W)
        y = y - 18
    end
    local bx = 0
    local b1 = button(bx, y, L["BTN_WAYPOINT"], function() setWaypoint(inst) end, L["BTN_WAYPOINT_TT"])
    bx = bx + b1:GetWidth() + 6
    if _G.DgnTrackerAPI then
        local b2 = button(bx, y, "DgnTracker", function() openDgnTracker(key) end, L["BTN_DGN_TT"])
        bx = bx + b2:GetWidth() + 6
    end
    local b3 = button(bx, y, L["BTN_JOURNAL"], function() openJournal(key, LL.db.info.lootDiff) end, L["BTN_JOURNAL_TT"])
    bx = bx + b3:GetWidth() + 6
    button(bx, y, L["DASH_TITLE"], function() if LL.modules.dashboard then LL.modules.dashboard:Toggle() end end)
    y = y - 30

    -- Semaine par difficulte.
    local week = LL.Lockouts:GetWeek(key)
    local lootDiff = chosenLootDiff(week)
    y = section(y, L["INFO_WEEK"])
    text(0, y, L["INFO_COL_DIFF"], "GameFontDisableSmall", nil, 90)
    text(92, y, L["INFO_COL_REC"], "GameFontDisableSmall", nil, 60, "RIGHT")
    text(156, y, L["INFO_COL_LOOT"], "GameFontDisableSmall", nil, 60, "RIGHT")
    text(222, y, L["INFO_COL_STATUS"], "GameFontDisableSmall", nil, W - 222)
    y = y - 16
    local equipped
    if GetAverageItemLevel then
        local ok, _, eq = pcall(GetAverageItemLevel)
        if ok then equipped = eq end
    end
    for _, diff in ipairs(C.DIFF_ORDER) do
        local info = D:GetDifficultyInfo(diff)
        local label = L[DIFF_LABEL[diff]]
        local selected = diff == lootDiff
        local b = button(0, y + 2, (selected and "> " or "") .. label, function()
            LL.db.info.lootDiff = diff
            rebuild()
        end, L["INFO_PICK_DIFF_TT"])
        b:SetWidth(86)
        b._fs:SetTextColor(unpack(DIFF_COLOR[diff]))
        text(92, y, tostring(info.rec), "GameFontHighlightSmall",
            (equipped and equipped < info.rec) and C.COLOR[C.VERDICT.RISKY] or C.COLOR.TEXT, 60, "RIGHT")
        local crest = LL.RewardData:CrestName(info.crest)
        text(156, y, tostring(info.ilvl), "GameFontHighlightSmall", C.COLOR.TEXT, 60, "RIGHT")
        local status
        if week[diff] then
            status = U.Colorize(L["INFO_DONE"], C.COLOR[C.VERDICT.VIABLE])
        else
            status = U.Colorize(L["INFO_TODO"], C.COLOR.MUTED)
        end
        status = status .. U.Colorize("  " .. (crest or L[info.track]), C.COLOR.MUTED)
        text(222, y, status, "GameFontHighlightSmall", nil, W - 222)
        y = y - 22
    end
    text(0, y, L["INFO_VAULT_NOTE"], "GameFontDisableSmall", C.COLOR.MUTED, W)
    y = y - 26

    -- Butin.
    y = section(y, string.format(L["INFO_LOOT"], L[DIFF_LABEL[lootDiff]]))
    local specBtn = button(W - 150, y + 20, allSpecs and L["INFO_LOOT_MINE"] or L["INFO_LOOT_ALL"], function()
        allSpecs = not allSpecs
        rebuild()
    end)
    specBtn:SetWidth(150)
    local cacheKey = key .. ":" .. lootDiff .. ":" .. tostring(allSpecs)
    local loot = lootCache[cacheKey]
    local complete = loot and #loot > 0
    if complete then
        for _, it in ipairs(loot) do if not it.link then complete = false break end end
    end
    if not complete then
        loot = LL.Journal and LL.Journal:GetLoot(key, lootDiff, allSpecs)
        lootCache[cacheKey] = loot
    end
    if loot == nil then
        text(0, y, L["INFO_LOOT_UNAVAILABLE"], "GameFontHighlightSmall", C.COLOR.MUTED, W)
        y = y - 18
    elseif #loot == 0 then
        text(0, y, L["INFO_LOOT_LOADING"], "GameFontHighlightSmall", C.COLOR.MUTED, W)
        y = y - 18
    else
        local colW = math.floor((W - 10) / 2)
        for i, item in ipairs(loot) do
            local col = (i - 1) % 2
            itemRow(col * (colW + 10), y, item, colW)
            if col == 1 or i == #loot then y = y - 20 end
        end
    end
    y = y - 10

    -- Hauts faits.
    y = section(y, L["INFO_ACHIEVEMENTS"])
    local achs = LL.Journal and LL.Journal:GetAchievements(key)
    if achs and #achs > 0 then
        for _, id in ipairs(achs) do
            local ok, aid, name, points, completed = pcall(GetAchievementInfo, id)
            if ok and aid then
                local mark = completed and U.Colorize("[x] ", C.COLOR[C.VERDICT.VIABLE]) or U.Colorize("[ ] ", C.COLOR.MUTED)
                local fs = text(0, y, mark .. (name or "?") .. U.Colorize("  " .. tostring(points or 0), C.COLOR.MUTED),
                    "GameFontHighlightSmall", completed and C.COLOR.TEXT or C.COLOR.MUTED, W)
                fs:SetWordWrap(false)
                y = y - 16
            end
        end
    elseif LL.Journal and LL.Journal:IsScanning() then
        text(0, y, L["INFO_ACH_SCANNING"], "GameFontHighlightSmall", C.COLOR.MUTED, W)
        y = y - 18
    else
        text(0, y, L["INFO_ACH_NONE"], "GameFontHighlightSmall", C.COLOR.MUTED, W)
        y = y - 18
        if LL.Journal then LL.Journal:FindAchievements(key) end
    end
    y = y - 10

    -- Records (personnage courant).
    y = section(y, L["INFO_RECORDS"])
    local mine = LL.RunHistory:Filter({ owner = LL:CharKey(), instance = key })
    local rec = LL.RunHistory:Records(mine)
    local any = false
    for _, diff in ipairs(C.DIFF_ORDER) do
        local r = rec[diff]
        if r then
            any = true
            local parts = { string.format(L["INFO_REC_RUNS"], r.runs, r.kills) }
            if r.bestKill then parts[#parts + 1] = string.format(L["INFO_REC_BEST"], U.FormatDuration(r.bestKill)) end
            if r.wipesBeforeFirst then parts[#parts + 1] = string.format(L["INFO_REC_FIRST"], r.wipesBeforeFirst) end
            if r.loot > 0 then parts[#parts + 1] = string.format(L["INFO_REC_LOOT"], r.loot) end
            text(0, y, U.Colorize(L[DIFF_LABEL[diff]], DIFF_COLOR[diff]) .. "  " .. table.concat(parts, "  -  "),
                "GameFontHighlightSmall", nil, W)
            y = y - 16
        end
    end
    if not any then
        text(0, y, L["INFO_REC_NONE"], "GameFontHighlightSmall", C.COLOR.MUTED, W)
        y = y - 16
    end

    local h = -y + 8
    content:SetHeight(h)
    if _G.TibiMidnight and _G.TibiMidnight.FitHeight then
        _G.TibiMidnight.FitHeight(frame, h, { chrome = 78, min = 300 })
    else
        frame:SetHeight(math.min(h + 78, 700))
    end
end

-- --- Construction ----------------------------------------------------------------
local function savePoint()
    local p = { frame:GetPoint() }
    LL.db.info.point = { p[1], nil, p[3], p[4], p[5] }
end

local function build()
    frame = CreateFrame("Frame", "LairLensInfoFrame", UIParent, "BackdropTemplate")
    frame:SetSize(420, 520)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame:SetBackdropColor(0.05, 0.06, 0.08, 0.97)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePoint() end)
    frame:Hide()
    tinsert(UISpecialFrames, "LairLensInfoFrame")

    local p = LL.db.info.point or { "CENTER", nil, "CENTER", 260, 0 }
    frame:SetPoint(p[1] or "CENTER", UIParent, p[3] or "CENTER", p[4] or 0, p[5] or 0)

    if _G.TibiMidnight and _G.TibiMidnight.SkinFrame then
        pcall(_G.TibiMidnight.SkinFrame, frame, C.COLOR.ACCENT)
    end

    frame._title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame._title:SetPoint("TOPLEFT", 14, -12)
    frame._title:SetPoint("RIGHT", -40, 0)
    frame._title:SetJustifyH("LEFT")
    U.SetTextColor(frame._title, C.COLOR.ACCENT)
    frame._sub = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame._sub:SetPoint("TOPLEFT", frame._title, "BOTTOMLEFT", 0, -3)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() frame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", "LairLensInfoScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -52)
    scroll:SetPoint("BOTTOMRIGHT", -30, 14)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(376, 10)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)

    frame:SetScript("OnShow", function()
        if LL.Journal then LL.Journal:Discover() end
        rebuild()
    end)
end

-- --- API publique ----------------------------------------------------------------
function Info:Open()
    if not frame then build() end
    ejRefreshes = 0
    frame:Show()
    rebuild()
end
function Info:Toggle()
    if frame and frame:IsShown() then frame:Hide() else self:Open() end
end
function Info:Refresh() rebuild() end

local function wire()
    local again = U.Debounce(0.3, rebuild)
    LL:On("LOCKOUTS_CHANGED", again)
    LL:On("JOURNAL_READY", again)
    LL:On("ACHIEVEMENTS_READY", again)
    LL:On("HISTORY_CHANGED", again)
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "EJ_LOOT_DATA_RECIEVED")
    pcall(f.RegisterEvent, f, "ACHIEVEMENT_EARNED")
    pcall(f.RegisterEvent, f, "PLAYER_SPECIALIZATION_CHANGED")
    f:SetScript("OnEvent", function(_, event)
        if event == "EJ_LOOT_DATA_RECIEVED" then
            -- Borne : au plus 6 rafraichissements par ouverture de la fiche.
            if not (frame and frame:IsShown()) or ejRefreshes >= 6 then return end
            ejRefreshes = ejRefreshes + 1
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
            wipe(lootCache)
        end
        again()
    end)
end

LL:On("DB_READY", wire)
