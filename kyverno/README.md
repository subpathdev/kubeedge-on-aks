# Using kyverno to prevent node label deletion or altering

This is needed when using several KubeEdge instances in the same cluster. When using vcluster to seperate tenants using the node-selector, it is possible that the labels that select the nodes is deleted or altered by the user. To prevent this one needs to have a policy agent of some sort preventing this altering or deletion. 

This shows how it can be done using kyverno.

## Install kyverno

```sh
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace -f values.yaml
```

Next apply the rule that to restrict the deletion or altering of the node labels `edgefarm.tenant`.

```sh
kubectl apply -f restrict_edgefarm_tenant_node_label_changes.yaml
```




