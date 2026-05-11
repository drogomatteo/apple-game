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

Répertoire : `Scenes/`

- **main_menu.tscn** : Menu principal
- **option_menu.tscn** : Options de jeu
- **Interface.tscn** : HUD du jeu (barre de vie, score, etc.)
- **break_menu.tscn** : Menu de pause
- **gdpr_menu.tscn** : Conformité GDPR
- **Daltonien.tscn** : Mode colorblind

Fichiers correspondants : `Scripts/*_menu.gd`, `Scripts/interface.gd`

### 2. Couche Logique de Jeu

Répertoire : `Scripts/`

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

## Flux de Données

```
Joueur → player.gd → main.gd → basket.gd
                        ↓
                    file_manager.gd ← FileManager (autoload)
                        ↓
                    sync_manager.gd ← SyncManager (autoload)
                        ↓
                    api.gd (GameManager) → Backend
```

## Système de Scènes

Godot utilise une hiérarchie de scènes :

```
main.tscn (Scene racine)
├── Player (player.tscn)
│   ├── Camera3D
│   ├── CanvasLayer
│   │   └── UI (Contrôles mobiles)
├── Environnement
│   ├── Herbe (grass_system.gd)
│   ├── Arbres dynamiques
├── UI (Interface.tscn)
│   ├── HUD
│   ├── Bouttons
│   └── Zone de texte
└── Panier (basket.tscn)
```

## Système de Physique

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
