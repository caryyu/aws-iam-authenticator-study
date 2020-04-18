学习 `aws-iam-authenticator` 的授权验证。

> 全程环境必须要使用代理，否则很多依赖下载会产生问题，我想能上 Github 的也基本都有代理吧 😄

# 预备知识

- aws-cli
- vagrant & virtualbox
- microk8s
- aws-iam-authenticator
- kubectl

## aws-cli

确保按照 `aws-iam-authenticator` 文档在 AWS Console 创建了一个所需的 Role ，请注意在 Mac 系统上进行的操作，配置的话直接用 AWS 的 `Root` 账号就可以了

```shell
aws configure

ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')

POLICY=$(echo -n '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::'; echo -n "$ACCOUNT_ID"; echo -n ':root"},"Action":"sts:AssumeRole","Condition":{}}]}')

aws iam create-role \
  --role-name KubernetesAdmin \
  --description "Kubernetes administrator role (for AWS IAM Authenticator for Kubernetes)." \
  --assume-role-policy-document "$POLICY" \
  --output text \
  --query 'Role.Arn'
```

> 确保命令在 Mac 电脑或主机上运行

## 环境变量准备

```shell
HTTP_PROXY_URL="http://192.168.2.79:7890"
cp ./environment /tmp/environment
sed -i "" -e "s~<ACCOUNT_ID>~$ACCOUNT_ID~g" /tmp/environment
sed -i "" -e "s~<HTTP_PROXY_URL>~$HTTP_PROXY_URL~g" /tmp/environment
```

> 确保命令在 Mac 电脑上或主机上运行

## vagrant & virtualbox

我这里是 MacOS 系统，所以先利用 Vagrant 进行安装一个 Ubuntu 的虚拟机来做 Kubernetes 的单集群环境，仓库中提供的 Vagrantfile 源自于 `vagrant init ubuntu/xenial64` 此段命令进行的修改。

 - 启动 Vagrantfile

    ```shell
    vagrant up
    ``` 

  - 进入 ssh 环境

    ```shell
    vagrant ssh
    ```

# 开始测试

## 测试 User 的权限

我们可以直接创建一个 IAM 的用户也可以进行测试，上述创建的 Role 其实可以忽略，但实际组织场景使用最多的还是 Role，比如 SSO 协议 SAML2 集成 AWS 的 IAM 最后都是 Role 来处理的，这里先跳过，用户比较简单。

顺便说一句：用户配置的对应关系在配置中使用 `mapUsers` 进行的关联。

## 测试 Role 的权限(未走通)

首先创建一个 IAM 的用户，具有上述 `arn:aws:iam::$ACCOUNT_ID:role/KubernetesAdmin` 的 `STS AssumeRole` 的权限，步骤如下：

- 到 IAM 控制台进行创建 IAM 用户，并保存 AK 到 `~/.aws/credentials` 中
  
  ```shell
  aws configure --profile iam
  ```

- 创建一个 Role 来做安全授权 - 哪一个用户具有此 Role 的 Assume 权限
  
  我这里创建的一个 IAM 用户叫 caryyu，所以 POLICY 的语法中写法就是给此用户授权

  ```shell
  POLICY=$(echo -n '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::'; echo -n "$ACCOUNT_ID"; echo -n ':user/caryyu"},"Action":"sts:AssumeRole","Condition":{}}]}')

  aws iam create-role \
    --role-name KubernetesAdmin \
    --description "Kubernetes administrator role (for AWS IAM Authenticator for Kubernetes)." \
    --assume-role-policy-document "$POLICY" \
    --output text \
    --query 'Role.Arn'
  ```

- 利用命令生成 STS 的临时 TOKEN 进行保存进 VM 的 `~/.aws/credentials` 中

  ```shell
  aws sts assume-role --profile iam --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/KubernetesAdmin" --role-session-name test
  ```

# 注意事项

- 记住 `~/.aws/credentials` 中的 token 不能使用 root 账号，必须要创建一个 iam 的用户再进行 AssumeRole