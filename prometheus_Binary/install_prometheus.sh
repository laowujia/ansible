#!/bin/bash

#定义外部输入确认的正则
export YES_REGULAR="^[yY][eE][sS]|[yY]$"

scripts_PATH="$( cd "$( dirname "$0"  )" && pwd  )"
echo $scripts_PATH


if [ ! -d $scripts_PATH/package ];then
mkdir $scripts_PATH/package
fi

echo "StrictHostKeyChecking no" > ~/.ssh/config

function Checkansible () {
if ! type ansible  >/dev/null 2>&1;then
echo  ansible 未安装a,现正在安装ansible
yum list |grep ansible
if [ $? -eq 0 ];then
yum install -y  ansible 
else
echo "yum 源中没有ansible,请手动安装ansible"
fi
fi
}

Checkansible

echo -e "以下为安装前提说明，请确认是否满足条件"
echo -e "1、同一个网络内只要部署一个prometheus即可"
echo -e "2、此脚本部署方式为二进制部署"




function prometheus_Version () {
if [[ -z "$prometheus_Version" || "$prometheus_Version" =~ "2.22.1" ]];then
prometheus_Version=2.22.1
rm -f $scripts_PATH/package/prometheus-*
wget -P $scripts_PATH/package  https://github.com/prometheus/prometheus/releases/download/v2.22.1/prometheus-2.22.1.linux-amd64.tar.gz
sed -i "s/^Cni_version:.*/Cni_version: ${Cni_version}/" ${scripts_PATH}/k8s_init/vars/main.yml
else
rm -f $scripts_PATH/package/prometheus-*
wget -P $scripts_PATH/package  https://github.com/prometheus/prometheus/releases/download/v"$prometheus_Version"/prometheus-"$prometheus_Version".linux-amd64.tar.gz
sed -i "s/^Cni_version:.*/Cni_version: ${Cni_version}/" ${scripts_PATH}/k8s_init/vars/main.yml
fi
scp  $scripts_PATH/package/cni-* ${scripts_PATH}/k8s_init/files/
}





read -r -p "确认是否安装prometheus? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then

echo "环境部署安装prometheus"
read -r -p "请输入prometheus版本号，默认为0.8.7 : " Prometheus_version
prometheus_Version



