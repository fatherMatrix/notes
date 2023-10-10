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
  
```