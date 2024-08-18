# md

## 设备创建

```c
md_probe
  md_alloc
    mddev_find_or_alloc                        // 分配struct mddev
    blk_alloc_queue
    blk_queue_make_request(md_make_request)    // 设置->make_reuqest
```

## 设备读写

```c
md_make_request
  md_handle_request
    mddev->pers->make_request
```

### raid10

```c
static struct md_personality raid10_personality =
{
        .name           = "raid10",
        .level          = 10,
        .owner          = THIS_MODULE,
        .make_request   = raid10_make_request,
        .run            = raid10_run,
        .free           = raid10_free,
        .status         = raid10_status,
        .error_handler  = raid10_error,
        .hot_add_disk   = raid10_add_disk,
        .hot_remove_disk= raid10_remove_disk,
        .spare_active   = raid10_spare_active,
        .sync_request   = raid10_sync_request,
        .quiesce        = raid10_quiesce,
        .size           = raid10_size,
        .resize         = raid10_resize,
        .takeover       = raid10_takeover,
        .check_reshape  = raid10_check_reshape,
        .start_reshape  = raid10_start_reshape,
        .finish_reshape = raid10_finish_reshape,
        .update_reshape_pos = raid10_update_reshape_pos,
        .congested      = raid10_congested,
};
```

## Update time

```c
md_update_sb
```
