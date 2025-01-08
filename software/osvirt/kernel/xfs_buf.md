# xfs_buf分析

## 分配

```c
xfs_buf_read_map(ops)
  xfs_buf_get_map
  xfs_buf->b_ops = ops
  _xfs_buf_read
```

## 释放

两个重点函数：

- xfs_buf_rele()
  
  - Release a hold on the specified buffer. If the hold count is 1, the buffer is placed on LRU or freed (depending on b_lru_ref).

- xfs_buf_relse()
  
  - xfs_buf_unlock() + xfs_buf_rele()

核心实现：

```c
xfs_buf_rele
```
