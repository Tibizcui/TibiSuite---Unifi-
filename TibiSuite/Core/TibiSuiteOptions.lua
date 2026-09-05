-- ================================================================
-- TibiSuiteOptions v7.0
-- Auteur : Tibiscui - Kirin Tor
-- Role   : Panneau « Modules » de la suite. Une case a cocher par
--          module connu (meme non charge). Cocher = charge le module
--          immediatement (LoadOnDemand a chaud). Decocher = le module
--          ne sera plus charge au prochain /reload.
--          Construit sur le socle commun (TibiMidnight.CreateOptionsPanel).
-- Ce fichier ne declare aucune SavedVariables : l'etat vit dans
-- TibiSuiteDB.enabledModules, gere par le core (TibiSuite.SetModuleEnabled).
-- ================================================================

local ACCENT_SUITE = { 0.769, 0.122, 0.231 }   -- rouge TibiSuite (#C41F3B) : accent des panneaux (liseré + en-tetes) et de l'installateur
local LOGO         = "Interface\\AddOns\\TibiSuite\\medias\\TibiSuite"

-- ================================================================
-- LOCALISATION
-- Le francais reste le defaut embarque directement ici (via l'operateur
-- "or") : Locale\enUS.lua ecrase ensuite ces cles si le client est en
-- anglais. Meme table partagee que TibiSuiteCore.lua (TibiSuiteL).
-- ================================================================
TibiSuiteL = TibiSuiteL or {}
local L = TibiSuiteL

-- Presentation de la suite (installateur + panneau des modules).
L.INTRO = L.INTRO or "TibiSuite reunit tous tes trackers Tibiscui sous un seul bouton de minicarte et une barre d'onglets. Tu actives seulement les modules voulus : les autres ne sont pas charges et ne consomment aucune memoire."

-- Resume court par module (repris des descriptions officielles de chaque toc).
L.DESC_Daily   = L.DESC_Daily   or "Quetes quotidiennes et hebdomadaires (Midnight, TWW), cochees automatiquement selon ton historique."
L.DESC_Dgn     = L.DESC_Dgn     or "Compteur d'entrees d'instances : donjons, raids, gouffres, Torghast, toutes extensions."
L.DESC_Leg     = L.DESC_Leg     or "Suivi des objets legendaires par extension : statut, quetes et composants, sur tout le compte."
L.DESC_Rep     = L.DESC_Rep     or "Reputations et Renom de Vanilla a Midnight : groupes pliables, quetes, suivi auto par zone."
L.DESC_Lvl     = L.DESC_Lvl     or "Historique des sessions de leveling et de farm, avec statistiques."
L.DESC_Weekly  = L.DESC_Weekly  or "Tableau de bord hebdomadaire : ce qu'il reste a faire pour maximiser tes recompenses."
L.DESC_MiniHub = L.DESC_MiniHub or "Regroupe les boutons de la minicarte dans un conteneur unique et retractable."
L.DESC_XPBar   = L.DESC_XPBar   or "Barre d'XP avancee : niveau, XP, repos, quetes et statistiques de session."
L.DESC_Lair    = L.DESC_Lair    or "Audit de groupe et pertinence des recompenses pour les Repaires."
L.DESC_Skill   = L.DESC_Skill   or "Progression des metiers par extension (actuel / max + %), pour tous tes personnages."
L.DESC_RepBar  = L.DESC_RepBar  or "Barre de reputation : remplace la barre native, suit la faction par zone et par quete."
L.DESC_Post    = L.DESC_Post    or "Gestion avancee de la boite aux lettres : ouverture en masse, carnet de contacts, statistiques de courrier."

local DESC = {
  Daily   = L.DESC_Daily,   Dgn  = L.DESC_Dgn,   Leg  = L.DESC_Leg,   Rep = L.DESC_Rep,
  Lvl     = L.DESC_Lvl,     Weekly = L.DESC_Weekly, MiniHub = L.DESC_MiniHub,
  XPBar   = L.DESC_XPBar,   Lair = L.DESC_Lair,  Skill = L.DESC_Skill,
  RepBar  = L.DESC_RepBar,  Post = L.DESC_Post,
}

L.URL_HINT = L.URL_HINT or "Ctrl+C pour copier"

-- Panneau "Modules"
L.PANEL_TITLE      = L.PANEL_TITLE      or "|cFFC41F3BTibiSuite|r  Modules"
L.SEC_MODULES       = L.SEC_MODULES       or "Modules : Chargés / Non chargés"
L.NOTE_MODULES      = L.NOTE_MODULES      or "Cochez les modules que vous voulez. Cocher un module le charge tout de suite. Decocher prend effet au prochain /reload (un module ne peut pas etre decharge a chaud)."
L.LBL_ABSENT         = L.LBL_ABSENT         or "  |cFF808080(absent)|r"
L.TOAST_ENABLED_FMT  = L.TOAST_ENABLED_FMT  or "activé"
L.TOAST_DISABLED_FMT = L.TOAST_DISABLED_FMT or "désactivé - effectif au prochain |cFFFFD700/reload|r"
L.CHECK_TOOLTIP_ON   = L.CHECK_TOOLTIP_ON   or "Charger / decharger "
L.CHECK_TOOLTIP_OFF  = L.CHECK_TOOLTIP_OFF  or " n'est pas installe (dossier absent)."
L.SEC_TIP            = L.SEC_TIP            or "Astuce"
L.NOTE_TIP           = L.NOTE_TIP           or "Un module decoche ne consomme aucune memoire : ses fichiers de donnees ne sont meme pas lus. Seul le core reste toujours charge."
L.SEC_REINSTALL_MOD  = L.SEC_REINSTALL_MOD  or "Reinstaller un module"
L.NOTE_REINSTALL_MOD = L.NOTE_REINSTALL_MOD or "Remet un module a zero : efface ses reglages et sa progression, puis recharge l'interface. Action irreversible. La barre TibiSuite et les autres modules ne sont pas touches."
L.BTN_REINSTALL       = L.BTN_REINSTALL       or "|cFFFF6666Reinstaller|r  "
L.CONFIRM_REINSTALL_MOD_FMT1 = L.CONFIRM_REINSTALL_MOD_FMT1 or "Reinstaller "
L.CONFIRM_REINSTALL_MOD_FMT2 = L.CONFIRM_REINSTALL_MOD_FMT2 or " ?\n\nCela efface definitivement ses reglages et sa progression, puis recharge l'interface."
L.SEC_REINSTALL_SUITE  = L.SEC_REINSTALL_SUITE  or "Reinstaller TibiSuite"
L.NOTE_REINSTALL_SUITE = L.NOTE_REINSTALL_SUITE or "Remet a zero les reglages de la suite (barre, modules actives, installation) et recharge l'interface. La progression de chaque module est conservee."
L.BTN_REINSTALL_SUITE  = L.BTN_REINSTALL_SUITE  or "|cFFC41F3BReinstaller TibiSuite|r  |cFF808080(la suite)|r"
L.CONFIRM_REINSTALL_CORE = L.CONFIRM_REINSTALL_CORE or
  "Reinstaller TibiSuite ?\n\nCela remet a zero les reglages de la suite (barre, modules actives, installation) puis recharge l'interface. La progression de chaque module est conservee."
L.SEC_DASHBOARD        = L.SEC_DASHBOARD        or "Dashboard web"
L.NOTE_DASHBOARD       = L.NOTE_DASHBOARD       or "Colle tes statistiques sur le site pour les consulter hors du jeu. Rien n'est envoye a un serveur : le code est lu localement par ton navigateur."
L.DASHBOARD_URL_LABEL  = L.DASHBOARD_URL_LABEL  or "URL du dashboard (Ctrl+C pour copier) :"
L.BTN_GENERATE_EXPORT  = L.BTN_GENERATE_EXPORT  or "Generer mon code d'export"
L.TOAST_NEED_STATS     = L.TOAST_NEED_STATS     or "Active le module |cFFFFD700Stats|r pour generer un export."
L.NOTE_DASHBOARD_PRIVACY = L.NOTE_DASHBOARD_PRIVACY or "Confidentialite : aucune donnee n'est envoyee a un serveur. Le code d'export est genere et lu entierement en local (jeu et navigateur)."

-- Assistant de premiere installation
L.WIZ_SUBTITLE = L.WIZ_SUBTITLE or "Assistant de premiere installation"
L.WIZ_STEP1 = L.WIZ_STEP1 or "Bienvenue"
L.WIZ_STEP2 = L.WIZ_STEP2 or "Modules"
L.WIZ_STEP3 = L.WIZ_STEP3 or "Terminer"
L.WIZ_PILL1 = L.WIZ_PILL1 or "modules detectes"
L.WIZ_PILL2 = L.WIZ_PILL2 or "Un seul bouton de minicarte"
L.WIZ_PILL3 = L.WIZ_PILL3 or "perte de progression"
L.WIZ_PILL4 = L.WIZ_PILL4 or "Reglable a tout moment"
L.WIZ_EXPRESS_TITLE = L.WIZ_EXPRESS_TITLE or "Installation express  -  recommande"
L.WIZ_EXPRESS_DESC  = L.WIZ_EXPRESS_DESC  or "Active tous les modules et demarre tout de suite. Ajuste plus tard avec /ts modules."
L.WIZ_CHOOSE_TITLE   = L.WIZ_CHOOSE_TITLE   or "Je choisis mes modules"
L.WIZ_CHOOSE_DESC    = L.WIZ_CHOOSE_DESC    or "Selectionne un par un ce que tu veux charger, par categorie."
L.WIZ_ALL_ON   = L.WIZ_ALL_ON   or "Tout activer"
L.WIZ_ALL_OFF  = L.WIZ_ALL_OFF  or "Tout desactiver"
L.WIZ_CAT_ALL  = L.WIZ_CAT_ALL  or "|cFFB8ADFFTout|r"
L.WIZ_CAT_NONE = L.WIZ_CAT_NONE or "|cFF9A96A8Aucun|r"
L.WIZ_CAT_TRACKERS = L.WIZ_CAT_TRACKERS or "Trackers (fenetres)"
L.WIZ_CAT_HUD      = L.WIZ_CAT_HUD      or "HUD ambiant (barres et conteneurs)"
L.WIZ_DETECTED_FMT = L.WIZ_DETECTED_FMT or "modules detectes"
L.WIZ_COUNTER_FMT   = L.WIZ_COUNTER_FMT   or "modules actives"
L.WIZ_RECAP_COUNT_FMT = L.WIZ_RECAP_COUNT_FMT or "modules seront actives au demarrage."
L.WIZ_RECAP_TITLE = L.WIZ_RECAP_TITLE or "Pret a installer"
L.WIZ_REASSURANCE = L.WIZ_REASSURANCE or
  "|cFFB8ADFF+|r Aucune progression deplacee : chaque module garde sa sauvegarde.\n"
  .. "|cFFB8ADFF+|r Cocher charge tout de suite ; decocher prend effet au /reload.\n"
  .. "|cFFB8ADFF+|r Reglable a tout moment avec |cFFFFD700/ts modules|r."
L.WIZ_SITE   = L.WIZ_SITE   or "Site web"
L.WIZ_CURSE  = L.WIZ_CURSE  or "CurseForge"
L.WIZ_PREV   = L.WIZ_PREV   or "Precedent"
L.WIZ_START     = L.WIZ_START     or "Commencer"
L.WIZ_CONTINUE  = L.WIZ_CONTINUE  or "Continuer"
L.WIZ_INSTALL   = L.WIZ_INSTALL   or "Installer et demarrer"
L.WIZ_FINISH_PRINT = L.WIZ_FINISH_PRINT or "installation terminee. |cFFFFD700/ts modules|r pour ajuster plus tard."
L.WIZ_FINISH_TOAST  = L.WIZ_FINISH_TOAST  or "|cFFC41F3BTibiSuite|r installe avec succes !"

-- Categorie pour l'installateur : "hud" = barre / conteneur ambiant, sinon
-- "tracker" (fenetre). Absent de la table => tracker.
local GROUP = { XPBar = "hud", RepBar = "hud", MiniHub = "hud" }

-- Liens officiels (ouverts via une fenetre "copier le lien").
local URL_SITE  = "https://www.tibiscui.fr"
local URL_CURSE = "https://www.curseforge.com/members/tibiscui/projects"

local panel   -- construit une seule fois (paresseux)

-- ================================================================
-- FENETRES MAISON (confirmation + copie de lien)
-- ----------------------------------------------------------------
-- PIEGE REEL, CONFIRME EN JEU (ADDON_ACTION_FORBIDDEN "SpellStopCasting" sur
-- ToggleGameMenu/Echap, meme sans jamais afficher le moindre popup) : ecrire
-- des entrees dans StaticPopupDialogs - une table PARTAGEE avec Blizzard -
-- suffit a contaminer l'execution que Blizzard utilise ensuite pour gerer
-- Echap. Isole par bisection complete du code (tout desactive sauf ces 3
-- entrees -> erreur ; ces 3 entrees seules desactivees -> plus d'erreur).
-- SOLUTION : ne plus jamais ecrire dans StaticPopupDialogs. Fenetres 100%
-- maison ci-dessous (meme principe que BuildPlaceholder/TibiSuiteCore.lua),
-- fermables par UISpecialFrames (Echap natif, aucun risque).
-- ================================================================

-- Bouton plat local, meme rendu que UI.MakeButton mais sans en dependre
-- directement (au cas ou TibiMidnight ne serait pas encore charge).
local function MakeThemedButton(parent, w, h, text)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h)
  b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  b:SetBackdropColor(1, 1, 1, 0.05)
  b:SetBackdropBorderColor(1, 1, 1, 0.12)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetAllPoints()
  fs:SetText(text or "")
  b:SetScript("OnEnter", function(s) s:SetBackdropColor(1, 1, 1, 0.10); s:SetBackdropBorderColor(1, 1, 1, 0.25) end)
  b:SetScript("OnLeave", function(s) s:SetBackdropColor(1, 1, 1, 0.05); s:SetBackdropBorderColor(1, 1, 1, 0.12) end)
  return b
end

-- Meme theme graphique que le reste de la suite (fond plat sombre, bordure
-- fine, liseré d'accent) via UI.SkinFrame ; repli local si TibiMidnight
-- n'est pas encore charge (ne devrait pas arriver, mais pas de crash).
local function SkinLikeSuite(f, accent)
  local UI = _G.TibiMidnight
  if UI and UI.SkinFrame then
    UI.SkinFrame(f, accent, UI.C.PANEL)
  else
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.055, 0.063, 0.082, 0.98)
    f:SetBackdropBorderColor(0, 0, 0, 1)
  end
end

local confirmFrame
local function ShowConfirm(text, onAccept)
  if not confirmFrame then
    confirmFrame = CreateFrame("Frame", "TibiSuiteConfirmFrame", UIParent, "BackdropTemplate")
    confirmFrame:SetSize(380, 150)
    confirmFrame:SetPoint("CENTER")
    -- FULLSCREEN_DIALOG (au-dessus de DIALOG) : garantit que la confirmation
    -- s'affiche devant le panneau d'options / le panneau des modules qui
    -- l'a ouverte (tous deux en DIALOG), au lieu de se lancer derriere.
    confirmFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    SkinLikeSuite(confirmFrame, ACCENT_SUITE)
    confirmFrame:EnableMouse(true)
    confirmFrame:SetMovable(true)
    confirmFrame:RegisterForDrag("LeftButton")
    confirmFrame:SetScript("OnDragStart", confirmFrame.StartMoving)
    confirmFrame:SetScript("OnDragStop",  confirmFrame.StopMovingOrSizing)
    confirmFrame:Hide()
    tinsert(UISpecialFrames, "TibiSuiteConfirmFrame")

    local closeB = CreateFrame("Button", nil, confirmFrame, "UIPanelCloseButton")
    closeB:SetPoint("TOPRIGHT", confirmFrame, "TOPRIGHT", 2, 2)
    closeB:SetScript("OnClick", function() confirmFrame:Hide() end)

    local msg = confirmFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msg:SetPoint("TOP", 0, -30)
    msg:SetWidth(320)
    msg:SetJustifyH("CENTER")
    confirmFrame._msg = msg

    local yesBtn = MakeThemedButton(confirmFrame, 90, 24, "|cFF66FF66" .. (YES or "Oui") .. "|r")
    yesBtn:SetPoint("BOTTOMRIGHT", confirmFrame, "BOTTOM", -10, 16)
    yesBtn:SetScript("OnClick", function()
      confirmFrame:Hide()
      if confirmFrame._onAccept then confirmFrame._onAccept() end
    end)

    local noBtn = MakeThemedButton(confirmFrame, 90, 24, "|cFFFF7777" .. (NO or "Non") .. "|r")
    noBtn:SetPoint("BOTTOMLEFT", confirmFrame, "BOTTOM", 10, 16)
    noBtn:SetScript("OnClick", function() confirmFrame:Hide() end)
  end

  confirmFrame._msg:SetText(text)
  confirmFrame._onAccept = onAccept
  confirmFrame:Show()
end
TibiSuite.ShowConfirm = ShowConfirm

local urlFrame
local function ShowURL(url)
  if not urlFrame then
    urlFrame = CreateFrame("Frame", "TibiSuiteURLFrame", UIParent, "BackdropTemplate")
    urlFrame:SetSize(420, 100)
    urlFrame:SetPoint("CENTER")
    urlFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    SkinLikeSuite(urlFrame, ACCENT_SUITE)
    urlFrame:EnableMouse(true)
    urlFrame:SetMovable(true)
    urlFrame:RegisterForDrag("LeftButton")
    urlFrame:SetScript("OnDragStart", urlFrame.StartMoving)
    urlFrame:SetScript("OnDragStop",  urlFrame.StopMovingOrSizing)
    urlFrame:Hide()
    tinsert(UISpecialFrames, "TibiSuiteURLFrame")

    local hint = urlFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOP", 0, -22)
    hint:SetText(L.URL_HINT)

    local eb = CreateFrame("EditBox", "TibiSuiteURLBox", urlFrame, "InputBoxTemplate")
    eb:SetSize(370, 30)
    eb:SetPoint("TOP", hint, "BOTTOM", 0, -10)
    eb:SetAutoFocus(true)
    eb:SetScript("OnEscapePressed", function(s) s:GetParent():Hide() end)
    eb:SetScript("OnEnterPressed",  function(s) s:GetParent():Hide() end)
    urlFrame._box = eb

    local closeBtn = CreateFrame("Button", nil, urlFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", urlFrame, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() urlFrame:Hide() end)
  end

  urlFrame._box:SetText(url or "")
  urlFrame._box:HighlightText()
  urlFrame:Show()
  urlFrame._box:SetFocus()
end

-- ================================================================
-- TOAST (confirmation courte, auto-disparait) - inspire du "toast" d'ElvUI
-- apres une action appliquee (installation terminee, module bascule...).
-- Pure UI, aucun element partage avec Blizzard.
-- ================================================================
local toastFrame
function TibiSuite.ShowToast(text)
  if not toastFrame then
    toastFrame = CreateFrame("Frame", "TibiSuiteToastFrame", UIParent, "BackdropTemplate")
    toastFrame:SetSize(360, 40)
    toastFrame:SetPoint("TOP", UIParent, "TOP", 0, -140)
    toastFrame:SetFrameStrata("TOOLTIP")
    toastFrame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
    })
    toastFrame:SetBackdropColor(0.06, 0.07, 0.09, 0.95)
    toastFrame:SetBackdropBorderColor(0.769, 0.122, 0.231, 1)
    toastFrame:Hide()

    local msg = toastFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    msg:SetPoint("CENTER")
    msg:SetWidth(340)
    msg:SetJustifyH("CENTER")
    toastFrame._msg = msg

    local ag = toastFrame:CreateAnimationGroup()
    local fadeIn = ag:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0); fadeIn:SetToAlpha(1); fadeIn:SetDuration(0.2); fadeIn:SetOrder(1)
    local hold = ag:CreateAnimation("Alpha")
    hold:SetFromAlpha(1); hold:SetToAlpha(1); hold:SetDuration(2.0); hold:SetOrder(2)
    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0); fadeOut:SetDuration(0.6); fadeOut:SetOrder(3)
    ag:SetScript("OnFinished", function() toastFrame:Hide() end)
    toastFrame._anim = ag
  end

  toastFrame._msg:SetText(text or "")
  toastFrame:SetAlpha(0)
  toastFrame:Show()
  toastFrame._anim:Stop()
  toastFrame._anim:Play()
end

-- Convertit r,g,b [0-1] en code couleur WoW pour teinter le libelle.
local function Hex(c)
  return string.format("|cFF%02X%02X%02X",
    math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
end

local function Build()
  local UI = _G.TibiMidnight
  if not UI or not UI.CreateOptionsPanel then return nil end
  if panel then return panel end

  panel = UI.CreateOptionsPanel({
    name  = "TibiSuiteModulesPanel",
    title = L.PANEL_TITLE,
    accent = ACCENT_SUITE,
    logo  = LOGO,
  })

  panel:Section(L.SEC_MODULES)
  panel:Note(L.NOTE_MODULES)

  local catalog = (TibiSuite.GetCatalog and TibiSuite.GetCatalog()) or {}
  for _, mod in ipairs(catalog) do
    local key     = mod.key
    local present = TibiSuite.ModuleExists and TibiSuite.ModuleExists(mod.addonName)
    local label   = Hex(mod.col) .. (mod.addonName or mod.label) .. "|r"
    if not present then
      label = label .. L.LBL_ABSENT
    end
    panel:Check(
      label,
      function() return TibiSuite.IsModuleEnabled and TibiSuite.IsModuleEnabled(key) end,
      function(v)
        if TibiSuite.SetModuleEnabled then TibiSuite.SetModuleEnabled(key, v) end
        -- Charger prend effet tout de suite ; decharger necessite un /reload
        -- (WoW ne permet pas de decharger un addon a chaud) - le toast reflete
        -- lequel des deux vient de se produire.
        if v then
          TibiSuite.ShowToast(Hex(mod.col) .. mod.addonName .. "|r " .. L.TOAST_ENABLED_FMT)
        else
          TibiSuite.ShowToast(Hex(mod.col) .. mod.addonName .. "|r " .. L.TOAST_DISABLED_FMT)
        end
      end,
      present and (L.CHECK_TOOLTIP_ON .. mod.addonName)
              or (mod.addonName .. L.CHECK_TOOLTIP_OFF)
    )
  end

  panel:Section(L.SEC_TIP)
  panel:Note(L.NOTE_TIP)

  -- ── Reinstallation : un bouton par module present ──────────────
  panel:Section(L.SEC_REINSTALL_MOD)
  panel:Note(L.NOTE_REINSTALL_MOD)
  for _, mod in ipairs(catalog) do
    local present = TibiSuite.ModuleExists and TibiSuite.ModuleExists(mod.addonName)
    if present then
      local addon = mod.addonName
      local key   = mod.key
      panel:Button(
        L.BTN_REINSTALL .. Hex(mod.col) .. addon .. "|r",
        function()
          ShowConfirm(
            L.CONFIRM_REINSTALL_MOD_FMT1 .. addon .. L.CONFIRM_REINSTALL_MOD_FMT2,
            function() if TibiSuite.ReinstallModule then TibiSuite.ReinstallModule(key) end end
          )
        end
      )
    end
  end

  -- Reinstallation de la suite elle-meme (reglages du core), progression conservee.
  panel:Section(L.SEC_REINSTALL_SUITE)
  panel:Note(L.NOTE_REINSTALL_SUITE)
  panel:Button(
    L.BTN_REINSTALL_SUITE,
    function()
      ShowConfirm(L.CONFIRM_REINSTALL_CORE,
        function() if TibiSuite.ReinstallCore then TibiSuite.ReinstallCore() end end
      )
    end
  )

  -- ── Dashboard web (module Stats) ─────────────────────────────────
  panel:Section(L.SEC_DASHBOARD)
  panel:Note(L.NOTE_DASHBOARD)
  if panel.SelectableText then
    panel:SelectableText(L.DASHBOARD_URL_LABEL, "https://www.tibiscui.fr/Dashboard.html")
  else
    panel:Note("https://www.tibiscui.fr/Dashboard.html")
  end
  panel:Button(L.BTN_GENERATE_EXPORT, function()
    if _G.Stats and _G.Stats.ShowExportPopup then
      _G.Stats.ShowExportPopup()
    else
      TibiSuite.ShowToast(L.TOAST_NEED_STATS)
    end
  end)
  panel:Note(L.NOTE_DASHBOARD_PRIVACY)

  return panel
end

-- API publique : ouvrir / fermer le panneau des modules.
function TibiSuite.OpenModulePanel()
  local p = Build()
  if p then p:Toggle() end
end

-- ================================================================
-- INSTALLATEUR PREMIER LANCEMENT
-- ----------------------------------------------------------------
-- Au tout premier login (TibiSuiteDB.setupDone absent), on presente les
-- modules DETECTES sur le disque par lots de 3 cartes, chacune avec sa case
-- "Activer". Terminer applique les choix (cocher = charge le module) et pose
-- le drapeau setupDone. Fermer la fenetre = terminer avec la selection en
-- cours (jamais d'etat bloque). Tout est deja coche par defaut : valider sans
-- rien changer active tous les modules presents, comportement non destructif.
-- ================================================================
local wizard

local function BuildWizard()
  local UI = _G.TibiMidnight
  if not UI then return nil end
  if wizard then return wizard end

  local LAV = ACCENT_SUITE
  local function hexLav(t) return UI.Hex(LAV[1], LAV[2], LAV[3]) .. t .. "|r" end
  local BORD = UI.C.BORDER or { 0, 0, 0 }

  -- ----- Fenetre -----
  local f = CreateFrame("Frame", "TibiSuiteSetupWizard", UIParent, "BackdropTemplate")
  f:SetSize(660, 600)
  f:SetPoint("CENTER", 0, 30)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  UI.SkinFrame(f, LAV, UI.C.PANEL)   -- fond plat sombre + liseré lavande (SetLisere)

  -- ----- En-tete : logo + titre -----
  local logo = f:CreateTexture(nil, "OVERLAY")
  logo:SetSize(40, 40); logo:SetPoint("TOPLEFT", 18, -16); logo:SetTexture(LOGO)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -2)
  title:SetText(hexLav("TibiSuite"))
  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -4)
  sub:SetText(L.WIZ_SUBTITLE)

  local closeB = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  closeB:SetPoint("TOPRIGHT", 2, 2)

  -- ----- Etapes -----
  local STEP_NAMES = { L.WIZ_STEP1, L.WIZ_STEP2, L.WIZ_STEP3 }
  local steps = {}
  local segW = (660 - 40 - 16) / 3
  for i = 1, 3 do
    local seg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    seg:SetSize(segW, 30)
    seg:SetPoint("TOPLEFT", 20 + (i - 1) * (segW + 8), -66)
    seg:SetBackdrop(UI.FlatBackdrop())
    local num = seg:CreateTexture(nil, "ARTWORK")
    num:SetSize(18, 18); num:SetPoint("LEFT", 8, 0)
    local numT = seg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    numT:SetPoint("CENTER", num, "CENTER")
    local lbl = seg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("LEFT", num, "RIGHT", 8, 0)
    seg:EnableMouse(true)
    seg:SetScript("OnMouseUp", function() if wizard.goStep then wizard.goStep(i - 1) end end)
    steps[i] = { frame = seg, num = num, numT = numT, lbl = lbl }
  end

  -- Barre de progression : degrade rouge -> jaune -> vert selon l'etape
  -- (inspire d'ElvUI Install.lua). Remplissage direct, sans animation image
  -- par image : suffisant pour un assistant a 3 etapes.
  local progressBG = CreateFrame("Frame", nil, f, "BackdropTemplate")
  progressBG:SetSize(660 - 40, 4)
  progressBG:SetPoint("TOPLEFT", 20, -100)
  progressBG:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  progressBG:SetBackdropColor(0.16, 0.15, 0.20, 1)
  local progressBar = CreateFrame("StatusBar", nil, progressBG)
  progressBar:SetAllPoints()
  progressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  progressBar:SetMinMaxValues(0, 2)
  progressBar:SetValue(0)

  local function GradientColor(t)
    t = math.max(0, math.min(1, t))
    if t < 0.5 then return 1, t / 0.5, 0 end
    return 1 - (t - 0.5) / 0.5, 1, 0
  end
  local function UpdateProgressBar(step)
    progressBar:SetValue(step)
    local r, g, b = GradientColor(step / 2)
    progressBar:SetStatusBarColor(r, g, b, 1)
  end

  local sep = f:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(1, 1, 1, 0.10)
  sep:SetPoint("TOPLEFT", 16, -108); sep:SetPoint("TOPRIGHT", -16, -108); sep:SetHeight(1)

  -- ================= PANE : BIENVENUE =================
  local pW = CreateFrame("Frame", nil, f)
  pW:SetPoint("TOPLEFT", 20, -116); pW:SetPoint("BOTTOMRIGHT", -20, 60)
  local intro = pW:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  intro:SetPoint("TOPLEFT", 2, -4); intro:SetPoint("RIGHT", -2, 0)
  intro:SetJustifyH("LEFT"); intro:SetText(L.INTRO)

  local PILLS = { "|cFFE9E7F011|r " .. L.WIZ_PILL1, L.WIZ_PILL2,
                  "|cFFE9E7F00|r " .. L.WIZ_PILL3, L.WIZ_PILL4 }
  local detectFS
  do
    local px, pillY = 2, -64
    for i2, txt in ipairs(PILLS) do
      local pill = CreateFrame("Frame", nil, pW, "BackdropTemplate")
      pill:SetBackdrop(UI.FlatBackdrop()); pill:SetBackdropColor(0.10, 0.095, 0.125, 0.9)
      local t = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      t:SetPoint("CENTER"); t:SetText(txt)
      local w = (t:GetStringWidth() or 60) + 20
      pill:SetSize(w, 22); pill:SetPoint("TOPLEFT", px, pillY)
      px = px + w + 8
      if px > 560 then px = 2; pillY = pillY - 28 end
      if i2 == 1 then detectFS = t end
    end
  end

  local function choiceCard(x, primary, titleTxt, descTxt, onClick)
    local c = CreateFrame("Button", nil, pW, "BackdropTemplate")
    c:SetSize(288, 96); c:SetPoint("TOPLEFT", x, -112)
    c:SetBackdrop(UI.FlatBackdrop()); c:SetBackdropColor(0.10, 0.095, 0.125, 0.95)
    local ti = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ti:SetPoint("TOPLEFT", 12, -12); ti:SetText(primary and hexLav(titleTxt) or titleTxt)
    local de = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    de:SetPoint("TOPLEFT", 12, -34); de:SetPoint("RIGHT", -12, 0); de:SetJustifyH("LEFT"); de:SetText(descTxt)
    c:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(LAV[1], LAV[2], LAV[3], 0.7) end)
    c:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(BORD[1], BORD[2], BORD[3], 1) end)
    c:SetScript("OnClick", onClick)
    return c
  end
  choiceCard(2, true, L.WIZ_EXPRESS_TITLE,
    L.WIZ_EXPRESS_DESC,
    function()
      for _, m in ipairs(wizard.present) do wizard.choice[m.key] = true end
      if wizard.refreshCards then wizard.refreshCards() end
      wizard.goStep(2)
    end)
  choiceCard(300, false, L.WIZ_CHOOSE_TITLE,
    L.WIZ_CHOOSE_DESC,
    function() wizard.goStep(1) end)

  -- ================= PANE : MODULES =================
  local pM = CreateFrame("Frame", nil, f)
  pM:SetPoint("TOPLEFT", 20, -116); pM:SetPoint("BOTTOMRIGHT", -20, 60)
  pM:Hide()
  local allOn = UI.MakeButton(pM, 96, 22, L.WIZ_ALL_ON)
  allOn:SetPoint("TOPLEFT", 2, -2)
  local allOff = UI.MakeButton(pM, 108, 22, L.WIZ_ALL_OFF)
  allOff:SetPoint("LEFT", allOn, "RIGHT", 8, 0)
  local counter = pM:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  counter:SetPoint("RIGHT", -4, 0); counter:SetPoint("TOP", allOn, "TOP", 0, -4)
  local scroll = CreateFrame("ScrollFrame", nil, pM, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -32); scroll:SetPoint("BOTTOMRIGHT", -24, 2)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(590, 10); scroll:SetScrollChild(content)
  allOn:SetScript("OnClick", function()
    for _, m in ipairs(wizard.present) do wizard.choice[m.key] = true end
    wizard.refreshCards()
  end)
  allOff:SetScript("OnClick", function()
    for _, m in ipairs(wizard.present) do wizard.choice[m.key] = nil end
    wizard.refreshCards()
  end)

  -- interrupteur on/off (deux textures : rail + pastille)
  local function makeSwitch(parent, col)
    local sw = CreateFrame("Button", nil, parent)
    sw:SetSize(36, 18)
    local track = sw:CreateTexture(nil, "BACKGROUND"); track:SetAllPoints()
    local knob = sw:CreateTexture(nil, "OVERLAY"); knob:SetSize(14, 14)
    sw._set = function(on)
      knob:ClearAllPoints()
      if on then
        track:SetColorTexture(col.r * 0.55, col.g * 0.55, col.b * 0.55, 1)
        knob:SetPoint("RIGHT", -2, 0); knob:SetColorTexture(1, 1, 1, 1)
      else
        track:SetColorTexture(0.16, 0.15, 0.20, 1)
        knob:SetPoint("LEFT", 2, 0); knob:SetColorTexture(0.42, 0.40, 0.46, 1)
      end
    end
    return sw
  end

  -- ================= PANE : RECAP =================
  local pR = CreateFrame("Frame", nil, f)
  pR:SetPoint("TOPLEFT", 20, -116); pR:SetPoint("BOTTOMRIGHT", -20, 60)
  pR:Hide()
  local rTitle = pR:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  rTitle:SetPoint("TOPLEFT", 2, -4); rTitle:SetText(hexLav(L.WIZ_RECAP_TITLE))
  local rSub = pR:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  rSub:SetPoint("TOPLEFT", 2, -30)
  local chipsHost = CreateFrame("Frame", nil, pR)
  chipsHost:SetPoint("TOPLEFT", 2, -54); chipsHost:SetPoint("RIGHT", -2, 0); chipsHost:SetHeight(150)
  local reass = pR:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  reass:SetPoint("BOTTOMLEFT", 2, 6); reass:SetPoint("RIGHT", -2, 0); reass:SetJustifyH("LEFT")
  reass:SetText(L.WIZ_REASSURANCE)

  -- ----- Pied : liens + navigation -----
  local sep2 = f:CreateTexture(nil, "ARTWORK")
  sep2:SetColorTexture(1, 1, 1, 0.10)
  sep2:SetPoint("BOTTOMLEFT", 16, 50); sep2:SetPoint("BOTTOMRIGHT", -16, 50); sep2:SetHeight(1)
  local siteB = UI.MakeButton(f, 92, 24, L.WIZ_SITE)
  siteB:SetPoint("BOTTOMLEFT", 16, 14)
  siteB:SetScript("OnClick", function() ShowURL(URL_SITE) end)
  local curseB = UI.MakeButton(f, 110, 24, L.WIZ_CURSE)
  curseB:SetPoint("LEFT", siteB, "RIGHT", 8, 0)
  curseB:SetScript("OnClick", function() ShowURL(URL_CURSE) end)
  local prevB = UI.MakeButton(f, 96, 24, L.WIZ_PREV)
  prevB:SetPoint("BOTTOMRIGHT", -148, 14)
  local nextB = UI.MakeButton(f, 132, 24, "")
  nextB:SetPoint("BOTTOMRIGHT", -16, 14)
  nextB:SetBackdropColor(0.34, 0.28, 0.66, 0.95)
  nextB:SetBackdropBorderColor(LAV[1], LAV[2], LAV[3], 1)

  wizard = { frame = f, present = {}, choice = {}, step = 0, steps = steps,
             counter = counter, rSub = rSub, chipsHost = chipsHost,
             prevB = prevB, nextB = nextB, detectFS = detectFS,
             panes = { [0] = pW, [1] = pM, [2] = pR } }

  local function colOf(m) return m.col or { r = 0.6, g = 0.6, b = 0.6 } end

  -- (re)construit les cartes de modules, groupees par categorie, 2 colonnes.
  local cards = {}
  local function buildCards()
    for _, cd in ipairs(cards) do cd:Hide(); cd:SetParent(nil) end
    wipe(cards)
    local CARDW, CARDH, GAP = 288, 56, 8
    local y = -2
    local function addCat(label, list)
      if #list == 0 then return end
      local h = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      h:SetPoint("TOPLEFT", 4, y); h:SetText("|cFF6A6676" .. label .. "|r")

      -- Tout / Aucun propres a cette categorie (par opposition aux boutons
      -- globaux allOn/allOff qui touchent toutes les categories a la fois).
      local catAll = UI.MakeButton(content, 40, 16, L.WIZ_CAT_ALL)
      catAll:SetPoint("LEFT", h, "RIGHT", 10, 0)
      catAll:SetScript("OnClick", function()
        for _, m in ipairs(list) do wizard.choice[m.key] = true end
        wizard.refreshCards()
      end)
      local catNone = UI.MakeButton(content, 48, 16, L.WIZ_CAT_NONE)
      catNone:SetPoint("LEFT", catAll, "RIGHT", 4, 0)
      catNone:SetScript("OnClick", function()
        for _, m in ipairs(list) do wizard.choice[m.key] = nil end
        wizard.refreshCards()
      end)

      y = y - 22
      for j, m in ipairs(list) do
        local col = colOf(m)
        local card = CreateFrame("Button", nil, content, "BackdropTemplate")
        card:SetSize(CARDW, CARDH)
        local cc, rr = (j - 1) % 2, math.floor((j - 1) / 2)
        card:SetPoint("TOPLEFT", 2 + cc * (CARDW + GAP), y - rr * (CARDH + GAP))
        card:SetBackdrop(UI.FlatBackdrop()); card:SetBackdropColor(0.10, 0.095, 0.125, 0.95)
        local barT = card:CreateTexture(nil, "OVERLAY")
        barT:SetSize(3, CARDH - 2); barT:SetPoint("LEFT", 0, 0)
        barT:SetColorTexture(col.r, col.g, col.b, 0.9)
        local ico = card:CreateTexture(nil, "ARTWORK")
        ico:SetSize(24, 24); ico:SetPoint("LEFT", 10, 0)
        ico:SetColorTexture(col.r * 0.22, col.g * 0.22, col.b * 0.22, 1)
        local ini = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ini:SetPoint("CENTER", ico, "CENTER")
        ini:SetText(Hex(col) .. string.upper(string.sub(m.label or m.addonName or "?", 1, 2)) .. "|r")
        local sw = makeSwitch(card, col)
        sw:SetPoint("RIGHT", -8, 0)
        local nm = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nm:SetPoint("TOPLEFT", ico, "TOPRIGHT", 8, -1)
        nm:SetText(Hex(col) .. (m.label or m.addonName) .. "|r")
        local ds = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        ds:SetPoint("TOPLEFT", nm, "BOTTOMLEFT", 0, -3)
        ds:SetPoint("RIGHT", sw, "LEFT", -8, 0)
        ds:SetJustifyH("LEFT"); ds:SetJustifyV("TOP")
        ds:SetText("|cFF9A96A8" .. (DESC[m.key] or "") .. "|r")
        local function apply()
          local on = wizard.choice[m.key] and true or false
          sw._set(on)
          if on then card:SetBackdropBorderColor(col.r, col.g, col.b, 0.5); card:SetAlpha(1)
          else card:SetBackdropBorderColor(0, 0, 0, 0.8); card:SetAlpha(0.60) end
        end
        local function toggle()
          wizard.choice[m.key] = (not wizard.choice[m.key]) or nil
          apply(); wizard.updateCount()
        end
        card:SetScript("OnClick", toggle)
        sw:SetScript("OnClick", toggle)
        card._apply = apply
        cards[#cards + 1] = card
      end
      y = y - math.ceil(#list / 2) * (CARDH + GAP) - 8
    end
    local trackers, hud = {}, {}
    for _, m in ipairs(wizard.present) do
      if GROUP[m.key] == "hud" then hud[#hud + 1] = m else trackers[#trackers + 1] = m end
    end
    addCat(L.WIZ_CAT_TRACKERS, trackers)
    addCat(L.WIZ_CAT_HUD, hud)
    content:SetHeight(math.max(-y + 10, 10))
    if wizard.detectFS then
      wizard.detectFS:SetText("|cFFE9E7F0" .. #wizard.present .. "|r " .. L.WIZ_DETECTED_FMT)
    end
  end
  wizard.buildCards = buildCards

  function wizard.refreshCards()
    for _, cd in ipairs(cards) do if cd._apply then cd._apply() end end
    wizard.updateCount()
  end

  function wizard.updateCount()
    local c = 0
    for _, m in ipairs(wizard.present) do if wizard.choice[m.key] then c = c + 1 end end
    counter:SetText(hexLav(tostring(c)) .. " / " .. #wizard.present .. " " .. L.WIZ_COUNTER_FMT)
    rSub:SetText(hexLav(tostring(c)) .. " " .. L.WIZ_RECAP_COUNT_FMT)
  end

  function wizard.refreshRecap()
    if wizard._chips then for _, ch in ipairs(wizard._chips) do ch:Hide(); ch:SetParent(nil) end end
    wizard._chips = {}
    local x, yy = 0, 0
    for _, m in ipairs(wizard.present) do
      if wizard.choice[m.key] then
        local col = colOf(m)
        local ch = CreateFrame("Frame", nil, chipsHost, "BackdropTemplate")
        ch:SetBackdrop(UI.FlatBackdrop()); ch:SetBackdropColor(0.10, 0.095, 0.125, 0.95)
        local dot = ch:CreateTexture(nil, "OVERLAY")
        dot:SetSize(8, 8); dot:SetPoint("LEFT", 8, 0); dot:SetColorTexture(col.r, col.g, col.b, 1)
        local t = ch:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("LEFT", dot, "RIGHT", 6, 0); t:SetText(m.label or m.addonName)
        local w = (t:GetStringWidth() or 40) + 30
        ch:SetSize(w, 22)
        if x + w > 600 then x = 0; yy = yy - 28 end
        ch:SetPoint("TOPLEFT", x, yy)
        x = x + w + 8
        wizard._chips[#wizard._chips + 1] = ch
      end
    end
  end

  local function styleSteps()
    for i = 1, 3 do
      local s = steps[i]
      local active = (i - 1) == wizard.step
      local done   = (i - 1) < wizard.step
      s.frame:SetBackdropColor(0.10, 0.095, 0.125, active and 0.95 or 0.5)
      if active then s.frame:SetBackdropBorderColor(LAV[1], LAV[2], LAV[3], 0.6)
      else s.frame:SetBackdropBorderColor(BORD[1], BORD[2], BORD[3], 1) end
      s.num:SetColorTexture(active and LAV[1] or 0.16, active and LAV[2] or 0.15, active and LAV[3] or 0.20, 1)
      if active then s.numT:SetText("|cFF12101C" .. i .. "|r")
      elseif done then s.numT:SetText("|cFFB8ADFF" .. i .. "|r")
      else s.numT:SetText("|cFF8F8B9E" .. i .. "|r") end
      s.lbl:SetText((active and "|cFFE9E7F0" or "|cFF8F8B9E") .. STEP_NAMES[i] .. "|r")
    end
  end

  function wizard.goStep(s)
    wizard.step = s
    for i = 0, 2 do wizard.panes[i]:SetShown(i == s) end
    styleSteps()
    UpdateProgressBar(s)
    prevB:SetShown(s > 0)
    if s == 0 then nextB._label:SetText(hexLav(L.WIZ_START))
    elseif s == 1 then nextB._label:SetText(hexLav(L.WIZ_CONTINUE)); wizard.refreshCards()
    else nextB._label:SetText(hexLav(L.WIZ_INSTALL)); wizard.refreshRecap(); wizard.updateCount() end
  end

  local function finish()
    for _, m in ipairs(wizard.present) do
      if TibiSuite.SetModuleEnabled then
        TibiSuite.SetModuleEnabled(m.key, wizard.choice[m.key] and true or false)
      end
    end
    TibiSuiteDB.setupDone = true
    f:Hide()
    print("|cFFC41F3BTibiSuite|r : " .. L.WIZ_FINISH_PRINT)
    TibiSuite.ShowToast(L.WIZ_FINISH_TOAST)
  end

  prevB:SetScript("OnClick", function() if wizard.step > 0 then wizard.goStep(wizard.step - 1) end end)
  nextB:SetScript("OnClick", function()
    if wizard.step < 2 then wizard.goStep(wizard.step + 1) else finish() end
  end)
  closeB:SetScript("OnClick", finish)   -- fermer = terminer avec la selection en cours

  return wizard
end

-- Appele par le core au tout premier login (setupDone absent).
function TibiSuite.RunFirstSetup()
  local catalog = (TibiSuite.GetCatalog and TibiSuite.GetCatalog()) or {}
  local w = BuildWizard()
  if not w then
    -- Socle absent : repli non destructif (activer tout ce qui est present).
    for _, mod in ipairs(catalog) do
      if TibiSuite.ModuleExists and TibiSuite.ModuleExists(mod.addonName)
         and TibiSuite.SetModuleEnabled then
        TibiSuite.SetModuleEnabled(mod.key, true)
      end
    end
    if TibiSuiteDB then TibiSuiteDB.setupDone = true end
    return
  end
  -- Modules presents seulement, tous coches par defaut.
  w.present, w.choice = {}, {}
  for _, mod in ipairs(catalog) do
    if TibiSuite.ModuleExists and TibiSuite.ModuleExists(mod.addonName) then
      w.present[#w.present + 1] = mod
      w.choice[mod.key] = true
    end
  end
  w.buildCards()
  w.goStep(0)
  w.frame:Show()
end
