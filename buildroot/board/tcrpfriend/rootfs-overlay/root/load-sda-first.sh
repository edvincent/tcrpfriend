#!/bin/bash
 
LOOPX=$(losetup -f)
losetup -P ${LOOPX} /root/boot-image-dummy-sda.img
ln -s ${LOOPX}  /dev/sda
