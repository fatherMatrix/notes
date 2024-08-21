# 内核脏页跟踪

脏页跟踪旨在记录pagecache中哪些page为dirty，以便内核在合适的时机进行脏页回写。

- 匿名页：**不需要**进行脏页跟踪，因为匿名页不需要回写操作。

- 私有文件页：**不需要**跟踪脏页，因为映射的时候，page会被设置只读属性，写访问会发生COW，转变为匿名页。

- 共享文件页：**需要**进行脏页跟踪。

文件读写过程中，pagecache的读写来源有两个：

- read/write，跟踪手段为page结构体的flags

- mmap，跟踪手段为pte的dirty位

## mmap共享映射

基本过程如下：

- mmap共享映射文件

- 第一次read文件页所映射page时，发生**缺页异常**后读文件页到pagecache

- 第一次write文件页所映射page时，设置本进程对应pte的dirty、writable标志

- 脏页回写时，通过rmap机制，清空所有共享映射了此page的进程的相应pte的dirty位，并设置只读

- 第二次write文件页所映射page时
  
  - 如果pagecache还未回写到磁盘，则相应的pte依然为dirty、writable，所以可以直接write该内存
  
  - 如果pagecache已经写回到磁盘，则此时pte只读，会产生**写时复制异常**，异常处理中重新将对应pte转换为dirty、writable

### 第一次写访问文件页

```c
handle_pte_fault
  do_fault
    do_shared_fault
        do_page_mkwrite
          vmf->vma->vm_ops->page_mkwrite
            xfs_filemap_page_mkwrite
              iomap_page_mkwrite
                lock_page
                iomap_apply(iomap_page_mkwrite_actor)
                  iomap_page_create
                  set_page_dirty                            // 设置page结构体中的PageDirty
                wait_for_stable_page
        finish_fault                                        // 设置pte中的writable，dirty位硬件自动设置
```

### 脏页回写

```c
write_cache_pages
  lock_page
  clear_page_dirty_for_io
    page_mkclean                                            // 通过rmap机制清除pte的dirty、writable标志
    TestClearPageDirty                                      // 清除page结构体中的PageDirty
  xfs_do_writepage
    unlock_page
```

### 第二次写访问文件页

如果脏页还未回写，则pte中依然是dirty、writable，可以直接访问对应内存；

如果已经回写了，则此时pte只读，会产生**写时复制异常（访问权限错误缺页）**：

```c
handle_pte_fault
  if (vmf->flags & FAULT_FLAG_WRITE)
    if (!pte_write())
      do_wp_page                                            // 访问权限错误
        wp_page_shared
          do_page_mkwrite                                   // 设置page结构体中的PageDirty
          finish_mkwrite_fault                              // 设置pte中的writable，dirty位硬件自动设置
```

## write系统调用

### 第一次写访问文件页

```c
xfs_file_write_iter
  xfs_file_buffered_aio_write
    iomap_file_buffered_write(xfs_iomap_ops)
      iomap_apply(iomap_write_iter)
        ... __iomap_write_end
          iomap_set_page_dirty                               // 仅标记page结构体的PageDirty即可
```

### 脏页回写

```c
write_cache_pages
  ... clear_page_dirty_for_io
    TestClearPageDirty                                       // 仅需清除page结构体的PageDirty即可
```

### 第二次写访问文件页

脏页回写之前，页描述符脏标志位依然被置位，等待回写, 不需要设置页描述符脏标志位。

脏页回写之后，页描述符脏标志位是清零的，文件写页调用链会设置页描述符脏标志位。
