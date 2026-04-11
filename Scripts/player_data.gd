extends Node


var user_id : int = -1
var pseudo : String = ""
var token : String = ""
var is_guest : bool = true

func reset():
	user_id = -1
	pseudo = ""
	token = ""
	is_guest = true



func set_user(_user_id, _pseudo, _token):
	user_id = _user_id
	pseudo = _pseudo
	token = _token
	is_guest = false

func set_guest(_user_id):
	user_id = _user_id
	pseudo = "guest"
	token = ""
	is_guest = true


# DEBUG
func print_data():
	print("User ID:", user_id)
	print("Pseudo:", pseudo)
	print("Token:", token)
	print("Guest:", is_guest)
