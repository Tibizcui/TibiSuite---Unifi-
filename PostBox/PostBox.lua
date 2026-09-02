--[[============================================================================
  PostBox - Gestion avancee de la boite aux lettres (reecriture native, style
  TibiSuite, inspiree du cahier des charges de l'addon Postal).
  Auteur : Tibiscui - Kirin Tor
  SavedVariables : PostBoxDB (identique en mode module et en mode standalone).

  API de courrier utilisees (toutes des fonctions globales confirmees a jour,
  AUCUNE n'a ete deplacee dans le namespace C_Mail a ce jour) :
    CheckInbox(), GetInboxNumItems(), GetInboxHeaderInfo(index),
    GetInboxItemLink(index, attachIndex), TakeInboxItem(index, attachIndex),
    TakeInboxMoney(index), ReturnInboxItem(index), SendMail(recipient, subject, body),
    ClickSendMailItemButton(itemIndex, clearItem), DeleteInboxItem(index).
  Le namespace C_Mail ne contient que des fonctions de capacite recentes
  (CanCheckInbox, CanSendMail...), pas les fonctions de lecture/prise citees
  ci-dessus : elles restent globales.
============================================================================]]

PostBox = PostBox or {}
local P = PostBox
local ADDON_NAME = "PostBox"
P.ACCENT = { 0.72, 0.47, 0.22 }  -- laiton / cachet de cire

local ACCENT = P.ACCENT
local L = P.L  -- table de localisation (PostBox_Locale.lua, charge avant ce fichier)

-- ============================================================================
-- FRAME RACINE DE LA BOITE AUX LETTRES BLIZZARD
-- ----------------------------------------------------------------
-- Confirme en jeu (21/08/2026) : le conteneur principal ne s'appelle PLUS
-- "MailFrame" mais "ConsortiumMailFrame" (renomme par Blizzard, probablement
-- pour le contenu du patch en cours - "MailFrame" existe toujours en global
-- mais reste cache/inutilise). Tous les widgets internes (SendMailNameEditBox,
-- SendMailAttachment*, MailItem1-7, MailFrameTab1/2, etc.) gardent en
-- revanche leurs noms historiques inchanges.
-- METHODE ROBUSTE : plutot que de deviner/lister les noms possibles du
-- conteneur (qui peut etre renomme a nouveau), on le deduit du parent de
-- "MailFrameTab1" (confirme stable) - correct quel que soit le nom du
-- conteneur, aujourd'hui ou dans un futur patch. Repli sur les noms connus
-- si ce widget venait lui aussi a disparaitre.
-- ============================================================================
function P.GetMailFrame()
  if _G.MailFrameTab1 and _G.MailFrameTab1.GetParent then
    local parent = _G.MailFrameTab1:GetParent()
    if parent then return parent end
  end
  return _G.ConsortiumMailFrame or _G.MailFrame
end

-- ============================================================================
-- CORRECTIF : ne PAS masquer P.GetMailFrame() en entier pour le remplacement
-- de boite aux lettres - ce conteneur porte AUSSI l'onglet "Envoyer un
-- message" (SendMailFrame), que PostBox ne remplace pas et dont l'utilisateur
-- a toujours besoin (aucune API publique ne permet de joindre or/objets
-- autrement, voir PostBox_BlackBook.lua). Masquer tout le conteneur bloquait
-- donc completement l'envoi de courrier des que le remplacement etait actif.
-- On cible desormais uniquement InboxFrame, le sous-cadre specifique a
-- l'onglet Reception (fond, liste MailItem1-7, bouton "Tout ouvrir",
-- pagination) - confirme present et distinct de SendMailFrame via le scan
-- de _G effectue precedemment en jeu. Les onglets, le titre et le bouton
-- fermer du conteneur restent inchanges et fonctionnels.
-- ============================================================================
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
  codThreshold   = 0,      -- 0 = jamais de confirmation ; sinon confirme au-dela de ce montant (cuivre)
  autoReturnDNW  = true,   -- DoNotWant : retourner automatiquement au lieu de ramasser
  expiryWarnDays = 1,      -- indicateur d'expiration en-deca de N jours
  filters = {
    cancelled = true, expired = true, outbid = true, sold = true, won = true, other = true,
  },
  doNotWant  = {},   -- [itemID] = true
  recentRecipients = {},  -- { "Nom-Royaume", ... } (20 max, plus recent en tete)
  blackBook  = { contacts = {}, presets = {} },
  knownChars = {},   -- ["Nom-Royaume"] = { faction=, class=, lastSeen= }
  stats = {
    goldReceived = 0, goldSent = 0, auctionSold = 0, auctionBought = 0,
    senders = {}, rakeSession = 0, history = {},
  },
  floatHidden = {},
  minimapAngle = 200,
  minimapHide  = false,
  open = false,
  smartSort = true,
  replaceNativeMailbox = false,  -- masque (SetAlpha, jamais Show/Hide) l'inventaire natif sur MAIL_SHOW
}

function P.InitDB()
  PostBoxDB = PostBoxDB or {}
  for k, v in pairs(DEFAULTS) do
    if PostBoxDB[k] == nil then PostBoxDB[k] = DeepCopy(v) end
  end
  -- Comble les sous-champs manquants de "stats" meme si la table existe deja
  -- (sauvegarde d'une version anterieure a l'ajout d'un champ) : la fusion
  -- ci-dessus est superficielle (une SavedVariables existante avec juste
  -- "stats={}" bloque tout, PostBoxDB.stats n'etant plus nil). Confirme en
  -- jeu : PostBoxDB.stats.senders manquant faisait planter TopSenders()
  -- (pairs sur nil), empechant le tableau de bord Stats de s'ouvrir.
  for k, v in pairs(DEFAULTS.stats) do
    if PostBoxDB.stats[k] == nil then PostBoxDB.stats[k] = DeepCopy(v) end
  end
  -- Enregistre le personnage courant (pour les alts du BlackBook).
  local name = UnitName("player")
  local realm = GetRealmName()
  if name and realm then
    local key = name .. "-" .. realm
    PostBoxDB.knownChars[key] = {
      faction = UnitFactionGroup("player"),
      class   = select(2, UnitClass("player")),
      lastSeen = time(),
    }
  end
end

-- ============================================================================
-- CLASSIFICATION D'UN COURRIER (pour filtres + tri intelligent)
-- ============================================================================
-- Retourne une categorie parmi : cancelled, expired, outbid, sold, won, other
-- Mots-cles fournis par PostBox_Locale.lua selon la langue du CLIENT DE JEU
-- (GetLocale()), puisque les libelles expediteur/sujet sont envoyes par le
-- serveur dans cette langue-la (independamment de la langue choisie pour
-- l'interface de PostBox elle-meme).
local function MatchesAny(haystack, keywords)
  for _, kw in ipairs(keywords) do
    if haystack:find(kw, 1, true) then return true end
  end
  return false
end

function P.ClassifyMail(sender, subject)
  local kw = P.AH_KEYWORDS
  local s = _G.TibiMidnight and _G.TibiMidnight.Normalize(sender or "") or tostring(sender or ""):lower()
  if not MatchesAny(s, kw.sender) then
    return "other"
  end
  local subj = _G.TibiMidnight and _G.TibiMidnight.Normalize(subject or "") or tostring(subject or ""):lower()
  if MatchesAny(subj, kw.cancelled) then return "cancelled" end
  if MatchesAny(subj, kw.expired) then return "expired" end
  if MatchesAny(subj, kw.outbid) then return "outbid" end
  if MatchesAny(subj, kw.sold) then return "sold" end
  if MatchesAny(subj, kw.won) then return "won" end
  return "other"
end

-- ============================================================================
-- CACHE DE LA BOITE DE RECEPTION (rafraichi a chaque CheckInbox / MAIL_INBOX_UPDATE)
-- ============================================================================
P.cache = {}  -- tableau ordonne d'entrees { index, sender, subject, money, cod, daysLeft, hasItem, itemLink, category }

local function SafeGetItemLink(index, attachIndex)
  -- GetInboxItemLink existe de longue date pour recuperer le lien exact de l'objet joint.
  local ok, link = pcall(GetInboxItemLink, index, attachIndex or 1)
  if ok then return link end
  return nil
end

local lastCheckInbox = 0
function P.RefreshCache()
  -- CORRECTIF : confirme en jeu que supprimer un courrier via l'interface
  -- native Blizzard met a jour l'affichage NATIF instantanement, mais pas la
  -- valeur que renvoie GetInboxNumItems() pour les autres addons - meme
  -- apres un MAIL_SHOW tout frais (sortie de portee + retour). CheckInbox()
  -- force explicitement cette resynchronisation. Reste asynchrone (voir la
  -- note sur le bouton Actualiser) : cet appel "reveille" le processus, la
  -- vraie mise a jour arrive via MAIL_INBOX_UPDATE (deja ecoute plus bas dans
  -- ce fichier, qui rappelle cette meme fonction) - ce qui rappellerait donc
  -- CheckInbox() en boucle sans la limite ci-dessous (au mieux du gaspillage
  -- de requetes, au pire une boucle si CheckInbox() redeclenche toujours
  -- MAIL_INBOX_UPDATE meme sans changement reel).
  if CheckInbox and (GetTime() - lastCheckInbox) > 2 then
    lastCheckInbox = GetTime()
    pcall(CheckInbox)
  end
  wipe(P.cache)
  local numItems = GetInboxNumItems() or 0
  for i = 1, numItems do
    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft,
      hasItem, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(i)
    if sender then
      local cat = P.ClassifyMail(sender, subject)
      P.cache[#P.cache + 1] = {
        index = i, sender = sender, subject = subject or "",
        money = money or 0, cod = CODAmount or 0, daysLeft = daysLeft or 0,
        hasItem = hasItem or 0, wasRead = wasRead, category = cat,
        itemLink = (hasItem and hasItem > 0) and SafeGetItemLink(i, 1) or nil,
      }
    end
  end
  if P.RefreshWindow then P.RefreshWindow() end
  if P.TryHookSendMail then P.TryHookSendMail() end
  if P.UpdateBadges then P.UpdateBadges() end
  -- Retente le masquage de l'inbox natif a chaque rafraichissement (pas
  -- seulement au MAIL_SHOW initial) : meme piege de timing que TryHookSendMail
  -- ci-dessus, InboxFrame peut ne pas encore exister au tout premier appel.
  if PostBoxDB and PostBoxDB.replaceNativeMailbox and P.SetNativeMailVisible then
    P.SetNativeMailVisible(false)
  end
  return P.cache
end

-- ============================================================================
-- SACS : slots libres (pour la reserve configurable pendant OpenAll)
-- ============================================================================
function P.GetFreeBagSlots()
  local free = 0
  local numBags = (NUM_BAG_SLOTS or 4)
  for bag = 0, numBags do
    local slots = C_Container and C_Container.GetContainerNumSlots(bag) or GetContainerNumSlots(bag)
    local used = C_Container and C_Container.GetContainerNumFreeSlots and select(1, C_Container.GetContainerNumFreeSlots(bag))
    if used then
      free = free + used
    elseif slots and slots > 0 then
      for slot = 1, slots do
        local info = C_Container and C_Container.GetContainerItemInfo(bag, slot)
        if not info then free = free + 1 end
      end
    end
  end
  return free
end

-- ============================================================================
-- DoNotWant : marquer un objet pour retour automatique au lieu de ramassage
-- ============================================================================
function P.IsDoNotWant(itemLink)
  if not itemLink then return false end
  local id = GetItemInfoInstant and select(1, GetItemInfoInstant(itemLink))
  return id and PostBoxDB.doNotWant[id] or false
end

function P.SetDoNotWant(itemLink, on)
  if not itemLink then return end
  local id = GetItemInfoInstant and select(1, GetItemInfoInstant(itemLink))
  if not id then return end
  if on then PostBoxDB.doNotWant[id] = true else PostBoxDB.doNotWant[id] = nil end
end

-- ============================================================================
-- STATS : mise a jour (delegue le stockage a PostBoxDB.stats, expose par
-- PostBox_Stats.lua pour l'affichage du tableau de bord)
-- ============================================================================
-- Cle du personnage courant, pour la vue multi-personnages (PostBoxDB est un
-- SavedVariables COMPTE, deja partage entre tous les personnages - voir
-- PostBox.toc : "## SavedVariables: PostBoxDB", pas PerCharacter).
local function CharKey()
  local name, realm = UnitName("player"), GetRealmName()
  if not (name and realm) then return nil end
  return name .. "-" .. realm
end

-- Cle du jour courant (heure serveur), pour l'historique temporel. Format
-- trie alphabetiquement = trie chronologiquement (AAAA-MM-JJ).
local function TodayKey()
  return date("%Y-%m-%d")
end

local HISTORY_MAX_DAYS = 60  -- purge au-dela, pour ne pas alourdir indefiniment PostBoxDB

local function GetHistoryDay(dayKey)
  local st = PostBoxDB.stats
  st.history = st.history or {}
  local d = st.history[dayKey]
  if not d then
    d = { goldReceived = 0, goldSent = 0, auctionSold = 0, auctionBought = 0 }
    st.history[dayKey] = d
    -- Purge des jours les plus anciens au-dela de HISTORY_MAX_DAYS (le tri
    -- alphabetique des cles AAAA-MM-JJ correspond au tri chronologique).
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

local function TrackReceivedGold(amount, sender)
  if not amount or amount == 0 then return end
  PostBoxDB.stats.goldReceived = PostBoxDB.stats.goldReceived + amount
  PostBoxDB.stats.rakeSession = PostBoxDB.stats.rakeSession + amount
  if sender then
    PostBoxDB.stats.senders[sender] = (PostBoxDB.stats.senders[sender] or 0) + amount
  end
  local day = GetHistoryDay(TodayKey())
  day.goldReceived = day.goldReceived + amount
  local c = GetCharBucket()
  if c then c.goldReceived = c.goldReceived + amount end
end

local function TrackAuction(category, amount)
  amount = amount or 0
  local day, c = GetHistoryDay(TodayKey()), GetCharBucket()
  if category == "sold" then
    PostBoxDB.stats.auctionSold = PostBoxDB.stats.auctionSold + amount
    day.auctionSold = day.auctionSold + amount
    if c then c.auctionSold = c.auctionSold + amount end
  elseif category == "won" then
    PostBoxDB.stats.auctionBought = PostBoxDB.stats.auctionBought + amount
    day.auctionBought = day.auctionBought + amount
    if c then c.auctionBought = c.auctionBought + amount end
  end
end

-- Envoi de courrier : SendMail() ne recoit que destinataire/sujet/corps, pas
-- le montant joint (attache separement via les widgets natifs de
-- SendMailFrame, voir PostBox_BlackBook.lua). hooksecurefunc sur SendMail
-- (une fonction API normale, PAS une methode de frame protegee - aucun
-- rapport avec le taint du frame de boite aux lettres, voir la note plus bas
-- dans ce fichier) permet de lire le montant au moment de l'envoi, avant que
-- Blizzard ne reinitialise le formulaire. NON VERIFIE EN JEU : si le montant
-- lu est incoherent (0 alors qu'un montant etait visiblement joint), le
-- timing de la lecture par rapport a la remise a zero du formulaire natif
-- devra etre revu avec un /run de diagnostic.
local function TrackSentGold(amount)
  if not amount or amount <= 0 then return end
  PostBoxDB.stats.goldSent = PostBoxDB.stats.goldSent + amount
  GetHistoryDay(TodayKey()).goldSent = GetHistoryDay(TodayKey()).goldSent + amount
  local c = GetCharBucket()
  if c then c.goldSent = c.goldSent + amount end
end

-- SendMailMoney fait partie du panneau de courrier charge a la demande : il
-- n'existe pas forcement au chargement de l'addon (meme piege que MailFrame,
-- voir la note en tete de fichier). On retente l'installation du hook a
-- chaque rafraichissement de cache (donc a chaque ouverture de boite aux
-- lettres) jusqu'a ce qu'il reussisse une fois ; idempotent (drapeau).
local sendMailHooked = false
function P.TryHookSendMail()
  if sendMailHooked or not (_G.SendMailMoney and MoneyInputFrame_GetCopper) then return end
  sendMailHooked = true
  hooksecurefunc("SendMail", function()
    local ok, copper = pcall(MoneyInputFrame_GetCopper, _G.SendMailMoney)
    if ok then TrackSentGold(copper) end
  end)
end

-- ============================================================================
-- OPENALL : ouverture/ramassage en masse (objets + or), gestion >50 courriers,
-- reserve de slots de sac, filtres AH, retour auto DoNotWant, recap anime.
-- ============================================================================
P.openAll = { active = false, loot = {}, gold = 0, itemsTaken = 0, returned = 0, seen = {} }

local function ResetRecap()
  P.openAll.loot = {}
  P.openAll.gold = 0
  P.openAll.itemsTaken = 0
  P.openAll.returned = 0
  -- Cles des courriers deja traites CETTE session "Tout ouvrir" (voir
  -- EntryKey plus bas) - empeche le double comptage.
  P.openAll.seen = {}
end

-- Cle "raisonnablement stable" d'un courrier a travers plusieurs scans de la
-- boite : PAS l'index (TakeInboxMoney est asynchrone - si le serveur n'a pas
-- confirme avant le prochain passage de step(), le meme courrier peut encore
-- apparaitre dans P.cache et se faire retraiter, l'or comptabilise plusieurs
-- fois pour une seule prise reelle - confirme en jeu). L'index, lui, se
-- decale des qu'un courrier disparait de la boite : pas fiable ici.
local function EntryKey(entry)
  return (entry.sender or "") .. "\30" .. (entry.subject or "") .. "\30"
    .. tostring(entry.money or 0) .. "\30" .. tostring(entry.daysLeft or 0)
end

local function AddLoot(itemLink, count)
  if not itemLink then return end
  local entry = P.openAll.loot[itemLink]
  if not entry then entry = { link = itemLink, count = 0 }; P.openAll.loot[itemLink] = entry end
  entry.count = entry.count + (count or 1)
end

-- Un courrier passe-t-il les filtres actifs ? (les filtres ne s'appliquent
-- qu'aux courriers de l'Hotel des ventes ; les autres sont toujours traites)
local function PassesFilters(entry)
  if entry.category == "other" then return true end
  return PostBoxDB.filters[entry.category] ~= false
end

-- opts.categories, si fourni, remplace entierement PassesFilters (utilise
-- par la recuperation groupee des invendus, qui cible delibrement une
-- categorie precise independamment des cases a cocher de filtrage general).
local function IsEligible(entry, opts)
  if opts and opts.categories then
    return opts.categories[entry.category] == true
  end
  return PassesFilters(entry)
end

-- Traite un seul courrier (argent + objets), en respectant DoNotWant et la
-- reserve de slots. Retourne true si quelque chose a ete pris/retourne.
local function ProcessOne(entry)
  local did = false
  if entry.money and entry.money > 0 then
    TakeInboxMoney(entry.index)
    TrackReceivedGold(entry.money, entry.sender)
    if entry.category == "sold" or entry.category == "won" then TrackAuction(entry.category, entry.money) end
    P.openAll.gold = P.openAll.gold + entry.money
    did = true
  end
  if entry.hasItem and entry.hasItem > 0 then
    if PostBoxDB.autoReturnDNW and P.IsDoNotWant(entry.itemLink) then
      ReturnInboxItem(entry.index)
      P.openAll.returned = P.openAll.returned + 1
      did = true
    else
      if P.GetFreeBagSlots() <= (PostBoxDB.reserveSlots or 0) then
        return did, "bagsfull"
      end
      for attach = 1, entry.hasItem do
        local link = SafeGetItemLink(entry.index, attach)
        TakeInboxItem(entry.index, attach)
        AddLoot(link, 1)
        P.openAll.itemsTaken = P.openAll.itemsTaken + 1
      end
      did = true
    end
  end
  return did
end

local function ShowRecap()
  if P.ShowRecapPopup then P.ShowRecapPopup(P.openAll) end
end

-- Boucle asynchrone : traite le cache courant, attend le rafraichissement
-- serveur (MAIL_INBOX_UPDATE) si plus de courriers restent (>50 caches par le
-- client), et continue jusqu'a inbox vide ou reserve de sac atteinte.
local openAllWatcher = CreateFrame("Frame")
local openAllTimeout

function P.OpenAll(opts)
  if P.openAll.active then return end
  P.openAll.active = true
  ResetRecap()
  print(L.MSG_OPENALL_START)

  local function step()
    -- CORRECTIF : le corps de step() n'etait protege par aucun pcall - une
    -- erreur Lua (API bizarre sur un courrier particulier, objet sans lien
    -- valide, etc.) au milieu du traitement interrompait la fonction AVANT
    -- la ligne qui remet P.openAll.active a false. Le bouton "Tout ouvrir"
    -- restait alors bloque en "actif" pour le reste de la session (chaque
    -- clic ressortait aussitot via le garde tout en haut de P.OpenAll), sans
    -- aucun message d'erreur visible - confirme en jeu (l'utilisateur devait
    -- tout cocher et passer par "Traiter la selection" a la place). On isole
    -- desormais le traitement dans un pcall et on garantit la remise a false
    -- de P.openAll.active dans TOUS les cas, erreur comprise.
    local ok, err = pcall(function()
      P.RefreshCache()
      -- CORRECTIF : traiter TOUS les courriers eligibles du cache dans la
      -- meme boucle synchrone (comme avant) les faisait echouer en cascade
      -- au-dela du premier - TakeInboxMoney/TakeInboxItem sont asynchrones et
      -- semblent refuser toute nouvelle demande tant que la precedente n'est
      -- pas confirmee par le serveur, exactement comme DeleteInboxItem (cf.
      -- P.DeleteSelected plus haut) - confirme en jeu ("Tout ouvrir n'ouvre
      -- qu'un mail sur 33"). On ne traite plus qu'UN SEUL courrier par appel
      -- de step(), le rappel via C_Timer 0.6s plus bas se charge d'avancer
      -- au suivant une fois la reponse serveur du precedent digeree.
      local target
      for _, entry in ipairs(P.cache) do
        if (entry.money and entry.money > 0) or (entry.hasItem and entry.hasItem > 0) then
          if IsEligible(entry, opts) and not P.openAll.seen[EntryKey(entry)] then
            target = entry
            break
          end
        end
      end
      if not target then
        P.openAll.active = false
        ShowRecap()
        return
      end
      P.openAll.seen[EntryKey(target)] = true
      local did, reason = ProcessOne(target)
      if reason == "bagsfull" then
        P.openAll.active = false
        print(string.format(L.MSG_OPENALL_BAGSFULL_FMT, PostBoxDB.reserveSlots or 0))
        ShowRecap()
        return
      end
      if openAllTimeout then openAllTimeout:Cancel() end
      openAllTimeout = C_Timer.NewTimer(0.6, step)
    end)
    if not ok then
      P.openAll.active = false
      print("|cFFFF5555PostBox|r : " .. tostring(err))
    end
  end
  step()
end

-- Recuperation groupee des invendus (auctions expirees ou annulees, l'objet
-- revient par courrier sans avoir ete vendu). Il n'existe aucune API pour
-- reposter directement un objet sur l'Hotel des ventes depuis la boite aux
-- lettres (il faut repasser par l'interface HV elle-meme, generalement sur
-- place) : ce bouton se limite donc a recuperer ces objets en un clic,
-- independamment des cases de filtrage general, pour les reposter ensuite
-- manuellement.
function P.CollectUnsold()
  P.OpenAll({ categories = { expired = true, cancelled = true } })
end

openAllWatcher:RegisterEvent("MAIL_INBOX_UPDATE")
openAllWatcher:SetScript("OnEvent", function()
  P.RefreshCache()
end)

-- ============================================================================
-- EXPRESS : Maj-clic = recuperer, Ctrl-clic = renvoyer, Alt-clic = joindre
-- depuis le sac (attache le dernier objet clique du sac au prochain courrier
-- de l'onglet Envoyer). Appele depuis les gestionnaires OnClick des lignes.
-- ============================================================================
function P.ExpressClick(entry, button)
  if IsShiftKeyDown() then
    ProcessOne(entry)
    P.RefreshCache()
  elseif IsControlKeyDown() then
    if PostBoxDB.codThreshold > 0 and entry.cod and entry.cod >= PostBoxDB.codThreshold then
      StaticPopup_Show("POSTBOX_COD_RETURN_CONFIRM", GetCoinTextureString(entry.cod), nil, entry)
    else
      ReturnInboxItem(entry.index)
      P.openAll.returned = P.openAll.returned + 1
      P.RefreshCache()
    end
  end
end

StaticPopupDialogs["POSTBOX_COD_RETURN_CONFIRM"] = {
  text = L.POPUP_COD_RETURN_TEXT,
  button1 = OKAY,
  button2 = CANCEL,
  OnAccept = function(self, data) ReturnInboxItem(data.index); P.RefreshCache() end,
  timeout = 0, whileDead = true, hideOnEscape = true,
}

-- ============================================================================
-- GARDE-FOU COD (a l'ouverture manuelle d'un courrier avec COD)
-- ============================================================================
local function TakeAllAttachments(entry)
  for attach = 1, math.max(entry.hasItem or 1, 1) do
    TakeInboxItem(entry.index, attach)
  end
end

StaticPopupDialogs["POSTBOX_COD_OPEN_CONFIRM"] = {
  text = L.POPUP_COD_OPEN_TEXT,
  button1 = OKAY,
  button2 = CANCEL,
  OnAccept = function(self, data) TakeAllAttachments(data); P.RefreshCache() end,
  timeout = 0, whileDead = true, hideOnEscape = true,
}

function P.ConfirmOpenCOD(entry)
  if PostBoxDB.codThreshold > 0 and entry.cod and entry.cod >= PostBoxDB.codThreshold then
    StaticPopup_Show("POSTBOX_COD_OPEN_CONFIRM", GetCoinTextureString(entry.cod), nil, entry)
  else
    TakeAllAttachments(entry)
    P.RefreshCache()
  end
end

-- ============================================================================
-- INDICATEUR D'EXPIRATION
-- ============================================================================
function P.IsExpiringSoon(entry)
  return entry.daysLeft and entry.daysLeft <= (PostBoxDB.expiryWarnDays or 1)
end

-- ============================================================================
-- TRI INTELLIGENT : regroupe par urgence d'expiration, puis par type AH, puis
-- par expediteur (ordre stable, pas de dependance a un tri natif instable).
-- ============================================================================
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
-- SELECTION : cases a cocher, plage (Maj), meme expediteur (Ctrl)
-- ============================================================================
P.selection = {}  -- [index] = true
P.lastClickedIndex = nil

function P.ToggleSelect(entry, extendKey)
  if extendKey == "shift" and P.lastClickedIndex then
    local lo, hi = P.lastClickedIndex, entry.index
    if lo > hi then lo, hi = hi, lo end
    for _, e in ipairs(P.cache) do
      if e.index >= lo and e.index <= hi then P.selection[e.index] = true end
    end
  elseif extendKey == "ctrl" then
    for _, e in ipairs(P.cache) do
      if e.sender == entry.sender then P.selection[e.index] = true end
    end
  else
    P.selection[entry.index] = not P.selection[entry.index] or nil
  end
  P.lastClickedIndex = entry.index
  if P.RefreshWindow then P.RefreshWindow() end
end

-- CORRECTIF : meme bug que "Tout ouvrir" et la suppression en masse (voir
-- leurs commentaires plus bas) - TakeInboxMoney/TakeInboxItem tires en
-- boucle synchrone pour toute la selection ne prenaient reellement que le
-- premier courrier cote serveur, mais TrackReceivedGold (le compteur "or
-- recu" de la session, PostBoxDB.stats.rakeSession) etait quand meme
-- incremente pour CHAQUE courrier selectionne de facon optimiste - gonflant
-- le cumul d'or de la session bien au-dela de ce qui a reellement ete pris.
-- Confirme en jeu ("le cumul d'or n'est toujours pas bon pour la session").
-- Meme remede : file d'attente, un courrier a la fois, cle stable (EntryKey).
local processQueue = nil
local processTimeout

function P.ProcessSelection()
  if processQueue or P.openAll.active then return end
  local keys = {}
  for _, entry in ipairs(P.cache) do
    if P.selection[entry.index] then keys[#keys + 1] = EntryKey(entry) end
  end
  wipe(P.selection)
  if #keys == 0 then return end
  processQueue = { keys = keys, i = 0 }

  local function step()
    local q = processQueue
    q.i = q.i + 1
    if q.i > #q.keys then
      processQueue = nil
      P.RefreshCache()
      return
    end
    local ok, err = pcall(function()
      P.RefreshCache()
      local target
      for _, entry in ipairs(P.cache) do
        if EntryKey(entry) == q.keys[q.i] then target = entry; break end
      end
      if target then ProcessOne(target) end
    end)
    if not ok then
      print("|cFFFF5555PostBox|r : " .. tostring(err))
    end
    if processTimeout then processTimeout:Cancel() end
    processTimeout = C_Timer.NewTimer(0.6, step)
  end
  step()
end

-- ============================================================================
-- SUPPRESSION (multi-selection) : DeleteInboxItem(index) - CORRECTIF confirme
-- en jeu : le code appelait "DeleteInboxMail", qui n'a jamais existe dans
-- l'API WoW (100% d'echec, "attempt to call a nil value") - le vrai nom est
-- DeleteInboxItem.
-- SECURITE : ne supprime JAMAIS un courrier qui a encore de l'or ou un objet
-- en attente. Ce n'est PAS le serveur qui l'empecherait : DeleteInboxItem()
-- est une requete inconditionnelle, Blizzard ne verifie pas cote serveur si
-- le courrier a encore une piece jointe - c'est nous qui devons le garantir.
-- ASYNCHRONE : DeleteInboxItem() "peut echouer... quand une autre demande de
-- suppression est deja en cours" (Warcraft Wiki) - tirer tous les
-- DeleteInboxItem d'une selection dans la meme boucle synchrone (comme
-- avant) les faisait donc echouer en cascade des le 2e, sans erreur Lua
-- (refus cote serveur, pas d'exception) : confirme en jeu ("je dois encore
-- les supprimer 1 par 1"). Meme remede que "Tout ouvrir" plus haut : une
-- file d'attente qui traite UN courrier a la fois et attend avant le
-- suivant, en reperant chaque courrier par une cle stable (EntryKey) plutot
-- que par son index, qui se decale a chaque suppression confirmee.
-- ============================================================================
local deleteQueue = nil
local deleteTimeout

function P.DeleteSelected()
  if deleteQueue then return end -- suppression deja en cours
  local keys, skipped = {}, 0
  for _, entry in ipairs(P.cache) do
    if P.selection[entry.index] then
      if (entry.money or 0) == 0 and (entry.hasItem or 0) == 0 then
        keys[#keys + 1] = EntryKey(entry)
      else
        skipped = skipped + 1
      end
    end
  end
  wipe(P.selection)
  if #keys == 0 then
    if skipped > 0 then print(string.format(L.MSG_DELETE_RESULT_SKIPPED_FMT, 0, skipped)) end
    return
  end

  deleteQueue = { keys = keys, i = 0, deleted = 0, failed = 0, skipped = skipped }

  local function step()
    local q = deleteQueue
    q.i = q.i + 1
    if q.i > #q.keys then
      deleteQueue = nil
      if q.failed > 0 then
        print(string.format(L.MSG_DELETE_RESULT_FAILED_FMT, q.deleted, q.failed))
      elseif q.skipped > 0 then
        print(string.format(L.MSG_DELETE_RESULT_SKIPPED_FMT, q.deleted, q.skipped))
      else
        print(string.format(L.MSG_DELETE_RESULT_FMT, q.deleted))
      end
      P.RefreshCache()
      return
    end

    local ok, err = pcall(function()
      P.RefreshCache()
      local target
      for _, entry in ipairs(P.cache) do
        if EntryKey(entry) == q.keys[q.i] then target = entry; break end
      end
      if target then
        local delOk, delErr = pcall(DeleteInboxItem, target.index)
        if delOk then
          q.deleted = q.deleted + 1
        else
          q.failed = q.failed + 1
          print("|cFFFF5555PostBox|r : " .. tostring(delErr))
        end
      else
        -- Deja absent du cache (courrier supprime entre-temps par un autre
        -- moyen) : on considere que c'est fait plutot que de le compter en echec.
        q.deleted = q.deleted + 1
      end
    end)
    if not ok then
      q.failed = q.failed + 1
      print("|cFFFF5555PostBox|r : " .. tostring(err))
    end

    if deleteTimeout then deleteTimeout:Cancel() end
    deleteTimeout = C_Timer.NewTimer(0.6, step)
  end
  step()
end

-- ============================================================================
-- RAKE : total d'or ramasse (compteur de session, remis a zero manuellement)
-- ============================================================================
function P.ResetRake() PostBoxDB.stats.rakeSession = 0 end
function P.GetRake() return PostBoxDB.stats.rakeSession or 0 end

-- ============================================================================
-- RECHERCHE GLOBALE (expediteur / objet / sujet)
-- ============================================================================
function P.SearchProvider(query)
  local out = {}
  local UI = _G.TibiMidnight
  for _, e in ipairs(P.cache) do
    local hay = (e.sender or "") .. " " .. (e.subject or "") .. " " .. (e.itemLink or "")
    if UI and UI.Match(hay, query) then
      out[#out + 1] = {
        text = string.format("%s - %s", e.sender or "?", e.subject or ""),
        onClick = function() if P.OpenWindow then P.OpenWindow() end end,
      }
    end
  end
  return out
end

-- ============================================================================
-- OUVERTURE / FERMETURE PUBLIQUE (utilise par le core en mode module, et par
-- le bouton minimap / slash en mode standalone)
-- ============================================================================
function PostBox_Toggle()
  if P.BuildUI then P.BuildUI() end
  local f = _G.PostBoxMainFrame
  if not f then return end
  if f:IsShown() then
    f:Hide(); PostBoxDB.open = false
  else
    f:Show(); PostBoxDB.open = true
    P.RefreshCache()
  end
end

function PostBox_OpenOptions()
  if P.BuildOptionsPanel then P.BuildOptionsPanel() end
  if _G.PostBoxOptions then _G.PostBoxOptions:Toggle() end
end

-- ============================================================================
-- FENETRE PRINCIPALE
-- ============================================================================
local ROW_H = 30
-- La zone de contenu fait LIST_W-40 = 660px (LIST_W defini dans BuildMainFrame,
-- plus bas). 560 laissait 100px inutilises a droite - la colonne "money"
-- (jusqu'a environ x=578) et le bouton "ne veut pas" (colle au bord droit de
-- la ligne) debordaient donc hors du fond sombre de la ligne. 656 (avec une
-- petite marge) fait rentrer tout le monde dans le fond visible.
local ROW_W = 656
local rows = {}

local function GetUI() return _G.TibiMidnight end

local function BuildRow(parent)
  local r = CreateFrame("Button", nil, parent, "BackdropTemplate")
  r:SetSize(ROW_W, ROW_H)
  local UI = GetUI()
  if UI then
    -- UI.FlatBackdrop() pose une texture blanche brute (WHITE8X8) sans
    -- teinte : sans SetBackdropColor explicite, la ligne reste blanche et le
    -- texte clair du theme devient illisible dessus. On applique le fond
    -- sombre du socle ici.
    r:SetBackdrop(UI.FlatBackdrop())
    r:SetBackdropColor(UI.C.PANEL[1], UI.C.PANEL[2], UI.C.PANEL[3], 0.92)
    r:SetBackdropBorderColor(0, 0, 0, 0.35)
  end

  local cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
  cb:SetSize(20, 20); cb:SetPoint("LEFT", 4, 0)
  r.cb = cb

  local expiry = r:CreateTexture(nil, "OVERLAY")
  expiry:SetSize(10, 10); expiry:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  expiry:SetColorTexture(0.90, 0.30, 0.20, 1)
  r.expiry = expiry

  -- SetWordWrap(false) sur sender/subject/item : un texte long qui passe sur
  -- 2 lignes debordait de la hauteur fixe de la ligne et chevauchait la ligne
  -- suivante (confirme en jeu). Une seule ligne + troncature (TruncateToWidth,
  -- plus bas) est plus robuste qu'une hauteur de ligne variable.
  local sender = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sender:SetPoint("LEFT", expiry, "RIGHT", 6, 0); sender:SetWidth(130); sender:SetJustifyH("LEFT")
  sender:SetWordWrap(false)
  r.sender = sender

  local subject = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  subject:SetPoint("LEFT", sender, "RIGHT", 6, 0); subject:SetWidth(190); subject:SetJustifyH("LEFT")
  subject:SetWordWrap(false)
  r.subject = subject

  -- Icone de l'objet joint (visuel, en plus du texte) : reduit la colonne
  -- texte de 120 a 96px pour lui faire de la place sans deplacer les
  -- colonnes suivantes (money/dnw gardent leurs ancrages inchanges).
  local itemIcon = r:CreateTexture(nil, "OVERLAY")
  itemIcon:SetSize(20, 20)
  itemIcon:SetPoint("LEFT", subject, "RIGHT", 4, 0)
  itemIcon:SetTexture(134400)  -- INV_Misc_QuestionMark : repli tant qu'aucun objet n'est affecte
  itemIcon:Hide()
  r.itemIcon = itemIcon

  local item = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  item:SetPoint("LEFT", itemIcon, "RIGHT", 4, 0); item:SetWidth(96); item:SetJustifyH("LEFT")
  item:SetWordWrap(false)
  r.item = item

  local money = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  money:SetPoint("LEFT", item, "RIGHT", 4, 0); money:SetWidth(80); money:SetJustifyH("LEFT")
  r.money = money

  local dnw = CreateFrame("Button", nil, r)
  dnw:SetSize(18, 18); dnw:SetPoint("RIGHT", -6, 0)
  local dnwTex = dnw:CreateTexture(nil, "OVERLAY"); dnwTex:SetAllPoints()
  dnwTex:SetTexture("Interface\\Buttons\\UI-GroupLoot-DE-Up")
  r.dnw = dnw

  r:SetScript("OnClick", function(self, button)
    local e = self._entry
    if not e then return end
    if button == "RightButton" then
      if e.hasItem and e.hasItem > 0 then P.ConfirmOpenCOD(e) end
      return
    end
    if IsShiftKeyDown() or IsControlKeyDown() then
      P.ExpressClick(e, button)
    else
      -- Clic simple sur la ligne (expediteur, sujet ou objet) = lire le
      -- contenu. La case a cocher (widget separe, cf. cb ci-dessous) reste
      -- l'unique moyen de selectionner un courrier.
      P.ShowMailPreview(e)
    end
  end)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")

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

-- Tronque un texte SIMPLE (jamais un lien d'objet - couper un |H...|h en plein
-- milieu casserait le lien) a la largeur d'affichage donnee, "..." en bout.
-- Empeche tout debordement horizontal vers la colonne suivante.
local function TruncateToWidth(fs, text, maxWidth)
  text = text or ""
  fs:SetText(text)
  if text == "" or (fs:GetStringWidth() or 0) <= maxWidth then return end
  local s = text
  while #s > 1 and (fs:GetStringWidth() or 0) > maxWidth do
    s = s:sub(1, #s - 1)
    fs:SetText(s .. "...")
  end
end

local function FormatRow(r, e)
  r._entry = e
  TruncateToWidth(r.sender, e.sender, 128)
  TruncateToWidth(r.subject, e.subject, 188)
  -- hasItem = nombre d'emplacements de piece jointe utilises (pas forcement
  -- le meme objet repete) : on affiche le premier objet + un compteur si
  -- d'autres emplacements sont joints, sans laisser croire a une quantite.
  -- (Pas de troncature ici : e.itemLink est un vrai lien |H...|h, le couper
  -- en plein milieu casserait sa syntaxe - SetWordWrap(false) suffit a
  -- empecher le retour a la ligne qui causait le chevauchement vertical.)
  r.item:SetText(e.itemLink and (e.hasItem > 1 and (e.itemLink .. " (+" .. (e.hasItem - 1) .. ")") or e.itemLink) or "")
  r.money:SetText(e.money > 0 and GetCoinTextureString(e.money) or "")
  if e.itemLink then
    -- GetItemIcon peut renvoyer nil un court instant si les infos de l'objet
    -- ne sont pas encore mises en cache cote client (objet jamais vu) - on
    -- garde alors le repli INV_Misc_QuestionMark pose a la creation de la
    -- ligne plutot que d'afficher une texture vide.
    local icon = GetItemIcon and GetItemIcon(e.itemLink)
    if icon then r.itemIcon:SetTexture(icon) end
    r.itemIcon:Show()
  else
    r.itemIcon:Hide()
  end
  r.cb:SetChecked(P.selection[e.index] and true or false)
  r.expiry:SetShown(P.IsExpiringSoon(e))
  r.dnw:SetShown(e.itemLink ~= nil)
  r.dnw:SetAlpha((e.itemLink and P.IsDoNotWant(e.itemLink)) and 1 or 0.35)
  if P.previewEntryKey and e.index == P.previewEntryKey then
    r:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
  else
    r:SetBackdropBorderColor(0, 0, 0, 0.35)
  end
end

P.searchQuery = ""

function P.RefreshWindow()
  local f = _G.PostBoxMainFrame
  if not f or not f:IsShown() then return end
  local list = PostBoxDB.smartSort and P.SmartSort(P.cache) or P.cache
  if P.searchQuery ~= "" then
    local filtered = {}
    for _, e in ipairs(list) do
      local hay = ((e.sender or "") .. " " .. (e.subject or "")):lower()
      if hay:find(P.searchQuery, 1, true) then filtered[#filtered + 1] = e end
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
    -- Hauteur de ligne FIXE : sender/subject sont maintenant tronques a une
    -- seule ligne (FormatRow/TruncateToWidth) plutot que d'autoriser un
    -- retour a la ligne qui debordait de la hauteur de ligne (chevauchement
    -- vertical confirme en jeu). Plus simple et plus fiable qu'une hauteur
    -- variable, et evite aussi tout debordement horizontal vers la colonne
    -- suivante.
    r:SetHeight(ROW_H)
    y = y - ROW_H
  end
  for i = #list + 1, #rows do rows[i]:Hide() end
  content:SetHeight(math.max(-y + 4, 10))

  if f.countText then
    f.countText:SetText(string.format(L.WINDOW_COUNT_FMT, #P.cache, GetCoinTextureString(P.GetRake())))
  end

  -- Conserve l'ordre affiche courant pour la navigation clavier (Haut/Bas)
  -- du volet d'apercu : les fleches doivent parcourir EXACTEMENT ce que
  -- l'utilisateur voit a l'ecran (tri + recherche appliques), pas P.cache brut.
  P.currentList = list
end

-- ============================================================================
-- BADGE (nombre de courriers NON LUS) : sur l'onglet du core (mode integre),
-- sur l'icone minicarte PRINCIPALE de TibiSuite (mode integre, visible meme
-- barre repliee) et sur le bouton minimap propre de PostBox (mode
-- standalone). Tous no-op silencieux si l'element vise n'existe pas encore.
-- Compte volontairement e.wasRead == false uniquement : un courrier deja lu
-- mais pas encore ramasse (or/objet toujours en attente) ne re-notifie pas
-- indefiniment - seul un VRAI nouveau courrier fait remonter le compteur.
-- ============================================================================
function P.UpdateBadges()
  local n = 0
  for _, e in ipairs(P.cache) do
    if not e.wasRead then n = n + 1 end
  end
  if _G.TibiSuite then
    if TibiSuite.SetTabBadge then TibiSuite.SetTabBadge("Post", n) end
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
-- APERCU DU CONTENU D'UN COURRIER (texte de la lettre)
-- ----------------------------------------------------------------
-- Integre a la fenetre principale (volet de droite, cree dans P.BuildUI) -
-- ce n'est plus une fenetre a part. P.previewEntryKey retient l'entry.index
-- du courrier actuellement affiche (pour surligner sa ligne - voir
-- FormatRow) ; P.currentList (mis a jour par RefreshWindow) est l'ordre
-- affiche courant, utilise par P.PreviewStep pour Haut/Bas.
--
-- NON VERIFIE EN JEU : sequence supposee CheckInboxItem(index) pour demander
-- le texte au serveur, puis GetInboxText(index) pour le lire une fois pret.
-- Si le texte n'est pas encore arrive, on reessaie sur l'evenement
-- MAIL_INBOX_UPDATE (deja utilise ailleurs dans ce fichier pour l'ouverture
-- en masse) avec un nombre de tentatives limite, pour ne jamais rester
-- bloque indefiniment sur "Chargement...". Si l'API reelle differe de ce qui
-- est suppose ici, le message d'indisponibilite s'affiche proprement au lieu
-- d'une erreur Lua (tous les appels sont proteges par pcall).
-- ============================================================================
local previewRetryTimer
P.previewEntryKey = nil

-- Reapplique juste la couleur de bordure des lignes deja construites, sans
-- reconstruire toute la liste (RefreshWindow complet serait plus lourd et
-- rappellerait P.RefreshCache indirectement a chaque changement de courrier
-- previsualise).
local function HighlightPreviewRow()
  for _, r in ipairs(rows) do
    if r:IsShown() and r._entry then
      if P.previewEntryKey and r._entry.index == P.previewEntryKey then
        r:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
      else
        r:SetBackdropBorderColor(0, 0, 0, 0.35)
      end
    end
  end
end

function P.ShowMailPreview(entry)
  if not entry then return end
  local f = _G.PostBoxMainFrame
  if not f or not f.preview then return end
  local pv = f.preview

  P.previewEntryKey = entry.index
  HighlightPreviewRow()

  pv.senderText:SetText((GetUI() and GetUI().Hex(ACCENT[1], ACCENT[2], ACCENT[3]) or "") .. (entry.sender or "?") .. (GetUI() and "|r" or ""))
  pv.subjectText:SetText(entry.subject or "")
  pv.bodyText:SetText(L.PREVIEW_LOADING)
  pv.bodyContent:SetHeight(10)
  pv.placeholder:Hide()
  pv.readingPane:Show()

  if previewRetryTimer then previewRetryTimer:Cancel(); previewRetryTimer = nil end
  pcall(CheckInboxItem, entry.index)

  local attempts = 0
  local function tryFetch()
    attempts = attempts + 1
    local ok, text = pcall(GetInboxText, entry.index)
    if ok and text and text ~= "" then
      pv.bodyText:SetText(text)
      pv.bodyContent:SetHeight(math.max(pv.bodyText:GetStringHeight() or 10, 10))
    elseif attempts < 8 then
      previewRetryTimer = C_Timer.NewTimer(0.25, tryFetch)
    else
      pv.bodyText:SetText(L.PREVIEW_UNAVAILABLE)
    end
  end
  tryFetch()
end

-- Navigation clavier (Haut/Bas) : deplace l'apercu au courrier precedent ou
-- suivant dans P.currentList (l'ordre EXACT affiche a l'ecran, tri/recherche
-- deja appliques). Sans courrier previsualise, une pression demarre sur le
-- premier de la liste plutot que de ne rien faire.
function P.PreviewStep(delta)
  local list = P.currentList
  if not list or #list == 0 then return end
  local idx
  if not P.previewEntryKey then
    idx = (delta > 0) and 1 or #list
  else
    for i, e in ipairs(list) do
      if e.index == P.previewEntryKey then idx = i; break end
    end
    idx = (idx or 1) + delta
  end
  if idx < 1 then idx = 1 elseif idx > #list then idx = #list end
  P.ShowMailPreview(list[idx])
end

function P.BuildUI()
  if _G.PostBoxMainFrame then return end
  local UI = GetUI()
  -- Elargi pour loger le volet d'apercu integre a droite (LIST_W = zone
  -- liste inchangee dans ses proportions internes, PREVIEW_W = volet de
  -- lecture). Hauteur augmentee de 460 a 500 pour compenser la deuxieme
  -- rangee de boutons (32px de plus en haut) sans reduire la hauteur
  -- visible de la liste.
  -- PREVIEW_W etait a 300 (confirme en jeu : texte du courrier illisible,
  -- ~250px de large reel une fois les marges retirees) - porte a 420.
  local LIST_W, PREVIEW_W, FRAME_H = 700, 420, 500
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

  -- Fermeture par Echap via UISpecialFrames (mecanisme natif Blizzard) : voir
  -- note detaillee dans TibiSuiteCore.lua (WireEscapeFor) - piege reel
  -- confirme en jeu quand un autre addon intercepte lui aussi Echap.
  tinsert(UISpecialFrames, "PostBoxMainFrame")

  -- REGRESSION CONFIRMEE EN JEU (retiree) : EnableKeyboard(true) +
  -- OnKeyDown pour la navigation Haut/Bas de l'apercu a cause une erreur
  -- ADDON_ACTION_FORBIDDEN sur SpellStopCasting() au moment d'appuyer sur
  -- Echap (ToggleGameMenu), MEME AVEC SetPropagateKeyboardInput(true) sur
  -- toutes les touches non gerees. Lecon plus generale que prevu : avoir NE
  -- SERAIT-CE QU'UN gestionnaire OnKeyDown actif sur une fenetre affichee
  -- semble suffire a contaminer le meme tick d'evenement que l'appel protege
  -- de Blizzard declenche par Echap, meme si ce gestionnaire ne fait rien
  -- pour la touche Echap elle-meme et la repropage explicitement. AUCUN
  -- EnableKeyboard/OnKeyDown ne doit donc etre pose sur PostBoxMainFrame -
  -- regle etendue au-dela du seul cas Echap. La navigation clavier Haut/Bas
  -- de P.PreviewStep reste disponible mais n'a plus de raccourci clavier ;
  -- utiliser les boutons/clics dans la liste pour changer d'apercu.

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -10)
  title:SetText((UI and UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) or "") .. "PostBox" .. (UI and "|r" or ""))

  -- ── Volet liste (gauche) ─────────────────────────────────────
  local listPane = CreateFrame("Frame", nil, f)
  listPane:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  listPane:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  listPane:SetWidth(LIST_W)
  f.listPane = listPane

  -- Boutons d'action sur DEUX rangees (six boutons ne tiennent plus sur une
  -- seule ligne sans chevaucher le titre - deja rencontre avec cinq boutons,
  -- corrige alors en elargissant la fenetre ; cette fois on repartit plutot
  -- sur deux rangees pour ne plus avoir a re-elargir a chaque bouton ajoute).
  -- Rangee 1 (actions principales) :
  local openAllBtn = UI and UI.MakeButton(listPane, 110, 24, L.BTN_OPENALL) or CreateFrame("Button", nil, listPane)
  openAllBtn:SetPoint("TOPRIGHT", -12, -10)
  openAllBtn:SetScript("OnClick", function() P.OpenAll() end)

  local selBtn = UI and UI.MakeButton(listPane, 110, 24, L.BTN_PROCESS_SELECTION) or CreateFrame("Button", nil, listPane)
  selBtn:SetPoint("RIGHT", openAllBtn, "LEFT", -6, 0)
  selBtn:SetScript("OnClick", function() P.ProcessSelection() end)

  local delBtn = UI and UI.MakeButton(listPane, 100, 24, L.BTN_DELETE_SELECTION) or CreateFrame("Button", nil, listPane)
  delBtn:SetPoint("RIGHT", selBtn, "LEFT", -6, 0)
  delBtn:SetScript("OnClick", function() P.DeleteSelected() end)

  -- Rangee 2 (secondaire) :
  local statsBtn = UI and UI.MakeButton(listPane, 80, 24, L.BTN_STATS) or CreateFrame("Button", nil, listPane)
  statsBtn:SetPoint("TOPRIGHT", openAllBtn, "BOTTOMRIGHT", 0, -6)
  statsBtn:SetScript("OnClick", function() if P.Stats and P.Stats.Toggle then P.Stats.Toggle() end end)

  local blackBookBtn = UI and UI.MakeButton(listPane, 90, 24, L.BTN_BLACKBOOK) or CreateFrame("Button", nil, listPane)
  blackBookBtn:SetPoint("RIGHT", statsBtn, "LEFT", -6, 0)
  blackBookBtn:SetScript("OnClick", function() if P.BlackBook and P.BlackBook.Toggle then P.BlackBook.Toggle() end end)

  local unsoldBtn = UI and UI.MakeButton(listPane, 130, 24, L.BTN_COLLECT_UNSOLD) or CreateFrame("Button", nil, listPane)
  unsoldBtn:SetPoint("RIGHT", blackBookBtn, "LEFT", -6, 0)
  unsoldBtn:SetScript("OnClick", function() P.CollectUnsold() end)

  -- Rafraichissement manuel : filet de securite si la liste ne se resynchronise
  -- pas toute seule (ex : courrier supprime via l'interface WoW native pendant
  -- que PostBox etait deja ouvert - MAIL_INBOX_UPDATE ne semble alors pas
  -- toujours parvenir jusqu'a nous). CheckInbox() force une requete serveur
  -- avant de relire le cache, au cas ou le client lui-meme n'etait pas a jour.
  local refreshBtn = UI and UI.MakeButton(listPane, 90, 24, L.BTN_REFRESH) or CreateFrame("Button", nil, listPane)
  refreshBtn:SetPoint("RIGHT", unsoldBtn, "LEFT", -6, 0)
  refreshBtn:SetScript("OnClick", function()
    -- CheckInbox() est asynchrone (aller-retour serveur) : une relecture
    -- immediate du cache tombe donc souvent avant la reponse. On relit
    -- quand meme tout de suite (sans effet nefaste si rien n'a change), puis
    -- on retente a quelques reprises pendant la seconde qui suit pour
    -- rattraper la reponse serveur meme si MAIL_INBOX_UPDATE ne nous
    -- parvient pas pour une raison quelconque (fenetre fermee entretemps,
    -- interaction mailbox deja terminee, etc.).
    if CheckInbox then pcall(CheckInbox) end
    P.RefreshCache()
    C_Timer.After(0.3, function() P.RefreshCache() end)
    C_Timer.After(0.8, function() P.RefreshCache() end)
  end)

  -- Sous les deux rangees de boutons (rangee 2 se termine a y=-10-24-6-24=-64).
  local countText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  countText:SetPoint("TOPLEFT", f, "TOPLEFT", 34, -70)
  f.countText = countText

  -- Filtres AH (cases a cocher compactes)
  local filterY = -92
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

  -- Recherche texte (expediteur/sujet), filtre la liste affichee en direct.
  -- Sur sa propre ligne (pas cote a cote des filtres) : les libelles francais
  -- des 6 filtres peuvent etre longs, pas de largeur garantie a partager sur
  -- la meme ligne sans verification visuelle en jeu.
  local searchBox = CreateFrame("EditBox", nil, listPane, "SearchBoxTemplate")
  searchBox:SetSize(180, 20)
  searchBox:SetPoint("TOPRIGHT", listPane, "TOPRIGHT", -14, filterY - 26)
  searchBox:SetScript("OnTextChanged", function(self)
    SearchBoxTemplate_OnTextChanged(self)
    P.searchQuery = self:GetText():lower()
    P.RefreshWindow()
  end)
  f.searchBox = searchBox

  -- En-tetes de colonnes (statiques, ne defilent pas avec la liste - les
  -- positions x reprennent exactement les ancrages de BuildRow : sender part
  -- a x=44, itemIcon/item a x=374). Positions Y relatives a filterY (pas de
  -- constantes absolues) pour ne plus se desynchroniser si la hauteur de
  -- l'en-tete change encore (deja arrive deux fois avec l'ajout de boutons).
  local hdrSender = listPane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hdrSender:SetPoint("TOPLEFT", listPane, "TOPLEFT", 44, filterY - 50)
  hdrSender:SetText(L.COL_SENDER)

  local hdrItem = listPane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hdrItem:SetPoint("TOPLEFT", listPane, "TOPLEFT", 374, filterY - 50)
  hdrItem:SetText(L.COL_ITEM)

  local scroll = CreateFrame("ScrollFrame", nil, listPane, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, filterY - 66)
  scroll:SetPoint("BOTTOMRIGHT", -28, 12)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(LIST_W - 40, 10)
  scroll:SetScrollChild(content)
  f.content = content

  -- ── Volet apercu (droite) ────────────────────────────────────
  local pv = CreateFrame("Frame", nil, f, "BackdropTemplate")
  pv:SetPoint("TOPLEFT", listPane, "TOPRIGHT", 6, 0)
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

  -- Boutons Precedent/Suivant (souris) : remplacent les fleches clavier
  -- Haut/Bas retirees (EnableKeyboard/OnKeyDown sur cette fenetre causait un
  -- ADDON_ACTION_FORBIDDEN sur Echap - voir la note dans P.BuildUI). Un clic
  -- souris ne presente pas ce risque.
  local prevBtn = UI and UI.MakeButton(readingPane, 100, 22, L.PREVIEW_PREV) or CreateFrame("Button", nil, readingPane)
  prevBtn:SetPoint("BOTTOMLEFT", readingPane, "BOTTOMLEFT", 14, 8)
  prevBtn:SetScript("OnClick", function() P.PreviewStep(-1) end)

  local nextBtn = UI and UI.MakeButton(readingPane, 100, 22, L.PREVIEW_NEXT) or CreateFrame("Button", nil, readingPane)
  nextBtn:SetPoint("BOTTOMRIGHT", readingPane, "BOTTOMRIGHT", -14, 8)
  nextBtn:SetScript("OnClick", function() P.PreviewStep(1) end)

  local pvScroll = CreateFrame("ScrollFrame", nil, readingPane, "UIPanelScrollFrameTemplate")
  pvScroll:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 4, -10)
  -- BUG CONFIRME EN JEU : ancre precedemment sur prevBtn (bouton "Precedent",
  -- cote GAUCHE du volet, ~100px de large) au lieu du coin bas-droit du volet
  -- lui-meme - ca limitait la zone visible/defilante a ~94px quel que soit
  -- PREVIEW_W, d'ou le texte illisible qui ne s'est pas ameliore en elargissant
  -- le volet. +40 en Y pour degager la rangee Precedent/Suivant en bas.
  pvScroll:SetPoint("BOTTOMRIGHT", readingPane, "BOTTOMRIGHT", -20, 40)
  local pvContent = CreateFrame("Frame", nil, pvScroll)
  pvContent:SetSize(PREVIEW_W - 50, 10)
  pvScroll:SetScrollChild(pvContent)

  local bodyText = pvContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bodyText:SetPoint("TOPLEFT", 0, 0)
  bodyText:SetWidth(PREVIEW_W - 50)
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

  f:SetScript("OnShow", function() P.RefreshCache() end)
  f:Hide()  -- CreateFrame() est visible par defaut : on masque avant le premier Toggle
end

function P.OpenWindow()
  P.BuildUI()
  if _G.PostBoxMainFrame and not _G.PostBoxMainFrame:IsShown() then PostBox_Toggle() end
end

-- ============================================================================
-- RECAP ANIME (fin d'OpenAll) : liste du butin + or, revele ligne par ligne.
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

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide() end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText((UI and UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) or "") .. L.RECAP_TITLE .. (UI and "|r" or ""))
    f.title = title

    local goldText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    goldText:SetPoint("TOP", title, "BOTTOM", 0, -8)
    f.goldText = goldText

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -60)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(260, 10)
    scroll:SetScrollChild(content)
    f.content = content
    f.lines = {}
  end

  for _, l in ipairs(f.lines) do l:Hide() end
  f.goldText:SetText(result.gold > 0 and string.format(L.RECAP_GOLD_FMT, GetCoinTextureString(result.gold)) or L.RECAP_NO_GOLD)

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
      l:SetPoint("TOPLEFT", f.content, "TOPLEFT", 4, y)
      l:SetWidth(250); l:SetJustifyH("LEFT")
      f.lines[i] = l
    end
    l:SetText(string.format("%s x%d", entry.link, entry.count))
    l:SetAlpha(0); l:Show()
    UIFrameFadeIn(l, 0.25, 0, 1)
    y = y - 18
    f.content:SetHeight(math.max(-y + 4, 10))
    C_Timer.After(0.08, function() revealLine(i + 1) end)
  end
  revealLine(1)

  if result.returned and result.returned > 0 then
    print(string.format(L.MSG_DNW_RETURNED_FMT, result.returned))
  end

  f:Show()
end

-- ============================================================================
-- PANNEAU D'OPTIONS
-- ============================================================================
function P.BuildOptionsPanel()
  if _G.PostBoxOptions then return end
  local UI = GetUI()
  if not UI then return end

  local panel = UI.CreateOptionsPanel({
    name = "PostBoxOptions", title = L.OPT_TITLE, accent = ACCENT,
  })

  panel:Section(L.OPT_SEC_OPENALL)
  panel:Slider(L.OPT_RESERVE_SLOTS, 0, 20, 1,
    function() return PostBoxDB.reserveSlots end,
    function(v) PostBoxDB.reserveSlots = v end)
  panel:Check(L.OPT_AUTORETURN_DNW,
    function() return PostBoxDB.autoReturnDNW end,
    function(v) PostBoxDB.autoReturnDNW = v end)

  panel:Section(L.OPT_SEC_SECURITY)
  panel:Slider(L.OPT_COD_THRESHOLD, 0, 5000, 50,
    function() return math.floor((PostBoxDB.codThreshold or 0) / 10000) end,
    function(v) PostBoxDB.codThreshold = v * 10000 end)
  panel:Slider(L.OPT_EXPIRY_DAYS, 1, 5, 1,
    function() return PostBoxDB.expiryWarnDays end,
    function(v) PostBoxDB.expiryWarnDays = v end)

  panel:Section(L.OPT_SEC_DISPLAY)
  panel:Check(L.OPT_SMART_SORT,
    function() return PostBoxDB.smartSort end,
    function(v) PostBoxDB.smartSort = v; P.RefreshWindow() end)

  panel:Section(L.OPT_SEC_MAILBOX)
  panel:Check(L.OPT_REPLACE_MAILBOX,
    function() return PostBoxDB.replaceNativeMailbox end,
    function(v) PostBoxDB.replaceNativeMailbox = v end)
  panel:Note(L.OPT_REPLACE_MAILBOX_NOTE)

  panel:Section(L.OPT_SEC_SESSION)
  panel:Note(L.OPT_SESSION_NOTE)
  panel:Button(L.OPT_RESET_RAKE, function() P.ResetRake(); P.RefreshWindow() end)

  _G.PostBoxOptions = panel
end
