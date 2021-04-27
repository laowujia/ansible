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
192.168.228.201 hostname=master02  ansible_ssh_pass=123456 ansible_user=root
192.168.228.202 hostname=master03  ansible_ssh_pass=123456 ansible_user=root
[k8s_node]
192.168.228.203 hostname=node01 ansible_ssh_pass=123456 ansible_user=root
192.168.228.204 hostname=node02 ansible_ssh_pass=123456 ansible_user=root
192.168.228.205 hostname=node03 ansible_ssh_pass=123456 ansible_user=root
192.168.228.206 hostname=node04 ansible_ssh_pass=123456 ansible_user=root
192.168.228.207 hostname=node05 ansible_ssh_pass=123456 ansible_user=root
"

echo "环境部署安装初始化"
#grep "hostname=" /etc/ansible/hosts|awk '{print $1 ,$2}'|awk -F 'hostname=' '{print $1 $2}' >>/etc/hosts
IP=`awk '{print $1}' /etc/ansible/hosts/hosts |grep -v "k8s"|head -n 1`
grep "$IP" /etc/hosts >>/dev/null 2>&1
if [ $? -ne 0 ];then
grep "hostname=" ${scripts_PATH}/hosts|awk '{print $1 ,$2}'|awk -F 'hostname=' '{print $1 $2}' >>/etc/hosts
fi


###添加docker yum 源
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

#####添加kubernetes yum 源
scp  $scripts_PATH/k8s_init/files/kubernetes.repo /etc/yum.repos.d/kubernetes.repo


#########################################################################################################################
function docker_Version () {
if [[ -z "$Docker_version"  ]];then
sed -i "s/^Docker_version:.*/Docker_version: ${Docker_version}/" ${scripts_PATH}/k8s_init/vars/main.yml
else
yum list docker-ce --showduplicates | sort -r |grep ${Docker_version} > /dev/null
if [ $? -eq 0 ];then
sed -i "s/^Docker_version:.*/Docker_version: -${Docker_version}/" ${scripts_PATH}/k8s_init/vars/main.yml
else
echo "yum源中没有这个版本，请重新输入"
fi
fi
}

function kubeadm_Version () {
if [[ -z "$Kubeadm_version"  ]];then
sed -i "s/^Kubeadm_version:.*/Kubeadm_version: ${Kubeadm_version}/" ${scripts_PATH}/k8s_init/vars/main.yml
else
yum list kubeadm --showduplicates | sort -r |grep ${Kubeadm_version} >/dev/null
if [ $? -eq 0 ];then
sed -i "s/^Kubeadm_version:.*/Kubeadm_version: ${Kubeadm_version}/" ${scripts_PATH}/k8s_init/vars/main.yml
else
echo "yum源中没有这个版本，请重新输入"
fi
fi
}

read -r -p "请输入k8s 集群docker 版本号，比如:19.03.9 ,默认为最新版本 : " Docker_version
docker_Version

read -r -p "请输入k8s 集群kubeadm 版本号，比如:1.17.17 ,默认为最新版本 : " Kubeadm_version
kubeadm_Version


cd $scripts_PATH
ansible-playbook k8s_init.yaml

ansible-playbook k8s_master.yaml

Ansible_IP=`sed -n '/k8s_master/{n;p;}' /etc/ansible/hosts |awk '{print $1}'`

scp $Ansible_IP:/root/add_node.sh  $scripts_PATH/k8s_node/files/

ansible-playbook k8s_node.yaml
