--[[============================================================================
  ReadyUp - Bridge.lua
  ---------------------------------------------------------------------------
  Liens avec la suite : ligne d'etat du Panneau vivant, apercu du Centre,
  badge de l'onglet, recherche globale, ligne de /ts doctor.
  NON TESTE EN JEU (2026-11-14).
============================================================================]]

local ADDON, RU = ...
local T = RU.T

-- Ligne d'etat (statusFn) : { text, color, urgent }.
function RU.Status()
  local ev = RU.last
  if not (TibiReadyUpDB and ev) then return nil end
  if not RU.IsRunning() then return { text = T("ST_OFF", "désactivé"), color = { 0.6, 0.6, 0.6 } } end
  if ev.issues == 0 then return { text = T("SUM_READY", "Prêt"), color = RU.ACCENT } end
  local r, g, b = RU.StateColor(ev.worst)
  return { text = string.format(T("SUM_ISSUES", "%d point(s) à revoir"), ev.issues), color = { r, g, b }, urgent = ev.worst == "fail" }
end

-- Apercu du Centre TibiSuite (overviewFn) : les 5 controles les plus urgents.
function RU.Overview()
  local out = { lines = {}, empty = T("EMPTY", "Aucun contrôle ne s'applique ici pour l'instant.") }
  local ev = RU.last
  if not (TibiReadyUpDB and ev) then return out end
  local list = {}
  for _, r in ipairs(ev.results) do list[#list + 1] = r end
  table.sort(list, function(a, b) return RU.RANK[a.state] > RU.RANK[b.state] end)
  for i = 1, math.min(5, #list) do
    local r = list[i]
    local cr, cg, cb = RU.StateColor(r.state)
    out.lines[i] = { text = r.label, value = tostring(r.value or ""), color = { cr, cg, cb }, urgent = r.state == "fail" }
  end
  return out
end

-- Badge de l'onglet : nombre de points a revoir (rien si tout va bien).
local lastBadge
RU.listeners[#RU.listeners + 1] = function()
  local TS = _G.TibiSuite
  if not (TS and TS.SetTabBadge and RU.last) then return end
  local n = RU.IsRunning() and RU.last.issues or 0
  if n ~= lastBadge then lastBadge = n; pcall(TS.SetTabBadge, RU.KEY, n) end
end

-- Recherche globale de la suite.
function RU.SearchProvider(query)
  local UI = _G.TibiMidnight
  if not (UI and TibiReadyUpDB) then return {} end
  local out = {}
  local items = {
    { T("BTN_CHECK", "Vérifier"), function() RU.ShowMain() end },
    { T("BTN_TEST", "Voir l'alerte"), function() local ev = RU.Evaluate("manual"); if ev then RU.ShowToast(ev, true) end end },
    { T("CHK_DUR", "Usure de l'équipement"), function() RU.ShowMain() end },
    { T("CHK_FOOD", "Nourriture"), function() RU.ShowMain() end },
    { T("CHK_FLASK", "Flacon ou élixir"), function() RU.ShowMain() end },
    { T("CHK_PET", "Familier"), function() RU.ShowMain() end },
    { T("CHK_REAGENTS", "Composants"), function() RU.ShowMain() end },
  }
  for _, c in ipairs(items) do
    if UI.Match(c[1] .. " readyup ready", query) then out[#out + 1] = { text = "ReadyUp : " .. c[1], onClick = c[2] } end
  end
  return out
end

-- /ts doctor : texte, probleme (booleen)
function TibiReadyUp_DoctorNote()
  if not TibiReadyUpDB then return T("DOC_NODB", "sauvegarde pas encore chargée"), true end
  if not RU.IsRunning() then return T("ST_OFF", "désactivé"), false end
  local ev = RU.last
  if not ev then return T("DOC_WAIT", "pas encore de vérification"), false end
  return string.format(T("DOC_LINE", "%d contrôle(s) actif(s), %d point(s) à revoir (%s)"),
    #ev.results, ev.issues, RU.ContextLabel(ev.context)), false
end
