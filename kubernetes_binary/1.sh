#!/bin/bash

#ARRAY_IP=`awk '{print $1}' /etc/ansible/roles/ansible/Cluster/kubernetes_binary/hosts  |grep -v "k8s"`
#IP_num=${#ARRAY_IP[@]}
##echo $IP_num
#IP=${ARRAY_IP[0]}
#echo $IP
awk '{print $1}' /etc/ansible/roles/ansible/Cluster/kubernetes_binary/hosts  |grep -v "k8s" >ip.txt
n=1
while ((n<=$(cat ip.txt|wc -l)))
do
ipaddr[$n]=$(cat ip.txt|sed -n "${n}p"|awk '{print $1}')
((n+=1))
done
n=`expr $n - 1`
IP_num=${#ipaddr[@]}
#echo $IP_num
#echo ${ipaddr[1]}

for ((i = 0; i < IP_num; i++)); do
IP=(${ipaddr[$i]})
echo $IP
sleep 1
done
