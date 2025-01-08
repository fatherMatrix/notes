# mkfs.xfs

v6.8.0如下：

```c
calculate_initial_ag_geometry
  calc_concurrency_ag_geometry
    calc_default_ag_geometry
```

v5.0.0如下：

```c
calculate_initial_ag_geometry
  1. try cli->agsize                    // ok则返回
  2. try cli->agcount                   // ok则返回
  3. calc_default_ag_geometry           // 都未指定或都ok，则计算default
align_ag_geometry
  can't align with dsunit
  validate_ag_geometry
```

# # mkfs.xfs参数

## -s sector_size_options

● -s size=value

○ 设置底层设备的扇区大小，最小为512字节，最大为32KB

○ 推荐由mkfs.xfs根据底层存储设备自行选择（磁盘512，固盘4096）

## -b block_size_options

● -b size=value

○ 表示xfs文件系统逻辑块大小，单位为字节，最小值为512，在Linux 5.x及6.10之前，最大值是PAGE_SIZE

○ 功能影响：无

○ 性能影响：文件系统分配/释放、读写的最小单位。推荐保持PAGE_SIZE

## -m global_metadata_options

● -m crc=value

○ 表示从/向磁盘读写数据时是否开启crc校验，1表示开启（默认），0表示关闭。

○ 功能影响：提供了校验机制和硬件错误检测；-m finobt的必要条件；

○ 性能影响：有计算开销，但目前主流cpu有硬件加速

● -m finobt=value

○ 是否在每个AG中新增一个用于索引空闲inode的B+树，1表示开启（默认），0表示关闭。

○ 性能影响：加速inode分配，推荐保持默认开启。

● -m inobtcount=value

○ 是否记录inobt和finobt使用的block数量，1表示开启，0表示关闭（默认）。

○ 性能影响：加速mount操作，但有运行时开销。推荐保持默认关闭。

● -m rmapbt=value

○ 是否在每个AG中新增一个用于记录每个文件系统块的owner的B+树，1表示开启，0表示关闭（默认）。举个例子，文件ino包含一个从文件系统块A到文件系统块B的extent，则在rmapbt中存在记录[A, B, ino]，表示文件系统块A到文件系统块B的所有文件系统块属于文件ino

○ 功能影响：用于文件系统恢复

○ 性能影响：有运行时开销，推荐保持默认关闭。

● -m reflink=value

○ 是否在每个AG中新增一个用于记录文件系统块是否被共享的B+树，1表示开启（默认），0表示关闭。

○ 功能影响：用于支持文件快照

○ 性能影响：有运行时开销。如无需使用该功能，可以考虑关闭

## -d data_section_options

● -d agcount=value,agsize=value

○ 用于指定AG数量或AG大小，两者只能使用一个。一个AG最小为128MB，最大为1TB。mkfs.xfs的默认方案如下：

■ 对于大于32TB的存储设备，AG大小默认设置为1TB

■ 对于非lvm/raid

● 总容量大于4TB时，AG大小默认设置为1TB

● 总容量小于4TB时，默认使用4个AG

■ 对于lvm/raid等支持条带化的设备

● 根据其总大小从32个AG开始随容量的减小而减小AG数量，具体地：

○ 大于512GB时，默认分为32～33个AG

○ 大于8GB且小于512GB时，默认分为16～17个AG

○ 大于128MB且小于8GB时，默认分为8～9个AG

○ 大于64MB且小于128MB时，默认分为4～5个AG

○ 大于32MB且小于64MB时，默认分为2～3个AG

○ 否则，默认为1～2个AG

■ agsize不应为stripe width的整数倍，整数倍会导致所有AG的起始位置位于raid/lvm中同一个磁盘上，降低性能

○ 性能影响：推荐采用默认值

● -d cowextsize=value

○ 用于指定cow fork在拓展eof时的extent size，默认值为32个fsblock

○ 性能影响：可尝试采用stripe unit大小

● -d extszinherit=value

○ 用于指定data fork在拓展eof时的extent size，默认值为0

○ 性能影响：可尝试采用stripe unit大小

● -d sunit/su/swidth/sw=value

○ 用于指定底层raid/lvm设备的stripe unit和stripe width大小

○ 性能影响：反应底层存储设备的最优读写大小，推荐采用默认值

## -i inode_options

● -i size=value

○ 指定xfs inode在磁盘上的字节大小。最小为256字节（crc=0的默认值），最大为2048字节。当crc=1时，默认值为512字节。

○ 功能影响：xfs_inode前半部分固定大小256字节，后半部分可变大小。可用于存储小文件数据、软链接数据、拓展属性数据等。推荐采用默认值。

● -i perblock=value

○ 同size=value，语意为一个fsblock包含多少inode，等价为fsblock / size

● -i sparse=value

○ 用于开启inode稀疏分配，0表示关闭，1表示开启（crc=1的默认值）。

○ 功能影响：xfs inode分配以64个为分配单位，对于512字节的inode，需要8个4096的连续fsblock。当磁盘碎片化严重时，可能会分配失败。稀疏分配允许分配时小于64个inode。推荐采用默认值

## -l log_section_options

● -l internal=value

○ 指定log是否与data放到同一个存储设备上，0表示否，1表示是（默认）

○ 性能影响：如果data放到大尺寸的慢速设备上，可以考虑将log单独放到一个小尺寸的快速设备上。

● -l agnum=value

○ 如果internal=1，指定log放到哪个AG中。默认为agcount / 2

○ 性能影响：推荐规避0号AG

● -l logdev=value

○ 如果internal=0，指定log放到哪个存储设备中

● -l size=value

○ 指定log区域的大小，最小为64MB，最大为2GB。

○ 性能影响：若log disk space写满，log flush期间可能阻塞新的事务。推荐尽可能大

● -i sunit/su=value

○ [mkfs.xfs中log sunit参数](https://doc.weixin.qq.com/doc/w3_AfMAIgbzAB82KyMpk0QQOCvTrEWHN?scode=AJEAIQdfAAoxF0r9qmAfMAIgbzAB8)

○ 性能影响：推荐设置为1个fsblock

## -n naming_options

● -n size=value

○ 指定目录在磁盘上的尺寸，默认值为4096。

○ 性能影响：推荐保持默认配置

## -r realtime_section_options

● -r rtdev=value

○ 指定realtime设备

○ 功能影响：realtime设备是一个全部划分为多个定长extents的设备，其分配算法简单，适用于对延迟有最低限制的文件。需使用xfsctl设置新创建的文件为实时文件。推荐合理选择数据库中的某些文件为实时文件。

● -r extsize=value

○ 指定realtime设备中定长extents的尺寸，最小值为fsblock size，最大值为1GB。对于raid/lvm默认值为stripe width，对于普通设备，默认值为64KB。

● -r noalign

○ 用于提示xfs忽略striped设备的stripe大小，不推荐。

# mount参数

## allocsize=size

○ buffer io下当extend eof时提前预留申请的磁盘块大小

## discard|nodiscard

○ 是否在删除文件块后对ssd触发trim指令

○ 开启后有利于延长ssd使用寿命，但对性能有一定影响

## filestreams

○ 对整个文件系统中的文件使用filestreams分配器，而不是仅对特定目录下的文件使用filestreams分配器。该分配器主要用于将目录下小文件集中到同一个AG中，而不是在所有AG中均衡分配。

○ 性能影响：建议mount时不添加该参数，仅对特定目录使用ioctl(XFS_IOC_FSSETXATTR)进行配置以针对性启用filestreams特性。
