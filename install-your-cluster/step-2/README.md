## IngressController

Look at the resources deployed on the `ingress-nginx` namespace.

Examine the DaemonSet to answer the following questions:
* Where are the nginx pods running?
* How is that achieved?
* What are the ports they exposed?

Ask your trainer to indicate the public DNS record for the workers and try to connect to the exposed Nginx.

## StorageClass and provisioner

What are the current StorageClasses?

You will create a new StorageClass with (Rancher Local path provisioner)[https://github.com/rancher/local-path-provisioner].

```sh
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Then mark the StorageClass as default
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Inspect the config maps of the related namespace, to determine where this StorageClass will create the persistent volumes.

You can connect to the kubernetes nodes `ssh -F provided_ssh_config worker-0` to see their file system and mount points.

Questions:
* What happens if the node is lost?
* What could you suggest to optimize this?

## Capacity of the cluster

Connect to a master node to view the `cidrs`of the cluster:
```sh
ssh -F provided_ssh_config master-0
sudo su
ps -ef|grep kube-controller
```

* What is the max number of Pods created by this cluster?
* What is the max number of Services created by this cluster?

## Networking

Inspect the `cluster.yaml` file to determine the network plugin used by the cluster.

Generally, netwok plugin are configured using Custom Resource Definition - CRDs. Those CRDs are additional Kubernetes objects. 
To list the available resources on a cluster: `kubectl api-resources`

### Overlay network. 

As seen, Calico is able to integrate or not overlays (IpInIP or VxLAN). 

In the `kube-system` namespace, look at the `ippools` and `configmap/calico-config` objects. 

* Is there an ovelay network?
* Is BGP (BIRD) used?
