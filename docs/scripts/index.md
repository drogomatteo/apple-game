# Scripts GDScript

Cette page donne une vue d'ensemble des scripts principaux du projet AppleGame.

## Rôle des scripts

Les scripts du répertoire `Scripts/` forment la logique de jeu, l'interface utilisateur, la communication backend et les services partagés.

## Principales familles

### Autoloads

- `game_manager.gd` : orchestrateur du jeu, connexion API et gestion des états.
- `settings.gd` : configuration globale et préférences utilisateur.
- `file_manager.gd` : sauvegarde et chargement local.
- `player_data.gd` : données persistantes du joueur.
- `sync_manager.gd` : synchronisation du jeu avec le serveur.

### Gameplay

- `main.gd` : logique principale du jeu, gestion de la phase, récolte des données et création du fichier.
- `player.gd` : contrôles du joueur.
- `basket.gd` : animation du panier.
- `tutorial.gd` : déroulement du tutoriel et guidage.
- `grass_system.gd` : gestion de l'affichage de l'herbe.

### Interface utilisateur

- `main_menu.gd` : navigation aux autres scènes.
- `option_menu.gd` : gestion des options.
- `break_menu.gd` : gestion du menu pause.
- `interface.gd` : affichage de l'interface en jeu.
- `user_menu.gd` : gestion du profil utilisateur.
- `info_menu.gd` : écran d'information.
- `gdpr_menu.gd` : conformité RGPD.

### Backend et API

- `api.gd` : communication avec le serveur distant.
- `ui_api.gd` : interface d'API pour l'utilisateur.
- `colour_bind.gd` : adaptation des couleurs pour le mode daltonien.

### Utilitaires

- `scene_transition.gd` : transitions entre la scène `main.tscn` et `main_menu.tscn`.
- `tracer_carte.gd` : génération de la carte et aperçu de niveau.
