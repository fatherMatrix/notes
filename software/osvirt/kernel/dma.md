# DMA

## 目录分析

DMA core

| 文件                       | 描述                             |
| ------------------------- | ----------------------------     |
| drivers/dma/dmaengine.c   | DMA框架的核心代码提供硬件无关的接口   |
| drivers/dma/of-dma.c      | DMA框架设备树相关的代码             |
| include/linux/dmaengine.h | DMA框架数据结构以及相关接口的头文件   |

DMA provider:

| 文件                       | 描述                             |
| -------------------------- | ------------------------------- |
| drivers/dma/ioat/          | Intel IOAT DMA Controller       |
| ...                        | ...                             |

