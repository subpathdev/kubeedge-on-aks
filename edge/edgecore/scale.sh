#!/bin/bash

NUM=${1:-100}
START=${2:-0}
END=`expr ${START} + ${NUM}`
echo Adding ${NUM} devices from ${START} to ${END}
for (( i=$START; i<=$END; i++ ))
do
  ./instanciate.sh flo${i}
  sleep 1
done
