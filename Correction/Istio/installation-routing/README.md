# Hands-on: Istio

You will install Istio using the `istioctl` - the Istio CLI.

Then you will get familiar with basic HTTP routing capabilities of Istio.

You will explore more advanced features like fault injection, traffic shifting.

To finish, you will see how Istio and Jaeger can provide powerfull observability for a micro service oriented application.

## Installing Istio

Install `istioctl`, the Istio CLI:

```sh
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.16.1 TARGET_ARCH=x86_64 sh -
cd istio-1.16.1
export PATH=$PWD/bin:$PATH
```

Then deploy basic Istio components:

```sh
istioctl install --set profile=default -y
```

Check Istio is running:

```sh
kubectl get all -n istio-system
```

The `default` profile deploys only two components:

* an `ingress gateway` to manage incoming traffic to the cluster. Similar to an ingress controller.
* `istiod` which is the istio control plane.

**Questions**:

* How many pods are created for each deployment in istio-system namespace?
* Is there any mechanism for scalability?

To expose your deployments externally to the cluster, you first need to declare a [`Gateway`](https://istio.io/latest/docs/reference/config/networking/gateway/) which is basically L4-L6 properties for a load balancer:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: http-gateway
spec:
  selector:
    # indicate the proxy where it must run. Here, the default ingressgateway pods deployed in istio-system
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
```

```sh
kubectl apply -f gateway.yaml -n istio-system
```

## HTTP routing with istio

You will deploy basic nginx and apache in the cluster. Then you will use Istio traffic management to reach those services

First, create a namespace called "mesh":

```sh
kubectl create ns mesh
```

Then, you must add a specific label to this namespace to enable auto injection of Istio sidecar (Envoy proxy) to all the pods.

To retrieve the expected key and value, look at the `mutatingwebhookconfigurations`. In particular `istio-revision-tag-default` which defines `namespace.sidecar-injector.istio.io` among others webhooks.

Add the label:

```sh
kubectl label namespace mesh istio-injection=enabled
```

Then, deploy the 2 apps (nginx & apache) with their services:

```sh
kubectl apply -f nginx.yaml -n mesh
kubectl apply -f apache.yaml -n mesh
```

If you inspect the pods, you will see that there are 2 containers inside each pod as an envoy side car was injected:

```sh
kubectl describe pods -n mesh
```

Now, you must indicate how to route the traffic using this istio **http-gateway** Gateway. For that, create a [`VirtualService`](https://istio.io/latest/docs/reference/config/networking/virtual-service/), Which routes on uri prefix:

```sh
kubectl apply -f web-vs-path.yaml -n mesh
```

**Question**: What are the HTTP header names, added on responses by the VirtualService?

To access the service you need to get the ingress-gateway NodeIP and port:

```sh
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
# Replace X with your environment
export INGRESS_HOST=lb.k8s-ops-X.wescaletraining.fr
```

Access the services:

```sh
curl http://$INGRESS_HOST:$INGRESS_PORT/nginx -v
curl http://$INGRESS_HOST:$INGRESS_PORT/apache -v
```

## Fault injection

Now you will test failure injection feature of Istio, to easily test the resiliency of an application.

Istio supports fixed delay or aborted responses.

Here, edit the [web-vs-delay.yaml]() file to update the previously defined VirtualService to inject a delay of 7s on nginx.

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: web-servers-vs
spec:
  hosts:
  - "*"
  gateways:
  - istio-system/http-gateway
  http:
  - fault:
      # To be completed for a 7s delay
      # See https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPFaultInjection
      ...
    match:
    - uri:
        prefix: "/nginx"
    rewrite:
      uri: "/"
```

```sh
kubectl apply -f web-vs-delay.yaml -n mesh
```

Curl the nginx service, it must take 7s to respond.

## Traffic shifting

You will deploy 2 versions of the same **hello application** behind the same service. This is a typical use case in the life of a micro service.

```sh
kubectl apply -f hello-app.yaml -n mesh
```

The given [hello-app.yaml](./hello-app.yaml) file declares 2 deployments that are served by the same service named `web`.

The deployments have specific labels.

For v1 pods:

```yaml
app: hello
run: web1
version: v2
```

For v2 pods:

```yaml
app: hello
run: web2
version: v2
```

The `web` service targets v1 and v2 pods because of the selector:

```yaml
selector:
    app: hello #This service is matching the 2 deployments
```

Edit the given [web-dr-vs-canary.yaml](./web-dr-vs-canary.yaml) file to create a VirtualService and DestinationRule to achieve traffic shifting. For that, the VirtualService **hello-vs** references 2 subsets **v1** and **v2*.
To get a working setup, you must declare a DestinationRule **hello-dr** which indicates how to the subsets are populated.

90% of the traffic must go to **v1** and 10% must go to **v2**.

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: hello-vs
spec:
  gateways:
  - istio-system/http-gateway
  hosts:
  - "hello.wescale.fr" # The expected host header
  http:
  - route:
    # Look at the https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPRouteDestination
    - destination:
        host: K8S_SERVICE_NAME #Target kubernetes service
        port:
          number: 8080        
        subset: v1
      weight: 90
    - destination:
        host: K8S_SERVICE_NAME #Target kubernetes service
        port:
          number: 8080        
        subset: v2
      weight: 10
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: hello-dr
spec:
  host: K8S_SERVICE_NAME #Target kubernetes service
  subsets:
  - name: v1
    labels:
      V1_LABELS #LABELS for V1
  - name: v2
    labels:
      V2_LABELS #LABELS for V2
```

Create the resources on kubernetes:

```sh
kubectl apply -f web-dr-vs-canary.yaml -n mesh
```

The virtual service routes traffic based on host header, to test the canary release execute several times the following command:

```sh
while true; do
curl --header "Host: hello.wescale.fr" http://$INGRESS_HOST:$INGRESS_PORT/:
sleep 0.2
done
```

Verify that 90% of traffic is going to version 1 and the remaining 10% is going to version 2.

Once OK, clean the VirtualService and the DestinationRule:

```sh
kubectl delete -f web-dr-vs-canary.yaml -n mesh
```

## Filtering on header matching

Here, you will use the same **hello-app** application.

But, instead of split the traffic using weights on versions, you will filter the **version 2** using a specific HTTP header `allow-preview: true`.

Edit the given [web-dr-vs-header.yaml](./web-dr-vs-header.yaml)

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: hello-vs
spec:
  gateways:
  - istio-system/http-gateway
  hosts:
  - "hello.wescale.fr"
  http:
  - match:
    # See https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPMatchRequest
    # To add matching on header `allow-preview: true`
    #
    # Routes are evaluted following first match principle.
    # Thus, matching on header value must be declared before the other route
    route:
      - destination:
          host: web
          port:
            number: 8080        
          subset: v2
  - route:
    - destination:
        host: web
        port:
          number: 8080        
        subset: v1
```

Create the resources on kubernetes:

```sh
kubectl apply -f web-dr-vs-header.yaml -n mesh
```

Tests it is OK:

```sh
curl --header "Host: hello.wescale.fr" --header "allow-preview: true" http://$INGRESS_HOST:$INGRESS_PORT/:
```

## Clean

Delete all the created resources:

```sh
kubectl delete ns mesh istio-system
```
