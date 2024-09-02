# Qemu内存初始化

```c
main
  qemu_create_machine
    cpu_exec_init_all
      io_mem_init
        memory_region_init_io
      memory_map_init
        memory_region_init(system_memory)
        address_space_init(address_space_memory, system_memory)
        memory_region_init(system_io)
        address_space_init(address_space_io, system_io)
```

# Qemu MMIO处理

```c
kvm_cpu_exec
  case KVM_EXIT_IO:
    kvm_handle_io
      address_space_rw(address_space_io)
  case KVM_EXIT_MMIO:
    address_space_rw(address_space_memory)
```
