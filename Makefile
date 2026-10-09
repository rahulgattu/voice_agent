.PHONY: setup check format test requirements up down migrate eval clean

setup:
	uv sync

check:
	uv run ruff check .
	uv run ruff format --check .
	uv run mypy src/
	uv run pytest -q

format:
	uv run ruff check --fix .
	uv run ruff format .

test:
	uv run pytest -q

requirements:
	uv export --no-dev --no-emit-project --no-hashes --format requirements-txt | uv run python -c "import sys; print('# Generated from pyproject.toml and uv.lock. Do not edit.'); print(sys.stdin.read(), end='')"

up:
	uv run docker compose -f deploy/compose.dev.yml up -d

down:
	uv run docker compose -f deploy/compose.dev.yml down

migrate:
	uv run alembic upgrade head

eval:
	uv run python -m receptionistai.cli eval

clean:
	uv run python -c "import shutil; [shutil.rmtree(p, ignore_errors=True) for p in ('build', 'dist', '.pytest_cache', '.mypy_cache', '.ruff_cache')]"
