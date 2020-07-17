#!/bin/sh
insmod 8812au.ko
cp 8812au.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless
depmod
