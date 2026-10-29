# Textes affichés à l'écran (à remplacer par des voix)

Recensement de tous les textes que le joueur voit, pour les remplacer petit à petit
par des enregistrements. Chaque ligne a un **identifiant** : c'est aussi le nom de
fichier proposé (`audio/voice/<identifiant>.wav`). Quand une réplique est enregistrée,
cocher la case et la reporter dans `A_ENREGISTRER.md`.

Les passages entre accolades sont calculés pendant la partie (`{n}` = un nombre) :
soit on enregistre une version par valeur utile, soit on garde le chiffre à l'écran.

Lignes indiquées : état du code au commit a1a6c90 (branche `fix`).

---

## 1. Messages devant les yeux — priorité

Ce sont les seuls vrais « sous-titres » du jeu : un titre et une phrase collés à la
caméra (`ChaseDirector._say` / `_show`, `world/chase/chase_director.gd`), lisibles en VR
et en mode bureau, recopiés chez le copilote en partie à deux. Tous passent par
`_say(titre, phrase, durée)` : c'est l'endroit unique où brancher les voix (jouer
`audio/voice/<identifiant>.wav` s'il existe, avec ou sans le texte).

### 1.1 Introduction cinématique (désactivée : `play_intro = false`)

| Fait | Identifiant | Titre | Phrase | Quand | Où |
|---|---|---|---|---|---|
| [ ] | `intro_lore_1` | 2049. | La Pils est arrivée en ville. Une pilule rose. Tout le monde en a pris. | Intro, écran 1 (5,5 s) | `chase_director.gd:18` (`LORE`) |
| [ ] | `intro_lore_2` | LA POLICE | Elle traque tous ceux qui en ont. Barrages, patrouilles, partout. | Intro, écran 2 | `chase_director.gd:19` |
| [ ] | `intro_lore_3` | TOI | Tu viens de filer avec vingt Pils dans la boîte à gants. | Intro, écran 3 | `chase_director.gd:20` |
| [ ] | `intro_lore_4` | LA PILS | Elle te rend plus rapide qu'eux. Mais chaque Pils te rend un peu plus accro. | Intro, écran 4 | `chase_director.gd:21` |
| [ ] | `intro_trouve` | ILS T'ONT TROUVÉ. | La police est sur tes traces. | Plan aérien | `chase_director.gd:127` |
| [ ] | `intro_rapprochent` | ILS SE RAPPROCHENT. | Ne ralentis jamais. | Plan aérien, suite | `chase_director.gd:129` |
| [ ] | `intro_volant_vr` | PRENDS LE VOLANT ! | Gâchette droite : accélérer. Ne lâche pas l'accélérateur. | Fin de l'intro, en VR | `chase_director.gd:141` + `_controls_text` (l. 199) |
| [ ] | `intro_volant_clavier` | PRENDS LE VOLANT ! | Z : accélérer · Q / D : tourner · ne ralentis pas ! | Fin de l'intro, sans casque | idem |

> Le départ actuel (garé, moteur coupé) n'affiche rien : il joue déjà la voix
> `demarre.wav` (voir `A_ENREGISTRER.md`).

### 1.2 Conseils (une seule fois par partie, pendant une poursuite de police)

| Fait | Identifiant | Titre | Phrase | Quand | Où |
|---|---|---|---|---|---|
| [ ] | `conseil_manque` | LE MANQUE | Il te ralentit. Avale une Pils : le sachet est quelque part dans la voiture. | Manque > 65 % | `chase_director.gd:361` |
| [ ] | `conseil_proche` | ILS SONT DERRIÈRE TOI | Une Pils = un boost. Avale-la. | Police à moins de 45 m | `chase_director.gd:363` |
| [ ] | `conseil_inversion` | TU CHANGES | Sans Pils, tout devient flou. Tu ne peux plus t'en passer. | Assimilation ≥ 45 % | `chase_director.gd:365` |
| [ ] | `conseil_presque` | ASSIMILATION {n} % | Encore quelques Pils et tu ne reviendras pas. | Assimilation ≥ 80 % | `chase_director.gd:367` |

> `conseil_manque` double la voix existante `manque.wav` (jouée à 45 % de manque) :
> on pourra n'en garder qu'une.

### 1.3 Événements de la partie

| Fait | Identifiant | Titre | Phrase | Quand | Où |
|---|---|---|---|---|---|
| [ ] | `pilule_boost` | BOOST ! | Mais tu leur ressembles un peu plus... | Première pilule avalée | `chase_director.gd:382` |
| [ ] | `police_debut` | LA POLICE ! | Sème-la : creuse l'écart jusqu'à ce qu'elle te perde. | Première poursuite (bas-côté, derrière) | `chase_director.gd:388-393` |
| [ ] | `police_barrage` | LA POLICE ! | Elle a démarré derrière toi. Sème-la : creuse l'écart jusqu'à ce qu'elle te perde. | Première poursuite, après un barrage | idem |
| [ ] | `police_semee` | SEMÉE ! | La police a perdu ta trace... pour l'instant. | Police semée (à chaque fois) | `chase_director.gd:398` |
| [ ] | `rivaux_debut` | LES CONCURRENTS ! | Le camping-car veut ta came. Ils vont tirer : sème-les. | Première apparition du camping-car | `chase_director.gd:406` |
| [ ] | `rivaux_retour` | ILS SONT REVENUS | Le camping-car est derrière toi. | Apparitions suivantes | `chase_director.gd:408` |
| [ ] | `rivaux_semes` | SEMÉS ! | Le camping-car a disparu du rétro. | Camping-car semé | `chase_director.gd:413` |
| [ ] | `rivaux_tir_{n}` | ON TE TIRE DESSUS ! | Encore {n} balle(s) et c'est fini. | 1re balle reçue, puis quand il en reste 2 ou 1 | `chase_director.gd:421` |

> `rivaux_tir_{n}` : en pratique `rivaux_tir_premier` (1re balle, {n} = nombre max − 1),
> `rivaux_tir_2` et `rivaux_tir_1`.

### 1.4 Livraisons (`world/delivery/delivery_manager.gd`, affichées via `_say`)

| Fait | Identifiant | Titre | Phrase | Quand | Où |
|---|---|---|---|---|---|
| [ ] | `livraison_encore` | ENCORE UN ! | Le client en veut {n}. Lance le suivant. | Commande de 2 : premier sachet livré | `delivery_manager.gd:206` |
| [ ] | `livraison_ok` | LIVRÉ ! | {n} livraison(s) · Prochaine adresse sur le GPS. | Livraison réussie | `delivery_manager.gd:213-214` |
| [ ] | `livraison_ok_sac_vide` | LIVRÉ ! | {n} livraison(s) · Le sac est vide. Plus rien à livrer. | Dernier sachet livré | idem |
| [ ] | `livraison_ratee` | LIVRAISON RATÉE | Le client attendra. Prochaine adresse sur le GPS. | Adresse dépassée de 120 m | `delivery_manager.gd:217` |

> Le compteur « {n} livraisons » peut rester écrit, ou disparaître de la voix.

### 1.5 Fins de partie (texte qui reste affiché, rideau sombre)

| Fait | Identifiant | Titre | Phrase | Quand | Où |
|---|---|---|---|---|---|
| [ ] | `fin_police` | ILS T'ONT RATTRAPÉ. | La police t'a eu. | Rattrapé par la police | `chase_director.gd:437` |
| [ ] | `fin_rivaux` | ILS T'ONT EU. | Les concurrents ont pris ta came. | Trop de balles du camping-car | `chase_director.gd:427` |
| [ ] | `fin_assimile` | PERDU DANS LA PILS. | Tu souris. Tu ne sais plus pourquoi tu roulais. | Assimilation 100 % | `chase_director.gd:445` |
| — | (garder écrit) | | {x,x} km parcourus · {n} Pils · assimilation {n} % · {n} livraisons | Sous la phrase de fin | `chase_director.gd:463-466` |
| [ ] | `fin_rejouer` | | Espace / A : rejouer | Sous les statistiques | `chase_director.gd:468` |

---

## 2. Menus et réseau (panneaux visés à la manette)

À garder écrits (boutons) ; les messages d'état peuvent avoir une voix en plus.

| Fait | Identifiant | Texte | Quand | Où |
|---|---|---|---|---|
| — | | NEED FOR PILS / Visez avec la manette et appuyez sur la gâchette | Menu principal (titre, sous-titre) | `menu/main_menu_ui.tscn:86, 93` |
| — | | JOUER À DEUX · JOUER SEUL · QUITTER · ANNULER | Boutons du menu principal | `menu/main_menu_ui.tscn:110-148` |
| [ ] | `reseau_recherche` | Recherche d'une partie sur le réseau... | Clic sur JOUER À DEUX | `network/net.gd:133` |
| [ ] | `reseau_attente` | En attente de l'autre joueur... (il doit cliquer sur JOUER À DEUX) | Aucune partie trouvée : on en crée une | `network/net.gd:162` (et `main_menu_ui.tscn:138`) |
| [ ] | `reseau_trouvee` | Partie trouvée ({adresse}), connexion... | Partie trouvée | `network/net.gd:174` |
| [ ] | `reseau_conducteur` | Joueur trouvé ! Tu conduis. | L'autre joueur a rejoint | `network/net.gd:266` |
| [ ] | `reseau_copilote` | Connecté ! Tu es copilote. | On a rejoint la partie | `network/net.gd:276` |
| [ ] | `reseau_echec_rejoindre` | Impossible de rejoindre {adresse} | Échec de connexion | `network/net.gd:169` |
| [ ] | `reseau_echec` | Connexion impossible. | Échec de connexion | `network/net.gd:283` |
| [ ] | `reseau_parti` | L'autre joueur est parti. | Déconnexion pendant l'attente | `network/net.gd:295` |
| [ ] | `reseau_conducteur_parti` | Le conducteur a quitté la partie. | Copilote : le conducteur s'en va (retour au menu) | `network/net.gd:299` |
| — | | PAUSE · REPRENDRE · REJOUER · MENU PRINCIPAL | Menu pause | `menu/pause_menu_ui.tscn:86-117` |
| [ ] | `pause_solo` | Partie en pause | Menu pause, seul | `menu/pause_menu_ui.gd:25` |
| [ ] | `pause_deux_conducteur` | Partie à deux : elle continue pendant le menu. REJOUER relance la partie pour vous deux. | Menu pause, conducteur | `menu/pause_menu_ui.gd:27` |
| [ ] | `pause_deux_copilote` | Partie à deux : elle continue pendant le menu. Seul le conducteur peut relancer la partie. | Menu pause, copilote | `menu/pause_menu_ui.gd:29` |

---

## 3. Aides du mode bureau et outils de développement (pas à remplacer)

| Texte | Quand | Où |
|---|---|---|
| Clic gauche : attraper   Clic droit : regarder   Molette : distance   F : ouvrir/fermer · « + » (viseur) | Mode bureau (sans casque), en haut à gauche | `interaction/mouse_hand.gd:44, 51` |
| Météo et heure — F1 pour fermer, boutons des météos, heures, vitesses, « Éclair maintenant »… | Menu de test F1 | `weather/weather_menu.gd` |

---

## 4. Textes dans le décor et sur les écrans de la voiture

Ils font partie du monde : on les garde écrits. Seul le GPS est un bon candidat pour
une voix (guidage façon GPS).

### 4.1 GPS (`cars/SUV4x4/gps_screen.gd`) — candidat à une voix

| Fait | Identifiant | Texte | Quand | Où |
|---|---|---|---|---|
| — | | ROUTE LIBRE / navigation | Démarrage de l'écran (contact mis) | l. 101-102 |
| — | | Recherche du signal... | Voiture loin de la route | l. 115 |
| [ ] | `gps_tout_droit` | Tout droit | Pas de virage annoncé | l. 139 |
| [ ] | `gps_virage_gauche` / `gps_virage_droite` | {distance}   virage à gauche / droite | Virage serré à moins de 900 m | l. 141 |
| [ ] | `gps_livraison` | LIVRAISON {distance} / ICI / DERRIÈRE | Encadré de la livraison en cours | l. 157-163 |
| [ ] | `gps_livraison_lieu` | station-service · motel · supérette · aire de repos · camp · boîte aux lettres à gauche/droite · carton à gauche/droite · x{n} | Détail sous la distance | l. 165-171 |
| — | | {n} km/h · heure | Bandeau du bas | l. 229-232 |

> Pour une voix GPS, il suffirait d'annoncer une fois chaque nouvelle adresse
> (« Nouvelle livraison : boîte aux lettres à gauche, dans 600 mètres ») et
> l'approche (« Livraison dans 100 mètres »), plutôt que lire l'écran en continu.

### 4.2 Autres écrans et étiquettes (garder écrits)

- Autoradio : fréquence, nom de la station, « VOL |||||.... », « RECHERCHE », titre du morceau, touches 1-5 et PWR (`cars/SUV4x4/car_radio.gd:115-170, 475-482`).
- Combiné d'instruments : vitesse, compte-tours, voyants (`cars/SUV4x4/cluster_display.gd`).
- Levier de vitesses R N D 2 1 (`suv_4x4.tscn:192-224`), contacteur 0 I II III (`ignition.gd:39`).
- Paquet « ROUTE LIBRE / FUMER TUE » (`interaction/cigarette_pack.gd:148-152`), feuilles « SLIM LIBRE / feuilles à rouler », « FILTRES » (`interaction/rolling/roll_dispenser.gd:112-125`), sachet de tabac (`interaction/rolling/tobacco_pouch.gd:89`), canettes « PILS DU BITUME » (`interaction/drinks/beer_can.gd:53`), sachets « :) x{n} » (`interaction/deal/dealer_bag.gd:29`).
- Voiture de police « POLICE » (`world/chase/pursuer.gd:692`).
- Points de livraison : carton « :) / ICI :) / FRAGILE / COLIS », numéro de boîte aux lettres, balise « :) x{n} » (`world/delivery/delivery_drop.gd:72-164`).
- Enseignes et tags des lieux (supérette, motel, aire, camp, station-service : « SUP  RETTE », « FERMÉ », « MOTEL », « CHAMBRES LIBRES », « RÉCEPTION », « CARBU 24 », prix, « OUVERT 24/24 », « PILS », « NO LIMIT »…) (`world/start/start_site.gd`, appels à `label(...)`).
