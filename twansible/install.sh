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
#wget -P $scripts_PATH/package  "http://yum.itestcn.com/github/elasticsearch/release/elasticsearch-7.6.2-linux-x86_64.tar.gz"
wget -P $scripts_PATH/package  "http://yum.itestcn.com/github/elasticsearch/release/elasticsearch-analysis-ik-7.6.2.zip"
sed -i "s/^ES_VERSION:.*/ES_VERSION: 7.6.2/" ${scripts_PATH}/alone/alone_es/vars/main.yml
cp /root/elasticsearch-7.6.2-linux-x86_64.tar.gz $scripts_PATH/package
else
sed -i "s/^ES_VERSION:.*/ES_VERSION: ${ES_version}/" ${scripts_PATH}/alone/alone_es/vars/main.yml
wget -P $scripts_PATH/package https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-"$ES_version"-linux-x86_64.tar.gz
wget -P $scripts_PATH/package https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v"$ES_version"/elasticsearch-analysis-ik-"$ES_version".zip
fi
}


function es_Memory () {
if [ -z "$ES_memory" ] ;then
ES_memory=2G
sed -i "s/^ES_memory:.*/ES_memory: "${ES_memory}"/" ${scripts_PATH}/alone/alone_es/vars/main.yml
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
echo $Master_hostname
sed -i "s/^Master_nodes:.*/Master_nodes: "$Master_hostname"/" ${scripts_PATH}/cluster/cluster_es/vars/main.yml
fi
cd ${scripts_PATH}/cluster/
ansible-playbook -i ${scripts_PATH}/hosts cluster_es.yaml
echo  "elasticsearch 集群安装完成"

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


#function kibana_Version () {
#if [[ -z "$Kibana_version" || "$Kibana_version" =~ "7.6.2" ]];then
#Kibana_version=7.6.2
#rm -f $scripts_PATH/package/kibana*
#wget -P $scripts_PATH/package  http://yum.itestcn.com/github/elasticsearch/release/kibana-7.6.2-linux-x86_64.tar.gz
#else
#wget -P $scripts_PATH/package https://artifacts.elastic.co/downloads/kibana/kibana-"$Kibana_version"-linux-x86_64.tar.gz
#fi
#}
#
#read -r -p "确认是否部署kibana ? [Y/n]:" input_confirm
#if [[ $input_confirm =~ $YES_REGULAR ]]; then
#echo "部署 kibana"
#read -r -p "请输入kibana 版本号，默认为7.6.2 : " Kibana_version
#kibana_Version
#
#cd ${scripts_PATH}/alone/
#
#fi
