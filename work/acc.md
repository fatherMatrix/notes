# 工作加速器

## 如何分析调度行为

```shell
perf sched 
```

## virt-install创建虚拟机

```shell
# 创建
virt-install --name ts31-genoa --vcpus 32 --ram 16384 --cdrom=xxx.iso --disk path=xxx.qcow2 --network=default --graphics vnc,listen=0.0.0.0

# 查询vnc端口
virsh vncdisplay <domain>
```
