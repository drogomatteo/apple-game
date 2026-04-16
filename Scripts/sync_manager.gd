extends Node

var BASE_URL = "https://alzheimer.magellan.fpms.ac.be/api/"
var file_path = "user://offline_queue.json"
const REQUEST_TIMEOUT_SECONDS := 5.0

var queue : Array = []
var http := HTTPRequest.new()
var is_running = false
var sync_done = false

var retry_delay = 0.5
var max_retry_delay = 5.0
const QUEUE_FILES_DIR := "user://queued_reports"

func _ready():
	add_child(http)
	http.timeout = REQUEST_TIMEOUT_SECONDS
	http.request_completed.connect(_on_request_completed)
	load_queue()
	_prioritize_login_actions()
	_drop_legacy_live_file_actions()

	if not queue.is_empty() and PlayerData.user_id != -1 and PlayerData.is_server_synced:
		print("[SYNC] Queue detected on startup:", queue.size())
		call_deferred("restart_sync")

func add_action(action : Dictionary):
	if not action.has("retries"):
		action["retries"] = 0

	if action.get("type", "") == "login":
		queue.push_front(action)
		_prioritize_login_actions()
	else:
		queue.append(action)

	save_queue()
	print("[SYNC] Action queued:", action.get("type", "unknown"), "queue size =", queue.size())


func _prioritize_login_actions() -> void:
	if queue.is_empty():
		return

	var login_actions : Array = []
	var other_actions : Array = []

	for action in queue:
		if action.get("type", "") == "login":
			login_actions.append(action)
		else:
			other_actions.append(action)

	queue = login_actions + other_actions


func _normalize_session_id(session_id: String) -> String:
	if session_id == "":
		return session_id

	var parts := session_id.split("_", false)

	if parts.size() == 3:
		return parts[0] + "_" + str(PlayerData.user_id) + "_" + parts[2]

	return session_id


func _normalize_pending_actions_for_current_user() -> void:
	var changed := false

	for action in queue:
		if action.get("type", "") == "file" and action.has("session_id"):
			var current_session_id := str(action.get("session_id", ""))
			var normalized_session_id := _normalize_session_id(current_session_id)

			if normalized_session_id != current_session_id:
				action["session_id"] = normalized_session_id
				changed = true

	if changed:
		save_queue()
		print("[SYNC] Normalized pending file actions for user", PlayerData.user_id)


func _drop_legacy_live_file_actions() -> void:
	var filtered_queue : Array = []
	var removed_count := 0

	for action in queue:
		var action_type := str(action.get("type", ""))
		var action_path := str(action.get("path", ""))

		if action_type == "file" and (
			action_path == "user://rapport_complet.dat" or action_path == "user://rapport_medecin.dat"
		):
			removed_count += 1
			continue

		filtered_queue.append(action)

	if removed_count > 0:
		queue = filtered_queue
		save_queue()
		print("[SYNC] Dropped legacy live file actions:", removed_count)


func _ensure_queue_files_dir() -> void:
	DirAccess.make_dir_recursive_absolute(QUEUE_FILES_DIR)


func _snapshot_file_for_queue(filepath: String, session_id: String, suffix: String) -> String:
	var source := FileAccess.open(filepath, FileAccess.READ)
	if source == null:
		return ""

	var file_bytes := source.get_buffer(source.get_length())
	source.close()

	_ensure_queue_files_dir()

	var safe_session_id := session_id.replace("/", "_").replace("\\", "_").replace(":", "_")
	if safe_session_id == "":
		safe_session_id = str(Time.get_unix_time_from_system()) + "_" + str(randi())

	var snapshot_path := QUEUE_FILES_DIR + "/" + safe_session_id + "_" + suffix + ".dat"
	var snapshot := FileAccess.open(snapshot_path, FileAccess.WRITE)
	if snapshot == null:
		return ""

	snapshot.store_buffer(file_bytes)
	snapshot.close()
	return snapshot_path


func enqueue_file_action(filepath: String, url: String, session_id: String = "", extra_fields := {}) -> void:
	var suffix := "rapport"

	if filepath.ends_with("rapport_complet.dat"):
		suffix = "rapport_complet"
	elif filepath.ends_with("rapport_medecin.dat"):
		suffix = "rapport_medecin"

	var queued_path := _snapshot_file_for_queue(filepath, session_id, suffix)
	if queued_path == "":
		print("[SYNC] Failed to snapshot file for queue:", filepath)
		return

	add_action({
		"type": "file",
		"path": queued_path,
		"url": url,
		"session_id": session_id,
		"extra_fields": extra_fields
	})


func _delete_queued_snapshot_if_needed(path: String) -> void:
	if path.begins_with(QUEUE_FILES_DIR + "/") and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func remove_actions_by_type(action_type: String) -> void:
	var filtered_queue : Array = []
	var removed_count := 0

	for action in queue:
		if action.get("type", "") != action_type:
			filtered_queue.append(action)
		else:
			removed_count += 1

	queue = filtered_queue
	save_queue()
	print("[SYNC] Removed actions of type", action_type, "count =", removed_count, "queue size =", queue.size())


func has_action_type(action_type: String) -> bool:
	for action in queue:
		if action.get("type", "") == action_type:
			return true

	return false

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
	if not PlayerData.is_server_synced and not has_action_type("login"):
		sync_done = true
		print("[SYNC] force_sync deferred, waiting for a real server login")
		return

	if queue.is_empty():
		sync_done = true
		print("[SYNC] force_sync called with empty queue")
		return
	sync_done = false
	print("[SYNC] force_sync starting, queue size =", queue.size())
	process_next()


func restart_sync() -> void:
	print("[SYNC] restart_sync requested, queue size =", queue.size(), "is_running =", is_running)

	if not PlayerData.is_server_synced and not has_action_type("login"):
		sync_done = true
		print("[SYNC] restart_sync deferred, waiting for a real server login")
		return

	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http.cancel_request()
		print("[SYNC] Previous HTTP request cancelled")

	is_running = false
	sync_done = false

	if queue.is_empty():
		sync_done = true
		print("[SYNC] restart_sync aborted, queue empty")
		return

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
		print("[SYNC] Queue fully processed")
		return

	if is_running:
		print("[SYNC] process_next skipped, already running")
		return

	is_running = true
	var action = queue[0]
	print("[SYNC] Processing action:", action.get("type", "unknown"), "retries =", action.get("retries", 0), "queue size =", queue.size())

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

		if url.ends_with("/rapport_medecin/") and PlayerData.is_server_synced and not PlayerData.has_medecins():
			print("[SYNC] Skipping rapport_medecin sync: no linked medecin for this account")
			_delete_queued_snapshot_if_needed(str(filepath))
			queue.pop_front()
			save_queue()
			is_running = false
			process_next()
			return

		var file = FileAccess.open(filepath, FileAccess.READ)
		if file == null:
			_delete_queued_snapshot_if_needed(filepath)
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
		print("[SYNC] Request completed but queue is empty")
		return

	var action = queue[0]
	print("[SYNC] Request completed for action:", action.get("type", "unknown"), "result =", result, "code =", code)

	if result != HTTPRequest.RESULT_SUCCESS or (code != 200 and code != 201):
		action["retries"] += 1
		print("[SYNC] Action failed, retry =", action["retries"])

		await get_tree().create_timer(retry_delay).timeout
		retry_delay = min(retry_delay * 2.0, max_retry_delay)
		save_queue()
		process_next()
		return

	retry_delay = 0.5

	queue.pop_front()
	save_queue()
	print("[SYNC] Action succeeded, remaining queue size =", queue.size())

	if action["type"] == "file":
		_delete_queued_snapshot_if_needed(str(action.get("path", "")))

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

			_normalize_pending_actions_for_current_user()
			save_queue()
			GestionFichier.save_data()

	process_next()
