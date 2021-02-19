#!/bin/bash
#定义外部输入确认的正则
export YES_REGULAR="^[yY][eE][sS]|[yY]$"

scripts_PATH="$( cd "$( dirname "$0"  )" && pwd  )"
echo $scripts_PATH

if [ ! -d $scripts_PATH/package ];then
mkdir $scripts_PATH/package
fi

read -r -p "确认是否部署elasticsearch ? [Y/n]:" input_confirm
if [[ $input_confirm =~ $YES_REGULAR ]]; then
echo "部署 elasticsearch"
read -r -p "请输入elasticsearch 版本号，version(7.6.2) :" version
elif [ -z "$version" || "$version" == "7.6.2" ];then
wget -P $scripts_PATH/package  http://yum.itestcn.com/github/elasticsearch/release/elasticsearch-7.6.2-linux-x86_64.tar.gz
else
wget -P $scripts_PATH/package https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-"$version"-linux-x86_64.tar.gz
if

read -r -p "请确认部署elasticsearch是集群版还是单机版？默认为单机版，输入2为集群版 notarize(1)" notarize
if [ -z "$notarize" || "$notarize" == "1" ];then
mv $scripts_PATH/package/elasticsearch* $scripts_PATH/alone/alone_es/files
read -r -p "请确认部署单机elasticsearch的服务器IP,例如: 192.168.228.208:" alone_es_IP
cat > {$scripts_PATH}/hosts << EOF
[alone_es]
$alone_es_IP
EOF

cd $scripts_PATH/alone/
ansible-playbook -i ${scripts_PATH}/hosts alone_es.yml
fi
