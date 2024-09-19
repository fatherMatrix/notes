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

## qemu创建虚拟机

```shell
./qemu-system-x86_64 \
        -machine accel=kvm \
        -m 16G \
        -smp 8 \
        -cdrom /data/alexjlzheng/TencentOS-Server-3.1-20240715.1-TK4-x86_64-minimal.iso \
        -boot order=d \
        -drive file=/data/alexjlzheng/disk.qcow2,format=qcow2 \
        -vnc 30.101.235.170:1
```
