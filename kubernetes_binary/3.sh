#!/bin/bash
read -r -p "请输入部署canal服务器IP ，例: 192.168.228.208 :" IP
i=1
echo "{" >>server-csr.json
echo "    \"CN\": \"kubernetes\"," >>server-csr.json
echo "    \"hosts\": ["   >>server-csr.json
echo "      \"10.0.0.1\"," >>server-csr.json
echo "      \"127.0.0.1\"," >>server-csr.json
while [ -n "$IP" ]
do
echo "      \"${IP}\"," >>server-csr.json
read -r -p "请输入部署canal服务器IP ，例: 192.168.228.208 :" IP
((i++))
done
echo "      \"kubernetes\"," >>server-csr.json
echo "      \"kubernetes.default\"," >>server-csr.json
echo "      \"kubernetes.default.svc\"," >>server-csr.json
echo "      \"kubernetes.default.svc.cluster\"," >>server-csr.json
echo "      \"kubernetes.default.svc.cluster.local\"" >>server-csr.json
echo "    ]," >>server-csr.json
echo "    \"key\": {" >>server-csr.json
echo "        \"algo\": \"rsa\"," >>server-csr.json
echo "        \"size\": 2048" >>server-csr.json
echo "    }," >>server-csr.json
echo "    \"names\": [" >>server-csr.json
echo "        {" >>server-csr.json
echo "            \"C\": \"CN\"," >>server-csr.json
echo "            \"L\": \"BeiJing\"," >>server-csr.json
echo "            \"ST\": \"BeiJing\"," >>server-csr.json
echo "            \"O\": \"k8s\"," >>server-csr.json
echo "            \"OU\": \"System\"" >>server-csr.json
echo "        }" >>server-csr.json
echo "    ]" >>server-csr.json
echo "}" >>server-csr.json
