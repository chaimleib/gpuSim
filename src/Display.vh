localparam WIDTH        = 800;
localparam HEIGHT       = 600;
localparam DEPTH        = 2;   // bits per pixel
localparam WORD_SIZE    = 32;


localparam PX_PER_WORD  = WORD_SIZE/DEPTH;
localparam FRAME_SIZE   = WIDTH*HEIGHT;
localparam VRAM_SIZE    = FRAME_SIZE/PX_PER_WORD;

