# blk-mq

```c
blk_register_queue
  sysfs_create_group(request_queue->kobj, queue_attr_group)
  ... sysfs_add_file_mode_ns
        kernfs_ops = xxx
```

## throttle

阻塞：

```c
blk_mq_make_request
  rq_qos_throttle
    rq_qos->ops->throttle / wbt_wait                // 参见wbt_init
```

缓解：

```c
blk_mq_end_request
  __blk_mq_end_request
    if (rq->end_io)
      rq_qos_done                                   // 唤醒
      rq->end_io
    else
      blk_mq_free_request
        rq_qos_done                                 // 唤醒
```

### wbt

```c
wbt_init
```

### 参考文档

https://lore.kernel.org/all/1473259610-3295-1-git-send-email-axboe@fb.com/

https://tinylab.org/lwn-682582/

https://www.cnblogs.com/zyly/p/16690841.html

## iostat

统计开始：

```c
blk_mq_make_request
  blk_mq_get_request
  blk_mq_bio_to_request
    blk_account_io_start
```
