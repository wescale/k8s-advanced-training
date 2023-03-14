# Distributed tracing with Jaeger

You will install the [Jaeger Operator](https://www.jaegertracing.io/docs/1.42/operator/) and experience how it works.

In a second time, you will deploy a demo application [Hot R.O.D](https://github.com/jaegertracing/jaeger/blob/main/examples/hotrod/README.md) which is configured with OpenTelemetry SDK, then see what distributed tracing can do.

## Install the Jaeger operator

Before starting, you must install the [cert-manager](https://cert-manager.io/), a pre-requisites for Jaeger to manage certificates and webhooks:

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml
```

Install the Jaeger operator in cluster wide mode:

```sh
kubectl create namespace observability
kubectl create -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.42.0/jaeger-operator.yaml -n observability
# Ensure everything is OK:
kubectl get deployment jaeger-operator -n observability
```

For more details about the Jaeger Operator, see the [documentation](https://www.jaegertracing.io/docs/1.42/operator/#installing-the-operator-on-kubernetes).

## Create a Jaeger instance

The Jaeger CRD supports a `strategy` field which accepts 3 values:

* `allInOne`: simplest way to deploy Jaeger. No persistency as data are stored un memory.
* `production`: on production environments, Jaeger would be deployed in a distributed fashion where each component (the agents, the collectors, the storage backend, the query and the UI) could be scaled independently. In this case, the storage backend (ElasticSearch or Cassandra) must be managed separately.
* `streaming`: similar to `production` but add a Kafka integration to buffer traces.

Here, for a sake of simplicity, you will create a basic Jaeger instance with the `allInOne` strategy:

```yaml
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: simplest
spec:
  strategy: allInOne
```

```sh
kubectl create ns tracing
kubectl apply -f jaeger-simplest.yaml -n tracing
```

Ensure the jager CR is Ok: `kubectl get jaegers -n tracing -w`

Then see all the deployed components: `kubectl get all,ing -n tracing`

**Questions**:

* How many agents are deployed?
* For more scalability, you could deploy the agents as: daemonset, deployment with horizontal pod autoscaler, or as sidecar containers. What are the differences between those choices?
* What is the default sampling strategy `kubectl get cm -n tracing simplest-sampling-configuration -o yaml`?

As you see, an Ingress is created on the port 80. Replace the -X and access the Jaeger UI: <http://lb.k8s-ops-X.wescaletraining.fr/search>

## Deploy a demo application

Edit the given [hot-rod.yml](./hotrod.yml) file to configure it:

```yaml
  containers:
    - name: jaeger-hotrod
      securityContext: {}
      image: jaegertracing/example-hotrod:1.42.0
      imagePullPolicy: IfNotPresent
      # "-j" option set the endpoint to generate 'find trace' links
      # Change the X wit your cluster number
      args: ["all", "-j", "http://lb.k8s-ops-X.wescaletraining.fr"]
      env:
        - name: OTEL_EXPORTER_JAEGER_ENDPOINT
          # The application directly call the collector. It needs to know the Jaeger collector endpoint
          # NOTE: the service is in the `tracing`namespace
          value: http://COLLECTOR_DNS:14268/api/traces
```              

Deploy the application in the `default` namespace:

```sh
kubectl apply -f hotrod.yml
```

The `Hot R.O.D` application run several microservices from a single binary. These microservices start several servers on different ports:

* `frontend` on port 8080
* `route` on port 8083
* `customer` on port 8081
* `driver` on port 8082

```sh
# Retrieve the NodePort
NODE_PORT=$(kubectl get svc jaeger-hotrod -o jsonpath="{.spec.ports[0].nodePort}")
echo $NODE_PORT
```

Open the application web page <http://lb.k8s-ops-X.wescaletraining.fr:${NODE_PORT}/>

You see four customers, and by clicking one of the four buttons you order a car to arrive to the customer’s location, perhaps to pick up a product and deliver it elsewhere. Once a request for a car is sent to the backend, it responds with the car’s license plate number and the expected time of arrival.

Click on some customers to generate traffic.

## Use tracing

### Dependency analysis

Jaeger analyzes traces to build a view of your system.

See the DAG view in <http://lb.k8s-ops-X.wescaletraining.fr/dependencies>.

You retrieve the micro service architecture plus the storage backends of the application. In addition, you get the total number of requests processeed by each component.

### Spans

On the Hot R.O.D web page, click on a `find trace` link.

You arrive on the `Search` tab of Jaeger with pre filled filters.

You see the related trace. Click on it.

The timeline view shows a typical view of a trace as a time sequence of nested spans, where a span represents a unit of work within a single service. The top level span, also called the root span, represents the main HTTP request from Javascript UI to the frontend service, which in turn called the customer service, which in turn called a MySQL database. The width of the spans is proportional to the time a given operation takes. It may represent a service doing some work or waiting on a downstream call.

If you click on any span in the timeline, it expands to show more details, including span tags, process tags, and logs. Let’s click on one of the failed calls to `Redis`.

You see that the span has a tag `error=true`, which is why the UI highlighted it as failed. You can also see that it has a log statement that explains the nature of the error as “redis timeout”. You can also see the `driver_id` (car’s license plate number) that the driver service was attempting to retrieve from Redis.

How do you decide if this data should go to span tag or span logs? The OpenTracing API does not dictate how you do it; the general principle is that information that applies to the span as a whole should be recorded as a tag, while events that have timestamps should be recorded as logs.

[OpenTelemetry specification repository](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/) defines semantic data conventions that prescribe certain well known tag names and log fields for common scenarios. Instrumentation is encouraged to use those names to ensure that the data reported to the tracing system is well defined and portable across different tracing backends.

## Clean

Delete the hot R.O.D applciation: `kubectl -delete -f hotrod.yml`

But keep cert-manager and jaeger installations for later hands-on.
