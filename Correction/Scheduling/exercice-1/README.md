# Create Scheduling Namespace
```sh
kubectl create namespace scheduling
```

# Hands-on: Scheduling

Can you explain what happened ?

Pod node-affinity-pod-hard scheduled in worker-1
Pod node-affinity-pod-soft scheduled in another node. The node affinity is not applied because there are not a node named worker-10

