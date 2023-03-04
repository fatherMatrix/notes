# 中断

## 中断初始化

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
        setup_IO_APIC
    
```

## 中断控制器模拟

### Qemu对PIC的模拟

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

### kvm对PIC的模拟

```ag-0-1gq8ahdjnag-1-1gq8ahdjnag-0-1gq8ahdjnag-1-1gq8ahdjnc

```

## 中断触发

### qemu

### kvm

```c
kvm_vm_ioctl(KVM_IRQ_LINE_STATUS, KVM_IRQ_LINE)
  kvm_vm_ioctl_irq_line
    kvm_set_irq
      irq_set[] = kvm_irq_map_gsi        // 从中断路由表中取出对应的中断路由表项
      irq_set[]->set()                   // 调用对应的set函数
```

对于PIC芯片，其set函数是：

```c
kvm_pic_set_irq
  pic_lock
  __kvm_irq_line_status
  pic_set_irq1
  pic_update_irq        // 设置kvm_pic.output成员为中断电平
  pic_unlock
    kvm_make_request    // 在对应的vcpu上挂上一个KVM_REQ_EVENT请求
    kvm_vcpu_kick       // 唤醒vcpu，使其尽快接受注入的中断
```

## 中断注入

```c
vcpu_enter_guest
  inject_pending_event
    kvm_queue_interrupt            // 将需要注入的中断向量号写入到vcpu->arch.interrupt中
    kvm_x86_ops->set_irq(vcpu)     // intel上对应的是vmx_inject_irq
      irq = vcpu->arch.interrupt.nr
      intr = irq | INTR_INFO_xxx | ... 
      vmcs_write32(VM_ENTRY_INFO_FIELD, intr)    // 写入到vmcs中
```
