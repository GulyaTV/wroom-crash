extends MeshInstance3D

## Простая система деформации для BoxMesh

@export var max_deformation: float = 0.3
@export var deformation_recovery_speed: float = 0.05
@export var collision_sensitivity: float = 0.01

var original_mesh: BoxMesh
var deformation_points: Dictionary = {}
var car_body: RigidBody3D

func _ready():
	# Находим родительский RigidBody3D
	car_body = get_parent() as RigidBody3D
	
	# Получаем оригинальный BoxMesh
	if mesh is BoxMesh:
		original_mesh = mesh.duplicate()
		print("Simple deformation initialized for BoxMesh")
	else:
		print("Warning: Not a BoxMesh, deformation may not work properly")

func apply_collision_deformation(collision_point: Vector3, collision_force: float, collision_normal: Vector3):
	if not car_body or not original_mesh:
		return
	
	var deformation_amount = min(collision_force * collision_sensitivity, max_deformation)
	
	# Сохраняем точку деформации
	var local_collision_point = to_local(collision_point)
	deformation_points[local_collision_point] = {
		"force": deformation_amount,
		"normal": collision_normal,
		"time": Time.get_time_dict_from_system()
	}
	
	# Применяем деформацию к мешу
	apply_deformation_to_mesh()
	
	print("Applied deformation: ", deformation_amount, " at ", local_collision_point)

func apply_deformation_to_mesh():
	if not original_mesh:
		return
	
	# Создаем новый BoxMesh с деформированными размерами
	var new_mesh = BoxMesh.new()
	
	# Получаем оригинальные размеры
	var original_size = original_mesh.size
	var deformed_size = original_size
	
	# Применяем суммарную деформацию
	var total_deformation = Vector3.ZERO
	for point in deformation_points:
		var deform_data = deformation_points[point]
		var influence = deform_data["force"]
		var direction = deform_data["normal"]
		
		# Деформация зависит от направления столкновения
		var deform_vector = direction * influence * 0.5
		total_deformation += deform_vector
	
	# Применяем деформацию к размерам
	deformed_size = original_size + total_deformation
	
	# Ограничиваем минимальный размер
	deformed_size.x = max(deformed_size.x, 0.5)
	deformed_size.y = max(deformed_size.y, 0.3)
	deformed_size.z = max(deformed_size.z, 0.5)
	
	new_mesh.size = deformed_size
	new_mesh.material = original_mesh.material
	
	# Применяем новый меш
	mesh = new_mesh
	
	# Деформируем также через scale для дополнительного эффекта
	var scale_deformation = Vector3.ONE
	scale_deformation.x *= (1.0 - total_deformation.x * 0.1)
	scale_deformation.y *= (1.0 - total_deformation.y * 0.1)
	scale_deformation.z *= (1.0 - total_deformation.z * 0.1)
	
	scale = scale_deformation

func recover_deformation(delta: float):
	if deformation_points.size() == 0:
		return
	
	var recovered = false
	var points_to_remove = []
	
	# Восстанавливаем каждую точку деформации
	for point in deformation_points:
		var deform_data = deformation_points[point]
		deform_data["force"] = max(0.0, deform_data["force"] - deformation_recovery_speed * delta)
		
		if deform_data["force"] <= 0.0:
			points_to_remove.append(point)
		else:
			recovered = true
	
	# Удаляем восстановленные точки
	for point in points_to_remove:
		deformation_points.erase(point)
	
	# Применяем обновленную деформацию
	if recovered:
		apply_deformation_to_mesh()
	else:
		# Полное восстановление
		if original_mesh:
			mesh = original_mesh.duplicate()
			scale = Vector3.ONE

func apply_damage_deformation(damage_level: float):
	if not original_mesh:
		return
	
	# Применяем общую деформацию на основе уровня повреждений
	var random_deformation = Vector3(
		randf_range(-1, 1) * damage_level * 0.3,
		randf_range(-1, 1) * damage_level * 0.2,  # Меньше деформация по Y
		randf_range(-1, 1) * damage_level * 0.3
	)
	
	# Создаем новый деформированный меш
	var new_mesh = BoxMesh.new()
	var original_size = original_mesh.size
	var deformed_size = original_size + random_deformation
	
	# Ограничиваем минимальный размер
	deformed_size.x = max(deformed_size.x, 0.5)
	deformed_size.y = max(deformed_size.y, 0.3)
	deformed_size.z = max(deformed_size.z, 0.5)
	
	new_mesh.size = deformed_size
	new_mesh.material = original_mesh.material
	
	mesh = new_mesh
	
	# Дополнительная деформация через scale
	var scale_deformation = Vector3.ONE
	scale_deformation.x *= (1.0 - damage_level * 0.1)
	scale_deformation.y *= (1.0 - damage_level * 0.05)
	scale_deformation.z *= (1.0 - damage_level * 0.1)
	
	scale = scale_deformation

func get_deformation_at_point(point: Vector3) -> float:
	if deformation_points.size() == 0:
		return 0.0
	
	var local_point = to_local(point)
	var total_deformation = 0.0
	
	for deform_point in deformation_points:
		var distance = local_point.distance_to(deform_point)
		if distance < 2.0:  # Радиус проверки
			var influence = max(0.0, 1.0 - distance / 2.0)
			total_deformation += deformation_points[deform_point]["force"] * influence
	
	return min(total_deformation, 1.0)
