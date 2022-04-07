# Hands-on: Scheduling

During this lab we will experience some scenarios of Pod scheduling constraints

First, start by creating a namespace `scheduling`.
## Node Affinity

Deploy 2 pods with node affinity one hard and one is soft
```sh
kubectl apply -f nodeaffinity.yaml -n scheduling
```

Check the status and location of the pods

```sh
kubectl get pods -owide  -n scheduling
```

Can you explain what happened ?


## Pod Affinity/AntiAffinity 

### Coupled pods

First we deploy 4 pods. In fact, those 4 pods are  2 pairs each, with a specific value for the label `app`.

Each pod is assigned to one node with a nodeSelector
```sh
kubectl apply -f podtest.yaml
```

See where the pods are deployed
```sh
kubectl get pods -l app=app0 -owide  -n scheduling
kubectl get pods -l app=app1 -owide  -n scheduling
```

Then we will deploy a pod which must be 
* close to the app0 pods - same node
* far from the app1 pods - different node

To do that, we propose to use pod affinity and pod anti-affinity.

What is the topology key you must use?

Complete the pod definition below:
```sh
apiVersion: v1
kind: Pod
metadata:
  name: pod-affinity-pod
  namespace: scheduling
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: #SET VALUE HERE#
            operator: In
            values:
            - #SET VALUE HERE#
        topologyKey: #SET KEY HERE#
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: #SET VALUE HERE#
              operator: In
              values:
              - #SET VALUE HERE#
          topologyKey: #SET KEY HERE#
  containers:
  - name: with-pod-affinity
    image: k8s.gcr.io/pause:2.0
```

Try to predict where this pod will be scheduled ?

Check the status and location of the pod

```sh
kubectl get pod pod-affinity-pod -o wide -n scheduling
```

Can you explain what happened ?

### Distribute replicas on failure domains

Then we will deploy Apache pods with 4 replicas and a scheduling constraint.

We use pod anti affinity to avoid getting the replicas inside the same failure domain.

Ensure you get a label named `zone` on your nodes.
```sh
kubectl get nodes --show-labels
```

Then complete the pod definition to avoid getting all the replicas on the same zone:
```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpd
  namespace: scheduling
spec:
  selector:
    matchLabels:
      app: apache
  replicas: 4
  template:
    metadata:
      labels:
        app: apache
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: #SET VALUE HERE#
                operator: In
                values:
                - #SET VALUE HERE#
            topologyKey: #SET KEY HERE#
      containers:
      - name: httpd
        image: httpd
```
Check pods status

```sh
kubectl get pods -l app=apache  -n scheduling
```
Can you explain what happened?

What do you suggest as an improvement?

What will happen if you get 10 replicas?

## Pod Topology Constraint

Finally, we want to mix topology spread and pod anti-affinity constraints.

Update the deployment with topology constraints 

```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pod-topology
  namespace: scheduling
spec:
  selector:
    matchLabels:
      app: pause
  replicas: 5
  template:
    metadata:
      labels:
        app: pause
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: #FAILURE DOMAIN KEY#
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: #POD LABEL KEY USED TO DISTRIBUTE#      
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: #POD LABEL KEY USED TO DISTRIBUTE#      
                  operator: In
                  values:
                  - #POD LABEL VALUE USED TO DISTRIBUTE#      
              topologyKey: #NODE level DOMAIN KEY#
      containers:
      - name: pod-topology
        image: k8s.gcr.io/pause:3.1
```


See where the pods are scheduled
```sh
kubectl get pods -l app=pause -n scheduling
```

Can you explain what happened ?
Does it look good to you?

## Clean

Delete all the created resources:
```sh
kubectl delete ns scheduling
```