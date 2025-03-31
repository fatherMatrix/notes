# 可能的优化点

- xfs: avoid redundant AGFL buffer invalidation

- xfs: lockless buffer cache lookups

- xfs: avoid cil push lock if possible

- [00/30] xfs: rework inode flushing to make inode reclaim fully asynchronous - 2020.06
  [RFC,00/24] mm, xfs: non-blocking inode reclaim - 2020.03

- block: cache current nsec time in struct blk_plug

- jbd2: remove unused t_handle_lock

- jbd2: kill t_handle_lock transaction spinlock

# 急需研究的patch：

- xfs: don't use BMBT btree split workers for IO completion

- xfs: per-ag centric allocation alogrithms [PATCHSET]

- Fast commits for ext4

- ext4: Fix race when reusing xattr blocks

- xfs bufferio锁减少
  
  - https://lore.kernel.org/linux-xfs/Z4grgXw2iw0lgKqD@dread.disaster.area/#R
  
  - https://lore.kernel.org/linux-fsdevel/20190407232728.GF26298@dastard/

- 社区版xfs 16K原子写
  
  - https://lore.kernel.org/linux-xfs/20250303171120.2837067-1-john.g.garry@oracle.com/T/#ma683955be4cef0ea37b158396b03b704780b39f8

- 硬件16K原子写
  
  - https://lwn.net/Articles/1009298/

# 需要学习的特性：

- arm64 sdei，弥补没有nmi中断时的perf采样

- jbd2: fix hung processes in jbd2_journal_lock_updates()

- jbd2: fix deadlock while checkpoint thread waits commit thread to finish

- ext4: avoid lockdep warning when inheriting encryption context *
