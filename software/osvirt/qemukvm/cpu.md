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
vmx_init
  kvm_init(&vmx_x86_ops, sizeof(vcpu_vmx))
    kvm_arch_init                               // 初始化架构相关代码，设置kvm_x86_ops全局变量、检测是否支持vmx特性、分配shared_msrs、初始化mmu_module
    kvm_irqfd_init
    kvm_arch_hardware_setup
      kvm_x86_ops->hardware_setup()             // kvm_x86_ops == &vmx_x86_ops
        setup_vmcs_config(&vmcs_config, ...)    // 根据硬件CPU的特性填充vmcs_config全局变量，后面创建vCPU的时候，以此作为模版
        alloc_kvm_area                          // 这里对每个物理CPU都分配一个VMXON区域，注意这里是并不是VMCS
          for_each_possible_cpu(cpu)
            vmcs = alloc_vmcs_cpu()
            per_cpu(vmxarea, cpu) = vmcs
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
case QEMU_OPTION_enable_kvm:                   // 当命令行加入--enable-kvm时，解析会进入下面的代码
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

## vCPU的创建

### QEMU侧vCPU的创建

QEMU能够模拟多种CPU模型，因此需要一套继承结构来表示CPU对象。

```
                                           +---------------+
                                           |  TYPE_DEVICE  |
                                           +-------+-------+
                                                   |
                                                   |
                                                   |
                                             +-----v-----+
                                             |  TYPE_CPU |
                                             +-----+-----+
                                                   |
                   +-------------------------------+-------------------------------+
                   |                               |                               |
          +--------v-------+              +--------v-------+              +--------v--------+
          |  TYPE_ARM_CPU  |              |  TYPE_X86_CPU  |              |  TYPE_MIPS_CPU  |
          +----------------+              +--------+-------+              +-----------------+
                                                   |
               +-----------------------------------+-----------------------------------+
               |                                   |                                   |
   +-----------v----------+             +----------v----------+            +-----------v----------+
   |  pentium-x86_64-cpu  |             |  qemu64-x86_64-cpu  |            |  Haswell-x86_64-cpu  |
   +----------------------+             +---------------------+            +----------------------+
```

其中，`TYPE_XXX`与`struct TypeInfo`的对应关系如下：

| TYPE_XXX     | struct TypeInfo   | ObjectClassX | ObjectX     |
| ------------ | ----------------- | ------------ | ----------- |
| TYPE_DEVICE  | device_type_info  | DeviceClass  | DeviceState |
| TYPE_CPU     | cpu_type_info     | CPUClass     | CPUState    |
| TYPE_X86_CPU | x86_cpu_type_info | X86CPUClass  | X86CPU      |

### kvm侧vCPU的创建

```
kvm_vm_ioctl_create_vcpu
  kvm_arch_vcpu_create
    kvm_x86_ops->vcpu_create                    // 对应vmx_create_vcpu() 
      vmx = kmem_cache_zalloc
      kvm_vcpu_init(&vmx->vcpu, ...)
        page = alloc_page
        vcpu->run = page_address(page)
        kvm_arch_vcpu_init
          创建mmu
          创建lapic
      alloc_loaded_vmcs(&vmx->vmcs01)           // 分配struct vcpu_vmx -> struct loaded_vmcs . *vmcs所指向的VMCS
      vmx->loaded_vmcs = &vmx->vmcs01
      vmx_vcpu_load
      vmx_vcpu_setup(vmx)                       // 将vCPU的状态初始化为类似于pCPU刚上电时的状态
  preempt_notifier_init
  kvm_arch_vcpu_setup
    vcpu_load
    kvm_vcpu_reset
      ...
      设置virtual-APIC page
      memset(vcpu->arch.regs, 0)                // 普通寄存器都被置为0了
  create_vcpu_fd
  kvm_arch_vcpu_postcreate
```

## vCPU的运行

### QEMU侧vCPU的运行

### kvm侧vCPU的运行

```
kvm_vcpu_ioctl
  kvm_arch_vcpu_ioctl_run
    vcpu_load
      preempt_notifier_register
      kvm_arch_vcpu_load
        ... ...
        kvm_x86_ops->vcpu_load                                          // 对应vmx_vcpu_load()
          vmx_vcpu_load_vmcs
            per_cpu(current_vmcs, cpu) = vmx->loaded_vmcs->vmcs
            vmcs_load(vmx->loaded_vmcs->vmcs)                           // 调用vmptrld指令
          vmx_vcpu_pi_load
    vcpu_run
      kvm_vcpu_running
      vcpu_enter_guest
        kvm_x86_ops->prepare_guest_switch                               // 对应vmx_prepare_switch_to_guest()
        ... ...
        kvm_x86_ops->run                                                // 对应vmx_vcpu_run()
          __vmx_vcpu_run                                                // 汇编开始，会调用vmentry。当返回时，即代表发生了VM_EXIT
        kvm_x86_ops->handle_exit
```
