# kprobe

## kprobe注册

```
register_kprobe
  kprobe_addr                           // 通过symbol获取addr
    _kprobe_addr                        // 如果symbol和addr都指定了，返回错误；否则如果仅指定了addr，则返回addr；如果仅指定了symbol，则查找
      kprobe_lookup_name
        kallsyms_lookup_name
          kallsyms_expand_symbol        // 1. 从内核的kallsyms中查找，如果查到了，返回
          module_kallsyms_lookup_name   // 2. 从模块的kallsyms中查找
```
