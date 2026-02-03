extends RigidBody3D

## Улучшенный автомобиль с реалистичной физикой и системой деформации

@export_group("Движение")
@export var engine_power: float = 2500.0
@export var max_speed: float = 80.0
@export var steering_speed: float = 3.0
@export var max_steering_angle: float = 0.7
@export var brake_force: float = 4000.0
@export var reverse_power: float = 1000.0

@export_group("Физика")
@export var downforce: float = 80.0
@export var air_resistance: float = 0.4
@export var friction: float = 0.8

@export_group("Деформация")
@export var deformation_strength: float = 0.6
@export var deformation_recovery: float = 0.05
@export var min_deformation_force: float = 200.0

var steering_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0

var original_scale: Vector3 = Vector3.ONE
var damage_level: float = 0.0  # Уровень повреждений (0-1)
var total_collisions: int = 0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

@export var particles_scene: PackedScene
var last_collision_position: Vector3

signal speed_changed(speed: float)
signal collision_occurred(force: float)

func _ready():
	original_scale = scale
	mass = 1200.0
	gravity_scale = 1.0
	add_to_group("car")
	
	# Настройка физики
	contact_monitor = true
	max_contacts_reported = 20
	
	# Подключаем обработчики
	body_entered.connect(_on_body_entered)
	
	# Находим компоненты
	if not mesh_instance:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape3D")

func _physics_process(delta):
	handle_input()
	apply_engine_force(delta)
	apply_steering(delta)
	apply_downforce()
	apply_air_resistance()
	apply_friction()
	
	recover_deformation(delta)
	
	# Отправляем сигнал скорости
	speed_changed.emit(linear_velocity.length() * 3.6)  # км/ч

func handle_input():
	# Ускорение
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		throttle_input = 1.0
		brake_input = 0.0
	elif Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		throttle_input = -1.0  # Задний ход
		brake_input = 0.0
	else:
		throttle_input = 0.0
	
	# Торможение
	if Input.is_action_pressed("ui_select") or Input.is_key_pressed(KEY_SPACE):
		brake_input = 1.0
		throttle_input = 0.0
	else:
		if throttle_input == 0.0:
			brake_input = 0.0
	
	# Поворот
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		steering_input = -1.0
	elif Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		steering_input = 1.0
	else:
		steering_input = 0.0

func apply_engine_force(delta):
	var speed = linear_velocity.length()
	var forward = -transform.basis.z
	
	if throttle_input > 0.0:
		# Движение вперед
		if speed < max_speed:
			var force = forward * throttle_input * engine_power
			apply_central_force(force)
	elif throttle_input < 0.0:
		# Задний ход
		if speed < max_speed * 0.5:
			var force = -forward * abs(throttle_input) * reverse_power
			apply_central_force(force)
	
	# Торможение
	if brake_input > 0.0:
		var brake_force_vector = -linear_velocity.normalized() * brake_force * brake_input
		apply_central_force(brake_force_vector)

func apply_steering(delta):
	var speed = linear_velocity.length()
	var speed_factor = min(speed / max_speed, 1.0)
	var steering_angle = steering_input * max_steering_angle * speed_factor
	
	if speed > 0.5:
		# Поворот зависит от скорости
		var turn_strength = steering_angle * speed * steering_speed
		apply_torque(Vector3(0, turn_strength, 0))
	
	# Визуализация поворота колес (опционально)
	update_wheel_rotation(steering_angle)

func apply_downforce():
	var speed = linear_velocity.length()
	var downforce_vector = Vector3(0, -downforce * speed, 0)
	apply_central_force(downforce_vector)

func apply_air_resistance():
	var speed = linear_velocity.length()
	if speed > 0.1:
		var air_resistance_force = -linear_velocity.normalized() * air_resistance * speed * speed
		apply_central_force(air_resistance_force)

func apply_friction():
	# Боковое трение для лучшего сцепления
	var lateral_velocity = transform.basis.x * transform.basis.x.dot(linear_velocity)
	if lateral_velocity.length() > 0.1:
		var friction_force = -lateral_velocity * friction * mass
		apply_central_force(friction_force)

func update_wheel_rotation(angle: float):
	# Визуализация поворота передних колес
	var front_left = get_node_or_null("FrontLeftWheel")
	var front_right = get_node_or_null("FrontRightWheel")
	
	if front_left:
		front_left.rotation.y = angle * 0.3
	if front_right:
		front_right.rotation.y = angle * 0.3
	
	# Вращение всех колес при движении
	var speed = linear_velocity.length()
	if speed > 0.1:
		var wheel_rotation_speed = speed * 0.5
		var front_left_wheel = get_node_or_null("FrontLeftWheel")
		var front_right_wheel = get_node_or_null("FrontRightWheel")
		var rear_left_wheel = get_node_or_null("RearLeftWheel")
		var rear_right_wheel = get_node_or_null("RearRightWheel")
		
		if front_left_wheel:
			front_left_wheel.rotation.x += wheel_rotation_speed * get_physics_process_delta_time()
		if front_right_wheel:
			front_right_wheel.rotation.x += wheel_rotation_speed * get_physics_process_delta_time()
		if rear_left_wheel:
			rear_left_wheel.rotation.x += wheel_rotation_speed * get_physics_process_delta_time()
		if rear_right_wheel:
			rear_right_wheel.rotation.x += wheel_rotation_speed * get_physics_process_delta_time()

func _on_body_entered(body):
	if body.is_in_group("obstacles"):
		var collision_force = linear_velocity.length() * mass
		
		if collision_force > min_deformation_force:
			apply_deformation(collision_force)
			total_collisions += 1
			collision_occurred.emit(collision_force)
			
			# Увеличиваем уровень повреждений
			damage_level = min(damage_level + collision_force / 10000.0, 1.0)

func apply_deformation(force: float):
	var deformation_amount = min(force / 5000.0, deformation_strength)
	var collision_direction = -linear_velocity.normalized()
	
	# Визуальная деформация через изменение масштаба
	if mesh_instance:
		# Деформируем в направлении столкновения
		var deformation_scale = Vector3.ONE
		deformation_scale.x *= (1.0 - deformation_amount * abs(collision_direction.x))
		deformation_scale.y *= (1.0 - deformation_amount * abs(collision_direction.y))
		deformation_scale.z *= (1.0 - deformation_amount * abs(collision_direction.z))
		
		# Применяем деформацию к мешу через изменение масштаба
		mesh_instance.scale = original_scale * deformation_scale
	
	# Изменяем цвет в зависимости от повреждений
	update_damage_visual()

func update_damage_visual():
	if mesh_instance and mesh_instance.get_surface_override_material(0):
		var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if material:
			# Изменяем цвет в зависимости от повреждений
			var base_color = Color(0.2, 0.6, 1.0)  # Синий
			var damaged_color = Color(0.8, 0.2, 0.2)  # Красный
			material.albedo_color = base_color.lerp(damaged_color, damage_level * 0.5)

func recover_deformation(delta):
	if mesh_instance and mesh_instance.scale != original_scale:
		mesh_instance.scale = mesh_instance.scale.lerp(original_scale, deformation_recovery * delta)

func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6

func spawn_collision_particles(pos: Vector3, direction: Vector3):
	if particles_scene:
		var particles = particles_scene.instantiate()
		get_tree().current_scene.add_child(particles)
		particles.play_at_position(pos, direction)
	else:
		# Создаем простые частицы программно
		var particles = GPUParticles3D.new()
		particles.amount = 30
		particles.lifetime = 1.5
		particles.one_shot = true
		particles.global_position = pos
		
		var material = ParticleProcessMaterial.new()
		material.gravity = Vector3(0, -9.8, 0)
		material.initial_velocity_min = 5.0
		material.initial_velocity_max = 15.0
		material.direction = direction
		particles.process_material = material
		
		get_tree().current_scene.add_child(particles)
		particles.emitting = true
		
		# Автоудаление
		await get_tree().create_timer(2.0).timeout
		particles.queue_free()

func reset_car():
	global_position = Vector3(0, 2, 0)
	global_rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	damage_level = 0.0
	total_collisions = 0
	if mesh_instance:
		mesh_instance.scale = original_scale
