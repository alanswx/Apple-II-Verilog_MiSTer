#!/bin/bash
#
# Apple //e Verilator regression suite
#
# Each test runs the simulator to a fixed frame, saves a PNG, and compares it
# byte-for-byte against a blessed reference in regression_images/.  The sim is
# deterministic, so an exact diff is the right check - but only if every test
# passes --fixed-time, because this core has a clock card fed from the host
# clock and any screen showing the date would otherwise never match.
#
# Usage:
#   ./regression.sh              run everything
#   ./regression.sh --bless      (re)create the reference images
#   ./regression.sh -h
#
# Must be run from the verilator/ directory: the ROMs are pulled in by
# $readmemh with paths relative to it.

set -u

REF_DIR="regression_images"
SIM="./obj_dir/Vemu"
BLESS=0

for arg in "$@"; do
	case "$arg" in
		--bless) BLESS=1 ;;
		-h|--help)
			sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
			exit 0 ;;
		*) echo "Unknown option: $arg"; exit 1 ;;
	esac
done

# Disk images the suite needs. They are gitignored (too large to track), so a
# missing one SKIPs its tests rather than failing the run.
REQUIRED_DISKS=(
	"floppy.nib"
	"hd.hdv"
)

PASSED=0
FAILED=0
SKIPPED=0
FAILED_TESTS=()

if [ ! -x "$SIM" ]; then
	echo "ERROR: $SIM not found. Run 'make' first."
	exit 1
fi

mkdir -p "$REF_DIR"

echo "=============================================="
echo " Apple //e Verilator regression"
echo "=============================================="
echo

echo "Disk images:"
for d in "${REQUIRED_DISKS[@]}"; do
	if [ -f "$d" ]; then
		printf "  %-40s present\n" "$d"
	else
		printf "  %-40s MISSING (dependent tests skip)\n" "$d"
	fi
done
echo

# run_test <name> <frame> <disk-or-empty> [extra args...]
#
# Runs the sim to <frame>, screenshots there, and diffs against the reference.
run_test() {
	local name="$1"; shift
	local frame="$1"; shift
	local disk="$1"; shift

	local png="screenshot_frame_$(printf '%04d' "$frame").png"
	local ref="$REF_DIR/${name}.png"
	local log="${name}.txt"

	printf "%-34s " "$name"

	if [ -n "$disk" ] && [ ! -f "$disk" ]; then
		echo "SKIP (no $disk)"
		SKIPPED=$((SKIPPED + 1))
		return
	fi

	rm -f "$png"

	# --fixed-time is mandatory here; see the header comment.
	if ! timeout 1800 "$SIM" --fixed-time --quiet \
	     --screenshot "$frame" --stop-at-frame "$frame" "$@" > "$log" 2>&1; then
		echo "FAIL (sim error or timeout, see $log)"
		FAILED=$((FAILED + 1))
		FAILED_TESTS+=("$name")
		return
	fi

	if [ ! -f "$png" ]; then
		echo "FAIL (no screenshot produced, see $log)"
		FAILED=$((FAILED + 1))
		FAILED_TESTS+=("$name")
		return
	fi

	if [ "$BLESS" = "1" ]; then
		mv "$png" "$ref"
		echo "BLESSED -> $ref"
		PASSED=$((PASSED + 1))
		return
	fi

	if [ ! -f "$ref" ]; then
		echo "SKIP (no reference; run --bless)"
		mv "$png" "${name}_current.png"
		SKIPPED=$((SKIPPED + 1))
		return
	fi

	if cmp -s "$png" "$ref"; then
		echo "PASS"
		rm -f "$png" "$log"
		PASSED=$((PASSED + 1))
	else
		mv "$png" "${name}_current.png"
		echo "FAIL (differs; see ${name}_current.png vs $ref)"
		FAILED=$((FAILED + 1))
		FAILED_TESTS+=("$name")
	fi
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

# The machine comes up and reaches the Applesoft prompt.
run_test "boot_basic_prompt" 600 "floppy.nib" --floppy floppy.nib

# DOS 3.3 has booted off the floppy and the catalog reads back.  This is the
# broadest single check in the suite: CPU, video, keyboard and the whole
# disk path all have to work for the listing to appear.
run_test "floppy_dos33_catalog" 1400 "floppy.nib" \
	--floppy floppy.nib --send-keys '700:CATALOG\n'

# CPU, keyboard and Applesoft all the way through to arithmetic.  Cheap, and
# it fails loudly if key injection or the BASIC ROM path breaks.
run_test "basic_print" 1400 "floppy.nib" \
	--floppy floppy.nib --send-keys '700:PRINT 2+2\n'

# No disk in the drive: the //e retries slot 6 forever and should sit on the
# splash screen.  Guards against a hang or a crash on the empty-drive path.
run_test "no_floppy_splash" 600 "" --no-floppy

# ---------------------------------------------------------------------------

echo
echo "=============================================="
echo " passed:  $PASSED"
echo " failed:  $FAILED"
echo " skipped: $SKIPPED"
if [ "$FAILED" -gt 0 ]; then
	echo
	echo " failures:"
	for t in "${FAILED_TESTS[@]}"; do echo "   - $t"; done
fi
echo "=============================================="

[ "$FAILED" -eq 0 ]
