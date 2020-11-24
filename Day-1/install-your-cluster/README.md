# Install your k8s cluster

In this exercise, you will deploy a cluster on Google Compute Engine Virtual Machines.
Each of you has 6 Virtual machines:
* a bastion accessible using the provided SSH private key and ssh_config file
* 3 VMs for the control plane
* 2 VMs for the data plane

You will use (Rancher Kubernetes Engine - RKE)[https://rancher.com/docs/rke/latest/en/].

## Deploy with RKE (10 minutes)

RKE is already installed on the bastion.

To connect on the bastion instance, download the [private SSH key](https://raw.githubusercontent.com/WeScale/k8s-advanced-training/master/resources/kubernetes-formation) start an ssh agent, then ssh to it:
```sh
`eval "$(ssh-agent -s)"`
ssh-add kubernetes-formation
# Ensure the key is present
ssh-add -L 
# SSH
ssh -F provided_ssh_config bastion-training-X
```

Once connected, to the bastion instance, use the provided cluster.yml file.
Look at this file. In particular the `nodes` section.

Now, you can build your cluster:
```sh
rke up
```

This takes about 5 minutes.
At the end, a kubeconfig has been generated.

Copy-it to the default location for kubectl:
```sh
mkdir -p ~/.kube
cp kube_config_cluster.yml ~/.kube/config
# test your cluster
kubectl cluster-info
```

## Rotate the certificates

Kubernetes involves a lot of certificates, which must be rotated in the case of a comprimised cert or just because they will soon expire.

RKE provides useful commands to rotate certificates.

```sh
rke cert rotate
```

## IngressController

Look at the resoucres deployed on the `ingress-nginx` namespace.

Examine the DaemonSet to answer the following questions:
* Where are the nginx pods running?
* How is that achieved?
* What are the ports they exposed?

Try to connect to the exposed Nginx.

For that, you have a DNS record: `lb.wsc-kubernetes-training-X.wescaletraining.fr`

## StorageClass and provisionenr

What are the current StorageClasses?

You will create a new StorageClass with (Rancher Local path provisioner)[https://github.com/rancher/local-path-provisioner].

```sh
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Then mark the StorageClass as default
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Inspect the config maps of the related namespace, to determine where this StorageClass will create the persistent volumes.

You can connect to the kubernetes nodes `ssh -F provided_ssh_config worker-0-training-X` to see their file system and mount points.

Questions:
* What happens if the node is lost?
* What could you suggest to optimize this?

## Activate the audit logs

Activating the audit logs of the api server is the only way to know who or what pod as perform operations like *delete* on a cluster.

For, that you have an example of configuration for RKE in `audit.yml`. Look at this file, in particular the `rules`.

* Append the `audit.yml` to your `cluster.yml`
* Run `rke up` to update the cluster.

Now, you can see relevant actions in `/var/log/kube-audit/audit-log.json` of control plane nodes.

Perform a test:
```sh
# Create a pod
kubectl run pod-with-special-name --image=gcr.io/google-samples/hello-app:1.0 --port=8080
# Then delete it
kubectl delete pod pod-with-special-name
```

Now connect to any master node and look for the delete operation.

## Update Strategy

Any cluster will need to be updated at a moment.
Different possibilities will be discussed later but in the case of an update of an existing cluster, the strategy must be carefully thought.

Look at the `update_strategy` section of the current `cluster.yml` file.
A parameter is not acceptable for the production.

Which one?

## Test backup and restore of etcd

Backups of ETCD are a good starting point to recover from a disaster.

RKE can configure automatic backups of etcd and send them to S3:
```
services:
  etcd:
    backup_config:
      interval_hours: 1
      retention: 6
      s3backupconfig:
        access_key: S3_ACCESS_KEY
        secret_key: S3_SECRET_KEY
        bucket_name: s3-bucket-name
        region: ""
        folder: ""
        endpoint: s3.amazonaws.com
        custom_ca: |-
          -----BEGIN CERTIFICATE-----
          $CERTIFICATE
          -----END CERTIFICATE----

```

Here, we propose to explore backup/restore features. You will put the cluster in a specific state, then do a one-time snapshot and inspect the state after a restore operation:

```sh
# run specific pods
kubectl run important-pod --image=gcr.io/google-samples/hello-app:1.0 --port=8080
# do snapshot
rke etcd snapshot-save --name test-snapshot
# change the cluster state
kubectl delete pod important-pod
# do restore
rke etcd snapshot-restore --name test-snapshot
# ensure the important-pod is running
kubectl describe pod important-pod
```


## Labels your domain of failure / topology key

Each node (control plane or data plane) is deployed in a given zone of the Google Cloud Platform.

This information of 'domain of failure' can be used later to manage affinity and anti-affinity.

With kubectl, describe the nodes and look for this information.
Can you find it?

What do you suggest to correct that?

## Capacity of the cluster

Connect to a master node to view the `cidrs`of the cluster:
```sh
ssh -F provided_ssh_config master-0-training-X
sudo su
ps -ef|grep kube-controller
```

* What is the max number of Pods created by this cluster?
* What is the max number of Services created by this cluster?
