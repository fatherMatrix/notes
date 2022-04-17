# Linux身份鉴别

## PAM框架

### PAM简介

PAM即可插拔认证模块。提供了对所有服务进行认证的中央机制，适用于login、远程登录（telnet、rlogin、fsh、ftp、ppp等）以及su等应用程序中。其动机是将应用程序与具体的认证机制分离，使得系统改变认证机制时，应用程序无需修改代码也可继续使用新的认证机制。核心原理为保持认证接口（PAM API）不变，将认证过程相关代码编译为动态链接库，应用程序只管点用PAM API进行认证，PAM API被调用后即时加载动态链接库执行认证过程。

```
                               +--------------------+
                               |     Application    |
                               |                    |
                               |  +--------------+  |       +---------------+      
                               |  | pam_handle_t |  |       | Administrator |
                               |  +--------------+  |       +-------+-------+ 
                  +------+     |  |  +--------+  |  |               |
                  | user +----------->  conv  |  |  |               |
                  +------+     |  |  +--------+  |  |      +--------v-------+
                               |  +-------+------+  |      |  /etc/pam.d/*  |
                               +----------|---------+      +--------^-------+
                                          |                         | 
   pam_xxxx()  ---------------------------+-------------            | 
                                          |                         |
                 +------------------------v-------------------------+---------------+
                 |                              PAM LIB                             |
                 +-------+-----------------+----------------+----------------+------+
                         |                 |                |                |
pam_sm_xxxx()  ----------+-----------------+----------------+----------------+-----------
                         |                 |                |                |
                 +-------v------+  +-------v------+ +-------v------+ +-------v------+
                 | authenticate |  |   account    | |   session    | |   password   |
                 +--------------+  +--------------+ +--------------+ +--------------+
```

PAM使用过程如图所示，分为四个部分：

- 系统管理员通过PAM配置文件（/etc/pam.d/*）来制定不同应用程序的不同认证策略

- 应用程序开发者通过调用PAM API（pam_xxxx()）来实现对认证方法的调用

- PAM服务模块的开发者利用PAM SPI来编写模块（主要是引出一些函数供PAM接口库调用，如pam_sm_xxxx()），将不同的认证机制加入到系统中。这部分代码通过`dlopen()`被加载

- PAM接口库则读取PAM配置文件，将应用程序调用的PAM API与PAM服务模块联系起来

### 配置文件

配置文件分为两种，一种是/etc/pam.conf文件，另一种是存在于/etc/pam.d/文件夹下的以服务名命名的诸多文件。两种文件的作用相同，都是用来约定哪种服务使用哪种验证规则。当第二种配置文件存在时，第一种会被忽略。

对于/etc/pam.conf文件，其格式为使用空格分隔的几个字段，其中前三个字段是大小写敏感的。

```
// 格式
service         type            control         module-path     module-arguments

// 实例
useradd         auth            sufficient      pam_rootok.so		
useradd         account         required        pam_permit.so
useradd         password        include         system-auth
su              auth            required        pam_env.so
su              auth            sufficient      pam_rootok.so
su              auth            substack        system-auth
su              auth            include         postlogin
```

对于/etc/pam.d/文件夹下的诸多文件，每个文件的文件名即为service，因此在这些文件中不在需要service这一项。

```
// 格式
type            control         module-path     module-arguments

// 实例 - /etc/pam.d/useradd
auth            sufficient      pam_rootok.so
account         required        pam_permit.so
password        include         system-auth
```

### PAM代码分析

#### 关键数据结构

struct pam_handle是pam中上下文的唯一性标识。

```c
struct pam_handle {
    char *authtok;    
    unsigned caller_is;    
    struct pam_conv *pam_conversation;   /* 用于调用用户自定义的验证交互方法 */ 
    char *oldauthtok;     
    char *prompt;                        /* for use by pam_get_user() */    
    char *service_name;    
    char *user;    
    char *rhost;    
    char *ruser;    
    char *tty;    
    char *xdisplay;    
    char *authtok_type;                  /* PAM_AUTHTOK_TYPE */    
    struct pam_data *data;    
    struct pam_environ *env;             /* structure to maintain environment list */    
    struct _pam_fail_delay fail_delay;   /* helper function for easy delays */    
    struct pam_xauth_data xauth;         /* auth info for X display */    
    struct service handlers;             /* 最核心字段，描述pam_sm_xxxx() */ 
    struct _pam_former_state former;     /* library state - support for
                                            event driven applications */
    const char *mod_name;                /* Name of the module currently executed */
    int mod_argc;                        /* Number of module arguments */
    char **mod_argv;                     /* module arguments */
    int choice;                          /* Which function we call from the module */
#ifdef HAVE_LIBAUDIT
    int audit_state;                     /* keep track of reported audit messages */
#endif
    int authtok_verified;
};
```

其中，struct service描述了要加载的module及其所包含的六个handler。这六个handler即为`PAM LIB`最终调用的`pam_sm_xxxx()`的函数指针。

```c
struct service {
    struct loaded_module *module; /* Array of modules */
    int modules_allocated;
    int modules_used;
    int handlers_loaded;
    struct handlers conf;        /* the configured handlers */
    struct handlers other;       /* the default handlers */
};

struct loaded_module {
    char *name;
    int type;                     /* PAM_STATIC_MOD or PAM_DYNAMIC_MOD */
    void *dl_handle;              /* dlopen()返回的handle */
};

struct handlers {
    struct handler *authenticate;
    struct handler *setcred;
    struct handler *acct_mgmt;
    struct handler *open_session;
    struct handler *close_session;
    struct handler *chauthtok;
};
```

struct handle描述了一个handle的详细信息。

```c
struct handler {
    int handler_type;
    int (*func)(pam_handle_t *pamh, int flags, int argc, char **argv);
    int actions[_PAM_RETURN_VALUES];
    /* set by authenticate, open_session, chauthtok(1st)
       consumed by setcred, close_session, chauthtok(2nd) */
    int cached_retval;
    int *cached_retval_p;
    int argc;
    char **argv;
    struct handler *next;
    char *mod_name;
    int stack_level;
    int grantor;
};
```

### 关键流程

初始化流程，动态库的加载调用栈

```
pam_start
  _pam_init_handlers
    _pam_open_config_file
    _pam_parse_config_file
      _pam_add_handler
        _pam_load_module        // 获取提供的模块路径状态服务模块
          _pam_dlopen
            dlopen              // 加载动态链接库
          _pam_dlsym
            dlsym               // 获取动态链接库中的符号地址
          填充到handler中
```

`pam_authenticate()`调用栈

```
pam_authenticate
  _pam_dispatch
    _pam_init_handlers          // 如果没有初始化过的话，就在此处初始化
    _pam_dispatch_aux
      调用对应的handler
```

## pam_usb使用及分析

`pam_usb`是一个基于PAM框架的USB KEY验证机制，其主要工作为实现了`pam_usb.so`动态链接库，其中包含了PAM LIB需要调用的`pam_sm_xxxx()`的实现。

### 安装

pam_usb中的pamusb-conf工具使用了dbus，以来其udisks-1，但现在大部分发行版仓库默认仅提供udisks-2，需要手动安装udisks-1及其依赖。

### 关键流程

`pam_usb.so`的关键函数为自定了`pam_sm_authenticate()`的逻辑，并提供了配置工具`pamusb-conf`用于配置user和usb的对应关系。

在配置user和usb关系时，其核心为使用`pamusb-conf`对于给定的user和usb，

- 生成一个随机数，并将其同时写入usb和操作系统上与user关联的配置文件中

- 读取usb的硬件特征，包括vendor_id、product_id和serial num，并将其写入到操作系统上与user关联的配置文件中

当需要进行验证时，

- 用户程序通过`pam_authenticate()`调用到位于`pam_usb.so`中的`pam_sm_authenticate()`

- `pam_sm_authenticate()`读取操作系统上与user关联的配置文件，检查是否存在对应硬件特征的usb。如果不存在，则直接返回失败

- 存在对应硬件特征的usb时，读取usb中的随机数，和操作系统上与user关联的配置文件中的随机数进行比对。如果不匹配，则直接返回失败

- 随机数匹配成功，此时更新一次随机数，使得下次匹配使用新的随机数

- 返回成功

## usb/ip使用及分析

`usb/ip`是一个基于TCP/IP网络的USB共享机制，使得插入client host的usb可以通过网络在server host上以访问本地USB设备的方式访问client host上的usb。将`usb/ip`与`pam_usb`配合可以实现远端ssh的USB KEY认证。

待测试。

## useradd代码分析

代码位于shadow-utils-4.6-14.tl3.1.src.rpm中。

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

# 参考文献

## PAM相关

1. [http://www.linux-pam.org/Linux-PAM-html/Linux-PAM_ADG.html](http://www.linux-pam.org/Linux-PAM-html/Linux-PAM_ADG.html)

2. [https://www.doc88.com/p-9455199013252.html?r=1](https://www.doc88.com/p-9455199013252.html?r=1)

3. [http://www.pamusb.org](http://www.pamusb.org)

4. [https://www.suse.com/c/pam-pluggable-authentication-module-usb-authentication/](https://www.suse.com/c/pam-pluggable-authentication-module-usb-authentication/)

5. [http://www.linux-pam.org/Linux-PAM-html/](http://www.linux-pam.org/Linux-PAM-html/)

## useradd相关

无
