#!/usr/bin/env bash
set -euxo pipefail

source /tmp/environment
echo "AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
echo "HTTP_PROXY_URL: $HTTP_PROXY_URL"

# aws-iam-authenticator setup
URL=https://amazon-eks.s3.us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/amd64/aws-iam-authenticator
sudo curl -s -x $HTTP_PROXY_URL $URL \
  -o /usr/local/aws-iam-authenticator
sudo chmod u+x /usr/local/aws-iam-authenticator

sudo snap set system proxy.https=$HTTP_PROXY_URL

# 安装完毕之后会有一个 microk8s.kubectl 来做超级管理员使用
sudo snap install microk8s --classic --channel=1.14/stable

# 安装的 kubectl 当作客户端的命令行工具使用
sudo snap install kubectl --classic

# 设置一些额外的配置, 主要是 API Server 的 Webhook 与 AWS IAM Authenticator 启动绑定
sudo microk8s.status --wait-ready
sudo microk8s.kubectl label nodes ubuntu-xenial node-role.kubernetes.io/master=""
sudo sed -i "s/<AWS_ACCOUNT_ID>/$AWS_ACCOUNT_ID/g" /tmp/k8s/aws-iam-authenticator.yaml
echo "HTTPS_PROXY=$HTTP_PROXY_URL" | sudo tee -a /var/snap/microk8s/current/args/containerd-env
sudo microk8s.stop
sudo microk8s.start
sudo mkdir -p /var/aws-iam-authenticator/
sudo chmod 777 /var/aws-iam-authenticator/
sudo mkdir -p /etc/kubernetes/aws-iam-authenticator/
sudo chmod 777 /etc/kubernetes/aws-iam-authenticator/
sudo microk8s.kubectl apply -f /tmp/k8s/aws-iam-authenticator.yaml
sudo microk8s.kubectl apply -f /tmp/k8s/namespace-role-binding.yaml
sudo microk8s.kubectl -n kube-system rollout status daemonset aws-iam-authenticator
POD_NAME=`sudo microk8s.kubectl -n kube-system get pod -o=jsonpath="{.items[0].metadata.name}"`
sudo microk8s.kubectl -n kube-system wait --for=condition=Ready pod/$POD_NAME
echo "--authentication-token-webhook-config-file=/etc/kubernetes/aws-iam-authenticator/kubeconfig.yaml" | sudo tee -a /var/snap/microk8s/current/args/kube-apiserver
sudo systemctl restart snap.microk8s.daemon-apiserver
CA=`sudo microk8s.config | grep "certificate-authority-data" | sed "s/certificate-authority-data://g" | xargs`
sudo sed -i "s/<CA>/$CA/g" /tmp/k8s/config
SERVER=`sudo microk8s.config | grep "server" | sed "s/server://g" | xargs`
sudo sed -i "s~<SERVER>~$SERVER~g" /tmp/k8s/config
