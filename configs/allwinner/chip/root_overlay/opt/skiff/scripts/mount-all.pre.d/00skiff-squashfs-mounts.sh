# note: persist is mounted by skiff-init-squashfs
export PERSIST_DEVICE="/dev/mmcblk0p1"
export ROOTFS_DEVICE="/mnt/persist/rootfs"
export ROOTFS_MNT_FLAGS="--rbind"
export BOOT_DEVICE="/mnt/persist/boot"
export BOOT_MNT_FLAGS="--rbind"
