--[[============================================================================
  TibiSuitePalette.lua  -  Palette de commandes (facon Ctrl+K)
  ---------------------------------------------------------------------------
  Un seul champ qui trouve tout :
    1. les COMMANDES de la suite (pages du Centre, recharger, style de barre,
       ouvrir / options / activer chaque module...) ;
    2. les REGLAGES de tous les panneaux d'options (index du socle v14,
       panel._items) : choisir un reglage ouvre la page du Centre et le
       surligne (panel:Reveal) ;
    3. le CONTENU des modules (recherche globale existante :
       UI.RunGlobalSearch, instances, factions, legendaires...).
  Clavier : Haut / Bas pour choisir, Entree pour valider, Echap pour fermer
  (gestionnaires de l'EditBox, aucune capture globale du clavier).
  Ouverture : raccourci (Bindings.xml), loupe de la barre, /ts k, Centre.

  API : TibiSuite.OpenPalette(query), TibiSuite.TogglePalette(),
        TibiSuite.ClosePalette().
============================================================================]]

local L = TibiSuiteL or {}
TibiSuiteL = L
local function D(k, v) if L[k] == nil then L[k] = v end end
D("PAL_PLACEHOLDER", "Chercher une commande, un réglage, une instance, une faction...")
D("PAL_HINT",        "Haut / Bas : choisir     Entrée : valider     Échap : fermer")
D("PAL_KIND_CMD",    "Commande")
D("PAL_KIND_SET",    "Réglage")
D("PAL_KIND_CONT",   "Contenu")
D("PAL_SUGGEST",     "SUGGESTIONS")
D("PAL_RECENT",      "RÉCENTS")
D("PAL_NONE",        "Aucun résultat. Essaie un nom de module, un réglage (« échelle », « son ») ou une instance.")
D("PAL_C_CENTRE",    "Ouvrir le Centre TibiSuite")
D("PAL_C_WEEK",      "Ma semaine")
D("PAL_C_ACTIVITY",  "Fil d'activité")
D("PAL_C_BARPAGE",   "Barre et accès")
D("PAL_C_DOCTOR",    "Diagnostic des modules")
D("PAL_C_MAINT",     "Maintenance")
D("PAL_C_SETUP",     "Relancer l'installateur")
D("PAL_C_NEWS",      "Quoi de neuf")
D("PAL_C_PROFILE",   "Exporter / importer un profil")
D("PAL_C_EXPORT",    "Code du Dashboard (Stats)")
D("PAL_C_RELOAD",    "Recharger l'interface")
D("PAL_C_BAR",       "Afficher / masquer la barre")
D("PAL_C_LOCK",      "Verrouiller / déverrouiller la barre")
D("PAL_C_STYLE_FMT", "Style de barre : %s")
D("PAL_C_ACC_SUITE", "Couleur d'accent : rouge TibiSuite")
D("PAL_C_ACC_CLASS", "Couleur d'accent : couleur de classe")
D("PAL_C_OPEN_FMT",  "Ouvrir %s")
D("PAL_C_OPT_FMT",   "Options de %s")
D("PAL_C_ON_FMT",    "Activer %s")
D("PAL_C_OFF_FMT",   "Désactiver %s")
D("PAL_C_STREAM_ON", "Mode streaming : activer (masquer nom et or)")
D("PAL_C_STREAM_OFF","Mode streaming : désactiver")
D("PAL_C_NEXT",      "Prochaine action")
D("PAL_C_PIN_FMT",   "Épingler %s à l'écran")
D("PAL_C_UNPIN_FMT", "Désépingler %s")
D("PAL_C_UNDO_FMT",  "Annuler : %s")
D("PAL_C_RP_NEW",    "Créer un point de restauration")
D("PAL_C_PROFILES",  "Profils et restauration")
D("PAL_C_DISPLAY",   "Lisibilité (taille, contraste, daltonisme)")
D("PAL_C_REMIND",    "Rappels")
D("PAL_C_SETUP_FMT", "Profil de suite : %s")
D("PAL_C_CONTRAST",  "Contraste élevé : activer / couper")
D("PAL_C_CVD",       "Couleurs pour daltoniens : activer / couper")
D("PAL_SUITE",       "TibiSuite")
D("PAL_KW_STYLE",    "classique dock panneau vivant apparence")

-- Raccourcis clavier (Echap > Options > Raccourcis > AddOns), Bindings.xml.
-- Categorie propre (comme Raider.IO, EllesmereUI) plutot que « Add-ons » :
-- WoW n'y affiche plus le nom de chaque addon.
BINDING_CATEGORY_TIBISUITE        = "TibiSuite"
BINDING_HEADER_TIBISUITE          = "TibiSuite"
BINDING_NAME_TIBISUITE_PALETTE    = L.BIND_PALETTE or "Palette de commandes"
BINDING_NAME_TIBISUITE_CENTRE     = L.BIND_CENTRE  or "Ouvrir / fermer le Centre"
BINDING_NAME_TIBISUITE_BAR        = L.BIND_BAR     or "Afficher / masquer la barre"
BINDING_NAME_TIBISUITE_WEEK       = L.BIND_WEEK    or "Ma semaine"
BINDING_NAME_TIBISUITE_ACTIVITY   = L.BIND_ACTIVITY or "Fil d'activité"
BINDING_NAME_TIBISUITE_STREAMING  = L.BIND_STREAMING or "Mode streaming (nom et or masqués)"
BINDING_NAME_TIBISUITE_NEXT       = L.BIND_NEXT or "Prochaine action"
BINDING_NAME_TIBISUITE_UNDO       = L.BIND_UNDO or "Annuler le dernier réglage"

D("PAL_HINT2",       "Haut / Bas : choisir     Tab : catégorie     Entrée : valider     Échap : fermer")
D("PAL_HINT_CHECK",  "Entrée : cocher / décocher ici     Maj + Entrée : ouvrir dans le Centre     Tab : catégorie")
D("PAL_HINT_SLIDER", "Gauche / Droite : ajuster ici     Entrée : ouvrir dans le Centre     Tab : catégorie")
D("PAL_F_ALL",       "Tout")
D("PAL_F_CMD",       "Commandes")
D("PAL_F_SET",       "Réglages")
D("PAL_F_MOD",       "Modules")
D("PAL_F_CONT",      "Contenu")
D("PAL_H_NEXT",      "PROCHAINE ACTION")
D("PAL_H_QUICK",     "ACTIONS RAPIDES")
D("PAL_H_CMD",       "COMMANDES")
D("PAL_H_SET",       "RÉGLAGES")
D("PAL_H_MOD",       "MODULES")
D("PAL_H_CONT",      "CONTENU")
D("PAL_KIND_MOD",    "Module")
D("PAL_ON",          "Activé")
D("PAL_OFF",         "Désactivé")
D("PAL_CONT_HINT",   "Tape un nom d'instance, de faction, d'objet... pour chercher dans le contenu des modules.")
D("PAL_NEXT_FMT",    "%s : %s")
D("PAL_UPTODATE",    "Tout est à jour")

local K, UI
local f, box, overlay, list, hint, chipsHost
local rows = {}
local chips = {}
local results = {}
local sel, offset = 1, 0
local filter = nil                        -- nil | "cmd" | "set" | "mod" | "cont"
local LIST_H, ROW_H, HEAD_H, PW = 342, 38, 24, 620
local MAX_ROWS = 16

-- Icones par type : une action (eclair), un reglage (engrenage), une page de
-- la suite (logo TibiSuite), un module (son logo), un contenu (son icone).
local ICON_ACT = "Interface\\Icons\\Spell_Nature_Lightning"
local ICON_SET = "Interface\\Icons\\INV_Misc_Gear_01"

local FILTERS = {
  { id = nil,    label = "PAL_F_ALL" },
  { id = "cmd",  label = "PAL_F_CMD" },
  { id = "set",  label = "PAL_F_SET" },
  { id = "mod",  label = "PAL_F_MOD" },
  { id = "cont", label = "PAL_F_CONT" },
}
local KIND = { cmd = "PAL_KIND_CMD", set = "PAL_KIND_SET", cont = "PAL_KIND_CONT", mod = "PAL_KIND_MOD" }
local HEAD = { cmd = "PAL_H_CMD", set = "PAL_H_SET", mod = "PAL_H_MOD", cont = "PAL_H_CONT" }

local function Norm(s)
  s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
  return UI and UI.Normalize(s) or s:lower()
end
local function Clean(s)
  return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))
end

-- Score : tous les mots de la requete doivent etre presents ; bonus si le
-- texte commence par la requete ou si un mot commence par elle.
local function Score(q, words, hay, title)
  for _, w in ipairs(words) do
    if not hay:find(w, 1, true) then return nil end
  end
  local s = 10
  if title:sub(1, #q) == q then s = s + 60
  elseif title:find(" " .. q, 1, true) then s = s + 35
  elseif title:find(q, 1, true) then s = s + 20 end
  return s - math.min(#title, 60) * 0.1
end

-- ── Sources ─────────────────────────────────────────────────────────
local function ModCol(mod) local c = mod.col or { r = 0.6, g = 0.6, b = 0.6 }; return { c.r, c.g, c.b } end

-- cat : "nav" (page de la suite), "act" (action), "mod" (lie a un module).
-- quick = vrai : propose dans « Actions rapides » quand la palette s'ouvre.
local function Commands()
  local out = {}
  local function add(text, run, kw, icon, col, cat, quick)
    cat = cat or (icon and "mod" or "act")
    out[#out + 1] = { kind = (cat == "mod") and "mod" or "cmd", cat = cat, text = text, run = run, kw = kw or "",
                      icon = icon or ((cat == "nav") and K and K.LOGO or ICON_ACT),
                      col = col, quick = quick, id = "cmd:" .. Clean(text) }
  end
  local O = TibiSuite.OpenCentre
  add(L.PAL_C_WEEK,     function() O("home") end, "accueil semaine reset tableau dashboard", nil, nil, "nav", true)
  add(L.PAL_C_CENTRE,   function() O() end, "centre options reglages parametres settings", nil, nil, "nav", true)
  add(L.PAL_C_ACTIVITY, function() O("activity") end, "notifications historique fil activite", nil, nil, "nav", true)
  add(L.PAL_C_BARPAGE,  function() O("bar") end, "barre minicarte menu echap accent couleur", nil, nil, "nav")
  if L.CTR_WIDGETS then
    add(L.CTR_WIDGETS,  function() O("widgets") end, "widgets epingler epingle ecran cartes", nil, nil, "nav")
  end
  add(L.PAL_C_PROFILES, function() O("profiles") end, "profil profils restauration restaurer point automatique specialisation personnage", nil, nil, "nav")
  add(L.PAL_C_DISPLAY,  function() O("display") end, "lisibilite taille texte contraste daltonien daltonisme accessibilite", nil, nil, "nav")
  add(L.PAL_C_REMIND,   function() O("reminders") end, "rappels rappel reset calendrier note alarme", nil, nil, "nav")
  add(L.PAL_C_DOCTOR,   function() O("doctor") end, "doctor diagnostic perf memoire cpu version", nil, nil, "nav")
  add(L.PAL_C_MAINT,    function() O("maint") end, "maintenance reinstaller profil", nil, nil, "nav")
  add(L.PAL_C_BAR,      function() SlashCmdList["TIBISUITE"]("bar") end, "barre afficher masquer onglets", nil, nil, "act", true)
  if TibiSuite.SetStreaming then
    local on = TibiSuite.IsStreaming()
    add(on and L.PAL_C_STREAM_OFF or L.PAL_C_STREAM_ON, function() TibiSuite.SetStreaming(not on) end,
      "streaming stream capture masquer nom or anonyme twitch", nil, nil, "act", true)
  end
  if TibiSuite.CanUndo and TibiSuite.CanUndo() then
    add(string.format(L.PAL_C_UNDO_FMT, TibiSuite.GetUndoLabel() or ""), function() TibiSuite.Undo() end,
      "annuler undo retour arriere ctrl z", nil, nil, "act", true)
  end
  add(L.PAL_C_RELOAD,   function() TibiSuite.Reload() end, "reload rl recharger interface", nil, nil, "act", true)
  add(L.PAL_C_SETUP,    function() if TibiSuite.RunSetup then TibiSuite.RunSetup() end end, "installateur installation setup", nil, nil, "act")
  add(L.PAL_C_NEWS,     function() if TibiSuite.ShowWhatsNew then TibiSuite.ShowWhatsNew(true) end end, "quoi de neuf nouveautes news", nil, nil, "act")
  add(L.PAL_C_PROFILE,  function() if TibiSuite.OpenProfileWindow then TibiSuite.OpenProfileWindow() end end, "profil ts1 exporter importer", nil, nil, "act")
  add(L.PAL_C_EXPORT,   function()
    if _G.Stats and _G.Stats.ShowExportPopup then _G.Stats.ShowExportPopup() end
  end, "dashboard export code stats companion site", nil, nil, "act")
  add(L.PAL_C_LOCK,     function() SlashCmdList["TIBISUITE"]("lock") end, "verrouiller deverrouiller lock barre", nil, nil, "act")
  for _, st in ipairs({ { "classic", L.CTR_BAR_STYLE_CLASSIC }, { "dock", L.CTR_BAR_STYLE_DOCK }, { "panel", L.CTR_BAR_STYLE_PANEL } }) do
    add(string.format(L.PAL_C_STYLE_FMT, st[2] or st[1]),
      function() if TibiSuite.ApplyBarSettings then TibiSuite.ApplyBarSettings({ style = st[1] }) end end, L.PAL_KW_STYLE, nil, nil, "act")
  end
  add(L.PAL_C_ACC_SUITE, function() TibiSuite.SetAccentMode("suite") end, "accent couleur rouge theme", nil, nil, "act")
  add(L.PAL_C_ACC_CLASS, function() TibiSuite.SetAccentMode("class") end, "accent couleur classe theme", nil, nil, "act")
  if TibiSuite.CreateRestorePoint then
    add(L.PAL_C_RP_NEW, function()
      local ok = TibiSuite.CreateRestorePoint(L.RP_MANUAL)
      if TibiSuite.ShowToast then TibiSuite.ShowToast(ok and L.RP_CREATED or L.RP_SAME) end
    end, "point restauration sauvegarde backup", nil, nil, "act")
  end
  if TibiSuite.GetSetupNames then
    for _, nm in ipairs(TibiSuite.GetSetupNames()) do
      add(string.format(L.PAL_C_SETUP_FMT, nm), function() TibiSuite.ApplySetup(nm) end, "profil appliquer charger", nil, nil, "act")
    end
  end
  if TibiSuite.ApplyReadability then
    add(L.PAL_C_CONTRAST, function()
      TibiSuiteDB.highContrast = (not TibiSuiteDB.highContrast) or nil; TibiSuite.ApplyReadability()
    end, "contraste lisibilite accessibilite", nil, nil, "act")
    add(L.PAL_C_CVD, function()
      TibiSuiteDB.cvd = (not TibiSuiteDB.cvd) or nil; TibiSuite.ApplyReadability()
    end, "daltonien daltonisme couleurs accessibilite", nil, nil, "act")
  end
  if TibiSuite.RunNextAction then
    add(L.PAL_C_NEXT, function() TibiSuite.RunNextAction() end, "prochaine action quoi faire suivant urgent", nil, nil, "act")
  end

  for _, mod in ipairs(TibiSuite.GetCatalog()) do
    if TibiSuite.ModuleExists(mod.addonName) then
      local icon = (TibiSuite.MODULE_LOGO and TibiSuite.MODULE_LOGO[mod.key]) or (K and K.LOGO)
      local col, name = ModCol(mod), mod.addonName
      local kw = (mod.label or "") .. " " .. (L["DESC_" .. mod.key] or "")
      local loaded = C_AddOns.IsAddOnLoaded(mod.addonName)
      if loaded then
        add(string.format(L.PAL_C_OPEN_FMT, name), function() TibiSuite.OpenModule(mod.key) end, kw, icon, col, "mod")
      end
      add(string.format(L.PAL_C_OPT_FMT, name), function() O(mod.key) end, kw .. " options reglages", icon, col, "mod")
      if TibiSuite.IsWidgetPinned then
        for _, pm in ipairs(TibiSuite.PinnableModules and TibiSuite.PinnableModules() or {}) do
          if pm.key == mod.key then
            local pinned = TibiSuite.IsWidgetPinned(mod.key)
            add(string.format(pinned and L.PAL_C_UNPIN_FMT or L.PAL_C_PIN_FMT, name),
              function() TibiSuite.PinWidget(mod.key, not pinned) end,
              kw .. " widget epingler epingle ecran carte", icon, col, "mod")
          end
        end
      end
      if TibiSuite.IsModuleEnabled(mod.key) then
        add(string.format(L.PAL_C_OFF_FMT, name), function()
          local s = TibiSuite.SetModuleEnabled(mod.key, false)
          if TibiSuite.ShowToast then TibiSuite.ShowToast(name .. (L.CTR_TOAST_OFF or "")) end
          return s
        end, kw .. " desactiver arreter", icon, col, "mod")
      else
        add(string.format(L.PAL_C_ON_FMT, name), function()
          local s = TibiSuite.SetModuleEnabled(mod.key, true)
          if TibiSuite.ShowToast then
            TibiSuite.ShowToast(name .. ((s == "reload") and (L.CTR_TOAST_RELOAD or "") or (L.CTR_TOAST_ON or "")))
          end
        end, kw .. " activer charger", icon, col, "mod")
      end
    end
  end
  return out
end

-- Reglages indexes par le socle (panel._items) des panneaux connus du Centre.
local function Settings()
  local out = {}
  if TibiSuite.PrebuildPanels then pcall(TibiSuite.PrebuildPanels) end
  local pageOf = TibiSuite.PANEL_PAGE or {}
  local extra = { TibiSuiteCentreBar = "bar", TibiSuiteCentreDisplay = "display", TibiSuiteCentreRemind = "reminders" }
  local PAGE_NAME = { bar = L.CTR_BAR, display = L.CTR_DISPLAY, reminders = L.CTR_REMIND }
  local byKey = {}
  for _, mod in ipairs(TibiSuite.GetCatalog()) do byKey[mod.key] = mod end
  for _, panel in ipairs(UI.panels or {}) do
    local page = panel._name and (pageOf[panel._name] or extra[panel._name])
    if page and panel._items then
      local mod = byKey[page]
      local owner = mod and mod.addonName or PAGE_NAME[page] or L.PAL_SUITE
      for _, it in ipairs(panel._items) do
        if it.kind ~= "section" then
          local label = Clean(it.label)
          out[#out + 1] = {
            kind = "set", cat = "set", text = label, panel = panel, sitem = it,
            sub = owner .. (it.section and ("  >  " .. Clean(it.section)) or ""),
            kw = owner .. " " .. Clean(it.section or ""), icon = ICON_SET, col = mod and ModCol(mod),
            id = "set:" .. (panel._name or "") .. ":" .. label,
            run = function()
              TibiSuite.OpenCentre(page)
              C_Timer.After(0.05, function() if panel.Reveal then panel:Reveal(it) end end)
            end,
          }
        end
      end
    end
  end
  return out
end

local function Content(q)
  local out = {}
  if not (UI and UI.RunGlobalSearch) then return out end
  local ok, res = pcall(UI.RunGlobalSearch, q)
  if not ok or type(res) ~= "table" then return out end
  for i, item in ipairs(res) do
    if i > 40 then break end
    out[#out + 1] = { kind = "cont", cat = "cont", text = Clean(item.text), sub = item._module, icon = item.icon,
                      run = item.onClick, id = "cont:" .. Clean(item.text) }
  end
  return out
end

-- Categorie de filtre d'un element.
local function FilterOf(it)
  if it.cat == "mod" then return "mod" end
  if it.cat == "set" then return "set" end
  if it.cat == "cont" then return "cont" end
  return "cmd"
end

-- ── Reglages modifies sur place ────────────────────────────────────
local function SettingValue(it)
  local si = it.sitem
  if not (si and si.get) then return nil end
  local ok, v = pcall(si.get)
  if ok then return v end
end

-- Meme photo que le socle : Annuler (pied du Centre, /ts undo) defait aussi
-- un changement fait depuis la palette.
local function RecordUndo(it)
  local panel = it.panel
  if not (UI and UI.RecordUndo and panel and panel._items) then return end
  pcall(UI.RecordUndo, panel, it.sitem, function()
    local t = {}
    for i, x in ipairs(panel._items) do
      if x.get then
        local ok, v = pcall(x.get)
        if ok then t[i] = (v == nil) and false or v end
      end
    end
    return t
  end)
end

local function SetSetting(it, v)
  RecordUndo(it)
  pcall(it.sitem.set, v)
  if it.panel and it.panel.Refresh then pcall(it.panel.Refresh, it.panel) end
end

-- ── Recherche ───────────────────────────────────────────────────────
local cmdCache, setCache

local function Recent()
  TibiSuiteDB.paletteRecent = TibiSuiteDB.paletteRecent or {}
  return TibiSuiteDB.paletteRecent
end

local function Remember(item)
  if item.kind == "cont" or item.synthetic then return end
  local r = Recent()
  for i = #r, 1, -1 do if r[i] == item.id then table.remove(r, i) end end
  table.insert(r, 1, item.id)
  while #r > 5 do table.remove(r) end
end

local function Head(text) results[#results + 1] = { head = text } end
local function Item(it) results[#results + 1] = { item = it } end

-- Ligne « Prochaine action » (accueil de la palette).
local function NextItem()
  if not TibiSuite.GetNextAction then return nil end
  local ok, na = pcall(TibiSuite.GetNextAction)
  if not ok then return nil end
  if not na then
    return { kind = "cmd", cat = "act", synthetic = true, text = L.PAL_UPTODATE, icon = K and K.LOGO,
             col = K and K.COL.OK, run = function() TibiSuite.OpenCentre("home") end, id = "next" }
  end
  local mod = na.mod
  return { kind = "cmd", cat = "act", synthetic = true, id = "next",
           text = string.format(L.PAL_NEXT_FMT, mod and mod.addonName or na.key, Clean(na.text or "")),
           icon = TibiSuite.MODULE_LOGO and TibiSuite.MODULE_LOGO[na.key], col = mod and ModCol(mod),
           run = function() TibiSuite.OpenModule(na.key) end }
end

local function Search(text)
  local q = Norm(text):gsub("^%s+", ""):gsub("%s+$", "")
  wipe(results)
  if q == "" then
    if filter == nil then
      -- Accueil : prochaine action, recents, actions rapides.
      local nx = NextItem()
      if nx then Head(L.PAL_H_NEXT); Item(nx) end
      local byId, seen = {}, {}
      for _, it in ipairs(cmdCache) do byId[it.id] = it end
      for _, it in ipairs(setCache) do byId[it.id] = it end
      local first = true
      for _, id in ipairs(Recent()) do
        local it = byId[id]
        if it then
          if first then Head(L.PAL_RECENT); first = false end
          Item(it); seen[id] = true
        end
      end
      first = true
      for _, it in ipairs(cmdCache) do
        if it.quick and not seen[it.id] then
          if first then Head(L.PAL_H_QUICK); first = false end
          Item(it)
        end
      end
    elseif filter == "cont" then
      -- Le contenu se cherche : rien a lister sans requete.
    else
      local src = (filter == "set") and setCache or cmdCache
      for _, it in ipairs(src) do
        if FilterOf(it) == filter then Item(it) end
      end
    end
    return
  end
  local words = {}
  for w in q:gmatch("%S+") do words[#words + 1] = w end
  local scored = {}
  local function consider(lst, bonus)
    for _, it in ipairs(lst) do
      if filter == nil or FilterOf(it) == filter then
        local title = Norm(it.text)
        local s = Score(q, words, title .. " " .. Norm(it.sub or "") .. " " .. Norm(it.kw or ""), title)
        if s then scored[#scored + 1] = { item = it, s = s + bonus } end
      end
    end
  end
  consider(cmdCache, 6)
  consider(setCache, 0)
  if filter == nil or filter == "cont" then consider(Content(q), -4) end
  table.sort(scored, function(a, b) return a.s > b.s end)
  if filter ~= nil then
    for i = 1, math.min(#scored, 60) do Item(scored[i].item) end
    return
  end
  -- Tout : regroupe par categorie, la plus pertinente d'abord, 8 par groupe.
  local groups, order = {}, {}
  for _, e in ipairs(scored) do
    local g = FilterOf(e.item)
    if not groups[g] then groups[g] = {}; order[#order + 1] = g end
    if #groups[g] < 8 then table.insert(groups[g], e.item) end
  end
  for _, g in ipairs(order) do
    Head(L[HEAD[g]])
    for _, it in ipairs(groups[g]) do Item(it) end
  end
end

-- ── Affichage ───────────────────────────────────────────────────────
local function EntryH(e) return e.head and HEAD_H or ROW_H end

-- Nombre d'entrees affichables a partir de `from` dans la hauteur de la liste.
local function FitFrom(from)
  local h, n = 0, 0
  for i = from, #results do
    local eh = EntryH(results[i])
    if h + eh > LIST_H or n >= MAX_ROWS then break end
    h, n = h + eh, n + 1
  end
  return n, h
end

local function SelectedItem() local e = results[sel]; return e and e.item end

local function PaintChips()
  local A = K.ACC
  for _, c in ipairs(chips) do
    local on = (c.fid == filter)
    if on then c.bg:SetColorTexture(A[1], A[2], A[3], 0.9) else c.bg:SetColorTexture(1, 1, 1, 0.06) end
    local light = on and TibiSuite.AccentIsLight and TibiSuite.AccentIsLight()
    if on then
      if light then c.txt:SetTextColor(0.08, 0.08, 0.1) else c.txt:SetTextColor(1, 1, 1) end
    else c.txt:SetTextColor(K.COL.MUT[1], K.COL.MUT[2], K.COL.MUT[3]) end
  end
end

local function Paint()
  PaintChips()
  local n, h = FitFrom(offset + 1)
  local y = 0
  for i = 1, MAX_ROWS do
    local r = rows[i]
    local e = (i <= n) and results[offset + i] or nil
    if e then
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", 0, -y)
      local eh = EntryH(e)
      r:SetHeight(eh)
      y = y + eh
      if e.head then
        r.headTxt:SetText(e.head); r.headTxt:Show()
        r.ico:Hide(); r.txt:Hide(); r.sub:Hide(); r.kind:Hide(); r.state:Hide()
        r.sel:Hide(); r.bar:Hide(); r.hl:Hide()
        r:EnableMouse(false)
      else
        local it = e.item
        r.headTxt:Hide(); r.hl:Show()
        r:EnableMouse(true)
        r.ico:SetTexture(it.icon or (K and K.LOGO)); r.ico:Show()
        r.txt:SetText(it.text or ""); r.txt:Show()
        local c = it.col or K.COL.TXT
        r.txt:SetTextColor(c[1], c[2], c[3])
        r.sub:SetText(it.sub or ""); r.sub:Show()
        r.kind:SetText(L[KIND[it.kind]] or ""); r.kind:Show()
        -- Etat du reglage, lu en direct.
        local st = ""
        if it.kind == "set" and it.sitem then
          local v = SettingValue(it)
          if it.sitem.kind == "check" then
            st = v and (K.HX.OK .. L.PAL_ON .. "|r") or (K.HX.DIM .. L.PAL_OFF .. "|r")
          elseif it.sitem.kind == "slider" and v ~= nil then
            st = K.HX.GOLD .. tostring(v) .. "|r"
          end
        end
        r.state:SetText(st); r.state:Show()
        local isSel = (offset + i) == sel
        r.sel:SetShown(isSel); r.bar:SetShown(isSel)
      end
      r:Show()
    else
      r:Hide()
    end
  end
  list:SetHeight(math.max(ROW_H, h))
  f:SetHeight(56 + 34 + math.max(ROW_H, h) + 30)
  local it = SelectedItem()
  local msg = L.PAL_HINT2
  if #results == 0 then msg = (filter == "cont" and Norm(box:GetText()) == "") and L.PAL_CONT_HINT or L.PAL_NONE
  elseif it and it.kind == "set" and it.sitem then
    if it.sitem.kind == "check" and it.sitem.set then msg = L.PAL_HINT_CHECK
    elseif it.sitem.kind == "slider" and it.sitem.min then msg = L.PAL_HINT_SLIDER end
  end
  hint:SetText(msg)
end

-- Premiere entree selectionnable a partir de i, dans le sens d.
local function Selectable(i, d)
  while results[i] and results[i].head do i = i + d end
  if results[i] then return i end
end

local function Ensure()
  if sel <= offset then
    offset = sel - 1
    if offset > 0 and results[offset] and results[offset].head then offset = offset - 1 end
  end
  while offset < sel - 1 and sel > offset + (FitFrom(offset + 1)) do offset = offset + 1 end
  offset = math.max(0, offset)
end

local function Move(d)
  if #results == 0 then return end
  local nxt = Selectable(sel + d, d)
  if not nxt then return end
  sel = nxt
  Ensure()
  Paint()
end

local function Run(i, openInCentre)
  local e = results[i or sel]
  if not (e and e.item and e.item.run) then return end
  local it = e.item
  Remember(it)
  -- Case a cocher : basculee sur place, la palette reste ouverte.
  if not openInCentre and it.kind == "set" and it.sitem and it.sitem.kind == "check" and it.sitem.set then
    SetSetting(it, not SettingValue(it))
    Paint()
    return
  end
  TibiSuite.ClosePalette()
  pcall(it.run)
end

local function Adjust(d)
  local it = SelectedItem()
  local si = it and it.sitem
  if not (it and it.kind == "set" and si and si.kind == "slider" and si.min and si.set) then return false end
  local v = tonumber(SettingValue(it)) or si.min
  local nv = math.max(si.min, math.min(si.max, v + d * (si.step or 1)))
  if nv ~= v then SetSetting(it, nv); Paint() end
  return true
end

local function Refresh()
  sel, offset = 1, 0
  Search(box:GetText())
  sel = Selectable(1, 1) or 1
  Paint()
end

local function SetFilter(fid)
  filter = fid
  Refresh()
end

local function CycleFilter(d)
  local idx = 1
  for i, fl in ipairs(FILTERS) do if fl.id == filter then idx = i end end
  idx = ((idx - 1 + d) % #FILTERS) + 1
  SetFilter(FILTERS[idx].id)
end

local function Build()
  if f then return true end
  K, UI = TibiSuite._kit, _G.TibiMidnight
  if not (K and UI) then return false end

  -- Voile sombre plein ecran : clic dessus = fermer.
  overlay = CreateFrame("Button", nil, UIParent)
  overlay:SetAllPoints(UIParent)
  overlay:SetFrameStrata("FULLSCREEN_DIALOG")
  local veil = overlay:CreateTexture(nil, "BACKGROUND")
  veil:SetAllPoints(); veil:SetColorTexture(0, 0, 0, 0.35)
  overlay:SetScript("OnClick", function() TibiSuite.ClosePalette() end)
  overlay:Hide()

  f = CreateFrame("Frame", "TibiSuitePalette", overlay, "BackdropTemplate")
  f:SetWidth(PW)
  f:SetPoint("TOP", UIParent, "TOP", 0, -math.floor((UIParent:GetHeight() or 768) * 0.16))
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetFrameLevel(overlay:GetFrameLevel() + 5)
  f:EnableMouse(true)
  K.SkinLikeSuite(f, K.ACC)

  local mag = f:CreateTexture(nil, "ARTWORK")
  mag:SetSize(18, 18); mag:SetPoint("TOPLEFT", 18, -19)
  mag:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
  box = CreateFrame("EditBox", nil, f)
  box:SetPoint("TOPLEFT", 46, -10); box:SetPoint("TOPRIGHT", -16, -10); box:SetHeight(36)
  box:SetFontObject("GameFontHighlightLarge")
  box:SetAutoFocus(false)
  local ph = K.Text(box, "GameFontDisable", L.PAL_PLACEHOLDER, K.COL.DIM)
  ph:SetPoint("LEFT", 2, 0)
  box:SetScript("OnTextChanged", function(s) ph:SetShown(s:GetText() == ""); Refresh() end)
  box:SetScript("OnEscapePressed", function() TibiSuite.ClosePalette() end)
  box:SetScript("OnEnterPressed", function() Run(nil, IsShiftKeyDown()) end)
  box:SetScript("OnTabPressed", function() CycleFilter(IsShiftKeyDown() and -1 or 1) end)
  box:SetScript("OnArrowPressed", function(_, key)
    if key == "UP" then Move(-1) elseif key == "DOWN" then Move(1)
    elseif key == "LEFT" then Adjust(-1) elseif key == "RIGHT" then Adjust(1) end
  end)

  -- Filtres par categorie (Tab / Maj + Tab, ou clic).
  chipsHost = CreateFrame("Frame", nil, f)
  chipsHost:SetPoint("TOPLEFT", 16, -54); chipsHost:SetPoint("TOPRIGHT", -16, -54); chipsHost:SetHeight(24)
  local x = 0
  for i, fl in ipairs(FILTERS) do
    local c = CreateFrame("Button", nil, chipsHost)
    c.fid = fl.id
    c.bg = c:CreateTexture(nil, "BACKGROUND"); c.bg:SetAllPoints()
    c.txt = K.Text(c, "GameFontHighlightSmall", L[fl.label], K.COL.MUT); c.txt:SetPoint("CENTER")
    c:SetSize((c.txt:GetStringWidth() or 40) + 24, 22)
    c:SetPoint("LEFT", x, 0)
    x = x + c:GetWidth() + 6
    c:SetScript("OnClick", function() SetFilter(fl.id); box:SetFocus() end)
    chips[i] = c
  end

  local sep = f:CreateTexture(nil, "ARTWORK")
  sep:SetPoint("TOPLEFT", 1, -84); sep:SetPoint("TOPRIGHT", -1, -84); sep:SetHeight(1)
  sep:SetColorTexture(1, 1, 1, 0.08)

  list = CreateFrame("Frame", nil, f)
  list:SetPoint("TOPLEFT", 8, -88); list:SetPoint("TOPRIGHT", -8, -88)
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(_, d)
    local maxOff = #results - 1
    offset = math.max(0, math.min(maxOff, offset - d))
    -- Garder une ligne choisie visible.
    local n = FitFrom(offset + 1)
    if sel <= offset or sel > offset + n then sel = Selectable(offset + 1, 1) or sel end
    Paint()
  end)
  local A = K.ACC
  for i = 1, MAX_ROWS do
    local r = CreateFrame("Button", nil, list)
    r:SetHeight(ROW_H)
    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetAllPoints(); r.sel:SetColorTexture(1, 1, 1, 0.07)
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetPoint("TOPLEFT", 0, -4); r.bar:SetPoint("BOTTOMLEFT", 0, 4); r.bar:SetWidth(3)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 1, 1, 0.04)
    r.ico = r:CreateTexture(nil, "ARTWORK"); r.ico:SetSize(22, 22); r.ico:SetPoint("LEFT", 12, 0)
    r.txt = K.Text(r, "GameFontHighlight", "", K.COL.TXT)
    r.txt:SetPoint("TOPLEFT", r.ico, "TOPRIGHT", 10, 2); r.txt:SetPoint("RIGHT", -150, 0)
    r.txt:SetJustifyH("LEFT"); r.txt:SetWordWrap(false)
    r.sub = K.Text(r, "GameFontHighlightSmall", "", K.COL.DIM)
    r.sub:SetPoint("TOPLEFT", r.txt, "BOTTOMLEFT", 0, -2); r.sub:SetPoint("RIGHT", -150, 0)
    r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false)
    r.kind = K.Text(r, "GameFontNormalSmall", "", K.COL.DIM); r.kind:SetPoint("RIGHT", -12, 0)
    r.state = K.Text(r, "GameFontNormalSmall", "", K.COL.TXT); r.state:SetPoint("RIGHT", r.kind, "LEFT", -12, 0)
    -- Titre de rubrique (ligne non selectionnable).
    r.headTxt = K.Label(r, ""); r.headTxt:SetPoint("BOTTOMLEFT", 12, 5)
    r.headTxt:SetTextColor(A[1], A[2], A[3])
    r:SetScript("OnClick", function() Run(offset + i, IsShiftKeyDown()) end)
    r:SetScript("OnEnter", function()
      local e = results[offset + i]
      if e and not e.head then sel = offset + i; Paint() end
    end)
    rows[i] = r
  end
  -- Couleur de la ligne choisie et des titres : accent du moment.
  local function tint()
    local Ac = K.ACC
    for _, r in ipairs(rows) do
      r.bar:SetColorTexture(Ac[1], Ac[2], Ac[3], 1)
      r.headTxt:SetTextColor(Ac[1], Ac[2], Ac[3])
    end
    PaintChips()
  end
  tint()
  if TibiSuite.OnAccentChanged then TibiSuite.OnAccentChanged(tint) end

  hint = K.Text(f, "GameFontDisableSmall", "", K.COL.DIM)
  hint:SetPoint("BOTTOMLEFT", 18, 10); hint:SetPoint("RIGHT", -18, 0); hint:SetJustifyH("LEFT")
  return true
end

-- ── API ─────────────────────────────────────────────────────────────
function TibiSuite.OpenPalette(query)
  if not Build() then return end
  cmdCache = Commands()
  setCache = Settings()
  filter = nil
  if TibiSuite.ApplyUIScaleTo then TibiSuite.ApplyUIScaleTo(f) end
  overlay:Show()
  box:SetText(query or "")
  box:SetFocus()
  Refresh()
end

function TibiSuite.ClosePalette()
  if overlay then overlay:Hide() end
  if box then box:ClearFocus() end
end

-- Acces de diagnostic et de test (/dump TibiSuite._paletteResults()).
function TibiSuite._paletteResults()
  local out = {}
  for _, e in ipairs(results) do if e.item then out[#out + 1] = e end end
  return out
end
function TibiSuite._paletteRaw() return results, sel end
function TibiSuite._paletteKey(k)
  if k == "TAB" then CycleFilter(1) elseif k == "ENTER" then Run() elseif k == "SHIFTENTER" then Run(nil, true)
  elseif k == "LEFT" then Adjust(-1) elseif k == "RIGHT" then Adjust(1)
  elseif k == "UP" then Move(-1) elseif k == "DOWN" then Move(1) end
end
function TibiSuite._paletteFilter() return filter end
function TibiSuite._paletteHint() return hint and hint:GetText() end

function TibiSuite.TogglePalette()
  if overlay and overlay:IsShown() then TibiSuite.ClosePalette() else TibiSuite.OpenPalette() end
end
