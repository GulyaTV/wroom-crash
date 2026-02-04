extends MeshInstance3D

## Ультра продвинутая BeamNG Drive стиля деформация
## Максимально реалистичная визуальная деформация с акцентом на детали

@export var frame_resolution: int = 10
@export var deformation_strength: float = 0.4
@export var recovery_speed: float = 0.008
@export var collision_sensitivity: float = 0.003
@export var frame_stiffness: float = 0.85
@export var visual_detail_multiplier: float = 2.0
@export var metal_crease_threshold: float = 0.5
@export var surface_tension: float = 0.3
@export var impact_propagation_speed: float = 15.0

var frame_nodes: Array[Dictionary] = []
var frame_connections: Array[Dictionary] = []
var surface_triangles: Array[Dictionary] = []
var deformation_history: Array[Dictionary] = []
var impact_waves: Array[Dictionary] = []
var original_mesh: BoxMesh
var car_body: RigidBody3D
var collision_forces: Array[Dictionary] = []
var mesh_cache: ArrayMesh = null

func _ready():
	car_body = get_parent() as RigidBody3D
	
	if mesh is BoxMesh:
		original_mesh = mesh.duplicate()
		create_ultra_frame_structure()
		print("Ultra BeamNG deformation initialized: ", frame_nodes.size(), " nodes")
	else:
		print("Warning: Not a BoxMesh, creating fallback")
		create_fallback_frame()

func create_ultra_frame_structure():
	frame_nodes.clear()
	frame_connections.clear()
	surface_triangles.clear()
	
	var size = original_mesh.size
	
	for x in range(frame_resolution):
		for y in range(frame_resolution):
			for z in range(frame_resolution):
				var node = {
					"position": Vector3(
						(x / float(frame_resolution - 1) - 0.5) * size.x,
						(y / float(frame_resolution - 1) - 0.5) * size.y,
						(z / float(frame_resolution - 1) - 0.5) * size.z
					),
					"original_position": Vector3.ZERO,
					"velocity": Vector3.ZERO,
					"acceleration": Vector3.ZERO,
					"mass": 1.0,
					"fixed": false,
					"connections": [],
					"surface_normal": Vector3.UP,
					"deformation_level": 0.0,
					"stress_level": 0.0,
					"crease_factor": 0.0
				}
				node["original_position"] = node["position"]
				
				var is_surface = (x == 0 or x == frame_resolution - 1 or 
								  y == 0 or y == frame_resolution - 1 or 
								  z == 0 or z == frame_resolution - 1)
				
				if is_surface:
					node["mass"] = 0.8
					if x == 0: node["surface_normal"] = Vector3.LEFT
					elif x == frame_resolution - 1: node["surface_normal"] = Vector3.RIGHT
					elif y == 0: node["surface_normal"] = Vector3.DOWN
					elif y == frame_resolution - 1: node["surface_normal"] = Vector3.UP
					elif z == 0: node["surface_normal"] = Vector3.BACK
					elif z == frame_resolution - 1: node["surface_normal"] = Vector3.FORWARD
				else:
					node["mass"] = 1.2
				
				frame_nodes.append(node)
	
	create_ultra_connections()
	create_surface_triangles()
	
	print("Ultra frame created: ", frame_nodes.size(), " nodes, ", frame_connections.size(), " connections")

func create_ultra_connections():
	for x in range(frame_resolution):
		for y in range(frame_resolution):
			for z in range(frame_resolution):
				var current_idx = x * frame_resolution * frame_resolution + y * frame_resolution + z
				
				if x < frame_resolution - 1:
					create_ultra_connection(current_idx, current_idx + frame_resolution * frame_resolution, 1.0)
				if y < frame_resolution - 1:
					create_ultra_connection(current_idx, current_idx + frame_resolution, 1.0)
				if z < frame_resolution - 1:
					create_ultra_connection(current_idx, current_idx + 1, 1.0)
				
				if x < frame_resolution - 1 and y < frame_resolution - 1:
					create_ultra_connection(current_idx, current_idx + frame_resolution * frame_resolution + frame_resolution, 0.7)
				if x < frame_resolution - 1 and z < frame_resolution - 1:
					create_ultra_connection(current_idx, current_idx + frame_resolution * frame_resolution + 1, 0.7)
				if y < frame_resolution - 1 and z < frame_resolution - 1:
					create_ultra_connection(current_idx, current_idx + frame_resolution + 1, 0.7)

func create_ultra_connection(node_a_idx: int, node_b_idx: int, stiffness_factor: float):
	var connection = {
		"node_a": node_a_idx,
		"node_b": node_b_idx,
		"rest_length": 0.0,
		"stiffness": frame_stiffness * stiffness_factor,
		"damping": 0.95,
		"stress": 0.0,
		"broken": false
	}
	connection["rest_length"] = frame_nodes[node_a_idx]["position"].distance_to(frame_nodes[node_b_idx]["position"])
	frame_connections.append(connection)
	
	frame_nodes[node_a_idx]["connections"].append(node_b_idx)
	frame_nodes[node_b_idx]["connections"].append(node_a_idx)

func create_surface_triangles():
	create_face_triangles(Vector3.UP, frame_resolution - 1)
	create_face_triangles(Vector3.DOWN, 0)
	create_face_triangles(Vector3.FORWARD, frame_resolution - 1)
	create_face_triangles(Vector3.BACK, 0)
	create_face_triangles(Vector3.RIGHT, frame_resolution - 1)
	create_face_triangles(Vector3.LEFT, 0)

func create_face_triangles(normal: Vector3, fixed_coord: int):
	var resolution = frame_resolution
	
	for x in range(resolution - 1):
		for y in range(resolution - 1):
			var idx1, idx2, idx3, idx4
			
			if normal == Vector3.UP:
				idx1 = x * resolution * resolution + fixed_coord * resolution + y
				idx2 = (x + 1) * resolution * resolution + fixed_coord * resolution + y
				idx3 = x * resolution * resolution + fixed_coord * resolution + (y + 1)
				idx4 = (x + 1) * resolution * resolution + fixed_coord * resolution + (y + 1)
			elif normal == Vector3.DOWN:
				idx1 = x * resolution * resolution + fixed_coord * resolution + y
				idx2 = (x + 1) * resolution * resolution + fixed_coord * resolution + y
				idx3 = x * resolution * resolution + fixed_coord * resolution + (y + 1)
				idx4 = (x + 1) * resolution * resolution + fixed_coord * resolution + (y + 1)
			elif normal == Vector3.FORWARD:
				idx1 = x * resolution * resolution + y * resolution + fixed_coord
				idx2 = (x + 1) * resolution * resolution + y * resolution + fixed_coord
				idx3 = x * resolution * resolution + (y + 1) * resolution + fixed_coord
				idx4 = (x + 1) * resolution * resolution + (y + 1) * resolution + fixed_coord
			elif normal == Vector3.BACK:
				idx1 = x * resolution * resolution + y * resolution + fixed_coord
				idx2 = (x + 1) * resolution * resolution + y * resolution + fixed_coord
				idx3 = x * resolution * resolution + (y + 1) * resolution + fixed_coord
				idx4 = (x + 1) * resolution * resolution + (y + 1) * resolution + fixed_coord
			elif normal == Vector3.RIGHT:
				idx1 = fixed_coord * resolution * resolution + y * resolution + x
				idx2 = fixed_coord * resolution * resolution + y * resolution + (x + 1)
				idx3 = fixed_coord * resolution * resolution + (y + 1) * resolution + x
				idx4 = fixed_coord * resolution * resolution + (y + 1) * resolution + (x + 1)
			else:  # LEFT
				idx1 = fixed_coord * resolution * resolution + y * resolution + x
				idx2 = fixed_coord * resolution * resolution + y * resolution + (x + 1)
				idx3 = fixed_coord * resolution * resolution + (y + 1) * resolution + x
				idx4 = fixed_coord * resolution * resolution + (y + 1) * resolution + (x + 1)
			
			if idx1 < frame_nodes.size() and idx2 < frame_nodes.size() and 
			   idx3 < frame_nodes.size() and idx4 < frame_nodes.size():
				surface_triangles.append({
					"vertices": [idx1, idx2, idx3],
					"normal": normal,
					"original_area": calculate_triangle_area(idx1, idx2, idx3),
					"deformation": 0.0
				})
				
				surface_triangles.append({
					"vertices": [idx2, idx4, idx3],
					"normal": normal,
					"original_area": calculate_triangle_area(idx2, idx4, idx3),
					"deformation": 0.0
				})

func calculate_triangle_area(idx1: int, idx2: int, idx3: int) -> float:
	var v1 = frame_nodes[idx1]["position"]
	var v2 = frame_nodes[idx2]["position"]
	var v3 = frame_nodes[idx3]["position"]
	return (v1 - v2).cross(v1 - v3).length() / 2.0

func create_fallback_frame():
	frame_resolution = 6
	create_ultra_frame_structure()

func apply_collision_deformation(collision_point: Vector3, collision_force: float, collision_normal: Vector3):
	if not car_body or frame_nodes.size() == 0:
		return
	
	var local_collision_point = to_local(collision_point)
	var deformation_amount = collision_force * collision_sensitivity
	
	deformation_history.append({
		"position": local_collision_point,
		"force": deformation_amount,
		"normal": collision_normal,
		"time": Time.get_unix_time_from_system(),
		"type": "collision"
	})
	
	impact_waves.append({
		"origin": local_collision_point,
		"radius": 0.0,
		"max_radius": deformation_amount * 20.0,
		"strength": deformation_amount,
		"normal": collision_normal,
		"speed": impact_propagation_speed
	})
	
	apply_ultra_force_to_nodes(local_collision_point, deformation_amount, collision_normal)
	
	print("Ultra collision: force=", deformation_amount, " waves=", impact_waves.size())

func apply_ultra_force_to_nodes(force_position: Vector3, force_amount: float, force_direction: Vector3):
	var influence_radius = force_amount * 25.0
	
	for i in range(frame_nodes.size()):
		var node = frame_nodes[i]
		var distance = node["position"].distance_to(force_position)
		
		if distance < influence_radius:
			var influence = calculate_influence(distance, influence_radius, force_amount)
			
			var main_force = force_direction * force_amount * influence * 15.0
			
			var compression_force = Vector3.ZERO
			if node["surface_normal"].dot(force_direction) < 0:
				compression_force = node["surface_normal"] * force_amount * influence * 8.0
			else:
				compression_force = node["surface_normal"] * force_amount * influence * 3.0
			
			var random_force = Vector3(
				randf_range(-1, 1),
				randf_range(-1, 1),
				randf_range(-1, 1)
			).normalized() * force_amount * influence * 3.0
			
			var crease_force = Vector3.ZERO
			if force_amount > metal_crease_threshold:
				var crease_direction = node["surface_normal"].cross(force_direction).normalized()
				crease_force = crease_direction * force_amount * influence * 2.0
				node["crease_factor"] = min(node["crease_factor"] + influence * 0.1, 1.0)
			
			node["velocity"] += (main_force + compression_force + random_force + crease_force) / node["mass"]
			node["deformation_level"] = min(node["deformation_level"] + influence, 1.0)
			node["stress_level"] = min(node["stress_level"] + influence * 0.5, 1.0)

func calculate_influence(distance: float, max_distance: float, force_amount: float) -> float:
	var normalized_distance = distance / max_distance
	
	var primary_influence = max(0.0, 1.0 - normalized_distance)
	var secondary_influence = exp(-normalized_distance * 3.0) * 0.5
	var tertiary_influence = pow(max(0.0, 1.0 - normalized_distance * normalized_distance), 2.0) * 0.3
	
	return primary_influence + secondary_influence + tertiary_influence

func _physics_process(delta):
	if frame_nodes.size() == 0:
		return
	
	update_impact_waves(delta)
	update_ultra_frame_physics(delta)
	update_ultra_visual_mesh(delta)
	apply_ultra_recovery(delta)
	cleanup_old_data()

func update_impact_waves(delta):
	var waves_to_remove = []
	
	for i in range(impact_waves.size()):
		var wave = impact_waves[i]
		wave["radius"] += wave["speed"] * delta
		
		for j in range(frame_nodes.size()):
			var node = frame_nodes[j]
			var distance = node["position"].distance_to(wave["origin"])
			
			if abs(distance - wave["radius"]) < 2.0:
				var wave_influence = exp(-pow(distance - wave["radius"], 2) / 4.0)
				var wave_force = wave["normal"] * wave["strength"] * wave_influence * 5.0
				node["velocity"] += wave_force / node["mass"]
		
		if wave["radius"] > wave["max_radius"]:
			waves_to_remove.append(i)
	
	for i in range(waves_to_remove.size() - 1, -1, -1):
		impact_waves.remove_at(waves_to_remove[i])

func update_ultra_frame_physics(delta):
	var damping = 0.985
	
	for i in range(frame_nodes.size()):
		var node = frame_nodes[i]
		
		if not node["fixed"]:
			node["acceleration"] *= 0.9
			node["position"] += node["velocity"] * delta + 0.5 * node["acceleration"] * delta * delta
			node["velocity"] *= damping
			
			if delta > 0:
				node["acceleration"] = (node["velocity"] - node["acceleration"] * delta) / delta
	
	for connection in frame_connections:
		if not connection["broken"]:
			apply_ultra_spring_force(connection, delta)
	
	apply_surface_tension(delta)
	
	for i in range(frame_nodes.size()):
		var node = frame_nodes[i]
		if not node["fixed"]:
			var restore_force = (node["original_position"] - node["position"]) * 0.15
			node["velocity"] += restore_force * delta

func apply_ultra_spring_force(connection: Dictionary, delta):
	var node_a = frame_nodes[connection["node_a"]]
	var node_b = frame_nodes[connection["node_b"]]
	
	var current_length = node_a["position"].distance_to(node_b["position"])
	
	if current_length > 0.001:
		var length_diff = current_length - connection["rest_length"]
		
		if abs(length_diff) > connection["rest_length"] * 0.5:
			connection["broken"] = true
			return
		
		var force_magnitude = length_diff * connection["stiffness"]
		force_magnitude *= (1.0 + abs(length_diff) / connection["rest_length"])
		
		var force_direction = (node_b["position"] - node_a["position"]).normalized()
		var force = force_direction * force_magnitude
		
		var relative_velocity = node_b["velocity"] - node_a["velocity"]
		var damping_force = relative_velocity.dot(force_direction) * connection["damping"] * 0.1
		force -= force_direction * damping_force
		
		if not node_a["fixed"]:
			node_a["velocity"] += force * delta / node_a["mass"]
			node_a["acceleration"] += force / node_a["mass"]
		if not node_b["fixed"]:
			node_b["velocity"] -= force * delta / node_b["mass"]
			node_b["acceleration"] -= force / node_b["mass"]
		
		connection["stress"] = abs(length_diff) / connection["rest_length"]

func apply_surface_tension(delta):
	for triangle in surface_triangles:
		var vertices = triangle["vertices"]
		if vertices.size() == 3:
			var v1 = frame_nodes[vertices[0]]
			var v2 = frame_nodes[vertices[1]]
			var v3 = frame_nodes[vertices[2]]
			
			var center = (v1["position"] + v2["position"] + v3["position"]) / 3.0
			
			for vertex_idx in vertices:
				var node = frame_nodes[vertex_idx]
				if not node["fixed"]:
					var tension_force = (center - node["position"]) * surface_tension * 0.1
					node["velocity"] += tension_force * delta

func update_ultra_visual_mesh(_delta):
	if frame_nodes.size() == 0:
		return
	
	if mesh_cache == null:
		mesh_cache = ArrayMesh.new()
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = generate_ultra_vertices()
	var normals = calculate_ultra_normals(vertices)
	var indices = generate_ultra_indices(vertices.size())
	var uvs = generate_ultra_uvs(vertices.size())
	var colors = generate_deformation_colors()
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	
	mesh_cache.clear_surfaces()
	mesh_cache.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	if original_mesh.get_surface_count() > 0:
		var original_material = original_mesh.surface_get_material(0)
		if original_material:
			mesh_cache.surface_set_material(0, original_material)
	
	mesh = mesh_cache

func generate_ultra_vertices() -> PackedVector3Array:
	var vertices = PackedVector3Array()
	var resolution = frame_resolution
	
	var faces = [
		{"normal": Vector3.UP, "fixed_coord": resolution - 1, "axis": "y"},
		{"normal": Vector3.DOWN, "fixed_coord": 0, "axis": "y"},
		{"normal": Vector3.FORWARD, "fixed_coord": resolution - 1, "axis": "z"},
		{"normal": Vector3.BACK, "fixed_coord": 0, "axis": "z"},
		{"normal": Vector3.RIGHT, "fixed_coord": resolution - 1, "axis": "x"},
		{"normal": Vector3.LEFT, "fixed_coord": 0, "axis": "x"}
	]
	
	for face in faces:
		for x in range(resolution):
			for y in range(resolution):
				var node_idx = get_face_node_index(x, y, face["fixed_coord"], face["axis"])
				if node_idx < frame_nodes.size():
					var node = frame_nodes[node_idx]
					var vertex = node["position"]
					
					if node["deformation_level"] > 0.1:
						var detail_offset = Vector3(
							sin(node["position"].x * 10.0) * node["deformation_level"] * 0.02,
							sin(node["position"].y * 10.0) * node["deformation_level"] * 0.02,
							sin(node["position"].z * 10.0) * node["deformation_level"] * 0.02
						)
						vertex += detail_offset * visual_detail_multiplier
					
					if node["crease_factor"] > 0.1:
						var crease_offset = node["surface_normal"] * node["crease_factor"] * 0.1
						vertex -= crease_offset
					
					vertices.append(vertex)
	
	return vertices

func get_face_node_index(x: int, y: int, fixed_coord: int, axis: String) -> int:
	var resolution = frame_resolution
	
	match axis:
		"y":
			return x * resolution * resolution + fixed_coord * resolution + y
		"z":
			return x * resolution * resolution + y * resolution + fixed_coord
		"x":
			return fixed_coord * resolution * resolution + y * resolution + x
		_:
			return 0

func calculate_ultra_normals(vertices: PackedVector3Array) -> PackedVector3Array:
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	
	var resolution = frame_resolution
	var face_vertex_count = resolution * resolution
	
	for face in range(6):
		var face_offset = face * face_vertex_count
		for i in range(face_vertex_count):
			var vertex_idx = face_offset + i
			if vertex_idx < vertices.size():
				var base_normal = get_face_normal(face)
				
				if i < frame_nodes.size():
					var node = frame_nodes[i]
					var deformation_factor = node["deformation_level"]
					
					var deformed_normal = base_normal
					if deformation_factor > 0.1:
						var random_offset = Vector3(
							randf_range(-0.1, 0.1),
							randf_range(-0.1, 0.1),
							randf_range(-0.1, 0.1)
						) * deformation_factor
						deformed_normal = (base_normal + random_offset).normalized()
					
					normals[vertex_idx] = deformed_normal
				else:
					normals[vertex_idx] = base_normal
	
	return normals

func get_face_normal(face_index: int) -> Vector3:
	match face_index:
		0: return Vector3.UP
		1: return Vector3.DOWN
		2: return Vector3.FORWARD
		3: return Vector3.BACK
		4: return Vector3.RIGHT
		5: return Vector3.LEFT
		_: return Vector3.UP

func generate_ultra_indices(vertex_count: int) -> PackedInt32Array:
	var indices = PackedInt32Array()
	var resolution = frame_resolution
	var face_vertex_count = resolution * resolution
	
	for face in range(6):
		var face_offset = face * face_vertex_count
		for x in range(resolution - 1):
			for z in range(resolution - 1):
				var i = x * resolution + z + face_offset
				if i + resolution + 1 < vertex_count:
					indices.append(i)
					indices.append(i + 1)
					indices.append(i + resolution)
					indices.append(i + 1)
					indices.append(i + resolution + 1)
					indices.append(i + resolution)
	
	return indices

func generate_ultra_uvs(vertex_count: int) -> PackedVector2Array:
	var uvs = PackedVector2Array()
	uvs.resize(vertex_count)
	
	var resolution = frame_resolution
	var face_vertex_count = resolution * resolution
	
	for face in range(6):
		var face_offset = face * face_vertex_count
		for x in range(resolution):
			for z in range(resolution):
				var i = x * resolution + z + face_offset
				if i < vertex_count:
					var base_uv = Vector2(x / float(resolution - 1), z / float(resolution - 1))
					
					var node_idx = x * resolution * resolution + z
					if node_idx < frame_nodes.size():
						var deformation = frame_nodes[node_idx]["deformation_level"]
						if deformation > 0.1:
							var uv_distortion = Vector2(
								sin(deformation * PI * 2.0) * 0.1,
								cos(deformation * PI * 2.0) * 0.1
							) * deformation
							base_uv += uv_distortion
					
					uvs[i] = base_uv
	
	return uvs

func generate_deformation_colors() -> PackedColorArray:
	var colors = PackedColorArray()
	
	for node in frame_nodes:
		var base_color = Color(0.2, 0.6, 1.0, 1.0)
		
		var deformation = node["deformation_level"]
		var stress = node["stress_level"]
		
		if deformation > 0.1:
			base_color.r = min(1.0, base_color.r + deformation * 0.8)
			base_color.g = max(0.0, base_color.g - deformation * 0.4)
			base_color.b = max(0.0, base_color.b - deformation * 0.6)
		
		if stress > 0.5:
			base_color *= (1.0 - stress * 0.3)
		
		if node["crease_factor"] > 0.1:
			base_color.r = min(1.0, base_color.r + node["crease_factor"] * 0.2)
			base_color.g = min(1.0, base_color.g + node["crease_factor"] * 0.1)
		
		colors.append(base_color)
	
	return colors

func apply_ultra_recovery(delta):
	for i in range(frame_nodes.size()):
		var node = frame_nodes[i]
		if not node["fixed"]:
			var restore_force = (node["original_position"] - node["position"]) * recovery_speed
			node["velocity"] += restore_force
			
			node["deformation_level"] = max(0.0, node["deformation_level"] - recovery_speed * delta * 0.5)
			node["stress_level"] = max(0.0, node["stress_level"] - recovery_speed * delta * 0.7)
			node["crease_factor"] = max(0.0, node["crease_factor"] - recovery_speed * delta * 0.3)
			
			for connection in frame_connections:
				if connection["node_a"] == i or connection["node_b"] == i:
					connection["stress"] = max(0.0, connection["stress"] - recovery_speed * delta * 0.5)

func cleanup_old_data():
	var current_time = Time.get_unix_time_from_system()
	
	var forces_to_remove = []
	for i in range(collision_forces.size()):
		if current_time - collision_forces[i]["time"] > 3.0:
			forces_to_remove.append(i)
	
	for i in range(forces_to_remove.size() - 1, -1, -1):
		collision_forces.remove_at(forces_to_remove[i])
	
	var history_to_remove = []
	for i in range(deformation_history.size()):
		if current_time - deformation_history[i]["time"] > 10.0:
			history_to_remove.append(i)
	
	for i in range(history_to_remove.size() - 1, -1, -1):
		deformation_history.remove_at(history_to_remove[i])

func get_total_deformation() -> float:
	var total_deform = 0.0
	var max_deform = 0.0
	
	for node in frame_nodes:
		var deform = node["position"].distance_to(node["original_position"])
		total_deform += deform
		max_deform = max(max_deform, deform)
	
	return min(total_deform / frame_nodes.size(), 1.0)

func apply_damage_deformation(damage_level: float):
	var num_impacts = int(damage_level * 15) + 1
	var size = original_mesh.size
	
	for i in range(num_impacts):
		var random_pos = Vector3(
			randf_range(-size.x * 0.5, size.x * 0.5),
			randf_range(-size.y * 0.5, size.y * 0.5),
			randf_range(-size.z * 0.5, size.z * 0.5)
		)
		
		var random_force = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			randf_range(-1, 1)
		).normalized() * damage_level * 0.8
		
		apply_ultra_force_to_nodes(random_pos, damage_level * 0.5, random_force)
