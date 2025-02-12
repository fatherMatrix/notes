# VFS

## inode

```c
#define S_IFMT  00170000                                // 共18位，2进制为001 111 000 000 000 000
#define S_IFSOCK 0140000                                // Socket
#define S_IFLNK  0120000                                // 符号链接
#define S_IFREG  0100000                                // 正规文件
#define S_IFBLK  0060000                                // 块设备文件
#define S_IFDIR  0040000                                // 目录
#define S_IFCHR  0020000                                // 字符设备文件
#define S_IFIFO  0010000                                // fifoå
#define S_ISUID  0004000                                // set uid
#define S_ISGID  0002000                                // set gid
#define S_ISVTX  0001000                                // sticky位

#define S_ISLNK(m)      (((m) & S_IFMT) == S_IFLNK)
#define S_ISREG(m)      (((m) & S_IFMT) == S_IFREG)
#define S_ISDIR(m)      (((m) & S_IFMT) == S_IFDIR)
#define S_ISCHR(m)      (((m) & S_IFMT) == S_IFCHR)
#define S_ISBLK(m)      (((m) & S_IFMT) == S_IFBLK)
#define S_ISFIFO(m)     (((m) & S_IFMT) == S_IFIFO)
#define S_ISSOCK(m)     (((m) & S_IFMT) == S_IFSOCK)

#define S_IRWXU 00700                                   // user
#define S_IRUSR 00400
#define S_IWUSR 00200
#define S_IXUSR 00100

#define S_IRWXG 00070                                   // group
#define S_IRGRP 00040
#define S_IWGRP 00020
#define S_IXGRP 00010

#define S_IRWXO 00007                                   // other
#define S_IROTH 00004
#define S_IWOTH 00002
#define S_IXOTH 00001
```

## open

```c
open
  do_sys_open(AT_FDCWD, filename, flags, mode)          // flags是O_*，mode是S_*
    build_open_flags(flags, mode, &op)                  // op是open_flags，其中包括open_flag和lookup_flag
    get_unused_fd_flags(flags)
    do_filp_open(dfd, tmp, &op)                         // tmp是filename结构体，op是open_flags结构体
      flags = op->lookup_flags                          // 此时flags是lookup_flags
      set_nameidata(&nd, dfd, pathname)
      path_openat(&nd, op, flags | LOOKUP_*)
        alloc_empty_file(op->open_flag, current_cred()) // 使用open_flag生成空file结构体
        path_init(nd, flags)
          nd->flags = flags | LOOKUP_*                  // nd->flags对应的是lookup_flags
        link_path_walk(s, nd)                           // 解析路径，最后一个代表文件的分量除外
          may_lookup(nd)                                // 检查下一个路径分量所在父目录的访问权限
        trailing_symlink(nd)                            // 处理文件链接
        do_last(nd, file, op)                           // 处理路径中最后的分量，执行打开操作
          ... ...
          lookup_open                                   // 查找或者创建file结构体，并完成其附属结构体的查找或创建（dentry，inode） 
            d_lookup                                    // 查找dentry，如果找到就返回 
            dir_inode->i_op->create -- ext4_create      // 调用文件系统层的方法创建inode
              ... ...
              alloc_inode
          may_open                                      // 检查权限
            inode_permission                            // 对inode中保存的权限进行检查，包括UGO和ACL
          vfs_open                                      // 对于块设备文件，这里是blkdev_open()，其中会将file->f_mapping设置为block_device的address_space
        terminate_walk(nd)
      restore_nameidata
    fd_install
```

## close

```c
close
  __close_fd(current->files, fd)
    spin_lock(&files->file_lock)
    __put_unused_fd
    spin_unlock()
    filp_close()
      filp->f_op->flush
      fput(filp)
        fput_many
          ----                                           // 这里其实是用工作队列延迟执行____fput -> __fput
          init_task_work(&file->f_u.fu_rcuhead, ____fput)
          test_work_add(task, &file->f_u.fu_rcuhead)
          ----
          llist_add(&file->f_u.fu_llist, &delayed_fput_list)
          schedule_delayed_work(&delayed_fput_work)
          ----

____fput
  __fput
    fsnotify_close
    eventpoll_release
    file->f_op->release
    fops_put
    dput
      dentry_kill
        __dentry_kill
          ...
    mntput
    file_free
```

## unlink

```c
unlink
  do_unlinkat
    vfs_unlink
      inode_lock
      dir->i_op->unlink
      inode_unlock
      iput
        atomic_dec_and_lock
        mark_inode_dirty_sync        
          ... ...                                       // 唤醒回写线程
        iput_final
          sop->drop_inode                               // 判断是否应该evict本inode
          evict
            inode_sb_list_del
            inode_wait_for_writeback                    // 既然已经决定要删除了，为什么还要等他写完呢？
            destroy_inode
              __destroy_inode
                security_inode_free
              inode->free_inode = sop->free_inode
              call_rcu(&inode->i_rcu, i_callback)
```

## mount

```c
mount
  ksys_mount(dev_name, dir_name, type, flags, data)     // dev_name是挂载设备文件路径，dir_name是挂载目录，type是文件系统名称，flags是标识，data是各种挂载选项
    do_mount
      user_path_at(dir_name, ...)                       // 获取挂载目录挂载点
      do_new_mount                                      // 有很多种mount类型
        fs_context_for_mount                            // 分配并初始化fs_context结构体，主要通过file_system_type->init_fs_context()回调函数进行
          alloc_fs_context
            init_fs_context = fs_type->init_fs_context  // 如果结果为NULL，则将init_fs_context设置为legacy_init_fs_context
            init_fs_context(fc)
              legacy_init_fs_context
                fc->ops = &legacy_fs_context_ops        // 在init_fs_context中设置对参数的解析函数 
        vfs_parse_fs_string                             // 解析参数，主要通过fs_context->ops->parse_xxx()回调函数进行
        vfs_get_tree                                    // 调用fs_context->ops->get_tree()来设置fc->root(struct dentry)，找到了dentry，其实就是找到了superblock(dentry->d_sb == superblock)
        do_new_mount_fc                                 // 进行真正的mount操作，设置mount结构体等的父子层次关系
      path_put() 
```

## chown/fchownat/chmod/fchmodat

```c
__sys_chown/__sys_fchownat
  do_fchmodat
    user_path_at
    chmod_common
      notify_change
        ext4_setattr/xfs_vn_setattr
          setattr_prepare
```

## setfacl/setfattr

设置acl和拓展属性都是通过setxattr()系统调用完成的：

```c
__sys_setxattr
  path_setxattr
    user_path_at
      user_path_at_empty
        filename_lookup
          path_lookupat
            path_init
            link_path_walk
              may_lookup
                inode_permission
                  sb_permission
                  do_inode_permission
                    acl_permission_check
                    capable_wrt_inode_uidgid(CAP_DAC_READ_SEARCH)
                    capable_wrt_inode_uidgid(CAP_DAC_OVERRIDE)
                  devcgroup_inode_permission
                  security_inode_permission
            trailing_symlink
            lookup_last
    setxattr
      cap_convert_nscap                 // security.capability 要求有CAP_SETFCAP
      vfs_setxattr
        inode_lock
        __vfs_setxattr_locked
          xattr_permission
            security./system. 两个不受限制  // ACL: system.posix_acl_access
            trusted. 需要CAP_SYS_ADMIN
            inode_permisskkkkion
          security_inode_setxattr
            cap_inode_setxattr          // security. 要求有CAP_SYS_ADMIN  (除security.capability)
              ns_capable(CAP_SYS_ADMIN)
                ns_capable_common
                  security_capable      // selinux_capable
          __vfs_setxattr_noperm
            __vfs_setxattr              // 要注意，对于setfattr中的ext4_xattr_handler_map，EXT4_XATTR_INDEX_POSIX_ACL_ACCESS，要求inode_owner_or_capable!!!
                                        // security. 不做特别检查，因为前面已经检查过了
        inode_unlock
```

## syncfs

```c
sync_filesystem(sb)
  __sync_filesystem(nowait)
  __sync_filesystem(wait)
    if (wait)
      sync_inodes_sb                         // 写回inode并等待
    else
      writeback_inodes_sb(WB_REASON_SYNC)    // 写回inode，只submit_bio，不等待
    sb->s_op->sync_fs()
    __sync_blockdev
```

```c
writeback_inodes_sb
  writeback_inodes_sb_nr
    __writeback_inodes_sb_nr                                        // 回写特定super_block下的inode
      make struct wb_writeback_work
      bdi_split_work_to_wbs
        foreach bdi_writeback in backing_dev_info->wb_list          // 每个memcg对应一个bdi_writeback
          wb_split_bdi_pages                                        // 根据memcg的带宽领取对应份额的page
          make struct wb_writeback_work                             // 生成子work，并设置自动释放
          wb_queue_work
            atomic_inc(done->cnt)                                   // 增加done->cnt，表示有一个wb_writeback_work正在queue_work()中
            spin_lock_bh(bdi_writeback->work_lock)
            list_add_tail(&wb_writeback_work->list, &bdi_writeback->work_list)    // 这是工作材料，放到这里，后续由worker_pool中的worker来取出处理
            mod_delayed_work(bdi_wq, wb_workfn)                     // 某个时间后被workqueue调用，这是工作流程
            spin_unlock_bh(bdi_writeback->work_lock)
      wb_wait_for_completion(&wb_write_work.done)                   // 等待done->cnt变为0
```

下面的路径在工作队列中执行：

```c
wb_workfn                                                           // 以各种姿势调用__writeback_inodes_wb()
  -wb_do_writeback                                                  // normal path
    wb_writeback
      queue_io
      writeback_sb_inodes
        make writeback_control
        __writeback_single_inode
          do_writepages
            address_space->a_ops->writepages
              write_cache_pages 5.x / iomap_writepages 6.x          // 针对特定inode开始flush pagecache
    wb_check_start_all                                              // 检查是否需要sync all
    wb_check_old_data_flush                                         // 检查是否需要周期性回写
    wb_check_background_flush                                       // 检查background回写是否需要继续
  -writeback_inodes_wb                                              // corner case，没有足够的worker了，同步处理
    wb_writeback_work.range_cyclic = 1
    __writeback_inodes_wb
      writeback_sb_inodes                                           // 写bdi_writeback->b_io上的一些inodes
```

## sync

```cag-0-1idj5p0niag-1-1idj5p0niag-0-1idj5p0niag-1-1idj5p0niag-0-1idj5p0niag-1-1idj5p0ni
ksys_sync
  wakeup_flusher_threads(WB_REASON_SYNC)
  iterate_supers(sync_inodes_one_sb, NULL)
  iterate_supers(sync_fs_one_sb, &nowait)
  iterate_supers(sync_fs_one_sb, &wait)
  iterate_bdevs(fdatawrite_one_bdev, NULL)
  iterate_bdevs(fdatawait_one_bdev, NULL)  
```

## readahead

5.4内核：

```c
generic_file_buffered_read
  find_get_page
  page_cache_sync_readahead
  page_cache_async_readahead
  wait_on_page_locked_killable
```

## 几个重要哈希表

- mountpoint_hashtable
  
  - 元素是struct mountpoint
  
  - 哈希是挂载点dentry
  
  - 参见`get_mountpoint()`

- mount_hashtable
  
  - 元素是struct mount
  
  - 哈希是{parent mount, mountpoint dentry}
  
  - 参见`attach_mnt()`

- dentry_hashtable

- inode_hashtable

## 关于inode.i_rwsem

在v6.6中：

|                  | xfs                       | ext4                                                 | bcachefs  |
| ---------------- | ------------------------- | ---------------------------------------------------- | --------- |
| **buffer read**  | shared                    | -                                                    |           |
| **buffer write** | exculsive                 | exclusive                                            | exclusive |
| **direct read**  | shared                    | shared                                               |           |
| **direct write** | 对齐时为shared；未对齐时为exculsive | 尺寸变更时为exclusive；尺寸未变更时为shared；尺寸未变更，但非对齐时也用exclusive | exclusive |
