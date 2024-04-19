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