# Yocto Build System

Yocto/Bitbake workflow for building a Linux image that includes your custom FPGA bitstream and device tree.

## Structure

```
yocto/
├── scripts/Makefile                          # build_yocto target
├── scripts/build_sd_boot.sh                  # in-container Yocto build/export logic
└── meta-custom-bitstream/                    # Reusable Yocto layer
    ├── conf/layer.conf
    ├── conf/machine/hermes-k26.conf
    ├── recipes-bsp/device-tree/hermes-external-dtb.bb
    └── recipes-bsp/kria-artifacts/kria-artifacts.bb
```

## Build

```sh
# Hardware flow first (writes vivado/ and dt/ under one build folder)
cd scripts && make build_bitstream && make devicetree

# Yocto build consumes those artifacts
cd yocto/scripts && make build_yocto

# Optional per-run overrides
# make build_yocto YOCTO_DTS_NAME=system-top.dts YOCTO_DTB_NAME=system-top.dtb

# Local developer workflow (build from this repo without pushing)
# Uses dt_example/dt as /dt input and writes outputs under output/yocto-local/
make build_yocto_local
```

Current artifact layout for one build:

```
/home/buildserver/artifacts/kria_zynq/<branch>/<timestamp>_<commit>/
    vivado/
    dt/
    yocto/
```

Path tracker files:
- `/home/buildserver/artifacts/kria_zynq_latest_build.txt` -> `.../vivado`
- `/home/buildserver/artifacts/kria_zynq_latest_devicetree.txt` -> `.../dt`
- `/home/buildserver/artifacts/kria_zynq_latest_yocto_build.txt` -> `.../yocto`

The `build_yocto` target mounts the device tree directory and uses it in two ways:
- Build-time DTS source (`SYSTEM_DTFILE`) → `/dt/<name>.dts` (defaults to `system-top.dts`)
- Packaged runtime artifacts:
    - Bitstream → `/lib/firmware/`
    - DTB copy → `/boot/dtbs/`
    - PL overlay DTS (`pl-overlay.dts`) generated from `pl.dtsi`

The Yocto `report` target reads `yocto.log` from that `yocto/` folder and generates `yocto-report.txt`.

After `bitbake` completes, the build also exports the boot disk image into:

```
/home/buildserver/artifacts/kria_zynq/<branch>/<timestamp>_<commit>/yocto/boot/
```

Current export policy copies only `*.wic.xz` from `DEPLOY_DIR_IMAGE`.
The bitstream and DTB are still packaged in the Yocto image via the custom layer,
but are not exported as separate files in `yocto/boot/`.

For local developer builds (`make build_yocto_local`), artifacts are staged in:

```
output/yocto-local/local/<timestamp>/yocto/
    yocto.log
    boot/
        *.wic.xz
```

## Reusing the Layer

Copy `meta-custom-bitstream/` into your Yocto workspace and register it:

```sh
bitbake-layers add-layer /path/to/meta-custom-bitstream
# or manually add to bblayers.conf:
# BBLAYERS += "/path/to/meta-custom-bitstream"
```

Include in your image:
```conf
IMAGE_INSTALL:append = " kria-artifacts"
```

Build machine and DT source integration:

```conf
MACHINE = "hermes-k26"
SYSTEM_DTFILE = "/dt/system-top.dts"
```

Per-run overrides are provided by the Yocto Makefile:

```sh
make build_yocto YOCTO_DTS_NAME=system-top.dts YOCTO_DTB_NAME=system-top.dtb
```

## Runtime Bitstream Load

Load bitstream in U-Boot or init script:
```sh
fpga load /lib/firmware/<your-bitstream.bit>
```

---

https://docs.yoctoproject.org/
