extends Node

var BASE_URL = "https://alzheimer.magellan.fpms.ac.be/api"

func send_file(filepath, url):

	if PlayerData.user_id == -1:
		SyncManager.add_action({
			"type": "file",
			"path": filepath,
			"url": url
		})
		return

	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
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

	var headers = [
		"Content-Type: multipart/form-data; boundary=" + boundary
	]

	var http = HTTPRequest.new()
	add_child(http)

	var err = http.request(url, headers, HTTPClient.METHOD_POST, final_body)

	if err != OK:
		SyncManager.add_action({
			"type": "file",
			"path": filepath,
			"url": url
		})
		return

	http.request_completed.connect(func(result, code, headers, body):
		if code != 200 and code != 201:
			SyncManager.add_action({
				"type": "file",
				"path": filepath,
				"url": url
			})
	)


func send_rapport_complet():
	send_file("user://rapport_complet.dat", BASE_URL + "rapport_complet/")


func send_rapport_medecin():
	send_file("user://rapport_medecin.dat", BASE_URL + "rapport_medecin/")
