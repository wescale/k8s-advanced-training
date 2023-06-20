This exercise aims to configure a ServiceAccount for Pods and accessing the API Server From a Pod

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

- Create a secret in the `wsc-kubernetes-training-sa` namespace with a token for the `default` service account
```sh
apiVersion: v1
kind: Secret
metadata:
  name: default-sa
  namespace: wsc-kubernetes-training-sa
  annotations:
    kubernetes.io/service-account.name: default
type: kubernetes.io/service-account-token
```

Look inside the secret to see its content.

There are several key/value pairs under the data key. The key that interests us is token:

- ca.crt is the Base64 encoding of the cluster certificate.
- namespace is the Base64 encoding of the current namespace.
- token is the Base64 encoding of the JWT used to authenticate against the API server.

Let’s focus on the token and try to decode it: use command line base64(or https://www.base64decode.org/) and https://jwt.io. 
Look on the payload:

```sh
{
  "aud": [
    "unknown"
  ],
  "exp": 1678723772,
  "iat": 1678720172,
  "iss": "rke",
  "kubernetes.io": {
    "namespace": "default",
    "serviceaccount": {
      "name": "default",
      "uid": "736679dd-3cb1-4d94-9e67-db61db763ec3"
    }
  },
  "nbf": 1678720172,
  "sub": "system:serviceaccount:default:default"
}
 ```


**Note that it's a security best practice to generate short lived token with the following command**
```sh
kubectl create token default --duration=1h
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

- Verify that the same default sa is used 

The serviceAccountName key is set with the name of the `default` ServiceAccount.
The information of the ServiceAccount is mounted inside the container of the Pod, through the usage of a projected volume, in the `/var/run/secrets/kubernetes.io/serviceaccount` folder.

You will request the API server from the pod. For that, use `wget` or `curl` (to install `curl`, run: `apk update && apk add curl`).

- Try from the container to get information from the API server (endpoint: `https://kubernetes.default.svc/api/v1`) without authentication.
  What do you notice ?

- Try from the container to do the same call using the ServiceAccount token in the `Authorization: Bearer` HTTP header

- Try to you use this token to list all the Pods 
  - inside the default namespace: https://kubernetes.default.svc/api/v1/namespaces/default/pods
  - inside the current namespace: https://kubernetes.default.svc/api/v1/namespaces/wsc-kubernetes-training-sa/pods

What do you notice ?

# Create a custom serviceaccount

- Create a the service Account training-sa in your namespace

- A ServiceAccount is not that useful unless certain rights are bound to it. Defines a Role allowing to list all the Pods in the your namespace.

What kind of Role do you need ? Role or ClusterRole ?

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

- Delete the namespace `wsc-kubernetes-training-sa`

