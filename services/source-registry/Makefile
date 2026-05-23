# SAM build target. Called by `sam build` when BuildMethod: makefile is set.
# ARTIFACTS_DIR is set by SAM to the target build directory for this function.
#
# Structure produced:
#   $(ARTIFACTS_DIR)/
#     src/           ← service code (handler, app, models, etc.)
#     shared/        ← repo-level shared utilities
#
# Lambda handler: src.handler.handler

.PHONY: build-SourceRegistryFunction
build-SourceRegistryFunction:
	cp -r src $(ARTIFACTS_DIR)/src
	cp -r ../../shared $(ARTIFACTS_DIR)/shared
	pip install -r requirements.txt -t $(ARTIFACTS_DIR) --quiet
