extends Node

# -------- PROFILE --------
var user_id = -1
var token = ""
var uuid = ""
var birth_year = ""
var doctor_key = ""
var session_id : String
var token_update_pending := false
var previous_token = ""
var updated_token = ""

# -------- API TOKENS --------
var access_token := ""
var refresh_token := ""
var access_token_expires_at := 0

# -------- INTERNAL HELPERS --------
func _clear_profile() -> void:
	user_id = -1
	token = ""
	uuid = ""
	birth_year = ""
	doctor_key = ""
	token_update_pending = false
	previous_token = ""
	updated_token = ""

func _clear_api_tokens() -> void:
	access_token = ""
	refresh_token = ""
	access_token_expires_at = 0

# -------- PUBLIC API --------
func set_user(id, u, t, birth_year_value, m = ""):
	user_id = id
	uuid = u
	token = t
	birth_year = birth_year_value
	doctor_key = m

func logout_user():
	_clear_profile()
	_clear_api_tokens()

# -------- DEBUG --------
func print_data():
	pass
