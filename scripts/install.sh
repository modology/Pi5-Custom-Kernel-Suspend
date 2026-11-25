#!/usr/bin/env bash
set -Eeuo pipefail

readonly LOCALVERSION="-pi5suspend"
readonly PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SOURCE_DIR="${KERNEL_SOURCE_DIR:-$HOME/src/raspberrypi-linux}"
readonly BOOT_DIR="${BOOT_DIR:-/boot/firmware}"
readonly IMAGE="$SOURCE_DIR/arch/arm64/boot/Image"
readonly DTB="$SOURCE_DIR/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb"
readonly KERNEL_NAME="kernel_2712-custom.img"
readonly DTB_NAME="bcm2712-rpi-5-b-custom.dtb"
readonly INITRAMFS_NAME="initramfs_2712-custom"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run this script with sudo: sudo bash scripts/install.sh" >&2
  exit 1
fi

for cmd in make depmod mkinitramfs; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: Required command not found: $cmd" >&2
    exit 1
  }
done

[[ -d "$SOURCE_DIR/.git" ]] || { echo "ERROR: Kernel source tree not found: $SOURCE_DIR" >&2; exit 1; }
[[ -f "$IMAGE" ]] || { echo "ERROR: Built kernel Image not found: $IMAGE" >&2; exit 1; }
[[ -f "$DTB" ]] || { echo "ERROR: Built Pi 5 DTB not found: $DTB" >&2; exit 1; }
[[ -f "$BOOT_DIR/config.txt" ]] || { echo "ERROR: $BOOT_DIR/config.txt not found. Set BOOT_DIR if needed." >&2; exit 1; }

release="$(make -s -C "$SOURCE_DIR" LOCALVERSION="$LOCALVERSION" kernelrelease)"
module_dir="/lib/modules/$release"

if [[ -e "$module_dir" ]]; then
  echo "ERROR: $module_dir already exists. Refusing to overwrite installed modules." >&2
  exit 1
fi

for name in "$KERNEL_NAME" "$DTB_NAME" "$INITRAMFS_NAME"; do
  if [[ -e "$BOOT_DIR/$name" ]]; then
    echo "ERROR: $BOOT_DIR/$name already exists. Move/remove the previous custom file first." >&2
    exit 1
  fi
done

tmp_initramfs="$(mktemp)"
cleanup() { rm -f "$tmp_initramfs"; }
trap cleanup EXIT

echo "Installing modules for kernel $release ..."
make -C "$SOURCE_DIR" LOCALVERSION="$LOCALVERSION" modules_install
depmod -a "$release"

echo "Generating matching initramfs ..."
mkinitramfs -o "$tmp_initramfs" "$release"
[[ -s "$tmp_initramfs" ]] || { echo "ERROR: initramfs generation failed." >&2; exit 1; }

echo "Installing separate boot files into $BOOT_DIR ..."
install -m 0644 "$IMAGE" "$BOOT_DIR/$KERNEL_NAME"
install -m 0644 "$DTB" "$BOOT_DIR/$DTB_NAME"
install -m 0644 "$tmp_initramfs" "$BOOT_DIR/$INITRAMFS_NAME"

echo
echo "Installation files are ready; the existing boot configuration has NOT been changed."
echo "Kernel release: $release"
echo "Kernel:    $BOOT_DIR/$KERNEL_NAME"
echo "DTB:       $BOOT_DIR/$DTB_NAME"
echo "Initramfs: $BOOT_DIR/$INITRAMFS_NAME"
echo
echo "To select the custom kernel on the next boot, run:"
echo "  sudo bash $PROJECT_DIR/scripts/activate.sh"
echo
echo "To remove the installed custom files later, first deactivate the custom boot config,"
echo "then remove the three files above and /lib/modules/$release."
