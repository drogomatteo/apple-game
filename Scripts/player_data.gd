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

func set_user(id, u, t, a, m = ""):
	user_id = id
	uuid =u
	token = t
	age =a
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
	PlayerData.user_id = -1
	PlayerData.token = ""
	PlayerData.uuid = ""
	PlayerData.age= ""
	PlayerData.medecin_key = ""
	PlayerData.is_guest = false
	PlayerData.access_token = ""
	PlayerData.refresh_token = ""
	PlayerData.access_token_expires_at = 0


# DEBUG
func print_data():
	pass
