extends Node

var user_id = -1
var token = ""
var uuid = ""
var is_guest = true
var session_id : String

func set_user(id, u, t):
	user_id = id
	uuid =u
	token = t
	is_guest = false

func set_guest(id):
	user_id = id
	uuid = ""
	token = ""
	is_guest = true



# DEBUG
func print_data():
	print("User ID:", user_id)
	print("uuid:", uuid)
	print("Token:", token)
	print("Guest:", is_guest)
