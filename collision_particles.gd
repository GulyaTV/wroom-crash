extends GPUParticles3D

## Система частиц для эффектов столкновений

@export var auto_cleanup: bool = true

func _ready():
	# Настройка частиц
	emitting = false
	amount = 50
	lifetime = 2.0
	one_shot = true
	
	# Настройка материала частиц
	var material = ParticleProcessMaterial.new()
	material.gravity = Vector3(0, -9.8, 0)
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0
	process_material = material
	
	# Автоматическая очистка
	if auto_cleanup:
		finished.connect(_on_finished)

func play_at_position(pos: Vector3, direction: Vector3 = Vector3.ZERO):
	global_position = pos
	emitting = true
	
	# Направление частиц
	if process_material:
		var mat = process_material as ParticleProcessMaterial
		if mat and direction.length() > 0.1:
			mat.direction = direction.normalized()
			mat.initial_velocity_min = 8.0
			mat.initial_velocity_max = 20.0

func _on_finished():
	queue_free()
