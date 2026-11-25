# Pi5 Custom Kernel — Suspend-to-RAM

A reproducible build and cautious installation project for the Raspberry Pi 5 custom Linux kernel tested on **TumTum**.

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
- `scripts/install.sh` — installs modules, a separately named kernel image, the Pi 5 DTB and a matching initramfs. It does not change boot selection.
- `scripts/activate.sh` — backs up `config.txt` on the boot partition and selects the custom kernel.
- `scripts/rollback.sh` — restores the saved boot configuration.
- `docs/TESTING.md` — test observations and known limitations.

The captured configuration SHA-256 is:

```
396c4e41854080b0cc37fba54c2ced3aa20e3b0c136593cfad092e0110a42792
```

## Fresh Raspberry Pi OS setup

Install build and initramfs dependencies:

```bash
sudo apt update
sudo apt install -y git bc bison flex libssl-dev make libc6-dev libncurses-dev dwarves device-tree-compiler initramfs-tools
```

Clone and build:

```bash
git clone https://github.com/modology/Pi5-Custom-Kernel-Suspend.git
cd Pi5-Custom-Kernel-Suspend
bash scripts/build.sh
```

The build uses the pinned source commit and a distinct kernel release suffix, `-pi5suspend`, so its modules do not overwrite the distribution kernel's modules.

Install the built artifacts:

```bash
sudo bash scripts/install.sh
```

This installs the custom kernel files and modules but **does not activate the custom kernel**. The original boot selection remains unchanged.

When ready to test the custom kernel:

```bash
sudo bash scripts/activate.sh
sudo reboot
```

The activation script saves the original boot configuration as `/boot/firmware/config.txt.pi5-custom-backup` before appending the custom kernel selection. It checks that the kernel, DTB and initramfs files exist first.

## Recovery / rollback

If the custom kernel boots but you want to return to the previous kernel:

```bash
sudo bash scripts/rollback.sh
sudo reboot
```

If the Pi cannot boot far enough to run the rollback script, remove the storage device, mount its FAT boot partition on another computer, and replace `config.txt` with the adjacent `config.txt.pi5-custom-backup` file.

The rollback script restores boot selection only. It intentionally leaves the custom kernel files and modules installed so they can be inspected or removed later.

## Important safety notes

- Build and installation are separate from activation. A successful build or install does not change the active boot kernel.
- Keep a recovery path before activating (for example, the ability to remove the NVMe and edit the FAT boot partition from another computer).
- The installer refuses to overwrite existing custom-named boot files or an existing module directory.
- The install script assumes the Raspberry Pi OS boot partition is mounted at `/boot/firmware`. Override with `BOOT_DIR=/path/to/boot` if necessary.
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
