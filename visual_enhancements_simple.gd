extends Node

## Упрощенные визуальные улучшения для Wroom Crash

@export var enable_screen_shake: bool = true
@export var enable_particle_effects: bool = true

var car: RigidBody3D
var camera: Camera3D

var screen_shake_intensity: float = 0.0
var screen_shake_duration: float = 0.0

func _ready():
	# Находим основные объекты
	var cars = get_tree().get_nodes_in_group("car")
	if cars.size() > 0:
		car = cars[0]
	
	camera = get_viewport().get_camera_3d()
	
	# Подключаемся к событиям
	connect_to_events()

func connect_to_events():
	if car:
		if car.has_signal("collision_occurred"):
			car.collision_occurred.connect(_on_collision_occurred)

func _process(delta):
	# Обновляем эффекты
	update_screen_shake(delta)
	update_boost_effects()

func update_screen_shake(delta):
	if screen_shake_duration > 0.0:
		screen_shake_duration -= delta
		
		if camera and enable_screen_shake:
			var shake_offset = Vector3(
				randf_range(-1, 1) * screen_shake_intensity,
				randf_range(-1, 1) * screen_shake_intensity,
				randf_range(-1, 1) * screen_shake_intensity
			)
			
			camera.h_offset = shake_offset.x
			camera.v_offset = shake_offset.y
	else:
		if camera:
			camera.h_offset = 0.0
			camera.v_offset = 0.0

func update_boost_effects():
	if car and car.has_method("is_boosting") and car.is_boosting():
		# Добавляем след частиц при boost
		if enable_particle_effects and randf() < 0.3:
			create_boost_trail()

func _on_collision_occurred(force: float):
	# Эффекты при столкновении
	if enable_screen_shake:
		screen_shake_intensity = min(force / 1000.0, 0.5)
		screen_shake_duration = 0.3
	
	if enable_particle_effects:
		create_collision_sparks(force)
	
	# Вспышка света
	create_collision_flash(force)

func create_collision_sparks(force: float):
	# Создаем искры при столкновении
	var sparks = GPUParticles3D.new()
	get_tree().current_scene.add_child(sparks)
	
	sparks.global_position = car.global_position
	sparks.amount = int(min(force / 200.0, 100))
	sparks.lifetime = 1.5
	sparks.one_shot = true
	sparks.emitting = true
	
	# Настраиваем материал искр
	var material = ParticleProcessMaterial.new()
	material.gravity = Vector3(0, -9.8, 0)
	material.initial_velocity_min = force * 0.02
	material.initial_velocity_max = force * 0.05
	material.angular_velocity_min = -720.0
	material.angular_velocity_max = 720.0
	material.scale_min = 0.01
	material.scale_max = 0.05
	
	# Искры оранжевого цвета
	material.color = Color(1.0, 0.5, 0.0)
	
	sparks.process_material = material
	
	# Автоудаление
	await get_tree().create_timer(2.0).timeout
	sparks.queue_free()

func create_collision_flash(force: float):
	# Создаем вспышку света при столкновении
	var flash_light = OmniLight3D.new()
	get_tree().current_scene.add_child(flash_light)
	
	flash_light.global_position = car.global_position
	flash_light.light_energy = min(force / 100.0, 5.0)
	flash_light.light_color = Color(1.0, 0.8, 0.3)
	flash_light.omni_range = 10.0
	flash_light.shadow_enabled = false
	
	# Быстрое затухание света
	var tween = create_tween()
	tween.tween_property(flash_light, "light_energy", 0.0, 0.2)
	await tween.finished
	flash_light.queue_free()

func create_boost_trail():
	# Создаем след частиц при boost
	var trail = GPUParticles3D.new()
	get_tree().current_scene.add_child(trail)
	
	trail.global_position = car.global_position - car.transform.basis.z * 2.0
	trail.amount = 20
	trail.lifetime = 1.0
	trail.one_shot = true
	trail.emitting = true
	
	# Настраиваем материал следа
	var material = ParticleProcessMaterial.new()
	material.gravity = Vector3(0, -1, 0)
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.direction = car.transform.basis.z
	material.spread = 30.0
	material.scale_min = 0.1
	material.scale_max = 0.3
	
	# Синий цвет для boost
	material.color = Color(0.3, 0.8, 1.0)
	
	trail.process_material = material
	
	# Автоудаление
	await get_tree().create_timer(1.5).timeout
	trail.queue_free()
