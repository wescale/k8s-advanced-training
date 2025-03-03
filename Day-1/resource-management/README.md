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

- Do you see any change on the deployed pods ? Why ?

- Force a new rollout of the `article-service` Deployment with the `kubectl rollout restart` command

- Take a look at the allocated resources and QoS class of the new pod. Are the values the ones we expect ?

- Now edit the `article-service` Deployment to add a **CPU limit** of **200 milicores** and a **memory limit** of **200 mebibytes**.

- What do you see as the QoS class? Why?

- Edit the `front-admin` Deployment to specify a **CPU request** of **100 milicores** and a **memory request** of **64 mebibytes**.

- What are the resources associated to the new pod ? And its QoS ? Why ?

## LimitRange to bind min/max limits

Now we are going to use our `LimitRange` object to specify min and max limits for resource allocation.

- Patch the existing `LimitRange` to set the following values:
  - **Min Memory** must 32Mi
  - **Min CPU** must be 0.1 core
  - **Max Memory** must 128Mi
  - **Max CPU** must be 0.3 core

- Force a new rollout of the `article-service` Deployment with the `kubectl rollout restart` command

- Do you see the new pod ? If not, investigate by looking at the `events` in the namespace

- If there is an issue, fix it to make the new pod running

## ResourceQuota to limit aggregate resource consumption per namespace

Finally, you will pay attention to the `ResourceQuota` object.

- Using the provided [resourcequota.yaml](./resourcequota.yaml) file, create a `ResourceQuota` resource with the following specs:
  - **Sum of CPU requests** for the namespace must be under 0.8 core
  - **Sum of Memory requests** for the namespace must be under 2Gi
  - **Sum of CPU limits** for the namespace must be under 1 core
  - **Sum of Memory limits** for the namespace must be under 3Gi

- Describe the resource you've just created and try to understand the output

- Increase the `front-admin` replica to **2**. Describe the resourcequota again and see if anything changes

- Suddently there is a huge load on the MongoDB database. To absorb the traffic, scale the `mongodb` StatefulSet to **3** replicas.

- Are new pods created ? If not investigate using the `kubectl events` command with the `--for` option.

- The load is gone, scale back to **1** replica.

## Cleanup

- **Delete the `LimitRange` and `ResourceQuota` objects to avoid problems during future exercises
