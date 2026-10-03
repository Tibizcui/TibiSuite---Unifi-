--[[============================================================================
  MiniHub - Integration TibiSuite "Midnight"  (ajout non destructif)
  Habillage socle du conteneur, controles d'en-tete (Options + Recherche) et
  fournisseur de recherche globale. Le panneau d'options lui-meme vit dans
  Options.lua (un seul panneau pour tout MiniHub).
============================================================================]]

local FRAME    = "MiniHubContainer"
local ACCENT   = { 0.988, 0.843, 0.282 }   -- or vif (logo #FCD748)
local LOGO     = "Interface\\AddOns\\MiniHub\\media\\Logo_MiniHub"
local KEY      = "MiniHub"

local function GetUI() return _G.TibiMidnight end
local function MH() return _G.MiniHub end
local function T(k)
  local m = MH()
  return (m and m.L and m.L[k]) or k
end

-- ---------------------------------------------------------------- Recherche
-- Cherche dans le nom lisible (titre de l'addon) ET le nom technique ; le clic
-- ouvre le hub et fait clignoter le bouton trouve.
local function provider(q)
  local out, ui = {}, GetUI()
  local m = MH()
  if not ui or not m or type(m.order) ~= "table" then return out end
  for _, btn in ipairs(m.order) do
    local info = m.GetInfo and m.GetInfo(btn)
    if info and (ui.Match(info.label, q) or ui.Match(info.name, q)) then
      local text = info.label
      if info.label ~= info.name then text = text .. "  |cFF888888" .. info.name .. "|r" end
      out[#out + 1] = { text = text,
        onClick = function() if m.Highlight then m.Highlight(btn) elseif m.Open then m.Open() end end }
      if #out >= 60 then return out end
    end
  end
  return out
end

local searchPopup
local function OpenSearch()
  local ui = GetUI(); if not ui then return end
  if not searchPopup then
    searchPopup = ui.CreateSearchPopup({
      name = "MiniHubSearchPopup",
      title = ui.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. "MiniHub|r  " .. T("SEARCH_TITLE"),
      accent = ACCENT, logo = LOGO, provider = provider })
  end
  searchPopup.Toggle()
end
if MH() then MH().OpenSearch = OpenSearch end

-- ---------------------------------------------------------- Attache & skin
local function Decorate()
  local ui = GetUI(); local f = _G[FRAME]
  if not (ui and f) then return end
  if not f._tibiSkinned then
    ui.SkinFrame(f, ACCENT)
    -- En-tete sobre : le titre MiniHub reste a sa place d'origine.
    if f.header and f.title then
      f.title:ClearAllPoints()
      f.title:SetPoint("LEFT", f.header, "LEFT", 7, 0)
    end
    f._tibiSkinned = true
  end
  if f._tibiControls then return end
  ui.AddHeaderControls(f, {
    accent = ACCENT,
    onOptions = function() if _G.MiniHub_OpenOptions then _G.MiniHub_OpenOptions() end end,
    provider = provider,
  })
end

-- Inscription immediate au registre de recherche globale
-- (le provider lit les donnees a la volee ; plus fiable que PLAYER_LOGIN seul)
do local _u = GetUI(); if _u and _u.RegisterSearch then _u.RegisterSearch(KEY, "MiniHub", provider) end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local ui = GetUI()
  if ui and ui.RegisterSearch then ui.RegisterSearch(KEY, "MiniHub", provider) end
  C_Timer.After(1.0, Decorate)
  C_Timer.After(3.0, Decorate)
end)
