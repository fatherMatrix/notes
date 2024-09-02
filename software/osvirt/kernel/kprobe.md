# kprobe

## kprobe注册

用0xcc或者jmp指令替换被探测指令，此处省略reenter。

```
register_kprobe
  kprobe_addr                           // 通过symbol获取addr
    _kprobe_addr                        // 如果symbol和addr都指定了，返回错误；否则如果仅指定了addr，则返回addr；如果仅指定了symbol，则查找
      kprobe_lookup_name
        kallsyms_lookup_name
          kallsyms_expand_symbol        // 1. 从内核的kallsyms中查找，如果查到了，返回
          module_kallsyms_lookup_name   // 2. 从模块的kallsyms中查找
  check_kprobe_rereg                    // 检测本kprobe是否已经注册
  check_kprobe_address_safe             // 检查探测地址
  prepare_kprobe                         
    arch_prepare_kprobe
      get_insn_slot                    
      arch_copy_kprobe                  // 函数内部会对类似ip相对寻址的指令进行修改（因为拷贝后ip已经变了）
  arm_kprobe                            // 将0xcc或者jmp指令写入被探测指令所在的位置，以帮助完成截获     
    arch_arm_kprobe
      text_poke
  try_to_optimize_kprobe                // 进行一些优化（jmp）
```

## Trap

以未优化的kprobe（0xcc）为例，被探测指令已经被替换为0xcc，当cpu执行到这条指令时会触发int3异常，进入do_int3。此时kprobe子系统首先执行pre_handler，然后修改regs中的内容，使得do_int3异常处理返回后，以单步调试的方式执行被保存的被探测指令。

```
do_int3
  ...
  kprobe_int3_handler
    addr = regs->ip - sizeof(kprobe_opcode_t)    // 计算0xcc所在位置，以此得到kprobe结构体
    kcb = get_kprobe_ctlblk()
    p = get_kprobe(addr)
    cur->pre_handler()                          // 调用pre_handler
    setup_singlestep                            // 配置regs中的内容，使得do_int3退出后可以单步执行被探测指令
      regs->flags |= X86_EFLAGS_TF              // 设置调试位
      regs->flags &= ~X86_EFLAGS_IF             // 清除中断屏蔽位
      res->ip = p->ainsn.insn                   // 设置返回后的ip，regs中的内容会被异常恢复机制恢复到CPU上下文中
  ...
```

## Debug

由于do_int3中设置了TF位，当被保存的被探测指令执行结束后，触发debug异常，进入do_debug。kprobe子系统在这里重新获得控制权，并执行post_handler。

```
do_debug
  ...
  kprobe_debug_handler
    resume_execution                            // 将debug异常返回后执行的下一条指令设置为被探测指令之后的指令
    regs->flags = kcb->kprobe_saved_flags
    cur->post_handler()                         // 调用post_handler
  ...
```

## kprobe stacktrace trace_options

kprobe打点时，可以使用echo stacktrace >> trace_options来使其显示对应堆栈。

但5.4内核中，打点函数的调用者的栈不显示。

```
----------------------------------- kprobe -------------------------------

     barad_agent-2896882 [001] .... 963476.030174: start_this_handle: (start_this_handle+0x0/0x480)
     barad_agent-2896882 [001] .... 963476.030175: <stack trace>
 => start_this_handle
                                          => 这里缺少了jbd2__journal_start
 => __ext4_journal_start_sb
 => ext4_da_write_begin
 => generic_perform_write
 => __generic_file_write_iter
 => ext4_file_write_iter
 => new_sync_write
 => __vfs_write
 => vfs_write
 => ksys_write
 => __x64_sys_write
 => do_syscall_64
 => entry_SYSCALL_64_after_hwframe
     barad_agent-9479    [001] .... 963476.309002: jbd2__journal_start: (jbd2__journal_start+0x0/0x1e0)
     barad_agent-9479    [001] .... 963476.309006: <stack trace>
 => jbd2__journal_start
                                          => 这里缺少了__ext4_journal_start_sb
 => ext4_dirty_inode
 => __mark_inode_dirty
 => generic_update_time
 => file_update_time
 => __generic_file_write_iter
 => ext4_file_write_iter
 => new_sync_write
 => __vfs_write
 => vfs_write
 => ksys_write
 => __x64_sys_write
 => do_syscall_64
 => entry_SYSCALL_64_after_hwframe

-------------------------------------- ret kprobe ------------------------------

         sap1002-7937    [004] d... 964000.125591: r_start_this_handle: (jbd2__journal_start+0xdb/0x1e0 <- start_this_handle)
         sap1002-7937    [004] d... 964000.125595: <stack trace>
 => [unknown/kretprobe'd]
 => [unknown/kretprobe'd]
 => ext4_dirty_inode
 => __mark_inode_dirty
 => generic_update_time
 => file_update_time
 => __generic_file_write_iter
 => ext4_file_write_iter
 => new_sync_write
 => __vfs_write
 => vfs_write
 => ksys_write
 => __ia32_sys_write
 => do_int80_syscall_32
 => entry_INT80_compat
         sap1002-7937    [004] d... 964000.125597: r_jbd2__journal_start: (__ext4_journal_start_sb+0x6a/0x120 <- jbd2__journal_start)
         sap1002-7937    [004] d... 964000.125597: <stack trace>
 => [unknown/kretprobe'd]
 => ext4_dirty_inode
 => __mark_inode_dirty
 => generic_update_time
 => file_update_time
 => __generic_file_write_iter
 => ext4_file_write_iter
 => new_sync_write
 => __vfs_write
 => vfs_write
 => ksys_write
 => __ia32_sys_write
 => do_int80_syscall_32
 => entry_INT80_compat
```

## Kprobe Jump优化

在进行优化探针之前，Kprobes 会做以下安全检查：

- Kprobes 校验会被 jump 指令替换的区域（”已优化的区域“）完全处于一个函数内部。（jump 指令是多字节指令，因此可能会覆盖多个指令）

- Kprobes 分析整个函数，并且确认不会跳入已优化的区域。特别是：
  
  - 该函数不包含间接跳转
  - 该函数不包含引起异常的指令（因为被异常触发的固定代码可能会跳回到已优化的区域 — Kprobes 会检查异常表来验证这一点）
  - 该函数附近没有跳转到已优化的区域（除了第一个字节）

- 对于已优化区域中的每一个指令，Kprobes 会验证它们能否离线执行。

[译｜2019｜Kernel Probes (Kprobes) – Blog](https://jayce.github.io/public/posts/trace/kernel-kprobes/)

[Linux kprobe原理-CSDN博客](https://blog.csdn.net/weixin_45030965/article/details/125793813)

## 参考文献

1. [https://zhuanlan.zhihu.com/p/455694175](https://zhuanlan.zhihu.com/p/455694175)
