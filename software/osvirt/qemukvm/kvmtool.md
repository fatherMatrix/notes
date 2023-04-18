# kvmtool

## 整体路径

```c
main
  handle_kvm_command
    handle_command
      p = kvm_get_command       // 返回一个cmd_struct的指针p
      p->fn()                   // 执行对应命令
```

虚拟机执行的主要流程：

```c
kvm_cmd_run
  kvm = kvm_cmd_run_init            // 初始化一个kvm对象
    kvm = kvm__new                      // 分配对象内存
    parse_options                       // 解析参数
    kvm_run_validate_cfg                // 验证配置
    init_list__init                     // 重中之重，调用各种初始化回调，逐步建立虚拟机！init_list中的元素是在constructor中添加的；
  kvm_cmd_run_work                  // 开始虚拟机运行
    pthread_create(kvm_cpu_thread)      // 创建vcpu线程
    pthread_join(vcpu0)                 // 等待0号vcpu（bsp）退出（关机时只有bsp vcpu会主动退出）
  kvm_cmd_run_exit                  // 退出清理工作
    init_list__exit                     // 对应init_list__init
```

初始化函数的优先级及其对应的典型实例如下：

```c
#define core_init(cb) __init_list_add(cb, 0)            // kvm__init
#define base_init(cb) __init_list_add(cb, 2)            // ioeventfd__init, **kvm_cpu__init**, kvm_ipc__init
#define dev_base_init(cb)  __init_list_add(cb, 4)       // disk_image__init, pci__init, vfio__init, ioport__setup_arch, irq__init
#define dev_init(cb) __init_list_add(cb, 5)             // cfi_flash__init, kbd__init, rtc__init, serial8250__init, term_init, [kvm_gtk_init, sdl__init, vnc__init]
#define virtio_dev_init(cb) __init_list_add(cb, 6)      // virtio_9p__init, virtio_bln__init, virtio_blk__init, virtio_console__init, virtio_net__init, virtio_rng__init, virtio_scsi_init, virtio_vsock_init
#define firmware_init(cb) __init_list_add(cb, 7)        // fb__init, mptable__init
#define late_init(cb) __init_list_add(cb, 9)            // symbol_init, thread_pool__init

#define core_exit(cb) __exit_list_add(cb, 0)
#define base_exit(cb) __exit_list_add(cb, 2)
#define dev_base_exit(cb) __exit_list_add(cb, 4)
#define dev_exit(cb) __exit_list_add(cb, 5)
#define virtio_dev_exit(cb) __exit_list_add(cb, 6)
#define firmware_exit(cb) __exit_list_add(cb, 7)
#define late_exit(cb) __exit_list_add(cb, 9)
```

## 初始化流程

### kvm__init

```c
kvm__init
  kvm->sys_fd = open(/dev/kvm)
  kvm->vm_fd = ioctl(sys_fd, KVM_CREATE_VM)             // 创建虚拟机
  kvm__arch_init                                        // 架构相关的初始化
    ioctl(vm_fd, KVM_SET_TSS_ADDR)                          // 设置TSS寄存器
    ioctl(vm_fd, KVM_CREATE_PIT2)                           // 创建kvm中的定时器
    分配内存条内存
    ioctl(vm_fd, KVM_CREATE_IRQCHIP)                        // 创建kvm中的pic和ioapic
  kvm__init_ram                                         // 内存初始化
    mmap                                                    // kvmtool进程分配HVA
    kvm__register_ram
      ioctl(vm_fd, KVM_SET_USER_MEMORY_REGION)              // 注册给kvm
  kvm__arch_setup_firmware                              // 加载默认或用户指定的固件
```

### kvm_cpu__init

```c
kvm_cpu__init
  task_eventfd = eventfd()
  kvm_cpu__arch_init
    ioctl(vm_fd, KVM_CREATE_VCPU)                           // 创建vcpu
    vcpu->kvm_run = mmap(vcpu->vcpu_fd)                     // 映射vcpu各自的kvm_run区域，用于获取exit_resons等诸多运行时信息
    kvm_cpu__set_lint                                   // 配置LAPIC LINT !!!
      ioctl(vcpu->vcpu_fd, KVM_GET_LAPIC, &lapic)
      lapic.lvt_lint0.delivery_mode = APIC_MODE_EXTINT
      lapic.lvt_lint1.delivery_mode = APIC_MODE_NMI
      ioctl(vcpu->vcpu_fd, KVM_SET_LAPIC, &lapic)
```

### irq__init

```c
irq__init
  ioctl(vm_fd, KVM_SET_GSI_ROUTING)
```

## 运行流程

### kvm_cpu_thread

```c
kvm_cpu_thread
  kvm__set_thread_name          // 设置线程名
  kvm_cpu__start                // 这是一个巨大的“陷入-模拟-陷入”循环
    kvm_cpu__arch_nmi
    kvm_cpu__run_task
    kvm_cpu__run
      ioctl(vcpu_fd, KVM_RUN)
    退出处理    
```