extends Node

## Система деформации для автомобилей с использованием множественных RigidBody узлов
## Создает реалистичную деформацию при столкновениях

@export var car_body: RigidBody3D
@export var deformation_parts: Array[Node3D] = []  # Части автомобиля для деформации
@export var deformation_strength: float = 0.3
@export var recovery_speed: float = 0.5

var original_transforms: Array[Transform3D] = []

func _ready():
	# Сохраняем оригинальные трансформы частей
	for part in deformation_parts:
		original_transforms.append(part.transform)

func apply_deformation(force: float, direction: Vector3, position: Vector3):
	# Применяем деформацию к частям автомобиля
	for i in range(deformation_parts.size()):
		var part = deformation_parts[i]
		var distance = (part.global_position - position).length()
		var deformation_amount = force / (distance + 1.0) * deformation_strength
		
		# Деформируем часть в направлении силы
		var deformation_offset = direction * deformation_amount
		part.position += deformation_offset

func recover_deformation(delta: float):
	# Восстанавливаем форму частей
	for i in range(deformation_parts.size()):
		var part = deformation_parts[i]
		var original_transform = original_transforms[i]
		part.transform = part.transform.interpolate_with(original_transform, recovery_speed * delta)

func _physics_process(delta):
	recover_deformation(delta)
