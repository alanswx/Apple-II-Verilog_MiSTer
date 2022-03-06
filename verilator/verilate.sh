OPTIMIZE="-O3 --x-assign fast --x-initial fast --noassert"
WARNINGS="-Wno-fatal"
DEFINES="+define+SIMULATION=1 "
echo "verilator -cc --compiler msvc $WARNINGS $OPTIMIZE"
/usr/local/bin/verilator -cc --compiler msvc $WARNINGS $OPTIMIZE --converge-limit 6000 --top-module emu sim.v \
-I../rtl/ \
-I../rtl/ssc \
-I../rtl/mouse \
-I../rtl/mockingboard \
../rtl/mockingboard/mockingboard.v \
../rtl/super_serial_card.v \
../rtl/uart_6551.v \
../rtl/6551tx.v \
../rtl/6551rx.v \
-I../rtl/t65 \
t65.v \
t65_alu.v \
t65_mcode.v
