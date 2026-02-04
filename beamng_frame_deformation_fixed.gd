extends MeshInstance3D

## BeamNG Drive стиль деформации с каркасом из вершин
## Визуальная и физическая деформация через сетку узлов

@export var frame_resolution: int = 8  # Разрешение каркаса
@export var deformation_strength: float = 0.3
@export var recovery_speed: float = 0.01
@export var collision_sensitivity: float = 0.005
@export var frame_stiffness: float = 0.8  # Жесткость каркаса

# Структуры для узлов и связей
var frame_nodes: Array[Dictionary] = []
var frame_connections: Array[Dictionary] = []
var original_mesh: BoxMesh
var car_body: RigidBody3D
var collision_forces: Array[Dictionary] = []

func _ready():
	# Находим родительский RigidBody3D
	car_body = get_parent() as RigidBody3D
	
	# Получаем оригинальный BoxMesh
	if mesh is BoxMesh:
		original_mesh = mesh.duplicate()
		create_frame_structure()
		print("BeamNG frame deformation initialized with ", frame_nodes.size(), " nodes")
	else:
		print("Warning: Not a BoxMesh, creating fallback frame")
		create_fallback_frame()

func create_frame_structure():
	frame_nodes.clear()
	frame_connections.clear()
	
	var size = original_mesh.size
	
	# Создаем узлы каркаса в 3D сетке
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
					"connections": []
				}
				node["original_position"] = node["position"]
				
				# Крайние узлы более жесткие
				if x == 0 or x == frame_resolution - 1 or y == 0 or y == frame_resolution - 1 or z == 0 or z == frame_resolution - 1:
					node["fixed"] = false  # Не фиксируем, но делаем более жесткими
				
				frame_nodes.append(node)
	
	# Создаем связи между узлами
	create_frame_connections()
	
	print("Created frame structure: ", frame_nodes.size(), " nodes, ", frame_connections.size(), " connections")

func create_frame_connections():
	var size = original_mesh.size
	
	# Связи между соседними узлами
	for x in range(frame_resolution):
		for y in range(frame_resolution):
			for z in range(frame_resolution):
				var current_idx = x * frame_resolution * frame_resolution + y * frame_resolution + z
				
				# Связи по X
				if x < frame_resolution - 1:
					var next_x_idx = (x + 1) * frame_resolution * frame_resolution + y * frame_resolution + z
					create_connection(current_idx, next_x_idx)
				
				# Связи по Y
				if y < frame_resolution - 1:
					var next_y_idx = x * frame_resolution * frame_resolution + (y + 1) * frame_resolution + z
					create_connection(current_idx, next_y_idx)
				
				# Связи по Z
				if z < frame_resolution - 1:
					var next_z_idx = x * frame_resolution * frame_resolution + y * frame_resolution + (z + 1)
					create_connection(current_idx, next_z_idx)
				
				# Диагональные связи для жесткости
				if x < frame_resolution - 1 and y < frame_resolution - 1:
					var diag_xy_idx = (x + 1) * frame_resolution * frame_resolution + (y + 1) * frame_resolution + z
					create_connection(current_idx, diag_xy_idx)
				
				if x < frame_resolution - 1 and z < frame_resolution - 1:
					var diag_xz_idx = (x + 1) * frame_resolution * frame_resolution + y * frame_resolution + (z + 1)
					create_connection(current_idx, diag_xz_idx)
				
				if y < frame_resolution - 1 and z < frame_resolution - 1:
					var diag_yz_idx = x * frame_resolution * frame_resolution + (y + 1) * frame_resolution + (z + 1)
					create_connection(current_idx, diag_yz_idx)

func create_connection(node_a_idx: int, node_b_idx: int):
	var connection = {
		"node_a": node_a_idx,
		"node_b": node_b_idx,
		"rest_length": 0.0,
		"stiffness": frame_stiffness
	}
	connection["rest_length"] = frame_nodes[node_a_idx]["position"].distance_to(frame_nodes[node_b_idx]["position"])
	frame_connections.append(connection)
	
	# Добавляем связи в узлы
	frame_nodes[node_a_idx]["connections"].append(node_b_idx)
	frame_nodes[node_b_idx]["connections"].append(node_a_idx)

func create_fallback_frame():
	# Запасной вариант с низким разрешением
	frame_resolution = 4
	create_frame_structure()

func apply_collision_deformation(collision_point: Vector3, collision_force: float, collision_normal: Vector3):
	if not car_body or frame_nodes.size() == 0:
		return
	
	var local_collision_point = to_local(collision_point)
	var deformation_amount = collision_force * collision_sensitivity
	
	# Добавляем силу столкновения
	collision_forces.append({
		"position": local_collision_point,
		"force": deformation_amount,
		"normal": collision_normal,
		"time": Time.get_unix_time_from_system()
	})
	
	# Применяем силу к ближайшим узлам
	apply_force_to_nodes(local_collision_point, deformation_amount, collision_normal)
	
	print("BeamNG frame collision: force=", deformation_amount, " at ", local_collision_point)

func apply_force_to_nodes(force_position: Vector3, force_amount: float, force_direction: Vector3):
	var influence_radius = force_amount * 15.0  # Радиус влияния силы
	
	for i in range(frame_nodes.size()):
		var node = frame_nodes[i]
		var distance = node["position"].distance_to(force_position)
		
		if distance < influence_radius:
			var influence = 1.0 - (distance / influence_radius)
			influence = influence * influence  # Квадратичная функция
			
			# Применяем силу к узлу
			var force = force_direction * force_amount * influence * 10.0
			node["velocity"] += force / node["mass"]
			
			# Добавляем случайный компонент для реалистичности
			var random_force = Vector3(
				randf_range(-1, 1),
				randf_range(-1, 1),
				randf_range(-1, 1)
			).normalized() * force_amount * influence * 2.0
			
			node["velocity"] += random_force

func _physics_process(delta):
	if frame_nodes.size() == 0:
		return
	
	# Обновляем физику каркаса
	update_frame_physics(delta)
	
	# Применяем деформацию к визуальному мешу
	update_visual_mesh(delta)
	
	# Восстановление
	apply_recovery(delta)
	
	# Очищаем старые силы столкновения
	cleanup_collision_forces()

func update_frame_physics(delta):
	var damping = 0.98  # Затухание
	
	# Обновляем позиции узлов на основе сил
	for i in range(frame_nodes.size()):
		var node = frame_nodes[i]
		
		if not node["fixed"]:
			# Применяем скорость
			node["position"] += node["velocity"] * delta
			
			# Затухание скорости
			node["velocity"] *= damping
	
	# Применяем силы связей (пружины)
	for connection in frame_connections:
		apply_spring_force(connection, delta)
	
	# Применяем силы восстановления к исходной позиции
	for i in range(frame_nodes.size()):
		var node = frame_nodes[i]
		if not node["fixed"]:
			var restore_force = (node["original_position"] - node["position"]) * 0.1
			node["velocity"] += restore_force * delta

func apply_spring_force(connection: Dictionary, delta):
	var node_a = frame_nodes[connection["node_a"]]
	var node_b = frame_nodes[connection["node_b"]]
	
	# Вычисляем текущую длину связи
	var current_length = node_a["position"].distance_to(node_b["position"])
	
	if current_length > 0.001:
		# Сила пружины
		var force_magnitude = (current_length - connection["rest_length"]) * connection["stiffness"]
		var force_direction = (node_b["position"] - node_a["position"]).normalized()
		var force = force_direction * force_magnitude
		
		# Применяем силу к обоим узлам
		if not node_a["fixed"]:
			node_a["velocity"] += force * delta / node_a["mass"]
		if not node_b["fixed"]:
			node_b["velocity"] -= force * delta / node_b["mass"]

func update_visual_mesh(delta):
	if frame_nodes.size() == 0:
		return
	
	# Создаем ArrayMesh из деформированных узлов
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Генерируем вершины из узлов каркаса
	var vertices = generate_vertices_from_frame()
	var normals = calculate_frame_normals(vertices)
	var indices = generate_frame_indices(vertices.size())
	var uvs = generate_frame_uvs(vertices.size())
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	
	# Создаем поверхность
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Применяем материал
	if original_mesh.get_surface_count() > 0:
		var original_material = original_mesh.surface_get_material(0)
		if original_material:
			array_mesh.surface_set_material(0, original_material)
	
	mesh = array_mesh

func generate_vertices_from_frame() -> PackedVector3Array:
	var vertices = PackedVector3Array()
	
	# Генерируем вершины для граней на основе узлов каркаса
	var resolution = frame_resolution
	
	# Верхняя грань (Y = max)
	for x in range(resolution):
		for z in range(resolution):
			var node_idx = x * resolution * resolution + (resolution - 1) * resolution + z
			if node_idx < frame_nodes.size():
				vertices.append(frame_nodes[node_idx]["position"])
	
	# Нижняя грань (Y = min)
	for x in range(resolution):
		for z in range(resolution):
			var node_idx = x * resolution * resolution + 0 * resolution + z
			if node_idx < frame_nodes.size():
				vertices.append(frame_nodes[node_idx]["position"])
	
	# Передняя грань (Z = max)
	for x in range(resolution):
		for y in range(resolution):
			var node_idx = x * resolution * resolution + y * resolution + (resolution - 1)
			if node_idx < frame_nodes.size():
				vertices.append(frame_nodes[node_idx]["position"])
	
	# Задняя грань (Z = min)
	for x in range(resolution):
		for y in range(resolution):
			var node_idx = x * resolution * resolution + y * resolution + 0
			if node_idx < frame_nodes.size():
				vertices.append(frame_nodes[node_idx]["position"])
	
	# Левая грань (X = min)
	for z in range(resolution):
		for y in range(resolution):
			var node_idx = 0 * resolution * resolution + y * resolution + z
			if node_idx < frame_nodes.size():
				vertices.append(frame_nodes[node_idx]["position"])
	
	# Правая грань (X = max)
	for z in range(resolution):
		for y in range(resolution):
			var node_idx = (resolution - 1) * resolution * resolution + y * resolution + z
			if node_idx < frame_nodes.size():
				vertices.append(frame_nodes[node_idx]["position"])
	
	return vertices

func calculate_frame_normals(vertices: PackedVector3Array) -> PackedVector3Array:
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	
	# Простые нормали для каждой грани
	var resolution = frame_resolution
	var face_vertex_count = resolution * resolution
	
	# Верхняя грань - нормаль вверх
	for i in range(face_vertex_count):
		normals[i] = Vector3(0, 1, 0)
	
	# Нижняя грань - нормаль вниз
	for i in range(face_vertex_count, face_vertex_count * 2):
		normals[i] = Vector3(0, -1, 0)
	
	# Передняя грань - нормаль вперед
	for i in range(face_vertex_count * 2, face_vertex_count * 3):
		normals[i] = Vector3(0, 0, 1)
	
	# Задняя грань - нормаль назад
	for i in range(face_vertex_count * 3, face_vertex_count * 4):
		normals[i] = Vector3(0, 0, -1)
	
	# Левая грань - нормаль влево
	for i in range(face_vertex_count * 4, face_vertex_count * 5):
		normals[i] = Vector3(-1, 0, 0)
	
	# Правая грань - нормаль вправо
	for i in range(face_vertex_count * 5, face_vertex_count * 6):
		normals[i] = Vector3(1, 0, 0)
	
	return normals

func generate_frame_indices(vertex_count: int) -> PackedInt32Array:
	var indices = PackedInt32Array()
	var resolution = frame_resolution
	var face_vertex_count = resolution * resolution
	
	# Генерируем индексы для каждой грани
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

func generate_frame_uvs(vertex_count: int) -> PackedVector2Array:
	var uvs = PackedVector2Array()
	uvs.resize(vertex_count)
	
	var resolution = frame_resolution
	var face_vertex_count = resolution * resolution
	
	# Генерируем UV для каждой грани
	for face in range(6):
		var face_offset = face * face_vertex_count
		for x in range(resolution):
			for z in range(resolution):
				var i = x * resolution + z + face_offset
				uvs[i] = Vector2(x / float(resolution - 1), z / float(resolution - 1))
	
	return uvs

func apply_recovery(delta):
	# Медленное восстановление к исходной форме
	for i in range(frame_nodes.size()):
		var node = frame_nodes[i]
		if not node["fixed"]:
			var restore_force = (node["original_position"] - node["position"]) * recovery_speed
			node["velocity"] += restore_force

func cleanup_collision_forces():
	var current_time = Time.get_unix_time_from_system()
	var forces_to_remove = []
	
	for i in range(collision_forces.size()):
		var force = collision_forces[i]
		if current_time - force["time"] > 2.0:  # Удаляем силы старше 2 секунд
			forces_to_remove.append(i)
	
	# Удаляем старые силы в обратном порядке
	for i in range(forces_to_remove.size() - 1, -1, -1):
		collision_forces.remove_at(forces_to_remove[i])

func get_total_deformation() -> float:
	var total_deform = 0.0
	for node in frame_nodes:
		total_deform += node["position"].distance_to(node["original_position"])
	return min(total_deform / frame_nodes.size(), 1.0)

func apply_damage_deformation(damage_level: float):
	# Применяем случайные повреждения к каркасу
	var num_impacts = int(damage_level * 10) + 1
	var size = original_mesh.size
	
	for i in range(num_impacts):
		var random_pos = Vector3(
			randf_range(-size.x * 0.4, size.x * 0.4),
			randf_range(-size.y * 0.4, size.y * 0.4),
			randf_range(-size.z * 0.4, size.z * 0.4)
		)
		
		var random_force = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			randf_range(-1, 1)
		).normalized() * damage_level * 0.5
		
		apply_force_to_nodes(random_pos, damage_level * 0.3, random_force)
