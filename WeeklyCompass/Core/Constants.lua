local addonName, ns = ...

ns.Const = ns.Const or {}
local C = ns.Const

-- Statut normalise d'une entree du journal. Toute activite parle ce langage,
-- et le journal comme l'interface n'ont besoin de rien connaitre de plus.
C.Status = {
    UNKNOWN     = "unknown",      -- donnee indisponible (API S2 non figee, hors perimetre, erreur)
    NOT_STARTED = "not_started",
    IN_PROGRESS = "in_progress",
    DONE        = "done",
}

-- Couleurs de statut, volontairement sobres et lisibles d'un coup d'oeil.
-- {r, g, b} sur 0..1.
C.StatusColor = {
    [C.Status.UNKNOWN]     = { 0.55, 0.55, 0.58 },
    [C.Status.NOT_STARTED] = { 0.82, 0.44, 0.40 },
    [C.Status.IN_PROGRESS] = { 0.87, 0.69, 0.32 },
    [C.Status.DONE]        = { 0.42, 0.73, 0.48 },
}

-- Pistes d'amelioration, du plus bas au plus haut palier. On CLASSE par piste
-- (identite stable du jeu : Explorateur -> Aventurier -> Veteran -> Champion ->
-- Heros -> Mythique), jamais par un seuil d'ilevel code en dur. Les ilevels de
-- la S2 ne sont pas figes, mais l'echelle des pistes, elle, l'est. C'est ce qui
-- permet de colorer un objet par palier absolu (Mythique toujours en haut) sans
-- rien inventer. La piste reelle d'un objet est lue via C_Item.GetItemUpgradeInfo.
--
-- color : teinte "type WoW" du palier {r, g, b} sur 0..1 (gris, blanc, vert,
-- bleu, violet, or), du plus bas au plus haut.
C.UpgradeTrack = {
    { key = "explorer",   rank = 1, color = { 0.62, 0.62, 0.62 } },  -- gris
    { key = "adventurer", rank = 2, color = { 1.00, 1.00, 1.00 } },  -- blanc
    { key = "veteran",    rank = 3, color = { 0.12, 1.00, 0.00 } },  -- vert
    { key = "champion",   rank = 4, color = { 0.00, 0.44, 0.87 } },  -- bleu
    { key = "hero",       rank = 5, color = { 0.64, 0.21, 0.93 } },  -- violet
    { key = "myth",       rank = 6, color = { 1.00, 0.50, 0.00 } },  -- or / mythique
}

-- Categories d'affichage (regroupement dans le tableau de bord).
C.Category = {
    VAULT  = "vault",
    LAIRS  = "lairs",
    DELVES = "delves",
    HUNT   = "hunt",
    MISC   = "misc",
}

-- Ordre d'affichage des categories (plus petit = plus haut).
C.CategoryOrder = {
    [C.Category.VAULT]  = 10,
    [C.Category.LAIRS]  = 20,
    [C.Category.DELVES] = 30,
    [C.Category.HUNT]   = 40,
    [C.Category.MISC]   = 90,
}
