extends Control

## HUD для отображения информации о скорости и состоянии автомобиля

@export var car: RigidBody3D
@onready var speed_label: Label = $SpeedLabel
@onready var info_label: Label = $InfoLabel

func _ready():
	# Создаем элементы интерфейса, если их нет
	if not speed_label:
		speed_label = Label.new()
		speed_label.name = "SpeedLabel"
		speed_label.position = Vector2(20, 20)
		speed_label.add_theme_font_size_override("font_size", 24)
		add_child(speed_label)
	
	if not info_label:
		info_label = Label.new()
		info_label.name = "InfoLabel"
		info_label.position = Vector2(20, 60)
		info_label.add_theme_font_size_override("font_size", 16)
		add_child(info_label)
	
	# Находим автомобиль автоматически
	if not car:
		var cars = get_tree().get_nodes_in_group("car")
		if cars.size() > 0:
			car = cars[0]

func _process(_delta):
	if car:
		update_speed_display()
		update_info_display()

func update_speed_display():
	var speed_kmh = car.linear_velocity.length() * 3.6  # Конвертация в км/ч
	speed_label.text = "Скорость: %.1f км/ч" % speed_kmh

func update_info_display():
	var info_text = "WASD - Управление\nSpace - Торможение\nESC - Мышь\nR - Перезапуск"
	info_label.text = info_text
