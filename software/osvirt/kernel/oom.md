# OOM

## out of memory

```c
out_of_memory
  select_bad_process
  oom_kill_process
    __oom_kill_process
      do_send_sig_info
      mark_oom_victim
```

## reaper线程

reaper线程的创建：

```c
subsys_initcall(oom_init)
  kthread_run(oom_reaper)
```

reaper线程的工作：

```c
oom_reaper
  <loop>
    wait_event_freezable(oom_reaper_wait)
    oom_reap_task

oom_reap_task
  oom_reap_task_mm
    down_read_trylock(mm->mmap_sem)
    __oom_reap_task_mm
      foreach vma
        if vma_is_anonymous                    // 内存紧张时，无力承担文件回写的内存开销，因此只做匿名页的回收
          tlb_gather_mmu
          unmap_page_range
          tlb_finish_mmu
    up_read(mm->mmap_sem)
```