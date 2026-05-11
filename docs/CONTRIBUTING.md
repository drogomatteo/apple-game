# Guide de Contribution - AppleGame

## Pour les Contributeurs

Merci de l'intérêt pour AppleGame ! Ce guide explique comment contribuer de manière efficace.

## Processus de Contribution

### 1. Forker et Cloner

```bash
# Forker le projet sur GitHub (bouton fork)
# Puis cloner votre fork
git clone https://github.com/VOTRE-USERNAME/apple-game.git
cd apple-game
```

### 2. Créer une Branche

```bash
# Toujours créer une branche pour vos changements
git checkout -b feature/ma-fonctionnalite
# ou
git checkout -b fix/mon-bug
```

### 3. Commit et Push

```bash
git add .
git commit -m "Ajouter ma fonctionnalité"
git push origin feature/ma-fonctionnalite
```

### 4. Pull Request

- Ouvrir une Pull Request sur GitHub
- Remplir le template PR avec une description claire
- Attendre la review des mainteneurs

## Normes de Codage

### GDScript

```gdscript
# Bon ✓
extends Node

func calculate_distance(point_a: Vector3, point_b: Vector3) -> float:
    return point_a.distance_to(point_b)

var player_health := 100
var enemy_count: int

# Mauvais ✗
extends Node
func calc(a,b):
    return a.distance_to(b)
var hp=100
```

**Règles** :
- ✓ Noms de variables en `snake_case`
- ✓ Noms de fonctions en `snake_case`
- ✓ Ajouter des types aux variables
- ✓ Commenter le code complexe
- ✓ Une fonction = une responsabilité

### Structure des Fichiers

```
Scripts/
├── core/                    # Systèmes principaux
│   ├── player.gd
│   ├── game_manager.gd
├── ui/                      # Code UI
│   ├── main_menu.gd
│   ├── interface.gd
├── managers/                # Managers (autoloads)
│   ├── file_manager.gd
│   ├── sync_manager.gd
└── utils/                   # Utilitaires
    └── api.gd
```

## Types de Contributions

### 1. Corrections de Bugs

- Créer une issue décrivant le bug
- Créer une branche `fix/nom-du-bug`
- Inclure un test si possible
- Référencer l'issue dans la PR

### 2. Nouvelles Fonctionnalités

- **Petites features** : Directement une branche + PR
- **Grandes features** : Discuter dans une issue d'abord
- Fournir une description claire de la fonctionnalité
- Inclure des commentaires explicatifs

### 3. Documentation

- Mettre à jour les `.md` correspondants
- Garder les exemples à jour
- Vérifier les liens

## Avant de Soumettre

### Checklist

- [ ] Code testé et fonctionnel
- [ ] Pas d'erreurs Godot
- [ ] Types de variables ajoutés
- [ ] Code commenté (si complexe)
- [ ] Respecte les normes de codage
- [ ] Documentation mise à jour si nécessaire
- [ ] Pas de dépendances externes non documentées

### Tests dans Godot

1. Lancer le jeu avec **F5**
2. Tester la fonctionnalité ajoutée
3. Vérifier qu'aucune erreur n'apparaît dans la console
4. Tester sur différentes résolutions si c'est de l'UI

## Communication

- **Discussions générales** : GitHub Discussions
- **Bug reports** : GitHub Issues avec template
- **Grands changements** : Discuter dans une issue d'abord
- **Contact rapide** : Voir les coordinateurs du projet

## Cycle de Review

1. PR soumise
2. Review automatique (lint, build)
3. Review manuelle par un mainteneur
4. Modifications demandées (si nécessaire)
5. Approbation et merge

## Conseils

✓ Faire des commits petits et logiques
✓ Écrire des messages de commit clairs
✓ Un changement = une PR
✓ Tester avant de soumettre
✓ Être respectueux dans les discussions

## Questions ?

Consulter [GETTING_STARTED.md](GETTING_STARTED.md) pour l'installation.
Consulter [ARCHITECTURE.md](ARCHITECTURE.md) pour comprendre le code.
