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
#rm -f $scripts_PATH/package/apache-zookeeper*
#wget -P $scripts_PATH/package  http://yum.itestcn.com/github/zookeeper/release/apache-zookeeper-3.6.1-bin.tar.gz
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/alone/alone_zookeeper/vars/main.yml
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/alone/alone_kafka_zookeeper/vars/main.yml
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/cluster/cluster_kafka_zookeeper/vars/main.yml
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/cluster/cluster_zookeeper/vars/main.yml
else
wget -P $scripts_PATH/package https://mirrors.tuna.tsinghua.edu.cn/apache/zookeeper/zookeeper-"$Zookeeper_version"/apache-zookeeper-"$Zookeeper_version"-bin.tar.gz
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/alone/alone_zookeeper/vars/main.yml
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/alone/alone_kafka_zookeeper/vars/main.yml
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/cluster/cluster_kafka_zookeeper/vars/main.yml
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/cluster/cluster_zookeeper/vars/main.yml
fi
}

function kafka_Version () {
if [[ -z "$Kafka_version" || "$Kafka_version" =~ "2.5.0" ]];then
Kafka_version=2.5.0
#rm -f $scripts_PATH/package/kafka*
#wget -P $scripts_PATH/package  http://yum.itestcn.com/github/kafka/release/kafka_2.12-2.5.0.tgz
sed -i "s/^KAFKA_VERSION:.*/KAFKA_VERSION: 2.12-${Kafka_version}/" ${scripts_PATH}/alone/alone_kafka/vars/main.yml
sed -i "s/^KAFKA_VERSION:.*/KAFKA_VERSION: 2.12-${Kafka_version}/" ${scripts_PATH}/alone/alone_kafka_zookeeper/vars/main.yml
sed -i "s/^KAFKA_VERSION:.*/KAFKA_VERSION: 2.12-${Kafka_version}/" ${scripts_PATH}/cluster/cluster_kafka_zookeeper/vars/main.yml
sed -i "s/^KAFKA_VERSION:.*/KAFKA_VERSION: 2.12-${Kafka_version}/" ${scripts_PATH}/cluster/cluster_kafka/vars/main.yml
else
wget -P $scripts_PATH/package  https://mirrors.tuna.tsinghua.edu.cn/apache/kafka/"$Kafka_version"/kafka_2.12-"$Kafka_version".tgz
sed -i "s/^KAFKA_VERSION:.*/KAFKA_VERSION: 2.12-${Kafka_version}/" ${scripts_PATH}/alone/alone_kafka/vars/main.yml
sed -i "s/^KAFKA_VERSION:.*/KAFKA_VERSION: 2.12-${Kafka_version}/" ${scripts_PATH}/alone/alone_kafka_zookeeper/vars/main.yml
sed -i "s/^KAFKA_VERSION:.*/KAFKA_VERSION: 2.12-${Kafka_version}/" ${scripts_PATH}/cluster/cluster_kafka_zookeeper/vars/main.yml
sed -i "s/^KAFKA_VERSION:.*/KAFKA_VERSION: 2.12-${Kafka_version}/" ${scripts_PATH}/cluster/cluster_kafka/vars/main.yml
fi
}

function zk_kafka_Mode () {
if [[ -z "$zk_kafka_mode" || "$zk_kafka_mode" == "1" ]];then
scp $scripts_PATH/package/apache-zookeeper* $scripts_PATH/alone/alone_kafka_zookeeper/files
scp $scripts_PATH/package/kafka* $scripts_PATH/alone/alone_kafka_zookeeper/files
read -r -p "请输入部署单机zookeeper+kafka的服务器IP,例如: 192.168.228.208 : " alone_zk_kafka_IP
cat > ${scripts_PATH}/hosts << EOF
[alone_kafka_zookeeper]
$alone_zk_kafka_IP
EOF
cd ${scripts_PATH}/alone/
ansible-playbook -i ${scripts_PATH}/hosts alone_kafka_zookeeper.yaml
echo  "zookeeper+kafka 单机部署完成"
else
scp $scripts_PATH/package/apache-zookeeper* $scripts_PATH/cluster/cluster_kafka_zookeeper/files
scp $scripts_PATH/package/kafka* $scripts_PATH/cluster/cluster_kafka_zookeeper/files
read -r -p "请输入集群版zookeeper+kafka服务器的第一个IP,例如: 192.168.228.204 : " cluster_ZK_KAFKA_IP1
read -r -p "请输入集群版zookeeper+kafka服务器的第二个IP,例如: 192.168.228.205 : " cluster_ZK_KAFKA_IP2
read -r -p "请输入集群版zookeeper+kafka服务器的第三个IP,例如: 192.168.228.206 : " cluster_ZK_KAFKA_IP3
cat > ${scripts_PATH}/hosts << EOF
[cluster_kafka_zookeeper]
$cluster_ZK_KAFKA_IP1  ZK_id=1 kafka_id=1
$cluster_ZK_KAFKA_IP2  ZK_id=2 kafka_id=2
$cluster_ZK_KAFKA_IP3  ZK_id=3 kafka_id=3
EOF
sed -i "s/^Zookpeer1_IP:.*/Zookpeer1_IP: ${cluster_ZK_KAFKA_IP1}/" ${scripts_PATH}/cluster/cluster_kafka/vars/main.yml
sed -i "s/^Zookpeer2_IP:.*/Zookpeer2_IP: ${cluster_ZK_KAFKA_IP2}/" ${scripts_PATH}/cluster/cluster_kafka/vars/main.yml
sed -i "s/^Zookpeer3_IP:.*/Zookpeer3_IP: ${cluster_ZK_KAFKA_IP3}/" ${scripts_PATH}/cluster/cluster_kafka/vars/main.yml
fi
cd ${scripts_PATH}/cluster/
ansible-playbook -i ${scripts_PATH}/hosts cluster_kafka_zookeeper.yaml
echo  "zookeeper+kafka 集群部署完成"
}

read -r -p "确认是否部署zookeeper+kafka? 默认zk和kafka是安装在一起的,(同为单机，同为集群，如果有特殊情况，请单独部署) [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "部署 zookeeper+kafka"
read -r -p "请输入zookeeper 版本号，默认为3.6.1 : " Zookeeper_version
zookeeper_Version
read -r -p "请输入kafka 版本号，默认为2.5.0 : " Kafka_version
kafka_Version
read -r -p "请确认部署zookeeper+kafka是集群版还是单机版？默认为单机版，输入1为单机版，输入2为集群版: " zk_kafka_mode
zk_kafka_Mode
fi


##########################################################redis############################################

function redis_Version () {
if [[ -z "$Redis_version" || "$Redis_version" =~ "5.0.8" ]];then
Redis_version=5.0.8
rm -f $scripts_PATH/package/redis*
rm -f $scripts_PATH/package/tcl*
wget -P $scripts_PATH/package  http://yum.itestcn.com/github/Redis/releases/redis-5.0.8.tar.gz
wget -P $scripts_PATH/package  http://yum.itestcn.com/github/Redis/releases/tcl-8.5.13-8.el7.x86_64.rpm
sed -i "s/^Redis_version:.*/Redis_version: ${Redis_version}/" ${scripts_PATH}/alone/alone_redis/vars/main.yml
sed -i "s/^Redis_version:.*/Redis_version: ${Redis_version}/" ${scripts_PATH}/cluster/active_standby_redis/vars/main.yml
sed -i "s/^Redis_version:.*/Redis_version: ${Redis_version}/" ${scripts_PATH}/cluster/active_standby_sentinel_redis/vars/main.yml
else
wget -P $scripts_PATH/package http://mirror.centos.org/centos/7/os/x86_64/Packages/tcl-8.5.13-8.el7.x86_64.rpm
wget -P $scripts_PATH/package http://download.redis.io/releases/redis-${Redis_version}.tar.gz
sed -i "s/^Redis_version:.*/Redis_version: ${Redis_version}/" ${scripts_PATH}/alone/alone_redis/vars/main.yml
sed -i "s/^Redis_version:.*/Redis_version: ${Redis_version}/" ${scripts_PATH}/cluster/active_standby_redis/vars/main.yml
sed -i "s/^Redis_version:.*/Redis_version: ${Redis_version}/" ${scripts_PATH}/cluster/active_standby_sentinel_redis/vars/main.yml
fi
}

function redis_Mode () {
if [[ -z "$REDIS_mode" || "$REDIS_mode" == "1" ]];then
scp $scripts_PATH/package/redis* $scripts_PATH/alone/alone_redis/files
scp $scripts_PATH/package/tcl* $scripts_PATH/alone/alone_redis/files
read -r -p "请输入部署单机redis的服务器IP,例如: 192.168.228.208 : " alone_redis_IP
cat > ${scripts_PATH}/hosts << EOF
[alone_redis]
$alone_redis_IP
EOF
cd ${scripts_PATH}/alone/
ansible-playbook -i ${scripts_PATH}/hosts alone_redis.yaml
echo  "redis 单机安装完成"
elif [ "$REDIS_mode" == "2" ];then
scp $scripts_PATH/package/redis* $scripts_PATH/cluster/active_standby_redis/files
scp $scripts_PATH/package/tcl* $scripts_PATH/cluster/active_standby_redis/files
read -r -p "请输入主从版redis服务器的第一个IP(主节点),例如: 192.168.228.204 : " cluster_REDIS_IP1
read -r -p "请输入主从版redis服务器的第二个IP(从节点),例如: 192.168.228.205 : " cluster_REDIS_IP2
read -r -p "请输入主从版redis服务器的第三个IP(从节点),例如: 192.168.228.206 : " cluster_REDIS_IP3
cat > ${scripts_PATH}/hosts << EOF
[active_standby_redis]
$cluster_REDIS_IP1
$cluster_REDIS_IP2
$cluster_REDIS_IP3
EOF
sed -i "s/^Redis_master_ip:.*/Redis_master_ip: "$cluster_REDIS_IP1"/" ${scripts_PATH}/cluster/active_standby_redis/vars/main.yml
cd ${scripts_PATH}/cluster/
ansible-playbook -i ${scripts_PATH}/hosts active_standby_redis.yaml
echo  "redis 主从安装完成"
else 
scp $scripts_PATH/package/redis* $scripts_PATH/cluster/active_standby_sentinel_redis/files
scp $scripts_PATH/package/tcl* $scripts_PATH/cluster/active_standby_sentinel_redis/files
read -r -p "请输入主从哨兵版redis服务器的第一个IP(主节点),例如: 192.168.228.204 : " cluster_REDIS_SEN_IP1
read -r -p "请输入主从哨兵版redis服务器的第二个IP(从节点),例如: 192.168.228.205 : " cluster_REDIS_SEN_IP2
read -r -p "请输入主从哨兵版redis服务器的第三个IP(从节点),例如: 192.168.228.206 : " cluster_REDIS_SEN_IP3
cat > ${scripts_PATH}/hosts << EOF
[active_standby_sentinel_redis]
$cluster_REDIS_SEN_IP1
$cluster_REDIS_SEN_IP2
$cluster_REDIS_SEN_IP3
EOF
sed -i "s/^Redis_master_ip:.*/Redis_master_ip: "$cluster_REDIS_SEN_IP1"/" ${scripts_PATH}/cluster/active_standby_sentinel_redis/vars/main.yml
cd ${scripts_PATH}/cluster/
ansible-playbook -i ${scripts_PATH}/hosts active_standby_sentinel_redis.yaml
echo  "redis 主从哨兵版安装完成"
fi
}


read -r -p "确认是否部署redis? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "部署 redis"
read -r -p "请输入redis 版本号，默认为5.0.8 : " Redis_version
redis_Version
read -r -p "请确认部署redis是集群版还是单机版？默认为单机版，输入1为单机版，输入2为集群版 ,输入3为集群哨兵版: " REDIS_mode
redis_Mode
fi
