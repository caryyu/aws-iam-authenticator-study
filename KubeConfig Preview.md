常见的 Kubernetes 配置 `~/.kube/kubeconfig` 授权认证的几种形式代表，不同的验证授权方式不同则 `API Server` 的配置也不相同，具体可以参考 Kubernetes 官方的配置。


- [几种示例](#%e5%87%a0%e7%a7%8d%e7%a4%ba%e4%be%8b)
  - [X509 客户端证书](#x509-%e5%ae%a2%e6%88%b7%e7%ab%af%e8%af%81%e4%b9%a6)
  - [Static Token](#static-token)
  - [Basic Auth](#basic-auth)
  - [OIDC](#oidc)
  - [AWS-IAM-Authenticator(Credential Plugin)](#aws-iam-authenticatorcredential-plugin)
- [参考文档](#%e5%8f%82%e8%80%83%e6%96%87%e6%a1%a3)

# 几种示例

## X509 客户端证书

```yaml
apiVersion: v1
clusters:
- cluster:
    server: https://<IP>:6443
    certificate-authority-data: <Base64>
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: "kubernetes"
  name: kubernetes
current-context: kubernetes
kind: Config
preferences: {}
users:
- name: "kubernetes"
  user:
    client-certificate-data: <Base64>
    client-key-data: <Base64>
```

## Static Token

```yaml
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: http://1.1.1.1:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    namespace: default
    user: kubernetes
  name: default
current-context: kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes
  user:
    token: "123456"
```

## Basic Auth

```yaml
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: http://1.1.1.1:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    namespace: default
    user: kubernetes
  name: default
current-context: kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes
  user:
    password: "123456"
    username: "admin"
```

## OIDC

```yaml
apiVersion: v1
clusters:
- cluster:
    server: https://<IP>:6443
    certificate-authority-data: <Base64>
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: "kubernetes"
  name: kubernetes
current-context: kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes
  user:
    auth-provider:
      config:
        client-id: <client-id>
        client-secret: <client-secret>
        id-token: <jwt-token>
        idp-certificate-authority: /root/ca.pem
        idp-issuer-url: https://oidcidp.tremolo.lan:8443/auth/idp/OidcIdP
        refresh-token: <refresh-token>
      name: oidc
```

## AWS-IAM-Authenticator(Credential Plugin)

一个 `credential plugin` 的实现，具体文档可以参考这个：https://kubernetes.io/docs/reference/access-authn-authz/authentication/#client-go-credential-plugins

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: <CA>
    server: <SERVER>
  name: kubernetes

contexts:
- context:
    cluster: kubernetes
    user: kubernetes
    namespace: default
  name: kubernetes

current-context: kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
      - token
      - -i
      - microk8s
```

# 参考文档

https://kubernetes.io/docs/reference/access-authn-authz/authentication/
https://qhh.me/2019/08/22/Kubernetes-%E9%9B%86%E7%BE%A4%E5%AE%89%E5%85%A8%E6%9C%BA%E5%88%B6%E8%AF%A6%E8%A7%A3/
https://jimmysong.io/kubernetes-handbook/guide/authentication.html
