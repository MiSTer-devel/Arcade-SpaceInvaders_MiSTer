//============================================================================
//  Arcade: Space Invaders
//
//  Port to MiSTer Dave Wood (oldgit)
//  April 2019 
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================
//
// 10 May 2024 - MacroFPGA - Update SYS, Add Shuffleboard, Add freeplay option for some games
//

// Enable overlay (or not) for debugging
//`define DEBUG_MODE


module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
assign VGA_DISABLE=0;
assign HDMI_FREEZE = 0;


assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign AUDIO_MIX = 0;
assign FB_FORCE_BLANK = 0;

wire [1:0] ar = status[26:25];

assign VIDEO_ARX = (!ar) ? ((status[2] | landscape) ? 8'd4 : 8'd3) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2] | landscape) ? 8'd3 : 8'd4) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.INVADERS;;",
	"-;",
	"H0OPQ,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H1H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",  
	"O6,Flip Screen (Vert only),No,Yes;",
	"OGJ,CRT H-Sync Adjust,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"OKN,CRT V-Sync Adjust,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"H4OR,Autosave Hiscores,Off,On;",
	"P1,Pause options;",
	"P1OS,Pause when OSD is open,On,Off;",
	"P1OT,Dim video after 10s,On,Off;",
	"-;",
	"DIP;",
	"-;",
	"O8,Overlay,On,Off;",
`ifdef DEBUG_MODE
	"O9,Overlay Test,Off,On;",
`endif
	"OA,Background Graphic,On,Off;",
`ifdef DEBUG_MODE
	"OB,Debug display,Off,On;",
`endif
	"-;",
	"H2OCD,Gun Control,Joy1,Joy2,Mouse,Disabled;",
	"H3OEF,Crosshair,Small,Medium,Big,None;",
	"-;",
	"R0,Reset;",
	"J1,Fire 1,Fire 2,Fire 3,Fire 4,Start 1P,Start 2P,Coin,Pause;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_80,clk_40, clk_10;
wire clk_mem = clk_80;
wire clk_sys = clk_10;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_40),
	.outclk_1(clk_10),
	.outclk_2(clk_80),
	.locked(pll_locked)
);


///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;
wire        video_rotated;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;


reg	[7:0] machine_info;



wire [24:0] ps2_mouse;

wire [15:0] joy1, joy2, joy3, joy4;
wire [15:0] joya, joya2;

wire [21:0] gamma_bus;

wire [15:0] sdram_sz;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask({~hs_configured,&gun_mode|!gun_game,!gun_game,landscape,direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),
   .video_rotated(video_rotated),

	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),

	.sdram_sz(sdram_sz),

	.joystick_0(joy1),
	.joystick_1(joy2),
	.joystick_2(joy3),
	.joystick_3(joy4),
	.joystick_l_analog_0(joya),
	.joystick_l_analog_1(joya2),
	.ps2_mouse(ps2_mouse)
);

// Freeplay option 

wire AllowFreeplay = (mod==mod_ballbomb || mod==mod_lunarrescue || mod==mod_lupin || mod==mod_polaris || mod==mod_spaceinvaders || mod==mod_spaceinvadersii || mod==mod_vortex);

wire m_start1;
wire m_start2;
wire m_coin1;
/*
wire m_start1  = joy[8];
wire m_start2  = joy[9];
wire m_coin1   = joy[10];
*/

freeplay #(
	.count(1000000),
	.delay(2))
freeplay (
  .i_clk(clk_sys),
  .i_coin(joy[10]),
  .i_start1(joy[8]),
  .i_start2(joy[9]),
  .o_coin(m_coin1),
  .o_start1(m_start1),
  .o_start2(m_start2),
  .enable(AllowFreeplay && sw[4][0])
);

wire m_right1  = joy1[0];
wire m_left1   = joy1[1];
wire m_down1   = joy1[2];
wire m_up1     = joy1[3];
wire m_fire1a  = joy1[4] | ps2_mouse[0];
wire m_fire1b  = joy1[5] | ps2_mouse[1];
wire m_fire1c  = joy1[6] | ps2_mouse[2];
wire m_fire1d  = joy1[7];

wire m_right2  = joy2[0];
wire m_left2   = joy2[1];
wire m_down2   = joy2[2];
wire m_up2     = joy2[3];
wire m_fire2a  = joy2[4];
wire m_fire2b  = joy2[5];
wire m_fire2c  = joy2[6];
wire m_fire2d  = joy2[7];

wire m_right   = m_right1 | m_right2;
wire m_left    = m_left1  | m_left2; 
wire m_down    = m_down1  | m_down2; 
wire m_up      = m_up1    | m_up2;   
wire m_fire_a  = m_fire1a | m_fire2a;
wire m_fire_b  = m_fire1b | m_fire2b;
wire m_fire_c  = m_fire1c | m_fire2c;
wire m_fire_d  = m_fire1d | m_fire2d;

wire m_coin3   = joy3[10];
wire m_start3  = joy3[8];
wire m_left3   = joy3[1];
wire m_right3  = joy3[0];
wire m_up3     = joy3[3];
wire m_down3   = joy3[2];
/*
wire m_fire3a  = joy3[4];
wire m_fire3b  = joy3[5];
wire m_fire3c  = joy3[6];
wire m_fire3d  = joy3[7];
*/

wire m_coin4   = joy4[10];
wire m_start4  = joy4[8];
wire m_left4   = joy4[1];
wire m_right4  = joy4[0];
wire m_up4     = joy4[3];
wire m_down4   = joy4[2];
/*
wire m_fire4a  = joy4[4];
wire m_fire4b  = joy4[5];
wire m_fire4c  = joy4[6];
wire m_fire4d  = joy4[7];
*/

wire [2:0] ms_col;
wire [2:0] bs_col;
wire [2:0] sh_col;
wire [2:0] sc1_col;
wire [2:0] sc2_col;
wire [2:0] mn_col;

wire [15:0] joy = joy1 | joy2;

wire m_pause   = joy[11];

// PAUSE SYSTEM
wire				pause_cpu;
wire [23:0]		rgb_out;
pause #(8,8,8,10) pause (
	.*,
	.r(rgbdata[23:16]),
	.g(rgbdata[15:8]),
	.b(rgbdata[7:0]),
	.user_button(m_pause),
	.pause_request(hs_pause),
	.options(~status[29:28])
);


///////////////////////////////////////////////////////////////////


wire hblank;
wire vblank;
wire r,g,b;
wire no_rotate = AllowRotate ? status[2] | direct_video | landscape : 1'd1;
wire flip = 0;

reg Force_Red;
reg [23:0] Background_Col;

reg ce_pix;
always @(posedge clk_40) begin
        reg [2:0] div;

        div <= div + 1'd1;
	ce_pix <= div == 0;
end

wire fg;

`ifdef DEBUG_MODE
	// mix in overlay!
	wire og = |{C_R};
	wire [7:0]rr = (Force_Red)? {8{r||g||b}} | {C_R,C_R} : {8{r}} | {C_R,C_R};
	wire [7:0]gg = (Force_Red)? {C_R,C_R} : {8{g}} | {C_R,C_R};
	wire [7:0]bb = (Force_Red)? {C_R,C_R} : {8{b}} | {C_R,C_R};
	wire [23:0] rgbdata  = (gun_target & (~&gun_mode & gun_game)) ? {8'd255, 16'd0} : status[10]? ((fg || og) ? {rr,gg,bb} : Background_Col) : ((fg || og) && !bg_a) ? {rr,gg,bb} : {bg_r,bg_g,bg_b} | Background_Col;
`else
   // normal mix of foreground / background 
	wire [7:0]rr = (Force_Red)? {8{r||g||b}} : {8{r}};
	wire [7:0]gg = (Force_Red)? {8'd0} : {8{g}};
	wire [7:0]bb = (Force_Red)? {8'd0} : {8{b}};
	wire [23:0] rgbdata  = (gun_target & (~&gun_mode & gun_game)) ? {8'd255, 16'd0} : status[10]? (fg ? {rr,gg,bb} : Background_Col) : (fg && !bg_a) ? {rr,gg,bb} : {bg_r,bg_g,bg_b} | Background_Col;
`endif

arcade_video #(.WIDTH(260), .DW(24)) arcade_video
(
        .*,

        .clk_video(clk_40),
        .ce_pix(ce_pix),

        .RGB_in(rgb_out),
        .HBlank(hblank),
        .VBlank(vblank),
        .HSync(HSync),
        .VSync(VSync),

        .fx(status[5:3]),
		  .forced_scandoubler(forced_scandoubler)
);

screen_rotate screen_rotate
(
		  .*,
		  .rotate_ccw(ccw)
);

/* some weird problem with FB detecting the size correctly */
reg old_reset;
reg [3:0] screencount;
reg vsync_c;
reg AllowRotate = 0;

always @(posedge clk_sys)
begin
   old_reset <= reset;
   if (old_reset == 1 && reset== 0)
       screencount <= 0;
   else
		if (reset == 0) begin
			vsync_c <= VSync;
			if (vsync_c ==0 && VSync== 1)
				  screencount <= screencount + 1'b1;

			if (screencount == 10)
				  AllowRotate <= 1;
	end;
end
/* END hack to fix FB */

wire [7:0] audio;
wire [7:0] inv_audio_data;
wire [15:0] zap_audio_data;
wire use_samples;

//assign AUDIO_L = use_samples? samples_left  : (mod==mod_280zap)? zap_audio_data:{inv_audio_data,inv_audio_data};
//assign AUDIO_R = use_samples? samples_right : (mod==mod_280zap)? zap_audio_data:{inv_audio_data,inv_audio_data};
assign AUDIO_L = use_samples? samples_left  : {inv_audio_data,inv_audio_data};
assign AUDIO_R = use_samples? samples_right : {inv_audio_data,inv_audio_data};
assign AUDIO_S = use_samples; // signed for samples, unsigned for generated

wire reset;
assign reset = (RESET | status[0] | buttons[1] | ioctl_download);

  logic [1:0] reset_sys_pipe;
  logic       reset_sys;
  logic [1:0] reset_mem_pipe;
  logic       reset_mem;

  always @(posedge clk_sys) begin
    reset_sys <= reset_sys_pipe[1];
    reset_sys_pipe <= reset_sys_pipe << 1 | reset;
  end
  always @(posedge clk_mem) begin
    reset_mem <= reset_mem_pipe[1];
    reset_mem_pipe <= reset_mem_pipe << 1 | reset;
  end
wire [7:0] GDB0;
wire [7:0] GDB1;
wire [7:0] GDB2;
wire [7:0] GDB3;
wire [7:0] GDB4;
wire [7:0] GDB5;
wire [7:0] GDB6;

// Games - Completed
localparam mod_boothill      = 5;
localparam mod_seawolf       = 33;

// Games - Working
localparam mod_spaceinvaders = 0;
localparam mod_vortex        = 2;
localparam mod_spacewalk     = 9;
localparam mod_spaceinvaderscv = 10;
localparam mod_ballbomb      = 16;
localparam mod_clowns        = 19;			// P2 Controls / Flip
localparam mod_cosmo         = 20;
localparam mod_indianbattle  = 26;
localparam mod_lupin         = 27; // Set 2 - uses colour ram

localparam mod_attackforce   = 15;
localparam mod_polaris       = 30;

// Games - Not yet looked at
localparam mod_shuffleboard  = 1;
localparam mod_280zap        = 3;
localparam mod_blueshark     = 4;
localparam mod_lunarrescue   = 6;
localparam mod_ozmawars      = 7;
localparam mod_spacelaser    = 8;
localparam mod_unknown1      = 11;
localparam mod_unknown2      = 12;
localparam mod_spaceinvadersii = 13;
localparam mod_amazingmaze   = 14;
localparam mod_bowler        = 17;
localparam mod_checkmate     = 18;
localparam mod_dogpatch      = 21;
localparam mod_doubleplay    = 22;
localparam mod_guidedmissle  = 23;
localparam mod_claybust      = 24;
localparam mod_gunfight      = 25;
localparam mod_m4            = 28;
localparam mod_phantom       = 29;
localparam mod_desertgun     = 31;
localparam mod_lagunaracer   = 32;
localparam mod_yosakdon      = 34;
localparam mod_spacechaser   = 35;
localparam mod_steelworker   = 36;
localparam mod_rollingcrash  = 37;
localparam mod_lupin1        = 38; // Set 1 : uses colour prom rather than colour ram
localparam mod_spaceinvaders2= 39; 

reg [7:0] mod = 255;
always @(posedge clk_sys) if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;

 
//wire [9:0] center_joystick_y   =  8'd127 + joya[15:8];
//wire [9:0] positive_joystick_y   =  joya[15] ? 8'd128+ $signed(joya[15:8]) : 10'b0;
wire [7:0] positive_joystick_y   =  joya[15] ? ~joya[15:8] : 8'd0;
//wire [7:0] positive_joystick_y_2   =  joya2[15] ? ~joya2[15:8] : 8'd0;
wire [3:0] zap_throttle = positive_joystick_y[6:3];

/* controls for blue shark */
wire [7:0] bluerange = { 1'b0, gun_x[7:1]+8'd8 };
reg [7:0] blue_shark_x;

always @(posedge clk_sys) 
begin
   if (bluerange > 9'h082)
	   blue_shark_x=8'h82;
   else
	   blue_shark_x=bluerange[7:0];
end

/* controls for claybust */
wire [15:0] gun_x_16 = gun_x;
wire [15:0] gun_y_16 = gun_y + 8'h20;
wire [15:0] claybust_gun_pos = (((gun_x_16 >> 3) | (gun_y_16 << 5)) + 2);
reg [7:0] claybust_gun_pos_lo;
reg [7:0] claybust_gun_pos_hi;
reg [19:0] claybust_gun_on;
reg claybust_old_fire;
always @(posedge clk_10) begin
	claybust_gun_pos_lo <= claybust_gun_pos & 8'hff;
	claybust_gun_pos_hi <= claybust_gun_pos >> 8;
	claybust_old_fire <= m_fire1a;
	if (~claybust_old_fire & m_fire1a) claybust_gun_on <= 20'hfffff; // arbitrary
	else if (claybust_gun_on) claybust_gun_on <= claybust_gun_on - 1;
end

/* controls for desert gun */
reg [7:0] desert_gun_x;
reg [7:0] desert_gun_y;
reg desert_gun_select;

always @(posedge clk_sys) 
begin
	desert_gun_x <= (gun_x[7:0]>>1)+8'h10;
	desert_gun_y <= (gun_y[7:0]>>1)+8'h10;
	if (Trigger_AudioDeviceP2) desert_gun_select <= SoundCtrl5[3];
end

/* controls for clown */
/*
reg [7:0] clown_y = 128;
reg [5:0] clown_timer= 0;
reg vsync_r;
always @(posedge clk_sys) 
begin
    vsync_r <= VSync;
    if (vsync_r ==0 && VSync== 1) 
    begin
       //if (clown_timer > 1) begin
        if (m_right1 && clown_y < 255)
            clown_y <= clown_y +1;
        else if (m_left1 && clown_y > 0)
            clown_y <= clown_y -1;
       clown_timer <= clown_timer +1;
       //end
       //else
	//     clown_timer <= clown_timer +1;
    end
end
*/


/* controls for dogpatch */
/* dogpatch has some weird non incremental thing going on*/
/*0x07, 0x06, 0x04, 0x05, 0x01, 0x00, 0x02*/
/* gunfight */
/*0x06, 0x02, 0x00, 0x04, 0x05, 0x01, 0x03*/
/* boothill */
/* 	0x00, 0x04, 0x06, 0x07, 0x03, 0x01, 0x05 */
reg [2:0] dogpatch_y_count= 0;
reg [2:0] dogpatch_y_2_count= 0;
reg [2:0] gunfight_y_count= 0;
reg [2:0] gunfight_y_count_2= 0;
wire [2:0] dogpatch_y;
wire [2:0] dogpatch_y_2;
wire [2:0] gunfight_y;
wire [2:0] gunfight_y_2;

wire [2:0] boothill_y;
wire [2:0] boothill_y_2;

reg vsync_r;
reg [5:0] dogpatch_timer= 0;
always @(posedge clk_sys) 
begin
    vsync_r <= VSync;
    if (vsync_r ==0 && VSync== 1) 
    begin
	if (dogpatch_timer == 8'd5) 
	begin
          if (m_up&& dogpatch_y_count< 7)
            dogpatch_y_count<= dogpatch_y_count+1'b1;
          else if (m_down&& dogpatch_y_count > 0)
            dogpatch_y_count<= dogpatch_y_count-1'b1;

          if (m_up2&& dogpatch_y_2_count< 7)
            dogpatch_y_2_count<= dogpatch_y_2_count+1'b1;
          else if (m_down2&& dogpatch_y_2_count > 0)
            dogpatch_y_2_count<= dogpatch_y_2_count-1'b1;

          if (m_fire1b&& gunfight_y_count< 7)
            gunfight_y_count<= gunfight_y_count+1'b1;
          else if (m_fire1c&& gunfight_y_count > 0)
            gunfight_y_count<= gunfight_y_count-1'b1;

          if (m_fire2b&& gunfight_y_count_2< 7)
            gunfight_y_count_2<= gunfight_y_count_2+1'b1;
          else if (m_fire2c&& gunfight_y_count_2 > 0)
            gunfight_y_count_2<= gunfight_y_count_2-1'b1;


          dogpatch_timer <= 0;
        end
	else 
	begin
          dogpatch_timer <= dogpatch_timer +1'b1;
	end
    case (dogpatch_y_count) 
		3'b000: dogpatch_y <= 3'h7;
		3'b001: dogpatch_y <= 3'h6;
		3'b010: dogpatch_y <= 3'h4;
		3'b011: dogpatch_y <= 3'h5;
		3'b100: dogpatch_y <= 3'h1;
		3'b101: dogpatch_y <= 3'h0;
		3'b110: dogpatch_y <= 3'h2;
		3'b111: dogpatch_y <= 3'h2; // ?
	endcase
    case (dogpatch_y_2_count) 
		3'b000: dogpatch_y_2 <= 3'h7;
		3'b001: dogpatch_y_2 <= 3'h6;
		3'b010: dogpatch_y_2 <= 3'h4;
		3'b011: dogpatch_y_2 <= 3'h5;
		3'b100: dogpatch_y_2 <= 3'h1;
		3'b101: dogpatch_y_2 <= 3'h0;
		3'b110: dogpatch_y_2 <= 3'h2;
		3'b111: dogpatch_y_2 <= 3'h2; // ?
	endcase
    case (gunfight_y_count) 
		3'b000: gunfight_y <= 3'h6;
		3'b001: gunfight_y <= 3'h2;
		3'b010: gunfight_y <= 3'h0;
		3'b011: gunfight_y <= 3'h4;
		3'b100: gunfight_y <= 3'h5;
		3'b101: gunfight_y <= 3'h1;
		3'b110: gunfight_y <= 3'h3;
		3'b111: gunfight_y <= 3'h3; //?
	endcase
   case (gunfight_y_count_2) 
		3'b000: gunfight_y_2 <= 3'h6;
		3'b001: gunfight_y_2 <= 3'h2;
		3'b010: gunfight_y_2 <= 3'h0;
		3'b011: gunfight_y_2 <= 3'h4;
		3'b100: gunfight_y_2 <= 3'h5;
		3'b101: gunfight_y_2 <= 3'h1;
		3'b110: gunfight_y_2 <= 3'h3;
		3'b111: gunfight_y_2 <= 3'h3; //?
	endcase
	
	case (gunfight_y_count)
		3'b000: boothill_y <= 3'h0;
		3'b001: boothill_y <= 3'h4;
		3'b010: boothill_y <= 3'h6;
		3'b011: boothill_y <= 3'h7;
		3'b100: boothill_y <= 3'h3;
		3'b101: boothill_y <= 3'h1;
		3'b110: boothill_y <= 3'h5;
		3'b111: boothill_y <= 3'h5; //?
	endcase
	case (gunfight_y_count_2)
		3'b000: boothill_y_2 <= 3'h0;
		3'b001: boothill_y_2 <= 3'h4;
		3'b010: boothill_y_2 <= 3'h6;
		3'b011: boothill_y_2 <= 3'h7;
		3'b100: boothill_y_2 <= 3'h3;
		3'b101: boothill_y_2 <= 3'h1;
		3'b110: boothill_y_2 <= 3'h5;
		3'b111: boothill_y_2 <= 3'h5; //?
	endcase

	
    end
end

/* controls for seawolf */
wire [7:0] seawolf_shifted_x = gun_x[7:0]>>3;
reg [4:0] seawolf_position;

always @(posedge clk_sys) 
begin
   case (seawolf_shifted_x[4:0]) 
      5'b00000: seawolf_position <= ~5'h1e; // clamp
      5'b00001: seawolf_position <= ~5'h1e;
      5'b00010: seawolf_position <= ~5'h1c;
      5'b00011: seawolf_position <= ~5'h1d;
      5'b00100: seawolf_position <= ~5'h19;
      5'b00101: seawolf_position <= ~5'h18;
      5'b00110: seawolf_position <= ~5'h1a;
      5'b00111: seawolf_position <= ~5'h1b;
      5'b01000: seawolf_position <= ~5'h13;
      5'b01001: seawolf_position <= ~5'h12;
      5'b01010: seawolf_position <= ~5'h10;
      5'b01011: seawolf_position <= ~5'h11;
      5'b01100: seawolf_position <= ~5'h15;
      5'b01101: seawolf_position <= ~5'h14;
      5'b01110: seawolf_position <= ~5'h16;
      5'b01111: seawolf_position <= ~5'h17;
      5'b10000: seawolf_position <= ~5'h07;
      5'b10001: seawolf_position <= ~5'h06;
      5'b10010: seawolf_position <= ~5'h04;
      5'b10011: seawolf_position <= ~5'h05;
      5'b10100: seawolf_position <= ~5'h01;
      5'b10101: seawolf_position <= ~5'h00;
      5'b10110: seawolf_position <= ~5'h02;
      5'b10111: seawolf_position <= ~5'h03;
      5'b11000: seawolf_position <= ~5'h0b;
      5'b11001: seawolf_position <= ~5'h0a;
      5'b11010: seawolf_position <= ~5'h08;
      5'b11011: seawolf_position <= ~5'h09;
      5'b11100: seawolf_position <= ~5'h0d;
      5'b11101: seawolf_position <= ~5'h0c;
      5'b11110: seawolf_position <= ~5'h0e;
      5'b11111: seawolf_position <= ~5'h0e; // clamp
   endcase
end

/* Mouse - Trackball for Shuffleboard */

reg old_state;
reg signed [7:0] Sum_X;
reg signed [7:0] Sum_Y;

always @(posedge clk_sys) 
begin
	/* sum up delta changes from mouse */

	old_state <= ps2_mouse[24];
	if(old_state != ps2_mouse[24]) begin
		// Mouse X
		Sum_X <= Sum_X - {ps2_mouse[4], ps2_mouse[15:9]};  // 1/2 Scale

		// Mouse Y
		Sum_Y <= Sum_Y - {ps2_mouse[5], ps2_mouse[23:17]}; // 1/2 Scale
	end
end

reg fire_toggle = 0;
always @(posedge m_fire_a) fire_toggle <= ~fire_toggle;

reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;

// Global Enables
reg  landscape;			// Landscape
reg  ccw;					// Rotates Counter Clockwise
reg  color_rom_enabled;	// Uses colour prom / ram
wire WDEnabled;			// Uses Watchdog
wire ShiftReverse;		// Uses shifter that does both directions
wire Audio_Output;		// Audio output control
wire ScreenFlip;			// Flip the screen 180 degrees
wire Overlay4;          // Overlay aligned to 4 pixels (otherwise 8)
reg  software_flip;     // Flip the screen when software says to 

// Trigger addresses - set addresses where these registers are written to
wire Trigger_ShiftCount;
wire Trigger_ShiftData;
wire Trigger_AudioDeviceP1;
wire Trigger_AudioDeviceP2;
wire Trigger_WatchDogReset;
wire Trigger_Tone_Low;
wire Trigger_Tone_High;

// Port data 
wire [7:0] PortWr;

// Shifter data
wire [7:0] S;
wire [7:0] SR= { S[0], S[1], S[2], S[3], S[4], S[5], S[6], S[7]} ;

// Midway Tone Generator data
wire [5:0] Tone_Low;
wire [7:0] Tone_High; // Also used for Balloon Bomber and Polaris

always @(*) begin

			// Defaults - games in case statement change these as needed
        software_flip      <= 0;      
        gun_game  			<= 0;
        landscape 			<= 1;
        ccw						<= 0;
        color_rom_enabled	<= 0;
		  WDEnabled 			<= 1;
        GDB0 					<= 8'hFF;
        GDB1 					<= 8'hFF;
        GDB2 					<= 8'hFF;
        GDB3 					<= S;
		  GDB6               <= 8'hFF;
		  Audio_Output 		<= 1;  	 // Default = ON : won't do anything if no sample header loaded. 
												 // some games control audio output via an output bit somewhere!
		  Force_Red          <= 0;
		  Background_Col     <= {8'd0,8'd0,8'd0}; // Black

		  ScreenFlip         <= status[6];
		  Overlay4           <= 0; 	 // Default aligned to characters
												 
		  // default PortWr mapping
        Trigger_ShiftCount     <= PortWr[2];
        Trigger_AudioDeviceP1  <= PortWr[3];
        Trigger_ShiftData      <= PortWr[4];
        Trigger_AudioDeviceP2  <= PortWr[5];
        Trigger_WatchDogReset  <= PortWr[6];		  
		  Trigger_Tone_Low       <= 0;
		  Trigger_Tone_High      <= 0;

        case (mod) 
		  
			mod_spaceinvaders:
				begin
				 landscape	<=0;
				 ccw			<=1;

				 GDB0 <= sw[0] | { 1'b1, m_right,m_left,m_fire_a,1'b1,1'b1, 1'b1,1'b1};
				 GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b1,m_start1, m_start2, m_coin1 };
				 GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b0, 1'b0 };
				end
			mod_spaceinvaders2: // invad2ct
			begin
				 landscape	<=0;
				 ccw			<=0;

				 GDB0 <= sw[0] | { 1'b1, 1'b0,1'b0,1'b0,1'b1,1'b1, 1'b1,1'b1};
				 GDB1 <= sw[1] | { 1'b1, m_left1,m_right1,m_fire1a,1'b1,m_start1, m_start2, m_coin1 };
				 GDB2 <= sw[2] | { 1'b0, m_right2,m_left2,m_fire2a,1'b0,1'b0, 1'b0, 1'b0 };
			end
			mod_shuffleboard:
        begin
          landscape<=0;
          ccw<=0;

          GDB1 <= S;
          GDB2 <= sw[0];
          GDB3 <= SR;
			 GDB4 <= ~{ 4'd0, m_fire_a, m_start2, m_start1, m_coin1 };	  // IN0
			 GDB5 <= Sum_Y;  // Trackball
			 GDB6 <= Sum_X;  // Trackball

          Trigger_ShiftCount     <= PortWr[1];
          Trigger_AudioDeviceP1  <= PortWr[5];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_AudioDeviceP2  <= PortWr[6];
          Trigger_WatchDogReset  <= PortWr[4];
          software_flip          <= 0;      
        end
		  
        mod_vortex:
        begin
          //GDB0 -- all FF
          //
          landscape<=0;
          ccw<=1;
	  // note because the CPU has the address line A9 (A1 for IO) inverted
	  // we have to be careful in looking at mame mapping
	  // Currently: GDB0-7 have A9 inverted, but PortWr doesn't
	  // we should probably not invert A9 in GDB0-7? AJS TODO
	  // IN0
          GDB0 <= sw[0] | { 1'b0, 1'b0,1'b0,1'b0,1'b0,1'b0, 1'b0,1'b0};
	  // IN1
          GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b0,m_start1, m_start2, ~m_coin1 };
          //GDB2 <= sw[2] | { 1'b0, 1'b0,1'b0,1'b0,1'b0,1'b0, 1'b0,1'b0};
          GDB2 <= sw[2] | { 1'b0, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b0, 1'b0 };
	  // IN2 -- settings
          GDB3 <= S;
	  
          Trigger_ShiftCount     <= PortWr[0];
          Trigger_AudioDeviceP1  <= PortWr[1];
          Trigger_ShiftData      <= PortWr[6];
          Trigger_AudioDeviceP2  <= PortWr[7];
          Trigger_WatchDogReset  <= PortWr[4];
 			software_flip          <= 0;      

        end
        mod_lagunaracer:
	begin
 	  landscape<=0;
			GDB0 <= sw[0] | { ~m_start1, ~m_coin1, 1'b1, fire_toggle, zap_throttle};
         GDB1 <= 8'd127-joya[7:0];
         GDB2 <= sw[2] | { 1'b0, 1'b0, 1'b0,1'b0,1'b0,1'b0, 1'b0, 1'b0 };
          Trigger_ShiftCount     <= PortWr[4];
          Trigger_AudioDeviceP1  <= PortWr[2];
          Trigger_ShiftData      <= PortWr[3];
          Trigger_AudioDeviceP2  <= PortWr[5];
          Trigger_WatchDogReset  <= PortWr[7];
			 software_flip          <= 0;

        end
	mod_280zap:
	begin
 	  landscape<=1;
	       GDB0 <= sw[0] | { ~m_start1, ~m_coin1, 1'b1, fire_toggle, zap_throttle};
          GDB1 <= 8'd127-joya[7:0];
          GDB2 <= sw[2] | { 1'b0, 1'b0, 1'b0,1'b0,1'b0,1'b0, 1'b0, 1'b0 };
          Trigger_ShiftCount     <= PortWr[4];
          Trigger_AudioDeviceP1  <= PortWr[2];
          Trigger_ShiftData      <= PortWr[3];
          Trigger_AudioDeviceP2  <= PortWr[5];
          Trigger_WatchDogReset  <= PortWr[7];
			 software_flip          <= 0;


	end

        mod_blueshark:
        begin
		    gun_game <= 1;
          GDB0 <= SR;
          GDB1 <= blue_shark_x;
          GDB2 <= sw[2] | { 1'b0, 1'b0,1'b0,1'b1,1'b1,1'b1,m_coin1 ,~m_fire_a};
          Trigger_ShiftCount     <= PortWr[1];
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_WatchDogReset  <= PortWr[4];
			 software_flip          <= 0;

        end
        mod_boothill:
        begin 
          // IN0
          GDB0 <= sw[0] | { ~m_fire2a,boothill_y_2,~m_right2,~m_left2,~m_down2,~m_up2};
          // IN1
          GDB1 <= sw[1] | { ~m_fire1a, boothill_y,~m_right1,~m_left1,~m_down1,~m_up1};
          // IN2
          GDB2 <= sw[2] | { ~m_start2, ~m_coin1,~m_start1,1'b0,1'b0,1'b0, 1'b0, 1'b0 };
          Trigger_ShiftCount     <= PortWr[1]; // IS THIS WEIRD?
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_WatchDogReset  <= PortWr[4];
	 		 Trigger_Tone_Low       <= PortWr[5];
		    Trigger_Tone_High      <= PortWr[6];
			 Audio_Output           <= SoundCtrl3[3];
          software_flip          <= 0;
			 GDB3 <= ShiftReverse ? SR: S;
        end
		  
        mod_lunarrescue:
        begin
          landscape<=0;
          color_rom_enabled<=1;
          ccw<=1;
			 WDEnabled <= 1'b0;
//			 if (Trigger_AudioDeviceP2)
//			     software_screen_flip <= SoundCtrl5[5] & sw[2][2];			 
          //GDB0 <= sw[0] | { 1'b1, m_right,m_left,m_fire_a,1'b1,1'b0, 1'b0,1'b0};
          //GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b1,m_start1, m_start2, m_coin1 };
          //GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b1, 1'b1 };
          GDB0 <= sw[0] | { 1'b0, 1'b0,1'b0,1'b0,1'b0,1'b0, 1'b0,1'b0};
          //GDB0 <= sw[0] | { 1'b0, 1'b0, 1'b0, m_right,m_left,m_fire_a,1'b1,1'b1, 1'b1,1'b1};
          GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b0,m_start1, m_start2, ~m_coin1 };
          GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b1, 1'b1 };
          software_flip          <= 0;      

        end
        mod_ozmawars:
        begin
            landscape<=0;
//				if (Trigger_AudioDeviceP2)
//				    software_screen_flip <= SoundCtrl5[5] & sw[3][0];
			   ccw<=1;
            color_rom_enabled<=1;
         // GDB0 <= sw[0] | ~{ 1'b0, m_right,m_left,m_fire_a,1'b0,1'b1, 1'b1,1'b1};
            GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b0,m_start1, m_start2, ~m_coin1 };
            GDB2 <= sw[2] | { m_start1, m_coin1,m_start2,1'b0,1'b0,1'b0, 1'b0, 1'b0 };
				software_flip          <= 0;      

          end
        mod_spacelaser:
        begin
            landscape<=0;
            ccw<=1;
            color_rom_enabled<=1;
        // GDB0 <= sw[0] | ~{ 1'b0, m_right,m_left,m_fire_a,1'b0,1'b1, 1'b1,1'b1};
            GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b1,m_start1, m_start2, m_coin1 };
            GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b0, 1'b0 };
		  end
        mod_spacewalk:
        begin
				 WDEnabled <= 1'b1;
             GDB0 <= ~(8'd127-joya[7:0]);
             GDB1 <= sw[1] | { 1'b1,~m_coin1,~m_start1,~m_start2,1'b1,1'b1,1'b1,1'b1};
             GDB2 <= sw[2];
				 Trigger_ShiftCount     <= PortWr[1];
             Trigger_AudioDeviceP1  <= PortWr[7];
             Trigger_ShiftData      <= PortWr[2];
             Trigger_AudioDeviceP2  <= PortWr[3];
             Trigger_WatchDogReset  <= PortWr[4];
             Audio_Output           <= SoundCtrl5[2];
             Trigger_Tone_Low       <= PortWr[5];
             Trigger_Tone_High      <= PortWr[6];
				 Overlay4               <= 1;
  				software_flip          <= 0;      

        end
		  
			mod_spaceinvaderscv:
			begin
				landscape<=0;
				ccw<=1;
				color_rom_enabled<=1;
				if (Trigger_AudioDeviceP2) software_flip <= SoundCtrl5[5] & sw[3][0];
				GDB0 <= sw[0] | { 1'b0, 1'b0,1'b0,1'b0,1'b0,1'b0, 1'b0,1'b0};
				GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b1,m_start1, m_start2, m_coin1 };
				GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b0, 1'b0 };
				software_flip          <= 0;      

			end
			mod_rollingcrash:
			begin
				landscape<=0;
				ccw<=1;
				color_rom_enabled<=1;
				if (Trigger_AudioDeviceP2) software_flip <= SoundCtrl5[5] & sw[3][0];
				GDB0 <= sw[0] | { 1'b0, 1'b0,1'b0,1'b0,1'b0,1'b0, 1'b0,1'b0};
				GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b1,m_start1, m_start2, m_coin1 };
				GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b0, 1'b0 };
			end
        mod_unknown1:
        begin
        GDB0 <= 8'hFF;
        GDB1 <= 8'hFF;
        GDB2 <= 8'hFF;
        end
        mod_unknown2:
        begin
        GDB0 <= 8'h00;
        GDB1 <= 8'h00;
        GDB2 <= 8'h00;
        end
        mod_spaceinvadersii:
        begin
				landscape<=0;
				ccw<=1;
				color_rom_enabled<=1;
				GDB0 <= sw[0] | { 1'b0, 1'b0,1'b0,1'b0,1'b0,1'b0, 1'b0,1'b0};
				//GDB0 <= sw[0] | { 1'b0, 1'b0, 1'b0, m_right,m_left,m_fire_a,1'b1,1'b1, 1'b1,1'b1};
				GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b0,m_start1, m_start2, ~m_coin1 };
				GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b1, 1'b1 };
				software_flip          <= 0;      

        end
        mod_amazingmaze:
        begin
				WDEnabled 		<= 1'b0;
				GDB0 				<= sw[0] | { m_up2, m_down2, m_right2, m_left2, m_up1, m_down1, m_right1, m_left1} ;
				GDB1 				<= sw[1] | { 1'b0, 1'b0,1'b0,1'b0,m_coin1, 1'b0, m_start2, m_start1};
				GDB2 				<= 8'b0;
				software_flip  <= 0;
		 end
        mod_attackforce:
		  begin
            landscape<=1;
            WDEnabled <= 1'b0;
            ccw<=1;
            GDB0 <= sw[0] | { ~m_coin1, 1'b1,1'b1,1'b1,1'b1,~m_fire_a, ~m_left,~m_right};
            GDB1 <= 8'b0;
            GDB2 <= 8'b0;
            Trigger_ShiftCount     <= PortWr[7];
            Trigger_AudioDeviceP1  <= PortWr[4];
            Trigger_ShiftData      <= PortWr[3];
            Trigger_AudioDeviceP2  <= PortWr[6];
            Trigger_WatchDogReset  <= PortWr[5];
				software_flip  <= 0;
        end
	
        mod_ballbomb:
			begin
            landscape<=0;
				WDEnabled <= 1'b0;
            ccw<=1;
            color_rom_enabled<=1;
            GDB0 <= sw[0] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b0, 1'b0 };
            GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b1,m_start1, m_start2, m_coin1 };
            GDB2 <= sw[2] | { 1'b0, 1'b0,1'b0,1'b0,1'b0,1'b0, 1'b0,1'b0};
				Audio_Output <= SoundCtrl3[5];
				if (Trigger_AudioDeviceP2) software_flip <= SoundCtrl5[5] & sw[3][0];
				Trigger_Tone_High <= PortWr[1]; // out 1 = music generator!
				Force_Red <=  SoundCtrl3[2]; // Base hit - all red
			   Background_Col     <= {8'd0,8'd0,8'd255}; // Blue
			end
			
        mod_bowler:
		  begin
            landscape<=0;
            software_flip          <= 0;
				// 0 - dips
				GDB0 <= sw[0];
				// 1 - controls
				GDB1 <= ~S;
				//GDB1 <= sw[1] | { 1'b0,1'b0,1'b0,1'b0,m_fire_b,m_start1, m_fire_a, m_coin1 };
				// 2, 3 trackball
				GDB2 <= sw[2];
				GDB3 <= ~SR;
				Trigger_ShiftCount     <= PortWr[1];
				//Trigger_AudioDeviceP1  <= PortWr[3];
				Trigger_ShiftData      <= PortWr[2];
				//Trigger_AudioDeviceP2  <= PortWr[6];
				Trigger_WatchDogReset  <= PortWr[4];
				//<= PortWr[5]; // bowler_audio_1_w 
				//<= PortWr[6]; // bowler_audio_2_w
				//<= PortWr[7]; // bowler_lights_1_w
				//<= PortWr[8]; //
				//<= PortWr[9]; //
				//<= PortWr[A]; //
				//<= PortWr[E]; //
				//<= PortWr[F]; //
			end
			mod_checkmate:
			begin
				WDEnabled <= 1'b0;
				// IN0
				GDB0 <= sw[0] | { m_right2,m_left2,m_down2,m_up2,m_right1,m_left1,m_down1,m_up1};
				GDB1 <= sw[1] | { m_right4,m_left4,m_down4,m_up4,m_right3,m_left3,m_down3,m_up3};
				GDB2 <= sw[2]; // dips
				GDB3 <= sw[3] | { m_coin1, 1'b0,1'b0,1'b0,m_start4,m_start3,m_start2,m_start1};
				//GDB3 <= sw[3] | { m_coin1, 1'b0,1'b0,1'b0,1'b0,1'b0,m_start2,m_start1};
				//<= PortWr[3]; //  checkmat_io_w
            software_flip          <= 0;
			end
        mod_clowns:
			begin
				//GDB0 -- all FF
				//
				landscape<=1;
				// IN0
				// 2 player is broken - they are multiplexed
				GDB0 <= SoundCtrl3[1] ? ~(8'd127-joya[7:0]) : ~(8'd127-joya2[7:0]);
				GDB1 <= sw[1] | { 1'b1,~m_coin1,~m_start1,~m_start2,1'b1,1'b1,1'b1,1'b1};
				GDB2 <= sw[2] | { 1'b0, 1'b0,1'b0,1'b0,1'b0,1'b0, 1'b0,1'b0};
				GDB3 <= S;

				Trigger_ShiftCount     <= PortWr[1];
				Trigger_AudioDeviceP1  <= PortWr[7];
				Trigger_ShiftData      <= PortWr[2];
				Trigger_AudioDeviceP2  <= PortWr[3];
				Trigger_WatchDogReset  <= PortWr[4];
				Audio_Output           <= SoundCtrl3[3];
				Trigger_Tone_Low       <= PortWr[5];
				Trigger_Tone_High      <= PortWr[6];
				software_flip   		  <= 1'd0;
			end

			mod_cosmo:
			begin
				landscape<=0;
				ccw<=0;
				color_rom_enabled<=1;
				GDB0 <= sw[0] | { 1'b0, 1'b0,1'b0,1'b0,1'b0,1'b0, 1'b0,1'b0};
				GDB1 <= sw[1] | { 1'b0, m_right,m_left,m_fire_a,1'b1,m_start1, m_start2, m_coin1 };
				GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b0, 1'b0 };
				Trigger_ShiftCount     <= 1'b0;
				Trigger_AudioDeviceP1  <= PortWr[3];
				Trigger_ShiftData      <= 1'b0;
				Trigger_AudioDeviceP2  <= PortWr[5];
				Trigger_WatchDogReset  <= PortWr[6];
				software_flip   		  <= 1'd0;
			end
			
	mod_dogpatch:
        begin
				landscape<=1;
				ccw<=0;
				color_rom_enabled<=1;
				GDB0 <= sw[0] | { ~m_fire_b, dogpatch_y_2, 1'b1, ~m_start2, ~m_start1, ~m_coin1 };
				GDB1 <= sw[1] | { ~m_fire_a, dogpatch_y, 1'b1, 1'b1, 1'b1 , 1'b1};
				GDB2 <= sw[2];
				Trigger_ShiftCount     <= PortWr[1];
				Trigger_AudioDeviceP1  <= PortWr[3];
				Trigger_ShiftData      <= PortWr[2];
				Trigger_AudioDeviceP2  <= PortWr[7];
				Trigger_WatchDogReset  <= PortWr[4];
				 //<= PortWr[5]; // tone_generator_low_w
				 //<= PortWr[6]; // tone_generator_hi_w
				
					// AJS -- will this work:
				Trigger_Tone_Low       <= PortWr[5];
		      Trigger_Tone_High      <= PortWr[6];

				 
				software_flip          <= 0;
			end
	mod_doubleplay:
        begin
				landscape<=1;
				ccw<=0;
				color_rom_enabled<=1;
				GDB0 <= sw[0] | { ~m_start1, joya[7:2], ~m_fire_a};
				GDB1 <= sw[1] | { ~m_start2, joya[7:2], ~m_fire_a};
				GDB2 <= sw[2] | { ~m_coin1, 7'b0 };
				Trigger_ShiftCount     <= PortWr[1];
				Trigger_AudioDeviceP1  <= PortWr[3];
				Trigger_ShiftData      <= PortWr[2];
				//Trigger_AudioDeviceP2  <= PortWr[7];
				Trigger_WatchDogReset  <= PortWr[4];
				//<= PortWr[5]; // tone_generator_low_w
				//<= PortWr[6]; // tone_generator_hi_w
				// AJS -- will this work:
				Trigger_Tone_Low       <= PortWr[5];
				Trigger_Tone_High      <= PortWr[6];
				software_flip          <= 0;

	end
        mod_guidedmissle:
        begin 
				// IN0
				GDB0 <= sw[0] | {~m_fire2a,~m_start1,1'b1,1'b1,~m_right2,~m_left2,1'b1,1'b1};
				GDB1 <= sw[1] | {~m_fire1a,~m_start2,1'b1,1'b1,~m_right1,~m_left1,~m_coin1,1'b1};
				// IN2
				GDB2 <= sw[2];
				Trigger_ShiftCount     <= PortWr[1]; // IS THIS WEIRD?
				Trigger_AudioDeviceP1  <= PortWr[3];
				Trigger_ShiftData      <= PortWr[2];
				Trigger_WatchDogReset  <= PortWr[4];
				//<= PortWr[5]; // tone_generator_low_w
				//<= PortWr[6]; // tone_generator_hi_w
				Trigger_Tone_Low       <= PortWr[5];
				Trigger_Tone_High      <= PortWr[6];
				GDB3 <= ShiftReverse ? SR: S;
				software_flip          <= 0;
        end
        mod_claybust:
        begin 
		    gun_game <= 1;
          // IN0
          GDB1 <= sw[1] | { 1'b0,1'b0,1'b0,1'b0, ~m_start1, ~m_coin1, |claybust_gun_on, |claybust_gun_on};
          GDB2 <=  claybust_gun_pos_lo;
          GDB6 <=  claybust_gun_pos_hi;
          Trigger_ShiftCount     <= PortWr[1];
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_WatchDogReset  <= PortWr[4];
          software_flip          <= 0;
        end
        mod_gunfight:
			begin
				WDEnabled <= 1'b0;
				// IN0
				GDB0 <= sw[0] | { m_fire1a,~gunfight_y, m_right1,m_left1,m_down1,m_up1};
				GDB1 <= sw[1] | { m_fire2a,~gunfight_y_2,m_right2,m_left2,m_down2,m_up2};
				GDB2 <= sw[2] | { m_start1,m_coin1, 6'b0};
				Trigger_ShiftCount     <= PortWr[2];
				Trigger_AudioDeviceP1  <= PortWr[1];
				Trigger_ShiftData      <= PortWr[4];
				//Trigger_WatchDogReset  <= PortWr[4];
				software_flip          <= 0;
			end
        mod_indianbattle:
        begin
          landscape<=0;
			 ccw <= 1;
          color_rom_enabled<=1;
          GDB0 <= sw[0];
          GDB1 <= sw[1] | { 1'b1,m_right1,m_left1,m_fire1a, 1'b0,  m_start1,m_start2,~m_coin1};
          GDB2 <= sw[2];
          Trigger_ShiftCount     <= PortWr[2];
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[4];
          Trigger_AudioDeviceP2  <= PortWr[5];
          Trigger_WatchDogReset  <= PortWr[6];
          software_flip          <= 0;      

        end
        mod_lupin:
        begin
          landscape<=0;
          ccw <= 1;
          color_rom_enabled<=1;
          GDB0 <= sw[0] | { m_up2,m_left2,m_down2,m_right2,m_fire2a,1'b0,1'b0,1'b0};
          GDB1 <= sw[1] | { m_up1,m_left1,m_down1,m_right1,m_fire1a,m_start1,m_start2,m_coin1};
          GDB2 <= sw[2];
          Trigger_ShiftCount     <= PortWr[2];
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[4];
          Trigger_AudioDeviceP2  <= PortWr[5];
          Trigger_WatchDogReset  <= PortWr[6];
          software_flip          <= 0;      
        end
		  
		  mod_lupin1:
		  begin 
          landscape<=0;
          ccw <= 1;
          color_rom_enabled<=1;
          GDB0 <= sw[0] | { m_up2,m_left2,m_down2,m_right2,m_fire2a,1'b0,1'b1,1'b1};
          GDB1 <= sw[1] | { m_up1,m_left1,m_down1,m_right1,m_fire1a,m_start1,m_start2,m_coin1};
          GDB2 <= sw[2];
          Trigger_ShiftCount     <= PortWr[2];
          Trigger_AudioDeviceP1  <= PortWr[3];
          Trigger_ShiftData      <= PortWr[4];
          Trigger_AudioDeviceP2  <= PortWr[5];
          Trigger_WatchDogReset  <= PortWr[6];
          software_flip          <= 0;      
		  end
		  
        mod_m4:
        begin 
				landscape<=1;
				WDEnabled <= 1'b0;
				// IN0
				GDB0 <= sw[0] | { 1'b1, 1'b1,~m_fire2b,~m_fire2a,~m_down2,1'b1,~m_up2,1'b1};
				GDB1 <= sw[1] | { 1'b1,~m_start2,~m_fire1b,~m_fire1a,~m_down1,~m_start1,~m_up1,~m_coin1};
				GDB2 <= sw[2];
				Trigger_ShiftCount     <= PortWr[1]; // IS THIS WEIRD?
				Trigger_AudioDeviceP1  <= PortWr[3];
				Trigger_ShiftData      <= PortWr[2];
				Trigger_WatchDogReset  <= PortWr[4];
				Trigger_AudioDeviceP2  <= PortWr[5];
				GDB3 <= ShiftReverse ? SR: S;
            software_flip          <= 0;      


        end
        mod_phantom:
        begin
				landscape<=1;
				GDB0 <= SR;
				GDB1 <= sw[1] | { 1'b1,1'b1,~m_coin1,~m_fire1a,~m_right1,~m_left1,~m_down1,~m_up1};
				GDB2 <= sw[2];
				Trigger_ShiftCount     <= PortWr[1];
				Trigger_ShiftData      <= PortWr[2];
				Trigger_WatchDogReset  <= PortWr[4];
				Trigger_AudioDeviceP1  <= PortWr[5];
				Trigger_AudioDeviceP2  <= PortWr[6];
				software_flip          <= 0;      

				end
        mod_polaris:
		  begin
				landscape<=0;
				ccw<=1;
				color_rom_enabled<=1;
				
				GDB0 <= sw[0];
				
				if (software_flip) begin
					GDB1 <= { m_up2,m_left2,m_down2,m_right2,m_fire2a,m_start1,m_start2,m_coin1};
				end
				else begin
					GDB1 <= { m_up1,m_left1,m_down1,m_right1,m_fire1a,m_start1,m_start2,m_coin1};
				end;
				
				GDB2 <= sw[2];

            Audio_Output           <= SoundCtrl3[5];
				Trigger_ShiftCount     <= PortWr[1];
				Trigger_Tone_High      <= PortWr[2];
				Trigger_ShiftData      <= PortWr[3];
				Trigger_AudioDeviceP1  <= PortWr[4];
				Trigger_WatchDogReset  <= PortWr[5];
				Trigger_AudioDeviceP2  <= PortWr[6];
				
				software_flip <= SoundCtrl5[5] & sw[3][0];

				// Background colour split mid screen
				if (VCount < 2) begin
					Background_Col     <= {8'd0,8'd0,8'd0}; 			// Black
				end
				else begin
					if (HCount < 127) begin // was 128
						Background_Col     <= {8'd0,8'd0,8'd255}; 	// Blue
					end
					else begin
						Background_Col     <= {8'd0,8'd255,8'd255}; 	// Cyan
					end;
				end;
		  end
		  
        mod_desertgun:
	     begin
          gun_game <= 1;
          landscape <= 1;
          GDB0 <= SR;
          GDB1 <= desert_gun_select ? desert_gun_x[7:0] : desert_gun_y[7:0];
          GDB2 <= sw[2] | { ~m_fire1a,m_coin1, 2'b0, 2'b0, 2'b0};

          Trigger_ShiftCount     <= PortWr[1];
          Trigger_ShiftData      <= PortWr[2];
          Trigger_WatchDogReset  <= PortWr[4];
          Trigger_AudioDeviceP1  <= PortWr[3];
          //<= PortWr[5]; // tone_generator_low_w
          //<= PortWr[6]; // tone_generator_hi_w
          Trigger_AudioDeviceP2  <= PortWr[7];
				Trigger_Tone_Low       <= PortWr[5];
				Trigger_Tone_High      <= PortWr[6];
				software_flip          <= 0;      
	      end
			mod_seawolf:
			begin
					gun_game <= 1;
					landscape<=1;
					WDEnabled <= 1'b0;
					ccw<=0;
					GDB0 <= SR;
					// IN0
					GDB1 <= sw[0] | { 2'b0, m_fire_a, seawolf_position};
					GDB2 <= sw[1] | { 3'b0,1'b0 /*erase?*/, 2'b0,m_start1,m_coin1};
					Trigger_ShiftData      <= PortWr[3];
					Trigger_ShiftCount     <= PortWr[4];
					//<= PortWr[5];
					//<= PortWr[6];
					//<= PortWr[4];
					Trigger_AudioDeviceP1  <= PortWr[5];
					Trigger_AudioDeviceP2  <= 1'b0;
					software_flip          <= 0;      

			end
			mod_yosakdon:
			begin
				WDEnabled <= 1'b0;
				landscape<=0;
				ccw<=1;
				//GDB0 <= SR;
				// IN0
				GDB1 <= sw[0] | { 1'b0, m_right,m_left,m_fire_a,1'b0,m_start1, m_start2, m_coin1 };
				// IN1
				GDB2 <= sw[1] | { 1'b0, m_right,m_left,m_fire_a,1'b0,1'b0,1'b0,1'b0};
				Trigger_AudioDeviceP1  <= PortWr[3];
				Trigger_AudioDeviceP2  <= PortWr[5];
				software_flip          <= 0;      

				end
       mod_spacechaser:
       begin
            landscape<=0;
            ccw<=1;
            color_rom_enabled<=1;
            GDB0 <= { sw[0][7:5],  m_fire2a,  m_right2,m_down2,m_left2,m_up2};
            GDB1 <= { m_coin1,m_start1,m_start2,m_fire_a,m_right,m_down,m_left,m_up};
            GDB2 <= sw[2];
				software_flip <= 0;    
				Background_Col <= {8'd0,8'd0,8'd255}; // Blue		
       end
		 
       mod_steelworker:
       begin
				WDEnabled <= 1'b0;
				GDB0 <= 0;
				GDB1 <= sw[1] |{ ~m_fire1b, m_right,m_left,m_fire1a,1'b0,m_start1,m_start2, ~m_coin1};
				GDB2 <= sw[2] |{ ~m_fire2b, m_right2, m_left2 , m_fire2a,1'b0,1'b0, 1'b0,1'b0} ;
				Trigger_ShiftCount     <= PortWr[2];
				//Trigger_AudioDeviceP1  <= PortWr[2];
				Trigger_ShiftData      <= PortWr[4];
				//Trigger_AudioDeviceP2  <= PortWr[5];
				//Trigger_WatchDogReset  <= PortWr[7];
				software_flip          <= 0;      

				end
			default:
				begin
				 landscape	<=0;
				 ccw			<=1;

				 GDB0 <= sw[0] | { 1'b1, m_right,m_left,m_fire_a,1'b1,1'b1, 1'b1,1'b1};
				 GDB1 <= sw[1] | { 1'b1, m_right,m_left,m_fire_a,1'b1,m_start1, m_start2, m_coin1 };
				 GDB2 <= sw[2] | { 1'b1, m_right,m_left,m_fire_a,1'b0,1'b0, 1'b1, 1'b1 };
				end
			
				
      endcase
end

wire [10:0] color_prom_addr;
wire [7:0]  color_prom_out;
wire [15:0]RAB;
wire [15:0]AD;
wire [7:0]RDB;
wire [7:0]RWD;
wire [7:0]IB;
wire [7:0]SoundCtrl3;
wire [7:0]SoundCtrl5;
wire Rst_n_s;
wire RWE_n;
wire Video;
wire HSync;
wire VSync;
wire CPU_RW_n;

wire [11:0] HCount;
wire [11:0] VCount;

wire Vortex_Col;

// Software flip reverses whatever the hardware flip was set to
wire DoScreenFlip = software_flip ? ~(ScreenFlip & ~landscape) : (ScreenFlip & ~landscape);

invaderst invaderst(
		.Rst_n(~(reset_sys)),
		.Clk(clk_sys),
		.ENA(),

		.GDB0(GDB0),
		.GDB1(GDB1),
		.GDB2(GDB2),
		.GDB3(GDB3),
		.GDB4(GDB4),
		.GDB5(GDB5),
		.GDB6(GDB6),

		.WD_Enabled(WDEnabled),

		.RDB(RDB),
		.IB(IB),
		.RWD(RWD),
		.RAB(RAB),
		.AD(AD),
		.SoundCtrl3(SoundCtrl3),
		.SoundCtrl5(SoundCtrl5),
		.Tone_Low(Tone_Low),
		.Tone_High(Tone_High),
		.Rst_n_s(Rst_n_s),
		.RWE_n(RWE_n),
		.Video(Video),
		.CPU_RW_n(CPU_RW_n),

		.color_prom_addr(color_prom_addr),
		.color_prom_out(color_prom_out),
		.ScreenFlip(DoScreenFlip),
		.Overlay_Align(Overlay4),

		.O_VIDEO_R(r),
		.O_VIDEO_G(g),
		.O_VIDEO_B(b),
		.O_VIDEO_A(fg),
		
		.HBLANK(hblank),
		.VBLANK(vblank),
		.HSync(HSync),
		.VSync(VSync),

		.HShift(status[19:16]),
		.VShift(status[23:20]),
		
		.Overlay(~status[8]),

`ifdef DEBUG_MODE
		.OverlayTest(status[9]),
`else
		.OverlayTest(1'd0),
`endif

		.pause(pause_cpu),

		.Trigger_ShiftCount(Trigger_ShiftCount),
		.Trigger_ShiftData(Trigger_ShiftData),
		.Trigger_AudioDeviceP1(Trigger_AudioDeviceP1),
		.Trigger_AudioDeviceP2(Trigger_AudioDeviceP2),
		.Trigger_WatchDogReset(Trigger_WatchDogReset),
		.Trigger_Tone_Low(Trigger_Tone_Low),
		.Trigger_Tone_High(Trigger_Tone_High),

		.PortWr(PortWr),
		.S(S),
		.ShiftReverse(ShiftReverse),

		.mod_vortex(mod==mod_vortex),
		.overclock(mod_polaris && sw[3][1]),
		.Vortex_Col(Vortex_Col)
   );
		  
	invaders_memory invaders_memory (
			.Clock(clk_sys),
			.RW_n(RWE_n),
			.CPU_RW_n(CPU_RW_n),
			.Addr(AD),
			.Ram_Addr(RAB),
			.Ram_out(RDB),
			.Ram_in(RWD),
			.Rom_out(IB),
			.color_prom_out(color_prom_out),
			.color_prom_addr(color_prom_addr),
			.dn_addr(ioctl_addr[15:0]),
			.dn_data(ioctl_dout),
			.dn_wr(ioctl_wr&ioctl_index==0),
			.Vortex_bit(Vortex_Col),
			.PlanePos(PlanePos),
			.mod_vortex(mod==mod_vortex),
			.mod_attackforce(mod==mod_attackforce),
			.mod_cosmo(mod==mod_cosmo),
			.mod_polaris(mod==mod_polaris),
			.mod_lupin(mod==mod_lupin),
			.mod_indianbattle(mod==mod_indianbattle),
			.mod_spacechaser(mod==mod_spacechaser),

			.hs_address(hs_address),
			.hs_data_in(hs_data_in),
			.hs_data_out(hs_data_out),
			.hs_write(hs_write_enable),
			.hs_access(hs_access_read|hs_access_write)
	);

invaders_audio invaders_audio (
        .Clk(clk_sys),
        .S1(SoundCtrl3),
        .S2(SoundCtrl5),
        .Aud(inv_audio_data)
        );

// 280z engine noise
zap_audio zap_audio (
        .Clk(clk_sys),
        .S1(SoundCtrl3),
        .S2(SoundCtrl5),
        .Aud(zap_audio_data)
        );

// Background Image

wire bg_download = ioctl_download && (ioctl_index == 2);
reg  [16:0] max_bg;

reg [7:0] ioctl_dout_r;
reg [7:0] ioctl_dout_r2;
reg [7:0] ioctl_dout_r3;

always @(posedge clk_sys) 
begin
	if(ioctl_wr & ~ioctl_addr[1] & ~ioctl_addr[0]) ioctl_dout_r <= ioctl_dout;
	if(ioctl_wr & ~ioctl_addr[1] &  ioctl_addr[0]) ioctl_dout_r2 <= ioctl_dout;
	if(ioctl_wr &  ioctl_addr[1] & ~ioctl_addr[0]) ioctl_dout_r3 <= ioctl_dout;
	if(bg_download) max_bg <= {ioctl_addr[17:2],1'd0};
end

spram #(
	.addr_width_g(16),
	.data_width_g(32)) 
u_ram0(
	.address(bg_download ? ioctl_addr[17:2] : pic_addr[16:1]),
	.clken(1'b1),
	.clock(clk_mem),
	.data({ioctl_dout, ioctl_dout_r3, ioctl_dout_r2, ioctl_dout_r}),
	.wren(bg_download & ioctl_wr & ioctl_addr[1] & ioctl_addr[0]),	// write every 4th byte 
	.q(pic_data)
	);

wire [31:0] pic_data;
reg  [16:0] pic_addr;
reg  [7:0]  bg_r,bg_g,bg_b,bg_a;

always @(posedge clk_40) begin
	reg use_bg = 0;
	
	if(bg_download) use_bg <= 1;

	if(use_bg) begin
		if(ce_pix) begin
			if (HCount < 4 || HCount > 247) begin
				{bg_a,bg_b,bg_g,bg_r} <= 0;
			end
			else begin
				{bg_a,bg_b,bg_g,bg_r} <= pic_data;
			end;
			if(~(hblank|vblank)) begin
				if(ScreenFlip & ~landscape) begin
					pic_addr <= pic_addr - 2'd2;
				end
				else begin
					pic_addr <= pic_addr + 2'd2;
				end;
			end
			
			if (VCount == 11'd0 && HCount == 11'd0) begin
				if(ScreenFlip & ~landscape) begin
					pic_addr <= max_bg;
				end
				else begin
					pic_addr <= 0;
				end;
			end;
			
		end
	end
	else begin
		// Mix cloud background in (Balloon Bomber or Polaris)
		if ((mod==mod_ballbomb & BBPixel==1'd1) || ((mod==mod_polaris & PolarisPixel==1'd1) && (VCount > 1))) begin
			// bg_a ?
			bg_b <= 255;
			bg_g <= 255;
			bg_r <= 255;
		end
		else 
		begin
			{bg_a,bg_b,bg_g,bg_r} <= 0;
		end;
	end
end

// Virtual Gun pointer

wire [1:0] gun_mode = status[12:11];
wire [1:0] gun_cross_size = status[14:13];
wire       gun_target;
wire [7:0] gun_x, gun_y;
reg        gun_game = 0;

virtualgun virtualgun
(
	.CLK(clk_40),
	
	.MOUSE(ps2_mouse),
	.MOUSE_XY(gun_mode[1]),
	.JOY_X(!gun_mode ? joya[7:0] : joya2[7:0]),
	.JOY_Y(!gun_mode ? joya[15:8] : joya2[15:8]),
	.JOY(!gun_mode ? joy1 : joy2),

	.HDE(~hblank),
	.VDE(~vblank),
	.CE_PIX(ce_pix),

	.SIZE(gun_cross_size),

	.H_COUNT(HCount),
	.V_COUNT(VCount),

	.TARGET(gun_target),
	.X_OUT(gun_x),
	.Y_OUT(gun_y)
);

////////////////////////////  Samples   ///////////////////////////////////

reg  [27:0] wav_addr;
wire [15:0] wav_data_o;
wire        wav_want_byte;
wire [15:0] samples_left;
wire [15:0] samples_right;

reg  Ready_L;
wire Ready;
reg  [15:0] wav_data;

        sdram sdram
        (
                .*,
                .init(~pll_locked),
                .clk(clk_mem),

                .addr(ioctl_download ? ioctl_addr : {wav_addr[24:1],1'd0}),
                .we(ioctl_download && ioctl_wr && (ioctl_index == 6)),
                .rd(~ioctl_download & wav_want_byte),
                .din(ioctl_dout),
                .dout(wav_data_o),

                .ready(Ready)
        );


always @(posedge clk_mem)
begin
         Ready_L <= Ready;
         // on Ready set keep data
         if(Ready && ~Ready_L) wav_data <= ~wav_data_o;
end

// Link to Samples module

samples samples
(
	.audio_enabled(Audio_Output),
	.audio_port_0(mod == mod_polaris ? {2'd0,SoundCtrl5[3] || SoundCtrl5[4],~SoundCtrl3[3],SoundCtrl3[3:0]} : mod == mod_amazingmaze ? MazeTrigger : mod == mod_lupin ? LupinPort : SoundCtrl3),	
	.audio_port_1(SoundCtrl5),

	.wave_addr(wav_addr),        
	.wave_read(wav_want_byte),   
	.wave_data({wav_data,wav_data}),

	.samples_ok(use_samples),

	.dl_addr(ioctl_addr),
	.dl_wr(ioctl_wr),
	.dl_data(ioctl_dout),
	.dl_download(ioctl_download && (ioctl_index == 5)),
	
	.CLK_SYS(clk_sys),
	.clock(clk_mem),
	.reset(reset_mem),
	
`ifdef DEBUG_MODE
	.Hex1(Line2),
`endif
	
	.audio_in(mod == mod_polaris ? P_Tone_Out : mod == mod_ballbomb ? BB_Tone_Out : (mod == mod_280zap || mod == mod_lagunaracer)? zap_audio_data : Tone_Out),
	.audio_out_L(samples_left),
	.audio_out_R(samples_right)
);


// Music for Amazing Maze

reg [7:0] MazeTrigger;

MAZE_MUSIC MAZE_MUSIC
(
     .I_JOYSTICK({m_up1 || m_up2,m_down1 || m_down2,m_left1 || m_left2,m_right1 || m_right2}),
     .I_COIN(m_coin1),
     .O_TRIGGER(MazeTrigger),
     .CLK(clk_sys)
);

// Sound changes for Lupin 3

reg [7:0] LupinPort;
reg LastStep = 0;
reg LastBit;

always @(posedge clk_sys)
begin
        LastBit <= SoundCtrl3[0];
        // on falling bit, change step
        if(LastBit && ~SoundCtrl3[0]) LastStep <= ~LastStep;           
        // set fake output accordingly
        if (SoundCtrl3[0]) begin
                LupinPort <= {LastStep,~LastStep,SoundCtrl3[5:0]};
        end
        else begin
                LupinPort <= {2'd0,SoundCtrl3[5:0]};
        end;
end

// Tone Generator

reg [15:0] Tone_Out;

ToneGen ToneGen
(
	 .Tone_enabled(Tone_Low[0]),
	 .Tone_Low({Tone_Low[5:1],1'b0}),
	 .Tone_High(Tone_High[5:0]),
	 
	 .Tone_out(Tone_Out),
	 
	.CLK_SYS(clk_sys),
	.reset(reset_sys)
);

// Balloon Bomber tune generator

reg [15:0] BB_Tone_Out;

BALLOON_MUSIC BALLOON_MUSIC
(
    .I_MUSIC_ON(Tone_High != 7'd127),
	 .I_TONE({1'b1,Tone_High[6:0]}),
    .O_AUDIO(BB_Tone_Out),
    .CLK(clk_10)
);

// Polaris tune generator (music or plane position)
reg [15:0] P_Tone_Out;
reg  [7:0] PlanePos;
wire [7:0] PolarTone = SoundCtrl5[1] ? PlanePos : Tone_High;

BALLOON_MUSIC POLARIS_MUSIC
(
    .I_MUSIC_ON(PolarTone != 8'd255),
	 .I_TONE(PolarTone),
    .O_AUDIO(P_Tone_Out),
    .CLK(clk_10)
);

	
// Debug Overlay!

`ifdef DEBUG_MODE

reg [3:0] C_R,C_G,C_B;
reg [159:0] Line1,Line2;

ovo OVERLAY
(
    .i_r(4'd0),
    .i_g(4'd0),
    .i_b(4'd0),
    .i_clk(clk_40),
	 .i_pix(ce_pix),
	 
	 .i_Hcount(HCount),
	 .i_VCount(VCount),

    .o_r(C_R),
    .o_g(C_G),
    .o_b(C_B),
    .ena(status[11]),

    .in0(Line1),
    .in1(Line2)
);

always @(posedge clk_sys)
begin
	Line1[4:0] <= 5'b10000;
	Line1[8:5] <= Tone_High[7:4];
	Line1[13:10] <= Tone_High[3:0];
	Line1[19:15] <= 5'b10000;
	Line1[23:20] <= PlanePos[7:4];
	Line1[29:25] <= PlanePos[3:0];
	Line1[34:30] <= 5'b10000;
end	

`endif

// Clouds for Balloon Bomber

reg BBPixel;

clouds clouds 
(
   .clk(clk_40),
	.pixel_en(ce_pix),
	.v(VCount),
	.h(HCount),
	.flip(DoScreenFlip),
	.pixel(BBPixel)
);

// Cloud for Polaris

reg PolarisPixel;

cloud cloud
(
   .clk(clk_40),
	.pixel_en(ce_pix),
	.v(VCount),
	.h(HCount),
	.flip(DoScreenFlip),
	.pixel(PolarisPixel)
);


// HISCORE SYSTEM
// --------------
wire [15:0]hs_address;
wire [7:0] hs_data_in;
wire [7:0] hs_data_out;
wire hs_write_enable;
wire hs_access_read;
wire hs_access_write;
wire hs_pause;
wire hs_configured;

hiscore #(
	.HS_ADDRESSWIDTH(16),
	.CFG_ADDRESSWIDTH(6),
	.CFG_LENGTHWIDTH(2)
) hi (
	.*,
	.clk(clk_sys),
	.paused(pause_cpu),
	.autosave(status[27]),
	.ram_address(hs_address),
	.data_from_ram(hs_data_out),
	.data_to_ram(hs_data_in),
	.data_from_hps(ioctl_dout),
	.data_to_hps(ioctl_din),
	.ram_write(hs_write_enable),
	.ram_intent_read(hs_access_read),
	.ram_intent_write(hs_access_write),
	.pause_cpu(hs_pause),
	.configured(hs_configured)
);

endmodule
