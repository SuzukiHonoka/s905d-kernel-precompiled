#!/bin/sh
insmod 88x2bu.ko
cp 88x2bu.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless
depmod
