## IngressController

Inside the `kube-system` namespace, look at the resources related to `ingress-nginx`.

Examine the DaemonSet to answer the following questions:

* Where are the nginx pods running?
* How is that achieved?
* What are the ports they exposed?

Ask your trainer to indicate the public DNS record for the `lb` and try to connect to the exposed Nginx.

## StorageClass and provisioner

What are the current StorageClasses?

You will create a new StorageClass with (Rancher Local path provisioner)[https://github.com/rancher/local-path-provisioner].

Local Path Provisioner provides a way for the Kubernetes users to utilize the local storage in each node. Based on the user configuration, the Local Path Provisioner will create hostPath based persistent volume on the node automatically. It utilizes the features introduced by Kubernetes Local Persistent Volume feature, but make it a simpler solution than the built-in local volume feature in Kubernetes.

```sh
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
# Then mark the StorageClass as the default
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Inspect the config maps of the related namespace, to determine where this StorageClass will create the persistent volumes.

You can connect to the kubernetes nodes `ssh -F provided_ssh_config worker-0` to see their file system and mount points.

Questions:
* What happens if the node is lost?
* What could you suggest to optimize this?

## Capacity of the cluster

Connect to a master node to view the `cidrs` of the cluster:

```sh
ssh -F provided_ssh_config master-0
sudo su
ps -ef|grep kube-controller
```

## Networking

On a master, inspect the `/etc/rancher/rke2/config.yaml` file to determine the network plugin used by the cluster.

Generally, a network plugin comes with Custom Resource Definition - CRDs to provide interactions for specific features. Those CRDs are additional Kubernetes objects.

To list the available resources on a cluster: `kubectl api-resources`. Do you retrieve something for Calico?

### Overlay network

Most of CNI deployments are based on a daemon set to get a pod managing the configuration on each node. This pod refers to a config map for its configuration.

Here, what is the daemonset? What is the config map?

As seen, Calico is able to integrate or not overlays (IPinIP or VxLAN).

Look at the config map used for the CNI daemonset. Is there an ovelay network?
