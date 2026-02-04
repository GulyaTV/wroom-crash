extends Control

## UI для отображения информации об игре

@export var car: RigidBody3D

var speed_label: Label
var damage_label: Label
var collisions_label: Label
var boost_label: Label
var info_label: Label
var achievement_notification: Label
var game_mode_label: Label
var timer_label: Label
var score_label: Label

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
		
		boost_label = Label.new()
		boost_label.name = "BoostLabel"
		boost_label.add_theme_font_size_override("font_size", 20)
		vbox.add_child(boost_label)
		
		game_mode_label = Label.new()
		game_mode_label.name = "GameModeLabel"
		game_mode_label.add_theme_font_size_override("font_size", 18)
		game_mode_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		vbox.add_child(game_mode_label)
		
		timer_label = Label.new()
		timer_label.name = "TimerLabel"
		timer_label.add_theme_font_size_override("font_size", 16)
		timer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
		vbox.add_child(timer_label)
		
		score_label = Label.new()
		score_label.name = "ScoreLabel"
		score_label.add_theme_font_size_override("font_size", 16)
		score_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.3))
		vbox.add_child(score_label)
		
		info_label = Label.new()
		info_label.name = "InfoLabel"
		info_label.add_theme_font_size_override("font_size", 16)
		info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		vbox.add_child(info_label)
	else:
		# Если VBoxContainer уже существует, находим все метки
		var vbox = get_node("VBoxContainer")
		speed_label = vbox.get_node_or_null("SpeedLabel")
		damage_label = vbox.get_node_or_null("DamageLabel")
		collisions_label = vbox.get_node_or_null("CollisionsLabel")
		boost_label = vbox.get_node_or_null("BoostLabel")
		game_mode_label = vbox.get_node_or_null("GameModeLabel")
		timer_label = vbox.get_node_or_null("TimerLabel")
		score_label = vbox.get_node_or_null("ScoreLabel")
		info_label = vbox.get_node_or_null("InfoLabel")
	
	# Создаем уведомление о достижениях
	if not has_node("AchievementNotification"):
		achievement_notification = Label.new()
		achievement_notification.name = "AchievementNotification"
		achievement_notification.position = Vector2(get_viewport().size.x / 2 - 200, 100)
		achievement_notification.size = Vector2(400, 60)
		achievement_notification.add_theme_font_size_override("font_size", 24)
		achievement_notification.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		achievement_notification.add_theme_constant_override("outline_size", 2)
		achievement_notification.add_theme_color_override("font_outline_color", Color(0.2, 0.2, 0.2))
		achievement_notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		achievement_notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		achievement_notification.visible = false
		add_child(achievement_notification)
	else:
		achievement_notification = get_node("AchievementNotification")
	
	# Находим автомобиль
	if not car:
		var cars = get_tree().get_nodes_in_group("car")
		if cars.size() > 0:
			car = cars[0]
			if car.has_signal("speed_changed"):
				car.speed_changed.connect(_on_speed_changed)
			if car.has_signal("collision_occurred"):
				car.collision_occurred.connect(_on_collision_occurred)
	
	# Подключаемся к системе достижений
	var achievement_system = get_node_or_null("../AchievementSystem")
	if achievement_system:
		achievement_system.achievement_unlocked.connect(_on_achievement_unlocked)
	
	# Подключаемся к системе игровых режимов
	var game_modes = get_node_or_null("../GameModes")
	if game_modes:
		game_modes.mode_changed.connect(_on_mode_changed)
		game_modes.game_timer_updated.connect(_on_timer_updated)
		game_modes.score_updated.connect(_on_score_updated)
		game_modes.game_over.connect(_on_game_over)
	
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
		if "total_collisions" in car:
			collisions = car.total_collisions
		collisions_label.text = "Столкновений: %d" % collisions
	
	# Boost статус
	if boost_label and car.has_method("is_boost_ready"):
		if car.is_boosting:
			boost_label.text = "BOOST: АКТИВЕН!"
			boost_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		elif car.is_boost_ready():
			boost_label.text = "BOOST: Готов [Shift]"
			boost_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		else:
			var cooldown_time = car.get("boost_cooldown_time") if car.get("boost_cooldown_time") else 0.0
			boost_label.text = "BOOST: Перезарядка %.1fs" % cooldown_time
			boost_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

func _on_mode_changed(new_mode):
	if game_mode_label:
		var game_modes = get_node_or_null("../GameModes")
		if game_modes:
			game_mode_label.text = "Режим: " + game_modes.get_mode_name(new_mode)

func _on_timer_updated(time_left):
	if timer_label:
		var game_modes = get_node_or_null("../GameModes")
		if game_modes and game_modes.is_timer_mode():
			timer_label.text = "Время: %.1fs" % time_left
		else:
			timer_label.text = ""

func _on_score_updated(new_score):
	if score_label:
		score_label.text = "Счет: %d" % new_score

func _on_game_over(reason):
	# Показываем уведомление об окончании игры
	if achievement_notification:
		achievement_notification.text = "Игра окончена!\n" + reason
		achievement_notification.visible = true
		
		var tween = create_tween()
		achievement_notification.modulate.a = 0.0
		tween.tween_property(achievement_notification, "modulate:a", 1.0, 0.5)
		
		await get_tree().create_timer(5.0).timeout
		tween.tween_property(achievement_notification, "modulate:a", 0.0, 0.5)
		await tween.finished
		achievement_notification.visible = false

func update_info_text():
	if info_label:
		info_label.text = "WASD - Управление | Space - Торможение\nShift - Boost | R - Перезапуск"

func _on_achievement_unlocked(achievement_name: String, _description: String):
	if achievement_notification:
		achievement_notification.text = "🏆 Достижение!\n" + achievement_name
		achievement_notification.visible = true
		
		# Анимация появления и исчезновения
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Появление
		achievement_notification.modulate.a = 0.0
		tween.tween_property(achievement_notification, "modulate:a", 1.0, 0.5)
		
		# Масштабная анимация
		achievement_notification.scale = Vector2(0.5, 0.5)
		tween.tween_property(achievement_notification, "scale", Vector2(1.2, 1.2), 0.3)
		tween.tween_property(achievement_notification, "scale", Vector2(1.0, 1.0), 0.2)
		
		# Исчезновение через 3 секунды
		await get_tree().create_timer(3.0).timeout
		tween.tween_property(achievement_notification, "modulate:a", 0.0, 0.5)
		await tween.finished
		achievement_notification.visible = false
