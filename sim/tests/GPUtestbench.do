set MODULE GPUtestbench
start $MODULE
add wave $MODULE/*
add wave $MODULE/GPU/*
add wave $MODULE/DVI/*
run 100000ms
