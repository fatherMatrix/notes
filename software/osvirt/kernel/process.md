# 进程管理

## fork

```c
fork
  _do_fork
    copy_process            // 创建新进程
    wake_up_new_task        // 唤醒新进程
```