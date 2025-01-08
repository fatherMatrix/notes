# spin_lock分析

## 初代自旋锁

v2.6.24之前，spinlock就是一个原子整数，初始化为1。加锁时，做atomic_dec()，如果其值为0，则表示获取到锁，如果为负数则需要忙等。

初代自旋锁的缺陷：公平性无法保障，即无法确保等待时间最长的竞争者优先获取到锁。

## ticket spinlock

实现类似叫号系统，每个锁的竞争者领取一个号码，持有者释放锁的时候递增号码。

ticket spinlock的缺陷：缓存行颠簸，即持有者释放锁的时候要invalid掉所有其他cpu上对应的缓存行。

## MCS spinlock

两个优点：

- 保证自旋锁申请者以先进先出的顺序获取锁（FIFO）

- 只在本地可访问的标志变量上自旋

结构体：

```c
struct mcs_spinlock {
	struct mcs_spinlock *next;
	int locked; /* 1 if lock acquired */
	int count;  /* nesting count, see qspinlock.c */
};
```

思路：

![](spinlock.assets/5ae54838b575d77887e62a9d06306cb9a8e47440.jpg)

- 主锁的next指向最后一个争抢者

- 每个锁的争抢者生成一个本地的mcs_spinlock，拿不到锁时将自己挂入前面一个等待的next，并将主锁的next指向自己。然后在自己本地的mcs_spinlock->locked上自旋

- 每个锁的释放者负责将自己的next的locked改为1

没见过mcs单独是怎么用的，只能做几点猜测：

- 主锁本身也是mcs_spinlock结构体

- 主锁的locked字段应该没啥用，其next是否为空才有用

缺点：

- 结构体太大了

## qspinlock


