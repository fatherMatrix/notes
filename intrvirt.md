# 1. 中断

## 1.1. 中断初始化

```c
start_kernel
  local_irq_disable
  setup_arch
    acpi_boot_init                            // ACPI表相关，包括MADT表
      acpi_process_madt                       // 解析MADT表
        acpi_parse_madt_lapic_entries         // 解析LAPIC
        acpi_parse_madt_ioapic_entries        // 解析IOAPIC
  trap_init                                   // 设置异常处理程序
  init_IRQ                                    // 设置中断处理程序
  late_time_init/x86_late_time_init
    x86_init.irq.intr_mode_init/apic_intr_mode_init
      apic_bsp_setup
        connect_bsp_APIC
        apic_bsp_up_setup
        setup_local_APIC
        enable_IO_APIC
        end_local_APIC_setup
        setup_IO_APIC                         // 重中之重，配置中断重定向表
```

## 1.2. 中断控制器模拟

### 1.2.1. Qemu对中断控制器的模拟

Qemu虚拟机的中断状态由GSIState结构体表示：

```
     +---------+
     |  i8259  |
     +---------+
     | ioapic  |
     +---------+
     | ioapic2 |
     +---------+
       GSIState
```

```c
pc_init1
  gsi_state = pc_gsi_create        // 创建QEMU层面的中断控制器，
                                   // 如果中断控制器是在内核中模拟，那这里会创建一个壳子，
                                   // 对中断控制器的操作由这个壳子调用ioctl转交给kvm处理
  ioapic_init_gsi                  // 初始化QEMU层面的IOAPIC设备
```

### 1.2.2. kvm对中断控制器的模拟

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
     +-----------+                         +-----------+         +-----------+
     |    gsi    |<----------------------->|    gsi    |         |    gsi    |
     +-----------+                         +-----------+         +-----------+
     |   type    |<----------------------->|   type    |         |   type    |
     +-----------+                         +-----------+         +-----------+
     |   flag    |                         |    set    |         |    set    |
     +-----------+                         +-----------+         +-----------+
     |    pad    |                         |  irqchip  |         |  irqchip  |
     +-----------+                         +-----------+         +-----------+
     |     u     |                            kvm_kernel_irq_routing_entry      
     +-----------+                 
 kvm_irq_routing_entry
```

```c
kvm_arch_vm_ioctl(KVM_CREATE_IRQCHIP)
  kvm_pic_init                     // 创建PIC
  kvm_ioapic_init                  // 创建IOAPIC
  kvm_setup_default_irq_routing    // 设置中断路由表
```

## 1.3. 中断触发

### 1.3.1. qemu

### 1.3.2. kvm

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
    pic_update_irq        // 设置kvm_pic.output成员为中断电平
    pic_unlock
      kvm_make_request    // 在对应的vcpu上挂上一个KVM_REQ_EVENT请求
      kvm_vcpu_kick       // 唤醒vcpu，使其尽快接受注入的中断
```

对于IOAPIC芯片，其set函数是：

```c
kvm_set_ioapic_irq
  kvm_ioapic_set_irq
    __kvm_irq_line_status
    ioapic_set_irq
      先进行一些必要的检查
      ioapic_service                       // 进行确实的中断分发
        kvm_irq_delivery_to_apic           // 根据ioapic_service函数格式化出来的kvm_lapic_irq结构寻找LAPIC
          kvm_irq_delivery_to_apic_fast    // 尝试使用预存在kvm中的一个表来查找LAPIC
          kvm_apic_set_irq                 // 已经找到了LAPIC，将中断发送到该LAPIC
            __apic_accept_irq
              if (支持APICv方式)
                deliver_posted_interrupt   // 通过APICv方式注入中断
              else
                apic_set_irr
                kvm_make_request
                kvm_vcpu_kick
```

对于MSI中断，其会绕过IOAPIC，直接由设备将中断信息通过总线发送到LAPIC上：

```c
kvm_set_msi
  kvm_set_msi_irq             // 格式化出一个kvm_lapic_irq
  kvm_irq_delivery_to_apic    // 根据格式化出来的kvm_lapic_irq发送到LAPIC上
                              // 后续的处理见IOAPIC芯片
```

## 1.4. 中断注入

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
| 20 ~ 12 | Reserved                                             |
+---------+------------------------------------------------------+
```

注入过程如下：

```c
vcpu_enter_guest
  inject_pending_event
    kvm_cpu_get_interrupt                        // 获取要注入的中断
      获取PIC或者LAPIC的上pending的中断
    kvm_queue_interrupt                          // 将需要注入的中断向量号写入到vcpu->arch.interrupt中
    kvm_x86_ops->set_irq(vcpu)                   // intel上对应的是vmx_inject_irq
      irq = vcpu->arch.interrupt.nr
      intr = irq | INTR_INFO_xxx | ... 
      vmcs_write32(VM_ENTRY_INFO_FIELD, intr)    // 写入到vmcs中
```

## APICv虚拟化

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
+-------------------------------------+
|                                     |
|                                     |
|                                     |
+-------------------------------------+
```

### 设置virtual-APIC page

### 设置APIC-access page

### 虚拟中断的分发

APICv虚拟中断的前半部分依旧要走IOAPIC -> LAPIC的中断分发过程，只不过在APICv虚拟化场景下，虚拟中断到达LAPIC后，无需使得或等待vcpu退出，即可向vcpu发送中断。

APICv的代码也从LAPIC的kvm_irq_delivery_to_apic函数开始：

``` c
kvm_irq_delivery_to_apic
  kvm_irq_delivery_to_apic_fast
  kvm_apic_set_irq
    __apic_accept_irq
    deliver_posted_interrupt/vmx_deliver_posted_interrupt      // 前面都是一样的，从这里开始不一样。普通的中断分发到这里走set_irr、make request、kick vcpu流程；
      pi_test_and_set_pir                                      // 判断当前是否已经设置了该vector id，如果已经设置了，则直接返回；不会丢中断嘛？
      r = pi_test_and_set_on
      kvm_make_request
      if (r || !kvm_vcpu_trigger_posted_interrupt)
        kvm_vcpu_kick
```
