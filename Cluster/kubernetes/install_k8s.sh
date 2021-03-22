#!/bin/bash
scripts_PATH="$( cd "$( dirname "$0"  )" && pwd  )"
echo $scripts_PATH

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
echo -e "1、安装环境centos7,部署方式为kubeadm"
echo -e "2、请先修改设置好inventory(/etc/ansible/hosts),如果已经做了免密可以删除ansible_ssh_pass和ansible_user字段 如:"
echo "[k8s_master]
192.168.228.200 hostname=master01  ansible_ssh_pass=123456 ansible_user=root
[k8s_node]
192.168.228.203 hostname=node01 ansible_ssh_pass=123456 ansible_user=root
192.168.228.204 hostname=node02 ansible_ssh_pass=123456 ansible_user=root
192.168.228.205 hostname=node03 ansible_ssh_pass=123456 ansible_user=root
192.168.228.206 hostname=node04 ansible_ssh_pass=123456 ansible_user=root
192.168.228.207 hostname=node05 ansible_ssh_pass=123456 ansible_user=root
"

echo "环境部署安装初始化"
grep "hostname=" /etc/ansible/hosts|awk '{print $1 ,$2}'|awk -F 'hostname=' '{print $1 $2}' >>/etc/hosts


cd $scripts_PATH
ansible-playbook k8s_init.yaml

ansible-playbook k8s_master.yaml

Ansible_IP=`sed -n '/k8s_master/{n;p;}' /etc/ansible/hosts |awk '{print $1}'`

scp $Ansible_IP:/root/add_node.sh  $scripts_PATH/k8s_node/files/

ansible-playbook k8s_node.yaml
