extends Node

const SETTINGS_PATH := "user://settings.json"

var sound: bool = true
var daltonien: int = 0
var tutorial_seen: bool = false

func _ready() -> void:
	charger_parametres()
	Daltonien._mettre_a_jour_daltonien(daltonien)

func definir_mode_daltonien(mode: int) -> void:
	daltonien = mode
	Daltonien._mettre_a_jour_daltonien(daltonien)
	sauvegarder_parametres()

func definir_sound(value: bool) -> void:
	sound = value
	sauvegarder_parametres()

func definir_tutorial_seen(value: bool) -> void:
	tutorial_seen = value
	sauvegarder_parametres()

func sauvegarder_parametres() -> void:
	var data := {
		"sound": sound,
		"daltonien": daltonien,
		"tutorial_seen": tutorial_seen
	}

	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		print("Impossible de sauvegarder les paramètres")
		return

	file.store_string(JSON.stringify(data))
	file.close()

func charger_parametres() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		sauvegarder_parametres()
		return

	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		print("Impossible de lire les paramètres")
		return

	var content := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("Fichier de paramètres invalide")
		return

	sound = parsed.get("sound", true)
	daltonien = parsed.get("daltonien", 0)
	tutorial_seen = parsed.get("tutorial_seen", false)
