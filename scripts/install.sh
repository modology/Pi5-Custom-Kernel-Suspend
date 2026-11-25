#!/usr/bin/env bash
set -Eeuo pipefail

readonly KERNEL_COMMIT="3eddc9976f7a4c687e1bf578118d0d91c12c69da"
readonly LOCALVERSION="-pi5suspend"
readonly BOOT_DIR="${BOOT_DIR:-/boot/firmware}"
readonly BUILD_USER="${SUDO_USER:-$USER}"
readonly BUILD_HOME="$(getent passwd "$BUILD_USER" | cut -d: -f6)"
readonly SOURCE_DIR="${KERNEL_SOURCE_DIR:-$BUILD_HOME/src/raspberrypi-linux}"
readonly IMAGE="$SOURCE_DIR/arch/arm64/boot/Image"
readonly DTB="$SOURCE_DIR/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb"
readonly MANIFEST="$BOOT_DIR/pi5-custom-kernel-install.conf"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root: sudo bash scripts/install.sh" >&2
  exit 1
fi
[[ -n "$BUILD_HOME" && -d "$BUILD_HOME" ]] || { echo "ERROR: Cannot determine build user's home directory ($BUILD_USER)." >&2; exit 1; }

for cmd in git make depmod mkinitramfs getent; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: Required command not found: $cmd" >&2; exit 1; }
done

[[ -d "$SOURCE_DIR/.git" ]] || { echo "ERROR: Kernel source tree not found: $SOURCE_DIR" >&2; exit 1; }
actual_commit="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
[[ "$actual_commit" == "$KERNEL_COMMIT" ]] || { echo "ERROR: Source commit mismatch: $actual_commit" >&2; exit 1; }
[[ -f "$IMAGE" ]] || { echo "ERROR: Built kernel Image not found: $IMAGE" >&2; exit 1; }
[[ -f "$DTB" ]] || { echo "ERROR: Built Pi 5 DTB not found: $DTB" >&2; exit 1; }
[[ -f "$BOOT_DIR/config.txt" ]] || { echo "ERROR: $BOOT_DIR/config.txt not found." >&2; exit 1; }
[[ -d /lib/modules ]] || { echo "ERROR: /lib/modules not found." >&2; exit 1; }
[[ ! -e "$MANIFEST" ]] || { echo "ERROR: $MANIFEST already exists. Inspect previous installation first." >&2; exit 1; }

release="$(make -s -C "$SOURCE_DIR" LOCALVERSION="$LOCALVERSION" kernelrelease)"
module_dir="/lib/modules/$release"
[[ ! -e "$module_dir" ]] || { echo "ERROR: $module_dir already exists; refusing to overwrite." >&2; exit 1; }

kernel_name="kernel_2712-pi5suspend-$release.img"
dtb_name="bcm2712-rpi-5-b-pi5suspend.dtb"
initramfs_name="initramfs-pi5suspend-$release"

for name in "$kernel_name" "$dtb_name" "$initramfs_name"; do
  [[ ! -e "$BOOT_DIR/$name" ]] || { echo "ERROR: $BOOT_DIR/$name already exists; refusing to overwrite." >&2; exit 1; }
done

tmp_initramfs="$(mktemp "$BOOT_DIR/.initramfs.XXXXXX")"
tmp_manifest="$(mktemp "$BOOT_DIR/.manifest.XXXXXX")"
cleanup() { rm -f "$tmp_initramfs" "$tmp_manifest"; }
trap cleanup EXIT

echo "Installing modules for $release from $SOURCE_DIR ..."
make -C "$SOURCE_DIR" LOCALVERSION="$LOCALVERSION" modules_install
depmod -a "$release"

echo "Generating initramfs for $release ..."
mkinitramfs -o "$tmp_initramfs" "$release"
[[ -s "$tmp_initramfs" ]] || { echo "ERROR: initramfs generation failed." >&2; exit 1; }

install -m 0644 "$IMAGE" "$BOOT_DIR/$kernel_name"
install -m 0644 "$DTB" "$BOOT_DIR/$dtb_name"
install -m 0644 "$tmp_initramfs" "$BOOT_DIR/$initramfs_name"

cat > "$tmp_manifest" <<EOF
KERNEL_RELEASE='$release'
KERNEL_FILE='$kernel_name'
DTB_FILE='$dtb_name'
INITRAMFS_FILE='$initramfs_name'
SOURCE_COMMIT='$KERNEL_COMMIT'
EOF
install -m 0644 "$tmp_manifest" "$MANIFEST"
sync

echo
echo "Custom kernel artifacts installed, but boot selection was not changed."
echo "Release:   $release"
echo "Kernel:    $BOOT_DIR/$kernel_name"
echo "DTB:       $BOOT_DIR/$dtb_name"
echo "Initramfs: $BOOT_DIR/$initramfs_name"
echo "Manifest:  $MANIFEST"
echo
echo "After reviewing the files, activate with:"
echo "  sudo bash $BUILD_HOME/Pi5-Custom-Kernel-Suspend/scripts/activate.sh"
