--[[============================================================================
  TibiSuiteCentre.lua  -  Centre TibiSuite (fenetre unique de reglages)
  ---------------------------------------------------------------------------
  Une seule fenetre, facon EllesmereUI : barre laterale (General + un
  interrupteur par module), page de droite, pied de fenetre avec le
  rechargement de l'interface quand il est necessaire.

  La page d'un module affiche SON PROPRE panneau d'options, ancre ici grace
  au socle v13 (panel:Dock). Aucun module n'a ete modifie : le Centre ouvre
  le panneau par la voie habituelle (onOptions ou <Addon>_OpenOptions), le
  recupere dans UI.lastShownPanel puis l'ancre. Fermer le Centre ne casse
  rien : la roue du module rouvre le panneau en fenetre flottante.

  Aucun crochet Blizzard : la fenetre est seulement inscrite dans
  UISpecialFrames (Echap natif, sans OnHide), comme les fenetres escClose.

  API : TibiSuite.OpenCentre(pageId), TibiSuite.ToggleCentre(),
        TibiSuite.IsCentreShown(). pageId = "home" | "bar" | "doctor" |
        "maint" | cle de module ("Stats", "Daily"...).
============================================================================]]

local L = TibiSuiteL or {}
TibiSuiteL = L

-- Textes (francais par defaut ; Locale\enUS.lua peut les ecraser).
local function D(k, v) if L[k] == nil then L[k] = v end end
D("CTR_FILTER",        "Filtrer...")
D("CTR_GENERAL",       "GÉNÉRAL")
D("CTR_MODULES",       "MODULES")
D("CTR_HOME",          "Accueil")
D("CTR_BAR",           "Barre et accès")
D("CTR_DOCTOR",        "Diagnostic")
D("CTR_MAINT",         "Maintenance")
D("CTR_HOME_DESC",     "Vue d'ensemble de la suite et accès rapides.")
D("CTR_BAR_DESC",      "Barre d'onglets, bouton de la minicarte, ligne du menu Échap et messages de connexion.")
D("CTR_DOCTOR_DESC",   "État de chaque module, versions, mémoire et temps CPU.")
D("CTR_MAINT_DESC",    "Installateur, profils, réinstallation d'un module et code du Dashboard.")
D("CTR_ST_ON",         "Actif")
D("CTR_ST_OFF",        "Désactivé")
D("CTR_ST_LOAD",       "Chargé au prochain rechargement")
D("CTR_ST_UNLOAD",     "Arrêté au prochain rechargement")
D("CTR_ST_ABSENT",     "Non installé")
D("CTR_SLASH",         "Commande : ")
D("CTR_RELOAD",        "Recharger l'interface")
D("CTR_CLOSE",         "Fermer")
D("CTR_PENDING_1",     "1 changement attend un rechargement")
D("CTR_PENDING_N",     " changements attendent un rechargement")
D("CTR_OPEN_MOD",      "Ouvrir le module")
D("CTR_REINSTALL",     "Réinstaller")
D("CTR_CURSE",         "Page CurseForge")
D("CTR_ENABLE",        "Activer le module")
D("CTR_NOTE_OFF",      "Ce module est désactivé : WoW ne le charge pas du tout. Active-le pour retrouver sa fenêtre et ses réglages.")
D("CTR_NOTE_LOAD",     "Ce module est activé. Il sera chargé au prochain rechargement de l'interface, ses réglages apparaîtront alors ici.")
D("CTR_NOTE_ABSENT",   "Ce module n'est pas installé. Tu peux le télécharger gratuitement sur CurseForge, il rejoindra la suite tout seul.")
D("CTR_NOTE_NOPANEL",  "Ce module n'a pas de panneau de réglages à afficher ici. Ouvre-le pour accéder à ses options.")
D("CTR_TOAST_ON",      " activé.")
D("CTR_TOAST_RELOAD",  " : rechargement nécessaire pour l'activer.")
D("CTR_TOAST_OFF",     " sera arrêté au prochain rechargement.")
D("CTR_TOAST_OFF_NOW", " désactivé.")
D("CTR_CARD_MODULES",  "Modules actifs")
D("CTR_CARD_RELOAD",   "Rechargement")
D("CTR_CARD_VERSION",  "Version")
D("CTR_RELOAD_NONE",   "Aucun")
D("CTR_RELOAD_WAIT",   " en attente")
D("CTR_QUICK",         "ACCÈS RAPIDE")
D("CTR_Q_BAR",         "Afficher la barre")
D("CTR_Q_SETUP",       "Installateur")
D("CTR_Q_NEWS",        "Quoi de neuf")
D("CTR_Q_PROFILE",     "Profils")
D("CTR_Q_EXPORT",      "Code du Dashboard")
D("CTR_Q_DOCTOR",      "Diagnostic")
D("CTR_HOME_TIP",      "Astuce : chaque module garde aussi sa roue d'options et son raccourci Maj+clic droit. Ici, tout est réuni au même endroit.")
D("CTR_DOC_RERUN",     "Relancer le diagnostic")
D("CTR_BAR_SEC_STYLE", "Style de la barre")
D("CTR_BAR_STYLE_NOTE","Classique : la grille d'onglets texte. Dock : une rangée d'icônes, discrète. Panneau vivant : chaque module affiche son état du moment (quêtes restantes, concentration, réputation...). Le changement est immédiat, sans rechargement.")
D("CTR_BAR_STYLE_CLASSIC", "Classique (grille d'onglets)")
D("CTR_BAR_STYLE_DOCK",    "Dock (icônes)")
D("CTR_BAR_STYLE_PANEL",   "Panneau vivant (état des modules)")
D("CTR_BAR_DOCKLBL",   "Noms courts sous les icônes du Dock")
D("CTR_BAR_GRID_NOTE", "Colonnes de la grille : style Classique seulement. Le Dock suit l'orientation (une rangée ou une colonne), le Panneau est toujours vertical.")
D("CTR_BAR_SEC_LAYOUT","Disposition")
D("CTR_BAR_VERTICAL",  "Barre verticale")
D("CTR_BAR_LOCKED",    "Verrouiller la barre")
D("CTR_BAR_OPEN",      "Barre affichée")
D("CTR_BAR_SCALE",     "Échelle (%)")
D("CTR_BAR_COLS",      "Colonnes de la grille")
D("CTR_BAR_LOGO",      "Taille du logo")
D("CTR_BAR_SEC_POS",   "Position")
D("CTR_BAR_POS_NOTE",  "La barre se déplace à la souris quand elle n'est pas verrouillée. Les curseurs la placent au pixel près, à partir de son point d'ancrage.")
D("CTR_BAR_X",         "Position horizontale (X)")
D("CTR_BAR_Y",         "Position verticale (Y)")
D("CTR_BAR_RECENTER",  "Recentrer la barre")
D("CTR_BAR_SEC_TABS",  "Onglets affichés dans la barre")
D("CTR_BAR_TABS_NOTE", "Masquer un onglet ne désactive pas le module : il reste chargé et accessible depuis le Centre.")
D("CTR_BAR_HIDE_MISSING", "Masquer les onglets des modules non chargés")
D("CTR_BAR_SEC_WIN",   "Fenêtres des modules")
D("CTR_BAR_OPENALL",   "Tout ouvrir")
D("CTR_BAR_CLOSEALL",  "Tout fermer")
D("CTR_BAR_SEC_MM",    "Minicarte")
D("CTR_BAR_MMHIDE",    "Masquer le bouton de la minicarte")
D("CTR_BAR_SEC_LOGIN", "Messages de connexion")
D("CTR_BAR_LOGIN_FULL","Complets")
D("CTR_BAR_LOGIN_ONE", "Une seule ligne")
D("CTR_BAR_LOGIN_NONE","Aucun")
D("CTR_BAR_SEC_GM",    "Menu Échap")
D("CTR_BAR_GM",        "Ligne TibiSuite dans le menu Échap")
D("CTR_BAR_GM_NOTE",   "Placée sous EllesmereUI quand il est présent, sinon sous « Boutique ». Elle ouvre ce Centre. Pris en compte à la prochaine ouverture du menu.")
D("CTR_SOCLE",         "socle v")
D("CTR_UNAVAIL",       "Centre indisponible (socle v13 requis).")
D("CTR_SET_DESC",     "Tous les réglages de la suite et de ses modules sont réunis dans le Centre TibiSuite.")
D("CTR_SET_OPEN",      "Ouvrir le Centre TibiSuite")
D("CTR_SET_HINT",      "Raccourcis : /ts, clic droit sur le bouton de la minicarte, ou la ligne TibiSuite du menu Échap.")

-- ── Dimensions ─────────────────────────────────────────────────────
local W, H        = 860, 580
local HDR, FOOT   = 48, 44
local SIDE        = 214
local ROW_W, ROW_H = SIDE - 26, 24
local PANE_X      = SIDE + 1 + 20          -- marge gauche de la page
local BODY_TOP    = 62                     -- en-tete de page
local PAGE_FOOT   = 36                     -- boutons de page

local GENERAL = {
  { id = "home",   label = "CTR_HOME"   },
  { id = "bar",    label = "CTR_BAR"    },
  { id = "doctor", label = "CTR_DOCTOR" },
  { id = "maint",  label = "CTR_MAINT"  },
}

local K, UI, ACC
local frame, listC, search
local rows, labels = {}, {}
local pages = {}                -- id -> frame
local panelCache = {}           -- id -> panneau socle ancre
local hdr = {}                  -- elements de l'en-tete de page
local foot = {}                 -- boutons de page
local note                      -- message (module non charge, etc.)
local pendingTxt, reloadBtn
local current = "home"
local byKey = {}
local docked                    -- panneau socle actuellement ancre dans la page

-- Taille variable (poignee bas-droit) : largeurs calculees a la volee.
local MIN_W, MIN_H = 760, 480
local function PaneW() return math.floor((frame and frame:GetWidth() or W) - PANE_X - 20) end
local function DockW() return PaneW() - 24 end

local function Hex(c)
  return string.format("|cFF%02X%02X%02X", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end
local function ModCol(mod) local c = mod.col or { r = 0.6, g = 0.6, b = 0.6 }; return { c.r, c.g, c.b } end

-- ── Etat d'un module ───────────────────────────────────────────────
local function ModState(mod)
  if not TibiSuite.ModuleExists(mod.addonName) then return "absent" end
  local loaded = C_AddOns.IsAddOnLoaded(mod.addonName)
  local on = TibiSuite.IsModuleEnabled(mod.key)
  if on and loaded then return "on" end
  if on then return "load" end
  if loaded then return "unload" end
  return "off"
end

local STATE_TXT = {
  on     = function() return K.ICON_OK .. " " .. K.HX.OK .. L.CTR_ST_ON .. "|r" end,
  load   = function() return K.ICON_WAIT .. " " .. K.HX.GOLD .. L.CTR_ST_LOAD .. "|r" end,
  unload = function() return K.ICON_WAIT .. " " .. K.HX.WARN .. L.CTR_ST_UNLOAD .. "|r" end,
  off    = function() return K.HX.DIM .. L.CTR_ST_OFF .. "|r" end,
  absent = function() return K.HX.DIM .. L.CTR_ST_ABSENT .. "|r" end,
}

local function PendingCount()
  local n = 0
  for _ in pairs(TibiSuite.pendingReload or {}) do n = n + 1 end
  return n
end

-- ── Recuperation du panneau d'options d'un module ──────────────────
-- On ouvre le panneau par la voie habituelle du module, puis on lit le
-- dernier panneau affiche dans le registre du socle. Si l'appel a referme
-- un panneau deja ouvert (bascule), un second appel le rouvre.
local function GrabPanel(id, opener)
  if panelCache[id] then return panelCache[id] end
  if not (UI and UI.panels) then return nil end
  UI.lastShownPanel = nil
  pcall(opener)
  local p = UI.lastShownPanel
  if not p then pcall(opener); p = UI.lastShownPanel end
  if p and p.Dock then panelCache[id] = p; return p end
  return nil
end

local function ModuleOpener(mod)
  return function()
    local reg = TibiSuite.registered and TibiSuite.registered[mod.key]
    if reg and type(reg.onOptions) == "function" then reg.onOptions(); return end
    local fn = mod.optionsFn and _G[mod.optionsFn]
    if type(fn) == "function" then fn() end
  end
end

-- ── Briques ────────────────────────────────────────────────────────
local function Page(id)
  local p = pages[id]
  if not p then
    p = CreateFrame("Frame", nil, frame.body)
    p:SetAllPoints(frame.body)
    p:Hide()
    pages[id] = p
  end
  return p
end

local function SetFooter(list)
  for i, b in ipairs(foot) do
    local spec = list and list[i]
    if spec then
      b._label:SetText(spec[1])
      b:SetScript("OnClick", spec[2])
      b:Show()
    else
      b:Hide()
    end
  end
end

local function SetHeader(logo, title, col, desc, status)
  hdr.logo:SetTexture(logo or K.LOGO)
  hdr.title:SetText(title or "")
  local c = col or ACC
  hdr.title:SetTextColor(c[1], c[2], c[3])
  hdr.desc:SetText(desc or "")
  hdr.status:SetText(status or "")
end

local function ShowNote(text, btnLabel, onClick)
  note.text:SetText(text or "")
  if btnLabel then
    note.btn._label:SetText(btnLabel)
    note.btn:SetScript("OnClick", onClick)
    note.btn:Show()
  else
    note.btn:Hide()
  end
  note:Show()
end

local Select, RefreshAll

-- ── Interrupteur d'un module ───────────────────────────────────────
local function ToggleModule(mod)
  local wasLoaded = C_AddOns.IsAddOnLoaded(mod.addonName)
  local on = not TibiSuite.IsModuleEnabled(mod.key)
  local st = TibiSuite.SetModuleEnabled(mod.key, on)
  local name = Hex(ModCol(mod)) .. mod.addonName .. "|r"
  local msg
  if st == "loaded" then msg = L.CTR_TOAST_ON
  elseif st == "reload" then msg = L.CTR_TOAST_RELOAD
  elseif st == "off" then msg = wasLoaded and L.CTR_TOAST_OFF or L.CTR_TOAST_OFF_NOW end
  if msg and TibiSuite.ShowToast then TibiSuite.ShowToast(name .. msg) end
  RefreshAll()
  if current == mod.key then Select(mod.key) end
end

-- ── Barre laterale ─────────────────────────────────────────────────
local function MakeRow(id, text, mod)
  local r = CreateFrame("Button", nil, listC)
  r:SetSize(ROW_W, ROW_H)
  r.sel = r:CreateTexture(nil, "BACKGROUND")
  r.sel:SetAllPoints()
  r.sel:SetColorTexture(ACC[1], ACC[2], ACC[3], 0.18)
  r.bar = r:CreateTexture(nil, "ARTWORK")
  r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(3)
  r.bar:SetColorTexture(ACC[1], ACC[2], ACC[3], 1)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.05)
  local x = 12
  if mod then
    local c = ModCol(mod)
    local dot = r:CreateTexture(nil, "ARTWORK")
    dot:SetSize(8, 8); dot:SetPoint("LEFT", 12, 0)
    dot:SetColorTexture(c[1], c[2], c[3], 1)
    r.dot = dot
    x = 26
  end
  r.txt = K.Text(r, "GameFontHighlightSmall", text)
  r.txt:SetPoint("LEFT", x, 0)
  r.txt:SetWidth(ROW_W - x - (mod and 64 or 8))
  r.txt:SetJustifyH("LEFT")
  r.txt:SetWordWrap(false)
  if mod then
    r.wait = r:CreateTexture(nil, "OVERLAY")
    r.wait:SetSize(13, 13)
    r.wait:SetPoint("RIGHT", -46, 0)
    r.wait:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
    r.sw = K.makeSwitch(r, ModCol(mod))
    r.sw:SetPoint("RIGHT", -4, 0)
    r.sw:SetScript("OnClick", function() ToggleModule(mod) end)
  end
  r:SetScript("OnClick", function() Select(id) end)
  r.id, r.mod, r.search = id, mod, UI.Normalize(text)
  rows[#rows + 1] = r
  return r
end

local function LayoutList()
  local q = UI.Normalize(search and search:GetText() or "")
  local y = -4
  local function place(lbl, group)
    local any = false
    for _, r in ipairs(rows) do
      if r.group == group and (q == "" or r.search:find(q, 1, true)) then any = true; break end
    end
    lbl:SetShown(any)
    if not any then
      for _, r in ipairs(rows) do if r.group == group then r:Hide() end end
      return
    end
    lbl:ClearAllPoints(); lbl:SetPoint("TOPLEFT", listC, "TOPLEFT", 12, y - 6)
    y = y - 24
    for _, r in ipairs(rows) do
      if r.group == group then
        local show = (q == "" or r.search:find(q, 1, true))
        r:SetShown(show)
        if show then
          r:ClearAllPoints(); r:SetPoint("TOPLEFT", listC, "TOPLEFT", 4, y)
          y = y - ROW_H - 2
        end
      end
    end
    y = y - 8
  end
  place(labels.general, "general")
  place(labels.modules, "modules")
  listC:SetHeight(math.max(-y + 6, 10))
end

local function RefreshRows()
  for _, r in ipairs(rows) do
    local sel = (r.id == current)
    r.sel:SetShown(sel); r.bar:SetShown(sel)
    if r.mod then
      local st = ModState(r.mod)
      if st == "absent" then
        r.txt:SetTextColor(K.COL.DIM[1], K.COL.DIM[2], K.COL.DIM[3])
        r.sw:Hide()
      else
        local c = sel and K.COL.TXT or K.COL.MUT
        r.txt:SetTextColor(c[1], c[2], c[3])
        r.sw:Show()
        r.sw._set(TibiSuite.IsModuleEnabled(r.mod.key))
      end
      r.wait:SetShown(st == "load" or st == "unload")
    else
      local c = sel and K.COL.TXT or K.COL.MUT
      r.txt:SetTextColor(c[1], c[2], c[3])
    end
  end
end

local function RefreshFooter()
  local n = PendingCount()
  if n > 0 then
    pendingTxt:SetText(K.ICON_WAIT .. " " .. K.HX.GOLD .. (n == 1 and L.CTR_PENDING_1 or (n .. L.CTR_PENDING_N)) .. "|r")
    reloadBtn:Show()
  else
    pendingTxt:SetText("")
    reloadBtn:Hide()
  end
end

-- ── Pages generales ────────────────────────────────────────────────
-- Place cartes et boutons de l'Accueil selon la largeur courante.
local function LayoutHome(p)
  local pw = PaneW()
  local cw = math.floor((pw - 20) / 3)
  p.intro:SetWidth(pw - 10)
  p.tip:SetWidth(pw - 10)
  for i, c in ipairs(p.cardFrames) do
    c:SetSize(cw, 62)
    c:ClearAllPoints(); c:SetPoint("TOPLEFT", (i - 1) * (cw + 10), -58)
  end
  for i, b in ipairs(p.quickBtns) do
    b:SetSize(cw, 30)
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", ((i - 1) % 3) * (cw + 10), -162 - math.floor((i - 1) / 3) * 40)
  end
end

local function BuildHome(p)
  local intro = K.Text(p, "GameFontHighlight", L.INTRO or "", K.COL.MUT, PaneW() - 10)
  intro:SetPoint("TOPLEFT", 0, -2)
  p.intro = intro
  p.cards, p.cardFrames, p.quickBtns = {}, {}, {}
  local cw = math.floor((PaneW() - 20) / 3)
  for i, lbl in ipairs({ L.CTR_CARD_MODULES, L.CTR_CARD_RELOAD, L.CTR_CARD_VERSION }) do
    local c = K.Card(p)
    c:SetSize(cw, 62)
    local l = K.Text(c, "GameFontNormalSmall", lbl, K.COL.DIM)
    l:SetPoint("TOPLEFT", 12, -10)
    local v = K.Text(c, "GameFontHighlightLarge", "", K.COL.TXT)
    v:SetPoint("TOPLEFT", 12, -30)
    p.cards[i] = v
    p.cardFrames[i] = c
  end
  local q = K.Label(p, L.CTR_QUICK)
  q:SetPoint("TOPLEFT", 0, -140)
  local function hideThen(fn) return function() frame:Hide(); fn() end end
  local quick = {
    { L.CTR_Q_BAR,     function() SlashCmdList["TIBISUITE"]("bar") end },
    { L.CTR_Q_SETUP,   hideThen(function() if TibiSuite.RunSetup then TibiSuite.RunSetup() end end) },
    { L.CTR_Q_NEWS,    hideThen(function() if TibiSuite.ShowWhatsNew then TibiSuite.ShowWhatsNew(true) end end) },
    { L.CTR_Q_PROFILE, hideThen(function() if TibiSuite.OpenProfileWindow then TibiSuite.OpenProfileWindow() end end) },
    { L.CTR_Q_EXPORT,  function()
        if _G.Stats and _G.Stats.ShowExportPopup then frame:Hide(); _G.Stats.ShowExportPopup()
        elseif TibiSuite.ShowToast then TibiSuite.ShowToast(L.TOAST_NEED_STATS or "Stats") end
      end },
    { L.CTR_Q_DOCTOR,  function() Select("doctor") end },
  }
  for i, spec in ipairs(quick) do
    local b = K.Btn(p, cw, 30, spec[1])
    b:SetScript("OnClick", spec[2])
    p.quickBtns[i] = b
  end
  local tip = K.Text(p, "GameFontDisableSmall", L.CTR_HOME_TIP, K.COL.DIM, PaneW() - 10)
  tip:SetPoint("TOPLEFT", 0, -260)
  p.tip = tip
  LayoutHome(p)
end

local function RefreshHome(p)
  local on, present = 0, 0
  for _, mod in ipairs(TibiSuite.GetCatalog()) do
    if TibiSuite.ModuleExists(mod.addonName) then
      present = present + 1
      if C_AddOns.IsAddOnLoaded(mod.addonName) then on = on + 1 end
    end
  end
  p.cards[1]:SetText(on .. " / " .. present)
  local n = PendingCount()
  p.cards[2]:SetText(n == 0 and L.CTR_RELOAD_NONE or (K.HX.GOLD .. n .. L.CTR_RELOAD_WAIT .. "|r"))
  p.cards[3]:SetText((TibiSuite.VERSION or "?") .. K.HX.DIM .. "  " .. L.CTR_SOCLE .. tostring(UI._version) .. "|r")
end

local barPanel
local function BuildBarPanel()
  if barPanel then return barPanel end
  local P = UI.CreateOptionsPanel({ name = "TibiSuiteCentreBar", title = L.CTR_BAR, accent = ACC })
  local function apply(t) if TibiSuite.ApplyBarSettings then TibiSuite.ApplyBarSettings(t) end end
  P:Section(L.CTR_BAR_SEC_STYLE)
  P:Note(L.CTR_BAR_STYLE_NOTE)
  for _, o in ipairs({ { "classic", L.CTR_BAR_STYLE_CLASSIC }, { "dock", L.CTR_BAR_STYLE_DOCK }, { "panel", L.CTR_BAR_STYLE_PANEL } }) do
    P:Check(o[2], function() return (TibiSuite.GetBarStyle and TibiSuite.GetBarStyle() or "classic") == o[1] end,
      function() apply({ style = o[1] }); P:Refresh() end)
  end
  P:Check(L.CTR_BAR_DOCKLBL, function() return TibiSuiteDB.dockLabels ~= false end,
    function(v) apply({ dockLabels = v }) end)
  P:Section(L.CTR_BAR_SEC_LAYOUT)
  P:Check(L.CTR_BAR_OPEN,     function() return TibiSuiteCharDB and TibiSuiteCharDB.barOpen end, function(v) apply({ open = v }) end)
  P:Check(L.CTR_BAR_VERTICAL, function() return TibiSuiteDB.vertical end, function(v) apply({ vertical = v }) end)
  P:Check(L.CTR_BAR_LOCKED,   function() return TibiSuiteDB.locked end,   function(v) apply({ locked = v }) end)
  P:Slider(L.CTR_BAR_SCALE, 70, 150, 5,
    function() return math.floor((TibiSuiteDB.scale or 1) * 100 + 0.5) end,
    function(v) if math.abs((TibiSuiteDB.scale or 1) * 100 - v) > 0.5 then apply({ scale = v / 100 }) end end)
  P:Note(L.CTR_BAR_GRID_NOTE)
  P:Slider(L.CTR_BAR_COLS, 1, #TibiSuite.GetCatalog(), 1,
    function() return TibiSuiteDB.cols or 2 end,
    function(v) if (TibiSuiteDB.cols or 2) ~= v then apply({ cols = v }) end end)
  P:Slider(L.CTR_BAR_LOGO, 16, 64, 2,
    function() return TibiSuiteDB.logoSize or 22 end,
    function(v) if (TibiSuiteDB.logoSize or 22) ~= v then apply({ logoSize = v }) end end)
  P:Section(L.CTR_BAR_SEC_POS)
  P:Note(L.CTR_BAR_POS_NOTE)
  local function posX() local x = TibiSuite.GetBarPos(); return x end
  local function posY() local _, y = TibiSuite.GetBarPos(); return y end
  P:Slider(L.CTR_BAR_X, -1500, 1500, 1, posX,
    function(v) if posX() ~= v then TibiSuite.SetBarPos(v, posY()) end end)
  P:Slider(L.CTR_BAR_Y, -1500, 1500, 1, posY,
    function(v) if posY() ~= v then TibiSuite.SetBarPos(posX(), v) end end)
  P:Button(L.CTR_BAR_RECENTER, function() SlashCmdList["TIBISUITE"]("reset"); P:Refresh() end)

  -- Onglets affiches dans la barre (le module reste charge : seul son
  -- onglet disparait de la barre).
  P:Section(L.CTR_BAR_SEC_TABS)
  P:Note(L.CTR_BAR_TABS_NOTE)
  for _, mod in ipairs(TibiSuite.GetCatalog()) do
    local label = Hex(ModCol(mod)) .. tostring(mod.label) .. "|r"
    if mod.label ~= mod.addonName then label = label .. K.HX.DIM .. "  (" .. mod.addonName .. ")|r" end
    P:Check(label, function() return TibiSuite.IsTabShown(mod.key) end,
      function(v) TibiSuite.SetTabShown(mod.key, v) end)
  end
  P:Button(L.OPT_HIDE_MISSING_BTN or L.CTR_BAR_HIDE_MISSING, function()
    for _, mod in ipairs(TibiSuite.GetCatalog()) do
      if not C_AddOns.IsAddOnLoaded(mod.addonName) then TibiSuite.SetTabShown(mod.key, false) end
    end
    P:Refresh()
  end)

  P:Section(L.CTR_BAR_SEC_WIN)
  P:Button(L.CTR_BAR_OPENALL,  function() TibiSuite.SetAllModulesShown(true) end)
  P:Button(L.CTR_BAR_CLOSEALL, function() TibiSuite.SetAllModulesShown(false) end)
  P:Section(L.CTR_BAR_SEC_GM)
  P:Note(L.CTR_BAR_GM_NOTE)
  P:Check(L.CTR_BAR_GM, function() return TibiSuite.IsGameMenuEntryOn and TibiSuite.IsGameMenuEntryOn() end,
    function(v) if TibiSuite.SetGameMenuEntry then TibiSuite.SetGameMenuEntry(v) end end)
  P:Section(L.CTR_BAR_SEC_MM)
  P:Check(L.CTR_BAR_MMHIDE, function() return TibiSuiteDB.mmHidden end,
    function(v) if TibiSuite.SetMinimapHidden then TibiSuite.SetMinimapHidden(v) end end)
  P:Section(L.CTR_BAR_SEC_LOGIN)
  for _, o in ipairs({ { "full", L.CTR_BAR_LOGIN_FULL }, { "one", L.CTR_BAR_LOGIN_ONE }, { "none", L.CTR_BAR_LOGIN_NONE } }) do
    P:Check(o[2], function() return (TibiSuiteDB.loginMsg or "one") == o[1] end,
      function() TibiSuiteDB.loginMsg = o[1]; P:Refresh() end)
  end
  barPanel = P
  return P
end

local function BuildDoctor(p)
  local sc = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
  sc:SetPoint("TOPLEFT", 0, 0)
  sc:SetPoint("BOTTOMRIGHT", -24, 0)
  if UI.SkinScrollBar then UI.SkinScrollBar(sc, ACC) end
  local c = CreateFrame("Frame", nil, sc)
  c:SetSize(DockW(), 10)
  sc:SetScrollChild(c)
  local fs = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", 4, -4)
  fs:SetWidth(DockW() - 10)
  fs:SetJustifyH("LEFT")
  fs:SetSpacing(4)
  p.fs, p.child = fs, c
end

local function RunDoctorInto(p)
  local lines = {}
  local function emit(s) lines[#lines + 1] = s end
  if TibiSuite.RunDoctor then pcall(TibiSuite.RunDoctor, emit) end
  lines[#lines + 1] = " "
  if TibiSuite.RunPerf then pcall(TibiSuite.RunPerf, emit) end
  p.fs:SetText(table.concat(lines, "\n"))
  p.child:SetHeight((p.fs:GetStringHeight() or 100) + 12)
end

local function LayoutDoctor(p)
  p.child:SetWidth(DockW())
  p.fs:SetWidth(DockW() - 10)
  p.child:SetHeight((p.fs:GetStringHeight() or 100) + 12)
end

-- Recalcule tout ce qui depend de la largeur (poignee de redimensionnement).
local function Relayout()
  if not frame then return end
  local pw = PaneW()
  hdr.desc:SetWidth(pw - 44)
  note.text:SetWidth(pw - 20)
  if pages.home and pages.home.cardFrames then LayoutHome(pages.home) end
  if pages.doctor and pages.doctor.fs then LayoutDoctor(pages.doctor) end
  if docked and docked:IsDocked() then docked:SetContentWidth(DockW()) end
end

-- ── Selection d'une page ───────────────────────────────────────────
function Select(id)
  current = id
  docked = nil
  for _, pg in pairs(pages) do pg:Hide() end
  note:Hide()
  SetFooter(nil)
  RefreshRows()

  if id == "home" then
    local p = Page("home")
    if not p.cards then BuildHome(p) end
    RefreshHome(p)
    SetHeader(K.LOGO, L.CTR_HOME, ACC, L.CTR_HOME_DESC)
    p:Show()
    return
  elseif id == "bar" then
    local p = Page("bar")
    SetHeader(K.LOGO, L.CTR_BAR, ACC, L.CTR_BAR_DESC)
    p:Show()
    docked = BuildBarPanel(); docked:Dock(p, DockW())
    return
  elseif id == "doctor" then
    local p = Page("doctor")
    if not p.fs then BuildDoctor(p) end
    SetHeader(K.LOGO, L.CTR_DOCTOR, ACC, L.CTR_DOCTOR_DESC)
    p:Show()
    RunDoctorInto(p)
    SetFooter({ { L.CTR_DOC_RERUN, function() RunDoctorInto(p) end } })
    return
  elseif id == "maint" then
    local p = Page("maint")
    SetHeader(K.LOGO, L.CTR_MAINT, ACC, L.CTR_MAINT_DESC)
    p:Show()
    local panel = GrabPanel("maint", function() TibiSuite.OpenModulePanel() end)
    if panel then docked = panel; panel:Dock(p, DockW()) else ShowNote(L.CTR_NOTE_NOPANEL) end
    return
  end

  local mod = byKey[id]
  if not mod then return Select("home") end
  local st = ModState(mod)
  local slash = K.MODULE_SLASH[mod.key]
  local desc = (L["DESC_" .. mod.key] or "") .. (slash and ("\n" .. K.HX.DIM .. L.CTR_SLASH .. slash .. "|r") or "")
  SetHeader(K.MODULE_LOGO[mod.key], mod.addonName, ModCol(mod), desc, STATE_TXT[st]())

  local name = Hex(ModCol(mod)) .. mod.addonName .. "|r"
  local footer = {}
  if st == "on" or st == "unload" then
    footer[#footer + 1] = { L.CTR_OPEN_MOD, function() frame:Hide(); TibiSuite.OpenModule(mod.key) end }
  end
  if st ~= "absent" then
    footer[#footer + 1] = { L.CTR_REINSTALL, function()
      TibiSuite.ShowConfirm((L.CONFIRM_REINSTALL_MOD_FMT1 or "") .. name .. (L.CONFIRM_REINSTALL_MOD_FMT2 or ""),
        function() TibiSuite.ReinstallModule(mod.key) end)
    end }
  end
  if mod.curseUrl then
    footer[#footer + 1] = { L.CTR_CURSE, function() K.ShowURL(mod.curseUrl) end }
  end
  SetFooter(footer)

  if st == "absent" then
    ShowNote(L.CTR_NOTE_ABSENT)
  elseif st == "off" then
    ShowNote(L.CTR_NOTE_OFF, L.CTR_ENABLE, function() ToggleModule(mod) end)
  elseif st == "load" then
    ShowNote(L.CTR_NOTE_LOAD, L.CTR_RELOAD, function() TibiSuite.Reload() end)
  else
    local p = Page(mod.key)
    p:Show()
    local panel = GrabPanel(mod.key, ModuleOpener(mod))
    if panel then docked = panel; panel:Dock(p, DockW()) else ShowNote(L.CTR_NOTE_NOPANEL) end
  end
end

function RefreshAll()
  if not frame then return end
  RefreshRows()
  RefreshFooter()
  if current == "home" and pages.home and pages.home.cards then RefreshHome(pages.home) end
end

-- ── Construction de la fenetre ─────────────────────────────────────
local function Build()
  if frame then return true end
  K, UI = TibiSuite._kit, _G.TibiMidnight
  if not (K and UI and UI.CreateOptionsPanel and (UI._version or 0) >= 13) then return false end
  ACC = K.ACC

  local f = CreateFrame("Frame", "TibiSuiteCentre", UIParent, "BackdropTemplate")
  -- Taille memorisee (poignee bas-droit), bornee a l'ecran.
  local maxW = math.max(MIN_W, math.floor(UIParent:GetWidth() or W))
  local maxH = math.max(MIN_H, math.floor(UIParent:GetHeight() or H))
  local sw, sh = TibiSuiteDB.centreW or W, TibiSuiteDB.centreH or H
  f:SetSize(math.min(math.max(sw, MIN_W), maxW), math.min(math.max(sh, MIN_H), maxH))
  f:SetResizable(true)
  if f.SetResizeBounds then f:SetResizeBounds(MIN_W, MIN_H, maxW, maxH)
  elseif f.SetMinResize then f:SetMinResize(MIN_W, MIN_H); f:SetMaxResize(maxW, maxH) end
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:Hide()
  K.SkinLikeSuite(f, ACC)
  tinsert(UISpecialFrames, "TibiSuiteCentre")
  frame = f

  -- En-tete (zone de deplacement)
  local head = CreateFrame("Frame", nil, f)
  head:SetPoint("TOPLEFT", 1, -3)
  head:SetPoint("TOPRIGHT", -1, -3)
  head:SetHeight(HDR)
  head:EnableMouse(true)
  head:RegisterForDrag("LeftButton")
  head:SetScript("OnDragStart", function() f:StartMoving() end)
  head:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
  local hbg = head:CreateTexture(nil, "BACKGROUND")
  hbg:SetAllPoints()
  hbg:SetColorTexture(UI.C.HDR[1], UI.C.HDR[2], UI.C.HDR[3], 1)
  local logo = head:CreateTexture(nil, "ARTWORK")
  logo:SetSize(28, 28); logo:SetPoint("LEFT", 14, 0); logo:SetTexture(K.LOGO)
  local title = head:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
  title:SetText("TibiSuite")
  title:SetTextColor(ACC[1], ACC[2], ACC[3])
  local ver = K.Text(head, "GameFontDisableSmall", "v" .. tostring(TibiSuite.VERSION or "?"), K.COL.DIM)
  ver:SetPoint("LEFT", title, "RIGHT", 10, -1)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 0, -10)
  close:SetScript("OnClick", function() f:Hide() end)

  -- Barre laterale
  local side = CreateFrame("Frame", nil, f)
  side:SetPoint("TOPLEFT", 1, -(HDR + 3))
  side:SetPoint("BOTTOMLEFT", 1, FOOT + 1)
  side:SetWidth(SIDE)
  local sbg = side:CreateTexture(nil, "BACKGROUND")
  sbg:SetAllPoints(); sbg:SetColorTexture(0, 0, 0, 0.22)
  local sline = side:CreateTexture(nil, "ARTWORK")
  sline:SetPoint("TOPRIGHT"); sline:SetPoint("BOTTOMRIGHT"); sline:SetWidth(1)
  sline:SetColorTexture(1, 1, 1, 0.08)

  search = CreateFrame("EditBox", nil, side, "BackdropTemplate")
  search:SetSize(SIDE - 20, 24)
  search:SetPoint("TOPLEFT", 10, -10)
  search:SetBackdrop(K.FLAT)
  search:SetBackdropColor(1, 1, 1, 0.05)
  search:SetBackdropBorderColor(1, 1, 1, 0.12)
  search:SetFontObject("GameFontHighlightSmall")
  search:SetTextInsets(8, 8, 0, 0)
  search:SetAutoFocus(false)
  local ph = K.Text(search, "GameFontDisableSmall", L.CTR_FILTER, K.COL.DIM)
  ph:SetPoint("LEFT", 9, 0)
  search:SetScript("OnTextChanged", function(s) ph:SetShown(s:GetText() == ""); LayoutList() end)
  search:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)
  search:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)

  local sc = CreateFrame("ScrollFrame", nil, side, "UIPanelScrollFrameTemplate")
  sc:SetPoint("TOPLEFT", 0, -42)
  sc:SetPoint("BOTTOMRIGHT", -20, 6)
  if UI.SkinScrollBar then UI.SkinScrollBar(sc, ACC) end
  listC = CreateFrame("Frame", nil, sc)
  listC:SetSize(SIDE - 22, 10)
  sc:SetScrollChild(listC)

  labels.general = K.Label(listC, L.CTR_GENERAL)
  labels.modules = K.Label(listC, L.CTR_MODULES)
  for _, g in ipairs(GENERAL) do
    MakeRow(g.id, L[g.label]).group = "general"
  end
  for _, mod in ipairs(TibiSuite.GetCatalog()) do
    byKey[mod.key] = mod
    MakeRow(mod.key, mod.addonName, mod).group = "modules"
  end
  LayoutList()

  -- Page : en-tete, corps, boutons
  local pane = CreateFrame("Frame", nil, f)
  pane:SetPoint("TOPLEFT", PANE_X, -(HDR + 3 + 14))
  pane:SetPoint("BOTTOMRIGHT", -20, FOOT + 1 + 10)
  hdr.logo = pane:CreateTexture(nil, "ARTWORK")
  hdr.logo:SetSize(30, 30); hdr.logo:SetPoint("TOPLEFT", 0, 0)
  hdr.title = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  hdr.title:SetPoint("TOPLEFT", hdr.logo, "TOPRIGHT", 10, 0)
  hdr.status = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hdr.status:SetPoint("TOPRIGHT", 0, -2)
  hdr.desc = K.Text(pane, "GameFontDisableSmall", "", K.COL.MUT, PaneW() - 44)
  hdr.desc:SetPoint("TOPLEFT", hdr.title, "BOTTOMLEFT", 0, -4)
  local psep = pane:CreateTexture(nil, "ARTWORK")
  psep:SetColorTexture(UI.C.SEP[1], UI.C.SEP[2], UI.C.SEP[3], UI.C.SEP[4])
  psep:SetPoint("TOPLEFT", 0, -(BODY_TOP - 8)); psep:SetPoint("TOPRIGHT", 0, -(BODY_TOP - 8)); psep:SetHeight(1)

  local body = CreateFrame("Frame", nil, pane)
  body:SetPoint("TOPLEFT", 0, -BODY_TOP)
  body:SetPoint("BOTTOMRIGHT", 0, PAGE_FOOT + 6)
  f.body = body

  note = CreateFrame("Frame", nil, body)
  note:SetAllPoints(body)
  note:Hide()
  note.text = K.Text(note, "GameFontHighlight", "", K.COL.MUT, PaneW() - 20)
  note.text:SetPoint("TOPLEFT", 4, -10)
  note.btn = K.Btn(note, 200, 28, "", "pri")
  note.btn:SetPoint("TOPLEFT", note.text, "BOTTOMLEFT", 0, -16)

  for i = 1, 3 do
    local b = K.Btn(pane, 180, 28, "")
    b:SetPoint("BOTTOMLEFT", (i - 1) * 190, 0)
    b:Hide()
    foot[i] = b
  end

  -- Pied de fenetre
  local fsep = f:CreateTexture(nil, "ARTWORK")
  fsep:SetColorTexture(UI.C.SEP[1], UI.C.SEP[2], UI.C.SEP[3], UI.C.SEP[4])
  fsep:SetPoint("BOTTOMLEFT", 1, FOOT); fsep:SetPoint("BOTTOMRIGHT", -1, FOOT); fsep:SetHeight(1)
  local closeBtn = K.Btn(f, 100, 26, L.CTR_CLOSE)
  closeBtn:SetPoint("BOTTOMRIGHT", -26, 9)

  -- Poignee de redimensionnement (coin bas-droit). Pendant le glissement,
  -- la mise en page suit (au plus une passe toutes les 0,05 s) ; au
  -- relachement, la taille est memorisee dans TibiSuiteDB.
  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -3, 3)
  grip:SetFrameLevel(f:GetFrameLevel() + 20)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function(_, btn) if btn == "LeftButton" then f:StartSizing("BOTTOMRIGHT") end end)
  grip:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    TibiSuiteDB.centreW = math.floor(f:GetWidth() + 0.5)
    TibiSuiteDB.centreH = math.floor(f:GetHeight() + 0.5)
    Relayout()
  end)
  local layoutPending = false
  f:SetScript("OnSizeChanged", function()
    if layoutPending then return end
    layoutPending = true
    C_Timer.After(0.05, function() layoutPending = false; Relayout() end)
  end)
  closeBtn:SetScript("OnClick", function() f:Hide() end)
  reloadBtn = K.Btn(f, 190, 26, L.CTR_RELOAD, "pri")
  reloadBtn:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
  reloadBtn:SetScript("OnClick", function() TibiSuite.Reload() end)
  pendingTxt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pendingTxt:SetPoint("BOTTOMLEFT", 16, 16)

  if K.AddFadeIn then K.AddFadeIn(f, 0.15) end
  return true
end

-- ── API ────────────────────────────────────────────────────────────
function TibiSuite.OpenCentre(pageId)
  if not Build() then
    print("|cFFC41F3BTibiSuite|r : " .. L.CTR_UNAVAIL)
    return
  end
  if pageId then current = pageId end
  frame:Show()
  frame:Raise()
  RefreshAll()
  Select(current)
end

function TibiSuite.ToggleCentre(pageId)
  if frame and frame:IsShown() then frame:Hide() else TibiSuite.OpenCentre(pageId) end
end

function TibiSuite.IsCentreShown() return frame and frame:IsShown() or false end

-- Resynchronise la page « Barre et acces » si elle est a l'ecran (appele par
-- RefreshOptions du core : /ts lock, barre deplacee a la souris, profils...).
function TibiSuite.RefreshCentreBar()
  if barPanel and barPanel:IsDocked() and barPanel:IsShown() then barPanel:Refresh() end
end

-- ── Page dans Options > AddOns de Blizzard ─────────────────────────
-- Simple vitrine avec un bouton vers le Centre. On ne referme PAS la
-- fenetre d'options de Blizzard depuis notre code (aucun risque de taint) :
-- le Centre (strate DIALOG) s'ouvre par-dessus, Echap le referme d'abord.
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local kit = TibiSuite._kit or {}
    local p = CreateFrame("Frame", "TibiSuiteSettingsPage", UIParent)
    p:Hide()
    local logo = p:CreateTexture(nil, "ARTWORK")
    logo:SetSize(48, 48); logo:SetPoint("TOPLEFT", 16, -16)
    logo:SetTexture(kit.LOGO or "Interface\\AddOns\\TibiSuite\\medias\\TibiSuite")
    local t = p:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    t:SetPoint("LEFT", logo, "RIGHT", 12, 6)
    t:SetText("|cFFC41F3BTibiSuite|r")
    local v = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    v:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
    v:SetText("v" .. tostring(TibiSuite.VERSION or "?"))
    local d = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    d:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -16)
    d:SetWidth(520); d:SetJustifyH("LEFT")
    d:SetText(L.CTR_SET_DESC)
    local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    b:SetSize(260, 28); b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -14)
    b:SetText(L.CTR_SET_OPEN)
    b:SetScript("OnClick", function()
      C_Timer.After(0, function() if TibiSuite.OpenCentre then TibiSuite.OpenCentre() end end)
    end)
    local h = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    h:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -12)
    h:SetWidth(520); h:SetJustifyH("LEFT")
    h:SetText(L.CTR_SET_HINT)
    local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, p, "TibiSuite")
    if ok and cat then pcall(Settings.RegisterAddOnCategory, cat); TibiSuite.settingsCategory = cat end
  end)
end
