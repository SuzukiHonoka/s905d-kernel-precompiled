#! /bin/sh
KVER=$1
if [ -z "$KVER" ];then
echo "Using current dir for installing."
else
cd $KVER
fi
dpkg -i *deb
mv /boot/zImage /boot/zImage.old
cp ./*dtb /boot/dtb/amlogic/
cp ./Image /boot/zImage
sync
echo "Installation completed."
echo "You may need to do a reboot for verity now."
#reboot
