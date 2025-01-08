# ABI

## 通用寄存器作用

<img title="" src="abi.assets/2024-11-22-11-08-33-image.png" alt="" width="701">

## 栈帧结构

![](abi.assets/2024-11-22-11-09-24-image.png)

## 汇编的index mode

![](abi.assets/2024-11-22-11-17-55-image.png)

另外，`LDR X0, [X1, #8]`表示的含义是，从`X1+8`的位置取数据放入`X0`，`X1`本身保持不变
