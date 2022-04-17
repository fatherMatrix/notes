# CPU虚拟化

CPU虚拟化的实现方案：

- 纯软件模拟：一条指令一条指令地解析，然后模拟执行，此时虚拟机中的一个寄存器对应一个软件中的变量。如Bochs和Qemu(不开启KVM等）

- 二进制翻译：虚拟化用户态的程序直接在CPU上执行，但是一些特权指令会通过**二进制翻译**去执行。二进制翻译即将程序中的敏感指令静态或动态地翻译为可被VMM捕获或模拟的指令。如早期的VMware方案

- 特权级压缩：该方案需要修改操作系统的代码，将虚拟机内核运行在`ring 1`，VMM运行在`ring 0`，并且对虚拟机中操作系统内核的敏感指令进行替换从而使其陷入到`ring 0`的VMM内核。如Xen

- 硬件辅助虚拟化：Intel的`VT-x`技术。

其中二进制翻译、特权级压缩和硬件辅助虚拟化都依赖于对敏感指令的发现与及时处理。CPU的指令可以按照如下方式进行分类

- 按照所运行的处理器级别可以分为：

  - 特权指令：运行在`ring 0`的指令，如操作系统代码

  - 非特权指令：运行在`ring 3`的指令，如应用程序代码

- 按照是否会对整个系统产生影响来划分，可以分为：

  - 敏感指令：指令会影响整个系统，如读写时钟、读写中断寄存器等

  - 非敏感指令：指令仅影响自身所在的进程

## VT-x

```
                +---------------------------------+               +---------------------------------+    
                |             Guest 0             |               |             Guest 1             |    
                +---+-------------------------^---+               +---+-------------------------^---+    
                    |                         |                       |                         |        
                 VM_EXIT                      |                    VM_EXIT                      |        
                    |                         |                       |                         |        
                  +-.-------------------------.-+                   +-.-------------------------.-+      
                  | .          VMCS 0         . |                   | .          VMCS 1         . |      
                  +-.-----^---------^---------.-+                   +-.-----^---------^---------.-+      
                    |     |         |         |                       |     |         |         |        
                    |  VM_READ   VM_WRITE  VM_ENTRY                   |  VM_READ   VM_WRITE  VM_ENTRY    
                    |     |         |         |                       |     |         |         | 
            +-------v-----v---------v---------+-----------------------v-----v---------v---------+-------+
VMXON ----> |                                  Virtual Machine Monitor                                  | ----> VMXOFF
            +-------------------------------------------------------------------------------------------+                  
```

## kvm内核模块启动过程

```
kvm_init
  kvm_arch_init
  kvm_irqfd_init
  kvm_arch_hardware_setup
  kvm_arch_check_processor_compat
  register_xxx_notifier
  kvm_async_pf_init
  misc_register
```

## 虚拟机的创建

### QEMU侧虚拟机的创建

当在QEMU命令行加入`--enable-kvm`时，会解析进入下面的`case`分支。主要工作是给`machine optslist`这个参数项添加了一个`accel=kvm`参数。

```
// vl.c
            case QEMU_OPTION_enable_kvm:
                /* 当命令行加入--enable-kvm时，解析会进入下面的代码 */
                olist = qemu_find_opts("machine");
                qemu_opts_parse_noisily(olist, "accel=kvm", false);
                break;
```

之后，`main`函数的调用链为：

```
main
  --enable-kvm对应的case分支
  configure_accelerator
    accel_init_machine
      accel = ACCEL(object_new(cname))
      acc->init_machine(ms)                  // 对应QEMU代码中的kvm_init，注意与kvm内核模块中的kvm_init进行区分
        qemu_open("/dev/kvm", O_RDWR)
        kvm_check_extension
        kvm_ioctl(s, KVM_CREATE_VM, type)
        kvm_arch_init
```

### kvm侧虚拟机的创建

```
kvm_dev_ioctl
  kvm_dev_ioctl_create_vm
    kvm_create_vm
    kvm_coalesced_mmio_init
    anon_inode_getfd
```
