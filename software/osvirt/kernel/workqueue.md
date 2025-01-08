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
  wq = kzalloc(sizeof(workqueue_struct) + unbound table size)                 // workqueue_struct尾部是一个关于WQ_UNBOUND的零长数组，WQ_BOUND类型有percpu变量
  alloc_and_link_pwqs
    if !WQ_UNBOUND
      wq->cpu_pwqs = alloc_percpu(pool_workqueue)                             // bound workqueue，分配percpu的pool_workqueue
      init_pwq                                                                // 关联pool_workqueue和percpu的worker_pool
      link_pwq                                                                // 关联pool_workqueue和workqueue_struct
    if WQ_UNBOUND
      apply_workqueue_attrs()                                                 // unbound workqueue，分配pernuma的worker_pool
        apply_workqueue_attrs_locked
          apply_wqattrs_prepare                                               // 分配pernuma的pool_workqueue，并关联合适的worker_pool
          apply_wqattrs_commit                                                // 关联pool_workqueue和workqueue_struct
            ... link_pwq
          apply_wqattrs_cleanup
  init_rescuer(rescuer_thread)                                                // 与workqueue_struct同名的kthread worker，用于处理内存死锁
  list_add_tail_rcu(&wq->list, &workqueues)                                   // 每个workqueue_struct都串联到全局链表workqueues上
```

## rescuer逻辑

rescuer thread的逻辑是：如果我们需要使用工作队列来做包含内存回收的操作，那么该工作队列一定需要有rescuer thread。如果无法创建新的worker来执行这个包含内存释放的work_struct，那么内存释放就无法执行，无法释放内存。

rescuer thread在workqueue创建的时候就创建了，无需再次分配内存。

```c
rescuer_thread
  
```

## worker创建

```c
create_worker
```

## 任务派发

```c
queue_work_on
  __queue_work
    select pool_workqueue
    last_pool = get_work_pool(work_struct)                                    // 优先选取work_struct上次运行的worker_pool，初衷是避免重入
    insert_work
```

## worker_pool动态缩减

```c
idle_worker_timeout
```

## WQ_MEM_RECLAIM死锁避免

```c
pool_mayday_timeout
```



## 参考文献

https://kernel.meizu.com/2016/08/21//linux-workqueue.html/

https://daybreakgx.github.io/2016/09/16/Linux_workqueue_generic/

https://www.cnblogs.com/LoyenWang/p/13185451.html

Documentation/core-api/workqueue.rst
