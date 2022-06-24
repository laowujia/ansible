1、需要手动创建数据库并授权
mongo  #连接
show dbs; #查看
#创建数据库并授权
use admin #switched to db admin

db.createUser({user:"admin",pwd:"android",roles:[{role:"userAdminAnyDatabase",db:"admin"}]});
db.createUser({user:"root",pwd:"android",roles:[{role:"userAdminAnyDatabase",db:"admin"}]});
use admin_data_log;
db.createUser({user:"root",pwd:"android",roles:[{role:"readWrite",db:"admin_data_log"}]});
use olap_engine;
db.createUser({user:"root",pwd:"android",roles:[{role:"readWrite",db:"olap_engine"}]});
use olap_bbgj; 
db.createUser({user:"root",pwd:"android",roles:[{role:"readWrite",db:"olap_bbgj"}]}); 
