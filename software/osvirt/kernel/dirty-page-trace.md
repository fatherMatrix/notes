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
                  iomap_page_create                         // 准备回写数据结构 ！
                  set_page_dirty
                    ... TestSetPageDirty                    // 设置page结构体中的PageDirty
                    ... __set_page_dirty
                      __xa_set_mark(PAGECACHE_TAG_DIRTY)    // 设置pagecache xarray中的tag，用于write_cache_pages中的scan
                    ... __mark_inode_dirty
                wait_for_stable_page
        finish_fault                                        // 设置pte中的writable，dirty位硬件自动设置
```

### 脏页回写

```c
write_cache_pages
  scan xarray PAGECACHE_TAG_DIRTY
  lock_page
  clear_page_dirty_for_io
    page_mkclean                                            // 通过rmap机制清除pte的dirty、writable标志
    TestClearPageDirty                                      // 清除page结构体中的PageDirty
  xfs_do_writepage
    ... unlock_page
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
      iomap_apply(iomap_write_actor)
        iomap_write_begin
          __iomap_write_begin
            iomap_page_create                                // 准备回写数据结构 ！
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

## iomap_page/buffer_head释放

```c

```

## GUP困境

https://www.eklektix.com/Articles/930667/

User-space processes access their memory by way of virtual addresses mapped in their page tables. Those addresses are only valid within the process owning the memory. The page tables provide a convenient handle when the kernel needs to control access to specific ranges of user-space memory for a while. A common example is writing dirty file pages back to persistent store. A filesystem will mark those pages (in the relevant page table) as read-only, preventing further modification while the writeback is underway. If the owning process attempts to write to those pages, it will be blocked until writeback completes; thereafter, the read-only protection will cause a page fault, allowing the filesystem to be notified that the page has been dirtied again.

A call to get_user_pages() will return pointers to the kernel's page structures representing the physical pages holding the user-space memory, which can be used to obtain kernel-virtual addresses for those pages. Those addresses are in the kernel's address space, usually in the kernel's direct map that covers all of physical memory (on 64-bit systems). They are not the same as the user-space addresses, and are not subject to the same control. Direct-mapped memory that does not hold executable text is (almost) always writable by the kernel.

User space can use [mmap()](https://man7.org/linux/man-pages/man2/mmap.2.html) to map a file into its address space, creating a range of file-backed pages. Those pages will be initially marked read-only, even if mapped for write access, so that the filesystem can be notified when one of them is changed. If the kernel uses get_user_pages() to obtain write access to file-backed pages, the underlying filesystem will be duly notified that the pages have been made writable. At some future time, that filesystem will write the pages back to persistent storage, making them read-only. That protection change, though, applies only to the *user-space* addresses for those pages. The mapping in the kernel's address space remains writable.

That is where the problem arises: if the kernel writes to its mapping after the filesystem has written the pages back, the filesystem will be unaware that those pages have changed. **Kernel code can mark the pages dirty**, possibly leading to filesystem-level surprises when a seemingly read-only page has been written to. There are also a few scenarios in which the pages may never get marked as dirty, despite having been written to, in which case the written data may never find its way out to disk. Either way, the consequences are unfortunate.

**GUP第一次获取file-backed user page的时候，底层文件系统会感知到。但当该page被文件系统回写后，clear_page_dirty_for_io() -> page_mkwrite()无法取消掉内核页表的writable标记，导致后续通过内核页表访问该page时无法经由页保护异常通知文件系统做准备。但后续通过内核页表访问该page后：**

- **内核代码可能通过set_page_dirty()将其page结构体标脏，进而在没有准备iomap_page/buffer_head的情况下触发再次writeback回写，最终导致空指针。**

- **内核代码也可能没有set_page_dirty()将其page结构体标脏，但此时如果用户态不写mmap，那内核代码写的数据可能永远也没有机会落盘。**
