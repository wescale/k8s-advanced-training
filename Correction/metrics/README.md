# Metrics and alerting with kube-prometheus

You will install the [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) monitoring stack and experience how it works.

In a second time, you will deploy a wordpress application then monitor it with Prometheus and Grafana. To achieve that, you will

* monitor mysql:
  * add a `mysql-exporter`
  * create a ServiceMonitor
  * create a dashboard on Grafana to verify your PromQL
  * add a PrometheusRule to ensure you always have a mysql running.
* monitor the wordpress webapp
  * deploy a BlackBox infrastructure
  * add a BlackBoxExporter resources to telleto getXXX

## Install

Create a `monitoring` namespace

Install the kube-prometheus stack using Helm. Use the `/tmp/prometheus-chart-values.yml` values file for the instantiation

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f /tmp/prometheus-chart-values.yml
```

## kube-prometheus CRDs

See the installed CRDs running `kubectl api-resources --api-group=monitoring.coreos.com`.

Among those CRDs, a `Prometheus` kind is now available on the cluster. The Helm release you have installed has created a `Prometheus` resource named `kube-prometheus-stack-prometheus`.

Regarding this resource, answer the following questions:

* Is the resource highly available ? **`kubectl describe prometheus/kube-prometheus-stack-prometheus -n monitoring` -> No, 1 replicas**
* Are there selectors on the Probes, ServiceMonitors, PodMonitors and Rules ? **No. This is a special setup to allow current kube-prometheus-stack-prometheus to watch all Probes, ServiceMonitors, PodMonitors and Rules without labels or namespace filtering**

Using selectors allows to get several `Prometheus` instances each being isolated from others.

## Play with Prometheus

Check that you can access prometheus (replace the X by value of your assigned project): <http://prometheus.k8s-ops-X.wescaletraining.fr/>

Navigate through the UI and check what's in the **Targets** tab.

Can you explain what each section corresponds to ?

Go back to the **Graph** tab and enter the following query

```sh
up
```

Can you tell what the result means ?

### PromQL queries

1. Using the `kube_pod_info` metric, retrieve the information of the `prometheus-kube-prometheus-stack-prometheus-0` pod on the `monitoring` namespace (tip: you might have to use some filters to facilitate your search). You can use this [documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/) to help you. **kube_pod_info{namespace="monitoring", pod="prometheus-kube-prometheus-stack-prometheus-0"}**

2. Find the number of pods that have containers that asks for memory limit over 200MB across the whole cluster. **count(kube_pod_container_resource_limits > 209715200)**

3. Display the sum of pods requested CPU per node **sum by(node) (kube_pod_container_resource_requests{resource="cpu"})**

### Alerts

Navigate through th UI to see the Alerts.

You see the list of community recommended alerts.
Each alert has a meaning, an impact, a disgnosis and a mitigation that can be found on [https://runbooks.prometheus-operator.dev/](https://runbooks.prometheus-operator.dev/)

Look at the currently `firing` alerts. Some are critical. Yet the cluster is functionnal. Why?
**RKE1 does not deploy ControllerManager, kube-proxy and kube-scheduler as pods.**

## Play with Grafana

Check that you can access Grafana(replace the X by value of your assigned project): <http://grafana.k8s-ops-X.wescaletraining.fr/>

To get the credentials, you have to look inside the `kube-prometheus-stack-grafana` secret in the monitoring namespace

When connected, look for the `Kubernetes / Compute Resources / Cluster` dashboard which gives an overview of the resource usage of the cluster, can you find out the meaning of each panel ?

Browse the other dashboards and try to guess what they are used for.

You can also import other dashboards if you want. Take a look at the Grafana website to see what already exists : <https://grafana.com/grafana/dashboards/>

## Monitor a wordpress application

Create a `wordpress` namespace.

All the resource creations for wordpress will be done in this `wordpress` namespace.

### Deploy the wordpress application

#### Deploy MySQL

Kubernetes secret `mysql-pass` is referenced by the MySQL and WordPress pod configuration so that those pods will have access to it. The MySQL pod will set the database password, and the WordPress pod will use the password to access the database.

Complete the following command to create the kubernetes secret `mysql-pass` from the given [password.txt](./password.txt) file.

```sh
kubectl create secret generic mysql-pass -n wordpress COMPLETE_THE_COMMAND
```

**`kubectl create secret generic mysql-pass -n wordpress --from-file=password.txt`**

Now, the MySQL pods can be launched. Start MySQL using [mysql-deployment.yaml](./mysql-deployment.yaml).

Take a look at [mysql-deployment.yaml](./mysql-deployment.yaml), and note that we've defined a volume mount for /var/lib/mysql, and then created a Persistent Volume Claim that looks for a 2G volume. This claim is satisfied by any volume that meets the requirements.

Also look at the env section and see that we specified the password by referencing the secret mysql-pass that we created above. Secrets can have multiple key:value pairs. Ours has only one key password.txt which was the name of the file we used to create the secret. The MySQL image sets the database password using the MYSQL_ROOT_PASSWORD environment variable.

It may take a short period before the new pod reaches the Running state.

Up to this point one Deployment, one Pod, one PVC, one Service, one Endpoint, one PV, and one Secret have been created, as shown below:

```sh
kubectl get deployment,pod,svc,endpoints,pvc -l app=wordpress -o wide -n wordpress && \
kubectl get secret mysql-pass -n wordpress && \
kubectl get pv -n wordpress 
```

#### Deploy WordPress

Use [wordpress-deployment.yaml](./wordpress-deployment.yaml).

Here we are using many of the same features, such as a volume claim for persistent storage and a secret for the password.

The WordPress image accepts the database hostname through the environment variable WORDPRESS_DB_HOST. We set the env value to the name of the MySQL service we created: wordpress-mysql.

Ensure everything is fine with

```sh
kubectl get deployment,pod,svc,endpoints,pvc -l app=wordpress -o wide -n wordpress && \
kubectl get secret mysql-pass -n wordpress && \
kubectl get pv -n wordpress 
```

Now, we can visit the running WordPress app.

Retrieve the opened Node port:

```sh
kubectl get services wordpress -n wordpress 
NAME        TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
wordpress   NodePort   10.43.21.217   <none>        80:31362/TCP   5m15s
```

<http://lb.k8s-ops-X.wescaletraining.fr:NODE_PORT>

You should see the familiar WordPress init page.

### Monitor MySQL

#### Get MySQL metrics in Prometheus

Edit the [mysql-deployment.yaml](./mysql-deployment.yaml) file to add a [prom/mysqld-exporter](https://registry.hub.docker.com/r/prom/mysqld-exporter/) sidecar to the `wordpress-mysql` deployment.

You can use the following snippet to add a sidecar container to the mysql container:

```yaml
   spec:
      containers:
      - name: mysql
        # Sidecar container
      - name: prom-mysql
        image: prom/mysqld-exporter
        env:
         # Configure the container to connect to the mysql container.
         # Expected environment variable name is DATA_SOURCE_NAME
         # You may use intermediary environment variables to build the value of DATA_SOURCE_NAME
        ...
        ports:
        - containerPort: 9104
          name: mysqld-exporter
      volumes:
      - name: mysql-persistent-storage
        persistentVolumeClaim:
          claimName: mysql-pv-claim
```

**`kubectl apply -f mysql-deployment.yaml`**

Ensure your pod starts without errors in the logs and your wordpress still works.

Because the sidecar declares a new port, do not forget to add the `mysqld-exporter` to the service `wordpress-mysql` port list.

Now, you must instruct Prometheus to scrape this exporter. To do that, create a ServiceMonitor by completing this snippet:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mysql-prom
  labels:
    app: wordpress
    tier: mysql
spec:
  selector:
    matchLabels:
      SERVICE_LABELS_TO_BE_SET
  endpoints:
  - port: SCRAPPED_PORT_TO_BE_SET
```

**`kubectl apply -f service-monitor.yml`**

Wait 1 minute and ensure you see this target in the Prometheus /targets

#### Create a Grafana Dashboard for MySQL

On grafana, click on the **Dashboards** / **Import** menu and add  Grafana [dashboard](https://grafana.com/grafana/dashboards/14057-mysql/).

Ensure it works well.

#### Create an alert for MySQL pod

Complete the given snippet to create a [PrometheusRule](https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/api.md#prometheusrule), to ensure you have at least one MySQL running for our wordpress application.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mysql-prom-up
  namespace: wordpress
spec:
  groups:
    - name: wordpress.mysql
      rules:
        - alert: NoRunningMysql
          annotations:
            description: Targets are down.
            summary: Targets are down
          # Hint: use the `up` metric
          expr: PROM_QL_QUERY_TO_BE_COMPLETED
          for: 10m
          labels:
            severity: warning
```

**`kubectl apply -f prom-rule.yaml`**

### Monitor Wordpress

To monitor the wordpress application, you would need a Prometheus exporter for the PHP layer.

A low cost alternative is to use the [Blackbox exporter](https://github.com/prometheus/blackbox_exporter) to perform HTTP checks.

#### Deploy the black box exporter

To perform health checks, you need to deploy a Blackbox exporter infratructure.

For that, use the community [Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-blackbox-exporter). The default Helm chart configurations will activate the http_2xx module, which is sufficient for our case.

If you run:

```sh
helm show values prometheus-community/prometheus-blackbox-exporter --jsonpath='{.config}'|jq ''
```

You will get:

```json
{
  "modules": {
    "http_2xx": {
      "http": {
        "follow_redirects": true,
        "preferred_ip_protocol": "ip4",
        "valid_http_versions": [
          "HTTP/1.1",
          "HTTP/2.0"
        ]
      },
      "prober": "http",
      "timeout": "5s"
    }
  }
}
```

Yet, Blackbox exporter supports other modules. See the [configuration example](https://github.com/prometheus/blackbox_exporter/blob/master/example.yml).

Deploy the chart inside the `bbox-exporter` namespace:

```sh
helm upgrade --install bbox-exporter prometheus-community/prometheus-blackbox-exporter --namespace bbox-exporter --create-namespace
```

With `kubectl`, retrieve the Blackbox exporter service name.

You can now use this Blackbox infrasructure to run HTTP tests on `google.com`:

```sh
kubectl run test -ti --image=busybox -- sh
# Inside the pod
wget -O- http://bbox-exporter-prometheus-blackbox-exporter.bbox-export.svc.cluster.local:9115/probe?target=google.com
```

#### Add an HTTP Probe to monitor the wordpress service

The last step is to create a [Probe](https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/api.md#probe) resource to tell Prometheus to call the blackbox exporter service with a specific target - your Wordpress URL.

Complete the following snippet:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: Probe
metadata:
  name: wordpress-website
  namespace: wordpress
spec:
  interval: 60s
  module: http_2xx
  prober:
    url: BBOX_INTERNAL_SERVICE_DNS:BBOX_PORT
  targets:
    staticConfig:
      static:
        - http://PUBLIC_DNS_OF_YOUR_CLUSTER:NODE_PORT_NUMBER/
```

Create this probe.

**Edit the port in blackbox-exporter-probe.yml. Then:**
**`kubectl apply -f blackbox-exporter-probe.yml`**

Then wait 1 minute to check the `wordpress-website` target is visible in `/targets` endpoint of your Prometheus (http://prometheus.k8s-ops-X.wescaletraining.fr)

Finally, consult the returned metrics opening `http://prometheus.k8s-ops-X.wescaletraining.fr/graph?g0.expr=%7Bjob%3D%22probe%2Fwordpress%2Fwordpress-website%22%7D&g0.tab=1&g0.stacked=0&g0.show_exemplars=0&g0.range_input=1h`. Replace the `-X` with your cluster number.

To create an alert, create a new PrometheusRule for the `up{job="probe/wordpress/wordpress-website", namespace="wordpress"}`.

**`kubectl apply -f prom-rule-wordpress.yaml`**

## Clean

```sh
helm uninstall bbox-exporter --namespace bbox-exporter
helm uninstall kube-prometheus-stack --namespace monitoring
kubectl delete ns bbox-exporter
kubectl delete ns monitoring
kubectl delete ns wordpress
```

Because CRDs are not deleted when uninstalling the helm release, manual deletion must be done:

```sh
kubectl delete crd alertmanagerconfigs.monitoring.coreos.com
kubectl delete crd alertmanagers.monitoring.coreos.com
kubectl delete crd podmonitors.monitoring.coreos.com
kubectl delete crd probes.monitoring.coreos.com
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd prometheusrules.monitoring.coreos.com
kubectl delete crd servicemonitors.monitoring.coreos.com
kubectl delete crd thanosrulers.monitoring.coreos.com
```
