extends Node3D

@export var lod1_distance: float = 5.0
@export var lod2_distance: float = 12.0
@export var update_rate: float = 0.2 # Met à jour 5 fois par seconde pour optimiser le CPU

var _lod_groups: Dictionary = {}
var _time_since_update: float = 0.0

func _ready() -> void:
	_collect_lods(self)
	_update_lods() # Première passe immédiate au chargement

func _process(delta: float) -> void:
	_time_since_update += delta
	if _time_since_update >= update_rate:
		_time_since_update = 0.0
		_update_lods()

func _update_lods() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
		
	var cam_pos := camera.global_position
	
	for parent: Node3D in _lod_groups:
		var lods: Array = _lod_groups[parent]
		var distance := parent.global_position.distance_to(cam_pos)
		
		# Déterminer quel niveau afficher
		var active_lod := 0
		if distance >= lod2_distance:
			active_lod = 2
		elif distance >= lod1_distance:
			active_lod = 1
			
		# Si le LOD ciblé n'existe pas pour cette instance, on prend le plus détaillé disponible
		while active_lod > 0 and lods[active_lod] == null:
			active_lod -= 1
			
		# Appliquer la visibilité
		for i in range(3):
			var mesh: MeshInstance3D = lods[i]
			if mesh != null:
				mesh.visible = (i == active_lod)

func _collect_lods(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var parent = child.get_parent()
			
			# Si c'est un LOD, on l'ajoute au dictionnaire groupé par son nœud parent
			if "LOD" in child.name:
				if not _lod_groups.has(parent):
					# Initialiser le tableau [LOD0, LOD1, LOD2]
					_lod_groups[parent] = [null, null, null]
				
				if "LOD0" in child.name:
					_lod_groups[parent][0] = child
				elif "LOD1" in child.name:
					_lod_groups[parent][1] = child
				elif "LOD2" in child.name:
					_lod_groups[parent][2] = child
		else:
			_collect_lods(child)
