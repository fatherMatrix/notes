# SELinux

## may_open

```c
may_open
  inode_permission
    security_inode_permission
      selinux_inode_permission
        avc_has_perm_noaudit
```