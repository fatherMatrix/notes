# task_group与组调度

# 调度时机

未开启内核抢占时，有如下调度点：

- 调用cond_resched()时
- 调用schedule()时
- 从系统调用返回用户态时
- 从中断上下文返回用户态时

开启了内核抢占时，增加如下调度点：

- preempt_enable()时

# select

```c
task_numa_fault
  numa_migrate_preferred
    task_numa_migrate
      migrate_swap
        migrate_swap_stop
          __migrate_swap_task
            deactivate_task

detach_one_task
  detach_task

load_balance
  detach_tasks
    detach_task
      deactivate_task
      set_task_cpu
```

# 参考文献

1. [https://www.cnblogs.com/LoyenWang/p/12459000.html](https://www.cnblogs.com/LoyenWang/p/12459000.html)
2. https://arthurchiao.art/blog/linux-cfs-design-and-implementation-zh/
3. 
