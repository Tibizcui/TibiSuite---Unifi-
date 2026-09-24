--[[============================================================================
  Opacity - Picker.lua  (pipette)
  ---------------------------------------------------------------------------
  Un calque plein ecran capte la souris le temps du choix (les clics ne
  partent donc pas dans l'interface en dessous). Sous le curseur, on cherche
  geometriquement (IsMouseOver) les frames NOMMEES candidates : enfants de
  UIParent et leurs enfants directs. La plus "haute" (strate, niveau, puis la
  plus petite) est surlignee ; la molette passe aux autres candidates.
    Clic gauche : ajoute la frame   Clic droit / Echap : annule

  Echap passe par UISpecialFrames (mecanisme natif, aucun code a nous sur la
  touche, cf. piege taint documente dans TibiSuiteCore.lua). Pas de OnHide
  non plus : la fin de pipette est detectee par le calque lui-meme.
  Refusee en combat, et annulee si un combat commence.

  Limite honnete : une frame SANS nom global ne peut pas etre memorisee
  (le profil identifie les frames par leur nom). La pipette l'ignore.
============================================================================]]

local ADDON, OP = ...
local T = OP.T

local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5,
                 FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

local overlay, hl, hlText, banner
local candidates, index = {}, 1
local clock = 0

local function IsOurs(f)
  return f == overlay or f == hl or f == banner
end

-- Toutes les lectures passent sous pcall, IsForbidden d'abord (via
-- OP.IsUsableFrame) : sous 12.x, UIParent contient des frames interdites dont
-- le moindre appel de methode leve une erreur, ce qui cassait toute la pipette.
local function Consider(f, list)
  if IsOurs(f) or not OP.IsUsableFrame(f) then return end
  local name = f:GetName()
  if not (name and OP.ValidName(name) and _G[name] == f) then return end
  if not f:IsVisible() or not f:IsMouseOver() then return end
  local w, h = f:GetWidth(), f:GetHeight()
  if not w or w < 4 or h < 4 then return end
  if w >= UIParent:GetWidth() * 0.98 and h >= UIParent:GetHeight() * 0.98 then return end
  list[#list + 1] = {
    frame = f, name = name, area = w * h,
    strata = STRATA[f:GetFrameStrata()] or 0, level = f:GetFrameLevel() or 0,
  }
end

-- Un enfant de UIParent sous la souris, et ses propres enfants directs.
local function ConsiderBranch(f, list)
  if IsOurs(f) or not OP.IsUsableFrame(f) then return end
  if not (f:IsVisible() and f:IsMouseOver()) then return end
  Consider(f, list)
  for _, c in ipairs({ f:GetChildren() }) do pcall(Consider, c, list) end
end

local function Gather()
  local list = {}
  local ok, children = pcall(function() return { UIParent:GetChildren() } end)
  if ok then
    for _, f in ipairs(children) do pcall(ConsiderBranch, f, list) end
  end
  table.sort(list, function(a, b)
    if a.strata ~= b.strata then return a.strata > b.strata end
    if a.level ~= b.level then return a.level > b.level end
    return a.area < b.area
  end)
  return list
end

local function Place()
  local c = candidates[index]
  if not c then hl:Hide(); return end
  local f = c.frame
  local l, b, w, h = f:GetRect()
  if not l then hl:Hide(); return end
  local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
  hl:ClearAllPoints()
  hl:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * s, b * s)
  hl:SetSize(math.max(w * s, 2), math.max(h * s, 2))
  local owner = OP.OwnerOf(c.name) or "?"
  local extra = ""
  if f:IsProtected() then extra = extra .. "  |cFFFFB347" .. T("TAG_PROTECTED", "protégée") .. "|r" end
  local managed = OP.ManagedBy(c.name)
  if managed then extra = extra .. "  |cFFFF7F7F" .. T("TAG_MANAGED", "gérée par ") .. managed .. "|r" end
  if OP.Profile().frames[c.name] then extra = extra .. "  |cFF66D98A" .. T("TAG_ALREADY", "déjà dans la liste") .. "|r" end
  hlText:SetText(string.format("|cFFFFFFFF%s|r  |cFFAAAAAA(%s)|r%s\n|cFF888888%d / %d  -  %s|r",
    c.name, owner, extra, index, #candidates, T("PICK_WHEEL", "molette : autre cadre")))
  hl:Show()
end

local function Stop()
  if overlay then overlay:Hide() end
  if hl then hl:Hide() end
end
OP.StopPicker = Stop

local function Build()
  local a = OP.ACCENT

  hl = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  hl:SetFrameStrata("FULLSCREEN_DIALOG")
  hl:SetFrameLevel(10)
  hl:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
  hl:SetBackdropColor(a[1], a[2], a[3], 0.15)
  hl:SetBackdropBorderColor(a[1], a[2], a[3], 0.95)
  hl:EnableMouse(false)
  hl:Hide()
  hlText = hl:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hlText:SetPoint("BOTTOMLEFT", hl, "TOPLEFT", 0, 4)
  hlText:SetJustifyH("LEFT")

  overlay = CreateFrame("Button", "OpacityPickerFrame", UIParent)
  overlay:SetAllPoints(UIParent)
  overlay:SetFrameStrata("FULLSCREEN_DIALOG")
  overlay:SetFrameLevel(20)
  overlay:EnableMouse(true)
  overlay:EnableMouseWheel(true)
  overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  overlay:Hide()
  tinsert(UISpecialFrames, "OpacityPickerFrame")   -- Echap ferme la pipette (natif)

  banner = CreateFrame("Frame", nil, overlay, "BackdropTemplate")
  banner:SetPoint("TOP", UIParent, "TOP", 0, -60)
  banner:SetSize(620, 30)
  banner:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  banner:SetBackdropColor(0.06, 0.07, 0.09, 0.92)
  banner:SetBackdropBorderColor(a[1], a[2], a[3], 0.9)
  local bt = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  bt:SetPoint("CENTER")
  bt:SetText(T("PICK_BANNER", "Pipette : survolez une fenêtre. Clic gauche = ajouter, molette = autre cadre, clic droit ou Échap = annuler."))

  overlay:SetScript("OnUpdate", function(_, dt)
    if InCombatLockdown() then Stop(); return end
    clock = clock + dt
    if clock < 0.1 then return end
    clock = 0
    local prevName = candidates[index] and candidates[index].name
    candidates = Gather()
    index = 1
    if prevName then   -- garde la selection de la molette si elle est toujours sous la souris
      for i, c in ipairs(candidates) do if c.name == prevName then index = i; break end end
    end
    if not pcall(Place) then hl:Hide() end
  end)

  overlay:SetScript("OnMouseWheel", function(_, delta)
    if #candidates == 0 then return end
    index = index - delta
    if index < 1 then index = #candidates elseif index > #candidates then index = 1 end
    if not pcall(Place) then hl:Hide() end
  end)

  overlay:SetScript("OnClick", function(_, button)
    local c = candidates[index]
    Stop()
    if button ~= "LeftButton" or not c then return end
    if OP.AddFrame(c.name) then
      OP.Print(T("MSG_ADDED", "ajoutée : ") .. "|cFFFFD700" .. c.name .. "|r")
    else
      OP.Print(T("MSG_ALREADY", "déjà dans la liste : ") .. c.name)
    end
    if OP.ShowMain then OP.ShowMain() end
  end)
end

-- Le calque masque (Echap, clic) cache aussi le surlignage : verifie au tick
-- suivant par un petit gardien, sans OnHide sur la frame de UISpecialFrames.
local guard = CreateFrame("Frame")
guard:Hide()
guard:SetScript("OnUpdate", function(self)
  if not (overlay and overlay:IsShown()) then
    if hl then hl:Hide() end
    self:Hide()
  end
end)

function OP.StartPicker()
  if InCombatLockdown() then
    OP.Print(T("MSG_PICK_COMBAT", "la pipette n'est pas disponible en combat."))
    return
  end
  if not overlay then Build() end
  candidates, index, clock = {}, 1, 1
  overlay:Show()
  guard:Show()
end

function Opacity_StartPicker() OP.StartPicker() end
