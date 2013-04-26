module vram (
    input              clk,
    input       [18:0] ra,
    output reg  [31:0] rd,

    input       [18:0] wa,
    input       [31:0] wd,
    input              we);

    `include "Display.vh"

    reg [31:0] ram [VRAM_SIZE-1:0];

    always @(posedge clk) begin
        rd <= ram[ra];

        if (we) ram[wa] <= wd;
    end

endmodule
