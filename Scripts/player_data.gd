extends Node

var user_id = -1
var token = ""
var uuid = ""
var age = ""
var medecin_key = ""
var is_guest = true
var session_id : String
var access_token := ""
var refresh_token := ""
var access_token_expires_at := 0

func _clear_profile() -> void:
	user_id = -1
	token = ""
	uuid = ""
	age = ""
	medecin_key = ""

func _clear_api_tokens() -> void:
	access_token = ""
	refresh_token = ""
	access_token_expires_at = 0

func set_user(id, u, t, a, m = ""):
	user_id = id
	uuid = u
	token = t
	age = a
	medecin_key = m
	is_guest = false

func set_guest(id):
	user_id = id
	uuid = ""
	token = ""
	age =""
	medecin_key = ""
	is_guest = true

func logout_user():
	_clear_profile()
	is_guest = false
	_clear_api_tokens()

# DEBUG
func print_data():
	pass
