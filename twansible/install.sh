#!/bin/bash
#定义外部输入确认的正则
export YES_REGULAR="^[yY][eE][sS]|[yY]$"

scripts_PATH="$( cd "$( dirname "$0"  )" && pwd  )"
echo $scripts_PATH

if [ ! -d $scripts_PATH/package ];then
mkdir $scripts_PATH/package
fi

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
#CheckIPAddr $1


#####################检查ansible 是否安装。为安装则安装###################

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


###############################是否做免密登录###########################
echo "StrictHostKeyChecking no" > ~/.ssh/config

function Alike_password() {
read -r -p "请输入需要做root免密登录的IP,以空格分隔。例：192.168.228.200 192.168.228.201: " Password_IP
echo [password] > ${scripts_PATH}/hosts
for i in $Password_IP;do
CheckIPAddr $i
if [ $? -eq 0 ];then
echo $i >> ${scripts_PATH}/hosts
else
echo "$i IP 不合法"
fi
done
read -s -r -p "如果所有服务器的root密码都是一样的，请输入root密码：" Password
if [ -f /root/.ssh/id_rsa.pub ];then
ansible -i ${scripts_PATH}/hosts  -m authorized_key -a "user=root state=present key=\"{{ lookup('file', '/root/.ssh/id_rsa.pub') }} \"" -k $Password
else
ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
ansible -i ${scripts_PATH}/hosts  -m authorized_key -a "user=root state=present key=\"{{ lookup('file', '/root/.ssh/id_rsa.pub') }} \"" -k $Password
fi
}


function Diff_password () {
read -r -p "请输入服务器的IP和密码，例如：192.168.228.200  root_password " IP ROOT_password
while  [ -n "$IP" ]
do
echo [password] > ${scripts_PATH}/hosts
CheckIPAddr $IP
if [ $? -eq 0 ];then
echo $IP >> ${scripts_PATH}/hosts
else
echo "$IP IP 不合法"
fi

done
}

#read -r -p "确认是否做root免密登录? [Y/n]:" input_confirm
#if [[ $input_confirm =~ $YES_REGULAR ]]; then
#echo "进行root免密登录配置"
#
#read -r -p "确认是服务器的root是否相同？默认为root密码相同，输入1为密码相同，输入2为密码不同 ：" passwd_diif
#if [[ -z "$passwd_diif" || "$passwd_diif" == "1" ]];then 
#Alike_password
#elif [[ "$passwd_diif" == "2" ]];then



echo "部署过程中需要输入版本的，回车为安装默认版本"

#################################################elasticsearch############################################

function es_Version () {
if [[ -z "$ES_version" || "$ES_version" =~ "7.6.2" ]];then
ES_version=7.6.2
if [ ! -f $scripts_PATH/package/elasticsearch-"$ES_version"-linux-x86_64.tar.gz ];then
wget -P $scripts_PATH/package  "http://yum.itestcn.com/github/elasticsearch/release/elasticsearch-7.6.2-linux-x86_64.tar.gz"
wget -P $scripts_PATH/package  "http://yum.itestcn.com/github/elasticsearch/release/elasticsearch-analysis-ik-7.6.2.zip"
fi
sed -i "s/^ES_VERSION:.*/ES_VERSION: 7.6.2/" ${scripts_PATH}/alone/alone_es/vars/main.yml
sed -i "s/^ES_VERSION:.*/ES_VERSION: 7.6.2/" ${scripts_PATH}/cluster/cluster_es/vars/main.yml
else
sed -i "s/^ES_VERSION:.*/ES_VERSION: ${ES_version}/" ${scripts_PATH}/alone/alone_es/vars/main.yml
sed -i "s/^ES_VERSION:.*/ES_VERSION: ${ES_version}/" ${scripts_PATH}/cluster/cluster_es/vars/main.yml
if [ ! -f $scripts_PATH/package/elasticsearch-"$ES_version"-linux-x86_64.tar.gz ];then
wget -P $scripts_PATH/package https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-"$ES_version"-linux-x86_64.tar.gz
wget -P $scripts_PATH/package https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v"$ES_version"/elasticsearch-analysis-ik-"$ES_version".zip
fi
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
CheckIPAddr $alone_es_IP
if [ $? -eq 0 ];then
cat > ${scripts_PATH}/hosts << EOF
[alone_es]
$alone_es_IP
EOF
sed -i "s/^IP:.*/IP: ${alone_es_IP}/" ${scripts_PATH}/alone/canal/vars/main.yml
else
echo "输入 $alone_es_IP IP 不合法"
fi
cd ${scripts_PATH}/alone/
ansible-playbook -i ${scripts_PATH}/hosts alone_es.yaml
if [ $? -eq 0 ];then
echo  "elasticsearch 单机安装完成"
else
echo "elasticsearch安装失败，请重新安装"
exit 1
fi
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
if [ $? -eq 0 ];then
echo  "elasticsearch 集群安装完成"
else
echo "elasticsearch 集群安装失败，请重新安装"
exit 1
fi
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
if [ ! -f $scripts_PATH/package/kibana-7.6.2-linux-x86_64.tar.gz ];then
wget -P $scripts_PATH/package  http://yum.itestcn.com/github/elasticsearch/release/kibana-7.6.2-linux-x86_64.tar.gz
fi
sed -i "s/^KIBANA_VERSION:.*/KIBANA_VERSION: ${Kibana_version}/" ${scripts_PATH}/alone/kibana/vars/main.yml
else
if [ ! -f $scripts_PATH/package/kibana-"$Kibana_version"-linux-x86_64.tar.gz ];then
fi
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
if [ $? -eq 0 ];then
echo kibana部署完成
else
echo "kibana部署失败，请重新部署"
exit 1
fi
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
if [ ! -f $scripts_PATH/package/apache-zookeeper-3.6.1-bin.tar.gz ];then
wget -P $scripts_PATH/package  http://yum.itestcn.com/github/zookeeper/release/apache-zookeeper-3.6.1-bin.tar.gz
fi
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/alone/alone_zookeeper/vars/main.yml
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/alone/alone_kafka_zookeeper/vars/main.yml
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/cluster/cluster_kafka_zookeeper/vars/main.yml
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/cluster/cluster_zookeeper/vars/main.yml
else
if [ ! -f $scripts_PATH/package/apache-zookeeper-"$Zookeeper_version"-bin.tar.gz ];then
wget -P $scripts_PATH/package https://mirrors.tuna.tsinghua.edu.cn/apache/zookeeper/zookeeper-"$Zookeeper_version"/apache-zookeeper-"$Zookeeper_version"-bin.tar.gz
fi
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/alone/alone_zookeeper/vars/main.yml
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/alone/alone_kafka_zookeeper/vars/main.yml
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/cluster/cluster_kafka_zookeeper/vars/main.yml
sed -i "s/^ZOOKEEPER_VERSION:.*/ZOOKEEPER_VERSION: ${Zookeeper_version}/" ${scripts_PATH}/cluster/cluster_zookeeper/vars/main.yml
fi
}

function kafka_Version () {
if [[ -z "$Kafka_version" || "$Kafka_version" =~ "2.5.0" ]];then
Kafka_version=2.5.0
if [ ! -f $scripts_PATH/package/kafka_2.12-"${Kafka_version}".tgz ];then
wget -P $scripts_PATH/package  http://yum.itestcn.com/github/kafka/release/kafka_2.12-2.5.0.tgz
fi
sed -i "s/^KAFKA_VERSION:.*/KAFKA_VERSION: 2.12-${Kafka_version}/" ${scripts_PATH}/alone/alone_kafka/vars/main.yml
sed -i "s/^KAFKA_VERSION:.*/KAFKA_VERSION: 2.12-${Kafka_version}/" ${scripts_PATH}/alone/alone_kafka_zookeeper/vars/main.yml
sed -i "s/^KAFKA_VERSION:.*/KAFKA_VERSION: 2.12-${Kafka_version}/" ${scripts_PATH}/cluster/cluster_kafka_zookeeper/vars/main.yml
sed -i "s/^KAFKA_VERSION:.*/KAFKA_VERSION: 2.12-${Kafka_version}/" ${scripts_PATH}/cluster/cluster_kafka/vars/main.yml
else
if [ ! -f $scripts_PATH/package/kafka_2.12-"${Kafka_version}".tgz ];then
wget -P $scripts_PATH/package  https://mirrors.tuna.tsinghua.edu.cn/apache/kafka/"$Kafka_version"/kafka_2.12-"$Kafka_version".tgz
fi
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
sed -i  "s/^IP:.*/IP: "${alone_zk_kafka_IP}"/" ${scripts_PATH}/alone/alone_kafka/vars/main.yml
cd ${scripts_PATH}/alone/
ansible-playbook -i ${scripts_PATH}/hosts alone_kafka_zookeeper.yaml
if [ $? -eq 0 ];then
echo  "zookeeper+kafka 单机部署完成"
else
echo "zookeeper+kafka 单机部署失败，请重新部署"
exit 1
fi
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
cd ${scripts_PATH}/cluster/
ansible-playbook -i ${scripts_PATH}/hosts cluster_kafka_zookeeper.yaml
if [ $? -eq 0 ];then 
echo  "zookeeper+kafka 集群部署完成"
else
echo "zookeeper+kafka 集群部署失败，请重新部署"
exit 1
fi
fi
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
if [ ! -f $scripts_PATH/package/redis-${Redis_version}.tar.gz ];then
wget -P $scripts_PATH/package  http://yum.itestcn.com/github/Redis/releases/redis-5.0.8.tar.gz
wget -P $scripts_PATH/package  http://yum.itestcn.com/github/Redis/releases/tcl-8.5.13-8.el7.x86_64.rpm
fi
sed -i "s/^Redis_version:.*/Redis_version: ${Redis_version}/" ${scripts_PATH}/alone/alone_redis/vars/main.yml
sed -i "s/^Redis_version:.*/Redis_version: ${Redis_version}/" ${scripts_PATH}/cluster/active_standby_redis/vars/main.yml
sed -i "s/^Redis_version:.*/Redis_version: ${Redis_version}/" ${scripts_PATH}/cluster/active_standby_sentinel_redis/vars/main.yml
else
if [ ! -f $scripts_PATH/package/redis-${Redis_version}.tar.gz ];then
wget -P $scripts_PATH/package http://mirror.centos.org/centos/7/os/x86_64/Packages/tcl-8.5.13-8.el7.x86_64.rpm
wget -P $scripts_PATH/package http://download.redis.io/releases/redis-${Redis_version}.tar.gz
fi
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
if [ $? -eq 0 ];then
echo  "redis 单机安装完成"
else
echo "redis 单机部署失败，请重新部署"
exit 1
fi
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
if [ $? -eq 0 ];then
echo  "redis 主从安装完成"
else
echo "redis 主从部署失败，请重新部署"
exit 1
fi
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
if [ $? -eq 0 ];then
echo  "redis 主从哨兵版安装完成"
else
echo "redis 主从哨兵版安装失败，请重新部署"
exit 1
fi
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

#################################################docker###############################################
function docker_Version () {
if [[ -z "$Docker_version"  ]];then
sed -i "s/^custom:.*/custom: false/" ${scripts_PATH}/alone/docker/vars/main.yml
else
sed -i "s/^Docker_version:.*/Docker_version: ${Docker_version}/" ${scripts_PATH}/alone/docker/vars/main.yml
sed -i "s/^custom:.*/custom: true/" ${scripts_PATH}/alone/docker/vars/main.yml
fi
}

function docker_IP () {
if [[ -z "$DOCKER_IP"  ]];then
echo "未输入部署dokcer的服务器IP，请输入部署docker的服务器IP,例如: 192.168.228.208"
read -r -p "请输入部署docker的服务器IP,例如: 192.168.228.208 :" DOCKER_IP
echo [docker] > ${scripts_PATH}/hosts
for i in $DOCKER_IP;do
CheckIPAddr $i
if [ $? -eq 0 ];then
echo $i >> ${scripts_PATH}/hosts
else
echo "$i IP 不合法"
fi
done
read -r -p "请输入docker 版本号，默认为当前最新版本: " Docker_version
docker_Version
cd ${scripts_PATH}/alone/
ansible-playbook -i ${scripts_PATH}/hosts docker.yaml
if [ $? -eq 0 ];then
echo  "docker 安装完成"
else
echo "doker 安装失败,请重新安装"
exit 1
fi
else
echo [docker] > ${scripts_PATH}/hosts
for i in $DOCKER_IP;do
CheckIPAddr $i
if [ $? -eq 0 ];then
echo $i >> ${scripts_PATH}/hosts
else
echo "$i IP 不合法"
fi
done
read -r -p "请输入docker 版本号，默认为当前最新版本: " Docker_version
docker_Version
cd ${scripts_PATH}/alone/
ansible-playbook -i ${scripts_PATH}/hosts docker.yaml
if [ $? -eq 0 ];then
echo  "docker 安装完成"
else
echo "doker 安装失败,请重新安装"
exit 1
fi
fi
}
read -r -p "确认是否部署docker? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "部署 docker"
read -r -p "请确认部署docker的服务器IP,例如: 192.168.228.208: " DOCKER_IP
docker_IP
fi

###################################################mysql#########################################
function mysql_Version () {
if [[ -z "$Mysql_version"   ||  "$Mysql_version" =~ "5.7" ]];then
rm -f $scripts_PATH/package/mysql*
wget -P $scripts_PATH/package http://dev.mysql.com/get/mysql57-community-release-el7-10.noarch.rpm
elif [[ "$Mysql_version" =~ "5.6" ]];then
rm -f $scripts_PATH/package/mysql*
wget -P $scripts_PATH/package  http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
else
echo "请输入mysql版本号 [5.6|5.7] "
fi
}

function mysql_Mode () {
if [[ -z "$mysql_mode" || "$mysql_mode" == "1" ]];then
scp $scripts_PATH/package/mysql* $scripts_PATH/alone/alone_mysql/files
read -r -p "请输入部署单机mysql的服务器IP,例如: 192.168.228.208 : " alone_mysql_IP
cat > ${scripts_PATH}/hosts << EOF
[alone_mysql]
$alone_mysql_IP
EOF
read -r -p "请输入mysql root 密码: " Mysql_user_root_password
sed -i "s/^mysql_login_password:.*/mysql_login_password: ${Mysql_user_root_password}/" ${scripts_PATH}/alone/alone_mysql/vars/main.yml
cd ${scripts_PATH}/alone/
ansible-playbook -i ${scripts_PATH}/hosts alone_mysql.yaml
if [ $? -eq 0 ];then
echo  "mysql 单机部署完成"
else
echo "mysql 单机部署失败，请重新部署"
exit 1
fi
else
scp $scripts_PATH/package/mysql* $scripts_PATH/cluster/active_standby_mysql/files
read -r -p "请输入主从版mysql主服务器IP,例如: 192.168.228.204 : " AS_MYSQL_IP1
read -r -p "请输入主从版mysql从服务器IP,例如: 192.168.228.205 : " AS_MYSQL_IP2
cat > ${scripts_PATH}/hosts << EOF
[active_standby_mysql]
$AS_MYSQL_IP1 mysql_role="master"
$AS_MYSQL_IP2 mysql_role="slave"
EOF
sed -i "s/^master_ip:.*/master_ip: ${AS_MYSQL_IP1}/" ${scripts_PATH}/cluster/active_standby_mysql/vars/main.yml
read -r -p "请输入mysql root 密码: " Mysql_user_root_password
sed -i "s/^mysql_root_password:.*/mysql_root_password: ${Mysql_user_root_password}/" ${scripts_PATH}/cluster/active_standby_mysql/vars/main.yml
cd ${scripts_PATH}/cluster/
ansible-playbook -i ${scripts_PATH}/hosts active_standby_mysql.yaml
if [ $? -eq 0 ];then
echo  "mysql主从部署完成"
else
echo "mysql主从部署失败，请重新部署"
exit 1
fi
fi
}

read -r -p "确认是否部署mysql? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "部署 mysql"
read -r -p "请输入mysql 版本号，默认为5.7最新版 : " Mysql_version
mysql_Version
read -r -p "请确认部署mysql是集群版还是单机版？默认为单机版，输入1为单机版，输入2为主从版 : " mysql_mode
mysql_Mode
fi


##########################################################canal###################################################
function canal_Version () {
if [[ -z "$Canal_version"   ||  "$Canal_version" =~ "1.1.5" ]];then
Canal_version=1.1.5
if [ ! -f $scripts_PATH/package/canal.deployer-1.1.5-SNAPSHOT.tar.gz ];then
wget -P $scripts_PATH/package http://yum.itestcn.com/github/canal/canal.deployer-1.1.5-SNAPSHOT.tar.gz
fi
sed -i "s/^Canal_version:.*/Canal_version: ${Canal_version}/" ${scripts_PATH}/alone/canal/vars/main.yml
else
echo "目前只写的有1.1.5版本的canal "
fi
scp $scripts_PATH/package/canal* ${scripts_PATH}/alone/canal/files/
}

function canal_mode () {
if [[ -z "$Canal_mode"   ||  "$Canal_mode" =~ "1" ]];then
sed -i "s/^sync_res:.*/sync_res: false/" ${scripts_PATH}/alone/canal/vars/main.yml
echo "当前同步只有基础平台"
cd ${scripts_PATH}/alone/
ansible-playbook -i ${scripts_PATH}/hosts canal.yaml
if [ $? -eq 0 ];then
echo  "canal部署完成"
else
echo "canal部署失败，请重新部署"
exit 1
fi
else
sed -i "s/^sync_res:.*/sync_res: true/" ${scripts_PATH}/alone/canal/vars/main.yml
Res_mysql_ip
read -r -p "请输入基础平台数据库账号和密码，空格隔开，确认能够远程登录，并且能够创建用户，否则会出问题 例如：mysql_user mysql_password  :  " res_mysql_user res_mysql_password
sed -i "s/^Res_mysql_login_user:.*/Res_mysql_login_user: ${res_mysql_user}/" ${scripts_PATH}/alone/canal/vars/main.yml
sed -i "s/^Res_mysql_login_password:.*/Res_mysql_login_password: ${res_mysql_password}/" ${scripts_PATH}/alone/canal/vars/main.yml
cd ${scripts_PATH}/alone/
ansible-playbook -i ${scripts_PATH}/hosts canal.yaml
if [ $? -eq 0 ];then
echo  "canal部署完成"
else
echo "canal部署失败，请重新部署"
exit 1
fi
fi
}

function Base_mysql_ip () {
if [[ -z "$base_mysql_ip" ]];then
read -r -p "请输入基础平台数据库IP，如：192.168.228.208 : " base_mysql_ip
CheckIPAddr $base_mysql_ip
if [ $? -eq 0 ];then
sed -i "s/^Talkweb_base_Mysql_dir:.*/Talkweb_base_Mysql_dir: ${base_mysql_ip}/" ${scripts_PATH}/alone/canal/vars/main.yml
else
echo "输入的IP 不合法 88 "
exit 1
fi
else
CheckIPAddr $base_mysql_ip
if [ $? -eq 0 ];then
sed -i "s/^Talkweb_base_Mysql_dir:.*/Talkweb_base_Mysql_dir: ${base_mysql_ip}/" ${scripts_PATH}/alone/canal/vars/main.yml
else
echo "输入的IP 不合法 88 "
fi
fi
}

function Res_mysql_ip () {
read -r -p "请输入资源中心数据库IP，如：192.168.228.208 : " res_mysql_ip
if [[ -z "$res_mysql_ip" ]];then
read -r -p "请输入基础平台数据库IP，如：192.168.228.208 : " res_mysql_ip
CheckIPAddr $res_mysql_ip
if [ $? -eq 0 ];then
sed -i "s/^Res_sync_Mysql_dir:.*/Res_sync_Mysql_dir: ${res_mysql_ip}/" ${scripts_PATH}/alone/canal/vars/main.yml
else
echo "输入的IP 不合法 88 "
exit 1
fi
else
CheckIPAddr $res_mysql_ip
if [ $? -eq 0 ];then
sed -i "s/^Res_sync_Mysql_dir:.*/Res_sync_Mysql_dir: ${res_mysql_ip}/" ${scripts_PATH}/alone/canal/vars/main.yml
else
echo "输入的IP 不合法 88 "
fi
fi
}

function canal_IP () {
if [[ -z "$Canal_IP" ]];then
read -r -p "请输入部署canal服务器IP ，例: 192.168.228.208 : " Canal_IP
CheckIPAddr $Canal_IP
if [  $? -eq 0 ];then 
cat > ${scripts_PATH}/hosts << EOF
[canal]
$Canal_IP
EOF
sed -i "s/^IP:.*/IP: ${Canal_IP}/" ${scripts_PATH}/alone/canal/vars/main.yml
else
echo "$Canal_IP IP 不合法"
fi
else
CheckIPAddr $Canal_IP
if [  $? -eq 0 ];then
cat > ${scripts_PATH}/hosts << EOF
[canal]
$Canal_IP
EOF
sed -i "s/^IP:.*/IP: ${Canal_IP}/" ${scripts_PATH}/alone/canal/vars/main.yml
fi
fi
}

read -r -p "确认是否部署canal? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "部署 canal"
read -r -p "请输入canal 版本号，默认为1.1.5 : " Canal_version
canal_Version
read -r -p "请输入部署canal服务器IP ，例: 192.168.228.208 : " Canal_IP
canal_IP
read -r -p "请输入kafka地址和端口，如：192.168.228.203:9092 : " kafka_ip_port
sed -i "s/^Canal_mq_servers:.*/Canal_mq_servers: ${kafka_ip_port}/" ${scripts_PATH}/alone/canal/vars/main.yml
read -r -p "请输入基础平台数据库IP，如：192.168.228.208 : " base_mysql_ip
Base_mysql_ip
read -r -p "请输入基础平台数据库账号和密码，空格隔开，确认能够远程登录，并且能够创建用户，否则会出问题 例如：mysql_user mysql_password  :  " mysql_user mysql_password
sed -i "s/^Base_mysql_login_user:.*/Base_mysql_login_user: ${mysql_user}/" ${scripts_PATH}/alone/canal/vars/main.yml
sed -i "s/^Base_mysql_login_password:.*/Base_mysql_login_password: ${mysql_password}/" ${scripts_PATH}/alone/canal/vars/main.yml
read -r -p "请确认是否需要同步资源中心，默认同步基础平台, 输入1为只同步基础平台，输入2同时同步基础平台和资源中心 : " Canal_mode
canal_mode
fi


#############################################promethues######################
