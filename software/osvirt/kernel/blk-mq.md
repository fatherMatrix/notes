# blk-mq

```c
blk_register_queue
  sysfs_create_group(request_queue->kobj, queue_attr_group)
  ... sysfs_add_file_mode_ns
        kernfs_ops = xxx
```
