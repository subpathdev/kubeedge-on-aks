#!/usr/bin/env bash
LOCAL_IP=$(hostname -i)
template=/kubeedge/edgecore.yaml.TEMPLATE
values=/kubeedge/values.conf

mkdir -p /etc/kubeedge/config/
. "${values}"
eval "echo \"$(cat "${template}")\"" > /etc/kubeedge/config/edgecore.yaml
