extends RigidBody3D

## Автомобиль с физикой мягких тел для деформации при столкновениях

@export_group("Движение")
@export var engine_power: float = 1500.0  # Мощность двигателя
@export var max_speed: float = 50.0  # Максимальная скорость
@export var steering_speed: float = 2.0  # Скорость поворота
@export var max_steering_angle: float = 0.5  # Максимальный угол поворота колес
@export var brake_force: float = 2000.0  # Сила торможения

@export_group("Физика")
@export var downforce: float = 50.0  # Прижимная сила
@export var air_resistance: float = 0.3  # Сопротивление воздуха

var steering_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0

var wheel_base: float = 2.5  # База колес
var front_wheels: Array[Node3D] = []
var rear_wheels: Array[Node3D] = []

func _ready():
	# Находим колеса в сцене
	find_wheels()
	
	# Настройка физики
	mass = 1200.0  # Масса автомобиля в кг
	gravity_scale = 1.0

func find_wheels():
	# Ищем узлы колес по имени
	for child in get_children():
		if "wheel" in child.name.to_lower() or "колесо" in child.name.to_lower():
			if "front" in child.name.to_lower() or "перед" in child.name.to_lower():
				front_wheels.append(child)
			else:
				rear_wheels.append(child)

func _physics_process(delta):
	# Получаем ввод
	handle_input()
	
	# Применяем физику движения
	apply_engine_force(delta)
	apply_steering(delta)
	apply_downforce()
	apply_air_resistance()
	
	# Визуализация деформации (если используется SoftBody3D)
	update_deformation()

func handle_input():
	# Ускорение/торможение
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		throttle_input = 1.0
		brake_input = 0.0
	elif Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		throttle_input = -0.5  # Задний ход
		brake_input = 0.0
	else:
		throttle_input = 0.0
	
	# Торможение
	if Input.is_action_pressed("ui_select") or Input.is_key_pressed(KEY_SPACE):
		brake_input = 1.0
		throttle_input = 0.0
	
	# Поворот
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		steering_input = -1.0
	elif Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		steering_input = 1.0
	else:
		steering_input = 0.0

func apply_engine_force(delta):
	var speed = linear_velocity.length()
	
	if speed < max_speed:
		# Направление движения (вперед по оси Z)
		var forward = -transform.basis.z
		var force = forward * throttle_input * engine_power
		apply_central_force(force)
	
	# Торможение
	if brake_input > 0.0:
		var brake_force_vector = -linear_velocity.normalized() * brake_force * brake_input
		apply_central_force(brake_force_vector)

func apply_steering(delta):
	# Поворот автомобиля на основе скорости
	var speed_factor = min(linear_velocity.length() / max_speed, 1.0)
	var steering_angle = steering_input * max_steering_angle * speed_factor
	
	# Поворот применяется только при движении
	if linear_velocity.length() > 0.1:
		var turn_force = transform.basis.x * steering_angle * linear_velocity.length() * steering_speed
		apply_torque(Vector3(0, turn_force.length() * sign(steering_input), 0))

func apply_downforce():
	# Прижимная сила для лучшего сцепления
	var downforce_vector = Vector3(0, -downforce * linear_velocity.length(), 0)
	apply_central_force(downforce_vector)

func apply_air_resistance():
	# Сопротивление воздуха
	var air_resistance_force = -linear_velocity * air_resistance * linear_velocity.length()
	apply_central_force(air_resistance_force)

func update_deformation():
	# Если используется SoftBody3D, деформация будет обрабатываться автоматически
	# Здесь можно добавить дополнительную логику визуализации
	pass

func _on_body_entered(body):
	# Обработка столкновений для дополнительных эффектов
	if body.is_in_group("obstacles"):
		# Можно добавить звуки, частицы и т.д.
		pass
