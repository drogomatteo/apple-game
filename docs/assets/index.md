# 🎨 Assets et Ressources

Cette page décrit la gestion des ressources du projet AppleGame.
Ici, l'objectif est de centraliser les règles d'organisation, d'import et d'optimisation des assets.

## Types d'assets

- **Modèles 3D** : objets du jeu, environnement et éléments de décor.
- **Textures** : images pour matériaux, terrain et UI.
- **Shaders** : effets visuels pour terrain et objets.
- **Audio** : sons de collecte, voix et ambiances.
- **UI** : thèmes, icônes et éléments d'interface.
- **Particules** : effets visuels du gameplay.

## Organisation

Les ressources sont classées par type dans le dossier `Assets/` :

- `Assets/Models/`
- `Assets/Textures/`
- `Assets/Sound/`
- `Assets/Shader/`
- `Assets/UI-UX/`
- `Assets/Particles/`

## Pipeline d'import

### Modèles 3D

1. Exporter en GLTF/GLB depuis Blender ou un autre outil.
2. Importer dans Godot en conservant les `CollisionShape` lorsque nécessaire.
3. Vérifier les matériaux, les UV et la taille du modèle.
4. Optimiser pour mobile : simplifier les maillages et utiliser des textures compressées.

### Textures

1. Utiliser des formats adaptés (`PNG`, `JPG`, `WEBP`).
2. Générer des mipmaps pour améliorer l'affichage.
3. Vérifier l'orientation et la taille.
4. Appliquer des cartes normales lorsque c'est utile.

### Audio

1. Préférer `OGG` pour l'équilibre qualité/taille.
2. Tester le bouclage et l'atténuation.
3. Doit rester léger pour un usage mobile.

## Optimisation

- **Compression** : réduire la taille des assets.
- **LOD** : utiliser des niveaux de détail pour les modèles lourds.
- **Atlas** : regrouper les textures lorsque possible.
- **Cache** : réutiliser les ressources partagées.

## Conventions de nommage

- `snake_case` pour les fichiers.
- Préfixer selon le type : `mdl_`, `tex_`, `snd_`, `ui_`.
- Suffixer par variante : `_diffuse`, `_normal`, `_01`.

## Bonnes pratiques

- Documenter chaque ressource importante.
- Garder les assets inutilisés hors du projet final.
- Vérifier les licences et crédits des ressources externes.
