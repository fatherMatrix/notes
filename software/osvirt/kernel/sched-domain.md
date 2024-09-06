# 调度域

创建

```c
sched_init_smp
  sched_init_numa                            // 检测系统是否是NUMA系统，如果是的话，添加NUMA层级
  sched_init_domains                         // 建立调度域
    cpumask_and()                            // isolcpus=命令行参数隔离cpu
    build_sched_domains
      __visit_domain_allocation_hell         // 分配sched_domain
      build_sched_domain
        sd_init                              // 初始化调度域的调度参数
      build_sched_groups
      init_sched_groups_capability
      cpu_attach_domain
```

# BMSA4性能劣化
