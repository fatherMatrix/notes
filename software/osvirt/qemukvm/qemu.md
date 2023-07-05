# qemu

## 整体框架

```c
main
  qemu_init
    qemu_init_main_loop                             // 初始化事件循环
    qemu_create_machine                             // 创建虚拟机
      select_machine                                // 获取MachineClass，选择是i440fx还是q35
      cpu_exec_init_all
        io_mem_init                                 // 创建io_mem_unassigned
        memory_map_init                             // 创建address_space_memory和address_space_io
      page_size_init
    configure_accelerator                           // 配置硬件辅助虚拟化
      do_configure_accelerator
        accel_init_machine
          kvm_init                                  // 通过回调调用kvm_init
    qmp_x_exit_preconfig
      qemu_init_board                                                 // 创建主板
        machine_run_board_init
          => machine_class->init => pc_init1                          // 这是个极其巨大的回调函数，参见DEFINE_I440FX_MACHINE()
            x86_cpus_init                                             // 初始化cpu
              x86_cpu_new
                object_new(cpu_type)                                  // 实例化object
                qdev_realize                                          // 具现化object
                  object_property_set_bool("realized", true)
                    => device_set_realized
                      => x86_cpu_realizefn                            // 参见x86_cpu_type_info->class_init
            pc_guest_info_init
            pc_memory_init
            pc_gsi_create                           // 创建qemu_irq，分配GSIState,但未初始化；x86MachineState::gsi指向这里
            i440fx_init
            piix3_create
            isa_bus_irqs
            pc_i8259_create                         // 创建8259芯片
            ...
  qemu_main_loop                                    // 主事件循环
  qemu_cleanup
```

```c
x86_cpu_realizefn
  qemu_init_vcpu
    cpus_accel->create_vcpu_thread/kvm_start_vcpu_thread
      qemu_create_thread(kvm_vcpu_thread_fn)

kvm_vcpu_thread_fn
  kvm_cpu_exec
```

## 参考文献

- https://martins3.github.io/qemu/init.html