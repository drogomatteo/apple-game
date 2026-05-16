extends StaticBody3D

func _ready() -> void:
	_optimize_apples()

func _optimize_apples() -> void:
	var apple_meshes: Array[MeshInstance3D] = []
	_collect_apples(self, apple_meshes)

	if apple_meshes.is_empty():
		return

	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = apple_meshes.size()
	mm.mesh = apple_meshes[0].mesh
	mmi.multimesh = mm

	for i in range(apple_meshes.size()):
		var mi = apple_meshes[i]
		# Calcul de la position locale par rapport à l'arbre
		var local_transform = global_transform.affine_inverse() * mi.global_transform
		mm.set_instance_transform(i, local_transform)

		# Nettoyage des nœuds individuels pour libérer la mémoire
		var parent = mi.get_parent()
		if parent != self and parent is Node3D and parent.get_child_count() == 1:
			parent.queue_free()
		else:
			mi.queue_free()

	add_child(mmi)

func _collect_apples(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.name.begins_with("Apple"):
			result.append(child)
		else:
			_collect_apples(child, result)
