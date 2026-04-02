#!/bin/bash
set -eo pipefail

if [ $EUID != 0 ]; then
  echo "This script requires sudo, so it might not work."
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

resources_path="${SKIFF_CURRENT_CONF_DIR}/resources"
outp_path="${BUILDROOT_DIR}"
images_path="${outp_path}/images"

img_path="${images_path}/Image"
zimg_path="${images_path}/zImage"
uinit_path="${images_path}/rootfs.cpio.uboot"
dtb_path=$(find ${images_path}/ -name '*.dtb' -print -quit)

source ${SKIFF_CURRENT_CONF_DIR}/scripts/determine_config.sh

if [ ! -f "$dtb_path" ]; then
  echo "DTB not found at ${images_path}/*.dtb — make sure Buildroot finished compiling."
  exit 1
fi

if [ ! -f "$img_path" ]; then
  img_path=$zimg_path
fi

if [ ! -f "$img_path" ]; then
  echo "zImage or Image not found — make sure Buildroot finished compiling."
  exit 1
fi

mounts=()
WORK_DIR=$(mktemp -d -p "${TMPDIR:-/tmp}")

function cleanup {
  sync || true
  for mount in "${mounts[@]}"; do
    echo "Unmounting ${mount}..."
    umount $mount || true
  done
  mounts=()
  if [ -d "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR" || true
  fi
}
trap cleanup EXIT

boot_dir="${WORK_DIR}/boot"
rootfs_dir="${WORK_DIR}/rootfs"
persist_dir="${WORK_DIR}/persist"

CLOCKWORK_SD_SFX=$CLOCKWORK_SD
if [ -b ${CLOCKWORK_SD}p1 ]; then
  CLOCKWORK_SD_SFX=${CLOCKWORK_SD}p
fi

mkdir -p $boot_dir
echo "Mounting ${CLOCKWORK_SD_SFX}1 to $boot_dir..."
mounts+=("$boot_dir")
mount ${CLOCKWORK_SD_SFX}1 $boot_dir

echo "Mounting ${CLOCKWORK_SD_SFX}2 to $rootfs_dir..."
mkdir -p $rootfs_dir
mounts+=("$rootfs_dir")
mount ${CLOCKWORK_SD_SFX}2 $rootfs_dir

echo "Mounting ${CLOCKWORK_SD_SFX}3 to $persist_dir..."
mkdir -p $persist_dir
mounts+=("$persist_dir")
mount ${CLOCKWORK_SD_SFX}3 $persist_dir

echo "Copying kernel image..."
sync
rsync -rav --no-perms --no-owner --no-group $img_path $boot_dir/
sync

echo "Copying uInitrd..."
rsync -rav --no-perms --no-owner --no-group $uinit_path $boot_dir/rootfs.cpio.uboot
sync

if [ -d "$outp_path/images/rootfs_part" ]; then
  echo "Copying rootfs_part..."
  rsync -rav --no-perms --no-owner --no-group $outp_path/images/rootfs_part/ $rootfs_dir/
  sync
fi

if [ -d "$outp_path/images/persist_part" ]; then
  echo "Copying persist_part..."
  rsync -rav --no-perms --no-owner --no-group $outp_path/images/persist_part/ $persist_dir/
  sync
fi

enable_silent() {
  if [ -f "$images_path/.disable-serial-console" ]; then
    echo "Disabling serial console and enabling silent mode..."
    sed -i -e "/^setenv condev/s/^/# /" -e "s/# setenv silent/setenv silent/" $1
  fi
}

echo "Compiling boot.cmd..."
cp $boot_conf $boot_dir/boot.cmd
enable_silent $boot_dir/boot.cmd
mkimage -A arm -C none -T script -d $boot_dir/boot.cmd $boot_dir/boot.scr
sync

echo "Copying device tree blobs..."
rsync -rav --no-perms --no-owner --no-group ${images_path}/*.dtb $boot_dir/
sync

cleanup
echo "Install complete."
