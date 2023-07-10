# 时间子系统

## 时钟初始化

```c
tick_init
init_timer
hrtimer_init
timekeeping_init
time_init
late_time_init/x86_late_time_init
  intr_mode_select/apic_intr_mode_select        // PIC、virtual wire和symmetric模式中选择一个
  timer_init/hpet_timer_init
    hpet_enable                                 // 或者pit_timer_init; 选出一个作为global_clock_event，hpet优先
      hpet_legacy_clockevent_register
          
    setup_default_timer_irq                     // 将上面选出的全局时钟事件源绑定到0号中断上
  intr_mode_init/apic_intr_mode_init
  tsc_init
```

## 时钟中断

```c
apic_timer_interrupt
  smp_apic_timer_interrupt
    enter_ack_irq
      entering_irq
        irq_enter
          rcu_irq_enter
          tick_irq_enter
          __irq_enter
            preempt_count_add(HARDIRQ_OFFSET)
      ack_APIC_irq
        apic_eoi
    local_apic_timer_interrupt
    existing_irq
      irq_exit
        preempt_count_sub(HARDIRQ_OFFSET)
        invoke_softirq
          __do_softirq
            __local_bh_disable_ip(_RET_IP_, SOFTIRQ_OFFSET)   // 这里会修改preempt_count表示正在执行softirq
            local_irq_enable                                  // 1. 后面执行softirq是开中断的； 2. 这里对应的关中断操作是在中断触发时硬件对IF标志位的自动清除
            exec softirq                                      // 执行softirq时是无法调度的
        tick_irq_exit
        rcu_irq_exit
    set_irq_regs                    // 设置中断处理使用的pt_regs到per cpu的指针变量
```

## 时钟中断与抢占调度

调度有两种方式：

- 主动调度：进程睡眠时主动放弃cpu
- 抢占调度：当一个进程执行时间过长，时间片到期时

### 抢占调度的开启

每次时钟中断发生时，时钟中断处理函数都会调用`scheduler_tick()`，该函数会调用调度算法相关的评估逻辑，当最终判定运行时间足够长（例如时间片到期等）时，会标记此进程应被抢占。

```c
scheduler_tick
  => set_tsk_need_resched
    set_tsk_thread_flag(tsk, TIF_NEED_RESCHED)
```

值得注意的是，此处只是标记该进程应该被抢占，而不是执行真正的调度逻辑。

### 抢占调度的时机

进程抢占调度发生的时机是提前安排好的，只能发生在合适的位置：

#### 用户态的抢占时机(一)

对于用户态的进程，从系统调用返回用户态的时刻，是抢占调度发生的好时机。

```c
exit_to_usermode_loop
  schedule
```

#### 用户态的抢占时机（二）

对于用户态的进程，从外部中断(?内部中断)返回用户态的时刻，是抢占调度发生的好时机。

```c
common_interrupt:
  ... ...                           // trampoline栈 -> 内核栈 -> 中断栈 
  do_IRQ
  ... ...

retint_user
  ... ...
  call    prepare_exit_to_usermode
  ... ...

prepare_exit_to_usermode
  exit_to_usermode_loop
    schedule                        // if (cached_flags & _TIF_NEED_RESCHED)
```

#### 内核态的抢占时机（一）

在内核态的执行中，有的操作是不能被中断的，所以在进行这些操作之前，总是先调用 preempt_disable() 关闭抢占，当再次打开的时候，就是一次内核态代码被抢占的机会。

```c
#ifdef CONFIG_PREEMPTION

#define preempt_enable() \
do { \
        barrier(); \
        if (unlikely(preempt_count_dec_and_test())) \
                __preempt_schedule(); \
} while (0)

#endif
```

#### 内核态的抢占时机（二）

在内核态中也会遇到外部中断(?内部中断)，此时也是个抢占调度的时机。

```c
/* Returning to kernel space */
retint_kernel:
#ifdef CONFIG_PREEMPTION
        /* Interrupts are off */
        /* Check if we need preemption */
        btl     $9, EFLAGS(%rsp)                /* were interrupts off? */
        jnc     1f   
        cmpl    $0, PER_CPU_VAR(__preempt_count)
        jnz     1f   
        call    preempt_schedule_irq            // 内部会调用schedule(true)
1:
#endif
```

## 参考文献

- [https://zhuanlan.zhihu.com/p/544432546](https://zhuanlan.zhihu.com/p/544432546)
