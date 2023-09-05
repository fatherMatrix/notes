# xfs

## 外存数据结构

### xfs_sb_t - superblock - 1 sector

### xfs_agf_t - AG free block info - 1 sector

xfs使用两棵树来跟踪空闲空间：
- 以block number为键值
- 以size为键值

xfs_agf_t中的block numbers/indexes/counts都是AG relative的。

### xfs_agi_t - AG inode B+tree info - 1 sector

### xfs_agfl_t - AG internal free list - 1 sector

## 内存数据结构

### xfs_sb_t

xfs超级块的内存数据结构和外存是一致的。

### xfs_

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