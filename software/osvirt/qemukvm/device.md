# 设备虚拟化

## 总线

总线的数据结构如下：

| Parent      | TYPE_XXX     | struct TypeInfo | ObjectClassX | ObjectX  |
| ----------- | ------------ | --------------- | ------------ | -------- |
| TYPE_OBJECT | TYPE_BUS     | bus_info        | BusClass     | BusState |
| TYPE_BUS    | TYPE_PCI_BUS | pci_bus_info    | PCIBusClass  | PCIBus   |

总线的创建过程如下，总线在创建的时候仅仅搭建了起了拓扑结构上的关系，并没有实现设备和总线的具现化（设置"realized"属性为true）。总线的具现化是通过其父设备的具现化来递归实现的。

```
qbus_new
  bus = BUS(object_new(typename))                                               // typename是类型名称
  qbus_init_internal(bus, parent, name)                                         // parent的类型为DeviceState，name是总线名称
    bus->parent = parent                                                        // 设置总线的父节点为parent指向的设备，总线和设备是交替的
    bus->name = g_strdup(name)                                                  // 设置总线的名称为name。如果传入的name为NULL，则根据某种规则生成总线名
    QLIST_INSERT_HEAD(&bus->parent->child_bus, bus, sibling)
    bus->parent->num_child_bus++
    object_property_add_child(OBJECT(bus->parent), bus->name, OBJECT(bus))
    object_unref(OBJECT(bus))
```

## 设备

设备的数据结构如下：

| Parent      | TYPE_XXX    | struct TypeInfo  | ObjectClassX | ObjectX     |
| ----------- | ----------- | ---------------- | ------------ | ----------- |
| TYPE_OBJECT | TYPE_DEVICE | device_type_info | DeviceClass  | DeviceState |

设备的创建过程如下：

```
qdev_new
  return DEVICE(object_new(name))
```

设备的创建有两种情况。第一种是跟随主板初始化一起创建，典型的设备包括南北桥、一些传统的ISA设备、默认的显卡设备等，这类设备是通过qdev_create函数创建的；第二种是在命令行通过-device或者在QEMU Monitor中通过device_add添加的，这类设备通过qdev_device_add函数创建。两种方式本质上都调用了object_new创建对应设备的QOM对象，然后进行具现化。

北桥的数据结构如下：

| Parent               | TYPE_XXX                    | struct TypeInfo         | ObjectClassX       | ObjectX      |
| -------------------- | --------------------------- | ----------------------- | ------------------ | ------------ |
| TYPE_DEVICE          | TYPE_SYS_BUS_DEVICE         | sysbus_device_type_info | SysBusDeviceClass  | SysBusDevice |
| TYPE_SYS_BUS_DEVICE  | TYPE_PCI_HOST_BRIDGE        | pci_host_type_info      | PCIHostBridgeClass | PCIHostState |
| TYPE_PCI_HOST_BRIDGE | TYPE_I440FX_PCI_HOST_BRIDGE | i440fx_pcihost_info     | -                  | I440FXState  |

PCI设备的数据结构如下（以0号总线0号设备————PCI Host的PCI设备部分为例）：

| Parent          | TYPE_XXX               | struct TypeInfo      | ObjectClassX   | ObjectX        |
| --------------- | ---------------------- | -------------------- | -------------- | -------------- |
| TYPE_DEVICE     | TYPE_PCI_DEVICE        | pci_device_type_info | PCIDeviceClass | PCIDevice      |
| TYPE_PCI_DEVICE | TYPE_I440FX_PCI_DEVICE | i440fx_info          | -              | PCII440FXState |
