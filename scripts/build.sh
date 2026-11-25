#!/usr/bin/env bash
set -Eeuo pipefail

readonly KERNEL_REPO="https://github.com/raspberrypi/linux.git"
readonly KERNEL_COMMIT="3eddc9976f7a4c687e1bf578118d0d91c12c69da"
readonly PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CONFIG_FILE="$PROJECT_DIR/config/bcm2712_tumtum.config"
readonly SOURCE_DIR="${KERNEL_SOURCE_DIR:-$HOME/src/raspberrypi-linux}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Kernel config not found: $CONFIG_FILE" >&2
  echo "Restore config/bcm2712_tumtum.config from the original kernel export." >&2
  exit 1
fi

for cmd in git make; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: Required command not found: $cmd" >&2
    exit 1
  }
done

mkdir -p "$(dirname "$SOURCE_DIR")"

if [[ -e "$SOURCE_DIR" ]]; then
  if [[ ! -d "$SOURCE_DIR/.git" ]]; then
    echo "ERROR: $SOURCE_DIR exists but is not a Git repository." >&2
    exit 1
  fi
  if [[ -n "$(git -C "$SOURCE_DIR" status --porcelain)" ]]; then
    echo "ERROR: Source tree has local changes; refusing to overwrite it:" >&2
    git -C "$SOURCE_DIR" status --short >&2
    exit 1
  fi
  git -C "$SOURCE_DIR" fetch --no-tags origin
else
  git clone --filter=blob:none "$KERNEL_REPO" "$SOURCE_DIR"
fi

git -C "$SOURCE_DIR" checkout --detach "$KERNEL_COMMIT"

actual_commit="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
if [[ "$actual_commit" != "$KERNEL_COMMIT" ]]; then
  echo "ERROR: Source commit mismatch: $actual_commit" >&2
  exit 1
fi

cd "$SOURCE_DIR"
cp "$CONFIG_FILE" .config
make olddefconfig

jobs="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc)}"
echo "Building pinned Raspberry Pi kernel commit $KERNEL_COMMIT"
echo "Source: $SOURCE_DIR"
echo "Parallel jobs: $jobs"

make -j"$jobs" Image modules dtbs

echo
echo "Build complete."
echo "Kernel release: $(make -s kernelrelease)"
echo "Image: $SOURCE_DIR/arch/arm64/boot/Image"
echo "DTB:   $SOURCE_DIR/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb"
echo
echo "Nothing has been installed. Review the artifacts and use a separately verified install procedure."
