# Makefile settings
# SHELL := bash
.ONESHELL:

PROJECT_NAME = kria_zynq
XSA_FILE = $(PROJECT_NAME).xsa
BIT_FILE = $(PROJECT_NAME).bit
BIN_FILE = $(PROJECT_NAME).bin
GENERATE_PL_OVERLAY = /workspace/scripts/generate_pl_overlay.py
DEVICETREE_LOG_DIR ?= $(PROJECT_PATH)/output/devicetree-logs
BUILD_PATH_OVERRIDE ?=
GENERATE_PL_OVERLAY_HOST = $(PROJECT_PATH)/scripts/generate_pl_overlay.py
VALIDATE_VIVADO_ARTIFACTS = $(PROJECT_PATH)/scripts/validate_vivado_artifacts.sh

# Host path where artifacts are stored
ARTIFACTS_HOST_DIR = /home/buildserver/artifacts

# Path to artifacts inside the container
ARTIFACTS_CONTAINER_DIR = /artifacts/$(PROJECT_NAME)

DOCKER_IMAGE_VIVADO_NAME = vivado
DOCKER_IMAGE_VIVADO_TAG  = 2025.2

DOCKER_IMAGE_VIVADO = ${DOCKER_IMAGE_VIVADO_NAME}:${DOCKER_IMAGE_VIVADO_TAG}

PROJECT_PATH = $(realpath ../)

# This path must follow scripts/setup_and_build_project.tcl
VIVADO_EXPORT_DIR = vivado
IMPL_RUN_DIR = $(VIVADO_EXPORT_DIR)/$(PROJECT_NAME)/$(PROJECT_NAME).runs/impl_1

# Git information
GIT_BRANCH_RAW  := $(shell git -C $(PROJECT_PATH) rev-parse --abbrev-ref HEAD)
GIT_COMMIT      := $(shell git -C $(PROJECT_PATH) rev-parse --short HEAD)

# Sanitize branch name for filesystem safety
# Replace any character that is not [a-zA-Z0-9_-] with '_'
GIT_BRANCH_SAFE := $(shell echo "$(GIT_BRANCH_RAW)" | sed 's/[^a-zA-Z0-9_-]/_/g')

# Timestamp used for artifact directories
BUILD_TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)

# Final unique build identifier (now just timestamp)
BUILD_ID := $(BUILD_TIMESTAMP)

# Build directory path
BASE_DIR := $(PROJECT_NAME)/$(GIT_BRANCH_SAFE)/$(BUILD_TIMESTAMP)_$(GIT_COMMIT)
BUILD_DIR := $(ARTIFACTS_HOST_DIR)/$(BASE_DIR)
VIVADO_DIR := $(BUILD_DIR)/vivado
DT_DIR := $(BUILD_DIR)/dt
YOCTO_DIR := $(BUILD_DIR)/yocto

# Relative paths for latest files
VIVADO_REL := $(BASE_DIR)/vivado
DT_REL := $(BASE_DIR)/dt
YOCTO_REL := $(BASE_DIR)/yocto

# File storing the most recent successful hardware build folder
LATEST_BUILD_FILE = $(ARTIFACTS_HOST_DIR)/$(PROJECT_NAME)_latest_build.txt

# File storing the most recent successful device tree folder
LATEST_DT_FILE = $(ARTIFACTS_HOST_DIR)/$(PROJECT_NAME)_latest_devicetree.txt


bitstream:
	mkdir -p $(VIVADO_DIR)

	set +e; \
	docker run --network bridge \
		--rm \
		-e LOCAL_UID=$$(id -u) \
		-e LOCAL_GID=$$(id -g) \
		-v ${PROJECT_PATH}:/workspace:rw \
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


devicetree:
	if [ -n "$(BUILD_PATH_OVERRIDE)" ]; then \
		BUILD_PATH_RAW="$(BUILD_PATH_OVERRIDE)"; \
	else \
		test -f $(LATEST_BUILD_FILE); \
		BUILD_PATH_RAW="$$(cat $(LATEST_BUILD_FILE))"; \
	fi
	case "$$BUILD_PATH_RAW" in \
		*/vivado) BUILD_PATH="$$BUILD_PATH_RAW" ;; \
		*) BUILD_PATH="$$BUILD_PATH_RAW/vivado" ;; \
	esac
	DT_BUILD_PATH=$$(dirname "$$BUILD_PATH")/dt
	mkdir -p $(ARTIFACTS_HOST_DIR)/$$DT_BUILD_PATH

	docker run --network bridge \
		--rm \
		-e LOCAL_UID=$$(id -u) \
		-e LOCAL_GID=$$(id -g) \
		-v ${PROJECT_PATH}:/workspace:rw \
		-v $(ARTIFACTS_HOST_DIR):$(ARTIFACTS_CONTAINER_DIR):rw \
		-w /workspace \
		$(DOCKER_IMAGE_VIVADO) \
		bash -lc ' \
			BUILD_PATH='"$$BUILD_PATH"' && \
			DT_BUILD_PATH='"$$DT_BUILD_PATH"' && \
			xsct -eval "sdtgen set_dt_param -xsa $(ARTIFACTS_CONTAINER_DIR)/$$BUILD_PATH/$(XSA_FILE) -dir $(ARTIFACTS_CONTAINER_DIR)/$$DT_BUILD_PATH; sdtgen generate_sdt; exit" && \
			ls $(ARTIFACTS_CONTAINER_DIR)/$$DT_BUILD_PATH \
		' || exit 1

	HOST_PYTHON_BIN=$$(command -v python3 || command -v python || true)
	if [ -z "$$HOST_PYTHON_BIN" ]; then echo "ERROR: no python interpreter found on host"; exit 1; fi
	echo "INFO: Using host Python interpreter $$HOST_PYTHON_BIN"
	"$$HOST_PYTHON_BIN" "$(GENERATE_PL_OVERLAY_HOST)" "$(ARTIFACTS_HOST_DIR)/$$DT_BUILD_PATH/pl.dtsi" "$(ARTIFACTS_HOST_DIR)/$$DT_BUILD_PATH/pl-overlay.dts"

	docker run --network bridge \
		--rm \
		-e LOCAL_UID=$$(id -u) \
		-e LOCAL_GID=$$(id -g) \
		-v ${PROJECT_PATH}:/workspace:rw \
		-v $(ARTIFACTS_HOST_DIR):$(ARTIFACTS_CONTAINER_DIR):rw \
		-w /workspace \
		$(DOCKER_IMAGE_VIVADO) \
		bash -lc ' \
			BUILD_PATH='"$$BUILD_PATH"' && \
			DT_BUILD_PATH='"$$DT_BUILD_PATH"' && \
			gcc -I $(ARTIFACTS_CONTAINER_DIR)/$$DT_BUILD_PATH -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
				-o $(ARTIFACTS_CONTAINER_DIR)/$$DT_BUILD_PATH/system-top.dts.tmp \
				$(ARTIFACTS_CONTAINER_DIR)/$$DT_BUILD_PATH/system-top.dts && \
			dtc -I dts -O dtb \
				-o $(ARTIFACTS_CONTAINER_DIR)/$$DT_BUILD_PATH/system-top.dtb \
				$(ARTIFACTS_CONTAINER_DIR)/$$DT_BUILD_PATH/system-top.dts.tmp && \
			cp $(ARTIFACTS_CONTAINER_DIR)/$$BUILD_PATH/$(BIT_FILE) $(ARTIFACTS_CONTAINER_DIR)/$$DT_BUILD_PATH/$(BIT_FILE) && \
			cp $(ARTIFACTS_CONTAINER_DIR)/$$BUILD_PATH/$(XSA_FILE) $(ARTIFACTS_CONTAINER_DIR)/$$DT_BUILD_PATH/$(XSA_FILE) && \
			if ls $(ARTIFACTS_CONTAINER_DIR)/$$BUILD_PATH/*.ltx >/dev/null 2>&1; then cp $(ARTIFACTS_CONTAINER_DIR)/$$BUILD_PATH/*.ltx $(ARTIFACTS_CONTAINER_DIR)/$$DT_BUILD_PATH/; else echo "No LTX in build artifacts; continuing without debug nets"; fi && \
			ls $(ARTIFACTS_CONTAINER_DIR)/$$DT_BUILD_PATH \
		' || exit 1

	# record the build ID
	printf '%s' "$$DT_BUILD_PATH" > $(LATEST_DT_FILE)

devicetree_logged:
	mkdir -p "$(DEVICETREE_LOG_DIR)"
	LOG_FILE="$(DEVICETREE_LOG_DIR)/devicetree-$$(date +%Y%m%d_%H%M%S).log"
	bash -lc 'set -o pipefail; $(MAKE) devicetree BUILD_PATH_OVERRIDE="$(BUILD_PATH_OVERRIDE)" 2>&1 | tee "$$0"' "$$LOG_FILE"
	printf 'Devicetree log: %s\n' "$$LOG_FILE"

# Run fast unit tests locally — no Docker, no Vivado, no Yocto.
# Tests mock the sysfs/configfs filesystem in /tmp and run in seconds.
# Requires: sh (dash/bash), dtc optional (overlay compilation tests skip if absent).
test:
	@echo "Running hermes unit tests..."
	bash $(PROJECT_PATH)/tests/run_tests.sh