# InnoDB

## 后台线程

### Master Thread

主要负责将缓冲池中的数据异步刷新到磁盘，保证数据的一致性。包括：

- 脏页的刷新

- Insert Buffer刷新

- Undo Page回收

- ... ...

### IO Thread

主要用来处理异步IO的回调，包括：

- Insert Buffer Thread

- Log Thread

- Read Thread

- Write Thread

- ... ...

### Purge Thread

事务被提交以后，其所使用的Undo Log可能不再需要，Purge Thread用于回收已经使用并分配的Undo Page。

### Page Cleaner Thread

InnoDB 1.2.x引入，将Master Thread中负责的脏页刷新操作都放入到单独的线程中来完成。

## 内存缓冲池

### 索引页

### 数据页

### Undo Page

### Insert Buffer Page

### Adaptive Hash Index Page

### Lock Info

### Data Dictionary Page

## 页链表

### LRU List

- 每个元素16KB

- 新申请的页不会放到List Head，而是有个Mid Position

### Free List

？

### FLush List

- 被写过的页

- 在Flush List中存在的页同时也在LRU List中存在

## Redo Log Buffer

InnodDB首先将Redo Log日志信息放入到Redo Log Buffer，然后按一定频率将其刷新到Rego Log File。

- Redo Log Buffer一般不需要设置特别大，因为每秒都会将其刷出

- Redo Log的作用是？

## Checkpoint机制

InnoDB采用Write Ahead Log策略，当事务提交时，先写Redo Log，再修改Page。当系统发生宕机时，通过Redo Log完成数据的恢复。

但是，Redo Log不能无限增长，需要在合适、必要的时候截断Redo Log，此机制即Checkpoint机制。

## 核心特性

### 插入缓冲

#### Insert Buffer

InnoDB中没张表都有一个聚集索引和若干个非聚集索引。

每次插入record时，修改聚集索引的操作一般来说都是顺序的，不需要磁盘的随机读取。但非聚集索引的更新则涉及到随机IO，因此应该避免对非聚集索引的高频更新。

所谓Insert Buffer即对于非聚集索引的更新操作先记录在Insert Buffer Object中，等合适的时机或者频率再合并（插入）到非聚集索引中。但这是有要求的：

- 仅限于非聚集索引

- 索引键不是unique，因为非unique键值我们可以任意插入，而无需读取非聚集索引后验证插入数据的唯一性。

#### Change Buffer

Insert Buffer的升级版，除了Insert操作外，还可以以相同的机制处理Delete、Update等操作。

### 两次写

主要用来解决部分写失效问题（partial page write）。不论是Undo Log、Redo Log还是两者结合，都需要一个基准Page，并以此为基准apply Undo/Redo Log。如果这个基准Page都是有问题的，则一切都是错误的了。

Double Write用来保证16KB的page是完整的。

### 自适应哈希索引

### 异步IO

### 刷新邻接页

## 常见日志文件

### Error Log

### Bin Log

Bin Log记录了对InnoDB进行更改的所有操作，不包括select、show等对数据库无影响的操作。该日志是逻辑日志，主要用途为：

- 恢复

- 复制

- 审计

### Slow Query Log

### Query Log

## 锁

### 一致性非锁定读

Consistent Nonlocking Read是指InnoDB通过行多版本控制的方式来读取当前执行时间数据库中行的数据。如果读取的行正在执行DELETE或UPDATE操作，这时读取操作不会因此去等待行上锁的释放。相反地，InnoDB会去读取行的一个快照数据。

快照数据是指该行之前版本的数据，该机制是通过Undo段来完成，而Undo用来在事务中回滚数据，因此快照数据本身是没有额外空间开销的。

一致性非锁定读在不同隔离级别下有不同的版本要求：

- Read Committed：读取被锁定行的最新一份快照

- Repeatable Read：读取事务开始时的行数据版本

## 事务实现

### Redo Log和Undo Log

InnoDB中的“重做日志”实际上是由Redo Log和Undo Log两部分组成。

- Redo用来保证事务的持久性，Undo用来帮助事务回滚及MVCC功能。

- Redo通常是物理日志，Undo通常是逻辑日志。

- Redo基本上都是顺序写，且在数据库正常运行时无读取操作；而Undo是需要随机读的。

为确保每次日志都写入重做日志文件，在每次将重做日志缓冲写入重做日志文件后，InnoDB都需要调用一次fsync操作。由于重做日志文件没有使用O_DIRECT选项，因此重做日志缓冲先写入文件系统缓存。

重做日志都是以log block（512字节）进行存储的，与磁盘扇区相同，因此无需double write。
