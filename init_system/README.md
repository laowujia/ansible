仅在centos7测试通过，其他版本和其他系统没有测试
1、在/etc/ansible/hosts 中设置好每个主机的主机名
2、云主机需要注释name: sync date和name : stop selinux
3、如果没有做免密，请先在ansible主机生成密钥对，还有在init_system.yml或/etc/ansible/hosts中设置登录账号和密码,之后就可以使用ansiblie的生成的密钥登录服务器了
4、默认修改sshd端口是22，如果想要修改sshd端口请修改defaults/main.yml
5、建议在/etc/ssh/ssh_config 中将其中的# StrictHostKeyChecking ask 改成 StrictHostKeyChecking no ,重启sshd #避免第一次登录询问
