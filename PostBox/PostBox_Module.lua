--[[============================================================================
  PostBox_Module - Glue "mode double".

  DETECTION A L'EXECUTION :
    - TibiSuite (core) present et charge -> MODE MODULE : s'enregistre via
      TibiSuite.RegisterModule (onglet de la barre unifiee, pas de bouton
      minimap propre, recherche globale partagee, panneau d'options du socle).
    - TibiSuite absent -> MODE STANDALONE : construit son propre bouton
      minimap (orbite/drag classique), sa propre commande slash /postbox,
      ouvre sa fenetre directement.
  PostBoxDB ne change JAMAIS de forme entre les deux modes.

  POURQUOI CE .toc N'EST PAS LoadOnDemand (contrairement a tous les autres
  modules de la suite) : LoadOnDemand=1 empeche tout chargement automatique
  au demarrage tant que rien n'appelle explicitement C_AddOns.LoadAddOn() sur
  cet addon. En mode integre, c'est le core qui fait cet appel pour chaque
  module active - mais en mode STANDALONE (sans le core), rien ne
  declencherait jamais ce chargement : l'addon resterait inerte pour
  toujours. PostBox doit donc se charger normalement (comme un addon
  classique) pour honorer sa promesse de fonctionner seul.
  CONSEQUENCE ASSUMEE : contrairement aux autres modules, decocher "PostBox"
  dans le panneau Modules de TibiSuite ne l'empeche pas d'etre CHARGE par
  WoW au /reload suivant (impossible a eviter sans LoadOnDemand) ; ce fichier
  simule neanmoins la meme promesse fonctionnelle en restant silencieux et
  inactif (aucune fenetre, aucun evenement de courrier accroche) tant que le
  module est explicitement desactive dans TibiSuiteDB.enabledModules.
============================================================================]]

local P = PostBox
local ACCENT = P.ACCENT
local L = P.L

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

-- Le core a-t-il explicitement desactive PostBox ? Convention du core :
-- enabledModules == nil (jamais configure) => tout est active par defaut ;
-- enabledModules est une table => seule la presence de [key]=true active.
local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then
    return true  -- pas encore configure (avant le premier assistant) : actif par defaut
  end
  return TibiSuiteDB.enabledModules.Post == true
end

-- ============================================================================
-- MODE STANDALONE : bouton minimap orbitant (drag pour repositionner)
-- ============================================================================
local function BuildStandaloneMinimapButton()
  if _G.PostBoxMinimapBtn or PostBoxDB.minimapHide then return end

  local btn = CreateFrame("Button", "PostBoxMinimapBtn", Minimap)
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
  icon:SetTexture("Interface\\AddOns\\PostBox\\medias\\Logo")

  -- Badge (nombre de courriers en attente) - mis a jour par P.UpdateBadges(),
  -- appele a chaque P.RefreshCache(). Masque quand le compteur est a 0.
  local badge = CreateFrame("Frame", nil, btn, "BackdropTemplate")
  badge:SetSize(16, 14)
  badge:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 2, 2)
  badge:SetFrameLevel(btn:GetFrameLevel() + 2)
  badge:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  badge:SetBackdropColor(0.75, 0.15, 0.15, 0.95)
  badge:SetBackdropBorderColor(0, 0, 0, 0.8)
  local badgeText = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  badgeText:SetPoint("CENTER")
  badgeText:SetTextColor(1, 1, 1)
  badge.text = badgeText
  badge:Hide()
  btn.badge = badge

  local function UpdatePosition()
    local angle = math.rad(PostBoxDB.minimapAngle or 200)
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
    PostBoxDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    UpdatePosition()
  end)

  btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then PostBox_OpenOptions() else PostBox_Toggle() end
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("PostBox")
    GameTooltip:AddLine(L.MM_TOOLTIP_LEFT, 0.9, 0.9, 0.95)
    GameTooltip:AddLine(L.MM_TOOLTIP_RIGHT, 0.9, 0.9, 0.95)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  UpdatePosition()
end

-- ============================================================================
-- OUVERTURE AUTOMATIQUE SUR MAIL_SHOW
-- ----------------------------------------------------------------
-- Sur MAIL_SHOW (le joueur interagit avec une boite aux lettres dans le
-- monde), on ouvre PostBox EN PLUS de la fenetre native de Blizzard (qui
-- reste affichee - voir la note "SUSPENDU" ci-dessous sur pourquoi on ne
-- tente plus de la masquer). PostBox lui-meme ne remplace donc, pour
-- l'instant, que l'usage quotidien (tri/traitement du courrier) ; l'envoi
-- passe encore par les widgets natifs de SendMailFrame (voir
-- PostBox_BlackBook.lua) car il n'existe aucune API publique pour joindre
-- or/objets autrement.
-- Fermeture : MAIL_CLOSED existe encore sur certains clients mais a ete
-- remplace en pratique par PLAYER_INTERACTION_MANAGER_FRAME_HIDE (patch
-- 10.0.0) ; on ecoute les deux par securite/compatibilite.
-- ============================================================================
local function ClosePostBoxWindow()
  if _G.PostBoxMainFrame and _G.PostBoxMainFrame:IsShown() then PostBox_Toggle() end
end

-- HISTORIQUE (2 tentatives echouees avant celle-ci) :
--  1) Hide() conditionne a IsShown() : IsShown() peut valoir false au moment
--     precis de MAIL_SHOW (rien ne garantit l'ordre Blizzard/nous), donc le
--     Hide() ne partait jamais et la fenetre native restait affichee.
--  2) Hide() inconditionnel + hooksecurefunc sur Show() : a casse Echap ET
--     le clic sur la boite aux lettres dans le monde ENTIEREMENT, confirme
--     en jeu. Les boites aux lettres passent par le systeme securise
--     PlayerInteractionManager de Blizzard ; hooksecurefunc(mf, "Show", ...)
--     qui appelle self:Hide() depuis ce contexte a contamine ce chemin
--     securise (meme categorie de bug que la collision Echap/Ellesmere plus
--     haut dans ce fichier). Corrige par un simple /reload cote joueur.
-- TENTATIVE ACTUELLE : SetAlpha(0) + EnableMouse(false) uniquement - AUCUN
-- appel a Show()/Hide()/SetScript ni hook sur ce frame. C'est le meme
-- pattern deja valide sans taint pour la barre XP native (voir
-- XPBar.lua/EnforceNativeBar). Desactive par defaut (PostBoxDB.
-- replaceNativeMailbox = false) : l'utilisateur l'active volontairement
-- depuis les options, en connaissance du caractere experimental (voir
-- OPT_REPLACE_MAILBOX_NOTE dans PostBox_Locale.lua).
--
-- CORRECTIF CONFIRME EN JEU (22/08/2026) : cible P.GetInboxContentFrame()
-- (InboxFrame) au lieu du conteneur entier, pour laisser l'onglet "Envoyer
-- un message" utilisable - le conteneur porte les deux onglets, le masquer
-- en entier bloquait completement l'envoi. Premier essai avait semble
-- infructueux (InboxFrame masque ne masquait visiblement rien), mais
-- diagnostic /run a confirme que MailItem1:GetParent() vaut bien
-- "InboxFrame" (ciblage correct) et que l'echec initial etait un probleme de
-- timing (InboxFrame pas encore cree au tout premier MAIL_SHOW), resolu en
-- retentant P.SetNativeMailVisible(false) a chaque P.RefreshCache() (pas
-- seulement au MAIL_SHOW initial), exactement comme P.TryHookSendMail.
-- Confirme par capture d'ecran : inbox masquee (SetAlpha 0), onglet "Envoyer
-- un message" pleinement fonctionnel (formulaire natif complet).
function P.SetNativeMailVisible(shown)
  local inbox = P.GetInboxContentFrame and P.GetInboxContentFrame()
  if not inbox then return end
  inbox:SetAlpha(shown and 1 or 0)
  if inbox.EnableMouse then inbox:EnableMouse(shown) end
end

local mailEvtFrame = CreateFrame("Frame")
mailEvtFrame:RegisterEvent("MAIL_SHOW")
mailEvtFrame:RegisterEvent("MAIL_CLOSED")
mailEvtFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
mailEvtFrame:SetScript("OnEvent", function(_, event, arg1)
  if not IsEnabledByCore() then return end  -- module desactive via le core : reste silencieux
  if event == "MAIL_SHOW" then
    if PostBoxDB and PostBoxDB.replaceNativeMailbox then P.SetNativeMailVisible(false) end
    if P.OpenWindow then P.OpenWindow() end
    if P.RefreshCache then P.RefreshCache() end
  elseif event == "MAIL_CLOSED" then
    P.SetNativeMailVisible(true)
    ClosePostBoxWindow()
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    if Enum.PlayerInteractionType and arg1 == Enum.PlayerInteractionType.MailInfo then
      P.SetNativeMailVisible(true)
      ClosePostBoxWindow()
    end
  end
end)

-- ============================================================================
-- INITIALISATION
-- ============================================================================
local function Init()
  if not IsEnabledByCore() then
    -- Desactive via le panneau Modules du core : reste silencieux (voir note
    -- en tete de fichier sur l'absence de LoadOnDemand pour ce module).
    return
  end

  if HasCore() then
    TibiSuite.RegisterModule({
      key            = "Post",
      label          = "PostBox",
      accent         = ACCENT,
      onOpen         = function() PostBox_Toggle() end,
      onOptions      = function() PostBox_OpenOptions() end,
      searchProvider = P.SearchProvider,
    })
  else
    BuildStandaloneMinimapButton()
  end

  -- Commande slash disponible dans les DEUX modes (comme le reste de la
  -- suite - /dt, /lt, /rt, etc. fonctionnent aussi bien integres que
  -- standalone) : avant ce correctif, /postbox n'existait qu'en standalone.
  SLASH_POSTBOX1 = "/postbox"
  SLASH_POSTBOX2 = "/pb"
  SlashCmdList["POSTBOX"] = function(msg)
    msg = strtrim((msg or ""):lower())
    if msg == "options" then PostBox_OpenOptions()
    else PostBox_Toggle() end
  end

  print("|cFFB87838PostBox|r v7.0 chargé -- tapez |cFFFFD700/pb|r pour ouvrir.")

  -- Le courrier ouvert par le systeme au login (frere du perso) reste geree
  -- par Blizzard ; on rafraichit juste notre cache si la fenetre est deja
  -- ouverte (utile apres un /reload avec la fenetre repositionnee visible).
  if PostBoxDB.open and P.BuildUI then
    P.BuildUI()
    PostBox_Toggle()
  end
end

local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("ADDON_LOADED")
evtFrame:RegisterEvent("PLAYER_LOGIN")
evtFrame:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "PostBox" then
    P.InitDB()
  elseif event == "PLAYER_LOGIN" then
    -- Petit delai : si TibiSuite est present, on le laisse d'abord terminer
    -- son propre PLAYER_LOGIN (assistant premier lancement / activation des
    -- modules) avant de lire TibiSuiteDB.enabledModules.
    C_Timer.After(0.5, Init)
  end
end)
