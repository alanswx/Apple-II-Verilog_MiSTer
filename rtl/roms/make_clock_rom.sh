acme -o clock.bin clock.asm
srec_cat clock.bin --binary -o clock2.hex --ascii_hex
cp clock2.hex ../../verilator/rtl/roms/

