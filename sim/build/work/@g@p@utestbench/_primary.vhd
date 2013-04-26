library verilog;
use verilog.vl_types.all;
entity GPUtestbench is
    generic(
        Cycle           : integer := 20;
        HalfCycle       : vl_notype
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of Cycle : constant is 1;
    attribute mti_svvh_generic_type of HalfCycle : constant is 3;
end GPUtestbench;
