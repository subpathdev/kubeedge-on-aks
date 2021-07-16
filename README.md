# KubeEdge on Azure AKS

This repository contains notes on how to setup [KubeEdge](https://github.com/kubeedge/kubeedge) on Azure AKS.

**:warning: This was only tested using KubeEdge v1.7.1 :warning:**

**:warning: Do not use this in production environments as it still contains errors and glitches :warning:**

## Setup AKS
You need two AKS clusters:
- `main` (this one later runs [Kubermatic Kubernetes Platform](https://www.kubermatic.com/products/kubermatic/))
- `kubeedge` (this one later runs [KubeEdge CloudCore](https://kubeedge.io/en/)). The KubeEdge nodes will connect to this cluster.

For this demo each cluster does not need more than one worker nodes. Turn off auto scaling and manually set worker nodes to `1`.

Export your two kubeconfig files that they can be choosen via `kubectl ctx`.

You need a static public IP for KubeEdge's CloudCore in the resource group created for your `kubeedge` cluster (`MC_...`). So create one using either the Azure Web UI or az cli.
This shows an example how to create one. [Further information](https://docs.microsoft.com/en-us/azure/aks/static-ip#create-a-static-ip-address)
```sh
az network public-ip create \
    --resource-group MC_<...> \
    --name cloudcorePublicIP \
    --sku Standard \
    --allocation-method static \
    - l germanywestcentral
```

Note the IP for later usage.

## Setup Kubermatic Kubernetes Platform

Switch to the `main` cluster
```sh
kubectl ctx main
```

Copy the example files and modify them as needed.

```sh
cd kubermatic
cp examples/kubermatic.example.ce.yaml kubermatic.yaml
cp examples/values.example.yaml values.yaml
```

**First modify values.yaml**

* Replace all references of `cluster.example.dev` with your domain
* Set `dex.clients.id["kubermatic"].secret` using `cat /dev/urandom | tr -dc A-Za-z0-9 | head -c32`
* Set `dex.staticPassword.email` to your needs (this is only needed to login to kubermatic)
* Set `dex.staticPassword.hash`. Think of a new password and note it somewhere. Then recreate the hash using `htpasswd -bnBC 10 "" PASSWORD_HERE | tr -d ':\n' | sed 's/$2y/$2a/'`
* Set `dex.certIssuer.name`. Decide if you want `letsencrypt-staging` or `letsencrypt-prod`

**Second modify kubermatic.yaml**

* Replace all references of `cluster.example.dev` with your domain
* Create `issuerCookieKey` and `serviceAccountKey` with `cat /dev/urandom | tr -dc A-Za-z0-9 | head -c32`
* Set `spec.ingress.name`. Decide if you want `letsencrypt-staging` or `letsencrypt-prod`
* Set `spec.auth.issuerClientSecret` to the value created in `values.yaml`@`dex.clients.id["kubermatic"].secret`


**Next deploy**

```sh
./kubermatic-installer deploy --config kubermatic.yaml --helm-values values.yaml --storageclass azure
```

If everything went fine you should a similar output.

```sh
$ kubectl ns kubermatic
$ kubectl get pods                           
NAME                                                    READY   STATUS    RESTARTS   AGE
kubermatic-api-689b466bcf-lmlx4                         1/1     Running   0          41m
kubermatic-api-689b466bcf-sjbbt                         0/1     Pending   0          40m
kubermatic-dashboard-5fb845c6f8-2x76r                   0/1     Pending   0          41m
kubermatic-dashboard-5fb845c6f8-xtg9v                   1/1     Running   0          41m
kubermatic-master-controller-manager-79897fcfb9-hzw5v   1/1     Running   0          46h
kubermatic-operator-6c6c49ffd9-5g8lq                    1/1     Running   0          41m
$ kubectl get service                  
NAME                   TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                       AGE
kubermatic-api         NodePort    10.0.69.232   <none>        80:31410/TCP,8085:30401/TCP   46h
kubermatic-dashboard   NodePort    10.0.146.89   <none>        80:31567/TCP                  46h
seed-webhook           ClusterIP   10.0.31.224   <none>        443/TCP                       46h
$ kubectl get ingress                 
NAME         CLASS    HOSTS                  ADDRESS         PORTS     AGE
kubermatic   <none>   cluster.example.dev   123.123.123.123   80, 443   46h
```

Visit the [kubermatic dashboard](https://cluster.example.dev) and login with the credentials in section dex.

## Connect `kubeedge` cluster with Kubermatic Kubernetes Platform

In the Kubermatic dashboard click the `Add Project` button and create a name e.g. `kubeedge`.
Go into the newly created project and click the `Connect Cluster` button. Enter a name and the kubeconfig from the `kubeedge` cluster. 
That's it. The `kubeedge` cluster is now maintained via kubermatic.


## Setup KubeEdge

First swtich to your `kubeedge` cluster.

```sh
kubectl ctx kubeedge
```

Copy values.yaml

```sh
cd kubeedge
cp charts/kubeedge/values.yaml.example charts/kubeedge/values.yaml
```

Modify in the file charts/kubeedge/values.yaml the sections `loadBalancerIp` and `cloudHub.advertiseAddress` to match your public IP created above. After that install the helm chart.
This helm chart deploys every CustomResourceDefinition (crd) needed for CloudCore, a serviceaccount, a clusterrole, a clusterrolebinding, the configmaps, the deployment and the service itself.

```sh
kubectl create ns kubeedge
helm install \
    kubeedge \
    ./charts/kubeedge \
    --namespace kubeedge
```

**:warning: Warning :warning:**

You may want to look after a service called `cloudcore` using `kubectl get service`. If the service is not deployed properly, please modify `spec.loadBalancerIP` in `manifeet/service.example.yaml` and deploy it using `kubectl apply -f manifest/service.example.yaml`.

If everything went fine ou can view the logs of the cloudcore pod and the service should be reachable from external.

```sh
$ kubectl ns kubeedge
$ kubectl get pods   
NAME                         READY   STATUS    RESTARTS   AGE
cloudcore-67b79b7785-mlsfh   1/1     Running   0          77m

$ kubectl logs cloudcore-67b79b7785-mlsfh 
I0715 07:51:57.784086       1 server.go:73] Version: v1.7.1
W0715 07:51:57.784126       1 client_config.go:608] Neither --kubeconfig nor --master was specified.  Using the inClusterConfig.  This might not work.
I0715 07:51:58.843076       1 module.go:34] Module cloudhub registered successfully
I0715 07:51:58.862774       1 module.go:34] Module edgecontroller registered successfully
I0715 07:51:58.862940       1 module.go:34] Module devicecontroller registered successfully
I0715 07:51:58.862972       1 module.go:34] Module synccontroller registered successfully
W0715 07:51:58.863015       1 module.go:37] Module cloudStream is disabled, do not register
W0715 07:51:58.863021       1 module.go:37] Module router is disabled, do not register
W0715 07:51:58.863026       1 module.go:37] Module dynamiccontroller is disabled, do not register
I0715 07:51:58.863061       1 core.go:24] Starting module edgecontroller
I0715 07:51:58.863106       1 core.go:24] Starting module devicecontroller
I0715 07:51:58.863139       1 core.go:24] Starting module synccontroller
I0715 07:51:58.863176       1 upstream.go:119] start upstream controller
I0715 07:51:58.864190       1 core.go:24] Starting module cloudhub
I0715 07:51:58.864513       1 downstream.go:870] Start downstream devicecontroller
I0715 07:51:58.868151       1 downstream.go:566] start downstream controller
I0715 07:51:58.967123       1 server.go:243] Ca and CaKey don't exist in local directory, and will read from the secret
W0715 07:51:58.967250       1 channelq.go:294] nodeQueue for edge node node-a not found and created now
W0715 07:51:58.967274       1 channelq.go:322] nodeStore for edge node node-a not found and created now
I0715 07:51:58.978119       1 server.go:288] CloudCoreCert and key don't exist in local directory, and will read from the secret
I0715 07:51:59.013469       1 signcerts.go:100] Succeed to creating token
I0715 07:51:59.013518       1 server.go:44] start unix domain socket server
I0715 07:51:59.013655       1 uds.go:71] listening on: //var/lib/kubeedge/kubeedge.sock
W0715 07:51:59.027087       1 channelq.go:308] nodeListQueue for edge node node-a not found and created now
W0715 07:51:59.027112       1 channelq.go:336] nodeListStore for edge node node-a not found and created now
I0715 07:51:59.033321       1 server.go:64] Starting cloudhub websocket server
I0715 07:52:00.864735       1 upstream.go:63] Start upstream devicecontroller

$ kubectl get service
NAME        TYPE           CLUSTER-IP   EXTERNAL-IP     PORT(S)                           AGE
cloudcore   LoadBalancer   10.0.48.54   123.123.123.123   10002:30002/TCP,10000:30000/TCP   13h
```

## Setup edge device

For this you need to have docker installed locally as the kubeedge nodes run in a docker container.
Copy `values.conf.example` and modify it. Build the image locally and instanciate a node. The name `mynode` is optional. If no name is provided, a random name is chosen for you.

```sh
cd edge/edgecore
cp template/values.conf.example template/values.conf
docker build -t edge:latest .
./instanciate.sh mynode
```

**:warning: When you close this terminal, the node will be deleted. :warning:**

Check if the node `mynode` has been successfully added

```sh
kubectl get nodes
NAME                                STATUS   ROLES               AGE   VERSION
aks-agentpool-82236215-vmss000000   Ready    agent               29h   v1.20.7
mynode                              Ready    agent,edge          4s    v1.19.3-kubeedge-v1.7.1
```

## Deploy some applications

### Simple nginx

This is a very basic example of a DaemonSet (gets deployed on every node the node selector matches), that runs a nginx instance.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
      nodeSelector:
        app: nginx
```

Label the node and apply it using kubectl

```sh
cd edge/application
kubectl label nodes mynode simplenginx=simplenginx
kubectl apply -f simplenginx/simplenginx.yaml
```

Monitor the pods being created

```sh
$ kubectl get pods
NAME                         READY   STATUS    RESTARTS   AGE
cloudcore-67b79b7785-mlsfh   1/1     Running   0          25h
simplenginx-4bb72            1/1     Running   0          31s
```

Now start an interactive shell within your virtual kubeedge device `mynode` and verify if the nginx container is running. 
You may repeat `docker ps` until the container comes alive.

```sh
docker exec -it mynode bash
docker ps
```
