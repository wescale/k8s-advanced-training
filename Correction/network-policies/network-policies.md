# Preparation 

To deploy wordpress in application namespace:

start ./tf-runner.sh prepare_network_policies

# Step 1 - Deny all traffic

```yaml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ing
  namespace: application
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ing
  namespace: kube-system
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: controller
      app.kubernetes.io/instance: rke2-ingress-nginx
      app.kubernetes.io/name: rke2-ingress-nginx
  policyTypes:
  - Ingress
```

# Step 2 - Allow traffic to the proxy

```sh
# retrieve labels of nginx ingress controller pod
kubectl get pods -n ingress-nginx -o=jsonpath='{.items[*].metadata.labels}'|jq ''
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: internet-to-proxy
  namespace: kube-system
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: controller
      app.kubernetes.io/instance: rke2-ingress-nginx
      app.kubernetes.io/name: rke2-ingress-nginx
  policyTypes:
  - Ingress
  ingress:
  - from:
    - ipBlock:
        cidr: 0.0.0.0/0
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
```

# Step 3 - Allow traffic to the database

Traffic between the **wordpress** pods and the database is blocked.
As a result, the **wordpress** pods fail to pass the readiness probes.

```sh
# retrieve labels of the wordpress pods and mariadb
kubectl get pods -n application -o=jsonpath='{.items[*].metadata.labels}'|jq ''
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: wordpress-app-to-db
  namespace: application
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: wordpress
      app.kubernetes.io/managed-by: Helm
      app.kubernetes.io/name: mariadb
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/instance: wordpress
          app.kubernetes.io/managed-by: Helm
          app.kubernetes.io/name: wordpress
    ports:
    - protocol: TCP
      port: 3306
```

# Step 4 - Allow traffic to the web-application

```sh
# retrieve labels of the wordpress pods
kubectl get pods -n application -o=jsonpath='{.items[*].metadata.labels}'|jq ''
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: proxy-to-wordpress-app
  namespace: application
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: wordpress
      app.kubernetes.io/managed-by: Helm
      app.kubernetes.io/name: wordpress
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          app.kubernetes.io/component: controller
          app.kubernetes.io/instance: rke2-ingress-nginx
          app.kubernetes.io/name: rke2-ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 4443
```

# Clean

```sh
./tf-runner.sh clean_network_policies
```
