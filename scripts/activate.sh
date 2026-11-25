#!/usr/bin/env bash
set -Eeuo pipefail

readonly BOOT_DIR="${BOOT_DIR:-/boot/firmware}"
readonly CONFIG="$BOOT_DIR/config.txt"
readonly BACKUP="$BOOT_DIR/config.txt.pi5-custom-backup"
readonly MANIFEST="$BOOT_DIR/pi5-custom-kernel-install.conf"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root: sudo bash scripts/activate.sh" >&2
  exit 1
fi
[[ -f "$CONFIG" ]] || { echo "ERROR: $CONFIG not found." >&2; exit 1; }
[[ -f "$MANIFEST" ]] || { echo "ERROR: Install manifest not found. Run install.sh first." >&2; exit 1; }
[[ ! -e "$BACKUP" ]] || { echo "ERROR: Backup already exists: $BACKUP. Inspect it; refusing to overwrite." >&2; exit 1; }

# Generated locally by install.sh.
# shellcheck disable=SC1090
source "$MANIFEST"

for file in "$KERNEL_FILE" "$DTB_FILE" "$INITRAMFS_FILE"; do
  [[ -s "$BOOT_DIR/$file" ]] || { echo "ERROR: Missing or empty boot file: $BOOT_DIR/$file" >&2; exit 1; }
done

pi5_count="$(grep -Ec '^\[pi5\][[:space:]]*$' "$CONFIG" || true)"
[[ "$pi5_count" -eq 1 ]] || { echo "ERROR: Expected exactly one [pi5] section; found $pi5_count. No changes made." >&2; exit 1; }

tmp_config="$(mktemp "$BOOT_DIR/.config.txt.XXXXXX")"
cleanup() { rm -f "$tmp_config"; }
trap cleanup EXIT

python3 - "$CONFIG" "$tmp_config" "$KERNEL_FILE" "$DTB_FILE" "$INITRAMFS_FILE" <<'PY'
import pathlib
import re
import sys

source, target, kernel, dtb, initramfs = sys.argv[1:]
lines = pathlib.Path(source).read_text().splitlines()
out = []
in_pi5 = False
inserted = False

for line in lines:
    section = re.match(r'^\s*\[([^]]+)\]\s*$', line)
    if section:
        if in_pi5 and not inserted:
            out.extend([f"kernel={kernel}", f"device_tree={dtb}",
                        f"initramfs {initramfs} followkernel"])
            inserted = True
        in_pi5 = section.group(1).strip().lower() == "pi5"
        out.append(line)
        continue

    if in_pi5 and re.match(r'^\s*(kernel\s*=|device_tree\s*=|initramfs\s+)', line, re.I):
        continue
    out.append(line)

if in_pi5 and not inserted:
    out.extend([f"kernel={kernel}", f"device_tree={dtb}",
                f"initramfs {initramfs} followkernel"])
    inserted = True

if not inserted:
    raise SystemExit("Could not safely locate [pi5] section; config not changed.")

pathlib.Path(target).write_text("\n".join(out) + "\n")
PY

cp -p "$CONFIG" "$BACKUP"
install -m "$(stat -c '%a' "$CONFIG")" "$tmp_config" "$CONFIG"
sync

echo "Custom kernel selected in the existing [pi5] section."
echo "Original config backup: $BACKUP"
echo "Reboot when ready: sudo reboot"
echo "If the Pi does not boot, restore config.txt from the backup using another computer."
