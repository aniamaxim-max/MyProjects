import os
import sys
import sqlite3
import logging
import requests
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config.config import FMS_API_KEYS, SQLITE_DB_PATH, LOG_FILE

BASE_URL = "https://api.fm-track.com"
PAGE_LIMIT = 1000

logging.basicConfig(
    filename=LOG_FILE,
    level=logging.ERROR,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


def init_db():
    os.makedirs(os.path.dirname(SQLITE_DB_PATH), exist_ok=True)
    conn = sqlite3.connect(SQLITE_DB_PATH)
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS vehicles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            object_id TEXT UNIQUE NOT NULL,
            name TEXT,
            api_key_name TEXT NOT NULL,
            last_updated TEXT
        )
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS coordinates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            object_id TEXT NOT NULL,
            datetime TEXT NOT NULL,
            latitude REAL,
            longitude REAL,
            altitude REAL,
            speed REAL,
            direction REAL,
            ignition_status INTEGER,
            satellites_count INTEGER,
            power_supply_voltage REAL,
            hdop REAL,
            mileage REAL,
            UNIQUE(object_id, datetime)
        )
    """)
    conn.commit()
    return conn


def get_last_datetime(conn, object_id):
    cur = conn.cursor()
    cur.execute(
        "SELECT MAX(datetime) FROM coordinates WHERE object_id = ?",
        (object_id,),
    )
    row = cur.fetchone()
    if row and row[0]:
        last_dt = datetime.fromisoformat(row[0].replace("Z", "+00:00"))
        last_dt += timedelta(seconds=1)
        return last_dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    return (datetime.now(timezone.utc) - timedelta(days=30)).strftime("%Y-%m-%dT%H:%M:%SZ")



def fetch_objects(api_key):
    url = f"{BASE_URL}/objects"
    params = {"api_key": api_key, "version": 1}
    response = requests.get(url, params=params, timeout=30)
    if response.status_code != 200:
        raise RuntimeError(f"GET /objects failed: {response.status_code} {response.text}")
    data = response.json()
    if isinstance(data, list):
        return data
    return data.get("items", [])


def fetch_coordinates(conn, api_key, object_id, from_dt, to_dt):
    url = f"{BASE_URL}/objects/{object_id}/coordinates"
    params = {
        "api_key": api_key,
        "version": 1,
        "limit": PAGE_LIMIT,
        "fromDatetime": from_dt,
        "toDatetime": to_dt,
    }
    total_new = 0
    continuation_token = None
    page = 0
    while True:
        if continuation_token:
            params["continuationToken"] = continuation_token
        page += 1
        response = requests.get(url, params=params, timeout=30)
        if response.status_code != 200:
            raise RuntimeError(
                f"GET /objects/{object_id}/coordinates failed: {response.status_code}"
            )
        data = response.json()
        items = data.get("items", [])
        points = []
        for item in items:
            point = {
                "datetime": item.get("datetime"),
                "latitude": item.get("position", {}).get("latitude"),
                "longitude": item.get("position", {}).get("longitude"),
                "altitude": item.get("position", {}).get("altitude"),
                "speed": item.get("position", {}).get("speed"),
                "direction": item.get("position", {}).get("direction"),
                "ignition_status": item.get("ignition_status"),
                "satellites_count": item.get("position", {}).get("satellites_count"),
                "power_supply_voltage": item.get("device_inputs", {}).get("power_supply_voltage"),
                "hdop": item.get("device_inputs", {}).get("hdop"),
                "mileage": item.get("calculated_inputs", {}).get("mileage"),
            }
            points.append(point)
        saved, new_records = upsert_coordinates(conn, object_id, points)
        total_new += new_records
        msg = f"  page {page}: +{len(points)} points, +{new_records} new"
        print(msg)
        continuation_token = data.get("continuation_token")
        if not continuation_token:
            break
    return total_new


def upsert_vehicle(conn, object_id, name, api_key_name):
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    conn.execute(
        """
        INSERT INTO vehicles (object_id, name, api_key_name, last_updated)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(object_id) DO UPDATE SET
            name = excluded.name,
            api_key_name = excluded.api_key_name,
            last_updated = excluded.last_updated
        """,
        (object_id, name, api_key_name, now),
    )
    conn.commit()


def upsert_coordinates(conn, object_id, points):
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM coordinates WHERE object_id = ?", (object_id,))
    count_before = cur.fetchone()[0]

    conn.executemany(
        """
        INSERT INTO coordinates (object_id, datetime, latitude, longitude, altitude, speed,
            direction, ignition_status, satellites_count, power_supply_voltage, hdop, mileage)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(object_id, datetime) DO UPDATE SET
            latitude = excluded.latitude,
            longitude = excluded.longitude,
            altitude = excluded.altitude,
            speed = excluded.speed,
            direction = excluded.direction,
            ignition_status = excluded.ignition_status,
            satellites_count = excluded.satellites_count,
            power_supply_voltage = excluded.power_supply_voltage,
            hdop = excluded.hdop,
            mileage = excluded.mileage
        """,
        [
            (
                object_id,
                p["datetime"],
                p["latitude"],
                p["longitude"],
                p["altitude"],
                p["speed"],
                p["direction"],
                p["ignition_status"],
                p["satellites_count"],
                p["power_supply_voltage"],
                p["hdop"],
                p["mileage"],
            )
            for p in points
        ],
    )
    conn.commit()
    cur.execute("SELECT COUNT(*) FROM coordinates WHERE object_id = ?", (object_id,))
    count_after = cur.fetchone()[0]
    return len(points), count_after - count_before


def main():
    conn = init_db()
    now_str = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    total_vehicles = 0
    total_points = 0

    for api_cfg in FMS_API_KEYS:
        api_key = api_cfg["key"]
        key_name = api_cfg["name"]
        if not api_key:
            continue

        try:
            objects = fetch_objects(api_key)
        except Exception as e:
            logger.error(f"[{key_name}] Failed to fetch objects: {e}")
            continue

        for obj in objects:
            obj_id = obj.get("id")
            obj_name = obj.get("name", "")
            if not obj_id:
                continue

            try:
                upsert_vehicle(conn, obj_id, obj_name, key_name)
                total_vehicles += 1
            except Exception as e:
                logger.error(f"[{key_name}] Failed to upsert vehicle {obj_id}: {e}")
                continue

            from_dt = get_last_datetime(conn, obj_id)
            print(f"[{key_name}] {obj_name} ({obj_id[:8]}...) — fromDatetime: {from_dt}")
            try:
                new_records = fetch_coordinates(conn, api_key, obj_id, from_dt, now_str)
                total_points += new_records
                cur = conn.execute("SELECT COUNT(*) FROM coordinates WHERE object_id = ?", (obj_id,))
                total_in_db = cur.fetchone()[0]
                print(f"  -> +{new_records} new records (total in DB: {total_in_db})")
            except Exception as e:
                logger.error(f"[{key_name}] Failed to fetch coordinates for {obj_id}: {e}")
                print(f"ERROR: {e}")
                continue

    conn.close()
    print(f"Done. Vehicles: {total_vehicles}, Points saved: {total_points}")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        raise
