vlib work
vlog -f ../rtl/rtl.f
vlog *.*v
vsim -vopt work.tb -voptargs="+acc=npr"
do wave.do
run -all