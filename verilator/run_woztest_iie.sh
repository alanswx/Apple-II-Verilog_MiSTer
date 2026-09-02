#!/usr/bin/env bash
# Run the Applesauce WOZ Test Images through the Verilog //e harness.
# Usage: ./run_woztest_iie.sh OUTDIR [FRAMES] [JOBS] [SUITEDIR]
OUT="${1:-woztest_iie}"; FRAMES="${2:-1200}"; JOBS="${3:-12}"
SUITE="${4:-/home/alans/mister/Apple-IIgs_MiSTer/vsim/woztest_suite}"
mkdir -p "$OUT/shots"; CSV="$OUT/results.csv"
echo "status,png_size,png_hash,image" > "$CSV"
run_one() {
  local w="$1" shot sz hash st
  shot="$OUT/shots/$(basename "$w" .woz | tr ' /' '__').png"
  timeout 1500 ./obj_dir/Vemu --floppy "$w" --fixed-time --quiet \
      --screenshot "$FRAMES" --stop-at-frame $((FRAMES+2)) --screenshot-name "$shot" >/dev/null 2>&1
  if [[ -f "$shot" ]]; then
    sz=$(stat -c%s "$shot"); hash=$(md5sum "$shot"|awk '{print $1}')
    # 2744 bytes is the bare "Apple //e" banner (nothing booted)
    if [[ $sz -le 2800 ]]; then st=BANNER; else st=SCREEN; fi
  else sz=0; hash=""; st=CRASH; fi
  printf '%s,%d,%s,"%s"\n' "$st" "$sz" "$hash" "$(basename "$w")" >> "$CSV"
  printf '  %-8s %-52s\n' "$st" "$(basename "$w" .woz)"
}
export -f run_one; export OUT FRAMES CSV
ls "$SUITE"/*.woz | tr '\n' '\0' | xargs -0 -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {}
echo; awk -F',' 'NR>1{c[$1]++} END{for(s in c) printf "  %-8s %d\n",s,c[s]}' "$CSV"
