.PHONY: infra up down seed test lint demo clean

# Start the 5 infrastructure containers only (TimescaleDB, Redis, Qdrant, Mosquitto, MLflow).
infra:
	docker compose up -d

# Build + start all services (infra + application services, once they exist from M2).
up:
	docker compose up -d --build

down:
	docker compose down

# Populate the DB with demo machines, sensors, and users.
seed:
	python scripts/seed_assets.py

test:
	pytest tests/unit tests/integration -v

lint:
	ruff check .
	mypy ml/src services/*/src || true

# Full launch: infra + seed + up.
demo: infra seed up

clean:
	docker compose down -v
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
