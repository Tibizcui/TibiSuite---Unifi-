local addonName, ns = ...

-- Manifeste pilote par la donnee.
--
-- C'est ICI qu'on active, desactive ou reordonne une activite, sans jamais
-- toucher au journal, au registre ni a l'interface. "reason" documente pourquoi
-- une activite est encore en attente : la regle S2 correspondante n'est pas
-- figee sur le PTR 12.1, donc son module ne fournit pas encore de vraie donnee.
--
-- Passer une activite a enabled=true une fois son API validee suffit a la faire
-- apparaitre pleinement dans le tableau de bord. Ajouter une activite = deposer
-- un module dans Data/Activities/, l'inscrire dans le .toc, et l'ajouter ici.
ns.ActivityManifest = {
    { key = "greatVault", enabled = true },
    { key = "lairs",      enabled = false, reason = "API Repaires S2 a confirmer sur le PTR 12.1" },
    { key = "delves",     enabled = false, reason = "API Gouffres (variantes Nemesis / Bountiful) a confirmer" },
    { key = "huntRanks",  enabled = false, reason = "API rangs de la Traque a confirmer" },
}
