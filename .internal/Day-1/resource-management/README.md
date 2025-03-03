# Resource Management

In this exercise, you will take a look at `ResourceQuota` and `LimitRange` objects to see what they are used for, how to use them and what they imply for pods resource management.

Here are the documentation pages that can help you:

- [LimitRange](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [ResourceQuota](https://kubernetes.io/docs/concepts/policy/resource-quotas/)

## LimitRange for default resource allocation

First, let's focus on the `LimitRange` object.

- Inspect the resources allocated to each pod on the `application` namespace

- Inside the `application` namespace, create a `LimitRange` resource which sets the followings default values:
  - **Memory limit** must 64Mi
  - **CPU limit** must be 0.2 core
  - **Memory request** must 32Mi
  - **CPU request** must be 0.1 core

```sh
training@bastion:~$ kubectl apply -f limitrange-default.yaml
```

- Do you see any change on the deployed pods ? Why ?

> No, because LimitRange is applied only on resource creation

- Force a new rollout of the `article-service` Deployment with the `kubectl rollout restart` command

```sh
training@bastion:~$ kubectl rollout restart deploy/article-service -n application
```

- Take a look at the allocated resources and QoS class of the new pod. Are the values the ones we expect ?

> Yes the values specified in the LimitRange are set. The QoS is Burstable as intended

- Now edit the `article-service` Deployment to add a **CPU limit** of **200 milicores** and a **memory limit** of **200 mebibytes**.

- What do you see as the QoS class? Why?

> The QoS is Guarenteed because requests=limits. This is the default behaviour when only specifying limits

- Edit the `front-admin` Deployment to specify a **CPU request** of **100 milicores** and a **memory request** of **64 mebibytes**.

- What are the resources associated to the new pod ? And its QoS ? Why ?

> The limitRange has set the limits for the new pod. The pod is now Burstable

## LimitRange to bind min/max limits

Now we are going to use our `LimitRange` object to specify min and max limits for resource allocation.

- Patch the existing `LimitRange` to set the following values:
  - **Min Memory** must 32Mi
  - **Min CPU** must be 0.1 core
  - **Max Memory** must 128Mi
  - **Max CPU** must be 0.3 core

- Force a new rollout of the `article-service` Deployment with the `kubectl rollout restart` command

```sh
training@bastion:~$ kubectl rollout restart deploy/article-service -n application
```

- Do you see the new pod ? If not, investigate by looking at the `events` in the namespace

```sh
training@bastion:~$ kubectl events -n application | grep article-service
```

- If there is an issue, fix it to make the new pod running

```sh
# Memory limit is too high, we must reduce it back to 128Mi
training@bastion:~$ kubectl apply -f article-service-deployment-fix.yaml
```

## ResourceQuota to limit aggregate resource consumption per namespace

Finally, you will pay attention to the `ResourceQuota` object.

- Using the provided [resourcequota.yaml](./resourcequota.yaml) file, create a `ResourceQuota` resource with the following specs:
  - **Sum of CPU requests** for the namespace must be under 0.8 core
  - **Sum of Memory requests** for the namespace must be under 2Gi
  - **Sum of CPU limits** for the namespace must be under 1 core
  - **Sum of Memory limits** for the namespace must be under 3Gi

- Describe the resource you've just created and try to understand the output

> The `kubectl describe resourcequota` command show the current used resources compared to the hard limit set

- Increase the `front-admin` replica to **2**. Describe the resourcequota again and see if anything changes

```sh
# Scale the deployment
training@bastion:~$ kubectl scale deploy/front-admin --replicas 2 -n application
# Look for the second pod
training@bastion:~$ kubectl get po -n application -l component=front-admin
# Describe the resourcequota again. Used resources have increased
training@bastion:~$ kubectl describe resourcequota -n application
```

- Suddently there is a huge load on the MongoDB database. To absorb the traffic, scale the `mongodb` StatefulSet to **3** replicas.

```sh
training@bastion:~$ kubectl scale sts/mongodb --replicas 3 -n application
```

- Are new pods created ? If not investigate using the `kubectl events` command with the `--for` option.

```sh
# Watch for newly created pod
training@bastion:~$ kubectl get po -l component=mongodb -n application -w
# Nothing spawns, look for events on the StatefulSet
training@bastion:~$ kubectl events --for sts/mongodb -n application
...
18m (x18 over 29m)    Warning   FailedCreate       StatefulSet/mongodb   create Pod mongodb-1 in StatefulSet mongodb failed error: pods "mongodb-1" is forbidden: exceeded quota: resource-quota, requested: limits.cpu=300m, used: limits.cpu=900m, limited: limits.cpu=1
...
# We have reached the limit !
```

- The load is gone, scale back to **1** replica.

## Cleanup

- **Delete the `LimitRange` and `ResourceQuota` objects to avoid problems during future exercises

```sh
training@bastion:~$ kubectl delete limitrange limitrange -n application
training@bastion:~$ kubectl delete resourcequota resource-quota -n application
```
