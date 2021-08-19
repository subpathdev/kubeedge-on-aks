#!/bin/bash
rm -rf config
mkdir -p config/ca
mkdir -p config/certs
kubectl get secrets casecret -o jsonpath='{.data}' -n kubeedge | jq -r '.cadata' > config/ca/rootCa.crt
kubectl get secrets cloudcoresecret -o jsonpath='{.data}' -n kubeedge | jq -r '.cloudcoredata' > config/certs/server.crt
kubectl get secrets cloudcoresecret -o jsonpath='{.data}' -n kubeedge | jq -r '.cloudcorekeydata' > config/certs/server.key
#IP=`kubectl get service cloudcore -n kubeedge -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
IP=my-tenant.kubeedge.edgefarm.dev
echo CLOUDCORE_IP=${IP} > template/values.conf
TOKEN=`kubectl get secrets tokensecret -n kubeedge -o jsonpath='{.data}' | jq -r '.tokendata' | base64 -d`
echo TOKEN="\"${TOKEN}\"" >> template/values.conf

docker build -t edge .
