#!/bin/bash
#定义外部输入确认的正则
export YES_REGULAR="^[yY][eE][sS]|[yY]$"

scripts_PATH="$( cd "$( dirname "$0"  )" && pwd  )"
echo $scripts_PATH

if [ ! -d $scripts_PATH/package ];then
mkdir $scripts_PATH/package
fi

#################################################elasticsearch############################################

function es_Version () {
if [[ -z "$ES_version" || "$ES_version" =~ "7.6.2" ]];then
ES_version=7.6.2
rm -f $scripts_PATH/package/elasticsearch*
wget -P $scripts_PATH/package  "http://yum.itestcn.com/github/elasticsearch/release/elasticsearch-7.6.2-linux-x86_64.tar.gz"
wget -P $scripts_PATH/package  "http://yum.itestcn.com/github/elasticsearch/release/elasticsearch-analysis-ik-7.6.2.zip"
sed -i "s/^ES_VERSION:.*/ES_VERSION: 7.6.2/" ${scripts_PATH}/alone/alone_es/vars/main.yml
sed -i "s/^ES_VERSION:.*/ES_VERSION: 7.6.2/" ${scripts_PATH}/cluster/cluster_es/vars/main.yml
else
sed -i "s/^ES_VERSION:.*/ES_VERSION: ${ES_version}/" ${scripts_PATH}/alone/alone_es/vars/main.yml
sed -i "s/^ES_VERSION:.*/ES_VERSION: ${ES_version}/" ${scripts_PATH}/cluster/cluster_es/vars/main.yml
wget -P $scripts_PATH/package https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-"$ES_version"-linux-x86_64.tar.gz
wget -P $scripts_PATH/package https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v"$ES_version"/elasticsearch-analysis-ik-"$ES_version".zip
fi
}


function es_Memory () {
if [ -z "$ES_memory" ] ;then
ES_memory=2G
sed -i "s/^ES_memory:.*/ES_memory: "${ES_memory}"/" ${scripts_PATH}/alone/alone_es/vars/main.yml
sed -i "s/^ES_memory:.*/ES_memory: "${ES_memory}"/" ${scripts_PATH}/cluster/cluster_es/vars/main.yml
else
sed -i "s/^ES_memory:.*/ES_memory: "${ES_memory}"/" ${scripts_PATH}/alone/alone_es/vars/main.yml
sed -i "s/^ES_memory:.*/ES_memory: "${ES_memory}"/" ${scripts_PATH}/cluster/cluster_es/vars/main.yml
fi
}

function es_Mode () {
if [[ -z "$ES_mode" || "$ES_mode" == "1" ]];then
scp $scripts_PATH/package/elasticsearch* $scripts_PATH/alone/alone_es/files
read -r -p "请输入部署单机elasticsearch的服务器IP,例如: 192.168.228.208 : " alone_es_IP
cat > ${scripts_PATH}/hosts << EOF
[alone_es]
$alone_es_IP
EOF
cd ${scripts_PATH}/alone/
ansible-playbook -i ${scripts_PATH}/hosts alone_es.yaml
echo  "elasticsearch 单机安装完成"
else
scp $scripts_PATH/package/elasticsearch* $scripts_PATH/cluster/cluster_es/files
read -r -p "请输入集群版elasticsearch服务器的第一个IP(主节点),例如: 192.168.228.204 : " cluster_IP1
read -r -p "请输入集群版elasticsearch服务器的第二个IP(从节点),例如: 192.168.228.205 : " cluster_IP2
read -r -p "请输入集群版elasticsearch服务器的第三个IP(从节点),例如: 192.168.228.206 : " cluster_IP3
cat > ${scripts_PATH}/hosts << EOF
[cluster_es]
$cluster_IP1
$cluster_IP2
$cluster_IP3
EOF
sed -i "s/^Discovery_seed_hosts:.*/Discovery_seed_hosts: "$cluster_IP1"/" ${scripts_PATH}/cluster/cluster_es/vars/main.yml
Master_hostname=`ansible "$cluster_IP1" -m shell  -a 'hostname'|awk 'END {print}'`
sed -i "s/^Master_nodes:.*/Master_nodes: "$Master_hostname"/" ${scripts_PATH}/cluster/cluster_es/vars/main.yml
cd ${scripts_PATH}/cluster/
ansible-playbook -i ${scripts_PATH}/hosts cluster_es.yaml
echo  "elasticsearch 集群安装完成"
fi
}

read -r -p "确认是否部署elasticsearch ? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "部署 elasticsearch"
read -r -p "请输入elasticsearch 版本号，默认为7.6.2 : " ES_version
es_Version

read -r -p "请输入elasticsearch jvm.optionsl配置 设置内存值 比如：2G 默认为2G : " ES_memory
es_Memory

read -r -p "请确认部署elasticsearch是集群版还是单机版？默认为单机版，输入1为单机版，输入2为集群版: " ES_mode
es_Mode
fi
##########################################################kibana##########################
function kibana_Version () {
if [[ -z "$Kibana_version" || "$Kibana_version" =~ "7.6.2" ]];then
Kibana_version=7.6.2
rm -f $scripts_PATH/package/kibana*
wget -P $scripts_PATH/package  http://yum.itestcn.com/github/elasticsearch/release/kibana-7.6.2-linux-x86_64.tar.gz
sed -i "s/^KIBANA_VERSION:.*/KIBANA_VERSION: ${Kibana_version}/" ${scripts_PATH}/alone/kibana/vars/main.yml
else
rm -f $scripts_PATH/package/kibana*
wget -P $scripts_PATH/package https://artifacts.elastic.co/downloads/kibana/kibana-"$Kibana_version"-linux-x86_64.tar.gz
sed -i "s/^KIBANA_VERSION:.*/KIBANA_VERSION: ${Kibana_version}/" ${scripts_PATH}/alone/kibana/vars/main.yml
fi
}


function kibana_Mode () {
cat > ${scripts_PATH}/hosts << EOF
[kibana]
$kibana_IP
EOF

cd ${scripts_PATH}/alone/
scp $scripts_PATH/package/kibana* $scripts_PATH/alone/kibana/files
ansible-playbook -i ${scripts_PATH}/hosts kibana.yaml
echo kibana部署完成
}

read -r -p "确认是否部署kibana ? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "部署 kibana"
read -r -p "请输入kibana 版本号，默认为7.6.2 : " Kibana_version
kibana_Version

read -r -p "请输入elasticsearch的服务器IP,如果kibana跟es部署在一起，可以不用输入IP，直接回车即可，例如: 192.168.228.208 : " es_IP
if [ -z "$es_IP" ] ;then
read -r -p "请输入部署kibana的服务器IP(建议跟es在一起) 例如: 192.168.228.208 : " kibana_IP
sed -i  "s/^IP:.*/IP: "${kibana_IP}"/" ${scripts_PATH}/alone/kibana/vars/main.yml
kibana_Mode
else
read -r -p "请输入部署kibana的服务器IP(建议跟es在一起) 例如: 192.168.228.208 : " kibana_IP
sed -i  "s/^IP:.*/IP: "${es_IP}"/" ${scripts_PATH}/alone/kibana/vars/main.yml
kibana_Mode
fi
fi


##########################################################kafka+zookeeper################################

function zookeeper_Version () {
if [[ -z "$Zookeeper_version" || "$Zookeeper_version" =~ "3.6.1" ]];then
Zookeeper_version=3.6.1
#rm -f $scripts_PATH/package/kibana*
#wget -P $scripts_PATH/package  http://yum.itestcn.com/github/zookeeper/release/apache-zookeeper-3.6.1-bin.tar.gz
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/alone/alone_zookeeper/vars/main.yml
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/cluster/cluster_zookeeper/vars/main.yml
else
wget -P $scripts_PATH/package https://mirrors.tuna.tsinghua.edu.cn/apache/zookeeper/zookeeper-"$Zookeeper_version"/apache-zookeeper-"$Zookeeper_version"-bin.tar.gz
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/alone/alone_zookeeper/vars/main.yml
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/cluster/cluster_zookeeper/vars/main.yml
fi
}

function zk_Mode () {
if [[ -z "$ZK_mode" || "$ZK_mode" == "1" ]];then
scp $scripts_PATH/package/apache-zookeeper* $scripts_PATH/alone/alone_zookeeper/files
read -r -p "请输入部署单机zookeeper的服务器IP,例如: 192.168.228.208 : " alone_zk_IP
cat > ${scripts_PATH}/hosts << EOF
[alone_zookeeper]
$alone_zk_IP
EOF
cd ${scripts_PATH}/alone/
ansible-playbook -i ${scripts_PATH}/hosts alone_zookeeper.yaml
echo  "zookeeper 单机安装完成"
else
scp $scripts_PATH/package/apache-zookeeper* $scripts_PATH/cluster/cluster_zookeeper/files
read -r -p "请输入集群版zookeeper服务器的第一个IP(主节点),例如: 192.168.228.204 : " cluster_ZKIP1
read -r -p "请输入集群版zookeeper服务器的第二个IP(从节点),例如: 192.168.228.205 : " cluster_ZKIP2
read -r -p "请输入集群版zookeeper服务器的第三个IP(从节点),例如: 192.168.228.206 : " cluster_ZKIP3
cat > ${scripts_PATH}/hosts << EOF
[cluster_zookeeper]
$cluster_ZKIP1  ZK_id=1
$cluster_ZKIP2  ZK_id=2
$cluster_ZKIP3  ZK_id=3
EOF
sed -i "s/^Zookpeer1_IP:.*/Zookpeer1_IP: ${cluster_ZKIP1}/" ${scripts_PATH}/cluster/cluster_zookeeper/vars/main.yml
sed -i "s/^Zookpeer2_IP:.*/Zookpeer2_IP: ${cluster_ZKIP2}/" ${scripts_PATH}/cluster/cluster_zookeeper/vars/main.yml
sed -i "s/^Zookpeer3_IP:.*/Zookpeer3_IP: ${cluster_ZKIP3}/" ${scripts_PATH}/cluster/cluster_zookeeper/vars/main.yml
cd ${scripts_PATH}/cluster/
ansible-playbook -i ${scripts_PATH}/hosts cluster_zookeeper.yaml
echo  "zookeeper 集群安装完成"
fi
}


read -r -p "确认是否部署zookeeper ? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "部署 zookeeper"
read -r -p "请输入zookeeper 版本号，默认为3.6.1 : " Zookeeper_version
zookeeper_Version

read -r -p "请确认部署zookeeper是集群版还是单机版？默认为单机版，输入1为单机版，输入2为集群版: " ZK_mode
zk_Mode
fi

read -r -p "确认是否部署kafka ? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "部署 kafka"
read -r -p "请输入kafka 版本号，默认为7.6.2 : " Kafka_version
kafka_Version

fi