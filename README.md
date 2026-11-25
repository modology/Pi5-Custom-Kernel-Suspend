# Pi5 Custom Kernel — Suspend-to-RAM

A reproducible build project for the Raspberry Pi 5 custom Linux kernel tested on **TumTum**.

The goal is to preserve the tested kernel source revision and configuration so the kernel can be rebuilt after reinstalling Raspberry Pi OS. The project focuses on **deep Suspend-to-RAM** (`mem` with `deep` selected), including the BCM2712 NVMe PCIe suspend/resume quirk.

> **Status:** experimental. Suspend/resume has succeeded in testing, including NVMe, Wi-Fi, WayVNC and Jellyfin MPV Shim returning after resume. A repeated three-cycle test caused an unexpected reboot, and the cause has not been established. Do not treat this as fully validated or production-safe.

## Tested source snapshot

| Item | Value |
|---|---|
| Upstream repository | [raspberrypi/linux](https://github.com/raspberrypi/linux) |
| Branch at export | `rpi-6.18.y` |
| Pinned commit | `3eddc9976f7a4c687e1bf578118d0d91c12c69da` |
| Reported running kernel | `6.18.65+` |
| Architecture | `aarch64` |
| Tested board | Raspberry Pi 5 |

The pinned commit is the exact source HEAD recorded on the test machine. The BCM2712 NVMe simple-suspend quirk is present in that source tree; the pinned HEAD itself is a later DRM commit, not the NVMe fix commit.

## Repository layout

- `config/bcm2712_tumtum.config` — full kernel configuration captured from the tested machine.
- `scripts/build.sh` — fetches the pinned source and builds Image, modules and device trees.
- `docs/TESTING.md` — test observations and known limitations.

The configuration file is taken from the exported `/lib/modules/6.18.65+/build/.config`. Its SHA-256 at export was:

```
396c4e41854080b0cc37fba54c2ced3aa20e3b0c136593cfad092e0110a42792
```

## Build on the Raspberry Pi 5

Install build dependencies (package names may vary by Raspberry Pi OS release):

```bash
sudo apt update
sudo apt install -y git bc bison flex libssl-dev make   libc6-dev libncurses-dev dwarves   device-tree-compiler
```

Clone this project and run:

```bash
git clone https://github.com/modology/Pi5-Custom-Kernel-Suspend.git
cd Pi5-Custom-Kernel-Suspend
./scripts/build.sh
```

The build script clones the Raspberry Pi kernel into `$HOME/src/raspberrypi-linux`, checks out the pinned commit, applies the committed configuration and builds the kernel.

Build artifacts remain in that source tree:

- `arch/arm64/boot/Image`
- `arch/arm64/boot/dts/broadcom/*.dtb`
- kernel modules under the normal kernel build output

## Important safety notes

- Building does not install or activate the kernel.
- Do not overwrite the working boot files until you have a recovery path (for example, the ability to remove the NVMe and edit the boot partition from another computer).
- The install procedure must preserve the existing boot files and the current working kernel.
- Do not run repeated suspend stress tests while the Pi reports undervoltage or throttling.
- The recorded `vcgencmd get_throttled` result was `0x50005`, indicating current and historical undervoltage/throttling flags. Power stability remains an unresolved test variable.
- No claim is made that this kernel fixes every suspend issue or that all peripherals reliably resume in every configuration.

## Updating the kernel

Do not silently move the pinned source revision. To test a newer Raspberry Pi kernel:
1. Select and test a specific upstream commit.
2. Record the commit SHA and kernel release.
3. Rebuild using the same configuration, reviewing any configuration changes.
4. Run the suspend/resume test plan and record the results.
5. Update the pin and documentation in a separate commit.

## License

The Linux kernel is licensed under the terms in the upstream [Linux kernel repository](https://github.com/raspberrypi/linux). Project scripts and documentation in this repository are provided under the MIT License; see [LICENSE](LICENSE).
