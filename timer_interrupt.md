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
    local_apic_timer_interrupt
    existing_irq
    set_irq_regs                    // 设置中断处理使用的pt_regs到per cpu的指针变量
```

## 参考文献

- [https://zhuanlan.zhihu.com/p/544432546](https://zhuanlan.zhihu.com/p/544432546)
