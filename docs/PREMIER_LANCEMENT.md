# Guide de Démarrage - AppleGame

## Installation et Configuration

### 1. Pré-requis

- **Godot Engine 4.6** ou plus récent ([Télécharger](https://godotengine.org/download))
- **Git** pour le contrôle de version
- Pour Android : **Android SDK** et **Android NDK**

### 2. Ouvrir le Projet

1. Ouvrir Godot Engine
2. Cliquer sur "Ouvrir un projet"
3. Sélectionner le dossier `apple-game`
4. Cliquer sur "Ouvrir et éditer"

### 3. Premier Lancement

Dans l'éditeur Godot, cliquer sur le bouton **Play** en haut à droite ou utiliser le raccourci **F5**. Le jeu démarrera dans la scène principale

## Structure des Fichiers

```
apple-game/
├── Scenes/           # Scènes Godot du jeu
├── Scripts/          # Code GDScript (logique du jeu)
├── Assets/           # Ressources (modèles, textures, sons)
├── addons/           # Extensions Godot
├── docs/             # Documentation
├── project.godot     # Configuration du projet
└── README.md         # Page d'accueil
```

## Contrôles du Jeu

### Mobile (Joystick virtuel)
- **Zone gauche** : Déplacer la caméra à gauche ou droite
- **Zone droite** : Avancer et valider sa position

## Scripts Principaux

| Script | Rôle |
|--------|------|
| `main.gd` | Gestion de la scène principale et logique de jeu |
| `player.gd` | Contrôle du joueur |
| `game_manager.gd` | Gestion des API et authentification |
| `file_manager.gd` | Sauvegarde/Chargement des données |
| `basket.gd` | Gestion du panier et collecte |

