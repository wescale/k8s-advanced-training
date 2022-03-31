# Monitoring with prometheus


In this exercise, you will deploy a wordpress application then monitor it with Prometheus and Grafana.

You will add prometheus exporters and prometheus-operator CRDs to add monitoring.

Then you will create a dashboard on Grafana to verify your PromQL query that you will reuse to create a Prometheus rule.

Finally, you will delete pods and ensure you see the alarm triggered.
## Setup

**If not already done**, install the [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) which is a ready to use complete monitoring stack: Prometheus, Grafana and Alert Manager.

```sh
git clone https://github.com/prometheus-operator/kube-prometheus
cd kube-prometheus
git checkout release-0.7
kubectl create -f manifests/setup
until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
kubectl create -f manifests/
````

Take a look a the manifests. 

In particular the CustomResourceDefinition in the folder `manifests/setup`:
* ServiceMonitor
* PodMonitor
* Prometheus

Prometheus, Grafana and Alert Manager are exposed as ClusterIP: they are only internal to the cluster.

If you want to reach them, you can use port forward, or create additional k8s NodePort services (recommended).

### Access the service using port-forward (not recommended)

Use `ssh -L` option to forward ports 9090, 3000 and 9093 from the bastion.

Then on the bastion,  use the `port-forward` kubectl command:
```sh
kubectl --namespace monitoring port-forward svc/prometheus-k8s 9090 &
kubectl --namespace monitoring port-forward svc/grafana 3000 &
kubectl --namespace monitoring port-forward svc/alertmanager-main 9093 &
```

And open the following URLs:
* Prometheus [http://localhost:9090](http://localhost:9090)
  * See its configuration, targets and some metrics
* Grafana [http://localhost:3000](http://localhost:3000)
  * admin/admin.
* AlertManager [http://localhost:9093](http://localhost:9093)

### Access the services using additional k8s Node Port services (preferred way)

Create new NodePort Services:
```sh
kubectl apply -f monitoring-services.yaml -n monitoring
```

Open you browser (replace `X` with your env number):
* Prometheus: http://lb.wsc-kubernetes-adv-training-X.wescaletraining.fr:32601
* Alert Manager http://lb.wsc-kubernetes-adv-training-X.wescaletraining.fr:32602
* Grafana: http://lb.wsc-kubernetes-adv-training-X.wescaletraining.fr:32603

### Add dashboards on Grafana

Add the [Kubernetes Cluster (Prometheus)](https://grafana.com/grafana/dashboards/6417) dashboard.


## Deploy the application

### Create the MySQL Password Secret

Use a [Secret](http://kubernetes.io/docs/user-guide/secrets/) object to store the MySQL password. First create a file (in the same directory as the wordpress sample files) called `password.txt` and save your password in it. Make sure to not have a trailing newline at the end of the password. The first `tr` command will remove the newline if your editor added one. Then, create the Secret object.

```shell
kubectl create secret generic mysql-pass --from-file=password.txt
```

This secret is referenced by the MySQL and WordPress pod configuration so that those pods will have access to it. The MySQL pod will set the database password, and the WordPress pod will use the password to access the database.

### Deploy MySQL

Now that the secrets is defined, the Kubernetes pods can be launched. Start MySQL using [mysql-deployment.yaml](mysql-deployment.yaml).

Take a look at [mysql-deployment.yaml](mysql-deployment.yaml), and note that we've defined a volume mount for `/var/lib/mysql`, and then created a Persistent Volume Claim that looks for a 2G volume. 
This claim is satisfied by any volume that meets the requirements.

Also look at the `env` section and see that we specified the password by referencing the secret `mysql-pass` that we created above. Secrets can have multiple key:value pairs. Ours has only one key `password.txt` which was the name of the file we used to create the secret. The [MySQL image](https://hub.docker.com/_/mysql/) sets the database password using the `MYSQL_ROOT_PASSWORD` environment variable.

It may take a short period before the new pod reaches the `Running` state.  List all pods to see the status of this new pod.

```shell
kubectl get pods
```

```shell
NAME                          READY     STATUS    RESTARTS   AGE
wordpress-mysql-cqcf4-9q8lo   1/1       Running   0          1m
```

Kubernetes logs the stderr and stdout for each pod. Take a look at the logs for a pod by using `kubectl log`. Copy the pod name from the `get pods` command, and then:

```shell
kubectl logs <pod-name>
```

```shell
...
2016-02-19 16:58:05 1 [Note] InnoDB: 128 rollback segment(s) are active.
2016-02-19 16:58:05 1 [Note] InnoDB: Waiting for purge to start
2016-02-19 16:58:05 1 [Note] InnoDB: 5.6.29 started; log sequence number 1626007
2016-02-19 16:58:05 1 [Note] Server hostname (bind-address): '*'; port: 3306
2016-02-19 16:58:05 1 [Note] IPv6 is available.
2016-02-19 16:58:05 1 [Note]   - '::' resolves to '::';
2016-02-19 16:58:05 1 [Note] Server socket created on IP: '::'.
2016-02-19 16:58:05 1 [Warning] 'proxies_priv' entry '@ root@wordpress-mysql-cqcf4-9q8lo' ignored in --skip-name-resolve mode.
2016-02-19 16:58:05 1 [Note] Event Scheduler: Loaded 0 events
2016-02-19 16:58:05 1 [Note] mysqld: ready for connections.
Version: '5.6.29'  socket: '/var/run/mysqld/mysqld.sock'  port: 3306  MySQL Community Server (GPL)
```

Also in [mysql-deployment.yaml](mysql-deployment.yaml) we created a service to allow other pods to reach this mysql instance. The name is `wordpress-mysql` which resolves to the pod IP.

Up to this point one Deployment, one Pod, one PVC, one Service, one Endpoint, one PV, and one Secret have been created, shown below:

```shell
kubectl get deployment,pod,svc,endpoints,pvc -l app=wordpress -o wide && \
kubectl get secret mysql-pass && \
kubectl get pv
```

```shell
NAME                     DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deploy/wordpress-mysql   1         1         1            1           3m
NAME                                  READY     STATUS    RESTARTS   AGE       IP           NODE
po/wordpress-mysql-3040864217-40soc   1/1       Running   0          3m        172.17.0.2   127.0.0.1
NAME                  CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE       SELECTOR
svc/wordpress-mysql   None         <none>        3306/TCP   3m        app=wordpress,tier=mysql
NAME                 ENDPOINTS         AGE
ep/wordpress-mysql   172.17.0.2:3306   3m
NAME                 STATUS    VOLUME       CAPACITY   ACCESSMODES   AGE
pvc/mysql-pv-claim   Bound     local-pv-2   20Gi       RWO           3m
NAME         TYPE      DATA      AGE
mysql-pass   Opaque    1         3m
NAME         CAPACITY   ACCESSMODES   STATUS      CLAIM                    REASON    AGE
local-pv-1   20Gi       RWO           Available                                      3m
local-pv-2   20Gi       RWO           Bound       default/mysql-pv-claim             3m
```

### Deploy WordPress

Next deploy WordPress using
[wordpress-deployment.yaml](wordpress-deployment.yaml).

Here we are using many of the same features, such as a volume claim
for persistent storage and a secret for the password.

The [WordPress image](https://hub.docker.com/_/wordpress/) accepts the
database hostname through the environment variable
`WORDPRESS_DB_HOST`. We set the env value to the name of the MySQL
service we created: `wordpress-mysql`.


### Visit your new WordPress blog


Now, we can visit the running WordPress app.

Retrieve the opened Node port:
```shell
kubectl get services wordpress
```

```shell
NAME        TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
wordpress   NodePort   10.43.21.217   <none>        80:31362/TCP   5m15s
```


```shell
http://<external-ip>:Node_Port
```

You should see the familiar WordPress init page.

## Add prometheus exporters

You will complete your stack to:
* add a [mysqld_exporter](https://github.com/prometheus/mysqld_exporter/blob/master/README.md) sidecar to the mysql container. With this sidecar the mysql pods can expose metrics and Prometheus will collect them.
* deploy a [backboxexporter](https://github.com/prometheus/blackbox_exporter) to call your wordpress application and ensure it is running

### Monitor the mysql pods

Edit the mysql-deployment to add mysqld_exporter.
Ensure your pod starts without errors in the logs and your wordpress still works.

### Add a PodMonitor for the mysql spod

Create a [PodMonitor](https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/api.md#podmonitor) CRD to monitor the pod wordpress-mysql on *port* 9104.

Wait 1 minute and ensure you see this target in the Prometheus /targets

### Create a Grafana dashboard to monitor the mysql service

Download this Grafana [dashboard](https://raw.githubusercontent.com/prometheus/mysqld_exporter/main/mysqld-mixin/dashboards/mysql-overview.json) `mysql-overview` for the mysqld_exporter and import it into Grafana.

Ensure it works well.

### Create rules

Create a [PrometheusRule](https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/api.md#prometheusrule), to ensure you have at least one mysql_exporter up.

N.B: inspect the `ruleSelector` of the Prometheus to be sure your rule will be taken into account.

### Bonus: Deploy the black box exporter and add an HTTP Probe to monitor the wordpress

To monitor the wordpress application, we need an exporter for the PHP layer.
Another solution is to use the [backboxexporter](https://github.com/prometheus/blackbox_exporter) to perform HTTP checks.

For that, you need to deploy a service and so deployment for a blackbox_exporter.
This exporter will need a configuration file: you can use the [default one](https://github.com/prometheus/blackbox_exporter/blob/master/example.yml).

Then, create a CRD [Probe](https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/api.md#probe) to monitor an URL of the Wordpress

