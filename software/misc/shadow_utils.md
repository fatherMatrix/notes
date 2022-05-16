# shadow-utils

代码位于shadow-utils-4.6-14.tl3.1.src.rpm中。

## useradd代码分析

### 主要调用流程

```
main
  process_root_flag            // 对-R提前处理
  process_prefix_flag          // 对-P提前处理
  #ifdef USE_PAM               // 使用PAM机制对当前用户进行权限检查
  pam_start
  pam_authenticate
  pam_acct_mgmt
  pam_end
  #endif
  perfix_getpwnam              // 检查要添加的用户是否已经存在
  perfix_getgrnam              // 检查要添加的用户对应的组是否存在，需配合-U参数
  open_files                   // 锁定并打开/etc/passwd文件
    pw_lock                              
    pw_open                    // 这里会对文件进行解析，每一项作为commonio_entry插入commonio_db中对应的链表
  open_group_files             // 锁定并打开/etc/group文件
  find_new_uid                 // 查找合适的uid，要配合-o、-u参数做相关合法性检查
  open_shadow                  // 锁定并打开/etc/shadow文件
  find_new_gid                 // 查找合适的gid，要配合-U参数做相关合法性检查
  usr_update                   // 创建要添加用户的passwd文件项，有必要的话还会创建group文件项
    new_pwent                  // 创建passwd文件项
    new_spent                  // 创建shadow文件项
    pw_update                  // 将新创建的passwd文件项添加到表中
      add_one_entry
    spw_update                 // 将新创建的shadow文件项添加到表中
    grp_update                 // 如果涉及到了group的增加，则进行相关的操作
  close_files                  // 关闭所有相关文件并进行回写
  冲刷各种文件缓存
  create_home
  create_mail
```

值得注意的是，代码中对相关文件加的锁都无法阻止用户对文件的直接访问，这里的锁主要用来互斥shadow-utils中的多个工具间的操作。

```
pw_open
  commonio_open            // 传入参数为&passwd_db
    open                   // 打开文件
    fdopen                 // 将fd转换为FILE*
    db->ops->fgets
    db->ops->parse
    eptr = db->ops->dup    // parse中的返回的是static变量的地址，这里要拷贝一份
    add_one_entry          // 添加到内存中的链表上
```
