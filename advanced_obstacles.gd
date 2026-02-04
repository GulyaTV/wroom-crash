extends RigidBody3D

## Расширенные типы препятствий с различными свойствами

enum ObstacleType {
	BARRIER,
	WALL,
	POST,
	PLATFORM,
	POLE,
	DESTRUCTIBLE_BOX,
	BOUNCY_BALL,
	HEAVY_BLOCK,
	GLASS_PANE,
	TIRE_STACK
}

@export var obstacle_type: ObstacleType = ObstacleType.BARRIER
@export var custom_color: Color = Color.WHITE
@export var health: float = 100.0
@export var explosion_force: float = 500.0

var original_position: Vector3
var original_rotation: Vector3
var is_destroyed: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready():
	original_position = global_position
	original_rotation = global_rotation
	
	setup_obstacle_properties()
	
	# Добавляем в группу препятствий
	add_to_group("obstacles")
	
	# Настройка физики
	contact_monitor = true
	max_contacts_reported = 10
	
	body_entered.connect(_on_body_entered)

func setup_obstacle_properties():
	match obstacle_type:
		ObstacleType.BARRIER:
			mass = 200.0
			health = 150.0
			custom_color = Color(0.8, 0.2, 0.2)
			
		ObstacleType.WALL:
			mass = 500.0
			health = 300.0
			custom_color = Color(0.6, 0.4, 0.2)
			
		ObstacleType.POST:
			mass = 80.0
			health = 80.0
			custom_color = Color(0.2, 0.2, 0.8)
			
		ObstacleType.PLATFORM:
			mass = 800.0
			health = 400.0
			custom_color = Color(0.6, 0.3, 0.1)
			
		ObstacleType.POLE:
			mass = 50.0
			health = 60.0
			custom_color = Color(0.9, 0.5, 0.1)
			
		ObstacleType.DESTRUCTIBLE_BOX:
			mass = 30.0
			health = 50.0
			custom_color = Color(0.8, 0.6, 0.3)
			
		ObstacleType.BOUNCY_BALL:
			mass = 20.0
			health = 40.0
			custom_color = Color(0.2, 0.8, 0.2)
			# Устанавливаем упругий материал
			var physics_material = PhysicsMaterial.new()
			physics_material.bounce = 0.8
			physics_material.friction = 0.3
			physics_material.rough = true
			if collision_shape.shape is ConcavePolygonShape3D or collision_shape.shape is ConvexPolygonShape3D:
				collision_shape.material = physics_material
			
		ObstacleType.HEAVY_BLOCK:
			mass = 1500.0
			health = 500.0
			custom_color = Color(0.3, 0.3, 0.3)
			
		ObstacleType.GLASS_PANE:
			mass = 10.0
			health = 20.0
			custom_color = Color(0.7, 0.9, 1.0, 0.7)
			
		ObstacleType.TIRE_STACK:
			mass = 120.0
			health = 100.0
			custom_color = Color(0.1, 0.1, 0.1)
	
	# Применяем цвет к материалу
	if mesh_instance and mesh_instance.get_surface_override_material(0):
		var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if material:
			material.albedo_color = custom_color
			
			# Особые свойства для некоторых типов
			if obstacle_type == ObstacleType.GLASS_PANE:
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.albedo_color.a = 0.7
				material.roughness = 0.1
				material.metallic = 0.1

func _on_body_entered(body):
	if is_destroyed:
		return
	
	# Проверяем столкновение с автомобилем
	if body.is_in_group("car"):
		var collision_force = (body.linear_velocity * body.mass).length()
		
		# Наносим урон
		take_damage(collision_force)
		
		# Создаем эффекты столкновения
		create_collision_effects(collision_force)

func take_damage(damage: float):
	health -= damage * 0.1  # Конвертируем силу в урон
	
	if health <= 0 and not is_destroyed:
		destroy_obstacle()

func destroy_obstacle():
	is_destroyed = true
	
	# Создаем взрыв
	create_explosion()
	
	# Разбиваем на части (визуально)
	if mesh_instance:
		# Изменяем цвет для индикации разрушения
		var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if material:
			material.albedo_color = Color.RED
	
	# Отключаем коллизию через короткое время
	await get_tree().create_timer(0.1).timeout
	if collision_shape:
		collision_shape.disabled = true
	
	# Удаляем объект через некоторое время
	await get_tree().create_timer(5.0).timeout
	queue_free()

func create_collision_effects(force: float):
	# Создаем частицы столкновения
	var particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(particles)
	
	particles.global_position = global_position
	particles.amount = int(min(force / 100.0, 50))
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.emitting = true
	
	# Настраиваем материал частиц
	var material = ParticleProcessMaterial.new()
	material.gravity = Vector3(0, -9.8, 0)
	material.initial_velocity_min = force * 0.01
	material.initial_velocity_max = force * 0.03
	material.direction = -linear_velocity.normalized()
	particles.process_material = material
	
	# Автоудаление
	await get_tree().create_timer(2.0).timeout
	particles.queue_free()

func create_explosion():
	# Создаем эффект взрыва
	var explosion_particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(explosion_particles)
	
	explosion_particles.global_position = global_position
	explosion_particles.amount = 100
	explosion_particles.lifetime = 2.0
	explosion_particles.one_shot = true
	explosion_particles.emitting = true
	
	# Настраиваем материал взрыва
	var material = ParticleProcessMaterial.new()
	material.gravity = Vector3(0, -5, 0)
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 30.0
	material.angular_velocity_min = -720.0
	material.angular_velocity_max = 720.0
	material.scale_min = 0.1
	material.scale_max = 0.5
	explosion_particles.process_material = material
	
	# Применяем силу взрыва к соседним объектам
	apply_explosion_force()
	
	# Автоудаление
	await get_tree().create_timer(3.0).timeout
	explosion_particles.queue_free()

func apply_explosion_force():
	# Находим все объекты в радиусе взрыва
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 5.0
	query.shape = sphere_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var body = result.collider
		if body != self and body is RigidBody3D:
			var direction = (body.global_position - global_position).normalized()
			var distance = body.global_position.distance_to(global_position)
			var force_magnitude = explosion_force / max(distance * distance, 1.0)
			
			body.apply_central_impulse(direction * force_magnitude)

func reset_obstacle():
	# Сброс препятствия к исходному состоянию
	global_position = original_position
	global_rotation = original_rotation
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	health = 100.0
	is_destroyed = false
	
	if collision_shape:
		collision_shape.disabled = false
	
	if mesh_instance and mesh_instance.get_surface_override_material(0):
		var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if material:
			material.albedo_color = custom_color
