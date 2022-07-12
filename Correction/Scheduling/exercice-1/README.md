# Create Scheduling Namespace
```sh
kubectl create namespace scheduling
```

# Hands-on: Scheduling

Can you explain what happened ?

Pod node-affinity-pod-hard scheduled in worker-1
Pod node-affinity-pod-soft scheduled in another node. The node affinity is not applied because there are not a node named worker-10

# Distribute replicas on failure domains
Can you explain what happened?

The 4th pod is not scheduled, because we have only 3 nodes and choose to distrubute replicas 

What do you suggest as an improvement?

Use topologySpreadConstraints

What will happen if you get 10 replicas?
7 replicas Pods stay in Pending status

