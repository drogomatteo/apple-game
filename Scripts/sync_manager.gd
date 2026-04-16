extends Node

var BASE_URL = "https://alzheimer.magellan.fpms.ac.be/api/"
var file_path = "user://offline_queue.json"

var queue : Array = []
var http := HTTPRequest.new()
var is_running = false
var sync_done = false

var retry_delay = 0.5
var max_retry_delay = 5.0

func _ready():
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	load_queue()

func add_action(action : Dictionary):
	if not action.has("retries"):
		action["retries"] = 0
	queue.append(action)
	save_queue()

func save_queue():
	var f = FileAccess.open(file_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(queue))
	f.close()

func load_queue():
	if not FileAccess.file_exists(file_path):
		queue = []
		return
	var f = FileAccess.open(file_path, FileAccess.READ)
	queue = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(queue) != TYPE_ARRAY:
		queue = []

func force_sync():
	if queue.is_empty():
		sync_done = true
		return
	sync_done = false
	process_next()

func _handle_immediate_request_error() -> void:
	is_running = false

	if queue.is_empty():
		sync_done = true
		return

	var action = queue[0]
	action["retries"] += 1

	save_queue()
	await get_tree().create_timer(retry_delay).timeout
	retry_delay = min(retry_delay * 2.0, max_retry_delay)
	process_next()

func process_next():
	if queue.is_empty():
		sync_done = true
		return

	if is_running:
		return

	is_running = true
	var action = queue[0]

	if action["type"] == "login":
		var err := http.request(
			BASE_URL + "user/",
			["Content-Type: application/json"],
			HTTPClient.METHOD_POST,
			JSON.stringify(action["data"])
		)
		if err != OK:
			_handle_immediate_request_error()

	elif action["type"] == "report":
		var err := http.request(
			BASE_URL + "rapport_complet/",
			["Content-Type: application/json"],
			HTTPClient.METHOD_POST,
			JSON.stringify(action["data"])
		)
		if err != OK:
			_handle_immediate_request_error()

	elif action["type"] == "file":

		var filepath = action["path"]
		var url = action["url"]
		var session_id = action.get("session_id", "")
		var extra_fields = action.get("extra_fields", {})

		var file = FileAccess.open(filepath, FileAccess.READ)
		if file == null:
			queue.pop_front()
			save_queue()
			is_running = false
			process_next()
			return

		var file_bytes = file.get_buffer(file.get_length())
		file.close()

		var boundary = "----GodotBoundary"
		var body = ""

		body += "--" + boundary + "\r\n"
		body += 'Content-Disposition: form-data; name="user"\r\n\r\n'
		body += str(PlayerData.user_id) + "\r\n"

		if session_id != "":
			body += "--" + boundary + "\r\n"
			body += 'Content-Disposition: form-data; name="session_id"\r\n\r\n'
			body += session_id + "\r\n"

		for field_name in extra_fields.keys():
			body += "--" + boundary + "\r\n"
			body += 'Content-Disposition: form-data; name="' + str(field_name) + '"\r\n\r\n'
			body += str(extra_fields[field_name]) + "\r\n"

		body += "--" + boundary + "\r\n"
		body += 'Content-Disposition: form-data; name="fichier"; filename="rapport.dat"\r\n'
		body += "Content-Type: application/octet-stream\r\n\r\n"

		var body_bytes = body.to_utf8_buffer()
		var end = ("\r\n--" + boundary + "--\r\n").to_utf8_buffer()

		var final_body = body_bytes + file_bytes + end

		var err := http.request_raw(
			url,
			["Content-Type: multipart/form-data; boundary=" + boundary],
			HTTPClient.METHOD_POST,
			final_body
		)
		if err != OK:
			_handle_immediate_request_error()

func _on_request_completed(result, code, headers, body):
	is_running = false

	if queue.is_empty():
		return

	var action = queue[0]

	if code != 200 and code != 201:
		action["retries"] += 1

		await get_tree().create_timer(retry_delay).timeout
		retry_delay = min(retry_delay * 2.0, max_retry_delay)
		save_queue()
		process_next()
		return

	retry_delay = 2.0

	queue.pop_front()
	save_queue()

	if action["type"] == "login":
		var response = JSON.parse_string(body.get_string_from_utf8())

		if typeof(response) == TYPE_DICTIONARY and response.has("id"):
			var synced_user_id = int(response["id"])
			var login_data = action.get("data", {})
			var synced_token = str(login_data.get("token", PlayerData.token))
			var synced_uuid = str(response.get("uuid", login_data.get("uuid", PlayerData.uuid)))

			if synced_token.to_lower() == "guest":
				PlayerData.set_guest(synced_user_id)
				PlayerData.token = "guest"
				PlayerData.uuid = "none"
			else:
				PlayerData.set_user(synced_user_id, synced_uuid, synced_token)

			for a in queue:
				if a["type"] == "report":
					a["data"]["user_id"] = PlayerData.user_id

			save_queue()
			GestionFichier.save_data()

	process_next()
