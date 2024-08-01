# PCID and VPID
## PCID
- 含义：`Process Context Identifier`
- 位置：`CR3[11:0]`
- 作用：当`CR4.PCIDE=1`时，自动切换`address_space`时不会flush所有的`TLB`。硬件查找`TLB`时，仅会匹配`PCID`等于当前`CR3[11:0]`的`TLB Entry`。
- AMD64：特性命名同Intel
## VPID
- 含义：`Virtual-Processor Identifier`
- 位置：`VMCS.virtual-processor identifier`，16 bit
- 作用：标记虚拟机
- AMD64：`ASID(Address Space Identifier)`
## mov cr3
对`cr3`寄存器进行更改会触发`tlb flush`和`pagetable cache flush`，冲刷规则如下：
- If `CR4.PCIDE = 0`, the instruction invalidates all TLB entries associated with PCID 000H except those for global pages. It also invalidates all entries in all paging-structure caches associated with PCID 000H.
- If `CR4.PCIDE = 1 and bit 63 of the instruction’s source operand is 0`, the instruction invalidates all TLB entries associated with the PCID specified in bits 11:0 of the instruction’s source operand except those for global pages. It also invalidates all entries in all paging-structure caches associated with that PCID. It is not required to invalidate entries in the TLBs and paging-structure caches that are associated with other PCIDs.
- If `CR4.PCIDE = 1 and bit 63 of the instruction’s source operand is 1`, the instruction is not required to invalidate any TLB entries or entries in paging-structure caches.

对于上述第2点，有两个关键点
- bit63是操作数中的，会存入cr3中吗？
	- 看cr3的表述，bit63似乎一直为0，也就是说mov cr3不会真正向cr3中写入bit 63？
- 这个刷的tlb不是当前cr3中已经有的，而是操作数中的；为什么不是mov cr3的时候刷当前cr3中的pcid对应的tlb？
	- 因为翻译时老的pcid本身就不再对翻译结果产生影响了，所以没必要flush当前cr3对应pcid的tlb。

对于上述第3点，要注意：
- 操作数中bit[11:0]指定pcid来刷什么？
	- 因为pcid只有12位，只能有4096个pcid，但进程数量肯定不止4096，所以pcid不够用。因此，进程B切进来后，要保证前面和进程B使用同一个pcid的进程A的tlb被flush掉。 
- 如何辨别pcid是进程A重复的，还是进程B原来的？
