# 构建状态
![S905D KERNEL CI](https://github.com/SuzukiHonoka/s905d-kernel-precompiled/workflows/S905D%20KERNEL%20CI/badge.svg?branch=master)

# 简介
此内核由Starx通过[REPO](https://github.com/150balbes/Amlogic_s905-kernel)直接进行编译，  
增加了对ARM 32bit 二进制文件的兼容。  
除此之外无任何额外改动。

# 目标
此内核的对应Target为S9xxx。  
目前在N1上运行正常且平滑。  

# 安装
请在终端执行以下命令:
```
dpkg -i *deb
mv /boot/zImage /boot/zImage.old
cp ./Image /boot/zImage
reboot
```
# 声明
感谢[150balbes](https://github.com/150balbes)提供的repo以进行编译。  
用户安装此内核而引发的问题均与Starx及原REPO作者无关。  
由于涉及到内核更换，错误的操作可能使你的系统无法启动。  
请务必小心谨慎执行。  
由于系统不一样，这里暂时不提供一键脚本。  

# 转载
本目录下的资源禁止分享至`恩山论坛`。  
本人极度讨厌其论坛的管理员。
私自将本人的账号无理由封禁。  
其他论坛/群组/博客均可，但请务必保留Starx及原作者的REPO链接。
