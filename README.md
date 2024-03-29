# KubeEdge on Azure AKS

This repository contains notes on how to setup [KubeEdge](https://github.com/kubeedge/kubeedge) on Azure AKS.
It is loosely based on [adriangonz/kubeedge-talk](https://github.com/adriangonz/kubeedge-talk).

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
$ az network public-ip create \
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
$ kubectl ctx main
```

Copy the example files and modify them as needed.

```sh
$ cd kubermatic
$ cp examples/kubermatic.example.ce.yaml kubermatic.yaml
$ cp examples/values.example.yaml values.yaml
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
$ ./kubermatic-installer deploy --config kubermatic.yaml --helm-values values.yaml --storageclass azure
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
$ kubectl ctx kubeedge
```

Copy values.yaml

```sh
$ cd kubeedge
$ cp charts/kubeedge/values.yaml.example charts/kubeedge/values.yaml
```
If you have created a public IP and want that, then modify in the file charts/kubeedge/values.yaml the sections `loadBalancerIp` and `cloudHub.advertiseAddress` to match your public IP created above. If you didn't create a public IP, then you have to create a LoadBalancer service first and put that IP address into the `cloudHub.advertiseAddress`. After that install the helm chart.
This helm chart deploys every CustomResourceDefinition (crd) needed for CloudCore, a serviceaccount, a clusterrole, a clusterrolebinding, the configmaps, the deployment and the service itself.

These are the steps to install that service called `cloudcore` using `kubectl get service` for your LoadBalancerIP. Deploy `manifeet/service.example.yaml` it using `kubectl apply -f manifest/service.example.yaml` and get the IP address using this

```sh
kubectl get service -n kubeedge
NAME        TYPE           CLUSTER-IP    EXTERNAL-IP       PORT(S)                           AGE
cloudcore   LoadBalancer   10.0.48.54    123.123.123.123   10002:30002/TCP,10000:30000/TCP   1m
```

Deploy kubeedge using helm after you've modified charts/kubeedge/values.yaml with that IP address.

```sh
$ kubectl create ns kubeedge
$ helm install \
    kubeedge \
    ./charts/kubeedge \
    --namespace kubeedge
```

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
NAME        TYPE           CLUSTER-IP   EXTERNAL-IP       PORT(S)                           AGE
cloudcore   LoadBalancer   10.0.48.54   123.123.123.123   10002:30002/TCP,10000:30000/TCP   13h
```

## Setup edge device

For this you need to have docker installed locally as the kubeedge nodes run in a docker container.
Copy `values.conf.example` and modify it. You find introductions in the file. Build the image locally and instanciate a node. The name `mynode` is optional. If no name is provided, a random name is chosen for you.

```sh
$ kubectl ns kubeedge
$ cd edge/edgecore
# Get rootCA.crt, server.crt and server.key from cloudcore
$ kubectl get secrets casecret -o jsonpath='{.data}' | jq -r '.cadata' > config/ca/rootCa.crt
$ kubectl get secrets cloudcoresecret -o jsonpath='{.data}' | jq -r '.cloudcoredata' > config/certs/server.crt
$ kubectl get secrets cloudcoresecret -o jsonpath='{.data}' | jq -r '.cloudcorekeydata' > config/certs/server.key
# modify template/values.conf
$ cp template/values.conf.example template/values.conf
$ docker build -t edge:latest .
$ ./instanciate.sh mynode
```

**:warning: When you close this terminal, the node will be deleted. :warning:**

Check if the node `mynode` has been successfully added

```sh
$ kubectl get nodes
NAME                                STATUS   ROLES               AGE   VERSION
aks-agentpool-82236215-vmss000000   Ready    agent               29h   v1.20.7
mynode                              Ready    agent,edge          4s    v1.19.3-kubeedge-v1.7.1
```

## Deploy some applications

### Simple nginx

This is a very basic example of a DaemonSet (gets deployed on every node the node selector matches), that runs a nginx instance.
See [simplenginx/manifest.yaml](edge/application/simplenginx/manifest.yaml)

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
        ports:
        - containerPort: 80
          hostPort: 8080
      nodeSelector:
        app: nginx
```

Label the node and apply it using kubectl

```sh
$ cd edge/application
$ kubectl label nodes mynode simplenginx=simplenginx
$ kubectl apply -f simplenginx/manifest.yaml
daemonset.apps/simplenginx created
```

Monitor the pods being created

```sh
$ kubectl get pods -o wide
NAME                         READY   STATUS    RESTARTS   AGE   IP           NODE                                NOMINATED NODE   READINESS GATES
cloudcore-67b79b7785-mlsfh   1/1     Running   0          27h   10.240.0.4   aks-agentpool-82236215-vmss000000   <none>           <none>
simplenginx-gsw4r            1/1     Running   0          26s   172.18.0.2   mynode                              <none>           <none>
```

Now start an interactive shell within your virtual kubeedge device `mynode` and verify that the nginx container is running. 
You may repeat `docker ps` until the container comes alive.

```sh
# Start a shell in the virtual node
$ docker exec -it mynode bash
# check for running containers
$ docker ps 
CONTAINER ID        IMAGE                COMMAND                  CREATED              STATUS              PORTS                  NAMES
518c37093c27        nginx                "/docker-entrypoint.…"   About a minute ago   Up About a minute                          k8s_simplenginx_simplenginx-gsw4r_kubeedge_dba3a54e-985a-44a8-ae08-e143705b2636_0
818a35aacffc        kubeedge/pause:3.1   "/pause"                 About a minute ago   Up About a minute   0.0.0.0:8080->80/tcp   k8s_POD_simplenginx-gsw4r_kubeedge_dba3a54e-985a-44a8-ae08-e143705b2636_0
# check within your virtual node if the nginx server is reachable
$ curl localhost:8080
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

### Pod to pod communication using host network

This example shows a pod running nginx (port 80) and another pod running cyclic curl commands on it. They can work together by
* exposing the nginx port to the host network
* using the host network and the given port to make a connection

See [simplenginx.yaml](edge/application/samenode_hostIP/manifest.yaml)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: curl
spec:
  selector:
    matchLabels:
      curl: curl
  template:
    metadata:
      labels:
        curl: curl
    spec:
      containers:
        - name: curl
          # This image takes $HOST as argument and runs cyclic curl commands on this host forvever 
          # showing that the DNS resolution and pod2pod communication is basically working.
          image: siredmar/curl:latest
          env:
          - name: HOST
            # WARNING: don't use http://... for curl
            valueFrom:
              fieldRef:
                fieldPath: status.hostIP
      nodeSelector:
        curl: curl
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      nginx: nginx
  template:
    metadata:
      labels:
        nginx: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
          hostPort: 80
      nodeSelector:
        nginx: nginx
```

Label the node and apply it using kubectl

```sh
$ cd edge/application
$ kubectl label nodes mynode curl=curl
$ kubectl label nodes mynode nginx=nginx
$ kubectl apply -f samenode_hostIP/manifest.yaml
daemonset.apps/curl created
daemonset.apps/nginx created
```

Monitor the pods being created

```sh
$ kubectl get pods -o wide
NAME                         READY   STATUS    RESTARTS   AGE   IP           NODE                                NOMINATED NODE   READINESS GATES
cloudcore-67b79b7785-mlsfh   1/1     Running   0          27h   10.240.0.4   aks-agentpool-82236215-vmss000000   <none>           <none>
curl-5hlcj                   1/1     Running   0          53s   172.18.0.3   mynode                              <none>           <none>
nginx-vc7hp                  1/1     Running   0          53s   172.18.0.2   mynode                              <none>           <none>
```

Now start an interactive shell within your virtual kubeedge device `mynode` and verify that the nginx container is running. 
You may repeat `docker ps` until the container comes alive.

```sh
# Start a shell in the virtual node
$ docker exec -it mynode bash
# check for running containers
$ docker ps
CONTAINER ID        IMAGE                COMMAND                  CREATED              STATUS              PORTS                NAMES
bfc7ef242bed        siredmar/curl        "/usr/local/bin/curl…"   About a minute ago   Up About a minute                        k8s_curl_curl-5hlcj_kubeedge_aad81518-20d9-4c06-8da1-fd7b96057217_0
3dcb27a8f887        nginx                "/docker-entrypoint.…"   About a minute ago   Up About a minute                        k8s_nginx_nginx-vc7hp_kubeedge_e600a79c-7f86-45ed-ac8e-0d19a0ecce1c_0
53f4a3b20236        kubeedge/pause:3.1   "/pause"                 About a minute ago   Up About a minute                        k8s_POD_curl-5hlcj_kubeedge_aad81518-20d9-4c06-8da1-fd7b96057217_0
df5fb3addc1f        kubeedge/pause:3.1   "/pause"                 About a minute ago   Up About a minute   0.0.0.0:80->80/tcp   k8s_POD_nginx-vc7hp_kubeedge_e600a79c-7f86-45ed-ac8e-0d19a0ecce1c_0
# check env variables of curl container. This is the internal host IP of the virtual device.
$ docker exec -it k8s_curl_curl-5hlcj_kubeedge_aad81518-20d9-4c06-8da1-fd7b96057217_0 env | grep HOST=
HOST=172.17.0.2
# check logs of curl container
$ docker logs k8s_curl_curl-5hlcj_kubeedge_aad81518-20d9-4c06-8da1-fd7b96057217_0
-----------------------------------------
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0   573k      0 --:--:-- --:--:-- --:--:--  597k
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

real	0m0.008s
user	0m0.007s
sys	0m0.000s
Fri Jul 16 11:38:59 UTC 2021
# ... and many more
```

### Pod using PersistentVolume

This example shows a pod running nginx (port 80) using a persistent volume. It mounts the default nginx files location to the hosts filesystem on `/mnt/data/`, meaning if you edit the `/mnt/data/index.html` the nginx running in the pod can read and deliver it.

See [persistent_volume/manifest.yaml](edge/application/persistent_volume/manifest.yaml)

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: task-pv-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: task-pv-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: task-pv-pod
spec:
  volumes:
    - name: task-pv-storage
      persistentVolumeClaim:
        claimName: task-pv-claim
  containers:
    - name: task-pv-container
      image: nginx
      ports:
        - containerPort: 80
          hostPort: 8080
          name: "http-server"
      volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: task-pv-storage
  nodeSelector:
    app: pv
```

Label the node and apply it using kubectl

```sh
$ cd edge/application
$ kubectl create ns tenant1
$ kubectl ns tenant1
$ kubectl label nodes mynode app=pv
$ kubectl apply -f persistent_volume/manifest.yaml
persistentvolume/task-pv-volume created
persistentvolumeclaim/task-pv-claim created
pod/task-pv-pod created
```

Monitor the pod being created

```sh
$ kubectl get pods -o wide
NAME                         READY   STATUS    RESTARTS   AGE   IP           NODE                                NOMINATED NODE   READINESS GATES
cloudcore-67b79b7785-mlsfh   1/1     Running   0          27h   10.240.0.4   aks-agentpool-82236215-vmss000000   <none>           <none>
task-pv-pod                  1/1     Running   0          8m18s 172.18.0.2   node0                               <none>           <none>
```

Watch PersistentVolumes and PersistentVolumeClaims

```sh
$ kubectl get persistentvolumeclaims
NAME            STATUS   VOLUME           CAPACITY   ACCESS MODES   STORAGECLASS   AGE
task-pv-claim   Bound    task-pv-volume   1Gi        RWO            manual         116s
$ kubectl get persistentvolume      
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                    STORAGECLASS   REASON   AGE
task-pv-volume                             1Gi        RWO            Retain           Bound    tenant1/task-pv-claim    manual                  2m1s
```

Now start an interactive shell within your virtual kubeedge device `mynode` and verify that the nginx container is running. 
You may repeat `docker ps` until the container comes alive.

```sh
# Start a shell in the virtual node
$ docker exec -it mynode bash
# check for running containers
$ docker ps
CONTAINER ID        IMAGE                COMMAND                  CREATED             STATUS              PORTS                  NAMES
54fc888dc56d        nginx                "/docker-entrypoint.…"   2 minutes ago       Up 2 minutes                               k8s_task-pv-container_task-pv-pod_tenant1_5bbef361-b43d-4740-a6e5-9893bae3bdf6_0
6dfd74ff48da        kubeedge/pause:3.1   "/pause"                 2 minutes ago       Up 2 minutes        0.0.0.0:8080->80/tcp   k8s_POD_task-pv-pod_tenant1_5bbef361-b43d-4740-a6e5-9893bae3bdf6_0
# Read nginx from host network on port 8080
$ curl localhost:8080
<html>
<head><title>403 Forbidden</title></head>
<body>
<center><h1>403 Forbidden</h1></center>
<hr><center>nginx/1.21.1</center>
</body>
</html>
# This error results in a missing index.html, as the volume is mounted `/usr/share/nginx/html` to `/mnt/data` but this is empty.
# Lets create a basic index.html
$ echo Hello from KubeEdge running on AKS > /mnt/data/index.html
# Let's try it again
$ curl localhost:8080
Hello from KubeEdge running on AKS
```

### Pod using secret

This example shows a pod using a secret. It shows that secrets can be used within pods. In this example the secret is used as a file within a pod. 

See [secretasfile/manifest.yaml](edge/application/secretasfile/manifest.yaml)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque 
data:
  # created using `echo -n 'myuser' | base64`
  username: bXl1c2Vy
---
apiVersion: v1
kind: Pod
metadata:
  name: secretasfile
spec:
  containers:
  - name: echo
    image: bash:5
    command: ["/bin/sh"]
    args: ["-c","while true; do date; cat /mnt/secrets/username; echo; sleep 1; done"]
    volumeMounts:
    - name: secret-volume
      mountPath: "/mnt/secrets"
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: mysecret
  nodeSelector:
    app: secretasfile
```

Label the node and apply it using kubectl

```sh
$ cd edge/application
$ kubectl create ns mynamespace
$ kubectl ns mynamespace
# delete label app if already set by another example
$ kubectl label nodes mynode app-
$ kubectl label nodes mynode app=secretasfile
$ kubectl apply -f secretasfile/manifest.yaml
secret/mysecret created
pod/secretasfile created
```

Monitor the pod being created

```sh
$ kubectl get pods -o wide
NAME                         READY   STATUS    RESTARTS   AGE   IP           NODE   NOMINATED NODE   READINESS GATES
secretasfile                 1/1     Running   0          20s   172.18.0.2   node0  <none>           <none>
```

Now start an interactive shell within your virtual kubeedge device `mynode` and verify that the container is running. 
You may repeat `docker ps` until the container comes alive.

```sh
# Start a shell in the virtual node
$ docker exec -it mynode bash
# check for running containers
$ docker ps
CONTAINER ID        IMAGE                COMMAND                  CREATED              STATUS              PORTS               NAMES
2ae3dae96663        d057f4d6e5e2         "/bin/sh -c 'while t…"   About a minute ago   Up About a minute                       k8s_echo_secretasfile_tenant1_da8f0168-4994-43fe-a62f-b82b8d366c36_0
cfde15c17abc        kubeedge/pause:3.1   "/pause"                 About a minute ago   Up About a minute                       k8s_POD_secretasfile_tenant1_da8f0168-4994-43fe-a62f-b82b8d366c36_0
# see docker logs, that should output the content of the secret and the date
$ docker logs k8s_echo_secretasfile_tenant1_da8f0168-4994-43fe-a62f-b82b8d366c36_0
Mon Jul 19 07:43:40 UTC 2021
myuser
Mon Jul 19 07:43:41 UTC 2021
myuser
Mon Jul 19 07:43:42 UTC 2021
myuser
```

## Use vcluster to differentiate between tenants

See [vcluster/README.md](vcluster/README.md)
