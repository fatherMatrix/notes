# 工作队列

## 工作队列初始化

工作队列初始化分为两个阶段：

- workqueue_init_early
- workqueue_init

```c
start_kernel
  workqueue_init_early                              // 第一阶段，建立workerqueue基础设施
    for_each_cpu_worker_pool(pool, cpu)             // 对bound类型的worker_pool进行初始化，unbound类型的在alloc_workqueue() -> alloc_and_link_pwqs()中
      init_worker_pool(pool)
    alloc_workqueue                                 // 分配常规workqueue
  rest_init
    kernel_init
      kernel_init_freeable
        workqueue_init                              // 第二阶段，为所有worker_pool创建worker
          for_each_cpu_worker_pool(pool, cpu)       // 针对bound类型worker_pool
            create_worker
          hash_for_each(unbound_pool_hash)          // 针对unbound类型worker_pool
            create_worker
```

## workqueue_struct创建

```c
alloc_workqueue
  wq = kzalloc(sizeof(workqueue_struct) + unbound table size)                 // workqueue_struct尾部是一个关于WQ_UNBOUND的零长数组
  alloc_and_link_pwqs
  init_rescuer                                                                // 与workqueue_struct同名的kthread worker，用于处理内存死锁
  list_add_tail_rcu(&wq->list, &workqueues)                                   // 每个workqueue_struct都串联到全局链表workqueues上
```

## worker创建

```c
create_worker
```
