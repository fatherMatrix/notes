# xfs_fsr

针对某个文件的情况

```c
main
  if (optind < argc)
    lstat(argname, &sb)                    // 获取文件
    fsrdir                                 // 如果是目录
    fsrfile                                // 如果是文件
```
