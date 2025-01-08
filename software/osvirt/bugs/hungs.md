# Lockups & Hungtask

## Hungtask

### 目标

检测**整个系统中**是否有task_struct长时间未被调度

### 原理

内核启动阶段初始化了一个名为`khungtaskd`的内核线程，该内核线程通过`schedule_timeout_interruptible(timeout)`每隔`timeout`唤醒一次，醒来后遍历系统上所有的进程，检查是否存在处于D状态超过120s(时长可以设置)的进程，如果存在，则打印相关警告和进程堆栈。如果配置了`hung_task_panic`（proc或内核启动参数），则直接发起panic。

```c
hung_task_init
  kthread_run(watchdog, "khungtaskd")

watchdog
  while (1)
    check_hung_uninterruptible_tasks(120)
    schedule_timeout_interruptible(timeout)
```

## Softlockup和Hardlockup

### 目标

- Softlockup：检测**特定cpu上**是否长时间未发生调度

- HardLockup：检测**特定cpu**上是否长时间关中断

### 原理

NMI Watchdog 的触发机制包括两部分：

1. 一个高精度计时器(hrtimer)，对应的中断处理例程是kernel/watchdog.c: watchdog_timer_fn()，在该例程中：
   - 要递增计数器hrtimer_interrupts，这个计数器供hard lockup detector用于判断CPU是否响应中断；
   - 还要唤醒[watchdog/x]内核线程，该线程的任务是更新一个时间戳；
   - soft lock detector检查时间戳，如果超过soft lockup threshold一直未更新，说明[watchdog/x]未得到运行机会，意味着CPU被霸占，也就是发生了soft lockup。
2. 基于PMU的NMI perf event，当PMU的计数器溢出时会触发NMI中断，对应的中断处理例程是 kernel/watchdog.c: watchdog_overflow_callback()，hard lockup detector就在其中，它会检查上述hrtimer的中断次数(hrtimer_interrupts)是否在保持递增，如果停滞则表明hrtimer中断未得到响应，也就是发生了hard lockup。