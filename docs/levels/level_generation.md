# Principe de génération des niveaux

L'algorithme utilisé pour généré les niveaux se rapprochent à celui utilisé par le démineur

## Phase d'initialisation

Une grille 8X8 est généré, rempli de 0. Cette grille servira de savoir si une case est occupé ou non. Un dictionnaire stocke la position des éléments (arbre(s), joueur, panier, repère visuel, pommier). Finalement, on utilise une graine de génération permettant de définir à l'avance la position des éléments.

## Algorithme de remplissage

On prend un objet (dans le code, on commence avec le repère visuel), puis on le place de façon aléatoire sur la grille, en indiquant que la case est occupé par un **1**. Pour éviter que deux objets soients juxtaposés, nous mettons aussi à **1** les case adjacentes à l'objet.

Ensuite pour l'objet suivant, nous testons une nouvelle position aléatoire, si cette position est occupée, alors on reprend une nouvelle position. Si cette position n'est pas occupée, alors nous plaçons l'objet à cette position en veillant bien à  