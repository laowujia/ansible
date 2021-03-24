#!/bin/bash
IP=`awk '{print $1}' hosts |grep -v "k8s"|head -n 1`
grep "$IP" /etc/hosts >>/dev/null 2>&1
echo $?
