# 网卡参数解析

```c
net_init_clients
  net_init_netdev                        // 解析"netdev"参数
    net_client_init(is_netdev=true)
  net_param_nic                          // 解析"nic"参数
  net_init_client                        // 解析"net"参数
    net_client_init(is_netdev=false)
```

# 网卡创建

## 后端网卡设备

```c
net_client_init
  net_client_init1
```

## 前端网卡

```c
pc_init1
  pc_nic_init
    NICInfo *nd = &nd_table[i]
    pci_nic_init_nofail
      qemu_find_nic_model
      pci_create
      object_property_set_bool(true, "rea)
```

# Virtio网卡的TypeInfo结构

| TypeInfo           | name               | parent             | class             | instance     | class init                | instance init                | realize                |
| ------------------ | ------------------ | ------------------ | ----------------- | ------------ | ------------------------- | ---------------------------- | ---------------------- |
| device_type_info   | TYPE_DEVICE        | TYPE_OBJECT        | DeviceClass       | DeviceState  |                           |                              |                        |
| virtio_device_info | TYPE_VIRTIO_DEVICE | TYPE_DEVICE        | VirtioDeviceClass | VirtIODevice |                           |                              |                        |
| virtio_net_info    | TYPE_VIRTIO_NET    | TYPE_VIRTIO_DEVICE | -                 | VirtIONet    | virtio_net_pci_class_init | virtio_net_pci_instance_init | virtio_net_pci_realize |

| TypeInfo             | name            | parent          | class          | instance       | class init            | instance init | realize            |
| -------------------- | --------------- | --------------- | -------------- | -------------- | --------------------- | ------------- | ------------------ |
| device_type_info     | TYPE_DEVICE     | TYPE_OBJECT     | DeviceClass    | DeviceState    |                       |               |                    |
| pci_device_type_info | TYPE_PCI_DEVICE | TYPE_DEVICE     | PCIDeviceClass | PCIDevice      | virtio_pci_class_init |               | virtio_pci_realize |
| virtio_pci_info      | TYPE_VIRTIO_PCI | TYPE_PCI_DEVICE | VirtIOPCIClass | VirtIOPCIProxy |                       |               |                    |

virtio网卡是两个结构粘在一起的：

```c
 struct VirtIONetPCI {
     VirtIOPCIProxy parent_obj;            // PCI代理设备部分
     VirtIONet vdev;                       // virtio设备部分
 };
```

## VirtIONetPCI类型的注册

```c
static const VirtioPCIDeviceTypeInfo virtio_net_pci_info = { 
    .base_name             = TYPE_VIRTIO_NET_PCI,
    .generic_name          = "virtio-net-pci",
    .transitional_name     = "virtio-net-pci-transitional",
    .non_transitional_name = "virtio-net-pci-non-transitional",
    .instance_size = sizeof(VirtIONetPCI),
    .instance_init = virtio_net_pci_instance_init,
    .class_init    = virtio_net_pci_class_init,
};

static void virtio_net_pci_register(void)
{
    virtio_pci_types_register(&virtio_net_pci_info);
}

type_init(virtio_net_pci_register)
```

## VirtIONetPCI类型的初始化

```c
virtio_net_pci_class_init
  VirtioPCIClass->realize = virtio_net_pci_realize
```

## VirtIONetPCI类型的实例化

```c
virtio_net_pci_instance_init
  virtio_instance_init_common
    object_initialize_child_with_props(VirtIONetPCI->VirtIONet)        // 在VirtIONetPCI的实例化函数中初始化VirtIONet部分，VirtIONetPCI部分应该是留到了具现化阶段
```

## VirtIONetPCI类型的具现化

正常来说，对于DeviceClass -> PCIDeviceClass -> XXXDeviceClass这种继承关系，具现化执行顺序应该是：

```c
device_set_realized
  pci_qdev_realize                // PCIDeviceClass的类初始化函数将DeviceClass->realize重写为pci_qdev_realize
    pci_default_realize
```

画个图，应该是：

| class          | realize             |
| -------------- | ------------------- |
| DeviceClass    | pci_qdev_realize    |
| PCIDeviceClass | pci_default_realize |

但是，VirtIOPCIClass的类实例化函数`virtio_pci_class_init()`将这个顺序进行了扭转：

```c
virtio_pci_class_init
  VirtIOPCIClass->parent_dc_realize = DeviceClass->realize
  DeviceClass->realize = virtio_pci_dc_realize                // 强行修改了DeviceClass的realize，会被首先调用
```

这个时候再画个图

| class          | realize                | parent_dc_realize |
| -------------- | ---------------------- | ----------------- |
| DeviceClass    | virtio_pci_dc_realize  |                   |
| PCIDeviceClass | virtio_pci_realize     |                   |
| VirtIOPCIClass | virtio_net_pci_realize | pci_qdev_realize  |



# qemu侧capability的初始化

```c
virtio_net_pci_class_init                                // 这个class有点特殊
  VirtioPCIClass->realize = virtio_net_pci_realize
```

```c
virtio_pci_device_plugged
  virtio_pci_modern_regions_init
  virtio_pci_modern_mem_region_map()
```



# 参考文献

[qemu侧 网络包发送调试记录_-nic tap,model=e1000-CSDN博客](https://blog.csdn.net/qq_41146650/article/details/127244959)
