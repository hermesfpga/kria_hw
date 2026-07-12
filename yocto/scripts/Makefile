# Makefile for Yocto builds
# SHELL := bash
.ONESHELL:

PROJECT_NAME = kria_zynq

# Host path where artifacts are stored
ARTIFACTS_HOST_DIR ?= /home/buildserver/artifacts

# Path to artifacts inside the container
ARTIFACTS_CONTAINER_DIR = /artifacts

# Path to the custom bitstream/DT layer
LAYER_PATH = $(realpath ../meta-custom-bitstream)
LAYER_CONTAINER_PATH = /workspace/meta-custom-bitstream

# Path to in-container Yocto build helper script
BUILD_SD_BOOT_SCRIPT_HOST = $(realpath ./build_sd_boot.sh)
BUILD_SD_BOOT_SCRIPT_CONTAINER = /workspace/build_sd_boot.sh
GENERATE_PL_OVERLAY_HOST = $(abspath ../../scripts/generate_pl_overlay.py)

# Yocto build settings
DOCKER_IMAGE_YOCTO_NAME ?= yocto_builder
DOCKER_IMAGE_YOCTO_TAG  ?= v1
DOCKER_IMAGE_YOCTO      = $(DOCKER_IMAGE_YOCTO_NAME):$(DOCKER_IMAGE_YOCTO_TAG)

YOCTO_CACHE_HOST_DIR     ?= /home/buildserver/yocto_cache
YOCTO_DOWNLOADS_HOST_DIR = $(YOCTO_CACHE_HOST_DIR)/downloads
YOCTO_SSTATE_HOST_DIR    = $(YOCTO_CACHE_HOST_DIR)/sstate

YOCTO_DOWNLOADS_DIR = /yocto-downloads
YOCTO_SSTATE_DIR    = /yocto-sstate

YOCTO_MACHINE = hermes-k26
YOCTO_IMAGE   = kria-image-full-cmdline
YOCTO_DTS_NAME ?= system-top.dts
YOCTO_DTB_NAME ?= system-top.dtb

# File storing the most recent successful device tree folder
LATEST_DT_FILE = $(ARTIFACTS_HOST_DIR)/$(PROJECT_NAME)_latest_devicetree.txt

# File storing the most recent successful hardware build folder
LATEST_BUILD_FILE = $(ARTIFACTS_HOST_DIR)/$(PROJECT_NAME)_latest_build.txt

# File storing the most recent successful Yocto build folder
LATEST_YOCTO_BUILD_FILE = $(ARTIFACTS_HOST_DIR)/$(PROJECT_NAME)_latest_yocto_build.txt

# Local developer workflow (no push required): build from workspace and stage
# artifacts under output/yocto-local.
LOCAL_ARTIFACTS_HOST_DIR ?= $(abspath ../../output/yocto-local)
LOCAL_YOCTO_CACHE_HOST_DIR ?= $(abspath ../../.cache/yocto)
LOCAL_YOCTO_DOWNLOADS_HOST_DIR ?= $(LOCAL_YOCTO_CACHE_HOST_DIR)/downloads
LOCAL_YOCTO_SSTATE_HOST_DIR ?= $(LOCAL_YOCTO_CACHE_HOST_DIR)/sstate
LOCAL_DT_DIR ?= $(abspath ../../dt_example/dt)
LOCAL_YOCTO_BUILD_PATH ?= local/$(shell date +%Y%m%d_%H%M%S)/yocto
LOCAL_LATEST_YOCTO_BUILD_FILE ?= $(LOCAL_ARTIFACTS_HOST_DIR)/$(PROJECT_NAME)_latest_yocto_build.txt

build_yocto:
	set -e
	test -f $(LATEST_DT_FILE)
	test -f $(LATEST_BUILD_FILE)
	test -f $(BUILD_SD_BOOT_SCRIPT_HOST)
	DT_BUILD_PATH="$$(cat $(LATEST_DT_FILE))"
	BUILD_PATH="$$(cat $(LATEST_BUILD_FILE))"
	# BUILD_PATH points at the vivado subfolder; take its parent to keep the
	# timestamp/commit directory, then add yocto/
	YOCTO_BUILD_PATH=$$(dirname "$$BUILD_PATH")/yocto
	@echo "DEBUG: DT_BUILD_PATH=$$DT_BUILD_PATH"
	@echo "DEBUG: BUILD_PATH=$$BUILD_PATH"
	@echo "DEBUG: YOCTO_BUILD_PATH=$$YOCTO_BUILD_PATH"
	mkdir -p $(ARTIFACTS_HOST_DIR)/$$YOCTO_BUILD_PATH
	touch $(ARTIFACTS_HOST_DIR)/$$YOCTO_BUILD_PATH/yocto.log
	YOCTO_LOG_PATH="$(ARTIFACTS_HOST_DIR)/$$YOCTO_BUILD_PATH/yocto.log"
	@echo "Running Yocto build. Log: $$YOCTO_LOG_PATH"
	DOCKER_EXIT=0
	docker run --rm \
		-e LOCAL_UID=$$(id -u) \
		-e LOCAL_GID=$$(id -g) \
		-e YOCTO_IMAGE="$(YOCTO_IMAGE)" \
		-e YOCTO_MACHINE="$(YOCTO_MACHINE)" \
		-e YOCTO_DTS_NAME="$(YOCTO_DTS_NAME)" \
		-e YOCTO_DTB_NAME="$(YOCTO_DTB_NAME)" \
		-e LAYER_CONTAINER_PATH="$(LAYER_CONTAINER_PATH)" \
		-e ARTIFACTS_CONTAINER_DIR="$(ARTIFACTS_CONTAINER_DIR)" \
		-e YOCTO_BUILD_PATH="$$YOCTO_BUILD_PATH" \
		-v $(ARTIFACTS_HOST_DIR):$(ARTIFACTS_CONTAINER_DIR):rw \
		-v $(YOCTO_DOWNLOADS_HOST_DIR):$(YOCTO_DOWNLOADS_DIR) \
		-v $(YOCTO_SSTATE_HOST_DIR):$(YOCTO_SSTATE_DIR) \
		-v "$(ARTIFACTS_HOST_DIR)/$$DT_BUILD_PATH":/dt:rw \
		-v "$(LAYER_PATH)":$(LAYER_CONTAINER_PATH):ro \
		-v "$(BUILD_SD_BOOT_SCRIPT_HOST)":$(BUILD_SD_BOOT_SCRIPT_CONTAINER):ro \
		$(DOCKER_IMAGE_YOCTO) \
		bash -lc "tr -d '\\r' < $(BUILD_SD_BOOT_SCRIPT_CONTAINER) > /tmp/build_sd_boot.sh && chmod +x /tmp/build_sd_boot.sh && /tmp/build_sd_boot.sh" || DOCKER_EXIT=$$?
	if [ $$DOCKER_EXIT -ne 0 ]; then \
		echo "ERROR: Yocto docker build failed with exit code $$DOCKER_EXIT"; \
		if [ -f "$$YOCTO_LOG_PATH" ]; then \
			echo "Last 80 lines of $$YOCTO_LOG_PATH:"; \
			tail -n 80 "$$YOCTO_LOG_PATH" || true; \
		fi; \
		exit $$DOCKER_EXIT; \
	fi

	# record the build ID even if bitbake failed
	printf '%s' "$$YOCTO_BUILD_PATH" > $(LATEST_YOCTO_BUILD_FILE)

build_yocto_local:
	set -e
	test -d "$(LOCAL_DT_DIR)"
	test -f $(BUILD_SD_BOOT_SCRIPT_HOST)
	test -f $(GENERATE_PL_OVERLAY_HOST)
	PYTHON_BIN=$$(command -v python3 || command -v python || true)
	if [ -z "$$PYTHON_BIN" ]; then echo "ERROR: no python interpreter found on host"; exit 1; fi
	@echo "Using Python interpreter $$PYTHON_BIN"
	"$$PYTHON_BIN" "$(GENERATE_PL_OVERLAY_HOST)" "$(LOCAL_DT_DIR)/pl.dtsi" "$(LOCAL_DT_DIR)/pl-overlay.dts"
	mkdir -p "$(LOCAL_ARTIFACTS_HOST_DIR)/$(LOCAL_YOCTO_BUILD_PATH)"
	mkdir -p "$(LOCAL_YOCTO_DOWNLOADS_HOST_DIR)" "$(LOCAL_YOCTO_SSTATE_HOST_DIR)"
	touch "$(LOCAL_ARTIFACTS_HOST_DIR)/$(LOCAL_YOCTO_BUILD_PATH)/yocto.log"
	YOCTO_LOG_PATH="$(LOCAL_ARTIFACTS_HOST_DIR)/$(LOCAL_YOCTO_BUILD_PATH)/yocto.log"
	@echo "Running local Yocto build. Log: $$YOCTO_LOG_PATH"
	DOCKER_EXIT=0
	docker run --rm \
		-e LOCAL_UID=$$(id -u) \
		-e LOCAL_GID=$$(id -g) \
		-e YOCTO_IMAGE="$(YOCTO_IMAGE)" \
		-e YOCTO_MACHINE="$(YOCTO_MACHINE)" \
		-e YOCTO_DTS_NAME="$(YOCTO_DTS_NAME)" \
		-e YOCTO_DTB_NAME="$(YOCTO_DTB_NAME)" \
		-e LAYER_CONTAINER_PATH="$(LAYER_CONTAINER_PATH)" \
		-e ARTIFACTS_CONTAINER_DIR="$(ARTIFACTS_CONTAINER_DIR)" \
		-e YOCTO_BUILD_PATH="$(LOCAL_YOCTO_BUILD_PATH)" \
		-v "$(LOCAL_ARTIFACTS_HOST_DIR)":$(ARTIFACTS_CONTAINER_DIR):rw \
		-v "$(LOCAL_YOCTO_DOWNLOADS_HOST_DIR)":$(YOCTO_DOWNLOADS_DIR) \
		-v "$(LOCAL_YOCTO_SSTATE_HOST_DIR)":$(YOCTO_SSTATE_DIR) \
		-v "$(LOCAL_DT_DIR)":/dt:rw \
		-v "$(LAYER_PATH)":$(LAYER_CONTAINER_PATH):ro \
		-v "$(BUILD_SD_BOOT_SCRIPT_HOST)":$(BUILD_SD_BOOT_SCRIPT_CONTAINER):ro \
		$(DOCKER_IMAGE_YOCTO) \
		bash -lc "tr -d '\\r' < $(BUILD_SD_BOOT_SCRIPT_CONTAINER) > /tmp/build_sd_boot.sh && chmod +x /tmp/build_sd_boot.sh && /tmp/build_sd_boot.sh" || DOCKER_EXIT=$$?
	if [ $$DOCKER_EXIT -ne 0 ]; then \
		echo "ERROR: Local Yocto docker build failed with exit code $$DOCKER_EXIT"; \
		if [ -f "$$YOCTO_LOG_PATH" ]; then \
			echo "Last 80 lines of $$YOCTO_LOG_PATH:"; \
			tail -n 80 "$$YOCTO_LOG_PATH" || true; \
		fi; \
		exit $$DOCKER_EXIT; \
	fi

	printf '%s' "$(LOCAL_YOCTO_BUILD_PATH)" > $(LOCAL_LATEST_YOCTO_BUILD_FILE)
	@echo "Local Yocto build complete."
	@echo "Log: $(LOCAL_ARTIFACTS_HOST_DIR)/$(LOCAL_YOCTO_BUILD_PATH)/yocto.log"
	@echo "Boot artifacts: $(LOCAL_ARTIFACTS_HOST_DIR)/$(LOCAL_YOCTO_BUILD_PATH)/boot"

# generate a formatted error/warning report and (optionally) append to
# the GitHub Actions step summary.  Accepts BUILD_ID as an environment
# variable or will read the latest if unspecified.
report:
	@BUILD_PATH=$${BUILD_ID:-$$(cat $(LATEST_YOCTO_BUILD_FILE))}; \
	LOG=$(ARTIFACTS_HOST_DIR)/$$BUILD_PATH/yocto.log; \
	REP=$(ARTIFACTS_HOST_DIR)/$$BUILD_PATH/yocto-report.txt; \
	if [ -f "$$LOG" ]; then \
		{ \
			echo "### Yocto run summary"; \
			echo ""; \
			grep -E "ERROR:|WARNING:" "$$LOG" | head -20 || echo "(no errors or warnings found)"; \
			echo ""; \
			echo "### Build Status"; \
			echo ""; \
			tail -5 "$$LOG" | grep -E "Tasks Summary|failed|succeeded" || echo "(build status unknown)"; \
		} > "$$REP"; \
		echo "Generated report $$REP"; \
		if [ -n "$$GITHUB_STEP_SUMMARY" ]; then \
			echo "" >> $$GITHUB_STEP_SUMMARY; \
			cat "$$REP" >> $$GITHUB_STEP_SUMMARY; \
		fi; \
	else \
		echo "no log file at $$LOG"; \
		exit 1; \
	fi
