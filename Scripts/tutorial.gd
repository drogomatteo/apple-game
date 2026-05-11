extends Node

enum EtapeTutoriel {
	AUCUNE,
	INTRO_1,
	INTRO_2,
	ATTENTE_ROTATION,
	ATTENTE_AVANCER,
	CONSIGNE_PANIER,
	ATTENTE_PANIER,
	CONSIGNE_ARBRE,
	ATTENTE_ARBRE,
	CONSIGNE_POMMIER,
	ATTENTE_POMMIER,
	CONSIGNE_RETOUR_PANIER_1,
	CONSIGNE_RETOUR_PANIER_2,
	CONSIGNE_RETOUR_PANIER_3,
	ATTENTE_RETOUR_PANIER,
	MESSAGE_FINAL,
	TERMINE
}

enum ModeControle {
	BLOQUE,
	ROTATION,
	AVANCER,
	TOUT
}

const TEMPS_ROTATION_DEMANDE: float = 2.0
const TEMPS_AVANCER_DEMANDE: float = 2.0

@onready var world = get_parent()
@onready var player = $"../Player"

@onready var tutorial_ui = $"../UI/TutorialUI"
@onready var boite_message = $"../UI/TutorialUI/MarginContainer/BoiteMessage"
@onready var message_label = $"../UI/TutorialUI/MarginContainer/BoiteMessage/MarginContainer/VBoxContainer/Message"
@onready var next_button = $"../UI/TutorialUI/MarginContainer/BoiteMessage/MarginContainer/VBoxContainer/Next"
@onready var highlight = $"../UI/TutorialUI/Highlight"
@onready var ToDo = $"../UI/Zone de texte/VBoxContainer/ToDo"



# Boutons de la scène Player
@onready var Left = $"../Player/CanvasLayer/MarginContainer/HBoxContainer/Control/Left"
@onready var Right = $"../Player/CanvasLayer/MarginContainer/HBoxContainer/Control3/Right"
@onready var forward_button_ui = $"../Player/CanvasLayer/MarginContainer/HBoxContainer2/Control2/Forward"

var messages := [
	"Bienvenue dans le tutoriel de l'Apple Game.\n\nAppuyez sur le bouton 'SUIVANT' afin de continuer.",
	"Parfait !\n\nCommençons sans plus tarder.",
	"Essayons un peu de regarder aux alentours.\n\nLaissez appuyer sur les boutons vert et rouge 'Pivoter'.",
	"Super !\n\nMaintenant, avançons en laissant appuyer sur le bouton jaune 'Avancer'.",
	"Vous êtes prêt !\n\nSuivez désormais les instructions notées au dessus de votre écran. \n Avancez jusque l'objet recherché",
	"Continuez comme ça.\n\nCherchons maintenant l'arbre.",
	"Très bien.\n\nAu tour du pommier.",
	"Nous arrivons à l'étape finale.\n\nConnaissez-vous le principe de l'Apple Game ?",
	"Le but du jeu est de retrouver la position initiale du panier sur la zone de jeu.\n\nVous en souvenez-vous ?",
	"Positionnez-vous là où le panier était et confirmez à l'aide du bouton 'Confirmer position'.\n\nVous avez 30 secondes !",
	"Bravo !\n\nLe tutoriel est terminé.\n\nVous allez maintenant voir votre résultat pour cette partie."
]

var tutorial_active: bool = false
var etape_actuelle: EtapeTutoriel = EtapeTutoriel.AUCUNE
var temps_action: float = 0.0
var waiting_final_popup: bool = false

var taille_bouton_suivant: Vector2 = Vector2.ONE
var animation_bouton_suivant: Tween


func _ready() -> void:
	tutorial_ui.hide()
	boite_message.hide()
	highlight.hide()

	if next_button is Control:
		taille_bouton_suivant = next_button.scale

	var appel_bouton_suivant := Callable(self, "_on_next_button_pressed")
	if not next_button.pressed.is_connected(appel_bouton_suivant):
		next_button.pressed.connect(appel_bouton_suivant)


func _process(delta: float) -> void:
	if not tutorial_active:
		return

	match etape_actuelle:
		EtapeTutoriel.ATTENTE_ROTATION:
			if player.tourner_gauche or player.tourner_droite:
				player.enlever_effets_tutoriel()
				temps_action += delta

				if temps_action >= TEMPS_ROTATION_DEMANDE:
					afficher_etape_action(EtapeTutoriel.ATTENTE_AVANCER, ModeControle.AVANCER, 3)

		EtapeTutoriel.ATTENTE_AVANCER:
			if player.avance:
				player.enlever_effets_tutoriel()
				temps_action += delta

				if temps_action >= TEMPS_AVANCER_DEMANDE:
					afficher_consigne(EtapeTutoriel.CONSIGNE_PANIER, 4)

		EtapeTutoriel.ATTENTE_PANIER:
			if world.phase >= 1:
				afficher_consigne(EtapeTutoriel.CONSIGNE_ARBRE, 5)

		EtapeTutoriel.ATTENTE_ARBRE:
			if world.phase >= 2:
				afficher_consigne(EtapeTutoriel.CONSIGNE_POMMIER, 6)

		EtapeTutoriel.ATTENTE_POMMIER:
			if world.phase >= 3:
				afficher_consigne(EtapeTutoriel.CONSIGNE_RETOUR_PANIER_1, 7)

		EtapeTutoriel.ATTENTE_RETOUR_PANIER:
			pass


func start_tutorial() -> void:
	tutorial_active = true
	etape_actuelle = EtapeTutoriel.INTRO_1
	temps_action = 0.0
	waiting_final_popup = false
	ToDo.visible = false

	regler_controles(ModeControle.BLOQUE)
	arreter_joueur()
	highlight.hide()
	player.enlever_effets_tutoriel()

	afficher_boite_tutoriel(messages[0], true)
	lancer_animation_next()


func _on_next_button_pressed() -> void:
	arreter_animation_next()

	if not tutorial_active:
		return

	match etape_actuelle:
		EtapeTutoriel.INTRO_1:
			etape_actuelle = EtapeTutoriel.INTRO_2
			regler_controles(ModeControle.BLOQUE)
			arreter_joueur()
			highlight.hide()
			player.enlever_effets_tutoriel()
			afficher_boite_tutoriel(messages[1], true)

		EtapeTutoriel.INTRO_2:
			afficher_etape_action(EtapeTutoriel.ATTENTE_ROTATION, ModeControle.ROTATION, 2)

		EtapeTutoriel.CONSIGNE_PANIER:
			lancer_recherche(EtapeTutoriel.ATTENTE_PANIER)

		EtapeTutoriel.CONSIGNE_ARBRE:
			lancer_recherche(EtapeTutoriel.ATTENTE_ARBRE)

		EtapeTutoriel.CONSIGNE_POMMIER:
			lancer_recherche(EtapeTutoriel.ATTENTE_POMMIER)

		EtapeTutoriel.CONSIGNE_RETOUR_PANIER_1:
			afficher_consigne(EtapeTutoriel.CONSIGNE_RETOUR_PANIER_2, 8)

		EtapeTutoriel.CONSIGNE_RETOUR_PANIER_2:
			afficher_consigne(EtapeTutoriel.CONSIGNE_RETOUR_PANIER_3, 9)

		EtapeTutoriel.CONSIGNE_RETOUR_PANIER_3:
			lancer_recherche(EtapeTutoriel.ATTENTE_RETOUR_PANIER)

		EtapeTutoriel.MESSAGE_FINAL:
				tutorial_active = false
				etape_actuelle = EtapeTutoriel.TERMINE
				temps_action = 0.0
				waiting_final_popup = false

				cacher_boite_tutoriel()
				highlight.hide()
				player.enlever_effets_tutoriel()
				regler_controles(ModeControle.TOUT)

				Settings.set_tutorial_seen(true)

				if world.pending_end_results:
					world.continuer_fin_apres_tuto()


func afficher_etape_action(etape: EtapeTutoriel, mode: ModeControle, indice_message: int) -> void:
	etape_actuelle = etape
	temps_action = 0.0

	regler_controles(mode)
	arreter_joueur()
	highlight.hide()
	player.enlever_effets_tutoriel()

	afficher_boite_tutoriel(messages[indice_message], false)

	if mode == ModeControle.ROTATION:
		player.mettre_en_avant_boutons_rotation(true)


	if mode == ModeControle.AVANCER:
		player.mettre_en_avant_bouton_avancer(true)



func afficher_consigne(etape: EtapeTutoriel, indice_message: int) -> void:
	etape_actuelle = etape

	regler_controles(ModeControle.BLOQUE)
	arreter_joueur()
	highlight.hide()
	player.enlever_effets_tutoriel()

	if etape == EtapeTutoriel.CONSIGNE_RETOUR_PANIER_1:
		world.max_timer.paused = true
		world.temps_restant.visible = false
		world.validate_button.visible = false

	afficher_boite_tutoriel(messages[indice_message], true)


func lancer_recherche(etape: EtapeTutoriel) -> void:
	etape_actuelle = etape

	cacher_boite_tutoriel()
	regler_controles(ModeControle.TOUT)
	highlight.hide()
	player.enlever_effets_tutoriel()

	if etape == EtapeTutoriel.ATTENTE_PANIER:
		ToDo.visible = true

	if etape == EtapeTutoriel.ATTENTE_RETOUR_PANIER:
		waiting_final_popup = true

		world.validate_button.visible = true
		world.temps_restant.visible = true
		world.max_timer.paused = false


func show_final_message_before_score() -> void:
	if not tutorial_active:
		return

	if not waiting_final_popup:
		return

	regler_controles(ModeControle.BLOQUE)
	arreter_joueur()
	highlight.hide()
	player.enlever_effets_tutoriel()

	waiting_final_popup = false
	etape_actuelle = EtapeTutoriel.MESSAGE_FINAL

	afficher_boite_tutoriel(messages[10], true)



func afficher_boite_tutoriel(texte: String, afficher_suivant: bool = true) -> void:
	tutorial_ui.show()
	boite_message.show()



	message_label.text = texte
	next_button.visible = afficher_suivant


func cacher_boite_tutoriel() -> void:
	arreter_animation_next()
	boite_message.hide()
	tutorial_ui.hide()


func regler_controles(mode: ModeControle) -> void:
	match mode:
		ModeControle.BLOQUE:
			player.controls_locked = true
			player.allow_forward = false
			player.allow_left = false
			player.allow_right = false

		ModeControle.ROTATION:
			player.controls_locked = false
			player.allow_forward = false
			player.allow_left = true
			player.allow_right = true

		ModeControle.AVANCER:
			player.controls_locked = false
			player.allow_forward = true
			player.allow_left = false
			player.allow_right = false

		ModeControle.TOUT:
			player.controls_locked = false
			player.allow_forward = true
			player.allow_left = true
			player.allow_right = true


func arreter_joueur() -> void:
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.temp_vel = 0.0
	player.temp_sens = 0.0

#Pour les animations de pop du bouton next

func lancer_animation_next() -> void:
	arreter_animation_next()

	if not next_button is Control:
		return

	next_button.scale = taille_bouton_suivant
	animation_bouton_suivant = create_tween()
	animation_bouton_suivant.set_loops()
	animation_bouton_suivant.tween_property(next_button, "scale", taille_bouton_suivant * 1.05, 0.85)
	animation_bouton_suivant.tween_property(next_button, "scale", taille_bouton_suivant, 0.85)


func arreter_animation_next() -> void:
	if animation_bouton_suivant:
		animation_bouton_suivant.kill()
		animation_bouton_suivant = null

	if next_button is Control:
		next_button.scale = taille_bouton_suivant
