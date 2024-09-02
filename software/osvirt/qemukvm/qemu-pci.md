# Qemu的PCI设备模拟

类型信息如下：

```c
static const TypeInfo pci_device_type_info = {
    .name = TYPE_PCI_DEVICE,
    .parent = TYPE_DEVICE,
    .instance_size = sizeof(PCIDevice),
    .abstract = true,
    .class_size = sizeof(PCIDeviceClass),
    .class_init = pci_device_class_init,
    .class_base_init = pci_device_class_base_init,
};
```

实例化过程如下：

```c
pci_device_class_init(ObjectClass *klass)
  DeviceClass *k = DEVICE_CLASS(klass)
  k->realize = pci_qdev_realize
  k->unrealize = pci_qdev_unrealize
  k->bus_type = TYPE_PCI_BUS
  device_class_set_props(k, pci_props)

pci_qdev_realize(DeviceState *qdev)
  PCIDevice *pci_dev = (PCIDevice *)qdev
  PCIDeviceClass *pc = PCI_DEVICE_GET_CLASS(pci_dev)
  bus = PCI_BUS(qdev_get_parent_bus(qdev)
  pci_dev = do_pci_register_device
  pc->realize
  pci_add_option_rom
```

`do_pci_register_device()`完成设备及其对应PCI总线上的一些初始化工作。

- 如果指定的devfn为-1，表示由总线自己选择插槽，得到插槽号后保存在PCIDevice的devfn中，如果在设备命令行中指定了addr，则addr会作为设备的devfn。

- 设置PCIDevice结构体中的各个字段，包括调用`pci_init_bus_master()`初始化PCIDevice中的AddressSpace成员bus_master_as及其对应的MR。

- 调用`pci_config_alloc()`分配PCI设备的配置空间，并设置其`config_read()`和`config_write()`函数。

- 最后将device复制到bus->devices数组中。

### pc->realize已pci_edu_realize()为例

```c
pci_edu_realize
  pci_config_set_interrupt_pin
  msi_init                            // 配置设备的MSI-X Capability
  memory_region_init_io               // 初始化一个MMIO
  pci_register_bar                    // 将MMIO注册为设备的BAR 0
```
