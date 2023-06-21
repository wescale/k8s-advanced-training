# Install your k8s cluster

In this exercise, you will deploy a cluster on Google Compute Engine Virtual Machines.
Each of you has 7 Virtual machines:
* a bastion accessible using the provided SSH private key and ssh_config file
* 3 VMs for the control plane
* 3 VMs for the data plane

In addition of the VMs, the trainer must give you a `provided_ssh_config` file and a number of environment `training-X`

## Deploy with RKE2 (10 minutes)

You will use [Rancher Kubernetes Engine - RKE 2](https://docs.rke2.io/).

### Control plane

At this stage, you get a cluster with the control plane initialized with RKE2, but the cluster has no worker.

Ensure the control plane is OK by connecting to the bastion instance.

For that, download the [private SSH key](https://raw.githubusercontent.com/WeScale/k8s-advanced-training/master/resources/kubernetes-formation) on you personal laptop and start an ssh agent to add the key and connect to the instance:

```sh
chmod 400 kubernetes-formation
eval "$(ssh-agent -s)"
ssh-add kubernetes-formation
# Ensure the key is present
ssh-add -L 
# SSH
ssh -A -F provided_ssh_config bastion
# Ensure you see 3 master nodes
kubectl get nodes
```

You will add 3 worker nodes (aka data agent nodes) in the RKE2 terminology.

For that, you will configure and start rke2-agent service on `worker-0`, `worker-1` and `worker-2` nodes. To join an existing cluster, you need to pass the `token` generated during the bootstrap of the control plane, and indicate the cluster registration endpoint. The RKE2 binary is already installed on the workers.

```sh
# Connect to the worker
ssh -F provided_ssh_config worker-0
# See the content of the RKE2 configuration file
cat ~/rke2-config.yaml
# server: https://PUBLIC_K8S_API:9345
# token: XXXXX
#
# Copy the RKE2 config file to the default location
sudo mkdir -p /etc/rancher/rke2
sudo cp /home/training/rke2-config.yaml /etc/rancher/rke2/config.yaml
# Enable RKE2 agent on startup
sudo systemctl enable rke2-agent.service
# Start RKE2 agent service. This can take few minutes
sudo systemctl start rke2-agent.service
# Go back to the bastion instance
exit
```

After few minutes, the worker nodes must be visible as `ready` members of the cluster:

```sh
# Ensure you see 6 nodes whose 3 workers
kubectl get nodes
```

To finish this step, copy the kubeconfig file to the bastion instance:

```sh
mkdir -p ~/.kube
# test your cluster
kubectl cluster-info
```

## Labels your domain of failure / topology key

Each node (control plane or data plane) is deployed in a given zone of the Google Cloud Platform.

This information of 'domain of failure' will be used later to manage affinity and anti-affinity.

With kubectl, describe the nodes and look for this information.

* Can you find it?
* What do you suggest to correct that?
* Add a label `topology.kubernetes.io/zone` onto each worker node. Each with a value `a`, `b` or `c`.
