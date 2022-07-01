# Labels your domain of failure / topology key

Currently, no Label to indicate the zone of each node.

Must add it:
```sh
kubectl label node master-0 topology.kubernetes.io/zone=a
kubectl label node master-1 topology.kubernetes.io/zone=b
kubectl label node master-2 topology.kubernetes.io/zone=c
kubectl label node worker-0 topology.kubernetes.io/zone=a
kubectl label node worker-1 topology.kubernetes.io/zone=b
kubectl label node worker-2 topology.kubernetes.io/zone=c
```

N.B: normally, on cloud infra, each node is able to describe itself, retrieves its zone, then update its own label.