# 构建状态

![S905D KERNEL CI](https://github.com/SuzukiHonoka/s905d-kernel-precompiled/workflows/S905D%20KERNEL%20CI/badge.svg?branch=master)

# 关于不再构建 mainline 及 stable 内核分支的说明 

- 目前 **LTS** 系列内核运行稳定
- 最新 **LTS** 版本已包含最新的实用特性
- 不需要频繁更新

# 简介

此内核由 **Starx** 通过 [上游源码](https://www.kernel.org/) 使用 GitHub Action 直接进行编译，  
增加了对 **ARM 32bit** 二进制文件的兼容及其他必要特性、功能的支持。  

## 关于已支持 Meson vdec 及 H265 的说明

从 5.15.189 开始，本内核已支持 VP9、H.264/H.265 视频解码，支持桌面环境使用，感谢相关 patch 的贡献者们。

## Linux Kernel 跨版本的安装注意事项

- 由于跨版本内核发行版包含了许多变更，需要 **更换 DTB** 才能正常启动、使用硬件等。  
- 请在安装替换内核镜像前将新的DTB文件覆盖到旧的DTB文件，以确保设备能够正常启动。  
- 目前 N1 已完成 5.9.x - 5.15.x 内核的安装及稳定性测试。

# 内核安装安全性及设备体质情况的注意事项

近期在不同设备上安装内核时遇到了一些未经预料的意外，例如：重启假死，底层 lib 请求被 abort，内核级报错等。  
故在此发布一些注意事项。  

- 请在安装前确认设备的 **MMC 闪存** 正常
- 请在安装前确认 **DTB 路径** 正确
- 请安装时务必 **按照文档** 进行操作
- 请勿 **频繁** 强行关闭/启动电源
- 请确认下载后的压缩文档文件 **未被损坏**
- 请在未测试正常之前不要将 **zImage.old** 及旧版本的内核包删除

# 通过测试的版本

- Linux Kernel 5.15.15 and above

**警告，不建议安装未测试的版本，除非您具备相当的恢复能力。**

# 目标

此内核的对应Target为 **AML-S905d**。  
目前在N1上运行正常且平滑。

# 安装

请在终端执行以下命令:

```
dpkg -i *deb
mv /boot/zImage /boot/zImage.old
cp ./*dtb /boot/dtb/amlogic/
cp ./Image /boot/zImage
sync
reboot
```

请确认 uEnv 中指定的DTB路径为 **/dtb/amlogic/meson-gxl-s905d-phicomm-n1.dtb**

# 恢复

1. 将 armbian 系统 **写入U盘**
2. 启动 **U 盘系统**
3. 挂载 emmc **第一分区**
4. 将 **zImage.old** 改回 **zImage** 
5. 重启

# 声明

感谢 [150balbes](https://github.com/150balbes) 先前提供的仓库以供参考。  
**用户安装此内核而引发的问题均与 Starx 作者无关。  
由于涉及到内核更换，错误的操作可能使你的系统无法启动。  
请务必小心谨慎执行。**

# 分享

本目录下的资源禁止分享至 **恩山论坛**。  
本人极度厌恶其论坛的管理员，私自将本人的账号无理由封禁。  
其他论坛/群组/博客均可，但请务必保留 **Starx** 的 [主页](https://www.starx.ink) 链接。
