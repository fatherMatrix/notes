# openssh

## sshd

sshd的主函数大致如下：

```
// sshd.c
main
  ...
  initialize_server_options(&options)                           // 初始化options为默认值
  parse_command_lines                                           // 解析命令行参数
  load_server_config                                            // sshd_config
  parse_server_config                                           // sshd_config
  daemonized                                                    // 进入守护模式
  server_listen
  server_accept_loop                                            // 只会在建立连接后，从服务进程中返回
  ...
  do_ssh2_kex                                                   // 交换Key
  do_authentication2                                            // 用户验证
    ssh_dispatch_set(SERVICE_REQUEST, input_service_request)    // 设置回调函数
    ssh_dispatch_run_fatal                                      // 事件循环
  ...
  do_authenticated                                              // 启动会话
```

当sshd收到SERVICE_REQUEST类型的消息后，调用回调函数input_service_request。其主要过程如下：

```
input_service_request
  ssh_dispatch_set(USERAUTH_REQUEST, input_userauth_request)    // <A0> 
  sshpkt_start(SERVICE_ACCEPT)                                  // <A1>，对应ssh中的<B>
  sshpkt_put_cstring(service)
  sshpkt_send
```

input_userauth_request的主要过程如下：

```
input_userauth_request
  userauth_banner
    userauth_send_banner
      sshpkt_start(USERAUTH_BANNER)
      ...
      sshpkt_send
  m = authmethod_lookup                                         // method_passwd 
  m->userauth                                                   // userauth_passwd
  userauth_finish
    sshpkt_start(USERAUTH_SUCCESS)
    ...
    sshpkt_send
```

如果是使用密码，则调用userauth_passwd函数：

```
userauth_passwd
  sshpkt_get_u8(change)
  sshpkt_get_cstring(password)                                  // 在ssh中是在哪儿发送的passwd呢？userauth_passwd中！
  PRIVSEP(auth_password(ssh, password))
```

## ssh

```
// ssh.c
main
  ...
  ssh_login                                                     // 登入远程系统，如果失败不会返回
    kex_exchange_identification                                 // 与服务器交换协议版本标识
    ssh_package_set_nonblocking
    ssh_kex2                                                    // 交换Key
    ssh_userauth2                                               // 用户验证
      sshpkt_start(SERVICE_REQUEST)                             // 向用户发送验证服务请求
      sshpkt_put_cstring("ssh-userauth")
      sshpkt_send
      sshpkt_dispatch_set(SERVICE_ACCEPT, input_userauth_service_accept)    // <B0>，对应sshd中的<A1> 
  ...
```

在收到服务端发来的SERVICE_ACCEPT报文后，调用回调函数input_userauth_service_accept。其主要过程如下：

```
input_userauth_service_accept
  userauth_none                                                 // 这一次没有输入密码，会触发服务端的USERAUTH_FAILURE
    sshpkt_start(USERAUTH_REQUEST)                              // <B1>，对应<A0>
    sshpkt_put_cstring(server_user)
    sshpkt_put_cstring(service)
    sshpkt_put_cstring(method_name)
    sshpkt_send
  ssh_dispatch_set(USERAUTH_SUCCESS, input_userauth_success)
  ssh_dispatch_set(USERAUTH_FAILURE, input_userauth_failure)    // 在这里会根据remote传回的authlist重新选择验证方法
  ssh_dispatch_set(USERAUTH_BANNER, input_userauth_banner)
```

在收到服务端发来的USERAUTH_FAILURE报文后，调用回调函数input_userauth_failure。其主要过程如下：

```
input_userauth_failure
  sshpkt_get_cstring(authlist)        // 获取remote传回的可选择认证方法列表
  userauth(authlist)                  // 调用authlist中指定的认证方法
    method = authmethod_get(authlist)
      authmethod_lookup(name)         // name是从authlist中挑选出来的，本函数在authmethods全局数组中查找
    method->userauth()
```

对密码验证方法来说，method->userauth指针指向userauth_password

```c
userauth_password
```

## privep
