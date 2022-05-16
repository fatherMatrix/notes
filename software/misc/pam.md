# PAM框架

## PAM简介

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

## 配置文件

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

## PAM代码分析

### 关键数据结构

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

## 关键流程

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
# 参考文献

1. [http://www.linux-pam.org/Linux-PAM-html/Linux-PAM_ADG.html](http://www.linux-pam.org/Linux-PAM-html/Linux-PAM_ADG.html)

2. [https://www.doc88.com/p-9455199013252.html?r=1](https://www.doc88.com/p-9455199013252.html?r=1)

3. [http://www.pamusb.org](http://www.pamusb.org)

4. [https://www.suse.com/c/pam-pluggable-authentication-module-usb-authentication/](https://www.suse.com/c/pam-pluggable-authentication-module-usb-authentication/)

5. [http://www.linux-pam.org/Linux-PAM-html/](http://www.linux-pam.org/Linux-PAM-html/)

