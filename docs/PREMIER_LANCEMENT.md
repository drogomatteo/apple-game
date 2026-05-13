# Premier Lancement

## Installation et Configuration

### 1. Pré-requis

- **Godot Engine 4.6.1** ([Télécharger](https://godotengine.org/download))
- **Android SDK** et **Android NDK**, pour la compilation du projet sur mobile ([Télécharger](https://developer.android.com/studio/index.html))


### 2. Ouvrir le Projet

1. Ouvrir Godot Engine
2. Cliquer sur "Ouvrir un projet"
3. Sélectionner le dossier `apple-game`
4. Cliquer sur "Ouvrir et éditer"

### 3. Premier Lancement

Dans l'éditeur Godot, cliquer sur le bouton **Play** en haut à droite ou utiliser le raccourci `F5`. Le jeu démarrera dans une nouvelle fenètre.

### 4. Arrêter le projet

Si vous voulez arrêter le projet, il suffit de soit fermer la fenêtre, soit appuyer sur le bouton **Stop** en haut à droite.

## Navigation dans le jeu

### Menu RGPD

Le menu RGPD est le premier menu qu'il s'affichera sur votre écran. Plus tard, si vous avez accepté le RGPD, alors vous serrez renvoyer directement dans le menu [Menu Principal](#menu-principal).

S'il s'agit de votre premier lancement du jeu, vous serez redirigé vers le [Menu Compte](#menu-compte) pour que vous puissez vous en créer un.

### Menu Compte

Le menu compte contient trois zones textes :

- Le token du joueur. Ce token est choisi par le joueur, tant qu'il n'existe pas dans la base de données. Il est possible de générer de façon aléatoire un token en appuyant sur le bouton `Aléatoire`.
- La date de naissance du joueur.
- La clé du médecin. Ce champ est optionnel. Il est obligatoire de le remplir par une clé existante dans la base de données.

Ensuite, pour se créer un compte, il faut appuyer sur le bouton `Créer un compte`.

Si par la suite vous souhaitez vous reconnecter avec ce compte, il faut appuyer sur le bouton `Se connecter`.

### Menu Principal

Le menu principal est le centre du jeu. Il contient l'accès à toutes les scènes. Depuis la scène `Menu principal`, il est possible de quitter le jeu grâce au bouton `Quitter`.

Il est possible de lancer le jeu à partir du bouton `Jouer`. Pour apporter des modifications aux options, il faut cliquer sur le rouage en bas à droite. Le cadena permet de retourner au [menu RGPD](#menu-rgpd). Le bouton `Info` permet d'aller sur le [Menu À propos](#à-propos).

### Menu À propos

Le menu À propos pose le contexte du projet, les personnes qui ont contribués et son état de dévellopement.

### Menu Option

Le menu option contient pour l'instant deux options :

- Ajout/retrait des bruits de pas
- Possibilité d'appliquer un filtre couleur pour les daltoniers.

Il est voué à contenir d'autres paramètres graphismes pour rendre le jeu plus accessible.
