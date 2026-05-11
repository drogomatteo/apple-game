# Architecture du Projet - AppleGame

## Vue d'Ensemble

AppleGame suit une architecture modulaire basée sur Godot Engine. Le projet est organisé en trois couches principales :

```
┌─────────────────────────────────┐
│   Interface Utilisateur (UI)    │ - Menus, HUD, Bouttons
├─────────────────────────────────┤
│   Logique de Jeu (Scripts)      │ - Gestion des arbres, collecte
├─────────────────────────────────┤
│   Backend API                   │ - Authentification, sync données
└─────────────────────────────────┘
```

## Couches de l'Application

### 1. Couche Présentation (UI)

Répertoire : `Scenes/`. Les scènes sur Godot sont utilisés pour construire le jeu vidéo et pour qu'utilisateur puisse interagir avec l'application (bouton, zone de texte)

Dans l'ordre d'apparition :

- **apple_tree.tscn** : le pommier
- **Barrières.tscn** : les barrières
- **basket.tscn** : le panier
- **break_menu.tscn** : Gestion du menu pause
- **Daltonien.tscn** : Gestion du mode Daltonien
- **gdpr_menu.tscn** : Conformité GDPR
- **info_menu.tscn** : Secion à propos
- **Interface.tscn** : Scène 3D du menu principal
- **main.tscn** : Le jeu
- **main_menu.tscn** : Menu principal du jeu
- **option_menu.tscn** : Options de jeu
- **ParticulesPannier.tscn** : Particules du panier (PAS UTILISÉ DANS LA VERSION FINALE)
- **player.tscn** : Le joueur
- **tavern.tscn** : Le repère visuel
- **tavernBis.tscn** : Le repère visuel (avec modification des collisions)
- **tracerCarte.tscn** : Le système d'affichage de résumé de niveau
- **transition.tscn** : Transition entre scènes main et main_menu
- **tree.tscn** : L'arbre
- **user_menu.tscn** : Le menu compte

### 2. Couche Logique de Jeu

Répertoire : `Scripts/`. Les scripts sont utilisés par Godot pour gérer l'aspect logique du jeu vidéo comme le déplacement du joueur, la création du monde, le tutoriel, etc...

**Gestion du Joueur** :
- `player.gd` - Contrôle et mouvement du joueur
- `player_data.gd` - Données persistantes du joueur

**Gestion du Jeu** :
- `main.gd` - Logique principale du jeu
- `game_manager.gd` - Gestion centrale (autoload)
- `tutorial.gd` - Système de tutoriel

**Système de Collecte** :
- `basket.gd` - Gestion du panier et collecte de pommes
- `apple_tree.tscn` - Représentation des pommiers

**Environnement** :
- `grass_system.gd` - Système d'herbe et terrain
- `tracer_carte.gd` - Génération de la carte

**Données** :
- `file_manager.gd` - Sauvegarde/Chargement (autoload)
- `sync_manager.gd` - Synchronisation avec le serveur

### 3. Couche Données & Backend

**API Backend** :
- `api.gd` - Communication avec le serveur
- `ui_api.gd` - API pour l'UI

**Serveur** :
- URL : `https://alzheimer.magellan.fpms.ac.be/api/`
- Endpoints principaux :
  - `/auth/token/` - Authentification
  - `/auth/refresh/` - Renouvellement de token
  - Endpoints de niveau (levels-v1)

## Système d'Autoload (Singletons)

Les autoloads sont des scripts chargés automatiquement au démarrage (voir `project.godot`) :

| Autoload | Script | Rôle |
|----------|--------|------|
| `Settings` | `settings.gd` | Configuration globale du jeu |
| `Transition` | `scene_transition.gd` | Transitions entre scènes |
| `ColourBind` | `colour_bind.gd` | Gestion du mode colorblind |
| `FileManager` | `file_manager.gd` | Sauvegarde/Chargement |
| `GameManager` | `game_manager.gd` | Gestion API & auth |
| `PlayerData` | `player_data.gd` | Données du joueur |
| `SyncManager` | `sync_manager.gd` | Synchronisation données |
| `Api` | `api.gd` | Requêtes API directes |


## Système de Physique

Le Système de physique permet de gérer les collisions entre les objets du type `CollisionObject3D`. Afin de rendre l'ajout d'objet facilement, chaque couche possède un nom. Il faut que les deux objets possèdent au moins une même couche `Layers` et `Mask`.

> [!NOTE]
> Pour plus d'informations concernant les attributs `Layers` et `Mask`, veuillez vous référer à la documentation Godot de l'objet `CollisionObject3D` : https://docs.godotengine.org/en/4.6/classes/class_collisionobject3d.html

- **Moteur** : Jolt Physics
- **Layers** :
  - Layer 1 : Joueur
  - Layer 2 : Repère visuel
  - Layer 3 : Panier
  - Layer 4 : Arbre
  - Layer 5 : Pommier

## Système d'Assets

**Dossiers** :
- `Assets/Models/` - Modèles 3D (.glb)
- `Assets/Textures/` - Images texturées
- `Assets/Shader/` - Shaders custom
- `Assets/Sound/` - Fichiers audio
- `Assets/Herbe/` - Système d'herbe

## Points d'Extension

Pour ajouter des fonctionnalités :

1. **Nouvelles mécaniques de jeu** → Ajouter dans `Scripts/main.gd` ou créer un nouveau script
2. **Nouveaux menus** → Créer une scène dans `Scenes/` + script associé
3. **Nouveaux modèles 3D** → Ajouter dans `Assets/Models/`
4. **Nouveaux shaders** → Ajouter dans `Assets/Shader/`
