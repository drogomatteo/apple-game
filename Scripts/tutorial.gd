extends Node

enum TutorialStep {
	NONE,
	INTRO_1,
	INTRO_2,
	WAIT_ROTATE,
	WAIT_FORWARD,
	BASKET_INSTRUCTION,
	WAIT_BASKET,
	TREE_INSTRUCTION,
	WAIT_TREE,
	APPLE_INSTRUCTION,
	WAIT_APPLE,
	RETURN_BASKET_INSTRUCTION_1,
	RETURN_BASKET_INSTRUCTION_2,
	RETURN_BASKET_INSTRUCTION_3,
	WAIT_RETURN_BASKET,
	FINAL_TUTORIAL_MESSAGE,
	FINISHED
}

var next_default_scale: Vector2 = Vector2.ONE
var next_tween: Tween

const REQUIRED_ROTATE_TIME: float = 2.0
const REQUIRED_FORWARD_TIME: float = 2.0
const HIGHLIGHT_COLOR := Color(1.0, 0.95, 0.55, 1.0)

@onready var world = get_parent()
@onready var player = $"../Player"

@onready var tutorial_ui = $"../UI/TutorialUI"
@onready var boite_message = $"../UI/TutorialUI/MarginContainer/BoiteMessage"
@onready var message_label = $"../UI/TutorialUI/MarginContainer/BoiteMessage/MarginContainer/VBoxContainer/Message"
@onready var next_button = $"../UI/TutorialUI/MarginContainer/BoiteMessage/MarginContainer/VBoxContainer/Next"
@onready var highlight = $"../UI/TutorialUI/Highlight"
@onready var ToDo = $"../UI/Zone de texte/VBoxContainer/ToDo"

@onready var icon_left = $"../UI/TutorialUI/MarginContainer/BoiteMessage/MarginContainer/Pivoter/Icon left"
@onready var icon_right = $"../UI/TutorialUI/MarginContainer/BoiteMessage/MarginContainer/Pivoter/IconRight"
@onready var icon_forward = $"../UI/TutorialUI/MarginContainer/BoiteMessage/MarginContainer/Pivoter/IconForward"

# Boutons de la scène Player
@onready var Left = $"../Player/CanvasLayer/MarginContainer/HBoxContainer/Control/Left"
@onready var Right = $"../Player/CanvasLayer/MarginContainer/HBoxContainer/Control3/Right"
@onready var forward_button_ui = $"../Player/CanvasLayer/MarginContainer/HBoxContainer2/Control2/Forward"

var messages := [
	"Bienvenue dans le tutoriel de l'Apple Game.\n\nAppuyez sur le bouton 'SUIVANT' afin de continuer.",
	"Parfait !\n\nCommençons sans plus tarder.",
	"Essayons un peu de regarder aux alentours.\n\nLaissez appuyer sur les boutons 'Pivoter'.",
	"Super !\n\nMaintenant, avançons en appuyant sur le bouton 'Avancer'.",
	"Vous êtes prêt !\n\nSuivez désormais les instructions notées au dessus de votre écran. \n Avancez jusque l'objet recherché",
	"Continuez comme ça.\n\nCherchons maintenant l'arbre.",
	"Très bien.\n\nAu tour du pommier.",
	"Nous arrivons à l'étape finale.\n\nConnaissez-vous le principe de l'Apple Game ?",
	"Le but du jeu est de retrouver la position initiale du panier sur la zone de jeu.\n\nVous en souvenez-vous ?",
	"Positionnez-vous là où le panier était et confirmez à l'aide du bouton 'Confirmer position'.\n\nVous avez 30 secondes !",
	"Bravo !\n\nLe tutoriel est terminé.\n\nVous allez maintenant voir votre résultat pour cette partie."
]

var tutorial_active: bool = false
var current_step: TutorialStep = TutorialStep.NONE
var action_timer: float = 0.0
var waiting_final_popup: bool = false


func _ready() -> void:
	tutorial_ui.hide()
	boite_message.hide()
	clear_highlight()
	if next_button is Control:
		next_default_scale = next_button.scale

	var next_callable := Callable(self, "_on_next_button_pressed")
	if not next_button.pressed.is_connected(next_callable):
		next_button.pressed.connect(next_callable)


func start_tutorial() -> void:
	tutorial_active = true
	current_step = TutorialStep.NONE
	action_timer = 0.0
	waiting_final_popup = false
	ToDo.visible = false

	_disable_all_player_actions()
	_stop_player_motion()
	_show_intro_1()


func _process(delta: float) -> void:
	if not tutorial_active:
		return

	match current_step:
		TutorialStep.WAIT_ROTATE:
			if player.tourner_gauche or player.tourner_droite:
				_reset_button_emphasis()
				action_timer += delta
				if action_timer >= REQUIRED_ROTATE_TIME:
					_show_forward_step()

		TutorialStep.WAIT_FORWARD:
			if player.avance:
				_reset_button_emphasis()
				action_timer += delta
				if action_timer >= REQUIRED_FORWARD_TIME:
					_show_basket_instruction()

		TutorialStep.WAIT_BASKET:
			if world.phase >= 1:
				_show_tree_instruction()

		TutorialStep.WAIT_TREE:
			if world.phase >= 2:
				_show_apple_instruction()

		TutorialStep.WAIT_APPLE:
			if world.phase >= 3:
				_show_return_basket_instruction()

		TutorialStep.WAIT_RETURN_BASKET:
			pass


func _on_next_button_pressed() -> void:
	_stop_next_pulse()
	if not tutorial_active:
		return

	match current_step:
		TutorialStep.INTRO_1:
			_show_intro_2()

		TutorialStep.INTRO_2:
			_show_rotate_step()

		TutorialStep.BASKET_INSTRUCTION:
			_start_basket_search()

		TutorialStep.TREE_INSTRUCTION:
			_start_tree_search()

		TutorialStep.APPLE_INSTRUCTION:
			_start_apple_search()

		TutorialStep.RETURN_BASKET_INSTRUCTION_1:
			current_step = TutorialStep.RETURN_BASKET_INSTRUCTION_2
			show_tutorial_box(messages[8], true)

		TutorialStep.RETURN_BASKET_INSTRUCTION_2:
			current_step = TutorialStep.RETURN_BASKET_INSTRUCTION_3
			show_tutorial_box(messages[9], true)

		TutorialStep.RETURN_BASKET_INSTRUCTION_3:
			_start_return_basket_search()

		TutorialStep.FINAL_TUTORIAL_MESSAGE:
			finish_tutorial()


func _show_intro_1() -> void:
	current_step = TutorialStep.INTRO_1
	_disable_all_player_actions()
	_stop_player_motion()
	clear_highlight()
	_reset_button_emphasis()
	show_tutorial_box(messages[0], true)
	_start_next_pulse()


func _show_intro_2() -> void:
	current_step = TutorialStep.INTRO_2
	_disable_all_player_actions()
	_stop_player_motion()
	clear_highlight()
	_reset_button_emphasis()
	show_tutorial_box(messages[1], true)


func _show_rotate_step() -> void:
	current_step = TutorialStep.WAIT_ROTATE
	action_timer = 0.0
	_allow_only_rotation()
	_stop_player_motion()
	clear_highlight()
	_highlight_rotation_buttons()
	show_tutorial_box(messages[2], false)
	icon_left.visible = true
	icon_right.visible = true


func _show_forward_step() -> void:
	current_step = TutorialStep.WAIT_FORWARD
	action_timer = 0.0
	_allow_only_forward()
	_stop_player_motion()
	clear_highlight()
	_highlight_forward_button()
	show_tutorial_box(messages[3], false)
	icon_forward.visible = true


func _show_basket_instruction() -> void:
	current_step = TutorialStep.BASKET_INSTRUCTION
	_disable_all_player_actions()
	_stop_player_motion()
	clear_highlight()
	_reset_button_emphasis()
	show_tutorial_box(messages[4], true)


func _start_basket_search() -> void:
	current_step = TutorialStep.WAIT_BASKET
	ToDo.visible = true
	hide_tutorial_box()
	_allow_all_player_actions()
	clear_highlight()
	_reset_button_emphasis()


func _show_tree_instruction() -> void:
	current_step = TutorialStep.TREE_INSTRUCTION
	_disable_all_player_actions()
	_stop_player_motion()
	clear_highlight()
	_reset_button_emphasis()
	show_tutorial_box(messages[5], true)


func _start_tree_search() -> void:
	current_step = TutorialStep.WAIT_TREE
	hide_tutorial_box()
	_allow_all_player_actions()
	clear_highlight()
	_reset_button_emphasis()


func _show_apple_instruction() -> void:
	current_step = TutorialStep.APPLE_INSTRUCTION
	_disable_all_player_actions()
	_stop_player_motion()
	clear_highlight()
	_reset_button_emphasis()
	show_tutorial_box(messages[6], true)


func _start_apple_search() -> void:
	current_step = TutorialStep.WAIT_APPLE
	hide_tutorial_box()
	_allow_all_player_actions()
	clear_highlight()
	_reset_button_emphasis()


func _show_return_basket_instruction() -> void:
	current_step = TutorialStep.RETURN_BASKET_INSTRUCTION_1
	_disable_all_player_actions()
	_stop_player_motion()
	clear_highlight()
	_reset_button_emphasis()

	# Pause du chrono tant que le joueur lit l'explication
	world.max_timer.paused = true
	world.temps_restant.visible = false
	world.validate_button.visible = false

	show_tutorial_box(messages[7], true)


func _start_return_basket_search() -> void:
	current_step = TutorialStep.WAIT_RETURN_BASKET
	waiting_final_popup = true
	hide_tutorial_box()
	_allow_all_player_actions()
	clear_highlight()
	_reset_button_emphasis()

	# Reprise du chrono seulement quand le joueur a fini de lire
	world.validate_button.visible = true
	world.temps_restant.visible = true
	world.max_timer.paused = false


func show_final_message_before_score() -> void:
	if not tutorial_active:
		return
	if not waiting_final_popup:
		return

	_disable_all_player_actions()
	_stop_player_motion()
	waiting_final_popup = false
	current_step = TutorialStep.FINAL_TUTORIAL_MESSAGE
	show_tutorial_box(messages[10], true)


func show_tutorial_box(text: String, show_next: bool = true) -> void:
	tutorial_ui.show()
	icon_left.visible = false
	icon_right.visible = false
	icon_forward.visible = false
	boite_message.show()
	message_label.text = text
	next_button.visible = show_next


func hide_tutorial_box() -> void:
	_stop_next_pulse()
	boite_message.hide()
	tutorial_ui.hide()


func clear_highlight() -> void:
	highlight.hide()


func finish_tutorial() -> void:
	tutorial_active = false
	current_step = TutorialStep.FINISHED
	action_timer = 0.0
	waiting_final_popup = false

	hide_tutorial_box()
	clear_highlight()
	_reset_button_emphasis()
	_allow_all_player_actions()

	Settings.set_tutorial_seen(true)
	if world.pending_end_results:
		world.continuer_fin_apres_tuto()


func _disable_all_player_actions() -> void:
	player.controls_locked = true
	player.allow_forward = false
	player.allow_left = false
	player.allow_right = false


func _allow_only_rotation() -> void:
	player.controls_locked = false
	player.allow_forward = false
	player.allow_left = true
	player.allow_right = true


func _allow_only_forward() -> void:
	player.controls_locked = false
	player.allow_forward = true
	player.allow_left = false
	player.allow_right = false


func _allow_all_player_actions() -> void:
	player.controls_locked = false
	player.allow_forward = true
	player.allow_left = true
	player.allow_right = true


func _stop_player_motion() -> void:
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.temp_vel = 0.0
	player.temp_sens = 0.0


func _highlight_rotation_buttons() -> void:
	player.clear_tutorial_highlights()
	player.highlight_rotation_buttons(true)


func _highlight_forward_button() -> void:
	player.clear_tutorial_highlights()
	player.highlight_forward_button(true)


func _reset_button_emphasis() -> void:
	player.clear_tutorial_highlights()


func _start_next_pulse() -> void:
	_stop_next_pulse()

	if not next_button is Control:
		return

	next_button.scale = next_default_scale

	next_tween = create_tween()
	next_tween.set_loops()
	next_tween.tween_property(next_button, "scale", next_default_scale * 1.05, 0.85)
	next_tween.tween_property(next_button, "scale", next_default_scale, 0.85)


func _stop_next_pulse() -> void:
	if next_tween:
		next_tween.kill()
		next_tween = null

	if next_button is Control:
		next_button.scale = next_default_scale
