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
* How is that achieved?
* What are the ports they expose?

Try to connect to the exposed Nginx using the load balancer DNS record for your cluster: `lb.k8s-ops-X.wescaletraining.fr`.

## Persistent storage

Now, you will look at what is configured for persistent storage.

* What are the current StorageClasses?

You will now create a new StorageClass with (Rancher Local path provisioner)[https://github.com/rancher/local-path-provisioner].

`Local Path Provisioner` provides a way for the Kubernetes users to utilize the local storage in each node. Based on the user configuration, the `Local Path Provisioner` will create `hostPath` based persistent volumes on the node automatically.

* Install the storage class:

```sh
training@bastion:~$ kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
# Then mark the StorageClass as the default
training@bastion:~$ kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

* Inspect the config maps of the related namespace, to determine where this StorageClass will create the persistent volumes.

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
* What could you suggest to optimize this?

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
* Are the pods in your cluster in the range you found ? If not, why ?

Now describe a worker node using the `kubectl` command and try to find:

* How many pods can we schedule on this node from a Kubernetes perspective ?
* How many pods can we schedule on this node from a network point of view ?

### CNI configuration

In order to deploy pods on the cluster, a CNI plugin has been configured.

* By looking at the namespaces, can you guess which one ?

> Calico is deployed by the `Tigera Operator` which allows to configure one or multiple Calico instances through `Custom Resource Definition` objects.

* List available resources in your cluster with the `kubectl api-resources` command. Do you find resources related to Calico ?

* Retrieve existing `IPAMBlock` objects and try to guess what they are used for

> Most of CNI deployments are based on a DaemonSet to provision one pod managing the configuration on each node. This pod refers to a config map for its configuration.

* Here, what is the DaemonSet named ?
* What ConfigMap does it refer to in the `CNI_NETWORK_CONFIG` environment variable ?
* Look at the ConfigMap content. Where are the CNI logs located ?

> As seen, Calico is able to integrate or not overlays (IPinIP or VxLAN).

* Retrieve existing `IPPool` objects and guess if there is an overlay network configured
