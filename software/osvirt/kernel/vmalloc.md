# 非连续内存分配

## vmalloc

## vfree

```c
vfree
  __vfree
    if in_interrupt()
      __vfree_deferred
    else
      __vunmap
```

__vfree_deferred()中主要是对工作队列queue_work()，使其在合适的时候调用__vunmap()，重点还是__vunmap():

```c
__vunmap
  vm_struct = find_vm_area
  vm_remove_mappings
    remove_vm_area
      spin_lock
      vmap_area = __find_vmap_area
      spin_unlock
      free_unmap_vmap_area
        unmap_vmap_area                                     // 取消页表映射
        free_vmap_area_noflush
          unlink_va                                         // 将vmap_area从vmap_area_root红黑树中摘下
          llist_add                                         // 将vmap_area放入vmap_purge_list链表中
          try_purge_vmap_area_lazy                          // 如果累计了足够多待回首vmap_area，才调用这个函数
  __free_pages(vm_struct->pages)

try_purge_vmap_area_lazy
  vmalloc_sync_unmappings                                   // 同步主内核页表
  flush_tlb_kernel_range
    on_each_cpu(do_flush_tlb_all/do_kernel_range_flush)     // 发送ipi执行TLB冲刷
  merge_or_add_vmap_area                                    // 将vmap_area最终放进free_vmap_area_root红黑树中
```

try_purge_vmap_area_lazy()有可能在未来触发：

```c

```