# 进程管理

## fork

v5.4：

```c
fork
  _do_fork
    copy_process                                               // 创建新进程
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
                pgd_ctor                                       // 拷贝父进程pgd的内核部分
            init_new_context
          dup_mmap
            down_write_killable(parent mm->mmap_sem)
            down_write_nested(child mm->mmap_sem)
              foreach vma in parent
                vma_start_write                                // v6.6中新增了vma lock
                copy_page_range                                // 拷贝页表
            up_write(child mm->mmap_sem)
            up_write(parent mm->mmap_sem)                      // v6.6中使用mmap_write_unlock()，其中包含了 vma_end_write_all()
      ... ...
    wake_up_new_task                                           // 唤醒新进程
```

v6.6中主要新增了vma lock：

```c
dup_mmap
  mmap_write_lock_killable(oldmm)                              // 锁定src_mm
  mmap_write_lock_nested(mm)                                   // 锁定dst_mm
  for_each_vma(oldmm)
    vma_start_write(old_vma)
    copy_page_range()
  mmap_write_unlock(mm)
  mmap_write_unlock(oldmm)
    vma_end_write_all
```
