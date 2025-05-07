#!/bin/sh
echo "Starting aarch64 toolchain setup"
stage_dir="/opt/toolchain"
tool_verision="arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu"
tool_file="$tool_verision.tar.xz"
tool_url="https://github.com/SuzukiHonoka/s905d-kernel-precompiled/releases/download/toolchain/$tool_file"
echo "toolchain ${tool_verision} will be installed to ${stage_dir}"
mkdir -p $stage_dir && cd $stage_dir
wget $tool_url
echo "Decompressing"
tar -xf $tool_file --strip-components=1 -C $stage_dir && rm *xz
export PATH=$PATH:"$stage_dir/aarch64-none-linux-gnu/bin"
echo "Done"
