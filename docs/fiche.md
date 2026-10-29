Antoine HAZEBROUCK

Axel ELIAS

Téo VILLET

Julien PRONIER

# Need for Pills - Fiche game design

Fuir la police au volant d'un 4x4. La seule chose qui te rend plus rapide c'est le cacheton. Chaque substance consommée t'aide dans ta fuite mais te rend toujours plus addicte et dans le besoin.

## Cœur du jeu

Une course-poursuite sans fin, parsemées d'embuches et de schmitts et de concurrents voulant voler notre came, où le seul moyen de rester libre, c'est de se laisser assimiler petit à petit (joint par joint). Le pilote peut être aidé par un copilote (multijoueur) dans la fuite. Ton but est de fournir ton produit tout en restant libre et en vie.

### Lore

Une pilule rose, la Pills, a envahi la ville. Tu en es le fournisseur et tu es donc recherché par tes concurrents et par la police locale : l'un veut te voler ta recette et l'autre veut te mettre derrière les barreaux. 

# Défi

<u>Conserver de la vitesse (via drogues) pour échapper à la police</u>

<u>Tenir les jauges viables : </u>

- conserver l'intoxication suffisamment basse

- ne pas s'endormir au volant

Le défi fun réside dans l'utilisation VR du matériel (bédave, conduite...) notamment en coop pour se répartir les tâches et aller toujours plus loin. Cela couplé à la conduite difficile et exigeante, ainsi qu'aux contraintes rencontrées sur la route, rend le jeu défiesque. Le jeu devient de plus en plus dur avec les km, les actions doivent s'enchainer de plus en plus vite.

# Gameloop

Après avoir, démarré la voiture. La gameloop principale est la suivante :

1. Conduire, fuir les poursuivants

2. La pression monte (le poursuivant roule plus vite que le joueur par défaut)

3. Le copilote prépare la drogue

4. Le pilote se drogue pour aller plus vite, au détriment d'une jauge d'intoxication

5. Livraison de drogue à des clients

6. ravitaillement à la station service

Se droguer implique d'effectuer certaines actions au préalables, rouler des joints, prendre dans le sachet...

# 3C

Character : pilote ou copilote dans la voiture, la voiture étant logiquement une extension du joueur. On se réveille dans la voiture à un endroit aléatoire (bord de la route, camp de junky, motel malfamé), nous incarnons un dealer de drogue se réveillant d'une salle nuit et devant effectuer ses livraisons sans se faire choper.

Camera : première personne

Controls : l'écrasante majorité des interactions se déroulent via les mains (contrôleurs VR) :

- conduite

- sortir des clopes du paquet, les allumer, fumer

- sortir le thermos, l'ouvrir, verser le café

On limite au maximum le fait de juste presser un bouton ou utiliser les joysticks

# Piliers

### 1. Fuite

police

gitans

gyrophares

...

### 2. L'habitacle en VR

coopération pilote/copilote

frein à main

rétros

ceinture

volant

préparer les joints (pochon, grinder etc)

...

### 3. Dépendance

pilote s'endort, café

top lent, pillule

...

# Interactions

| Interaction                                               | Joueur     | Via                  |
| --------------------------------------------------------- | ---------- | -------------------- |
| Accélérer / freiner                                       | Conducteur | Gâchettes            |
| Tourner le volant                                         | Les deux   | Mains                |
| Levier de vitesse, frein à main                           | Les deux   | Mains                |
| Klaxon                                                    | Les deux   | Mains                |
| Pare-soleil, puis prendre la clé                          | Les deux   | Mains                |
| Clé dans le contact, démarrer                             | Les deux   | Mains                |
| Ceinture                                                  | Les deux   | Mains                |
| Portes                                                    | Les deux   | Mains                |
| Manivelles de vitres                                      | Les deux   | Mains                |
| Rétroviseurs                                              | Les deux   | Mains                |
| Boîte à gants, accoudoir                                  | Les deux   | Mains                |
| Autoradio                                                 | Les deux   | Mains                |
| Lire le GPS                                               | Les deux   | Regard               |
| Ranger, poser ou jeter un objet                           | Les deux   | Main                 |
| Ouvrir le sachet de pillules                              | Les deux   | A/X                  |
| Prendre une pilule                                        | Les deux   | Index                |
| Avaler une pilule                                         | Les deux   | Mains                |
| Ouvrir le paquet, prendre une cigarette                   | Les deux   | A/X, puis mains      |
| Allumer le briquet                                        | Les deux   | Main + A/X           |
| Allumer une cigarette ou un joint                         | Les deux   | Mains                |
| Fumer                                                     | Les deux   | Main vers la bouche  |
| Dévisser le thermos, verser le café                       | Les deux   | Mains                |
| Boire le café                                             | Les deux   | Mains vers la bouche |
| Préparer un joint : weed, grinder, feuille, filtre, tabac | Les deux   | Mains + A/X          |
