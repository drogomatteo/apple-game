# 🗂️ Structure du projet AppleGame

Cette page présente l'organisation principale du dépôt et les fichiers techniques importants.

## Fichiers racine

- `project.godot` : fichier de projet Godot principal.
- `export_presets.cfg` : paramètres d'export pour les builds Android.
- `README.md` : page d'accueil du dépôt GitHub.
- `requirements.txt` : dépendances Python pour MkDocs.
- `mkdocs.yml` : configuration du site de documentation.
- `AndroidManifest.xml` et fichiers Android dans `android/`.

## Dossiers principaux

- `Scenes/` : scènes Godot du jeu.
- `Scripts/` : scripts GDScript du projet.
- `Assets/` : ressources graphiques, audio et 3D.
- `PommeAnimation/` : animations spécifiques de pommes.
- `android/` : configuration Android et réglages d'export.
- `addons/` : extensions Godot utilisées par le projet.

## Outils utiles

- `tools/get_version.py` : récupère ou met à jour les versions dans le projet.
- `tools/set_version.py` : script d'automatisation de versionnement.
- `tools/set_version.ps1` : version PowerShell du script.

## Objectif

Regrouper la documentation sur la structure du projet permet de retrouver rapidement les fichiers essentiels et de comprendre où se trouvent les éléments clés du jeu.
