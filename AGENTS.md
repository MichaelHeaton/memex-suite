# Memex Suite — Agent Instructions

See `CLAUDE.md` and `README.md` for full project documentation and common commands.

## Cursor Cloud specific instructions

### Running the source-registry service locally

The only implemented service is `source-registry`. To run it locally without Docker/PostgreSQL:

```bash
cd /workspace
PYTHONPATH=/workspace/services/source-registry:/workspace \
  DATABASE_URL="sqlite:///source_registry_dev.db" \
  python3 -m uvicorn src.app:app --host 0.0.0.0 --port 8000 --reload
```

- `PYTHONPATH` must include both the service root (for `from src.…` imports) and the workspace root (for `from shared.…` imports).
- `DATABASE_URL` with a SQLite URI avoids the need for a running PostgreSQL instance. Tests already use SQLite in-memory via `conftest.py`, so this is safe for local development.
- `uvicorn` is not in `pyproject.toml` dev deps — install it with `pip install uvicorn` if missing.

### Tests and lint

- `make test` — runs pytest across all services using SQLite in-memory; no external services needed.
- `make lint` — runs `ruff check` and `ruff format --check`.
- Both commands match the CI pipeline in `.github/workflows/test.yml`.

### Gotchas

- The `services/source-registry` directory has a hyphen in its name. Python cannot import it as a dotted module path (e.g., `services.source-registry.src.app` will fail). Always set `PYTHONPATH` and use `src.app:app` as the uvicorn target.
- Only `source-registry` has code; the other 10 service directories contain only `.gitkeep` placeholder files.
- The `shared/` directory must be importable at runtime. Setting `PYTHONPATH` to include `/workspace` handles this.
