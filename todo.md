# TODO List

Ordered by immediate value. Pick one at a time.

---

## 1. Auto-generate pl-overlay.dts from pl.dtsi in the devicetree step
**File:** `scripts/Makefile` — `devicetree` target  
**Why:** `pl.dtsi` is regenerated from the XSA on every build. The hand-written `pl-overlay.dts` will silently drift if you add/change IP in Vivado, causing runtime freezes again.  
**How:** Add a sed/awk transform after `dtc` that wraps `pl.dtsi` nodes into the overlay skeleton automatically.  
**Effort:** Quick

---

## 2. Add artifact validation script between Vivado and DT steps
**File:** New — `scripts/validate_vivado_artifacts.sh`  
**Why:** Vivado exit code goes into `vivado-status.txt` but the Make target returns 0 regardless. A corrupt/empty bitstream can silently flow into DT → Yocto.  
**How:** Assert `.bit` file exists and has non-zero size, `.xsa` is a valid zip, `.bit` header magic bytes are correct.  
**Effort:** Medium

---

## 3. Assert pl-overlay nodes match pl.dtsi
**File:** New — `scripts/validate_dt_overlay.sh`  
**Why:** CI safety net to catch drift between generated `pl.dtsi` and the overlay before a bad build ships.  
**How:** Extract node names from both files and diff them.  
**Effort:** Quick

---

## 4. Fix: CI should fail if Vivado exit code is non-zero
**Files:** `.github/workflows/build_bitstream.yml`, `scripts/Makefile`  
**Why:** Currently `build_bitstream` always exits 0 from CI's perspective. A broken bitstream silently proceeds to DT and Yocto.  
**How:** Read `vivado-status.txt` at end of Make target and propagate non-zero exit code.  
**Effort:** Quick (one-liner fix)

---

## 5. Add AGENTS.md with system constraints
**File:** New — `AGENTS.md`  
**Why:** Documents what is safe/unsafe to modify for any contributor (human or AI). E.g., "don't hand-edit pl.dtsi — it is generated", "pl-overlay.dts must mirror pl.dtsi PL nodes".  
**Effort:** Quick

---

## 6. Add DTB smoke test — verify compiled DTB is loadable
**File:** `scripts/Makefile` — `devicetree` target  
**Why:** `dtc` can succeed and produce a corrupt DTB. Yocto will consume it silently.  
**How:** Round-trip check: `dtc -I dtb -O dts` on the output and verify it parses.  
**Effort:** Quick

---

## 7. Add .wic artifact validation after Yocto build
**File:** New — `yocto/scripts/validate_wic.sh`  
**Why:** `build_sd_boot.sh` warns but doesn't fail if no `.wic.xz` is found. Broken images can be silently produced.  
**How:** Assert file exists, has non-zero size, `xz -t` integrity check passes.  
**Effort:** Medium

---

## 8. Add REPO_MAP.md
**File:** New — `REPO_MAP.md`  
**Why:** Documents artifact flow, which files are generated vs hand-maintained, and how Vivado → DT → Yocto connect. Prevents confusion about what is auto-generated vs what must be manually kept in sync.  
**Effort:** Quick

---

## 9. Make build modular — skip bitstream rebuild if unchanged
**Files:** `scripts/Makefile`, `.github/workflows/build_bitstream.yml`  
**Why:** Vivado synthesis+implementation takes 5-10 minutes and is only needed when HDL or block design changes. DT and Yocto changes (the common case) currently force a full rebuild needlessly.  
**How:**
- Compute a hash of all HDL/XDC/TCL sources before running Vivado
- Store the hash alongside the last successful bitstream artifact
- Skip `build_bitstream` if hash matches; reuse existing `.bit`/`.xsa` from artifacts
- Add a `--force-bitstream` override for when you explicitly need a fresh build
- CI: split into two jobs — `build_bitstream` (conditional) and `build_dt_and_image` (always runs, consumes latest bitstream)

**Effort:** Medium

---

## 10. Enable network-based boot update (no SD card reflash)
**Why:** Currently deploying a new image requires: build → copy .wic.xz → decompress → `dd` to SD card → physically reinsert → repower. This is the biggest friction point in the iteration loop.  
**Options (pick one or combine):**

- **Option A — TFTP + NFS root** (fastest iteration): U-Boot loads kernel + DTB over TFTP; rootfs served over NFS. No SD writes at all. Best for active development. Requires a TFTP/NFS server on the build machine.
- **Option B — SSH push + in-place update** (simplest): Board stays powered, `scp` the new `.wic.xz` over SSH, then a script on the board writes it to the *inactive* SD partition and reboots. Good if NFS setup is undesirable.
- **Option C — TFTP kernel/DTB only, rootfs on SD** (middle ground): Kernel and DTB updated over network; only rootfs changes still need an SD write. Faster than full reflash.

**Recommended start:** Option A — add a `make deploy_tftp` target that copies kernel + DTB to the TFTP server directory after a Yocto build, and document the U-Boot env vars needed (`serverip`, `bootcmd`, `nfsroot`).  
**Files:** `scripts/Makefile` (new `deploy_tftp` target), `docs/` (setup guide for U-Boot env + NFS/TFTP server), optionally a board-side `hermes-update.sh`.  
**Effort:** Medium
