#! /bin/sh
KVER=$1
if [ -z "$KVER" ];then
echo "Usage: ./install.sh KVER"
exit
else
cd $KVER
dpkg -i *deb
mv /boot/zImage /boot/zImage.old
cp ./Image /boot/zImage
echo "Installation completed."
echo "You may need to do a reboot for verity now."
fi
#reboot
