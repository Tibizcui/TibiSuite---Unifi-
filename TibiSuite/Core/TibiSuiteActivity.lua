--[[============================================================================
  TibiSuiteActivity.lua  -  Fil d'activite et notifications unifiees
  ---------------------------------------------------------------------------
  Un seul fil pour les evenements de la suite, une seule forme de
  notification a l'ecran (au style TibiSuite, a la couleur du module).

  Contrat pour les modules (facultatif, comme statusFn) :
    if TibiSuite and TibiSuite.Notify then
      TibiSuite.Notify("Leg", "Composant obtenu : ...", { toast = false })
    end
    opts = { urgent = bool, toast = bool (defaut vrai), sound = bool,
             once = "cle" (pas deux fois la meme cle en 10 min) }
  toast = false : seulement dans le fil (le module affiche deja sa propre
  alerte, pas de doublon a l'ecran).

  Sources gerees ici, sans toucher aux modules :
    - lignes d'etat (statusFn) : un module qui devient urgent, ou dont la
      progression atteint 100 % ;
    - nouveau courrier, niveau gagne, palier de Renom ;
    - nouvelle semaine depuis la derniere connexion.

  Stockage : TibiSuiteDB.feed (200 entrees au plus, compte entier),
  TibiSuiteDB.feedSeen (derniere lecture). Reglages : notifToasts,
  notifSound, notifCombat (nil = actif), notifMute[cle] = true.
  Pendant un combat, les notifications attendent PLAYER_REGEN_ENABLED.
============================================================================]]

local L = TibiSuiteL or {}
TibiSuiteL = L
local function D(k, v) if L[k] == nil then L[k] = v end end
D("ACT_MAIL",       "Nouveau courrier dans ta boîte aux lettres.")
D("ACT_LEVEL_FMT",  "Niveau %d atteint !")
D("ACT_RENOWN_FMT", "Renom %d avec %s.")
D("ACT_WEEK",       "Nouvelle semaine : tes activités hebdomadaires sont remises à zéro.")
D("ACT_DONE_FMT",   "%s")
D("ACT_SUITE",      "TibiSuite")

local MAX_FEED   = 200
local TOAST_LIFE = 6
local MAX_TOASTS = 3

local listeners = {}
local onceSeen = {}        -- cle -> heure (anti-doublon « once »)
local queue = {}           -- notifications en attente (combat)

local function DB()
  TibiSuiteDB.feed = TibiSuiteDB.feed or {}
  return TibiSuiteDB.feed
end

local function CatalogByKey(key)
  for _, m in ipairs(TibiSuite.GetCatalog and TibiSuite.GetCatalog() or {}) do
    if m.key == key then return m end
  end
end

-- Cle de module si le module est present, sinon la suite elle-meme.
local function Owner(...)
  for i = 1, select("#", ...) do
    local k = select(i, ...)
    local m = CatalogByKey(k)
    if m and C_AddOns.IsAddOnLoaded(m.addonName) then return k end
  end
  return "Suite"
end

function TibiSuite.OnFeedChanged(fn)
  if type(fn) == "function" then listeners[#listeners + 1] = fn end
end
local function Changed() for _, fn in ipairs(listeners) do pcall(fn) end end

function TibiSuite.GetFeed() return DB() end

function TibiSuite.UnreadCount()
  local seen, n = TibiSuiteDB.feedSeen or 0, 0
  local feed = DB()
  for i = #feed, 1, -1 do
    if (feed[i].t or 0) > seen then n = n + 1 else break end
  end
  return n
end

function TibiSuite.MarkFeedSeen()
  TibiSuiteDB.feedSeen = time()
  Changed()
end

function TibiSuite.ClearFeed()
  wipe(DB())
  TibiSuiteDB.feedSeen = time()
  Changed()
end

function TibiSuite.IsNotifMuted(key) return TibiSuiteDB.notifMute and TibiSuiteDB.notifMute[key] and true or false end
function TibiSuite.SetNotifMuted(key, muted)
  TibiSuiteDB.notifMute = TibiSuiteDB.notifMute or {}
  TibiSuiteDB.notifMute[key] = muted and true or nil
end

-- ── Notifications a l'ecran ─────────────────────────────────────────
local toasts = {}
local K

local function ModInfo(key)
  local m = CatalogByKey(key)
  if m then
    local c = m.col or { r = 0.6, g = 0.6, b = 0.6 }
    return m.addonName, { c.r, c.g, c.b }, TibiSuite.MODULE_LOGO and TibiSuite.MODULE_LOGO[key]
  end
  return L.ACT_SUITE, TibiSuite.ACCENT or { 0.769, 0.122, 0.231 }, K and K.LOGO
end

local function LayoutToasts()
  local y = -110
  for _, t in ipairs(toasts) do
    if t:IsShown() then
      t:ClearAllPoints()
      t:SetPoint("TOP", UIParent, "TOP", 0, y)
      y = y - t:GetHeight() - 8
    end
  end
end

local function GetToast()
  for _, t in ipairs(toasts) do if not t:IsShown() then return t end end
  if #toasts >= MAX_TOASTS then
    -- Plus de place : on recycle la plus ancienne.
    local old = table.remove(toasts, 1)
    old:Hide()
    toasts[#toasts + 1] = old
    return old
  end
  K = K or TibiSuite._kit
  local t = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
  t:SetSize(360, 56)
  t:SetFrameStrata("HIGH")
  t:SetBackdrop(K.FLAT)
  t:SetBackdropColor(0.055, 0.063, 0.082, 0.96)
  t:SetBackdropBorderColor(0, 0, 0, 1)
  t.bar = t:CreateTexture(nil, "OVERLAY")
  t.bar:SetPoint("TOPLEFT"); t.bar:SetPoint("BOTTOMLEFT"); t.bar:SetWidth(3)
  t.ico = t:CreateTexture(nil, "ARTWORK"); t.ico:SetSize(30, 30); t.ico:SetPoint("LEFT", 12, 0)
  t.title = K.Text(t, "GameFontNormal", "", K.COL.TXT); t.title:SetPoint("TOPLEFT", t.ico, "TOPRIGHT", 10, 1)
  t.txt = K.Text(t, "GameFontHighlightSmall", "", K.COL.TXT, 290)
  t.txt:SetPoint("TOPLEFT", t.title, "BOTTOMLEFT", 0, -3)
  if t.txt.SetMaxLines then t.txt:SetMaxLines(2) end
  local ag = t:CreateAnimationGroup()
  local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(0.2); a1:SetOrder(1)
  local a2 = ag:CreateAnimation("Alpha"); a2:SetFromAlpha(1); a2:SetToAlpha(1); a2:SetDuration(TOAST_LIFE); a2:SetOrder(2)
  local a3 = ag:CreateAnimation("Alpha"); a3:SetFromAlpha(1); a3:SetToAlpha(0); a3:SetDuration(0.6); a3:SetOrder(3)
  ag:SetScript("OnFinished", function() t:Hide(); LayoutToasts() end)
  t.ag = ag
  -- Survol : la notification reste ; clic : le fil d'activite.
  t:SetScript("OnEnter", function(s) s.ag:Pause() end)
  t:SetScript("OnLeave", function(s) s.ag:Play() end)
  t:SetScript("OnClick", function(s)
    s.ag:Stop(); s:Hide(); LayoutToasts()
    if TibiSuite.OpenCentre then TibiSuite.OpenCentre("activity") end
  end)
  toasts[#toasts + 1] = t
  return t
end

local function ShowToastFor(e)
  K = K or TibiSuite._kit
  if not K then return end
  local name, col, icon = ModInfo(e.k)
  local t = GetToast()
  t.bar:SetColorTexture(col[1], col[2], col[3], 1)
  t:SetBackdropBorderColor(e.u and 1 or 0, e.u and 0.6 or 0, e.u and 0.24 or 0, 1)
  t.ico:SetTexture(icon or K.LOGO)
  t.title:SetText(name); t.title:SetTextColor(col[1], col[2], col[3])
  t.txt:SetText(e.x or "")
  t:SetHeight(math.max(56, (t.txt:GetStringHeight() or 14) + 38))
  t:SetAlpha(0); t:Show()
  LayoutToasts()
  t.ag:Stop(); t.ag:Play()
end

local function PlayNotifySound()
  if TibiSuiteDB.notifSound == false or not PlaySound or not SOUNDKIT then return end
  local id = SOUNDKIT.IG_QUEST_LIST_COMPLETE or SOUNDKIT.TELL_MESSAGE
  if id then pcall(PlaySound, id) end
end

local function Present(e, opts)
  if TibiSuiteDB.notifToasts == false or opts.toast == false then return end
  if TibiSuiteDB.notifCombat ~= false and InCombatLockdown() then
    queue[#queue + 1] = e
    return
  end
  ShowToastFor(e)
  if opts.sound ~= false then PlayNotifySound() end
end

-- ── API ─────────────────────────────────────────────────────────────
function TibiSuite.Notify(key, text, opts)
  if type(text) ~= "string" or text == "" then return end
  opts = opts or {}
  key = key or "Suite"
  if TibiSuite.IsNotifMuted(key) then return end
  local now = time()
  if opts.once then
    local last = onceSeen[opts.once]
    if last and now - last < 600 then return end
    onceSeen[opts.once] = now
  end
  local e = { t = now, k = key, x = text, u = opts.urgent and true or nil,
              c = UnitName and UnitName("player") or nil }
  local feed = DB()
  feed[#feed + 1] = e
  while #feed > MAX_FEED do table.remove(feed, 1) end
  Present(e, opts)
  Changed()
end

-- ── Sources gerees par la suite ─────────────────────────────────────
-- Lignes d'etat : transitions « devient urgent » et « atteint 100 % ».
-- Premiere lecture de la session = reference, jamais de notification.
local lastState = {}
local function ScanStatus()
  if not TibiSuite.GetModuleStatus then return end
  for _, mod in ipairs(TibiSuite.GetCatalog()) do
    local st = TibiSuite.GetModuleStatus(mod.key)
    if st then
      local done = (st.progress or 0) >= 1
      local prev = lastState[mod.key]
      if prev then
        if st.urgent and not prev.urgent then
          TibiSuite.Notify(mod.key, st.text or "", { urgent = true, once = mod.key .. ":u:" .. tostring(st.text) })
        elseif done and not prev.done and st.text then
          TibiSuite.Notify(mod.key, string.format(L.ACT_DONE_FMT, st.text), { once = mod.key .. ":d:" .. st.text })
        end
      end
      lastState[mod.key] = { urgent = st.urgent and true or false, done = done }
    end
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("UPDATE_PENDING_MAIL")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
local hadMail
ev:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "PLAYER_LOGIN" then
    hadMail = HasNewMail and HasNewMail() or false
    -- Nouvelle semaine depuis la derniere connexion de ce personnage.
    local untilReset = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
      and select(2, pcall(C_DateAndTime.GetSecondsUntilWeeklyReset))
    if tonumber(untilReset) and TibiSuiteCharDB then
      local nextReset = time() + tonumber(untilReset)
      local stored = TibiSuiteCharDB.nextWeeklyReset
      if stored and time() >= stored then
        C_Timer.After(8, function() TibiSuite.Notify("Suite", L.ACT_WEEK, { once = "week" }) end)
      end
      TibiSuiteCharDB.nextWeeklyReset = nextReset
    end
    -- Reference des lignes d'etat une fois les modules charges, puis une
    -- verification par minute (en plus des RefreshStatus des modules).
    C_Timer.After(10, ScanStatus)
    C_Timer.NewTicker(60, ScanStatus)
    if TibiSuite.OnStatusChanged then TibiSuite.OnStatusChanged(ScanStatus) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    local n = #queue
    for i = 1, n do ShowToastFor(queue[i]) end
    if n > 0 then PlayNotifySound() end
    wipe(queue)
  elseif event == "UPDATE_PENDING_MAIL" then
    local has = HasNewMail and HasNewMail() or false
    if has and not hadMail then TibiSuite.Notify(Owner("Post"), L.ACT_MAIL, { once = "mail" }) end
    hadMail = has
  elseif event == "PLAYER_LEVEL_UP" then
    TibiSuite.Notify(Owner("Lvl", "XPBar"), string.format(L.ACT_LEVEL_FMT, tonumber(a1) or 0))
  elseif event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" then
    local name
    if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
      local ok, d = pcall(C_MajorFactions.GetMajorFactionData, a1)
      name = ok and d and d.name
    end
    TibiSuite.Notify(Owner("Rep", "RepBar"), string.format(L.ACT_RENOWN_FMT, tonumber(a2) or 0, name or "?"))
  end
end)
