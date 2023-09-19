# devtmpfs

即/dev目录所挂载的文件系统

## 初始化

```c
devtmpfs_init
  mnt = vfs_kern_mount(&internal_fs_type, 0, "devtmpfs", opts)      // 先挂载一个internal_fs_type文件系统
  register_filesystem(&dev_fs_type)                                 // dev_fs_type中的mount()方法不再执行真正的挂载动作，仅返回上面挂载的mnt.sb即可
  kthread_run(devtmpfs, &err, "kdevtmpfs")                          // 该内核线程负责
```

## 几个关键点

### 根目录的产生：

```c
shmem_get_tree
  get_tree_nodev
    shmem_fill_super
      shmem_get_inode                           // 其实后续产生新的inode也是要靠shmem_get_inode()，其中会调用init_special_inode()
```

### devtmpfs到bdevfs的转换

```c
vfs_open
  do_dentry_open
    file->f_mapping = inode->i_mapping          // 这里直接复制inode中的address_space指针；
                                                // - 理论上，设备文件的devtmpfs inode->i_mapping应该指向bdevfs inode的i_mapping(&bdevfs inode.i_data），但到这里的时候这件事还未发生；
                                                // - devtmpfs inode->i_mapping设置为bdevfs inode->i_mapping字段发生在：blkdev_open() -> bd_acquire()中；
                                                // - file->f_mapping的设置在blkdev_open()中的bd_acquire()之后，直接拷贝devtmpfs inode->i_mapping，此时devtmpfs inode->i_mapping已经是&bdevfs inode->i_data了；
    file->f_op = fops_get(inode->i_fops)
    file->f_op->open()/blkdev_open()            // 此处对应的是blkdev_open()
      bd_acquire
        inode->i_mapping = bdev->bd_inode->i_mapping
      file->f_mapping = bdev->bd_inode->i_mapping
```


## mknod例子

```
[root@VM-0-41-tencentos ~]# stap ./a.stp
rbp=0xffffc900008afe38
 0xffffffff812bdb30 : init_special_inode+0x0/0x60 [kernel]
 0xffffffff8120cd9c : shmem_get_inode+0x16c/0x220 [kernel]
 0xffffffff8120cf1b : shmem_mknod+0x2b/0xe0 [kernel]
 0xffffffff812aece1 : vfs_mknod+0x191/0x250 [kernel]
 0xffffffff812b2722 : do_mknodat+0x202/0x210 [kernel]
 0xffffffff812b278f : __x64_sys_mknod+0x1f/0x30 [kernel]
 0xffffffff810025cd : do_syscall_64+0x4d/0x150 [kernel]
 0xffffffff81e0008c : entry_SYSCALL_64_after_hwframe+0x44/0xa9 [kernel]
 0xffffffff81e0008c : entry_SYSCALL_64_after_hwframe+0x44/0xa9 [kernel]
```