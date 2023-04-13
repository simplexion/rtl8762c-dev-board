# Board Bring-Up

## Power On
After assembly and inspection, power on the board with a current limited power
supply set to 5V and 100mA through the USB test pads.
- [ ] power LEDs light up
- [ ] current draw < TBD mA
- [ ] magic smoke stays in device

If all is fine, the board can be powered from USB.

## Debug Probe Firmware
This dev board provides an RP2040 as USB to JTAG/SWD and UART adapter based on
[picoprobe](https://github.com/raspberrypi/picoprobe).

While shorting the boot jumper (with tweezers), plug the board into USB.
It should show up as a storage device.

Download the firmware file from the [release page](https://github.com/simplexion/picoprobe/releases/tag/debugprobe-cmsis-v1.02-rtl8762c-dev-baords).
You can store it directly to the pico or first on your file system and then copy it over.

After successful firmware upload the device should enumerate as a `Debug Probe (CMSIS-DAP)` with `USB ACM device`.
