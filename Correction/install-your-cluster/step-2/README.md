# IngressController

Nginx prods are deployed as a daemonSet -> 1 per node.

Yet, only 3 pods for a cluster with 3 masters and 3 workers... this is due to the taint `node-role.kubernetes.io/controlplane=true:NoSchedule` present on the masters.

The daemonset exposes the nginx directly on the host port:
```yaml
  ports:
    - containerPort: 80
      hostPort: 80
      name: http
      protocol: TCP
    - containerPort: 443
      hostPort: 443
      name: https
      protocol: TCP
    - containerPort: 8443
      hostPort: 8443
      name: webhook
      protocol: TCP
```

Because the workers have public IPs, you can join the nginx ingress pods using the `lb` DNS record which is a round robin the worker IPs.

# StorageClass and provisioner

```sh
# No strorage class.
kubectl get storageclass
```

Inspect the configmap:
```sh
kubectl get ns
kubectl get cm local-path-config -n local-path-storage
```
Persistent volumes will be created in `/opt/local-path-provisioner`.

This directory is a local folder on each node -> data are stuck to a node.If a node is lost, the data are also lost.

To optimize this:
* either keep local path provisioner and mount `/opt/local-path-provisioner` to a remote storage system (NFS, SAN)
* better: use another storage class with a driver to provision PV on a remote storage.

# Capacity of the cluster

## for pods

NB pods: min (cluster-cidr, min(nb nodes * pod CIDR per node, nb nodes * max nb of pods per node ))

Values:
* Cluster CIDR: --cluster-cidr=10.42.0.0/16
* pod CIDR per node (`kubectl describe nodes`): 10.42.0.0/24
* max number of pods per node (`kubectl describe nodes`) :110

## for services

Service CIDR: --service-cluster-ip-range=10.43.0.0/16

# Networking

Network plugin: [calico with GCE](https://projectcalico.docs.tigera.io/getting-started/kubernetes/self-managed-public-cloud/gce).

That means IPIP overlay.

Calico resources:
```sh
kubectl api-resources |grep calico
# Look at the pod CIDR seen by Calico
kubectl get ippools/default-ipv4-ippool -o yaml
# Look at the Calico allocation tables:
kubectl get ipamblocks
```

## Overlay Network

```sh
# See ipipMode value
kubectl get ippools/default-ipv4-ippool -o yaml
# See calico_backend: bird
kubectl get configmap/calico-config -o yaml -n kube-system
```