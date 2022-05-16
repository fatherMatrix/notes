# SeaBIOS

SeaBIOS的执行过程主要包括post阶段、boot阶段、main runtime阶段和resume and reboot阶段。

## post阶段

```
reset_vector
  entry_post
    handle_post
      dopost
        qemu_preinit
          qemu_detect
          e820_add
        maininit
          interface_init
            qemu_cfg_init
          platform_hardware_setup
            qemu_platform_setup
              pci_setup
          vfarom_setup
          startBoot
```
