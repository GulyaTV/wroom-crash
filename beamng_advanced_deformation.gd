extends MeshInstance3D

## Продвинутая BeamNG стиля деформация с акцентом на визуальные эффекты

@export var frame_resolution: int = 12  # Высокое разрешение для детализации
@export var deformation_strength: float = 0.5
@export var recovery_speed: float = 0.005
@export var collision_sensitivity: float = 0.002
@export var frame_stiffness: float = 0.9
@export var visual_detail_multiplier: float = 3.0
@export var metal_crease_threshold: float = 0.4
@export var surface_tension: float = 0.4
@export var impact_propagation_speed: float = 20.0

var frame_nodes: Array[Dictionary] = []
var frame_connections: Array[Dictionary] = []
var original_mesh: BoxMesh
var car_body: RigidBody3D
var collision_forces: Array[Dictionary] = []
var impact_waves: Array[Dictionary] = []
var mesh_cache: ArrayMesh = null

func _ready():
	car_body = get_parent() as RigidBody3D
	
	if mesh is BoxMesh:
		original_mesh = mesh.duplicate()
		create_advanced_frame_structure()
		print("Advanced BeamNG deformation initialized: ", frame_nodes.size(), " nodes")
	else:
		print("Warning: Not a BoxMesh, creating fallback")
		create_fallback_frame()

func create_advanced_frame_structure():
	frame_nodes.clear()
	frame_connections.clear()
	
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
					"mass": 1.0,
					"fixed": false,
					"connections": [],
					"surface_normal": Vector3.UP,
					"deformation_level": 0.0,
					"stress_level": 0.0,
					"crease_factor": 0.0,
					"impact_history": []
				}
				node["original_position"] = node["position"]
				
				var is_surface = (x == 0 or x == frame_resolution - 1 or 
								  y == 0 or y == frame_resolution - 1 or 
								  z == 0 or z == frame_resolution - 1)
				
				if is_surface:
					node["mass"] = 0.7
					if x == 0: node["surface_normal"] = Vector3.LEFT
					elif x == frame_resolution - 1: node["surface_normal"] = Vector3.RIGHT
					elif y == 0: node["surface_normal"] = Vector3.DOWN
					elif y == frame_resolution - 1: node["surface_normal"] = Vector3.UP
					elif z == 0: node["surface_normal"] = Vector3.BACK
					elif z == frame_resolution - 1: node["surface_normal"] = Vector3.FORWARD
				else:
					node["mass"] = 1.3
				
				frame_nodes.append(node)
	
	create_advanced_connections()
	
	print("Advanced frame created: ", frame_nodes.size(), " nodes, ", frame_connections.size(), " connections")

func create_advanced_connections():
	for x in range(frame_resolution):
		for y in range(frame_resolution):
			for z in range(frame_resolution):
				var current_idx = x * frame_resolution * frame_resolution + y * frame_resolution + z
				
				if x < frame_resolution - 1:
					create_connection(current_idx, current_idx + frame_resolution * frame_resolution, 1.0)
				if y < frame_resolution - 1:
					create_connection(current_idx, current_idx + frame_resolution, 1.0)
				if z < frame_resolution - 1:
					create_connection(current_idx, current_idx + 1, 1.0)
				
				if x < frame_resolution - 1 and y < frame_resolution - 1:
					create_connection(current_idx, current_idx + frame_resolution * frame_resolution + frame_resolution, 0.8)
				if x < frame_resolution - 1 and z < frame_resolution - 1:
					create_connection(current_idx, current_idx + frame_resolution * frame_resolution + 1, 0.8)
				if y < frame_resolution - 1 and z < frame_resolution - 1:
					create_connection(current_idx, current_idx + frame_resolution + 1, 0.8)
				
				if x < frame_resolution - 1 and y < frame_resolution - 1 and z < frame_resolution - 1:
					var diag_idx = current_idx + frame_resolution * frame_resolution + frame_resolution + 1
					create_connection(current_idx, diag_idx, 0.6)

func create_connection(node_a_idx: int, node_b_idx: int, stiffness_factor: float):
	var connection = {
		"node_a": node_a_idx,
		"node_b": node_b_idx,
		"rest_length": 0.0,
		"stiffness": frame_stiffness * stiffness_factor,
		"damping": 0.96,
		"stress": 0.0,
		"broken": false
	}
	connection["rest_length"] = frame_nodes[node_a_idx]["position"].distance_to(frame_nodes[node_b_idx]["position"])
	frame_connections.append(connection)
	
	frame_nodes[node_a_idx]["connections"].append(node_b_idx)
	frame_nodes[node_b_idx]["connections"].append(node_a_idx)

func create_fallback_frame():
	frame_resolution = 8
	create_advanced_frame_structure()

func apply_collision_deformation(collision_point: Vector3, collision_force: float, collision_normal: Vector3):
	if not car_body or frame_nodes.size() == 0:
		return
	
	var local_collision_point = to_local(collision_point)
	var deformation_amount = collision_force * collision_sensitivity
	
	impact_waves.append({
		"origin": local_collision_point,
		"radius": 0.0,
		"max_radius": deformation_amount * 25.0,
		"strength": deformation_amount,
		"normal": collision_normal,
		"speed": impact_propagation_speed
	})
	
	apply_advanced_force_to_nodes(local_collision_point, deformation_amount, collision_normal)
	
	print("Advanced collision: force=", deformation_amount, " waves=", impact_waves.size())

func apply_advanced_force_to_nodes(force_position: Vector3, force_amount: float, force_direction: Vector3):
	var influence_radius = force_amount * 30.0
	
	for i in range(frame_nodes.size()):
		var node = frame_nodes[i]
		var distance = node["position"].distance_to(force_position)
		
		if distance < influence_radius:
			var influence = calculate_advanced_influence(distance, influence_radius, force_amount)
			
			var main_force = force_direction * force_amount * influence * 20.0
			
			var compression_force = Vector3.ZERO
			if node["surface_normal"].dot(force_direction) < 0:
				compression_force = node["surface_normal"] * force_amount * influence * 10.0
			else:
				compression_force = node["surface_normal"] * force_amount * influence * 4.0
			
			var random_force = Vector3(
				randf_range(-1, 1),
				randf_range(-1, 1),
				randf_range(-1, 1)
			).normalized() * force_amount * influence * 4.0
			
			var crease_force = Vector3.ZERO
			if force_amount > metal_crease_threshold:
				var crease_direction = node["surface_normal"].cross(force_direction).normalized()
				crease_force = crease_direction * force_amount * influence * 3.0
				node["crease_factor"] = min(node["crease_factor"] + influence * 0.15, 1.0)
			
			node["velocity"] += (main_force + compression_force + random_force + crease_force) / node["mass"]
			node["deformation_level"] = min(node["deformation_level"] + influence * 1.2, 1.0)
			node["stress_level"] = min(node["stress_level"] + influence * 0.7, 1.0)
			
			node["impact_history"].append({
				"force": force_amount,
				"time": Time.get_unix_time_from_system()
			})

func calculate_advanced_influence(distance: float, max_distance: float, force_amount: float) -> float:
	var normalized_distance = distance / max_distance
	
	var primary = max(0.0, 1.0 - normalized_distance)
	var secondary = exp(-normalized_distance * 2.5) * 0.6
	var tertiary = pow(max(0.0, 1.0 - normalized_distance * normalized_distance), 3.0) * 0.4
	var quaternary = sin(normalized_distance * PI) * 0.2 * (1.0 - normalized_distance)
	
	return primary + secondary + tertiary + quaternary

func _physics_process(delta):
	if frame_nodes.size() == 0:
		return
	
	update_impact_waves(delta)
	update_advanced_physics(delta)
	update_advanced_visual_mesh(delta)
	apply_advanced_recovery(delta)
	cleanup_old_data()

func update_impact_waves(delta):
	var waves_to_remove = []
	
	for i in range(impact_waves.size()):
		var wave = impact_waves[i]
		wave["radius"] += wave["speed"] * delta
		
		for j in range(frame_nodes.size()):
			var node = frame_nodes[j]
			var distance = node["position"].distance_to(wave["origin"])
			
			if abs(distance - wave["radius"]) < 3.0:
				var wave_influence = exp(-pow(distance - wave["radius"], 2) / 6.0)
				var wave_force = wave["normal"] * wave["strength"] * wave_influence * 8.0
				node["velocity"] += wave_force / node["mass"]
		
		if wave["radius"] > wave["max_radius"]:
			waves_to_remove.append(i)
	
	for i in range(waves_to_remove.size() - 1, -1, -1):
		impact_waves.remove_at(waves_to_remove[i])

func update_advanced_physics(delta):
	var damping = 0.987
	
	for i in range(frame_nodes.size()):
		var node = frame_nodes[i]
		
		if not node["fixed"]:
			node["position"] += node["velocity"] * delta
			node["velocity"] *= damping
	
	for connection in frame_connections:
		if not connection["broken"]:
			apply_advanced_spring_force(connection, delta)
	
	apply_surface_tension(delta)
	
	for i in range(frame_nodes.size()):
		var node = frame_nodes[i]
		if not node["fixed"]:
			var restore_force = (node["original_position"] - node["position"]) * 0.2
			node["velocity"] += restore_force * delta

func apply_advanced_spring_force(connection: Dictionary, delta):
	var node_a = frame_nodes[connection["node_a"]]
	var node_b = frame_nodes[connection["node_b"]]
	
	var current_length = node_a["position"].distance_to(node_b["position"])
	
	if current_length > 0.001:
		var length_diff = current_length - connection["rest_length"]
		
		if abs(length_diff) > connection["rest_length"] * 0.6:
			connection["broken"] = true
			return
		
		var force_magnitude = length_diff * connection["stiffness"]
		force_magnitude *= (1.0 + pow(abs(length_diff) / connection["rest_length"], 1.5))
		
		var force_direction = (node_b["position"] - node_a["position"]).normalized()
		var force = force_direction * force_magnitude
		
		var relative_velocity = node_b["velocity"] - node_a["velocity"]
		var damping_force = relative_velocity.dot(force_direction) * connection["damping"] * 0.15
		force -= force_direction * damping_force
		
		if not node_a["fixed"]:
			node_a["velocity"] += force * delta / node_a["mass"]
		if not node_b["fixed"]:
			node_b["velocity"] -= force * delta / node_b["mass"]
		
		connection["stress"] = abs(length_diff) / connection["rest_length"]

func apply_surface_tension(delta):
	for i in range(frame_nodes.size()):
		var node = frame_nodes[i]
		if not node["fixed"] and node["connections"].size() > 0:
			var center = Vector3.ZERO
			var connected_nodes = 0
			
			for conn_idx in node["connections"]:
				var connected_node = frame_nodes[conn_idx]
				center += connected_node["position"]
				connected_nodes += 1
			
			if connected_nodes > 0:
				center /= connected_nodes
				var tension_force = (center - node["position"]) * surface_tension * 0.15
				node["velocity"] += tension_force * delta

func update_advanced_visual_mesh(_delta):
	if frame_nodes.size() == 0:
		return
	
	if mesh_cache == null:
		mesh_cache = ArrayMesh.new()
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = generate_advanced_vertices()
	var normals = calculate_advanced_normals(vertices)
	var indices = generate_advanced_indices(vertices.size())
	var uvs = generate_advanced_uvs(vertices.size())
	var colors = generate_deformation_colors_for_vertices(vertices.size())
	
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

func generate_advanced_vertices() -> PackedVector3Array:
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
					
					if node["deformation_level"] > 0.05:
						var detail_offset = Vector3(
							sin(node["position"].x * 15.0 + Time.get_time_dict_from_system()["second"]) * node["deformation_level"] * 0.03,
							sin(node["position"].y * 15.0 + Time.get_time_dict_from_system()["second"]) * node["deformation_level"] * 0.03,
							sin(node["position"].z * 15.0 + Time.get_time_dict_from_system()["second"]) * node["deformation_level"] * 0.03
						)
						vertex += detail_offset * visual_detail_multiplier
					
					if node["crease_factor"] > 0.05:
						var crease_offset = node["surface_normal"] * node["crease_factor"] * 0.15
						vertex -= crease_offset
					
					if node["stress_level"] > 0.3:
						var stress_offset = node["surface_normal"] * node["stress_level"] * 0.08 * sin(Time.get_time_dict_from_system()["second"] * 5.0)
						vertex += stress_offset
					
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

func calculate_advanced_normals(vertices: PackedVector3Array) -> PackedVector3Array:
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	
	var resolution = frame_resolution
	var face_vertex_count = resolution * resolution
	
	for face in range(6):
		var face_offset = face * face_vertex_count
		for x in range(resolution):
			for y in range(resolution):
				var vertex_idx = face_offset + x * resolution + y
				if vertex_idx < vertices.size():
					var base_normal = get_face_normal(face)
					
					var node_idx = get_face_node_index(x, y, get_face_fixed_coord(face), get_face_axis(face))
					if node_idx < frame_nodes.size():
						var node = frame_nodes[node_idx]
						var deformation_factor = node["deformation_level"]
						
						var deformed_normal = base_normal
						if deformation_factor > 0.05:
							var noise_offset = Vector3(
								randf_range(-0.15, 0.15),
								randf_range(-0.15, 0.15),
								randf_range(-0.15, 0.15)
							) * deformation_factor
							deformed_normal = (base_normal + noise_offset).normalized()
						
						if node["crease_factor"] > 0.1:
							deformed_normal = deformed_normal.lerp(node["surface_normal"], node["crease_factor"])
						
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

func generate_advanced_indices(vertex_count: int) -> PackedInt32Array:
	var indices = PackedInt32Array()
	var resolution = frame_resolution
	var face_vertex_count = resolution * resolution
	
	for face in range(6):
		var face_offset = face * face_vertex_count
		for x in range(resolution - 1):
			for z in range(resolution - 1):
				var i = face_offset + x * resolution + z
				if i + resolution + 1 < vertex_count:
					indices.append(i)
					indices.append(i + 1)
					indices.append(i + resolution)
					indices.append(i + 1)
					indices.append(i + resolution + 1)
					indices.append(i + resolution)
	
	return indices

func generate_advanced_uvs(vertex_count: int) -> PackedVector2Array:
	var uvs = PackedVector2Array()
	uvs.resize(vertex_count)
	
	var resolution = frame_resolution
	var face_vertex_count = resolution * resolution
	
	for face in range(6):
		var face_offset = face * face_vertex_count
		for x in range(resolution):
			for z in range(resolution):
				var i = face_offset + x * resolution + z
				if i < vertex_count:
					var base_uv = Vector2(x / float(resolution - 1), z / float(resolution - 1))
					
					var node_idx = get_face_node_index(x, z, get_face_fixed_coord(face), get_face_axis(face))
					if node_idx < frame_nodes.size():
						var deformation = frame_nodes[node_idx]["deformation_level"]
						if deformation > 0.05:
							var uv_distortion = Vector2(
								sin(deformation * PI * 3.0) * 0.15,
								cos(deformation * PI * 3.0) * 0.15
							) * deformation
							base_uv += uv_distortion
					
					uvs[i] = base_uv
	
	return uvs

func generate_deformation_colors_for_vertices(vertex_count: int) -> PackedColorArray:
	var colors = PackedColorArray()
	colors.resize(vertex_count)
	
	var resolution = frame_resolution
	var face_vertex_count = resolution * resolution
	
	for face in range(6):
		var face_offset = face * face_vertex_count
		for x in range(resolution):
			for y in range(resolution):
				var vertex_idx = face_offset + x * resolution + y
				if vertex_idx < vertex_count:
					var node_idx = get_face_node_index(x, y, get_face_fixed_coord(face), get_face_axis(face))
					
					if node_idx < frame_nodes.size():
						var node = frame_nodes[node_idx]
						var base_color = Color(0.2, 0.6, 1.0, 1.0)
						
						var deformation = node["deformation_level"]
						var stress = node["stress_level"]
						
						if deformation > 0.05:
							base_color.r = min(1.0, base_color.r + deformation * 0.9)
							base_color.g = max(0.0, base_color.g - deformation * 0.5)
							base_color.b = max(0.0, base_color.b - deformation * 0.7)
						
						if stress > 0.4:
							base_color *= (1.0 - stress * 0.4)
						
						if node["crease_factor"] > 0.05:
							base_color.r = min(1.0, base_color.r + node["crease_factor"] * 0.3)
							base_color.g = min(1.0, base_color.g + node["crease_factor"] * 0.15)
							base_color.b = max(0.0, base_color.b - node["crease_factor"] * 0.1)
						
						if node["impact_history"].size() > 0:
							var recent_impact = false
							var current_time = Time.get_unix_time_from_system()
							for impact in node["impact_history"]:
								if current_time - impact["time"] < 1.0:
									recent_impact = true
									break
							
							if recent_impact:
								base_color.r = min(1.0, base_color.r + 0.3)
								base_color.g = min(1.0, base_color.g + 0.2)
						
						colors[vertex_idx] = base_color
					else:
						colors[vertex_idx] = Color(0.2, 0.6, 1.0, 1.0)
	
	return colors

func get_face_fixed_coord(face_index: int) -> int:
	match face_index:
		0: return frame_resolution - 1  # UP
		1: return 0                     # DOWN
		2: return frame_resolution - 1  # FORWARD
		3: return 0                     # BACK
		4: return frame_resolution - 1  # RIGHT
		5: return 0                     # LEFT
		_: return 0

func get_face_axis(face_index: int) -> String:
	match face_index:
		0: return "y"  # UP
		1: return "y"  # DOWN
		2: return "z"  # FORWARD
		3: return "z"  # BACK
		4: return "x"  # RIGHT
		5: return "x"  # LEFT
		_: return "y"

func generate_deformation_colors() -> PackedColorArray:
	var colors = PackedColorArray()
	
	for node in frame_nodes:
		var base_color = Color(0.2, 0.6, 1.0, 1.0)
		
		var deformation = node["deformation_level"]
		var stress = node["stress_level"]
		
		if deformation > 0.05:
			base_color.r = min(1.0, base_color.r + deformation * 0.9)
			base_color.g = max(0.0, base_color.g - deformation * 0.5)
			base_color.b = max(0.0, base_color.b - deformation * 0.7)
		
		if stress > 0.4:
			base_color *= (1.0 - stress * 0.4)
		
		if node["crease_factor"] > 0.05:
			base_color.r = min(1.0, base_color.r + node["crease_factor"] * 0.3)
			base_color.g = min(1.0, base_color.g + node["crease_factor"] * 0.15)
			base_color.b = max(0.0, base_color.b - node["crease_factor"] * 0.1)
		
		if node["impact_history"].size() > 0:
			var recent_impact = false
			var current_time = Time.get_unix_time_from_system()
			for impact in node["impact_history"]:
				if current_time - impact["time"] < 1.0:
					recent_impact = true
					break
			
			if recent_impact:
				base_color.r = min(1.0, base_color.r + 0.3)
				base_color.g = min(1.0, base_color.g + 0.2)
		
		colors.append(base_color)
	
	return colors

func apply_advanced_recovery(delta):
	for i in range(frame_nodes.size()):
		var node = frame_nodes[i]
		if not node["fixed"]:
			var restore_force = (node["original_position"] - node["position"]) * recovery_speed
			node["velocity"] += restore_force
			
			node["deformation_level"] = max(0.0, node["deformation_level"] - recovery_speed * delta * 0.3)
			node["stress_level"] = max(0.0, node["stress_level"] - recovery_speed * delta * 0.5)
			node["crease_factor"] = max(0.0, node["crease_factor"] - recovery_speed * delta * 0.2)
			
			for connection in frame_connections:
				if connection["node_a"] == i or connection["node_b"] == i:
					connection["stress"] = max(0.0, connection["stress"] - recovery_speed * delta * 0.3)

func cleanup_old_data():
	var current_time = Time.get_unix_time_from_system()
	
	var forces_to_remove = []
	for i in range(collision_forces.size()):
		if current_time - collision_forces[i]["time"] > 4.0:
			forces_to_remove.append(i)
	
	for i in range(forces_to_remove.size() - 1, -1, -1):
		collision_forces.remove_at(forces_to_remove[i])
	
	for i in range(frame_nodes.size()):
		var node = frame_nodes[i]
		var impacts_to_remove = []
		for j in range(node["impact_history"].size()):
			if current_time - node["impact_history"][j]["time"] > 5.0:
				impacts_to_remove.append(j)
		
		for j in range(impacts_to_remove.size() - 1, -1, -1):
			node["impact_history"].remove_at(impacts_to_remove[j])

func get_total_deformation() -> float:
	var total_deform = 0.0
	
	for node in frame_nodes:
		var deform = node["position"].distance_to(node["original_position"])
		total_deform += deform
	
	return min(total_deform / frame_nodes.size(), 1.0)

func apply_damage_deformation(damage_level: float):
	var num_impacts = int(damage_level * 20) + 1
	var size = original_mesh.size
	
	for i in range(num_impacts):
		var random_pos = Vector3(
			randf_range(-size.x * 0.6, size.x * 0.6),
			randf_range(-size.y * 0.6, size.y * 0.6),
			randf_range(-size.z * 0.6, size.z * 0.6)
		)
		
		var random_force = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			randf_range(-1, 1)
		).normalized() * damage_level * 1.0
		
		apply_advanced_force_to_nodes(random_pos, damage_level * 0.6, random_force)
