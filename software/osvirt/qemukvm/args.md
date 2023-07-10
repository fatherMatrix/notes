# 参数解析

## 大体结构

参数例子：

```
/usr/bin/bin/qemu-system-x86_64 linux-0.2.img -m 512 -enable-kvm -smp 1,sockets=1,cores=1,threads=1 -realtime mlock=off -device ivshmem,shm=ivshmem,size=1 -device ivshmem,shm=ivshmem1,size=2
```

解析后的框架：

```
    QemuOptsList    +------------------+------------------+------------------+------------------+------------------+
vm_config_groups[N] | qemu_machine_ops |  qemu_smp_opts   |  qemu_device_ops |      ... ...     |      ... ...     |
                    +------------------+------------------+------------------+------------------+------------------+
                             |                   |                   |
                             V                   V                   V
                      +------------+      +------------+      +------------+
                      |  QemuOpts  |      |  QemuOpts  |      |  QemuOpts  |
                      +------------+      +------------+      +------------+
                             |
                           




```

## 参考文献

- https://terenceli.github.io/技术/2015/09/26/qemu-options
