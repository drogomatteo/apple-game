extends Node3D

@export var chunk_size: float = 6.0
@export var density_per_m2: float = 8.0

@export var grass_mesh: Mesh
@export var grass_material: Material

@export var near_density_multiplier: float = 1.0
@export var far_density_multiplier: float = 0.35

@export var near_scale_multiplier: float = 1.0
@export var far_scale_multiplier: float = 1.8

@export var near_min_random_scale: float = 0.8
@export var near_max_random_scale: float = 1.2

@export var far_min_random_scale: float = 0.8
@export var far_max_random_scale: float = 1.2
@export var near_visibility_begin: float = 0.0
@export var near_visibility_end: float = 8.0
@export var near_visibility_end_margin: float = 0.25

@export var far_visibility_begin: float = 5.5
@export var far_visibility_begin_margin: float = 0.25
@export var far_visibility_end: float = 12.0
@export var far_visibility_end_margin: float = 1.0

@export var rebuild_on_ready: bool = true

var chunks: Array[MultiMeshInstance3D] = []

func _ready() -> void:
	randomize()
	call_deferred("_setup_after_first_frame")

func _setup_after_first_frame() -> void:
	await get_tree().process_frame
	setup_all_chunks()

func setup_all_chunks() -> void:
	chunks.clear()

	for child in get_children():
		var grass_near := child.get_node_or_null("GrassNear") as MultiMeshInstance3D
		var grass_far := child.get_node_or_null("GrassFar") as MultiMeshInstance3D

		if grass_near == null and grass_far == null:
			print("Aucun GrassNear / GrassFar trouvé dans : ", child.name)
			continue

		var base_seed := child.name.hash()

		if grass_near != null:
			setup_grass_node(grass_near)
			configure_near_visibility(grass_near)
			chunks.append(grass_near)

			if rebuild_on_ready:
				populate_chunk_with_density(
					grass_near,
					density_per_m2 * near_density_multiplier,
					near_scale_multiplier,
					near_min_random_scale,
					near_max_random_scale,
					base_seed + 1
				)

		if grass_far != null:
			setup_grass_node(grass_far)
			configure_far_visibility(grass_far)
			chunks.append(grass_far)

			if rebuild_on_ready:
				populate_chunk_with_density(
					grass_far,
					density_per_m2 * far_density_multiplier,
					far_scale_multiplier,
					far_min_random_scale,
					far_max_random_scale,
					base_seed + 2
				)

func setup_grass_node(node: MultiMeshInstance3D) -> void:
	var new_multimesh := MultiMesh.new()
	new_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	new_multimesh.mesh = grass_mesh

	node.multimesh = new_multimesh

	if grass_material != null:
		node.material_override = grass_material

	var half := chunk_size * 0.5
	node.multimesh.custom_aabb = AABB(
		Vector3(-half, -1.0, -half),
		Vector3(chunk_size, 3.0, chunk_size)
	)

func populate_chunk_with_density(
	node: MultiMeshInstance3D,
	density: float,
	grass_scale_multiplier: float,
	min_random_scale: float,
	max_random_scale: float,
	chunk_seed: int
) -> void:
	var mm := node.multimesh
	if mm == null:
		return

	var area := chunk_size * chunk_size
	var target_count := int(area * density)
	target_count = max(target_count, 0)

	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed

	var grid_size := int(ceil(sqrt(float(target_count))))
	grid_size = max(grid_size, 1)

	var cell_size := chunk_size / float(grid_size)

	var transforms: Array[Transform3D] = []

	for gz in range(grid_size):
		for gx in range(grid_size):
			if transforms.size() >= target_count:
				break

			var cell_center_x := -chunk_size * 0.5 + (gx + 0.5) * cell_size
			var cell_center_z := -chunk_size * 0.5 + (gz + 0.5) * cell_size

			var jitter_x := rng.randf_range(-cell_size * 0.35, cell_size * 0.35)
			var jitter_z := rng.randf_range(-cell_size * 0.35, cell_size * 0.35)

			var px := cell_center_x + jitter_x
			var pz := cell_center_z + jitter_z
			var py := 0.0

			var random_scale := rng.randf_range(min_random_scale, max_random_scale)
			var final_scale := random_scale * grass_scale_multiplier
			var rot_y := rng.randf_range(0.0, TAU)

			var basis := Basis()
			basis = basis.rotated(Vector3.UP, rot_y)
			basis = basis.scaled(Vector3(final_scale, final_scale, final_scale))

			var transform := Transform3D(basis, Vector3(px, py, pz))
			transforms.append(transform)

	if target_count == 0:
		mm.instance_count = 0
		mm.visible_instance_count = 0
		return

	mm.instance_count = transforms.size()
	mm.visible_instance_count = transforms.size()

	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])

func configure_near_visibility(node: MultiMeshInstance3D) -> void:
	node.visibility_range_begin = near_visibility_begin
	node.visibility_range_end = near_visibility_end
	node.visibility_range_end_margin = near_visibility_end_margin

func configure_far_visibility(node: MultiMeshInstance3D) -> void:
	node.visibility_range_begin = far_visibility_begin
	node.visibility_range_begin_margin = far_visibility_begin_margin
	node.visibility_range_end = far_visibility_end
	node.visibility_range_end_margin = far_visibility_end_margin

func set_mobile_mode(enabled: bool) -> void:
	for node in chunks:
		var mm := node.multimesh
		if mm == null:
			continue

		if enabled:
			mm.visible_instance_count = int(mm.instance_count * 0.5)
		else:
			mm.visible_instance_count = mm.instance_count

func rebuild_all_chunks() -> void:
	randomize()
	setup_all_chunks()
