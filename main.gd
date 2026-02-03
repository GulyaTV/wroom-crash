extends Node3D

## Главный скрипт игры

@export var car_scene: PackedScene
@export var obstacle_scene: PackedScene

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
	# Создаем случайные препятствия на карте
	if not obstacle_scene:
		return
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(20):
		var obstacle = obstacle_scene.instantiate()
		var x = rng.randf_range(-30, 30)
		var z = rng.randf_range(-30, 30)
		obstacle.global_position = Vector3(x, 0.5, z)
		
		# Случайный размер
		var scale = rng.randf_range(0.5, 2.0)
		obstacle.scale = Vector3(scale, scale, scale)
		
		add_child(obstacle)
		obstacle.add_to_group("obstacles")

func setup_lighting():
	# Освещение уже настроено в сцене
	pass

func _input(event):
	# Перезапуск игры
	if Input.is_action_just_pressed("ui_accept"):
		get_tree().reload_current_scene()
