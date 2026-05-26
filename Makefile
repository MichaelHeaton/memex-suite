.DEFAULT_GOAL := help
SHELL         := /bin/bash

LOCALSTACK_URL ?= http://localhost:4566
SAM_STACK_DEV  ?= memex-dev
SAM_STACK_PROD ?= memex-prod
AWS_REGION     ?= us-east-1
PYTHON         ?= python3
SAM_TEMPLATE   ?= infrastructure/template.yaml
SAM_BUILD_TEMPLATE ?= .aws-sam/build/template.yaml
SERVICE_REQUIREMENTS := $(wildcard services/*/requirements.txt)

# ── Help ──────────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Deferred local environment ────────────────────────────────────────────────
.PHONY: dev
dev: ## Start optional local stack (deferred; AWS deploy is the primary path)
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
install: ## Install dev tooling and service runtime dependencies
	$(PYTHON) -m pip install --upgrade pip
	$(PYTHON) -m pip install -e ".[dev]"
	@for req in $(SERVICE_REQUIREMENTS); do \
	  echo "Installing $$req"; \
	  $(PYTHON) -m pip install -r $$req; \
	done

.PHONY: lint
lint: ## Run ruff linter + formatter check
	$(PYTHON) -m ruff check .
	$(PYTHON) -m ruff format --check .

.PHONY: fmt
fmt: ## Auto-format with ruff
	$(PYTHON) -m ruff format .
	$(PYTHON) -m ruff check --fix .

.PHONY: test
test: ## Run all tests
	$(PYTHON) -m pytest

.PHONY: test-cov
test-cov: ## Run tests with coverage report
	$(PYTHON) -m pytest --cov=services --cov=shared --cov-report=term-missing

# ── SAM build & deploy ────────────────────────────────────────────────────────
.PHONY: build-SourceRegistryFunction
build-SourceRegistryFunction: ## SAM custom build target for SourceRegistryFunction
	cp -r services/source-registry/src $(ARTIFACTS_DIR)/src
	cp -r shared $(ARTIFACTS_DIR)/shared
	$(PYTHON) -m pip install -r services/source-registry/requirements.txt -t $(ARTIFACTS_DIR) --quiet

.PHONY: build
build: ## Build all Lambda functions with SAM
	sam build --template-file $(SAM_TEMPLATE)

.PHONY: deploy-local
deploy-local: build ## Deploy to LocalStack (requires dev stack running)
	AWS_ENDPOINT_URL=$(LOCALSTACK_URL) sam deploy \
	  --template-file $(SAM_BUILD_TEMPLATE) \
	  --stack-name $(SAM_STACK_DEV) \
	  --resolve-s3 \
	  --no-confirm-changeset \
	  --no-fail-on-empty-changeset \
	  --region $(AWS_REGION)

.PHONY: deploy-aws
deploy-aws: build ## Deploy to real AWS (requires AWS_PROFILE or credentials)
	sam deploy \
	  --template-file $(SAM_BUILD_TEMPLATE) \
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
