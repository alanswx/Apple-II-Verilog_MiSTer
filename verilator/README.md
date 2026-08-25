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

- **`#` displays as `£`.** The built-in `rtl/roms/video.hex` is a single 4K
  character ROM that renders `$23` as a pound sign. The published VHDL core
  has switchable US / LOCAL video ROMs; this one does not, so anything typing
  `#` (e.g. `PR#7`) looks wrong on screen even though the keystroke is
  correct.
- **Screenshots carry a margin.** `VGA_WIDTH`/`VGA_HEIGHT` are 320×240
  (`sim_main.cpp`) while the core's active area is about 282 pixels wide, and
  `sim.v` samples `ce_pix` at half rate. Raising the width and sampling every
  clock would recover horizontal resolution and artifact colour.
- **`hd.hdv` bootability is unverified** — `PR#7` appears to hang rather than
  boot, so there is no hard-disk test in the suite yet.
- **The top level is duplicated.** `sim.v` re-implements the body of
  `../Apple-II.sv` (same RAM arrays, same `apple2_top` instantiation, same
  floppy/HDD plumbing). Any top-level change has to be made in both places.
  Collapsing them into a shared include is the highest-leverage cleanup here.
