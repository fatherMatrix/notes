# 进程管理

## fork

```c
fork
  _do_fork
    copy_process            // 创建新进程
      dup_task_struct
      ... ...
      sched_fork
      ... ...
      copy_mm
        vmacache_flush
        dup_mm
          allocate_mm
          mm_init
            mm_alloc_pgd
              pgd_alloc
                _pgd_alloc
                pgd_ctor    // 拷贝父进程pgd的内核部分
            init_new_context
          dup_mmap
            down_write_killable(parent mm->mmap_sem)
            down_write_nested(child mm->mmap_sem)
              foreach vma in parent

            up_write(child mm->mmap_sem)
            up_write(parent mm->mmap_sem)
      ... ...
    wake_up_new_task        // 唤醒新进程
```
