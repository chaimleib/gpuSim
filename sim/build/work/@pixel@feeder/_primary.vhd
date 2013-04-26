library verilog;
use verilog.vl_types.all;
entity PixelFeeder is
    port(
        cpu_clk_g       : in     vl_logic;
        clk50_g         : in     vl_logic;
        rst             : in     vl_logic;
        vram_valid      : in     vl_logic;
        vram_ready      : out    vl_logic;
        vram_dout       : in     vl_logic_vector(31 downto 0);
        color_map       : in     vl_logic_vector(95 downto 0);
        video           : out    vl_logic_vector(23 downto 0);
        video_valid     : out    vl_logic;
        video_ready     : in     vl_logic
    );
end PixelFeeder;
