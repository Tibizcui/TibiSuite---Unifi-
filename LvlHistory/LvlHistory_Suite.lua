--[[============================================================================
  LvlHistory - Intégration TibiSuite "Midnight"  (ajout non destructif)
  Cet addon utilisait une palette brune : on l'harmonise en Midnight (FULLSKIN).
============================================================================]]

local FRAME    = "LvlHistoryMainFrame"
local ACCENT   = { 0.369, 0.886, 0.137 }   -- vert (logo #5EE223)
local LOGO     = "Interface\\AddOns\\LvlHistory\\Media\\icon"
local KEY      = "Lvl"
local FULLSKIN = true

local function GetUI() return _G.TibiMidnight end
local function Settings() local db = _G.LvlHistoryDB; return db and db.settings end
local L = LvlHistory and LvlHistory.L or {}
local function T(key, default) return L[key] or default end

-- ---------------------------------------------------------------- Options
local panel
local function BuildOptions()
  local ui = GetUI(); if not ui then return nil end
  if panel then return panel end
  panel = ui.CreateOptionsPanel({
    name = "LvlHistoryOptionsMidnight",
    title = "LvlHistory - Options", accent = ACCENT })

  panel:Section(T("OPT_SEC_WINDOW", "Fenêtre"))
  panel:Button(T("OPT_TOGGLE", "Ouvrir / fermer"), function()
    if _G.LvlHistory_Toggle then _G.LvlHistory_Toggle() end
  end)
  panel:Button(T("OPT_RECENTER", "Recentrer la fenêtre"), function()
    local f = _G[FRAME]; if f then f:ClearAllPoints(); f:SetPoint("CENTER") end
  end)
  panel:Slider(T("OPT_OPACITY", "Opacité (%)"), 30, 100, 5,
    function() local s = Settings(); return math.floor(((s and s.alpha) or 0.97) * 100 + 0.5) end,
    function(v)
      local s = Settings(); if s then s.alpha = v / 100 end
      local f = _G[FRAME]; if f then f:SetAlpha(v / 100) end
    end)

  panel:Section(T("OPT_SEC_TRACKING", "Suivi"))
  panel:Check(T("OPT_LEVEL_ALERT", "Message a chaque niveau (temps passe au niveau)"),
    function() local s = Settings(); return not s or s.levelAlert ~= false end,
    function(v) local s = Settings(); if s then s.levelAlert = v and true or false end end)
  panel:Check(T("OPT_RESUME", "Un /reload ne coupe pas la session (reprise sous 10 min)"),
    function() local s = Settings(); return not s or s.resumeSession ~= false end,
    function(v) local s = Settings(); if s then s.resumeSession = v and true or false end end)
  panel:Check(T("OPT_SESSION_ALERT", "Message au passage en mode Farming"),
    function() local s = Settings(); return not s or s.sessionAlert ~= false end,
    function(v) local s = Settings(); if s then s.sessionAlert = v and true or false end end)
  panel:Button(T("OPT_OPEN_LEVELS", "Ouvrir la chronologie des niveaux"), function()
    if LvlHistory.UI and LvlHistory.UI.OpenTab then LvlHistory.UI.OpenTab(6) end
  end)

  panel:Section(T("OPT_SEC_FLOATING", "Boutons flottants (barre TibiSuite)"))
  panel:Check(T("OPT_HIDE_OPTIONS_BTN", "Masquer le bouton Options"),
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("LvlHistoryMainFrame", "options") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("LvlHistoryMainFrame", "options", v) end end)
  panel:Check(T("OPT_HIDE_SEARCH_BTN", "Masquer le champ Recherche"),
    function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("LvlHistoryMainFrame", "search") end,
    function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden("LvlHistoryMainFrame", "search", v) end end)
  panel:Note(T("OPT_FLOATING_NOTE", "Le bouton Options et le champ Recherche debordent au-dessus de la fenetre. Meme masques, Maj+clic droit sur la fenetre ouvre ces options."))

  panel:Note(T("OPT_NOTE", "Astuce : clic droit sur la vignette Lvl Hist dans la barre TibiSuite ouvre aussi ces options."))
  return panel
end

function LvlHistory_OpenOptions()
  local p = BuildOptions(); if p then p:Toggle() end
end

-- ---------------------------------------------------------------- Recherche
-- On cherche parmi les personnages suivis, leurs zones, donjons et gouffres ;
-- un clic ouvre la fenetre sur l'onglet correspondant.
local function OpenOn(tab)
  return function()
    if LvlHistory.UI and LvlHistory.UI.OpenTab then LvlHistory.UI.OpenTab(tab)
    elseif _G.LvlHistory_Toggle then _G.LvlHistory_Toggle() end
  end
end

local function provider(q)
  local out, ui = {}, GetUI()
  local db = _G.LvlHistoryDB
  if not ui or type(db) ~= "table" or type(db.chars) ~= "table" then return out end
  local seen = {}
  local function add(text, tab)
    if seen[text] then return end
    seen[text] = true
    out[#out + 1] = { text = text, onClick = OpenOn(tab) }
  end
  for key, char in pairs(db.chars) do
    if type(char) == "table" then
      local label = tostring(key)
      if ui.Match(label, q) then
        add(label .. "  |cff808080" .. T("SEARCH_LEVEL_FMT", "niv. ") .. tostring(char.level or "?") .. "|r", 3)
      end
      for zname in pairs(type(char.zones) == "table" and char.zones or {}) do
        if type(zname) == "string" and ui.Match(zname, q) then
          add(zname .. "  |cff808080" .. label .. "|r", 2)
        end
      end
      for dname in pairs(type(char.dgnRuns) == "table" and char.dgnRuns or {}) do
        if type(dname) == "string" and ui.Match(dname, q) then
          add(dname .. "  |cff808080" .. T("SEARCH_DUNGEON", "donjon") .. "|r", 4)
        end
      end
      for vname in pairs(type(char.delveRuns) == "table" and char.delveRuns or {}) do
        if type(vname) == "string" and ui.Match(vname, q) then
          add(vname .. "  |cff808080" .. T("SEARCH_DELVE", "gouffre") .. "|r", 4)
        end
      end
    end
    if #out >= 60 then return out end
  end
  return out
end

local searchPopup
local function OpenSearch()
  local ui = GetUI(); if not ui then return end
  if not searchPopup then
    searchPopup = ui.CreateSearchPopup({
      name = "LvlHistorySearchPopup",
      title = "|cFF5EE223LvlHistory|r  " .. T("SEARCH_TITLE", "Recherche"), accent = ACCENT, logo = LOGO, provider = provider })
  end
  searchPopup.Toggle()
end

-- ---------------------------------------------------------- Attache & skin
local function Decorate()
  local ui = GetUI(); local f = _G[FRAME]
  if not (ui and f) then return end
  if not f._tibiSkinned then
    ui.SkinFrame(f, ACCENT)
    f._tibiSkinned = true
  end
  if f._tibiControls then return end
  ui.AddHeaderControls(f, {
    accent = ACCENT,
    onOptions = function() LvlHistory_OpenOptions() end,
    provider = provider,
  })
end

-- Inscription immediate au registre de recherche globale
-- (le provider lit les donnees a la volee ; plus fiable que PLAYER_LOGIN seul)
do local _u = GetUI(); if _u and _u.RegisterSearch then _u.RegisterSearch(KEY, T("MODULE_LABEL", "Lvl Hist"), provider) end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local ui = GetUI()
  if ui and ui.RegisterSearch then ui.RegisterSearch(KEY, T("MODULE_LABEL", "Lvl Hist"), provider) end
  C_Timer.After(1.0, Decorate)
  C_Timer.After(3.0, Decorate)
end)
