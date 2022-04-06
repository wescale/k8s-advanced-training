# Preemption with PriorityClasses

In this exercise, you will see how PriorityClasses control eviction of pods to ensure critical components are always running.

## Start by creating a namespace

Create a namespace named `pc-demo`.

## Create a priority Class

First, we need to choose a value for our class. 
Inspect the existing priority classes then choose a reasonable value **below** the current critical classes.

Once you get a value, create the PriorityClass:
```sh
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: test-pc
globalDefault: false
...
```

## Deploy pods without priority class
Indicate basic resource consumption

```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deploy
spec:
  selector:
    matchLabels:
      app: test-deploy
  template:
    metadata:
      labels:
        app: test-deploy
    spec:
      containers:
      - name: default-resources-cont
        image: httpd:2.4
        resources:
          limits:
            memory: "64Mi"
            cpu: 0.1
          requests:
            memory: "64Mi"
            cpu: 0.1
```

```sh
kubectl apply -f resource-quota-deploy.yaml
```

You should see your pod.
Scale the deployment to 10 replicas.

## Deploy pods with a priority class

Create a new deployment file using the `resource-quota-deploy.yaml` as a reference.
Indicate the priority class `test-pc` in the pod spec.
Hint: remember to change the selector in your new deployment to avoid conflict with `test-deploy`
```

Create the deployment on kubernetes. Is your pod running?
Now scale your new deployment to 10 pods. Are they running?

## Clean

Delete the priority class and all the deployments in the `default` namespace.