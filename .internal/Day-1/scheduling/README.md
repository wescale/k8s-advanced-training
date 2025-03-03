# Scheduling

In this exercise, you will practice on several ways to have an influence on the scheduling of pods on nodes:

- Node selector
- Node and Pod Affinity/Anti-affinity
- Topology spread constraints

If you need help, you can refer to [this documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)

*Note: starting this exercise, we are going to need the other services of the microservices application. That's what we are going to deploy first.*

## Deploy the rest of the microservices application

As said above, we are the remaining services for our demo application. It is composed of three services: a `redis` database to store users' cart, a `cart-service` that saves users' articles and a `front-user` user interface for users to interact with the application.

You will now deploy these three components:

- Deploy the `redis`, `cart-service` and `front-user` services in the `application` namespace using the manifests in the current directory.

```sh
training@bastion:~$ kubectl apply -f redis
training@bastion:~$ kubectl apply -f cart-service
training@bastion:~$ kubectl apply -f front-user
```

- Once done, you should be able to access the user interface on your browser at the `demo.k8s-ops-X.wescaletraining.fr` endpoint. Try to add an article to your cart to see if it is working.

## Node Affinity

If you took a glimpse at the manifests you've just deployed, you may have noticed a new section that impacts the scheduling of pods.

- Check the status and location of the pods

```sh
training@bastion:~$ kubect get po -o wide -n application
```

- Can you explain what happened ?

> The `redis` pod is scheduled on worker-1.wescale.internal because there is a hard node affinity rule.

> The `cart-service` pod is scheduled on another node but not on worker-10.wescale.internal because such a node does not exist and the affinity rule is soft.

## Pod Affinity/Anti-affinity

### Coupled pods

Since the `article-service` and `mongodb` pods are tightely coupled, we are going to configure the `article-service` Deployment to be scheduled as closely as possible to the `mongodb` database.

On the contrary, we want the `article-service` to be as far as possible to the `front-admin` service.

- Take a look at where `mongodb` and `front-admin` pods are scheduled

```sh
training@bastion:~$ kubectl get po -o wide -n application
```

- Add both pod affinity and pod anti-affinity section to the `article-service` Deployment so that:
  - `article-service` pods **MUST** be on the same node than `mongodb` pods
  - `article-service` pods **should** be on a different node than `front-admin` pods

```sh
    ...
    affinity:
      podAffinity:
        #SET TYPE HERE#:
        - labelSelector:
            matchExpressions:
            - key: #SET VALUE HERE#
              operator: In
              values:
              - #SET VALUE HERE#
          topologyKey: #SET KEY HERE#
      podAntiAffinity:
        #SET TYPE HERE#:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
              - key: #SET VALUE HERE#
                operator: In
                values:
                - #SET VALUE HERE#
            topologyKey: #SET KEY HERE#
    ...
```

```sh
training@bastion:~$ kubectl apply -f article-service-deployment.yaml
```

- Try to predict where this pod will be scheduled

- Check the status and location of the pod

```sh
training@bastion:~$ kubectl get pods -o wide -n application
```

- Can you explain what happened ?

> This will depend on where the pods are scheduled at first

### Distribute replicas on multiple failure domains

As it is the component interacting directly with our clients, the `front-user` service can be considered as important. Consequently, we need to increase its number of replicas and make sure that each of them is scheduled on a unique failure domain.

To do that, we are going to use pod anti-affinity to distribute replicas on multiple failure domains:

- Increase the number of replicas of the `front-user` Deployment to `3`

```sh
training@bastion:~$ kubectl scale deploy/front-user --replicas 3 -n application
```

- Make sure you have correctly labeled your nodes with a `zone` label

```sh
training@bastion:~$ kubectl get nodes --show-labels
```

- Add a `podAntiAffinity` section in the `front-user` Deployment to avoid the replicas in the same zone

```sh
    ...
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
    ...
```

```sh
training@bastion:~$ kubectl apply -f front-user-deployment.yaml
```

- Check pods status

```sh
training@bastion:~$ kubectl get pods -o wide -l component=front-user -n application
```

- Can you explain what happened?

> One pod is not scheduled because we already have 3 running (1 from earlier deployment and 2 new ones) because of the default rolling strategy and that the rule is hard

- What will happen if you get 10 replicas?

> 7 replicas will be in `Pending` status

- What do you suggest as an improvement to have all pods scheduled ? Do the change and see what happens.

> Use `preferredDuringSchedulingIgnoredDuringExecution` and not `requiredDuringSchedulingIgnoredDuringExecution`

```sh
training@bastion:~$ kubectl apply -f front-user-deployment-preferred.yaml
```

## BONUS: Topology Spread Constraints

We can do ever better by splitting `front-user` replicas eavenly using *Topology Spread Constraints* to achieve high avaibility as well as efficient resource utilization.

- Update the `front-user` Deployment to scale to `5` replicas and add a `topologySpreadConstraints` section:

```sh
    ...
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
      ...
```

```sh
training@bastion:~$ kubectl apply -f front-user-deployment-constraint.yaml
```

- See where pods are scheduled:

```sh
training@bastion:~$ kubectl get pods -o wide -l component=front-user -n application
```

- Can you explain what happened ?

> Replicas will be as eavenly spread as possible. We will have 2 replicas on one node, 2 replicas on another one and the last replica on the third node.

- Does it look good to you?

> Yes
