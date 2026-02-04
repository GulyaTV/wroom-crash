extends MeshInstance3D

## Система деформации как в BeamNG Drive

@export var max_deformation: float = 0.5
@export var deformation_recovery_speed: float = 0.1
@export var collision_sensitivity: float = 0.001

var original_vertices: PackedVector3Array
var deformed_vertices: PackedVector3Array
var mesh_deformation: Array[float] = []
var car_body: RigidBody3D

func _ready():
	# Находим родительский RigidBody3D
	car_body = get_parent() as RigidBody3D
	
	# Получаем оригинальные вершины меша
	if mesh and mesh.get_faces().size() > 0:
		original_vertices = PackedVector3Array()
		deformed_vertices = PackedVector3Array()
		mesh_deformation.resize(0)
		
		# Собираем все вершины из меша
		var surface_tool = SurfaceTool.new()
		surface_tool.create_from(mesh, 0)
		var data = surface_tool.commit()
		
		# Получаем вершины из ArrayMesh
		if data.get_array().size() > 0:
			var arrays = data.get_array()
			if arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				original_vertices = arrays[Mesh.ARRAY_VERTEX]
				deformed_vertices = original_vertices.duplicate()
				mesh_deformation.resize(original_vertices.size())
				mesh_deformation.fill(0.0)
				print("BeamNG deformation initialized with ", original_vertices.size(), " vertices")
		else:
			# Запасной вариант - создаем простую сетку вершин
			var simple_vertices = PackedVector3Array()
			var size = 2.0
			var resolution = 4
			for x in range(resolution):
				for z in range(resolution):
					var vx = (x / float(resolution - 1) - 0.5) * size
					var vz = (z / float(resolution - 1) - 0.5) * size
					simple_vertices.append(Vector3(vx, 0.6, vz))
			original_vertices = simple_vertices
			deformed_vertices = simple_vertices.duplicate()
			mesh_deformation.resize(simple_vertices.size())
			mesh_deformation.fill(0.0)
			print("BeamNG deformation created simple mesh with ", original_vertices.size(), " vertices")

func apply_collision_deformation(collision_point: Vector3, collision_force: float, collision_normal: Vector3):
	if not car_body or original_vertices.size() == 0:
		return
	
	var deformation_amount = min(collision_force * collision_sensitivity, max_deformation)
	
	# Применяем деформацию к вершинам рядом с точкой столкновения
	for i in range(original_vertices.size()):
		var vertex = original_vertices[i]
		var world_vertex = car_body.to_global(vertex)
		var distance = world_vertex.distance_to(collision_point)
		
		# Чем ближе к точке столкновения, тем сильнее деформация
		var influence = max(0.0, 1.0 - distance / 5.0)  # Радиус влияния 5 единиц
		var deformation = influence * deformation_amount
		
		# Деформация в направлении столкновения
		var deformation_vector = collision_normal * deformation
		var new_vertex = vertex + deformation_vector
		
		deformed_vertices[i] = new_vertex
		mesh_deformation[i] = deformation
	
	# Применяем деформацию к мешу
	update_mesh()

func update_mesh():
	if not mesh or original_vertices.size() == 0:
		return
	
	# Создаем новый ArrayMesh с деформированными вершинами
	var new_mesh = ArrayMesh.new()
	var arrays = []
	
	# Вершины
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = deformed_vertices
	
	# Нормали (простой расчет)
	var normals = PackedVector3Array()
	normals.resize(original_vertices.size())
	for i in range(original_vertices.size()):
		normals[i] = Vector3.UP  # Простая нормаль вверх
	arrays[Mesh.ARRAY_NORMAL] = normals
	
	# Индексы (треугольники)
	var indices = PackedInt32Array()
	for i in range(0, original_vertices.size() / 3.0):
		indices.append(i * 3)
		indices.append(i * 3 + 1)
		indices.append(i * 3 + 2)
	arrays[Mesh.ARRAY_INDEX] = indices
	
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = new_mesh

func recover_deformation(delta: float):
	if mesh_deformation.size() == 0:
		return
	
	var recovered = false
	for i in range(mesh_deformation.size()):
		if mesh_deformation[i] > 0.0:
			mesh_deformation[i] = max(0.0, mesh_deformation[i] - deformation_recovery_speed * delta)
			
			# Восстанавливаем вершину
			var recovery_factor = 1.0 - mesh_deformation[i]
			deformed_vertices[i] = original_vertices[i].lerp(original_vertices[i], recovery_factor)
			recovered = true
	
	if recovered:
		update_mesh()

func apply_damage_deformation(damage_level: float):
	if original_vertices.size() == 0:
		return
	
	# Применяем деформацию на основе уровня повреждений
	for i in range(original_vertices.size()):
		var vertex = original_vertices[i]
		var random_deformation = Vector3(
			randf_range(-1, 1) * damage_level,
			randf_range(-1, 1) * damage_level * 0.3,  # Меньше деформация по Y
			randf_range(-1, 1) * damage_level
		)
		
		deformed_vertices[i] = vertex + random_deformation
		mesh_deformation[i] = damage_level
	
	update_mesh()

func get_deformation_at_point(point: Vector3) -> float:
	if not car_body or original_vertices.size() == 0:
		return 0.0
	
	var world_point = car_body.to_global(point)
	var total_deformation = 0.0
	var count = 0
	
	for i in range(original_vertices.size()):
		var vertex = original_vertices[i]
		var world_vertex = car_body.to_global(vertex)
		var distance = world_point.distance_to(world_vertex)
		
		if distance < 2.0:  # Радиус проверки
			total_deformation += mesh_deformation[i]
			count += 1
	
	if count > 0:
		return total_deformation / count
	else:
		return 0.0
