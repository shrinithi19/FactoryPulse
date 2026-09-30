"""
Populates the database with demo machines, sensors, and users so the
platform is explorable immediately after `make demo`, without needing
real telemetry flowing yet.

Run:
    python scripts/seed_assets.py
(reads DB_* from the environment / .env — see .env.example)
"""

from __future__ import annotations

import os

import bcrypt
import psycopg2

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "localhost"),
    "port": os.environ.get("DB_PORT", "5432"),
    "user": os.environ.get("DB_USER", "factorypulse"),
    "password": os.environ.get("DB_PASS", "fp_dev_2024"),
    "dbname": os.environ.get("DB_NAME", "factorypulse"),
}

# id, machine_class, location
MACHINES = [
    ("CNC-07", "CNC_Mill", "Plant-A / Bay-3"),
    ("CNC-12", "CNC_Mill", "Plant-A / Bay-5"),
    ("TURB-01", "Turbofan", "Plant-B / Engine-Bay"),
    ("TURB-02", "Turbofan", "Plant-B / Engine-Bay"),
    ("BRG-04", "Bearing_Rig", "Plant-A / Test-Lab"),
    ("PUMP-09", "Centrifugal_Pump", "Plant-C / Utility"),
]

# sensor type -> (unit, min_valid, max_valid) — physical plausibility
# bounds used by the ingestion service (M2) to reject out-of-range readings.
SENSOR_SPECS = {
    "temperature": ("C", -40.0, 400.0),
    "vibration": ("mm/s", 0.0, 50.0),
    "pressure": ("bar", 0.0, 300.0),
    "rpm": ("rpm", 0.0, 20000.0),
    "current": ("A", 0.0, 500.0),
}

# username, role
USERS = [
    ("tech_arun", "technician"),
    ("eng_priya", "engineer"),
    ("mgr_raj", "manager"),
    ("ds_meera", "data_scientist"),
    ("admin_sys", "admin"),
]

# Demo-only default password — every seeded user shares this locally.
# Never used outside local/dev seeding; production auth issues its own
# credentials.
DEMO_PASSWORD = "factorypulse_demo"


def seed(conn) -> None:
    with conn.cursor() as cur:
        for machine_id, machine_class, location in MACHINES:
            cur.execute(
                """
                INSERT INTO machines (id, machine_class, location, install_date, status)
                VALUES (%s, %s, %s, CURRENT_DATE, 'active')
                ON CONFLICT (id) DO NOTHING
                """,
                (machine_id, machine_class, location),
            )

            for sensor_type, (unit, min_v, max_v) in SENSOR_SPECS.items():
                sensor_id = f"{machine_id}-{sensor_type}"
                cur.execute(
                    """
                    INSERT INTO sensors (id, machine_id, type, unit, min_valid, max_valid)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    ON CONFLICT (machine_id, type) DO NOTHING
                    """,
                    (sensor_id, machine_id, sensor_type, unit, min_v, max_v),
                )

        password_hash = bcrypt.hashpw(DEMO_PASSWORD.encode(), bcrypt.gensalt()).decode()
        for username, role in USERS:
            user_id = f"user-{username}"
            cur.execute(
                """
                INSERT INTO users (id, username, password_hash, role)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (username) DO NOTHING
                """,
                (user_id, username, password_hash, role),
            )

    conn.commit()
    print(
        f"[seed] {len(MACHINES)} machines, "
        f"{len(MACHINES) * len(SENSOR_SPECS)} sensors, "
        f"{len(USERS)} users seeded "
        f"(demo password for all seeded users: '{DEMO_PASSWORD}')"
    )


def main() -> None:
    conn = psycopg2.connect(**DB_CONFIG)
    try:
        seed(conn)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
