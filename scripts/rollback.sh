#!/usr/bin/env bash
set -Eeuo pipefail

readonly BOOT_DIR="${BOOT_DIR:-/boot/firmware}"
readonly CONFIG="$BOOT_DIR/config.txt"
readonly BACKUP="$BOOT_DIR/config.txt.pi5-custom-backup"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run this script with sudo: sudo bash scripts/rollback.sh" >&2
  exit 1
fi

[[ -f "$BACKUP" ]] || {
  echo "ERROR: No boot configuration backup found at $BACKUP" >&2
  exit 1
}

cp -p "$BACKUP" "$CONFIG"
sync
echo "Original Raspberry Pi boot configuration restored."
echo "The custom kernel files and modules were left in place."
echo "Reboot when ready: sudo reboot"
