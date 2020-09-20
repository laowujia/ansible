1、要执行免密脚本的主机，需要在inventory中设置 mysql_role=master, 其他主机可以不用设置，会自动同步到其他主机
2、记得修改vars/main.yml下的变量
