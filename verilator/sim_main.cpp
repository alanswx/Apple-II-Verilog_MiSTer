#include <verilated.h>
#include "Vemu.h"

#include "imgui.h"
#include "implot.h"
#ifndef _MSC_VER
#include <stdio.h>
#include <SDL.h>
#include <SDL_opengl.h>
#else
#define WIN32
#include <dinput.h>
#endif

#include "sim_console.h"
#include "sim_bus.h"
#include "sim_blkdevice.h"
#include "sim_video.h"
#include "sim_audio.h"
#include "sim_input.h"
#include "sim_clock.h"

#include "../imgui/imgui_memory_editor.h"
#include "../imgui/ImGuiFileDialog.h"

#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <sstream>
#include <algorithm>
#include <cstring>
#include <cstdlib>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "sim/stb_image_write.h"
using namespace std;

// Batch / automation control
// --------------------------
static std::vector<int> screenshot_frames;
static std::string      screenshot_name_override;
static int              stop_at_frame = -1;
static bool             stop_at_frame_enabled = false;
static std::string      floppy_image  = "floppy.nib";
static std::string      floppy2_image = "";
static std::string      hdd_image     = "";
static bool             fixed_time = false;
static time_t           fixed_time_epoch = 527169600; // 1986-09-15 00:00:00 UTC
static bool             batch_verbose = true;

struct KeyInjection { int frame; std::string keys; };
static std::vector<KeyInjection> key_injections;

// Simulation control
// ------------------
int initialReset = 48;
bool run_enable = 1;
int batchSize = 650000;
bool single_step = 0;
bool multi_step = 0;
int multi_step_amount = 1024;

// Debug GUI 
// ---------
const char* windowTitle = "Verilator Sim: Apple II";
const char* windowTitle_Control = "Simulation control";
const char* windowTitle_DebugLog = "Debug log";
const char* windowTitle_Video = "VGA output";
const char* windowTitle_Audio = "Audio output";
bool showDebugLog = true;
DebugConsole console;
MemoryEditor mem_edit;

// HPS emulator
// ------------
SimBus bus(console);
SimBlockDevice blockdevice(console);

// Input handling
// --------------
SimInput input(13, console);
const int input_right = 0;
const int input_left = 1;
const int input_down = 2;
const int input_up = 3;
const int input_a = 4;
const int input_b = 5;
const int input_x = 6;
const int input_y = 7;
const int input_l = 8;
const int input_r = 9;
const int input_select = 10;
const int input_start = 11;
const int input_menu = 12;

// Video
// -----
#define VGA_WIDTH 320
#define VGA_HEIGHT 240
#define VGA_ROTATE 0  // 90 degrees anti-clockwise
#define VGA_SCALE_X vga_scale
#define VGA_SCALE_Y vga_scale
SimVideo video(VGA_WIDTH, VGA_HEIGHT, VGA_ROTATE);
float vga_scale = 2.5;

// Verilog module
// --------------
Vemu* top = NULL;

vluint64_t main_time = 0;	// Current simulation time.
double sc_time_stamp() {	// Called by $time in Verilog.
	return main_time;
}

int clk_sys_freq = 24000000;
SimClock clk_sys(1);

int soft_reset=0;
vluint64_t soft_reset_time=0;

// Audio
// -----
//#define DISABLE_AUDIO
#ifndef DISABLE_AUDIO
SimAudio audio(clk_sys_freq, false);
#endif

// Reset simulation variables and clocks
void resetSim() {
	main_time = 0;
	top->reset = 1;
	clk_sys.Reset();
}

	//MSM6242B layout
void send_clock() {
	//printf("Update RTC %ld %d\n",main_time,send_clock_done);
	uint8_t rtc[8];
	
//	printf("Update RTC %ld %d\n",main_time,send_clock_done);
	
	time_t t;

	if (fixed_time)
		t = fixed_time_epoch;   // deterministic RTC, for reproducible screenshots
	else
		time(&t);

	struct tm tm;
	if (fixed_time)
		gmtime_r(&t, &tm);      // avoid host timezone leaking into a fixed run
	else
		localtime_r(&t, &tm);

	
	rtc[0] = (tm.tm_sec % 10) | ((tm.tm_sec / 10) << 4);
	rtc[1] = (tm.tm_min % 10) | ((tm.tm_min / 10) << 4);
	rtc[2] = (tm.tm_hour % 10) | ((tm.tm_hour / 10) << 4);
	rtc[3] = (tm.tm_mday % 10) | ((tm.tm_mday / 10) << 4);

	rtc[4] = ((tm.tm_mon + 1) % 10) | (((tm.tm_mon + 1) / 10) << 4);
	rtc[5] = (tm.tm_year % 10) | (((tm.tm_year / 10) % 10) << 4);
	rtc[6] = tm.tm_wday;
	rtc[7] = 0x40;

	// 64:0
	 
	//top->RTC_l = 0;
	top->RTC_l = rtc[0] | rtc[1] << 8 | rtc[2] << 16 | rtc[3] << 24 ;
	printf("RTC: %x 0: %x",top->RTC_l,rtc[0]);
	top->RTC_h = rtc[4] | rtc[5] << 8 | rtc[6] << 16 | rtc[7] << 24 ;
	//t += t - mktime(gmtime(&t));
	top->RTC_toggle=~top->RTC_toggle;
	// 32:0
	//top->TIMESTAMP=t;//|0x01<<32;


}


int verilate() {

	if (!Verilated::gotFinish()) {
		if (soft_reset){
			fprintf(stderr,"soft_reset.. in gotFinish\n");
			top->soft_reset = 1;
			soft_reset=0;
			soft_reset_time=0;
			fprintf(stderr,"turning on %x\n",top->soft_reset);
		}
		if (clk_sys.IsRising()) {
			soft_reset_time++;
		}
		if (soft_reset_time==initialReset) {
			top->soft_reset = 0; 
			fprintf(stderr,"turning off %x\n",top->soft_reset);
			fprintf(stderr,"soft_reset_time %ld initialReset %x\n",soft_reset_time,initialReset);
		} 

		// Assert reset during startup
		if (main_time < initialReset) { top->reset = 1; }
		// Deassert reset after startup
		if (main_time == initialReset) { top->reset = 0; }

		// Clock dividers
		clk_sys.Tick();

		// Set system clock in core
		top->clk_sys = clk_sys.clk;

		// Simulate both edges of system clock
		if (clk_sys.clk != clk_sys.old) {
			if (clk_sys.IsRising() && *bus.ioctl_download!=1	) blockdevice.BeforeEval(main_time);
			if (clk_sys.clk) {
				input.BeforeEval();
				bus.BeforeEval();
			}
			top->eval();
			if (clk_sys.clk) { bus.AfterEval(); blockdevice.AfterEval(); }
		}

#ifndef DISABLE_AUDIO
		if (clk_sys.IsRising())
		{
			audio.Clock(top->AUDIO_L, top->AUDIO_R);
		}
#endif

		// Output pixels on rising edge of pixel clock
		if (clk_sys.IsRising() && top->CE_PIXEL ) {
			uint32_t colour = 0xFF000000 | top->VGA_B << 16 | top->VGA_G << 8 | top->VGA_R;
			video.Clock(top->VGA_HB, top->VGA_VB, top->VGA_HS, top->VGA_VS, colour);
		}

		if (clk_sys.IsRising()) {
			main_time++;
		}
		return 1;
	}

	// Stop verilating and cleanup
	top->final();
	delete top;
	exit(0);
	return 0;
}

unsigned char mouse_clock = 0;
unsigned char mouse_clock_reduce = 0;
unsigned char mouse_buttons = 0;
unsigned char mouse_x = 0;
unsigned char mouse_y = 0;

char spinner_toggle = 0;


// ---------------------------------------------------------------------------
// Keyboard injection (PS/2 set 2, US layout)
// ---------------------------------------------------------------------------
//
// Reaches the core through the same SimInput queue the interactive path uses,
// so no RTL change is needed: SimInput::BeforeEval() pops one event every
// keyEventWait ticks and drives ps2_key[10:0].

struct AsciiToPS2 { unsigned int scancode; bool needs_shift; };

static AsciiToPS2 ascii_to_ps2(char c)
{
	AsciiToPS2 r = { 0xFF, false };

	static const unsigned int letters[] = {
		0x1c, 0x32, 0x21, 0x23, 0x24, 0x2b, 0x34, 0x33,  // a-h
		0x43, 0x3b, 0x42, 0x4b, 0x3a, 0x31, 0x44, 0x4d,  // i-p
		0x15, 0x2d, 0x1b, 0x2c, 0x3c, 0x2a, 0x1d, 0x22,  // q-x
		0x35, 0x1a                                        // y-z
	};
	static const unsigned int digits[] = {
		0x45, 0x16, 0x1e, 0x26, 0x25, 0x2e, 0x36, 0x3d, 0x3e, 0x46
	};

	if (c >= 'a' && c <= 'z') { r.scancode = letters[c - 'a']; return r; }
	if (c >= 'A' && c <= 'Z') { r.scancode = letters[c - 'A']; r.needs_shift = true; return r; }
	if (c >= '0' && c <= '9') { r.scancode = digits[c - '0'];  return r; }

	switch (c) {
	case ' ':  r.scancode = 0x29; break;
	case '\n': case '\r': r.scancode = 0x5a; break;   // Return
	case '\t': r.scancode = 0x0d; break;
	case '\b': r.scancode = 0x66; break;
	case 0x1b: r.scancode = 0x76; break;              // Escape
	case '-':  r.scancode = 0x4e; break;
	case '=':  r.scancode = 0x55; break;
	case '[':  r.scancode = 0x54; break;
	case ']':  r.scancode = 0x5b; break;
	case '\\': r.scancode = 0x5d; break;
	case ';':  r.scancode = 0x4c; break;
	case '\'': r.scancode = 0x52; break;
	case '`':  r.scancode = 0x0e; break;
	case ',':  r.scancode = 0x41; break;
	case '.':  r.scancode = 0x49; break;
	case '/':  r.scancode = 0x4a; break;
	case '!':  r.scancode = 0x16; r.needs_shift = true; break;
	case '@':  r.scancode = 0x1e; r.needs_shift = true; break;
	case '#':  r.scancode = 0x26; r.needs_shift = true; break;
	case '$':  r.scancode = 0x25; r.needs_shift = true; break;
	case '%':  r.scancode = 0x2e; r.needs_shift = true; break;
	case '^':  r.scancode = 0x36; r.needs_shift = true; break;
	case '&':  r.scancode = 0x3d; r.needs_shift = true; break;
	case '*':  r.scancode = 0x3e; r.needs_shift = true; break;
	case '(':  r.scancode = 0x46; r.needs_shift = true; break;
	case ')':  r.scancode = 0x45; r.needs_shift = true; break;
	case '_':  r.scancode = 0x4e; r.needs_shift = true; break;
	case '+':  r.scancode = 0x55; r.needs_shift = true; break;
	case '{':  r.scancode = 0x54; r.needs_shift = true; break;
	case '}':  r.scancode = 0x5b; r.needs_shift = true; break;
	case '|':  r.scancode = 0x5d; r.needs_shift = true; break;
	case ':':  r.scancode = 0x4c; r.needs_shift = true; break;
	case '"':  r.scancode = 0x52; r.needs_shift = true; break;
	case '~':  r.scancode = 0x0e; r.needs_shift = true; break;
	case '<':  r.scancode = 0x41; r.needs_shift = true; break;
	case '>':  r.scancode = 0x49; r.needs_shift = true; break;
	case '?':  r.scancode = 0x4a; r.needs_shift = true; break;
	}
	return r;
}

// Internal markers produced by the --send-keys escape parser.
enum {
	KEYMARK_CTRL  = 0x01,   // next char is sent with Left Ctrl held
	KEYMARK_UP    = 0x04,
	KEYMARK_DOWN  = 0x05,
	KEYMARK_LEFT  = 0x06,
	KEYMARK_RIGHT = 0x07
};

static void queue_key_string(const std::string& keys)
{
	const unsigned int SHIFT_SC = 0x12;   // Left Shift
	const unsigned int CTRL_SC  = 0x14;   // Left Ctrl

	for (size_t i = 0; i < keys.size(); i++) {
		char c = keys[i];

		if (c == KEYMARK_CTRL && i + 1 < keys.size()) {
			char combo = keys[++i];
			AsciiToPS2 m = ascii_to_ps2(combo);
			if (m.scancode == 0xFF) continue;
			input.keyEvents.push(SimInput_PS2KeyEvent(CTRL_SC, true,  false, CTRL_SC));
			input.keyEvents.push(SimInput_PS2KeyEvent(m.scancode, true,  false, m.scancode));
			input.keyEvents.push(SimInput_PS2KeyEvent(m.scancode, false, false, m.scancode));
			input.keyEvents.push(SimInput_PS2KeyEvent(CTRL_SC, false, false, CTRL_SC));
			continue;
		}

		if (c >= KEYMARK_UP && c <= KEYMARK_RIGHT) {
			unsigned int sc = (c == KEYMARK_UP)   ? 0x75 :
			                  (c == KEYMARK_DOWN) ? 0x72 :
			                  (c == KEYMARK_LEFT) ? 0x6b : 0x74;
			input.keyEvents.push(SimInput_PS2KeyEvent(sc, true,  true, sc));
			input.keyEvents.push(SimInput_PS2KeyEvent(sc, false, true, sc));
			continue;
		}

		AsciiToPS2 m = ascii_to_ps2(c);
		if (m.scancode == 0xFF) continue;

		if (m.needs_shift)
			input.keyEvents.push(SimInput_PS2KeyEvent(SHIFT_SC, true, false, SHIFT_SC));
		input.keyEvents.push(SimInput_PS2KeyEvent(m.scancode, true,  false, m.scancode));
		input.keyEvents.push(SimInput_PS2KeyEvent(m.scancode, false, false, m.scancode));
		if (m.needs_shift)
			input.keyEvents.push(SimInput_PS2KeyEvent(SHIFT_SC, false, false, SHIFT_SC));
	}
}

static void process_key_injections(int frame)
{
	for (auto it = key_injections.begin(); it != key_injections.end(); ) {
		if (it->frame == frame) {
			printf("Injecting keys at frame %d\n", frame);
			fflush(stdout);
			queue_key_string(it->keys);
			it = key_injections.erase(it);
		} else {
			++it;
		}
	}
}

// "300:CATALOG\n" -> frame 300, keys "CATALOG<CR>"
static void parse_send_keys(const std::string& spec)
{
	size_t colon = spec.find(':');
	if (colon == std::string::npos) {
		printf("Error: --send-keys wants frame:text (got \"%s\")\n", spec.c_str());
		exit(1);
	}

	KeyInjection ki;
	ki.frame = atoi(spec.substr(0, colon).c_str());

	const std::string raw = spec.substr(colon + 1);
	std::string out;
	for (size_t i = 0; i < raw.size(); i++) {
		if (raw[i] != '\\' || i + 1 >= raw.size()) { out += raw[i]; continue; }
		char e = raw[++i];
		switch (e) {
		case 'n': out += '\n'; break;
		case 'r': out += '\r'; break;
		case 't': out += '\t'; break;
		case 'b': out += '\b'; break;
		case 'e': out += (char)0x1b; break;
		case '\\': out += '\\'; break;
		case 'U': out += (char)KEYMARK_UP; break;
		case 'D': out += (char)KEYMARK_DOWN; break;
		case 'L': out += (char)KEYMARK_LEFT; break;
		case 'R': out += (char)KEYMARK_RIGHT; break;
		case 'c':  // \cC = Ctrl-C
			if (i + 1 < raw.size()) { out += (char)KEYMARK_CTRL; out += raw[++i]; }
			break;
		case 'x': {
			std::string hex;
			while (hex.size() < 2 && i + 1 < raw.size() && isxdigit((unsigned char)raw[i + 1]))
				hex += raw[++i];
			if (!hex.empty()) out += (char)strtol(hex.c_str(), NULL, 16);
			break;
		}
		default: out += e; break;
		}
	}
	ki.keys = out;
	key_injections.push_back(ki);
}

// ---------------------------------------------------------------------------
// Screenshot / batch automation
// ---------------------------------------------------------------------------

// Reads the framebuffer that SimVideo::Clock() fills, so this works identically
// whether or not a window is open. Pixel format is 0xFF000000 | B<<16 | G<<8 | R.
static void save_screenshot(int frame_number)
{
	if (!output_ptr) {
		printf("Screenshot: output_ptr is null, nothing to save\n");
		return;
	}

	int w = video.output_width;
	int h = video.output_height;
	if (w <= 0 || h <= 0) {
		printf("Screenshot: video is %dx%d, nothing to save\n", w, h);
		return;
	}

	char filename[512];
	if (!screenshot_name_override.empty())
		snprintf(filename, sizeof(filename), "%s", screenshot_name_override.c_str());
	else
		snprintf(filename, sizeof(filename), "screenshot_frame_%04d.png", frame_number);

	uint8_t* rgb = (uint8_t*)malloc((size_t)w * h * 3);
	if (!rgb) {
		printf("Screenshot: out of memory\n");
		return;
	}

	for (int y = 0; y < h; y++) {
		for (int x = 0; x < w; x++) {
			uint32_t pixel = output_ptr[y * w + x];
			int d = (y * w + x) * 3;
			rgb[d + 0] = (pixel >> 0) & 0xFF;  // R
			rgb[d + 1] = (pixel >> 8) & 0xFF;  // G
			rgb[d + 2] = (pixel >> 16) & 0xFF; // B
		}
	}

	int ok = stbi_write_png(filename, w, h, 3, rgb, w * 3);
	free(rgb);

	printf(ok ? "Screenshot saved: %s (%dx%d)\n" : "Screenshot FAILED: %s (%dx%d)\n",
	       filename, w, h);
	fflush(stdout);
}

// Called once per new video frame from whichever run loop is active.
static void on_new_frame(int frame)
{
	if (batch_verbose && (!screenshot_frames.empty() || stop_at_frame_enabled))
		printf("Frame: %d\n", frame);

	process_key_injections(frame);

	if (std::find(screenshot_frames.begin(), screenshot_frames.end(), frame)
	    != screenshot_frames.end())
		save_screenshot(frame);

	if (stop_at_frame_enabled && frame >= stop_at_frame) {
		printf("Reached frame %d, stopping.\n", frame);
		fflush(stdout);
		exit(0);
	}
}

static void show_help(const char* argv0)
{
	printf("Usage: %s [options]\n\n", argv0);
	printf("  Run from the verilator/ directory - the ROMs are loaded by\n");
	printf("  $readmemh using paths relative to it.\n\n");
	printf("Disks:\n");
	printf("  --floppy <file.nib>     Drive 1 (slot 6 d1). Default: floppy.nib\n");
	printf("  --floppy2 <file.nib>    Drive 2 (slot 6 d2)\n");
	printf("  --hdd <file.hdv>        Hard disk (slot 7). Also --disk\n");
	printf("  --no-floppy             Start with no floppy mounted\n\n");
	printf("Automation:\n");
	printf("  --screenshot N[,N..]    Save a PNG at these frame numbers\n");
	printf("  --screenshot-name FILE  Override the screenshot filename\n");
	printf("  --stop-at-frame N       Exit once frame N is reached\n");
	printf("  --fixed-time [epoch]    Freeze the RTC for reproducible runs\n");
	printf("  --send-keys F:TEXT      Type TEXT at frame F. Repeatable.\n");
	printf("                          Escapes: \\n \\r \\t \\b \\e \\\\ \\xNN\n");
	printf("                                   \\cX = Ctrl-X, \\U \\D \\L \\R = arrows\n");
	printf("  --quiet                 Suppress per-frame progress lines\n");
	printf("  -h, --help              This message\n\n");
	printf("Example:\n");
	printf("  %s --floppy floppy.nib --screenshot 300 --stop-at-frame 300\n", argv0);
}

static void parse_args(int argc, char** argv)
{
	for (int i = 1; i < argc; i++) {
		std::string a = argv[i];
		auto next = [&](const char* what) -> std::string {
			if (i + 1 >= argc) {
				printf("Error: %s needs an argument\n", what);
				exit(1);
			}
			return std::string(argv[++i]);
		};

		if (a == "-h" || a == "--help") { show_help(argv[0]); exit(0); }
		else if (a == "--floppy")        floppy_image  = next("--floppy");
		else if (a == "--floppy2")       floppy2_image = next("--floppy2");
		else if (a == "--hdd" || a == "--disk") hdd_image = next(a.c_str());
		else if (a == "--no-floppy")     floppy_image.clear();
		else if (a == "--screenshot-name") screenshot_name_override = next("--screenshot-name");
		else if (a == "--stop-at-frame") {
			stop_at_frame = atoi(next("--stop-at-frame").c_str());
			stop_at_frame_enabled = true;
		}
		else if (a == "--quiet")         batch_verbose = false;
		else if (a == "--send-keys")     parse_send_keys(next("--send-keys"));
		else if (a == "--fixed-time") {
			fixed_time = true;
			if (i + 1 < argc && argv[i + 1][0] != '-')
				fixed_time_epoch = (time_t)atol(argv[++i]);
		}
		else if (a == "--screenshot") {
			std::stringstream ss(next("--screenshot"));
			std::string tok;
			while (std::getline(ss, tok, ',')) {
				if (!tok.empty()) screenshot_frames.push_back(atoi(tok.c_str()));
			}
		}
		else if (!a.empty() && a[0] == '-') {
			// Leave unknown dash-args to Verilated::commandArgs (e.g. +verilator+...)
			continue;
		}
	}
}

int main(int argc, char** argv, char** env) {

	parse_args(argc, argv);

	// Create core and initialise
	top = new Vemu();
	Verilated::commandArgs(argc, argv);

#ifdef WIN32
	// Attach debug console to the verilated code
	Verilated::setDebug(console);
#endif

	// Attach bus
	bus.ioctl_addr = &top->ioctl_addr;
	bus.ioctl_index = &top->ioctl_index;
	bus.ioctl_wait = &top->ioctl_wait;
	bus.ioctl_download = &top->ioctl_download;
	//bus.ioctl_upload = &top->ioctl_upload;
	bus.ioctl_wr = &top->ioctl_wr;
	bus.ioctl_dout = &top->ioctl_dout;
	//bus.ioctl_din = &top->ioctl_din;
	input.ps2_key = &top->ps2_key;

	// hookup blk device
	blockdevice.sd_lba[0] = &top->sd_lba[0];
	blockdevice.sd_lba[1] = &top->sd_lba[1];
	blockdevice.sd_lba[2] = &top->sd_lba[2];
	blockdevice.sd_rd = &top->sd_rd;
	blockdevice.sd_wr = &top->sd_wr;
	blockdevice.sd_ack = &top->sd_ack;
	blockdevice.sd_buff_addr= &top->sd_buff_addr;
	blockdevice.sd_buff_dout= &top->sd_buff_dout;
	blockdevice.sd_buff_din[0]= &top->sd_buff_din[0];
	blockdevice.sd_buff_din[1]= &top->sd_buff_din[1];
	blockdevice.sd_buff_din[2]= &top->sd_buff_din[2];
	blockdevice.sd_buff_wr= &top->sd_buff_wr;
	blockdevice.img_mounted= &top->img_mounted;
	blockdevice.img_readonly= &top->img_readonly;
	blockdevice.img_size= &top->img_size;

	send_clock();

#ifndef DISABLE_AUDIO
	audio.Initialise();
#endif

	// Set up input module
	input.Initialise();
#ifdef WIN32
	input.SetMapping(input_up, DIK_UP);
	input.SetMapping(input_right, DIK_RIGHT);
	input.SetMapping(input_down, DIK_DOWN);
	input.SetMapping(input_left, DIK_LEFT);
	input.SetMapping(input_a, DIK_Z); // A
	input.SetMapping(input_b, DIK_X); // B
	input.SetMapping(input_x, DIK_A); // X
	input.SetMapping(input_y, DIK_S); // Y
	input.SetMapping(input_l, DIK_Q); // L
	input.SetMapping(input_r, DIK_W); // R
	input.SetMapping(input_select, DIK_1); // Select
	input.SetMapping(input_start, DIK_2); // Start
	input.SetMapping(input_menu, DIK_M); // System menu trigger

#else
	input.SetMapping(input_up, SDL_SCANCODE_UP);
	input.SetMapping(input_right, SDL_SCANCODE_RIGHT);
	input.SetMapping(input_down, SDL_SCANCODE_DOWN);
	input.SetMapping(input_left, SDL_SCANCODE_LEFT);
	input.SetMapping(input_a, SDL_SCANCODE_A);
	input.SetMapping(input_b, SDL_SCANCODE_B);
	input.SetMapping(input_x, SDL_SCANCODE_X);
	input.SetMapping(input_y, SDL_SCANCODE_Y);
	input.SetMapping(input_l, SDL_SCANCODE_L);
	input.SetMapping(input_r, SDL_SCANCODE_E);
	input.SetMapping(input_start, SDL_SCANCODE_1);
	input.SetMapping(input_select, SDL_SCANCODE_2);
	input.SetMapping(input_menu, SDL_SCANCODE_M);
#endif
	// Setup video output
	if (video.Initialise(windowTitle) == 1) { return 1; }


	// Block device slots: 0 = floppy drive 1, 1 = hard disk, 2 = floppy drive 2
	if (!floppy_image.empty())  blockdevice.MountDisk((char*)floppy_image.c_str(), 0);
	if (!hdd_image.empty())     blockdevice.MountDisk((char*)hdd_image.c_str(), 1);
	if (!floppy2_image.empty()) blockdevice.MountDisk((char*)floppy2_image.c_str(), 2);

#ifdef WIN32
	MSG msg;
	ZeroMemory(&msg, sizeof(msg));
	while (msg.message != WM_QUIT)
	{
		if (PeekMessage(&msg, NULL, 0U, 0U, PM_REMOVE))
		{
			TranslateMessage(&msg);
			DispatchMessage(&msg);
			continue;
		}
#else
	bool done = false;
	while (!done)
	{
		SDL_Event event;
		while (SDL_PollEvent(&event))
		{
			ImGui_ImplSDL2_ProcessEvent(&event);
			if (event.type == SDL_QUIT)
				done = true;
		}
#endif
		video.StartFrame();

		input.Read();


		// Draw GUI
		// --------
		ImGui::NewFrame();

		// Simulation control window
		ImGui::Begin(windowTitle_Control);
		ImGui::SetWindowPos(windowTitle_Control, ImVec2(0, 0), ImGuiCond_Once);
		ImGui::SetWindowSize(windowTitle_Control, ImVec2(500, 150), ImGuiCond_Once);
		if (ImGui::Button("Reset simulation")) { resetSim(); } ImGui::SameLine();
		if (ImGui::Button("Start running")) { run_enable = 1; } ImGui::SameLine();
		if (ImGui::Button("Stop running")) { run_enable = 0; } ImGui::SameLine();
		ImGui::Checkbox("RUN", &run_enable);
		//ImGui::PopItemWidth();
		ImGui::SliderInt("Run batch size", &batchSize, 1, 1750000);
		if (single_step == 1) { single_step = 0; }
		if (ImGui::Button("Single Step")) { run_enable = 0; single_step = 1; }
		ImGui::SameLine();
		if (multi_step == 1) { multi_step = 0; }
		if (ImGui::Button("Multi Step")) { run_enable = 0; multi_step = 1; }
		//ImGui::SameLine();
		ImGui::SliderInt("Multi step amount", &multi_step_amount, 8, 1024);
		if (ImGui::Button("Soft Reset")) { fprintf(stderr,"soft reset\n"); soft_reset=1; } ImGui::SameLine();

		ImGui::End();

		// Debug log window
		console.Draw(windowTitle_DebugLog, &showDebugLog, ImVec2(500, 700));
		ImGui::SetWindowPos(windowTitle_DebugLog, ImVec2(0, 160), ImGuiCond_Once);

		// Memory debug
		//ImGui::Begin("PGROM Editor");
		//mem_edit.DrawContents(top->emu__DOT__system__DOT__pgrom__DOT__mem, 32768, 0);
		//ImGui::End();
		//ImGui::Begin("CHROM Editor");
		//mem_edit.DrawContents(top->emu__DOT__system__DOT__chrom__DOT__mem, 2048, 0);
		//ImGui::End();
		//ImGui::Begin("WKRAM Editor");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__wkram__DOT__mem, 16384, 0);
		//ImGui::End();
		//ImGui::Begin("CHRAM Editor");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__chram__DOT__mem, 2048, 0);
		//ImGui::End();
		//ImGui::Begin("FGCOLRAM Editor");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__fgcolram__DOT__mem, 2048, 0);
		//ImGui::End();
		//ImGui::Begin("BGCOLRAM Editor");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__bgcolram__DOT__mem, 2048, 0);
		//ImGui::End();
		//ImGui::Begin("Sprite RAM");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__spriteram__DOT__mem, 96, 0);
		//ImGui::End();
		//ImGui::Begin("Sprite Linebuffer RAM");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__spritelbram__DOT__mem, 1024, 0);
		//ImGui::End();
		//ImGui::Begin("Sprite Collision Buffer RAM A");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__comet__DOT__spritecollisionbufferram_a__DOT__mem, 512, 0);
		//ImGui::End();
		//ImGui::Begin("Sprite Collision Buffer RAM B");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__comet__DOT__spritecollisionbufferram_b__DOT__mem, 512, 0);
		//ImGui::End();
		//ImGui::Begin("Sprite Collision RAM ");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__spritecollisionram__DOT__mem, 32, 0);
		//ImGui::End();
		//ImGui::Begin("Sprite Debug RAM");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__spritedebugram__DOT__mem, 128000, 0);
		//ImGui::End();
		//ImGui::Begin("Palette ROM");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__palrom__DOT__mem, 64, 0);
		//ImGui::End();
		//ImGui::Begin("Sprite ROM");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__spriterom__DOT__mem, 2048, 0);
		//ImGui::End();
		//ImGui::Begin("Tilemap ROM");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__tilemaprom__DOT__mem, 8192, 0);
		//ImGui::End();
		//ImGui::Begin("Tilemap RAM");
		//	mem_edit.DrawContents(&top->emu__DOT__system__DOT__tilemapram__DOT__mem, 768, 0);
		//ImGui::End();
		//ImGui::Begin("Sound ROM");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__soundrom__DOT__mem, 64000, 0);
		//ImGui::End();

		int windowX = 550;
		int windowWidth = (VGA_WIDTH * VGA_SCALE_X) + 24;
		int windowHeight = (VGA_HEIGHT * VGA_SCALE_Y) + 90;

		// Video window
		ImGui::Begin(windowTitle_Video);
		ImGui::SetWindowPos(windowTitle_Video, ImVec2(windowX, 0), ImGuiCond_Once);
		ImGui::SetWindowSize(windowTitle_Video, ImVec2(windowWidth, windowHeight), ImGuiCond_Once);

		ImGui::SliderFloat("Zoom", &vga_scale, 1, 8); ImGui::SameLine();
		ImGui::SliderInt("Rotate", &video.output_rotate, -1, 1); ImGui::SameLine();
		ImGui::Checkbox("Flip V", &video.output_vflip);
		ImGui::Text("main_time: %ld frame_count: %d sim FPS: %f", main_time, video.count_frame, video.stats_fps);

		// Batch automation: fire once per new frame
		{
			static int last_seen_frame = -1;
			if (video.count_frame != last_seen_frame) {
				last_seen_frame = video.count_frame;
				on_new_frame(video.count_frame);
			}
		}
		//ImGui::Text("pixel: %06d line: %03d", video.count_pixel, video.count_line);

		// Draw VGA output
		ImGui::Image(video.texture_id, ImVec2(video.output_width * VGA_SCALE_X, video.output_height * VGA_SCALE_Y));
		ImGui::End();

  if (ImGuiFileDialog::Instance()->Display("ChooseFileDlgKey"))
  {
    // action if OK
    if (ImGuiFileDialog::Instance()->IsOk())
    {
      std::string filePathName = ImGuiFileDialog::Instance()->GetFilePathName();
      std::string filePath = ImGuiFileDialog::Instance()->GetCurrentPath();
      // action
fprintf(stderr,"filePathName: %s\n",filePathName.c_str());
fprintf(stderr,"filePath: %s\n",filePath.c_str());
     bus.QueueDownload(filePathName, 1,0);
    }
   
    // close
    ImGuiFileDialog::Instance()->Close();
  }


#ifndef DISABLE_AUDIO

		ImGui::Begin(windowTitle_Audio);
		ImGui::SetWindowPos(windowTitle_Audio, ImVec2(windowX, windowHeight), ImGuiCond_Once);
		ImGui::SetWindowSize(windowTitle_Audio, ImVec2(windowWidth, 250), ImGuiCond_Once);

		
		//float vol_l = ((signed short)(top->AUDIO_L) / 256.0f) / 256.0f;
		//float vol_r = ((signed short)(top->AUDIO_R) / 256.0f) / 256.0f;
		//ImGui::ProgressBar(vol_l + 0.5f, ImVec2(200, 16), 0); ImGui::SameLine();
		//ImGui::ProgressBar(vol_r + 0.5f, ImVec2(200, 16), 0);

		int ticksPerSec = (24000000 / 60);
		if (run_enable) {
			audio.CollectDebug((signed short)top->AUDIO_L, (signed short)top->AUDIO_R);
		}
		int channelWidth = (windowWidth / 2)  -16;
		ImPlot::CreateContext();
		if (ImPlot::BeginPlot("Audio - L", ImVec2(channelWidth, 220), ImPlotFlags_NoLegend | ImPlotFlags_NoMenus | ImPlotFlags_NoTitle)) {
			ImPlot::SetupAxes("T", "A", ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks, ImPlotAxisFlags_AutoFit | ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks);
			ImPlot::SetupAxesLimits(0, 1, -1, 1, ImPlotCond_Once);
			ImPlot::PlotStairs("", audio.debug_positions, audio.debug_wave_l, audio.debug_max_samples, audio.debug_pos);
			ImPlot::EndPlot();
		}
		ImGui::SameLine();
		if (ImPlot::BeginPlot("Audio - R", ImVec2(channelWidth, 220), ImPlotFlags_NoLegend | ImPlotFlags_NoMenus | ImPlotFlags_NoTitle)) {
			ImPlot::SetupAxes("T", "A", ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks, ImPlotAxisFlags_AutoFit | ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks);
			ImPlot::SetupAxesLimits(0, 1, -1, 1, ImPlotCond_Once);
			ImPlot::PlotStairs("", audio.debug_positions, audio.debug_wave_r, audio.debug_max_samples, audio.debug_pos);
			ImPlot::EndPlot();
		}
		ImPlot::DestroyContext();
		ImGui::End();
#endif

		video.UpdateTexture();


		// Pass inputs to sim

		top->menu = input.inputs[input_menu];

		top->joystick_0 = 0;
		for (int i = 0; i < input.inputCount; i++)
		{
			if (input.inputs[i]) { top->joystick_0 |= (1 << i); }
		}
		top->joystick_1 = top->joystick_0;

		/*top->joystick_analog_0 += 1;
		top->joystick_analog_0 -= 256;*/
		//top->paddle_0 += 1;
		//if (input.inputs[0] || input.inputs[1]) {
		//	spinner_toggle = !spinner_toggle;
		//	top->spinner_0 = (input.inputs[0]) ? 16 : -16;
		//	for (char b = 8; b < 16; b++) {
		//		top->spinner_0 &= ~(1UL << b);
		//	}
		//	if (spinner_toggle) { top->spinner_0 |= 1UL << 8; }
		//}

		mouse_buttons = 0;
		mouse_x = 0;
		mouse_y = 0;
		if (input.inputs[input_left]) { mouse_x = -2; }
		if (input.inputs[input_right]) { mouse_x = 2; }
		if (input.inputs[input_up]) { mouse_y = 2; }
		if (input.inputs[input_down]) { mouse_y = -2; }

		if (input.inputs[input_a]) { mouse_buttons |= (1UL << 0); }
		if (input.inputs[input_b]) { mouse_buttons |= (1UL << 1); }

		unsigned long mouse_temp = mouse_buttons;
		mouse_temp += (mouse_x << 8);
		mouse_temp += (mouse_y << 16);
		if (mouse_clock) { mouse_temp |= (1UL << 24); }
		mouse_clock = !mouse_clock;

		top->ps2_mouse = mouse_temp;
		top->ps2_mouse_ext = mouse_x + (mouse_buttons << 8);

		// Run simulation
		if (run_enable) {
			for (int step = 0; step < batchSize; step++) { verilate(); }
		}
		else {
			if (single_step) { verilate(); }
			if (multi_step) {
				for (int step = 0; step < multi_step_amount; step++) { verilate(); }
			}
		}
	}

	// Clean up before exit
	// --------------------

#ifndef DISABLE_AUDIO
	audio.CleanUp();
#endif 
	video.CleanUp();
	input.CleanUp();

	return 0;
}
