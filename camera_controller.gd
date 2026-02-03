extends Camera3D

## Камера следования за автомобилем с плавным движением и управлением мышью

@export var target: Node3D  # Целевой объект (автомобиль)
@export var follow_distance: float = 10.0  # Расстояние следования
@export var follow_height: float = 5.0  # Высота камеры
@export var follow_speed: float = 5.0  # Скорость следования
@export var rotation_speed: float = 3.0  # Скорость поворота камеры
@export var look_ahead: float = 8.0  # Опережение взгляда

var mouse_sensitivity: float = 0.002
var mouse_rotation: Vector2 = Vector2.ZERO
var current_distance: float = 10.0

func _ready():
	# Находим автомобиль автоматически, если не задан
	if not target:
		var cars = get_tree().get_nodes_in_group("car")
		if cars.size() > 0:
			target = cars[0]
	
	# Включаем обработку ввода мыши
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	current_distance = follow_distance

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_rotation -= event.relative * mouse_sensitivity
		mouse_rotation.y = clamp(mouse_rotation.y, -PI / 3, PI / 3)  # Ограничение вертикального угла
	
	# Переключение режима мыши
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Зум колесиком мыши
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_distance = max(current_distance - 2.0, 5.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_distance = min(current_distance + 2.0, 20.0)

func _physics_process(delta):
	if not target:
		return
	
	# Целевая позиция камеры
	var target_position = target.global_position
	var target_forward = -target.transform.basis.z
	
	# Позиция камеры с учетом расстояния и высоты
	var desired_position = target_position - target_forward * current_distance
	desired_position.y = target_position.y + follow_height
	
	# Плавное перемещение камеры
	global_position = global_position.lerp(desired_position, follow_speed * delta)
	
	# Направление взгляда с опережением
	var look_target = target_position + target_forward * look_ahead
	look_target.y = target_position.y + 1.5
	
	# Базовое направление взгляда
	var look_direction = (look_target - global_position).normalized()
	
	# Применяем поворот мыши
	var horizontal_rotation = Basis(Vector3.UP, mouse_rotation.x)
	var vertical_rotation = Basis(transform.basis.x, mouse_rotation.y)
	
	# Вычисляем финальное направление взгляда
	var final_direction = horizontal_rotation * look_direction
	final_direction = final_direction.rotated(transform.basis.x, mouse_rotation.y)
	
	# Плавный поворот камеры
	var target_basis = Basis.looking_at((look_target - global_position).normalized(), Vector3.UP)
	transform.basis = transform.basis.slerp(target_basis, rotation_speed * delta)
