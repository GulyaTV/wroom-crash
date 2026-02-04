extends Node

## Визуальные улучшения для Wroom Crash

@export var enable_dynamic_lighting: bool = true
@export var enable_particle_effects: bool = true
@export var enable_screen_shake: bool = true
@export var enable_motion_blur: bool = true

var car: RigidBody3D
var camera: Camera3D
var world_environment: WorldEnvironment

var screen_shake_intensity: float = 0.0
var screen_shake_duration: float = 0.0

func _ready():
	# Находим основные объекты
	var cars = get_tree().get_nodes_in_group("car")
	if cars.size() > 0:
		car = cars[0]
	
	camera = get_viewport().get_camera_3d()
	
	# Настраиваем окружение
	setup_environment()
	
	# Подключаемся к событиям
	connect_to_events()

func setup_environment():
	# Создаем WorldEnvironment если его нет
	if not world_environment:
		world_environment = WorldEnvironment.new()
		world_environment.name = "WorldEnvironment"
		get_tree().current_scene.add_child(world_environment)
	
	# Настраиваем небо и окружение
	var environment = Environment.new()
	world_environment.environment = environment
	
	# Настраиваем небо ProceduralSky
	var sky = ProceduralSkyMaterial.new()
	sky.ground_bottom_color = Color(0.1, 0.1, 0.1)
	sky.ground_horizon_color = Color(0.2, 0.2, 0.2)
	sky.sky_top_color = Color(0.3, 0.5, 0.8)
	sky.sky_horizon_color = Color(0.6, 0.7, 0.9)
	sky.sun_elevation = 0.5
	sky.sun_rotation = 0.0
	sky.sun_energy = 1.0
	
	var sky_box = Sky.new()
	sky_box.sky_material = sky
	environment.sky = sky_box
	
	# Настраиваем туман для глубины
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.8, 0.9, 1.0)
	environment.fog_density = 0.001
	environment.fog_sky_affect = 0.5
	
	# Настраиваем ambient light
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.3
	
	# Настраиваем tonemap для лучшего контраста
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 10.0
	
	# Включаем bloom для свечения
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.2
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

func connect_to_events():
	if car:
		if car.has_signal("collision_occurred"):
			car.collision_occurred.connect(_on_collision_occurred)
		
		# Подключаемся к boost системе
		if car.has_method("is_boosting"):
			# Будем проверять boost статус в процессе
			pass

func _process(delta):
	# Обновляем эффекты
	update_screen_shake(delta)
	update_boost_effects()
	update_lighting_effects()

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
		# Усиливаем эффекты при boost
		if world_environment and world_environment.environment:
			var env = world_environment.environment
			env.glow_intensity = 0.8
			env.tonemap_exposure = 1.2
		
		# Добавляем след частиц при boost
		if enable_particle_effects and randf() < 0.3:
			create_boost_trail()
	else:
		# Возвращаем к нормальным настройкам
		if world_environment and world_environment.environment:
			var env = world_environment.environment
			env.glow_intensity = 0.5
			env.tonemap_exposure = 1.0

func update_lighting_effects():
	# Динамическое освещение в зависимости от скорости
	if car and enable_dynamic_lighting:
		var speed = car.linear_velocity.length()
		
		# Находим основной источник света
		var main_light = get_tree().current_scene.find_child("DirectionalLight3D", true, false)
		if main_light and main_light is DirectionalLight3D:
			# Увеличиваем интенсивность света на высокой скорости
			var speed_factor = min(speed / 100.0, 1.0)
			main_light.light_energy = 1.2 + speed_factor * 0.3
			
			# Изменяем цвет света в зависимости от времени суток
			var time_factor = (Time.get_ticks_msec() % 10000) / 10000.0  # 10 секунд цикл
			var sun_color = Color.WHITE.lerp(Color(1.0, 0.8, 0.6), sin(time_factor * TAU) * 0.2 + 0.2)
			main_light.light_color = sun_color

func _on_collision_occurred(force: float):
	# Эффекты при столкновении
	if enable_screen_shake:
		screen_shake_intensity = min(force / 1000.0, 0.5)
		screen_shake_duration = 0.3
	
	if enable_particle_effects:
		create_collision_sparks(force)
	
	# Вспышка света
	if enable_dynamic_lighting:
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

func add_environment_details():
	# Добавляем детали окружения
	add_ground_details()
	add_atmospheric_effects()

func add_ground_details():
	# Добавляем детали на землю
	var ground = get_tree().current_scene.find_child("Ground", true, false)
	if ground:
		# Создаем декоративные элементы
		for i in range(20):
			var decoration = create_ground_decoration()
			ground.add_child(decoration)

func create_ground_decoration() -> Node3D:
	var decoration = MeshInstance3D.new()
	
	# Случайный тип декорации
	var decoration_type = randi() % 3
	
	match decoration_type:
		0:
			# Камень
			var stone_mesh = SphereMesh.new()
			stone_mesh.radius = randf_range(0.1, 0.3)
			stone_mesh.height = stone_mesh.radius * 2
			decoration.mesh = stone_mesh
			
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(0.4, 0.4, 0.4)
			material.roughness = 0.8
			decoration.set_surface_override_material(0, material)
			
		1:
			# Пыльная куча
			var dust_mesh = SphereMesh.new()
			dust_mesh.radius = randf_range(0.2, 0.5)
			dust_mesh.height = dust_mesh.radius * 0.5
			decoration.mesh = dust_mesh
			
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(0.6, 0.4, 0.2)
			material.roughness = 1.0
			decoration.set_surface_override_material(0, material)
			
		2:
			# Трава
			var grass_mesh = CylinderMesh.new()
			grass_mesh.top_radius = 0.05
			grass_mesh.bottom_radius = 0.05
			grass_mesh.height = randf_range(0.1, 0.3)
			decoration.mesh = grass_mesh
			
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(0.2, 0.6, 0.1)
			material.roughness = 0.9
			decoration.set_surface_override_material(0, material)
	
	# Случайная позиция
	decoration.global_position = Vector3(
		randf_range(-40, 40),
		0.1,
		randf_range(-40, 40)
	)
	
	return decoration

func add_atmospheric_effects():
	# Добавляем атмосферные частицы (пыль, дым)
	var dust_particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(dust_particles)
	
	dust_particles.global_position = Vector3(0, 10, 0)
	dust_particles.amount = 100
	dust_particles.lifetime = 20.0
	dust_particles.emitting = true
	dust_particles.process_material.direction = Vector3(1, 0, 0)
	dust_particles.process_material.initial_velocity_min = 0.1
	dust_particles.process_material.initial_velocity_max = 0.5
	
	# Настраиваем материал пыли
	var material = ParticleProcessMaterial.new()
	material.gravity = Vector3(0, -0.1, 0)
	material.scale_min = 0.5
	material.scale_max = 2.0
	material.color = Color(0.8, 0.7, 0.6, 0.3)
	
	dust_particles.process_material = material
