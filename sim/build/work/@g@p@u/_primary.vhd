library verilog;
use verilog.vl_types.all;
entity GPU is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        dv              : in     vl_logic;
        din             : in     vl_logic_vector(31 downto 0);
        ready           : out    vl_logic;
        busy            : out    vl_logic;
        reading         : out    vl_logic;
        cmdOut          : out    vl_logic_vector(15 downto 0);
        video           : out    vl_logic_vector(23 downto 0);
        video_valid     : out    vl_logic;
        video_ready     : in     vl_logic
    );
end GPU;
