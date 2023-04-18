# qemu

## 整体框架

```c
main
  qemu_init
    qemu_init_main_loop         // 初始化事件循环
    qemu_create_machine         // 创建虚拟机
      select_machine                // 获取MachineClass，选择是i440fx还是q35
      cpu_exec_init_all
      page_size_init
    configure_accelerator       // 配置硬件辅助虚拟化
      do_configure_accelerator
        accel_init_machine
          kvm_init                  // 通过回调调用kvm_init
  qemu_main_loop                // 主事件循环
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