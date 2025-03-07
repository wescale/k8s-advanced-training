# Logs with Elastic Cloud on Kubernetes - ECK

In this exercise, we will see how to deploy a logging stack and how to configure it to collect logs from a Kubernetes cluster.

To demonstrate that, you will install the ElasticStack through the [ECK operator](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-overview.html).

## Install ECK operator

- Install the ECK operator using the associated Helm chart

```sh
training@bastion:~$ helm repo add elastic https://helm.elastic.co
training@bastion:~$ helm install elastic-operator elastic/eck-operator -n elastic-system --create-namespace
```

- Look at the CRDs that have been created

```sh
training@bastion:~$ kubectl api-resources | grep elastic
```

In particular, note the `ElasticSearch`, `Kibana` and `Beat` that will automate the deployment of the well known related components.

## Create an ElasticSearch instance

- Deploy an ElasticSearch instance in a new `logging` namespace

```sh
training@bastion:~$ kubectl create ns logging
training@bastion:~$ cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: elasticsearch
  namespace: logging
spec:
  version: 8.17.3
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false
EOF
```

- Wait until the ES instance becomes green:

```sh
training@bastion:~$ watch kubectl get elasticsearch -n logging
```

- Retrieve user credentials in the `elasticsearch-es-elastic-user` secret

```sh
training@bastion:~$ kubectl get secret elasticsearch-es-elastic-user -n logging -o json | jq -r '.data.elastic' | base64 -d
```

## Deploy the Kibana interface

```sh
training@bastion:~$ kubectl apply -f kibana.yaml -n logging

# Wait until Kibana status becomes green
training@bastion:~$ watch kubectl get kibana kibana -n logging
```

- Now you can open a browser on the `kibana.k8s-ops-X.wescaletraining.fr` address and authenticate using the credentials you retrieved earlier. Click **Explore on my own**... but as you can see, there is no data because we have not deployed a log collector yet.

## Deploy a Filebeat log collector

In the ElasticSearch world, the senders are `Beats`.

There are different types of [`Beats`](https://www.elastic.co/beats/) (file, audit, journal, heartbeat, ...etc) each having its own purpose.

Here, we want to collect container and pods logs from files on the nodes.

We use a `processor` to enrich the log metadata with some kubernetes information.
For that, the filebeat we want to deploy needs a service account with non default privileges.

- Create a ServiceAccount for filebeat and give it cluster-scoped permissions:

```sh
training@bastion:~$ kubectl apply -f filebeat-rbac.yaml
```

- Inspect the [filebeat definition](filebeat.yaml) and deploy it in the `logging` namespace

```sh
training@bastion:~$ kubectl apply -f filebeat.yaml -n logging
```

- Wait until filebeat status becomes green and inspect its logs

```sh
training@bastion:~$ watch kubectl get beat filebeat -n logging
```

## Test logs collection

Now we are going to test our setup to see if we can explore our logs on Kibana.

- First, generate some traffic on the admin UI.

- Then go to [https://kibana.k8s-ops-X.wescaletraining.fr/app/discover](https://kibana.k8s-ops-X.wescaletraining.fr/app/discover) and filter on `kubernetes.namespace: application`, you should see logs within 5 minutes.

- Select a log record and expand it by clicking on the double array.

You can retrieve interesting information thanks to the metadata enrichment:

- Data collected by the Beat agent: `cloud.machine.type`, `cloud.project.id`, `container.image.name`, ...
- Data collected from Kubernetes API server: `kubernetes.labels`, `kubernetes.pod.name`, ...

And finally, the `message` which is the original log message.

## Collect logs from the masters

As you probably noticed, the filebeat pods are only scheduled on the workers for now. This means that we are not collecting logs from the controlplane which is not good !

- Inspect the current pods to see what kind of resource owns them

- Modify the filebeat definition to allow pods to be deployed on the master nodes

```sh
training@bastion:~$ kubectl apply -f filebeat-with-masters.yaml -n logging
```

- Once updated, ensure you see 6 filebeat pods

- Wait few minutes, and should see log entries on Kibana for the query `agent.hostname: master-*`
