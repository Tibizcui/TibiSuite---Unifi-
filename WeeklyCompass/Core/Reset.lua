local addonName, ns = ...

ns.Reset = ns.Reset or {}
local Reset = ns.Reset

-- Identifiant de la semaine courante = horodatage serveur du PROCHAIN reset.
-- Propriete utile : cette valeur est constante toute la semaine (quand "now"
-- avance d'une seconde, "secondsUntil" recule d'une seconde), puis saute d'une
-- semaine pile au moment du reset. C'est donc un identifiant de periode fiable.
--
-- API utilisee : C_DateAndTime.GetSecondsUntilWeeklyReset(). Stable depuis
-- plusieurs extensions et absente de la liste des retraits 12.1.0. Le garde
-- ci-dessous evite tout crash si son nom venait a changer sur la build live.
function Reset:GetCurrentPeriodId()
    local now = GetServerTime()
    local secs
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
    end
    if not secs or secs <= 0 then
        -- Repli defensif uniquement (ne devrait jamais servir en pratique) :
        -- un seau hebdomadaire brut, a retirer une fois l'API validee sur le PTR.
        return math.floor(now / (7 * 24 * 3600))
    end
    return now + secs
end

-- Deux horodatages appartiennent a la meme semaine si tres proches.
-- La tolerance absorbe la micro variation d'un appel a l'autre, sans risque de
-- confondre deux semaines distinctes (separees de 604800 s).
function Reset:IsSamePeriod(a, b)
    if not a or not b then return false end
    return math.abs(a - b) < 120
end

-- Verifie la periode du perso courant et remet a zero proprement si on a
-- franchi un reset depuis la derniere ecriture.
function Reset:EnsureCurrentPeriod()
    local char = ns.DB:GetChar()
    if not char then return end

    local current = self:GetCurrentPeriodId()
    if not self:IsSamePeriod(char.periodId, current) then
        wipe(char.entries)
        char.periodId = current
        ns:Debug("Nouveau reset hebdomadaire detecte (periode %s).", tostring(current))
        ns:SendMessage("WC_PERIOD_RESET", current)
    end
end
