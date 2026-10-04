--[[============================================================================
  Standby - Screen.lua
  ---------------------------------------------------------------------------
  L'ecran lui-meme. Frame SANS parent (StandbyScreen), strate
  FULLSCREEN_DIALOG, a l'echelle d'UIParent et calee sur elle : elle reste
  visible quand UIParent est masquee (meme construction que l'ecran d'ElvUI).

  Trois mises en page :
    - vitrine : horloge, journal des messages, tuiles de la suite, carte du
                personnage (titre, specialisation, niveau d'objet, stats),
                minuteur ;
    - fiche   : grand personnage au centre, equipement en deux colonnes,
                panneau de statistiques (Sheet.lua) ;
    - epure   : horloge, carte du personnage, minuteur ;
    - eco     : noir, horloge et minuteur discrets (economie forcee).

  Un clic n'importe ou fait revenir (SB.OnScreenClick). Aucune capture du
  clavier (voir pieges connus dans CLAUDE.md).

  NON TESTE EN JEU : rendu, tailles, PlayerModel, degradés SetGradient.
============================================================================]]

local ADDON, SB = ...
local T = SB.T

local Screen = {}
SB.Screen = Screen

-- Mise en page affichee : celle des options, ou celle du diaporama en cours
-- (alternance Vitrine / Fiche, voir Screen.Tick).
function Screen.Layout() return Screen.slide or SB.db.layout end

local f
local FONT = (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local MAX_LINES, MAX_TILES = 8, 9
local tickCount = 0

local function FS(parent, size, justify)
  local s = parent:CreateFontString(nil, "OVERLAY")
  s:SetFont(FONT, size, "")
  s:SetShadowOffset(1, -1)
  s:SetShadowColor(0, 0, 0, 0.95)
  s:SetJustifyH(justify or "LEFT")
  s:SetTextColor(0.953, 0.933, 0.945)
  return s
end

local function Muted(s) s:SetTextColor(0.725, 0.682, 0.714) end

local function Panel(parent)
  local p = CreateFrame("Frame", nil, parent)
  local bg = p:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(); bg:SetColorTexture(0.055, 0.047, 0.063, 0.78)
  local function Edge(a1, a2, w, h)
    local e = p:CreateTexture(nil, "BORDER")
    e:SetColorTexture(1, 1, 1, 0.12)
    e:SetPoint(a1); e:SetPoint(a2)
    if w then e:SetWidth(w) end
    if h then e:SetHeight(h) end
  end
  Edge("TOPLEFT", "TOPRIGHT", nil, 1); Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
  Edge("TOPLEFT", "BOTTOMLEFT", 1, nil); Edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
  return p
end

-- Fondu vertical vers le noir. SetGradient("VERTICAL", min, max) : min = BAS,
-- max = HAUT. (Premiere version inversee, constate en jeu le 2026-10-04 :
-- bandes sombres a bord net au lieu d'un fondu.)
local function Gradient(tex, darkAtTop)
  tex:SetColorTexture(1, 1, 1, 1)
  local dark, clear = CreateColor and CreateColor(0, 0, 0, 0.85), CreateColor and CreateColor(0, 0, 0, 0)
  local bottom, top = clear, dark
  if not darkAtTop then bottom, top = dark, clear end
  local ok = dark and pcall(tex.SetGradient, tex, "VERTICAL", bottom, top)
  if not ok then tex:SetColorTexture(0, 0, 0, 0.35) end
end

-- ============================================================================
-- CONSTRUCTION
-- ============================================================================
local function Build()
  f = CreateFrame("Frame", "StandbyScreen", nil)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetFrameLevel(50)
  f:SetClipsChildren(true)
  f:EnableMouse(true)
  f:Hide()
  f:SetScript("OnMouseUp", function() SB.OnScreenClick() end)

  -- Fond : voile (scene / noir), illustration (art) + ombre, degradés haut et bas
  f.veil = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  f.veil:SetAllPoints()
  f.artHolder = CreateFrame("Frame", nil, f)
  f.artHolder:SetAllPoints()
  f.artHolder:SetFrameLevel(f:GetFrameLevel())
  f.art = f.artHolder:CreateTexture(nil, "BACKGROUND", nil, -7)
  f.art:SetAllPoints()
  f.shade = f.artHolder:CreateTexture(nil, "BACKGROUND", nil, -6)
  f.shade:SetAllPoints(); f.shade:SetColorTexture(0, 0, 0, 0.72)

  -- Tableau : l'illustration entiere, cadre de parchemin compris, a sa vraie
  -- proportion. Les images du journal ne font qu'environ 390 x 336 pixels
  -- (coin haut-gauche d'un fichier 512 x 512, meme decoupe que la fiche
  -- d'instance du journal) : etirees en plein ecran elles etaient floues et
  -- deformees (constate en jeu le 2026-10-04). Le plein ecran ne sert plus que
  -- d'ambiance, recadre sans le cadre et assombri.
  f.picHolder = CreateFrame("Frame", nil, f)
  f.picHolder:SetFrameLevel(f:GetFrameLevel() + 3)
  -- Pas d'ombre portee : rectangle a bords droits autour d'un cadre de
  -- parchemin irregulier (vu en jeu le 2026-10-04).
  f.pic = f.picHolder:CreateTexture(nil, "ARTWORK")
  f.pic:SetAllPoints()
  f.picHolder:Hide()
  -- Lent zoom avant / arriere sur l'illustration
  local ag = f.artHolder:CreateAnimationGroup()
  local sc = ag:CreateAnimation("Scale")
  if sc.SetScaleFrom then sc:SetScaleFrom(1, 1); sc:SetScaleTo(1.08, 1.08) else sc:SetScale(1.08, 1.08) end
  sc:SetDuration(45); sc:SetSmoothing("IN_OUT")
  ag:SetLooping("BOUNCE")
  f.artAnim = ag

  -- Fondu d'entree a chaque changement du diaporama.
  local fade = f:CreateAnimationGroup()
  local fa = fade:CreateAnimation("Alpha")
  fa:SetFromAlpha(0.25); fa:SetToAlpha(1); fa:SetDuration(0.8); fa:SetSmoothing("OUT")
  f.fade = fade

  f.topGrad = f:CreateTexture(nil, "BORDER")
  f.topGrad:SetPoint("TOPLEFT"); f.topGrad:SetPoint("TOPRIGHT"); f.topGrad:SetHeight(180)
  Gradient(f.topGrad, true)
  f.botGrad = f:CreateTexture(nil, "BORDER")
  f.botGrad:SetPoint("BOTTOMLEFT"); f.botGrad:SetPoint("BOTTOMRIGHT"); f.botGrad:SetHeight(220)
  Gradient(f.botGrad, false)

  f.lisere = f:CreateTexture(nil, "ARTWORK")
  f.lisere:SetPoint("TOPLEFT"); f.lisere:SetPoint("TOPRIGHT"); f.lisere:SetHeight(2)
  f.lisere:SetColorTexture(SB.ACCENT[1], SB.ACCENT[2], SB.ACCENT[3], 1)

  -- Personnage en 3D. Modele de cabine d'essayage : le personnage a pied, en
  -- tenue. (Un PlayerModel affichait la monture quand le joueur etait monte,
  -- constate en jeu le 2026-10-04.) Place par ApplyLayout.
  local okM, model = pcall(CreateFrame, "DressUpModel", nil, f)
  if not (okM and model) then okM, model = pcall(CreateFrame, "PlayerModel", nil, f) end
  if okM and model then
    model:SetFrameLevel(f:GetFrameLevel() + 2)
    f.model = model
  end

  -- Haut : horloge, date, marque
  f.clock = FS(f, 56)
  f.clock:SetPoint("TOPLEFT", f, "TOPLEFT", 48, -40)
  f.date = FS(f, 15); Muted(f.date)
  f.date:SetPoint("TOPLEFT", f.clock, "BOTTOMLEFT", 2, -4)
  f.brand = FS(f, 11, "RIGHT"); Muted(f.brand)
  f.brand:SetPoint("TOPRIGHT", f, "TOPRIGHT", -48, -44)
  f.brand:SetText("STANDBY  ·  " .. SB.Hex({ 0.769, 0.122, 0.231 }) .. "TIBISUITE|r")
  f.realm = FS(f, 11, "RIGHT"); Muted(f.realm)
  f.realm:SetPoint("TOPRIGHT", f.brand, "BOTTOMRIGHT", 0, -4)
  f.ecoTag = FS(f, 11, "CENTER")
  f.ecoTag:SetTextColor(0.43, 0.39, 0.42)
  f.ecoTag:SetPoint("TOP", f, "TOP", 0, -40)

  -- Messages
  local msg = Panel(f)
  msg:SetSize(470, 40)
  msg:SetPoint("TOPLEFT", f, "TOPLEFT", 48, -150)
  msg:SetFrameLevel(f:GetFrameLevel() + 5)
  msg.head = FS(msg, 11); Muted(msg.head)
  msg.head:SetPoint("TOPLEFT", 12, -10)
  msg.count = FS(msg, 11, "RIGHT"); Muted(msg.count)
  msg.count:SetPoint("TOPRIGHT", -12, -10)
  msg.lines = {}
  for i = 1, MAX_LINES do
    local l = FS(msg, 13)
    l:SetWidth(446); l:SetWordWrap(false)
    l:SetPoint("TOPLEFT", 12, -28 - (i - 1) * 19)
    msg.lines[i] = l
  end
  f.msg = msg

  -- Tuiles
  f.tiles = {}
  for i = 1, MAX_TILES do
    local t = Panel(f)
    t:SetSize(360, 44)
    t:SetFrameLevel(f:GetFrameLevel() + 5)
    t.k = FS(t, 10); Muted(t.k)
    t.k:SetPoint("TOPLEFT", 10, -7)
    t.src = FS(t, 9, "RIGHT"); Muted(t.src)
    t.src:SetPoint("TOPRIGHT", -10, -7)
    t.v = FS(t, 13)
    t.v:SetWidth(340); t.v:SetWordWrap(true)
    t.v:SetSpacing(2)
    t.v:SetPoint("TOPLEFT", 10, -20)
    t.barBg = t:CreateTexture(nil, "ARTWORK")
    t.barBg:SetPoint("BOTTOMLEFT", 10, 6); t.barBg:SetSize(340, 3)
    t.barBg:SetColorTexture(1, 1, 1, 0.10)
    t.bar = t:CreateTexture(nil, "OVERLAY")
    t.bar:SetPoint("BOTTOMLEFT", 10, 6); t.bar:SetHeight(3)
    f.tiles[i] = t
  end

  -- Carte du personnage. Sur un cadre au-dessus du modele 3D : en Fiche, le
  -- nom passe par-dessus les pieds du personnage (une region de f serait
  -- dessinee SOUS le modele, qui est un cadre enfant).
  local idf = CreateFrame("Frame", nil, f)
  idf:SetAllPoints()
  idf:SetFrameLevel(f:GetFrameLevel() + 6)
  f.idHolder = idf
  -- Fondu sombre propre a la Fiche, pour lire le nom sur le personnage.
  f.idGrad = idf:CreateTexture(nil, "BACKGROUND")
  f.idGrad:SetPoint("BOTTOMLEFT"); f.idGrad:SetPoint("BOTTOMRIGHT"); f.idGrad:SetHeight(230)
  Gradient(f.idGrad, false)
  f.idGrad:Hide()
  f.name = FS(idf, 34)
  f.title = FS(idf, 15)
  f.title:SetTextColor(SB.ACCENT[1], SB.ACCENT[2], SB.ACCENT[3])
  f.sub = FS(idf, 14); Muted(f.sub)
  f.sub2 = FS(idf, 13); Muted(f.sub2)
  f.spec = FS(idf, 13)
  f.stats = FS(idf, 12); Muted(f.stats)
  f.idLines = { f.name, f.title, f.sub, f.sub2, f.spec, f.stats }

  -- Mise en page Fiche : equipement en deux colonnes + statistiques
  f.slots = {}
  local function SlotRow(left)
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(350, 38)
    r:SetFrameLevel(f:GetFrameLevel() + 5)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(34, 34)
    r.edge = r:CreateTexture(nil, "BORDER")
    r.edge:SetColorTexture(0, 0, 0, 0.8)
    r.edge:SetPoint("TOPLEFT", r.icon, "TOPLEFT", -1, 1); r.edge:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 1, -1)
    r.name = FS(r, 13, left and "LEFT" or "RIGHT")
    r.info = FS(r, 11, left and "LEFT" or "RIGHT"); Muted(r.info)
    -- 300 : les noms longs (« Garde providentielle du verdict effulgent »)
    -- etaient coupes a 250 (vu en jeu le 2026-10-04).
    r.name:SetWidth(300); r.name:SetWordWrap(false)
    r.info:SetWidth(300); r.info:SetWordWrap(false)
    if left then
      r.icon:SetPoint("LEFT")
      r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -2)
      r.info:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 2)
    else
      r.icon:SetPoint("RIGHT")
      r.name:SetPoint("TOPRIGHT", r.icon, "TOPLEFT", -8, -2)
      r.info:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMLEFT", -8, 2)
    end
    r:Hide()
    return r
  end
  for i, slot in ipairs(SB.Sheet.LEFT) do
    local r = SlotRow(true); r.slot = slot
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 48, -150 - (i - 1) * 46)
    f.slots[#f.slots + 1] = r
  end
  for i, slot in ipairs(SB.Sheet.RIGHT) do
    local r = SlotRow(false); r.slot = slot
    r:SetPoint("TOPRIGHT", f, "TOPRIGHT", -48, -150 - (i - 1) * 46)
    f.slots[#f.slots + 1] = r
  end
  local sp = Panel(f)
  sp:SetSize(300, 40)
  sp:SetPoint("TOPLEFT", f, "TOPLEFT", 48, -150 - #SB.Sheet.LEFT * 46 - 10)
  sp:SetFrameLevel(f:GetFrameLevel() + 5)
  sp.head = FS(sp, 11); Muted(sp.head)
  sp.head:SetPoint("TOPLEFT", 12, -10)
  sp.rows = {}
  for i = 1, 8 do
    local l = FS(sp, 13); local v = FS(sp, 13, "RIGHT")
    l:SetPoint("TOPLEFT", 12, -28 - (i - 1) * 18); v:SetPoint("TOPRIGHT", -12, -28 - (i - 1) * 18)
    sp.rows[i] = { l = l, v = v }
  end
  sp:Hide()
  f.statPanel = sp

  -- Minuteur
  -- Sur le calque de la carte (au-dessus du fondu de la Fiche, sinon le
  -- minuteur et la legende sont ternis : vu en jeu le 2026-10-04).
  f.afkLbl = FS(f.idHolder, 11, "RIGHT")
  f.afkLbl:SetTextColor(SB.ACCENT[1], SB.ACCENT[2], SB.ACCENT[3])
  f.timer = FS(f.idHolder, 32, "RIGHT")
  f.hint = FS(f.idHolder, 12, "RIGHT"); Muted(f.hint)
  f.msgCount = FS(f.idHolder, 12, "RIGHT")
  f.msgCount:SetTextColor(SB.ACCENT[1], SB.ACCENT[2], SB.ACCENT[3])
  f.caption = FS(f.idHolder, 10, "CENTER"); Muted(f.caption)
  f.caption:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
end

-- ============================================================================
-- CONTENU
-- ============================================================================
local CHAT_FALLBACK = {
  WHISPER = { 1, 0.5, 1 }, BN_WHISPER = { 0, 1, 0.965 }, GUILD = { 0.251, 1, 0.251 }, OFFICER = { 0.251, 0.753, 0.251 },
  PARTY = { 0.667, 0.667, 1 }, PARTY_LEADER = { 0.463, 0.784, 1 }, RAID = { 1, 0.498, 0 }, RAID_LEADER = { 1, 0.282, 0.035 },
  INSTANCE_CHAT = { 1, 0.498, 0 }, INSTANCE_CHAT_LEADER = { 1, 0.282, 0.035 },
}

local function ChatColor(ct)
  local info = ChatTypeInfo and ChatTypeInfo[ct]
  if info and info.r then return info.r, info.g, info.b end
  local c = CHAT_FALLBACK[ct] or { 1, 1, 1 }
  return c[1], c[2], c[3]
end

function Screen.RefreshMessages()
  if not f then return end
  local msg = f.msg
  local list = SB.messages
  local n = #list
  msg.head:SetText(string.upper(T("MSG_HEAD", "Pendant votre absence")))
  msg.count:SetText(n > 0 and tostring(n) or "")
  local first = math.max(1, n - MAX_LINES + 1)
  local shown = 0
  for i = 1, MAX_LINES do
    local m = list[first + i - 1]
    local l = msg.lines[i]
    if m then
      local r, g, b = ChatColor(m.type)
      local who = m.from and ("[" .. m.from .. "] ") or ""
      local body = m.text or T("MSG_SECRET", "message reçu (contenu masqué par le jeu)")
      l:SetText("|cFF8A8088" .. date("%H:%M", m.t) .. "|r  " .. SB.Hex({ r, g, b }) .. who .. body .. "|r")
      l:Show(); shown = shown + 1
    else
      l:SetText(""); l:Hide()
    end
  end
  if shown == 0 then
    msg.lines[1]:SetText("|cFF8A8088" .. T("MSG_NONE", "Aucun message pour l'instant.") .. "|r")
    msg.lines[1]:Show(); shown = 1
  end
  msg:SetHeight(36 + shown * 19)
  -- Hors Vitrine (journal masque) : simple compteur sous le minuteur.
  if Screen.Layout() ~= "vitrine" and SB.db.messages and n > 0 then
    f.msgCount:SetText(string.format(T("MSG_COUNT", "%d message(s) reçu(s)"), n))
  else
    f.msgCount:SetText("")
  end
end

function Screen.RefreshTiles()
  if not f then return end
  local list = (Screen.Layout() == "vitrine") and SB.Tiles.Collect() or {}
  local y = -150
  -- Les tuiles s'arretent avant le minuteur (bas a droite).
  local floor = -((UIParent:GetHeight() or 768) - 140)
  for i = 1, MAX_TILES do
    local t, d = f.tiles[i], list[i]
    if d and y > floor then
      t:ClearAllPoints()
      t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -48, y)
      t.k:SetText(string.upper(d.label or ""))
      t.src:SetText(d.src or "")
      if t.v.SetMaxLines then t.v:SetMaxLines(d.maxLines or 2) end
      t.v:SetText(d.value or "")
      local c = d.color or SB.ACCENT
      if d.frac then
        t.bar:SetColorTexture(c[1], c[2], c[3], 1)
        t.bar:SetWidth(math.max(1, 340 * math.min(1, math.max(0, d.frac))))
        t.bar:Show(); t.barBg:Show()
      else
        t.bar:Hide(); t.barBg:Hide()
      end
      -- Hauteur selon le texte (1 a 4 lignes).
      local th = (t.v.GetStringHeight and t.v:GetStringHeight()) or 14
      if type(th) ~= "number" or th < 14 then th = 14 end
      local h = math.floor(26 + th + (d.frac and 12 or 6))
      t:SetHeight(h)
      t:Show()
      y = y - h - 8
    else
      t:Hide()
    end
  end
end

local function DateText()
  local d = date("*t")
  local wd = CALENDAR_WEEKDAY_NAMES and CALENDAR_WEEKDAY_NAMES[d.wday]
  local mo = CALENDAR_FULLDATE_MONTH_NAMES and CALENDAR_FULLDATE_MONTH_NAMES[d.month]
  if wd and mo then return string.format("%s %d %s", wd, d.day, mo) end
  return date("%d/%m/%Y")
end

local function Money()
  local m = GetMoney and GetMoney() or 0
  if GetMoneyString then
    local ok, s = pcall(GetMoneyString, m, true)
    if ok and s then return s end
  end
  return tostring(math.floor(m / 10000)) .. " po"
end

function Screen.RefreshIdentity()
  local db = SB.db
  local name = UnitName("player") or "?"
  local className, classToken = UnitClass("player")
  local cc = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
  local classHex = cc and SB.Hex({ cc.r, cc.g, cc.b }) or "|cFFFFFFFF"
  local guild = GetGuildInfo and GetGuildInfo("player")
  local lvl = UnitLevel("player") or 0

  local fiche = Screen.Layout() == "fiche"
  local title = (db.showTitle and not db.privacy) and SB.Sheet.Title() or nil
  f.title:SetText(title or "")
  local wantSheet = fiche or (db.showSheet and Screen.Layout() == "vitrine")
  f.spec:SetText(wantSheet and (SB.Sheet.SpecLine() or "") or "")
  f.stats:SetText((db.showSheet and Screen.Layout() == "vitrine") and (SB.Sheet.StatsLine() or "") or "")

  if db.privacy then
    f.name:SetText(T("PRIV_NAME", "Personnage"))
    f.name:SetTextColor(SB.ACCENT[1], SB.ACCENT[2], SB.ACCENT[3])
    f.sub:SetText(classHex .. (className or "") .. "|r  ·  " .. string.format(T("ID_LEVEL", "niveau %d"), lvl))
    f.sub2:SetText(GetZoneText and GetZoneText() or "")
    f.realm:SetText("")
  else
    f.name:SetText(name)
    if db.classColor and cc then f.name:SetTextColor(cc.r, cc.g, cc.b)
    else f.name:SetTextColor(0.953, 0.933, 0.945) end
    local sub = classHex .. (className or "") .. "|r  ·  " .. string.format(T("ID_LEVEL", "niveau %d"), lvl)
    if guild then sub = sub .. "  ·  <" .. guild .. ">" end
    f.sub:SetText(sub)
    local zone = GetZoneText and GetZoneText() or ""
    f.sub2:SetText((zone ~= "" and (zone .. "  ·  ") or "") .. Money())
    f.realm:SetText(GetRealmName and GetRealmName() or "")
  end
  Screen.StackIdentity()
end

-- Empile les lignes non vides de la carte du personnage. Vitrine / Epuree :
-- en bas a gauche, de bas en haut. Fiche : en haut au centre, de haut en bas.
-- Economie : rien.
function Screen.StackIdentity()
  local layout = Screen.Layout()
  for _, fs in ipairs(f.idLines) do fs:ClearAllPoints(); fs:Hide() end
  if layout == "eco" then return end
  local list = {}
  local fiche = layout == "fiche"
  for _, fs in ipairs(f.idLines) do
    local hidden = fiche and (fs == f.sub2 or fs == f.stats)
    local txt = fs:GetText()
    if not hidden and txt and txt ~= "" then list[#list + 1] = fs end
  end
  f.idGrad:SetShown(fiche)
  if fiche then
    -- Choix 1 valide le 2026-10-04 : en bas au centre, par-dessus les pieds
    -- du personnage geant.
    local nxt
    for i = #list, 1, -1 do
      local fs = list[i]
      fs:SetJustifyH("CENTER")
      if not nxt then fs:SetPoint("BOTTOM", f, "BOTTOM", 0, 40)
      else fs:SetPoint("BOTTOM", nxt, "TOP", 0, (fs == f.name) and 6 or 4) end
      fs:Show(); nxt = fs
    end
  else
    local x = (f.model and f.model:IsShown()) and 400 or 48
    local nxt
    for i = #list, 1, -1 do
      local fs = list[i]
      fs:SetJustifyH("LEFT")
      if not nxt then fs:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 44)
      else fs:SetPoint("BOTTOMLEFT", nxt, "TOPLEFT", 0, (fs == f.name) and 6 or 4) end
      fs:Show(); nxt = fs
    end
  end
end

-- Mise en page Fiche : equipement et statistiques.
function Screen.RefreshSheet()
  local fiche = Screen.Layout() == "fiche"
  for _, r in ipairs(f.slots) do
    if fiche then
      local d = SB.Sheet.Slot(r.slot)
      if d then
        if d.icon then r.icon:SetTexture(d.icon) else r.icon:SetColorTexture(1, 1, 1, 0.08) end
        r.icon:SetDesaturated(false)
        r.name:SetText(d.name)
        r.info:SetText(SB.Sheet.SlotInfo(d))
      else
        r.icon:SetColorTexture(1, 1, 1, 0.06)
        r.name:SetText("|cFF8A8088" .. SB.Sheet.SlotLabel(r.slot) .. "|r")
        r.info:SetText(T("SHEET_EMPTY", "vide"))
      end
      r:Show()
    else
      r:Hide()
    end
  end
  local sp = f.statPanel
  if not fiche then sp:Hide(); return end
  sp.head:SetText(string.upper(T("SHEET_STATS", "Statistiques")))
  local stats = SB.Sheet.Stats()
  for i, row in ipairs(sp.rows) do
    local s = stats[i]
    if s then row.l:SetText(s.label); row.v:SetText(s.value); row.l:Show(); row.v:Show()
    else row.l:Hide(); row.v:Hide() end
  end
  sp:SetHeight(36 + math.min(#stats, #sp.rows) * 18)
  sp:Show()
end

local Relayout   -- defini plus bas (utilise par le diaporama dans Screen.Tick)

local function Clock()
  f.clock:SetText(date("%H:%M"))
end

local function Timer()
  local s = math.max(0, math.floor(GetTime() - (SB.shownStart or GetTime())))
  f.timer:SetText(string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60))
end

function Screen.Tick()
  if not f or not f:IsShown() then return end
  Clock(); Timer()
  tickCount = tickCount + 1
  local db = SB.db
  -- Diaporama : alternance Vitrine / Fiche (seulement depuis l'une des deux).
  local slideOn = db.slideshow and (db.layout == "vitrine" or db.layout == "fiche")
  if slideOn and tickCount % math.max(10, db.slideSec or 45) == 0 then
    Screen.slide = (Screen.Layout() == "vitrine") and "fiche" or "vitrine"
    Relayout(false)
    f.fade:Stop(); f.fade:Play()
    return
  end
  -- Nouvelle illustration toutes les N minutes (fond Illustration).
  if SB.Scene.mode == "art" and (db.artEvery or 0) > 0 and tickCount % (db.artEvery * 60) == 0 then
    Relayout(true)
    f.fade:Stop(); f.fade:Play()
    return
  end
  if tickCount % 30 == 0 then
    Screen.RefreshTiles(); Screen.RefreshIdentity()
    if Screen.RefreshExtras then Screen.RefreshExtras() end
  end
end

-- ============================================================================
-- MISE EN PAGE
-- ============================================================================
local function ApplyBackground(repick)
  local mode = SB.Scene.mode or "black"
  f.art:Hide(); f.shade:Hide(); f.artAnim:Stop(); f.picHolder:Hide()
  f.caption:SetText("")
  if mode == "scene" then
    -- Interface masquee : on voit le monde. Sinon (mode sur, case decochee),
    -- voile plus dense pour couvrir l'interface.
    local dim = SB.Scene.uiHidden and 0.12 or 0.78
    if Screen.Layout() == "fiche" then dim = 0.82 end   -- le grand personnage passe devant
    f.veil:SetColorTexture(0, 0, 0, dim)
    f.topGrad:Show(); f.botGrad:Show()
  elseif mode == "art" then
    f.veil:SetColorTexture(0, 0, 0, 1)
    if repick or not Screen.pick then Screen.pick = SB.Scene.PickArt() end
    local pick = Screen.pick
    if pick then
      -- Ambiance : interieur de l'image (sans le cadre), plein ecran, assombri.
      f.art:SetTexture(pick.file)
      f.art:SetTexCoord(0.08, 0.68, 0.10, 0.56)
      -- Plus sombre en Fiche : les noms d'objets doivent rester lisibles sur
      -- une illustration claire (vu en jeu le 2026-10-04).
      f.shade:SetColorTexture(0, 0, 0, (Screen.Layout() == "fiche") and 0.85 or 0.72)
      f.art:Show(); f.shade:Show()
      -- Tableau : image complete (390 x 336 dans 512 x 512), hauteur 46 % de
      -- l'ecran, soit a peu pres sa resolution d'origine a l'echelle 1.
      local sh = UIParent:GetHeight() or 768
      local ph = math.floor(sh * 0.46)
      local pw = math.floor(ph * 390 / 336)
      f.pic:SetTexture(pick.file)
      f.pic:SetTexCoord(0, 390 / 512, 0, 336 / 512)
      f.picHolder:SetSize(pw, ph)
      f.picHolder:ClearAllPoints()
      f.picHolder:SetPoint("CENTER", f, "CENTER", 0, 10)
      f.picHolder:SetShown(Screen.Layout() ~= "fiche")   -- en Fiche, le personnage occupe le centre
      f.artAnim:Play()
      f.caption:SetText((pick.tierName or "") .. ((pick.inst and pick.inst ~= "") and ("  ·  " .. pick.inst) or ""))
    else
      f.caption:SetText(T("ART_NONE", "Illustrations indisponibles pour le moment (journal des aventures ouvert ?)"))
    end
    f.topGrad:Show(); f.botGrad:Show()
  else
    f.veil:SetColorTexture(0, 0, 0, 1)
    f.topGrad:Hide(); f.botGrad:Hide()
  end
end

local function ApplyLayout()
  local db = SB.db
  local layout = Screen.Layout()
  local eco = layout == "eco"

  local fiche = layout == "fiche"
  -- Personnage 3D : pas sur la scene en Vitrine / Epuree (on voit deja le
  -- vrai), toujours en Fiche, jamais en eco.
  if f.model then
    local wantModel = not eco and (fiche or (db.showModel and SB.Scene.mode ~= "scene"))
    if wantModel then
      local m = f.model
      m:ClearAllPoints()
      if fiche then
        -- Toute la hauteur de l'ecran, centre (choix 1 du 2026-10-04), cadre
        -- 0,70 x hauteur : cadrage valide en jeu. NE PAS elargir le cadre a
        -- tout l'ecran : le jeu recadre selon la forme du cadre et zoome sur
        -- le personnage (essai du 2026-10-04, personnage coupe). Contrepartie
        -- assumee : un halo d'arme peut etre rogne au bord du cadre.
        local sh = UIParent:GetHeight() or 768
        m:SetSize(math.floor(sh * 0.70), sh)
        m:SetPoint("CENTER", f, "CENTER", 0, 0)
      else
        -- 1,4 fois l'ancienne taille (320 x 460), demande du 2026-10-04.
        m:SetSize(440, 640)
        m:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 0)
      end
      m:Show()
      pcall(m.SetUnit, m, "player")
      pcall(m.SetPortraitZoom, m, 0)
      pcall(m.SetFacing, m, fiche and 0 or 0.45)
    else
      f.model:Hide()
    end
  end

  f.clock:SetFont(FONT, eco and 22 or (layout == "epure" and 72 or 56), "")
  f.clock:ClearAllPoints()
  f.timer:ClearAllPoints(); f.afkLbl:ClearAllPoints(); f.hint:ClearAllPoints()
  f.msgCount:ClearAllPoints()

  if eco then
    f.clock:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 48, 48)
    f.clock:SetTextColor(0.54, 0.50, 0.53)
    f.timer:SetFont(FONT, 22, "")
    f.timer:SetTextColor(0.54, 0.50, 0.53)
    f.timer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -48, 48)
    f.hint:SetPoint("TOPRIGHT", f.timer, "BOTTOMRIGHT", 0, -4)
    f.afkLbl:SetPoint("BOTTOMRIGHT", f.timer, "TOPRIGHT", 0, 4)
    f.ecoTag:SetText(string.format(T("ECO_TAG", "Mode économie  ·  %d images/s  ·  interface masquée"), db.ecoFPS))
    f.ecoTag:Show()
    f.date:Hide(); f.brand:Hide(); f.realm:Hide()
    f.msg:Hide()
  else
    f.clock:SetPoint("TOPLEFT", f, "TOPLEFT", 48, -40)
    f.clock:SetTextColor(0.953, 0.933, 0.945)
    f.timer:SetFont(FONT, 32, "")
    f.timer:SetTextColor(0.953, 0.933, 0.945)
    f.timer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -48, 58)
    f.afkLbl:SetPoint("BOTTOMRIGHT", f.timer, "TOPRIGHT", 0, 4)
    f.hint:SetPoint("TOPRIGHT", f.timer, "BOTTOMRIGHT", 0, -6)
    f.ecoTag:Hide()
    f.date:Show(); f.brand:Show(); f.realm:Show()
    f.msg:SetShown(layout == "vitrine" and db.messages)
  end
  f.msgCount:SetPoint("BOTTOMRIGHT", f.afkLbl, "TOPRIGHT", 0, 6)
  f.afkLbl:SetText(string.upper(T("AFK_SINCE", "Absent depuis")))
  f.hint:SetText(SB.preview and T("HINT_PREVIEW", "Aperçu  ·  cliquez pour fermer") or T("HINT_BACK", "Bougez ou cliquez pour revenir"))
end

-- Recompose l'ecran (a l'ouverture, et a chaque changement du diaporama).
-- repick : tirer une nouvelle illustration.
Relayout = function(repick)
  ApplyBackground(repick)
  -- Largeur du journal : ce qui reste a gauche des tuiles (ecrans 4:3 compris),
  -- et a gauche du tableau quand il est affiche.
  local sw = UIParent:GetWidth() or 1200
  local w = math.min(470, sw - 360 - 96 - 40)
  if f.picHolder:IsShown() then w = math.min(w, (sw - f.picHolder:GetWidth()) / 2 - 48 - 20) end
  w = math.max(260, math.floor(w))
  f.msg:SetWidth(w)
  for _, l in ipairs(f.msg.lines) do l:SetWidth(w - 24) end
  ApplyLayout()
  f.date:SetText(DateText())
  Screen.RefreshIdentity()
  Screen.RefreshMessages()
  Screen.RefreshTiles()
  Screen.RefreshSheet()
  if Screen.RefreshExtras then Screen.RefreshExtras() end
  Clock(); Timer()
end

function Screen.Show()
  if not f then Build() end
  f:SetScale(UIParent:GetScale())
  f:ClearAllPoints()
  f:SetAllPoints(UIParent)
  tickCount = 0
  Screen.slide, Screen.pick = nil, nil
  Relayout(true)
  f:Show()
end

function Screen.Hide()
  Screen.slide, Screen.pick = nil, nil
  if not f then return end
  f.artAnim:Stop()
  f:Hide()
end

function Screen.IsShown() return f and f:IsShown() or false end
