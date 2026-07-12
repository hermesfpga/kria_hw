# hermes-fpga-trader

FPGA reference project for high-frequency trading on Xilinx Kria KR260. This repository contains source HDL, block design scripts, and utility Tcl scripts used to recreate and build the Vivado project. The design is a self-study and experimental platform for low-latency market data processing, 10 GbE networking, and Zynq real‑time control.

## Structure

```
/scripts                     # Vivado hardware + DT build scripts
/src                         # HDL, constraints, and block design
/vivado                      # generated Vivado project (ignored)
/yocto                       # Yocto/Linux build system
  /scripts                   # Yocto Makefile + build_sd_boot.sh helper
  /meta-custom-bitstream     # reusable Yocto layer (bitstream + DT recipe)
/docs                        # project docs/notes
```

## Build Overview

The project has two independent build workflows:

### 1. Hardware Build (Vivado)

Generates FPGA bitstream and device tree:

```sh
cd scripts
make build_bitstream     # Vivado synthesis, implementation, bitstream
make devicetree          # Generate system device tree from .xsa
```

Outputs are grouped per build under one timestamp+commit directory:

```
/home/buildserver/artifacts/kria_zynq/<branch>/<timestamp>_<commit>/
  vivado/
  dt/
```

### 2. Linux Image Build (Yocto)

Builds a complete Linux image with your custom bitstream and SDT-integrated device tree:

```sh
cd yocto/scripts
make build_yocto         # Bitbake image (mounts DT artifacts, installs them)
# optional per-run DT names:
# make build_yocto YOCTO_DTS_NAME=system-top.dts YOCTO_DTB_NAME=system-top.dtb
```

Yocto logs and reports for that same build are written to:

```
/home/buildserver/artifacts/kria_zynq/<branch>/<timestamp>_<commit>/yocto/
```

Bootable Yocto disk image output is exported to:

```
/home/buildserver/artifacts/kria_zynq/<branch>/<timestamp>_<commit>/yocto/boot/
```

Current export policy copies only `*.wic.xz` into that `boot/` folder.

See [yocto/README.md](yocto/README.md) for details on the Yocto layer and how to reuse it.

### Full CI/CD Pipeline

The GitHub Actions workflow runs all steps in sequence:
1. Generate bitstream
2. Generate device tree
3. Build Yocto image (consumes DT artifacts)
4. Generate Vivado and Yocto reports

## Goals

- Generate market actions and measure end‑to‑end latency via 10 GbE UDP on the Kria KR260
- Iteratively reduce latency and explore hardware techniques for speed
- Keep project reproducible via scripted flow

## Manual Vivado Flow

For interactive development, you can use the Tcl scripts directly in a Vivado GUI session:

- **`scripts/setup_project.tcl`**  
  Run this in the Vivado Tcl console to recreate the project structure. Useful for quick
  iterations when changing constraints or block design.

- **`scripts/create_project_and_gen_bitstream.tcl`**  
  Full build entry point: creates project, synthesizes, implements, and exports bitstream + XSA.
  Used by the Makefile and CI pipelines.

- **`scripts/common.tcl`**  
  Shared project setup (board definition, IP config, etc.). Sourced by all other scripts.

- **`scripts/build_utils.tcl`**  
  Utility procedures to reduce duplication across scripts.

See [scripts/README.md](scripts/README.md) for more details.

## Vivado Licensing

The 10‑GbE core and certain IP in this project require a Vivado license. Xilinx
offers a free WebPACK/Pro trial license that can be generated from the
Xilinx Support website and is valid for 120 days. After obtaining a license, place
it in `~/.Xilinx/Vivado/Licenses` (or use `vivado -license` to add it) before
running the build scripts. No commercial license is needed for evaluation; the
trial covers the cores used here. Always check the Xilinx site for the latest
licensing terms.

---

*This is a personal study/experiment, not intended for production use.*
