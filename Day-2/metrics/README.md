# Metrics and alerting with kube-prometheus

To ensure the applications are running correctly and that the cluster is healthy we need to monitor what is deployed on the cluster. To do that, we need a metrics backend that can collect, store and present this data to cluster admin and users.

In this exercise, we will demonstrate that using the [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) monitoring stack and experience how it works.

The goal will be to monitor our MongoDB cluster using the Prometheus configuration properties in the MongoDB operator as well as the performance of our admin UI using the [Blackbox exporter](https://github.com/prometheus/blackbox_exporter).

## Install kube-prometheus stack

First, we are going to deploy the kube-prometheus stack using its Helm chart. To give context to the Helm release you have the `~/files/prometheus-chart-values.yaml` values file at your disposal.

- Inspect the values file and install the kube-prometheus stack using Helm in a new `monitoring` namespace.

```sh
# Inspect Values file
training@bastion:~$ cat ~/files/prometheus-chart-values.yaml
# Install kube-prometheus stack
training@bastion:~$ helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
training@bastion:~$ helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -f ~/files/prometheus-chart-values.yaml -n monitoring --create-namespace
```

- Look at the pods that have been created and see the installed CRDs belonging to the `monitoring.coreos.com` API group

```sh
training@bastion:~$ kubectl api-resources --api-group=monitoring.coreos.com
```

> Among those CRDs, a `Prometheus` kind is now available on the cluster. The Helm release you have installed has created a `Prometheus` resource named `kube-prometheus-stack-prometheus`.

Regarding this resource, answer the following questions:

- Is the resource highly available?
- At which frequency will metrics be scraped ?
- How long are metrics stored ?

## Play with Prometheus

- Check that you can access prometheus (replace the X by value of your assigned project): <http://prometheus.k8s-ops-X.wescaletraining.fr/>

- Navigate through the UI and check what's in the **Status -> Target health** tab. Can you explain what each section corresponds to ?

- Go back to the **Query** tab and enter the following query

```sh
up
```

- Can you tell what the result means ?

### PromQL queries

You will now try out the PromQL querying language to retrieve some specific information. You can use this [documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/) to help you.

1. Using the `kube_pod_info` metric, retrieve the information of the `prometheus-kube-prometheus-stack-prometheus-0` pod on the `monitoring` namespace (*tip: you might have to use some filters to facilitate your search*).

2. Find the number of pods that have containers that asks for memory limit over 200MB across the whole cluster

3. Display the sum of pods requested CPU per node

### Alerts

- Navigate through the Prometheus UI to see the Alerts.

> You see the list of community recommended alerts. Each alert has a meaning, an impact, a diagnosis and a mitigation that can be found on [https://runbooks.prometheus-operator.dev/](https://runbooks.prometheus-operator.dev/)

- Look at the alerts that are currently `firing`. Some are critical yet the cluster is functionnal. Can you guess why the `TargetDown` rules fires ?

## Play with Grafana

- Check that you can access Grafana (replace the X by value of your assigned project): <http://grafana.k8s-ops-X.wescaletraining.fr/>

- To get the credentials, you have to look inside the `kube-prometheus-stack-grafana` secret in the `monitoring` namespace

- When connected, look for the `Kubernetes / Compute Resources / Cluster` dashboard which gives an overview of the resource usage of the cluster, can you find out the meaning of each panel ?

- Browse the other dashboards and try to guess what they are used for.

- You can also import other dashboards if you want. Take a look at the Grafana website to see what already exists: [https://grafana.com/grafana/dashboards/](https://grafana.com/grafana/dashboards/)

## Monitor our microservices demo app

### MongoDB

As said in the beginning, we will configure the MongoDB monitoring directy with the operator. Let's do it !

- Create a secret containing credentials for the MongoDB user that will be in charge of querying metrics

```sh
training@bastion:~$ kubectl create secret generic mongodb-metrics-credentials -n application \
  --from-literal username=prometheus --from-literal password=<YOUR_PASSWORD>
```

- Edit your `MongoDBCommunity` cluster to expose Prometheus metrics on a custom endpoint

```sh
...
spec:
  ...
  prometheus:
    username: prometheus
    passwordSecretRef:
      name: mongodb-metrics-credentials
  ...
```

- Once the cluster is ready again, you can look at what kind of metrics are exported

```sh
training@bastion:~$ kubectl -n application port-forward svc/mongodb-cluster-svc 9216
# Query the metrics endpoint to see what is gathered
training@bastion:~$ curl http://prometheus:<YOUR_PASSWORD>@localhost:9216/metrics
```

- Now, you must instruct Prometheus to scrape the metrics. To do that, create a [ServiceMonitor](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#servicemonitor) by completing the [mongodb-servicemonitor.yaml](./mongodb-servicemonitor.yaml) file.

```sh
training@bastion:~$ kubectl apply -f mongodb-servicemonitor.yaml -n application
```

- Wait a minute and check the **Targets Health** tab on Prometheus. You should see your MongoDB instances appear

- Import the Grafana dashboard defined in the [mongodb-dashboard.json](./mongodb-dashboard.json) file directly from the Grafana UI (Dashboards tab -> New -> Import -> Paste the json content). Ensure it works well.

- We will now create a [PrometheusRule](https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/api.md#prometheusrule) to be alerted when one or more instances from our MongoDB cluster are missing. Complete the [mongodb-prometheusrule.yaml](./mongodb-prometheusrule.yaml) file and create the resource.

- After a few seconds, you should see your alert on the Prometheus UI. You can play with the MongoDB replicas to see if your alert fires.

### Admin UI

Now, we will use the Blackbox exporter to perform health checks on our admin UI.

Blackbox exporter supports differents modules to perform checks. See the [configuration example](https://github.com/prometheus/blackbox_exporter/blob/master/example.yml).

In our case, we will focus on HTTP checks.

- Deploy the chart inside the `blackbox-exporter` namespace:

```sh
training@bastion:~$ helm upgrade --install blackbox-exporter prometheus-community/prometheus-blackbox-exporter --namespace blackbox-exporter --create-namespace
```

- Inspect the configmap to see which modules are enabled by default

- We can now test the exporter by running a manual HTTP test against `google.com`

```sh
training@bastion:~$ kubectl exec deploy/front-admin -n application -- curl "http://blackbox-exporter-prometheus-blackbox-exporter.blackbox-exporter.svc.cluster.local:9115/probe?target=google.com"
# Inspect the output to see the exported metrics
```

- It's time to monitor our admin UI ! This is done with a [Probe](https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/api.md#probe) resource to tell Prometheus to call the blackbox exporter service with a specific target

```yaml
apiVersion: monitoring.coreos.com/v1
kind: Probe
metadata:
  name: front-admin
  namespace: application
spec:
  interval: 30s
  module: http_2xx
  prober:
    url: blackbox-exporter-prometheus-blackbox-exporter.blackbox-exporter.svc.cluster.local:9115
  targets:
    staticConfig:
      static:
        - https://demo-admin.k8s-ops-X.wescaletraining.fr
```

- Wait 1 minute and check that the new probe is visible in the Prometheus targets

- Check the `probe_success` metric to see if your probe works. Is it the case ?

- Troubleshoot this by executing the probe manually in debug mode

```sh
training@bastion:~$ kubectl exec deploy/front-admin -n application -- curl "http://blackbox-exporter-prometheus-blackbox-exporter.blackbox-exporter.svc.cluster.local:9115/probe?target=demo-admin.k8s-ops-X.wescaletraining.fr&debug=true"
# Inspect the log lines to try to pinpoint the issue
```

- Make the necessary change on the blackbox exporter configuration to make our probe work

- Restart the blackbox exporter. The probe should now be successful !
