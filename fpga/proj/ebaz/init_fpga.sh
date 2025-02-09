#!/bin/sh
cp $1 /lib/firmware/fw.bin
./a.out
echo 0 > /sys/class/fpga_manager/fpga0/flags
echo fw.bin > /sys/class/fpga_manager/fpga0/firmware
