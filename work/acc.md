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
        -vnc 0.0.0.0:1
```

## qemu启动虚拟机

```shell
./qemu-system-x86_64 \
        -machine accel=kvm \
        -D /data/alexjlzheng/qemu.log \
        -m 64G \
        -smp 128 \
        -object memory-backend-ram,id=mem0,size=32G \
        -object memory-backend-ram,id=mem1,size=32G \
        -numa node,cpus=0-63,memdev=mem0,nodeid=0 \
        -numa node,cpus=64-127,memdev=mem1,nodeid=1 \
        -drive file=/data/alexjlzheng/kernels/ts31.qcow2,format=qcow2,if=virtio \
        -drive file=/data/alexjlzheng/kernels/ts31.data.qcow2,format=qcow2,if=virtio \
        -netdev user,id=netdev0,hostfwd=tcp:127.0.0.1:36666-:22 \
        -device virtio-net-pci,netdev=netdev0,len-numaware-queue=2,numaware-queue[0]=1 \
        -serial file:/data/alexjlzheng/kernels/serial.log \
        -vnc 0.0.0.0:5
```
