# Pi5 Custom Kernel — Suspend-to-RAM

Reproducible build and cautious installation project for the Raspberry Pi 5 custom Linux kernel tested on **TumTum**.

> **Experimental status:** Suspend/resume succeeded in individual tests, including NVMe, Wi-Fi, WayVNC and Jellyfin MPV Shim returning after resume. A repeated three-cycle test caused an unexpected reboot; the cause is unknown. This is not yet production-validated.

## Pinned test snapshot

| Item | Value |
|---|---|
| Upstream | [raspberrypi/linux](https://github.com/raspberrypi/linux) |
| Branch at export | `rpi-6.18.y` |
| Exact source commit | `3eddc9976f7a4c687e1bf578118d0d91c12c69da` |
| Reported running kernel | `6.18.65+` |
| Architecture / board | `aarch64` / Raspberry Pi 5 |

The pinned commit is the exact source HEAD recorded on the test machine. The BCM2712 NVMe simple-suspend quirk is present in that tree; the pinned HEAD itself is a later DRM commit, not the NVMe fix commit.

## Files

- `config/bcm2712_tumtum.config` — captured kernel configuration.
- `scripts/build.sh` — fetches the pinned source and builds Image, modules and DTBs.
- `scripts/install.sh` — installs a kernel built from source; does not change boot selection.
- `scripts/package-tested.sh` — packages the currently running kernel and matching boot files.
- `scripts/install-prebuilt.sh` — verifies and installs a prebuilt release.
- `scripts/activate.sh` — backs up config.txt and changes only the existing `[pi5]` section.
- `scripts/rollback.sh` — restores the saved config.txt.
- `docs/TESTING.md` — test observations and limitations.

Config SHA-256: `396c4e41854080b0cc37fba54c2ced3aa20e3b0c136593cfad092e0110a42792`.

## Fresh Raspberry Pi OS setup (prebuilt package recommended)

Download `pi5-custom-kernel-6.18.65-plus-arm64.tar.gz` and its `.sha256` sidecar from GitHub Releases into `~/Downloads`.

Clone the repository and install the package:

```bash
git clone https://github.com/modology/Pi5-Custom-Kernel-Suspend.git
cd Pi5-Custom-Kernel-Suspend
sudo bash scripts/install-prebuilt.sh ~/Downloads/pi5-custom-kernel-6.18.65-plus-arm64.tar.gz
```

Review the installed files before activation:

```bash
cat /boot/firmware/pi5-custom-kernel-install.conf
ls -lh /boot/firmware/kernel_2712-custom.img /boot/firmware/bcm2712-rpi-5-b-custom.dtb /boot/firmware/initramfs_2712-custom
ls -ld /lib/modules/6.18.65+
```

Activate only when ready:

```bash
sudo bash scripts/activate.sh
sudo reboot
```

### Optional: build from source

The source-build workflow below remains available if you prefer to compile the kernel yourself.


Install dependencies:

```bash
sudo apt update
sudo apt install -y git bc bison flex libssl-dev make libc6-dev libncurses-dev dwarves device-tree-compiler initramfs-tools
```

Clone and build as your normal user:

```bash
git clone https://github.com/modology/Pi5-Custom-Kernel-Suspend.git
cd Pi5-Custom-Kernel-Suspend
bash scripts/build.sh
```

The build uses kernel release suffix `-pi5suspend`, keeping its modules separate from the distribution kernel.

Install (root is required; the script detects the invoking sudo user's home directory):

```bash
sudo bash scripts/install.sh
```

The installer creates unique versioned names such as `kernel_2712-pi5suspend-6.18.65-pi5suspend.img`, a separate Pi 5 DTB, and a matching initramfs. It records their names in `/boot/firmware/pi5-custom-kernel-install.conf`. Existing custom boot files and module directories are never overwritten. The active boot configuration is not changed.

Activate only after checking the installed files:

```bash
sudo bash scripts/activate.sh
sudo reboot
```

Activation requires exactly one existing `[pi5]` section. It backs up `config.txt` to `config.txt.pi5-custom-backup`, then replaces only the kernel, device-tree and initramfs selections within that section. Other settings and sections are preserved.

## Rollback

If the system boots but you want to return to the previous selection:

```bash
sudo bash scripts/rollback.sh
sudo reboot
```

If the Pi cannot boot far enough to run the script, remove the storage device, mount its FAT boot partition on another computer, and restore `config.txt.pi5-custom-backup` as `config.txt`.

Rollback restores boot selection only; it leaves custom kernel files and modules installed.

## Safety and limitations

- Build, install and activation are separate steps.
- Keep an offline recovery path before activating.
- The installer assumes the boot partition is mounted at `/boot/firmware`; set `BOOT_DIR=/path` if needed.
- The install script assumes the default build directory `~/src/raspberrypi-linux` for the invoking user. Set `KERNEL_SOURCE_DIR=/path/to/source` if you built elsewhere, e.g. `sudo KERNEL_SOURCE_DIR=/home/admin/src/raspberrypi-linux bash scripts/install.sh`.
- Do not stress-test suspend while undervoltage or throttling is present. The recorded `vcgencmd get_throttled` value was `0x50005`; power stability remains unresolved.
- No claim is made that every peripheral resumes reliably.

## Updating the kernel

Do not silently move the source pin. Test a specific upstream commit, record the kernel release and config changes, run the suspend test plan, then update the pin and docs in a separate commit.

## License

Project scripts and documentation are MIT licensed; see [LICENSE](LICENSE). The Linux kernel remains under its upstream license.
