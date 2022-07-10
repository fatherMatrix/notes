# VFS

## inode

```
#define S_IFMT  00170000                                // 共18位，2进制为001 111 000 000 000 000
#define S_IFSOCK 0140000                                // Socket
#define S_IFLNK  0120000                                // 符号链接
#define S_IFREG  0100000                                // 正规文件
#define S_IFBLK  0060000                                // 块设备文件
#define S_IFDIR  0040000                                // 目录
#define S_IFCHR  0020000                                // 字符设备文件
#define S_IFIFO  0010000                                // fifo
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

```
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
          may_open                                      // 检查权限
            inode_permission                            // 对inode中保存的权限进行检查，包括UGO和ACL
          vfs_open
        terminate_walk(nd)
      restore_nameidata
    fd_install
```

## mount

```
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
