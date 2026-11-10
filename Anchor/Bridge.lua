--[[============================================================================
  Anchor - Bridge.lua
  ---------------------------------------------------------------------------
  Liens avec la suite : recherche globale, ligne de /ts doctor, apercu du
  Centre, et sonde /anchor probe (verifie en jeu ce qui n'a pas pu l'etre
  hors client : noms du catalogue, fenetres protegees, cohabitation).
  Valide en jeu par Tibiscui le 2026-11-10 (7.5.0).
============================================================================]]

local ADDON, AN = ...
local T = AN.T

local function CountMoved()
  local n = 0
  if TibiAnchorDB then for _ in pairs(AN.Positions()) do n = n + 1 end end
  return n
end

-- Apercu du Centre TibiSuite (overviewFn)
function AN.Overview()
  local out = { lines = {} }
  if not TibiAnchorDB then return out end
  out.lines[1] = { text = T("OV_MOVED", "Fenêtres déplacées"), value = tostring(CountMoved()) }
  out.lines[2] = { text = T("OV_LAYOUT", "Disposition"),
    value = (AN.LayoutKey() == "*" and T("LAYOUT_ACCOUNT", "compte") or T("LAYOUT_CHAR", "ce personnage")) .. " / " .. AN.ResKey() }
  return out
end

-- Recherche globale de la suite
function AN.SearchProvider(query)
  local UI = _G.TibiMidnight
  if not (UI and TibiAnchorDB) then return {} end
  local out = {}
  local cmds = {
    { T("BTN_LOOT", "Placer le butin"), function() AN.Loot.Toggle() end },
    { T("BTN_UNDO", "Annuler"), function() AN.Undo() end },
    { T("BTN_RESET_ALL", "Tout remettre"), function() AN.ResetAll() end },
  }
  for _, c in ipairs(cmds) do
    if UI.Match(c[1] .. " anchor", query) then out[#out + 1] = { text = "Anchor : " .. c[1], onClick = c[2] } end
  end
  for _, e in ipairs(AN.CATALOG) do
    local name = AN.NameOf(e) or e.names[1]
    if UI.Match(e.label .. " " .. name .. " anchor", query) then
      local moved = AN.GetPos(name) and (" |cFF888888" .. T("TAG_MOVED", "déplacée") .. "|r") or ""
      out[#out + 1] = { text = "Anchor : " .. e.label .. moved, onClick = function() AN.ShowMain() end }
    end
  end
  return out
end

-- /ts doctor : texte, probleme (booleen)
function TibiAnchor_DoctorNote()
  if not TibiAnchorDB then return T("DOC_NODB", "sauvegarde pas encore chargée"), true end
  if not AN.IsRunning() then return T("DOC_OFF", "désactivé"), false end
  local c = AN.Conflict()
  local hooked = 0
  for _ in pairs(AN.hooked) do hooked = hooked + 1 end
  local txt = string.format(T("DOC_LINE", "%d fenêtre(s) déplacée(s), %d suivie(s), écran %s"), CountMoved(), hooked, AN.ResKey())
  if c and not TibiAnchorDB.force then
    return txt .. string.format(T("DOC_CONFLICT", " ; en retrait : %s est chargé"), c), false
  end
  return txt, false
end

-- /anchor probe
function AN.RunProbe()
  local found, missing, prot, managed = {}, {}, {}, {}
  for _, e in ipairs(AN.CATALOG) do
    local name = AN.NameOf(e)
    if not name then
      missing[#missing + 1] = e.names[1]
    else
      local f = _G[name]
      if AN.Refused(f) then prot[#prot + 1] = name
      else
        local by = AN.ManagedBy(name, f)
        if by then managed[#managed + 1] = name .. " (" .. by .. ")" else found[#found + 1] = name end
      end
    end
  end
  local _, build, _, toc = GetBuildInfo()
  TibiAnchorDB.probe = { at = time(), build = build, toc = toc, found = found, missing = missing, protected = prot, managed = managed }
  AN.Print(string.format(T("PROBE_HEAD", "sonde (interface %s) : %d prises en charge, %d absentes ou pas encore chargées, %d protégées, %d gérées ailleurs."),
    tostring(toc), #found, #missing, #prot, #managed))
  if #prot > 0 then AN.Print(T("PROBE_PROT", "protégées : ") .. table.concat(prot, ", ")) end
  if #managed > 0 then AN.Print(T("PROBE_MANAGED", "gérées ailleurs : ") .. table.concat(managed, ", ")) end
  AN.Print(T("PROBE_SAVED", "détail gardé dans TibiAnchorDB.probe (lisible après /reload)."))
end
