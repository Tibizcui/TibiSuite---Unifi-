--[[============================================================================
  PostBox_Module - Glue "mode double" + evenements de la boite aux lettres.

  DETECTION A L'EXECUTION :
    - TibiSuite (core) present -> MODE MODULE : onglet de la barre unifiee,
      pas de bouton minimap propre, recherche globale partagee.
    - TibiSuite absent -> MODE STANDALONE : bouton minimap propre.
  PostBoxDB ne change JAMAIS de forme entre les deux modes.

  Aucun module de la suite n'est LoadOnDemand (mode double) : depuis la
  7.1.5.32, decocher PostBox dans TibiSuite le desactive reellement dans WoW
  au /reload suivant. Tant que le /reload n'est pas fait, ce fichier reste
  silencieux (P.enabled = false : aucun evenement de courrier traite).
============================================================================]]

local P = PostBox
local ACCENT = P.ACCENT
local L = P.L

local function HasCore()
  return _G.TibiSuite and _G.TibiSuite.RegisterModule and true or false
end

-- enabledModules == nil (jamais configure) => tout est actif par defaut.
local function IsEnabledByCore()
  if not (TibiSuiteDB and type(TibiSuiteDB.enabledModules) == "table") then
    return true
  end
  return TibiSuiteDB.enabledModules.Post == true
end

P.enabled = false

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

  local badge = CreateFrame("Frame", nil, btn)
  badge:SetSize(16, 14)
  badge:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 2, 2)
  badge:SetFrameLevel(btn:GetFrameLevel() + 2)
  local bbg = badge:CreateTexture(nil, "BACKGROUND")
  bbg:SetAllPoints(); bbg:SetColorTexture(0.75, 0.15, 0.15, 0.95)
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
-- MASQUAGE DE L'INBOX NATIF (option experimentale)
-- SetAlpha(0) + EnableMouse(false) sur InboxFrame UNIQUEMENT : aucun
-- Show()/Hide()/SetScript ni hook (deux tentatives precedentes avaient casse
-- Echap et le clic sur la boite, via le PlayerInteractionManager securise).
-- Confirme en jeu le 22/08/2026, onglet Envoyer intact.
-- ============================================================================
function P.SetNativeMailVisible(shown)
  local inbox = P.GetInboxContentFrame and P.GetInboxContentFrame()
  if not inbox then return end
  inbox:SetAlpha(shown and 1 or 0)
  if inbox.EnableMouse then inbox:EnableMouse(shown) end
end

-- ============================================================================
-- TRADEBLOCK : bloque les demandes d'echange tant que la boite est ouverte
-- (comme Postal). On ne touche au CVar que s'il etait a 0, et on note qu'il
-- faut le remettre : meme une deconnexion brutale est rattrapee au login.
-- ============================================================================
local function TradeBlockOn()
  if not PostBoxDB.tradeBlock or not (GetCVar and SetCVar) then return end
  local ok, cur = pcall(GetCVar, "blockTrades")
  if ok and cur == "0" then
    if pcall(SetCVar, "blockTrades", "1") then PostBoxDB.tradeBlockRestore = true end
  end
end

local function TradeBlockOff()
  if PostBoxDB and PostBoxDB.tradeBlockRestore and SetCVar then
    pcall(SetCVar, "blockTrades", "0")
    PostBoxDB.tradeBlockRestore = nil
  end
end

-- ============================================================================
-- OUVERTURE / FERMETURE DE LA BOITE AUX LETTRES
-- MAIL_CLOSED existe encore mais PLAYER_INTERACTION_MANAGER_FRAME_HIDE l'a
-- remplace en pratique (10.0.0) : on ecoute les deux.
-- ============================================================================
local function ClosePostBoxWindow()
  if _G.PostBoxMainFrame and _G.PostBoxMainFrame:IsShown() then PostBox_Toggle() end
end

local function OnMailboxClosed()
  if not P.mailboxOpen then return end
  P.SetNativeMailVisible(true)
  P.SetMailboxOpen(false)
  TradeBlockOff()
  ClosePostBoxWindow()
  if P.BlackBook and P.BlackBook.OnMailClosed then P.BlackBook.OnMailClosed() end
  if P.Mule and P.Mule.OnMailClosed then P.Mule.OnMailClosed() end
end

local function OnMailboxShown()
  if PostBoxDB.replaceNativeMailbox then P.SetNativeMailVisible(false) end
  P.SetMailboxOpen(true)
  TradeBlockOn()
  P.OpenWindow()
  P.RefreshCache(true)
  if P.BlackBook and P.BlackBook.OnMailShow then P.BlackBook.OnMailShow() end
  -- Ramassage auto : on laisse le temps au serveur de remplir la boite.
  C_Timer.After(1.2, function()
    if P.mailboxOpen then
      P.RefreshCache(false)
      P.AutoCollectSold()
    end
  end)
end

local mailEvtFrame = CreateFrame("Frame")
mailEvtFrame:RegisterEvent("MAIL_SHOW")
mailEvtFrame:RegisterEvent("MAIL_CLOSED")
mailEvtFrame:RegisterEvent("MAIL_INBOX_UPDATE")
mailEvtFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
mailEvtFrame:RegisterEvent("PLAYER_LOGOUT")
mailEvtFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "PLAYER_LOGOUT" then TradeBlockOff() return end
  if not P.enabled then return end
  if event == "MAIL_SHOW" then
    OnMailboxShown()
  elseif event == "MAIL_INBOX_UPDATE" then
    P.RequestRefresh()
  elseif event == "MAIL_CLOSED" then
    OnMailboxClosed()
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    if Enum.PlayerInteractionType and arg1 == Enum.PlayerInteractionType.MailInfo then
      OnMailboxClosed()
    end
  end
end)

-- ============================================================================
-- COMMANDE SLASH (les deux modes)
-- ============================================================================
local function Slash(msg)
  msg = strtrim((msg or ""):lower())
  if msg == "options" then PostBox_OpenOptions()
  elseif msg == "mule" then if P.Mule then P.Mule.Toggle() end
  elseif msg == "persos" or msg == "alts" then if P.Alts then P.Alts.Toggle() end
  elseif msg == "journal" or msg == "ledger" then if P.Ledger then P.Ledger.Toggle() end
  elseif msg == "carnet" or msg == "book" then if P.BlackBook then P.BlackBook.Toggle() end
  elseif msg == "dnw" then P.ToggleDNWWindow()
  elseif msg == "badge" then
    local unread = 0
    for _, e in ipairs(P.cache) do if not e.wasRead then unread = unread + 1 end end
    local num, total = GetInboxNumItems()
    print(string.format("|cFFB87838PostBox|r badge : boite ouverte=%s, HasNewMail=%s, GetInboxNumItems=%s/%s, cache=%d, non lus=%d",
      tostring(P.mailboxOpen), tostring(HasNewMail and HasNewMail()), tostring(num), tostring(total), #P.cache, unread))
  elseif msg == "debug" then
    P.debugOpenAll = not P.debugOpenAll
    print("|cFFB87838PostBox|r trace : " .. (P.debugOpenAll and "activee" or "desactivee"))
  elseif msg == "help" or msg == "?" then
    print(L.SLASH_HELP)
  else
    PostBox_Toggle()
  end
end

-- ============================================================================
-- INITIALISATION
-- ============================================================================
local function Init()
  -- Restaure le CVar d'echange si la session precedente s'est mal terminee.
  TradeBlockOff()
  if not IsEnabledByCore() then return end
  P.enabled = true

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

  SLASH_POSTBOX1 = "/postbox"
  SLASH_POSTBOX2 = "/pb"
  SlashCmdList["POSTBOX"] = Slash

  -- /reload devant la boite deja ouverte : MAIL_SHOW ne revient pas.
  local mf = P.GetMailFrame and P.GetMailFrame()
  if mf and mf:IsShown() then OnMailboxShown() end

  -- Message de connexion : en suite, on suit TibiSuiteDB.loginMsg (seul
  -- "full" fait parler les modules) ; en autonome, message complet.
  local mode = "full"
  if HasCore() then mode = (TibiSuiteDB and TibiSuiteDB.loginMsg) or "one" end
  if mode == "full" then
    print(string.format(L.LOGIN_MSG, P.VERSION))
  end
  if not HasCore() then
    C_Timer.After(45, function()
      print("|cFFC41F3BTibiSuite|r : plus d'infos sur |cFFFFD700https://www.tibiscui.fr|r")
      print("|cFFC41F3BTibiSuite|r : télécharge Tibi-Companion sur |cFFFFD700https://tibiscui.fr/tibi-companion.html|r")
    end)
  end

  -- Alerte : courriers d'alts (ou de ce perso) qui vont bientot expirer.
  C_Timer.After(6, function()
    if P.Alts and P.Alts.LoginAlert then pcall(P.Alts.LoginAlert) end
  end)

  -- Fenetre laissee ouverte avant le /reload : on la rouvre (comportement
  -- historique conserve).
  if PostBoxDB.open and not P.mailboxOpen then
    P.BuildUI()
    if not _G.PostBoxMainFrame:IsShown() then PostBox_Toggle() end
  end
end

local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("ADDON_LOADED")
evtFrame:RegisterEvent("PLAYER_LOGIN")
evtFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "PostBox" then
    P.InitDB()
  elseif event == "PLAYER_LOGIN" then
    -- On laisse le core terminer son propre PLAYER_LOGIN avant de lire
    -- TibiSuiteDB.enabledModules.
    C_Timer.After(0.5, Init)
  end
end)
