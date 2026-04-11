extends Control

@onready var api = get_node("../API")
var cheminMenu = "MainMenu"

@onready var nom_input = $NomInput
@onready var prenom_input = $PrenomInput
@onready var email_input = $EmailInput
@onready var annee_input = $AnneeInput
@onready var id_input = $IdInput
@onready var result_label = $ResultLabel


func _ready():
	verifier_champs()
	$CreateButton.pressed.connect(_on_create_pressed)
	$UpdateButton.pressed.connect(_on_update_pressed)
	$RetourMenuPrincipal.pressed.connect(_on_retour_menu_principal_pressed)
	
	
# CREATE
func verifier_champs():
	var nom_ok = nom_input.text.strip_edges() != ""
	var prenom_ok = prenom_input.text.strip_edges() != ""
	var email_ok = email_input.text.strip_edges() != ""
	var annee_ok = annee_input.text.strip_edges() != ""
	$CreateButton.disabled = not (nom_ok and prenom_ok and email_ok and annee_ok)

func _on_nom_input_text_changed(new_text):
	verifier_champs()

func _on_prenom_input_text_changed(new_text):
	verifier_champs()

func _on_email_input_text_changed(new_text):
	verifier_champs()

func _on_annee_input_text_changed(new_text):
	verifier_champs()

func _on_create_pressed():
	var nom = nom_input.text
	var prenom = prenom_input.text
	var email = email_input.text
	var annee_txt = annee_input.text.strip_edges()
	var annee_ok = annee_txt != "" and annee_txt.is_valid_int()

	api.create_user(nom, prenom, email, annee_ok)
	result_label.text = "Création envoyée..."
	
func _on_retour_menu_principal_pressed():
	PlayerData.nom = $NomInput.text
	PlayerData.prenom = $PrenomInput.text
	PlayerData.email = $EmailInput.text
	PlayerData.annee = $AnneeInput.text
	PlayerData.id = int($IdInput.text)
	Transition.go_to_scene(cheminMenu)

# UPDATE
func _on_update_pressed():
	var id = int(id_input.text)
	var nom = nom_input.text
	var prenom = prenom_input.text
	var email = email_input.text
	var annee = int(annee_input.text)

	api.update_user(id, nom, prenom, email, annee)
	result_label.text = "Modification envoyée..."
