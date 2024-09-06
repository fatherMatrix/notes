# Nvme IO初始化

1. 对admin_tagset结构进行初始化，特别是nvme_mq_admin_ops的赋值

2. 调用blk_mq_alloc_tag_set分配tag set并与request queue关联

3. 然后调用blk_mq_init_allocated_queue对hardware queue和software queue进行初始化，并配置两者之间的mapping关系，最后将返回值传递给dev->ctrl.admin_q

# Nvme IO下发

```c
blk_mq_make_request
  ... ...
```

# Nvme IO完成

![](io.assets/76bd8fe21fd69fbd68cb8061c631030ea0d57df8.png)

# 参考文献

[linux block layer第二篇bio 的操作 - geshifei - 博客园](https://www.cnblogs.com/kernel-dev/p/17306812.html)
