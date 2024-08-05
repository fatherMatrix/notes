# PCI

PCI设备有三个空间：

- 内存地址空间
- IO地址空间
- 配置空间
# PCIE
## Power Management Capability
```
 31                 16 15       8  7       0
+---------------------+----------+----------+
|         PMCR        |  Pointer |    ID    |
+----------+----------+----------+----------+
|   Data   |             PMCSR              |
+----------+--------------------------------+
```
# 初始化
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
      do_initcalls
```
通过`initcall机制`调用的pci/pcie初始化相关代码：
```c
postcore_initcall(pcibus_class_init)
postcore_initcall(pci_driver_init)

arch_initcall(acpi_pci_init)
  register_acpi_bus_type
arch_initcall(pci_arch_init)

subsys_initcall(acpi_init)
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
## pci_arch_init
第一个总线初始化函数，枚举总线：
```c
pci_arch_init
  pci_direct_probe                    # 由linux自行枚举总线
    request_region(0xcf8, 8)          # 分配0xcf8、0xcfc端口
    raw_pci_ops = &pci_direct_conf1
  pci_mmcfg_early_init
  x86_default_pci_init / pci_acpi_init
  pci_direct_init
    

arch_initcall(pci_arch_init)
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