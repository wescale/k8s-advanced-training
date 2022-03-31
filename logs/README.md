
# Install ECK - [Elastic Cloud on Kubernetes](https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html)


```sh
kubectl create -f https://download.elastic.co/downloads/eck/2.1.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.1.0/operator.yaml
```

## Create elasticsearch and kibana

```sh
cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: quickstart
spec:
  version: 8.1.1
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false
EOF

# Wait it becomes green
kubectl get elasticsearch
# Retrieve PASSWORD
export PASSWORD=$(kubectl get secret quickstart-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')
```

```sh
# Deploy Kibana
cat <<EOF | kubectl apply -f -
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: quickstart
spec:
  version: 8.1.1
  count: 1
  elasticsearchRef:
    name: quickstart
EOF
# Wait it becomes green
kubectl get kibana
# Port Forward
kubectl port-forward service/quickstart-kb-http 5601
```

Now, you can open a browser on https://localhost:5601 and enter the "elastic / ${PASSWORD}" credentials.

## Deploy Filebeat

Several `beat` exist: file, audit, journal, heartbeat.

Here, we want to collect container and pods logs from files on the nodes.
We use a `processor` to enrich the log metadata with some kubernetes information.
For that, the Filebeat we want to deploy needs a service account with non default priviledges.

```sh
# RBAC for Filebeat to add k8S metadata
kubectl apply -f filebeat-rbac.yaml
# YAML for Filebeat
kubectl apply -f filebeat.yaml
# Ensure the create beat becomes green. If not, inspect pod logs
kubectl get beat
```

Then you should logs on Kibana. Go to `Discover`.

## Bonus

You may have notice Filbeat pods are only on the workers.
We want logs from the masters!

1. Modify the Filebeat definition to deploy pods also on the master nodes.
2. Modify the Filebeat definition to collect the audit logs for the API server. Path is `/var/log/kube-audit/audit-log.json`
