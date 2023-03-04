# virtio

## 整体思想

![](https://img2020.cnblogs.com/blog/774036/202111/774036-20211126153504501-1486553797.png)

1. 虚拟机产生的IO请求会被前端的virtio设备接收，并存放在virtio设备散列表scatterlist里

2. Virtio设备的virtqueue提供add_buf将散列表中的数据映射至前后端数据共享区域Vring中

3. Virtqueue通过kick函数来通知后端qemu进程。Kick通过写pci配置空间的寄存器产生kvm_exit

4. Qemu端注册ioport_write/read函数监听PCI配置空间的改变，获取前端的通知消息

5. Qemu端维护的virtqueue队列从数据共享区vring中获取数据

6. Qemu将数据封装成virtioreq

7. Qemu进程将请求发送至硬件层

## virtio-blk后端

![](https://img-blog.csdn.net/20140727164945442?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvdTAxMjM3NzAzMQ==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/Center)

![](https://img-blog.csdn.net/20140728005159624?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvdTAxMjM3NzAzMQ==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/Center)

## vhost-blk后端

![](https://img-blog.csdn.net/20140727232721472?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvdTAxMjM3NzAzMQ==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/Center)

![](https://img-blog.csdn.net/20140727225312330?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvdTAxMjM3NzAzMQ==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/Center)
