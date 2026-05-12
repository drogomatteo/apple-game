extends Node

var user_id: int = -1
var token: String = ""
var uuid: String = ""
var birth_year: String = ""
var doctor_token: String = ""
var session_id: String = ""

var token_update_pending: bool = false
var previous_token: String = ""
var updated_token: String = ""

var access_token: String = ""
var refresh_token: String = ""
var access_token_expires_at: int = 0


func set_user(id: int, user_uuid: String, user_token: String, year: Variant, doctor: String = "") :
	user_id = id
	uuid = user_uuid
	token = user_token
	birth_year = str(year)
	doctor_token = doctor


func logout_user() :
	user_id = -1
	token = ""
	uuid = ""
	birth_year = ""
	doctor_token = ""
	session_id = ""

	token_update_pending = false
	previous_token = ""
	updated_token = ""

	access_token = ""
	refresh_token = ""
	access_token_expires_at = 0


func print_data() -> void:
	print({
		"user_id": user_id,
		"uuid": uuid,
		"token": token,
		"birth_year": birth_year,
		"doctor_token": doctor_token
	})
