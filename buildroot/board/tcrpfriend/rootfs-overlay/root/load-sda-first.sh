#!/bin/bash

echo "Mounting /root/boot-image-dummy-sda.img to /dev/loop0" >> /var/log/messages
imgpath="/root/boot-image-dummy-sda.img"
gunzip -f "${imgpath}.gz" >> /var/log/messages
insmod /lib/modules/loop.ko >> /var/log/messages
echo "Before losetup /root/boot-image-dummy-sda.img" >> /var/log/messages
blkid | grep msdos >> /var/log/messages
losetup -P /dev/loop0 ${imgpath} 
echo "After losetup /root/boot-image-dummy-sda.img" >> /var/log/messages
blkid | grep msdos >> /var/log/messages
