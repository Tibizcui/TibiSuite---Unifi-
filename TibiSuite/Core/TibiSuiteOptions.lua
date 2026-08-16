-- ================================================================
-- TibiSuiteOptions v4.0
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

-- Presentation de la suite (installateur + panneau des modules).
local INTRO = "TibiSuite reunit tous tes trackers Tibiscui sous un seul bouton de minicarte et une barre d'onglets. Tu actives seulement les modules voulus : les autres ne sont pas charges et ne consomment aucune memoire."

-- Resume court par module (repris des descriptions officielles de chaque toc).
local DESC = {
  Daily   = "Quetes quotidiennes et hebdomadaires (Midnight, TWW), cochees automatiquement selon ton historique.",
  Dgn     = "Compteur d'entrees d'instances : donjons, raids, gouffres, Torghast, toutes extensions.",
  Leg     = "Suivi des objets legendaires par extension : statut, quetes et composants, sur tout le compte.",
  Rep     = "Reputations et Renom de Vanilla a Midnight : groupes pliables, quetes, suivi auto par zone.",
  Lvl     = "Historique des sessions de leveling et de farm, avec statistiques.",
  Weekly  = "Tableau de bord hebdomadaire : ce qu'il reste a faire pour maximiser tes recompenses.",
  MiniHub = "Regroupe les boutons de la minicarte dans un conteneur unique et retractable.",
  XPBar   = "Barre d'XP avancee : niveau, XP, repos, quetes et statistiques de session.",
  Lair    = "Audit de groupe et pertinence des recompenses pour les Repaires.",
  Skill   = "Progression des metiers par extension (actuel / max + %), pour tous tes personnages.",
  RepBar  = "Barre de reputation : remplace la barre native, suit la faction par zone et par quete.",
}

-- Categorie pour l'installateur : "hud" = barre / conteneur ambiant, sinon
-- "tracker" (fenetre). Absent de la table => tracker.
local GROUP = { XPBar = "hud", RepBar = "hud", MiniHub = "hud" }

-- Liens officiels (ouverts via une fenetre "copier le lien").
local URL_SITE  = "https://www.tibiscui.fr"
local URL_CURSE = "https://www.curseforge.com/members/tibiscui/projects"

local panel   -- construit une seule fois (paresseux)

-- Confirmation avant de reinstaller un module (efface reglages + progression,
-- puis recharge l'interface). %s = nom de l'addon, data = cle du module.
StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["TIBISUITE_REINSTALL"] = {
  text = "Reinstaller %s ?\n\nCela efface definitivement ses reglages et sa progression, puis recharge l'interface.",
  button1 = YES or "Oui",
  button2 = NO or "Non",
  OnAccept = function(_, data)
    if data and TibiSuite.ReinstallModule then TibiSuite.ReinstallModule(data) end
  end,
  timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

-- Confirmation avant de reinstaller TibiSuite (le core) : reglages de la suite
-- remis a zero, progression des modules conservee, puis reload.
StaticPopupDialogs["TIBISUITE_REINSTALL_CORE"] = {
  text = "Reinstaller TibiSuite ?\n\nCela remet a zero les reglages de la suite (barre, modules actives, installation) puis recharge l'interface. La progression de chaque module est conservee.",
  button1 = YES or "Oui",
  button2 = NO or "Non",
  OnAccept = function()
    if TibiSuite.ReinstallCore then TibiSuite.ReinstallCore() end
  end,
  timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

-- Fenetre "copier un lien" : WoW n'ouvre pas de navigateur, on presente donc
-- l'URL dans une EditBox pre-selectionnee (Ctrl+C pour copier).
StaticPopupDialogs["TIBISUITE_URL"] = {
  text = "%s",
  button1 = CLOSE or "Fermer",
  hasEditBox = true, editBoxWidth = 340,
  OnShow = function(self, data)
    local eb = self.editBox or (self.GetEditBox and self:GetEditBox())
    if eb then
      eb:SetText(data or "")
      eb:HighlightText()
      eb:SetFocus()
      eb:SetScript("OnEscapePressed", function(s) s:GetParent():Hide() end)
      eb:SetScript("OnEnterPressed",  function(s) s:GetParent():Hide() end)
    end
  end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
local function ShowURL(url)
  StaticPopup_Show("TIBISUITE_URL", url, nil, url)
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
    title = "|cFFC41F3BTibiSuite|r  Modules",
    accent = ACCENT_SUITE,
    logo  = LOGO,
  })

  panel:Section("Modules : Chargés / Non chargés")
  panel:Note("Cochez les modules que vous voulez. Cocher un module le charge tout de suite. Decocher prend effet au prochain /reload (un module ne peut pas etre decharge a chaud).")

  local catalog = (TibiSuite.GetCatalog and TibiSuite.GetCatalog()) or {}
  for _, mod in ipairs(catalog) do
    local key     = mod.key
    local present = TibiSuite.ModuleExists and TibiSuite.ModuleExists(mod.addonName)
    local label   = Hex(mod.col) .. (mod.addonName or mod.label) .. "|r"
    if not present then
      label = label .. "  |cFF808080(absent)|r"
    end
    panel:Check(
      label,
      function() return TibiSuite.IsModuleEnabled and TibiSuite.IsModuleEnabled(key) end,
      function(v) if TibiSuite.SetModuleEnabled then TibiSuite.SetModuleEnabled(key, v) end end,
      present and ("Charger / decharger " .. mod.addonName)
              or (mod.addonName .. " n'est pas installe (dossier absent).")
    )
  end

  panel:Section("Astuce")
  panel:Note("Un module decoche ne consomme aucune memoire : ses fichiers de donnees ne sont meme pas lus. Seul le core reste toujours charge.")

  -- ── Reinstallation : un bouton par module present ──────────────
  panel:Section("Reinstaller un module")
  panel:Note("Remet un module a zero : efface ses reglages et sa progression, puis recharge l'interface. Action irreversible. La barre TibiSuite et les autres modules ne sont pas touches.")
  for _, mod in ipairs(catalog) do
    local present = TibiSuite.ModuleExists and TibiSuite.ModuleExists(mod.addonName)
    if present then
      local addon = mod.addonName
      local key   = mod.key
      panel:Button(
        "|cFFFF6666Reinstaller|r  " .. Hex(mod.col) .. addon .. "|r",
        function() StaticPopup_Show("TIBISUITE_REINSTALL", addon, nil, key) end
      )
    end
  end

  -- Reinstallation de la suite elle-meme (reglages du core), progression conservee.
  panel:Section("Reinstaller TibiSuite")
  panel:Note("Remet a zero les reglages de la suite (barre, modules actives, installation) et recharge l'interface. La progression de chaque module est conservee.")
  panel:Button(
    "|cFFC41F3BReinstaller TibiSuite|r  |cFF808080(la suite)|r",
    function() StaticPopup_Show("TIBISUITE_REINSTALL_CORE") end
  )

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
  title:SetText(hexLav("TibiSuite") .. "  |cFF7C7790- Midnight|r")
  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -4)
  sub:SetText("Assistant de premiere installation")

  local closeB = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  closeB:SetPoint("TOPRIGHT", 2, 2)

  -- ----- Etapes -----
  local STEP_NAMES = { "Bienvenue", "Modules", "Terminer" }
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

  local sep = f:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(1, 1, 1, 0.10)
  sep:SetPoint("TOPLEFT", 16, -104); sep:SetPoint("TOPRIGHT", -16, -104); sep:SetHeight(1)

  -- ================= PANE : BIENVENUE =================
  local pW = CreateFrame("Frame", nil, f)
  pW:SetPoint("TOPLEFT", 20, -116); pW:SetPoint("BOTTOMRIGHT", -20, 60)
  local intro = pW:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  intro:SetPoint("TOPLEFT", 2, -4); intro:SetPoint("RIGHT", -2, 0)
  intro:SetJustifyH("LEFT"); intro:SetText(INTRO)

  local PILLS = { "|cFFE9E7F011|r modules detectes", "Un seul bouton de minicarte",
                  "|cFFE9E7F00|r perte de progression", "Reglable a tout moment" }
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
  choiceCard(2, true, "Installation express  -  recommande",
    "Active tous les modules et demarre tout de suite. Ajuste plus tard avec /ts modules.",
    function()
      for _, m in ipairs(wizard.present) do wizard.choice[m.key] = true end
      if wizard.refreshCards then wizard.refreshCards() end
      wizard.goStep(2)
    end)
  choiceCard(300, false, "Je choisis mes modules",
    "Selectionne un par un ce que tu veux charger, par categorie.",
    function() wizard.goStep(1) end)

  -- ================= PANE : MODULES =================
  local pM = CreateFrame("Frame", nil, f)
  pM:SetPoint("TOPLEFT", 20, -116); pM:SetPoint("BOTTOMRIGHT", -20, 60)
  pM:Hide()
  local allOn = UI.MakeButton(pM, 96, 22, "Tout activer")
  allOn:SetPoint("TOPLEFT", 2, -2)
  local allOff = UI.MakeButton(pM, 108, 22, "Tout desactiver")
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
  rTitle:SetPoint("TOPLEFT", 2, -4); rTitle:SetText(hexLav("Pret a installer"))
  local rSub = pR:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  rSub:SetPoint("TOPLEFT", 2, -30)
  local chipsHost = CreateFrame("Frame", nil, pR)
  chipsHost:SetPoint("TOPLEFT", 2, -54); chipsHost:SetPoint("RIGHT", -2, 0); chipsHost:SetHeight(150)
  local reass = pR:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  reass:SetPoint("BOTTOMLEFT", 2, 6); reass:SetPoint("RIGHT", -2, 0); reass:SetJustifyH("LEFT")
  reass:SetText("|cFFB8ADFF+|r Aucune progression deplacee : chaque module garde sa sauvegarde.\n"
    .. "|cFFB8ADFF+|r Cocher charge tout de suite ; decocher prend effet au /reload.\n"
    .. "|cFFB8ADFF+|r Reglable a tout moment avec |cFFFFD700/ts modules|r.")

  -- ----- Pied : liens + navigation -----
  local sep2 = f:CreateTexture(nil, "ARTWORK")
  sep2:SetColorTexture(1, 1, 1, 0.10)
  sep2:SetPoint("BOTTOMLEFT", 16, 50); sep2:SetPoint("BOTTOMRIGHT", -16, 50); sep2:SetHeight(1)
  local siteB = UI.MakeButton(f, 92, 24, "Site web")
  siteB:SetPoint("BOTTOMLEFT", 16, 14)
  siteB:SetScript("OnClick", function() ShowURL(URL_SITE) end)
  local curseB = UI.MakeButton(f, 110, 24, "CurseForge")
  curseB:SetPoint("LEFT", siteB, "RIGHT", 8, 0)
  curseB:SetScript("OnClick", function() ShowURL(URL_CURSE) end)
  local prevB = UI.MakeButton(f, 96, 24, "Precedent")
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
    addCat("Trackers (fenetres)", trackers)
    addCat("HUD ambiant (barres et conteneurs)", hud)
    content:SetHeight(math.max(-y + 10, 10))
    if wizard.detectFS then
      wizard.detectFS:SetText("|cFFE9E7F0" .. #wizard.present .. "|r modules detectes")
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
    counter:SetText(hexLav(tostring(c)) .. " / " .. #wizard.present .. " modules actives")
    rSub:SetText(hexLav(tostring(c)) .. " modules seront actives au demarrage.")
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
    prevB:SetShown(s > 0)
    if s == 0 then nextB._label:SetText(hexLav("Commencer"))
    elseif s == 1 then nextB._label:SetText(hexLav("Continuer")); wizard.refreshCards()
    else nextB._label:SetText(hexLav("Installer et demarrer")); wizard.refreshRecap(); wizard.updateCount() end
  end

  local function finish()
    for _, m in ipairs(wizard.present) do
      if TibiSuite.SetModuleEnabled then
        TibiSuite.SetModuleEnabled(m.key, wizard.choice[m.key] and true or false)
      end
    end
    TibiSuiteDB.setupDone = true
    f:Hide()
    print("|cFFC41F3BTibiSuite|r : installation terminee. |cFFFFD700/ts modules|r pour ajuster plus tard.")
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
