# virtio_blk
```c
static struct pci_driver virtio_pci_driver = { 
        .name           = "virtio-pci",
        .id_table       = virtio_pci_id_table,
        .probe          = virtio_pci_probe,
        .remove         = virtio_pci_remove,
#ifdef CONFIG_PM_SLEEP
        .driver.pm      = &virtio_pci_pm_ops,
#endif
        .sriov_configure = virtio_pci_sriov_configure,
};
```
`virtio_blk设备`作为一个`pci/pcie设备`挂入`pci/pcie总线`，设备与驱动匹配后出发驱动的`probe()方法`。
## virtio_pci_probe
![[Pasted image 20240805112820.png]]
```c
virtio_pci_probe(pci_dev)                              // pci_device结构体
  vp_dev = alloc(s virtio_pci_device)
  pci_set_drvdata(pci_dev, vp_dev)                     // 将virtio_pci_device关联到pci_device->device->driver_data中
    pci_dev->dev->driver_data = vp_dev
  vp_dev->pci_dev = pci_dev                            // 将pci_device关联到virtio_pci_device中
  pci_enable_device(pci_dev)
  virtio_pci_modern_probe(vp_dev)
```