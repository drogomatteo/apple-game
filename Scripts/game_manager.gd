extends Node

var BASE_URL = "https://alzheimer.magellan.fpms.ac.be/"

func send_file(filepath, url, session_id := ""):
	print("=== SEND FILE DEBUG ===")
	print("filepath =", filepath)
	print("url =", url)
	print("user_id =", PlayerData.user_id)
	print("session_id =", session_id)

	if PlayerData.user_id == -1:
		print("user_id invalide, mise en attente")
		SyncManager.add_action({
			"type": "file",
			"path": filepath,
			"url": url,
			"session_id": session_id
		})
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
		SyncManager.add_action({
			"type": "file",
			"path": filepath,
			"url": url,
			"session_id": session_id
		})
		return

	http.request_completed.connect(func(result, code, headers, body):
		print("request_completed result =", result)
		print("request_completed code =", code)
		print("request_completed body =", body.get_string_from_utf8())

		if code != 200 and code != 201:
			print("Echec envoi, mise en attente")
			SyncManager.add_action({
				"type": "file",
				"path": filepath,
				"url": url,
				"session_id": session_id
			})
	)


func send_rapport_complet(session_id := ""):
	send_file("user://rapport_complet.dat", BASE_URL + "rapport_complet/", session_id)


func send_rapport_medecin(session_id := ""):
	send_file("user://rapport_medecin.dat", BASE_URL + "rapport_medecin/")
