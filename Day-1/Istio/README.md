# exercise: Istio

Istio hand-on


## Installing Istio
```sh
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.8.0
export PATH=$PWD/bin:$PATH
istioctl install --set profile=default -y
```

Check istio is running:
```sh
kubectl get pods -n istio-system
NAME                                    READY   STATUS    RESTARTS   AGE
istio-ingressgateway-7d47447b67-r2scr   1/1     Running   0          60s
istiod-66bb7cb55c-59cvh                 1/1     Running   0          75s
```

## HTTP routing with istio
We will deploy ngninx and apache in the cluster and use Istio traffic management to reach those services

First we will create a namespace called "mesh" and add the appropriate label to enable envoy sidecar injection
```sh
kubectl create ns mesh
kubectl label namespace mesh istio-injection=enabled
```

First we deploy the 2 apps (nginx & apache)

Deploy nginx (deployment and service):
```sh
kubectl apply -f nginx.yaml -n mesh
```
Deploy apache (deployment and service):
```sh
kubectl apply -f apache.yaml -n mesh
```

If we get the pods we will see that there 2 containers, an envoy side car was injected

Now we will expose our deployment throug the ingress gateway:
Create the http gateway
```sh
kubectl apply -f gateway.yaml -n istio-system
```
Create the virtual service:
```sh
kubectl apply -f web-vs-path.yaml -n mesh
```
Note that the virtual service is routing based on path and setting a header
To access the service we need to get the ingress-gateway IP
```sh
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```
Accessing services
```sh
curl http://$INGRESS_HOST/nginx -I -v
curl  http://$INGRESS_HOST/apache -I -v
```

## Fault injection

Now we will test failure injection, to do so we will inject a delay of 7s on ngnix
```sh
kubectl apply -f web-vs-delay.yaml -n mesh
```

Curl nginx service, its taking 7s to respond

## Canary release
We will deploy 2 version of hello app
```sh
kubectl apply -f hello-app.yaml -n mesh
```
Then we create a VirtualService and DestinationRule to achieve canary deployment
```sh
kubectl apply -f web-dr-vs-canary.yaml -n mesh
```
The virtual service routes trafic based on host header, to test the canary release in a browser you need to edit /etc/hosts and add:
```sh
<INGRESS_HOST> hello.wescale.fr
```
90% of trafic is going to version 1 and the remaining 10% is going to version 2

## Observability
Intall Prometheus
```sh
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/addons/prometheus.yaml
```
Install Kiali
```sh
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/addons/kiali.yaml
```
Install Grafana
```sh
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/addons/grafana.yaml
```

Deploy bookinfo app
```sh
kubectl apply -f bookinfo.yaml -n mesh
```

Deploy bookinfo app
```sh
kubectl apply -f bookinfo-vs.yaml -n mesh
```

Generate trafic 
```sh
watch -n 1 curl -o /dev/null -s -w %{http_code} $GATEWAY_URL/productpage
```

Observe with Kiali

```sh
istioctl dashboard kiali
```

Visualise trafic graph

http://localhost:62314/kiali/console/graph/namespaces/?edges=noEdgeLabels&graphType=versionedApp&unusedNodes=false&operationNodes=false&injectServiceNodes=true&duration=60&refresh=10000&namespaces=mesh&layout=dagre

Observe with Grafana

```sh
istioctl dashboard grafana
```

Multiple graphs are available 