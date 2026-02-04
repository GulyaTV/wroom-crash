extends Node

## Система игровых режимов для Wroom Crash

enum GameMode {
	FREE_ROAM,
	CRASH_TEST,
	SPEED_RUN,
	SURVIVAL,
	DESTRUCTION_DERBY
}

signal mode_changed(new_mode: GameMode)
signal game_timer_updated(time_left: float)
signal score_updated(score: int)
signal game_over(reason: String)

var current_mode: GameMode = GameMode.FREE_ROAM
var game_active: bool = true
var game_timer: float = 0.0
var score: int = 0
var high_scores: Dictionary = {}

var car: RigidBody3D
var achievement_system: Node

func _ready():
	# Находим автомобиль и систему достижений
	var cars = get_tree().get_nodes_in_group("car")
	if cars.size() > 0:
		car = cars[0]
	
	achievement_system = get_node_or_null("../AchievementSystem")
	
	# Загружаем рекорды
	load_high_scores()

func _process(delta):
	if not game_active:
		return
	
	match current_mode:
		GameMode.SPEED_RUN:
			update_speed_run(delta)
		GameMode.SURVIVAL:
			update_survival(delta)
		GameMode.DESTRUCTION_DERBY:
			update_destruction_derby(delta)
		GameMode.CRASH_TEST:
			update_crash_test(delta)

func set_game_mode(mode: GameMode):
	current_mode = mode
	reset_game()
	mode_changed.emit(mode)
	
	print("Режим игры изменен на: ", get_mode_name(mode))

func reset_game():
	game_active = true
	game_timer = get_mode_timer()
	score = 0
	
	if car:
		car.global_position = Vector3(0, 2, 0)
		car.global_rotation = Vector3.ZERO
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		
		# Сбрасываем статистику автомобиля
		if car.has_method("reset_car"):
			car.reset_car()
	
	# Сбрасываем статистику достижений
	if achievement_system:
		achievement_system.reset_stats()

func get_mode_timer() -> float:
	match current_mode:
		GameMode.SPEED_RUN:
			return 60.0  # 1 минута на рекорд скорости
		GameMode.SURVIVAL:
			return 180.0  # 3 минуты выживания
		GameMode.DESTRUCTION_DERBY:
			return 120.0  # 2 минуты на разрушение
		GameMode.CRASH_TEST:
			return 30.0  # 30 секунд на тест столкновений
		_:
			return -1.0  # Безлимитный режим

func update_speed_run(delta):
	game_timer -= delta
	game_timer_updated.emit(game_timer)
	
	if game_timer <= 0:
		end_game("Время вышло!")
		return
	
	# Обновляем счет на основе скорости
	if car:
		var speed = car.linear_velocity.length() * 3.6  # км/ч
		if speed > score:
			score = int(speed)
			score_updated.emit(score)

func update_survival(delta):
	game_timer -= delta
	game_timer_updated.emit(game_timer)
	
	if game_timer <= 0:
		end_game("Выживание завершено!")
		return
	
	# Проверяем состояние автомобиля
	if car and car.has_method("get") and car.get("damage_level") != null:
		if car.damage_level >= 0.9:
			end_game("Автомобиль разрушен!")
			return
	
	# Обновляем счет на основе времени выживания
	score = int((get_mode_timer() - game_timer) * 10)
	score_updated.emit(score)

func update_destruction_derby(delta):
	game_timer -= delta
	game_timer_updated.emit(game_timer)
	
	if game_timer <= 0:
		end_game("Время разрушения вышло!")
		return
	
	# Обновляем счет на основе столкновений
	if achievement_system:
		var collisions = achievement_system.stats.total_collisions
		score = collisions * 100
		score_updated.emit(score)

func update_crash_test(delta):
	game_timer -= delta
	game_timer_updated.emit(game_timer)
	
	if game_timer <= 0:
		end_game("Тест завершен!")
		return
	
	# Обновляем счет на основе силы столкновений
	if achievement_system:
		var total_force = achievement_system.stats.total_collisions * 500  # Примерный расчет
		score = int(total_force)
		score_updated.emit(score)

func end_game(reason: String):
	game_active = false
	game_over.emit(reason)
	
	# Сохраняем рекорд
	save_high_score()
	
	print("Игра окончена: ", reason)
	print("Финальный счет: ", score)

func save_high_score():
	var mode_name = get_mode_name(current_mode)
	if not high_scores.has(mode_name) or score > high_scores[mode_name]:
		high_scores[mode_name] = score
		print("Новый рекорд для режима ", mode_name, ": ", score)

func load_high_scores():
	# Здесь можно добавить загрузку из файла
	# Пока используем значения по умолчанию
	high_scores = {
		"Free Roam": 0,
		"Crash Test": 0,
		"Speed Run": 0,
		"Survival": 0,
		"Destruction Derby": 0
	}

func get_mode_name(mode: GameMode) -> String:
	match mode:
		GameMode.FREE_ROAM:
			return "Free Roam"
		GameMode.CRASH_TEST:
			return "Crash Test"
		GameMode.SPEED_RUN:
			return "Speed Run"
		GameMode.SURVIVAL:
			return "Survival"
		GameMode.DESTRUCTION_DERBY:
			return "Destruction Derby"
		_:
			return "Unknown"

func get_mode_description(mode: GameMode) -> String:
	match mode:
		GameMode.FREE_ROAM:
			return "Свободное катание без ограничений"
		GameMode.CRASH_TEST:
			return "Тестирование столкновений за 30 секунд"
		GameMode.SPEED_RUN:
			return "Разгонитесь до максимальной скорости за 1 минуту"
		GameMode.SURVIVAL:
			return "Выживите 3 минуты без разрушения автомобиля"
		GameMode.DESTRUCTION_DERBY:
			return "Создайте максимум столкновений за 2 минуты"
		_:
			return "Неизвестный режим"

func get_high_score(mode: GameMode) -> int:
	var mode_name = get_mode_name(mode)
	return high_scores.get(mode_name, 0)

func is_timer_mode() -> bool:
	return current_mode in [GameMode.SPEED_RUN, GameMode.SURVIVAL, GameMode.DESTRUCTION_DERBY, GameMode.CRASH_TEST]

func get_time_left() -> float:
	return max(0.0, game_timer)

func get_score() -> int:
	return score

func is_game_active() -> bool:
	return game_active

# Функции для переключения режимов
func start_free_roam():
	set_game_mode(GameMode.FREE_ROAM)

func start_crash_test():
	set_game_mode(GameMode.CRASH_TEST)

func start_speed_run():
	set_game_mode(GameMode.SPEED_RUN)

func start_survival():
	set_game_mode(GameMode.SURVIVAL)

func start_destruction_derby():
	set_game_mode(GameMode.DESTRUCTION_DERBY)
