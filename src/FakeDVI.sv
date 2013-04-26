//-----------------------------------------------
// FakeDVI stands in place of DVI. Whenever it detects
// that the video frame has changed, it optionally writes
// the frame to disk as a hex file, which can be translated
// into an image.
//-----------------------------------------------

module FakeDVI(
    input        clk,
    input        rst,

    input [23:0] video,
    input        video_valid,
    output reg   video_ready
);
    `include "Display.vh"
    localparam OUTPUT=1; // Whether to write files


    reg frameClk;

    reg [23:0] frame [FRAME_SIZE-1:0];
    reg [19:0] addr;
    wire [23:0] px;
    assign px = frame[addr];

    reg change; // is the new frame different from the old one?

    string file;  // file name
    reg [31:0] i; // frame number


    task Reset;
        begin
            frameClk = 0;
            video_ready = 1;
            addr = 0;
            change = 0;
        end
    endtask

    initial begin
        Reset();
        i = 0;
    end

    always @(posedge clk) begin
        if (rst) Reset();
        else if (video_valid) begin
            if (px != video) change <= 1;
            frame[addr] <= video;

            if (addr == 0 && change) begin
                frameClk <= ~frameClk;
                change <= 0;
                if (OUTPUT) begin
                    $sformat(file, "frame%03.0d.hex",i);
                    $display("Creating %s...", file);   
                    $writememh(file, frame);
                    i <= i+1;
                end
            end

            if (addr < FRAME_SIZE-1)  addr <= addr+1;
            else                      addr <= 0;

        end
    end

endmodule
