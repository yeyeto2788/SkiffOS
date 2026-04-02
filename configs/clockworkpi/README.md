# Clockwork Pi Configurations

This configuration package series configures Buildroot to produce a SkiffOS
image for Clockwork Pi devices.

References:

 - https://www.clockworkpi.com/gameshell
 - https://linux-sunxi.org/ClockworkPi_Gameshell
 - https://github.com/clockworkpi/GameShell

# Board Compatibility

| **Board**    | **Config Package**          | Notes          |
|--------------|-----------------------------|----------------|
| [GameShell]  | [clockworkpi/gameshell]     | ⚠ Experimental |

[GameShell]: https://www.clockworkpi.com/gameshell
[clockworkpi/gameshell]: ./gameshell

# GameShell (CPI3)

The Clockwork Pi GameShell is an open-source modular handheld game console.

**Hardware specs:**

| Component   | Details |
|-------------|---------|
| SoC         | Allwinner R16 / A33 (sun8i), quad-core ARM Cortex-A7 @ 1.2 GHz |
| RAM         | 512 MB LPDDR3 |
| Display     | 2.7" KD027 LCD, 320×240, connected via GPIO bit-banged SPI |
| WiFi / BT   | Broadcom BCM43430 (Ampak AP6212), SDIO on MMC1 |
| Buttons     | USB HID microcontroller (rancidbacon.com, USB ID 4242:E131) on OHCI |
| USB         | EHCI (USB 2.0 host) + OHCI (USB 1.1 host) + MUSB OTG |
| Audio       | Allwinner sun8i analog codec + speaker amplifier (GPIO PL3) |
| PMIC        | X-Powers AXP223 on R_RSB bus |
| Storage     | MicroSD (MMC0), card-detect on PB3 |
| Console     | UART0 on PB8 (TX) / PB9 (RX), 115200 baud |

# Compilation

Standard SkiffOS build. Requires a Linux host with Buildroot dependencies
installed (gcc, make, etc. — see the [Buildroot manual](https://buildroot.org/downloads/manual/manual.html#requirement)).

```bash
# Select the GameShell target plus a user environment
export SKIFF_CONFIG=clockworkpi/gameshell,skiff/core

# Build (this will take a while on first run)
make compile
```

To add a workspace name (useful if building multiple targets):

```bash
export SKIFF_WORKSPACE=gameshell
export SKIFF_CONFIG=clockworkpi/gameshell,skiff/core
make compile
```

# Flashing

These commands require root. Insert your SD card and identify its device node
(e.g. `/dev/sdb` — **verify carefully before proceeding**).

```bash
export CLOCKWORK_SD=/dev/sdX   # replace with your actual device

# Format the SD card and flash U-Boot (run once)
make cmd/clockworkpi/gameshell/format

# Install the OS (run after every compile)
make cmd/clockworkpi/gameshell/install
```

`format` creates the partition layout (FAT boot + ext4 rootfs + ext4 persist)
and writes the U-Boot SPL at the required offset (8 KiB). This only needs to
be run once. `install` copies the kernel, device tree, initramfs, and boot
script to the SD card and can be re-run after each `make compile`.

To build a flashable image file instead of writing directly to a device:

```bash
export CLOCKWORK_IMAGE=/path/to/output.img
make cmd/clockworkpi/gameshell/buildimage
```

# Booting

Insert the SD card into the GameShell and power on. SkiffOS will boot from
the SD card. Serial console output is available on the UART0 pads (PB8/PB9)
at 115200 8N1 — useful for diagnosing boot failures.

# Known Limitations

- **Display**: The KD027 panel uses a custom 9-bit GPIO SPI protocol. The
  mainline `fbtft` ILI9341 driver is used as a fallback and should provide
  basic framebuffer output. Full panel support (brightness control, correct
  init sequence) requires the out-of-tree `kd027-lcd` driver.

- **U-Boot DRAM**: The `A33-OLinuXino_defconfig` is used as the closest
  upstream U-Boot config for the A33 SoC. DRAM parameters (CLK=432 MHz,
  ZQ=15291, ODT_EN=y) should be compatible with the GameShell's LPDDR3.
  If the board hangs silently at power-on, connect a serial adapter and check
  for DRAM init errors; the parameters may need tuning.

- **WiFi firmware**: Requires `brcm/brcmfmac43430a0-sdio.bin` from
  `linux-firmware`. This is included via `BR2_PACKAGE_LINUX_FIRMWARE_BRCM_BCM43XX`.
  A board-specific NVRAM file (`brcmfmac43430a0-sdio.clockwork,clockworkpi-cpi3.txt`)
  can be added to `root_overlay/lib/firmware/brcm/` for better WiFi performance.
