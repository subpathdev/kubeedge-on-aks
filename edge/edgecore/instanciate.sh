#!/bin/bash

# This script starts a virtual kubeedge client node
# Usage: ./instanciate.sh [device-name]
# if no device-name is given a random uuid is used prefixed with 'kubeedge-'
# example: kubeedge-03e73467-944f-423a-b2fb-3076787e0658

EDGE_NAME=${1}
if [ "$#" -ne 1 ]; then
    #EDGE_NAME=kubeedge-$(uuidgen)
    EDGE_NAME=`tr -dc a-z </dev/urandom | head -c 20 ; echo ''`
fi
echo Creating virtual kubeedge node with called ${EDGE_NAME}
template=template/node.json.TEMPLATE
values=template/values.conf

. "${values}"
TMPFILE=`mktemp`
eval "echo \"$(cat "${template}")\"" > ${TMPFILE}
cat ${TMPFILE}
kubectl apply -f ${TMPFILE}
docker run -d --privileged -e EDGE_NAME=${EDGE_NAME} --name ${EDGE_NAME} edge:latest
