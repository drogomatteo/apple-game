extends Node

var user_id = -1
var pseudo = ""
var token = ""
var is_guest = true

func set_user(id, p, t):
	user_id = id
	pseudo = p
	token = t
	is_guest = false

func set_guest(id):
	user_id = id
	pseudo = "guest"
	token = ""
	is_guest = true



# DEBUG
func print_data():
	print("User ID:", user_id)
	print("Pseudo:", pseudo)
	print("Token:", token)
	print("Guest:", is_guest)
