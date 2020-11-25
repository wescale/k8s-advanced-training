# Hands-on: Scheduling

During this lab we will experience some scenarios of Pod scheduling constraints

## Node Affinity

Deploy 2 pods with node affinity one hard and one is soft
```sh
kubectl apply -f nodeaffinity.yaml
```

Check the status and location of the pods

```sh
kubectl get pods -owide
```

Can you explain what happened ?


## Pod Affinity/AntiAffinity 

First we deploy 4 pods, each pod is assigned to one node with a nodeSelector
```sh
kubectl apply -f podtest.yaml
```

See where the pods are deployed
```sh
kubectl get pods -l app=app0 -owide
kubectl get pods -l app=app1 -owide
```


Then we will deploy a pod with 2 constraints (PodAffinity and PodAntiAffinity)

```sh
kubectl apply -f podaffinity.yaml
```

Try to predict where this pod will be scheduled ?

Check the status and location of the pod

```sh
kubectl get pod pod-affinity-pod -o wide
```

Can you explain what happened ?

Then we will deploy an apache deployment with 3 replicas and a scheduling constraint

```sh
kubectl apply -f apache.yaml
```
Check pods status

```sh
kubectl get pods -l app=apache
```
Can you explain what happened ?


## Pod Topology Constraint

Deploy a deployment without topology constraints

```sh
kubectl apply -f no-constraint.yaml
```
See where the pods are scheduled
```sh
k get pods -l app=pause 
```

Update the deployment with topology constraints 

```sh
kubectl apply -f constraint.yaml
```
See where the pods are scheduled
```sh
k get pods -l app=pause 
```

Can you explain what happened ?

Delete all the created resources:
```sh
kubectl delete -f .
```