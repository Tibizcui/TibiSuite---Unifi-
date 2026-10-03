--[[============================================================================
  LairLens - Glue module pour TibiSuite  (remplace LairLens_Suite.lua)
  ---------------------------------------------------------------------------
  Ce fichier NE TOUCHE PAS a LairLensDB / LairLensCharDB ni au code de donnees.
  Charge dans le namespace LairLens (recoit ADDON, LL), il se contente de :
    - RegisterModule : ajoute l'onglet "Repaire" (accent blanc) a la barre
      unifiee et branche le provider dans la recherche globale.
    - expose LairLens_Toggle / LairLens_OpenOptions (attendus par le core).
    - habille la fenetre LairLensAuditFrame au style socle (lisere, loupe,
      options), en differe car en LoadOnDemand PLAYER_LOGIN est deja passe.
  LairLens n'a pas de bouton minimap : rien a masquer de ce cote.
  Charge en dernier par LairLens.toc, apres les modules internes.
============================================================================]]

local ADDON, LL = ...

local FRAME       = "LairLensAuditFrame"        -- frame principale (AuditFrame.lua)
local ACCENT      = { 1.000, 1.000, 1.000 }     -- blanc pretre (#FFFFFF), accent LairLens
local LOGO        = "Interface\\AddOns\\LairLens\\Media\\Logo"
local KEY         = "Lair"                       -- cle du module cote TibiSuite
local LABEL       = (LL.L and LL.L["TAB_LABEL"]) or "Repaire"
local DECOR_WIDTH = 272                          -- largeur du panneau une fois decore
                                                 -- (fait tenir le champ recherche + Options)

local function GetUI() return _G.TibiMidnight end

-- MODE DOUBLE : le core est-il present et fonctionnel ?
local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end

-- Rappel du site officiel, 10s apres le login, UNIQUEMENT en mode standalone
-- (sans core) : si TibiSuite est present, c'est LUI qui affiche ce message
-- une seule fois (voir TibiSuiteCore.lua) - sinon il apparaitrait jusqu'a
-- 12 fois, une par module.
if not HasCore() then
  C_Timer.After(45, function()
    print("|cFFC41F3BTibiSuite|r : plus d'infos sur |cFFFFD700https://www.tibiscui.fr|r")
    print("|cFFC41F3BTibiSuite|r : télécharge Tibi-Companion sur |cFFFFD700https://tibiscui.fr/tibi-companion.html|r")
  end)
end

local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then return true end
  return TibiSuiteDB.enabledModules[KEY] == true
end

-- Rafraichit le panneau d'audit apres un changement de reglage.
local function RefreshAudit()
    local audit = LL.modules and LL.modules.groupAudit
    if audit and audit.Update then pcall(function() audit:Update() end) end
end

-- Passe une commande a la barre slash interne (voie deja testee et sure).
local function Slash(arg)
    if SlashCmdList and SlashCmdList["LAIRLENS"] then
        SlashCmdList["LAIRLENS"](arg or "")
    end
end

-- ---------------------------------------------------------------- Toggle
-- Ouvre / ferme le panneau. Reutilise "/ll show" qui bascule forcedShow puis
-- met a jour, plutot que de dupliquer la logique de visibilite du module.
function LairLens_Toggle()
    Slash("show")
end

-- ---------------------------------------------------------------- Options
-- 7.1.5.37 : panneau unique (convention de la suite). L'ancien panneau natif
-- (Core/Options.lua, menu Interface de WoW) faisait doublon : ses reglages
-- (echelle, boutons flottants) sont repris ici.
local panel
local function BuildOptions()
    local ui = GetUI(); if not ui then return nil end
    if panel then return panel end
    local L = LL.L
    panel = ui.CreateOptionsPanel({
        name = "LairLensOptionsMidnight",
        title = "LairLens - " .. L["OPT_TITLE"], accent = ACCENT })

    panel:Section(L["OPT_SEC_PANEL"])
    panel:Button(L["OPT_TOGGLE"], function() LairLens_Toggle() end)
    panel:Button(L["BTN_INFO"], function() if LL.modules.lairInfo then LL.modules.lairInfo:Toggle() end end)
    panel:Button(L["DASH_TITLE"], function() if LL.modules.dashboard then LL.modules.dashboard:Toggle() end end)
    panel:Button(L["OPT_RECENTER"], function() if LL.modules.groupAudit then LL.modules.groupAudit:ResetPosition() end end)

    panel:Section(L["OPT_SEC_BEHAVIOR"])
    panel:Check(L["OPT_ENABLED"],
        function() return LL.db and LL.db.enabled end,
        function(v) if LL.db then LL.db.enabled = v; RefreshAudit() end end, L["OPT_ENABLED_TT"])
    panel:Check(L["OPT_HIDE_OUT"],
        function() return LL.db and LL.db.audit and LL.db.audit.hideOutOfLair end,
        function(v) if LL.db and LL.db.audit then LL.db.audit.hideOutOfLair = v; RefreshAudit() end end, L["OPT_HIDE_OUT_TT"])
    panel:Check(L["OPT_FADE_COMBAT"],
        function() return LL.db and LL.db.audit and LL.db.audit.fadeInCombat end,
        function(v) if LL.db and LL.db.audit then LL.db.audit.fadeInCombat = v end end, L["OPT_FADE_COMBAT_TT"])
    panel:Check(L["OPT_LOCK"],
        function() return LL.db and LL.db.audit and LL.db.audit.locked end,
        function(v) if LL.db and LL.db.audit then LL.db.audit.locked = v end end, L["OPT_LOCK_TT"])
    panel:Check(L["OPT_TRACK_RUNS"],
        function() return LL.db and LL.db.runTracking end,
        function(v) if LL.db then LL.db.runTracking = v end end, L["OPT_TRACK_RUNS_TT"])
    panel:Slider(L["OPT_SCALE"], 0.6, 1.5, 0.05,
        function() return LL.db and LL.db.audit and LL.db.audit.scale or 1.0 end,
        function(v)
            if not (LL.db and LL.db.audit) then return end
            LL.db.audit.scale = math.floor(v * 20 + 0.5) / 20
            if LL.modules.groupAudit then LL.modules.groupAudit:ApplyScale() end
        end)

    panel:Section(L["OPT_SEC_FLOAT"])
    panel:Check(L["OPT_HIDE_OPTBTN"],
        function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden(FRAME, "options") end,
        function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden(FRAME, "options", v) end end,
        L["OPT_HIDE_OPTBTN_TT"])
    panel:Check(L["OPT_HIDE_SEARCH"],
        function() return TibiSuite and TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden(FRAME, "search") end,
        function(v) if TibiSuite and TibiSuite.SetCtrlHidden then TibiSuite.SetCtrlHidden(FRAME, "search", v) end end)

    panel:Section(L["OPT_SEC_TOOLS"])
    panel:Button(L["OPT_DEMO"], function()
        local a = LL.modules.groupAudit
        if a then a:SetSim(not a:IsSim()) end
    end)
    panel:Button(L["OPT_PROBE"], function() if LL.Probe then LL.Probe:Run() end end)
    panel:Note(L["OPT_PROBE_NOTE"])
    panel:Note(L["OPT_TIP"])
    return panel
end

-- Fonction publique attendue par TibiSuite (clic droit sur la vignette).
function LairLens_OpenOptions()
    local p = BuildOptions()
    if p then p:Toggle() end
end

-- ---------------------------------------------------------------- Recherche
-- Lit LL.Data a la volee. Un clic sur un resultat ouvre la fiche du Repaire.
local function provider(q)
    local out, ui = {}, GetUI()
    if not ui then return out end

    local function open()
        local info = LL.modules and LL.modules.lairInfo
        if info and info.Open then info:Open() else LairLens_Toggle() end
    end
    local function add(text) out[#out + 1] = { text = text, onClick = open } end

    local instances = (LL.Data and LL.Data:GetInstances("lair")) or {}
    for key, inst in pairs(instances) do
        if type(inst) == "table" then
            local iname = LL.Data:GetLairName(key)
            local hay = iname .. " " .. table.concat(inst.matchNames or {}, " ") .. " " .. tostring(inst.key or "")
            if ui.Match(hay, q) then add(iname) end
            local boss = LL.Data:GetBossName(key)
            if ui.Match(boss .. " " .. (inst.bosses and inst.bosses[1] and inst.bosses[1].name or ""), q) then
                add(boss .. "  |cff808080" .. iname .. "|r")
            end
            if #out >= 60 then return out end
        end
    end
    return out
end

-- ---------------------------------------------------------- Attache & skin
local function Decorate()
    local ui = GetUI(); local f = _G[FRAME]
    if not (ui and f) then return end
    if not f._tibiSkinned then
        ui.SkinFrame(f, ACCENT)
        f._tibiSkinned = true
    end
    if not f._tibiWidened then
        if (f:GetWidth() or 0) < DECOR_WIDTH then f:SetWidth(DECOR_WIDTH) end
        f._tibiWidened = true
    end
    if f._tibiControls then return end
    ui.AddHeaderControls(f, {
        accent = ACCENT,
        onOptions = function() LairLens_OpenOptions() end,
        provider = provider,
    })
    -- NB : AddHeaderControls a deja pose f._tibiControls = table des controles
    -- (bouton Options + champ Recherche). On ne l'ecrase PAS par un booleen,
    -- sinon le core ne pourrait plus masquer ces controles a la demande.
end

-- ============================================================================
-- MODE STANDALONE : LairLens n'a pas de bouton minimap propre. On en
-- construit un ici, uniquement quand le core est absent.
-- ============================================================================
local function BuildStandaloneMinimapButton()
    if _G.LairLensMinimapBtn then return end
    local btn = CreateFrame("Button", "LairLensMinimapBtn", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT", 0, 0)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(LOGO)

    LairLensDB = LairLensDB or {}
    LairLensDB.minimapAngle = LairLensDB.minimapAngle or 200
    local function UpdatePosition()
        local angle = math.rad(LairLensDB.minimapAngle)
        local radius = 105
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    end

    btn:SetScript("OnDragStart", function(self) self.dragging = true end)
    btn:SetScript("OnDragStop", function(self) self.dragging = false end)
    btn:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        LairLensDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
        UpdatePosition()
    end)

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then LairLens_OpenOptions() else LairLens_Toggle() end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("LairLens")
        GameTooltip:AddLine(LL.L["MM_LEFT"], 0.9, 0.9, 0.95)
        GameTooltip:AddLine(LL.L["MM_RIGHT"], 0.9, 0.9, 0.95)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdatePosition()
end

-- ---------------------------------------------------------- Inscription suite
-- MODE MODULE : inscription au catalogue, sauf si explicitement desactive.
-- MODE STANDALONE : construit son propre bouton minimap ; "/lairlens" (ou
-- "/ll") reste la commande slash, deja inconditionnelle cote AuditFrame.lua.
if HasCore() and IsEnabledByCore() then
    TibiSuite.RegisterModule({
        key            = KEY,
        label          = LABEL,
        accent         = ACCENT,
        onOpen         = function() if _G.LairLens_Toggle then _G.LairLens_Toggle() end end,
        onOptions      = function() if _G.LairLens_OpenOptions then _G.LairLens_OpenOptions() end end,
        searchProvider = provider,
    })
elseif not HasCore() then
    BuildStandaloneMinimapButton()
end

-- La fenetre LairLensAuditFrame est construite par AuditFrame.lua. En
-- LoadOnDemand, PLAYER_LOGIN est deja passe quand ce fichier se charge : on
-- habille donc en differe, avec quelques tentatives de secours.
C_Timer.After(0.2, Decorate)
C_Timer.After(1.0, Decorate)
C_Timer.After(3.0, Decorate)