# EPT

## 初始化

```c
kvm_create_vm
  kvm->mm = current->mm
  kvm_alloc_memslots                                    // 分配memslots，这里只是分配slot，内部插什么内存条还是要用kvm_vm_ioctl(KVM_SET_USER_MEMORY_REGION)配置
    slots->id_to_index[i] = slots->memslots[i].id = i   // 初始化slot id到index的映射
  kvm_arch_init_vm
    kvm_mmu_init_vm

kvm_vm_ioctl_create_vcpu
  kvm_arch_vcpu_create
    kvm_x86_ops->vcpu_create/vmx_create_vcpu
      vmx->vpid = allocate_vpid()
      kvm_vcpu_init
        kvm_arch_vcpu_init
          kvm_mmu_create
  kvm_arch_vcpu_setup
    kvm_init_mmu
      init_kvm_tdp_mmu                                  // 或者init_kvm_nested_mmu()、init_kvm_softmmu()
        context->page_fault = tdp_page_fault
        context->direct_map = true
        context->set_cr3 = kvm_x86_ops->set_tdp_cr3     // vmx_set_cr3()
        context->get_cr3 = get_cr3
```

## kvm_memslots配置

```c
kvm_vm_ioctl(KVM_SET_USER_MEMORY_REGION)
  kvm_vm_ioctl_set_memory_region
    kvm_set_memory_region
      __kvm_set_memory_region
        as_id = mem->slot >> 16                                 // 获取address space id
        slot_id = (u16)mem->slot                                // 获取slot id
        kvm_memslots = __kvm_memslots(kvm, as_id)               // 获取address space id对应的kvm_memslots
        kvm_memory_slot = id_to_memslot(kvm_memslots, slot_id)  // 获取slot id对应的kvm_memory_slot
```

## 进入Guest

```c
vcpu_enter_guest
  kvm_mmu_reload
    kvm_mmu_load                                                // 如果kvm_mmu->root_hpa == INVALID_PAGE，说明还没有EPT页表根，则执行kvm_mmu_load()
      mmu_alloc_roots
        kvm_alloc_direct_roots
          kvm_mmu_get_page
            kvm_mmu_alloc_page
          vcpu->arch.mmu->root_hpa = __pa(kvm_mmu_page->spt)    // 设置EPT页表根节点
      kvm_mmu_sync_roots
      kvm_mmu_load_cr3
        vcpu->arch.mmu->set_cr3()/vmx_set_cr3()                 // cr3入参是EPT根的HPA
          eptp = construct_eptp(vcpu, cr3)
          vmcs_write64(EPT_POINTER, eptp)
          guest_cr3 = kvm_read_cr3()                            // cr3本来就是guest自己设置的，与kvm无关啊
          vmcs_writel(GUEST_CR3, guest_cr3)
```

## 退出Guest

```c
handle_ept_violation
  exit_qualification = vmcs_readl(EXIT_QUALIFICATION)
  vcpu->arch.exit_qualification = exit_qualification
  kvm_mmu_page_fault
    tdp_page_fault
```