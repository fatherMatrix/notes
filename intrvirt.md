# 1. 中断

## 1.1. APIC

```
MP specification defines three different interrupt delivery modes as follows:

 1. PIC Mode
 2. Virtual Wire Mode
 3. Symmetric I/O Mode

They will be setup in the different periods of booting time:
 1. *PIC Mode*, the default interrupt delivery modes, will be set first.
 2. *Virtual Wire Mode* will be setup during ISA IRQ initialization( step 1
    in the figure.1).
 3. *Symmetric I/O Mode*'s setup is related to the system
    3.1 In SMP-capable system, setup during prepares CPUs(step 2) 
    3.2 In UP system, setup during initializes itself(step 3).


 start_kernel
+---------------+
|
+--> .......
|
|    setup_arch
+--> +-------+
|
|    init_IRQ
+-> +--+-----+
|      |        init_ISA_irqs
|      +------> +-+--------+
|                 |         +----------------+
+--->             +------>  | 1.init_bsp_APIC|
|     .......               +----------------+
+--->
|     rest_init
+--->---+-----+
|       |  kernel_init
|       +> ----+-----+
|              |    kernel_init_freeable
|              +->  ----+--------------+
|                       |     smp_prepare_cpus
|                       +---> +----+---------+
|                       |          |   +-------------------+
|                       |          +-> |2.  apic_bsp_setup |
|                       |              +-------------------+
|                       |
v                       |     smp_init
                        +---> +---+----+
                                  |    +-------------------+
                                  +--> |3.  apic_bsp_setup |
                                       +-------------------+
```

## 1.2. 中断初始化

```c
start_kernel
  local_irq_disable
  setup_arch
    parse_early_param
      | early_param(noapic)                   // noapic参数会导致全局变量skip_ioapic_setup=1
    acpi_boot_init                            // ACPI表相关，包括MADT表
      acpi_process_madt                       // 解析MADT表
        acpi_parse_madt_lapic_entries         // 解析LAPIC，结束后我们知道了LAPIC的地址
        acpi_parse_madt_ioapic_entries        // 解析IOAPIC，结束后我们知道了IOAPIC的相关信息，包括IOAPIC的地址以及中断源相关的信息（mp_irqs)
                                              // -- skip_ioapic_setup为1时会跳过
  trap_init                                   // 设置异常处理程序
  init_IRQ                                    // 设置中断处理程序
  local_irq_enable                            // 这里开始就开中断了
  late_time_init/x86_late_time_init
    x86_init.timers.timer_init/hpet_time_init // 会决定时钟事件源用谁：hpet/pit
    x86_init.irq.intr_mode_init/apic_intr_mode_init
      default_setup_apic_routing
        enable_IR_x2apic                      // -- skip_ioapic_setup全局变量为1时直接跳过
      apic_bsp_setup
        connect_bsp_APIC
        apic_bsp_up_setup
        setup_local_APIC
        enable_IO_APIC                        // -- skip_ioapic_setup为1时会跳过，并设置nr_ioapics = 0
        end_local_APIC_setup
        setup_IO_APIC                         // -- skip_ioapic_setup为1或nr_ioapics为0时会跳过
                                              // 配置中断重定向表。根据mp_irqs配置好中断发生时向cpu发送的vector
  arch_call_rest_init
    rest_init                                 // 对x86_64来说，arch_call_rest_init()直接调用rest_init()
      kernel_thread -> kernel_init

kernel_init
  kernel_init_freeable
    smp_prepare_cpus
      smp_ops.smp_prepare_cpus/native_smp_prepare_cpus
        x86_init.timers.setup_percpu_clockdev/setup_boot_APIC_clock
          
          setup_APIC_timer                    // 设置bsp的lapic timer

            

      
```

## 1.3. 中断控制器模拟

### 1.3.1. Qemu对中断控制器的模拟

Qemu虚拟机的中断状态由GSIState结构体表示，整体关系：

```c
===========================================   pic + ioapic   =============================================
+------------+  
|            |  
+------------+  
|     gsi    |----->+------------+                    
+------------+      |   gsi[0]   |                   
|            |      +------------+                   
+------------+      |   gsi[1]   |----->+------------+
PCMachineState      +------------+      | parent_obj |
                    |    ...     |      +------------+
                    +------------+      |   handler  |----->gsi_handler
                    |   gsi[22]  |      +------------+
                    +------------+      |   opaque   |--------->+---------+
                    |   gsi[23]  |      +------------+  +-------|  i8259  |
                    +------------+      |            |  |       +---------+      
                       qemu_irq         +------------+  |   +---| ioapic  |
                                           IRQState     |   |   +---------+
                                                        |   |   | ioapic2 |
                                +----------------+<-----+   |   +---------+
                                | i8259a_irq[0]  |          |     GSIState
                                +----------------+          |
            +------------+<-----| i8259a_irq[1]  |          V
            | parent_obj |      +----------------+          +----------------+
            +------------+      |     ...        |          | ioapic_irq[0]  |
        +---|   handler  |      +----------------+          +----------------+
        |   +------------+      | i8259a_irq[14] |          | ioapic_irq[1]  |----->+------------+
        |   |   opaque   |      +----------------+          +----------------+      | parent_obj |
        |   +------------+      | i8259a_irq[15] |          |      ...       |      +------------+
        |   |            |      +----------------+          +----------------+      |   handler  |---+
        |   +------------+           qemu_irq               | ioapic_irq[22] |      +------------+   |
        |      IRQState                                     +----------------+      |   opaque   |   |
        |                                                   | ioapic_irq[23] |      +------------+   |
        +---> qemu: pic_set_irq -> pic_irq_request          +----------------+      |            |   |
        +---> kvm: kvm_pic_set_irq                                qemu_irq          +------------+   |
        +---> ...                                                                      IRQState      |
                                                                                                     |
                                                                            qemu: ioapic_set_irq <---+
                                                                         kvm: kvm_ioapic_set_irq <---+
                                                                                             ... <---+
===========================================        msi        ============================================
msi_notify
```

```c
pc_init1
  gsi_state = pc_gsi_create        // 创建QEMU层面的中断控制器，
                                   // 如果中断控制器是在内核中模拟，那这里会创建一个壳子，
                                   // 对中断控制器的操作由这个壳子调用ioctl转交给kvm处理
  pc_i8259a_create                 // 创建GSIState.i8259[]，指定了pic的handler
    kvm_i8259_init                    // 如果是kvm模拟
    i8259a_init                       // 如果是qemu模拟
      i8259_init_chip
        isa_realize_and_unref
          qdev_realize_and_unref
            => pic_realize
      qdev_connect_gpio_out
  ioapic_init_gsi                  // 初始化QEMU层面的IOAPIC设备，指定了ioapic的handler
```

### 1.3.2. kvm对中断控制器的模拟

```c
+-------------+
|             |
+-------------+
| irq_routing |-->+---------------+
+-------------+   |  irq_routing  |
|             |   +---------------+
+-------------+   | nr_rt_entries |
      kvm         +---------------+
                  |     map[0]    |
                  +---------------+
                  |      ...      |
                  +---------------+
                  |     map[n]    |----+---------------------+----------------
                  +---------------+    |                     |               
               kvm_irq_routing_table   |                     |               
                                       |   +-----------+     |   +-----------+
                                       +-->|   link    |     +-->|   link    |
       +-----------+                       +-----------+         +-----------+
       |    gsi    |----------copy-------->|    gsi    |         |    gsi    |
       +-----------+                       +-----------+         +-----------+
       |   type    |<---------copy-------->|   type    |         |   type    |
       +-----------+                       +-----------+         +-----------+
       |   flag    |                       |    set    |         |    set    |--+
       +-----------+                       +-----------+         +-----------+  |
       |    pad    |                       |  irqchip  |         |  irqchip  |  |
       +-----------+                       +-----------+         +-----------+  |
       |     u     |                          kvm_kernel_irq_routing_entry      |
       +-----------+                                                            |
    kvm_irq_routing_entry                               pic: kvm_set_pic_irq <--+
== from userspace by ioctl ==                     ioapic: kvm_set_ioapic_irq <--+
                                                            msi: kvm_set_msi <--+
```

```c
kvm_arch_vm_ioctl(KVM_CREATE_IRQCHIP)
  kvm_pic_init                     // 创建PIC
  kvm_ioapic_init                  // 创建IOAPIC
  kvm_setup_default_irq_routing    // 设置中断路由表
```

## 1.4. 中断触发

### 1.4.1. qemu

```c
kvm_vcpu_thread_fn
  kvm_cpu_exec - loop
    kvm_arch_pre_run
    kvm_vcpu_ioctl(KVM_RUN)
    kvm_arch_post_run
  
```

### 1.4.2. kvm

```c
kvm_vm_ioctl(KVM_IRQ_LINE_STATUS, KVM_IRQ_LINE)
  kvm_vm_ioctl_irq_line
    kvm_set_irq
      irq_set[] = kvm_irq_map_gsi        // 从中断路由表中取出对应的中断路由表项
      irq_set[]->set()                   // 调用对应的set函数
```

对于PIC芯片，其set函数是：

```c
kvm_set_pic_irq
  kvm_pic_set_irq
    pic_lock
    __kvm_irq_line_status
    pic_set_irq1
    pic_update_irq                        // 设置kvm_pic.output成员为中断电平
    pic_unlock
      spin_unlock(s->lock)                // 这里就解锁了，要注意pic只会在单核情况下使用
      如果guest处于APIC mode，直接返回
      kvm_make_request                    // 在对应的vcpu上挂上一个KVM_REQ_EVENT请求，
      kvm_vcpu_kick                       // 唤醒vcpu，使其尽快接受注入的中断
```

对于IOAPIC芯片，其set函数是：

```c
kvm_set_ioapic_irq
  kvm_ioapic_set_irq
    spin_lock(ioapic->lock)
    __kvm_irq_line_status
    ioapic_set_irq
      先进行一些必要的检查
      ioapic_service                       // 进行确实的中断分发
        kvm_irq_delivery_to_apic           // 根据ioapic_service函数格式化出来的kvm_lapic_irq结构寻找LAPIC
          如果guest处于pic mode，直接退出
          kvm_irq_delivery_to_apic_fast    // 尝试使用预存在kvm中的一个表来查找LAPIC
          kvm_apic_set_irq                 // 已经找到了LAPIC，将中断发送到该LAPIC
            __apic_accept_irq
              if (支持APICv方式)
                deliver_posted_interrupt   // 通过APICv方式注入中断
              else
                apic_set_irr
                kvm_make_request
                kvm_vcpu_kick
    spin_unlock(ioapic->lock)
```

对于MSI中断，其会绕过IOAPIC，直接由设备将中断信息通过总线发送到LAPIC上：

```c
kvm_set_msi
  kvm_set_msi_irq             // 格式化出一个kvm_lapic_irq
  kvm_irq_delivery_to_apic    // 根据格式化出来的kvm_lapic_irq发送到LAPIC上
                              // 后续的处理见IOAPIC芯片
```

## 1.5. 中断注入

下面这个数据结构与中断注入息息相关：

```c
+-----------------------------------------+
|                                         |
|                                         | 
|                                         | 
+-----------------------------------------+ 
| VM-entry interruption-information field |----------------------+
+-----------------------------------------+                      |
|                                         |                      |
|                                         |                      |
|                                         |                      |
+-----------------------------------------+                      |
                                                                 v
+---------+------------------------------------------------------+
|  0 ~ 7  | Vector of interrupt or exception                     |
+---------+------------------------------------------------------+ 
|  8 ~ 10 | Interruption type:                                   |
|         |  0: External interrupt                               |
|         |  1: Reserved                                         |
|         |  2: Non-maskable interrupt (NMI)                     |
|         |  3: Hardware exception (e.g,. #PF)                   |
|         |  4: Software interrupt (INT n)                       |
|         |  5: Privileged software exception (INT1)             |
|         |  6: Software exception (INT3 or INTO) 7: Other event |
+---------+------------------------------------------------------+
|   11    | Deliver error code                                   |
|         |  0: do not deliver                                   |
|         |  1: deliver                                          |
+---------+------------------------------------------------------+
| 30 ~ 12 | Reserved                                             |
+---------+------------------------------------------------------+
|   31    | Valid                                                |
+---------+------------------------------------------------------+
```

注入过程如下：

```c
kvm_vcpu_ioctl
  kvm_arch_vcpu_ioctl_run
    vcpu_load
    kvm_sigset_activate
    如果kvm_run->immediate_exit非0，返回-EINTR
    vcpu_run - loop
      vcpu_enter_guest
    post_kvm_run_save
      ...
      ready_for_interrupt_injection=xxx               // 用户态在注入中断前应检查这个字段，该字段为0时不可注入中断
    kvm_sigset_deactivate
```

```c
vcpu_enter_guest
  inject_pending_event
    kvm_cpu_get_interrupt                             // 获取要注入的中断
      获取PIC或者LAPIC的上pending的中断
    kvm_queue_interrupt                               // 将需要注入的中断向量号写入到vcpu->arch.interrupt中
    kvm_x86_ops->set_irq(vcpu)                        // intel上对应的是vmx_inject_irq
      irq = vcpu->arch.interrupt.nr
      intr = irq | INTR_INFO_xxx | ... 
      vmcs_write32(VM_ENTRY_INTR_INFO_FIELD, intr)    // 写入到vmcs中的VM_ENTRY_INFO_FILED字段中
  if (开启了APICv)                                     // 这里对应于kvm_vcpu_trigger_posted_interrupt返回错误的情况（UP系统）
    sync_pir_to_irr                                   // 对应vmx_sync_pir_to_irr，同步posted-interrupt desc中的PIR到VIRR
```

## 1.6. APICv虚拟化

下面几个VM-Execution controls域是与APIC虚拟化和虚拟中断相关的：

- `virtual-interrupt delivery`：设置为1则开启虚拟中断的评估与分发
- `user TPR shadow`：设置为1则由cpu模拟通过cr8访问APIC的TPR处理器
- `virtualize APIC access`：设置为1则由cpu模拟通过MMIO访问APIC的行为，当虚拟机访问APIC-access page时，可能会产生VM Exit，也可能访问virtual APIC page
- `virtualize x2APIC access`：MSR寄存器访问APIC相关
- `APIC-register virtualization`：设置为1，虚拟机对APIC-access page的访问会重定向到virtual-APIC page，如果有必要才会陷入VMM
- `process posted interrupts`：系统软件可以向正在运行的vcpu发送中断，vcpu在不产生VM Exit的情况下就能够处理该中断

下面几个数据结构与APICv虚拟化息息相关：

``` c
+-------------------------------------+                 +----------+--------------------------+---------------------------+
|                                     |         +-----> | Reserved | Outstanding Notification | Posted-interrupts request |
|                                     |         |       +----------+--------------------------+---------------------------+
|                                     |         |           256b                  1b                       255b
+-------------------------------------+         |
| posted-interrupt descriptor address |---------+
+-------------------------------------+
|     virtual-APIC page address       |
+-------------------------------------+
|      APIC-access page address       |
+------------------+------------------+
|        Guest interrupt status       |
|       RVI        |       SVI        |
+------------------+------------------+
|                                     |
|                                     |
|                                     |
+-------------------------------------+
```

### 1.6.1. 设置virtual-APIC page

### 1.6.2. 设置APIC-access page

### 1.6.3. 虚拟中断的分发

APICv虚拟中断的前半部分依旧要走IOAPIC -> LAPIC的中断分发过程，只不过在APICv虚拟化场景下，虚拟中断到达LAPIC后，无需使得或等待vcpu退出，即可向vcpu发送中断。

APICv的代码也从LAPIC的kvm_irq_delivery_to_apic函数开始：

``` c
kvm_irq_delivery_to_apic
  kvm_irq_delivery_to_apic_fast
  kvm_apic_set_irq
    __apic_accept_irq
    deliver_posted_interrupt/vmx_deliver_posted_interrupt      // 前面都是一样的，从这里开始不一样。普通的中断分发到这里走set_irr、make request、kick vcpu流程；
      pi_test_and_set_pir                                      // 设置PIR
      pi_test_and_set_on                                       // 设置Outstanding bit
      if (!kvm_vcpu_trigger_posted_interrupt)                  // 发送特定IPI中断：posted-interrupt notification vector
        kvm_vcpu_kick                                          // 如果是UP系统，无法发送IPI中断，会走到这里；后续的中断注入交由vcpu_enter_guest负责
```

### 1.6.4. 中断虚拟化总结

#### 1.6.4.1. 全部在kvm模拟

|        | qemu               | kvm                | interface             |
|--------|--------------------|--------------------|-----------------------|
| pic    | kvm_pic_set_irq    | kvm_set_pic_irq    | ioctl(KVM_IRQ_LINE)   |
| ioapic | kvm_ioapic_set_irq | kvm_set_ioapic_irq | ioctl(KVM_IRQ_LINE)   |
| msi    | msi_notify         | kvm_set_msi        | ioctl(KVM_SIGNAL_MSI) |

#### 1.6.4.2. split模式

|        | qemu            | kvm           | interface             |
|--------|-----------------|---------------|-----------------------|
| pic    | pic_irq_request | vmx_enter_cpu | ioctl(KVM_INTERRUPT)  |
| ioapic | ioapic_set_irq  | kvm_set_msi   | ioctl(KVM_IRQ_LINE)   |
| msi    |                 | kvm_set_msi   | ioctl(KVM_SIGNAL_MSI) |

qemu中的数据结构：

|        | TypeInfo   | Class    | Instance       |
|--------|------------|----------|----------------|
| pic    | i8259_info | PICClass | PICCommonState |

## 1.7. 参考文献

[https://www.binss.me/blog/qemu-note-of-interrupt/](https://www.binss.me/blog/qemu-note-of-interrupt/)