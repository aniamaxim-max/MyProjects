import json
import os
import sys
import requests
import pandas as pd
from datetime import datetime, timedelta

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config.config import FMS_CONFIG

# ─────────────── Настройки ───────────────
API_KEY = FMS_CONFIG["api_key"]
OBJECT_ID = FMS_CONFIG["object_id"]
BASE_URL = FMS_CONFIG["base_url"]
ENDPOINT = f"{BASE_URL}/objects/{OBJECT_ID}/coordinates"

FROM_DATETIME = "2026-07-01T00:00:00Z"
TO_DATETIME = "2026-07-10T23:59:59Z"
OUTPUT_FILE = "car_history.xlsx"

FILTER_INTERVAL_SEC = 600  # 10 минут
PAGE_LIMIT = 1000


def fetch_coordinates():
    """Загрузка всех координат с пагинацией."""
    params = {
        "api_key": API_KEY,
        "version": 1,
        "limit": PAGE_LIMIT,
        "fromDatetime": FROM_DATETIME,
        "toDatetime": TO_DATETIME,
    }

    all_points = []
    continuation_token = None

    while True:
        if continuation_token:
            params["continuationToken"] = continuation_token

        print(f"Запрос данных (загружено: {len(all_points)} точек)...")
        response = requests.get(ENDPOINT, params=params)

        if response.status_code != 200:
            raise RuntimeError(
                f"API вернул статус {response.status_code}: {response.text}"
            )

        data = response.json()
        items = data.get("items", [])
        for item in items:
            flat = {
                "datetime": item.get("datetime"),
                "ignition_status": item.get("ignition_status"),
                "latitude": item.get("position", {}).get("latitude"),
                "longitude": item.get("position", {}).get("longitude"),
                "altitude": item.get("position", {}).get("altitude"),
                "direction": item.get("position", {}).get("direction"),
                "speed": item.get("position", {}).get("speed"),
                "satellites": item.get("position", {}).get("satellites_count"),
                "voltage": item.get("device_inputs", {}).get("power_supply_voltage"),
                "hdop": item.get("device_inputs", {}).get("hdop"),
                "mileage": item.get("calculated_inputs", {}).get("mileage"),
            }
            all_points.append(flat)
        print(f"  +{len(items)} точек (всего: {len(all_points)})")

        continuation_token = data.get("continuationToken")
        if not continuation_token:
            break

    print(f"Загрузка завершена. Всего получено точек: {len(all_points)}")
    return all_points


def filter_by_interval(points):
    """Оставить только точки с интервалом >= 10 минут."""
    if not points:
        return points

    datetime_field = None
    for field in ("datetime", "timestamp", "date", "time"):
        if field in points[0]:
            datetime_field = field
            break

    if not datetime_field:
        print("Поле даты/времени не найдено, фильтрация пропущена.")
        return points

    filtered = [points[0]]
    last_time = datetime.fromisoformat(points[0][datetime_field].replace("Z", "+00:00"))

    for point in points[1:]:
        current_time = datetime.fromisoformat(point[datetime_field].replace("Z", "+00:00"))
        if (current_time - last_time) >= timedelta(seconds=FILTER_INTERVAL_SEC):
            filtered.append(point)
            last_time = current_time

    print(f"После фильтрации (>=10 мин): {len(filtered)} точек из {len(points)}")
    return filtered


def save_to_excel(points):
    """Сохранение координат в Excel."""
    if not points:
        print("Нет данных для сохранения.")
        return

    COLUMN_MAP = {
        "datetime": "Дата/Время",
        "ignition_status": "Зажигание",
        "latitude": "Широта (Latitude)",
        "longitude": "Долгота (Longitude)",
        "altitude": "Высота (Altitude)",
        "direction": "Курс (Direction)",
        "speed": "Скорость (Speed)",
        "satellites": "Спутники",
        "voltage": "Напряжение (V)",
        "hdop": "HDOP",
        "mileage": "Пробег (м)",
    }

    df = pd.DataFrame(points)
    rename = {col: COLUMN_MAP[col.lower()] for col in df.columns if col.lower() in COLUMN_MAP}
    df.rename(columns=rename, inplace=True)

    df.to_excel(OUTPUT_FILE, index=False, engine="openpyxl")
    print(f"Файл успешно сохранен: {OUTPUT_FILE}")


def save_map(points, map_file="car_track.html"):
    """Генерация HTML-страницы с картой и треком."""
    if not points:
        print("Нет данных для карты.")
        return

    coords = [[p["latitude"], p["longitude"]] for p in points if p.get("latitude") and p.get("longitude")]
    if not coords:
        print("Нет координат для карты.")
        return

    center_lat = coords[0][0]
    center_lon = coords[0][1]

    markers_js = ""
    for i, p in enumerate(points):
        if not p.get("latitude") or not p.get("longitude"):
            continue
        dt = (p.get("datetime") or "").replace("T", " ").replace("Z", "")
        speed = p.get("speed", 0)
        popup = f"<b>#{i+1}</b><br>{dt}<br>Скорость: {speed} км/ч"
        markers_js += f"L.marker([{p['latitude']},{p['longitude']}]).addTo(map).bindPopup('{popup}');\n"

    html = f"""<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <title>Трек автомобиля</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <style>
        body {{ margin: 0; font-family: Arial, sans-serif; }}
        #map {{ height: calc(100vh - 50px); width: 100%; }}
        #header {{
            height: 50px; display: flex; align-items: center; justify-content: space-between;
            padding: 0 20px; background: #333; color: #fff; font-size: 16px;
        }}
        #header span {{ color: #aaa; font-size: 13px; }}
    </style>
</head>
<body>
    <div id="header">
        Трек автомобиля &mdash; {len(points)} точек
        <span>{points[0].get('datetime', '')[:10]} &mdash; {points[-1].get('datetime', '')[:10]}</span>
    </div>
    <div id="map"></div>
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <script>
        var coords = {json.dumps(coords)};
        var map = L.map('map').setView([{center_lat}, {center_lon}], 13);
        L.tileLayer('https://{{s}}.tile.openstreetmap.org/{{z}}/{{x}}/{{y}}.png', {{
            attribution: '&copy; OpenStreetMap'
        }}).addTo(map);
        L.polyline(coords, {{color: '#3388ff', weight: 4, opacity: 0.8}}).addTo(map);
        L.marker(coords[0]).addTo(map).bindPopup('<b>Старт</b>').openPopup();
        L.marker(coords[coords.length - 1]).addTo(map).bindPopup('<b>Финиш</b>');
        {markers_js}
        map.fitBounds(coords);
    </script>
</body>
</html>"""

    with open(map_file, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Карта сохранена: {map_file}")


if __name__ == "__main__":
    try:
        points = fetch_coordinates()
        filtered = filter_by_interval(points)
        save_to_excel(filtered)
        save_map(filtered)
    except Exception as e:
        print(f"Ошибка: {e}")
