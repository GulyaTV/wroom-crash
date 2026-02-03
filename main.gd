extends Node3D

## Главный скрипт игры с улучшенной генерацией препятствий

@export var car_scene: PackedScene
@export var obstacle_scene: PackedScene
@export var obstacle_count: int = 30
@export var spawn_area_size: float = 50.0

func _ready():
	# Создаем автомобиль
	if car_scene:
		var car = car_scene.instantiate()
		car.global_position = Vector3(0, 2, 0)
		add_child(car)
	
	# Создаем препятствия
	spawn_obstacles()
	
	# Настройка освещения
	setup_lighting()

func spawn_obstacles():
	if not obstacle_scene:
		return
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Разнообразные препятствия
	var obstacle_types = [
		{"size": Vector3(2, 2, 2), "color": Color(0.8, 0.2, 0.2)},
		{"size": Vector3(1.5, 3, 1.5), "color": Color(0.2, 0.8, 0.2)},
		{"size": Vector3(3, 1, 1), "color": Color(0.8, 0.8, 0.2)},
		{"size": Vector3(1, 1, 3), "color": Color(0.2, 0.2, 0.8)},
	]
	
	for i in range(obstacle_count):
		var obstacle = obstacle_scene.instantiate()
		
		# Случайная позиция (избегаем центра где спавнится машина)
		var angle = rng.randf() * TAU
		var distance = rng.randf_range(10.0, spawn_area_size)
		var x = cos(angle) * distance
		var z = sin(angle) * distance
		
		obstacle.global_position = Vector3(x, 1.0, z)
		
		# Случайный тип препятствия
		var obstacle_type = obstacle_types[rng.randi() % obstacle_types.size()]
		obstacle.scale = obstacle_type.size
		
		# Применяем цвет к материалу
		var mesh_instance = obstacle.get_node_or_null("MeshInstance3D")
		if mesh_instance and mesh_instance.get_surface_override_material(0):
			var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
			if material:
				material.albedo_color = obstacle_type.color
		
		# Случайный поворот
		obstacle.rotation.y = rng.randf() * TAU
		
		add_child(obstacle)
		obstacle.add_to_group("obstacles")
		
		# Настройка массы в зависимости от размера
		if obstacle is RigidBody3D:
			var volume = obstacle_type.size.x * obstacle_type.size.y * obstacle_type.size.z
			obstacle.mass = volume * 100.0  # Плотность 100 кг/м³

func setup_lighting():
	# Освещение уже настроено в сцене, но можно добавить дополнительные источники
	pass

func _input(event):
	# Перезапуск игры
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()
