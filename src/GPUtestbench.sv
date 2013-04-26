`timescale 1ns/1ps

module GPUtestbench; 
    // Clock
    parameter Cycle = 20;           // 50 MHz
    parameter HalfCycle = Cycle/2;
    reg clk;
    initial clk = 0;
    always #(HalfCycle) clk=~clk;

    // Includes
    `include "GPUcommands.vh"
    `include "Display.vh"

    reg         rst;

    reg [15:0]  cmd;        // -> GPU
    wire[15:0]  cmdOut;     // <- GPU  // testing
    reg [95:0]  colormap;   // -> GPU
    reg [1:0]   color;      // -> GPU
    
    reg [15:0]  x;          // -> GPU
    reg [15:0]  y;          // -> GPU
    reg [15:0]  w;          // -> GPU
    reg [15:0]  h;          // -> GPU

    reg [31:0]  cmdColor;   // = {0,color,cmd}
    reg [31:0]  xy;         // = {y,x}
    reg [31:0]  wh;         // = {h,w}

    wire        ready;      // <- GPU ready
    reg         dv;         // -> GPU data valid
    reg [31:0]  data;       // -> GPU din

    wire [23:0] video;      // -> DVI
    wire        video_valid;// -> DVI
    wire        video_ready;// <- DVI

    always @(*) begin
        cmdColor = {0, color, cmd};
        xy = {y,x};
        wh = {h,w};
    end

    `define NEXT #(Cycle)

    task WaitGPU;
        reg [31:0] wd;     // watchdog timer
        begin
            dv = 0;
            wd = 0;
            $display("Waiting for GPU...");
            while(~ready) begin
                if (wd > 10*FRAME_SIZE) begin
                    $display("FAIL: GPU took too long to finish.");
                    $finish();
                end
                wd = wd+1;
                `NEXT;
            end
            $display("GPU finished.");
        end
    endtask
    
    task WaitScreen;
        reg [31:0] i;
        begin
            dv = 0;
            for (i = 0; i < 2*FRAME_SIZE; i=i+1) begin
                `NEXT;
            end
        end
    endtask

    initial begin 
        $display("Hello! Resetting...");
        rst = 1;
        cmd = 0;
        color = 0;
        dv  = 0;
        `NEXT;
        `NEXT;
        $display("Finished reset.");
        rst = 0;

        
        WaitScreen();
        $display("Finished WaitScreen().");

        // #### Color map test 0 ####
        cmd         = `GPU_Swap;
        `NEXT;

        //colormap    = 96'hffffff_ff0000_000000_00ffff;
        dv          = 1;
        data        = cmdColor;
        `NEXT;

        $display("Sent swap command.");
       
        WaitGPU();

        WaitScreen();
        

        /*

            cmd     <= `GPU_Pixel;
            color   <= 1;
            dv      <= 0;
            x       <= 200;
            y       <= 300;
            `NEXT
            data <= cmdColor;
            dv   <= 1;
            `NEXT
            data <= xy;
            `NEXT
            dv <= 0;
            if (i < `MSEC(2000)) i<=i+1;
            else begin
                `NEXT
            end
        // #### Buffer swap ####
            data <= `GPU_Swap;
            dv <= 1;
            `NEXT
        13: `WAIT_GPU

        // #### Pause ####

        // #### Rect test 1 ####
            cmd     <= `GPU_Rect;
            color   <= 2;
            x       <= 0;
            y       <= 0;
            w       <= 800;
            h       <= 300;

            `NEXT
            dv   <= 1;
            data <= cmdColor;
            `NEXT
            data <= xy;
            `NEXT
            data <= wh;
            `NEXT
            dv <= 0;
            if (i < `MSEC(2000)) i<=i+1;
            else `WAIT_GPU

        // #### Buffer swap ####
            data <= `GPU_Swap;
            dv <= 1;
            `NEXT
        21: `WAIT_GPU
*/
        $display("Bye!");
        $finish();
    end // initial

    GPU GPU (
        .clk(           clk),
        .rst(           rst),
        .dv(            dv),
        .din(           data),
        .ready(         ready),
        .busy(          busy),
        .reading(       reading),
        .cmdOut(        cmdOut),
        .video(         video),
        .video_valid(   video_valid),
        .video_ready(   video_ready)
    );

    FakeDVI DVI (
        .clk(           clk),
        .rst(           rst),
        .video(         video),
        .video_valid(   video_valid),
        .video_ready(   video_ready)
    );
    
endmodule
