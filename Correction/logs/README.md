# Logs with Elastic Cloud on Kubernetes - ECK

After installing a wordpress application, you deploy install [Elastic Cloud on Kubernetes](https://www.elastic.co/guide/en/cloud-on-k8s/master/k8s-overview.html), an operator for the Elastic Search stack.

Using the CRDs, you will deploy a complete logging stack based on ElasticSearch, Kibana and Logs senders (Beats).

## Install Wordpress app

```sh
kubectl create ns wordpress
kubectl create secret generic mysql-pass -n wordpress --from-file=password.txt
kubectl apply -f mysql-deployment.yaml
kubectl apply -f wordpress-deployment.yaml
```

Check all the pods and resources are OK:

```sh
kubectl get deployment,pod,svc,endpoints,pvc -l app=wordpress -o wide -n wordpress && \
kubectl get secret mysql-pass -n wordpress && \
kubectl get pv -n wordpress
```

## Install ECK

You will install a cluster wide ECK with an Helm chart:

```sh
helm repo add elastic https://helm.elastic.co
helm repo update
helm install elastic-operator elastic/eck-operator -n elastic-system --create-namespace
```

---

NOTE: you can install ECK in a [more restricted way](https://www.elastic.co/guide/en/cloud-on-k8s/master/k8s-install-helm.html#k8s-install-helm-restricted)

See the CRDs that have been created:

```sh
kubectl api-resources|grep elastic
```

In particular, note the `ElasticSearch`, `Kibana` and `Beat` that will automate the deployment of the well known related components.

## Create an ElasticSearch instance

Deploy an ElasticSearch instance for demo (single node, no virtual memory):

```sh
kubectl create ns logs
cat <<EOF | kubectl apply -n logs -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: quickstart
spec:
  version: 8.6.2
  nodeSets:
  - name: default
    count: 1
    config:
      # https://www.elastic.co/guide/en/cloud-on-k8s/master/k8s-virtual-memory.html
      node.store.allow_mmap: false
```

Wait the instance becomes (unknown -> green):

```sh
kubectl get elasticsearch -n logs -w
```

Retrieve the password: `export PASSWORD=$(kubectl get secret quickstart-es-elastic-user -n logs -o go-template='{{.data.elastic | base64decode}}')`

## Create a Kibana

```sh
# Deploy Kibana
cat <<EOF | kubectl apply -n logs -f -
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: quickstart
spec:
  version: 8.6.2
  count: 1
  elasticsearchRef:
    name: quickstart
EOF
# Wait that the health becomes green (red -> green)
kubectl get kibana -n logs -w
# Port Forward
kubectl port-forward service/quickstart-kb-http  -n logs 5601 &
```

Now, you can open a browser on <https://bastion.k8s-ops-X.wescaletraining.fr:5601/login?next=%2F> (replace X with your cluster number) and enter the "elastic / ${PASSWORD}" credentials.

Click 'Explore on my own'... but as you can see, there is no data because no sender is configured.

## Deploy a Filebeat

In the ElasticSearch world, the senders are `Beats`.

Several [`Beat`](https://www.elastic.co/beats/) exist: file, audit, journal, heartbeat, ...

Here, we want to collect container and pods logs from files on the nodes.

We use a `processor` to enrich the log metadata with some kubernetes information.
For that, the Filebeat we want to deploy needs a service account with non default privileges.

Create specific Service account, cluster role and cluster role bindig:

```sh
# RBAC for Filebeat to add k8S metadata
kubectl apply -f es/filebeat-rbac.yaml
```

Look at the [Filebeat definition](es/filebeat.yaml).

Then create it:

```sh
kubectl apply -f es/filebeat.yaml -n logs
# Ensure the create beat becomes green. If not, inspect pod logs
kubectl get beat -n logs
```

## Test the log aggregation

Generate some traffic on the wordpress application.

Go to [https://bastion.k8s-ops-X.wescaletraining.fr:5601/app/discover#/](https://bastion.k8s-ops-X.wescaletraining.fr:5601/app/discover#/?_g=(filters:!(),refreshInterval:(pause:!t,value:0),time:(from:now-15m,to:now))&_a=(columns:!(),filters:!(),index:'filebeat-*',interval:auto,query:(language:kuery,query:'kubernetes.namespace%20:%20wordpress'),sort:!(!('@timestamp',desc)))) and filter on `kubernetes.namespace : wordpress`, you should see logs within 5 minutes.

Select a log record and expand it by clicking on the double array.

You can retrieve interesting information thanks to the metadata enrichment:

* Data collected by the Beat agent: `cloud.machine.type`, `cloud.project.id`, `container.image.name`, ...
* Data collected from Kubernetes API server: `kubernetes.labels`, `kubernetes.pod.name`, ...

And finally, the `message` which is the original log message.

## Collect logs from the masters

We want logs from the masters!

You have probably noticed the Filbeat pods are only on the workers.

Yet, they are deployed by a daemonset...

Modify the Filebeat definition to deploy pods also on the master nodes.

Once updated, ensure you see 6 available / expected pods for `kubectl get beat -n logs`.

**`kubectl apply -f es/filebeat-solution.yaml -n log`**

Wait few minutes, and should see log entries for the query `agent.hostname: master-*`

### Clean

```sh
kubectl delete ns wordpress
kubectl delete ns logs
helm uninstall elastic-operator -n elastic-system
kubectl delete ns elastic-system

for CRD in $(kubectl get crds --no-headers -o custom-columns=NAME:.metadata.name | grep k8s.elastic.co); do
    kubectl delete crd "$CRD"
done
```
