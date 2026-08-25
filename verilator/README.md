# Verilator harness

A Verilator build of the Apple //e core with an ImGui front end, plus batch
options so it can be driven from a script.

Run everything from **this directory** — the ROMs are pulled in by
`$readmemh` with paths relative to it (`rtl/roms/*.hex`).

## Build

```bash
make
```

Needs Verilator (tested with 4.204) and SDL2. `make clean` removes `obj_dir/`.

## Running

Interactive, as before:

```bash
./obj_dir/Vemu
```

Batch:

```bash
./obj_dir/Vemu --floppy floppy.nib --fixed-time \
               --screenshot 300 --stop-at-frame 300
```

### Options

| Option | Meaning |
|---|---|
| `--floppy <file.nib>` | Drive 1 (slot 6, drive 1). Default `floppy.nib` |
| `--floppy2 <file.nib>` | Drive 2 |
| `--hdd <file.hdv>` (or `--disk`) | Hard disk, slot 7 |
| `--no-floppy` | Start with an empty drive |
| `--screenshot N[,N..]` | Write a PNG at those frame numbers |
| `--screenshot-name FILE` | Override the output filename |
| `--stop-at-frame N` | Exit once frame N is reached |
| `--send-keys F:TEXT` | Type TEXT at frame F. Repeatable |
| `--fixed-time [epoch]` | Freeze the RTC |
| `--quiet` | Suppress per-frame progress lines |
| `-h`, `--help` | Usage |

Floppies must be 232960-byte `.nib` images — the core's track loader reads
13 × 512-byte blocks per track and there is no format conversion in the
harness yet.

### `--send-keys` escapes

`\n` `\r` `\t` `\b` `\e` `\\` `\xNN`, plus `\cX` for Ctrl-X and
`\U` `\D` `\L` `\R` for the arrow keys.

```bash
./obj_dir/Vemu --floppy floppy.nib --send-keys '700:CATALOG\n' \
               --screenshot 1400 --stop-at-frame 1400
```

Keys go through the same `SimInput` queue the interactive path uses, so no
RTL change is involved. Allow a few hundred frames between the injection and
the screenshot: `SimInput::BeforeEval()` releases one event every
`keyEventWait` ticks, so a long string takes a while to type.

## Regression suite

```bash
./regression.sh            # run
./regression.sh --bless    # (re)create reference images
```

Each test runs to a fixed frame, screenshots, and compares byte-for-byte
against `regression_images/`. The simulation is deterministic, so an exact
diff is the right check — **provided every test passes `--fixed-time`**.
This core has a clock card fed from the host clock, so without it any screen
showing the date would never match twice.

Current tests:

| Test | Covers |
|---|---|
| `boot_basic_prompt` | Machine comes up and reaches the Applesoft prompt |
| `floppy_dos33_catalog` | Boots DOS 3.3 and lists the catalog — the broadest check: CPU, video, keyboard and the whole disk path |
| `basic_print` | Key injection through to Applesoft arithmetic |
| `no_floppy_splash` | Empty drive doesn't hang or crash the core |

Disk images are gitignored, so a missing one SKIPs its tests instead of
failing the run. A test with no reference image also SKIPs and leaves
`<name>_current.png` for inspection.

## Known quirks

- **Video ROM is US, and it is a build-time choice.** The 8K
  `Apple IIe Video UK-US - Enhanced - 342-0273-A` ROM holds two 4K national
  sets that differ at exactly two characters, `$23` and `$A3` — `#` in the US
  set, `£` in the UK set. They are split here into `rtl/roms/video_us.hex`
  and `video_uk.hex`, and `rtl/video_generator.v` selects one. This core used
  to hardwire the UK set, so `#` rendered as `£`.

  The published VHDL core instead loads the whole 8K ROM and selects a half at
  runtime with `ROMSWITCH` (OSD "Video Rom, US / LOCAL", defaulting to US).
  Porting that is the proper fix; until then, edit the filename in
  `video_generator.v`.

- **ROMs are duplicated.** There are two trees: `../rtl/roms/` for synthesis
  and `verilator/rtl/roms/` for the sim, because `$readmemh` resolves relative
  to the working directory. A ROM added to one must be copied to the other.
- **Screenshots carry a margin.** `VGA_WIDTH`/`VGA_HEIGHT` are 320×240
  (`sim_main.cpp`) while the core's active area is about 282 pixels wide, and
  `sim.v` samples `ce_pix` at half rate. Raising the width and sampling every
  clock would recover horizontal resolution and artifact colour.
- **`hd.hdv` bootability is unverified** — `PR#7` appears to hang rather than
  boot, so there is no hard-disk test in the suite yet.
- **A flashing cursor sits in most screenshots.** It is deterministic, so
  exact diffs still work, but a test whose frame lands mid-blink will differ by
  a single character cell if timing shifts at all. If a test proves fragile,
  move its frame rather than loosening the comparison.

- **The top level is duplicated.** `sim.v` re-implements the body of
  `../Apple-II.sv` (same RAM arrays, same `apple2_top` instantiation, same
  floppy/HDD plumbing). Any top-level change has to be made in both places.
  Collapsing them into a shared include is the highest-leverage cleanup here.
