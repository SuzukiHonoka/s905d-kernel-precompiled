#! /bin/sh
KVER=$1
mkdir $KVER
cp ~/*$KVER* ./$KVER -v
cp ~/Amlogic_s905-kernel/arch/arm64/boot/Image ./$KVER -v
