.DEFAULT_GOAL := help
SHELL         := /bin/bash

LOCALSTACK_URL ?= http://localhost:4566
SAM_STACK_DEV  ?= memex-dev
SAM_STACK_PROD ?= memex-prod
AWS_REGION     ?= us-east-1

# ── Help ──────────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Dev environment ───────────────────────────────────────────────────────────
.PHONY: dev
dev: ## Start local dev stack (LocalStack + Postgres + Vault + Traefik)
	docker compose up -d
	@echo "LocalStack: http://localhost:4566"
	@echo "Vault:      http://localhost:8200"
	@echo "Postgres:   localhost:5432"

.PHONY: stop
stop: ## Stop local dev stack
	docker compose down

.PHONY: logs
logs: ## Tail docker compose logs
	docker compose logs -f

# ── Python tooling ─────────────────────────────────────────────────────────────
.PHONY: install
install: ## Install dev dependencies via uv (or pip if uv not available)
	@if command -v uv &>/dev/null; then \
	  uv pip install -e ".[dev]"; \
	else \
	  pip install -e ".[dev]"; \
	fi

.PHONY: lint
lint: ## Run ruff linter + formatter check
	ruff check .
	ruff format --check .

.PHONY: fmt
fmt: ## Auto-format with ruff
	ruff format .
	ruff check --fix .

.PHONY: test
test: ## Run all tests
	pytest

.PHONY: test-cov
test-cov: ## Run tests with coverage report
	pytest --cov=services --cov=shared --cov-report=term-missing

# ── SAM build & deploy ────────────────────────────────────────────────────────
.PHONY: build
build: ## Build all Lambda functions with SAM
	sam build

.PHONY: deploy-local
deploy-local: build ## Deploy to LocalStack (requires dev stack running)
	AWS_ENDPOINT_URL=$(LOCALSTACK_URL) sam deploy \
	  --stack-name $(SAM_STACK_DEV) \
	  --resolve-s3 \
	  --no-confirm-changeset \
	  --no-fail-on-empty-changeset \
	  --region $(AWS_REGION)

.PHONY: deploy-aws
deploy-aws: build ## Deploy to real AWS (requires AWS_PROFILE or credentials)
	sam deploy \
	  --stack-name $(SAM_STACK_PROD) \
	  --resolve-s3 \
	  --no-confirm-changeset \
	  --no-fail-on-empty-changeset \
	  --region $(AWS_REGION) \
	  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

# ── Utilities ─────────────────────────────────────────────────────────────────
.PHONY: clean
clean: ## Remove build artifacts
	rm -rf .aws-sam/
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.pyc" -delete 2>/dev/null || true
