--[[============================================================================
  PostBox_BlackBook - Carnet de contacts, alts, destinataires recents,
  presets d'envoi, et pont vers l'onglet "Envoyer" natif de Blizzard.

  IMPORTANT : l'envoi de courrier (nom, sujet, corps, or attache, COD, objets
  joints) reste pilote via les widgets natifs de SendMailFrame (money via
  MoneyInputFrame, objets via ClickSendMailItemButton, envoi final via
  SendMail()). Il n'existe pas d'API pour injecter directement un montant
  d'or ou une piece jointe sans passer par ces widgets ; BlackBook se contente
  donc de les REMPLIR intelligemment (nom auto-complete, presets), pas de
  reimplementer le protocole d'envoi.
============================================================================]]

local P = PostBox
P.BlackBook = P.BlackBook or {}
local B = P.BlackBook
local ACCENT = P.ACCENT
local L = P.L

local function GetUI() return _G.TibiMidnight end

-- ============================================================================
-- CONTACTS
-- ============================================================================
function B.AddContact(name, note)
  if not name or name == "" then return end
  PostBoxDB.blackBook.contacts[name] = { note = note or "", added = time() }
end

function B.RemoveContact(name)
  PostBoxDB.blackBook.contacts[name] = nil
end

function B.GetContacts()
  local out = {}
  for name, data in pairs(PostBoxDB.blackBook.contacts) do
    out[#out + 1] = { name = name, note = data.note }
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- ============================================================================
-- ALTS (meme royaume + meme faction, hors le perso courant). Se construit au
-- fil des connexions : chaque personnage qui charge PostBox s'auto-enregistre
-- dans PostBoxDB.knownChars (voir PostBox.InitDB). Limitation honnete : un
-- alt n'apparait qu'apres s'etre connecte au moins une fois avec PostBox actif.
-- ============================================================================
function B.GetAlts()
  local selfName = UnitName("player") .. "-" .. GetRealmName()
  local selfFaction = UnitFactionGroup("player")
  local out = {}
  for key, info in pairs(PostBoxDB.knownChars) do
    if key ~= selfName and info.faction == selfFaction then
      out[#out + 1] = { name = key, class = info.class, lastSeen = info.lastSeen }
    end
  end
  table.sort(out, function(a, b) return (a.lastSeen or 0) > (b.lastSeen or 0) end)
  return out
end

-- ============================================================================
-- DESTINATAIRES RECENTS (20 max, plus recent en tete, sans doublon)
-- ============================================================================
function B.RecordRecipient(name)
  if not name or name == "" then return end
  local list = PostBoxDB.recentRecipients
  for i = #list, 1, -1 do
    if list[i] == name then table.remove(list, i) end
  end
  table.insert(list, 1, name)
  while #list > 20 do table.remove(list) end
end

-- ============================================================================
-- AUTOCOMPLETION : combine contacts + alts + recents, filtre par prefixe
-- ============================================================================
function B.Autocomplete(query)
  local UI = GetUI()
  local q = UI and UI.Normalize(query) or tostring(query or ""):lower()
  if q == "" then return {} end
  local seen, out = {}, {}
  local function consider(name)
    if seen[name] then return end
    local hay = UI and UI.Normalize(name) or name:lower()
    if hay:find(q, 1, true) then seen[name] = true; out[#out + 1] = name end
  end
  for _, c in ipairs(B.GetContacts()) do consider(c.name) end
  for _, a in ipairs(B.GetAlts()) do consider(a.name) end
  for _, r in ipairs(PostBoxDB.recentRecipients) do consider(r) end
  return out
end

-- ============================================================================
-- PRESETS (gabarits de destinataire recurrents)
-- ============================================================================
function B.AddPreset(name, recipient, subject, body, money)
  PostBoxDB.blackBook.presets[name] = { recipient = recipient, subject = subject or "", body = body or "", money = money or 0 }
end

function B.RemovePreset(name)
  PostBoxDB.blackBook.presets[name] = nil
end

function B.GetPresets()
  local out = {}
  for name, data in pairs(PostBoxDB.blackBook.presets) do
    out[#out + 1] = { name = name, recipient = data.recipient, subject = data.subject, body = data.body, money = data.money }
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- ============================================================================
-- PONT VERS L'ONGLET "ENVOYER" NATIF : ouvre la boite aux lettres si besoin,
-- bascule sur SendMailFrame et pre-remplit les champs. L'utilisateur clique
-- ensuite sur le bouton "Envoyer" natif (ou nous l'appelons directement si
-- confirmSend=true, apres avoir attache l'or/les objets).
-- ============================================================================
function B.FillSendForm(recipient, opts)
  opts = opts or {}
  local mf = P.GetMailFrame and P.GetMailFrame()
  if not mf then
    print(L.MSG_OPEN_MAILBOX_FIRST)
    return false
  end
  if not mf:IsShown() then
    -- PostBox suppresse l'ouverture automatique du conteneur natif (voir
    -- PostBox_Module.lua), mais l'interaction serveur avec la boite aux
    -- lettres reste active tant que PostBox est ouvert : on peut donc
    -- l'afficher nous-memes a la demande pour l'onglet Envoyer, plutot que
    -- de demander a l'utilisateur de l'ouvrir lui-meme.
    if _G.ShowUIPanel then ShowUIPanel(mf) else mf:Show() end
  end
  -- Bascule sur l'onglet "Envoyer" en simulant un vrai clic sur son bouton
  -- (plus fiable que d'appeler directement un gestionnaire interne Blizzard
  -- dont la signature exacte peut varier).
  if _G.MailFrameTab2 and (not SendMailFrame or not SendMailFrame:IsShown()) then
    _G.MailFrameTab2:Click()
  end
  if SendMailNameEditBox then SendMailNameEditBox:SetText(recipient or "") end
  if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText(opts.subject or "") end
  if SendMailBodyEditBox then SendMailBodyEditBox:SetText(opts.body or "") end
  if opts.money and opts.money > 0 and MoneyInputFrame_SetCopper and SendMailMoney then
    MoneyInputFrame_SetCopper(SendMailMoney, opts.money)
  end
  if recipient then B.RecordRecipient(recipient) end
  return true
end

-- Attache l'objet d'un slot de sac au prochain emplacement libre de l'onglet
-- Envoyer (QuickAttach). Doit etre appele avec l'onglet Envoyer deja actif.
function B.QuickAttachFromBag(bag, slot)
  local mf = P.GetMailFrame and P.GetMailFrame()
  if not (mf and mf:IsShown()) then
    print(L.MSG_OPEN_SEND_TAB_FIRST)
    return
  end
  local container = C_Container or _G
  local pickup = container.PickupContainerItem or PickupContainerItem
  if not pickup then return end
  pickup(bag, slot)
  -- Cherche le premier emplacement de piece jointe libre (1..ATTACHMENTS_MAX_SEND).
  local maxSend = ATTACHMENTS_MAX_SEND or 12
  for i = 1, maxSend do
    local texture = _G["SendMailAttachment" .. i]
    if texture and not texture:IsShown() then
      ClickSendMailItemButton(i)
      return
    end
  end
  ClickSendMailItemButton(maxSend)
end

-- Alt-clic sur un objet du sac (a cabler cote bag-hook standard Blizzard :
-- ce gestionnaire est expose pour qu'un hook externe l'appelle).
function B.OnBagItemAltClick(bag, slot)
  if IsAltKeyDown and IsAltKeyDown() then B.QuickAttachFromBag(bag, slot) end
end

-- ============================================================================
-- FORWARD : reexpedie un courrier recu (or + objets) vers un autre
-- destinataire. WoW n'a pas de "transfert" direct : on prend d'abord le
-- contenu (il passe dans les sacs / l'or du perso), puis on ouvre l'onglet
-- Envoyer pre-rempli avec le meme or et on joint les objets fraichement pris.
-- ============================================================================
function B.Forward(entry, recipient)
  if not entry then return end
  local money = entry.money or 0
  local items = {}
  if entry.money and entry.money > 0 then TakeInboxMoney(entry.index) end
  if entry.hasItem and entry.hasItem > 0 then
    for attach = 1, entry.hasItem do
      local link = GetInboxItemLink and GetInboxItemLink(entry.index, attach)
      TakeInboxItem(entry.index, attach)
      items[#items + 1] = link
    end
  end
  B.FillSendForm(recipient, { subject = L.FORWARD_SUBJECT_PREFIX .. (entry.subject or ""), money = money })
  print(L.MSG_FORWARD_ITEMS_TAKEN)
end

-- ============================================================================
-- CARBONCOPY : envoie le meme message (texte + or) a plusieurs destinataires
-- a la suite (l'utilisateur valide chaque envoi ; les objets ne sont pas
-- dupliques automatiquement - un objet ne peut etre joint qu'une fois).
-- ============================================================================
function B.CarbonCopy(recipients, subject, body, money)
  B.ccQueue = { list = recipients or {}, i = 0, subject = subject, body = body, money = money }
  B.CarbonCopyNext()
end

function B.CarbonCopyNext()
  local q = B.ccQueue
  if not q then return end
  q.i = q.i + 1
  local recipient = q.list[q.i]
  if not recipient then B.ccQueue = nil; return end
  B.FillSendForm(recipient, { subject = q.subject, body = q.body, money = q.money })
  print(string.format(L.MSG_CARBONCOPY_FMT, q.i, #q.list, recipient))
end

-- ============================================================================
-- TRADEBLOCK : preset rapide "envoi vers un destinataire fixe" (ex. mule de
-- banque de guilde) - un clic pre-remplit nom + objet du curseur.
-- ============================================================================
function B.TradeBlockSend(presetName)
  local p = PostBoxDB.blackBook.presets[presetName]
  if not p then return end
  B.FillSendForm(p.recipient, { subject = p.subject, body = p.body, money = p.money })
end

-- ============================================================================
-- FENETRE BLACKBOOK
-- ============================================================================
function B.BuildUI()
  if _G.PostBoxBlackBookFrame then return end
  local UI = GetUI()
  local f = CreateFrame("Frame", "PostBoxBlackBookFrame", UIParent, "BackdropTemplate")
  f:SetSize(360, 460)
  f:SetPoint("CENTER", 40, 0)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true); f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UI then UI.SkinFrame(f, ACCENT, UI.C.PANEL) end

  -- Fermeture par Echap via UISpecialFrames (mecanisme natif Blizzard) : voir
  -- note detaillee dans TibiSuiteCore.lua (WireEscapeFor).
  tinsert(UISpecialFrames, "PostBoxBlackBookFrame")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() f:Hide() end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -10)
  title:SetText((UI and UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) or "") .. L.BB_TITLE .. (UI and "|r" or ""))

  local nameBox = CreateFrame("EditBox", nil, f, "BackdropTemplate")
  nameBox:SetSize(300, 22)
  nameBox:SetPoint("TOP", title, "BOTTOM", 0, -12)
  if UI then nameBox:SetBackdrop(UI.FlatBackdrop()); nameBox:SetBackdropColor(0.02,0.01,0.04,0.95) end
  nameBox:SetAutoFocus(false)
  nameBox:SetFontObject("GameFontHighlightSmall")
  nameBox:SetTextInsets(6, 6, 0, 0)
  f.nameBox = nameBox

  local addBtn = UI and UI.MakeButton(f, 90, 22, L.BB_ADD) or CreateFrame("Button", nil, f)
  addBtn:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)
  addBtn:SetScript("OnClick", function()
    local n = nameBox:GetText()
    if n and n ~= "" then B.AddContact(n); nameBox:SetText(""); B.RefreshUI() end
  end)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -78)
  scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(300, 10)
  scroll:SetScrollChild(content)
  f.content = content
  f.rows = {}
  f:Hide()  -- CreateFrame() est visible par defaut : on masque avant le premier Toggle
end

local function BbRow(content, UI)
  local r = UI and UI.MakeButton(content, 300, 24, "") or CreateFrame("Button", nil, content)
  return r
end

function B.RefreshUI()
  local f = _G.PostBoxBlackBookFrame
  if not f then return end
  local UI = GetUI()
  local y = -4
  local entries = {}
  entries[#entries + 1] = { header = L.BB_SEC_CONTACTS }
  for _, c in ipairs(B.GetContacts()) do entries[#entries + 1] = { name = c.name, kind = "contact" } end
  entries[#entries + 1] = { header = L.BB_SEC_ALTS }
  for _, a in ipairs(B.GetAlts()) do entries[#entries + 1] = { name = a.name, kind = "alt" } end
  entries[#entries + 1] = { header = L.BB_SEC_RECENT }
  for _, name in ipairs(PostBoxDB.recentRecipients) do entries[#entries + 1] = { name = name, kind = "recent" } end

  for i, e in ipairs(entries) do
    local r = f.rows[i]
    if not r then r = BbRow(f.content, UI); f.rows[i] = r end
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, y)
    if e.header then
      r._label:SetText((UI and UI.Hex(ACCENT[1],ACCENT[2],ACCENT[3]) or "") .. e.header .. (UI and "|r" or ""))
      r:SetScript("OnClick", nil)
    else
      r._label:SetText(e.name)
      r:SetScript("OnClick", function()
        f.nameBox:SetText(e.name)
        B.FillSendForm(e.name)
      end)
    end
    r:Show()
    y = y - 26
  end
  for i = #entries + 1, #f.rows do f.rows[i]:Hide() end
  f.content:SetHeight(math.max(-y + 4, 10))
end

function B.Toggle()
  B.BuildUI()
  local f = _G.PostBoxBlackBookFrame
  if f:IsShown() then f:Hide() else f:Show(); B.RefreshUI() end
end
