# Linux Audit System

Linux Audit用于对操作系统的执行过程进行审计。由如下组件构成：

- `kauditd`内核模块：负责拦截系统调用并记录相关事件，并形成报告发送给`audit`守护进程。

- `auditd`守护进程：负责将从`kauditd`接收到的审计报告进行一些处理并写入持久化设备。

- 各种tools：负责显示、查询和存档审计数据。

## 内核部分分析

初始化过程的调用栈：

```
start_kernel
  arch_call_rest_init
    rest_init
      kernel_thread(kernel_init, ...)    // 使用内核线程执行kernel_init函数

kernel_init_freeable                     // 在kernel_init函数中调用
  do_basic_setup
    do_initcalls
      使用audit_init作为参数进行初始化过程   // postcore_initcall(audit_init)将aduit_init()注册到了特殊的section中，以便此时调用               
```

审计过程：

- 提供了标准接口`audit_log`进行主动审计

- 对于系统调用，在`do_syscall_64()`中预先埋了点进行处理
