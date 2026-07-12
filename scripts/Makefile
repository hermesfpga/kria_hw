# Makefile settings
# SHELL := bash
.ONESHELL:

PROJECT_PATH = $(realpath ../)
VIVADO_IP_CACHE = "/home/buildserver/vivado_cache"

# Host path where artifacts are stored
ARTIFACTS_HOST_DIR = /home/buildserver/artifacts/$(REPO_NAME)
REPO_NAME = kria_hw
PROJECT_NAME = kria_zynq

# Git information
GIT_BRANCH_RAW  := $(shell git -C $(PROJECT_PATH) rev-parse --abbrev-ref HEAD)
GIT_COMMIT      := $(shell git -C $(PROJECT_PATH) rev-parse --short HEAD)

# Timestamp used for artifact directories
BUILD_TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)
# Final unique build identifier (now just timestamp)
BUILD_ID := $(BUILD_TIMESTAMP)

# Sanitize branch name for filesystem safety
# Replace any character that is not [a-zA-Z0-9_-] with '_'
GIT_BRANCH_SAFE := $(shell echo "$(GIT_BRANCH_RAW)" | sed 's/[^a-zA-Z0-9_-]/_/g')
XSA_FILE = $(PROJECT_NAME).xsa
BIT_FILE = $(PROJECT_NAME).bit
BIN_FILE = $(PROJECT_NAME).bin

# Path to artifacts inside the container
ARTIFACTS_CONTAINER_DIR = /artifacts/$(PROJECT_NAME)
VIVADO_CACHE_CONTAINER_DIR = /vivado_cache

# Docker container
DOCKER_IMAGE_VIVADO_NAME = vivado
DOCKER_IMAGE_VIVADO_TAG  = 2025.2
DOCKER_IMAGE_VIVADO = ${DOCKER_IMAGE_VIVADO_NAME}:${DOCKER_IMAGE_VIVADO_TAG}

# This path must follow scripts/setup_and_build_project.tcl
VIVADO_EXPORT_DIR = vivado
IMPL_RUN_DIR = $(VIVADO_EXPORT_DIR)/$(PROJECT_NAME)/$(PROJECT_NAME).runs/impl_1

VALIDATE_VIVADO_ARTIFACTS = $(PROJECT_PATH)/scripts/validate_vivado_artifacts.sh

# Build directory path
BASE_DIR := $(PROJECT_NAME)/$(GIT_BRANCH_SAFE)/$(BUILD_TIMESTAMP)_$(GIT_COMMIT)
BUILD_DIR := $(ARTIFACTS_HOST_DIR)/$(BASE_DIR)
VIVADO_DIR := $(BUILD_DIR)/vivado
DT_DIR := $(BUILD_DIR)/dt
YOCTO_DIR := $(BUILD_DIR)/yocto

# Relative paths for latest files
VIVADO_REL := $(BASE_DIR)/vivado

# File storing the most recent successful hardware build folder
LATEST_BUILD_FILE = $(ARTIFACTS_HOST_DIR)/$(PROJECT_NAME)_latest_build.txt


bitstream:
	mkdir -p $(VIVADO_DIR)

	set +e; \
	docker run --network bridge \
		--rm \
		-e LOCAL_UID=$$(id -u) \
		-e LOCAL_GID=$$(id -g) \
		-v ${PROJECT_PATH}:/workspace:rw \
		-v $(VIVADO_IP_CACHE):$(VIVADO_CACHE_CONTAINER_DIR):rw \
		-v $(ARTIFACTS_HOST_DIR):$(ARTIFACTS_CONTAINER_DIR):rw \
		-w /workspace \
		$(DOCKER_IMAGE_VIVADO) \
		bash -lc ' \
			vivado -mode batch -notrace -source ./scripts/create_project_and_gen_bitstream.tcl \
				2>&1 | tee $(ARTIFACTS_CONTAINER_DIR)/$(VIVADO_REL)/vivado.log ; \
			cp $(VIVADO_EXPORT_DIR)/$(XSA_FILE) $(ARTIFACTS_CONTAINER_DIR)/$(VIVADO_REL)/$(XSA_FILE) && \
			cp $(VIVADO_EXPORT_DIR)/$(BIT_FILE) $(ARTIFACTS_CONTAINER_DIR)/$(VIVADO_REL)/$(BIT_FILE) && \
			if ls $(IMPL_RUN_DIR)/*.ltx >/dev/null 2>&1; then cp $(IMPL_RUN_DIR)/*.ltx $(ARTIFACTS_CONTAINER_DIR)/$(VIVADO_REL)/; else echo "No LTX file found in $(IMPL_RUN_DIR); continuing without debug nets"; fi && \
			echo 'all: { [destination_device=pl] $(ARTIFACTS_CONTAINER_DIR)/$(VIVADO_REL)/$(BIT_FILE) }' > /tmp/$(PROJECT_NAME).bif && \
			bootgen -arch zynqmp -image /tmp/$(PROJECT_NAME).bif -process_bitstream bin -o $(ARTIFACTS_CONTAINER_DIR)/$(VIVADO_REL)/$(BIN_FILE) -w on && \
			ls -l $(ARTIFACTS_CONTAINER_DIR)/$(VIVADO_REL) \
		' ; \
	STATUS=$$?; \
	set -e; \
	echo $$STATUS > $(VIVADO_DIR)/vivado-status.txt; \
	if [ "$$STATUS" -ne 0 ]; then echo "Vivado build failed with status $$STATUS" >&2; exit $$STATUS; fi; \
	bash $(VALIDATE_VIVADO_ARTIFACTS) $(ARTIFACTS_HOST_DIR)/$(VIVADO_REL)/$(BIT_FILE) $(ARTIFACTS_HOST_DIR)/$(VIVADO_REL)/$(XSA_FILE); \
	printf '%s' "$(VIVADO_REL)" > $(LATEST_BUILD_FILE)

	# allow the build to fail but still run report from CI with `make report`


# generate a formatted error/warning report and (optionally) append to
# the GitHub Actions step summary.  Accepts BUILD_ID as an environment
# variable or will read the latest if unspecified.
report:
	@BUILD_PATH=$${BUILD_ID:-$$(cat $(LATEST_BUILD_FILE))}; \
	LOG=$(ARTIFACTS_HOST_DIR)/$$BUILD_PATH/vivado.log; \
	STATUS_FILE=$(ARTIFACTS_HOST_DIR)/$$BUILD_PATH/vivado-status.txt; \
	REP=$(ARTIFACTS_HOST_DIR)/$$BUILD_PATH/vivado-report.txt; \
	if [ -f "$$LOG" ]; then \
		STATUS=$$(cat $$STATUS_FILE 2>/dev/null || echo "1"); \
		{ \
			echo "### Vivado run summary"; \
			echo ""; \
			grep "Failing Nets\|Worst Negative Slack" "$$LOG" || echo "(no summary found)"; \
			echo ""; \
			echo "### Errors and Warnings"; \
			echo ""; \
			grep -E "ERROR:|CRITICAL WARNING" "$$LOG" || echo "(no errors or warnings)"; \
		} > "$$REP"; \
		echo "Generated report $$REP"; \
		if [ -n "$$GITHUB_STEP_SUMMARY" ]; then \
			echo "" >> $$GITHUB_STEP_SUMMARY; \
			cat "$$REP" >> $$GITHUB_STEP_SUMMARY; \
		fi; \
	else \
		echo "no log file for build $$BUILD_PATH"; \
		exit 1; \
	fi