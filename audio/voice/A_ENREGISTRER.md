# Enregistrements à faire

Chaque fichier ci-dessous existe déjà (0,5 s de silence) : enregistre la réplique et
**écrase le fichier en gardant le même nom** (.wav). Un .ogg ou un .mp3 du même nom
déposé à côté est pris à la place du .wav (sauf pour les trois premières lignes, dont
le chemin se règle dans la colonne « Réglage »).

Un fichier de **0,5 s exactement** est considéré comme « pas encore enregistré » :
garde tes prises un peu plus longues (un souffle de silence au début suffit).

Les répliques sont jouées par `VoiceLine` (`audio/voice_line.gd`) ; les textes à
l'écran correspondants sont recensés dans `TEXTES_A_L_ECRAN.md`. Les textes restent
affichés comme sous-titres (au moins le temps de la réplique) ; décocher
`ChaseDirector.show_text_with_voice` les fait disparaître dès que la voix existe.
En partie à deux, le copilote entend les mêmes répliques que le conducteur.

## Voix déjà en place

| Fait | Fichier | Réplique | Quand c'est joué | Réglage |
|---|---|---|---|---|
| [ ] | `audio/voice/demarre.wav` | (intro : trouver les clés et démarrer, texte libre) | 1 s après le début de la partie, voiture garée moteur coupé | `ChaseDirector.start_voice_path` |
| [ ] | `audio/voice/manque.wav` | « Je suis en manque bordel, il me faut un truc là. » | Quand le manque atteint 45 % (une fois, jusqu'à la pilule suivante) | `PillAddiction.craving_voice_path` |
| [ ] | `audio/voice/baillement.wav` | (un long bâillement, 3 à 4 s, sans parole) | Quand le conducteur est fatigué : de plus en plus souvent avec la fatigue (toutes les ~75 s puis ~22 s) | `Fatigue.yawn_voice_path` |
| [ ] | `audio/voice/bourre.wav` | « Oh putain... je suis complètement bourré là. » (voix pâteuse) | Quand on devient bien bourré (vers 2 canettes et demie), une fois par cuite | `PillAddiction.drunk_voice_id` |

## Narrateur (textes affichés devant les yeux)

Le titre est en majuscules, la phrase en dessous : la voix peut dire les deux, ou
seulement la phrase. `{n}` : nombre affiché à l'écran, pas besoin de le dire.

### Introduction cinématique (désactivée pour l'instant : `ChaseDirector.play_intro`)

| Fait | Fichier | Réplique | Quand c'est joué |
|---|---|---|---|
| [ ] | `intro_lore_1.wav` | « 2049. La Pils est arrivée en ville. Une pilule rose. Tout le monde en a pris. » | Intro, écran 1 |
| [ ] | `intro_lore_2.wav` | « La police. Elle traque tous ceux qui en ont. Barrages, patrouilles, partout. » | Intro, écran 2 |
| [ ] | `intro_lore_3.wav` | « Toi. Tu viens de filer avec vingt Pils dans la boîte à gants. » | Intro, écran 3 |
| [ ] | `intro_lore_4.wav` | « La Pils. Elle te rend plus rapide qu'eux. Mais chaque Pils te rend un peu plus accro. » | Intro, écran 4 |
| [ ] | `intro_trouve.wav` | « Ils t'ont trouvé. La police est sur tes traces. » | Plan aérien |
| [ ] | `intro_rapprochent.wav` | « Ils se rapprochent. Ne ralentis jamais. » | Plan aérien, suite |
| [ ] | `intro_volant_vr.wav` | « Prends le volant ! Gâchette droite pour accélérer. Ne lâche pas l'accélérateur. » | Fin de l'intro, en VR |
| [ ] | `intro_volant_clavier.wav` | « Prends le volant ! Z pour accélérer, Q et D pour tourner. Ne ralentis pas ! » | Fin de l'intro, sans casque |

### Conseils (une fois par partie, pendant une poursuite)

| Fait | Fichier | Réplique | Quand c'est joué |
|---|---|---|---|
| [ ] | `conseil_manque.wav` | « Le manque. Il te ralentit. Avale une Pils : le sachet est quelque part dans la voiture. » | Manque au-dessus de 65 % |
| [ ] | `conseil_proche.wav` | « Ils sont derrière toi. Une Pils, c'est un boost. Avale-la. » | Police à moins de 45 m |
| [ ] | `conseil_inversion.wav` | « Tu changes. Sans Pils, tout devient flou. Tu ne peux plus t'en passer. » | Assimilation à 45 % |
| [ ] | `conseil_presque.wav` | « Encore quelques Pils et tu ne reviendras pas. » (écran : « ASSIMILATION {n} % ») | Assimilation à 80 % |

### Événements

| Fait | Fichier | Réplique | Quand c'est joué |
|---|---|---|---|
| [ ] | `pilule_boost.wav` | « Boost ! Mais tu leur ressembles un peu plus... » | Première pilule avalée |
| [ ] | `police_debut.wav` | « La police ! Sème-la : creuse l'écart jusqu'à ce qu'elle te perde. » | Première poursuite |
| [ ] | `police_barrage.wav` | « La police ! Elle a démarré derrière toi. Sème-la : creuse l'écart jusqu'à ce qu'elle te perde. » | Première poursuite, partie d'un barrage |
| [ ] | `police_semee.wav` | « Semée ! La police a perdu ta trace... pour l'instant. » | Police semée (chaque fois) |
| [ ] | `rivaux_debut.wav` | « Les concurrents ! Le camping-car veut ta came. Ils vont tirer : sème-les. » | Première apparition du camping-car |
| [ ] | `rivaux_retour.wav` | « Ils sont revenus. Le camping-car est derrière toi. » | Apparitions suivantes |
| [ ] | `rivaux_semes.wav` | « Semés ! Le camping-car a disparu du rétro. » | Camping-car semé |
| [ ] | `rivaux_tir_premier.wav` | « On te tire dessus ! Encore quelques balles et c'est fini. » | Première balle reçue |
| [ ] | `rivaux_tir_2.wav` | « On te tire dessus ! Encore deux balles et c'est fini. » | Il reste 2 balles |
| [ ] | `rivaux_tir_1.wav` | « On te tire dessus ! Encore une balle et c'est fini. » | Il reste 1 balle |

### Livraisons

| Fait | Fichier | Réplique | Quand c'est joué |
|---|---|---|---|
| [ ] | `livraison_encore.wav` | « Encore un ! Le client en veut deux. Lance le suivant. » | Commande de 2 : premier sachet livré |
| [ ] | `livraison_ok.wav` | « Livré ! Prochaine adresse sur le GPS. » | Livraison réussie |
| [ ] | `livraison_ok_sac_vide.wav` | « Livré ! Le sac est vide. Plus rien à livrer. » | Dernier sachet livré |
| [ ] | `livraison_ratee.wav` | « Livraison ratée. Le client attendra. Prochaine adresse sur le GPS. » | Adresse dépassée |

### Fins de partie

| Fait | Fichier | Réplique | Quand c'est joué |
|---|---|---|---|
| [ ] | `fin_police.wav` | « Ils t'ont rattrapé. La police t'a eu. » | Rattrapé par la police |
| [ ] | `fin_rivaux.wav` | « Ils t'ont eu. Les concurrents ont pris ta came. » | Trop de balles du camping-car |
| [ ] | `fin_assimile.wav` | « Perdu dans la Pils. Tu souris. Tu ne sais plus pourquoi tu roulais. » | Assimilation à 100 % |
| [ ] | `fin_pare_brise.wav` | « À travers le pare-brise. Pas de ceinture, pas de deuxième chance. » | Choc violent sans ceinture (le conducteur est éjecté) |
| [ ] | `fin_pare_brise_copilote.wav` | « Le copilote a traversé le pare-brise. Il n'avait pas mis sa ceinture. » | Partie à deux : choc violent, le copilote sans ceinture est éjecté |
| [ ] | `fin_rejouer.wav` | « Espace ou A pour rejouer. » | Juste après la réplique de fin |

## GPS (la voix sort de l'écran du GPS)

Pour une nouvelle adresse, le GPS joue la réplique propre au lieu si elle est
enregistrée, sinon `gps_livraison_nouvelle` : on peut n'enregistrer que celle-là.

| Fait | Fichier | Réplique | Quand c'est joué |
|---|---|---|---|
| [ ] | `gps_virage_gauche.wav` | « Virage serré à gauche. » | Virage serré à moins de 350 m (une fois par virage) |
| [ ] | `gps_virage_droite.wav` | « Virage serré à droite. » | Idem, à droite |
| [ ] | `gps_livraison_nouvelle.wav` | « Nouvelle livraison. Suivez le point rose. » | Nouvelle adresse (version générique) |
| [ ] | `gps_livraison_boite_gauche.wav` | « Nouvelle livraison : boîte aux lettres sur la gauche. » | Nouvelle adresse au bord de la route |
| [ ] | `gps_livraison_boite_droite.wav` | « Nouvelle livraison : boîte aux lettres sur la droite. » | Idem |
| [ ] | `gps_livraison_carton_gauche.wav` | « Nouvelle livraison : un carton sur la gauche. Lancez le sachet dedans. » | Idem |
| [ ] | `gps_livraison_carton_droite.wav` | « Nouvelle livraison : un carton sur la droite. Lancez le sachet dedans. » | Idem |
| [ ] | `gps_livraison_station.wav` | « Nouvelle livraison : à la station-service. » | Nouvelle adresse sur un lieu |
| [ ] | `gps_livraison_motel.wav` | « Nouvelle livraison : au motel. » | Idem |
| [ ] | `gps_livraison_superette.wav` | « Nouvelle livraison : à la supérette. » | Idem |
| [ ] | `gps_livraison_aire.wav` | « Nouvelle livraison : sur l'aire de repos. » | Idem |
| [ ] | `gps_livraison_camp.wav` | « Nouvelle livraison : au camp de caravanes. » | Idem |
| [ ] | `gps_livraison_proche.wav` | « Livraison dans cent cinquante mètres. » | À 150 m de l'adresse |

## Menus et réseau

| Fait | Fichier | Réplique | Quand c'est joué |
|---|---|---|---|
| [ ] | `reseau_recherche.wav` | « Recherche d'une partie sur le réseau... » | Clic sur JOUER À DEUX |
| [ ] | `reseau_attente.wav` | « En attente de l'autre joueur. Il doit cliquer sur Jouer à deux. » | Aucune partie trouvée : on en crée une |
| [ ] | `reseau_trouvee.wav` | « Partie trouvée, connexion... » | Partie trouvée |
| [ ] | `reseau_conducteur.wav` | « Joueur trouvé ! Tu conduis. » | L'autre joueur a rejoint |
| [ ] | `reseau_copilote.wav` | « Connecté ! Tu es copilote. » | On a rejoint la partie |
| [ ] | `reseau_echec_rejoindre.wav` | « Impossible de rejoindre la partie. » | Échec de connexion à la partie trouvée |
| [ ] | `reseau_echec.wav` | « Connexion impossible. » | Échec de connexion |
| [ ] | `reseau_parti.wav` | « L'autre joueur est parti. » | Déconnexion de l'autre joueur |
| [ ] | `reseau_conducteur_parti.wav` | « Le conducteur a quitté la partie. » | Copilote : le conducteur s'en va |
| [ ] | `pause_solo.wav` | « Partie en pause. » | Ouverture du menu pause, seul |
| [ ] | `pause_deux_conducteur.wav` | « La partie continue pendant le menu. Rejouer la relance pour vous deux. » | Menu pause, conducteur en partie à deux |
| [ ] | `pause_deux_copilote.wav` | « La partie continue pendant le menu. Seul le conducteur peut la relancer. » | Menu pause, copilote |
