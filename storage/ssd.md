# SSD

SSD的问题：

- log-on-log
- large tail-latencies
- unpredictable IO latency
- resource under-utilization

SSD架构：

- Die: A die allows a single IO command to be executed at a time. There may be one or several dies within a single physical package.
- Plane: A plane allow similar flash commands to be executed in parallel within a die.
- Block: The unit of earse is a block. Each plane contains the same number of blocks.
- Page: The minimal units of read and write. Each block contains the same number of pages.

SSD读写特性：

- 读：sub-hundred microseconds
- 写/擦：a few milliseconds

SSD读写要求：

- 每次写命令必须包含能否写满一个或多个page的数据
- block内的多个写必须串行化
- 先擦后写