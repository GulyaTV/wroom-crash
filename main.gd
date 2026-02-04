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
		add_child(car)  # Добавляем в сцену СРАЗУ
		car.global_position = Vector3(0, 1, 0)  # Ниже к земле
		car.add_to_group("car")  # Добавляем в группу для поиска
		
		# Убедимся, что физика настроена правильно
		if car is RigidBody3D:
			car.freeze = false  # Размораживаем физику
			car.gravity_scale = 1.0
			car.linear_damp = 0.1  # Добавляем небольшое затухание
			car.angular_damp = 0.1
			print("Car created at position: ", car.global_position)
			print("Car physics enabled - freeze: ", car.freeze)
	
	# Создаем препятствия
	spawn_obstacles()
	
	# Настройка освещения
	setup_lighting()

func spawn_obstacles():
	if not obstacle_scene:
		return
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Разнообразные препятствия с разными свойствами
	var obstacle_types = [
		{"size": Vector3(2, 2, 2), "color": Color(0.8, 0.2, 0.2), "mass_multiplier": 1.0, "name": "Concrete Block"},
		{"size": Vector3(1.5, 3, 1.5), "color": Color(0.2, 0.8, 0.2), "mass_multiplier": 0.8, "name": "Barrier"},
		{"size": Vector3(3, 1, 1), "color": Color(0.8, 0.8, 0.2), "mass_multiplier": 1.2, "name": "Wall"},
		{"size": Vector3(1, 1, 3), "color": Color(0.2, 0.2, 0.8), "mass_multiplier": 0.6, "name": "Post"},
		{"size": Vector3(4, 0.5, 4), "color": Color(0.6, 0.3, 0.1), "mass_multiplier": 2.0, "name": "Platform"},
		{"size": Vector3(0.8, 5, 0.8), "color": Color(0.9, 0.5, 0.1), "mass_multiplier": 0.5, "name": "Pole"}
	]
	
	# Создаем зоны с высокой плотностью препятствий для интересных столкновений
	var crash_zones = [
		{"center": Vector3(15, 0, 0), "radius": 8, "count": 8},
		{"center": Vector3(-15, 0, 0), "radius": 8, "count": 8},
		{"center": Vector3(0, 0, 20), "radius": 8, "count": 8},
		{"center": Vector3(0, 0, -20), "radius": 8, "count": 6}
	]
	
	# Спавним препятствия в зонах столкновений
	for zone in crash_zones:
		for i in range(zone.count):
			var obstacle = obstacle_scene.instantiate()
			
			# Случайная позиция в зоне
			var angle = rng.randf() * TAU
			var distance = rng.randf_range(2.0, zone.radius)
			var x = zone.center.x + cos(angle) * distance
			var z = zone.center.z + sin(angle) * distance
			
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
			
			add_child(obstacle)  # Добавляем в сцену только ОДИН РАЗ
			obstacle.global_position = Vector3(x, zone.center.y + 1.0, z)
			obstacle.add_to_group("obstacles")
			
			# Настройка массы
			if obstacle is RigidBody3D:
				var volume = obstacle_type.size.x * obstacle_type.size.y * obstacle_type.size.z
				obstacle.mass = volume * 100.0 * obstacle_type.mass_multiplier
	
	# Добавляем случайные препятствия для разнообразия
	var remaining_obstacles = obstacle_count - (crash_zones[0].count + crash_zones[1].count + crash_zones[2].count + crash_zones[3].count)
	
	for i in range(remaining_obstacles):
		var obstacle = obstacle_scene.instantiate()
		
		# Случайная позиция (избегаем центра где спавнится машина)
		var angle = rng.randf() * TAU
		var distance = rng.randf_range(10.0, spawn_area_size)
		var x = cos(angle) * distance
		var z = sin(angle) * distance
		
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
		
		add_child(obstacle)  # Добавляем в сцену только ОДИН РАЗ
		obstacle.global_position = Vector3(x, 1.0, z)
		obstacle.add_to_group("obstacles")
		
		# Настройка массы
		if obstacle is RigidBody3D:
			var volume = obstacle_type.size.x * obstacle_type.size.y * obstacle_type.size.z
			obstacle.mass = volume * 100.0 * obstacle_type.mass_multiplier

func setup_lighting():
	# Освещение уже настроено в сцене, но можно добавить дополнительные источники
	pass

func _input(_event):
	# Перезапуск игры
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()
