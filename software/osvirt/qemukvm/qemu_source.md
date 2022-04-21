# Qemu代码注释

<a name="__source_struct_TypeInfo"></a>

## struct TypeInfo

```c
struct TypeInfo
{
    const char *name;
    const char *parent;

    size_t instance_size;                                       /* ObjectX所占用的内存大小 */
    size_t instance_align;                                      /* ObjectX的内存对齐数值 */
    void (*instance_init)(Object *obj);                         /* ObjectX的初始化函数 */
    void (*instance_post_init)(Object *obj);
    void (*instance_finalize)(Object *obj);                     /* ObjectX的析构函数 */

    bool abstract;                                              /* 是否是抽象类 */
    size_t class_size;                                          /* ObjectClassX所占用的内存大小 */

    void (*class_init)(ObjectClass *klass, void *data);         /* ObjectClassX的初始化函数 */
    /* 在执行了父class的class_init之后，自己的class_init之前执行，
     * 用来解除memcpy的副作用
     */
    void (*class_base_init)(ObjectClass *klass, void *data);
    void *class_data;

    /* 这是一个static类型的数组，没有长度。
     * 最后一个元素是0填充的，用来确定尾部位置。 
     * 保存了接口的字符名称
     */
    InterfaceInfo *interfaces;
};
```

<a name="__source_struct_TypeImpl"></a>

## struct TypeImpl

```c
struct TypeImpl
{   
    const char *name;

    size_t class_size;
    size_t instance_size;
    size_t instance_align;

    void (*class_init)(ObjectClass *klass, void *data);
    void (*class_base_init)(ObjectClass *klass, void *data);
    void *class_data;

    void (*instance_init)(Object *obj);
    void (*instance_post_init)(Object *obj);
    void (*instance_finalize)(Object *obj);

    bool abstract;

    const char *parent;
    TypeImpl *parent_type;

    /* 所有class类型的基类 */
    ObjectClass *class;

    /* 接口的数量 */
    int num_interfaces;
    /* 接口的字符名称数组 */
    InterfaceImpl interfaces[MAX_INTERFACES];
};
```

<a name="__source_struct_ObjectClass"></a>

## struct ObjectClass

```c
struct ObjectClass
{
    /* private: */
    Type type;                  /* typedef TypeImpl * Type; */

    /* Interface链表，其中每个元素是一个InterfaceClass的指针，即
     * interfaces->data是一个指向InterfaceClass的指针
     */
    GSList *interfaces;

    const char *object_cast_cache[OBJECT_CLASS_CAST_CACHE];
    const char *class_cast_cache[OBJECT_CLASS_CAST_CACHE];

    ObjectUnparent *unparent;   /* 干嘛的？*/

    GHashTable *properties;     /* name -> struct ObjectProperty的映射 */
};
```

<a name="__source_struct_Object"></a>

## struct Object

```c
struct Object
{
    /* private: */
    ObjectClass *class;        /* ObjectX所属的ObjectClassX */           
    ObjectFree *free;          /* 内存的释放函数 */
    GHashTable *properties;    /* name -> struct ObjectProperty的映射 */
    uint32_t ref;              /* 引用计数 */
    Object *parent;            /* parent ObjectX */
};
```

<a name="__source_about_init_type_list"></a>

## init_type_list

```c
typedef struct ModuleEntry
{
    void (*init)(void);                 /* 对应的注册函数，例如pci_edu_register_types */
    QTAILQ_ENTRY(ModuleEntry) node;     /* 内嵌的链表节点 */
    module_init_type type;              /* 类型对应的type，QOM只是init_type_list中的一大类 */
} ModuleEntry;

typedef QTAILQ_HEAD(, ModuleEntry) ModuleTypeList;
static ModuleTypeList init_type_list[MODULE_INIT_MAX];
typedef enum {
    MODULE_INIT_MIGRATION,
    MODULE_INIT_BLOCK,
    MODULE_INIT_OPTS,
    MODULE_INIT_QOM,                    /* QOM中的类型都插入到这个下标对应的链表里 */
    MODULE_INIT_TRACE,
    MODULE_INIT_XEN_BACKEND,
    MODULE_INIT_LIBQOS,
    MODULE_INIT_FUZZ_TARGET,
    MODULE_INIT_MAX
} module_init_type;
```

<a name="__source_func_pci_edu_register_types_AND_type_init"></a>

## pci_edu_register_types()与type_init()

```c
static void pci_edu_register_types(void)
{   
    static InterfaceInfo interfaces[] = {
        { INTERFACE_CONVENTIONAL_PCI_DEVICE },
        { },
    }; 
    static const TypeInfo edu_info = {
        .name          = TYPE_PCI_EDU_DEVICE,
        .parent        = TYPE_PCI_DEVICE,
        .instance_size = sizeof(EduState),
        .instance_init = edu_instance_init,
        .class_init    = edu_class_init,
        .interfaces = interfaces,
    };

    type_register_static(&edu_info);
}
type_init(pci_edu_register_types)

#define type_init(function) module_init(function, MODULE_INIT_QOM)
static void __attribute__((constructor)) do_qemu_init_ ## function(void)    \
{                                                                           \
    register_module_init(function, type);                                   \
}

void register_module_init(void (*fn)(void), module_init_type type)
{
    ModuleEntry *e;
    ModuleTypeList *l;

    e = g_malloc0(sizeof(*e));
    e->init = fn;                           /* 这个就是pci_edu_register_types这类 */
    e->type = type;

    l = find_type(type);

    QTAILQ_INSERT_TAIL(l, e, node);
}
```
