#### 配置免密远程登录
PASSWD=Talkweb
APP_IP='IP:192.168.228.200,IP:192.168.228.203,IP:192.168.228.204,IP:127.0.0.1'
COMMON_NAME=docker.talkedu.cn
EMAIL_URL=zhangke@talkweb.com.cn
### 创建CA私钥
openssl genrsa  -passout pass:$PASSWD -out ca-key.pem  -aes256  4096
### 创建CA公钥
#openssl req -new -x509 -days 36500 -key ca-key.pem -out ca.pem  -passin pass:$PASSWD -subj /C=CN/ST=HN/L=CS/O=talkweb/OU=ops/CN=${COMMON_NAME}/emailAddress=${EMAIL_URL}
openssl req -new -x509 -days 36500 -key ca-key.pem -out ca.pem -passin pass:$PASSWD -subj /C=CN/ST=HN/L=CS/O=talweb/OU=ops/CN=${COMMON_NAME}/emailAddress=${EMAIL_URL}
### 创建一个服务器密钥和证书签名请求
openssl genrsa -out server-key.pem 4096
openssl req -subj "/CN=docker.talkedu.cn" -sha256 -new -key server-key.pem -out server.csr
echo subjectAltName = DNS:docker.talkedu.cn,$APP_IP >> extfile.cnf
echo extendedKeyUsage = serverAuth >> extfile.cnf
###创建客户端密钥和证书签名请求
openssl x509 -req -days 36500 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem  -CAcreateserial -out server-cert.pem -extfile extfile.cnf -passin pass:$PASSWD
openssl genrsa -out key.pem 4096
openssl req -subj '/CN=client' -new -key key.pem -out client.csr
echo extendedKeyUsage = clientAuth >> extfile.client.cnf
openssl x509 -req -days 36500 -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem  -CAcreateserial -out cert.pem -extfile extfile.client.cnf -passin pass:$PASSWD
#修改文件权限
chmod -v 0400 ca-key.pem key.pem server-key.pem
chmod -v 0444 ca.pem server-cert.pem cert.pem
