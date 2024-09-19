# 网卡创建

## 后端网卡设备

后端网卡设备创建的主要工作就是创建一个或多个（多队列）NetClientState结构并将其放在net_clients链表上。

```c
QEMU_OPTION_netdev:
QEMU_OPTION_net:
  qemu_find_opts
  net_client_parse
    qemu_opts_parse_noisily
```

```c
QEMU_OPTION_netdev:
QEMU_OPTION_net:
  net_client_parse

qemu_init_main_loop
qemu_create_machine
qemu_create_early_backends

  net_init_clients
    net_init_netdev                            // 解析"netdev"参数
      net_client_init(is_netdev=true)
        net_client_init1
          net_client_init_fun[netdev->type]()
    net_param_nic                              // 解析"nic"参数
    net_init_client                            // 解析"net"参数
      net_client_init(is_netdev=false)
```

对于NET_CLIENT_DRIVER_VHOST_USER类型，该回调函数是：

```c
net_init_vhost_user
  net_vhost_user_init
    qemu_new_net_client
      NetClientState = g_malloc0()
      qemu_net_client_setup
        QTAILQ_INSERT_TAIL(&net_clients)
    vhost_user_init
```

## 前端网卡

```c
qemu_main
  qemu_create_machine
  qmp_x_exit_preconfig
    qemu_init_board
      machine_run_board_init
        machine_class->init

pc_init1
  pc_nic_init
    NICInfo *nd = &nd_table[i]
    pci_nic_init_nofail
      qemu_find_nic_model
      pci_create
      object_property_set_bool(true, "realize")
```

摘抄：

```c
main
    ->qemu_init
        ->qemu_create_late_backends
            ->net_init_clients    /* 初始化网络设备 */
                ->qemu_opts_foreach(qemu_find_opts("netdev"), net_init_netdev, NULL,&error_fatal)
                    ->net_init_netdev
                        ->net_client_init
                            ->net_client_init1
                                ->net_client_init_fun[netdev->type](netdev, netdev->id, peer, errp)    /* 根据传入的参数类型再 net_client_init_fun 选择相应函数处理 */
        ->qmp_x_exit_preconfig
            ->qemu_create_cli_devices
                ->qemu_opts_foreach(qemu_find_opts("device"),    /* 根据需要虚拟化的设备的数量for循环执行 */
                      device_init_func, NULL, &error_fatal); ->device_init_func
device_init_func
    ->qdev_device_add
        ->qdev_device_add
            ->qdev_device_add_from_qdict
                ->qdev_get_device_class
                    ->module_object_class_by_name
                        ->type_initialize
                            ->type_initialize_interface    /* class_init 赋值 */
                                ->ti->class_init(ti->class, ti->class_data)    /* 根据对应的驱动类型调用相应的 class_init 函数初始化类 */
                ->qdev_new
                    ->DEVICE(object_new(name))
                        ->object_new_with_type
                            ->object_initialize_with_type
                                ->
                                ->object_init_with_type
                                    ->ti->instance_init(obj)    /* 创建 virtio-xx 设备实例初始化对象 */
                ->object_set_properties_from_keyval
                    ->len-queue_numa,queue_numa[0]
                ->qdev_realize
                    ->object_property_set_bool
                        ->object_property_set_qobject
                            ->object_property_set
                                ->prop->set(obj, v, name, prop->opaque, errp)    /* realize 调用 */
```

# Virtio网卡的TypeInfo结构

| TypeInfo           | name               | parent             | class             | instance     | class init               | instance init                   | realize                   |
| ------------------ | ------------------ | ------------------ | ----------------- | ------------ | ------------------------ | ------------------------------- | ------------------------- |
| device_type_info   | TYPE_DEVICE        | TYPE_OBJECT        | DeviceClass       | DeviceState  |                          |                                 | virtio_device_realize     |
| virtio_device_info | TYPE_VIRTIO_DEVICE | TYPE_DEVICE        | VirtioDeviceClass | VirtIODevice | virtio_device_class_init | virtio_device_instance_finalize | virtio_net_device_realize |
| virtio_net_info    | TYPE_VIRTIO_NET    | TYPE_VIRTIO_DEVICE | -                 | VirtIONet    | virtio_net_class_init    | virtio_net_instance_init        | -                         |

| TypeInfo             | name                | parent          | class          | instance       | class init                | instance init                | realize                |
| -------------------- | ------------------- | --------------- | -------------- | -------------- | ------------------------- | ---------------------------- | ---------------------- |
| device_type_info     | TYPE_DEVICE         | TYPE_OBJECT     | DeviceClass    | DeviceState    |                           |                              |                        |
| pci_device_type_info | TYPE_PCI_DEVICE     | TYPE_DEVICE     | PCIDeviceClass | PCIDevice      | pci_device_class_init     |                              | virtio_pci_realize     |
| virtio_pci_info      | TYPE_VIRTIO_PCI     | TYPE_PCI_DEVICE | VirtioPCIClass | VirtIOPCIProxy | virtio_pci_class_init     |                              | virtio_net_pci_realize |
| virtio_net_pci_info  | TYPE_VIRTIO_NET_PCI |                 |                | VirtIONetPCI   | virtio_net_pci_class_init | virtio_net_pci_instance_init |                        |

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
    object_initialize_child_with_props(VirtIONetPCI->VirtIONet)    // 在VirtIONetPCI的实例化函数中初始化VirtIONet部分，VirtIONetPCI部分应该是留到了具现化阶段
```

## VirtIONetPCI类型的具现化

正常来说，对于DeviceClass -> PCIDeviceClass -> XXXDeviceClass这种继承关系，具现化执行顺序应该是：

```c
device_set_realized
  pci_qdev_realize                                           // PCIDeviceClass的类初始化函数将DeviceClass->realize重写为pci_qdev_realize
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
  PCIDeviceClass->realize = virtio_pci_realize
  device_class_set_parent_realize
    VirtIOPCIClass->parent_dc_realize = DeviceClass->realize
    DeviceClass->realize = virtio_pci_dc_realize            // 强行修改了DeviceClass的realize，会被首先调用
```

这个时候再画个图

| class          | realize                | parent_dc_realize |
| -------------- | ---------------------- | ----------------- |
| DeviceClass    | virtio_pci_dc_realize  |                   |
| PCIDeviceClass | virtio_pci_realize     |                   |
| VirtioPCIClass | virtio_net_pci_realize | pci_qdev_realize  |

关键代码流程如下，从DeviceClass->realize()开始调用：

```c
virtio_pci_dc_realize
  VirtioPCIClass->parent_dc_realize                        // 对照上表，可知为pci_qdev_realize
```

进入原本应该首先调用的pci_qdev_realize()，该函数会将VirtIONetPCI中的PCI代理设备VirtIOPCIProxy注册到PCI总线上，并调用PCIDeviceClass->realize，即virtio_pci_realize()：

```c
pci_qdev_realize
  PCIDevice = do_pci_register_device
    pci_config_alloc
    pci_config_set_{vendor_id,device_id,revision,class}
    pci_init_multifunction
  PCIDeviceClass->realize()                                // virtio_pci_realize  
```

virtio_pci_realize()函数针对PCIDeviceClass进行初始化操作：

```c
virtio_pci_realize
  初始化各类cap的偏移
  memory_region_init(VirtIOPCIProxy->modern_bar)           // 初始化BAR 4
  VirtioPCIClass->realize()                                // virtio_net_pci_realize
```

virtio_net_pci_realize()函数会负责具现化VirtIONetPCI复合设备的virtio设备部分：VirtIONet

```c
virtio_net_pci_realize
  qdev_realize(vdev)                                       // 最终调用到VirtIONet->realize()，即virtio_net_device_realize
    bus add children
```

VirtIONet设备的具现化过程中，首先调用DeviceClass->realize()，即virtio_device_realize():

```c
virtio_device_realize
  VirtioDeviceClass->realize()                             // 在virtio_net_class_init()中被设置为virtio_net_device_realize()
  virtio_bus_device_plugged
    VirtioBusClass->device_plugged()                       // 在virtio_pci_bus_class_init()中被设置为virtio_pci_device_plugged()
      virtio_pci_modern_regions_init
        memory_region_init_io                              // 配置各个capability在BAR空间中的结构体的读写函数
      virtio_pci_modern_mem_region_map
        memory_region_add_subregion                        // 向BAR 4中添加子Memory Region，每个region表示一个capability list item指向的数据
        virtio_pci_add_mem_cap                             // 向capability list中添加item
```

```c
virtio_net_device_realize
  virtio_init
```

# 参考文献

[qemu侧 网络包发送调试记录_-nic tap,model=e1000-CSDN博客](https://blog.csdn.net/qq_41146650/article/details/1272449598)
