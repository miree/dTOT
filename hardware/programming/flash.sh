#!/bin/bash
cp ../gateware/syn/tdc_top.bin .
truncate -s 512k tdc_top.bin
flashrom -V -p ft2232_spi:type=232H,port=A -c SST25VF040B -w tdc_top.bin
rm tdc_top.bin
