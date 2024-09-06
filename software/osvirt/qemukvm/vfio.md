# VFIO使用方法

- 确定直通设备的BDF

- 找到这个设备的VFIO group，这是由内核生成的：
  
  - readlink /sys/bus/pci/devices/BDF/iommu_group

- 查看该group中的设备
  
  - ls /sys/bus/pci/devices/BDF/iommu_group/devices/

- 将设备与母机原生驱动设备解绑：
  
  - echo 0000:01:10.0 > /sys/bus/pci/devices/BDF/driver/unbind

- 找到设备的vendor id和device id
  
  - lspci -n -s BDF

- 将设备绑定到vfio-pci驱动，这会导致一个新的设备节点/dev/vfio/<group>被创建。这个节点表示直通设备所属的group文件，用户态程序可以通过该节点操作直通设备的group
  
  - echo vendorid deviceid > /sys/bus/pci/devices/vfio-pci/new_id

- 向qemu传递相关参数
  
  - qemu-system-x86_64 ... -device vfio-pci,host=BDF,id=...

# VFIO编程接口

## container层面

- 设备文件：/dev/vfio/vfio，打开该设备文件可以获得一个container

- container的ioctl包括：
  
  - VFIO_GET_API_VERSION
  
  - VFIO_CHECK_EXTENSION
  
  - VFIO_SET_IOMMU
  
  - VFIO_IOMMU_GET_INFO
    
    - 只针对Type1 IOMMU，比如：Intel Vt-d、AMD-Vi
  
  - VFIO_IOMMU_MAP_DMA
    
    - 用来指定设备端看到的io地址到进程虚拟地址之间的转换关系，类似于KVM_SET_USER_MEMORY_REGION指定虚拟机物理地址到进程虚拟地址之间的映射

## group层面

- 设备文件：/dev/vfio/<groupid>，打开该设备可以获得一个group

- group的ioctl包括：
  
  - VFIO_GROUP_GET_STATUS
  
  - VFIO_GROUP_SET_CONTAINER
  
  - VFIO_GROUP_GET_DEVICE_FD
    
    - 用来返回一个新的文件描述符fd来描述具体设备

## device层面

- 文件描述符fd来源于group的VFIO_GROUP_GET_DEVICE_ID

- device的ioctl包括：
  
  - VFIO_DEVICE_GET_REGION_INFO
  
  - VFIO_DEVICE_GET_IRQ_INFO
  
  - VFIO_DEVICE_RESET
