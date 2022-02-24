--
-- Apple II+ toplevel abstract
--
-- Copyright (c) 2014 W. Soltys <wsoltys@gmail.com>
--
-- This source file is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published
-- by the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This source file is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity apple2_top is
port (
	CLK_14M        : in std_logic;
   CLK_50M        : in std_logic;
	reset_cold     : in std_logic;
	reset_warm     : in std_logic;
	cpu_type       : in std_logic;
	CPU_WAIT       : in std_logic;

	-- main RAM
	ram_we         : out std_logic;
	ram_di         : out std_logic_vector(7 downto 0);
	ram_do         : in  std_logic_vector(15 downto 0);
	ram_addr       : out std_logic_vector(17 downto 0);
	ram_aux        : out std_logic;

	-- video output
	hsync          : out std_logic;
	vsync          : out std_logic;
	hblank         : out std_logic;
	vblank         : out std_logic;
	r              : out std_logic_vector(7 downto 0);
	g              : out std_logic_vector(7 downto 0);
	b              : out std_logic_vector(7 downto 0);
	SCREEN_MODE    : in  std_logic_vector(1 downto 0); -- 00: Color, 01: B&W, 10:Green, 11: Amber

	PS2_Key        : in  std_logic_vector(10 downto 0);
	joy            : in  std_logic_vector(5 downto 0);
	joy_an         : in  std_logic_vector(15 downto 0);

	-- mocking board
	mb_enabled 		: in std_logic;

	-- disk control
	TRACK 			: out unsigned(5 downto 0);
	DISK_RAM_ADDR  : in  unsigned(12 downto 0);
	DISK_RAM_DI 	: in  unsigned(7 downto 0);
	DISK_RAM_DO    : out unsigned(7 downto 0);
	DISK_RAM_WE 	: in  std_logic;
	DISK_ACT       : out std_logic;
	DISK_TRACK_ADDR: out unsigned(13 downto 0);

	DISK_FD_WRITE_DISK : out std_logic;
	DISK_FD_READ_DISK : out std_logic;
	DISK_FD_TRACK_ADDR : out unsigned(13 downto 0);
	DISK_FD_DATA_IN    : in unsigned(7 downto 0);
	DISK_FD_DATA_OUT   : out unsigned(7 downto 0);
	
	
	-- HDD control
	HDD_SECTOR     : out unsigned(15 downto 0);
	HDD_READ       : out std_logic;
	HDD_WRITE      : out std_logic;
	HDD_MOUNTED    : in  std_logic;
	HDD_PROTECT    : in  std_logic;
	HDD_RAM_ADDR   : in  unsigned(8 downto 0);
	HDD_RAM_DI     : in  unsigned(7 downto 0);
	HDD_RAM_DO     : out unsigned(7 downto 0);
	HDD_RAM_WE     : in  std_logic;

	AUDIO_L        : out std_logic_vector(9 downto 0);
	AUDIO_R        : out std_logic_vector(9 downto 0);
	TAPE_IN        : in  std_logic;

	UART_TXD       :out  std_logic;
	UART_RXD       :in  std_logic;
	UART_RTS       :out  std_logic;
	UART_CTS       :in  std_logic;
	UART_DTR       :out  std_logic;
	UART_DSR       :in  std_logic

);
end apple2_top;

architecture arch of apple2_top is
component apple2 is 
		  port (
    CLK_14M        : in  std_logic;              -- 14.31818 MHz master clock
    CLK_2M         : out std_logic;
    CPU_WAIT       : in  std_logic;
    PHASE_ZERO     : buffer std_logic;
    FLASH_CLK      : in  std_logic;        -- approx. 2 Hz flashing char clock
    reset          : in  std_logic;
    cpu            : in  std_logic;              -- 0 - 6502, 1 - 65C02
    ADDR           : out unsigned(15 downto 0);  -- CPU address
    ram_addr       : out unsigned(17 downto 0);  -- RAM address
    D              : out unsigned(7 downto 0);   -- Data to RAM
    ram_do         : in unsigned(15 downto 0);   -- Data from RAM (lo byte: MAIN RAM, hi byte: AUX RAM)
    aux            : buffer std_logic;           -- Write to MAIN or AUX RAM
    PD             : in unsigned(7 downto 0);    -- Data to CPU from peripherals
    CPU_WE         : out std_logic;
    IRQ_n          : in std_logic;
    NMI_n          : in std_logic;
    ram_we         : out std_logic;              -- RAM write enable
    VIDEO          : out std_logic;
    COLOR_LINE     : out std_logic;
    HBL            : out std_logic;
    VBL            : buffer std_logic;
    K              : in unsigned(7 downto 0);    -- Keyboard data
    READ_KEY       : buffer std_logic;           -- Processor has read key
    AKD            : in std_logic;               -- Any key down flag
    AN             : buffer std_logic_vector(3 downto 0);  -- Annunciator outputs
    -- GAMEPORT input bits:
    --  7    6    5    4    3   2   1    0
    -- pdl3 pdl2 pdl1 pdl0 pb3 pb2 pb1 casette
    GAMEPORT       : in std_logic_vector(7 downto 0);
    PDL_STROBE     : buffer std_logic;           -- Pulses high when C07x read
    STB            : buffer std_logic;           -- Pulses high when C04x read
    IO_SELECT      : out std_logic_vector(7 downto 0);
    DEVICE_SELECT  : out std_logic_vector(7 downto 0);
    IO_STROBE      : out std_logic;
    speaker        : out std_logic              -- One-bit speaker output
    );
	end component;
component vga_controller is
        port (
                CLK_14M    : in  std_logic;          -- 14.31818 MHz master clock

                VIDEO      : in std_logic;         -- from the Apple video generator
                COLOR_LINE : in std_logic;
                SCREEN_MODE: in std_logic_vector(1 downto 0); -- 00: Color, 01: B&W, 10: Green, 11: Amber
                HBL        : in std_logic;
                VBL        : in std_logic;

                VGA_HS     : out std_logic;
                VGA_VS     : out std_logic;
                VGA_HBL    : out std_logic;
                VGA_VBL    : out std_logic;
                VGA_R      : out unsigned(7 downto 0);
                VGA_G      : out unsigned(7 downto 0);
                VGA_B      : out unsigned(7 downto 0)
        );
end component;
  component disk_ii is
  port (
    CLK_14M        : in std_logic;
    CLK_2M         : in std_logic;
    PHASE_ZERO     : in std_logic;
    IO_SELECT      : in std_logic;      -- e.g., C600 - C6FF ROM
    DEVICE_SELECT  : in std_logic;      -- e.g., C0E0 - C0EF I/O locations
    RESET          : in std_logic;
    A              : in unsigned(15 downto 0);
    D_IN           : in unsigned(7 downto 0);  -- From 6502
    D_OUT          : out unsigned(7 downto 0);  -- To 6502
    TRACK          : out unsigned(5 downto 0);  -- Current track (0-34)
    track_addr     : out unsigned(13 downto 0);
    D1_ACTIVE      : out std_logic;     -- Disk 1 motor on
    D2_ACTIVE      : out std_logic;     -- Disk 2 motor on
    ram_write_addr : in unsigned(12 downto 0);  -- Address for track RAM
    ram_di         : in unsigned(7 downto 0);  -- Data to track RAM
    ram_we         : in std_logic  ;            -- RAM write enable

         DISK_FD_WRITE_DISK : out std_logic;
         DISK_FD_READ_DISK : out std_logic;
        DISK_FD_TRACK_ADDR : out unsigned(13 downto 0);
        DISK_FD_DATA_IN    : in unsigned(7 downto 0);
        DISK_FD_DATA_OUT   : out unsigned(7 downto 0)



    );
	end component;
  component superserial is
    port ( 
	 	    CLK_14M  :in std_logic;
	    CLK_2M  :in std_logic;
		 CLK_50M:in std_logic;
		 PH_2    :in std_logic;
       IO_SELECT_N:in std_logic;
       DEVICE_SELECT_N : in std_logic;
       IO_STROBE_N  : in std_logic;
       ADDRESS     : in std_logic_vector(15 downto 0);
       RW_N        : in std_logic;
       RESET      :in std_logic;
       DATA_IN    :in std_logic_vector(7 downto 0);
      DATA_OUT   :out std_logic_vector(7 downto 0);
		ROM_EN : out std_logic;
      UART_CTS :in std_logic;
      UART_RTS :out std_logic;
      UART_RXD :in std_logic;
      UART_TXD :out std_logic;
      UART_DTR :out std_logic;
      UART_DSR :in std_logic;
		IRQ_N :out std_logic);
	

  end component;


  signal CLK_2M, CLK_2M_D, PHASE_ZERO : std_logic;
  signal IO_SELECT, DEVICE_SELECT : std_logic_vector(7 downto 0);
  signal IO_STROBE : std_logic;
  signal ADDR : unsigned(15 downto 0);
  signal D, PD: unsigned(7 downto 0);
  signal DISK_DO, PSG_DO, HDD_DO, SSC_DO : unsigned(7 downto 0);
  signal SSC_ROM_EN : std_logic;
  signal cpu_we : std_logic;
  signal psg_irq_n, psg_nmi_n : std_logic;
  signal ssc_irq_n: std_logic;
  
  signal we_ram : std_logic;
  signal VIDEO, HBL, VBL : std_logic;
  signal COLOR_LINE : std_logic;
  signal COLOR_LINE_CONTROL : std_logic;
  signal GAMEPORT : std_logic_vector(7 downto 0);

  signal K : unsigned(7 downto 0);
  signal read_key : std_logic;
  signal akd : std_logic;

  signal flash_clk : unsigned(22 downto 0) := (others => '0');
  signal power_on_reset : std_logic := '1';
  signal reset : std_logic;

  signal D1_ACTIVE, D2_ACTIVE : std_logic;

  signal a_ram: unsigned(17 downto 0);
  
  signal psg_audio_l : unsigned(9 downto 0);
  signal psg_audio_r : unsigned(9 downto 0);
  signal audio       : unsigned(9 downto 0);

  signal joyx       : std_logic;
  signal joyy       : std_logic;
  signal pdl_strobe : std_logic;

begin


  -- In the Apple ][, this was a 555 timer
  power_on : process(CLK_14M)
  begin
    if rising_edge(CLK_14M) then
      reset <= reset_warm or power_on_reset;

      if reset_cold = '1' then
        power_on_reset <= '1';
        flash_clk <= (others=>'0');
      else
		  if flash_clk(22) = '1' then
          power_on_reset <= '0';
			end if;
			 
        flash_clk <= flash_clk + 1;
      end if;
    end if;
  end process;
  
  -- Paddle buttons
  -- GAMEPORT input bits:
  --  7    6    5    4    3   2   1    0
  -- pdl3 pdl2 pdl1 pdl0 pb3 pb2 pb1 casette
  GAMEPORT <=  "00" & joyy & joyx & "0" & joy(5) & joy(4) & TAPE_IN;
  
  process(CLK_14M, pdl_strobe)
    variable cx, cy : integer range -100 to 5800 := 0;
  begin
    if rising_edge(CLK_14M) then
     CLK_2M_D <= CLK_2M;
     if CLK_2M_D = '0' and CLK_2M = '1' then
      if cx > 0 then
        cx := cx -1;
        joyx <= '1';
      else
        joyx <= '0';
      end if;
      if cy > 0 then
        cy := cy -1;
        joyy <= '1';
      else
        joyy <= '0';
      end if;
      if pdl_strobe = '1' then
        cx := 2800+(22*to_integer(signed(joy_an(15 downto 8))));
        cy := 2800+(22*to_integer(signed(joy_an(7 downto 0)))); -- max 5650
        if cx < 0 then
          cx := 0;
        elsif cx >= 5590 then
          cx := 5650;
        end if;
        if cy < 0 then
          cy := 0;
        elsif cy >= 5590 then
          cy := 5650;
        end if;
      end if;
     end if;
    end if;
  end process;

  COLOR_LINE_CONTROL <= COLOR_LINE and not (SCREEN_MODE(1) or SCREEN_MODE(0));  -- Color or B&W mode
  
  -- Simulate power up on cold reset to go to the disk boot routine
  ram_we   <= we_ram when reset_cold = '0' else '1';
  ram_addr <= std_logic_vector(a_ram) when reset_cold = '0' else std_logic_vector(to_unsigned(1012,ram_addr'length)); -- $3F4
  ram_di   <= std_logic_vector(D) when reset_cold = '0' else "00000000";

  PD <= PSG_DO when IO_SELECT(4) = '1' and mb_enabled = '1' else
        HDD_DO when IO_SELECT(7) = '1' or DEVICE_SELECT(7) = '1' else
		  --DISK_DO when IO_SELECT(6) = '1' or DEVICE_SELECT(6) = '1' else 
		  SSC_DO when IO_SELECT(2) = '1' or DEVICE_SELECT(2) = '1' or SSC_ROM_EN ='1' else -- AJS turn on port
        DISK_DO;

  core : component apple2 port map (
    CLK_14M        => CLK_14M,
    CLK_2M         => CLK_2M,
    CPU_WAIT       => CPU_WAIT,
    PHASE_ZERO     => PHASE_ZERO,
    FLASH_CLK      => flash_clk(22),
    reset          => reset,
    cpu            => cpu_type,
    ADDR           => ADDR,
    ram_addr       => a_ram,      
    D              => D,
    ram_do         => unsigned(ram_do),
    aux            => ram_aux,
    PD             => PD,
    CPU_WE         => cpu_we,
    IRQ_N          => psg_irq_n and ssc_irq_n,
    NMI_N          => psg_nmi_n,
    ram_we         => we_ram,
    VIDEO          => VIDEO,
    COLOR_LINE     => COLOR_LINE,
    HBL            => HBL,
    VBL            => VBL,
    K              => K,
    read_key       => read_key,
    AKD            => akd,
    AN             => open,
    GAMEPORT       => GAMEPORT,
    PDL_strobe     => pdl_strobe,
    IO_SELECT      => IO_SELECT,
    DEVICE_SELECT  => DEVICE_SELECT,
    IO_STROBE      => IO_STROBE,
    speaker        => audio(7)
    );

  tv : component vga_controller port map (
    CLK_14M    => CLK_14M,
    VIDEO      => VIDEO,
    COLOR_LINE => COLOR_LINE_CONTROL,
    SCREEN_MODE => SCREEN_MODE,
    HBL        => HBL,
    VBL        => VBL,
    VGA_HS     => hsync,
    VGA_VS     => vsync,
    VGA_HBL    => hblank,
    VGA_VBL    => vblank,
    std_logic_vector(VGA_R) => r,
    std_logic_vector(VGA_G) => g,
    std_logic_vector(VGA_B) => b
    );

  keyboard : entity work.keyboard port map (
    PS2_Key  => PS2_Key,
    CLK_14M  => CLK_14M,
    reset    => reset,
    reads    => read_key,
    K        => K,
    akd      => akd
    );

  disk : component disk_ii port map (
    CLK_14M        => CLK_14M,
    CLK_2M         => CLK_2M,
    PHASE_ZERO     => PHASE_ZERO,
    IO_SELECT      => IO_SELECT(6),
    DEVICE_SELECT  => DEVICE_SELECT(6),
    RESET          => reset,
    A              => ADDR,
    D_IN           => D,
    D_OUT          => DISK_DO,
    TRACK          => TRACK,
    TRACK_ADDR     => DISK_TRACK_ADDR,
    D1_ACTIVE      => D1_ACTIVE,
    D2_ACTIVE      => D2_ACTIVE,
	 
    ram_write_addr => DISK_RAM_ADDR,
    ram_di         => DISK_RAM_DI,
   -- ram_do         => DISK_RAM_DO,
    ram_we         => DISK_RAM_WE,

	 DISK_FD_WRITE_DISK => DISK_FD_WRITE_DISK,
	 DISK_FD_READ_DISK => DISK_FD_READ_DISK,
	DISK_FD_TRACK_ADDR => DISK_FD_TRACK_ADDR,
	DISK_FD_DATA_IN    => DISK_FD_DATA_IN,
	DISK_FD_DATA_OUT  => DISK_FD_DATA_OUT


    );

  DISK_ACT <= D1_ACTIVE or D2_ACTIVE;
  DISK_RAM_DO <= (others => '0');

  hdd : entity work.hdd port map (
    CLK_14M        => CLK_14M,
    IO_SELECT      => IO_SELECT(7),
    DEVICE_SELECT  => DEVICE_SELECT(7),
    RESET          => reset,
    A              => ADDR,
    RD             => not cpu_we,
    D_IN           => D,
    D_OUT          => HDD_DO,
    sector         => HDD_SECTOR,
    hdd_read       => HDD_READ,
    hdd_write      => HDD_WRITE,
    hdd_mounted    => HDD_MOUNTED,
    hdd_protect    => HDD_PROTECT,
    ram_addr       => HDD_RAM_ADDR,
    ram_di         => HDD_RAM_DI,
    ram_do         => HDD_RAM_DO,
    ram_we         => HDD_RAM_WE
    );

	 
  mb : work.mockingboard
    port map (
      CLK_14M    => CLK_14M,
      PHASE_ZERO => PHASE_ZERO,
      I_RESET_L => not reset,
      I_ENA_H   => mb_enabled,

      I_ADDR    => std_logic_vector(ADDR)(7 downto 0),
      I_DATA    => std_logic_vector(D),
      unsigned(O_DATA) => PSG_DO,
      I_RW_L    => not cpu_we,
      I_IOSEL_L => not IO_SELECT(4),
      O_IRQ_L   => psg_irq_n,
      O_NMI_L   => psg_nmi_n,
      unsigned(O_AUDIO_L) => psg_audio_l,
      unsigned(O_AUDIO_R) => psg_audio_r
      );

  ssc : component superserial
     port map (
      CLK_50M       => CLK_50M,
      CLK_14M       => CLK_14M,
      CLK_2M        => CLK_2M,
      PH_2          => PHASE_ZERO,
      IO_SELECT_N   => not IO_SELECT(2),
      DEVICE_SELECT_N => not DEVICE_SELECT(2),
      IO_STROBE_N   => NOT IO_STROBE,
      ADDRESS       => std_logic_vector(ADDR),
      RW_N          => not cpu_we,
      RESET         => reset,
      DATA_IN       => std_logic_vector(D),
      unsigned(DATA_OUT) => SSC_DO,
      ROM_EN => SSC_ROM_EN,
      UART_CTS => UART_CTS,
      UART_RTS => UART_RTS,
      UART_RXD => UART_RXD,
      UART_TXD => UART_TXD,
      UART_DTR => UART_DTR,
      UART_DSR => UART_DSR,
      IRQ_N => ssc_irq_n
);	
		
		
  audio(6 downto 0) <= (others => '0');
  audio(9 downto 8) <= (others => '0');
  AUDIO_R <= std_logic_vector(psg_audio_r + audio);
  AUDIO_L <= std_logic_vector(psg_audio_l + audio);

end arch;
