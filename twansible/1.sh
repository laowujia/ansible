#!/bin/bash
echo "StrictHostKeyChecking no" > ~/.ssh/config
timeout 5 ssh $1
if [[ $? -ne 0 ]]; then
    echo "SSH 未免密登录"
fi
