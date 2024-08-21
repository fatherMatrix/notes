# PCI/PCIE

PCI/PCIe设备有三个空间：

- 内存地址空间

- IO地址空间

- 配置空间

## 配置空间

### 整体配置空间

![](pci.assets/df251786662fad26a81a3d13872ea049858b055d.png)

### 配置空间头

配置空间头占据整体配置空间的前64字节：

![](pci.assets/349f1f88be47915280ab73877fa313eb50d67b21.png)

## Capability机制

```
31                 16 15       8  7       0
+---------------------+----------+----------+
|         xxxx        |  Pointer |    ID    |
+----------+----------+----------+----------+
|                   xxxxx.                  |
+----------+--------------------------------+
```

- ID：由相关SIG分配

- Pointer：下一个Capability在整体配置空间中的偏移，PCI是256B，PCIe是4KB
  
  - 第一个Capability结构的地址在配置空间头的Capability字段中记录

# 总线枚举与初始化

`start_kernel()`中直接调用的pci/pcie初始化相关代码：

```c
start_kernel
  setup_arch
    acpi_boot_table_init
    early_acpi_boot_init
      early_acpi_process_madt                       // 处理MDAT表
    acpi_boot_init
      acpi_table_parse                                // ACPI_SIG_BOOT、ACPI_SIG_FADT
      acpi_process_madt                               // 解析MDAT表，获取bios提供的中断信息
      x86_init.pci.init = pci_acpi_init               // 在pci_subsys_init()中调用，在acpi_boot_init()中         
  rest_init
    kernel_thread(kernel_init)

kernel_init
  kernel_init_freeable
    do_basic_setup
      do_initcalls                                    // 开始对initcall的调用
```

通过`initcall机制`调用的pci/pcie初始化相关代码：

```c
postcore_initcall(pcibus_class_init)                // 创建/sys/class/pci_bus目录
postcore_initcall(pci_driver_init)                  // 注册pci_bus_type和pcie_port_bus_type 

arch_initcall(acpi_pci_init)
arch_initcall(pci_arch_init)                        // 配置pci总线的各种访问方式

subsys_initcall(acpi_init)                          // 基于ACPI的pci设备枚举过程
```

## pcibus_class_init

主要作用是注册一个名为`pci_bus`的`class`结构，对应`/sys/class/pci_bus/`目录。

```c
static struct class pcibus_class = {
    .name           = "pci_bus",
    .dev_release    = &release_pcibus_dev,
    .dev_groups     = pcibus_groups,
};

pcibus_class_init(void)
  class_register(&pcibus_class);

postcore_initcall(pcibus_class_init);
```

## pci_driver_init

注册`pci/pcie`两类总线。该函数执行结束后，会产生`/sys/bus/pci/`和`/sys/bus/pci_express`两个目录，之后当使用`device_register()`函数注册一个新的pci设备时，将在`/sys/bus/{pci,pci_express}/drivers/`目录下创建这个设备使用的目录。

```c
struct bus_type pci_bus_type = {
    .name           = "pci",
    .match          = pci_bus_match,
    .uevent         = pci_uevent,
    .probe          = pci_device_probe,
    .remove         = pci_device_remove,
    .shutdown       = pci_device_shutdown,
    .dev_groups     = pci_dev_groups,
    .bus_groups     = pci_bus_groups,
    .drv_groups     = pci_drv_groups,
    .pm             = PCI_PM_OPS_PTR,
    .num_vf         = pci_bus_num_vf,
    .dma_configure  = pci_dma_configure,
};

struct bus_type pcie_port_bus_type = {
    .name           = "pci_express",
    .match          = pcie_port_bus_match,
};

pci_driver_init
  bus_register(&pci_bus_type);
  bus_register(&pcie_port_bus_type);

postcore_initcall(pci_driver_init);
```

## acpi_pci_init

主要作用就是注册了`acpi_pci_bus`这条总线，但目前并不知道其作用是什么。

```c
acpi_pci_init
  register_acpi_bus_type(&acpi_pci_bus)
  acpi_pci_slot_init
  acpiphp_init
```

## pci_arch_init

主要作用是配置pci总线的各种访问函数

```c
pci_arch_init
  pci_direct_probe                                        // 由linux自行枚举总线
    request_region(0xcf8, 8)                              // 分配0xcf8、0xcfc端口
    raw_pci_ops = &pci_direct_conf1
  pci_mmcfg_early_init
  x86_default_pci_init / pci_acpi_init
  pci_direct_init
```

## acpi_init

基于`ACPI`机制的`PCI/PCIe`总线枚举过程：

```c
acpi_init
  acpi_bus_init                                                            // 注册acpi_bus_type
  kobject_create_and_add("acpi", firmware_kobj)
  pci_mmcfg_late_init                                                      // 扫描MCFG表，其中包括了ecam相关的资源
  acpi_scan_init
    acpi_pci_root_init
      acpi_scan_add_handler_with_hotplug(&pci_root_handler, "pci_root")    // 注册对pci/pcie host bridge的handler，ACPI枚举过程中，发现device后会调用对应的attach()方法
    ... ...
    acpi_bus_scan
      acpi_bus_attach
    ... ...
```

`pci/pcie`总线的枚举过程聚集在了`pci_root_handler`中，其定义如下：

```c
static struct acpi_scan_handler pci_root_handler = { 
        .ids = root_device_ids,                                            // PNP0A03表示一个pci/pcie host bridge，匹配后调用acpi_pci_root_add()
        .attach = acpi_pci_root_add,
        .detach = acpi_pci_root_remove,
        .hotplug = { 
                .enabled = true,
                .scan_dependent = acpi_pci_root_scan_dependent,
        },
};
```

当发现设备是一个`pci/pcie host bridge`后，会调用`acpi_pci_root_add()`进行`pci/pcie host bridge`的创建、设备/子桥的递归枚举。

```c
acpi_add_root_add
  ... ...
  获取设备的bdf
  pci_acpi_scan_root                                        // 枚举此host bridge下的设备和子桥
    acpi_pci_root_create(acpi_pci_root_ops)
      pci_create_root_bus
      pci_scan_child_bus
        pci_scan_child_bus_extend
          for dev range(0, 256) pci_scan_slot
            pci_scan_single_device
              pci_scan_device
                pci_bus_read_dev_vendor_id
                pci_alloc_dev
                pci_setup_device
              pci_device_add                                // 触发对应的driver->probe()方法，比如virtio_pci_probe()
                pci_configure_device
                device_initialize
                list_add_tail(&dev->bus_list, &bus->devices)
                pci_set_msi_domain
                device_add
                  bus_add_device
                  kobject_uevent(&dev->kobj, KOBJ_ADD)
                  bus_probe_device
                    if drivers_autoprobe
                      device_initial_probe
                        __device_attach
                          __device_attach_driver
                            driver_match_device
                            driver_probe_device
                              really_probe
                                调用bus或者driver的probe
                    list_for_each_entry(sif, &bus->p->interfaces, node)
                      sif->add_dev(dev, sif)
          for each pci bridge pci_scan_bridge_extend
```

## pci_iommu_init

该函数主要用来初始化处理器系统的`IOMMU`，可以配置IBM X-Series刀片服务器使用的Calgary IOMMU、Intel的Vt-d和AMD的IOMMU使用的页表。
如果在Linux系统中没有使能IOMMU选项，`pci_iommu_init`函数将调用`no_iommu_init`函数，并将`dma_ops`函数设置为`nommu_dma_ops`。

## pcibios_assign_resources

## pci_init

主要作用是对已完成枚举的PCI设备进行修复工作，用于修补一些BIOS中对pci设备有影响的bug。

## pci_proc_init

主要功能是在`proc文件系统`中建立`./bus/pci/`目录，并将`proc_fs`默认提供的`file_operations`更换为`proc_bus_pci_dev_operations`。

## pcie_portdrv_init

## pci_hotplug_init

## pci_sysfs_init