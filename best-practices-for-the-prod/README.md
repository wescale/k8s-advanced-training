
In this exercise, you will explore different aspects 

# who-can

Who-can is an interesting tool to view your RBAC configuration.

This tool is packaged as a kubectl plugin available with [krew](https://github.com/kubernetes-sigs/krew).

Once who-can plugin is installed, run commands to determine:
* who can create/delete/update deployment in the kube-system namespace?
* who can create ClusterRoles?
* who can get Secrets?

# OpenPolicyAgent

In this exercise, you will write a policy to ensure no container reference the tag `latest`of an image.
This is very bad habit.

## Install OPA

You will install OpenPolicyAgent with Gatekeeper.


The doc is [here](https://open-policy-agent.github.io/gatekeeper/website/docs/install/)

## Create your first policy

Write your own policy to ensure a pod does not have the `latest` tag.
You can consult this [page](https://www.magalix.com/blog/enforce-that-all-kubernetes-container-images-must-have-a-label-that-is-not-latest-using-opa)


Then, push the policy via a Gatekeeper CRD.

An example is [here](https://github.com/open-policy-agent/gatekeeper/blob/master/example/templates/k8srequiredlabels_template.yaml)


Is your policy working?

Have you tested with a deployment resource? 

A daemonSet? A replicaSet?
