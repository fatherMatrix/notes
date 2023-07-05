# 主板与固件模拟

`Intel 440FX(i440FX)`是Intel在1996年发布的用来支持`Pentium 2`的主板芯片，距今已有20多年的历史，是一代比较经典的架构。虽然Qemu已经能够支持更先进的`q35`架构的模拟，但是目前`Qemu`依然默认使用`i440FX`架构。

## 主板层次

| TYPE_XXX         | struct TypeInfo  | ObjectClassX    | ObjectX         | Abstract |
| ---------------- | ---------------- | --------------- | --------------- | -------- |
| TYPE_MACHINE     | machine_info     | MachineClass    | MachineState    | True     |
| TYPE_X86_MACHINE | x86_machine_info | X86MachineClass | X86MachineState | True     |
| TYPE_PC_MACHINE  | pc_machine_info  | PCMachineClass  | PCMachineState  | True     |

上面的类都是`Abstract`的，对于x86架构来说，真正可以运行的Machine都需要通过`DEFINE_I440FX_MACHINE`宏来定义：

```c
#define DEFINE_PC_MACHINE(suffix, namestr, initfn, optsfn) \
    static void pc_machine_##suffix##_class_init(ObjectClass *oc, void *data) \
    { \
        MachineClass *mc = MACHINE_CLASS(oc); \
        optsfn(mc); \
        mc->init = initfn; \
    } \
    static const TypeInfo pc_machine_type_##suffix = { \
        .name       = namestr TYPE_MACHINE_SUFFIX, \
        .parent     = TYPE_PC_MACHINE, \
        .class_init = pc_machine_##suffix##_class_init, \
    }; \
    static void pc_machine_init_##suffix(void) \
    { \
        type_register(&pc_machine_type_##suffix); \
    } \
    type_init(pc_machine_init_##suffix)

#define DEFINE_I440FX_MACHINE(suffix, name, compatfn, optionfn) \
    static void pc_init_##suffix(MachineState *machine) \
    { \
        void (*compat)(MachineState *m) = (compatfn); \
        if (compat) { \
            compat(machine); \
        } \
        pc_init1(machine, TYPE_I440FX_PCI_HOST_BRIDGE, \
                 TYPE_I440FX_PCI_DEVICE); \
    } \
    DEFINE_PC_MACHINE(suffix, name, pc_init_##suffix, optionfn)
```

两个重要信息：

- `DEFINE_I440FX_MACHINE()`重点在于生成对应的`struct TypeInfo`并使用`type_init()`将其在`main()`运行前注册
- 关键初始化函数为`pc_init1()`

