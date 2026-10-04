--[[============================================================================
  Standby - Bridge.lua
  ---------------------------------------------------------------------------
    - StandbyAPI (globale publique, lecture seule) : un autre module peut
      savoir si l'ecran est affiche (Opacity, Stats plus tard) et lire le
      temps d'absence cumule d'un personnage ;
    - fournisseur de la recherche globale TibiSuite (loupe de la barre) ;
    - ligne de sante pour /ts doctor (Standby_DoctorNote, lue par le core) ;
    - sonde /standby probe : verifie en jeu ce qui n'a pas pu l'etre hors
      client. Resultat imprime ET garde dans StandbyDB.probe.
============================================================================]]

local ADDON, SB = ...
local T = SB.T

-- ============================================================================
-- StandbyAPI
-- ============================================================================
StandbyAPI = StandbyAPI or {}
StandbyAPI.version = 1

-- L'ecran d'absence est-il affiche ? (true aussi pendant un apercu)
function StandbyAPI.IsActive() return SB.active and true or false end
function StandbyAPI.IsPreview() return SB.preview and true or false end

-- Cumul d'un personnage ("Nom-Royaume", defaut : le personnage connecte) :
-- { count, total (s), longest (s), last = { at, dur, msgs } }
function StandbyAPI.GetTotals(charKey) return SB.Totals(charKey) end

function StandbyAPI.Preview() SB.Preview() end

-- ============================================================================
-- Recherche globale
-- ============================================================================
function SB.SearchProvider(query)
  local UI = _G.TibiMidnight
  local out = {}
  if not (UI and SB.db) then return out end
  local entries = {
    { T("SEARCH_PREVIEW", "Standby : aperçu de l'écran d'absence"), function() SB.Preview() end },
    { T("SEARCH_OPTIONS", "Standby : options"), function() Standby_OpenOptions() end },
  }
  for _, layout in ipairs(SB.LAYOUTS) do
    local label = ({ vitrine = T("LAYOUT_VITRINE", "Vitrine"), fiche = T("LAYOUT_FICHE", "Fiche"), epure = T("LAYOUT_EPURE", "Épurée"), eco = T("LAYOUT_ECO", "Économie") })[layout]
    entries[#entries + 1] = { T("SEARCH_LAYOUT", "Standby : mise en page ") .. label, function() SB.db.layout = layout; SB.Print(label) end }
  end
  for _, e in ipairs(entries) do
    if UI.Match(e[1] .. " standby afk absent away", query) then out[#out + 1] = { text = e[1], onClick = e[2] } end
  end
  return out
end

-- ============================================================================
-- /ts doctor : une ligne d'etat. Renvoie : texte, probleme (booleen).
-- ============================================================================
function Standby_DoctorNote()
  if not SB.db then return T("DOC_NODB", "sauvegarde pas encore chargée"), true end
  local db = SB.db
  local parts = {}
  local problem = false
  if not db.enabled then parts[#parts + 1] = T("ST_OFF", "désactivé") end
  if SB.ElvUIAFK() then parts[#parts + 1] = T("DOC_ELVUI", "en retrait (écran d'absence d'ElvUI actif)") end
  if db.safeMode then parts[#parts + 1] = T("DOC_SAFE", "mode sûr (le jeu a refusé le masquage de l'interface)"); problem = true end
  if db.restore and db.restore.cvars then parts[#parts + 1] = T("DOC_PENDING", "réglages à rétablir au prochain login"); problem = true end
  if OpacityDB and OpacityAPI then
    parts[#parts + 1] = T("DOC_OPACITY", "Opacity présent (son contexte Absent agit sous l'écran, sans conflit)")
  end
  parts[#parts + 1] = string.format(T("DOC_LAYOUT", "mise en page %s, fond %s"), db.layout, db.background)
  local tot = SB.Totals()
  parts[#parts + 1] = string.format(T("DOC_COUNT", "%d absence(s) sur ce personnage"), tot.count)
  return table.concat(parts, ", "), problem
end

-- ============================================================================
-- /standby probe
-- ============================================================================
local blockedDuringProbe = false

function SB.RunProbe()
  if InCombatLockdown() then SB.Print(T("MSG_COMBAT", "pas en combat.")); return end
  if SB.active then SB.Print(T("PROBE_ACTIVE", "fermez d'abord l'écran.")); return end
  local res = { when = date("%Y-%m-%d %H:%M"), build = select(4, GetBuildInfo()) }

  -- 1. Masquage de l'interface : Hide puis Show dans la meme image (aucun
  --    clignotement visible). Un refus du client leve ADDON_ACTION_BLOCKED.
  local wasSafe = SB.db.safeMode
  blockedDuringProbe = false
  local probeFrame = CreateFrame("Frame")
  probeFrame:RegisterEvent("ADDON_ACTION_BLOCKED"); probeFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
  probeFrame:SetScript("OnEvent", function(_, _, who) if who == ADDON then blockedDuringProbe = true end end)
  local okHide = pcall(UIParent.Hide, UIParent)
  local hidden = not UIParent:IsShown()
  local okShow = pcall(UIParent.Show, UIParent)
  res.uiHide = okHide and hidden and okShow and UIParent:IsShown() and true or false

  -- 2. Camera
  res.spinApi = type(MoveViewLeftStart) == "function" and type(MoveViewLeftStop) == "function"
  if res.spinApi then
    res.spinOk = pcall(MoveViewLeftStart, 0.001) and pcall(MoveViewLeftStop)
  end

  -- 3. Illustrations du journal
  SB.Scene.art = nil
  local cat = SB.Scene.ArtCatalog()
  res.artTiers, res.artImages, res.artResolved = 0, 0, 0
  if cat then
    local tex = probeFrame:CreateTexture()
    res.artTiers = #cat
    res.tierNames = {}
    for _, e in ipairs(cat) do
      res.tierNames[#res.tierNames + 1] = e.tier .. "=" .. tostring(e.name) .. "(" .. #e.images .. ")"
      res.artImages = res.artImages + #e.images
      local img = e.images[1]
      if img then
        tex:SetTexture(nil)
        tex:SetTexture(img.file)
        local id = tex.GetTextureFileID and tex:GetTextureFileID()
        if id and id ~= 0 then res.artResolved = res.artResolved + 1 end
      end
    end
  end
  res.expansionLevel = GetExpansionLevel and GetExpansionLevel() or nil

  -- 4. Chat et valeurs secretes
  res.issecretvalue = type(issecretvalue) == "function"
  res.sendChat = (C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function") and "C_ChatInfo" or (type(SendChatMessage) == "function" and "global" or "none")

  -- 5. CVars du mode economie (lecture seule)
  res.cvars = {}
  for _, n in ipairs({ "useMaxFPS", "maxFPS", "useMaxFPSBk", "maxFPSBk", "Sound_EnableAmbience" }) do
    local ok, v = pcall(C_CVar and C_CVar.GetCVar or GetCVar, n)
    res.cvars[n] = ok and tostring(v) or "?"
  end

  -- 6. Voisins et tuiles
  res.elvuiAFK = SB.ElvUIAFK()
  res.ellesmere = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EllesmereUI")) and true or false
  res.tiles = {}
  for _, t in ipairs(SB.Tiles.Collect()) do res.tiles[#res.tiles + 1] = t.key end

  probeFrame:UnregisterAllEvents()
  res.blocked = blockedDuringProbe
  if blockedDuringProbe and not wasSafe then SB.db.safeMode = true end
  SB.db.probe = res

  local G, R, Y = "|cFF66D98A", "|cFFFF7F7F", "|cFFFFD700"
  local function OK(b) return b and (G .. "OK|r") or (R .. T("PROBE_KO", "refusé") .. "|r") end
  SB.Print(T("PROBE_HEAD", "sonde (résultat aussi gardé dans StandbyDB.probe) :"))
  print("  " .. T("PROBE_UI", "Masquer l'interface : ") .. OK(res.uiHide and not res.blocked))
  print("  " .. T("PROBE_SPIN", "Rotation de la caméra : ") .. OK(res.spinApi and res.spinOk))
  print("  " .. string.format(T("PROBE_ART", "Illustrations : %s%d|r extensions, %s%d|r images, %d/%d lues"),
    Y, res.artTiers, Y, res.artImages, res.artResolved, res.artTiers))
  print("  " .. T("PROBE_SECRET", "Valeurs secrètes détectables : ") .. OK(res.issecretvalue))
  print("  " .. T("PROBE_ELVUI", "Écran d'absence ElvUI actif : ") .. Y .. tostring(res.elvuiAFK) .. "|r"
    .. "  ·  EllesmereUI : " .. Y .. tostring(res.ellesmere) .. "|r")
  print("  " .. T("PROBE_TILES", "Tuiles disponibles : ") .. Y .. table.concat(res.tiles, ", ") .. "|r")
  if res.blocked then print("  " .. R .. T("PROBE_BLOCKED", "Le jeu a refusé une action : mode sûr activé.") .. "|r") end
end
