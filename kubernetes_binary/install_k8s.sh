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
echo -e "1、脚本必须运行在其中一个master服务器上"
echo -e "2、安装环境centos7,部署方式为二进制"
echo -e "3、master和etcd部署在相同服务器上"
echo -e "4、master为3个服务器"
echo -e "5、安装的docker为最新版本，如果想要指定版本，请另行安装"
echo -e "6、请先修改设置好inventory($scripts_PATH/hosts),如果已经做了免密可以删除ansible_ssh_pass和ansible_user字段 如:"
echo "[k8s_master]
192.168.228.200 hostname=k8s_master01  ansible_ssh_pass=123456 ansible_user=root
192.168.228.201 hostname=k8s_master02  ansible_ssh_pass=123456 ansible_user=root
192.168.228.202 hostname=k8s_master03  ansible_ssh_pass=123456 ansible_user=root
[k8s_node]
192.168.228.203 hostname=k8s_node01 ansible_ssh_pass=123456 ansible_user=root
192.168.228.204 hostname=k8s_node02 ansible_ssh_pass=123456 ansible_user=root
192.168.228.205 hostname=k8s_node03 ansible_ssh_pass=123456 ansible_user=root
192.168.228.206 hostname=k8s_node04 ansible_ssh_pass=123456 ansible_user=root
192.168.228.207 hostname=k8s_node05 ansible_ssh_pass=123456 ansible_user=root
"

######################################环境部署安装初始化并安装docker########################

function cni_Version () {
if [[ -z "$Cni_version" || "$Cni_version" =~ "0.8.7" ]];then
Cni_version=0.8.7
rm -f $scripts_PATH/package/cni-*
wget -P $scripts_PATH/package  https://github.com/containernetworking/plugins/releases/download/v0.8.7/cni-plugins-linux-amd64-v0.8.7.tgz
sed -i "s/^Cni_version:.*/Cni_version: ${Cni_version}/" ${scripts_PATH}/k8s_init/vars/main.yml
else
rm -f $scripts_PATH/package/cni-*
wget -P $scripts_PATH/package  https://github.com/containernetworking/plugins/releases/download/v"$Cni_version"/cni-plugins-linux-amd64-v"$Cni_version".tgz
sed -i "s/^Cni_version:.*/Cni_version: ${Cni_version}/" ${scripts_PATH}/k8s_init/vars/main.yml
fi
scp  $scripts_PATH/package/cni-* ${scripts_PATH}/k8s_init/files/
}


function system_init() {
IP=`awk '{print $1}' ${scripts_PATH}/hosts |grep -v "k8s"|head -n 1`
grep "$IP" /etc/hosts >>/dev/null 2>&1
if [ $? -ne 0 ];then
grep "hostname=" ${scripts_PATH}/hosts|awk '{print $1 ,$2}'|awk -F 'hostname=' '{print $1 $2}' >>/etc/hosts
fi
cd $scripts_PATH
ansible-playbook -i ${scripts_PATH}/hosts k8s_init.yaml

}

read -r -p "确认是否环境部署安装初始化并安装docker? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then

echo "环境部署安装初始化并安装docker"
read -r -p "请输入cni版本号，默认为0.8.7 : " Cni_version
cni_Version

system_init
fi

#######################安装证书管理工具cfssl #########################
#cd $scripts_PATH/package
#wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64  && wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 && wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
#if [ -f $scripts_PATH/package/cfssl_linux-amd64 ] ;then
#chmod +x cfssl_linux-amd64 cfssljson_linux-amd64 cfssl-certinfo_linux-amd64
#mv cfssl_linux-amd64 /usr/local/bin/cfssl   && mv cfssljson_linux-amd64 /usr/local/bin/cfssljson && mv cfssl-certinfo_linux-amd64 /usr/bin/cfssl-certinfo
#fi


################################ETCD##########################

function etcd_Version () {
if [[ -z "$Etcd_version" || "$Etcd_version" =~ "3.4.13" ]];then
Etcd_version=3.4.13
rm -f $scripts_PATH/package/etcd*
wget -P $scripts_PATH/package  https://github.com/etcd-io/etcd/releases/download/v3.4.13/etcd-v3.4.13-linux-amd64.tar.gz
sed -i "s/^Etcd_version:.*/Etcd_version: ${Etcd_version}/" ${scripts_PATH}/k8s_etcd/vars/main.yml
else
rm -f $scripts_PATH/package/etcd*
wget -P $scripts_PATH/package https://github.com/etcd-io/etcd/releases/download/v"$Etcd_version"/etcd-v"$Etcd_version"-linux-amd64.tar.gz
sed -i "s/^Etcd_version:.*/Etcd_version: ${Etcd_version}/" ${scripts_PATH}/k8s_etcd/vars/main.yml
fi
scp  $scripts_PATH/package/etcd-* ${scripts_PATH}/k8s_etcd/files/
}


read -r -p "确认是否安装etcd? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "进行安装etcd"

echo "etcd自签证书"

if [ ! -d $scripts_PATH/package/etcd ];then
mkdir $scripts_PATH/package/etcd
fi


cat > $scripts_PATH/package/etcd/ca-config.json << EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "www": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
EOF


cat > $scripts_PATH/package/etcd/ca-csr.json << EOF
{
    "CN": "etcd CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing"
        }
    ]
}
EOF
if [ ! -f $scripts_PATH/package/etcd/ca-key.pem ] ;then
cd $scripts_PATH/package/etcd/
/usr/local/bin/cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
fi

echo "目前只做三台服务器的ETCD集群"
read -r -p "请输入etcd第一台IP,例如: 192.168.228.200 : " master_IP1

read -r -p "请输入etcd第二台IP,例如: 192.168.228.201 : " master_IP2

read -r -p "请输入etcd第三台IP,例如: 192.168.228.202 : " master_IP3

cat > $scripts_PATH/etcd_hosts << EOF
[etcd]
$master_IP1
$master_IP2
$master_IP3
EOF

cat > $scripts_PATH/package/etcd/server-csr.json << EOF
{
    "CN": "etcd",
    "hosts": [
    "${master_IP1}",
    "${master_IP2}",
    "${master_IP3}"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "BeiJing",
            "ST": "BeiJing"
        }
    ]
}
EOF

if [ ! -f $scripts_PATH/package/etcd/server-key.pem ] ;then
cd $scripts_PATH/package/etcd/
/usr/local/bin/cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www server-csr.json | cfssljson -bare server
fi

scp $scripts_PATH/package/etcd/*pem ${scripts_PATH}/k8s_etcd/files/

sed -i "s/^K8s_master01:.*/K8s_master01: ${master_IP1}/" ${scripts_PATH}/k8s_etcd/vars/main.yml
sed -i "s/^K8s_master01:.*/K8s_master01: ${master_IP1}/" ${scripts_PATH}/k8s_master/vars/main.yml
sed -i "s/^K8s_master01:.*/K8s_master01: ${master_IP1}/" ${scripts_PATH}/nginx_keepalived/vars/main.yml
sed -i "s/^K8s_master02:.*/K8s_master02: ${master_IP2}/" ${scripts_PATH}/k8s_etcd/vars/main.yml
sed -i "s/^K8s_master02:.*/K8s_master02: ${master_IP2}/" ${scripts_PATH}/k8s_master/vars/main.yml
sed -i "s/^K8s_master02:.*/K8s_master02: ${master_IP2}/" ${scripts_PATH}/nginx_keepalived/vars/main.yml
sed -i "s/^K8s_master03:.*/K8s_master03: ${master_IP3}/" ${scripts_PATH}/k8s_etcd/vars/main.yml
sed -i "s/^K8s_master03:.*/K8s_master03: ${master_IP3}/" ${scripts_PATH}/k8s_master/vars/main.yml
sed -i "s/^K8s_master03:.*/K8s_master03: ${master_IP3}/" ${scripts_PATH}/nginx_keepalived/vars/main.yml

read -r -p "请输入etcd版本号，默认为3.4.13 : " Etcd_version
etcd_Version

cd ${scripts_PATH}
ansible-playbook -i $scripts_PATH/etcd_hosts k8s_etcd.yaml
if [ $? -eq 0 ];then
echo "etcd安装完成，检测etcd集群状态"

ETCDCTL_API=3 /opt/etcd/bin/etcdctl --cacert=/opt/etcd/ssl/ca.pem --cert=/opt/etcd/ssl/server.pem --key=/opt/etcd/ssl/server-key.pem --endpoints="https://"$master_IP1":2379,https://"$master_IP2":2379,https://"$master_IP3":2379" endpoint health
fi
fi


########################################################安装kube-apiserver kube-scheduler kube-controller-manager#################################################


function k8s_Version () {
if [[ -z "$K8s_version" || "$K8s_version" =~ "1.19.1" ]];then
K8s_version=1.19.1
#rm -f $scripts_PATH/package/kubernetes-*
#wget -P $scripts_PATH/package  wget https://dl.k8s.io/v1.19.1/kubernetes-server-linux-amd64.tar.gz
else
rm -f $scripts_PATH/package/kubernetes-*
wget -P $scripts_PATH/package  wget https://dl.k8s.io/v"$K8s_version"/kubernetes-server-linux-amd64.tar.gz
echo 1
fi
scp  $scripts_PATH/package/kubernetes-* ${scripts_PATH}/k8s_master/files/
scp  $scripts_PATH/package/kubernetes-* ${scripts_PATH}/k8s_node/files/
}

read -r -p "请输入k8s版本号，默认为1.19.1 : " K8s_version
k8s_Version

read -r -p "确认是否部署k8s_master? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "部署 k8s_master"

if [ ! -d $scripts_PATH/package/k8s ];then
mkdir $scripts_PATH/package/k8s
fi

############################ssl证书####################
cat > $scripts_PATH/package/k8s/ca-config.json << EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
EOF


cat > $scripts_PATH/package/k8s/ca-csr.json << EOF
{
    "CN": "kubernetes",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

if [ ! -f $scripts_PATH/package/k8s/ca-key.pem ];then
cd $scripts_PATH/package/k8s/
/usr/local/bin/cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
fi

rm -f $scripts_PATH/package/k8s/server-csr.json
read -r -p "请输入所有Master/LB/VIP IP，一个都不能少！为了方便后期扩容可以多写几个预留的IP,一次输入一个IP,然后回车，输入完毕后回车,例: 192.168.228.208 :" IP
i=1
echo "{" >>$scripts_PATH/package/k8s/server-csr.json
echo "    \"CN\": \"kubernetes\"," >>$scripts_PATH/package/k8s/server-csr.json
echo "    \"hosts\": ["   >>$scripts_PATH/package/k8s/server-csr.json
echo "      \"10.0.0.1\"," >>$scripts_PATH/package/k8s/server-csr.json
echo "      \"127.0.0.1\"," >>$scripts_PATH/package/k8s/server-csr.json
while [ -n "$IP" ]
do
echo "      \"${IP}\"," >>$scripts_PATH/package/k8s/server-csr.json
read -r -p "请输入所有Master/LB/VIP IP，一个都不能少！为了方便后期扩容可以多写几个预留的IP,一次输入一个IP,然后回车,输入完毕后回车,例: 192.168.228.208 :" IP
((i++))
done
echo "      \"kubernetes\"," >>$scripts_PATH/package/k8s/server-csr.json
echo "      \"kubernetes.default\"," >>$scripts_PATH/package/k8s/server-csr.json
echo "      \"kubernetes.default.svc\"," >>$scripts_PATH/package/k8s/server-csr.json
echo "      \"kubernetes.default.svc.cluster\"," >>$scripts_PATH/package/k8s/server-csr.json
echo "      \"kubernetes.default.svc.cluster.local\"" >>$scripts_PATH/package/k8s/server-csr.json
echo "    ]," >>$scripts_PATH/package/k8s/server-csr.json
echo "    \"key\": {" >>$scripts_PATH/package/k8s/server-csr.json
echo "        \"algo\": \"rsa\"," >>$scripts_PATH/package/k8s/server-csr.json
echo "        \"size\": 2048" >>$scripts_PATH/package/k8s/server-csr.json
echo "    }," >>$scripts_PATH/package/k8s/server-csr.json
echo "    \"names\": [" >>$scripts_PATH/package/k8s/server-csr.json
echo "        {" >>$scripts_PATH/package/k8s/server-csr.json
echo "            \"C\": \"CN\"," >>$scripts_PATH/package/k8s/server-csr.json
echo "            \"L\": \"BeiJing\"," >>$scripts_PATH/package/k8s/server-csr.json
echo "            \"ST\": \"BeiJing\"," >>$scripts_PATH/package/k8s/server-csr.json
echo "            \"O\": \"k8s\"," >>$scripts_PATH/package/k8s/server-csr.json
echo "            \"OU\": \"System\"" >>$scripts_PATH/package/k8s/server-csr.json
echo "        }" >>$scripts_PATH/package/k8s/server-csr.json
echo "    ]" >>$scripts_PATH/package/k8s/server-csr.json
echo "}" >>$scripts_PATH/package/k8s/server-csr.json

#read -r -p "请输入部署K8S的IP段 ，例: 192.168.228.0/24 :" IP_segment
#
#cat > $scripts_PATH/package/k8s/server-csr.json << EOF
#{
#    "CN": "kubernetes",
#    "hosts": [
#      "10.0.0.1",
#      "127.0.0.1",
#      "$IP_segment",
#      "kubernetes",
#      "kubernetes.default",
#      "kubernetes.default.svc",
#      "kubernetes.default.svc.cluster",
#      "kubernetes.default.svc.cluster.local"
#    ],
#    "key": {
#        "algo": "rsa",
#        "size": 2048
#    },
#    "names": [
#        {
#            "C": "CN",
#            "L": "BeiJing",
#            "ST": "BeiJing",
#            "O": "k8s",
#            "OU": "System"
#        }
#    ]
#}
#EOF


cat > $scripts_PATH/package/k8s/kube-proxy-csr.json << EOF
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "BeiJing",
      "ST": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF





TOKEN="87f2fc3ccad8123f2deee204131e1d99"
sed -i "s/^Token:.*/Token: ${TOKEN}/" ${scripts_PATH}/k8s_master/vars/main.yml

if [ ! -f  $scripts_PATH/package/k8s/server-key.pem ];then
cd $scripts_PATH/package/k8s/
/usr/local/bin/cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes server-csr.json | cfssljson -bare server
fi
scp $scripts_PATH/package/k8s/*pem ${scripts_PATH}/k8s_master/files/

cd $scripts_PATH
ansible-playbook -i ${scripts_PATH}/hosts k8s_master.yaml

kubectl create clusterrolebinding kubelet-bootstrap \
--clusterrole=system:node-bootstrapper \
--user=kubelet-bootstrap


#查看集群状态
kubectl get cs


fi


########################apiserver Keepalived#############################
function NIC_version () {
if [[ -z "$Nic_version" || "$Nic_version" =~ "ens33" ]];then
Nic_version=ens33
sed -i "s/^NIC:.*/NIC: "${Nic_version}"/" ${scripts_PATH}/nginx_keepalived/vars/main.yml
else
sed -i "s/^NIC:.*/NIC: "${Nic_version}"/" ${scripts_PATH}/nginx_keepalived/vars/main.yml
fi
}

read -r -p "确认是否部署apiserver Keepalived? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "部署 apiserver Keepalived"

echo "目前apiserver Keepalived 只提供了主备模式"

read -r -p "请输入Keepalived masterIP,例如: 192.168.228.200 : " nginx_IP1
read -r -p "请输入Keepalived slaveIP,例如: 192.168.228.201 : " nginx_IP2
cat > $scripts_PATH/nginx_hosts << EOF
[Keepalived]
$nginx_IP1   servertype=master priority=100
$nginx_IP2   servertype=slave  priority=90
EOF


read -r -p "请输入部署Keepalived的网卡名称，默认为：ens33 : " Nic_version
NIC_version

read -r -p "请输入部署Keepalived的VIP，例如：192.168.228.250 : " KVip
sed -i "s/^Vip:.*/Vip: "${KVip}"/" ${scripts_PATH}/nginx_keepalived/vars/main.yml


cd $scripts_PATH
ansible-playbook -i ${scripts_PATH}/nginx_hosts nginx_keepalived.yaml 
if [ $? -eq 0 ];then
sleep 10
curl -k https://"$KVip":64435/version
fi

scp $scripts_PATH/package/k8s/ca.pem $scripts_PATH/k8s_node/files/

cd $scripts_PATH/k8s_node/files/

KUBE_APISERVER="https://"$KVip":64435"
echo $KUBE_APISERVER
kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=bootstrap.kubeconfig
kubectl config set-credentials "kubelet-bootstrap" \
  --token=${TOKEN} \
  --kubeconfig=bootstrap.kubeconfig
kubectl config set-context default \
  --cluster=kubernetes \
  --user="kubelet-bootstrap" \
  --kubeconfig=bootstrap.kubeconfig
kubectl config use-context default --kubeconfig=bootstrap.kubeconfig


if [ ! -f  $scripts_PATH/package/k8s/kube-proxy-key.pem ];then
cd $scripts_PATH/package/k8s/
/usr/local/bin/cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy
fi
scp $scripts_PATH/package/k8s/*pem ${scripts_PATH}/k8s_node/files/



cd $scripts_PATH/k8s_node/files/

kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config set-credentials kube-proxy \
  --client-certificate=./kube-proxy.pem \
  --client-key=./kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

fi
echo ${KUBE_APISERVER}
read -r -p "确认是否部署k8s node? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "部署 k8s node"


cd $scripts_PATH
ansible-playbook -i ${scripts_PATH}/hosts k8s_node.yaml


for i in `kubectl get csr|grep Pending|awk '{print $1}'`;do
kubectl certificate approve $i
done
fi
read -r -p "确认是否部署k8s 完成? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "结束收尾"
#/usr/bin/kubectl apply -f ${scripts_PATH}/package/kube-flannel.yml
/usr/bin/kubectl apply -f ${scripts_PATH}/package/apiserver-to-kubelet-rbac.yaml
/usr/bin/kubectl apply -f ${scripts_PATH}/package/coredns.yaml
fi
