# Cgroup

## 初始化

```c
start_kernel
  cgroup_init
    cgroup_init_cftypes(NULL, cgroup_base_files)
    cgroup_init_cftypes(NULL, cgroup1_base_files)

    cgroup_setup_root
      cgroup_root->kf_root = kernfs_create_root()                            // 里面会配置支持cgroupfs的文件系统接口
```

## mkdir
