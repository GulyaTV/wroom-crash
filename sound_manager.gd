extends Node

## Менеджер звуковых эффектов для игры

@export var engine_sound_stream: AudioStream
@export var collision_sound_stream: AudioStream
@export var boost_sound_stream: AudioStream

var engine_player: AudioStreamPlayer3D
var collision_player: AudioStreamPlayer3D
var boost_player: AudioStreamPlayer3D

var car: RigidBody3D

func _ready():
	setup_audio_players()
	
	# Находим автомобиль
	var cars = get_tree().get_nodes_in_group("car")
	if cars.size() > 0:
		car = cars[0]
		connect_to_car_signals()

func setup_audio_players():
	# Engine sound player
	engine_player = AudioStreamPlayer3D.new()
	engine_player.name = "EngineSound"
	add_child(engine_player)
	if engine_sound_stream:
		engine_player.stream = engine_sound_stream
		engine_player.loop = true
		engine_player.autoplay = true
	
	# Collision sound player
	collision_player = AudioStreamPlayer3D.new()
	collision_player.name = "CollisionSound"
	add_child(collision_player)
	if collision_sound_stream:
		collision_player.stream = collision_sound_stream
	
	# Boost sound player
	boost_player = AudioStreamPlayer3D.new()
	boost_player.name = "BoostSound"
	add_child(boost_player)
	if boost_sound_stream:
		boost_player.stream = boost_sound_stream

func connect_to_car_signals():
	if car:
		# Подключаемся к сигналам автомобиля
		if car.has_signal("collision_occurred"):
			car.collision_occurred.connect(_on_collision_occurred)
		
		# Подключаемся к boost системе если есть
		if car.has_method("is_boost_ready"):
			# Будем проверять boost статус в процессе
			pass

func _process(_delta):
	if not car:
		return
	
	# Обновляем позицию звуков
	var car_pos = car.global_position
	engine_player.global_position = car_pos
	collision_player.global_position = car_pos
	boost_player.global_position = car_pos
	
	# Настраиваем звук двигателя в зависимости от скорости
	if engine_player and engine_player.playing:
		var speed = car.linear_velocity.length()
		var pitch_scale = 1.0 + (speed / 100.0)  # Увеличиваем тон со скоростью
		engine_player.pitch_scale = clamp(pitch_scale, 0.8, 2.5)
		
		# Увеличиваем громкость при ускорении
		var volume_db = -20.0 + (speed / 5.0)
		engine_player.volume_db = clamp(volume_db, -20.0, 0.0)
	
	# Проверяем boost активацию
	if boost_player and car.has_method("is_boosting") and car.is_boosting():
		if not boost_player.playing:
			boost_player.play()

func _on_collision_occurred(force: float):
	# Воспроизводим звук столкновения
	if collision_player and collision_sound_stream:
		# Настраиваем громкость в зависимости от силы столкновения
		var volume_db = -10.0 + (force / 1000.0)
		collision_player.volume_db = clamp(volume_db, -10.0, 10.0)
		
		# Случайный тон для разнообразия
		collision_player.pitch_scale = randf_range(0.8, 1.2)
		
		collision_player.play()

func play_boost_sound():
	if boost_player and not boost_player.playing:
		boost_player.play()

func stop_boost_sound():
	if boost_player and boost_player.playing:
		boost_player.stop()
