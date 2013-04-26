module GPU(
    input clk,
    input rst,

    input        dv,
    input [31:0] din,
    output ready,

    // debug
    output busy,
    output reading,
    output [15:0] cmdOut,

    // DVI
    output [23:0] video,
    output        video_valid,
    input         video_ready
    );

    `include "Display.vh"
    
    // FSM state
    localparam Idle = 0; 
    localparam ReadInputs = 1;
    localparam Busy = 2;
    reg [1:0] state;
    
    // commands
    `include "GPUcommands.vh"
    localparam Swap             = `GPU_Swap;            // Swap video buffers
    localparam ChangeColorMap   = `GPU_ChangeColorMap;  // Change color values
    localparam Pixel            = `GPU_Pixel;           // Set the color of a pixel
    localparam Rect             = `GPU_Rect;            // Fill a rectangle
    reg [15:0] cmd;
    

    reg [DEPTH-1:0] color; // a command color, eg. fill color

    // #### Video buffers - low-level iface ####
    reg  [95:0] color_map;
    
    wire [18:0] ra0;
    wire [31:0] rd0;
    wire [18:0] wa0;
    wire [31:0] wd0;
    wire        we0;

    wire [18:0] ra1;
    reg [31:0] rd1;
    wire [18:0] wa1;
    wire [31:0] wd1;
    wire        we1;

    vram vbuf0(
        .clk(clk),
        .ra(ra0),
        .rd(rd0),
        .wa(wa0),
        .wd(wd0),
        .we(we0)
    );
    /*
    vram vbuf1(
        .clk(clk),
        .ra(ra1),
        .rd(rd1),
        .wa(wa1),
        .wd(wd1),
        .we(we1)
    );
    */
    reg [31:0] vbuf1 [VRAM_SIZE-1:0];
    always @(posedge clk) begin
        if (we1) vbuf1[wa1] <= wd1;
        rd1 <= vbuf1[ra1];
    end
    initial vbuf1[0] = 32'hffff_5555;
    

    // #### Video buffers - high-level iface ####
    reg         vramSel; // which buffer is the work; other one is displayed
   
    // PixelFeeder - This goes directly to the DVI module
    localparam A_MAX = WIDTH*HEIGHT/(32/DEPTH) - 1; // Maximum VRAM addr
    wire pf_ready;
    reg  [18:0] pfa; // VRAM address
    wire [31:0] pfd; // VRAM data
    PixelFeeder pf(
        .cpu_clk_g(clk),
        .clk50_g(clk),
        .rst(rst),
        .vram_valid(~rst),
        .vram_ready(pf_ready),
        .vram_dout(pfd),
        .color_map(color_map),
        .video(video),             // -> DVI
        .video_valid(video_valid), // -> DVI
        .video_ready(video_ready)  // <- DVI
    );

    // These will point the working buffer, while the other buffer is displayed
    reg  [18:0] ra;
    wire [31:0] rd;
    reg  [18:0] wa;
    reg  [31:0] wd;
    reg         we;

    // Video buffers - connections b/w high and low level
    assign ra0 = (vramSel == 0) ? ra:pfa;
    assign ra1 = (vramSel == 1) ? ra:pfa;
    assign rd  = (vramSel == 0) ? rd0:rd1;
    assign pfd = (vramSel != 0) ? rd0:rd1;
    assign wa0 = wa;
    assign wa1 = wa;
    assign wd0 = wd;
    assign wd1 = wd;
    assign we0 = (vramSel == 0) & we; 
    assign we1 = (vramSel == 1) & we;


    initial begin
        color_map = 96'hffffff_00ffff_ff0000_ffbbbb;
        vramSel = 0;
    end


    reg [18:0] i;
    reg [9:0] x[1:0];
    reg [9:0] y[1:0];
    reg [9:0] w;
    reg [9:0] h;


    // #### Helper variables ####
    // (x[0],y[0]) is the first pixel in the row
    // (x[1],y[1]) is the current pixel
    reg [5:0] xStride;         // how many pixels to skip ahead, along the x-axis
    reg       rowDone;         // whether to skip to the next row

    wire [18:0] xy[1:0];       // word addr of (x[0],y[0]) and (x[1],y[1])
    wire [18:0] xyMax;         // word addr of end of w-sized row, starting @(x[0],y[0])
    wire [4:0] xyb[1:0];       // bit addr  of (x[0],y[0]) and (x[1],y[1])
    wire [4:0] xybMax;         // bit addr  of end of w-sized row, starting @(x[0],y[0])

    reg [31:0] modPxData;      // word for plotting a pixel
    reg [31:0] modRectData;   // word for filling a rect


    `define WADDR(X,Y) (((X)+(Y)*WIDTH)>>(5-DEPTH+1)) // word addr of (x,y)
    `define BADDR(X)   (DEPTH*((X)%(32/DEPTH)))   // bit addr of (x,y) within word
    assign xy[0] =  `WADDR(x[0],y[0]); 
    assign xy[1] =  `WADDR(x[1],y[1]);
    assign xyMax =  `WADDR(x[0]+w-1,y[0]);         // end of current row
    assign xyb[0] = `BADDR(x[0]);
    assign xyb[1] = `BADDR(x[1]);
    assign xybMax = `BADDR(x[0]+w-1);         // end of current row

    // XST vomits if a 2-d vector is in a sensitivity list, so we have to
    // add every member of the 2-d vector to the list manually.
    // This issue is fixed for Virtex-6 and Spartan-6, but I'm on Virtex-5.
    // *sigh*
    always @(
        xy[0], xyb[0], 
        xy[1], xyb[1],
        xybMax, xyMax,
        color, rd
    ) begin
        xStride = (32-xyb[1])/DEPTH;  // try to jump to word boundary
        rowDone = 1;

        // #### Pixel ####
        `define MODPX_BIT(B) \
            if (xyb[0] == (B)) modPxData[(B)+1:(B)] = color;
        modPxData = rd;                     // get the old word
        `MODPX_BIT(0)
        `MODPX_BIT(2)
        `MODPX_BIT(4)
        `MODPX_BIT(6)
        `MODPX_BIT(8)
        `MODPX_BIT(10)
        `MODPX_BIT(12)
        `MODPX_BIT(14)
        `MODPX_BIT(16)
        `MODPX_BIT(18)
        `MODPX_BIT(20)
        `MODPX_BIT(22)
        `MODPX_BIT(24)
        `MODPX_BIT(26)
        `MODPX_BIT(28)
        `MODPX_BIT(30)

        // #### Rect fill ####

        /* Had to remove this elegant code; verilog doesn't allow
         * replication by a variable, only by a constant.
         * Retained to explain what is happening in the code following
         * this comment.

        modBlockData = rd;
        if (xy[0] == xyMax) begin               // first word == last word
            modBlockData[xybMax+1:xyb[0]] = {w{color}};
        end
        else if (xy[1] == xyMax) begin          // row end
            modBlockData[xybMax+1:0] = {(xybMax/2){color}};
        end
        else begin                              // row start or middle
            modBlockData[31:xyb[1]] = {xStride{color}};
            rowDone = 0;
        end
        //*/
        if (x[1] >= WIDTH) rowDone = 1;
        modRectData = rd;
        if (xy[0] == xyMax) begin               // row begins and ends in same word
            `define MODRECT_BIT(B) \
                if (xyb[0] <= (B) && (B) <= xybMax) modRectData[(B)+1:(B)] = color;
            `MODRECT_BIT(0)
            `MODRECT_BIT(2)
            `MODRECT_BIT(4)
            `MODRECT_BIT(6)
            `MODRECT_BIT(8)
            `MODRECT_BIT(10)
            `MODRECT_BIT(12)
            `MODRECT_BIT(14)
            `MODRECT_BIT(16)
            `MODRECT_BIT(18)
            `MODRECT_BIT(20)
            `MODRECT_BIT(22)
            `MODRECT_BIT(24)
            `MODRECT_BIT(26)
            `MODRECT_BIT(28)
            `MODRECT_BIT(30)
        end
        else if (xy[1] == xyMax) begin          // row end
            `undef MODRECT_BIT
            `define MODRECT_BIT(B) \
                if ((B) <= xybMax) modRectData[(B)+1:(B)] = color;
            `MODRECT_BIT(0)
            `MODRECT_BIT(2)
            `MODRECT_BIT(4)
            `MODRECT_BIT(6)
            `MODRECT_BIT(8)
            `MODRECT_BIT(10)
            `MODRECT_BIT(12)
            `MODRECT_BIT(14)
            `MODRECT_BIT(16)
            `MODRECT_BIT(18)
            `MODRECT_BIT(20)
            `MODRECT_BIT(22)
            `MODRECT_BIT(24)
            `MODRECT_BIT(26)
            `MODRECT_BIT(28)
            `MODRECT_BIT(30)
        end
        else begin                              // row start or middle
            `undef MODRECT_BIT
            `define MODRECT_BIT(B) \
                if ((B) >= xyb[1]) modRectData[(B)+1:(B)] = color;
            `MODRECT_BIT(0)
            `MODRECT_BIT(2)
            `MODRECT_BIT(4)
            `MODRECT_BIT(6)
            `MODRECT_BIT(8)
            `MODRECT_BIT(10)
            `MODRECT_BIT(12)
            `MODRECT_BIT(14)
            `MODRECT_BIT(16)
            `MODRECT_BIT(18)
            `MODRECT_BIT(20)
            `MODRECT_BIT(22)
            `MODRECT_BIT(24)
            `MODRECT_BIT(26)
            `MODRECT_BIT(28)
            `MODRECT_BIT(30)
            rowDone = 0;
        end
    end // always @(*)
//*/
    assign ready =      (state == Idle);
    assign reading =    (state == ReadInputs);
    assign busy  =      (vramSel);
    assign cmdOut =     cmd;

    always @(posedge clk) begin
        if (rst) state <= Idle;
        else begin
            if (pf_ready) begin                     // Keep PixelFeeder happy
                if (pfa < A_MAX) pfa <= pfa + 1;
                else             pfa <= 0;
            end

            case (state)                            // FSM
            Idle: begin
                ra   <= 0;
                wa   <= 0;
                wd   <= 0;
                we   <= 0;
                i    <= 0;
                x[0] <= 0;
                y[0] <= 0;
                x[1] <= 0;
                y[1] <= 0;
                w    <= 0;
                h    <= 0;
                cmd  <= 0;
                color<= 0;

                if (dv) begin
                    state <= ReadInputs;
                    cmd   <= din[15:0];
                    color <= din[16+DEPTH-1:16];
                end
            end // Idle

            ReadInputs: 
                /*if (dv)*/ case (cmd)
                    Swap: begin
                        if (pfa == A_MAX) begin
                            vramSel <= ~vramSel;
                            state <= Idle;
                        end
                    end // Swap

                    ChangeColorMap: begin
                        i <= i+1;
                        if (i == 3) state <= Idle;
                        
                        case (i)
                            0: color_map[23:0]  <= din[23:0];
                            1: color_map[47:24] <= din[23:0];
                            2: color_map[71:48] <= din[23:0];
                            3: color_map[95:72] <= din[23:0];
                            default: state <= Idle;
                        endcase
                    end // ChangeColorMap

                    Pixel: begin 
                        x[0] <= din[9:0];
                        y[0] <= din[25:16];

                        // validate x and y
                        if ((din[9:0] >= WIDTH) || 
                            (din[25:16] >= HEIGHT)) state <= Idle;
                        else begin
                            ra <= `WADDR(din[9:0],din[25:16]);
                            wa <= `WADDR(din[9:0],din[25:16]);

                            state <= Busy;
                        end
                    end // Pixel

                    Rect: 
                        case (i)
                            0: begin
                                x[0] <= din[9:0];
                                y[0] <= din[25:16];
                                i <= i+1;
                            end // 0
                            1: begin
                                w <= din[9:0];  
                                h <= din[25:16];

                                x[1] <= x[0];
                                y[1] <= y[0];
                                
                                i <= i+1;

                                // validate x and y
                                if ((x[0] >= WIDTH) || 
                                    (y[0] >= HEIGHT)) state <= Idle;
                                else state <= Busy;
                            end // 1
                            default: state <= Busy;
                        endcase // (i) // Rect
//*/
                    default: state <= Idle;
                endcase // (cmd) // ReadInputs

            Busy: 
                case (cmd)
 ///*
                    Pixel: begin
                        wd <= modPxData;
                        we <= 1;
                        state <= Idle;
                    end
                   
                    Rect: begin
                        if (h == 0) state <= Idle;
                        else begin
                            wd <= modRectData;
                            we <= 1;
                            ra <= xy[1];
                            wa <= xy[1];
                            if (rowDone) begin
                                h <= h-1;
                                y[0] <= y[0]+1;
                                y[1] <= y[0]+1;
                                x[1] <= x[0];
                            end
                            else x[1] <= x[1] + xStride;
                        end
                    end // Rect
//*/
                    default: state <= Idle;
                endcase // (cmd) // Busy

            default: state <= Idle;
            endcase // (state)
        end // (!rst)
    end // always @(posedge clk)

endmodule

