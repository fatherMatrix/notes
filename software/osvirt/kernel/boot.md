# Boot

## Linux Boot Protocal

```
              ~                        ~
              |                        | 
 1000000+offs |  Compressed kernel     |      Compressed kernel relocated here          # 5. 压缩内核搬到了这里，跳到这里来运行解压程序。
              |                        |
              |                        |
 1000000(16M) +------------------------+      Uncompressed kernel relocated here        # 6. arch/x86/kernel/head_64.S:startup_64; 进入到这里时，cpu处于64位模式，开启了页表，页表中是1:1的4GB映射
              |                        |
              ~                        ~
              |                        |
              +------------------------+
              |                        |
              ~                        ~                                                # 4. jump here <- startup_64(arch/x86/boot/compressed/head_64.S)
              |  Protected-mode kernel |                                                # 3. kernel setup jump here <- 0x100000(startup_32, arch/x86/boot/compressed/head_64.S)
  100000(1M)  +------------------------+
              |  I/O memory hole       |                                                # 0. power on <- 0xffff0
      0A0000  +------------------------+
              |  Reserved for BIOS     |      Leave as much as possible unused     
              ~                        ~
              |  Command line          |      (Can also be below the X+10000 mark)
      X+10000 +------------------------+
              |  Stack/heap            |      For use by the kernel real-mode code.
      X+08000 +------------------------+
              |  Kernel setup          |      The kernel real-mode code.                # 2. boot loader jump here <- X + 0x200 (start_of_setup, arch/x86/boot/header.S)
              |  Kernel boot sector    |      The kernel legacy boot sector.            # 未使用，直接跳过
      X       +------------------------+
              |  Boot loader           |      <- Boot sector entry point 0000:7C00      # 1. BIOS jump here <- 0x7c00
      001000  +------------------------+
              |  Reserved for MBR/BIOS |
      000800  +------------------------+
              |  Typically used by MBR |
      000600  +------------------------+
              |  BIOS use only         |
      000000  +------------------------+
```

```
bootloader
  _start                        // arch/x86/boot/header.S
  start_of_setup    
    设置段寄存器为0x1000
    设置call main使用的堆栈环境
    比较signature
    将BSS段清空为0
    calll main                  // arch/x86/boot/main.c 进入C语言环境，不返回。 
```

## 参考文献

- [https://zhuanlan.zhihu.com/p/55596339](https://zhuanlan.zhihu.com/p/55596339)

- [https://zhuanlan.zhihu.com/p/466591309](https://zhuanlan.zhihu.com/p/466591309)

- [http://home.ustc.edu.cn/~boj/courses/linux_kernel/1_boot.html](http://home.ustc.edu.cn/~boj/courses/linux_kernel/1_boot.html)
