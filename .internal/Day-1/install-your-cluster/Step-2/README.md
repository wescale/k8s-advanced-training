# Ingress, storage and network

In this exercise, you will go through different components of your cluster setup to discover what is already configured for ingress, storage and network purposes.

## Ingress Controller

First, an ingress controller is already deployed on the cluster.

Look at the cluster namespaces and find the one where the ingress controller is deployed

```sh
# Find the namespace for the ingress controler
training@bastion:~$ kubectl get namespaces

# Look at what is deployed inside the namespace
training@bastion:~$ kubectl get all -n ...
```

Examine the DaemonSet to answer the following questions:

* Where are the nginx pods running?

> They are only running on worker nodes

* How is that achieved?

> This is due to the taint `node-role.kubernetes.io/controlplane=true:NoSchedule` present on the masters.

* What are the ports they expose?

The daemonset exposes the nginx directly on the host port:

```yaml
  ...
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

Try to connect to the exposed Nginx using the load balancer DNS record for your cluster: `lb.k8s-ops-X.wescaletraining.fr`.

> Because the workers have public IPs, you can join the nginx ingress pods using the `lb` DNS record which is a round robin the worker IPs.

## StorageClass and provisioner

Now, you will look at what is configured for persistent storage.

* What are the current StorageClasses?

```sh
training@bastion:~$ kubectl get storageclass
# No storage class configured
```

You will now create a new StorageClass with (Rancher Local path provisioner)[https://github.com/rancher/local-path-provisioner].

`Local Path Provisioner` provides a way for the Kubernetes users to utilize the local storage in each node. Based on the user configuration, the `Local Path Provisioner` will create `hostPath` based persistent volumes on the node automatically.

* Install the storage class:

```sh
training@bastion:~$ kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
# Then mark the StorageClass as the default
training@bastion:~$ kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

* Inspect the config maps of the related namespace, to determine where this StorageClass will create the persistent volumes.

```sh
training@bastion:~$ kubectl get ns
training@bastion:~$ kubectl describe cm local-path-config -n local-path-storage
# Persistent volumes will be created in `/opt/local-path-provisioner`
```

* Deploy a sample pod with a persistent volume claim attached to it

```sh
training@bastion:~$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pv
  labels:
    app: nginx
spec:
  containers:
  - image: nginx:1.17.6
    name: nginx
    ports:
    - containerPort: 80
    volumeMounts:
      - mountPath: "/usr/share/nginx/html"
        name: nginx-pv-storage
  volumes:
    - name: nginx-pv-storage
      persistentVolumeClaim:
        claimName: test-pvc
EOF

# Get more information on the pod that you have created
training@bastion:~$ kubectl get po nginx-pv -o wide

```

* Explore PV and PVC resources to get more information on the volume you created

```sh
training@bastion:~$ kubectl describe pvc test-pvc
training@bastion:~$ kubectl describe pv
```

* You can connect to the kubernetes nodes `ssh -F provided_ssh_config worker-x` to see their file system and mount points.

Questions:

* What happens if the node is lost?

> The data is stored locally on the node where the pod is running. If the node is lost, the data is also lost.

* What could you suggest to optimize this?

> You can keep local path provisioner and mount `/opt/local-path-provisioner` to a remote storage system (NFS, SAN).

> A better solution is to use another storage class with a [CSI driver](https://kubernetes-csi.github.io/docs/drivers.html) to provision PV on a remote storage.

* Delete the resources you have just created:

```sh
training@bastion:~$ kubectl delete po nginx-pv
training@bastion:~$ kubectl delete pvc test-pvc
```

## Network

Finally, you will look at several things regarding the network configuration of your cluster.

### Cluster capacity

Connect to a master node and explore the content of the `/etc/kubernetes` directory. Try to understand the different files you find (hint: you may have to get more privileges to do this).

* Find both the `pods` and `services` CIDR in these files.

```sh
training@bastion:~$ ssh -F provided_ssh_config master-0
training@master-0:~$ sudo -i
# First we look for the pods CIDR also known as cluster CIDR
root@master-0:~$ grep -ri cluster-cidr /etc/kubernetes
/etc/kubernetes/manifests/kube-controller-manager.yaml:    - --cluster-cidr=10.244.0.0/16
# Then we search for the services CIDR
root@master-0:~$ grep -ri service-cluster-ip-range /etc/kubernetes
/etc/kubernetes/manifests/kube-controller-manager.yaml:    - --service-cluster-ip-range=10.96.0.0/12
/etc/kubernetes/manifests/kube-apiserver.yaml:    - --service-cluster-ip-range=10.96.0.0/12
```

* Are the pods in your cluster in the range you found ? If not, why ?

```sh
# Some pods are in the 10.244.0.0/16
# The ones that are not correspond to static pods defined in the /etc/kubernetes directory
# These ones take the Node IP directly
training@bastion:~$ kubectl get po -o wide -A
NAMESPACE          NAME                                                READY   STATUS    RESTARTS   AGE    IP              NODE                        NOMINATED NODE   READINESS GATES
calico-apiserver   calico-apiserver-55d56748bf-cfwdk                   1/1     Running   0          117m   10.244.194.5    master-0.wescale.internal   <none>           <none>
calico-apiserver   calico-apiserver-55d56748bf-hzw96                   1/1     Running   0          117m   10.244.194.2    master-0.wescale.internal   <none>           <none>
calico-system      calico-kube-controllers-ddc6ccdd6-cvws6             1/1     Running   0          117m   10.244.194.6    master-0.wescale.internal   <none>           <none>
calico-system      calico-node-4f7zb                                   1/1     Running   0          117m   10.123.1.4      master-0.wescale.internal   <none>           <none>
calico-system      calico-node-fhsk4                                   1/1     Running   0          115m   10.123.1.2      master-2.wescale.internal   <none>           <none>
calico-system      calico-node-ghd7h                                   1/1     Running   0          116m   10.123.1.3      master-1.wescale.internal   <none>           <none>
...
```

Now describe a worker node using the `kubectl` command and try to find:

* How many pods can we schedule on this node from a Kubernetes perspective ?

```sh
training@bastion:~$ kubectl get no worker-0.wescale.internal -ojsonpath='{.status.capacity.pods}{"\n"}'
# There is a default limitation to 110 pods per node from a Kubernetes standpoint
```

* How many pods can we schedule on this node from a network point of view ?

```sh
training@bastion:~$ kubectl get no worker-0.wescale.internal -ojsonpath='{.spec.podCIDR}{"\n"}'
# 10.244.3.0/24 means that we have 256 IPs available, so 256 pods
```

### CNI configuration

In order to deploy pods on the cluster, a CNI plugin has been configured.

* By looking at the namespaces, can you guess which one ?

```sh
training@bastion:~$ kubectl get ns
# There is a namespace called calico-system so probably Calico
```

> Calico is deployed by the `Tigera Operator` which allows to configure one or multiple Calico instances through `Custom Resource Definition` objects.

* List available resources in your cluster with the `kubectl api-resources` command. Do you find resources related to Calico ?

```sh
training@bastion:~$ kubectl api-resources | grep calico
kubectl api-resources | grep calico
bgpconfigurations                                                                   crd.projectcalico.org/v1            false        BGPConfiguration
bgpfilters                                                                          crd.projectcalico.org/v1            false        BGPFilter
bgppeers                                                                            crd.projectcalico.org/v1            false        BGPPeer
blockaffinities                                                                     crd.projectcalico.org/v1            false        BlockAffinity
caliconodestatuses                                                                  crd.projectcalico.org/v1            false        CalicoNodeStatus
clusterinformations                                                                 crd.projectcalico.org/v1            false        ClusterInformation
felixconfigurations                                                                 crd.projectcalico.org/v1            false        FelixConfiguration
globalnetworkpolicies                                                               crd.projectcalico.org/v1            false        GlobalNetworkPolicy
globalnetworksets                                                                   crd.projectcalico.org/v1            false        GlobalNetworkSet
hostendpoints                                                                       crd.projectcalico.org/v1            false        HostEndpoint
ipamblocks                                                                          crd.projectcalico.org/v1            false        IPAMBlock
ipamconfigs                                                                         crd.projectcalico.org/v1            false        IPAMConfig
...
```

* Retrieve existing `IPAMBlock` objects and try to guess what they are used for

```sh
training@bastion:~$ kubectl get ipamblock
# There is one IPAMBlock resource per node
# It contains the current IP allocations for each node CIDR
```

> Most of CNI deployments are based on a DaemonSet to provision one pod managing the configuration on each node. This pod refers to a config map for its configuration.

* Here, what is the DaemonSet named ?

> The daemonset is named `calico-node` in the `calico-system` namespace

* What ConfigMap does it refer to in the `CNI_NETWORK_CONFIG` environment variable ?

```sh
training@bastion:~$ kubectl describe ds -n calico-system calico-node | grep CNI_NETWORK_CONFIG
      CNI_NETWORK_CONFIG:       <set to the key 'config' of config map 'cni-config'>  Optional: false
# It refers to the "cni-config" ConfigMap
```

* Look at the ConfigMap content. Where are the CNI logs located ?

```sh
training@bastion:~$ kubectl describe cm cni-config -n calico-system
# In the /var/log/calico/cni/cni.log file that is mounted on the host
```

> As seen, Calico is able to integrate or not overlays (IPinIP or VxLAN).

* Retrieve existing `IPPool` objects and guess if there is an overlay network configured

```sh
training@bastion:~$ kubectl get ippool -o yaml
...
  spec:
    allowedUses:
    - Workload
    - Tunnel
    blockSize: 26
    cidr: 10.244.0.0/16
    ipipMode: Never # IPinIP not configured
    natOutgoing: true
    nodeSelector: all()
    vxlanMode: CrossSubnet # But VXLAN is configured
...
```
