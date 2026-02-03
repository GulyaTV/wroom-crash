# Настройка GitHub репозитория

## Подключение к существующему репозиторию

Если репозиторий еще не подключен локально:

```bash
git remote add origin https://github.com/GulyaTV/wroom-crash.git
git branch -M main
git push -u origin main
```

## Первая публикация проекта

```bash
# Добавить все файлы
git add .

# Создать коммит
git commit -m "Initial commit: Wroom Crash game with soft body physics"

# Отправить в репозиторий
git push origin main
```

## Обновление проекта

После внесения изменений:

```bash
# Проверить статус
git status

# Добавить изменения
git add .

# Создать коммит с описанием
git commit -m "Описание изменений"

# Отправить изменения
git push origin main
```

## Структура проекта

Проект содержит:
- `main.tscn` - Главная сцена игры
- `car_soft.tscn` - Автомобиль с физикой
- `soft_body_car.gd` - Скрипт управления автомобилем
- `camera_controller.gd` - Контроллер камеры
- `obstacle.tscn` - Препятствия
- `ground.tscn` - Поверхность
- `project.godot` - Настройки проекта Godot

## Важные файлы для Git

Убедитесь, что `.gitignore` содержит:
- `*.import` - Импортированные ресурсы (генерируются автоматически)
- `.godot/` - Кэш редактора
- `*.tmp` - Временные файлы
