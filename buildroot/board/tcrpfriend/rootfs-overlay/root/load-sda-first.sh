#!/bin/bash

echo "Mounting /root/boot-image-dummy-sda.img to /dev/sda"
imgpath="/root/boot-image-dummy-sda.img"
gunzip -f "${imgpath}.gz"
losetup -P /dev/loop0 ${imgpath}
