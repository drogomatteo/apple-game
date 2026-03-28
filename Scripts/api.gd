extends Node

var base_url = "http://100.111.28.32:8000/user/"
var http: HTTPRequest

func _ready():
	print("API ready")

	http = HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(_on_request_completed)


# CREATE USER (POST)
func create_user(nom, prenom, email, annee):
	var data = {
		"nom": nom,
		"prenom": prenom,
		"email": email,
		"annee_naissance": annee
	}

	var json = JSON.stringify(data)

	return http.request(
		base_url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		json
	)


# UPDATE USER (PUT)
func update_user(id, nom, prenom, email, annee):
	var data = {
		"nom": nom,
		"prenom": prenom,
		"email": email,
		"annee_naissance": annee
	}

	var json = JSON.stringify(data)

	return http.request(
		base_url + str(id) + "/",
		["Content-Type: application/json"],
		HTTPClient.METHOD_PUT,
		json
	)



# CALLBACK
func _on_request_completed(result, response_code, headers, body):
	print("RESULT:", result)
	print("Code:", response_code)
	var response = body.get_string_from_utf8()
	print("Réponse:", response)

	# ⚠️ éviter crash si UI n'existe pas
	if has_node("../UI/ResultLabel"):
		get_node("../UI/ResultLabel").text = response
