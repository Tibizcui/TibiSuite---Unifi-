--[[============================================================================
  PostBox_Stats - Tableau de bord des statistiques de courrier.
  Les compteurs (or recu/envoye, ventes/achats AH, top expediteurs, historique
  temporel, ventilation par personnage) sont mis a jour par PostBox.lua au fil
  des prises/envois et persistes dans PostBoxDB.stats. Ce fichier ne fait que
  les afficher.
============================================================================]]

local P = PostBox
P.Stats = P.Stats or {}
local S = P.Stats
local ACCENT = P.ACCENT
local L = P.L

local function GetUI() return _G.TibiMidnight end
local function AccentText(txt)
  local UI = GetUI()
  return (UI and UI.Hex(ACCENT[1], ACCENT[2], ACCENT[3]) or "") .. txt .. (UI and "|r" or "")
end

local function TopSenders(n)
  local out = {}
  for name, gold in pairs(PostBoxDB.stats.senders or {}) do
    out[#out + 1] = { name = name, gold = gold }
  end
  table.sort(out, function(a, b) return a.gold > b.gold end)
  local trimmed = {}
  for i = 1, math.min(n or 5, #out) do trimmed[i] = out[i] end
  return trimmed
end

-- Dernieres N cles de jour (AAAA-MM-JJ), la plus ancienne en premier. Un jour
-- sans activite renvoie simplement une valeur a zero (pas un trou dans la
-- liste), pour que le graphique garde toujours 7 barres alignees sur "hier,
-- avant-hier, etc." independamment des jours ou rien n'a ete recolte.
local function LastDayKeys(n)
  local keys = {}
  for i = n - 1, 0, -1 do
    keys[#keys + 1] = date("%Y-%m-%d", time() - i * 86400)
  end
  return keys
end

local function HistorySum(days, field)
  local st = PostBoxDB.stats
  local total = 0
  for _, k in ipairs(LastDayKeys(days)) do
    local d = st.history and st.history[k]
    if d then total = total + (d[field] or 0) end
  end
  return total
end

local CHART_MAX_H = 56  -- hauteur utile (px) pour la plus haute barre

function S.BuildUI()
  if _G.PostBoxStatsFrame then return end
  local UI = GetUI()
  local f = CreateFrame("Frame", "PostBoxStatsFrame", UIParent, "BackdropTemplate")
  f:SetSize(360, 660)
  f:SetPoint("CENTER", -40, 0)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true); f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UI then UI.SkinFrame(f, ACCENT, UI.C.PANEL) end

  -- Fermeture par Echap via UISpecialFrames (mecanisme natif Blizzard) : voir
  -- note detaillee dans TibiSuiteCore.lua (WireEscapeFor).
  tinsert(UISpecialFrames, "PostBoxStatsFrame")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() f:Hide() end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -10)
  title:SetText(AccentText(L.STATS_TITLE))

  -- ── Compteurs globaux (compte) ────────────────────────────────
  local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  body:SetPoint("TOPLEFT", 14, -40)
  body:SetPoint("TOPRIGHT", -14, -40)
  body:SetJustifyH("LEFT"); body:SetJustifyV("TOP")
  body:SetSpacing(4)
  f.body = body

  -- ── Historique 7 jours (barres = ventes HV du jour) ────────────
  local histTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  histTitle:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -16)
  f.histTitle = histTitle

  local chart = CreateFrame("Frame", nil, f)
  chart:SetSize(320, CHART_MAX_H + 34)
  chart:SetPoint("TOPLEFT", histTitle, "BOTTOMLEFT", 4, -20)
  f.chart = chart

  local bars, dayLabels, valLabels = {}, {}, {}
  local barW = 28
  local gap = (320 - 7 * barW) / 6
  for i = 1, 7 do
    local bar = chart:CreateTexture(nil, "ARTWORK")
    bar:SetWidth(barW)
    bar:SetHeight(2)
    bar:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", (i - 1) * (barW + gap), 14)
    bar:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.85)
    bars[i] = bar

    local vlbl = chart:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    vlbl:SetPoint("BOTTOM", bar, "TOP", 0, 2)
    vlbl:SetWidth(barW + 10)
    vlbl:SetJustifyH("CENTER")
    valLabels[i] = vlbl

    local dlbl = chart:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dlbl:SetPoint("TOP", bar, "BOTTOM", 0, -2)
    dlbl:SetWidth(barW + 10)
    dlbl:SetJustifyH("CENTER")
    dayLabels[i] = dlbl
  end
  f.bars, f.dayLabels, f.valLabels = bars, dayLabels, valLabels

  -- ── Multi-personnages ───────────────────────────────────────
  local charsTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  charsTitle:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", -4, -18)
  charsTitle:SetText(AccentText(L.STATS_CHARS_TITLE))
  f.charsTitle = charsTitle

  local charsBody = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  charsBody:SetPoint("TOPLEFT", charsTitle, "BOTTOMLEFT", 4, -8)
  charsBody:SetWidth(320)
  charsBody:SetJustifyH("LEFT"); charsBody:SetJustifyV("TOP")
  charsBody:SetSpacing(3)
  f.charsBody = charsBody

  f:Hide()  -- CreateFrame() est visible par defaut : on masque avant le premier Toggle
end

-- GetCoinTextureString() de Blizzard n'accepte pas les montants negatifs
-- (erreur Lua "bad argument #1") - confirme en jeu sur le total "net" d'un
-- personnage ayant plus depense que recu par courrier. Les compteurs bruts
-- (or recu/envoye, ventes/achats, rake) sont des cumuls qui ne descendent
-- jamais sous zero et n'ont pas besoin de cette protection ; seuls les
-- SOUSTRACTIONS (net compte, net 7 jours, net par personnage) le peuvent.
local function FmtSignedCoin(amount)
  amount = amount or 0
  if amount < 0 then return "-" .. GetCoinTextureString(-amount) end
  return GetCoinTextureString(amount)
end

function S.Refresh()
  local f = _G.PostBoxStatsFrame
  if not f then return end
  local st = PostBoxDB.stats

  -- Le "cout HV" (taxe de vente) est deja deduit par Blizzard AVANT que le
  -- courrier de paiement n'arrive : auctionSold est donc deja net de taxe.
  -- Le "revenu net" ci-dessous est simplement ventes - achats.
  local netTotal = (st.auctionSold or 0) - (st.auctionBought or 0)
  local lines = {
    string.format(L.STATS_GOLD_RECEIVED_FMT, GetCoinTextureString(st.goldReceived or 0)),
    string.format(L.STATS_GOLD_SENT_FMT, GetCoinTextureString(st.goldSent or 0)),
    string.format(L.STATS_AH_SOLD_FMT, GetCoinTextureString(st.auctionSold or 0)),
    string.format(L.STATS_AH_BOUGHT_FMT, GetCoinTextureString(st.auctionBought or 0)),
    string.format(L.STATS_NET_FMT, FmtSignedCoin(netTotal)),
    string.format(L.STATS_SESSION_RAKE_FMT, GetCoinTextureString(st.rakeSession or 0)),
    " ",
    L.STATS_TOP_SENDERS,
  }
  for _, s in ipairs(TopSenders(5)) do
    lines[#lines + 1] = string.format("  %s - %s", s.name, GetCoinTextureString(s.gold))
  end
  f.body:SetText(table.concat(lines, "\n"))

  -- Historique : 7 barres = ventes HV du jour, la plus recente a droite.
  local keys = LastDayKeys(7)
  local vals, maxVal = {}, 1
  for i, k in ipairs(keys) do
    local d = st.history and st.history[k]
    vals[i] = d and (d.auctionSold or 0) or 0
    if vals[i] > maxVal then maxVal = vals[i] end
  end
  for i = 1, 7 do
    local h = vals[i] > 0 and math.max(2, (vals[i] / maxVal) * CHART_MAX_H) or 2
    f.bars[i]:SetHeight(h)
    f.dayLabels[i]:SetText(date("%d/%m", time() - (7 - i) * 86400))
    f.valLabels[i]:SetText(vals[i] > 0 and GetCoinTextureString(vals[i]) or "")
  end
  local net7 = HistorySum(7, "auctionSold") - HistorySum(7, "auctionBought")
  f.histTitle:SetText(AccentText(L.STATS_HISTORY_TITLE) .. "   " .. string.format(L.STATS_NET_7D_FMT, FmtSignedCoin(net7)))

  -- Multi-personnages : ventilation par personnage (compte partage entre
  -- tous les persos - voir PostBox.toc), triee par revenu net decroissant.
  local byChar = st.byChar or {}
  local list = {}
  for key, c in pairs(byChar) do
    list[#list + 1] = { key = key, c = c, net = (c.goldReceived or 0) - (c.goldSent or 0) }
  end
  table.sort(list, function(a, b) return a.net > b.net end)
  local rows = {}
  if #list == 0 then
    rows[1] = L.STATS_CHARS_EMPTY
  else
    for _, e in ipairs(list) do
      local info = PostBoxDB.knownChars and PostBoxDB.knownChars[e.key]
      local classTxt = (info and info.class) or "?"
      rows[#rows + 1] = string.format("  %s |cFF888888(%s)|r : %s", e.key, classTxt, FmtSignedCoin(e.net))
    end
  end
  f.charsBody:SetText(table.concat(rows, "\n"))
end

function S.Toggle()
  S.BuildUI()
  local f = _G.PostBoxStatsFrame
  if f:IsShown() then f:Hide() else S.Refresh(); f:Show() end
end
