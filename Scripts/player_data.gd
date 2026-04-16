extends Node

var user_id = -1
var token = ""
var uuid = ""
var is_guest = true
var is_server_synced = false
var medecins : Array = []
var session_id : String

func set_user(id, u, t):
	print("[AUTH] Logging in user")
	user_id = id
	uuid =u
	token = t
	is_guest = false

func set_guest(id):
	print("[AUTH] Logging in guest")
	user_id = id
	uuid = ""
	token = ""
	is_guest = true


func set_server_synced(value: bool) -> void:
	is_server_synced = value


func set_medecins(value: Array) -> void:
	medecins = value.duplicate(true)


func has_medecins() -> bool:
	return not medecins.is_empty()

func logout_user():
	print("[AUTH] Logging out user/guest")

	PlayerData.user_id = -1
	PlayerData.token = ""
	PlayerData.uuid = ""
	PlayerData.is_guest = false
	PlayerData.is_server_synced = false
	PlayerData.medecins = []


# DEBUG
func print_data():
	print("User ID:", user_id)
	print("uuid:", uuid)
	print("Token:", token)
	print("Guest:", is_guest)
	print("Server synced:", is_server_synced)
	print("Medecins:", medecins)
