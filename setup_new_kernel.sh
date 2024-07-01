#!/bin/bash
ROOT_DIR="/tmp/ramfs"
BUILD_DIR="$ROOT_DIR/build"
KVERV="5.9.1"

if [ ! -z "$1" ]; then
KVERV=$1
fi

KVER="linux-$KVERV"
KURL="https://cdn.kernel.org/pub/linux/kernel/v${KVERV:0:1}.x"
KDURL="$KURL/$KVER.tar.xz"

if [ ! -d "$ROOT_DIR" ];then
mkdir -p $ROOT_DIR
fi

sudo mount -t tmpfs -o size=6G tmpfs $ROOT_DIR
mkdir $BUILD_DIR && cd $BUILD_DIR

wget $KDURL
tar -xf "$KVER.tar.xz" && rm *xz
cd "$BUILD_DIR/$KVER"