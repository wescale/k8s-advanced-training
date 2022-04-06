# exercise-7: Limits per container and inside a namespace

In this exercise, you will see how to control the maximum resource used in a namspace:
* LimitRange to define limits per container
* ResourceQuota to define limits inside the whole namespace

## Start by creating a namespace

Create a namespace named `resource-constraints-demo`.

## Create a LimitRange to bound the min/max limits


Inside this namespace, create a `LimitRange` named `resource-constraints-lr` which sets the followings lower/upper limits:
* **Memory min** must 32Mi
* **CPU min** must be 0.1 core
* **Memory max** must 128Gi
* **CPU max** must be 0.3 core

For details about the LimitRange specification, use `kubectl explain` command or see the online documentation for your current Kubernetes version.

```
apiVersion: apps/v1
kind: LimitRange
metadata:
  name: resource-constraints-lr
spec:
  limits:
  - max:
  ...
```

## Create a pod matching the LimitRange

Its resources must be:
* limits:
  * Memory 96Mi
  * Cpu: 0.3
* requests:
  * Memory: 64Mi
  * Cpu: 0.2


```sh
apiVersion: v1
kind: Pod
metadata:
  name: resource-constraints-pod
  namespace: resource-constraints-demo
spec:
  containers:
  - name: resource-constraints-ctr
    image: httpd:2.4
    resources:
      ...
```


## Create pod outside the boundaries of the LimitRange
```sh
kubectl create -f resource-constraints-pod-2.yaml --namespace resource-constraints-demo
```

What happened?

## Create a new namespace 

Create a namespace named `resource-quota-demo`.

## Create a ResourceQuota

Inside this namespace, create a ResourceQuota named `resource-quota` with the following specs:
* Sum of CPU requests for the namespace must under 1.4 core
* Sum of Memory requests for the namespace must under 2Gi
* Sum of CPU limits for the namespace must under 2 cores
* Sum of Memory limits for the namespace must under 3Gi


```
apiVersion: v1
kind: ResourceQuota
metadata:
  name: resource-quota
  namespace: resource-quota-demo
spec:
  hard:
    ...
```

Get the current ResourceQuota usage:
```sh
kubectl get resourcequota --namespace resource-quota-demo
```

## Create a first pod inside the namespace with resource quota

```
kubectl create -f resource-quota-pod-1.yaml --namespace resource-quota-demo
```

## Create a second pod inside the namespace with resource quota
```
kubectl create -f resource-quota-pod-2.yaml --namespace resource-quota-demo
```

What happens?

## Try to create deployment with similar resource values

```
kubectl create -f resource-quota-deploy.yaml --namespace resource-quota-demo
```

Is it accepted? Why?

## Clean
```
kubectl delete namespace resource-constraints-demo
kubectl delete namespace resource-quota-demo
```