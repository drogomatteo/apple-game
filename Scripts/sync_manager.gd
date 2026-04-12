extends Node

var BASE_URL = "http://100.111.28.32:8000/api/"
var file_path = "user://offline_queue.json"

var queue : Array = []
var http := HTTPRequest.new()
var is_running = false
var sync_done = false

var retry_delay = 2.0
var max_retry_delay = 60.0
var max_retries = 5

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

func process_next():
	if queue.is_empty():
		sync_done = true
		return

	if is_running:
		return

	is_running = true
	var action = queue[0]

	if action["type"] == "login":
		http.request(
			BASE_URL + "user/",
			["Content-Type: application/json"],
			HTTPClient.METHOD_POST,
			JSON.stringify(action["data"])
		)

	elif action["type"] == "report":
		http.request(
			BASE_URL + "rapport_complet/",
			["Content-Type: application/json"],
			HTTPClient.METHOD_POST,
			JSON.stringify(action["data"])
		)

	elif action["type"] == "file":

		var filepath = action["path"]
		var url = action["url"]

		var file = FileAccess.open(filepath, FileAccess.READ)
		if file == null:
			queue.pop_front()
			save_queue()
			is_running = false
			process_next()
			return

		var file_bytes = file.get_buffer(file.get_length())

		var boundary = "----GodotBoundary"
		var body = ""

		body += "--" + boundary + "\r\n"
		body += 'Content-Disposition: form-data; name="user"\r\n\r\n'
		body += str(PlayerData.user_id) + "\r\n"

		body += "--" + boundary + "\r\n"
		body += 'Content-Disposition: form-data; name="fichier"; filename="rapport.dat"\r\n'
		body += "Content-Type: application/octet-stream\r\n\r\n"

		var body_bytes = body.to_utf8_buffer()
		var end = ("\r\n--" + boundary + "--\r\n").to_utf8_buffer()

		var final_body = body_bytes + file_bytes + end

		http.request(
			url,
			["Content-Type: multipart/form-data; boundary=" + boundary],
			HTTPClient.METHOD_POST,
			final_body
		)

func _on_request_completed(result, code, headers, body):
	is_running = false

	if queue.is_empty():
		return

	var action = queue[0]

	if code != 200 and code != 201:
		action["retries"] += 1

		if action["retries"] >= max_retries:
			queue.pop_front()
			save_queue()
			retry_delay = 2.0
			process_next()
			return

		await get_tree().create_timer(retry_delay).timeout
		retry_delay = min(retry_delay * 2.0, max_retry_delay)
		process_next()
		return

	retry_delay = 2.0

	queue.pop_front()
	save_queue()

	if action["type"] == "login":
		var response = JSON.parse_string(body.get_string_from_utf8())

		if typeof(response) == TYPE_DICTIONARY and response.has("id"):
			PlayerData.user_id = response["id"]

			for a in queue:
				if a["type"] == "report":
					a["data"]["user_id"] = PlayerData.user_id

	process_next()
