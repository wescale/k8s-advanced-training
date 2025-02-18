# Hands-on: Istio advanced

Once Istio will be installed, you will deploy a web application, then configure Istio to validate JWT for a specific endpoint.

Then you will see how Istio and Jaeger can provide powerfull observability for a micro service oriented application.

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

* an `ingressgateway` to manage incoming traffic to the cluster. Similar to an ingress controller.
* `istiod` which is the istio control plane.

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

## Deploy the application

Create a **mesh** namespace with the `istio-injection=enabled` label.

Then deploy the [bookinfo app](https://istio.io/latest/docs/examples/bookinfo/). It has several deployments: `/productpage`, `/static`, `login`, `logout` and `/api/v1/products`.

```sh
kubectl apply -f bookinfo.yaml -n mesh
```

Because the **mesh** namespace has a `istio-injection=enabled` label, the bookinfo deployment are part of the istio service mesh.

## Securing an endpoint with JWT

### Validate JWT token signature

Now, in the **istio-system** namespace, you will create a `RequestAuthentication` resource to validate JWT tokens.

To avoid deploying an Identity provider, you will use an example JWT token signed by an example key, all coming from the Istio examples git repository.

```yaml
apiVersion:  security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: ingress-jwt
spec:
  selector: {}
  jwtRules:
  - issuer: "testing@secure.istio.io"
    jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.17/security/tools/jwt/samples/jwks.json"
```

Execute:

```sh
kubectl apply -f request-authent.yml -n istio-system
```

At this stage, you have enabled the validation of JWT tokens for all workloads on the cluster. A token not signed by "https://raw.githubusercontent.com/istio/istio/release-1.17/security/tools/jwt/samples/jwks.json" will lead to a '401 Unauthorized' error. You could use a selector to restrict this validation to specific namespaces or workload.

Yet, you did not require the presence of a valid JWT token on requests. If you omit the token, your request may be served, depending on the match.

### Require the presence of valid JWT claim

To secure your application, you will require a JWT token must contain **group1** in its **groups** claim before routing to `/productpage`.

Edit the given [secured-vs.yaml](./secured-vs.yaml) file:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: secured-bookinfo
spec:
  hosts:
    - "*"
  gateways:
    - istio-system/http-gateway
  http:
    - match:
        - uri:
            exact: /productpage
          headers:
            # "@request.auth" is populated by a `RequestAuthentication`.
            "@request.auth.claims.groups":
              # Must complete the expected value
              exact: COMPLETE_VALUE
        - uri:
            prefix: /static
        - uri:
            exact: /login
        - uri:
            exact: /logout
        - uri:
            prefix: /api/v1/products
      route:
        - destination:
            host: productpage
            port:
              number: 9080
```

Create the VirtualService:

```sh
kubectl apply -f secured-vs.yaml -n mesh
```

### Time to test

To access the service you need to get the ingress-gateway NodeIP and port:

```sh
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
# Replace X with your environment
export INGRESS_HOST=lb.k8s-ops-X.wescaletraining.fr
```

Call the `/productpage` endpoint with no JWT token. You will get a `404 Not Found`, as there is no match:

```sh
curl -v http://$INGRESS_HOST:$INGRESS_PORT/productpage
```

Call the `/productpage` endpoint with an invalid JWT token. You will get a `401 Unauthorized`, as the JWT token is invalid:

```sh
curl -v http://$INGRESS_HOST:$INGRESS_PORT/productpage  -H "Authorization: Bearer some.invalid.token"
```

Call the `/productpage` endpoint with an valid JWT token. You will get a `200`:

```sh
TOKEN_GROUP=$(curl https://raw.githubusercontent.com/istio/istio/release-1.17/security/tools/jwt/samples/groups-scope.jwt -s) && echo "$TOKEN_GROUP" | cut -d '.' -f2 - | base64 -d
curl -v http://$INGRESS_HOST:$INGRESS_PORT/productpage -H "Authorization: Bearer $TOKEN_GROUP"
```

### Clean

```sh
kubectl delete -f request-authent.yml -n istio-system
kubectl delete -f secured-vs.yaml -n mesh
```

## Observability

For a full observability stack, install: Prometheus, Kiali, Grafana and Jaeger addons.

Istio addons are shortcut to install components in a **demo** way.

```sh
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.16/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.16/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.16/samples/addons/kiali.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.16/samples/addons/jaeger.yaml
```

Deploy a basic VirtualService to expose the application with Istio:

```sh
kubectl apply -f bookinfo-vs.yaml -n mesh
```

Generate some traffic opening your browser on: <http://$INGRESS_HOST:$INGRESS_PORT/productpage#>

### Kiali

Kiali is a specific UI to see service graphs of an Istio mesh and interact with Istio resources.

The bookinfo app is not instrumented for tracing. Yet, thanks to the use of Istio and the deployment of Jaeger, you can get a view of the calls and dependencies between your services.

Start the Kiali proxy:

```sh
istioctl dashboard kiali --address 0.0.0.0 --browser=false --port 20001 &
```

Note the proxy port then open a browser for Kiali on (replace x with your trainee index):

```sh
echo -e "Open in your web browser:\nhttp://${BASTION_HOST}:20001/kiali/"
```

You can view the graph of services for the **mesh** namespace:

```sh
echo -e "http://${BASTION_HOST}:20001/kiali/console/graph/namespaces/?duration=1800&refresh=60000&namespaces=mesh&traffic=grpc%2CgrpcRequest%2Chttp%2ChttpRequest%2Ctcp%2CtcpSent&graphType=versionedApp&layout=kiali-dagre&namespaceLayout=kiali-dagre"
```

You can view the list of services for the **mesh** namespace:

```sh
echo -e "http://${BASTION_HOST}:20001/kiali/console/services?duration=1800&refresh=60000&namespaces=mesh"
```

If you click on an service, you will see many indicators like RPS, duration or size.

### Other addons

Istio provides easy integrations with Prometheus and Grafana.

```sh
istioctl dashboard grafana --address 0.0.0.0 --browser=false --port 20002 &
# Open http://${BASTION_HOST}:20002
```

```sh
istioctl dashboard prometheus --address 0.0.0.0 --browser=false --port 20003 &
# Open http://${BASTION_HOST}:20003
```

## Clean

Delete all the created resources:

```sh
kubectl delete ns mesh istio-system
```
