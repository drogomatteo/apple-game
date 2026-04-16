extends Node

var BASE_URL = "https://alzheimer.magellan.fpms.ac.be/api/"
var file_path = "user://offline_queue.json"
const REQUEST_TIMEOUT_SECONDS := 5.0
const MAX_RETRIES := 10

var queue : Array = []
var http := HTTPRequest.new()
var is_running = false
var sync_done = false

var retry_delay = 0.5
var max_retry_delay = 5.0

# Variables de tracking pour le diagnostic
var sync_start_time = 0
var request_start_time = 0

func _ready():
	add_child(http)
	http.timeout = REQUEST_TIMEOUT_SECONDS
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
		print("[SyncManager] Queue is empty, sync_done = true")
		sync_done = true
		return
	sync_start_time = Time.get_ticks_msec()
	sync_done = false
	print("[SyncManager] force_sync() called. Queue size: ", queue.size())
	print("[SyncManager] Queue content:")
	for i in range(queue.size()):
		print("  [", i, "] type: ", queue[i].get("type", "unknown"), " retries: ", queue[i].get("retries", 0))
	process_next()

func _handle_immediate_request_error() -> void:
	is_running = false

	if queue.is_empty():
		sync_done = true
		return

	var action = queue[0]
	action["retries"] += 1
	
	# Vérifier si on a dépassé le nombre maximal de retries
	if action["retries"] > MAX_RETRIES:
		print("[SyncManager] CRITICAL: Action type=%s has exceeded max retries (%d). Abandoning it." % [action.get("type", "unknown"), MAX_RETRIES])
		
		# Nettoyer le fichier temporaire si c'est une création de seed
		if action.get("type", "") == "create_seed":
			var seed_value = str(action.get("seed_value", ""))
			var temp_file_path = "user://temp_seed_%s.dat" % seed_value
			if FileAccess.file_exists(temp_file_path):
				DirAccess.remove_absolute(temp_file_path)
				print("[SyncManager] Cleaned up temp seed file: %s" % temp_file_path)
		
		queue.pop_front()
		save_queue()
		retry_delay = 0.5  # Réinitialiser le délai
		process_next()
		return

	save_queue()
	await get_tree().create_timer(retry_delay).timeout
	retry_delay = min(retry_delay * 2.0, max_retry_delay)
	process_next()

func process_next():
	if queue.is_empty():
		var elapsed = Time.get_ticks_msec() - sync_start_time
		print("[SyncManager] Queue processed. Total sync time: %d ms" % elapsed)
		sync_done = true
		return

	if is_running:
		print("[SyncManager] Already running, waiting...")
		return

	is_running = true
	var action = queue[0]
	
	print("[SyncManager] Processing action: type=%s, retries=%d" % [action.get("type", "unknown"), action.get("retries", 0)])
	request_start_time = Time.get_ticks_msec()

	if action["type"] == "login":
		print("[SyncManager] Sending LOGIN request to: %s" % (BASE_URL + "user/"))
		var err := http.request(
			BASE_URL + "user/",
			["Content-Type: application/json"],
			HTTPClient.METHOD_POST,
			JSON.stringify(action["data"])
		)
		if err != OK:
			print("[SyncManager] ERROR: Login request failed with error code: %d" % err)
			_handle_immediate_request_error()

	elif action["type"] == "create_seed":
		print("[SyncManager] Creating SeedLevel with seed value: %s" % action.get("seed_value", ""))
		var seed_value = str(action.get("seed_value", ""))
		var temp_file_path = "user://temp_seed_%s.dat" % seed_value
		
		# Créer un fichier temporaire contenant la seed
		var temp_file = FileAccess.open(temp_file_path, FileAccess.WRITE)
		if temp_file:
			temp_file.store_string(seed_value)
			temp_file.close()
		else:
			print("[SyncManager] ERROR: Could not create temp seed file")
			_handle_immediate_request_error()
			return
		
		# Lire le fichier créé
		var seed_file = FileAccess.open(temp_file_path, FileAccess.READ)
		if seed_file == null:
			print("[SyncManager] ERROR: Could not read temp seed file")
			# Nettoyer le fichier en cas d'erreur
			if FileAccess.file_exists(temp_file_path):
				DirAccess.remove_absolute(temp_file_path)
			_handle_immediate_request_error()
			return
		
		var file_bytes = seed_file.get_buffer(seed_file.get_length())
		seed_file.close()
		
		# Construire multipart form-data
		var boundary = "----GodotBoundary"
		var body = ""
		
		body += "--" + boundary + "\r\n"
		body += 'Content-Disposition: form-data; name="nom"\r\n\r\n'
		body += seed_value + "\r\n"
		
		body += "--" + boundary + "\r\n"
		body += 'Content-Disposition: form-data; name="seed_file"; filename="seed.dat"\r\n'
		body += "Content-Type: application/octet-stream\r\n\r\n"
		
		var body_bytes = body.to_utf8_buffer()
		var end = ("\r\n--" + boundary + "--\r\n").to_utf8_buffer()
		var final_body = body_bytes + file_bytes + end
		
		var err := http.request_raw(
			BASE_URL + "seed/",
			["Content-Type: multipart/form-data; boundary=" + boundary],
			HTTPClient.METHOD_POST,
			final_body
		)
		if err != OK:
			print("[SyncManager] ERROR: Seed creation request failed with error code: %d" % err)
			_handle_immediate_request_error()

	elif action["type"] == "report":
		print("[SyncManager] Sending REPORT request to: %s" % (BASE_URL + "rapport_complet/"))
		var err := http.request(
			BASE_URL + "rapport_complet/",
			["Content-Type: application/json"],
			HTTPClient.METHOD_POST,
			JSON.stringify(action["data"])
		)
		if err != OK:
			print("[SyncManager] ERROR: Report request failed with error code: %d" % err)
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
	var elapsed = Time.get_ticks_msec() - request_start_time
	is_running = false

	if queue.is_empty():
		return

	var action = queue[0]
	var action_type = action.get("type", "unknown")
	
	print("[SyncManager] Response received for %s request. Time: %d ms, Result: %d, Code: %d" % [action_type, elapsed, result, code])

	if result != HTTPRequest.RESULT_SUCCESS or (code != 200 and code != 201):
		action["retries"] += 1
		print("[SyncManager] ERROR: Request failed. Result=%d, Code=%d, Retries=%d. Retry delay: %.1f s" % [result, code, action["retries"], retry_delay])
		print("[SyncManager] Response body: %s" % body.get_string_from_utf8())

		# Vérifier si on a dépassé le nombre maximal de retries
		if action["retries"] > MAX_RETRIES:
			print("[SyncManager] CRITICAL: Action type=%s has exceeded max retries (%d). Abandoning it." % [action_type, MAX_RETRIES])
			
			# Nettoyer le fichier temporaire si c'est une création de seed
			if action_type == "create_seed":
				var seed_value = str(action.get("seed_value", ""))
				var temp_file_path = "user://temp_seed_%s.dat" % seed_value
				if FileAccess.file_exists(temp_file_path):
					DirAccess.remove_absolute(temp_file_path)
					print("[SyncManager] Cleaned up temp seed file: %s" % temp_file_path)
			
			queue.pop_front()
			save_queue()
			is_running = false
			retry_delay = 0.5  # Réinitialiser le délai
			process_next()
			return

		await get_tree().create_timer(retry_delay).timeout
		retry_delay = min(retry_delay * 2.0, max_retry_delay)
		save_queue()
		process_next()
		return

	print("[SyncManager] Request successful!")
	retry_delay = 0.5

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

	elif action["type"] == "create_seed":
		var response = JSON.parse_string(body.get_string_from_utf8())
		print("[SyncManager] SeedLevel creation response: %s" % response)
		
		if typeof(response) == TYPE_DICTIONARY and response.has("id"):
			var seed_id = int(response["id"])
			var session_id = action.get("session_id", "")
			var seed_value = str(action.get("seed_value", ""))
			
			print("[SyncManager] SeedLevel created with ID: %d" % seed_id)
			
			# Nettoyer le fichier temporaire
			var temp_file_path = "user://temp_seed_%s.dat" % seed_value
			if FileAccess.file_exists(temp_file_path):
				DirAccess.remove_absolute(temp_file_path)
				print("[SyncManager] Cleaned up temp seed file: %s" % temp_file_path)
			
			# Ajouter l'action pour envoyer le rapport médecin avec l'ID de la seed
			queue.insert(0, {
				"type": "file",
				"path": "user://rapport_medecin.dat",
				"url": BASE_URL + "rapport_medecin/",
				"session_id": session_id,
				"extra_fields": {"seed": seed_id},
				"retries": 0
			})
			save_queue()
			print("[SyncManager] Queued rapport_medecin to be sent with seed ID: %d" % seed_id)
		else:
			print("[SyncManager] ERROR: Invalid response format for create_seed")

	process_next()
