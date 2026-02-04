extends Node

## Система достижений для Wroom Crash

signal achievement_unlocked(name: String, description: String)

var achievements: Dictionary = {
	"first_crash": {
		"name": "Первое столкновение",
		"description": "Совершите первое столкновение",
		"unlocked": false,
		"icon": "🔥"
	},
	"speed_demon": {
		"name": "Демон скорости",
		"description": "Разгонитесь до 100 км/ч",
		"unlocked": false,
		"icon": "⚡"
	},
	"crash_master": {
		"name": "Мастер аварий",
		"description": "Совершите 10 столкновений",
		"unlocked": false,
		"icon": "💥"
	},
	"boost_junkie": {
		"name": "Бустер",
		"description": "Используйте boost 5 раз",
		"unlocked": false,
		"icon": "🚀"
	},
	"survivor": {
		"name": "Выживший",
		"description": "Продержитесь 2 минуты без перезапуска",
		"unlocked": false,
		"icon": "🛡️"
	},
	"wrecker": {
		"name": "Разрушитель",
		"description": "Повредите автомобиль на 80%",
		"unlocked": false,
		"icon": "🔧"
	}
}

var stats: Dictionary = {
	"total_collisions": 0,
	"boost_uses": 0,
	"max_speed": 0.0,
	"survival_time": 0.0,
	"max_damage": 0.0
}

var car: RigidBody3D
var game_start_time: float
var last_boost_check: bool = false

func _ready():
	# Находим автомобиль
	var cars = get_tree().get_nodes_in_group("car")
	if cars.size() > 0:
		car = cars[0]
		connect_to_car_signals()
	
	game_start_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second

func connect_to_car_signals():
	if car:
		if car.has_signal("collision_occurred"):
			car.collision_occurred.connect(_on_collision_occurred)
		if car.has_signal("speed_changed"):
			car.speed_changed.connect(_on_speed_changed)

func _process(_delta):
	if not car:
		return
	
	# Обновляем статистику
	update_stats()
	
	# Проверяем достижения
	check_achievements()

func update_stats():
	# Обновляем максимальную скорость
	var current_speed_kmh = car.linear_velocity.length() * 3.6
	if current_speed_kmh > stats.max_speed:
		stats.max_speed = current_speed_kmh
	
	# Обновляем время выживания
	var current_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	stats.survival_time = current_time - game_start_time
	
	# Обновляем максимальные повреждения
	if car.has_method("get") and car.get("damage_level") != null:
		var current_damage = car.damage_level
		if current_damage > stats.max_damage:
			stats.max_damage = current_damage
	
	# Проверяем использование boost
	if car.has_method("is_boosting") and car.is_boosting():
		if not last_boost_check:
			stats.boost_uses += 1
			last_boost_check = true
	else:
		last_boost_check = false

func check_achievements():
	# Первое столкновение
	if stats.total_collisions >= 1 and not achievements.first_crash.unlocked:
		unlock_achievement("first_crash")
	
	# Демон скорости
	if stats.max_speed >= 100 and not achievements.speed_demon.unlocked:
		unlock_achievement("speed_demon")
	
	# Мастер аварий
	if stats.total_collisions >= 10 and not achievements.crash_master.unlocked:
		unlock_achievement("crash_master")
	
	# Бустер
	if stats.boost_uses >= 5 and not achievements.boost_junkie.unlocked:
		unlock_achievement("boost_junkie")
	
	# Выживший
	if stats.survival_time >= 120 and not achievements.survivor.unlocked:
		unlock_achievement("survivor")
	
	# Разрушитель
	if stats.max_damage >= 0.8 and not achievements.wrecker.unlocked:
		unlock_achievement("wrecker")

func unlock_achievement(achievement_id: String):
	if achievements.has(achievement_id) and not achievements[achievement_id].unlocked:
		achievements[achievement_id].unlocked = true
		var achievement = achievements[achievement_id]
		
		print("🏆 Достижение разблокировано: ", achievement.name)
		print("📝 ", achievement.description)
		
		achievement_unlocked.emit(achievement.name, achievement.description)

func _on_collision_occurred(_force: float):
	stats.total_collisions += 1

func _on_speed_changed(_speed: float):
	# Скорость обрабатывается в update_stats
	pass

func get_unlocked_achievements() -> Array:
	var unlocked = []
	for achievement_id in achievements:
		if achievements[achievement_id].unlocked:
			unlocked.append(achievements[achievement_id])
	return unlocked

func get_achievement_progress() -> Dictionary:
	return {
		"first_crash": min(stats.total_collisions, 1),
		"speed_demon": min(stats.max_speed / 100.0, 1.0),
		"crash_master": min(stats.total_collisions / 10.0, 1.0),
		"boost_junkie": min(stats.boost_uses / 5.0, 1.0),
		"survivor": min(stats.survival_time / 120.0, 1.0),
		"wrecker": min(stats.max_damage, 1.0)
	}

func reset_stats():
	stats = {
		"total_collisions": 0,
		"boost_uses": 0,
		"max_speed": 0.0,
		"survival_time": 0.0,
		"max_damage": 0.0
	}
	game_start_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	
	# Сбрасываем разблокированные достижения (опционально)
	# for achievement_id in achievements:
	# 	achievements[achievement_id].unlocked = false
