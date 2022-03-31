
# Install ECK

```sh
kubectl create -f https://download.elastic.co/downloads/eck/2.1.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.1.0/operator.yaml
```

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

# Wait it green
kubectl get elasticsearch
# Retrieve PASSWORD
PASSWORD=$(kubectl get secret quickstart-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')
# Port forward
kubectl port-forward service/quickstart-es-http 9200
# Curl
curl -u "elastic:$PASSWORD" -k "https://localhost:9200"
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
# Check
kubectl get kibana
# Port Forward
kubectl port-forward service/quickstart-kb-http 5601
# Browser
"https://localhost:5601"
```

```sh
# RBAC for Filebeat to add k8S metadata
cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: filebeat
rules:
- apiGroups: [""] # "" indicates the core API group
  resources:
  - namespaces
  - pods
  - nodes
  verbs:
  - get
  - watch
  - list
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: filebeat
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: filebeat
subjects:
- kind: ServiceAccount
  name: filebeat
  namespace: default
roleRef:
  kind: ClusterRole
  name: filebeat
  apiGroup: rbac.authorization.k8s.io
---
EOF

# Deploy Filrbeat to collect pod logs
cat <<EOF | kubectl apply -f -
apiVersion: beat.k8s.elastic.co/v1beta1
kind: Beat
metadata:
  name: quickstart
spec:
  type: filebeat
  version: 8.1.1
  elasticsearchRef:
    name: quickstart
  kibanaRef:
    name: quickstart
  config:
    processors:
    - add_cloud_metadata: {}
    - add_host_metadata: {}
    - add_kubernetes_metadata:
        default_indexers.enabled: true
        default_matchers.enabled: true
        indexers:
          - pod_uid:
    filebeat.inputs:
    - type: container
      paths:
      - /var/log/containers/*.log
  daemonSet:
    podTemplate:
      spec:
        serviceAccountName: filebeat
        automountServiceAccountToken: true
        dnsPolicy: ClusterFirstWithHostNet
        hostNetwork: true
        securityContext:
          runAsUser: 0
        containers:
        - name: filebeat
          volumeMounts:
          - name: varlogcontainers
            mountPath: /var/log/containers
          - name: varlogpods
            mountPath: /var/log/pods
          - name: varlibdockercontainers
            mountPath: /var/lib/docker/containers
        volumes:
        - name: varlogcontainers
          hostPath:
            path: /var/log/containers
        - name: varlogpods
          hostPath:
            path: /var/log/pods
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
EOF
```


# Deploy File beats for logs => KO
kubectl apply -f https://raw.githubusercontent.com/elastic/cloud-on-k8s/2.1/config/recipes/beats/filebeat_autodiscover.yaml

# ES / Kibana / Stack monitoring
kubectl apply -f https://raw.githubusercontent.com/elastic/cloud-on-k8s/2.1/config/recipes/beats/stack_monitoring.yaml

# For systemd logs
kubectl apply -f https://raw.githubusercontent.com/elastic/cloud-on-k8s/2.1/config/recipes/beats/journalbeat_hosts.yaml
```

# Deploy an ElasticSearch cluster

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
```

# Then BEAT to collect kubernetes node logs agents

https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-beat-quickstart.html

## All in one 
kubectl apply -f https://raw.githubusercontent.com/elastic/cloud-on-k8s/2.1/config/recipes/beats/stack_monitoring.yaml