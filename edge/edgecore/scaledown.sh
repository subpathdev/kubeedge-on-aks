#!/bin/bash
#!/bin/bash
for i in {0..700}
do
  docker kill ${1:-node}${i}
  kubectl delete node ${1:-node}${i}
done
