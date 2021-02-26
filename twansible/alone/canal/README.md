1、安装前要确认vars/main.yml的变量，变量后面写的有注释，记得看一眼，确认一下
2、如果有资源中心，需要在/etc/ansible/hosts中安装canal的服务器后添加 mysql_role=all ,例：192.168.228.205   mysql_role=all (一定要写，不然不有资源中心的同步,mysql_role只是一个标识，跟MySQL没有关系)
