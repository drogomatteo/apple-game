# Intégration API - AppleGame

## Vue d'Ensemble

AppleGame communique avec un serveur backend pour :
- Authentification des utilisateurs
- Synchronisation des données de progression
- Génération de niveaux
- Sauvegarde des résultats

**URL de Base** : `https://alzheimer.magellan.fpms.ac.be/api/`

## Authentification

### Flow Authentification

```
┌─────────────────────┐
│ Utilisateur login   │
└──────────┬──────────┘
           ↓
┌─────────────────────────────────────┐
│ POST /auth/token/                   │
│ Body: { username, password, key }   │
└──────────┬──────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│ Response:                           │
│ { access_token, refresh_token, ... }│
└──────────┬──────────────────────────┘
           ↓
┌─────────────────────┐
│ Token stocké        │
│ Jeu lancé           │
└─────────────────────┘
```

### Endpoints Authentification

#### POST /auth/token/

**Obtenir un token d'accès**

```
Request:
POST /auth/token/
Headers:
  X-Game-Api-Key: pL6UIb8R486IeTDv7arnpqm7NuJkQbHGesgpBIzClec
Body:
{
  "username": "utilisateur",
  "password": "motdepasse"
}

Response (200):
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "expires_in": 900
}

Erreur (401):
{
  "detail": "Invalid credentials"
}
```

#### POST /auth/refresh/

**Renouveler le token d'accès**

```
Request:
POST /auth/refresh/
Headers:
  X-Game-Api-Key: [API_KEY]
Body:
{
  "refresh_token": "..."
}

Response (200):
{
  "access_token": "...",
  "expires_in": 900
}
```

## Gestion des Niveaux

### GET /levels/

**Récupérer les niveaux disponibles**

```
Request:
GET /levels/?format=levels-v1
Headers:
  Authorization: Bearer [ACCESS_TOKEN]

Response:
[
  {
    "id": 1,
    "name": "Tutorial",
    "difficulty": "easy",
    "apple_count": 5,
    "time_limit": null,
    "basket_size": 5,
    "version": "levels-v1"
  },
  {
    "id": 2,
    "name": "Garden Zone 1",
    "difficulty": "easy",
    "apple_count": 10,
    "time_limit": 300,
    "basket_size": 10,
    "version": "levels-v1"
  }
]
```

## Sauvegarde de Données

### POST /progress/

**Sauvegarder la progression d'un niveau**

```
Request:
POST /progress/
Headers:
  Authorization: Bearer [ACCESS_TOKEN]
  Content-Type: application/json
Body:
{
  "level_id": 2,
  "score": 1250,
  "completion_time": 125,
  "apples_collected": 10,
  "status": "completed",
  "timestamp": "2026-05-11T14:30:00Z"
}

Response (201):
{
  "id": 1001,
  "user": 42,
  "level_id": 2,
  "score": 1250,
  "created_at": "2026-05-11T14:30:00Z"
}
```

### GET /progress/

**Récupérer l'historique de progression**

```
Request:
GET /progress/?user_id=42
Headers:
  Authorization: Bearer [ACCESS_TOKEN]

Response:
[
  {
    "id": 1000,
    "level_id": 1,
    "score": 500,
    "completion_time": 60,
    "status": "completed",
    "timestamp": "2026-05-10T10:00:00Z"
  },
  {
    "id": 1001,
    "level_id": 2,
    "score": 1250,
    "completion_time": 125,
    "status": "completed",
    "timestamp": "2026-05-11T14:30:00Z"
  }
]
```

## Implémentation en GDScript

### Classe GameManager

```gdscript
# Scripts/game_manager.gd
extends Node

const BASE_URL := "https://alzheimer.magellan.fpms.ac.be/api/"
const GAME_API_KEY := "pL6UIb8R486IeTDv7arnpqm7NuJkQbHGesgpBIzClec"

var auth_http := HTTPRequest.new()
var access_token := ""
var refresh_token := ""

func _ready():
    add_child(auth_http)
    auth_http.timeout = 5.0

func login(username: String, password: String):
    var url = BASE_URL + "auth/token/"
    var headers = ["X-Game-Api-Key: " + GAME_API_KEY]
    var body = {"username": username, "password": password}
    
    var error = auth_http.request(
        url,
        headers,
        HTTPClient.METHOD_POST,
        JSON.stringify(body)
    )
    
    if error != OK:
        push_error("Erreur requête login:", error)
```

## Codes d'Erreur

| Code | Signification | Action |
|------|---------------|--------|
| 200 | OK | Requête réussie |
| 201 | Created | Ressource créée |
| 400 | Bad Request | Données invalides |
| 401 | Unauthorized | Token invalide/expiré |
| 403 | Forbidden | Pas de permission |
| 404 | Not Found | Ressource inexistante |
| 500 | Server Error | Erreur serveur |

## Gestion des Tokens

### Durée de Vie

- **Access Token** : 900s (15 min)
- **Refresh Token** : 7 jours

### Refresh Automatique

```gdscript
func _process(delta):
    if should_refresh_token():
        refresh_access_token()

func should_refresh_token() -> bool:
    # Refresh si expiration dans < 60s
    return get_token_expiry() < 60
```

## Sauvegarde Hors-Ligne

Les données non synchronisées sont stockées dans :
```
user://offline_uploads/
```

Lors de la reconnexion, le `SyncManager` envoie les données mises en cache.

## Déboguer les Requêtes API

Voir les logs Godot :
```
Output → Debug Console
```

Pour activer les logs détaillés dans `project.godot` :
```ini
[debug]
gdscript/warnings/return_value_discarded=false
```

## Sécurité

⚠️ **IMPORTANT** :
- Ne JAMAIS commiter le `GAME_API_KEY` en clair
- Utiliser un fichier `.env` (non versionné)
- Valider TOUTES les données du serveur
- Implémenter rate limiting côté client

## Endpoints Futures

Plans pour v2.0 :
- Leaderboard global
- Achievements/Badges
- Replay system
- Social features
