#!/bin/bash

echo "Mounting /root/boot-image-dummy-sda.img to /dev/sda"
imgpath="/root/boot-image-dummy-sda.img"
gunzip -f "${imgpath}.gz"
insmod /lib/modules/loop.ko
losetup -P /dev/loop0 ${imgpath}
