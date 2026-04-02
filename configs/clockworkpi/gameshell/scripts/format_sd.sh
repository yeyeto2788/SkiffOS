#!/bin/bash
set -e

if [ $EUID != 0 ]; then
  echo "This script requires sudo, so it might not work."
fi

if ! parted -h > /dev/null; then
  echo "Please install 'parted' and try again."
  exit 1
fi

if ! command -v mkfs.vfat >/dev/null 2>&1; then
  echo "Please install 'mkfs.vfat' (usually dosfstools) and try again."
  exit 1
fi

if [ -z "$CLOCKWORK_SD" ]; then
  echo "Please set CLOCKWORK_SD to the target block device and try again."
  echo "Example: export CLOCKWORK_SD=/dev/sdX"
  exit 1
fi

if [ ! -b "$CLOCKWORK_SD" ]; then
  echo "$CLOCKWORK_SD is not a block device or doesn't exist."
  exit 1
fi

ubootimg="${BUILDROOT_DIR}/images/u-boot-sunxi-with-spl.bin"

if [ ! -f "$ubootimg" ]; then
  echo "Can't find U-Boot image at $ubootimg"
  echo "Run 'make compile' first."
  exit 1
fi

if [ -z "$SKIFF_NO_INTERACTIVE" ]; then
  read -p "Are you sure? This will completely destroy all data on $CLOCKWORK_SD. [y/N] " -n 1 -r
  echo
  if ! [[ $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

if [ -z "$SKIFF_NO_INTERACTIVE" ]; then
  read -p "Verify that '$CLOCKWORK_SD' is the correct device. Be sure. [y/N] " -n 1 -r
  echo
  if ! [[ $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

MKEXT4="mkfs.ext4 -F -O ^64bit"

set -x
set -e

echo "Formatting device..."
parted $CLOCKWORK_SD mklabel msdos

echo "Making boot partition..."
parted -a optimal $CLOCKWORK_SD mkpart primary fat32 100MiB 410MiB

echo "Making rootfs partition..."
parted -a optimal $CLOCKWORK_SD mkpart primary ext4 410MiB 600MiB

echo "Making persist partition..."
parted -a optimal $CLOCKWORK_SD -- mkpart primary ext4 600MiB "-1s"

echo "Waiting for partprobe..."
sync && sync
partprobe $CLOCKWORK_SD || true
sleep 2

CLOCKWORK_SD_SFX=$CLOCKWORK_SD
if [ -b ${CLOCKWORK_SD}p1 ]; then
  CLOCKWORK_SD_SFX=${CLOCKWORK_SD}p
fi

echo "Building FAT filesystem for boot..."
mkfs.vfat -F 32 ${CLOCKWORK_SD_SFX}1
fatlabel ${CLOCKWORK_SD_SFX}1 boot

echo "Building ext4 filesystem for rootfs..."
$MKEXT4 -L "rootfs" ${CLOCKWORK_SD_SFX}2

echo "Building ext4 filesystem for persist..."
$MKEXT4 -L "persist" ${CLOCKWORK_SD_SFX}3

# Allwinner sunxi U-Boot SPL must be written at offset 8 KiB (sector 16)
echo "Flashing U-Boot SPL..."
dd if=$ubootimg of=${CLOCKWORK_SD} conv=fsync bs=1024 seek=8

echo "Done! Run 'make cmd/clockworkpi/gameshell/install' to copy the OS."
