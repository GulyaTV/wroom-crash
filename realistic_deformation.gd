extends MeshInstance3D

## Реалистичная система деформации корпуса как в BeamNG Drive

@export var max_deformation: float = 0.4
@export var deformation_recovery_speed: float = 0.02
@export var collision_sensitivity: float = 0.008
@export var dent_depth: float = 0.3
@export var metal_tearing_threshold: float = 0.7

var original_mesh: BoxMesh
var deformation_grid: Dictionary = {}
var damage_zones: Array[Dictionary] = []
var car_body: RigidBody3D

func _ready():
	# Находим родительский RigidBody3D
	car_body = get_parent() as RigidBody3D
	
	# Получаем оригинальный BoxMesh
	if mesh is BoxMesh:
		original_mesh = mesh.duplicate()
		print("Realistic deformation initialized for BoxMesh")
	else:
		print("Warning: Not a BoxMesh, deformation may not work properly")

func apply_collision_deformation(collision_point: Vector3, collision_force: float, collision_normal: Vector3):
	if not car_body:
		return
	
	var deformation_amount = min(collision_force * collision_sensitivity, max_deformation)
	var local_collision_point = to_local(collision_point)
	
	# Создаем зону повреждения
	var damage_zone = {
		"position": local_collision_point,
		"force": deformation_amount,
		"normal": collision_normal,
		"radius": min(deformation_amount * 10.0, 2.0),
		"time": Time.get_unix_time_from_system()
	}
	
	damage_zones.append(damage_zone)
	
	# Применяем деформацию ко всем вершинам
	apply_realistic_deformation()
	
	print("Realistic deformation applied: ", deformation_amount, " at ", local_collision_point)

func apply_realistic_deformation():
	if not original_mesh:
		return
	
	# Создаем новый BoxMesh с деформированными размерами
	var deformed_mesh = BoxMesh.new()
	var original_size = original_mesh.size
	var deformed_size = original_size
	
	# Применяем сумму всех зон повреждения
	var total_deformation = Vector3.ZERO
	
	for damage_zone in damage_zones:
		var zone_force = damage_zone["force"]
		var zone_normal = damage_zone["normal"]
		var zone_radius = damage_zone["radius"]
		
		# Деформация зависит от силы и направления
		var deform_amount = zone_force * 0.2
		var deform_vector = zone_normal * deform_amount * -1.0  # Вмятина внутрь
		
		# Добавляем случайный компонент для реалистичности
		var random_component = Vector3(
			randf_range(-0.1, 0.1),
			randf_range(-0.1, 0.1),
			randf_range(-0.1, 0.1)
		) * zone_force * 0.1
		
		total_deformation += deform_vector + random_component
	
	# Применяем деформацию к размерам
	deformed_size.x = max(original_size.x + total_deformation.x, original_size.x * 0.5)
	deformed_size.y = max(original_size.y + total_deformation.y, original_size.y * 0.7)
	deformed_size.z = max(original_size.z + total_deformation.z, original_size.z * 0.5)
	
	deformed_mesh.size = deformed_size
	
	# Применяем материал из оригинального меша
	if original_mesh.get_surface_count() > 0:
		var original_material = original_mesh.surface_get_material(0)
		if original_material:
			deformed_mesh.material = original_material
	
	mesh = deformed_mesh
	
	# Дополнительная деформация через scale
	var scale_deformation = Vector3.ONE
	var total_force = get_total_deformation()
	scale_deformation.x *= (1.0 - total_force * 0.05)
	scale_deformation.y *= (1.0 - total_force * 0.03)
	scale_deformation.z *= (1.0 - total_force * 0.05)
	
	scale = scale_deformation

func recover_deformation(delta: float):
	if damage_zones.size() == 0:
		return
	
	var recovered = false
	var zones_to_remove = []
	
	# Восстанавливаем каждую зону повреждения
	for i in range(damage_zones.size()):
		var damage_zone = damage_zones[i]
		damage_zone["force"] = max(0.0, damage_zone["force"] - deformation_recovery_speed * delta)
		
		if damage_zone["force"] <= 0.01:
			zones_to_remove.append(i)
		else:
			recovered = true
	
	# Удаляем восстановленные зоны в обратном порядке
	for i in range(zones_to_remove.size() - 1, -1, -1):
		damage_zones.remove_at(zones_to_remove[i])
	
	# Применяем обновленную деформацию
	if recovered:
		apply_realistic_deformation()
	else:
		# Полное восстановление
		if original_mesh:
			mesh = original_mesh.duplicate()
			scale = Vector3.ONE

func apply_damage_deformation(damage_level: float):
	# Создаем множественные зоны повреждения для общего урона
	var num_impacts = int(damage_level * 5) + 1
	var size = original_mesh.size
	
	for i in range(num_impacts):
		var random_pos = Vector3(
			randf_range(-size.x * 0.4, size.x * 0.4),
			randf_range(-size.y * 0.4, size.y * 0.4),
			randf_range(-size.z * 0.4, size.z * 0.4)
		)
		
		var random_normal = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			randf_range(-1, 1)
		).normalized()
		
		var damage_zone = {
			"position": random_pos,
			"force": damage_level * 0.3,
			"normal": random_normal,
			"radius": damage_level * 2.0,
			"time": Time.get_unix_time_from_system()
		}
		
		damage_zones.append(damage_zone)
	
	apply_realistic_deformation()

func get_total_deformation() -> float:
	var total_deform = 0.0
	for damage_zone in damage_zones:
		total_deform += damage_zone["force"]
	return min(total_deform, 1.0)
