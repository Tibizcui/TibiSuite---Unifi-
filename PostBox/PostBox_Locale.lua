--[[============================================================================
  PostBox_Locale - Chaines localisees + mots-cles de classification du
  courrier de l'Hotel des ventes, selon la langue du CLIENT DE JEU
  (GetLocale()), pas un choix manuel : la suite s'adapte automatiquement a la
  region du joueur.

  Convention reprise de SkillTracker/DailyTracker (deja utilisee ailleurs dans
  la suite) : une table de base COMPLETE (anglais, enUS) sert de filet de
  secours ; chaque langue supplementaire ne fournit que ses propres valeurs,
  et toute cle manquante retombe silencieusement sur l'anglais (jamais de nil
  affiche a l'ecran). PostBox.L est la table finale a utiliser partout.

  IMPORTANT (a verifier en jeu, non teste) : les mots-cles AH_KEYWORDS servent
  a deviner la categorie d'un courrier de l'Hotel des ventes (annule / expire
  / surenchere / vendu / gagne) a partir de l'expediteur et du sujet renvoyes
  par le SERVEUR dans la langue du client - ces libelles exacts n'ont pas pu
  etre verifies en jeu pour l'allemand et l'espagnol (ni meme parfaitement
  pour le francais/anglais) : ce sont des mots-cles plausibles, a ajuster une
  fois testes avec du vrai courrier d'Hotel des ventes dans chaque langue.
============================================================================]]

PostBox = PostBox or {}

-- ============================================================================
-- BASE ANGLAISE (complete - sert de filet de secours pour toute langue non
-- traduite integralement, y compris les regions non listees ci-dessous)
-- ============================================================================
local BASE = {
  -- Fenetre principale
  WINDOW_COUNT_FMT        = "%d mails - %s collected this session",
  BTN_OPENALL             = "Open All",
  BTN_PROCESS_SELECTION   = "Process Selection",
  BTN_BLACKBOOK           = "BlackBook",
  BTN_STATS               = "Stats",
  BTN_COLLECT_UNSOLD      = "Collect Unsold",
  BTN_DELETE_SELECTION    = "Delete",
  BTN_REFRESH             = "Refresh",
  COL_SENDER              = "Sender",
  COL_ITEM                = "Item",
  FILTER_CANCELLED        = "Cancelled",
  FILTER_EXPIRED          = "Expired",
  FILTER_OUTBID           = "Outbid",
  FILTER_SOLD             = "Sold",
  FILTER_WON              = "Won",
  FILTER_OTHER            = "Other",
  MSG_OPENALL_START       = "|cffFFB347[PostBox]|r Opening all mail...",
  MSG_OPENALL_BAGSFULL_FMT= "|cffFF8040[PostBox]|r Stopped: bag reserve reached (%d free slots requested).",
  POPUP_COD_RETURN_TEXT   = "This mail has a cash-on-delivery charge of %s. Return it anyway?",
  POPUP_COD_OPEN_TEXT     = "Accept this cash-on-delivery charge of %s?",
  RECAP_TITLE             = "Loot Recovered",
  RECAP_GOLD_FMT          = "Gold: %s",
  RECAP_NO_GOLD           = "No gold collected.",
  MSG_DNW_RETURNED_FMT    = "|cffFF8040[PostBox]|r %d unwanted item(s) automatically returned.",
  MSG_DELETE_RESULT_FMT   = "|cffFFD700[PostBox]|r %d mail(s) deleted.",
  MSG_DELETE_RESULT_SKIPPED_FMT = "|cffFFD700[PostBox]|r %d mail(s) deleted, %d skipped (unclaimed gold/items).",
  MSG_DELETE_RESULT_FAILED_FMT = "|cffFF5555[PostBox]|r %d mail(s) deleted, %d FAILED (server refused or unsupported).",
  PREVIEW_TOOLTIP         = "Click to read the letter",
  PREVIEW_LOADING         = "Loading...",
  PREVIEW_UNAVAILABLE     = "Content unavailable (not yet loaded by the server).",
  PREVIEW_PLACEHOLDER     = "Click a subject to read its content.",
  PREVIEW_NAV_HINT        = "Up / Down arrows: previous / next mail",
  PREVIEW_PREV            = "< Previous",
  PREVIEW_NEXT            = "Next >",

  -- Panneau d'options
  OPT_TITLE               = "PostBox - Options",
  OPT_SEC_OPENALL         = "Mass Opening",
  OPT_RESERVE_SLOTS       = "Bag slots to reserve",
  OPT_AUTORETURN_DNW      = "Automatically return unwanted items (DoNotWant)",
  OPT_SEC_SECURITY        = "Safety",
  OPT_COD_THRESHOLD       = "COD confirmation threshold (in gold)",
  OPT_EXPIRY_DAYS         = "Expiry warning (days left)",
  OPT_SEC_DISPLAY         = "Display",
  OPT_SMART_SORT          = "Smart sort (urgency, type, sender)",
  OPT_SEC_SESSION         = "Session",
  OPT_SESSION_NOTE        = "Gold collected this session: updated live in the main window.",
  OPT_RESET_RAKE          = "Reset counter (Rake)",
  OPT_SEC_MAILBOX         = "Mailbox",
  OPT_REPLACE_MAILBOX     = "Replace the native mailbox with PostBox",
  OPT_REPLACE_MAILBOX_NOTE= "Experimental: visually hides the native window (without touching it technically) while PostBox is open. Sending mail still uses the native Send Mail tab (no public API lets an addon attach gold/items otherwise). If Escape or clicks ever stop responding, /reload immediately.",

  -- BlackBook
  BB_TITLE                = "BlackBook",
  BB_ADD                  = "Add",
  BB_SEC_CONTACTS         = "Contacts",
  BB_SEC_ALTS             = "Alts (same realm/faction)",
  BB_SEC_RECENT           = "Recent Recipients",
  MSG_OPEN_MAILBOX_FIRST  = "|cffFF8040[PostBox]|r Open the mailbox first to use quick send.",
  MSG_OPEN_SEND_TAB_FIRST = "|cffFF8040[PostBox]|r Open the Send Mail tab to attach an item.",
  MSG_FORWARD_ITEMS_TAKEN = "|cffFFD700[PostBox]|r Items collected into your bags: attach them manually (Alt-click) then click Send.",
  FORWARD_SUBJECT_PREFIX  = "Fwd: ",
  MSG_CARBONCOPY_FMT      = "|cffFFD700[PostBox]|r CarbonCopy %d/%d -> %s. Click Send, then run the next one.",

  -- Stats
  STATS_TITLE             = "Mail Statistics",
  STATS_GOLD_RECEIVED_FMT = "Total gold received: %s",
  STATS_GOLD_SENT_FMT     = "Total gold sent: %s",
  STATS_AH_SOLD_FMT       = "Auction House sales: %s",
  STATS_AH_BOUGHT_FMT     = "Auction House purchases: %s",
  STATS_SESSION_RAKE_FMT  = "Current session (Rake): %s",
  STATS_NET_FMT           = "Net revenue (account): %s",
  STATS_TOP_SENDERS       = "Top senders:",
  STATS_HISTORY_TITLE     = "History (last 7 days, AH sales)",
  STATS_NET_7D_FMT        = "Net (7d): %s",
  STATS_CHARS_TITLE       = "By character",
  STATS_CHARS_EMPTY       = "  No data yet - open PostBox at least once on each character.",

  -- Bouton minimap / AddonCompartment / tooltips
  MM_TOOLTIP_LEFT         = "Left-click: open/close",
  MM_TOOLTIP_RIGHT        = "Right-click: options",
  AC_TOOLTIP              = "Click to open/close the mailbox.",
}

-- ============================================================================
-- SURCHARGES PAR LANGUE (uniquement les valeurs qui different de l'anglais ;
-- toute cle absente ici retombe automatiquement sur BASE)
-- ============================================================================
local OVERRIDES = {}

OVERRIDES.frFR = {
  WINDOW_COUNT_FMT        = "%d courriers - %s ramasse cette session",
  BTN_OPENALL             = "Tout ouvrir",
  BTN_PROCESS_SELECTION   = "Traiter selection",
  BTN_BLACKBOOK           = "Carnet",
  BTN_STATS               = "Stats",
  BTN_COLLECT_UNSOLD      = "Recuperer invendus",
  BTN_DELETE_SELECTION    = "Supprimer",
  BTN_REFRESH             = "Actualiser",
  COL_SENDER              = "Expediteur",
  COL_ITEM                = "Objets",
  FILTER_CANCELLED        = "Annulees",
  FILTER_EXPIRED          = "Expirees",
  FILTER_OUTBID           = "Surencheries",
  FILTER_SOLD             = "Vendues",
  FILTER_WON              = "Gagnees",
  FILTER_OTHER            = "Autres",
  MSG_OPENALL_START       = "|cffFFB347[PostBox]|r Ouverture en masse en cours...",
  MSG_OPENALL_BAGSFULL_FMT= "|cffFF8040[PostBox]|r Arret : reserve de sacs atteinte (%d slots libres demandes).",
  POPUP_COD_RETURN_TEXT   = "Ce courrier porte un contre-remboursement de %s. Le retourner quand meme ?",
  POPUP_COD_OPEN_TEXT     = "Accepter ce contre-remboursement de %s ?",
  RECAP_TITLE             = "Butin recupere",
  RECAP_GOLD_FMT          = "Or : %s",
  RECAP_NO_GOLD           = "Aucun or ramasse.",
  MSG_DNW_RETURNED_FMT    = "|cffFF8040[PostBox]|r %d objet(s) indesirable(s) retourne(s) automatiquement.",
  MSG_DELETE_RESULT_FMT   = "|cffFFD700[PostBox]|r %d courrier(s) supprime(s).",
  MSG_DELETE_RESULT_SKIPPED_FMT = "|cffFFD700[PostBox]|r %d courrier(s) supprime(s), %d ignore(s) (or/objet non recupere).",
  MSG_DELETE_RESULT_FAILED_FMT = "|cffFF5555[PostBox]|r %d courrier(s) supprime(s), %d ECHEC(S) (refuse par le serveur ou non supporte).",
  PREVIEW_TOOLTIP         = "Clique pour lire la lettre",
  PREVIEW_LOADING         = "Chargement...",
  PREVIEW_UNAVAILABLE     = "Contenu indisponible (pas encore recu du serveur).",
  PREVIEW_PLACEHOLDER     = "Clique sur un sujet pour lire son contenu.",
  PREVIEW_NAV_HINT        = "Fleches Haut / Bas : courrier precedent / suivant",
  PREVIEW_PREV            = "< Precedent",
  PREVIEW_NEXT            = "Suivant >",

  OPT_TITLE               = "PostBox - Options",
  OPT_SEC_OPENALL         = "Ouverture en masse",
  OPT_RESERVE_SLOTS       = "Slots de sac a reserver",
  OPT_AUTORETURN_DNW      = "Retourner automatiquement les objets indesirables (DoNotWant)",
  OPT_SEC_SECURITY        = "Securite",
  OPT_COD_THRESHOLD       = "Seuil de confirmation COD (en or)",
  OPT_EXPIRY_DAYS         = "Alerte d'expiration (jours restants)",
  OPT_SEC_DISPLAY         = "Affichage",
  OPT_SMART_SORT          = "Tri intelligent (urgence, type, expediteur)",
  OPT_SEC_SESSION         = "Session",
  OPT_SESSION_NOTE        = "Or ramasse cette session : mis a jour en direct dans la fenetre principale.",
  OPT_RESET_RAKE          = "Remettre a zero le compteur (Rake)",
  OPT_SEC_MAILBOX         = "Boite aux lettres",
  OPT_REPLACE_MAILBOX     = "Remplacer la boite aux lettres native par PostBox",
  OPT_REPLACE_MAILBOX_NOTE= "Experimental : masque visuellement la fenetre native (sans y toucher techniquement) pendant que PostBox est ouvert. L'envoi de courrier reste sur l'onglet natif Envoyer (aucune API publique ne permet a un addon de joindre or/objets autrement). En cas de blocage (Echap ou clic qui ne repond plus), fais /reload immediatement.",

  BB_TITLE                = "Carnet (BlackBook)",
  BB_ADD                  = "Ajouter",
  BB_SEC_CONTACTS         = "Contacts",
  BB_SEC_ALTS             = "Alts (meme royaume/faction)",
  BB_SEC_RECENT           = "Destinataires recents",
  MSG_OPEN_MAILBOX_FIRST  = "|cffFF8040[PostBox]|r Ouvre d'abord la boite aux lettres pour utiliser l'envoi rapide.",
  MSG_OPEN_SEND_TAB_FIRST = "|cffFF8040[PostBox]|r Ouvre l'onglet Envoyer de la boite aux lettres pour joindre un objet.",
  MSG_FORWARD_ITEMS_TAKEN = "|cffFFD700[PostBox]|r Objets recuperes dans les sacs : joins-les manuellement (Alt-clic) puis clique Envoyer.",
  FORWARD_SUBJECT_PREFIX  = "Tr: ",
  MSG_CARBONCOPY_FMT      = "|cffFFD700[PostBox]|r CarbonCopy %d/%d -> %s. Clique Envoyer, puis relance pour le suivant.",

  STATS_TITLE             = "Statistiques de courrier",
  STATS_GOLD_RECEIVED_FMT = "Or recu au total : %s",
  STATS_GOLD_SENT_FMT     = "Or envoye au total : %s",
  STATS_AH_SOLD_FMT       = "Ventes Hotel des ventes : %s",
  STATS_AH_BOUGHT_FMT     = "Achats Hotel des ventes : %s",
  STATS_SESSION_RAKE_FMT  = "Session en cours (Rake) : %s",
  STATS_NET_FMT           = "Revenu net (compte) : %s",
  STATS_TOP_SENDERS       = "Top expediteurs :",
  STATS_HISTORY_TITLE     = "Historique (7 derniers jours, ventes HV)",
  STATS_NET_7D_FMT        = "Net (7j) : %s",
  STATS_CHARS_TITLE       = "Par personnage",
  STATS_CHARS_EMPTY       = "  Aucune donnee pour l'instant - ouvre PostBox au moins une fois sur chaque personnage.",

  MM_TOOLTIP_LEFT         = "Clic gauche : ouvrir/fermer",
  MM_TOOLTIP_RIGHT        = "Clic droit : options",
  AC_TOOLTIP              = "Clic pour ouvrir/fermer la boite aux lettres.",
}

OVERRIDES.deDE = {
  WINDOW_COUNT_FMT        = "%d Briefe - %s in dieser Sitzung eingenommen",
  BTN_OPENALL             = "Alles offnen",
  BTN_PROCESS_SELECTION   = "Auswahl bearbeiten",
  BTN_BLACKBOOK           = "Adressbuch",
  BTN_STATS               = "Statistik",
  BTN_COLLECT_UNSOLD      = "Unverkaufte einsammeln",
  BTN_DELETE_SELECTION    = "Loschen",
  BTN_REFRESH             = "Aktualisieren",
  COL_SENDER              = "Absender",
  COL_ITEM                = "Objekt",
  FILTER_CANCELLED        = "Storniert",
  FILTER_EXPIRED          = "Abgelaufen",
  FILTER_OUTBID           = "Uberboten",
  FILTER_SOLD             = "Verkauft",
  FILTER_WON              = "Ersteigert",
  FILTER_OTHER            = "Sonstige",
  MSG_OPENALL_START       = "|cffFFB347[PostBox]|r Post wird geoffnet...",
  MSG_OPENALL_BAGSFULL_FMT= "|cffFF8040[PostBox]|r Gestoppt: Taschenreserve erreicht (%d freie Platze gefordert).",
  POPUP_COD_RETURN_TEXT   = "Dieser Brief hat eine Nachnahmegebuhr von %s. Trotzdem zuruckschicken?",
  POPUP_COD_OPEN_TEXT     = "Diese Nachnahmegebuhr von %s akzeptieren?",
  RECAP_TITLE             = "Erhaltene Beute",
  RECAP_GOLD_FMT          = "Gold: %s",
  RECAP_NO_GOLD           = "Kein Gold eingenommen.",
  MSG_DNW_RETURNED_FMT    = "|cffFF8040[PostBox]|r %d unerwunschte(s) Objekt(e) automatisch zuruckgeschickt.",
  MSG_DELETE_RESULT_FMT   = "|cffFFD700[PostBox]|r %d Brief(e) geloscht.",
  MSG_DELETE_RESULT_SKIPPED_FMT = "|cffFFD700[PostBox]|r %d Brief(e) geloscht, %d ubersprungen (Gold/Objekt noch nicht abgeholt).",
  MSG_DELETE_RESULT_FAILED_FMT = "|cffFF5555[PostBox]|r %d Brief(e) geloscht, %d FEHLGESCHLAGEN (vom Server abgelehnt oder nicht unterstutzt).",
  PREVIEW_TOOLTIP         = "Klicken, um den Brief zu lesen",
  PREVIEW_LOADING         = "Wird geladen...",
  PREVIEW_UNAVAILABLE     = "Inhalt nicht verfugbar (noch nicht vom Server erhalten).",
  PREVIEW_PLACEHOLDER     = "Klicke auf einen Betreff, um den Inhalt zu lesen.",
  PREVIEW_NAV_HINT        = "Pfeiltasten Hoch/Runter: vorherige/nachste Post",
  PREVIEW_PREV            = "< Vorherige",
  PREVIEW_NEXT            = "Nachste >",

  OPT_TITLE               = "PostBox - Optionen",
  OPT_SEC_OPENALL         = "Massenoffnung",
  OPT_RESERVE_SLOTS       = "Reservierte Taschenplatze",
  OPT_AUTORETURN_DNW      = "Unerwunschte Objekte automatisch zuruckschicken (DoNotWant)",
  OPT_SEC_SECURITY        = "Sicherheit",
  OPT_COD_THRESHOLD       = "Bestatigungsschwelle fur Nachnahme (in Gold)",
  OPT_EXPIRY_DAYS         = "Ablaufwarnung (verbleibende Tage)",
  OPT_SEC_DISPLAY         = "Anzeige",
  OPT_SMART_SORT          = "Intelligente Sortierung (Dringlichkeit, Typ, Absender)",
  OPT_SEC_SESSION         = "Sitzung",
  OPT_SESSION_NOTE        = "In dieser Sitzung eingenommenes Gold: live im Hauptfenster aktualisiert.",
  OPT_RESET_RAKE          = "Zahler zurucksetzen (Rake)",
  OPT_SEC_MAILBOX         = "Briefkasten",
  OPT_REPLACE_MAILBOX     = "Nativen Briefkasten durch PostBox ersetzen",
  OPT_REPLACE_MAILBOX_NOTE= "Experimentell: blendet das native Fenster nur optisch aus (ohne es technisch zu beruhren), solange PostBox geoffnet ist. Der Versand nutzt weiterhin den nativen Reiter 'Senden' (keine offentliche API erlaubt Addons, Gold/Objekte anders anzuhangen). Falls Escape oder Klicks nicht mehr reagieren, sofort /reload ausfuhren.",

  BB_TITLE                = "Adressbuch (BlackBook)",
  BB_ADD                  = "Hinzufugen",
  BB_SEC_CONTACTS         = "Kontakte",
  BB_SEC_ALTS             = "Zweitcharaktere (gleicher Realm/Fraktion)",
  BB_SEC_RECENT           = "Letzte Empfanger",
  MSG_OPEN_MAILBOX_FIRST  = "|cffFF8040[PostBox]|r Offne zuerst den Briefkasten, um den Schnellversand zu nutzen.",
  MSG_OPEN_SEND_TAB_FIRST = "|cffFF8040[PostBox]|r Offne den Reiter 'Senden' des Briefkastens, um ein Objekt anzuhangen.",
  MSG_FORWARD_ITEMS_TAKEN = "|cffFFD700[PostBox]|r Objekte in die Taschen ubernommen: hange sie manuell an (Alt-Klick), dann klicke Senden.",
  FORWARD_SUBJECT_PREFIX  = "Wg: ",
  MSG_CARBONCOPY_FMT      = "|cffFFD700[PostBox]|r CarbonCopy %d/%d -> %s. Klicke Senden, dann starte den nachsten.",

  STATS_TITLE             = "Poststatistik",
  STATS_GOLD_RECEIVED_FMT = "Gesamt erhaltenes Gold: %s",
  STATS_GOLD_SENT_FMT     = "Gesamt gesendetes Gold: %s",
  STATS_AH_SOLD_FMT       = "Auktionshaus-Verkaufe: %s",
  STATS_AH_BOUGHT_FMT     = "Auktionshaus-Kaufe: %s",
  STATS_SESSION_RAKE_FMT  = "Aktuelle Sitzung (Rake): %s",
  STATS_NET_FMT           = "Nettoertrag (Konto): %s",
  STATS_TOP_SENDERS       = "Top-Absender:",
  STATS_HISTORY_TITLE     = "Verlauf (letzte 7 Tage, AH-Verkaufe)",
  STATS_NET_7D_FMT        = "Netto (7T): %s",
  STATS_CHARS_TITLE       = "Nach Charakter",
  STATS_CHARS_EMPTY       = "  Noch keine Daten - offne PostBox mindestens einmal auf jedem Charakter.",

  MM_TOOLTIP_LEFT         = "Linksklick: offnen/schliessen",
  MM_TOOLTIP_RIGHT        = "Rechtsklick: Optionen",
  AC_TOOLTIP              = "Klicken, um den Briefkasten zu offnen/schliessen.",
}

OVERRIDES.esES = {
  WINDOW_COUNT_FMT        = "%d cartas - %s recolectado en esta sesion",
  BTN_OPENALL             = "Abrir todo",
  BTN_PROCESS_SELECTION   = "Procesar seleccion",
  BTN_BLACKBOOK           = "Agenda",
  BTN_STATS               = "Estadisticas",
  BTN_COLLECT_UNSOLD      = "Recoger no vendidos",
  BTN_DELETE_SELECTION    = "Eliminar",
  BTN_REFRESH             = "Actualizar",
  COL_SENDER              = "Remitente",
  COL_ITEM                = "Objeto",
  FILTER_CANCELLED        = "Canceladas",
  FILTER_EXPIRED          = "Caducadas",
  FILTER_OUTBID           = "Superadas",
  FILTER_SOLD             = "Vendidas",
  FILTER_WON              = "Ganadas",
  FILTER_OTHER            = "Otras",
  MSG_OPENALL_START       = "|cffFFB347[PostBox]|r Abriendo todo el correo...",
  MSG_OPENALL_BAGSFULL_FMT= "|cffFF8040[PostBox]|r Detenido: reserva de bolsas alcanzada (%d espacios libres solicitados).",
  POPUP_COD_RETURN_TEXT   = "Esta carta tiene un reembolso contra entrega de %s. Devolverla de todos modos?",
  POPUP_COD_OPEN_TEXT     = "Aceptar este reembolso contra entrega de %s?",
  RECAP_TITLE             = "Botin recuperado",
  RECAP_GOLD_FMT          = "Oro: %s",
  RECAP_NO_GOLD           = "No se recolecto oro.",
  MSG_DNW_RETURNED_FMT    = "|cffFF8040[PostBox]|r %d objeto(s) no deseado(s) devuelto(s) automaticamente.",
  MSG_DELETE_RESULT_FMT   = "|cffFFD700[PostBox]|r %d correo(s) eliminado(s).",
  MSG_DELETE_RESULT_SKIPPED_FMT = "|cffFFD700[PostBox]|r %d correo(s) eliminado(s), %d omitido(s) (oro/objeto sin recoger).",
  PREVIEW_TOOLTIP         = "Clic para leer la carta",
  PREVIEW_LOADING         = "Cargando...",
  PREVIEW_UNAVAILABLE     = "Contenido no disponible (aun no recibido del servidor).",
  PREVIEW_PLACEHOLDER     = "Haz clic en un asunto para leer su contenido.",
  PREVIEW_NAV_HINT        = "Flechas Arriba / Abajo: correo anterior / siguiente",
  PREVIEW_PREV            = "< Anterior",
  PREVIEW_NEXT            = "Siguiente >",

  OPT_TITLE               = "PostBox - Opciones",
  OPT_SEC_OPENALL         = "Apertura masiva",
  OPT_RESERVE_SLOTS       = "Espacios de bolsa a reservar",
  OPT_AUTORETURN_DNW      = "Devolver automaticamente los objetos no deseados (DoNotWant)",
  OPT_SEC_SECURITY        = "Seguridad",
  OPT_COD_THRESHOLD       = "Umbral de confirmacion de reembolso contra entrega (en oro)",
  OPT_EXPIRY_DAYS         = "Aviso de caducidad (dias restantes)",
  OPT_SEC_DISPLAY         = "Visualizacion",
  OPT_SMART_SORT          = "Orden inteligente (urgencia, tipo, remitente)",
  OPT_SEC_SESSION         = "Sesion",
  OPT_SESSION_NOTE        = "Oro recolectado en esta sesion: actualizado en vivo en la ventana principal.",
  OPT_RESET_RAKE          = "Reiniciar el contador (Rake)",
  OPT_SEC_MAILBOX         = "Buzon",
  OPT_REPLACE_MAILBOX     = "Reemplazar el buzon nativo por PostBox",
  OPT_REPLACE_MAILBOX_NOTE= "Experimental: oculta visualmente la ventana nativa (sin tocarla tecnicamente) mientras PostBox esta abierto. El envio sigue usando la pestana nativa Enviar (ninguna API publica permite a un addon adjuntar oro/objetos de otra forma). Si Escape o los clics dejan de responder, haz /reload de inmediato.",

  BB_TITLE                = "Agenda (BlackBook)",
  BB_ADD                  = "Anadir",
  BB_SEC_CONTACTS         = "Contactos",
  BB_SEC_ALTS             = "Personajes secundarios (mismo reino/faccion)",
  BB_SEC_RECENT           = "Destinatarios recientes",
  MSG_OPEN_MAILBOX_FIRST  = "|cffFF8040[PostBox]|r Abre primero el buzon para usar el envio rapido.",
  MSG_OPEN_SEND_TAB_FIRST = "|cffFF8040[PostBox]|r Abre la pestana Enviar del buzon para adjuntar un objeto.",
  MSG_FORWARD_ITEMS_TAKEN = "|cffFFD700[PostBox]|r Objetos recogidos en las bolsas: adjuntalos manualmente (Alt-clic) y luego pulsa Enviar.",
  FORWARD_SUBJECT_PREFIX  = "Reenv: ",
  MSG_CARBONCOPY_FMT      = "|cffFFD700[PostBox]|r CarbonCopy %d/%d -> %s. Pulsa Enviar y luego continua con el siguiente.",

  STATS_TITLE             = "Estadisticas de correo",
  STATS_GOLD_RECEIVED_FMT = "Oro total recibido: %s",
  STATS_GOLD_SENT_FMT     = "Oro total enviado: %s",
  STATS_AH_SOLD_FMT       = "Ventas en la casa de subastas: %s",
  STATS_AH_BOUGHT_FMT     = "Compras en la casa de subastas: %s",
  STATS_SESSION_RAKE_FMT  = "Sesion actual (Rake): %s",
  STATS_NET_FMT           = "Ingreso neto (cuenta): %s",
  STATS_TOP_SENDERS       = "Principales remitentes:",
  STATS_HISTORY_TITLE     = "Historial (ultimos 7 dias, ventas HV)",
  STATS_NET_7D_FMT        = "Neto (7d): %s",
  STATS_CHARS_TITLE       = "Por personaje",
  STATS_CHARS_EMPTY       = "  Sin datos todavia - abre PostBox al menos una vez en cada personaje.",

  MM_TOOLTIP_LEFT         = "Clic izquierdo: abrir/cerrar",
  MM_TOOLTIP_RIGHT        = "Clic derecho: opciones",
  AC_TOOLTIP              = "Clic para abrir/cerrar el buzon.",
}
OVERRIDES.esMX = OVERRIDES.esES

-- ============================================================================
-- SELECTION DE LA LANGUE ACTIVE : GetLocale() = langue du CLIENT DE JEU,
-- jamais un reglage manuel. Toute cle absente de la surcharge retombe sur
-- BASE (anglais) via la metatable __index - jamais de nil affiche.
-- ============================================================================
local activeLocale = (GetLocale and GetLocale()) or "enUS"
PostBox.L = setmetatable(OVERRIDES[activeLocale] or {}, { __index = BASE })

-- ============================================================================
-- MOTS-CLES DE CLASSIFICATION DU COURRIER DE L'HOTEL DES VENTES (expediteur +
-- sujet), selon la meme langue de client. Utilises par PostBox.ClassifyMail
-- via UI.Normalize (minuscules, accents retires) - d'ou des mots-cles ici
-- deja sans accents. A VERIFIER EN JEU (voir avertissement en tete de fichier).
-- ============================================================================
local AH_BASE = {
  sender    = { "auction house" },
  cancelled = { "auction cancelled", "auction canceled" },
  expired   = { "auction expired" },
  outbid    = { "outbid" },
  sold      = { "auction successful" },
  won       = { "auction won" },
}

local AH_OVERRIDES = {
  frFR = {
    sender    = { "hotel des ventes" },
    cancelled = { "vente annulee", "enchere annulee" },
    expired   = { "vente expiree", "enchere expiree" },
    outbid    = { "surenchere" },
    sold      = { "vente reussie", "objet vendu" },
    won       = { "enchere remportee", "vente remportee" },
  },
  deDE = {
    sender    = { "auktionshaus" },
    cancelled = { "auktion storniert" },
    expired   = { "auktion abgelaufen" },
    outbid    = { "uberboten" },
    sold      = { "auktion erfolgreich" },
    won       = { "auktion ersteigert" },
  },
  esES = {
    sender    = { "casa de subastas" },
    cancelled = { "subasta cancelada" },
    expired   = { "subasta caducada" },
    outbid    = { "puja superada", "oferta superada" },
    sold      = { "subasta exitosa", "venta exitosa" },
    won       = { "subasta ganada" },
  },
}
AH_OVERRIDES.esMX = AH_OVERRIDES.esES

PostBox.AH_KEYWORDS = setmetatable(AH_OVERRIDES[activeLocale] or {}, { __index = AH_BASE })
