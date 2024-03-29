# IngressController

Nginx prods are deployed as a daemonSet -> 1 per node.

Where are the nginx pods running?:

```yaml
kubectl get ns
kubectl get all -n kube-system |grep ingress-nginx
kubectl describe daemonset.apps/rke2-ingress-nginx-controller -n kube-system
```

How is that achieved ?

Yet, only 3 pods for a cluster with 3 masters and 3 workers... this is due to the taint `node-role.kubernetes.io/controlplane=true:NoSchedule` present on the masters.

What are the ports they exposed?

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
Ask your trainer to indicate the public DNS record for the lb and try to connect to the exposed Nginx ?

http://lb.k8s-ops-X.wescaletraining.fr/

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
* better: use another storage class with a [CSI driver](https://kubernetes-csi.github.io/docs/drivers.html) to provision PV on a remote storage.

# Capacity of the cluster

## for pods

* Default value max number of pods per node: 
```sh
kubectl get node worker-X -ojsonpath='{.status.capacity.pods}{"\n"}'
```
=> Default number of pods for each node: 110

* Max number of pods:

```sh
kubectl describe node worker-X
```
=> 10.42.X.0/24 : 256 Ips so 256 Pods

## for services

```sh
ssh -F provided_ssh_config master-0
sudo su
ps -ef|grep kube-controller
```
=> Service CIDR: --service-cluster-ip-range=10.43.0.0/16

# Networking

Current CNI is CANAL. Works great but Calico recommends to use the native VXLan/IPinIP mode without Flannel.

That means IPIP overlay.

Calico resources:

```sh
kubectl api-resources |grep calico
```

## Overlay Network

```sh
kubectl get cm -n kube-system|grep canal
# See CM content -> VXLAN and Calico
kubectl get cm -n kube-system rke2-canal-config -o yaml
```
