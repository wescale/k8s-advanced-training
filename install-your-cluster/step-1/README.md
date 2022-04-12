# Install your k8s cluster

In this exercise, you will deploy a cluster on Google Compute Engine Virtual Machines.
Each of you has 7 Virtual machines:
* a bastion accessible using the provided SSH private key and ssh_config file
* 3 VMs for the control plane
* 3 VMs for the data plane

In addition of the VMs, the trainer must give you a `provided_ssh_config` file and a number of environment `training-X`

## Deploy with RKE (10 minutes)

You will use (Rancher Kubernetes Engine - RKE)[https://rancher.com/docs/rke/latest/en/].

RKE is already installed on the bastion.

To connect on the bastion instance, download the [private SSH key](https://raw.githubusercontent.com/WeScale/k8s-advanced-training/master/resources/kubernetes-formation) start an ssh agent to add the key and connect to the instance:
```sh
chmod 400 kubernetes-formation
eval "$(ssh-agent -s)"
ssh-add kubernetes-formation
# Ensure the key is present
ssh-add -L 
# SSH
ssh -A -F provided_ssh_config bastion
cd creds
# you should see a cluster.yml file
ls -lath
```

Once connected to the bastion instance, use the provided `cluster.yml` file.
Look at this file. In particular the `nodes` section.

Now, you can build your cluster:
```sh
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
```

## Labels your domain of failure / topology key

Each node (control plane or data plane) is deployed in a given zone of the Google Cloud Platform.

This information of 'domain of failure' will be used later to manage affinity and anti-affinity.

With kubectl, describe the nodes and look for this information.

* Can you find it?
* What do you suggest to correct that?
* Add a label `topology.kubernetes.io/zone` onto each worker node. Each with a value `a`, `b` or `c`.
