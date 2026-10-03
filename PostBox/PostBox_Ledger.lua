--[[============================================================================
  PostBox_Ledger - Journal de l'Hotel des ventes.

  Source : les factures des courriers de l'Hotel des ventes
  (GetInboxInvoiceInfo : vente "seller" ou achat "buyer", objet, quantite,
  prix, acheteur/vendeur, depot, taxe). Independant de la langue du client.
  Chaque facture est enregistree UNE fois, meme si le courrier reste des jours
  dans la boite : cle = type + objet + joueur + prix + quantite + heure
  d'arrivee estimee (les courriers HV vivent 30 jours : arrivee = maintenant
  - (30 - jours restants)), a 5 minutes pres.

  Alimente aussi PostBoxDB.stats : achats HV (enfin justes, l'or du courrier
  "gagne" etait toujours a 0) et taxe HV payee.

  A VERIFIER EN JEU : GetInboxInvoiceInfo n'a pas ete sondee en 12.1 (appel
  sous pcall ; si elle ne renvoie rien, le journal reste vide et le
  classement retombe sur les mots-cles).
============================================================================]]

local P = PostBox
P.Ledger = P.Ledger or {}
local G = P.Ledger
local ACCENT = P.ACCENT
local L = P.L

local function GetUI() return _G.TibiMidnight end

local AH_MAIL_DAYS = 30
local BUCKET = 300
local MAX_ENTRIES = 1500
local KEEP_DAYS = 120

-- ============================================================================
-- ENREGISTREMENT
-- ============================================================================
local function Purge(db, now)
  for k, t in pairs(db.seen) do
    if now - t > 40 * 86400 then db.seen[k] = nil end
  end
  local entries = db.entries
  local cut = now - KEEP_DAYS * 86400
  local i = 1
  while i <= #entries do
    if (entries[i].t or 0) < cut then table.remove(entries, i) else i = i + 1 end
  end
  while #entries > MAX_ENTRIES do table.remove(entries, 1) end
end

function G.Scan(cache)
  local db = PostBoxDB.ledger
  local now = time()
  local added = false
  for _, e in ipairs(cache) do
    local inv = e.invoice
    if inv and (inv.type == "seller" or inv.type == "buyer") and inv.item then
      local arrival = now - math.floor((AH_MAIL_DAYS - (e.daysLeft or 0)) * 86400)
      local base = table.concat({ inv.type, inv.item, inv.player or "", tostring(inv.bid or 0), tostring(inv.count or 1) }, "|")
      local b = math.floor(arrival / BUCKET)
      if not (db.seen[base .. "|" .. b] or db.seen[base .. "|" .. (b - 1)] or db.seen[base .. "|" .. (b + 1)]) then
        db.seen[base .. "|" .. b] = now
        local rec = {
          t = arrival, k = (inv.type == "seller") and "s" or "b", item = inv.item,
          n = inv.count or 1, price = inv.bid or 0, cut = inv.cut or 0, dep = inv.deposit or 0,
          who = inv.player, char = P.CharKey(),
        }
        table.insert(db.entries, rec)
        if rec.k == "b" then P.TrackAuctionBought(rec.price) else P.TrackAuctionCut(rec.cut) end
        added = true
      end
    end
  end
  if added then
    table.sort(db.entries, function(a, b) return (a.t or 0) < (b.t or 0) end)
    Purge(db, now)
    G.Refresh()
  end
end

local function Net(rec)
  if rec.k == "s" then return (rec.price or 0) + (rec.dep or 0) - (rec.cut or 0) end
  return rec.price or 0
end
G.Net = Net

-- Totaux sur N jours : ventes nettes, achats, taxe, nombre de ventes.
function G.Totals(days)
  local since = time() - days * 86400
  local sold, bought, cut, n = 0, 0, 0, 0
  for _, rec in ipairs(PostBoxDB.ledger.entries) do
    if (rec.t or 0) >= since then
      if rec.k == "s" then sold = sold + Net(rec); cut = cut + (rec.cut or 0); n = n + 1
      else bought = bought + (rec.price or 0) end
    end
  end
  return sold, bought, cut, n
end

-- Meilleurs objets vendus sur N jours : quantite, revenu net, prix unitaire moyen.
function G.TopItems(days, limit)
  local since = time() - days * 86400
  local map = {}
  for _, rec in ipairs(PostBoxDB.ledger.entries) do
    if rec.k == "s" and (rec.t or 0) >= since then
      local m = map[rec.item]
      if not m then m = { item = rec.item, qty = 0, net = 0, gross = 0 }; map[rec.item] = m end
      m.qty = m.qty + (rec.n or 1)
      m.net = m.net + Net(rec)
      m.gross = m.gross + (rec.price or 0)
    end
  end
  local out = {}
  for _, m in pairs(map) do out[#out + 1] = m end
  table.sort(out, function(a, b) return a.net > b.net end)
  while #out > (limit or 30) do table.remove(out) end
  return out
end

-- ============================================================================
-- FENETRE
-- ============================================================================
local Coin = function(c) return P.Coin(c) end
G.tab = "s"

local function BuildRow(parent)
  local r = CreateFrame("Frame", nil, parent)
  r:SetSize(510, 20)
  local bg = r:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.03)
  r.bg = bg
  local function fs(w, justify, font)
    local t = r:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    t:SetWidth(w); t:SetJustifyH(justify or "LEFT"); t:SetWordWrap(false)
    return t
  end
  r.c1 = fs(78, "LEFT", "GameFontDisableSmall"); r.c1:SetPoint("LEFT", 4, 0)
  r.c2 = fs(190); r.c2:SetPoint("LEFT", r.c1, "RIGHT", 4, 0)
  r.c3 = fs(110, "RIGHT"); r.c3:SetPoint("LEFT", r.c2, "RIGHT", 4, 0)
  r.c4 = fs(116, "RIGHT", "GameFontDisableSmall"); r.c4:SetPoint("LEFT", r.c3, "RIGHT", 4, 0)
  return r
end

function G.Refresh()
  local f = _G.PostBoxLedgerFrame
  if not f or not f:IsShown() then return end
  local s7, b7, c7, n7 = G.Totals(7)
  local s30, b30, c30, n30 = G.Totals(30)
  f.summary:SetText(string.format(L.LEDGER_SUMMARY_FMT, Coin(s7), n7, Coin(s30), n30, Coin(b7), Coin(b30), Coin(c30)))

  for k, b in pairs(f.tabs) do
    b:SetAlpha(k == G.tab and 1 or 0.55)
  end

  local lines = {}
  if G.tab == "top" then
    f.hdr:SetText(L.LEDGER_HDR_TOP)
    for _, m in ipairs(G.TopItems(30, 60)) do
      lines[#lines + 1] = { "x" .. m.qty, m.item, Coin(m.net), Coin(math.floor(m.gross / math.max(m.qty, 1))) }
    end
  else
    f.hdr:SetText(G.tab == "s" and L.LEDGER_HDR_SOLD or L.LEDGER_HDR_BOUGHT)
    local entries = PostBoxDB.ledger.entries
    for i = #entries, 1, -1 do
      local rec = entries[i]
      if rec.k == G.tab then
        local who = rec.who or "?"
        local name = rec.char and P.SplitKey(rec.char) or ""
        lines[#lines + 1] = {
          date("%d/%m %H:%M", rec.t or 0),
          (rec.item or "?") .. ((rec.n or 1) > 1 and (" x" .. rec.n) or ""),
          Coin(Net(rec)),
          who .. (name ~= "" and (" |cFF777777(" .. name .. ")|r") or ""),
        }
        if #lines >= 300 then break end
      end
    end
  end

  local y = -2
  for i, ln in ipairs(lines) do
    local r = f.rows[i]
    if not r then r = BuildRow(f.content); f.rows[i] = r end
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, y)
    r.c1:SetText(ln[1]); r.c2:SetText(ln[2]); r.c3:SetText(ln[3]); r.c4:SetText(ln[4])
    r.bg:SetShown(i % 2 == 0)
    r:Show()
    y = y - 21
  end
  for i = #lines + 1, #f.rows do f.rows[i]:Hide() end
  f.content:SetHeight(math.max(-y + 4, 10))
  f.empty:SetShown(#lines == 0)
end

function G.BuildUI()
  if _G.PostBoxLedgerFrame then return end
  local UI = GetUI()
  local f = CreateFrame("Frame", "PostBoxLedgerFrame", UIParent, "BackdropTemplate")
  f:SetSize(560, 480)
  f:SetPoint("CENTER", 20, 20)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true); f:SetMovable(true); f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UI then UI.SkinFrame(f, ACCENT, UI.C.PANEL) end
  tinsert(UISpecialFrames, "PostBoxLedgerFrame")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -12)
  title:SetText(P.AccentText(L.LEDGER_TITLE))

  local summary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  summary:SetPoint("TOPLEFT", 16, -40); summary:SetWidth(528); summary:SetJustifyH("LEFT")
  summary:SetSpacing(3)
  f.summary = summary

  f.tabs = {}
  local prev
  for _, t in ipairs({ { "s", L.LEDGER_TAB_SOLD }, { "b", L.LEDGER_TAB_BOUGHT }, { "top", L.LEDGER_TAB_TOP } }) do
    local b = P.Btn(f, 120, t[2], function() G.tab = t[1]; G.Refresh() end)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 14, -86) end
    f.tabs[t[1]] = b
    prev = b
  end

  local hdr = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hdr:SetPoint("TOPLEFT", 18, -118); hdr:SetWidth(520); hdr:SetJustifyH("LEFT")
  f.hdr = hdr

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -136)
  scroll:SetPoint("BOTTOMRIGHT", -30, 30)
  if UI and UI.SkinScrollBar then UI.SkinScrollBar(scroll, ACCENT) end
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(510, 10)
  scroll:SetScrollChild(content)
  f.content, f.rows = content, {}

  local empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  empty:SetPoint("CENTER", scroll, "CENTER"); empty:SetWidth(440); empty:SetText(L.LEDGER_EMPTY)
  f.empty = empty

  local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetPoint("BOTTOMLEFT", 16, 10); note:SetWidth(528); note:SetJustifyH("LEFT")
  note:SetText(L.LEDGER_NOTE)

  f:Hide()
end

function G.Toggle()
  G.BuildUI()
  local f = _G.PostBoxLedgerFrame
  if f:IsShown() then f:Hide() else f:Show(); G.Refresh() end
end
