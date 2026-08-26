OPTIMIZE="-O3 --x-assign fast --x-initial fast --noassert"
WARNINGS="-Wno-fatal"
DEFINES="+define+SIMULATION=1 "
echo "verilator -cc --compiler msvc $WARNINGS $OPTIMIZE"
/usr/local/bin/verilator -cc --compiler msvc $WARNINGS $OPTIMIZE --converge-limit 6000 --top-module emu \
-I../rtl/ \
-I../rtl/mouse \
-I../rtl/mockingboard \
-I../rtl/t65 \
sim.v \
../rtl/super_serial_card.v  \
../rtl/t65/t65_alu.v \
../rtl/t65/t65_mcode.v \
../rtl/t65/t65_pack.v \
../rtl/t65/t65.v \
../rtl/hdd.v \
../rtl/uart_6551.v \
../rtl/6551tx.v \
../rtl/6551rx.v \
../rtl/R65Cx2.sv \
../rtl/vga_controller.v  \
../rtl/mockingboard/mockingboard.v  \
../rtl/mockingboard/via6522.v  \
../rtl/mockingboard/YM2149.sv  \
../rtl/disk_ii.v  \
../rtl/clock_card.v  \
../rtl/apple2_top.v  \
../rtl/apple2.v  \
../rtl/gfloppy.v  \
../rtl/track_loader.v  \
../rtl/keyboard.v 
