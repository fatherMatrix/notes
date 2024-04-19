# smartpqi

drivers/scsi/libsas/sas_scsi_host.c:545:        res = shost->hostt->eh_device_reset_handler(cmd);
drivers/scsi/scsi_error.c:898:  rtn = hostt->eh_device_reset_handler(scmd);

```c
pqi_eh_device_reset_handler
  pqi_device_reset
    pqi_lun_reset_with_retries
      pqi_device_wait_for_pending_io
        while (scsi_cmds_outstanding > 0)
          if (msecs_waiting > timeout_msecs) {
            dev_err("scsi %d:%d:%d:%d: timed out after %lu seconds waiting for %d outstanding command(s)\n")
            return -ETIMEOUT
          }
          msleep
```

```c
pqi_scsi_queue_command
  atomic_inc(&device->scsi_cmds_outstanding)
```

```c
pqi_irq_handler
  pqi_process_io_intr
    io_request->io_complete_callback                // pqi_raid_io_complete/pqi_aio_io_complete
      pqi_scsi_done
        atomic_dec(&device->scsi_cmds_outstanding)  // 减小scsi_cmds_outstanding
```

```c
scsi_error_handler                                  // kthread_run开启的内核线程
  shost->transportt->eh_strategy_handler            // sas_scsi_recover_host
    scsi_eh_ready_devs
      scsi_eh_offline_sdevs
        sdev_printk("Device offline - not ready after error recovery")
        scsi_device_set_state(sdev, SDEV_OFFLINE)
```

```c
scsi_queue_rq
  scsi_prep_state_check
    case SDEV_OFFLINE:
      sdev_printk("rejecting I/O to offline device\n")
```