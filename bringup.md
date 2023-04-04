# Board Bring-Up
After assembly and inspection, power on the board with a current limited power
supply set to 5V and 100mA through the USB test pads.
- [ ] power LEDs light up
- [ ] current draw < TBD mA
- [ ] magic smoke stays in device

If all is fine, the board can be powered from USB.

## Debug Adapter
This dev board provides an STM32F103 USB to JTAG/SWD and UART adapter based on
[Black Magic Probe](https://black-magic.org/). The next step is building and
flashing the BMP firmware.

### Build
Download and compile [blackmagic](https://github.com/blackmagic-debug/blackmagic)
for the `swlink` probe host.
```shell
git clone --recurse-submodules https://github.com/blackmagic-debug/blackmagic
cd blackmagic
make PROBE_HOST=swlink
export BMP_FW=./src/
```

#### Nix
The Nix package repository provides expressions to build the firmware binaries.
```shell
nix-build '<nixpkgs>' -A blackmagic
export BMP_FW=./result/firmware/swlink/
```

### Flash DFU Bootloader
All STM32F103 and [its clones](https://hackaday.com/2020/10/22/stm32-clones-the-good-the-bad-and-the-ugly/)
can be flashed via SWD. Only genuine devices from ST seem to provide the UART bootloader.

Disconnect the dev board from USB, short the *BOOT* jumper with a wire or pair of
tweezers and connect USB.

#### SWD
This requires an USB to SWD adapter, ideally another BMP. Connect the SWD pins of
your debug adapter to the SWD pins next to the break-away section.

Currently the Nix package repository build of the firmware doesn't export the dfu
elf file. So you will need to build from source.

Use `arm-none-eabi-gdb` to write the bootloader.

```shell
arm-none-eabi-gdb -nx --batch \
  -ex 'target extended-remote /dev/ttyACM0' \
  -ex 'monitor swdp_scan' \
  -ex 'attach 1' \
  -ex 'monitor erase' \
  -ex 'load' \
  -ex 'compare-sections' \
  -ex 'kill' \
  src/blackmagic_dfu.elf
```

#### UART
This requires an USB to UART adapter, like FT232 or CP210x.

Connect the RX and TX from the USB UART adapter to the castellated pads on the
side of the dev boards debug adapter part.
Then use [`stm32flash`](https://sourceforge.net/p/stm32flash/wiki/Home/) to write
the DFU bootloader. Adapt `/dev/ttyUSB0` according to your system.

```shell
# (optional) erase flash
stm32flash /dev/ttyUSB0 -o

stm32flash /dev/ttyUSB0 -g 0 -v -w ${BMP_FW}/blackmagic_dfu.bin
```

### Flash Firmware
When the bootloader is flashed, the board should be enumerated as an USB DFU
device. You can then upgrade the firmware with [`dfu-util`](https://dfu-util.sourceforge.net/). This may require sudo privileges depending on udev rules.

```shell
dfu-util -d 1d50:6018,:6017 -s 0x08002000:leave -D ${BMP_FW}/blackmagic.bin
```
