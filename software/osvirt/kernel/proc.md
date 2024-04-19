# procfs

## 初始化

```c
start_kernel
  proc_root_init
    ... ...
    proc_self_init(&self_inum)                          // 初始化self_inum全局起始ino
      proc_alloc_inum
        ida_simple_get
    proc_thread_self_init                               // 初始化thread_self_inum全局起始ino
    proc_sys_init
    register_filesystem(&proc_fs_type)
```

## /proc根inode

```c
struct proc_dir_entry proc_root = { 
        .low_ino        = PROC_ROOT_INO, 
        .namelen        = 5,  
        .mode           = S_IFDIR | S_IRUGO | S_IXUGO, 
        .nlink          = 2,  
        .refcnt         = REFCOUNT_INIT(1),
        .proc_iops      = &proc_root_inode_operations, 
        .proc_fops      = &proc_root_operations,
        .parent         = &proc_root,
        .subdir         = RB_ROOT,
        .name           = "/proc",
};
```

## 创建目录/文件

```c
proc_mkdir
  proc_mkdir_data
    _proc_mkdir
      ent = __proc_create                               // 创建proc_dir_entry
        xlate_proc_name
        ent->proc_dops = &proc_misc_dentry_ops
      ent->data = data
      ent->proc_fops = &proc_dir_operations
      ent->proc_iops = &proc_dir_inode_operations
      proc_register(dir, dp)                            // dir和dp都是proc_dir_entry指针
        proc_alloc_inum(&dp->low_ino)
        write_lock(&proc_subdir_lock)
        dp->parent = dir
        pde_subdir_insert(dir, dp)
        dir->nlink++
        write_unlock(&proc_subdir_lock)
```

## 挂载操作

```c
proc_fill_super
  s->s_op = &proc_sops

```