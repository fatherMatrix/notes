# ulimit

ulimit -<x> value 更改软限制

ulimit -H<x> value 更改硬限制

ulimit -n这个用于限制最大可打开的文件，但这个值还受sysctl nr_open的限制

| sysctl变量   | 内核变量           |
| ---------- | -------------- |
| fs.nr_open | sysctl_nr_open |
|            |                |
|            |                |
