#!/usr/bin/env bash

echo -e "installing docker-compose..."
curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
echo -e "done."

echo -e "installing yq..."
curl -L "https://github.com/mikefarah/yq/releases/download/2.4.0/yq_linux_amd64" -o /usr/local/bin/yq
chmod +x /usr/local/bin/yq
echo -e "done."

echo -e "install jenkins dependencies..."
apt -y install python-git default-jre
echo -e "done"