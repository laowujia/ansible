1、如果没有使用系统初始化脚本或是不是云主机，请手动配置selinux (/usr/sbin/setenforce 0 ; sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config)
2、记得修改vars/main.yml下的变量
3、如果防火墙开了或者云上的安全组开了，请放开端口
