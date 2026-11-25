#!/usr/bin/env bash
set -Eeuo pipefail

readonly PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BOOT_DIR="${BOOT_DIR:-/boot/firmware}"
readonly CONFIG="$BOOT_DIR/config.txt"
readonly BACKUP="$BOOT_DIR/config.txt.pi5-custom-backup"
readonly BEGIN="# BEGIN Pi5-Custom-Kernel-Suspend"
readonly END="# END Pi5-Custom-Kernel-Suspend"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run this script with sudo: sudo bash scripts/activate.sh" >&2
  exit 1
fi

[[ -f "$CONFIG" ]] || { echo "ERROR: $CONFIG not found." >&2; exit 1; }

for file in kernel_2712-custom.img bcm2712-rpi-5-b-custom.dtb initramfs_2712-custom; do
  [[ -s "$BOOT_DIR/$file" ]] || { echo "ERROR: Missing boot file: $BOOT_DIR/$file. Run install.sh first." >&2; exit 1; }
done

if grep -Fq "$BEGIN" "$CONFIG"; then
  echo "ERROR: Custom boot configuration is already present. Use rollback.sh first." >&2
  exit 1
fi

if [[ -e "$BACKUP" ]]; then
  echo "ERROR: Backup already exists: $BACKUP" >&2
  echo "Preserve it. If this is a previous installation, inspect it before proceeding." >&2
  exit 1
fi

cp -p "$CONFIG" "$BACKUP"

cat >> "$CONFIG" <<'EOF'

# BEGIN Pi5-Custom-Kernel-Suspend
[all]
kernel=kernel_2712-custom.img
device_tree=bcm2712-rpi-5-b-custom.dtb
initramfs initramfs_2712-custom followkernel
# END Pi5-Custom-Kernel-Suspend
EOF

sync
echo "Custom kernel selected for the next boot."
echo "Original config backup: $BACKUP"
echo "Reboot when ready: sudo reboot"
echo "If it fails to boot, mount the boot partition on another computer and"
echo "replace config.txt with config.txt.pi5-custom-backup."
