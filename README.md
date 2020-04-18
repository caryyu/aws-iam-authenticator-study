学习 `aws-iam-authenticator` 的授权验证。

> 全程环境必须要使用代理，否则很多依赖下载会产生问题，我想能上 Github 的也基本都有代理吧 😄

# 预备知识

- aws-cli
- vagrant & virtualbox
- microk8s
- aws-iam-authenticator
- kubectl

## aws-cli

先使用 AWS 的 Root 账户进行获取 AccountID 到环境中

```shell
aws configure

ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
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

## 测试 Role 的权限

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

- 利用命令生成 STS 的临时 TOKEN 进行保存进 VM 的 `~/.aws/credentials` 中，然后按下列命令参考执行，这里需要的是 `assume-role` 出来的会话 ARN 不用管它，因为最终的角色依然会按照 `--role-arn` 进行匹配验证。

  ```shell
  aws sts assume-role --profile iam --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/KubernetesAdmin" --role-session-name microk8s
  ```
   
  上述执行完毕之后会产生一个 1 小时可用的临时会话 AK，如下：

  ```json
  {
      "Credentials": {
          "AccessKeyId": "ASIA5YHSUDGNLLNZOMDY",
          "SecretAccessKey": "Dlwdw3FuWarIBQzjkRmNvO9S00he8oKa7pVa/yY5",
          "SessionToken": "FwoGZXIvYXdzEMf//////////wEaDLA0FLudQrt6u2oYcyKsAUgtzMM3UHUfkaNE6XiHwo3m0VrVhN3i6X3HIWjraPfvjjEDjt3AzGFRno/ziwgOKbtjnRvRpqMeeb6VixlfW6S+1UPmdHdXRpD8xGhcAlXqVS958z7YLAH97ODcn9NSAM7KC51YmePgJdx6+Gda+0pbQ1lnEy5hjfJeBMAs9LRf/KHH5ddfC20++zg9SsZMk8nmA9/vafTOwiJQWdWpPnnze2OkVL43m7g/jzMon5fq9AUyLfKh6bo2y9VWwJ59s93NrxtCbh1t/uz0iQTQyqdVcskaGBZZuTQjA3dfkFefXA==",
          "Expiration": "2020-04-18T06:09:51Z"
      },
      "AssumedRoleUser": {
          "AssumedRoleId": "AROA5YHSUDGNMU2QYY6RF:microk8s",
          "Arn": "arn:aws:sts::945401633178:assumed-role/KubernetesAdmin/microk8s"
      }
  }
  ```

  把上述的 JSON 内容复然后保存进 VM 中的 `~/.aws/credentials` 中去使用：

  ```ini
  [default]
  aws_access_key_id = ASIA5YHSUDGNLLNZOMDY
  aws_secret_access_key = Dlwdw3FuWarIBQzjkRmNvO9S00he8oKa7pVa/yY5
  aws_session_token = FwoGZXIvYXdzEMf//////////wEaDLA0FLudQrt6u2oYcyKsAUgtzMM3UHUfkaNE6XiHwo3m0VrVhN3i6X3HIWjraPfvjjEDjt3AzGFRno/ziwgOKbtjnRvRpqMeeb6VixlfW6S+1UPmdHdXRpD8xGhcAlXqVS958z7YLAH97ODcn9NSAM7KC51YmePgJdx6+Gda+0pbQ1lnEy5hjfJeBMAs9LRf/KHH5ddfC20++zg9SsZMk8nmA9/vafTOwiJQWdWpPnnze2OkVL43m7g/jzMon5fq9AUyLfKh6bo2y9VWwJ59s93NrxtCbh1t/uz0iQTQyqdVcskaGBZZuTQjA3dfkFefXA==
  ```
  
  执行这一步要保证上述的 `~/.aws/credentials` 准备完毕了，由于 AWS 交互在国外可能会出现 `TLS handshake timeout` 的问题(分析 `aws-iam-authenticator` 的日志)，多试几次就好了，或者设置代理：

  ```shell
  kubectl -v=7 get pod
  ```

# 注意事项

- 记住 `~/.aws/credentials` 中的 token 不能使用 root 账号，必须要创建一个 iam 的用户再进行 AssumeRole