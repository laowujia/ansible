#!/bin/bash
#定义外部输入确认的正则
export YES_REGULAR="^[yY][eE][sS]|[yY]$"

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


##############检查IP 合法性##############
function CheckIPAddr () {
echo $1 |grep "^[0-9]\{1,3\}\.\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}$" >/dev/null;
if [ $? -ne 0 ]
then
        return 1
fi
ipaddr=$1
a=`echo $ipaddr|awk -F . '{print $1}'`
b=`echo $ipaddr|awk -F . '{print $2}'`
c=`echo $ipaddr|awk -F . '{print $3}'`
d=`echo $ipaddr|awk -F . '{print $4}'`
for num in $a $b $c $d
do
  if [ $num -gt 255 ] || [ $num -lt 0 ]
  then
     return 1
    fi
done
   return 0
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
read -r -p "确认安装kubeadm及依赖? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "安装kubeadm及依赖"

echo "环境部署安装初始化"
#grep "hostname=" /etc/ansible/hosts|awk '{print $1 ,$2}'|awk -F 'hostname=' '{print $1 $2}' >>/etc/hosts
#IP=`awk '{print $1}' /etc/ansible/hosts |grep -v "#" |grep -v ^$ |grep -v "k8s" |head -n 1`
IP=`awk '{print $1}' /etc/ansible/hosts | egrep -o "([0-9]{1,3}.){3}[0-9]{1,3}" |head -n 1`
grep "$IP" /etc/hosts >>/dev/null 2>&1
if [ $? -ne 0 ];then
grep "hostname=" /etc/ansible/hosts|awk '{print $1 ,$2}'|awk -F 'hostname=' '{print $1 $2}' >>/etc/hosts
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
sed -i "s/^Kubeadm_version:.*/Kubeadm_version: -${Kubeadm_version}/" ${scripts_PATH}/k8s_init/vars/main.yml
else
echo "yum源中没有这个版本，请重新输入"
fi
fi
}

read -r -p "请输入k8s 集群docker 版本号，比如:19.03.9 ,默认为最新版本 : " Docker_version
docker_Version

read -r -p "请输入k8s 集群kubeadm 版本号，比如:1.17.17 ,默认为最新版本 : " Kubeadm_version
kubeadm_Version

#read -r -p "请输入k8s 集群kubeadm初始化的第一个master服务器 IP : " Master_IP
#CheckIPAddr $Master_IP
#if [ $? -eq 0 ];then
#cat > ${scripts_PATH}/k8s_master_hosts << EOF
#[k8s_master]
#$Master_IP
#EOF
#else
#echo "输入 $Master_IP IP 不合法"
#fi

#read -r -p "确认安装kubeadm及依赖? [Y/n]:" input_confirm
#if [[ $input_confirm =~ $YES_REGULAR ]]; then
#echo "安装kubeadm及依赖"

cd $scripts_PATH
ansible-playbook k8s_init.yaml
fi

read -r -p "确认安装部署haproxy keepalived(三节点)? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "安装部署haproxy keepalived"
read -r -p "请输入的keepalived 第一个VIP : " VIP
CheckIPAddr $VIP
if [ $? -eq 0 ];then
sed -i "s/^VIP:.*/VIP: ${VIP}/" ${scripts_PATH}/ha_keepalived/vars/main.yml
else
echo "输入 IP 不合法,请确认"
fi
read -r -p "请输入的keepalived 第一个master节点IP : " HA_Master_IP
read -r -p "请输入的keepalived 第一个BACKUP节点IP : " HA_BACKUP_IP
read -r -p "请输入的keepalived 第二个BACKUP节点IP : " HA_BACKUP_IP1
CheckIPAddr $HA_Master_IP && CheckIPAddr $HA_BACKUP_IP && CheckIPAddr $HA_BACKUP_IP1

if [ $? -eq 0 ];then
cat > ${scripts_PATH}/k8s_HA_hosts << EOF
[ha_keepalived]
$HA_Master_IP
$HA_BACKUP_IP
$HA_BACKUP_IP1
EOF
sed -i "s/^Master01:.*/Master01: ${HA_Master_IP}/" ${scripts_PATH}/ha_keepalived/vars/main.yml
sed -i "s/^Master02:.*/Master02: ${HA_BACKUP_IP}/" ${scripts_PATH}/ha_keepalived/vars/main.yml
sed -i "s/^Master03:.*/Master03: ${HA_BACKUP_IP1}/" ${scripts_PATH}/ha_keepalived/vars/main.yml
else
echo "输入 IP 不合法,请确认"
fi
cd $scripts_PATH
ansible-playbook -i k8s_HA_hosts  ha_keepalived.yaml
fi

#ansible-playbook k8s_master.yaml

#Ansible_IP=`sed -n '/k8s_master/{n;p;}' /etc/ansible/hosts |awk '{print $1}'`

#scp $Ansible_IP:/root/add_node.sh  $scripts_PATH/k8s_node/files/

#ansible-playbook k8s_node.yaml
