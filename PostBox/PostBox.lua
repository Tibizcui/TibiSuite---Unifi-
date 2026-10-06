--[[============================================================================
  PostBox - Gestion avancee de la boite aux lettres (reecriture native, style
  TibiSuite, inspiree du cahier des charges de l'addon Postal).
  Auteur : Tibiscui - Kirin Tor
  SavedVariables : PostBoxDB (identique en mode module et en mode standalone).

  API de courrier utilisees (fonctions globales, aucune n'a ete deplacee dans
  C_Mail a ce jour) : CheckInbox, GetInboxNumItems, GetInboxHeaderInfo,
  GetInboxItem, GetInboxItemLink, GetInboxInvoiceInfo, GetInboxText,
  CheckInboxItem, TakeInboxItem, TakeInboxMoney, ReturnInboxItem,
  DeleteInboxItem, SendMail, HasSendMailItem, ClickSendMailItemButton.

  REGLES CONFIRMEES EN JEU (2026-09-21) qui structurent tout ce fichier :
    - le serveur n'accepte qu'UNE prise (objet ou or) a la fois ; les prises
      envoyees dans la meme image sont ignorees silencieusement ;
    - les en-tetes (hasItem, money) ne sont pas rafraichis tant que la boite
      reste ouverte : on lit les emplacements en direct (GetInboxItemLink) ;
    - on parcourt la boite du dernier au premier index.
  Depuis la 7.1.5.37, TOUTES les prises passent par un seul moteur (P.OpenAll
  et ses options) : Tout ouvrir, la selection, Maj+clic, clic droit, le
  transfert et le ramassage automatique. Plus aucune boucle synchrone.
============================================================================]]

PostBox = PostBox or {}
local P = PostBox
P.ACCENT = { 0.72, 0.47, 0.22 }  -- laiton / cachet de cire

local ACCENT = P.ACCENT
local L = P.L

local function Meta(field)
  local fn = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
  if not fn then return nil end
  local ok, v = pcall(fn, "PostBox", field)
  return ok and v or nil
end
P.VERSION = Meta("Version") or "?"

local function GetUI() return _G.TibiMidnight end
local function AccentText(txt)
  local UI = GetUI()
  if not UI then return txt end
  return UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) .. txt .. "|r"
end
P.AccentText = AccentText

local function Coin(c) return GetCoinTextureString(math.max(0, math.floor(c or 0))) end
P.Coin = Coin

local function Debug(fmt, ...)
  if P.debugOpenAll then print("|cFF9DA5FFPostBox|r " .. string.format(fmt, ...)) end
end
P.Debug = Debug

-- ============================================================================
-- FRAME RACINE DE LA BOITE AUX LETTRES BLIZZARD
-- Confirme en jeu (21/08/2026) : le conteneur s'appelle "ConsortiumMailFrame"
-- ("MailFrame" existe encore mais reste cache). On le deduit du parent de
-- MailFrameTab1 (stable), avec repli sur les noms connus.
-- ============================================================================
function P.GetMailFrame()
  if _G.MailFrameTab1 and _G.MailFrameTab1.GetParent then
    local parent = _G.MailFrameTab1:GetParent()
    if parent then return parent end
  end
  return _G.ConsortiumMailFrame or _G.MailFrame
end

-- Sous-cadre de l'onglet Reception seul (le conteneur porte aussi l'onglet
-- Envoyer, qu'il ne faut jamais masquer). Confirme en jeu le 22/08/2026.
function P.GetInboxContentFrame()
  return _G.InboxFrame
end

-- ============================================================================
-- SAVEDVARIABLES : defauts + init
-- ============================================================================
local function DeepCopy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, val in pairs(v) do out[k] = DeepCopy(val) end
  return out
end

local DEFAULTS = {
  reserveSlots   = 4,      -- slots de sac a garder libres pendant OpenAll
  codThreshold   = 0,      -- confirmation du contre-remboursement a partir de ce montant (cuivre), 0 = toujours
  autoReturnDNW  = true,   -- DoNotWant : retourner au lieu de ramasser
  expiryWarnDays = 1,      -- indicateur d'expiration en-deca de N jours
  autoCollectSold = false, -- ramasse l'or des ventes HV des l'ouverture de la boite
  tradeBlock     = false,  -- bloque les demandes d'echange tant que la boite est ouverte
  altAlert       = true,   -- alerte au login : courriers d'alts qui vont expirer
  altAlertDays   = 3,
  filters = {
    cancelled = true, expired = true, outbid = true, sold = true, won = true, other = true,
  },
  doNotWant  = {},   -- [itemID] = true
  recentRecipients = {},  -- { "Nom-Royaume", ... } (20 max, plus recent en tete)
  blackBook  = { contacts = {}, presets = {} },
  knownChars = {},   -- ["Nom-Royaume"] = { faction=, class=, lastSeen= }
  inboxes    = {},   -- ["Nom-Royaume"] = instantane de la boite (PostBox_Alts.lua)
  ledger     = { entries = {}, seen = {} },  -- journal HV (PostBox_Ledger.lua)
  mule       = { rules = {}, autoSend = true },  -- PostBox_Mule.lua
  stats = {
    goldReceived = 0, goldSent = 0, auctionSold = 0, auctionBought = 0, auctionCut = 0,
    senders = {}, rakeSession = 0, history = {},
  },
  floatHidden = {},
  minimapAngle = 200,
  minimapHide  = false,
  open = false,
  smartSort = true,
  replaceNativeMailbox = false,  -- masque (SetAlpha, jamais Show/Hide) l'inbox natif sur MAIL_SHOW
}

-- Comble recursivement les champs manquants d'une table existante (une
-- SavedVariables d'une version anterieure : "stats={}" ou "mule={}" ne doit
-- jamais bloquer l'ajout d'un nouveau sous-champ).
local function FillDefaults(dst, src)
  for k, v in pairs(src) do
    if dst[k] == nil then
      dst[k] = DeepCopy(v)
    elseif type(v) == "table" and type(dst[k]) == "table" and next(v) ~= nil
      and k ~= "filters" then
      FillDefaults(dst[k], v)
    end
  end
end

local function CharKey()
  local name, realm = UnitName("player"), GetRealmName()
  if not (name and realm) then return nil end
  return name .. "-" .. realm
end
P.CharKey = CharKey

function P.InitDB()
  PostBoxDB = PostBoxDB or {}
  FillDefaults(PostBoxDB, DEFAULTS)
  if type(PostBoxDB.filters) ~= "table" then PostBoxDB.filters = DeepCopy(DEFAULTS.filters) end
  local key = CharKey()
  if key then
    PostBoxDB.knownChars[key] = {
      faction = UnitFactionGroup("player"),
      class   = select(2, UnitClass("player")),
      lastSeen = time(),
    }
  end
end

-- ============================================================================
-- NOMS ET ROYAUMES
-- Les cles internes sont "Nom-Royaume" avec le nom de royaume tel que renvoye
-- par GetRealmName() (espaces compris). Un destinataire de courrier, lui,
-- s'ecrit "Nom" (meme royaume) ou "Nom-RoyaumeNormalise" (sans espaces ni
-- tirets). On ne peut envoyer du courrier qu'aux royaumes CONNECTES.
-- ============================================================================
local function NormRealm(r) return (tostring(r or ""):gsub("[%s%-]", "")) end
P.NormRealm = NormRealm

function P.SplitKey(key)
  local name, realm = tostring(key or ""):match("^([^%-]+)%-(.+)$")
  return name or key, realm
end

-- Destinataire a taper dans le champ de la boite pour une cle "Nom-Royaume".
function P.MailName(key)
  local name, realm = P.SplitKey(key)
  if not realm or NormRealm(realm) == NormRealm(GetRealmName()) then return name end
  return name .. "-" .. NormRealm(realm)
end

local connectedCache
function P.IsConnectedRealm(realm)
  if not realm then return true end
  local n = NormRealm(realm)
  if n == NormRealm(GetRealmName()) then return true end
  if not connectedCache then
    connectedCache = {}
    if GetAutoCompleteRealms then
      local ok, list = pcall(GetAutoCompleteRealms)
      if ok and type(list) == "table" then
        for _, r in ipairs(list) do connectedCache[NormRealm(r)] = true end
      end
    end
  end
  return connectedCache[n] == true
end

-- Retrouve la cle "Nom-Royaume" d'un de nos personnages a partir d'un
-- destinataire tape ("Nom" ou "Nom-Royaume"), ou nil si ce n'est pas un alt.
function P.ResolveOwnChar(recipient)
  if not recipient or recipient == "" then return nil end
  local name, realm = tostring(recipient):match("^([^%-]+)%-(.+)$")
  name = name or recipient
  local wantRealm = realm and NormRealm(realm) or NormRealm(GetRealmName())
  local lname = name:lower()
  for key in pairs(PostBoxDB.knownChars or {}) do
    local n, r = P.SplitKey(key)
    if n and n:lower() == lname and NormRealm(r) == wantRealm then return key end
  end
  return nil
end

-- ============================================================================
-- FENETRES MAISON : confirmation, saisie, autocompletion
-- Regle de la suite : on n'ecrit JAMAIS dans StaticPopupDialogs (taint). En
-- suite, on emprunte la confirmation du core ; en autonome, une mini fenetre.
-- ============================================================================
local function MakeDialog(name, h)
  local UI = GetUI()
  local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  f:SetSize(380, h)
  f:SetPoint("CENTER", 0, 120)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:EnableMouse(true); f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UI then UI.SkinFrame(f, ACCENT, UI.C.PANEL) end
  tinsert(UISpecialFrames, name)
  local msg = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  msg:SetPoint("TOP", 0, -20); msg:SetWidth(340); msg:SetJustifyH("CENTER")
  f.msg = msg
  local function btn(label, x)
    local b = UI and UI.MakeButton(f, 100, 24, label) or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    if not UI then b:SetSize(100, 24); b:SetText(label) end
    b:SetPoint("BOTTOM", x, 14)
    return b
  end
  f.yes = btn(OKAY or "OK", -56)
  f.no = btn(CANCEL or "Annuler", 56)
  f.no:SetScript("OnClick", function() f:Hide() end)
  f:Hide()
  return f
end

function P.Confirm(text, onAccept)
  if _G.TibiSuite and _G.TibiSuite.ShowConfirm then
    _G.TibiSuite.ShowConfirm(text, onAccept)
    return
  end
  local f = _G.PostBoxConfirmFrame or MakeDialog("PostBoxConfirmFrame", 130)
  f.msg:SetText(text)
  f.yes:SetScript("OnClick", function() f:Hide(); if onAccept then onAccept() end end)
  f:Show()
end

-- Saisie d'un texte (destinataire, nom de modele...). L'autocompletion des
-- noms se branche si opts.names.
function P.Prompt(text, default, onAccept, opts)
  opts = opts or {}
  local f = _G.PostBoxPromptFrame
  if not f then
    f = MakeDialog("PostBoxPromptFrame", 150)
    local UI = GetUI()
    local box = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    box:SetSize(300, 22)
    box:SetPoint("TOP", f.msg, "BOTTOM", 0, -12)
    if UI then box:SetBackdrop(UI.FlatBackdrop()); box:SetBackdropColor(0.02, 0.02, 0.03, 0.95); box:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8) end
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlight")
    box:SetTextInsets(6, 6, 0, 0)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    f.box = box
  end
  f.msg:SetText(text)
  f.box:SetText(default or "")
  if opts.names then P.AttachAutocomplete(f.box) end
  f.box._acOff = not opts.names
  local function accept()
    local v = strtrim(f.box:GetText() or "")
    f:Hide()
    if v ~= "" and onAccept then onAccept(v) end
  end
  f.yes:SetScript("OnClick", accept)
  f.box:SetScript("OnEnterPressed", accept)
  f:Show()
  f.box:SetFocus()
end

-- Popup d'autocompletion des noms (contacts + alts + recents), accroche a
-- n'importe quelle EditBox par HookScript (jamais SetScript : la boite de
-- saisie native du destinataire garde ses propres gestionnaires intacts).
local acPopup
local function GetACPopup()
  if acPopup then return acPopup end
  local UI = GetUI()
  local f = CreateFrame("Frame", "PostBoxAutocomplete", UIParent, "BackdropTemplate")
  f:SetFrameStrata("TOOLTIP")
  f:SetSize(190, 20)
  if UI then UI.SkinFrame(f, ACCENT, UI.C.PANEL) end
  f.rows = {}
  f:Hide()
  acPopup = f
  return f
end

local function ShowSuggestions(box)
  if box._acOff then return end
  local f = GetACPopup()
  local B = P.BlackBook
  local list = (B and B.Autocomplete) and B.Autocomplete(box:GetText() or "") or {}
  if #list == 0 or not box:HasFocus() then f:Hide(); return end
  local UI = GetUI()
  local n = math.min(#list, 8)
  for i = 1, n do
    local r = f.rows[i]
    if not r then
      r = UI and UI.MakeButton(f, 182, 18, "") or CreateFrame("Button", nil, f)
      r._label:ClearAllPoints(); r._label:SetPoint("LEFT", 6, 0); r._label:SetJustifyH("LEFT")
      f.rows[i] = r
    end
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 19)
    local entry = list[i]
    r._label:SetText(entry.label or entry.name)
    r:SetScript("OnClick", function()
      box:SetText(entry.name)
      box:SetCursorPosition(#entry.name)
      f:Hide()
    end)
    r:Show()
  end
  for i = n + 1, #f.rows do f.rows[i]:Hide() end
  f:SetHeight(n * 19 + 8)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, 2)
  f:Show()
end

function P.AttachAutocomplete(box)
  if not box or box._pbAC then return end
  box._pbAC = true
  box:HookScript("OnTextChanged", function(self, userInput)
    if userInput then ShowSuggestions(self) end
  end)
  box:HookScript("OnEditFocusLost", function()
    C_Timer.After(0.25, function() if acPopup and not box:HasFocus() then acPopup:Hide() end end)
  end)
  box:HookScript("OnHide", function() if acPopup then acPopup:Hide() end end)
end

-- ============================================================================
-- CLASSIFICATION D'UN COURRIER
-- 1) facture de l'Hotel des ventes (GetInboxInvoiceInfo) : independante de la
--    langue, fiable ; 2) a defaut, mots-cles de PostBox_Locale.lua.
-- ============================================================================
local function MatchesAny(haystack, keywords)
  for _, kw in ipairs(keywords or {}) do
    if haystack:find(kw, 1, true) then return true end
  end
  return false
end

local function Norm(s)
  local UI = GetUI()
  return UI and UI.Normalize(s or "") or tostring(s or ""):lower()
end

function P.ClassifyMail(sender, subject, invoice)
  if invoice then
    if invoice.type == "seller" or invoice.type == "seller_temp_invoice" then return "sold" end
    if invoice.type == "buyer" then return "won" end
  end
  local kw = P.AH_KEYWORDS
  if not MatchesAny(Norm(sender), kw.sender) then return "other" end
  local subj = Norm(subject)
  if MatchesAny(subj, kw.cancelled) then return "cancelled" end
  if MatchesAny(subj, kw.expired) then return "expired" end
  if MatchesAny(subj, kw.outbid) then return "outbid" end
  if MatchesAny(subj, kw.sold) then return "sold" end
  if MatchesAny(subj, kw.won) then return "won" end
  return "other"
end

local function ReadInvoice(i)
  if not GetInboxInvoiceInfo then return nil end
  local ok, invType, itemName, playerName, bid, buyout, deposit, consignment, _, _, _, count =
    pcall(GetInboxInvoiceInfo, i)
  if not ok or not invType then return nil end
  return {
    type = invType, item = itemName, player = playerName, bid = bid or 0, buyout = buyout or 0,
    deposit = deposit or 0, cut = consignment or 0, count = count or 1,
  }
end

-- ============================================================================
-- CACHE DE LA BOITE DE RECEPTION
-- RefreshCache(poll) : poll=true relance aussi CheckInbox (au plus toutes les
-- 2 s). L'evenement MAIL_INBOX_UPDATE ne le fait JAMAIS : avant la 7.1.5.37,
-- chaque evenement relancait CheckInbox, qui relancait l'evenement, soit une
-- requete serveur et une reconstruction complete toutes les 2 s tant que la
-- boite restait ouverte.
-- ============================================================================
P.cache = {}

local function SafeGetItemLink(index, attachIndex)
  local ok, link = pcall(GetInboxItemLink, index, attachIndex or 1)
  if ok then return link end
  return nil
end
P.SafeGetItemLink = SafeGetItemLink

local function SafeGetItemCount(index, attachIndex)
  if not GetInboxItem then return 1 end
  local ok, _, _, _, count = pcall(GetInboxItem, index, attachIndex)
  if ok and count and count > 0 then return count end
  return 1
end

-- Cle "raisonnablement stable" d'un courrier : PAS l'index (il se decale des
-- qu'un courrier disparait). Contient le nombre de pieces jointes et l'objet
-- pour distinguer les courriers identiques du Maitre de poste.
local function EntryKey(entry)
  return (entry.sender or "") .. "\30" .. (entry.subject or "") .. "\30"
    .. tostring(entry.money or 0) .. "\30" .. tostring(entry.daysLeft or 0)
    .. "\30" .. tostring(entry.hasItem or 0) .. "\30" .. (entry.itemLink or "")
end

local lastCheckInbox = 0
function P.RefreshCache(poll)
  if poll and CheckInbox and (GetTime() - lastCheckInbox) > 2 then
    lastCheckInbox = GetTime()
    pcall(CheckInbox)
  end
  wipe(P.cache)
  local numItems = GetInboxNumItems() or 0
  for i = 1, numItems do
    local _, _, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned,
      _, canReply = GetInboxHeaderInfo(i)
    if sender then
      local invoice = ReadInvoice(i)
      local e = {
        index = i, sender = sender, subject = subject or "",
        money = money or 0, cod = CODAmount or 0, daysLeft = daysLeft or 0,
        hasItem = hasItem or 0, wasRead = wasRead, wasReturned = wasReturned, canReply = canReply,
        invoice = invoice,
        itemLink = (hasItem and hasItem > 0) and SafeGetItemLink(i, 1) or nil,
      }
      e.category = P.ClassifyMail(sender, subject, invoice)
      e.key = EntryKey(e)
      P.cache[#P.cache + 1] = e
    end
  end
  if P.mailboxOpen then
    if P.Ledger and P.Ledger.Scan then pcall(P.Ledger.Scan, P.cache) end
    if P.Alts and P.Alts.Snapshot then pcall(P.Alts.Snapshot, P.cache) end
  end
  if P.RefreshWindow then P.RefreshWindow() end
  if P.UpdateBadges then P.UpdateBadges() end
  -- InboxFrame peut ne pas exister au tout premier MAIL_SHOW : on retente ici.
  if PostBoxDB and PostBoxDB.replaceNativeMailbox and P.mailboxOpen and P.SetNativeMailVisible then
    P.SetNativeMailVisible(false)
  end
  return P.cache
end

-- Rafraichissement differe : regroupe les rafales de MAIL_INBOX_UPDATE (le
-- client en envoie plusieurs par prise) en une seule reconstruction.
local refreshPending = false
function P.RequestRefresh()
  if refreshPending then return end
  refreshPending = true
  C_Timer.After(0.1, function()
    refreshPending = false
    P.RefreshCache(false)
  end)
end

-- ============================================================================
-- SACS : slots libres des sacs generalistes (les sacs de metier ne comptent
-- pas : un objet quelconque ne peut pas y aller)
-- ============================================================================
function P.GetFreeBagSlots()
  local free = 0
  local numBags = NUM_BAG_SLOTS or 4
  for bag = 0, numBags do
    if C_Container and C_Container.GetContainerNumFreeSlots then
      local n, family = C_Container.GetContainerNumFreeSlots(bag)
      if n and (family == nil or family == 0) then free = free + n end
    end
  end
  return free
end

-- ============================================================================
-- DoNotWant : objets a retourner automatiquement au lieu de les ramasser
-- ============================================================================
local function ItemIDOf(link)
  if not link then return nil end
  local fn = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
  if not fn then return nil end
  local ok, id = pcall(fn, link)
  return ok and id or nil
end
P.ItemIDOf = ItemIDOf

function P.IsDoNotWant(itemLink)
  local id = ItemIDOf(itemLink)
  return id and PostBoxDB.doNotWant[id] or false
end

function P.SetDoNotWant(itemLink, on)
  local id = ItemIDOf(itemLink)
  if not id then return end
  PostBoxDB.doNotWant[id] = on and true or nil
  if P.RefreshDNWWindow then P.RefreshDNWWindow() end
end

-- ============================================================================
-- STATS : historique par jour (AAAA-MM-JJ, purge a 60 jours) et par perso.
-- Stats/Core.lua lit history[jour].auctionSold (SX.ReadPostBoxAHDeltaToday).
-- ============================================================================
local function TodayKey() return date("%Y-%m-%d") end
local HISTORY_MAX_DAYS = 60

local function GetHistoryDay(dayKey)
  local st = PostBoxDB.stats
  st.history = st.history or {}
  local d = st.history[dayKey]
  if not d then
    d = { goldReceived = 0, goldSent = 0, auctionSold = 0, auctionBought = 0 }
    st.history[dayKey] = d
    local keys = {}
    for k in pairs(st.history) do keys[#keys + 1] = k end
    if #keys > HISTORY_MAX_DAYS then
      table.sort(keys)
      for i = 1, #keys - HISTORY_MAX_DAYS do st.history[keys[i]] = nil end
    end
  end
  return d
end

local function GetCharBucket()
  local key = CharKey()
  if not key then return nil end
  local st = PostBoxDB.stats
  st.byChar = st.byChar or {}
  local c = st.byChar[key]
  if not c then
    c = { goldReceived = 0, goldSent = 0, auctionSold = 0, auctionBought = 0 }
    st.byChar[key] = c
  end
  return c
end

local function AddStat(field, amount)
  if not amount or amount <= 0 then return end
  local st = PostBoxDB.stats
  st[field] = (st[field] or 0) + amount
  local d = GetHistoryDay(TodayKey())
  d[field] = (d[field] or 0) + amount
  local c = GetCharBucket()
  if c then c[field] = (c[field] or 0) + amount end
end

local function TrackReceivedGold(amount, sender)
  if not amount or amount <= 0 then return end
  AddStat("goldReceived", amount)
  local st = PostBoxDB.stats
  st.rakeSession = (st.rakeSession or 0) + amount
  if sender then st.senders[sender] = (st.senders[sender] or 0) + amount end
end

-- Achat HV : compte UNE fois par facture "buyer" (appele par le journal HV).
-- Avant la 7.1.5.37 on lisait l'or du courrier "gagne", toujours a 0 (ce
-- courrier contient l'objet, pas d'or) : les achats restaient a zero.
function P.TrackAuctionBought(amount)
  AddStat("auctionBought", amount)
end
function P.TrackAuctionCut(amount)
  if amount and amount > 0 then
    PostBoxDB.stats.auctionCut = (PostBoxDB.stats.auctionCut or 0) + amount
  end
end

-- ============================================================================
-- OR RECU : compte seulement quand le serveur l'a vraiment verse
-- TakeInboxMoney est asynchrone et peut etre refuse sans erreur Lua. On
-- memorise GetMoney() avant la prise, et c'est PLAYER_MONEY (hausse reelle
-- de l'or) qui valide le montant. Sans confirmation en 2,5 s, rien n'est
-- compte et la prise est signalee en echec.
-- ============================================================================
P.pendingMoney = nil
P.sessionMoneyTaken = {}  -- courriers dont l'or a ete pris cette visite (en-tetes figes)

-- Identifiant d'un courrier pour la visite en cours, independant des pieces
-- jointes (qui changent au fil des prises).
function P.MailIdKey(e)
  return (e.sender or "") .. "\30" .. (e.subject or "") .. "\30" .. math.floor((e.daysLeft or 0) * 1440)
end

function P.TakeMoneyTracked(entry, res)
  P.pendingMoney = {
    before = GetMoney(), amount = entry.money or 0, sender = entry.sender,
    category = entry.category, t = GetTime(), res = res, idk = P.MailIdKey(entry),
  }
  TakeInboxMoney(entry.index)
end

local moneyWatcher = CreateFrame("Frame")
moneyWatcher:RegisterEvent("PLAYER_MONEY")
moneyWatcher:SetScript("OnEvent", function()
  local pm = P.pendingMoney
  if not pm or GetMoney() <= pm.before then return end
  P.pendingMoney = nil
  P.sessionMoneyTaken[pm.idk] = true
  TrackReceivedGold(pm.amount, pm.sender)
  if pm.category == "sold" then AddStat("auctionSold", pm.amount) end
  if pm.res then pm.res.gold = pm.res.gold + pm.amount end
  Debug("or confirme : %s", Coin(pm.amount))
end)

-- ============================================================================
-- ENVOI : suivi des courriers envoyes
-- hooksecurefunc sur SendMail (fonction API, pas une methode de frame
-- protegee) lit le formulaire au moment de l'envoi ; on ne valide qu'a
-- MAIL_SEND_SUCCESS (or envoye, destinataire recent, courrier "en route" vers
-- un alt). P.OnSendResult(fn) inscrit un ecouteur (carnet, mule, copie).
-- ============================================================================
local pendingSend
local sendListeners = {}
function P.OnSendResult(fn) sendListeners[#sendListeners + 1] = fn end

local function CountSendAttachments()
  local n = 0
  if HasSendMailItem then
    for i = 1, (ATTACHMENTS_MAX_SEND or 12) do
      local ok, has = pcall(HasSendMailItem, i)
      if ok and has then n = n + 1 end
    end
  end
  return n
end
P.CountSendAttachments = CountSendAttachments

if SendMail then
  hooksecurefunc("SendMail", function(recipient)
    local copper = 0
    if _G.SendMailMoney and MoneyInputFrame_GetCopper then
      local ok, c = pcall(MoneyInputFrame_GetCopper, _G.SendMailMoney)
      if ok and c then copper = c end
    end
    local isCOD = _G.SendMailCODButton and _G.SendMailCODButton.GetChecked and _G.SendMailCODButton:GetChecked()
    pendingSend = {
      to = recipient, gold = isCOD and 0 or copper, items = CountSendAttachments(), t = GetTime(),
    }
  end)
end

local sendWatcher = CreateFrame("Frame")
sendWatcher:RegisterEvent("MAIL_SEND_SUCCESS")
sendWatcher:RegisterEvent("MAIL_FAILED")
sendWatcher:SetScript("OnEvent", function(_, event)
  local s = pendingSend
  pendingSend = nil
  local ok = (event == "MAIL_SEND_SUCCESS")
  if ok and s then
    AddStat("goldSent", s.gold)
    if P.BlackBook and P.BlackBook.RecordRecipient then P.BlackBook.RecordRecipient(s.to) end
    if P.Alts and P.Alts.RecordIncoming then pcall(P.Alts.RecordIncoming, s.to, s.gold, s.items) end
  end
  for _, fn in ipairs(sendListeners) do pcall(fn, ok, s and s.to) end
end)

-- ============================================================================
-- MOTEUR UNIQUE DE PRISE : P.OpenAll(opts)
-- Une seule action serveur par tick (0,6 s), courrier par courrier du dernier
-- au premier index, emplacements lus en direct. Options :
--   keys       = { [cle]=true }  courriers precis (selection, Maj+clic...)
--   categories = { sold=true }   categories precises (invendus, ramassage auto)
--   moneyOnly  = true            ne prend que l'or
--   allowCOD   = true            accepte le contre-remboursement (apres confirmation)
--   silent     = true            ni message de depart ni recapitulatif
--   onDone     = fn(result)
-- Les courriers en contre-remboursement sont TOUJOURS ignores sans allowCOD :
-- avant la 7.1.5.37, "Tout ouvrir" les payait sans rien demander.
-- ============================================================================
P.openAll = { active = false }
local queueTimer
local deleteQueue  -- declare ici : le moteur refuse de demarrer pendant une suppression

local function NewResult()
  return { loot = {}, slots = {}, gold = 0, itemsTaken = 0, returned = 0, codSkipped = 0, failed = 0 }
end

local function AddLoot(res, itemLink, count)
  if not itemLink then return end
  local e = res.loot[itemLink]
  if not e then e = { link = itemLink, count = 0 }; res.loot[itemLink] = e end
  e.count = e.count + (count or 1)
  res.itemsTaken = res.itemsTaken + 1
  res.slots[#res.slots + 1] = itemLink  -- une entree par piece jointe reellement prise
end

local function PassesFilters(entry)
  if entry.category == "other" then return true end
  return PostBoxDB.filters[entry.category] ~= false
end

local function QueueEligible(entry, opts)
  local hasMoney = (entry.money or 0) > 0
  if not (hasMoney or (entry.hasItem or 0) > 0) then return false end
  if opts.moneyOnly and not hasMoney then return false end
  if opts.keys then return opts.keys[entry.key] == true end
  if opts.categories then return opts.categories[entry.category] == true end
  return PassesFilters(entry)
end

function P.IsBusy()
  return P.openAll.active or deleteQueue ~= nil
end

function P.OpenAll(opts)
  opts = opts or {}
  if P.IsBusy() then return false end
  local res = NewResult()
  local st = { cursor = math.huge, passes = 1, cur = nil, codSeen = {} }
  P.openAll.active = true
  if not opts.silent then print(L.MSG_OPENALL_START) end

  local step
  local function schedule(delay)
    if queueTimer then queueTimer:Cancel() end
    queueTimer = C_Timer.NewTimer(delay, step)
  end

  local function finish(reason)
    P.openAll.active = false
    if queueTimer then queueTimer:Cancel(); queueTimer = nil end
    if reason == "bagsfull" then print(string.format(L.MSG_OPENALL_BAGSFULL_FMT, PostBoxDB.reserveSlots or 0)) end
    if res.codSkipped > 0 then print(string.format(L.MSG_COD_SKIPPED_FMT, res.codSkipped)) end
    if res.failed > 0 then print(string.format(L.MSG_TAKE_FAILED_FMT, res.failed)) end
    if res.returned > 0 then print(string.format(L.MSG_DNW_RETURNED_FMT, res.returned)) end
    if not opts.silent and P.ShowRecapPopup then P.ShowRecapPopup(res) end
    if opts.onDone then pcall(opts.onDone, res) end
    P.RefreshCache(true)
  end

  -- Pieces jointes dont la prise a ete demandee : on les credite au butin
  -- seulement quand l'emplacement est vide en lecture directe.
  local function reconcile(cur, vanished)
    for a, info in pairs(cur.pending) do
      if vanished or not SafeGetItemLink(cur.index, a) then
        AddLoot(res, info.link, info.count)
        cur.pending[a] = nil
      end
    end
  end

  step = function()
    local ok, err = pcall(function()
      -- On attend la confirmation de l'or precedent avant toute autre prise.
      if P.pendingMoney then
        if GetTime() - P.pendingMoney.t < 2.5 then return schedule(0.2) end
        P.pendingMoney = nil
        res.failed = res.failed + 1
        Debug("or non confirme par le serveur")
      end
      P.RefreshCache(false)

      local cur, target = st.cur, nil
      if cur then
        for _, e in ipairs(P.cache) do
          if e.index == cur.index then target = e; break end
        end
        -- Le courrier a disparu (vide puis supprime par le serveur), ou un
        -- autre courrier a glisse a sa place : ses prises sont faites.
        if not target or target.sender ~= cur.sender or target.subject ~= cur.subject then
          reconcile(cur, true)
          st.cursor, st.cur, cur, target = cur.index, nil, nil, nil
        else
          reconcile(cur, false)
        end
      end

      if not target then
        for _, e in ipairs(P.cache) do
          if e.index < st.cursor and QueueEligible(e, opts) then
            if (e.cod or 0) > 0 and not opts.allowCOD then
              if not st.codSeen[e.key] then st.codSeen[e.key] = true; res.codSkipped = res.codSkipped + 1 end
            elseif not target or e.index > target.index then
              target = e
            end
          end
        end
        if target then
          cur = { index = target.index, sender = target.sender, subject = target.subject, pending = {}, tries = {} }
          st.cur = cur
        end
      end

      if not target then
        -- Plus de 50 courriers : le client n'en montre que 50 a la fois.
        local num, total = GetInboxNumItems()
        if not opts.keys and (total or 0) > (num or 0) and st.passes < 5 then
          st.passes, st.cursor, st.cur = st.passes + 1, math.huge, nil
          Debug("nouveau tour (%s/%s)", tostring(num), tostring(total))
          if CheckInbox then lastCheckInbox = GetTime(); pcall(CheckInbox) end
          return schedule(2.0)
        end
        return finish()
      end

      local action
      if (target.money or 0) > 0 and not cur.moneyDone then
        cur.moneyDone = true
        P.TakeMoneyTracked(target, res)
        action = "or"
      elseif not opts.moneyOnly and not cur.returned then
        for a = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
          local link = SafeGetItemLink(target.index, a)
          if link and (cur.tries[a] or 0) < 3 then
            if PostBoxDB.autoReturnDNW and not opts.keys and P.IsDoNotWant(link) then
              cur.returned = true
              ReturnInboxItem(target.index)
              res.returned = res.returned + 1
              action = "retour"
            elseif P.GetFreeBagSlots() <= (PostBoxDB.reserveSlots or 0) then
              return finish("bagsfull")
            else
              cur.tries[a] = (cur.tries[a] or 0) + 1
              cur.pending[a] = { link = link, count = SafeGetItemCount(target.index, a) }
              TakeInboxItem(target.index, a)
              action = "emplacement " .. a
            end
            break
          end
        end
      end
      Debug("[%d] %s | action=%s", target.index, tostring(target.subject), tostring(action))
      if action then
        schedule(0.6)
      else
        for _ in pairs(cur.pending) do res.failed = res.failed + 1 end
        st.cursor, st.cur = cur.index, nil
        schedule(0.05)
      end
    end)
    if not ok then
      P.openAll.active = false
      if queueTimer then queueTimer:Cancel(); queueTimer = nil end
      print("|cFFFF5555PostBox|r : " .. tostring(err))
    end
  end
  step()
  return true
end

-- Objets revenus sans avoir ete vendus (expires ou annules). Aucune API ne
-- permet de les reposter depuis la boite : on les recupere en un clic.
function P.CollectUnsold()
  P.OpenAll({ categories = { expired = true, cancelled = true } })
end

-- Ramassage automatique de l'or des ventes HV a l'ouverture de la boite.
function P.AutoCollectSold()
  if not PostBoxDB.autoCollectSold or P.IsBusy() then return end
  local any = false
  for _, e in ipairs(P.cache) do
    if e.category == "sold" and (e.money or 0) > 0 and (e.cod or 0) == 0 then any = true; break end
  end
  if not any then return end
  P.OpenAll({
    categories = { sold = true }, moneyOnly = true, silent = true,
    onDone = function(res)
      if res.gold > 0 then print(string.format(L.MSG_AUTOCOLLECT_FMT, Coin(res.gold))) end
    end,
  })
end

-- ============================================================================
-- EXPRESS (sur une ligne) : Maj+clic = recuperer, Ctrl+clic = renvoyer,
-- clic droit = recuperer en acceptant le contre-remboursement (confirme).
-- ============================================================================
local function TakeOne(entry, allowCOD)
  if P.IsBusy() then print(L.MSG_BUSY) return end
  P.OpenAll({ keys = { [entry.key] = true }, silent = true, allowCOD = allowCOD })
end

function P.TakeWithCOD(entry)
  if (entry.cod or 0) <= 0 then return TakeOne(entry, false) end
  local threshold = PostBoxDB.codThreshold or 0
  if entry.cod >= threshold then
    P.Confirm(string.format(L.POPUP_COD_OPEN_TEXT, Coin(entry.cod)), function() TakeOne(entry, true) end)
  else
    TakeOne(entry, true)
  end
end

function P.ReturnMail(entry)
  if entry.wasReturned or entry.canReply == false then
    print(L.MSG_CANT_RETURN)
    return
  end
  ReturnInboxItem(entry.index)
  C_Timer.After(0.4, function() P.RefreshCache(true) end)
end

function P.ExpressClick(entry)
  if IsShiftKeyDown() then
    TakeOne(entry, false)
  elseif IsControlKeyDown() then
    P.ReturnMail(entry)
  end
end

-- ============================================================================
-- EXPIRATION ET TRI INTELLIGENT
-- ============================================================================
function P.IsExpiringSoon(entry)
  return entry.daysLeft and entry.daysLeft <= (PostBoxDB.expiryWarnDays or 1)
end

local CATEGORY_ORDER = { cancelled = 1, expired = 2, outbid = 3, sold = 4, won = 5, other = 6 }
function P.SmartSort(list)
  local out = {}
  for i, v in ipairs(list) do out[i] = v end
  table.sort(out, function(a, b)
    local ea, eb = P.IsExpiringSoon(a), P.IsExpiringSoon(b)
    if ea ~= eb then return ea end
    local ca, cb = CATEGORY_ORDER[a.category] or 9, CATEGORY_ORDER[b.category] or 9
    if ca ~= cb then return ca < cb end
    if a.sender ~= b.sender then return a.sender < b.sender end
    return a.index < b.index
  end)
  return out
end

-- ============================================================================
-- SELECTION
-- ============================================================================
P.selection = {}  -- [index] = true

function P.ProcessSelection()
  if P.IsBusy() then print(L.MSG_BUSY) return end
  local keys, n = {}, 0
  for _, entry in ipairs(P.cache) do
    if P.selection[entry.index] then keys[entry.key] = true; n = n + 1 end
  end
  wipe(P.selection)
  if n == 0 then return end
  P.OpenAll({ keys = keys })
end

-- ============================================================================
-- SUPPRESSION (multi-selection) : DeleteInboxItem, une a la fois, verifiee par
-- la baisse de GetInboxNumItems() (un refus serveur ne leve aucune erreur).
-- Ne supprime JAMAIS un courrier qui a encore de l'or ou un objet.
-- ============================================================================
local deleteTimeout

local function InboxCount()
  return (GetInboxNumItems and (GetInboxNumItems())) or 0
end

-- Pieces jointes reellement presentes (lecture directe, pas l'en-tete fige).
function P.LiveItemCount(e)
  if (e.hasItem or 0) <= 0 then return 0 end
  local n = 0
  for a = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
    if SafeGetItemLink(e.index, a) then n = n + 1 end
    if n >= e.hasItem then break end
  end
  return n
end

-- Un courrier est vide si plus aucune piece jointe n'est lisible et si son or
-- a ete pris pendant cette visite (l'en-tete, lui, garde l'ancien montant).
function P.IsMailEmpty(e)
  local goldLeft = (e.money or 0) > 0 and not P.sessionMoneyTaken[P.MailIdKey(e)]
  return not goldLeft and P.LiveItemCount(e) == 0
end

function P.DeleteSelected()
  if P.IsBusy() then print(L.MSG_BUSY) return end
  local keys, skipped = {}, 0
  for _, entry in ipairs(P.cache) do
    if P.selection[entry.index] then
      if P.IsMailEmpty(entry) then
        keys[#keys + 1] = entry.key
      else
        skipped = skipped + 1
      end
    end
  end
  wipe(P.selection)
  if #keys == 0 then
    if skipped > 0 then print(string.format(L.MSG_DELETE_RESULT_SKIPPED_FMT, 0, skipped)) end
    P.RefreshWindow()
    return
  end

  deleteQueue = { keys = keys, i = 0, deleted = 0, failed = 0, skipped = skipped, failures = {} }
  local step

  local function finish()
    local q = deleteQueue
    deleteQueue = nil
    if q.failed > 0 then
      print(string.format(L.MSG_DELETE_RESULT_FAILED_FMT, q.deleted, q.failed))
      for n, line in ipairs(q.failures) do
        if n > 3 then break end
        print(string.format(L.MSG_DELETE_FAIL_DETAIL_FMT, line))
      end
    elseif q.skipped > 0 then
      print(string.format(L.MSG_DELETE_RESULT_SKIPPED_FMT, q.deleted, q.skipped))
    else
      print(string.format(L.MSG_DELETE_RESULT_FMT, q.deleted))
    end
    P.RefreshCache(true)
  end

  local function nextStep()
    if deleteTimeout then deleteTimeout:Cancel() end
    deleteTimeout = C_Timer.NewTimer(0.3, step)
  end

  local function findTarget(key)
    for _, entry in ipairs(P.cache) do
      if entry.key == key then return entry end
    end
  end

  local function attempt(key, retried)
    P.RefreshCache(true)
    local target = findTarget(key)
    if not target then
      deleteQueue.deleted = deleteQueue.deleted + 1
      return nextStep()
    end
    local before = InboxCount()
    -- Le serveur refuse de supprimer un courrier a texte non "ouvert" :
    -- l'interface Blizzard appelle GetInboxText avant DeleteInboxItem.
    pcall(GetInboxText, target.index)
    local delFn = (C_Mail and C_Mail.DeleteInboxItem) or DeleteInboxItem
    local delOk, delErr = pcall(delFn, target.index)
    if not delOk then
      deleteQueue.failed = deleteQueue.failed + 1
      deleteQueue.failures[#deleteQueue.failures + 1] = string.format("%s - %s : %s",
        target.sender or "?", target.subject or "", tostring(delErr))
      return nextStep()
    end
    local tries = 0
    local function confirm()
      if not deleteQueue then return end
      if InboxCount() < before then
        deleteQueue.deleted = deleteQueue.deleted + 1
        return nextStep()
      end
      tries = tries + 1
      if tries < 8 then
        C_Timer.After(0.3, confirm)
      elseif not retried then
        attempt(key, true)
      else
        local canDelete = "?"
        if InboxItemCanDelete then
          local okc, can = pcall(InboxItemCanDelete, target.index)
          if okc then canDelete = tostring(can) end
        end
        deleteQueue.failed = deleteQueue.failed + 1
        deleteQueue.failures[#deleteQueue.failures + 1] = string.format(
          "%s - %s (InboxItemCanDelete=%s)", target.sender or "?", target.subject or "", canDelete)
        nextStep()
      end
    end
    C_Timer.After(0.3, confirm)
  end

  step = function()
    local q = deleteQueue
    q.i = q.i + 1
    if q.i > #q.keys then return finish() end
    local ok, err = pcall(attempt, q.keys[q.i], false)
    if not ok then
      q.failed = q.failed + 1
      q.failures[#q.failures + 1] = tostring(err)
      nextStep()
    end
  end
  step()
end

-- ============================================================================
-- RAKE : or ramasse sur la session (remis a zero a la main)
-- ============================================================================
function P.ResetRake() PostBoxDB.stats.rakeSession = 0 end
function P.GetRake() return PostBoxDB.stats.rakeSession or 0 end

-- ============================================================================
-- RECHERCHE GLOBALE (expediteur / sujet / objet) - requete deja normalisee
-- ============================================================================
function P.SearchProvider(query)
  local out = {}
  local UI = GetUI()
  for _, e in ipairs(P.cache) do
    local hay = (e.sender or "") .. " " .. (e.subject or "") .. " " .. (e.itemLink or "")
    if UI and UI.Match(hay, query) then
      out[#out + 1] = {
        text = string.format("%s - %s", e.sender or "?", e.subject or ""),
        onClick = function() if P.OpenWindow then P.OpenWindow() end; P.ShowMailPreview(e) end,
      }
    end
  end
  return out
end

-- ============================================================================
-- OUVERTURE / FERMETURE PUBLIQUE
-- ============================================================================
function PostBox_Toggle()
  if P.BuildUI then P.BuildUI() end
  local f = _G.PostBoxMainFrame
  if not f then return end
  if f:IsShown() then
    f:Hide(); PostBoxDB.open = false
  else
    f:Show(); PostBoxDB.open = true
    P.RefreshCache(false)
  end
end

function PostBox_OpenOptions()
  if P.BuildOptionsPanel then P.BuildOptionsPanel() end
  if _G.PostBoxOptions then _G.PostBoxOptions:Toggle() end
end

-- ============================================================================
-- FENETRE PRINCIPALE
-- Lignes habillees par textures (SetColorTexture) et non par backdrop : un
-- SetBackdropColor pose juste apres le premier Show perdait son alpha en jeu.
-- Les textes sont a largeur fixe sans retour a la ligne : WoW les termine
-- lui-meme par "...". L'ancienne troncature octet par octet coupait les
-- lettres accentuees en deux.
-- ============================================================================
local ROW_H = 30
local ROW_W = 656
local rows = {}

local function BuildRow(parent)
  local UI = GetUI()
  local r = CreateFrame("Button", nil, parent)
  r:SetSize(ROW_W, ROW_H)

  local bg = r:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  local panel = UI and UI.C.PANEL or { 0.055, 0.063, 0.082 }
  bg:SetColorTexture(panel[1] + 0.02, panel[2] + 0.02, panel[3] + 0.02, 0.92)
  r.bg = bg

  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.05)

  local sel = r:CreateTexture(nil, "ARTWORK")
  sel:SetPoint("TOPLEFT"); sel:SetPoint("BOTTOMLEFT")
  sel:SetWidth(3)
  sel:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
  sel:Hide()
  r.sel = sel

  local cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
  cb:SetSize(20, 20); cb:SetPoint("LEFT", 6, 0)
  r.cb = cb

  local expiry = r:CreateTexture(nil, "OVERLAY")
  expiry:SetSize(10, 10); expiry:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  expiry:SetColorTexture(0.90, 0.30, 0.20, 1)
  r.expiry = expiry

  local sender = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sender:SetPoint("LEFT", expiry, "RIGHT", 6, 0); sender:SetWidth(128); sender:SetJustifyH("LEFT")
  sender:SetWordWrap(false)
  r.sender = sender

  local subject = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  subject:SetPoint("LEFT", sender, "RIGHT", 6, 0); subject:SetWidth(188); subject:SetJustifyH("LEFT")
  subject:SetWordWrap(false)
  r.subject = subject

  local itemIcon = r:CreateTexture(nil, "OVERLAY")
  itemIcon:SetSize(20, 20)
  itemIcon:SetPoint("LEFT", subject, "RIGHT", 4, 0)
  itemIcon:SetTexture(134400)
  itemIcon:Hide()
  r.itemIcon = itemIcon

  local item = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  item:SetPoint("LEFT", itemIcon, "RIGHT", 4, 0); item:SetWidth(96); item:SetJustifyH("LEFT")
  item:SetWordWrap(false)
  r.item = item

  local money = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  money:SetPoint("LEFT", item, "RIGHT", 4, 0); money:SetWidth(84); money:SetJustifyH("LEFT")
  money:SetWordWrap(false)
  r.money = money

  local dnw = CreateFrame("Button", nil, r)
  dnw:SetSize(18, 18); dnw:SetPoint("RIGHT", -6, 0)
  local dnwTex = dnw:CreateTexture(nil, "OVERLAY"); dnwTex:SetAllPoints()
  dnwTex:SetTexture("Interface\\Buttons\\UI-GroupLoot-DE-Up")
  dnw:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_LEFT"); GameTooltip:SetText(L.DNW_TOOLTIP, nil, nil, nil, nil, true); GameTooltip:Show()
  end)
  dnw:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r.dnw = dnw

  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r:SetScript("OnClick", function(self, button)
    local e = self._entry
    if not e then return end
    if button == "RightButton" then
      if (e.money or 0) > 0 or (e.hasItem or 0) > 0 then P.TakeWithCOD(e) end
      return
    end
    if IsShiftKeyDown() or IsControlKeyDown() then
      P.ExpressClick(e)
    else
      P.ShowMailPreview(e)
    end
  end)
  r:SetScript("OnEnter", function(self)
    local e = self._entry
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if e.itemLink then GameTooltip:SetHyperlink(e.itemLink) else GameTooltip:SetText(e.subject or "") end
    if (e.cod or 0) > 0 then GameTooltip:AddLine(string.format(L.ROW_COD_FMT, Coin(e.cod)), 1, 0.4, 0.3) end
    GameTooltip:AddLine(L.ROW_HINT, 0.7, 0.7, 0.75, true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)

  cb:SetScript("OnClick", function(self)
    local e = r._entry
    if not e then return end
    P.selection[e.index] = self:GetChecked() and true or nil
  end)

  dnw:SetScript("OnClick", function()
    local e = r._entry
    if e and e.itemLink then
      P.SetDoNotWant(e.itemLink, not P.IsDoNotWant(e.itemLink))
      P.RefreshWindow()
    end
  end)

  return r
end

local function FormatRow(r, e)
  r._entry = e
  r.sender:SetText(e.sender or "")
  r.subject:SetText(e.subject or "")
  r.item:SetText(e.itemLink and (e.hasItem > 1 and (e.itemLink .. " (+" .. (e.hasItem - 1) .. ")") or e.itemLink) or "")
  if (e.cod or 0) > 0 then
    r.money:SetText("|cFFFF6650COD|r " .. Coin(e.cod))
  else
    r.money:SetText(e.money > 0 and Coin(e.money) or "")
  end
  if e.itemLink then
    local icon = (C_Item and C_Item.GetItemIconByID and ItemIDOf(e.itemLink) and C_Item.GetItemIconByID(ItemIDOf(e.itemLink)))
      or (GetItemIcon and GetItemIcon(e.itemLink))
    r.itemIcon:SetTexture(icon or 134400)
    r.itemIcon:Show()
  else
    r.itemIcon:Hide()
  end
  r.cb:SetChecked(P.selection[e.index] and true or false)
  r.expiry:SetShown(P.IsExpiringSoon(e))
  r.dnw:SetShown(e.itemLink ~= nil)
  r.dnw:SetAlpha((e.itemLink and P.IsDoNotWant(e.itemLink)) and 1 or 0.35)
  r.sel:SetShown(P.previewIndex ~= nil and e.index == P.previewIndex)
  r.sender:SetAlpha(e.wasRead and 0.75 or 1)
end

P.searchQuery = ""

function P.RefreshWindow()
  local f = _G.PostBoxMainFrame
  if not f or not f:IsShown() then return end
  local list = PostBoxDB.smartSort and P.SmartSort(P.cache) or P.cache
  if P.searchQuery ~= "" then
    local UI = GetUI()
    local filtered = {}
    for _, e in ipairs(list) do
      local hay = (e.sender or "") .. " " .. (e.subject or "") .. " " .. ((e.invoice and e.invoice.item) or "")
      if (UI and UI.Match(hay, P.searchQuery)) or (not UI and hay:lower():find(P.searchQuery, 1, true)) then
        filtered[#filtered + 1] = e
      end
    end
    list = filtered
  end
  local content = f.content
  local y = -4
  for i, e in ipairs(list) do
    local r = rows[i]
    if not r then r = BuildRow(content); rows[i] = r end
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
    FormatRow(r, e)
    r:Show()
    y = y - ROW_H - 1
  end
  for i = #list + 1, #rows do rows[i]:Hide() end
  content:SetHeight(math.max(-y + 4, 10))
  f.empty:SetShown(#list == 0)

  if f.countText then
    local _, total = GetInboxNumItems()
    local extra = ((total or 0) > #P.cache) and string.format(L.WINDOW_MORE_FMT, total - #P.cache) or ""
    f.countText:SetText(string.format(L.WINDOW_COUNT_FMT, #P.cache, Coin(P.GetRake())) .. extra)
  end
  P.currentList = list
end

-- ============================================================================
-- BADGE (courriers NON LUS, boite ouverte seulement ; boite fermee, c'est la
-- pastille "!" du core, basee sur HasNewMail(), qui prend le relais)
-- ============================================================================
P.mailboxOpen = false
function P.SetMailboxOpen(open)
  if open and not P.mailboxOpen then wipe(P.sessionMoneyTaken) end
  P.mailboxOpen = open and true or false
  if P.UpdateBadges then P.UpdateBadges() end
end

function P.UpdateBadges()
  local n = 0
  if P.mailboxOpen then
    for _, e in ipairs(P.cache) do
      if not e.wasRead then n = n + 1 end
    end
  end
  if _G.TibiSuite then
    if TibiSuite.SetTabBadge then TibiSuite.SetTabBadge("Post", n) end
    if TibiSuite.RefreshStatus then TibiSuite.RefreshStatus() end
    if TibiSuite.SetMinimapBadge then TibiSuite.SetMinimapBadge(n) end
  end
  local mm = _G.PostBoxMinimapBtn
  if mm and mm.badge then
    if n > 0 then
      mm.badge.text:SetText(n > 99 and "99+" or tostring(n))
      mm.badge:Show()
    else
      mm.badge:Hide()
    end
  end
end

-- ============================================================================
-- APERCU DU CONTENU D'UN COURRIER (volet de droite)
-- CheckInboxItem(index) demande le texte, GetInboxText(index) le lit ; on
-- reessaie quelques fois (8 x 0,25 s) avant d'afficher "indisponible".
-- ============================================================================
local previewRetryTimer
P.previewIndex = nil

local function HighlightPreviewRow()
  for _, r in ipairs(rows) do
    if r:IsShown() and r._entry then
      r.sel:SetShown(P.previewIndex ~= nil and r._entry.index == P.previewIndex)
    end
  end
end

local function InvoiceText(inv)
  if not inv then return nil end
  if inv.type == "seller" then
    return string.format(L.INVOICE_SOLD_FMT, inv.item or "?", inv.count or 1, inv.player or "?",
      Coin(inv.bid), Coin(inv.cut), Coin(inv.deposit), Coin((inv.bid or 0) + (inv.deposit or 0) - (inv.cut or 0)))
  elseif inv.type == "buyer" then
    return string.format(L.INVOICE_BOUGHT_FMT, inv.item or "?", inv.count or 1, inv.player or "?", Coin(inv.bid))
  elseif inv.type == "seller_temp_invoice" then
    return string.format(L.INVOICE_PENDING_FMT, inv.item or "?", Coin(inv.bid))
  end
end

function P.ShowMailPreview(entry)
  if not entry then return end
  local f = _G.PostBoxMainFrame
  if not f or not f.preview then return end
  local pv = f.preview

  P.previewIndex = entry.index
  P.previewEntry = entry
  HighlightPreviewRow()

  pv.senderText:SetText(AccentText(entry.sender or "?"))
  pv.subjectText:SetText(entry.subject or "")
  pv.bodyText:SetText(L.PREVIEW_LOADING)
  pv.bodyContent:SetHeight(10)
  pv.placeholder:Hide()
  pv.readingPane:Show()
  pv.fwdBtn:SetShown((entry.money or 0) > 0 or (entry.hasItem or 0) > 0)

  if previewRetryTimer then previewRetryTimer:Cancel(); previewRetryTimer = nil end
  pcall(CheckInboxItem, entry.index)

  local inv = InvoiceText(entry.invoice)
  local attempts = 0
  local function tryFetch()
    attempts = attempts + 1
    local ok, text = pcall(GetInboxText, entry.index)
    local body
    if ok and text and text ~= "" then body = text end
    if body or inv or attempts >= 8 then
      local parts = {}
      if inv then parts[#parts + 1] = inv end
      parts[#parts + 1] = body or (inv and "" or L.PREVIEW_UNAVAILABLE)
      pv.bodyText:SetText(table.concat(parts, "\n\n"))
      pv.bodyContent:SetHeight(math.max(pv.bodyText:GetStringHeight() or 10, 10))
      if body or attempts >= 8 then return end
    end
    previewRetryTimer = C_Timer.NewTimer(0.25, tryFetch)
  end
  tryFetch()
end

function P.PreviewStep(delta)
  local list = P.currentList
  if not list or #list == 0 then return end
  local idx
  if not P.previewIndex then
    idx = (delta > 0) and 1 or #list
  else
    for i, e in ipairs(list) do
      if e.index == P.previewIndex then idx = i; break end
    end
    idx = (idx or 1) + delta
  end
  if idx < 1 then idx = 1 elseif idx > #list then idx = #list end
  P.ShowMailPreview(list[idx])
end

local function Btn(parent, w, label, onClick, tip)
  local UI = GetUI()
  local b = UI and UI.MakeButton(parent, w, 24, label) or CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  if not UI then b:SetSize(w, 24); b:SetText(label) end
  b:SetScript("OnClick", onClick)
  if tip then
    b:HookScript("OnEnter", function(s)
      GameTooltip:SetOwner(s, "ANCHOR_BOTTOM"); GameTooltip:SetText(tip, nil, nil, nil, nil, true); GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return b
end
P.Btn = Btn

function P.BuildUI()
  if _G.PostBoxMainFrame then return end
  local UI = GetUI()
  local LIST_W, PREVIEW_W, FRAME_H = 700, 420, 520
  local FRAME_W = LIST_W + PREVIEW_W

  local f = CreateFrame("Frame", "PostBoxMainFrame", UIParent, "BackdropTemplate")
  f:SetSize(FRAME_W, FRAME_H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetMovable(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  if UI then UI.SkinFrame(f, ACCENT, UI.C.BG) end

  -- Echap via UISpecialFrames seulement. AUCUN EnableKeyboard/OnKeyDown sur
  -- cette fenetre : confirme en jeu, un simple OnKeyDown actif contaminait
  -- l'appel protege de Blizzard declenche par Echap (ADDON_ACTION_FORBIDDEN).
  tinsert(UISpecialFrames, "PostBoxMainFrame")

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -12)
  title:SetText(AccentText("PostBox"))

  local listPane = CreateFrame("Frame", nil, f)
  listPane:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  listPane:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  listPane:SetWidth(LIST_W)
  f.listPane = listPane

  -- Rangee 1 : actions sur le courrier
  local openAllBtn = Btn(listPane, 104, L.BTN_OPENALL, function() P.OpenAll() end, L.TIP_OPENALL)
  openAllBtn:SetPoint("TOPRIGHT", -12, -10)
  local selBtn = Btn(listPane, 112, L.BTN_PROCESS_SELECTION, function() P.ProcessSelection() end, L.TIP_PROCESS)
  selBtn:SetPoint("RIGHT", openAllBtn, "LEFT", -6, 0)
  local delBtn = Btn(listPane, 90, L.BTN_DELETE_SELECTION, function() P.DeleteSelected() end, L.TIP_DELETE)
  delBtn:SetPoint("RIGHT", selBtn, "LEFT", -6, 0)
  local unsoldBtn = Btn(listPane, 124, L.BTN_COLLECT_UNSOLD, function() P.CollectUnsold() end, L.TIP_UNSOLD)
  unsoldBtn:SetPoint("RIGHT", delBtn, "LEFT", -6, 0)
  local refreshBtn = Btn(listPane, 86, L.BTN_REFRESH, function()
    P.RefreshCache(true)
    C_Timer.After(0.4, function() P.RefreshCache(false) end)
    C_Timer.After(1.0, function() P.RefreshCache(false) end)
  end)
  refreshBtn:SetPoint("RIGHT", unsoldBtn, "LEFT", -6, 0)

  -- Rangee 2 : outils (carnet, mule, persos, journal, stats)
  local statsBtn = Btn(listPane, 70, L.BTN_STATS, function() if P.Stats and P.Stats.Toggle then P.Stats.Toggle() end end)
  statsBtn:SetPoint("TOPRIGHT", openAllBtn, "BOTTOMRIGHT", 0, -6)
  local ledgerBtn = Btn(listPane, 96, L.BTN_LEDGER, function() if P.Ledger and P.Ledger.Toggle then P.Ledger.Toggle() end end, L.TIP_LEDGER)
  ledgerBtn:SetPoint("RIGHT", statsBtn, "LEFT", -6, 0)
  local altsBtn = Btn(listPane, 96, L.BTN_ALTS, function() if P.Alts and P.Alts.Toggle then P.Alts.Toggle() end end, L.TIP_ALTS)
  altsBtn:SetPoint("RIGHT", ledgerBtn, "LEFT", -6, 0)
  local muleBtn = Btn(listPane, 70, L.BTN_MULE, function() if P.Mule and P.Mule.Toggle then P.Mule.Toggle() end end, L.TIP_MULE)
  muleBtn:SetPoint("RIGHT", altsBtn, "LEFT", -6, 0)
  local bbBtn = Btn(listPane, 80, L.BTN_BLACKBOOK, function() if P.BlackBook and P.BlackBook.Toggle then P.BlackBook.Toggle() end end, L.TIP_BLACKBOOK)
  bbBtn:SetPoint("RIGHT", muleBtn, "LEFT", -6, 0)

  local countText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  countText:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -72)
  f.countText = countText

  -- Filtres HV
  local filterY = -94
  local filterLabels = {
    { key = "cancelled", label = L.FILTER_CANCELLED }, { key = "expired", label = L.FILTER_EXPIRED },
    { key = "outbid", label = L.FILTER_OUTBID }, { key = "sold", label = L.FILTER_SOLD },
    { key = "won", label = L.FILTER_WON }, { key = "other", label = L.FILTER_OTHER },
  }
  local fx = 12
  for _, fl in ipairs(filterLabels) do
    local cb = CreateFrame("CheckButton", nil, listPane, "UICheckButtonTemplate")
    cb:SetSize(18, 18)
    cb:SetPoint("TOPLEFT", listPane, "TOPLEFT", fx, filterY)
    cb:SetChecked(PostBoxDB.filters[fl.key] ~= false)
    cb:SetScript("OnClick", function(s) PostBoxDB.filters[fl.key] = s:GetChecked() and true or false end)
    local t = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", cb, "RIGHT", 2, 0); t:SetText(fl.label)
    fx = fx + 18 + t:GetStringWidth() + 12
  end

  local searchBox = CreateFrame("EditBox", nil, listPane, "SearchBoxTemplate")
  searchBox:SetSize(180, 20)
  searchBox:SetPoint("TOPRIGHT", listPane, "TOPRIGHT", -14, filterY - 26)
  searchBox:SetScript("OnTextChanged", function(self)
    SearchBoxTemplate_OnTextChanged(self)
    P.searchQuery = Norm(self:GetText() or "")
    P.RefreshWindow()
  end)
  f.searchBox = searchBox

  local hint = listPane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", listPane, "TOPLEFT", 14, filterY - 30)
  hint:SetText(L.LIST_HINT)

  local hdrSender = listPane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hdrSender:SetPoint("TOPLEFT", listPane, "TOPLEFT", 56, filterY - 52)
  hdrSender:SetText(L.COL_SENDER)
  local hdrItem = listPane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hdrItem:SetPoint("TOPLEFT", listPane, "TOPLEFT", 382, filterY - 52)
  hdrItem:SetText(L.COL_ITEM)

  local scroll = CreateFrame("ScrollFrame", nil, listPane, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, filterY - 68)
  scroll:SetPoint("BOTTOMRIGHT", -28, 12)
  if UI and UI.SkinScrollBar then UI.SkinScrollBar(scroll, ACCENT) end
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(LIST_W - 40, 10)
  scroll:SetScrollChild(content)
  f.content = content

  local empty = listPane:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  empty:SetPoint("CENTER", scroll, "CENTER", 0, 0)
  empty:SetText(L.LIST_EMPTY)
  empty:Hide()
  f.empty = empty

  -- Volet apercu (droite)
  local pv = CreateFrame("Frame", nil, f, "BackdropTemplate")
  pv:SetPoint("TOPLEFT", listPane, "TOPRIGHT", 6, -6)
  pv:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
  if UI then UI.SkinFrame(pv, ACCENT, UI.C.PANEL) end
  f.preview = pv

  local placeholder = pv:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  placeholder:SetPoint("CENTER", 0, 0)
  placeholder:SetWidth(PREVIEW_W - 40)
  placeholder:SetJustifyH("CENTER"); placeholder:SetJustifyV("MIDDLE")
  placeholder:SetText(L.PREVIEW_PLACEHOLDER)
  pv.placeholder = placeholder

  local readingPane = CreateFrame("Frame", nil, pv)
  readingPane:SetAllPoints()
  pv.readingPane = readingPane
  readingPane:Hide()

  local senderText = readingPane:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  senderText:SetPoint("TOPLEFT", 14, -14)
  senderText:SetPoint("TOPRIGHT", -14, -14)
  senderText:SetJustifyH("LEFT")
  pv.senderText = senderText

  local subjectText = readingPane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  subjectText:SetPoint("TOPLEFT", senderText, "BOTTOMLEFT", 0, -6)
  subjectText:SetPoint("TOPRIGHT", senderText, "BOTTOMRIGHT", 0, -6)
  subjectText:SetJustifyH("LEFT")
  pv.subjectText = subjectText

  local sep = readingPane:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(1, 1, 1, 0.12)
  sep:SetHeight(1)
  sep:SetPoint("TOPLEFT", subjectText, "BOTTOMLEFT", -4, -10)
  sep:SetPoint("TOPRIGHT", subjectText, "BOTTOMRIGHT", 4, -10)

  local prevBtn = Btn(readingPane, 96, L.PREVIEW_PREV, function() P.PreviewStep(-1) end)
  prevBtn:SetPoint("BOTTOMLEFT", readingPane, "BOTTOMLEFT", 14, 8)
  local nextBtn = Btn(readingPane, 96, L.PREVIEW_NEXT, function() P.PreviewStep(1) end)
  nextBtn:SetPoint("BOTTOMRIGHT", readingPane, "BOTTOMRIGHT", -14, 8)
  local fwdBtn = Btn(readingPane, 110, L.BTN_FORWARD, function()
    local e = P.previewEntry
    if e and P.BlackBook and P.BlackBook.ForwardPrompt then P.BlackBook.ForwardPrompt(e) end
  end, L.TIP_FORWARD)
  fwdBtn:SetPoint("BOTTOM", readingPane, "BOTTOM", 0, 8)
  pv.fwdBtn = fwdBtn

  local pvScroll = CreateFrame("ScrollFrame", nil, readingPane, "UIPanelScrollFrameTemplate")
  pvScroll:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 4, -10)
  pvScroll:SetPoint("BOTTOMRIGHT", readingPane, "BOTTOMRIGHT", -26, 40)
  if UI and UI.SkinScrollBar then UI.SkinScrollBar(pvScroll, ACCENT) end
  local pvContent = CreateFrame("Frame", nil, pvScroll)
  pvContent:SetSize(PREVIEW_W - 56, 10)
  pvScroll:SetScrollChild(pvContent)

  local bodyText = pvContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bodyText:SetPoint("TOPLEFT", 0, 0)
  bodyText:SetWidth(PREVIEW_W - 56)
  bodyText:SetJustifyH("LEFT"); bodyText:SetJustifyV("TOP")
  bodyText:SetSpacing(3)
  pv.bodyText = bodyText
  pv.bodyContent = pvContent

  if UI then
    UI.AddHeaderControls(f, {
      accent = ACCENT,
      onOptions = function() PostBox_OpenOptions() end,
      provider = P.SearchProvider,
    })
  end

  f:SetScript("OnShow", function() P.RefreshCache(false) end)
  f:Hide()
end

function P.OpenWindow()
  P.BuildUI()
  if _G.PostBoxMainFrame and not _G.PostBoxMainFrame:IsShown() then PostBox_Toggle() end
end

-- ============================================================================
-- RECAP ANIME (fin d'un "Tout ouvrir") : butin + or, revele ligne par ligne.
-- ============================================================================
function P.ShowRecapPopup(result)
  local UI = GetUI()
  local f = _G.PostBoxRecapFrame
  if not f then
    f = CreateFrame("Frame", "PostBoxRecapFrame", UIParent, "BackdropTemplate")
    f:SetSize(320, 360)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    if UI then UI.SkinFrame(f, ACCENT, UI.C.PANEL) end
    f:EnableMouse(true); f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "PostBoxRecapFrame")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide() end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText(AccentText(L.RECAP_TITLE))

    local goldText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    goldText:SetPoint("TOP", title, "BOTTOM", 0, -8)
    f.goldText = goldText

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -60)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    if UI and UI.SkinScrollBar then UI.SkinScrollBar(scroll, ACCENT) end
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(260, 10)
    scroll:SetScrollChild(content)
    f.content = content
    f.lines = {}
  end

  for _, l in ipairs(f.lines) do l:Hide() end
  f.goldText:SetText(result.gold > 0 and string.format(L.RECAP_GOLD_FMT, Coin(result.gold)) or L.RECAP_NO_GOLD)

  local items = {}
  for _, entry in pairs(result.loot) do items[#items + 1] = entry end
  table.sort(items, function(a, b) return a.link < b.link end)

  local y = -4
  local function revealLine(i)
    if i > #items then return end
    local entry = items[i]
    local l = f.lines[i]
    if not l then
      l = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      l:SetWidth(250); l:SetJustifyH("LEFT")
      f.lines[i] = l
    end
    l:ClearAllPoints(); l:SetPoint("TOPLEFT", f.content, "TOPLEFT", 4, y)
    l:SetText(string.format("%s x%d", entry.link, entry.count))
    l:SetAlpha(0); l:Show()
    UIFrameFadeIn(l, 0.25, 0, 1)
    y = y - 18
    f.content:SetHeight(math.max(-y + 4, 10))
    C_Timer.After(0.08, function() revealLine(i + 1) end)
  end
  revealLine(1)
  f:Show()
end

-- ============================================================================
-- GESTION DE LA LISTE "NE VEUT PAS" (objets retournes automatiquement)
-- ============================================================================
function P.RefreshDNWWindow()
  local f = _G.PostBoxDNWFrame
  if not f or not f:IsShown() then return end
  local UI = GetUI()
  local ids = {}
  for id in pairs(PostBoxDB.doNotWant) do ids[#ids + 1] = id end
  table.sort(ids)
  local y = -4
  for i, id in ipairs(ids) do
    local r = f.rows[i]
    if not r then
      r = CreateFrame("Frame", nil, f.content)
      r:SetSize(300, 22)
      r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", 2, 0)
      r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0); r.text:SetWidth(200); r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
      r.del = UI and UI.MakeButton(r, 70, 18, L.DNW_REMOVE) or CreateFrame("Button", nil, r)
      r.del:SetPoint("RIGHT", -2, 0)
      f.rows[i] = r
    end
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, y)
    local name, link, _, _, _, _, _, _, _, icon = (C_Item and C_Item.GetItemInfo or GetItemInfo)(id)
    r.icon:SetTexture(icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or 134400)
    r.text:SetText(link or name or ("item:" .. id))
    r.del:SetScript("OnClick", function() PostBoxDB.doNotWant[id] = nil; P.RefreshDNWWindow(); P.RefreshWindow() end)
    r:Show()
    y = y - 24
  end
  for i = #ids + 1, #f.rows do f.rows[i]:Hide() end
  f.content:SetHeight(math.max(-y + 4, 10))
  f.empty:SetShown(#ids == 0)
end

function P.ToggleDNWWindow()
  local f = _G.PostBoxDNWFrame
  if not f then
    local UI = GetUI()
    f = CreateFrame("Frame", "PostBoxDNWFrame", UIParent, "BackdropTemplate")
    f:SetSize(340, 360)
    f:SetPoint("CENTER", 60, 0)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true); f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if UI then UI.SkinFrame(f, ACCENT, UI.C.PANEL) end
    tinsert(UISpecialFrames, "PostBoxDNWFrame")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10); title:SetText(AccentText(L.DNW_TITLE))
    local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOP", title, "BOTTOM", 0, -6); note:SetWidth(300); note:SetText(L.DNW_NOTE)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -70); scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    if UI and UI.SkinScrollBar then UI.SkinScrollBar(scroll, ACCENT) end
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(300, 10); scroll:SetScrollChild(content)
    f.content, f.rows = content, {}
    local empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("CENTER"); empty:SetText(L.DNW_EMPTY)
    f.empty = empty
    f:Hide()
  end
  if f:IsShown() then f:Hide() else f:Show(); P.RefreshDNWWindow() end
end

-- ============================================================================
-- PANNEAU D'OPTIONS
-- ============================================================================
function P.BuildOptionsPanel()
  if _G.PostBoxOptions then return end
  local UI = GetUI()
  if not UI then return end

  local panel = UI.CreateOptionsPanel({
    name = "PostBoxOptionsFrame", title = L.OPT_TITLE, accent = ACCENT,
  })

  panel:Section(L.OPT_SEC_OPENALL)
  panel:Slider(L.OPT_RESERVE_SLOTS, 0, 20, 1,
    function() return PostBoxDB.reserveSlots end,
    function(v) PostBoxDB.reserveSlots = v end)
  panel:Check(L.OPT_AUTORETURN_DNW,
    function() return PostBoxDB.autoReturnDNW end,
    function(v) PostBoxDB.autoReturnDNW = v end)
  panel:Button(L.OPT_MANAGE_DNW, function() P.ToggleDNWWindow() end)
  panel:Check(L.OPT_AUTOCOLLECT,
    function() return PostBoxDB.autoCollectSold end,
    function(v) PostBoxDB.autoCollectSold = v end, L.OPT_AUTOCOLLECT_TIP)

  panel:Section(L.OPT_SEC_SECURITY)
  panel:Slider(L.OPT_COD_THRESHOLD, 0, 5000, 50,
    function() return math.floor((PostBoxDB.codThreshold or 0) / 10000) end,
    function(v) PostBoxDB.codThreshold = v * 10000 end)
  panel:Note(L.OPT_COD_NOTE)
  panel:Slider(L.OPT_EXPIRY_DAYS, 1, 5, 1,
    function() return PostBoxDB.expiryWarnDays end,
    function(v) PostBoxDB.expiryWarnDays = v; P.RefreshWindow() end)
  panel:Check(L.OPT_TRADEBLOCK,
    function() return PostBoxDB.tradeBlock end,
    function(v) PostBoxDB.tradeBlock = v end, L.OPT_TRADEBLOCK_TIP)

  panel:Section(L.OPT_SEC_ALTS)
  panel:Check(L.OPT_ALT_ALERT,
    function() return PostBoxDB.altAlert end,
    function(v) PostBoxDB.altAlert = v end)
  panel:Slider(L.OPT_ALT_ALERT_DAYS, 1, 7, 1,
    function() return PostBoxDB.altAlertDays or 3 end,
    function(v) PostBoxDB.altAlertDays = v end)

  panel:Section(L.OPT_SEC_MULE)
  panel:Check(L.OPT_MULE_AUTOSEND,
    function() return PostBoxDB.mule.autoSend ~= false end,
    function(v) PostBoxDB.mule.autoSend = v end, L.OPT_MULE_AUTOSEND_TIP)

  panel:Section(L.OPT_SEC_DISPLAY)
  panel:Check(L.OPT_SMART_SORT,
    function() return PostBoxDB.smartSort end,
    function(v) PostBoxDB.smartSort = v; P.RefreshWindow() end)

  panel:Section(L.OPT_SEC_MAILBOX)
  panel:Check(L.OPT_REPLACE_MAILBOX,
    function() return PostBoxDB.replaceNativeMailbox end,
    function(v) PostBoxDB.replaceNativeMailbox = v; if not v and P.SetNativeMailVisible then P.SetNativeMailVisible(true) end end)
  panel:Note(L.OPT_REPLACE_MAILBOX_NOTE)

  panel:Section(L.OPT_SEC_SESSION)
  panel:Note(L.OPT_SESSION_NOTE)
  panel:Button(L.OPT_RESET_RAKE, function() P.ResetRake(); P.RefreshWindow() end)

  if _G.TibiSuite and _G.TibiSuite.SetCtrlHidden then
    panel:Section(L.OPT_SEC_SUITE)
    panel:Check(L.OPT_HIDE_OPTS,
      function() return TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("PostBoxMainFrame", "options") end,
      function(v) TibiSuite.SetCtrlHidden("PostBoxMainFrame", "options", v) end)
    panel:Check(L.OPT_HIDE_SEARCH,
      function() return TibiSuite.IsCtrlHidden and TibiSuite.IsCtrlHidden("PostBoxMainFrame", "search") end,
      function(v) TibiSuite.SetCtrlHidden("PostBoxMainFrame", "search", v) end)
    panel:Note(L.OPT_FLOAT_NOTE)
  end

  _G.PostBoxOptions = panel
end
