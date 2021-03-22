#!/bin/bash
read -r -p "请输入服务器的IP和密码，例如：192.168.228.200:" IP
read -r -p "请输入服务器的IP和密码，例如：192.168.228.200:" IP
while 
do
echo [password] > ${scripts_PATH}/hosts
read -r -p "请输入服务器的IP和密码，例如：192.168.228.200:" IP
  if [ -z "$IP" ];then
exit 1
else
CheckIPAddr $IP
if [ $? -eq 0 ];then
echo $IP >> ${scripts_PATH}/hosts
else
echo "$IP IP 不合法"
fi
fi
break
done

