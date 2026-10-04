--[[============================================================================
  Standby - UI.lua
  ---------------------------------------------------------------------------
  Fenetre du module : panneau d'options du socle (StandbyMainFrame), qui sert
  aussi de fenetre principale (onglet de la barre, bouton minimap autonome).
  En tete : etat, derniere absence et bouton Apercu.

  Choix a plusieurs valeurs (mise en page, fond, extension) : bouton qui fait
  defiler les valeurs, le panneau du socle n'ayant pas de liste deroulante.

  NON TESTE EN JEU.
============================================================================]]

local ADDON, SB = ...
local T = SB.T

local panel

local LAYOUT_LABEL = {
  vitrine = T("LAYOUT_VITRINE", "Vitrine"),
  fiche   = T("LAYOUT_FICHE", "Fiche"),
  epure   = T("LAYOUT_EPURE", "Épurée"),
  eco     = T("LAYOUT_ECO", "Économie"),
}
local BG_LABEL = {
  scene = T("BG_SCENE", "Scène (caméra tournante)"),
  art   = T("BG_ART", "Illustration d'extension"),
  black = T("BG_BLACK", "Noir"),
}

-- Aide des choix (demande du 2026-10-04) : description de l'option choisie
-- sous le bouton, et infobulle qui presente toutes les options au survol.
local LAYOUT_HELP = {
  vitrine = T("HELP_VITRINE", "Ta semaine d'un coup d'œil : horloge, messages reçus, tuiles de la suite (coffre, à faire ce soir, personnages), carte du personnage avec titre et stats."),
  fiche   = T("HELP_FICHE", "Ton personnage en grand au centre, son équipement en deux colonnes (niveau d'objet, enchantements, gemmes, châsses vides) et ses statistiques."),
  epure   = T("HELP_EPURE", "L'essentiel seulement : grande horloge, carte du personnage et minuteur."),
  eco     = T("HELP_ECO", "Écran noir, horloge et minuteur discrets. Images par seconde bridées et sons d'ambiance coupés pour économiser l'énergie."),
}
local BG_HELP = {
  scene = T("HELP_SCENE", "Le monde reste visible, la caméra tourne lentement autour de ton personnage, l'interface du jeu est masquée."),
  art   = T("HELP_ART", "Une illustration du journal des aventures, présentée en tableau sur une ambiance assombrie."),
  black = T("HELP_BLACK", "Fond noir uni."),
}
local ART_HELP = T("HELP_ARTTIER", "Choisit l'extension des illustrations : l'extension actuelle, une extension précise, ou une au hasard à chaque absence.")

local function Next(list, cur)
  for i, v in ipairs(list) do if v == cur then return list[(i % #list) + 1] end end
  return list[1]
end

-- Bouton qui fait defiler une valeur (pose dans le contenu du panneau, meme
-- pas vertical que les autres controles du socle).
-- help (facultatif) = { list = { cles }, labels = { cle = libelle },
--   texts = { cle = description }, current = fn -> cle, title = "..." }
-- ou une simple chaine (texte fixe sous le bouton et dans l'infobulle).
local function Cycle(p, getText, onClick, help)
  local UI = _G.TibiMidnight
  local b = UI.MakeButton(p.content, 250, 22, "")
  b:SetPoint("TOPLEFT", p.content, "TOPLEFT", 6, p._y)
  p._y = p._y - 26
  local desc
  if help then
    desc = p.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    desc:SetPoint("TOPLEFT", p.content, "TOPLEFT", 8, p._y)
    desc:SetWidth(256); desc:SetJustifyH("LEFT")
    if desc.SetMaxLines then desc:SetMaxLines(3) end
    p._y = p._y - 40
  end
  p._y = p._y - 4
  local function refresh()
    b._label:SetText(getText())
    if desc then
      if type(help) == "string" then desc:SetText(help)
      else desc:SetText(help.texts[help.current()] or "") end
    end
  end
  b:SetScript("OnClick", function() onClick(); refresh()
    if GameTooltip:IsOwned(b) and b:GetScript("OnEnter") then b:GetScript("OnEnter")(b) end
  end)
  if help then
    local baseEnter, baseLeave = b:GetScript("OnEnter"), b:GetScript("OnLeave")
    b:SetScript("OnEnter", function(self)
      if baseEnter then baseEnter(self) end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if type(help) == "string" then
        GameTooltip:SetText(help, 1, 1, 1, 1, true)
      else
        GameTooltip:SetText(help.title, SB.ACCENT[1], SB.ACCENT[2], SB.ACCENT[3])
        local cur = help.current()
        for _, k in ipairs(help.list) do
          local on = (k == cur)
          GameTooltip:AddLine((on and "> " or "") .. (help.labels[k] or k), on and 1 or 0.85, on and 0.82 or 0.85, on and 0.3 or 0.85)
          GameTooltip:AddLine(help.texts[k] or "", 0.65, 0.65, 0.7, true)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(T("HELP_CLICK", "Clic : option suivante"), 0.5, 0.5, 0.55)
      end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
      if baseLeave then baseLeave(self) end
      GameTooltip:Hide()
    end)
  end
  refresh()
  p._refresh[#p._refresh + 1] = refresh
  return b
end

local function TierLabel(v)
  if v == 0 then return T("ART_CURRENT", "Extension actuelle") end
  if v == -1 then return T("ART_RANDOM", "Aléatoire") end
  for _, e in ipairs(SB.Scene.ArtCatalog() or {}) do
    if e.tier == v then return e.name end
  end
  return "#" .. tostring(v)
end

local function NextTier(cur)
  local values = { 0, -1 }
  for _, e in ipairs(SB.Scene.ArtCatalog() or {}) do values[#values + 1] = e.tier end
  return Next(values, cur)
end

local function StatusText()
  local db = SB.db
  local lines = {}
  local state
  if SB.SuiteDisabled() then state = "|cFFFF7F7F" .. T("ST_SUITE_OFF", "décoché dans TibiSuite (/ts modules)") .. "|r"
  elseif not db.enabled then state = "|cFFFF7F7F" .. T("ST_OFF", "désactivé") .. "|r"
  elseif SB.ElvUIAFK() then state = "|cFFFFD700" .. T("ST_ELVUI", "en retrait : l'écran d'absence d'ElvUI est actif") .. "|r"
  else state = "|cFF66D98A" .. T("ST_ON", "actif") .. "|r" end
  lines[1] = T("ST_STATE", "État : ") .. state
  if db.safeMode then lines[#lines + 1] = "|cFFFFD700" .. T("ST_SAFE", "Mode sûr : l'interface n'est plus masquée.") .. "|r" end
  local tot = SB.Totals()
  if tot.count > 0 then
    lines[#lines + 1] = string.format(T("ST_TOTALS", "%d absences, %s au total, record %s"),
      tot.count, SB.FormatDuration(tot.total), SB.FormatDuration(tot.longest))
    if tot.last then
      lines[#lines + 1] = string.format(T("ST_LAST", "Dernière : %s le %s, %d message(s)"),
        SB.FormatDuration(tot.last.dur), date("%d/%m %H:%M", tot.last.at), tot.last.msgs or 0)
    end
  else
    lines[#lines + 1] = T("ST_NONE", "Aucune absence enregistrée sur ce personnage.")
  end
  return table.concat(lines, "\n")
end

local function Build()
  local UI = _G.TibiMidnight
  if not UI then return nil end
  local db = SB.db
  local p = UI.CreateOptionsPanel({ name = "StandbyMainFrame", title = "Standby", accent = SB.ACCENT, logo = SB.LOGO })
  p.frame:SetSize(330, 560)

  -- Etat (texte rafraichi a chaque ouverture)
  local st = p.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  st:SetPoint("TOPLEFT", p.content, "TOPLEFT", 6, p._y)
  st:SetWidth(262); st:SetJustifyH("LEFT"); st:SetSpacing(3)
  p._refresh[#p._refresh + 1] = function() st:SetText(StatusText()) end
  st:SetText(StatusText())
  p._y = p._y - 64

  p:Button(T("BTN_PREVIEW", "Aperçu (15 secondes)"), function() SB.Preview() end)
  p:Check(T("OPT_ENABLED", "Afficher l'écran quand je suis absent"),
    function() return db.enabled end, function(v) SB.SetEnabled(v) end)

  p:Section(T("SEC_LOOK", "Apparence"))
  Cycle(p, function() return T("OPT_LAYOUT", "Mise en page : ") .. LAYOUT_LABEL[db.layout] end,
    function() db.layout = Next(SB.LAYOUTS, db.layout) end,
    { title = T("HELP_LAYOUT_T", "Mises en page"), list = SB.LAYOUTS, labels = LAYOUT_LABEL,
      texts = LAYOUT_HELP, current = function() return db.layout end })
  Cycle(p, function() return T("OPT_BG", "Fond : ") .. BG_LABEL[db.background] end,
    function() db.background = Next(SB.BACKGROUNDS, db.background) end,
    { title = T("HELP_BG_T", "Fonds"), list = SB.BACKGROUNDS, labels = BG_LABEL,
      texts = BG_HELP, current = function() return db.background end })
  Cycle(p, function() return T("OPT_ART", "Illustration : ") .. TierLabel(db.artTier) end,
    function() db.artTier = NextTier(db.artTier) end, ART_HELP)
  p:Check(T("OPT_SLIDESHOW", "Diaporama : alterner Vitrine et Fiche"),
    function() return db.slideshow end, function(v) db.slideshow = v end,
    T("TT_SLIDESHOW", "Actif quand la mise en page choisie est Vitrine ou Fiche."))
  p:Slider(T("OPT_SLIDE_SEC", "Secondes entre deux mises en page"), 10, 300, 5,
    function() return db.slideSec end, function(v) db.slideSec = v end)
  p:Slider(T("OPT_ART_EVERY", "Nouvelle illustration toutes les (min, 0 = jamais)"), 0, 30, 1,
    function() return db.artEvery end, function(v) db.artEvery = v end)
  p:Note(T("NOTE_ART", "Les illustrations viennent du journal des aventures du jeu : rien n'est ajouté au poids de l'addon. La mise en page Économie impose un fond noir."))
  p:Check(T("OPT_MODEL", "Personnage en 3D (fonds Illustration et Noir)"),
    function() return db.showModel end, function(v) db.showModel = v end)
  p:Check(T("OPT_TITLE", "Titre sous le nom"),
    function() return db.showTitle end, function(v) db.showTitle = v end)
  p:Check(T("OPT_SHEET", "Spécialisation, niveau d'objet et stats sous le nom (Vitrine)"),
    function() return db.showSheet end, function(v) db.showSheet = v end)
  p:Check(T("OPT_MESSAGES", "Journal des messages reçus"),
    function() return db.messages end, function(v) db.messages = v end)
  p:Check(T("OPT_PRIVACY", "Mode discret (nom, guilde, royaume, or)"),
    function() return db.privacy end, function(v) db.privacy = v end,
    T("TT_PRIVACY", "Pour le streaming ou les captures d'écran."))
  p:Check(T("OPT_CLASSCOLOR", "Nom à la couleur de la classe"),
    function() return db.classColor end, function(v) db.classColor = v end)

  p:Section(T("SEC_TILES", "Tuiles (mise en page Vitrine)"))
  for _, key in ipairs(SB.TILE_ORDER) do
    p:Check(SB.Tiles.LABELS[key], function() return db.tiles[key] end, function(v) db.tiles[key] = v end)
  end

  p:Section(T("SEC_TRIGGER", "Déclenchement"))
  p:Slider(T("OPT_DELAY", "Délai après le passage en Absent (s)"), 0, 120, 1,
    function() return db.delay end, function(v) db.delay = v end)
  p:Check(T("OPT_SKIP_INSTANCE", "Pas en instance (donjon, raid, gouffre, JcJ)"),
    function() return db.skipInstance end, function(v) db.skipInstance = v end)
  p:Check(T("OPT_SKIP_RAID", "Pas en raid"),
    function() return db.skipRaid end, function(v) db.skipRaid = v end)
  p:Check(T("OPT_SKIP_GROUP", "Pas en groupe"),
    function() return db.skipGroup end, function(v) db.skipGroup = v end)
  p:Note(T("NOTE_ALERTS", "L'écran s'écarte tout seul : file prête, appel, convocation, invitation, combat, mort, échange, duel. Jamais d'entrée en combat."))

  p:Section(T("SEC_SCENE", "Fond Scène"))
  p:Check(T("OPT_HIDEUI", "Masquer l'interface du jeu"),
    function() return db.hideUI end, function(v) db.hideUI = v end,
    T("TT_HIDEUI", "Décoché : un voile sombre recouvre l'interface à la place."))
  p:Check(T("OPT_SPIN", "Rotation lente de la caméra"),
    function() return db.spin end, function(v) db.spin = v end)
  p:Slider(T("OPT_SPIN_SPEED", "Vitesse de rotation"), 1, 10, 1,
    function() return db.spinSpeed end, function(v) db.spinSpeed = v end)

  p:Section(T("SEC_ECO", "Économie"))
  p:Check(T("OPT_ECO_ALL", "Économiser aussi dans Vitrine et Épurée"),
    function() return db.ecoAll end, function(v) db.ecoAll = v end)
  p:Slider(T("OPT_ECO_FPS", "Images par seconde pendant l'absence"), 5, 60, 5,
    function() return db.ecoFPS end, function(v) db.ecoFPS = v end)
  p:Check(T("OPT_ECO_AMB", "Couper les sons d'ambiance"),
    function() return db.ecoAmbience end, function(v) db.ecoAmbience = v end)
  p:Note(T("NOTE_ECO", "Vos réglages d'origine sont rétablis au retour, et au prochain login en cas de coupure."))

  p:Section(T("SEC_MISC", "Divers"))
  p:Check(T("OPT_RECAP", "Résumé dans le chat au retour"),
    function() return db.recap end, function(v) db.recap = v end)
  p:Button(T("BTN_SAFE_RESET", "Réessayer le masquage de l'interface"), function()
    db.safeMode = nil
    SB.Print(T("MSG_SAFE_RESET", "mode sûr levé : l'interface sera de nouveau masquée sur le fond Scène."))
    p:Refresh()
  end)
  p:Button(T("BTN_PROBE", "Vérification en jeu (/standby probe)"), function() SB.RunProbe() end)
  return p
end

local function Get()
  if not panel then panel = Build() end
  return panel
end

function Standby_Toggle()
  local p = Get()
  if p then p:Toggle() end
end

function Standby_OpenOptions()
  local p = Get()
  if p then p:Show() end
end
