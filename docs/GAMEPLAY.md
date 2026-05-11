# Mécanique de Jeu - AppleGame

## Objectif Principal

Collecter des pommes dans un jardin pour évaluer les capacités d'orientation spatiale liées à Alzheimer.

## Mécanique de Collecte

### Système de Pommes

- **Source** : Les pommes apparaissent sur les pommiers
- **Collection** : S'approcher et interagir avec une pomme
- **Stockage** : Les pommes collectées vont dans le panier
- **Score** : Chaque pomme = points

### Panier

Le panier fonctionne comme inventaire :
- **Capacité** : Définie par niveau
- **Limite** : Une fois plein, ne peut plus collecter
- **Vidage** : Apporter le panier à la zone de livraison
- **Points** : Bonus si livraison rapide

## Système de Niveaux

### Progression

```
Niveau 1 (Tutoriel)
    ↓
Niveau 2-5 (Facile)
    ↓
Niveau 6-10 (Moyen)
    ↓
Niveau 11+ (Difficile)
```

### Paramètres par Niveau

| Paramètre | Tutoriel | Facile | Moyen | Difficile |
|-----------|----------|--------|-------|-----------|
| Pommes | 5 | 10 | 20 | 30+ |
| Temps | ∞ | 5 min | 3 min | 2 min |
| Zones | 1 | 2 | 3 | 4+ |
| Panier | 5 | 10 | 15 | 20 |

## Système de Santé

- **Points de Vie** : 100 HP au départ
- **Dégâts** : Obstacles causent 10-20 HP
- **Régénération** : +5 HP par seconde (arrêté)
- **Mort** : Jeu terminé si 0 HP

## Système de Score

### Points Gagnés

- Pomme collectée : +10 pts
- Panier livré : +50 pts
- Bonus temps : +100 pts (si < 1 min)
- Complétion niveau : +200 pts

### Multiplicateurs

- Collecte rapide (< 30s) : x1.5
- Sans dégâts : x2
- Panier au maximum : x1.2

## Système de Temps

- **Compteur** : Compte en avant
- **Limite** : Définie par niveau
- **Alerte** : 30s avant expiration
- **Conséquence** : Fin du niveau si dépassée

## Tutoriel

### Déroulement

1. **Intro** : Explication des contrôles
2. **Mouvement** : Apprendre à se déplacer
3. **Interaction** : Collecter la première pomme
4. **Panier** : Livrer le panier
5. **Fin** : Score et retour au menu

## Accessibilité

### Mode Colorblind

- Palettes ajustées pour daltonisme
- Icônes additionnelles au-delà des couleurs
- Textes de description renforcés

### Contrôles Mobiles

```
┌─────────┬─────────┐
│ GAUCHE  │ DROITE  │
│ Mouv.   │ Interact│
└─────────┴─────────┘
```

- Zone gauche : Joystick de mouvement
- Zone droite : Bouton d'interaction
- Responsive au toucher

## Données Sauvegardées

```json
{
    "player_level": 5,
    "total_score": 1250,
    "levels_completed": [1,2,3,4,5],
    "best_times": {
        "level_1": 45,
        "level_2": 120
    },
    "achievements": ["first_apple", "speedrun"],
    "last_played": "2026-05-10T14:30:00"
}
```

## Progression d'un Niveau Typique

```
┌────────────────────┐
│ Début du niveau    │
└────────────┬───────┘
             ↓
┌────────────────────┐
│ Spawn à la base    │
│ HUD affiche...     │
│ - Pommes restantes │
│ - Temps limite     │
│ - Panier (vide)    │
└────────────┬───────┘
             ↓
┌────────────────────┐
│ Joueur navigue     │
│ et collecte pommes │
└────────────┬───────┘
             ↓
┌────────────────────┐
│ Panier plein ?     │
│ NON: Continuer     │
│ OUI: Livrer        │
└────────────┬───────┘
             ↓
┌────────────────────┐
│ Tous objectifs OK? │
│ NON: Continuer     │
│ OUI: Fin niveau    │
└────────────┬───────┘
             ↓
┌────────────────────┐
│ Résultats & Score  │
│ Débloquer next lvl │
└────────────────────┘
```

## Système de Feedback Joueur

### Visuel
- Particules lors de collecte
- Flash d'écran lors de dégâts
- Barre de progression du panier

### Sonore
- Son de collecte (ding)
- Son de livraison
- Son d'alerte temps
- Musique adaptée à tension

### Textuel
- Messages en haut d'écran
- Notifications pour panier plein
- Alerte danger
