# Qemu对象模型(QOM)

`QOM`全称`Qemu Object Model`，是qemu用来进行面向对象编程的基础。`QOM`使用C语言的模拟了C++的面向对象机制，主要是继承和多态。需要注意的是，`QOM`的面向对象机制实现并不高效，甚至处处体现着极致的低效，并不适合作为C语言下通用的面向对象机制使用。但其针对qemu设计，符合qemu设备模拟的诸多特点。

题外话，面向对象机制其实并不是C与C++二者的核心差异，C++中面向对象的整个机制都可以使用C语言极其高效地实现，不存在性能损失，甚至可能略有上升。因为C++面向对象机制的核心是vptr，linux内核中的面向对象机制可以看做一个较为高效的实现。C++相对于C真正的提高是Template，这一点是C编译器没有支持的。

## 主要数据结构

```
+--------------------------------------------------------------------------------------------------+
|                                                                                                  |
|                             +---------class---------+                                            |
|                             |                       |                                            |
| +--------+           +------v------+          +-----+----+                                       |
| | Object +---class---> ObjectClass +---type---> TypeImpl |                                       |
| +---+----+           +------+------+          +----------+                                       |
|     |                       |                                                                    |         +----------+
|     |                       |                 +----------------+             +----------------+  <--input--+ TypeInfo |
|     |                       +---properties----> ObjectProperty +--hash_link--> ObjectProperty |  |         +----------+
|     |                                         +----------------+             +----------------+  |
|     |                                                                                            |
|     |               +----------------+               +----------------+                          |
|     +--properties---> ObjectProperty +---hash_link---> ObjectProperty |                          |
|                     +----------------+               +----------------+                          |
|                                                                                                  |
+--------------------------------------------------------------------------------------------------+
```

- `TypeInfo`用于定义一个类型。代码见[struct TypeInfo](qemu_source.md#__source_struct_TypeInfo)，其核心字段如下：
  
  - `class_init`： `ObjectClassX`的初始化函数
  
  - `instance_init`：`ObjectX`的初始化函数
  
  - `class_size`：`ObjectClassX`的实际大小
  
  - `instance_size`：`ObjectX`的实际大小

- `TypeImpl`是`TypeInfo`的内部表示，大部分核心字段来自于对`TypeInfo`的克隆。代码见[struct TypeImpl](qemu_source.md#__source_struct_TypeImpl)，其核心字段如下：
  
  - `class`：指向产生的类型对应的`ObjectClassX`，type_initialize()的核心任务就是分配并初始化一个TypeImpl对应的ObjectClassX。

- `ObjectClass`描述了一个类型，其作用类似于`C++`中的`class`，所有`ObjectClassX`的第一个成员都是`ObjectClass`。代码见[struct ObjectClass](qemu_source.md#__source_struct_ObjectClass)，其核心字段如下：
  
  - `type`：指向`TypeImpl`结构体
  
  - `properties`：指向一个哈希表，存储了类型对应的属性，这些属性由当前类的所有对象共享

- `Object`描述了一个对象，代表一个由`QOM`控制的对象，所有`ObjectX`的第一个成员都是`Object`，用于管理对象。代码见[struct Object](qemu_source.md#__source_struct_Object)其核心字段如下：
  
  - `class`：指向对应类型的`ObjectClassX`
  
  - `properties`：指向一个哈希表，存储了此对象特有的属性

## 类型注册

类型注册是向`QOM`声明一个类型的过程，以`edu`设备类型为例，其注册分为如下几步。

### type_init

首先，程序员需要通过`type_init()`将一个包含`static`类型`TypeInfo`的函数（例如函数)插入`init_type_list[MODULE_INIT_QOM]`全局链表中，该链表类型声明代码见[init_type_list](qemu_source.md#__source_about_init_type_list)。`type_init()`内部使用`__attribute__((constructor))`，使得函数插入链表动作在main函数开始之前执行。相关代码见[pci_edu_register_types()与type_init()](qemu_source.md#__source_func_pci_edu_register_types_AND_type_init)。

所有将要在`QOM`中使用的类型都必须在此链表中存在对应的该函数，该函数的作用是将要产生的类型信息在函数自己内部的`static struct TypeInfo`中描述，并将其转化为`TypeImpl`插入全局的类型哈希表`type_table`中。

插入后的内存视图如下：

```
+-------------------+
| MODULE_INIT_BLOCK |
+-------------------+                +------+                +------+
| MODULE_INIT_OPTS  |                | type |                | type |
+-------------------+                +------+                +------+
| MODULE_INIT_QOM   +----------------> node +----------------> node |
+-------------------+                +------+                +------+
| MODULE_INIT_TRACE |                | init |                | init |
+-------------------+                +--+---+                +--+---+
|        ...        |                   |                       |
+-------------------+                   v                       v
   init_type_list             pci_edu_register_types   vmxnet3_register_types
```

函数展开栈如下，之所以是函数展开栈而不是函数调用栈，是因为`type_init()`这个宏展开后并不是函数调用，仅仅是个函数声明而已。

```
type_init(pci_edu_register_types)                                     展开为
module_init(pci_edu_register_types, MODULE_INIT_QOM)                  展开为
do_qemu_init_ ## pci_edu_resiter_types __attribute__((constructor))   函数声明，该函数在main函数之前执行

do_qemu_init_ ## pci_edu_register_types       /* 函数大概调用流程 */   
  register_module_init
    e = g_malloc0                             /* 分配ModuleEntry */
    e->init = pci_edu_register_types          /* 配置相关字段 */
    e->type = MODULE_INIT_QOM
    i = find_type(MODULE_INIT_QOM)            /* 找到init_type_list[MODULE_INIT_QOM] */
    QTAILQ_INSERT_TAIL(l, e, node)            /* 插入到i的尾部 */
```

值得注意的是，到此为止，我们并没有将具体的类型注册到`QOM`中，仅仅是注册了去注册具体类型的函数，当这个函数被调用后，才是将具体的类型注册到了`QOM`中。

### module_call_init()

## 类型初始化

```
type_initialize
  ti->class_size = type_class_get_size(ti)
  ti->instance_size = type_object_get_size(ti)
  ti->class = g_malloc0(ti->class_size)
  type_initialize(parent)                           
  type_initialize_interface
  ti->class_init()
```

## 对象初始化

```
object_new
  object_new_with_type
    object_initialize_with_type
      object_init_with_type
        ti->instance_init()        // ti是TypeImpl的指针，先递归调用父亲的
```

## 接口

## 属性

类属性存在于ObjectClass的properties域中，这个域是在类型初始化函数type_initialize()中构造的。对象属性存在与Object的properties域中，这个域是在对象的初始化函数object_initialize_with_type()中构造的。两者皆为一个哈希表，存着属性名字到ObjectProperty的映射。

ObjectProperty的定义如下：

```
typedef struct ObjectProperty
{
    gchar *name;
    gchar *type;
    gchar *description;
    ObjectPropertyAccessor *get;
    ObjectPropertyAccessor *set;
    ObjectPropertyResolve *resolve;
    ObjectPropertyRelease *release;
    void *opaque;
} ObjectProperty;


Object / ObjectClass
   +------------+
   |            |
   |            |
   |            |
   +------------+
   | properties |---------+--------------------------------
   +------------+         |                  |
   |            |         |                  |
   |            |     +--------+        +--------+
   |            |     |  name  |        |  name  |
   +------------+     +--------+        +--------+
                      |  type  |        |  type  |
                      +--------+        +--------+
                      |   set  |        |   set  |----> property_set_bool
                      +--------+        +--------+
                      |   get  |        |   get  |----> property_get_bool
                      +--------+        +--------+      
                      | opaque |        | opaque |--+ 
                      +--------+        +--------+  |   +----------------------------------------------+
                                                    +-> | BoolProperty / StringProperty / LinkProperty |
                                                        +----------------------------------------------+
```
