# smp_call_function

## smp_call_function的发送

在smp上，smp_call_function()依赖IPI中断：

```c
on_each_cpu
  preempt_disable
  smp_call_function                 // 可以单独调用
    preempt_disable
    smp_call_function_many          // 迫使其他cpu执行func，可以选择是否等待其他cpu返回
    preempt_enable
  local_irq_save
  func                              // 在本地cpu上执行func
  local_irq_restore
  preempt_enable
```

## smp_call_function的处理

```c

```