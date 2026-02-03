extends Control

## UI для отображения информации об игре

@export var car: RigidBody3D

@onready var speed_label: Label = $VBoxContainer/SpeedLabel
@onready var damage_label: Label = $VBoxContainer/DamageLabel
@onready var collisions_label: Label = $VBoxContainer/CollisionsLabel
@onready var info_label: Label = $VBoxContainer/InfoLabel

var speed: float = 0.0
var damage: float = 0.0
var collisions: int = 0

func _ready():
	# Создаем UI элементы если их нет
	if not has_node("VBoxContainer"):
		var vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		vbox.position = Vector2(20, 20)
		vbox.add_theme_constant_override("separation", 10)
		add_child(vbox)
		
		speed_label = Label.new()
		speed_label.name = "SpeedLabel"
		speed_label.add_theme_font_size_override("font_size", 32)
		speed_label.add_theme_color_override("font_color", Color.WHITE)
		vbox.add_child(speed_label)
		
		damage_label = Label.new()
		damage_label.name = "DamageLabel"
		damage_label.add_theme_font_size_override("font_size", 20)
		vbox.add_child(damage_label)
		
		collisions_label = Label.new()
		collisions_label.name = "CollisionsLabel"
		collisions_label.add_theme_font_size_override("font_size", 18)
		vbox.add_child(collisions_label)
		
		info_label = Label.new()
		info_label.name = "InfoLabel"
		info_label.add_theme_font_size_override("font_size", 16)
		info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		vbox.add_child(info_label)
	
	# Находим автомобиль
	if not car:
		var cars = get_tree().get_nodes_in_group("car")
		if cars.size() > 0:
			car = cars[0]
			if car.has_signal("speed_changed"):
				car.speed_changed.connect(_on_speed_changed)
			if car.has_signal("collision_occurred"):
				car.collision_occurred.connect(_on_collision_occurred)
	
	update_info_text()

func _process(_delta):
	if car:
		update_display()

func _on_speed_changed(new_speed: float):
	speed = new_speed

func _on_collision_occurred(_force: float):
	collisions += 1

func update_display():
	if not car or not car is RigidBody3D:
		return
	
	# Скорость
	if speed_label:
		var speed_kmh = car.linear_velocity.length() * 3.6
		speed_label.text = "%.0f км/ч" % speed_kmh
		
		# Изменяем цвет в зависимости от скорости
		if speed_kmh > 60:
			speed_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		elif speed_kmh > 30:
			speed_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		else:
			speed_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Повреждения
	if damage_label:
		if car.has_method("get") and car.get("damage_level") != null:
			damage = car.damage_level
		else:
			damage = 0.0
			
		var damage_percent = damage * 100.0
		damage_label.text = "Повреждения: %.0f%%" % damage_percent
		
		if damage_percent > 70:
			damage_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		elif damage_percent > 40:
			damage_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		else:
			damage_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Столкновения
	if collisions_label:
		if car.has_method("get") and car.get("total_collisions") != null:
			collisions = car.total_collisions
		collisions_label.text = "Столкновений: %d" % collisions

func update_info_text():
	if info_label:
		info_label.text = "WASD - Управление | Space - Торможение\nESC - Мышь | R - Перезапуск"
