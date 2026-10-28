# Enregistrements à faire

Chaque fichier ci-dessous existe déjà (0,5 s de silence) : enregistre la réplique et
**écrase le fichier en gardant le même nom** (.wav). Pour un autre format (.ogg, .mp3),
dépose-le à côté et change le chemin indiqué dans la colonne « Réglage ».

| Fait | Fichier | Réplique | Quand c'est joué | Réglage |
|---|---|---|---|---|
| [ ] | `audio/voice/demarre.wav` | (intro : trouver les clés et démarrer, texte libre) | 1 s après le début de la partie, voiture garée moteur coupé | `ChaseDirector.start_voice_path` |
| [ ] | `audio/voice/manque.wav` | « Je suis en manque bordel, il me faut un truc là. » | Quand le manque atteint 45 % (une fois, jusqu'à la pilule suivante) | `PillAddiction.craving_voice_path` |
| [ ] | `audio/voice/baillement.wav` | (un long bâillement, 3 à 4 s, sans parole) | Quand le conducteur est fatigué : de plus en plus souvent avec la fatigue (toutes les ~75 s puis ~22 s) | `Fatigue.yawn_voice_path` |
