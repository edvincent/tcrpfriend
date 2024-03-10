#!/bin/bash

echo "Mounting /root/boot-image-dummy-sda.img to /dev/sda"
LOOPX=$(losetup -f)
losetup -P ${LOOPX} /root/boot-image-dummy-sda.img
ln -s ${LOOPX}  /dev/sda
