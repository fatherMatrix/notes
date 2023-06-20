# 各种hungs

## hung tasks warning

内核启动阶段初始化了一个名为`khungtaskd`的内核线程，该内核线程通过schedule_timeout_interrupt(timeout)每隔timeout唤醒一次，醒来后遍历系统上所有的进程，检查是否存在处于D状态超过120s(时长可以设置)的进程，如果存在，则打印相关警告和进程堆栈。如果配置了hung_task_panic（proc或内核启动参数），则直接发起panic。

```c
hung_task_init
  kthread_run(watchdog, "khungtaskd")

watchdog
  while (1)
    check_hung_uninterruptible_tasks(120)
    schedule_timeout_interruptible(timeout)
```

## soft lockup



## hard lockup