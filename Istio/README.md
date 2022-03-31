# Hands-on: Istio

Istio hand-on


## Installing Istio
```sh
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.8.0 TARGET_ARCH=x86_64 sh -
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
We will deploy nginx and apache in the cluster and use Istio traffic management to reach those services

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

If we inspect the pods we will see that there are 2 containers inside each pod, an envoy side car was injected (Istio Mutating admission controller)

```sh
kubectl describe pod nginx-xxxx -n mesh
kubectl describe pod apache-xxxx -n mesh
```



Now we will expose our deployment through the ingress gateway:
Create the http gateway
```sh
kubectl apply -f gateway.yaml -n istio-system
```
Create the virtual service:
```sh
kubectl apply -f web-vs-path.yaml -n mesh
```
Note that the virtual service is routing based on path and setting a header on response depending on the route

To access the service we need to get the ingress-gateway NodeIP and port
```sh
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
# Replace X with your environment
export INGRESS_HOST=lb.wsc-kubernetes-adv-training-X.wescaletraining.fr
```
Accessing services
```sh
curl http://$INGRESS_HOST:$INGRESS_PORT/nginx -v
curl http://$INGRESS_HOST:$INGRESS_PORT/apache -v
```

## Fault injection

Now we will test failure injection, to do so we will inject a delay of 7s on nginx
```sh
kubectl apply -f web-vs-delay.yaml -n mesh
```

Curl nginx service, its taking 7s to respond

## Canary release
We will deploy 2 versions of hello app
```sh
kubectl apply -f hello-app.yaml -n mesh
```
Then we create a VirtualService and DestinationRule to achieve canary deployment
```sh
kubectl apply -f web-dr-vs-canary.yaml -n mesh
```
The virtual service routes traffic based on host header, to test the canary release execute several times:
```sh
curl --header "Host: hello.wescale.fr" http://$INGRESS_HOST:$INGRESS_PORT/
```
90% of traffic is going to version 1 and the remaining 10% is going to version 2

## Observability

For a full observability stack, intall: Prometheus, Kiali, Grafana and Jaeger
```sh
kubectl apply -f prometheus.yaml
kubectl apply -f kiali.yaml
kubectl apply -f grafana.yaml
kubectk apply -f  https://raw.githubusercontent.com/istio/istio/release-1.8/samples/addons/jaeger.yaml
```

Deploy [bookinfo app](https://istio.io/latest/docs/examples/bookinfo/) 
```sh
kubectl apply -f bookinfo.yaml -n mesh
```

Deploy bookinfo VirtualService
```sh
kubectl apply -f bookinfo-vs.yaml -n mesh
```

Generate traffic 
```sh
watch -n 1 curl -o /dev/null -s -w %{http_code} http://$INGRESS_HOST:$INGRESS_PORT/productpage
```


Visualize traffic graph with kiali (replace x with your trainee index)

http://lb.wsc-kubernetes-adv-training-x.wescaletraining.fr:30672/kiali/console/graph/namespaces/?edges=responseTime&graphType=versionedApp&unusedNodes=false&operationNodes=false&injectServiceNodes=true&duration=60&refresh=10000&namespaces=mesh&layout=dagre


Multiple graphs are available on grafana explore them

http://lb.wsc-kubernetes-adv-training-x.wescaletraining.fr:31717/d/LJ_uJAvmk/istio-service-dashboard?orgId=1&refresh=1m&var-datasource=default&var-service=productpage.mesh.svc.cluster.local&var-srcns=All&var-srcwl=All&var-dstns=All&var-dstwl=All



Delete all the created resources:
```sh
kubectl delete ns mesh istio-system
```