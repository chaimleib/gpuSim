proc start {m} {vsim -L unisims_ver -L unimacro_ver -L xilinxcorelib_ver -L secureip work.glbl $m}
set MODULE GPUtestbench
start $MODULE
add wave $MODULE/*
add wave $MODULE/GPU/*
add wave $MODULE/DVI/*
run 100000ms
