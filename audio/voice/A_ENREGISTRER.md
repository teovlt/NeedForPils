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

| Fait | Fichier                      | Réplique                                             | Quand c'est joué                                                                                        | Réglage                            |
| ---- | ---------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| [x]  | `audio/voice/demarre.wav`    | (intro : trouver les clés et démarrer, texte libre)  | 1 s après le début de la partie, voiture garée moteur coupé                                             | `ChaseDirector.start_voice_path`   |
| [x]  | `audio/voice/manque.wav`     | « Je suis en manque bordel, il me faut un truc là. » | Quand le manque atteint 45 % (une fois, jusqu'à la pilule suivante)                                     | `PillAddiction.craving_voice_path` |
| [x]  | `audio/voice/baillement.wav` | (un long bâillement, 3 à 4 s, sans parole)           | Quand le conducteur est fatigué : de plus en plus souvent avec la fatigue (toutes les ~75 s puis ~22 s) | `Fatigue.yawn_voice_path`          |
| [x]  | `audio/voice/bourre.wav`     | je suis bourré de rok                                | Quand on devient bien bourré (vers 2 canettes et demie), une fois par cuite                             | `PillAddiction.drunk_voice_id`     |
| [x]  | `audio/voice/intro_telephone.wav` | (conversation téléphonique de l'intro, enregistrée) | Début de partie : le téléphone sonne et réveille le joueur ; joué quand on décroche (téléphone en main, bouton vert appuyé avec l'autre main ; F sans casque) | `Phone.call_voice` |

## Narrateur (textes affichés devant les yeux)

Le titre est en majuscules, la phrase en dessous : la voix peut dire les deux, ou
seulement la phrase. `{n}` : nombre affiché à l'écran, pas besoin de le dire.

### Introduction cinématique (désactivée pour l'instant : `ChaseDirector.play_intro`)

| Fait | Fichier | Réplique | Quand c'est joué |
| ---- | ------- | -------- | ---------------- |
| [ ]  |         |          |                  |
| [ ]  |         |          |                  |
| [ ]  |         |          |                  |
| [ ]  |         |          |                  |
| [ ]  |         |          |                  |
| [ ]  |         |          |                  |
| [ ]  |         |          |                  |
| [ ]  |         |          |                  |

### Conseils (une fois par partie, pendant une poursuite)

| Fait | Fichier                 | Réplique                                                      | Quand c'est joué         |
| ---- | ----------------------- | ------------------------------------------------------------- | ------------------------ |
| [x]  | `conseil_manque.wav`    | « Nous sommes trop lent, il me faudrait un cacheton »         | Manque au-dessus de 65 % |
| [x]  | `conseil_proche.wav`    | « Ils nous collent au cul mec »                               | Police à moins de 45 m   |
| [x]  | `conseil_inversion.wav` | « Woa c'est trop le kiff »                                    | Assimilation à 45 %      |
| [x]  | `conseil_presque.wav`   | « Chui cuit gros jgamberge » (écran : « ASSIMILATION {n} % ») | Assimilation à 80 %      |

### Événements

| Fait | Fichier                  | Réplique                                    | Quand c'est joué                        |
| ---- | ------------------------ | ------------------------------------------- | --------------------------------------- |
| [x]  | `pilule_boost.wav`       | « La on est bieng »                         | Première pilule avalée                  |
| [x]  | `police_debut.wav`       | « Y a les hendeks qui arrivent »            | Première poursuite                      |
| [x]  | `police_barrage.wav`     | « Oh non ils ont vu les bières fais gaffe » | Première poursuite, partie d'un barrage |
| [x]  | `police_semee.wav`       | nik les keufs                               | Police semée (chaque fois)              |
| [x]  | `rivaux_debut.wav`       | « No heisenberg »                           | Première apparition du camping-car      |
| [x]  | `rivaux_retour.wav`      | « Le retour de la meth mobile putaing »     | Apparitions suivantes                   |
| [x]  | `rivaux_semes.wav`       | « Tchao le chauve »                         | Camping-car semé                        |
| [x]  | `rivaux_tir_premier.wav` | « Les enculés ils ont des fers »            | Première balle reçue                    |
| [x]  | `rivaux_tir_2.wav`       | « Encore deux balles et ca lâche »          | Il reste 2 balles                       |
| [x]  | `rivaux_tir_1.wav`       | « Nique zebi roule »                        | Il reste 1 balle                        |

### Livraisons

| Fait | Fichier                     | Réplique                          | Quand c'est joué                     |
| ---- | --------------------------- | --------------------------------- | ------------------------------------ |
| [x]  | `livraison_encore.wav`      | « Mets en deuxième »              | Commande de 2 : premier sachet livré |
| [x]  | `livraison_ok.wav`          | « Lezzgo direction la prochaine » | Livraison réussie                    |
| [x]  | `livraison_ok_sac_vide.wav` | « On a pu de came zebi »          | Dernier sachet livré                 |
| [x]  | `livraison_ratee.wav`       | « Putaing on l'a raté »           | Adresse dépassée                     |

### Fins de partie

| Fait | Fichier          | Réplique                                  | Quand c'est joué       |
| ---- | ---------------- | ----------------------------------------- | ---------------------- |
| [x]  | `fin_police.wav` | « Ils t'ont rattrapé. La police t'a eu. » | Rattrapé par la police |
| [ ]  |                  |                                           |                        |
| [ ]  |                  |                                           |                        |
| [ ]  |                  |                                           |                        |
| [ ]  |                  |                                           |                        |
| [ ]  |                  |                                           |                        |

## GPS (la voix sort de l'écran du GPS)

Pour une nouvelle adresse, le GPS joue la réplique propre au lieu si elle est
enregistrée, sinon `gps_livraison_nouvelle` : on peut n'enregistrer que celle-là.

|     |     |     |     |
| --- | --- | --- | --- |
|     |     |     |     |
|     |     |     |     |
|     |     |     |     |
|     |     |     |     |
|     |     |     |     |
|     |     |     |     |
|     |     |     |     |
|     |     |     |     |
|     |     |     |     |
|     |     |     |     |
|     |     |     |     |
|     |     |     |     |
|     |     |     |     |

## Menus et réseau

| Fait | Fichier                       | Réplique                                                                     | Quand c'est joué                        |
| ---- | ----------------------------- | ---------------------------------------------------------------------------- | --------------------------------------- |
| [ ]  | `reseau_recherche.wav`        | « Recherche d'une partie sur le réseau... »                                  | Clic sur JOUER À DEUX                   |
| [ ]  | `reseau_attente.wav`          | « En attente de l'autre joueur. Il doit cliquer sur Jouer à deux. »          | Aucune partie trouvée : on en crée une  |
| [ ]  | `reseau_trouvee.wav`          | « Partie trouvée, connexion... »                                             | Partie trouvée                          |
| [ ]  | `reseau_conducteur.wav`       | « Joueur trouvé ! Tu conduis. »                                              | L'autre joueur a rejoint                |
| [ ]  | `reseau_copilote.wav`         | « Connecté ! Tu es copilote. »                                               | On a rejoint la partie                  |
| [ ]  | `reseau_echec_rejoindre.wav`  | « Impossible de rejoindre la partie. »                                       | Échec de connexion à la partie trouvée  |
| [ ]  | `reseau_echec.wav`            | « Connexion impossible. »                                                    | Échec de connexion                      |
| [ ]  | `reseau_parti.wav`            | « L'autre joueur est parti. »                                                | Déconnexion de l'autre joueur           |
| [ ]  | `reseau_conducteur_parti.wav` | « Le conducteur a quitté la partie. »                                        | Copilote : le conducteur s'en va        |
| [ ]  | `pause_solo.wav`              | « Partie en pause. »                                                         | Ouverture du menu pause, seul           |
| [ ]  | `pause_deux_conducteur.wav`   | « La partie continue pendant le menu. Rejouer la relance pour vous deux. »   | Menu pause, conducteur en partie à deux |
| [ ]  | `pause_deux_copilote.wav`     | « La partie continue pendant le menu. Seul le conducteur peut la relancer. » | Menu pause, copilote                    |
