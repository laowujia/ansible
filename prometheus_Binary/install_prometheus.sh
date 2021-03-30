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
echo -e "3、环境中需要有一台服务器安装docker，用来部署consul"




function prometheus_Version () {
if [[ -z "$Prometheus_version" || "$Prometheus_version" =~ "2.22.1" ]];then
Prometheus_version=2.22.1
#rm -f $scripts_PATH/package/prometheus-*
#wget -P $scripts_PATH/package  https://github.com/prometheus/prometheus/releases/download/v2.22.1/prometheus-2.22.1.linux-amd64.tar.gz
sed -i "s/^Prometheus_verison:.*/Prometheus_verison: ${Prometheus_version}/" ${scripts_PATH}/prometheus/vars/main.yml
else
rm -f $scripts_PATH/package/prometheus-*
wget -P $scripts_PATH/package  https://github.com/prometheus/prometheus/releases/download/v"$Prometheus_version"/prometheus-"$Prometheus_version".linux-amd64.tar.gz
sed -i "s/^Prometheus_verison:.*/Prometheus_verison: ${Prometheus_version}/" ${scripts_PATH}/prometheus/vars/main.yml
fi
scp  $scripts_PATH/package/prometheus-* ${scripts_PATH}/prometheus/files/
}



function alertmanager_Version () {
if [[ -z "$Alertmanager_version" || "$Alertmanager_version" =~ "0.21.0" ]];then
Alertmanager_version=0.21.0
#rm -f $scripts_PATH/package/alertmanager-*
#wget -P $scripts_PATH/package  https://github.com/prometheus/alertmanager/releases/download/v0.21.0/alertmanager-0.21.0.linux-amd64.tar.gz
sed -i "s/^Alertmanager_version:.*/Alertmanager_version: ${Alertmanager_version}/" ${scripts_PATH}/prometheus/vars/main.yml
else
rm -f $scripts_PATH/package/alertmanager-*
wget -P $scripts_PATH/package  https://github.com/prometheus/alertmanager/releases/download/v"$Alertmanager_version"/alertmanager-"$Alertmanager_version".linux-amd64.tar.gz
sed -i "s/^Alertmanager_version:.*/Alertmanager_version: ${Alertmanager_version}/" ${scripts_PATH}/prometheus/vars/main.yml
fi
scp  $scripts_PATH/package/alertmanager-* ${scripts_PATH}/prometheus/files/
}

function node_exporter_Version () {
if [[ -z "$Node_exporter_version" || "$Node_exporter_version" =~ "1.0.1" ]];then
Node_exporter_version=0.21.0
#rm -f $scripts_PATH/package/node_exporter-*
#wget -P $scripts_PATH/package  https://github.com/prometheus/alertmanager/releases/download/v0.21.0/alertmanager-0.21.0.linux-amd64.tar.gz
sed -i "s/^Node_exporter_version:.*/Node_exporter_version: ${Node_exporter_version}/" ${scripts_PATH}/prometheus/vars/main.yml
else
rm -f $scripts_PATH/package/node_exporter-*
wget -P $scripts_PATH/package  https://github.com/prometheus/node_exporter/releases/download/v"$Node_exporter_version"/node_exporter-"$Node_exporter_version".linux-amd64.tar.gz
sed -i "s/^Node_exporter_version:.*/Node_exporter_version: ${Node_exporter_version}/" ${scripts_PATH}/prometheus/vars/main.yml
fi
scp  $scripts_PATH/package/node_exporter-* ${scripts_PATH}/prometheus/files/
}


read -r -p "确认是否安装prometheus? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then

echo "环境部署安装prometheus"
read -r -p "请输入prometheus版本号，默认为2.22.1 : " Prometheus_version
prometheus_Version
read -r -p "请输入alertmanager版本号，默认为0.21.0 : " Alertmanager_version
alertmanager_Version
read -r -p "请输入部署consul服务器IP（确保事先已经按照docker）,例如：192.168.228.200: "Consul_IP
sed -i "s/^Consul_IP:.*/Consul_IP: ${Consul_IP}/" ${scripts_PATH}/prometheus/vars/main.yml
read -r -p "请输入部署prometheus服务器IP,例如：192.168.228.200: "Prometheus_IP
cat > ${scripts_PATH}/prometheus_hosts << EOF
[prometheus]
$Prometheus_IP
EOF
sed -i "s/^Prometheus_IP:.*/Prometheus_IP: ${Prometheus_IP}/" ${scripts_PATH}/prometheus/vars/main.yml
cd ${scripts_PATH}/
ansible-playbook -i ${scripts_PATH}/prometheus_hosts prometheus.yaml
fi

read -r -p "确认是否安装node_exporter? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then

echo "环境部署安装nodex_exporter"
read -r -p "请输入nodex_exporter版本号，默认为1.0.1 : " Node_exporter_version
node_exporter_Version
read -r -p "请输入所有需要安装node_exporter的服务器IP,一次输入一个IP,然后回车，输入完毕后回车,例: 192.168.228.208 :" IP
i=1
#echo $IP >>${scripts_PATH}/node_exporter_hosts
while [ -n "$IP" ]
do
echo $IP >>${scripts_PATH}/node_exporter_hosts
read -r -p "请输入所有需要安装node_exporter的服务器IP,一次输入一个IP,然后回车，输入完毕后回车,例: 192.168.228.208 :" IP
((i++))
done

ansible-playbook -i ${scripts_PATH}/node_exporter_hosts prometheus.yaml
fi
