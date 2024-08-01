# kvmtool中断

## kvm

### kvm对中断控制器的模拟

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

### 中断触发

与用户态接驳：

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
      如果guest处于APIC mode，直接返回
      kvm_make_request                    // 在对应的vcpu上挂上一个KVM_REQ_EVENT请求，
      kvm_vcpu_kick                       // 唤醒vcpu，使其尽快接受注入的中断
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
```

对于MSI中断，其会绕过IOAPIC，直接由设备将中断信息通过总线发送到LAPIC上：

```c
kvm_set_msi
  kvm_set_msi_irq             // 格式化出一个kvm_lapic_irq
  kvm_irq_delivery_to_apic    // 根据格式化出来的kvm_lapic_irq发送到LAPIC上
                              // 后续的处理见IOAPIC芯片
```

## kvmtool

对于pic和ioapic，在kvmtool启动的时候，会执行irq__init向kvm注册中断路由表；然后通过KVM_IRQ_LINE触发中断；

```c
irq__init
  ioctl(vm_fd, KVM_SET_GSI_ROUTING)

kvm__irq_line
  ioctl(KVM_IRQ_LINE)
```

对于msi中断，kvmtool的实现并没有通过kvm中的中断路由表，而是通过KVM_SIGNAL_MSI直接向kvm中的LAPIC提交msi中断；

qemu中会判断kvm是否提供了KVM_SIGNAL_MSI能力，如果提供了，则会采用；如果没有提供，则会使用注册msi相应中断路由表项+KVM_IRQ_LINE的方式触发msi中断；

```c
irq__signal_msi
  irq__default_signal_msi
    ioctl(KVM_SIGNAL_MSI, kvm_msi)      // kvm_msi中包含了与中断路由表中的msi项相同的信息，进入kvm后直接调用kvm_set_msi
```

## 我们的工作

现有kvm+(kvmtool/qemu)的IRQCHIP_KERNEL实现：

```c
                  +------------------+                 +------------------+
                  | pin-based device |                 | msi-based device |-----------+
                  +------------------+                 +------------------+           |
                           |                                    |                     |
                 kvm__irq_line[kvmtool]                    [qemu-only]      irq__signal_msi[kvmtool]
                  ioctl(KVM_IRQ_LINE)                  ioctl(KVM_IRQ_LINE)  ioctl(KVM_SIGNAL_MSI)
                           |                                    |                     |
---------------------------|------------------------------------|---------------------|---------------
                           |                                    |                     |
                +----------+------------+                       |                     |
                V                       V                       V                     |
+-----+-----------------+-----+--------------------+-----+-------------+-----+        |
|     |                 |     |                    |     |             |     |        |
| ... | kvm_set_pic_irq | ... | kvm_set_ioapic_irq | ... | kvm_set_msi | ... |    kvm_set_msi
|     |                 |     |                    |     |             |     |        |
+-----+-----------------+-----+--------------------+-----+-------------+-----+        |
                |                       |                       |                     |
                V                       V                       |                     |
           +--------+              +---------+                  |                     |
           | v8259A |              | vIOAPIC |--------+---------+---------------------+
           +--------+              +---------+        |
                |                                     | kvm_irq_delivery_to_apic
                |                                     V
                |                                 +--------+
                |                                 | vLAPIC |
        kvm_make_request                          +--------+
                |                                     |
                |             /########\              |
                |             #        #              |
                |             #  VMCS  #<-------------+
                |             #        #              |
                |             \########/              |
         kvm_kick_vcpu                      posted-interrupt IPI
                |             /++++++++\              |
                |             +        +              |
                +------------>+  VCPU  +<-------------+
                              +        +                          
                              \++++++++/                            
```

由于kvmtool仅有IRQCHIP_KERNEL的实现，我们想要补充IRQCHIP_SPLIT实现：

```c
              +------------------+         +------------------+
              | pin-based device |         | msi-based device |------------+
              +------------------+         +------------------+            |
                       |                             |                     |
                 kvm__irq_line                       |                     |
                       |                             |                     |
             +---------+-----------+                 |                     |
             V                     V                 |                     | 
        +--------+            +---------+            |                     |
        | v8259A |            | vIOAPIC |            |                     |
        +--------+            +---------+            |                     |
             |                     |                 |                     |
             |                     +-----------------+                     |
             |                                       |                     |
   1. ioctl(KVM_INTERRUPT)                  ioctl(KVM_IRQ_LINE)     ioctl(KVM_SIGNAL_MSI)
2. kick vcpu(method undetermined)                    |                     |
             |                                       |                     |
-------------|---------------------------------------|---------------------|----------------------
             |                                       |                     |
             |                   +-------------------+                     |
             |                   |                   |
             |                   V                   V                     |
             |            +-------------+-----+-------------+-----+        |
             |            |             |     |             |     |        |
             |            | kvm_set_msi | ... | kvm_set_msi | ... |    kvm_set_msi
             |            |             |     |             |     |        |
             V            +-------------+-----+-------------+-----+        |
    1. kvm_make_request          |                   |                     |
             |                   +-------------------+---------------------+
             |                                       |
             |                                       | kvm_irq_delivery_to_apic
             |                                       V
             |                                 +--------+
             |                                 | vLAPIC |
             |                                 +--------+
             |                                     |
             |             /########\              |
             |             #        #              |
             |             #  VMCS  #<-------------+             
             |             #        #              |
             |             \########/              |
   2. kick vcpu thread                   posted-interrupt IPI
             |             /++++++++\              |
             |             +        +              |
             +------------>+  VCPU  +<-------------+
                           +        +                          
                           \++++++++/                         
```
