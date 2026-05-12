# � Scènes Godot

Cette page donne une vue d'ensemble des scènes principales du projet AppleGame.

## Thèmes de documentation réduite

Pour simplifier, documentez uniquement les 6 sections suivantes :

1. **Gameplay**
   - `main.tscn`
   - `player.tscn`
   - `basket.tscn`
2. **Menus**
   - `main_menu.tscn`
   - `option_menu.tscn`
   - `break_menu.tscn`
3. **Tutoriel**
   - `tutorial.tscn`
4. **Environnement**
   - `apple_tree.tscn`
   - `tree.tscn`
5. **Interface**
   - `interface.tscn`
   - `user_menu.tscn`
6. **Effets et transitions**
   - `particles_pannier.tscn`
   - `transition.tscn`

## Pourquoi cette structure ?

- Beaucoup de fichiers `.tscn` sont des variantes ou des scènes secondaires.
- Se concentrer sur les scènes clés réduit le travail tout en couvrant l’essentiel.
- Les détails spécifiques peuvent rester dans le code plutôt que dans la documentation.

## Exemple de contenu

**`main.tscn`**
- Objectif : scène de jeu principale
- Contenu : joueur, environnement, UI
- Scripts associés : `main.gd`

**`player.tscn`**
- Objectif : contrôles du joueur
- Contenu : caméra, collisions, inputs
- Scripts associés : `player.gd`

**`main_menu.tscn`**
- Objectif : écran d’accueil
- Contenu : boutons, navigation vers le jeu
- Scripts associés : `main_menu.gd`

## Note

Il n’est pas nécessaire de créer un document séparé pour chaque scène ou asset.
Regrouper par section est plus efficace pour un projet scolaire.