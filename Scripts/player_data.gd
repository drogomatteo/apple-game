extends Node

const LOG_TAG := "[PlayerData]"
func _log(message: String) -> void:
	print("%s %s" % [LOG_TAG, message])

var user_id = -1
var token = ""
var uuid = ""
var age = ""
var is_guest = true
var session_id : String

func set_user(id, u, t,a):
	_log("set_user | id=%s" % str(id))
	user_id = id
	uuid =u
	token = t
	age =a
	is_guest = false

func set_guest(id):
	_log("set_guest | id=%s" % str(id))
	user_id = id
	uuid = ""
	token = ""
	age =""
	is_guest = true

func logout_user():
	_log("logout_user")

	PlayerData.user_id = -1
	PlayerData.token = ""
	PlayerData.uuid = ""
	PlayerData.age= ""
	PlayerData.is_guest = false


# DEBUG
func print_data():
	_log("user_id=%s token=%s uuid=%s age=%s guest=%s" % [str(user_id), str(token), str(uuid), str(age), str(is_guest)])
