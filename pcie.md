# PCI/PCIE总线
## 数据结构

![[Pasted image 20240805105653.png]]
## 总线驱动模型
![[Pasted image 20240805105715.png]]
## 关键调用顺序
```c
|-->pcibus_class_init
|-->pci_driver_init
|-->acpi_pci_init
|-->acpi_init        // 这里面会进行pci总线的枚举
```
## 注册总线类型
### pci_driver_init
```c
pci_driver_init                        // postcore_initcall
  bus_register(&pci_bus_type)          // pci总线注册
  bus_register(&pcie_port_bus_type)    // pcie总线注册

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
```
- 内核通过postcore_initcall调用pci_driver_init；
- pci_bus_match和pcie_port_bus_match用来检查设备与驱动是否匹配，一旦匹配则调用pci_device_probe函数。
## 总线及设备的实例化
### pci_host_probe
![[Pasted image 20240805105328.png]]
- 设备的扫描从pci_scan_root_bus_bridge开始，首先需要先向系统注册一个host bridge，在注册的过程中需要创建一个root bus，也就是bus 0，在pci_register_host_bridge函数中，主要是一系列的初始化和注册工作，此外还为总线分配资源，包括地址空间等；
- pci_scan_child_bus开始，从bus 0向下扫描并添加设备，这个过程由pci_scan_child_bus_extend来完成；
- 从pci_scan_child_bus_extend的流程可以看出，主要有两大块：
- PCI设备扫描，从循环也能看出来，每条总线支持32个设备，每个设备支持8个功能，扫描完设备后将设备注册进系统，pci_scan_device的过程中会去读取PCI设备的配置空间，获取到BAR的相关信息，细节不表了；
- PCI桥设备扫描，PCI桥是用于连接上一级PCI总线和下一级PCI总线的，当发现有下一级总线时，创建子结构，并再次调用pci_scan_child_bus_extend的函数来扫描下一级的总线，从这个过程看，就是一个递归过程。
- 从设备的扫描过程看，这是一个典型的DFS（Depth First Search）过程，熟悉数据结构与算法的同学应该清楚，这就类似典型的走迷宫的过程；
## pci驱动与设备的匹配
匹配由两种行为触发：
- 新device添加
- 新driver注册
### 新device添加
```c
pci_device_add(pci_dev dev, xxx)        // 本函数在调用前dev中的bus字段已经设置
  device_add                            // core函数
    bus_add_device
      klist_add_tail                    // 将device加入bus的device list
    bus_probe_device
      device_initial_probe              // 如果设置了自动探测
        device_attach
          __device_attach_driver
            driver_match_device
            driver_probe_device         // 如果上一步匹配上了
```
### 新driver注册
```c
pci_register_driver
  __pci_register_driver
    drv->driver.bus = &pci_bus_type    // 表明driver所属总线
    driver_register                    // core函数
      bus_add_driver
        klist_add_tail                 // 将driver加入bus的driver list
        driver_attach                  // 如果设置了自动探测，则进行操作
          __driver_attach
            driver_match_device
            device_driver_attach       // 如果上一步匹配上了
              driver_probe_device
```
### driver_probe_device
最终会先尝试调用bus的probe函数，其中会回调到驱动的probe函数；如果bus的probe函数未定义，则直接调用driver的probe函数。  
### pci_bus_match
```c
pci_bus_match
  to_pci_dev                // 获取要匹配的设备
  to_pci_driver             // 获取要匹配的驱动
  pci_match_device
    pci_match_one_device    // 根据vendor id, device id等进行匹配
```
- 设备或者驱动注册后，触发pci_bus_match函数的调用，实际会去比对vendor和device等信息，这个都是厂家固化的，在驱动中设置成PCI_ANY_ID就能支持所有设备；
- 一旦匹配成功后，就会去触发pci_device_probe的执行。
### pci_device_probe

![[Pasted image 20240805105741.png]]
