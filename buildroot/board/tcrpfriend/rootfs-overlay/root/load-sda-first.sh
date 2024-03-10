#!/bin/bash

echo "Mounting /root/boot-image-dummy-sda.img to /dev/sda"
imgpath="/root/boot-image-dummy-sda.img"
gunzip -f "${imgpath}.gz"
LOOPX=$(losetup -f)
losetup -P ${LOOPX} ${imgpath}
ln -s ${LOOPX}  /dev/sda
