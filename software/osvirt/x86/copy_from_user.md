# copy_from_user

## 优化补丁

- https://mp.weixin.qq.com/s/AVAWyZOcqfzMZztGspZUVg?nwr_flag=1#wechat_redirect

## 分析

核心问题是未优化内核在`copy_from_user()`的`access_ok()`中检查地址是否为用户空间地址时，为了规避`spectre漏洞`，加入了`barrier_nospec()`处理器屏障，导致性能下降。

解决方案为通过**虚拟地址最高位**来判断目标地址是否属于用户地址空间，由因为用户地址空间与内核地址空间存在巨大的gap，#GP异常会处理对应情况。因此无需判断size。因此没有if分支，不存在`spectre漏洞`。

## 关联

之所以难以合入，主要是因为新实现中的很多函数是经由较大时间跨度的诸多commit逐步修改、调整后引入的，需要逐个分析。目前已经分析过的commit如下：

- 74e19ef0ff8061ef55957c3abd71614ef0f42f47在`_copy_from_user()`中加入了`barrier_nospec()`

- 1f9a8286bc0c3df7d789ea625d9d9db3d7779f2d将`barrier_nospec()`统一到了`_inline_copy_from_user()`中

- 2865baf54077aa98fcdb478cefe6a42c417b9374初次引入了`mask_user_address()`、`masked_user_access_begin()`、`can_do_masked_user_access()`

- 86e6b1547b3d013bc392adf775b89318441403c2修复了`mask_user_address()`的一些bug
  
  - 2865baf54077 ("x86: support user address masking instead of non-speculative conditional")
  
  - 6014bc27561f ("x86-64: make access_ok() independent of LAM")
  
  - b19b74bc99b1 ("x86/mm: Rework address range check in get_user() and put_user()")

- 91309a70829d9优化了`mask_user_address()`的实现

- 0fc810ae3ae110f9e2fcccce80fc8c8d62f97907减少了`copy_from_user()`过程中对`barrier_nospec()`的调用次数，是性能提升的关键
