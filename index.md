# 郑三七的学习笔记

之所以有这个博客，一是因为当前各大厂“毕业典礼”盛行，不知道哪天就被裁了；二是因为很多技术点刚学习时懂了，但过不了几天又忘了，总有种熊瞎子掰玉米的感觉。两厢作用，苦不堪言。

生活不易，作者只好未雨绸缪，把学习过的知识点整理下来，一来用作日常工作的参考，二来便于被裁员后可以快速恢复上下文再找下家 :)

## 硬件

操作系统的本质是管理与调度硬件资源，理解硬件的工作方式对理解操作系统大有裨益。待整理

## 软件

### 操作系统及虚拟化

作者主要从事操作系统及虚拟化相关工作，虚拟化技术的三大件分别是`kernel(kvm)`、`qemu`和`libvirt`，在此将对这三大件进行一些简单地分析与记录。由于`kvm`是当前`qemu+kvm`架构的重要组成部分，因此特地将其从`kernel`中抽出，与Qemu一起讨论记录。

[Kernel](software/osvirt/kernel/kernel.md)

[Qemu/KVM](software/osvirt/qemukvm/qemu_kvm.md)

[Libvirt](software/osvirt/libvirt/libvirt.md)

用户态程序大多时候并不是直接使用操作系统的功能，而是通过`glibc`间接地使用操作系统提供的功能。例如，C语言程序中常用的`malloc()/free()`等最基本的内存分配与管理能力，其实是`glibc`对`brk()/sbrk()/mmap()/unmap()`等系统调用的封装。操作系统提供的是后者，而没有提供对应于`malloc()/free()`的系统调用。因此，将`glibc`相关的知识点也安排到此处。

[Glibc](software/osvirt/glibc/glibc.md)

### 编译原理

计算机科学的无上瑰宝，学习中，待整理

### 数据库与分布式系统

作者研究生阶段实验室没有纯操作系统及虚拟化相关的项目，都是数据库与分布式系统相关的项目，本人也算是以数据库的IO优化为引，才正式入了操作系统的坑。而且女朋友是做数据库内核的，帮她记录一下。待整理

### 杂记

[PAM机制](software/misc/pam.md)

[Shadow-utils](software/misc/shadow_utils.md)

[Make构建相关](software/misc/make.md)

[openSSH](software/misc/openssh.md)
