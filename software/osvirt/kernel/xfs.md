# xfs

## 日志外存布局

```

```

## 数据结构

### 超级块

#### 外存数据结构

xfs_sb_t - superblock - 1 sector

#### 内存数据结构

xfs_sb_t - xfs_mount.m_sb

超级块在内存和外存上都是一致的数据结构；

### 空闲磁盘块

#### 外存数据结构

xfs_agf_t - AG free block info - 1 sector

xfs使用两棵树来跟踪空闲空间：
- 以block number为键值
- 以size为键值

xfs_agf_t中的block numbers/indexes/counts都是AG relative的。

#### 内存数据结构

### 索引节点表

#### 外存数据结构 

xfs_agi_t - AG inode B+tree info - 1 sector

### 内部空闲链表

#### 外存数据结构

xfs_agfl_t - AG internal free list - 1 sector

### Log item

#### 外存数据结构

#### 内存数据结构

xfs_log_item

## 虚拟文件系统数据结构

|      | file_operations         | inode_operations         |
| ---- | ----------------------- | ------------------------ |
| file | xfs_file_operations     | xfs_inode_operations     |
| dir  | xfs_dir_file_operations | xfs_dir_inode_operations |

### write

```c

```

### write_inode_now

```c

```

## 事务

事务整体流程：

```
xfs_trans_alloc                 // 分配一个事务
xfs_trans_ijoin                 // 关联inode节点，此处是以xfs_fs_dirty_inode()为例 
  xfs_trans_add_item
xfs_trans_log_xxx
xfs_trans_commit                // 事务提交
```

### xfs_tran_alloc()

```
xfs_trans_alloc
  tp = kmem_zone_zalloc         // 分配xfs_trans结构体，内部清零
  初始化tp
  xfs_trans_reserve             // 预留事务所需空间 
```