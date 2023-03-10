# exercise-6: Default limits and request with a LimitRange

In this exercise, you will create a new namespace and set LimitRange for this namespace.

Then, you will create 3 pods, each with or without requests and limits.

## Create a namespace

Create a namespace named `default-resources-config`.

## Create a LimitRange to specify default limits and requests

Inside this namespace, create a `LimitRange` named `default-requests-and-limits` which sets the followings default values:
* **Memory limit** must 64Mi
* **CPU limit** must be 0.2 core
* **Memory request** must 32Mi
* **CPU request** must be 0.1 core

For details about the LimitRange specification, use `kubectl explain` command or see the online documentation for your current Kubernetes version.

```
apiVersion: v1
kind: LimitRange
metadata:
  name: default-requests-and-limits
spec:
  limits:
  - default:
  ...
```
## Create a Deployment without resource specifications

Here is the file to use:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: no-res-spec
  namespace: default-resources-config
spec:
  selector:
    matchLabels:
      app: no-res-spec
  template:
    metadata:
      labels:
        app: no-res-spec
    spec:
      containers:
      - name: apache
        image: httpd:2.4
```

View the `QoS` class of the created pods and the resource requests/limits.

Are the values the ones we expected?

## Create a Deployment with only limits

```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: limit-only-spec
  namespace: default-resources-config
spec:
  selector:
    matchLabels:
      app: limit-only-spec
  template:
    metadata:
      labels:
        app: limit-only-spec
    spec:
      containers:
      - name: default-resources-cont
        image: httpd:2.4
        resources:
          limits:
            memory: "200Mi"
            cpu: 0.2
```

What do you see as QoS class?

Why?

## Create a Deployment with only requests

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: req-only-spec
  namespace: default-resources-config
spec:
  selector:
    matchLabels:
      app: req-only-spec
  template:
    metadata:
      labels:
        app: req-only-spec
    spec:
      containers:
      - name: default-resources-cont
        image: httpd:2.4
        resources:
          requests:
            memory: "64Mi"
            cpu: 0.2
```

What do you see as QoS class?

Why?

## Clean

```sh
kubectl delete namespace default-resources-config
```

## Your opinion

What values should you use for default limits and request?
