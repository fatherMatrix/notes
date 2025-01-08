# 巨型页

## 传统巨型页 - hugetlbfs

传统巨型页以来一个提前构建的巨型页池，其构建过程如下：

```c
hugetlb_nrpages_setup
  hugetlb_hstate_alloc_pages                        // 此时调用该函数，在其内部必定只会调用alloc_bootmem_huge_page()从memblock中分配阶数大于MAX_ORDER的巨型页
    alloc_bootmem_huge_page
      addr = memblock_virt_alloc_try_nid_nopanic
      list_add(&m->list, &huge_boot_pages)          // 由于mem_map还没准备好，此时先将分配好的阶数大于MAX_ORDER的巨型页放到临时链表中

/*******************  此时内存管理准备好了 *************************/

hugetlb_init
  hugetlb_init_hstates
    hugetlb_hstate_alloc_pages                      // 此时调用该函数，在其内部必定只会调用alloc_pool_huge_page()从页分配器中分配阶数不超过MAX_ORDER的巨型页
  gather_bootmem_prealloc                           // 将早期分配的阶数大于MAX_ORDER的巨型页信息收集到hstate数组中
  hugetlb_sysfs_init
  hugetlb_register_all_nodes
  hugetlb_cgroup_file_init
```

通过`/proc/sys/vm/nr_hugepages`来增加或减少永久巨型页，其处理函数为`hugetlb_sysctl_handler()`：

```c
hugetlb_sysctl_handler
  hugetlb_sysctl_handler_common
    __nr_hugepages_store_common
      set_max_huge_pages
```

## 透明巨型页 - transparent hugepage

### THP是否开启

文件`/sys/kernel/mm/transparent_hugepage/enabled`配置内存分配时是否使用THP：

- `always`
  
  - 全局开启

- `never`
  
  - 全局关闭

- `madvise`
  
  - 仅通过`madvise()`系统调用配置了`MADV_HUGEPAGE`的内存区域开启

### THP分配时的碎片整理

文件`/sys/kernel/mm/transparent_hugepage/defrag`控制**新分配巨型页时**，若无连续物理页时的处理方式：

```c
static struct kobj_attribute defrag_attr =
        __ATTR(defrag, 0644, defrag_show, defrag_store);

defrag_store
```

发生缺页异常（Page Fault）时，该功能可控制内存分别进行直接回收（Direct Reclaim）、后台回收（Background Reclaim）、直接整理（Direct Compaction）、后台整理（Background Compaction）的行为。开启或关闭该功能的配置文件路径为`/sys/kernel/mm/transparent_hugepage/defrag`，可选的配置项如下：

- `always`
  
  当系统分配不出透明大页时，暂停内存分配行为，总是等待系统进行内存的直接回收和内存的直接整理。内存回收和整理结束后，如果存在足够的连续空闲内存，则继续分配透明大页。

- `defer`
  
  当系统分配不出透明大页时，转为分配普通的4 KB页。同时唤醒kswapd内核守护进程以进行内存的后台回收，唤醒kcompactd内核守护进程以进行内存的后台整理。一段时间后，如果存在足够的连续空闲内存，khugepaged内核守护进程将此前分配的4 KB页合并为2 MB的透明大页。

- `madvise`
  
  仅在通过`madvise()`系统调用，并且设置了`MADV_HUGEPAGE`标记的内存区域中，内存分配行为等同于`always`。其余部分的内存分配行为保持为：发生缺页异常时，转为分配普通的4 KB页。阿里巴巴和腾讯的操作系统目前的默认选项。

- `defer+madvise`
  
  仅在通过`madvise()`系统调用，并且设置了`MADV_HUGEPAGE`标记的内存区域中，内存分配行为等同于`always`。其余部分的内存分配行为保持为`defer`。

- `never`
  
  禁止碎片整理。

### khugepaged的碎片整理

文件`/sys/kernel/mm/transparent_hugepage/khugepaged/defrag`控制对已分配页的合并，使其成为更大的页：

功能开关的配置文件路径为`/sys/kernel/mm/transparent_hugepage/khugepaged/defrag`。可选的配置项如下：

- `0`
  
  关闭khugepaged碎片整理功能。

- `1`
  
  配置为`1`时，khugepaged内核守护进程会在系统空闲时周期性唤醒，尝试将连续的4 KB页合并成2 MB的透明大页。