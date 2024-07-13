#! /bin/sh
KVER=$1

# change dir if specified
if [ -z "$KVER" ]; then
echo "Using current dir for installing."
else
cd $KVER
fi

# backup ramdisk image
cp /boot/uInitrd /boot/uInitrd.old

# backup zImage
mv /boot/zImage /boot/zImage.old

# install deb packages
dpkg -i *deb

# ensure dtb dir existence
mkdir -p /boot/dtb/amlogic

# move amlogic related dtbs
cp ./*dtb /boot/dtb/amlogic

# move zImage
cp ./Image /boot/zImage

# flush filesystem caches
sync
echo "Installation completed."
echo "You may need to do a reboot for verity now."
#reboot
