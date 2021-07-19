# Using vcluser to seperate tenants

This shows how to setup virtual clusters for a multitenant setup using [vcluster](https://www.vcluster.com/docs/what-are-virtual-clusters).
This is used with the KubeEdge services installed in the `kubeedge` cluster running on AKS. So make sure everything is setup as shown in the [README.md](../README.md).

## Prerequisites

Download and install vcluster cli

```sh
$ curl -s -L "https://github.com/loft-sh/vcluster/releases/latest" | sed -nE 's!.*"([^"]*vcluster-linux-amd64)".*!https://github.com\1!p' | xargs -n 1 curl -L -o vcluster && chmod +x vcluster
$ sudo mv vcluster /usr/local/bin
# Check if vcluster is working
$ vcluster --version
```

## Setup a virtual cluster

```sh
# switch to the `kubeedge` cluster
$ kubectl ctx kubeedge
$ cd vcluster/
# create a new virtual cluster called `tenant1` in the namespace `tenant1`.
$ vcluster create tenant1 --create-cluster-role -n tenant1 -f values.yaml 
[info]   Creating namespace tenant1
[info]   execute command: helm upgrade tenant1 vcluster --repo https://charts.loft.sh --version 0.3.1 --kubeconfig /tmp/407369614 --namespace tenant1 --install --repository-config='' --values /tmp/577391509 --values values.yaml
[done] √ Successfully created virtual cluster tenant1 in namespace tenant1. Use 'vcluster connect tenant1 --namespace tenant1' to access the virtual cluster
# check the new created vcluster
$ vcluster list
 NAME      NAMESPACE   CREATED                         
 tenant1   tenant1     2021-07-19 11:02:45 +0200 CEST 
```

The vcluster is now ready to use. 

## Using a vcluster

```sh
# now connect to the cluster to use it. A kubeconfig will be created that can be used to access the vcluster
$ vcluster connect tenant1 --namespace tenant1
[done] √ Virtual cluster kube config written to: ./kubeconfig.yaml. You can access the cluster via `kubectl --kubeconfig ./kubeconfig.yaml get namespaces`
[info]   Starting port forwarding: kubectl port-forward --namespace tenant1 tenant1-0 8443:8443
Forwarding from 127.0.0.1:8443 -> 8443
Forwarding from [::1]:8443 -> 8443
$ kubectl --kubeconfig ./kubeconfig.yaml get namespaces
NAME              STATUS   AGE
default           Active   106s
kube-system       Active   106s
kube-public       Active   106s
kube-node-lease   Active   106s
$ kubectl --kubeconfig ./kubeconfig.yaml get nodes
NAME                                STATUS   ROLES               AGE    VERSION
aks-agentpool-82236215-vmss000000   Ready    agent               2m1s   v1.20.7
mynode                              Ready    agent,edge,master   2m1s   v1.19.3-kubeedge-v1.7.1
# apply some manifest
kubectl --kubeconfig ./kubeconfig.yaml apply -f ../edge/application/secretasfile/manifest.yaml 
secret/mysecret created
pod/secretasfile created
# check pods
$ kubectl --kubeconfig ./kubeconfig.yaml get pods
NAME           READY   STATUS    RESTARTS   AGE
secretasfile   1/1     Running   0          38s
# check containers on virtual device mynode
$ docker exec -it mynode bash
$ docker ps
CONTAINER ID        IMAGE                COMMAND                  CREATED              STATUS              PORTS               NAMES
490983be94b9        d057f4d6e5e2         "/bin/sh -c 'while t…"   About a minute ago   Up About a minute                       k8s_echo_secretasfile-x-default-x-tenant1_tenant1_a2c3ec9f-11ba-4d12-8ecb-e3710ef0b0cd_0
471e9b4ae07c        kubeedge/pause:3.1   "/pause"                 About a minute ago   Up About a minute                       k8s_POD_secretasfile-x-default-x-tenant1_tenant1_a2c3ec9f-11ba-4d12-8ecb-e3710ef0b0cd_0
$ docker logs 
docker logs k8s_echo_secretasfile-x-default-x-tenant1_tenant1_a2c3ec9f-11ba-4d12-8ecb-e3710ef0b0cd_0
Mon Jul 19 09:05:57 UTC 2021
myuser
Mon Jul 19 09:05:58 UTC 2021
myuser
Mon Jul 19 09:05:59 UTC 2021
myuser
Mon Jul 19 09:06:00 UTC 2021
myuser
```
