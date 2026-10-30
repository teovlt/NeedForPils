# Textes affichés à l'écran (à remplacer par des voix)

Recensement de tous les textes que le joueur voit, pour les remplacer petit à petit
par des enregistrements. Chaque ligne cochable a un **identifiant** : c'est le nom du
fichier de la voix, `audio/voice/<identifiant>.wav`. **Les voix sont branchées** : ces
fichiers existent déjà (silence de 0,5 s) et sont joués au moment du texte ; il suffit
de les écraser par l'enregistrement. Les répliques à dire sont dans `A_ENREGISTRER.md`
(cocher là-bas).

Les passages entre accolades sont calculés pendant la partie (`{n}` = un nombre) :
soit on enregistre une version par valeur utile, soit on garde le chiffre à l'écran.

Lignes indiquées : état du code au commit a1a6c90 (branche `fix`), avant le
branchement des voix (les numéros ont pu bouger de quelques lignes).

---

## 1. Messages devant les yeux — priorité

Ce sont les seuls vrais « sous-titres » du jeu : un titre et une phrase collés à la
caméra (`ChaseDirector._say` / `_show`, `world/chase/chase_director.gd`), lisibles en VR
et en mode bureau, recopiés chez le copilote en partie à deux. Tous passent par
`_say(titre, phrase, durée, voix)`, qui joue `audio/voice/<identifiant>` et garde le
texte au moins le temps de la réplique (ou le masque si `show_text_with_voice` est
décoché et que la voix est enregistrée).

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
| [ ] | `rivaux_tir_premier` · `rivaux_tir_2` · `rivaux_tir_1` | ON TE TIRE DESSUS ! | Encore {n} balle(s) et c'est fini. | 1re balle reçue, puis quand il en reste 2 ou 1 | `chase_director.gd:421` |


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
| [ ] | `fin_pare_brise` | À TRAVERS LE PARE-BRISE. | Pas de ceinture, {n} km/h dans le décor. | Choc violent sans ceinture (conducteur éjecté) | `chase_director.gd` (`end_crash`) |
| [ ] | `fin_pare_brise_copilote` | LE COPILOTE A TRAVERSÉ LE PARE-BRISE. | Pas de ceinture, {n} km/h dans le décor. | Partie à deux : copilote sans ceinture éjecté | `chase_director.gd` (`end_crash`) |
| — | (garder écrit) | | {x,x} km parcourus · {n} Pils · assimilation {n} % · {n} livraisons | Sous la phrase de fin | `chase_director.gd:463-466` |
| [ ] | `fin_rejouer` | | Espace / A : rejouer | Sous les statistiques | `chase_director.gd:468` |

---

## 2. Menus et réseau (panneaux visés à la manette)

Les boutons restent écrits ; les messages d'état et de pause ont une voix en plus
(jouée par `Net._status` / `Net._fail` et `PauseMenu.open`).

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

### 4.1 GPS (`cars/SUV4x4/gps_screen.gd`) — voix branchée (`_update_voice`)

L'écran reste tel quel ; la voix sort du GPS pour les annonces utiles, sans lire
l'écran en continu.

| Fait | Identifiant | Texte à l'écran | Voix | Où |
|---|---|---|---|---|
| — | | ROUTE LIBRE / navigation | (démarrage de l'écran, pas de voix) | l. 101-102 |
| — | | Recherche du signal... / Tout droit / {n} km/h / heure | (pas de voix) | l. 115, 139, 229-232 |
| [ ] | `gps_virage_gauche` · `gps_virage_droite` | {distance}   virage à gauche / droite | Une fois par virage serré, à moins de 350 m | l. 141 |
| [ ] | `gps_livraison_nouvelle` (+ variantes `gps_livraison_boite_gauche/droite`, `gps_livraison_carton_gauche/droite`, `gps_livraison_station/motel/superette/aire/camp`) | LIVRAISON {distance} + détail du lieu | Nouvelle adresse : variante du lieu si enregistrée, sinon la générique | l. 157-171 |
| [ ] | `gps_livraison_proche` | LIVRAISON {distance} / ICI | À 150 m de l'adresse | idem |

### 4.2 Autres écrans et étiquettes (garder écrits)

- Autoradio : fréquence, nom de la station, « VOL |||||.... », « RECHERCHE », titre du morceau, touches 1-5 et PWR (`cars/SUV4x4/car_radio.gd:115-170, 475-482`).
- Combiné d'instruments : vitesse, compte-tours, voyants (`cars/SUV4x4/cluster_display.gd`).
- Levier de vitesses R N D 2 1 (`suv_4x4.tscn:192-224`), contacteur 0 I II III (`ignition.gd:39`).
- Paquet « ROUTE LIBRE / FUMER TUE » (`interaction/cigarette_pack.gd:148-152`), feuilles « SLIM LIBRE / feuilles à rouler », « FILTRES » (`interaction/rolling/roll_dispenser.gd:112-125`), sachet de tabac (`interaction/rolling/tobacco_pouch.gd:89`), canettes « PILS DU BITUME » (`interaction/drinks/beer_can.gd:53`), sachets « :) x{n} » (`interaction/deal/dealer_bag.gd:29`).
- Téléphone de l'intro : « APPEL ENTRANT », « NUMÉRO MASQUÉ », bouton « DÉCROCHER », « EN APPEL 00:12 », « APPEL TERMINÉ », « 1 APPEL MANQUÉ » (`interaction/phone.gd`) ; la conversation est la voix `intro_telephone`.
- Voiture de police « POLICE » (`world/chase/pursuer.gd:692`).
- Points de livraison : carton « :) / ICI :) / FRAGILE / COLIS », numéro de boîte aux lettres, balise « :) x{n} » (`world/delivery/delivery_drop.gd:72-164`).
- Enseignes et tags des lieux (supérette, motel, aire, camp, station-service : « SUP  RETTE », « FERMÉ », « MOTEL », « CHAMBRES LIBRES », « RÉCEPTION », « CARBU 24 », prix, « OUVERT 24/24 », « PILS », « NO LIMIT »…) (`world/start/start_site.gd`, appels à `label(...)`).
