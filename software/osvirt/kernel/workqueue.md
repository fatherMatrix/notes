# 工作队列

## 工作队列初始化

工作队列初始化分为两个阶段：

- workqueue_init_early
- workqueue_init

```c
start_kernel
  workqueue_init_early              // 第一阶段
  rest_init
    kernel_init
      kernel_init_freeable
        workqueue_init              // 第二阶段
```
