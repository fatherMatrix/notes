# qemu

## 整体框架

kvm加速器架构：

| TYPE_XXX       | TypeInfo       | Object     | ObjectClass |
| -------------- | -------------- | ---------- | ----------- |
| TYPE_ACCEL     | accel_type     | AccelState | AccelClass  |
| TYPE_KVM_ACCEL | kvm_accel_type | KVMState   | -           |

加速cpu架构：

| TYPE_XXX              | TypeInfo                | Object     | ObjectClass    |
| --------------------- | ----------------------- | ---------- | -------------- |
| TYPE_ACCEL_CPU        | accel_cpu_type          | -          | AccelCPUClass  |
| ACCEL_CPU_NAME("kvm") | kvm_cpu_accel_type_info | -          | -              |

qemu主线程：

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
    configure_accelerators                                      // 配置硬件辅助虚拟化
      do_configure_accelerator
        accel = ACCEL(object_new_with_class(OBJECT_CLASS(ac)))  // 分配AccelState的派生对象
        accel_init_machine(accel, current_machine)
          current_machine->accelerator = accel                  // 配置好当前machine使用的accel
          AccelClass->init_machine => kvm_init                  // 通过回调调用kvm_init
    qmp_x_exit_preconfig
      qemu_init_board                                                 // 创建主板
        machine_run_board_init
          accel_init_interfaces
            accel_init_ops_interfaces
              AccelOpsClass = object_new_xxx                          // 分配AccelOpsClass
                => AccelOpsClass->class_init / kvm_accel_ops_class_init
            accel_init_cpu_interfaces
              => accel_init_cpu_int_aux                               // 1. 调用关系比较绕； 2. 对kvm来说只有下面的赋值；
                CPUClass->accel_cpu = AccelCPUClass
                AccelCPUClass->cpu_class_init                         // tcg有操作，kvm是空的
                CPUClass->init_accel_cpu                              // tcg有操作，kvm是空的                    
          machine_class->init => pc_init1                             // 这是个极其巨大的回调函数，参见DEFINE_I440FX_MACHINE()
            x86_cpus_init                                             // 初始化cpu
              x86_cpu_new
                object_new(cpu_type)                                  // 实例化object
                qdev_realize                                          // 具现化object
                  object_property_set_bool("realized", true)
                    => device_set_realized                            // 在device_class_init中设置realized属性对应的回调函数
                      DeviceClass->realize() => x86_cpu_realizefn     // 参见x86_cpu_type_info->class_init
            pc_guest_info_init
            pc_memory_init
            pc_gsi_create                           // 创建qemu_irq，分配GSIState,但未初始化；x86MachineState::gsi指向这里
            i440fx_init
            piix3_create
            isa_bus_irqs
            pc_i8259_create                         // 创建8259芯片
            ...
  qemu_main_loop                                    // 主事件循环
    os_host_main_loop_wait
      glib_pollfds_fill                             // prepare 和 query
        g_main_context_prepare
        g_main_context_query
      qemu_mutex_lock_iothread
      qemu_poll_ns                                  // poll
      qemu_mutex_unlock_iothread
      glib_pollfds_poll                             // check 和 dispatch
  qemu_cleanup
```

vcpu线程：

```c
x86_cpu_realizefn
  cpu_exec_realizefn
    cpu_list_add                                                      // 将CPUState添加到cpus全局链表上
    accel_cpu_realizefn
      CPUClass->accel_cpu->cpu_realizefn / kvm_cpu_realizefn          // accel_cpu字段本身在accel_init_interfaces中赋值；cpu_realizefn字段在kvm_cpu_accel_class_init中设置
  qemu_init_vcpu
    cpus_accel->create_vcpu_thread/kvm_start_vcpu_thread              // 在kvm_accel_ops_class_init中设置
      qemu_create_thread(kvm_vcpu_thread_fn)

kvm_vcpu_thread_fn
  kvm_cpu_exec
```

iothread线程：

```c
```

## 参考文献

- https://martins3.github.io/qemu/init.html