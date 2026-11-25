#!/usr/bin/env bash
set -Eeuo pipefail

readonly RELEASE="6.18.65+"
readonly SOURCE_COMMIT="3eddc9976f7a4c687e1bf578118d0d91c12c69da"
readonly PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SOURCE_DIR="${KERNEL_SOURCE_DIR:-$HOME/.local/share/pipx/venvs/jellyfin-mpv-shim/lib/python3.13/site-packages/jellyfin_mpv_shim/.kernel-suspend-work/linux}"
readonly BOOT_DIR="${BOOT_DIR:-/boot/firmware}"
readonly MODULES_DIR="/lib/modules/$RELEASE"
readonly PACKAGE_NAME="pi5-custom-kernel-6.18.65-plus-arm64"
readonly OUTPUT_DIR="$PROJECT_DIR/dist"
readonly ARCHIVE="$OUTPUT_DIR/$PACKAGE_NAME.tar.gz"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

echo "Checking running kernel..."
[[ "$(uname -r)" == "$RELEASE" ]] || fail "Running kernel is not $RELEASE"
[[ "$(cat "$SOURCE_DIR/include/config/kernel.release")" == "$RELEASE" ]] || fail "Source kernel release mismatch"
[[ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" == "$SOURCE_COMMIT" ]] || fail "Source commit mismatch"
[[ -z "$(git -C "$SOURCE_DIR" status --porcelain)" ]] || fail "Source tree is not clean"

echo "Checking kernel configuration..."
cmp -s "$SOURCE_DIR/.config" "$PROJECT_DIR/config/bcm2712_tumtum.config" || fail "Kernel config differs from repository config"

echo "Checking kernel image..."
cmp -s "$SOURCE_DIR/arch/arm64/boot/Image" "$BOOT_DIR/kernel_2712-custom.img" || fail "Kernel image mismatch"

echo "Checking device tree..."
cmp -s "$SOURCE_DIR/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb" "$BOOT_DIR/bcm2712-rpi-5-b-custom.dtb" || fail "Device tree mismatch"

echo "Checking modules and initramfs..."
[[ -d "$MODULES_DIR/kernel" ]] || fail "Installed module tree missing"
[[ -s "$MODULES_DIR/modules.dep" ]] || fail "Module dependency metadata missing"
[[ -s "$BOOT_DIR/initramfs_2712-custom" ]] || fail "Initramfs missing"
lsinitramfs "$BOOT_DIR/initramfs_2712-custom" | grep -F "usr/lib/modules/$RELEASE/" >/dev/null || fail "Initramfs does not contain matching modules"

[[ ! -e "$ARCHIVE" ]] || fail "Archive already exists: $ARCHIVE"

mkdir -p "$OUTPUT_DIR"
WORK="$(mktemp -d "$OUTPUT_DIR/.package.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

STAGE="$WORK/$PACKAGE_NAME"
mkdir -p "$STAGE/boot" "$STAGE/modules" "$STAGE/config"

cp -a "$MODULES_DIR" "$STAGE/modules/"
rm -f "$STAGE/modules/$RELEASE/build" "$STAGE/modules/$RELEASE/source"
install -m 0644 "$BOOT_DIR/kernel_2712-custom.img" "$STAGE/boot/"
install -m 0644 "$BOOT_DIR/bcm2712-rpi-5-b-custom.dtb" "$STAGE/boot/"
install -m 0644 "$BOOT_DIR/initramfs_2712-custom" "$STAGE/boot/"
install -m 0644 "$SOURCE_DIR/.config" "$STAGE/config/kernel.config"
install -m 0644 "$PROJECT_DIR/config/bcm2712_tumtum.config" "$STAGE/config/repository.config"

cat > "$STAGE/metadata.txt" <<META
Package: $PACKAGE_NAME
Architecture: arm64
Kernel release: $RELEASE
Source repository: https://github.com/raspberrypi/linux
Source commit: $SOURCE_COMMIT
Project commit: $(git -C "$PROJECT_DIR" rev-parse HEAD)
Kernel config SHA256: $(sha256sum "$SOURCE_DIR/.config" | awk '{print $1}')
META

(
  cd "$STAGE"
  find boot modules config -type f -print0 |
    sort -z |
    xargs -0 sha256sum > SHA256SUMS
)

echo "Creating archive..."
tar -czf "$WORK/$PACKAGE_NAME.tar.gz" -C "$WORK" "$PACKAGE_NAME"
tar -tzf "$WORK/$PACKAGE_NAME.tar.gz" >/dev/null

mv "$WORK/$PACKAGE_NAME.tar.gz" "$ARCHIVE"
(cd "$OUTPUT_DIR" && sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256")

echo
echo "Package created successfully:"
ls -lh "$ARCHIVE" "$ARCHIVE.sha256"
echo
cat "$ARCHIVE.sha256"
