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
kubectl create token default -n wsc-kubernetes-training-sa --duration=1h
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

```sh
kubectl get po/pod-default -o yaml -n wsc-kubernetes-training-sa

result:
(...)
serviceAccount: default
serviceAccountName: default
volumes:
- name: kube-api-access-whdwz
  projected:
    defaultMode: 420
    sources:
    - serviceAccountToken:
        expirationSeconds: 3607
        path: token
(...)
  ```

The serviceAccountName key is set with the name of the default ServiceAccount.
The information of the ServiceAccount is mounted inside the container of the Pod, through the usage of volume, in /var/run/secrets/kubernetes.io/serviceaccount

```sh
kubectl exec -n wsc-kubernetes-training-sa -it pod-default -- sh
ls /var/run/secrets/kubernetes.io/serviceaccount
```

- Try from the container to get information from the API server (dns kubernetes.default.svc) without authentication.
  What do you notice ?

```sh
$ kubectl exec -n wsc-kubernetes-training-sa -it pod-default -- sh
# apk add --update curl
# curl https://kubernetes.default.svc/api/v1 --insecure

{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {

  },
  "status": "Failure",
  "message": "Unauthorized",
  "reason": "Unauthorized",
  "code": 401
}
```

- Try from the container to do the same call using the ServiceAccount token

```sh
$ kubectl exec -n wsc-kubernetes-training-sa -it pod-default -- sh
# TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
# curl -H "Authorization: Bearer $TOKEN" https://kubernetes.default.svc/api/v1/ --insecure

{
  "kind": "APIResourceList",
  "groupVersion": "v1",
  "resources": [
    {
      "name": "bindings",
      "singularName": "",
      "namespaced": true,
      "kind": "Binding",
      "verbs": [
        "create"
      ]
    },
   (...)
}
```

- Within your pod, try to you use this token to list all the Pods: https://kubernetes.default.svc/api/v1/default/pods
and https://kubernetes.default.svc/api/v1/wsc-kubernetes-training-sa/pods

 ```sh
# curl -H "Authorization: Bearer $TOKEN" https://kubernetes.default.svc/api/v1/default/pods --insecure

 "message": "wsc-kubernetes-training-sa \"pods\" is forbidden: User \"system:serviceaccount:default:default\" cannot get resource \"wsc-kubernetes-training-sa\" in API group \"\" at the cluster scope",

 # curl -H "Authorization: Bearer $TOKEN" https://kubernetes.default.svc/api/v1/wsc-kubernetes-training-sa/pods --insecure

  "message": "wsc-kubernetes-training-sa \"pods\" is forbidden: User \"system:serviceaccount:default:default\" cannot get resource \"wsc-kubernetes-training-sa\" in API group \"\" at the cluster scope",

 ```

 What do you notice ? > The default service account does not have enough rights to perform this query.
 => We will create our own ServiceAccount and provide it with the additional rights it needs for this action.

# Create a custom serviceaccount

- Create a the service Account training-sa

```sh
$ kubectl apply -f training-sa.yaml
serviceaccount/training-sa created
 ```

- A ServiceAccount is not that useful unless certain rights are bound to it. Defines a Role allowing to list all the Pods in the your namespace.

What kind of Role do you need ? Role or ClusterRole ?
> Role because, I just need to list all Pods in my namespace and not in others namespaces.


```sh
$ kubectl apply -f training-role-sa.yaml
role.rbac.authorization.k8s.io/list-pods created

$ kubectl get role -n wsc-kubernetes-training-sa
 ```

- Try to bind the Role and the ServiceAccount created above

```sh
$ kubectl apply -f training-role-binding-sa.yaml
$ kubectl get rolebinding -n wsc-kubernetes-training-sa
 ```

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

 ```sh
 $ kubectl exec -n wsc-kubernetes-training-sa -it pod-sa -- sh
# apk add --update curl
# TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
# curl -H "Authorization: Bearer $TOKEN" https://kubernetes.default.svc/api/v1/ --insecure
# curl -H "Authorization: Bearer $TOKEN" https://kubernetes.default.svc/api/v1/namespaces/wsc-kubernetes-training-sa/pods --insecure
# curl -H "Authorization: Bearer $TOKEN"  https://kubernetes.default.svc/api/v1/namespaces/default/pods --insecure
  ```
What do you notice when you call the api namespaces/default/pods ?
=> Yes got a reason Forbidden when call the api namespaces/default/pods

What is the solution to solve this ?
Creation of ClusterRole

