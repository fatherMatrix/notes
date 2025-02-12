<style></style>

# xfs-农行-0306-根因排查-更新版

# Step1 - mysqld-69972为什么拿不到写锁？

## 结论

mysqld-69972试图创建文件/data1/tdengine/log/4006/dblogs/bin/binlog.index，此时需要获取目录/data1/tdengine/log/4006/dblogs/bin/的写锁。

mysqlreport-116700在遍历目录/data1/tdengine/log/4006/dblogs/bin/下的文件，此时持有该目录的读锁，导致写端获取不到写锁。

## 分析

mysqlreport-116700唤醒mysqld-69972的栈

mysqlreport-116700 [047] .... 679403.932092: hook_symbol4: wakeup task: waker comm=mysqlreport pid=116700, tgid=116616, wakee comm=mysqld pid=69972 wakee state=2 latency=32037737

mysqlreport-116700 [047] .... 679403.932093: <stack trace>

=> hook_symbol4

=> aggr_pre_handler

=> kprobe_ftrace_handler

=> ftrace_ops_assist_func

=> 0xffffffffa00260da

=> try_to_wake_up

=> rwsem_wake.isra.10

=> up_read

=> lookup_slow

=> walk_component

=> path_lookupat.isra.62

=> filename_lookup.part.78

=> user_path_at_empty

=> vfs_statx

=> __do_sys_newlstat

=> __x64_sys_newlstat

=> do_syscall_64

=> entry_SYSCALL_64_after_hwframe

mysqld-69972被唤醒后第一次上cpu运行时的栈

mysqld-69972 [019] d... 679403.932104: hook_symbol1: task_switch: prev=swapper/19 next=mysqld next pid=69972 prev pid=0, prev stat=0, next stat=0, offcpu time=32037747

mysqld-69972 [019] d... 679403.932109: <stack trace>

=> hook_symbol1

=> aggr_pre_handler

=> kprobe_ftrace_handler

=> ftrace_ops_assist_func

=> 0xffffffffa00260da

=> finish_task_switch

=> schedule

=> rwsem_down_write_slowpath

=> down_write

=> path_openat

=> do_filp_open

=> [unknown/kretprobe'd]

=> __x64_sys_open

=> do_syscall_64

=> entry_SYSCALL_64_after_hwframe

... ...

mysqld-69972 [020] d... 679403.933075: ____exit: open /data1/tdengine/log/4006/dblogs/bin/binlog.index lat:32038 comm:mysqld

上述两个栈说明：mysqlreport-116700持有目录读锁一段时间后释放读锁，并唤醒对应写者mysqld-69972；mysqld-69972试图获取目录写锁失败，导致睡眠，并在约32秒后被唤醒并重新调度。调度后open(/data1/tdengine/log/4006/dblogs/bin/binlog.index, O_CREAT)立即返回。

# Step2 - 拿了读锁的mysqlreport-116700在做什么？

## 结论

mysqlreport-116700与mysqlreport-116733同时读取bin目录下某一文件的元数据，此时IO操作交由mysqlreport-116733承担，mysqlreport-116700等待其IO完成。

## 分析

mysqlreport-116733唤醒mysqlreport-116700的栈

mysqlreport-116733 [020] d... 679403.932066: hook_symbol4: wakeup task: waker comm=mysqlreport pid=116733, tgid=116616, wakee comm=mysqlreport pid=116700 wakee state=2 latency=49221598

mysqlreport-116733 [020] d... 679403.932073: <stack trace>

=> hook_symbol4

=> aggr_pre_handler

=> kprobe_ftrace_handler

=> ftrace_ops_assist_func

=> 0xffffffffa00260da

=> try_to_wake_up

=> __wake_up_common

=> __wake_up_common_lock

=> __wake_up

=> __d_lookup_done

=> d_splice_alias

=> xfs_vn_lookup

=> __lookup_slow

=> lookup_slow

=> walk_component

=> path_lookupat.isra.62

=> filename_lookup.part.78

=> user_path_at_empty

=> vfs_statx

=> __do_sys_newlstat

=> __x64_sys_newlstat

=> do_syscall_64

=> entry_SYSCALL_64_after_hwframe

mysqlreport-116700被唤醒之后第一次上cpu运行时的栈：

mysqlreport-116700 [047] d... 679403.932080: hook_symbol1: task_switch: prev=swapper/47 next=mysqlreport next pid=116700 prev pid=0, prev stat=0, next stat=0, offcpu time=49221612

mysqlreport-116700 [047] d... 679403.932085: <stack trace>

=> hook_symbol1

=> aggr_pre_handler

=> kprobe_ftrace_handler

=> ftrace_ops_assist_func

=> 0xffffffffa00260da

=> finish_task_switch

=> schedule

=> d_alloc_parallel

=> __lookup_slow

=> lookup_slow

=> walk_component

=> path_lookupat.isra.62

=> filename_lookup.part.78

=> user_path_at_empty

=> vfs_statx

=> __do_sys_newlstat

=> __x64_sys_newlstat

=> do_syscall_64

=> entry_SYSCALL_64_after_hwframe

上述两个栈说明：mysqlreport-116700无法释放bin目录的读锁是因为其在等待mysqlreport-116733的lookup操作完成。mysqlreport-116733完成IO后通过d_lookup_done()唤醒在d_alloc_paralle()中睡眠的mysqlreport-116700。

# Step3 - mysqlreport-116733在做什么？

## 结论

而mysqlreport-116733的IO动作xfs_vn_lookup() -> xfs_iget()一直处于xfs_iget_cache_hit() -> igrab() -> delay()的循环中，该循环的主要作用是等待被标记了I_FREEING且未标记XFS_IRECLAIMABLE的xfs_inode被回收，从而用于承接从磁盘上读出的元数据。xfs_inode被标记为I_FREEING说明该inode正处于回收的开始阶段。

## 分析

mysqlreport-116733 [026] .... 679354.318488: xfs_lookup: dev 9:0 dp ino 0x36000046e name binlog.008008

mysqlreport-116733 [026] d... 679354.318492: return_xfs_lookup: (xfs_vn_lookup+0x70/0xa0 [xfs] <- xfs_lookup)

mysqlreport-116733 [026] .... 679354.318495: xfs_lookup: dev 9:0 dp ino 0x36000046e name binlog.008009

mysqlreport-116733 [026] d... 679354.318500: return_xfs_lookup: (xfs_vn_lookup+0x70/0xa0 [xfs] <- xfs_lookup)

mysqlreport-116733 [026] .... 679354.318503: xfs_lookup: dev 9:0 dp ino 0x36000046e name binlog.008010

mysqlreport-116733 [026] d... 679354.318507: igrab: (xfs_iget+0x34e/0xa10 [xfs] <- igrab) comm="mysqlreport" ret=0x0

mysqlreport-116733 [026] .... 679354.318508: xfs_iget_skip: dev 9:0 ino 0x360015809

mysqlreport-116733 [026] .... 679354.318509: p1: (schedule_timeout_uninterruptible+0x0/0x30) comm="mysqlreport"

mysqlreport-116733 [026] d... 679354.320327: igrab: (xfs_iget+0x34e/0xa10 [xfs] <- igrab) comm="mysqlreport" ret=0x0

mysqlreport-116733 [026] .... 679354.320328: xfs_iget_skip: dev 9:0 ino 0x360015809

mysqlreport-116733 [026] .... 679354.320329: p1: (schedule_timeout_uninterruptible+0x0/0x30) comm="mysqlreport"

mysqlreport-116733 [026] d... 679354.322328: igrab: (xfs_iget+0x34e/0xa10 [xfs] <- igrab) comm="mysqlreport" ret=0x0

mysqlreport-116733 [026] .... 679354.322329: xfs_iget_skip: dev 9:0 ino 0x360015809

mysqlreport-116733 [026] .... 679354.322330: p1: (schedule_timeout_uninterruptible+0x0/0x30) comm="mysqlreport"

mysqlreport-116733 [026] d... 679354.324329: igrab: (xfs_iget+0x34e/0xa10 [xfs] <- igrab) comm="mysqlreport" ret=0x0

mysqlreport-116733 [026] .... 679354.324330: xfs_iget_skip: dev 9:0 ino 0x360015809

mysqlreport-116733 [026] .... 679354.324330: p1: (schedule_timeout_uninterruptible+0x0/0x30) comm="mysqlreport"

说明mysqlreport-116733在持有目录读锁的情况下依次遍历binlog文件，并在某些文件（例如binlog.008010）上发生了xfs_iget_cache_hit() -> igrab() -> delay()循环。

# Step4 - 为什么I_FREEING标记保持了这么久？

## 结论

内存不足导致触发inode cache回收，但inode cache回收时采用的策略是批回收。对于一批inode，首先依次标记其为I_FREEING，然后依次回收内存。回收内存的动作当中包含了潜在的元数据回写/page的清除/page的unmap等，会产生一定的耗时。当本批次inode数量较多时，时间会累积，可能导致某个inode从被标记为I_FREEING到完成释放（或被xfs标记为XFS_IRECLAIMABLE）中间间隔过大。该问题在所有文件系统中都存在，但xfs中时间窗口更大一些。

## 分析

mysqlreport-116733 [026] .... 679354.318488: xfs_lookup: dev 9:0 dp ino 0x36000046e name binlog.008008

mysqlreport-116733 [026] d... 679354.318492: return_xfs_lookup: (xfs_vn_lookup+0x70/0xa0 [xfs] <- xfs_lookup)

mysqlreport-116733 [026] .... 679354.318495: xfs_lookup: dev 9:0 dp ino 0x36000046e name binlog.008009

eat1Gmem-70337 [017] .... 679354.318497: prune_icache_sb_p: (prune_icache_sb+0x0/0x80) comm="eat1Gmem"

mysqlreport-116733 [026] .... 679354.318503: xfs_lookup: dev 9:0 dp ino 0x36000046e name binlog.008010

... ...

mysqlreport-116733 [020] d... 679403.930051: igrab: (xfs_iget+0x34e/0xa10 [xfs] <- igrab) comm="mysqlreport" ret=0x0

mysqlreport-116733 [020] .... 679403.930054: xfs_iget_skip: dev 9:0 ino 0x360015809

mysqlreport-116733 [020] .... 679403.930054: p1: (schedule_timeout_uninterruptible+0x0/0x30) comm="mysqlreport"

... ...

eat1Gmem-70337 [037] d... 679403.930118: prune_icache_sb: (super_cache_scan+0x128/0x1a0 <- prune_icache_sb) comm="eat1Gmem" ret=0xc3

... ...

mysqlreport-116733 [020] d... 679403.932063: return_xfs_lookup: (xfs_vn_lookup+0x70/0xa0 [xfs] <- xfs_lookup)

上述trace记录表示，在mysqlreport-116733读取binlog.008010时遭遇了inode cache回收，且目标inode刚好被prune_icache_sb()标记为I_FREEING，导致mysqlreport-116733循环等待，直到XFS_IRECLAIMABLE标记置位（对应到此处为prune_icache_sb返回）。该部分的耗时约49秒。

# 社区进展

针对xfs_vn_lookup() -> xfs_iget() -> xfs_iget_cache_hit()中对有I_FREEING标记的inode的循环死等情况，社区确实注意到了这个问题，并对xfs_iget()增加了XFS_IGET_NORETRY标记打破这种循环死等的局面。但目前该标志仅用于一些xfs内部的事务（如在线错误恢复等机制），并未开放给用户态使用。

# 推荐方案

这个延迟触发的必要条件是：

1.  内存极度紧张

2.  page cache/inode cache回收的同时又有大量遍历读需求。

目前可行的解决方案：

1.  通过TDSQL的free page的脚本，主动回收机制，避免内存紧张情况发生。

2.  降低sysctl_vfs_cache_pressure，减小inode cache回收量

# 代码分析

## xfs_iget相关伪代码

```
xfs_iget  error = xfs_iget_cache_hit  if (error == -EAGAIN)    delay(1)    goto xfs_iget_cache_hit
```

## xfs_iget_cache_hit相关伪代码

```
xfs_iget_cache_hit  ... ...  if (ip->i_flags & XFS_RECLAIMABLE) {    vfs已停止对该inode的操作，由xfs接管，可以重用  } else {    if (!igrab(inode))        // inode->i_state & (I_FREEING | I_WILL_FREEING)会导致返回-EAGAIN      return -EAGAIN;    找到了一个正在使用的inode  }
```

## prune_icache_sb相关伪代码

```
prune_icache_sb  ... ...  list_lru_shrink_walk    inode_lru_isolate(&freeable)      inode->i_state |= I_FREEING    // 从这个时候开始，xfs_iget_cache_hit()将一直等待  dispose_list(&freeable)    for inode in freeable      evict(inode)        inode_wait_for_writeback    // 等待回写        truncate_inode_pages_final  // 剔除inode关联的pagecache中的pages        destroy_inode          xfs_fs_destroy_inode            xfs_inactive            // 如果本次evict inode时，该inode->i_nlink == 0，组织事务在磁盘上删除该inode            xfs_inode_set_reclaim_tag              __xfs_iflags_set(XFS_IRECLAIMABLE)    // 此时xfs_iget_cache_hit()有机会结束循环      
```
