# Windows下git clone linux kernel失败

## aux文件不可创建

error: invalid path 'GIT/kernel-v4.14/drivers/gpu/drm/nouveau/nvkm/subdev/i2c/aux.c'

aux是NTFS文件系统的保留字，解决方案：

```shell
git config core.protectNTFS false
```

## NTFS不区分大小写

```shell
fsutil.exe file queryCaseSensitiveInfo <path>
fsutil.exe file setCaseSensitiveInfo <path> enable
fsutil.exe file setCaseSensitiveInfo <path> disable
```
