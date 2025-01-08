# xfs_inode分配 - 磁盘

```c
xfs_dir_ialloc
  xfs_ialloc(&ialloc_context, &ip)            // 如果分配不到ip，则返回AGI
    xfs_dialloc
  xfs_trans_bhold(ialloc_context)
  xfs_trans_roll                              // 里面的iop_committing中，hold发挥抑制xfs_buf_relse()的作用后便失效
  xfs_trans_bjoin
  xfs_ialloc(&ialloc_context, &ip)            // 第二次肯定可以分配到ip
    xfs_dialloc
    xfs_iget
      xfs_iget_cache_miss                     // 这里肯定是cache miss的
```

# xfs_inode删除 - 磁盘

```c
xfs_inactive
  xfs_inactive_symlink                        // 删除xfs_inode在磁盘上的数据
  xfs_inactive_truncate                       // 删除xfs_inode在磁盘上的数据
  xfs_inactive_ifree                          // 删除磁盘上xfs_inode本身
    xfs_trans_alloc
    xfs_ilock(XFS_ILOCK_EXCL)
    xfs_trans_ijoin
    xfs_ifree
      xfs_iunlink_remove                      // xfs_ifree()处理的xfs_inode已经被vfs_remove()在放入了unlinked list
      xfs_difree                              // 操作AGI
    xfs_trans_commit
```
