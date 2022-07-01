This exercice aims to configure a ServiceAccount for Pods and accessing the API Server From a Pod

A lot of applications that run in the cluster (read: running in Pods), need to communicate with the API server.
For example, some applications might need to know:

- The status of the cluster’s nodes.
- The namespaces available.
- The Pods running in the cluster, or in a specific namespace.
...

# Create a namespace and inspect default serviceaccount

- Create the namespace `wsc-kubernetes-training-sa`
- Each namespace has a default ServiceAccount, named `default`. Can you verify this for your namespace ?

```sh
kubectl get sa --all-namespaces | grep default
 ```

- Let’s inspect the ServiceAccount named `default` for your namespace

```sh
kubectl get sa default -n wsc-kubernetes-training-sa -o yaml
 ```

- We can see here that a Secret is provided to this ServiceAccount. Let’s have a closer look at this one 

```sh
kubectl get secret <name token> -n wsc-kubernetes-training-sa -o yaml
 ```

There are several key/value pairs under the data key of this Secret. The key that interests us is token:

- ca.crt is the Base64 encoding of the cluster certificate.
- namespace is the Base64 encoding of the current namespace.
- token is the Base64 encoding of the JWT used to authenticate against the API server.

Let’s focus on the token and try to decode it: use command line base64(or https://www.base64decode.org/) and jwt.io. 
Look on the payload:

```sh
{
  "iss": "kubernetes/serviceaccount",
  "kubernetes.io/serviceaccount/namespace": "wsc-kubernetes-training-sa",
  "kubernetes.io/serviceaccount/secret.name": "default-token-jpzfm",
  "kubernetes.io/serviceaccount/service-account.name": "default",
  "kubernetes.io/serviceaccount/service-account.uid": "e8125353-bf49-4a41-b687-f32a79d77770",
  "sub": "system:serviceaccount:wsc-kubernetes-training-sa:default"
}
 ```

How to use this default token from within a simple Pod: 

- Create a new Pod in your namespace 

```sh
apiVersion: v1
kind: Pod
metadata:
  name: pod-default
  namespace: wsc-kubernetes-training-sa
spec:
  containers:
  - name: alpine
    image: alpine:3.9
    command:
      - "sleep"
      - "10000"
```

```sh
kubectl apply -n wsc-kubernetes-training-sa -f pod-default.yaml
  ```

- Verify that the same default sa is used 

The serviceAccountName key is set with the name of the default ServiceAccount.
The information of the ServiceAccount is mounted inside the container of the Pod, through the usage of volume, in `/var/run/secrets/kubernetes.io/serviceaccount`

You will request the API server from the pod. For that, use `wget` or `curl` (to install `curl`, run: `apk update && apt install curl`).

- Try from the container to get information from the API server (endpoint: `https://kubernetes.default.svc/api/v1`) without authentication.
  What do you notice ?

- Try from the container to do the same call using the ServiceAccount token

- Try to you use this token to list all the Pods 
  - inside the default namespace: https://kubernetes.default.svc/api/v1/namespaces/default/pods
  - inside the current namespace: https://kubernetes.default.svc/api/v1/namespaces/wsc-kubernetes-training-sa/pods

What do you notice ?

# Create a custom serviceaccount

- Create a the service Account training-sa in your namespace

- A ServiceAccount is not that useful unless certain rights are bound to it. Defines a Role allowing to list all the Pods in the your namespace.

What kind of Role do you need ? Role ou ClusterRole ?

- Try to create the Role in your namespace with good rules and verify that it's created

- Try to bind the Role and the ServiceAccount created above

- Create a new pod in your namespace using the ServiceAccount within a Pod 

```sh
apiVersion: v1
kind: Pod
metadata:
  name: pod-sa
  namespace: wsc-kubernetes-training-sa
spec:
  serviceAccountName: training-sa
  containers:
  - name: alpine
    image: alpine:3.9
    command:
     - "sleep"
     - "10000"
```

- Within your namespace, inside the new Pod, try to you use the token for your new sa to list all the Pods:  https://kubernetes.default.svc/api/v1/namespaces/wsc-kubernetes-training-sa/pods and 
 https://kubernetes.default.svc/api/v1/namespaces/default/pods
 
What do you notice when you call the api namespaces/default/pods ?
What is the solution to solve this ?

