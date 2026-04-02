# Clockwork Pi CPI3 (GameShell) boot script
# Vendor uses: kernel=0x48000000, dtb=0x49000000, bootm+uImage
# SkiffOS uses: zImage + bootz with U-Boot default env addresses

setenv fdt_high ffffffff

setenv condev "console=ttyS0,115200n8"
setenv bootargs "root=/dev/initrd rootwait ro ramdisk_size=100000 ${condev} earlyprintk no_console_suspend net.ifnames=0"

# Use U-Boot env addresses if set, else fall back to vendor addresses
test -n "${kernel_addr_r}" || setenv kernel_addr_r 0x48000000
test -n "${fdt_addr_r}"    || setenv fdt_addr_r    0x49000000
setenv initramfs_addr_r "0x44000000"

fatload mmc 0 ${initramfs_addr_r} rootfs.cpio.uboot
fatload mmc 0 ${kernel_addr_r} zImage
fatload mmc 0 ${fdt_addr_r} sun8i-r16-clockworkpi-cpi3.dtb

bootz ${kernel_addr_r} ${initramfs_addr_r} ${fdt_addr_r}
