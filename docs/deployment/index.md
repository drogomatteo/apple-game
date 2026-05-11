# 🚀 Déploiement AppleGame

Cette page donne un aperçu des options de déploiement pour le projet AppleGame.

## Déploiement Android

- Le projet cible principalement Android.
- Les paramètres d'export sont définis dans `export_presets.cfg`.
- Le dossier `android/` contient la configuration et les fichiers nécessaires à l'export.
- Utiliser Godot pour générer un APK ou AAB compatible avec Android 12+.

## Déploiement web (optionnel)

- Godot peut exporter une version HTML5 si le projet est adapté.
- La version web est une option secondaire et demande des tests supplémentaires.
- Il faut vérifier les performances dans le navigateur et l'utilisation mémoire.

## Bonnes pratiques

- Tester le build sur un appareil réel.
- Vérifier les permissions Android avant publication.
- Minimiser la taille des assets pour réduire le temps de chargement et l'espace occupé.
