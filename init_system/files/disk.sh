#!/bin/bash

DISK=$1

CHECK_EXIST=`/sbin/fdisk -l 2> /dev/null | grep -o "$DISK"`
[ ! "$CHECK_EXIST" ] && { echo "Error: Disk is not found !"; exit 1;}

echo "1" > /tmp/disk.log

CHECK_DISK_EXIST=`/sbin/fdisk -l 2> /dev/null | grep -o "$DISK[1-9]"`
[ ! "$CHECK_DISK_EXIST" ] || { echo "WARNING: ${CHECK_DISK_EXIST} is Partition already !"; exit 1;}

echo "2" > /tmp/disk.log

/sbin/fdisk /dev/sdb<<EOF
d
n
p
1


t
83
w
EOF
