#!/usr/bin/env bash
set -Eeuo pipefail

readonly RELEASE="6.18.65+"
readonly PACKAGE_NAME="pi5-custom-kernel-6.18.65-plus-arm64"
readonly SOURCE_COMMIT="3eddc9976f7a4c687e1bf578118d0d91c12c69da"
readonly BOOT_DIR="${BOOT_DIR:-/boot/firmware}"
readonly MODULES_PARENT="/lib/modules"
readonly MODULES_DIR="$MODULES_PARENT/$RELEASE"
readonly MANIFEST="$BOOT_DIR/pi5-custom-kernel-install.conf"

readonly KERNEL_FILE="kernel_2712-custom.img"
readonly DTB_FILE="bcm2712-rpi-5-b-custom.dtb"
readonly INITRAMFS_FILE="initramfs_2712-custom"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

if [[ "$EUID" -ne 0 ]]; then
    echo "Run as root: sudo bash scripts/install-prebuilt.sh PACKAGE.tar.gz" >&2
    exit 1
fi

[[ $# -eq 1 ]] || fail "Usage: sudo bash scripts/install-prebuilt.sh PACKAGE.tar.gz"

ARCHIVE="$(realpath -- "$1")"
[[ -f "$ARCHIVE" ]] || fail "Package archive not found: $ARCHIVE"

for cmd in tar sha256sum depmod mountpoint lsinitramfs install realpath; do
    command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
done

[[ "$(uname -m)" == "aarch64" ]] || fail "64-bit ARM Linux is required"

MODEL="$(tr -d '\0' </proc/device-tree/model 2>/dev/null || true)"
[[ "$MODEL" == *"Raspberry Pi 5"* ]] || fail "This package is intended for Raspberry Pi 5; detected: $MODEL"

[[ -f "$BOOT_DIR/config.txt" ]] || fail "$BOOT_DIR/config.txt not found"
mountpoint -q "$BOOT_DIR" || fail "$BOOT_DIR is not a mounted filesystem"
[[ -d "$MODULES_PARENT" ]] || fail "$MODULES_PARENT not found"

[[ ! -e "$MODULES_DIR" ]] || fail "$MODULES_DIR already exists; refusing to overwrite"
[[ ! -e "$MANIFEST" ]] || fail "$MANIFEST already exists; inspect the previous installation"

for file in "$KERNEL_FILE" "$DTB_FILE" "$INITRAMFS_FILE"; do
    [[ ! -e "$BOOT_DIR/$file" ]] || fail "$BOOT_DIR/$file already exists; refusing to overwrite"
done

WORK="$(mktemp -d)"
TMP_MANIFEST=""
MODULES_INSTALLED=0
BOOT_FILES_INSTALLED=0
COMMITTED=0

cleanup() {
    if [[ "$COMMITTED" -ne 1 ]]; then
        rm -f "$MANIFEST"
        if [[ "$BOOT_FILES_INSTALLED" -eq 1 ]]; then
            rm -f "$BOOT_DIR/$KERNEL_FILE" "$BOOT_DIR/$DTB_FILE" "$BOOT_DIR/$INITRAMFS_FILE"
        fi
        if [[ "$MODULES_INSTALLED" -eq 1 ]]; then
            rm -rf "$MODULES_DIR"
        fi
    fi
    [[ -z "$TMP_MANIFEST" ]] || rm -f "$TMP_MANIFEST"
    rm -rf "$WORK"
}
trap cleanup EXIT

echo "Extracting package..."
tar -xzf "$ARCHIVE" -C "$WORK"

PKG="$WORK/$PACKAGE_NAME"
[[ -d "$PKG" ]] || fail "Expected package directory not found"

echo "Verifying package checksums..."
(
    cd "$PKG"
    sha256sum -c SHA256SUMS
)

[[ -f "$ARCHIVE.sha256" ]] || fail "Archive SHA256 sidecar is missing: $ARCHIVE.sha256"

echo "Verifying archive checksum..."
(
    cd "$(dirname "$ARCHIVE")"
    sha256sum -c "$(basename "$ARCHIVE").sha256"
)

grep -Fxq "Architecture: arm64" "$PKG/metadata.txt" || fail "Package architecture mismatch"
grep -Fxq "Kernel release: $RELEASE" "$PKG/metadata.txt" || fail "Kernel release mismatch"
grep -Fxq "Source commit: $SOURCE_COMMIT" "$PKG/metadata.txt" || fail "Kernel source commit mismatch"

[[ -d "$PKG/modules/$RELEASE/kernel" ]] || fail "Kernel module directory missing"
[[ -s "$PKG/modules/$RELEASE/modules.dep" ]] || fail "Module dependency metadata missing"

for file in "$KERNEL_FILE" "$DTB_FILE" "$INITRAMFS_FILE"; do
    [[ -s "$PKG/boot/$file" ]] || fail "Package boot file missing: $file"
done

lsinitramfs "$PKG/boot/$INITRAMFS_FILE" |
    grep -F "usr/lib/modules/$RELEASE/" >/dev/null ||
    fail "Packaged initramfs does not contain modules for $RELEASE"

echo "Installing kernel modules..."
MODULES_INSTALLED=1
cp -a "$PKG/modules/$RELEASE" "$MODULES_PARENT/"
depmod -a "$RELEASE"

echo "Installing boot files..."
BOOT_FILES_INSTALLED=1
install -m 0644 "$PKG/boot/$KERNEL_FILE" "$BOOT_DIR/$KERNEL_FILE"
install -m 0644 "$PKG/boot/$DTB_FILE" "$BOOT_DIR/$DTB_FILE"
install -m 0644 "$PKG/boot/$INITRAMFS_FILE" "$BOOT_DIR/$INITRAMFS_FILE"

TMP_MANIFEST="$(mktemp "$BOOT_DIR/.manifest.XXXXXX")"

cat > "$TMP_MANIFEST" <<MANIFEST
KERNEL_RELEASE='$RELEASE'
KERNEL_FILE='$KERNEL_FILE'
DTB_FILE='$DTB_FILE'
INITRAMFS_FILE='$INITRAMFS_FILE'
SOURCE_COMMIT='$SOURCE_COMMIT'
MANIFEST

install -m 0644 "$TMP_MANIFEST" "$MANIFEST"
sync
COMMITTED=1

echo
echo "Prebuilt kernel installed successfully."
echo "Kernel release: $RELEASE"
echo "Modules:        $MODULES_DIR"
echo "Kernel:         $BOOT_DIR/$KERNEL_FILE"
echo "Device tree:    $BOOT_DIR/$DTB_FILE"
echo "Initramfs:      $BOOT_DIR/$INITRAMFS_FILE"
echo "Manifest:       $MANIFEST"
echo
echo "Boot configuration was NOT changed."
echo "Review the installed files before activation."
echo "Activate separately with:"
echo "  sudo bash scripts/activate.sh"
