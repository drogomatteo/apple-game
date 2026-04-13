extends Node3D

# On passe en Vector3. L'axe Y (milieu) est à 0 pour rester au niveau du sol.
var positions_joueur
var pos_panier
var pos_pommier
var pos_repere
var pos_arbres

# Variables d'animation
var vitesse_animation: float = 3.0
var current_path_index: int = 0
var progress_segment: float = 0.0
var position_actuelle: Vector3

var sequence_objectifs: Array[Vector3] = []
var index_objectif_courant: int = 0
var seuil_distance: float = 0.5
var animation_terminee: bool = false

# Dictionnaires pour stocker nos objets 3D générés
var mesh_joueur: MeshInstance3D
var dictionnaire_marqueurs = {} # Pour retrouver quel mesh correspond à quelle position

var lancer = false

func launch(PositionJoueur, PositionPanier, PositionPommier, PositionArbres, PositionRepère = Vector3(0,-10,0)) -> void:
	positions_joueur = PositionJoueur
	pos_panier = PositionPanier
	pos_pommier = PositionPommier
	pos_repere = PositionRepère
	pos_arbres = PositionArbres
	
	position_actuelle = positions_joueur[0]
	
	current_path_index = 0
	animation_terminee = false
	
	# Création du joueur
	mesh_joueur = creer_sphere(0.3, Color.CYAN)
	add_child(mesh_joueur)
	mesh_joueur.position = position_actuelle
	
	lancer = true

func _process(delta: float) -> void:
	if lancer:
		print("Je démarre l'animation")
		if animation_terminee:
			lancer = false
			print("On arrete l'animation")
			return

		# 1. Déplacement du joueur en 3D
		if current_path_index < len(positions_joueur) - 1:
			var debut = positions_joueur[current_path_index]
			var fin = positions_joueur[current_path_index + 1]
			var distance = debut.distance_to(fin)
			
			progress_segment += (vitesse_animation * delta) / distance
			
			if progress_segment >= 1.0:
				print("Je bascule à la droite suivante")
				progress_segment = 0.0
				current_path_index += 1
				
				if current_path_index >= len(positions_joueur) - 1:
					animation_terminee = true
					position_actuelle = positions_joueur[-1]
				else:
					position_actuelle = positions_joueur[current_path_index]
			else:
				position_actuelle = debut.lerp(fin, progress_segment)
				
			# On applique la position calculée au Mesh du joueur
			mesh_joueur.position = position_actuelle


# --- FONCTIONS 3D ---

func creer_marqueur(pos: Vector3, couleur: Color, nom: String):
	var mesh = creer_sphere(0.5, couleur)
	mesh.position = pos
	mesh.name = nom
	add_child(mesh)
	# On stocke le mesh avec sa position comme clé pour le retrouver facilement
	dictionnaire_marqueurs[pos] = {"mesh": mesh, "couleur_base": couleur}

func creer_sphere(rayon: float, couleur: Color) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = rayon
	sphere.height = rayon * 2.0
	mesh_instance.mesh = sphere
	
	var materiel = StandardMaterial3D.new()
	materiel.albedo_color = couleur
	mesh_instance.material_override = materiel
	
	return mesh_instance
