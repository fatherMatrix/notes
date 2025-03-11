# Page Fault

## page_fault()

## async_page_fault()

子机中的缺页异常处理函数是async_page_fault()而不是普通的page_fault()

### async_page_fault()的来源

```c
start_kernel
  setup_arch
    init_hypervisor_platform
      h = detect_hypervisor_vendor
        p = 在hypervisors数组中遍历                           // 得到的是x86_hyper_kvm
          (*p)->detect()/kvm_detect()                       // 内部根据cpuid确认，猜测qemu应该在这里做了参与
      x86_hyper_type = h->type
      x86_init.hyper.init_platform
```

x86_hyper_kvm具体如下：

```c
const __initconst struct hypervisor_x86 x86_hyper_kvm = { 
        .name                   = "KVM",
        .detect                 = kvm_detect,
        .type                   = X86_HYPER_KVM,
        .init.guest_late_init   = kvm_guest_init,
        .init.x2apic_available  = kvm_para_available,
        .init.init_platform     = kvm_init_platform,
};
```

kvm_guest_init()中，对缺页异常的中断门函数进行了修改：

```c
kvm_guest_init
  x86_init.irqs.trap_init = kvm_apf_trap_init               // 设置用于设置PF中断向量处理函数的函数
```

kvm_apf_trap_init()最终的动作如下：

```c
kvm_apf_trap_init                                           // x86_init.irqs.trap_init = kvm_apf_trap_init
  update_intr_gate(X86_TRAP_PF, async_page_fault)
```

### async_page_fault()的流程

原理：

```c
dotraplinkage void
do_async_page_fault(struct pt_regs *regs, unsigned long error_code, unsigned long address)
{
	enum ctx_state prev_state;

	switch (kvm_read_and_reset_pf_reason()) {
	default:
		/*
		 * 子机页表异常直接在这里处理了
		 */
		do_page_fault(regs, error_code, address);
		break;
	/*
	 * 母机页表异常会导致EPT violation / EPT misconfig，会产生vmexit
	 * - 此时母机上会先于这里对apf做处理，并在vmentry前注入一个缺页异常，
	 *   导致进入guest态后先来到了这里
	 */
	case KVM_PV_REASON_PAGE_NOT_PRESENT:
		/* page is swapped out by the host. */
		prev_state = exception_enter();
		kvm_async_pf_task_wait((u32)address, !user_mode(regs));
		exception_exit(prev_state);
		break;
	case KVM_PV_REASON_PAGE_READY:
		rcu_irq_enter();
		kvm_async_pf_task_wake((u32)address);
		rcu_irq_exit();
		break;
	}
}
NOKPROBE_SYMBOL(do_async_page_fault);
```

vmexit流程：

```c
vcpu_run
  vcpu_enter_guest
    kvm_x86_ops->run()/vmx_vcpu_run
    kvm_x86_ops->handle_exit()/vmx_handle_exit
      kvm_vmx_exit_handlers[exit_reason]()                  // 对缺页异常来说，这里对应的exit_reason是EXIT_REASON_EPT_VIOLATION
```

退出处理函数：

```c
static int (*kvm_vmx_exit_handlers[])(struct kvm_vcpu *vcpu) = {
        ... ...
        [EXIT_REASON_EPT_VIOLATION] = handle_ept_violation,
        [EXIT_REASON_EPT_MISCONFIG] = handle_ept_misconfig,
        ... ...
};
```

violation处理：

```c
handle_ept_violation
  exit_qualification = vmcs_readl(EXIT_QUALIFICATION)
  vcpu->arch.exit_qualification = exit_qualification
  kvm_mmu_page_fault
```

### 参考文献

- https://terenceli.github.io/%E6%8A%80%E6%9C%AF/2019/03/24/kvm-async-page-fault
