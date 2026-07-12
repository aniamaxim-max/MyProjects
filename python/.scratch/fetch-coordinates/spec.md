Status: ready-for-agent

# Спецификация: Автоматический сбор GPS-координат车辆

## Problem Statement

Существующий скрипт `fms_coordinates.py` тянет координаты только одной машины, сохраняет в Excel, и запускается вручную. Нужно автоматизировать сбор координат для всех车辆 из API fm-track.com, сохранять их в локальную SQLite базу, и запускать ежедневно в 3:00 ночи.

## Solution

Новый скрипт `scripts/fetch_coordinates.py`, который:
1. Читает API ключи из переменных среды (`API_KEY_TRIMEX`, `API_KEY_STELLAR`)
2. Для каждого ключа получает список车辆 через `GET /objects`
3. Обновляет справочник车辆 в SQLite (таблица `vehicles`)
4. Для каждой машины запрашивает координаты за период: от последней записи в БД (или -30 дней) до текущего момента
5. Фильтрует точки со скоростью > 200 км/ч (расчет через формулу Haversine)
6. Сохраняет координаты в SQLite с UPSERT

## User Stories

1. As a fleet manager, I want to automatically collect GPS coordinates for all vehicles daily, so that I don't have to manually run scripts
2. As a fleet manager, I want coordinates stored in a SQLite database, so that I can query historical data efficiently
3. As a fleet manager, I want the script to handle multiple API keys, so that I can track vehicles from different organizations
4. As a fleet manager, I want the script to detect where it left off, so that it doesn't re-download already stored data
5. As a fleet manager, I want the script to filter out GPS errors (speed > 200 km/h), so that the data is clean and reliable
6. As a fleet manager, I want the script to run automatically at 3:00 AM daily, so that data is always up to date
7. As a fleet manager, I want a vehicles table showing which API key each vehicle belongs to, so that I can track data sources
8. As a fleet manager, I want error logging, so that I can diagnose issues when they occur
9. As a fleet manager, I want the script to handle pagination for APIs with many results, so that no data is lost
10. As a fleet manager, I want the script to handle API errors gracefully, so that one failed request doesn't stop the entire process

## Implementation Decisions

### Модули

- `scripts/fetch_coordinates.py` — основной скрипт
- `config/config.py` — добавить список API ключей
- `data/coordinates.db` — SQLite база данных
- `logs/fetch_coords.log` — лог ошибок

### Схема SQLite

**Таблица `vehicles`:**
- `id` INTEGER PRIMARY KEY
- `object_id` TEXT UNIQUE
- `name` TEXT
- `api_key_name` TEXT
- `last_updated` TEXT

**Таблица `coordinates`:**
- `id` INTEGER PRIMARY KEY
- `object_id` TEXT
- `datetime` TEXT
- `latitude` REAL
- `longitude` REAL
- `altitude` REAL
- `speed` REAL
- `direction` REAL
- `ignition_status` BOOLEAN
- `satellites_count` INTEGER
- `power_supply_voltage` REAL
- `hdop` REAL
- `mileage` REAL
- UNIQUE(object_id, datetime)

### API контракты

1. `GET /objects` — список车辆
   - Query params: `api_key`, `version=1`
   - Response: `items[]` с `id`, `name`

2. `GET /objects/{id}/coordinates` — координаты
   - Query params: `api_key`, `version=1`, `limit`, `fromDatetime`, `toDatetime`, `continuationToken`
   - Response: `items[]` с `datetime`, `position.*`, `ignition_status`, `device_inputs.*`, `calculated_inputs.*`
   - Pagination: `continuationToken` (1000 items per page)

### Логика определения диапазона дат

Для каждой машины:
- Дата начала: `SELECT MAX(datetime) FROM coordinates WHERE object_id = ?` или `now - 30 days`
- Дата конца: `now`

### Фильтрация по скорости

Для последовательных точек:
1. Загрузить предыдущую точку из БД
2. Рассчитать расстояние через Haversine
3. Рассчитать скорость = расстояние / время
4. Если скорость > 200 км/ч → пропустить точку

Формула Haversine:
```
a = sin²(Δφ/2) + cos(φ1) · cos(φ2) · sin²(Δλ/2)
c = 2 · atan2(√a, √(1−a))
d = R · c   (R = 6371 км)
speed = d / Δt (км/ч)
```

### Расписание

Windows Task Scheduler — ежедневно в 3:00 ночи

## Testing Decisions

- Тестировать внешнее поведение, не детали реализации
- Покрыть: создание таблиц, UPSERT, Haversine, фильтрацию по скорости
- Использовать pytest
- Мокать API вызовы для тестирования

## Out of Scope

- Визуализация данных (картографирование)
- Уведомления об ошибках
- Веб-интерфейс
- Экспорт данных из SQLite

## Further Notes

- Скрипт расширяет существующий проект, не заменяет его
- API ключи хранятся в переменных среды Windows
- SQLite выбрана для простоты и портативности
