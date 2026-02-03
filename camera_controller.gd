extends Camera3D

## Улучшенная камера следования с плавным движением

@export var target: Node3D
@export var follow_distance: float = 12.0
@export var follow_height: float = 6.0
@export var follow_speed: float = 8.0
@export var rotation_speed: float = 5.0
@export var look_ahead: float = 10.0
@export var use_mouse: bool = true

var mouse_sensitivity: float = 0.002
var mouse_rotation: Vector2 = Vector2.ZERO
var current_distance: float = 12.0
var target_speed_factor: float = 1.0  # Учет скорости автомобиля

func _ready():
	if not target:
		var cars = get_tree().get_nodes_in_group("car")
		if cars.size() > 0:
			target = cars[0]
	
	if use_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	current_distance = follow_distance

func _input(event):
	if not use_mouse:
		return
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_rotation -= event.relative * mouse_sensitivity
		mouse_rotation.y = clamp(mouse_rotation.y, -PI / 3, PI / 3)
	
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_distance = max(current_distance - 2.0, 6.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_distance = min(current_distance + 2.0, 25.0)

func _physics_process(delta):
	if not target:
		return
	
	var target_position = target.global_position
	var target_forward = -target.transform.basis.z
	
	# Учитываем скорость автомобиля для динамического расстояния
	if target is RigidBody3D:
		var car_speed = target.linear_velocity.length()
		target_speed_factor = 1.0 + (car_speed / 50.0) * 0.3  # Увеличиваем расстояние на скорости
	
	# Позиция камеры
	var desired_position = target_position - target_forward * current_distance * target_speed_factor
	desired_position.y = target_position.y + follow_height
	
	# Плавное перемещение
	global_position = global_position.lerp(desired_position, follow_speed * delta)
	
	# Направление взгляда
	var look_target = target_position + target_forward * look_ahead
	look_target.y = target_position.y + 2.0
	
	# Базовое направление
	var look_direction = (look_target - global_position).normalized()
	
	# Применяем поворот мыши
	if use_mouse and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var horizontal_basis = Basis(Vector3.UP, mouse_rotation.x)
		look_direction = horizontal_basis * look_direction
		look_direction = look_direction.rotated(transform.basis.x, mouse_rotation.y)
	
	# Плавный поворот камеры
	var target_basis = Basis.looking_at(look_direction, Vector3.UP)
	transform.basis = transform.basis.slerp(target_basis, rotation_speed * delta)
