extends Control

var scaling = 20

var Position_joueur = [Vector2(0,0), Vector2(1,0), Vector2(2,0), Vector2(3,1), Vector2(8,8)]
var Position_panier = Vector2(3,1)
var Position_pommier = Vector2(8,8)
var Position_repere = Vector2(5,3)
var Position_arbre = [Vector2(1,0), Vector2(2,0)]
var rectangle = [Vector2(-1, -1), Vector2(17, -1), Vector2(17, 17), Vector2(-1, 17), Vector2(-1, -1)]

# --- NOUVELLES VARIABLES D'ANIMATION ---
var vitesse_animation: float = 3.0 # Vitesse de déplacement du joueur
var current_path_index: int = 0    # Indice du segment actuel
var progress_segment: float = 0.0  # Pourcentage d'avancement sur le segment actuel (0.0 à 1.0)
var position_actuelle: Vector2     # La position calculée du joueur en temps réel

# --- VARIABLES DE LOGIQUE D'OBJECTIFS ---
var sequence_objectifs: Array[Vector2] = []
var index_objectif_courant: int = 0
var seuil_distance: float = 0.5    # La distance à partir de laquelle le point "bascule"
var animation_terminee: bool = false

func _ready() -> void:
	# Initialisation de la position de départ
	position_actuelle = Position_joueur[0]
	
	# On définit l'ordre d'allumage souhaité : 1. Panier, 2. Arbres, 3. Pommier
	sequence_objectifs.append(Position_panier)
	sequence_objectifs.append(Position_arbre[0]) 
	sequence_objectifs.append(Position_arbre[1]) 
	sequence_objectifs.append(Position_pommier)

func _process(delta: float) -> void:
	# On force le redessin de l'interface à chaque frame
	queue_redraw()
	
	if animation_terminee:
		return # L'animation est finie, on arrête de calculer

	# 1. Calcul du déplacement du joueur
	if current_path_index < len(Position_joueur) - 1:
		var debut_segment = Position_joueur[current_path_index]
		var fin_segment = Position_joueur[current_path_index + 1]
		var distance_segment = debut_segment.distance_to(fin_segment)
		
		# On avance le pourcentage proportionnellement à la distance pour avoir une vitesse constante
		progress_segment += (vitesse_animation * delta) / distance_segment
		
		if progress_segment >= 1.0:
			progress_segment = 0.0
			current_path_index += 1
			
			# Fin du parcours
			if current_path_index >= len(Position_joueur) - 1:
				animation_terminee = true
				position_actuelle = Position_joueur[-1]
				# A la fin, le panier se rallume (il est à l'index 0 de notre séquence)
				index_objectif_courant = 0
			else:
				position_actuelle = Position_joueur[current_path_index]
		else:
			# lerp permet d'interpoler doucement entre le début et la fin du segment
			position_actuelle = debut_segment.lerp(fin_segment, progress_segment)
			
	# 2. Vérification de la distance avec l'objectif lumineux en cours
	if not animation_terminee and index_objectif_courant < len(sequence_objectifs):
		var cible = sequence_objectifs[index_objectif_courant]
		if position_actuelle.distance_to(cible) <= seuil_distance:
			index_objectif_courant += 1 # Le joueur est assez proche, on passe à l'objectif suivant


func _draw() -> void:
	# 1. Dessin de la bordure
	for i in range(len(rectangle)-1):
		Ligne(rectangle[i], rectangle[i+1], Color.BLACK, 5)
		
	# 2. Dessin du repère (toujours visible et inchangé)
	Circle(Position_repere, 0.25, Color.DIM_GRAY)

	# Détermination de l'objectif en cours d'allumage
	var cible_actuelle = sequence_objectifs[index_objectif_courant] if index_objectif_courant < len(sequence_objectifs) else Vector2(-999, -999)
	
	# 3. Dessin des points (avec surbrillance si c'est la cible actuelle)
	var is_panier_active = (cible_actuelle == Position_panier)
	Circle(Position_panier, 0.4 if is_panier_active else 0.25, Color.YELLOW if is_panier_active else Color.SADDLE_BROWN, is_panier_active)

	var is_pommier_active = (cible_actuelle == Position_pommier)
	Circle(Position_pommier, 0.4 if is_pommier_active else 0.25, Color.ORANGE if is_pommier_active else Color.RED, is_pommier_active)

	for i in range(len(Position_arbre)):
		var is_arbre_active = (cible_actuelle == Position_arbre[i])
		Circle(Position_arbre[i], 0.4 if is_arbre_active else 0.25, Color.GREEN_YELLOW if is_arbre_active else Color.WEB_GREEN, is_arbre_active)

	# 4. Dessin du tracé accompli par le joueur
	# Lignes passées
	for i in range(current_path_index):
		Ligne(Position_joueur[i], Position_joueur[i+1], Color.DARK_BLUE, 3)
		
	# Ligne en cours de dessin (du dernier point passé à la position actuelle)
	if current_path_index < len(Position_joueur) - 1:
		Ligne(Position_joueur[current_path_index], position_actuelle, Color.DARK_BLUE, 3)
		
	# 5. Dessiner la "tête" du joueur pour qu'on le voie bouger
	Circle(position_actuelle, 0.15, Color.CYAN)


# --- FONCTIONS UTILITAIRES ---

func Ligne(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line((from - Vector2(8 ,8)) * scaling, (to - Vector2(8, 8)) * scaling, color, width, true) # Le 'true' ajoute l'antialiasing

# Modification de Circle pour supporter le mode "actif/allumé"
func Circle(center: Vector2, radius: float, color: Color, is_active: bool = false) -> void:
	var scaled_center = (center - Vector2(8, 8)) * scaling
	var scaled_radius = radius * scaling
	draw_circle(scaled_center, scaled_radius, color)
	
	# Si le point est la cible active, on lui dessine un contour (Halo)
	if is_active:
		draw_arc(scaled_center, scaled_radius + 4.0, 0, TAU, 32, Color.WHITE, 2.0, true)
