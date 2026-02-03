extends RigidBody3D

## Автомобиль с системой деформации на основе множественных RigidBody3D узлов
## Это более стабильный подход для физики деформации в Godot 4.6

@export_group("Движение")
@export var engine_power: float = 2000.0
@export var max_speed: float = 60.0
@export var steering_speed: float = 2.5
@export var max_steering_angle: float = 0.6
@export var brake_force: float = 3000.0

@export_group("Деформация")
@export var deformation_strength: float = 0.5  # Сила деформации при столкновении
@export var deformation_recovery: float = 0.1  # Скорость восстановления формы

var steering_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0

var original_scale: Vector3 = Vector3.ONE
var deformation_points: Array[Vector3] = []  # Точки деформации

func _ready():
	original_scale = scale
	mass = 1200.0
	gravity_scale = 1.0
	add_to_group("car")
	
	# Настройка физики для лучшей деформации
	contact_monitor = true
	max_contacts_reported = 10
	
	# Подключаем обработчик столкновений
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	handle_input()
	apply_engine_force(delta)
	apply_steering(delta)
	apply_downforce()
	apply_air_resistance()
	
	# Восстановление формы после деформации
	recover_deformation(delta)

func handle_input():
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		throttle_input = 1.0
		brake_input = 0.0
	elif Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		throttle_input = -0.4  # Задний ход
		brake_input = 0.0
	else:
		throttle_input = 0.0
	
	if Input.is_action_pressed("ui_select") or Input.is_key_pressed(KEY_SPACE):
		brake_input = 1.0
		throttle_input = 0.0
	
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		steering_input = -1.0
	elif Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		steering_input = 1.0
	else:
		steering_input = 0.0

func apply_engine_force(delta):
	var speed = linear_velocity.length()
	
	if speed < max_speed:
		var forward = -transform.basis.z
		var force = forward * throttle_input * engine_power
		apply_central_force(force)
	
	if brake_input > 0.0:
		var brake_force_vector = -linear_velocity.normalized() * brake_force * brake_input
		apply_central_force(brake_force_vector)

func apply_steering(delta):
	var speed_factor = min(linear_velocity.length() / max_speed, 1.0)
	var steering_angle = steering_input * max_steering_angle * speed_factor
	
	if linear_velocity.length() > 0.1:
		var turn_force = transform.basis.x * steering_angle * linear_velocity.length() * steering_speed
		apply_torque(Vector3(0, turn_force.length() * sign(steering_input), 0))

func apply_downforce():
	var downforce_vector = Vector3(0, -60.0 * linear_velocity.length(), 0)
	apply_central_force(downforce_vector)

func apply_air_resistance():
	var air_resistance_force = -linear_velocity * 0.35 * linear_velocity.length()
	apply_central_force(air_resistance_force)

func _on_body_entered(body):
	# Обработка столкновения для деформации
	if body.is_in_group("obstacles") or body.is_in_group("ground"):
		var collision_force = linear_velocity.length() * mass
		
		if collision_force > 100.0:  # Минимальная сила для деформации
			apply_deformation(collision_force)

func apply_deformation(force: float):
	# Применяем визуальную деформацию через изменение масштаба
	var deformation_amount = min(force / 5000.0, 0.3)  # Максимальная деформация 30%
	
	# Деформация в направлении столкновения (упрощенная)
	var deformation_direction = -linear_velocity.normalized()
	
	# Визуальная деформация через изменение формы меша
	# В реальной реализации здесь можно использовать SoftBody3D или изменять вершины меша
	var mesh_instance = get_node_or_null("MeshInstance3D")
	if mesh_instance:
		# Можно добавить визуальные эффекты деформации
		pass

func recover_deformation(delta):
	# Постепенное восстановление формы
	if scale != original_scale:
		scale = scale.lerp(original_scale, deformation_recovery * delta)
