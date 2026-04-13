extends Node

enum TutorialStep {
	NONE,
	INTRO_1,
	INTRO_2,
	WAIT_ROTATE,
	WAIT_FORWARD,
	FREE_MOVEMENT_MESSAGE,
	WAIT_BASKET,
	AFTER_BASKET,
	FINAL_MESSAGE,
	FINISHED
}

const REQUIRED_ROTATE_TIME: float = 2.0
const REQUIRED_FORWARD_TIME: float = 2.0
const HIGHLIGHT_COLOR := Color(1.0, 0.95, 0.55, 1.0)

@onready var world = get_parent()

@onready var player = $"../Player"
@onready var left_button = $"../Player/Left"
@onready var right_button = $"../Player/Right"
@onready var forward_button = $"../Player/Forward"

@onready var highlight = $"../UI/TutorialUI/Highlight"
@onready var tutorial_ui = $"../UI/TutorialUI"
@onready var boite_message = $"../UI/TutorialUI/BoiteMessage"
@onready var message_label = $"../UI/TutorialUI/BoiteMessage/Message"
@onready var next_button = $"../UI/TutorialUI/BoiteMessage/Next"

var messages := [
	"Bienvenue dans le tutoriel. \n \n Appuyez sur le boutton 'Next' afin de continuer",
	"Parfait ! \n \n L'apple Game est une façon ludique de diagnostiquer la maladier d'Alzeimer.  \n Commençons sans plus tarder le tutoriel.",
	"Essayons un peu de regarder aux alentours. \n \n Appuyez sur un des boutons 'Pivoter'",
	"Superbe paysage !. \n \n Maintenant, avançons en appuyantt sur le bouton 'Flèche'.",
	"Maintenant que vous êtes libre de vos mouvements, passons à l'étape suivante. \n \n Cliquez sur 'Next' suivez les insctuctions notées au dessus de votre écran. \n Avancez-vous jusqu'à toucher l'objet recherché",
	"Continuez comme ça, cherchons maintenant les arbres",
	"Nous arrivons à l'étape finale. \n Vous souvenez-vous de la position du pannier ? \n \n Retrouvez la position initiale du Pannier"
]

var current_message_index: int = 0
var tutorial_active: bool = false
var current_step: TutorialStep = TutorialStep.NONE
var action_timer: float = 0.0

var left_default_modulate: Color = Color.WHITE
var right_default_modulate: Color = Color.WHITE
var forward_default_modulate: Color = Color.WHITE


func _ready() -> void:
	tutorial_ui.hide()
	boite_message.hide()
	clear_highlight()
	_cache_default_button_modulates()

	var next_callable := Callable(self, "_on_next_button_pressed")
	if not next_button.pressed.is_connected(next_callable):
		next_button.pressed.connect(next_callable)


func start_tutorial() -> void:
	tutorial_active = true
	action_timer = 0.0
	_disable_all_player_actions()
	_stop_player_motion()
	_show_intro_1()


func _process(delta: float) -> void:
	if not tutorial_active:
		return

	match current_step:
		TutorialStep.WAIT_ROTATE:
			if player.tourner_gauche or player.tourner_droite:
				action_timer += delta
				if action_timer >= REQUIRED_ROTATE_TIME:
					_show_forward_step()

		TutorialStep.WAIT_FORWARD:
			if player.avance:
				action_timer += delta
				if action_timer >= REQUIRED_FORWARD_TIME:
					_show_free_movement_message()

		TutorialStep.WAIT_BASKET:
			if world.phase >= 1:
				_show_after_basket_message()


func _on_next_button_pressed() -> void:
	if not tutorial_active:
		return

	match current_step:
		TutorialStep.INTRO_1:
			_show_intro_2()

		TutorialStep.INTRO_2:
			_show_rotate_step()

		TutorialStep.FREE_MOVEMENT_MESSAGE:
			_start_basket_search()

		TutorialStep.AFTER_BASKET:
			_show_final_message()

		TutorialStep.FINAL_MESSAGE:
			finish_tutorial()


func _show_intro_1() -> void:
	current_step = TutorialStep.INTRO_1
	current_message_index = 0
	_disable_all_player_actions()
	_stop_player_motion()
	clear_highlight()
	_reset_button_emphasis()
	show_tutorial_box(messages[current_message_index], true)


func _show_intro_2() -> void:
	current_step = TutorialStep.INTRO_2
	current_message_index = 1
	_disable_all_player_actions()
	_stop_player_motion()
	clear_highlight()
	_reset_button_emphasis()
	show_tutorial_box(messages[current_message_index], true)


func _show_rotate_step() -> void:
	current_step = TutorialStep.WAIT_ROTATE
	current_message_index = 2
	action_timer = 0.0

	_allow_only_rotation()
	_stop_player_motion()
	clear_highlight()
	_highlight_rotation_buttons()

	show_tutorial_box(messages[current_message_index], false)


func _show_forward_step() -> void:
	current_step = TutorialStep.WAIT_FORWARD
	current_message_index = 3
	action_timer = 0.0

	_allow_only_forward()
	_stop_player_motion()
	clear_highlight()
	_highlight_forward_button()

	show_tutorial_box(messages[current_message_index], false)


func _show_free_movement_message() -> void:
	current_step = TutorialStep.FREE_MOVEMENT_MESSAGE
	current_message_index = 4

	_allow_all_player_actions()
	clear_highlight()
	_reset_button_emphasis()

	show_tutorial_box(messages[current_message_index], true)


func _start_basket_search() -> void:
	current_step = TutorialStep.WAIT_BASKET

	_allow_all_player_actions()
	clear_highlight()
	_reset_button_emphasis()
	hide_tutorial_box()


func _show_after_basket_message() -> void:
	current_step = TutorialStep.AFTER_BASKET
	current_message_index = 5

	_allow_all_player_actions()
	clear_highlight()
	_reset_button_emphasis()

	show_tutorial_box(messages[current_message_index], true)


func _show_final_message() -> void:
	current_step = TutorialStep.FINAL_MESSAGE
	current_message_index = 6

	_allow_all_player_actions()
	clear_highlight()
	_reset_button_emphasis()

	show_tutorial_box(messages[current_message_index], true)


func show_tutorial_box(text: String, show_next: bool = true) -> void:
	tutorial_ui.show()
	boite_message.show()
	message_label.text = text
	next_button.visible = show_next


func hide_tutorial_box() -> void:
	boite_message.hide()
	tutorial_ui.hide()


func highlight_control(target: Control, padding: int = 8) -> void:
	var rect: Rect2 = target.get_global_rect()
	highlight.show()
	highlight.global_position = rect.position - Vector2(padding, padding)
	highlight.size = rect.size + Vector2(padding * 2, padding * 2)


func clear_highlight() -> void:
	highlight.hide()


func finish_tutorial() -> void:
	tutorial_active = false
	current_step = TutorialStep.FINISHED
	action_timer = 0.0

	hide_tutorial_box()
	clear_highlight()
	_reset_button_emphasis()
	_allow_all_player_actions()

	Paramètre.definir_tutorial_seen(true)


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


func _cache_default_button_modulates() -> void:
	if left_button is CanvasItem:
		left_default_modulate = left_button.modulate
	if right_button is CanvasItem:
		right_default_modulate = right_button.modulate
	if forward_button is CanvasItem:
		forward_default_modulate = forward_button.modulate


func _highlight_rotation_buttons() -> void:
	_reset_button_emphasis()

	if left_button is CanvasItem:
		left_button.modulate = HIGHLIGHT_COLOR
	if right_button is CanvasItem:
		right_button.modulate = HIGHLIGHT_COLOR


func _highlight_forward_button() -> void:
	_reset_button_emphasis()

	if forward_button is CanvasItem:
		forward_button.modulate = HIGHLIGHT_COLOR


func _reset_button_emphasis() -> void:
	if left_button is CanvasItem:
		left_button.modulate = left_default_modulate
	if right_button is CanvasItem:
		right_button.modulate = right_default_modulate
	if forward_button is CanvasItem:
		forward_button.modulate = forward_default_modulate
