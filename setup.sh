#!/bin/bash
# Spin up the cluster using kind
kind create cluster --config=./config/kind.yaml --name kubeedge

# Getting kubeconfig and selecting right context
kind get kubeconfig --name kubeedge > ~/.kube/custom-contexts/kubeedge-local/config.yaml
kubectl ctx kind-kubeedge

# Deploy cloudcore to namespace `kubeedge`
kubectl create ns kubeedge
helm install kubeedge ./charts/kubeedge --namespace kubeedge

# Check if everything runs fine
kubectl ns kubeedge
kubectl get pods


# kubectl logs cloudcore-67b79b7785-XXXXX
# I0714 12:25:38.510495       1 server.go:73] Version: v1.7.1
# W0714 12:25:38.510541       1 client_config.go:608] Neither --kubeconfig nor --master was specified.  Using the inClusterConfig.  This might not work.
# I0714 12:25:39.540986       1 module.go:34] Module cloudhub registered successfully
# I0714 12:25:39.549237       1 module.go:34] Module edgecontroller registered successfully
# I0714 12:25:39.549320       1 module.go:34] Module devicecontroller registered successfully
# I0714 12:25:39.549348       1 module.go:34] Module synccontroller registered successfully
# W0714 12:25:39.549390       1 module.go:37] Module cloudStream is disabled, do not register
# W0714 12:25:39.549397       1 module.go:37] Module router is disabled, do not register
# W0714 12:25:39.549403       1 module.go:37] Module dynamiccontroller is disabled, do not register
# I0714 12:25:39.549844       1 core.go:24] Starting module synccontroller
# I0714 12:25:39.549939       1 core.go:24] Starting module cloudhub
# I0714 12:25:39.549980       1 core.go:24] Starting module edgecontroller
# I0714 12:25:39.550040       1 core.go:24] Starting module devicecontroller
# I0714 12:25:39.550178       1 downstream.go:870] Start downstream devicecontroller
# I0714 12:25:39.599793       1 upstream.go:119] start upstream controller
# I0714 12:25:39.602699       1 downstream.go:566] start downstream controller
# I0714 12:25:39.899392       1 server.go:243] Ca and CaKey don't exist in local directory, and will read from the secret
# I0714 12:25:39.904499       1 server.go:288] CloudCoreCert and key don't exist in local directory, and will read from the secret
# I0714 12:25:39.915717       1 signcerts.go:100] Succeed to creating token
# I0714 12:25:39.915785       1 server.go:44] start unix domain socket server
# I0714 12:25:39.916052       1 uds.go:71] listening on: //var/lib/kubeedge/kubeedge.sock
# I0714 12:25:40.009967       1 server.go:64] Starting cloudhub websocket server
# I0714 12:25:41.550437       1 upstream.go:63] Start upstream devicecontroller

# kubectl get service
# NAME        TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                           AGE
# cloudcore   LoadBalancer   10.96.115.232   <pending>     10002:30002/TCP,10000:30000/TCP   52m

