# kernfs

`kernfs`是在`sysfs`中剥离出来的用于处理vfs层交互的部分，其也被应用到`cgroupfs`中。

`kernfs`没有通过`register_filesystem(&file_system_type)`进行过文件系统类型注册，只是一个搭建文件系统的部件。

# sysfs

## 初始化

```c
start_kernel
  vfs_caches_init
    mnt_init
      kernfs_init
      sysfs_init
        sysfs_root = kernfs_create_root(syscall_ops = NULL)
          kernfs_node = __kernfs_new_node()                     // 这里并没有创建inode，inode的创建是在kernfs_get_inode()中通过iget_lock()无条件创建；
                                                                // kernfs_root是在挂载时调用kernfs_get_inode()以生成vfs inode
        sysfs_root_kn = sysfs_root->kernfs_node
        register_fielsystem(sysfs_fs_type)
      kobject_create_and_add("fs", NULL)                        // 创建目录/sys/fs/
```

## 挂载

```c
static struct file_system_type sysfs_fs_type = {
    .name            = "sysfs",
    .init_fs_context    = sysfs_init_fs_context,
    .kill_sb        = sysfs_kill_sb,
    .fs_flags        = FS_USERNS_MOUNT,
}; 


sysfs_init_fs_context
  kernfs_fs_context kfc = kzalloc
  kfc->root = sysfs_root
  fs_context->fs_private = kfc
  fs_context->ops = &sysfs_fs_context_ops


static const struct fs_context_operations sysfs_fs_context_ops = {
    .free        = sysfs_fs_context_free,
    .get_tree    = sysfs_get_tree,
};


sysfs_get_tree
  kernfs_get_tree
    kernfs_fill_super
      sb->s_ops = &kernfs_sops
      sb->s_xattr = &kernfs_xattr_handlers
      down_read(kernfs_root->kernfs_rwsem)
      inode = kernfs_get_inode()                                                // 配置本文件系统的根目录
        inode = iget_locked()                                                   // 无条件分配一个vfs inode
        kernfs_init_inode                                                       // 会配置该inode的vfs操作方法
      up_read(kernfs_root->kernfs_rwsem)
      d_make_root(inode)
      sb->s_d_op = &kernfs_dops
```

关注一下kernfs_init_inode()：

```c
static void kernfs_init_inode(struct kernfs_node *kn, struct inode *inode)
{
    kernfs_get(kn);
    inode->i_private = kn;
    inode->i_mapping->a_ops = &ram_aops;
    inode->i_op = &kernfs_iops;
    inode->i_generation = kernfs_gen(kn);

    set_default_inode_attr(inode, kn->mode);
    kernfs_refresh_inode(kn, inode);

    /* initialize inode according to type */
    switch (kernfs_type(kn)) {
    case KERNFS_DIR:
        inode->i_op = &kernfs_dir_iops;
        inode->i_fop = &kernfs_dir_fops;
        if (kn->flags & KERNFS_EMPTY_DIR)
            make_empty_dir_inode(inode);
        break;
    case KERNFS_FILE:
        inode->i_size = kn->attr.size;
        inode->i_fop = &kernfs_file_fops;
        break;
    case KERNFS_LINK:
        inode->i_op = &kernfs_symlink_iops;
        break;
    default:
        BUG();
    }

    unlock_new_inode(inode);
}
```

## 文件相关

### sysfs文件的vfs层接口

```c
const struct file_operations kernfs_file_fops = {
    .read_iter    = kernfs_fop_read_iter,
    .write_iter    = kernfs_fop_write_iter,
    .llseek        = kernfs_fop_llseek,
    .mmap        = kernfs_fop_mmap,
    .open        = kernfs_fop_open,
    .release    = kernfs_fop_release,
    .poll        = kernfs_fop_poll,
    .fsync        = noop_fsync,
    .splice_read    = copy_splice_read,
    .splice_write    = iter_file_splice_write,
};
```

### sysfs文件的创建

文件创建路径，以`/sys/fs/ext4/features/*`为例：

```c
// 这里是静态属性，生命周期与kobject相同
// 静态属性会放入kobject->kobj_type中
ext4_init_sysfs
  kobject_init_and_add(ext4_feat, &ext4_feat_ktype, ext4_root, "features")
    kobject_init(kobj, kobj_type)                                                // 将kobj_type设置给kobject
    kobject_add_varg
      kobject_add_internal
        create_dir
          sysfs_create_dir_ns
          sysfs_create_groups                                                    // 如果有kobj_type的话，有这个表明这个kobject有attribute
            internal_create_groups
              internal_create_group
                create_files
                  sysfs_add_file_mode_ns ---------------------------------------------
                    kobject->kobj_type->sysfs_ops = ...                          // 根据不同情况设置不同的sysfs_ops
                    __kernfs_create_file
                      kernfs_node = kernfs_new_node(sysfs_ops)
                        kernfs_node.attr.ops = sysfs_ops                         // 这里确认了是文件而不是目录，所以可以直接使用attr
                      kernfs_add_one
                        kernfs_link_sibling                                      // 将这个kernfs_node链入目录kobject->kernfs_node->dir中的红黑树中
// 直到这一步，还没有vfs inode产生，更没有inode_operations的设置！！！！！！！！！！
//             ^^^                ^^^
```

或者，还有个更直接的：

```c
// 这里是动态属性，可通过sysfs_remove_files()动态删除
// 动态属性不会放入kobj_type中，仅通过kernfs的kernfs_node链入kobject->kernfs_node->dir->children的红黑树
sysfs_create_files
  sysfs_create_file
    sysfs_create_file_ns
      sysfs_add_file_mode_ns    -------------------------------------------------------
```

### sysfs文件的查找

应该需要从kernfs_root开始，根据挂载时的情况，这里会从`kernfs_dir_iops->kernfs_iop_lookup()`开始：

```c
kernfs_iop_lookup
  kernfs_root = kernfs_root()
  kernfs_node = kernfs_find_ns(parent, name)
  kernfs_get_inode                                                                // 这一步才正式生成vfs inode
    iget_locked()
    kernfs_init_inode                                                             // 参见挂载一节
  
```

### sysfs文件的读写

以`.read_iter`为例，可以看到`kernfs`和`seq_file`相关性很强：

```c
static struct kernfs_open_file *kernfs_of(struct file *file)
{
    return ((struct seq_file *)file->private_data)->private;
}

static ssize_t kernfs_fop_read_iter(struct kiocb *iocb, struct iov_iter *iter)
{
    if (kernfs_of(iocb->ki_filp)->kn->flags & KERNFS_HAS_SEQ_SHOW)
        return seq_read_iter(iocb, iter);
    return kernfs_file_read_iter(iocb, iter);
}
```

`kernfs`和`seq_file`是如何关联起来的？`struct file`中的很多内容都是在`vfs_open()`中装配的，所以肯定要看其对应实现：

```c
kernfs_fop_open
  ... 
  seq_open
    
```



## 目录相关

```c
sysfs_create_dir_ns
```

## 
