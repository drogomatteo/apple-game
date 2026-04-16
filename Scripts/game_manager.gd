extends Node

var BASE_URL = "https://alzheimer.magellan.fpms.ac.be/api/"

func _is_http_success(result: int, code: int) -> bool:
	return result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300

func send_file(filepath, url, session_id := "", extra_fields := {}):
	print("=== SEND FILE DEBUG ===")
	print("filepath =", filepath)
	print("url =", url)
	print("user_id =", PlayerData.user_id)
	print("session_id =", session_id)
	print("extra_fields =", extra_fields)

	if PlayerData.user_id == -1 or not PlayerData.is_server_synced or SyncManager.has_action_type("login"):
		print("user_id non synchronise, mise en attente")
		SyncManager.enqueue_file_action(filepath, url, session_id, extra_fields)
		SyncManager.force_sync()
		return

	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		print("Impossible d'ouvrir le fichier :", filepath)
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

	var headers = [
		"Content-Type: multipart/form-data; boundary=" + boundary
	]

	var http = HTTPRequest.new()
	add_child(http)

	var err = http.request_raw(url, headers, HTTPClient.METHOD_POST, final_body)

	print("request err =", err)

	if err != OK:
		print("Erreur immédiate HTTPRequest :", err)
		SyncManager.enqueue_file_action(filepath, url, session_id, extra_fields)
		return

	http.request_completed.connect(func(result, code, headers, body):
		print("request_completed result =", result)
		print("request_completed code =", code)
		print("request_completed body =", body.get_string_from_utf8())

		if not _is_http_success(result, code):
			print("Echec envoi, mise en attente")
			SyncManager.enqueue_file_action(filepath, url, session_id, extra_fields)

		http.queue_free()
	)


func send_rapport_complet(session_id := ""):
	send_file("user://rapport_complet.dat", BASE_URL + "rapport_complet/", session_id)


func send_rapport_medecin(session_id := "", seed_value := ""):
	send_file("user://rapport_medecin.dat", BASE_URL + "rapport_medecin/", session_id, {"seed": seed_value})
