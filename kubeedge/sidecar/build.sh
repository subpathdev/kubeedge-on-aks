#!/bin/bash
docker build -t harbor.ci4rail.com/edgefarm-dev/iptables-sidecar:0.0.1-unicorn . 
docker push harbor.ci4rail.com/edgefarm-dev/iptables-sidecar:0.0.1-unicorn
