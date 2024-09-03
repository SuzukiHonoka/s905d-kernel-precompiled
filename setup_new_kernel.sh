#!/bin/bash
ROOT_DIR="/tmp/ramfs"
BUILD_DIR="$ROOT_DIR/build"
KVERV="5.9.1"

if [ ! -z "$1" ]; then
KVERV=$1
fi

KVER="linux-$KVERV"
FILE_NAME="$KVER.tar.xz"
KURL="https://cdn.kernel.org/pub/linux/kernel/v${KVERV:0:1}.x"
KDURL="$KURL/$FILE_NAME"

mkdir -p $ROOT_DIR && sudo mount -t tmpfs -o size=10G tmpfs $ROOT_DIR
mkdir -p $BUILD_DIR && cd $BUILD_DIR

wget $KDURL
tar -xf $FILE_NAME && rm $FILE_NAME
cd "$BUILD_DIR/$KVER"
