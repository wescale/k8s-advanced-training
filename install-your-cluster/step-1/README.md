# Install your k8s cluster

In this exercise, you will deploy a cluster on Google Compute Engine Virtual Machines.
Each of you has 7 Virtual machines:
* a bastion accessible using the provided SSH private key and ssh_config file
* 3 VMs for the control plane
* 3 VMs for the data plane

## Deploy with RKE (10 minutes)

You will use [Rancher Kubernetes Engine - RKE](https://rancher.com/docs/rke/latest/en/).

RKE is already installed on the bastion.

To connect on the bastion instance, use the following command (you must authorize gcloud to use the Google Identity):
```sh
gcloud compute ssh training@bastion-0 --zone=europe-west1-b
```

Once connected to the bastion instance, load the cluster private key in the ssh agent (RKE needs this to connect to each VM):
```sh
wget https://raw.githubusercontent.com/WeScale/k8s-advanced-training/master/resources/kubernetes-formation
chmod 600 kubernetes-formation
ssh-add kubernetes-formation
# Ensure the key is present
ssh-add -L 
```

RKE will use the provided `creds/cluster.yml` file.
Look at this file, in particular the `nodes` section.

Now, you can build your cluster:
```sh
cd creds
rke up
```

This takes about 5 minutes.
At the end, a kubeconfig has been generated.

Copy it to the default location for kubectl:
```sh
mkdir -p ~/.kube
cp kube_config_cluster.yml ~/.kube/config
# test your cluster
kubectl cluster-info
# enable kubectl completion
echo 'source <(kubectl completion bash)' >>~/.bashrc
source <(kubectl completion bash)
```

## Labels your domain of failure / topology key

Each node (control plane or data plane) is deployed in a given zone of the Google Cloud Platform.

This information of 'domain of failure' will be used later to manage affinity and anti-affinity.

With kubectl, describe the nodes and look for this information.

* Can you find it?
* What do you suggest to correct that?
* Add a label `topology.kubernetes.io/zone` onto each worker node. Each with a value `a`, `b` or `c`.
