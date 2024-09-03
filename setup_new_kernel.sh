#!/bin/bash

# Configurable vars
BUILD_DIR="./build"
KVERV="5.9.1"

# Override by args if present
if [ ! -z "$1" ]; then
  KVERV=$1
fi

if [ ! -z "$2" ]; then
  BUILD_DIR=$2
fi

# Kernel archives info
KVER="linux-$KVERV"
FILE_NAME="$KVER.tar.xz"
KURL="https://cdn.kernel.org/pub/linux/kernel/v${KVERV:0:1}.x"
KDURL="$KURL/$FILE_NAME"

# Create the build dir if not present and enter
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# Download kernel archive
wget "$KDURL"

# Uncompress
tar -xf "$FILE_NAME" && rm "$FILE_NAME"

# Enter archive dir
cd "$KVER"
