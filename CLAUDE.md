# Memex Suite

Personal knowledge and operations platform. Nine microservices with a unified MCP gateway, deployed as Lambda functions via AWS SAM.

## Stack

- **Language**: Python 3.12 + FastAPI
- **Lambda adapter**: Mangum (ASGI → Lambda event)
- **Database**: Aurora Serverless v2 (PostgreSQL 16) via RDS Proxy; SQLite in tests
- **IaC**: AWS SAM (`infrastructure/template.yaml`)
- **CI/CD**: GitHub Actions (`.github/workflows/`)
- **Primary environment**: AWS via SAM and GitHub Actions
- **Local dev**: LocalStack/docker-compose scaffolding exists but is deferred
- **Secrets**: HashiCorp Vault (dev mode locally; production endpoint via SSM)

## Repository layout

```
services/{service-name}/
  src/
    app.py        FastAPI app, routes wired here
    handler.py    Lambda entry point (Mangum wrapper)
    models.py     SQLAlchemy ORM + Pydantic schemas
    database.py   Engine, session factory, init_db()
    routes/
      sources.py  Route handlers
      health.py   GET /v1/health
  tests/
    conftest.py   sys.path setup, SQLite fixtures, TestClient
    test_*.py
  requirements.txt
  Makefile        SAM build target (build-{FunctionName})

shared/
  health.py       Standard health check response builder
  responses.py    MCP envelope schema

infrastructure/
  template.yaml   Root SAM template — add new functions here

bootstrap/        (none — owned by platform-bootstrap)
```

## Common commands

```bash
make install       # install dev tooling + service runtime deps
make test          # run all tests
make lint          # ruff check
make build         # sam build using infrastructure/template.yaml
make deploy-aws    # deploy to AWS (requires credentials)
```

LocalStack/docker-compose commands are available but are not the current
delivery path. Do not let local environment work block AWS deployment work.

## Adding a new service

1. Copy `services/source-registry/` as a template
2. Rename the SAM function in the service `Makefile` (`build-{FunctionName}`)
3. Add the function resource to `infrastructure/template.yaml`
4. Register the service in the MCP gateway

## Imports

- Within a service: relative (`from .models import`, `from ..database import`)
- Shared utilities: absolute (`from shared.health import`) — works at runtime because SAM build copies `shared/` alongside `src/` in the artifact

## Tests

- Uses SQLite in-memory (not PostgreSQL) — SQLAlchemy abstracts the difference
- Each test gets a fresh transaction that rolls back on teardown
- `app.dependency_overrides[get_session]` injects the test session

## API conventions

- All routes versioned: `/v1/{resource}`
- Every service exposes `GET /v1/health`
- Timestamps in ISO 8601 with timezone
- Soft deletes: deactivate/archive, never hard delete
- `created_by` / `updated_by` on all mutable records (contact_id string or `"system"`)

## AWS credentials

Manual AWS deploys: set `AWS_PROFILE` or use `aws configure` with IAM keys for
your personal account.

The GitHub Actions deploy role and SAM artifacts bucket are owned by **platform-bootstrap** — not this repo. After running `terraform apply` in platform-bootstrap, copy `service_deploy_role_arns["memex-suite"]` from its outputs and add it as `AWS_DEPLOY_ROLE_ARN` in this repo's GitHub Actions secrets. The `service_artifact_buckets["memex-suite"]` output gives the SAM bucket name to pass via `--s3-bucket`.
