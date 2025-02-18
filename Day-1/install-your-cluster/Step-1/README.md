# Install your k8s cluster

In this exercise, you will deploy a cluster on Google Compute Engine Virtual Machines.
Each of you has 7 Virtual machines:

* 1 bastion accessible using the provided SSH private key and ssh_config file
* 3 VMs for the control plane
* 3 VMs for the data plane

In addition of the VMs, the trainer must provide you several files that will help you during the entire course.

## Manage your cluster with Kubeadm (10 minutes)

You will use the [Kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/) to manage your Kubernetes cluster.

### Control plane

At this stage, you get a cluster with the control plane initialized with Kubeadm, but the cluster has no worker.

Ensure the control plane is OK by connecting to the bastion instance.

For that, use the private ssh key provided by your instructor and start an ssh agent to add the key and connect to the instance:

```sh
localhost:~$ chmod 400 kubernetes-formation
localhost:~$ eval "$(ssh-agent -s)"
localhost:~$ ssh-add kubernetes-formation
# Ensure the key is present
localhost:~$ ssh-add -L
# SSH
localhost:~$ ssh -A -F provided_ssh_config bastion
# Ensure you see 3 master nodes and memorize their version
training@bastion:~$ kubectl get nodes
```

You will now add 3 worker nodes to your cluster to host workloads for the rest of the training course.

For that, you will install the kubelet and containerd services on `worker-0`, `worker-1` and `worker-2` nodes. After this, you will join the existing cluster using a command generated from the `master-0` node.

```sh
# Connect to the worker
training@bastion:~$ ssh -F provided_ssh_config worker-0

# Check if the kubelet service is installed
training@worker-0:~$ kubelet --version
# Check if it is running
training@worker-0:~$ systemctl status kubelet
# It seems like it is not, start it ! Make sure it also persists across reboots
training@worker-0:~$ systemctl start kubelet
training@worker-0:~$ systemctl enable kubelet
# Check if it is running now
training@worker-0:~$ systemctl status kubelet
# Go back to the bastion instance
training@worker-0:~$ exit

# Connect to the master-0 node and generate a token to join the cluster
training@bastion:~$ ssh -F provided_ssh_config master-0
training@master-0:~$ kubeadm token create --print-join-command

# Copy the command output and run it on worker-0 with privileged rights
training@bastion:~$ ssh -F provided_ssh_config worker-0
training@worker-0:~$ sudo kubeadm join ..

# Go back to the bastion instance and check that the worker-0 joined the cluster
# It should also have the "Ready" status
training@worker-0:~$ exit
training@bastion:~$ kubectl get nodes
```

**Now repeat the actions above for both `worker-1` and `worker-2` nodes to have 6 nodes in total.**

```sh
# Ensure you see 6 nodes in total with 3 masters and 3 workers
training@bastion:~$ kubectl get nodes
```

## Labels your domain of failure / topology key

Each node (control plane or data plane) is deployed in a given zone of the Google Cloud Platform.

This information of 'domain of failure' will be used later to manage affinity and anti-affinity.

With kubectl, describe the nodes and look for this information.

* Can you find it?
* What do you suggest to correct that?
* Add a label `topology.kubernetes.io/zone` onto each worker node. Each with a value `a`, `b` or `c`.
