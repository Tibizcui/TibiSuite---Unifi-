-- ================================================================
--  SkillTracker  -  Concentration.lua
--  Concentration de TOUS les personnages, meme deconnectes.
--
--  Principe honnete : aucune vitesse de recharge n'est codee en dur. Chaque
--  lecture reelle est horodatee ; quand deux lectures d'un meme metier sont
--  espacees d'au moins 30 min sans depense entre les deux, on en deduit un
--  echantillon de vitesse (fraction du max par seconde). La vitesse retenue
--  est le PLUS GRAND des 7 derniers echantillons : une depense glissee entre
--  deux lectures ne peut que faire baisser un echantillon, jamais le gonfler.
--  Tant qu'aucune vitesse n'est apprise, on affiche la derniere valeur lue
--  et son anciennete, sans projection.
-- ================================================================

local _, ST = ...
local L = ST.L

local MIN_DT, MAX_DT = 1800, 3 * 86400
local MAX_SAMPLES = 7

-- Vitesse apprise (fraction du max par seconde), ou nil.
function ST.ConcRate()
  local r = ST.db and ST.db.concRate
  if type(r) == "table" and type(r.rate) == "number" and r.rate > 0 then return r.rate end
  return nil
end

local function AddSample(s)
  local r = ST.db.concRate
  r.samples = r.samples or {}
  table.insert(r.samples, s)
  while #r.samples > MAX_SAMPLES do table.remove(r.samples, 1) end
  local best = 0
  for _, v in ipairs(r.samples) do if v > best then best = v end end
  r.rate = (best > 0) and best or nil
  r.t = time()
end

-- Enregistre une lecture reelle { cur, max, currencyID } pour un metier.
function ST.ConcRecord(prof, reading)
  local now = time()
  local cur, max = reading.cur or 0, reading.max or 0
  if max <= 0 then return end

  local a = prof.concAnchor
  local resetAnchor = true
  if a and a.max == max and a.cur < max and cur >= a.cur then
    local dt = now - (a.t or now)
    if dt >= MIN_DT and dt <= MAX_DT and cur < max then
      local gain = cur - a.cur
      if gain > 0 then AddSample((gain / max) / dt) end
      -- echantillon pris : le point de depart repart d'ici
    elseif dt < MIN_DT then
      resetAnchor = false   -- trop tot : on garde l'ancre pour cumuler du temps
    end
  end
  if resetAnchor then
    -- Nouveau point de depart (premiere lecture, depense, max change, ou plein).
    prof.concAnchor = { cur = cur, max = max, t = now }
  end

  prof.conc = { cur = cur, max = max, currencyID = reading.currencyID or prof.concCid, t = now }
end

-- Projection a l'instant present. Renvoie nil si aucune lecture, sinon :
--   { cur, max, full, fullIn (s, nil si inconnu), fullSince (s), age (s), hasRate }
function ST.ConcProject(prof, now)
  local c = type(prof) == "table" and prof.conc
  if not c or (c.max or 0) <= 0 then return nil end
  now = now or time()
  local age = math.max(0, now - (c.t or now))
  local rate = ST.ConcRate()
  local out = { max = c.max, age = age, hasRate = rate and true or false }
  if rate then
    local perSec = rate * c.max
    local proj = c.cur + perSec * age
    if proj >= c.max then
      out.cur, out.full = c.max, true
      out.fullSince = age - (c.max - c.cur) / perSec
    else
      out.cur = math.floor(proj)
      out.fullIn = (c.max - proj) / perSec
    end
  else
    out.cur = c.cur
    out.full = c.cur >= c.max
  end
  return out
end

-- Toutes les concentrations connues (persos locaux, metiers principaux),
-- pleines d'abord (les plus anciennes en tete), puis les plus proches du plein.
function ST.ConcList()
  local out = {}
  if not ST.db then return out end
  local curRealm, curName = ST.CurrentCharKey()
  local now = time()
  for realm, list in pairs(ST.db.chars) do
    for name, rec in pairs(list) do
      for parent, prof in pairs(type(rec) == "table" and rec.professions or {}) do
        if prof.isPrimary then
          local pr = ST.ConcProject(prof, now)
          if pr then
            out[#out + 1] = {
              realm = realm, name = name, class = rec.class, parent = parent,
              prof = prof.name or "?", pr = pr,
              current = (realm == curRealm and name == curName),
            }
          end
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.pr.full ~= b.pr.full then return a.pr.full end
    if a.pr.full then return (a.pr.fullSince or 0) > (b.pr.fullSince or 0) end
    local fa, fb = a.pr.fullIn or math.huge, b.pr.fullIn or math.huge
    if fa ~= fb then return fa < fb end
    return a.name < b.name
  end)
  return out
end

-- Duree lisible et courte : "3 j 4 h", "5 h 12 min", "8 min".
function ST.FormatDuration(s)
  s = math.max(0, math.floor(s or 0))
  local d = math.floor(s / 86400)
  local h = math.floor((s % 86400) / 3600)
  local m = math.floor((s % 3600) / 60)
  if d > 0 then return string.format(L.DUR_DH, d, h) end
  if h > 0 then return string.format(L.DUR_HM, h, m) end
  return string.format(L.DUR_M, m)
end

-- Texte d'etat d'une projection : "PLEINE depuis 2 j", "pleine dans 5 h"...
function ST.ConcStatusText(pr)
  if not pr then return "" end
  if pr.full then
    if pr.fullSince and pr.fullSince > 60 then
      return string.format(L.CONC_FULL_SINCE, ST.FormatDuration(pr.fullSince))
    end
    return L.CONC_FULL_TAG
  end
  if pr.fullIn then return string.format(L.CONC_FULL_IN, ST.FormatDuration(pr.fullIn)) end
  return string.format(L.CONC_SEEN_AGO, ST.FormatDuration(pr.age))
end

-- Nombre de concentrations pleines (tous persos locaux).
function ST.ConcFullCount()
  local n = 0
  for _, e in ipairs(ST.ConcList()) do if e.pr.full then n = n + 1 end end
  return n
end

-- Pastille d'onglet de la suite (si le core est la).
function ST.UpdateBadge()
  if not (ST.settings and _G.TibiSuite and _G.TibiSuite.SetTabBadge) then return end
  local n = ST.settings.badge and ST.ConcFullCount() or 0
  pcall(_G.TibiSuite.SetTabBadge, "Skill", n)
end

-- Au login : une ligne pour les alts dont la concentration est (projetee) pleine.
-- Le perso connecte a deja son alerte dediee (Core.lua).
function ST.AltConcAlert()
  if not (ST.settings and ST.settings.concAltAlert) then return end
  local parts = {}
  for _, e in ipairs(ST.ConcList()) do
    if e.pr.full and not e.current then
      local cc = RAID_CLASS_COLORS and e.class and RAID_CLASS_COLORS[e.class]
      local nm = cc and string.format("|cFF%02X%02X%02X%s|r", cc.r * 255, cc.g * 255, cc.b * 255, e.name) or e.name
      parts[#parts + 1] = nm .. " (" .. e.prof .. ")"
    end
  end
  if #parts > 0 then
    print(ST.TAG .. " " .. L.CONC_ALT_ALERT .. " " .. table.concat(parts, ", "))
  end
end
