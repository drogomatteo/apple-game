extends Node

var user_id = -1
var token = ""
var uuid = ""
var age = ""
var is_guest = true
var session_id : String

func set_user(id, u, t,a):
	print("[AUTH] Logging in user")
	user_id = id
	uuid =u
	token = t
	age =a
	is_guest = false

func set_guest(id):
	print("[AUTH] Logging in guest")
	user_id = id
	uuid = ""
	token = ""
	age =""
	is_guest = true

func logout_user():
	print("[AUTH] Logging out user/guest")

	PlayerData.user_id = -1
	PlayerData.token = ""
	PlayerData.uuid = ""
	PlayerData.age= ""
	PlayerData.is_guest = false


# DEBUG
func print_data():
	print("User ID:", user_id)
	print("uuid:", uuid)
	print("Token:", token)
	print("Age:", age)
	print("Guest:", is_guest)
