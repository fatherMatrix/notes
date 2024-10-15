# IO util

## 为什么v5.4相较于v3.10的ioutils高？

iostat的数据来源是/proc/diskstats，其内核处理路径是：

```c
static const struct seq_operations diskstats_op = {
        .start  = disk_seqf_start,
        .next   = disk_seqf_next,
        .stop   = disk_seqf_stop,
        .show   = diskstats_show
};
```

util的计算公式：(采样结束io_ticks - 采样开始io_ticks) / 采样间隔 * HZ

问题的关键是：io_ticks如何统计。

v3.10.99中：

```c
static void part_round_stats_single(int cpu, struct hd_struct *part,
                                    unsigned long now) 
{
        /*
         * 如果io在一个jiffies中完成了，则不计算
         * - v3.10的一个jiffies是4ms
         */
        if (now == part->stamp)
                return;

        if (part_in_flight(part)) {
                __part_stat_add(cpu, part, time_in_queue,
                                part_in_flight(part) * (now - part->stamp));
                __part_stat_add(cpu, part, io_ticks, (now - part->stamp));
        }
        part->stamp = now; 
}
```

v5.4中：

```c
void update_io_ticks(struct hd_struct *part, unsigned long now, bool end)
{
        unsigned long stamp;
again:
        stamp = READ_ONCE(part->stamp);
        if (unlikely(stamp != now)) {
                if (likely(cmpxchg(&part->stamp, stamp, now) == stamp)) {
                        /*
                         * 每个io下发时，先给io_ticks加1，保证当前jiffies被统计；
                         * 每个io结束时，增加这个io跨越的jiffies；
                         */
                        __part_stat_add(part, io_ticks, end ? now - stamp : 1);
                }
        }
        if (part->partno) {
                part = &part_to_disk(part)->part0;
                goto again;
        }
}
```

io_ticks的算法差别导致util的值变高。

## 为什么SSD盘不应该关注ioutils？
