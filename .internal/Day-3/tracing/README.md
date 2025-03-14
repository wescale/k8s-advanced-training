# Distributed tracing

In this exercise we will explore how to track requests across multiples services with distributed tracing.

You will install [Grafana Tempo](https://grafana.com/docs/tempo/latest/) as a backend to store traces and visualize them directly in Grafana.

Then we will configure some of our services (`front-admin`, `article-service`) to generate traces using the Opentelemetry protocol and send them to Tempo.

## Install Tempo

Before generating traces, we need a backend to store them.

- Install Grafana Tempo in standalone mode with its Helm chart

```sh
training@bastion:~$ helm repo add grafana https://grafana.github.io/helm-charts
training@bastion:~$ helm install tempo grafana/tempo -n tracing --create-namespace
# Ensure Tempo is running
training@bastion:~$ watch kubectl po -n tracing
```

- Take a look at the configuration in the `tempo` configmap.
  - What protocol(s) can be used to push traces to Tempo ?

> Jaeger and Opentelemetry on both HTTP and GRPC

  - On which ports ?

> Jaeger: GRPC => 14250 and HTTP => 14268

> Opentelemetry: GRPC => 4317 and HTTP => 4318

- Add a Tempo datasource in Grafana from the `Connections` tab
  - Type: `tempo`
  - Name: `Tempo`
  - No authentication
  - Url: `http://tempo.tracing.svc.cluster.local:3100`
  - Save and test to make sure the datasource is correctly configured

- Go on the `Explore` tab and select the `Tempo` datasource to query some traces. Do you see any of them ? Why ?

> No because we don't have any component that is emitting traces.

## Send our first traces

Now that we have our traces backend deployed and configured, we can configure the `article-service` component to emit spans.

This can be done by setting the `OTLP_ENDPOINT` environment variable to the Tempo opentelemetry receiver HTTP endpoint. The service will then emit traces for both API and MongoDB calls.

- Configure the `article-service` Deployment to sent traces to Tempo on the `/v1/traces` API endpoint

```sh
training@bastion:~$ kubectl apply -f article-service-deployment.yaml -n application
```

- Inspect the logs to see if there are any errors

- Generate some traffic on the admin UI and query traces on Grafana again. You should see some entries appear. Click on one to see what it looks like.

- Questions
  - Can you tell the differences between the traces ?
  - Find out which operation they correspond to
  - Look for a trace that contains both a HTTP call and a MongoDB command. How long did the MongoDB took ?

This is the first step towards having a vision on what a request goes through when we interact with our application. The only thing left is to also setup traces on the `front-admin` component.

## Front-admin traces

Since the `front-admin` service is a web interface, calls are made by the client's browser. This means that the Tempo endpoint must be publicly accessible. On top of that me need to configure a Cross-Origin Resource Sharing (CORS) policy since both Tempo and the admin UI will not share the same address.

- Create an ingress for Tempo and reconfigure it to allows CORS

```sh
# Create the ingress for tempo
training@bastion:~$ kubectl apply -f tempo-ingress.yaml -n tracing
# Add the CORS policy to the tempo config
training@bastion:~$ kubectl edit cm tempo -n tracing
...
            otlp:
              protocols:
                grpc:
                  endpoint: 0.0.0.0:4317
                http:
                  endpoint: 0.0.0.0:4318
                  cors:
                    allowed_origins:
                    - "*.k8s-ops-X.wescaletraining.fr"
...
# Then restart tempo
training@bastion:~$ kubectl rollout restart sts/tempo -n tracing
```

Now we can enable opentelemetry tracing on the `front-admin` component.

- Edit the `front-admin` configmap to add the `otlpEndpoint` endpoint set to `https://tempo.k8s-ops-X.wescaletraining.fr/v1/traces`

```sh
training@bastion:~$ kubectl apply -f front-admin-configmap.yaml -n application
```

- Restart the admin UI pod. If you refresh the page on your browser, you should see a message in the dev console that tracing is enabled.

```sh
training@bastion:~$ kubectl rollout restart deploy/front-admin -n application
```

- Generate some traffic again and go take a look at the generated traces on Grafana.

- Find a trace emitted by the `front-admin` and inspect it.

  - How many spans are in the trace ?

> 4

  - What operations does each one correspond to ?

> HTTP request on `front-admin`, HTTP API request to `article-service`, `GetArticles` function call and `article.find` command on MongoDB

  - What is the library used to instrument this application?

> @opentelemetry/instrumentation-fetch

  - What version of the opentelemetry SDK is used ?

> 1.30.1

- You can also explore the `front-admin` UI and add an article to see if the traces emitted are different than the one you just inspected

> [OpenTelemetry specification repository](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/) defines semantic data conventions that prescribe certain well known tag names and log fields for common scenarios. Instrumentation is encouraged to use those names to ensure that the data reported to the tracing system is well defined and portable across different tracing backends.

> You might have noticed that spans can also have events. A span event can be thought of as a structured log message (or annotation) on a span, typically used to denote a meaningful, singular point in time during the Span’s duration. For example, denoting when a page becomes interactive can be achieved with a span event because it represents a meaningful, singular point in time. For more information on span events, you can take a look at [this documentation](https://opentelemetry.io/docs/concepts/signals/traces/#span-events).
