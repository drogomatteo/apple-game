extends Node3D

@export_group("Grass Distribution")
@export var use_distribution_texture: bool = true
@export var distribution_texture: Texture2D
@export var distribution_texture_scale: float = 0.05
@export var distribution_threshold: float = 0.5
@export var distribution_softness: float = 0.15
@export var invert_distribution_mask: bool = false

@export_group("Grass Edge Scaling")
@export var enable_edge_scale_falloff: bool = true
@export var edge_scale_min: float = 0.45

@export_group("Distribution Remap")
@export var remap_distribution_values: bool = true
@export var distribution_input_min: float = 0.80
@export var distribution_input_max: float = 0.90

var distribution_image: Image

@export_group("Chunk Settings")
@export var chunk_size: float = 6.0
@export var density_per_m2: float = 8.0

@export_group("Grass Resources")
@export var grass_mesh: Mesh
@export var grass_material: Material

@export_group("Near Grass")
@export var near_density_multiplier: float = 1.0
@export var near_scale_multiplier: float = 1.0
@export var near_min_random_scale: float = 0.8
@export var near_max_random_scale: float = 1.2
@export var near_visibility_begin: float = 0.0
@export var near_visibility_end: float = 8.0
@export var near_visibility_end_margin: float = 0.25

@export_group("Far Grass")
@export var far_density_multiplier: float = 0.35
@export var far_scale_multiplier: float = 1.8
@export var far_min_random_scale: float = 0.8
@export var far_max_random_scale: float = 1.2
@export var far_visibility_begin: float = 5.5
@export var far_visibility_begin_margin: float = 0.25
@export var far_visibility_end: float = 12.0
@export var far_visibility_end_margin: float = 1.0

@export_group("Build")
@export var rebuild_on_ready: bool = true

@export_group("Debug")
@export var print_distribution_debug: bool = false

var chunks: Array[MultiMeshInstance3D] = []


func _ready() -> void:
	randomize()
	await setup_distribution_texture()
	call_deferred("_setup_after_first_frame")


func setup_distribution_texture() -> void:
	if distribution_texture == null:
		distribution_image = null
		return

	# Cas particulier : NoiseTexture2D peut ne pas être prête tout de suite
	if distribution_texture is NoiseTexture2D:
		var noise_tex := distribution_texture as NoiseTexture2D

		distribution_image = noise_tex.get_image()

		if distribution_image == null:
			await noise_tex.changed
			distribution_image = noise_tex.get_image()

	else:
		distribution_image = distribution_texture.get_image()

		if distribution_image == null:
			pass

func remap_distribution_value(value: float) -> float:
	if not remap_distribution_values:
		return clampf(value, 0.0, 1.0)

	if distribution_input_max <= distribution_input_min:
		return clampf(value, 0.0, 1.0)

	return clampf(inverse_lerp(distribution_input_min, distribution_input_max, value), 0.0, 1.0)


func sample_distribution_texture(world_x: float, world_z: float) -> float:
	if distribution_image == null:
		return 1.0

	var uv_x: float = world_x * distribution_texture_scale
	var uv_z: float = world_z * distribution_texture_scale

	uv_x = uv_x - floor(uv_x)
	uv_z = uv_z - floor(uv_z)

	var w: int = distribution_image.get_width()
	var h: int = distribution_image.get_height()

	if w <= 0 or h <= 0:
		return 1.0

	var fx: float = uv_x * float(w - 1)
	var fz: float = uv_z * float(h - 1)

	var x0: int = int(floor(fx))
	var z0: int = int(floor(fz))
	var x1: int = min(x0 + 1, w - 1)
	var z1: int = min(z0 + 1, h - 1)

	var tx: float = fx - float(x0)
	var tz: float = fz - float(z0)

	var c00: float = distribution_image.get_pixel(x0, z0).r
	var c10: float = distribution_image.get_pixel(x1, z0).r
	var c01: float = distribution_image.get_pixel(x0, z1).r
	var c11: float = distribution_image.get_pixel(x1, z1).r

	var a: float = lerpf(c00, c10, tx)
	var b: float = lerpf(c01, c11, tx)

	return lerpf(a, b, tz)


func _setup_after_first_frame() -> void:
	await get_tree().process_frame
	setup_all_chunks()


func setup_all_chunks() -> void:
	chunks.clear()

	for child in get_children():
		var grass_near := child.get_node_or_null("GrassNear") as MultiMeshInstance3D
		var grass_far := child.get_node_or_null("GrassFar") as MultiMeshInstance3D

		if grass_near == null and grass_far == null:
			continue

		var base_seed: int = child.name.hash()

		if grass_near != null:
			setup_grass_node(grass_near)
			configure_near_visibility(grass_near)
			chunks.append(grass_near)

			if rebuild_on_ready:
				populate_chunk_with_density(grass_near, density_per_m2 * near_density_multiplier, near_scale_multiplier, near_min_random_scale, near_max_random_scale, base_seed + 1)

		if grass_far != null:
			setup_grass_node(grass_far)
			configure_far_visibility(grass_far)
			chunks.append(grass_far)

			if rebuild_on_ready:
				populate_chunk_with_density(grass_far, density_per_m2 * far_density_multiplier, far_scale_multiplier, far_min_random_scale, far_max_random_scale, base_seed + 2)


func setup_grass_node(node: MultiMeshInstance3D) -> void:
	var new_multimesh := MultiMesh.new()
	new_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	new_multimesh.mesh = grass_mesh

	node.multimesh = new_multimesh

	if grass_material != null:
		node.material_override = grass_material

	var half: float = chunk_size * 0.5
	node.multimesh.custom_aabb = AABB(Vector3(-half, -1.0, -half), Vector3(chunk_size, 3.0, chunk_size))


func populate_chunk_with_density(node: MultiMeshInstance3D, density: float, grass_scale_multiplier: float, min_random_scale: float, max_random_scale: float, chunk_seed: int) -> void:
	var mm := node.multimesh
	if mm == null:
		return

	var area: float = chunk_size * chunk_size
	var target_count: int = int(area * density)
	target_count = max(target_count, 0)

	if target_count == 0:
		mm.instance_count = 0
		mm.visible_instance_count = 0
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed

	var grid_size: int = int(ceil(sqrt(float(target_count))))
	grid_size = max(grid_size, 1)

	var cell_size: float = chunk_size / float(grid_size)

	var transforms: Array[Transform3D] = []

	var max_attempts: int = target_count * 8
	var attempts: int = 0
	var debug_print_count: int = 0

	while transforms.size() < target_count and attempts < max_attempts:
		attempts += 1

		var gx: int = rng.randi_range(0, grid_size - 1)
		var gz: int = rng.randi_range(0, grid_size - 1)

		var cell_center_x: float = -chunk_size * 0.5 + (float(gx) + 0.5) * cell_size
		var cell_center_z: float = -chunk_size * 0.5 + (float(gz) + 0.5) * cell_size

		var jitter_x: float = rng.randf_range(-cell_size * 0.35, cell_size * 0.35)
		var jitter_z: float = rng.randf_range(-cell_size * 0.35, cell_size * 0.35)

		var px: float = cell_center_x + jitter_x
		var pz: float = cell_center_z + jitter_z
		var py: float = 0.0

		var world_x: float = node.global_position.x + px
		var world_z: float = node.global_position.z + pz
		
		var edge_scale_factor: float = 1.0
		
		if use_distribution_texture:
			var raw_distribution_value: float = sample_distribution_texture(world_x, world_z)
			var distribution_value: float = remap_distribution_value(raw_distribution_value)

			if invert_distribution_mask:
				distribution_value = 1.0 - distribution_value



			# En dehors du cluster -> rejet
			if distribution_value > distribution_threshold + distribution_softness:
				continue

			# Zone de transition -> possible rejet + réduction de taille
			elif distribution_value > distribution_threshold:
				var t: float = inverse_lerp(distribution_threshold, distribution_threshold + distribution_softness, distribution_value)

				if rng.randf() < t:
					continue

				if enable_edge_scale_falloff:
					# t = 0 au début de la transition
					# t = 1 à l’extérieur
					# donc on inverse pour garder une grande taille côté intérieur
					edge_scale_factor = lerpf(1.0, edge_scale_min, t)

			# Bien à l’intérieur du cluster -> taille normale
			else:
				edge_scale_factor = 1.0
		
		

		var random_scale: float = rng.randf_range(min_random_scale, max_random_scale)
		var final_scale: float = random_scale * grass_scale_multiplier * edge_scale_factor
		var rot_y: float = rng.randf_range(0.0, TAU)

		var basis := Basis()
		basis = basis.rotated(Vector3.UP, rot_y)
		basis = basis.scaled(Vector3(final_scale, final_scale, final_scale))

		var transform := Transform3D(basis, Vector3(px, py, pz))
		transforms.append(transform)

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
