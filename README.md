# AppleGame

Projet Réalisé par Eva Kabelis, Tom Boreux, Matteo Drogo et Martin Lempite, quatre étudiants de la faculté polytechnique de Mons en troième bachelier, supervisé par le professeur Mohammed Benjelloun et le promoteur Quentin De Coninck.

## Description

*AppleGame* est une application mobile développer dans le but d'évaluer l'orientation spatiale lié à la maladie d'Alzheimer.

## Fonctionnalités

- Environnement de jardin 3D avec éléments interactifs
- Gameplay de collecte de pommes
- Système de gestion de panier
- Plusieurs niveaux et défis
- Sauvegarde et synchronisation en ligne des progrès
- Interface conviviale avec options d'accessibilité
- Support du mode daltonien
- Menu de conformité RGPD

## Structure du Projet

- `Scenes/` : Scènes de jeu et éléments UI
- `Scripts/` : Fichiers GDScript pour la logique de jeu
- `Assets/` : Modèles 3D, textures, sons et shaders
- `addons/` : Addons Godot (plugin Git)

## Intégration API

Le jeu s'intègre avec une API backend pour :
- Authentification utilisateur
- Sauvegarde des progrès
- Synchronisation des données de niveau

Point de terminaison API : https://alzheimer.magellan.fpms.ac.be/api/

## Documentation

La documentation complète du projet se trouve dans le dossier [`docs/`](docs/) :

- [Guide de Démarrage](docs/GETTING_STARTED.md) - Installation et premiers pas
- [Architecture du Projet](docs/ARCHITECTURE.md) - Structure technique
- [Mécanique de Jeu](docs/GAMEPLAY.md) - Règles et gameplay
- [Intégration API](docs/API.md) - Documentation des endpoints
- [Guide de Contribution](docs/CONTRIBUTING.md) - Comment contribuer

## Plus d'informations

Pour plus d'informations sur AppleGame, veuillez consulter le site dédié : https://alzheimer.magellan.fpms.ac.be/
