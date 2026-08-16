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
local LABEL       = "Repaire"
local DECOR_WIDTH = 272                          -- largeur du panneau une fois decore
                                                 -- (fait tenir le champ recherche + Options)

local function GetUI() return _G.TibiMidnight end

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
local panel
local function BuildOptions()
    local ui = GetUI(); if not ui then return nil end
    if panel then return panel end
    panel = ui.CreateOptionsPanel({
        name = "LairLensOptionsMidnight",
        title = "|cFF9480FFLairLens|r  Options", accent = ACCENT })

    panel:Section("Panneau")
    panel:Button("Ouvrir / fermer", function() LairLens_Toggle() end)
    panel:Button("Recentrer le panneau", function() Slash("reset") end)

    panel:Section("Historique")
    panel:Button("Tableau de bord des runs", function()
        local dash = LL.modules and LL.modules.dashboard
        if dash and dash.Toggle then dash:Toggle() else Slash("dash") end
    end)

    panel:Section("Comportement")
    panel:Check("Activer LairLens",
        function() return LL.db and LL.db.enabled end,
        function(v) if LL.db then LL.db.enabled = v; RefreshAudit() end end)
    panel:Check("Masquer hors Repaire",
        function() return LL.db and LL.db.audit and LL.db.audit.hideOutOfLair end,
        function(v) if LL.db and LL.db.audit then LL.db.audit.hideOutOfLair = v; RefreshAudit() end end)
    panel:Check("S'effacer en combat",
        function() return LL.db and LL.db.audit and LL.db.audit.fadeInCombat end,
        function(v) if LL.db and LL.db.audit then LL.db.audit.fadeInCombat = v end end)
    panel:Check("Panneau verrouille",
        function() return LL.db and LL.db.audit and LL.db.audit.locked end,
        function(v) if LL.db and LL.db.audit then LL.db.audit.locked = v end end)

    panel:Note("Astuce : clic droit sur la vignette Repaire dans la barre TibiSuite ouvre aussi ces options.")
    return panel
end

-- Fonction publique attendue par TibiSuite (clic droit sur la vignette).
function LairLens_OpenOptions()
    local p = BuildOptions()
    if p then
        p:Toggle()
    else
        -- Pas de lib TibiMidnight : on ouvre le panneau d'options natif.
        Slash("config")
    end
end

-- ---------------------------------------------------------------- Recherche
-- Provider inchange (porte depuis LairLens_Suite.lua) : lit LL.Data a la volee.
-- Un clic sur un resultat ouvre le tableau de bord, avec repli sur l'audit.
local function provider(q)
    local out, ui = {}, GetUI()
    if not ui then return out end

    local function open()
        local dash = LL.modules and LL.modules.dashboard
        if dash and dash.Open then dash:Open() else LairLens_Toggle() end
    end
    local function add(text) out[#out + 1] = { text = text, onClick = open } end

    local instances = (LL.Data and LL.Data:GetInstances("lair")) or {}
    for _, inst in pairs(instances) do
        if type(inst) == "table" then
            local iname = inst.name or "?"
            if ui.Match(iname .. " " .. tostring(inst.key or ""), q) then
                add(iname)
            end
            if type(inst.bosses) == "table" then
                for _, boss in ipairs(inst.bosses) do
                    if ui.Match((boss.name or "") .. " " .. iname, q) then
                        add((boss.name or "boss") .. "  |cff808080" .. iname .. "|r")
                    end
                end
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

-- ---------------------------------------------------------- Inscription suite
-- Le core est charge avant nous (## Dependencies: TibiSuite), donc l'API existe.
if TibiSuite and TibiSuite.RegisterModule then
    TibiSuite.RegisterModule({
        key            = KEY,
        label          = LABEL,
        accent         = ACCENT,
        onOpen         = function() if _G.LairLens_Toggle then _G.LairLens_Toggle() end end,
        onOptions      = function() if _G.LairLens_OpenOptions then _G.LairLens_OpenOptions() end end,
        searchProvider = provider,
    })
elseif GetUI() and GetUI().RegisterSearch then
    -- Repli : suite absente mais socle present -> au moins la recherche marche.
    GetUI().RegisterSearch(KEY, LABEL, provider)
end

-- La fenetre LairLensAuditFrame est construite par AuditFrame.lua. En
-- LoadOnDemand, PLAYER_LOGIN est deja passe quand ce fichier se charge : on
-- habille donc en differe, avec quelques tentatives de secours.
C_Timer.After(0.2, Decorate)
C_Timer.After(1.0, Decorate)
C_Timer.After(3.0, Decorate)