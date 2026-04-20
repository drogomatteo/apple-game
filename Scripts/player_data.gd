extends Node

var user_id = -1
var token = ""
var uuid = ""
var age = ""
var medecin_key = ""
var is_guest = true
var session_id : String

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


# DEBUG
func print_data():
	pass
