# Access Kubernetes API with ServiceAccounts

Some applications that run in the cluster (read: running in pods) need to communicate with the API server.

For example, applications might need to know:

- The status of cluster nodes.
- Some configuration specified in custom K8s objects
- The list of existing namespaces
- Pods running in the cluster, or in a specific namespace.

This exercise aims to configure a ServiceAccount and accessing the API Server from inside a pod.

In case you need help during this exercise, you can refer to this [documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/).

## Inspect the default ServiceAccount

Each namespace has a default ServiceAccount.

- Verify this statement using the `kubectl get` command

```sh
training@bastion:~$ kubectl get sa --all-namespaces | grep default
 ```

- Create a secret called `default-sa` in the `application` namespace to generate a long-lived API token for the `default` ServiceAccount

```sh
apiVersion: v1
kind: Secret
metadata:
  name: default-sa
  namespace: application
  annotations:
    kubernetes.io/service-account.name: default
type: kubernetes.io/service-account-token
```

- Look inside the secret to see its content
  - There are several key/value pairs under the data key. The key that interests us is token:
    - `ca.crt` is the Base64 encoding of the cluster certificate.
    - `namespace` is the Base64 encoding of the current namespace.
    - `token` is the Base64 encoding of the JWT used to authenticate against the API server.

- Let’s focus on the token and try to decode it: use command line base64(or https://www.base64decode.org/) and https://jwt.io.

- Tak a look at the decoded payload:

```json
{
  "iss": "kubernetes/serviceaccount",
  "kubernetes.io/serviceaccount/namespace": "application",
  "kubernetes.io/serviceaccount/secret.name": "default-sa",
  "kubernetes.io/serviceaccount/service-account.name": "default",
  "kubernetes.io/serviceaccount/service-account.uid": "1798ba67-78e3-4cd7-9758-51fb5c7913d4",
  "sub": "system:serviceaccount:application:default"
}
 ```

> Note that having a long-lived token can become a security issue in case it is leaked. Hence, it is a security best practice to generat short-lived token to reduce the exposure.

- Create a short-lived token using the following command:

```sh
training@bastion:~$ kubectl create token default --duration=1h -n application
```

- Decode it again using the [jwt.io](https://jwt.io) website. Do you see a change compared to the long-lived token ?

> Yes we can see that the token format differs. The most noticeable change is the appearance of issued and expiration date of the token

```json
{
  "aud": [
    "https://kubernetes.default.svc.cluster.local"
  ],
  "exp": 1741084429,
  "iat": 1741080829,
  "iss": "https://kubernetes.default.svc.cluster.local",
  "jti": "78d76117-a178-4db9-b6f8-c276bdffb2bb",
  "kubernetes.io": {
    "namespace": "application",
    "serviceaccount": {
      "name": "default",
      "uid": "1798ba67-78e3-4cd7-9758-51fb5c7913d4"
    }
  },
  "nbf": 1741080829,
  "sub": "system:serviceaccount:application:default"
}
```

> As we have seen, the `default` ServiceAccount is used by default in pods when you don't specify a ServiceAccount explicitly

- Inspect the `front-admin` pod the verify this statement

```sh
training@bastion:~$ kubectl get po -l component=front-admin -o yaml -n application
```

> The `serviceAccountName` key is set with the name of the `default` ServiceAccount.

> The information of the ServiceAccount is mounted inside the container of the Pod, through the usage of a projected volume, in the `/var/run/secrets/kubernetes.io/serviceaccount` folder.

You will now request the API server from the `front-admin` pod using the `curl` command.

- Exec in the container using the `kubectl exec -it` command and try to retrieve information from the API server at the `https://kubernetes.default.svc/api/v1` endpoint. What do you notice ?

```sh
training@bastion:~$ export POD_NAME=$(kubectl get po -l component=front-admin -o json -n application | jq -r '.items[0].metadata.name')
training@bastion:~$ kubectl -n application exec -it $POD_NAME -- sh

$ curl -k https://kubernetes.default.svc/api/v1
# We are not authenticated and we don't have the rights to query the API Server
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "forbidden: User \"system:anonymous\" cannot get path \"/api/v1\"",
  "reason": "Forbidden",
  "details": {},
  "code": 403
}
```

- Do the same call using the ServiceAccount token bound to the pod in the `Authorization: Bearer` HTTP header

```sh
$ curl -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" -k https://kubernetes.default.svc/api/v1
# We can now list the API endpoints !
{
  "kind": "APIResourceList",
  "groupVersion": "v1",
  "resources": [
    {
      "name": "bindings",
      "singularName": "binding",
      "namespaced": true,
      "kind": "Binding",
      "verbs": [
        "create"
      ]
    },
...
}
```

- Try to you use this token to list all the Pods
  - Inside the `default` namespace: `https://kubernetes.default.svc/api/v1/namespaces/default/pods`
  - Inside the `application` namespace: `https://kubernetes.default.svc/api/v1/namespaces/application/pods`

- What do you notice ?

```sh
$ curl -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" -k https://kubernetes.default.svc/api/v1/namespaces/default/pods
# The default ServiceAccount does not have the rights to list pods in the defautl namespace
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "pods is forbidden: User \"system:serviceaccount:application:default\" cannot list resource \"pods\" in API group \"\" in the namespace \"default\"",
  "reason": "Forbidden",
  "details": {
    "kind": "pods"
  },
  "code": 403
}

$ curl -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" -k https://kubernetes.default.svc/api/v1/namespaces/application/pods
# Same for application namespace
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "pods is forbidden: User \"system:serviceaccount:application:default\" cannot list resource \"pods\" in API group \"\" in the namespace \"application\"",
  "reason": "Forbidden",
  "details": {
    "kind": "pods"
  },
  "code": 403
}
```

## Create a custom ServiceAccount

As said earlier this is not a best practice to use the `default` ServiceAccount if you intend to give it permissions since it is assigned by default to every pod in the namespace.

We will now create a custom ServiceAccount instead and give it permissions to request the API server.

- Create a Servce Account called `training-sa` in the `application` namespace

```sh
training@bastion:~$ kubectl create sa training-sa -n application
```

- A ServiceAccount is not that useful unless certain rights are bound to it. Define a Role allowing to list all the Pods in the `application` namespace. What kind of Role do you need ? Role or ClusterRole ?

> Role because we only want to list pods in a single namespace

- Create the Role in the `application` namespace

```sh
training@bastion:~$ kubectl apply -f training-role.yaml
```

- Bind the Role you've just created and the ServiceAccount created above

```sh
training@bastion:~$ kubectl apply -f training-rolebinding.yaml
```

- Edit the `front-admin` Deployment to specify the `training-sa` serviceAccount

```sh
training@bastion:~$ kubectl patch deploy/front-admin -p '{"spec": {"template": {"spec": {"serviceAccount": "training-sa"}}}}' -n application
```

- Connect to the new `front-admin` pod and try to list the pods using the ServiceAccount token:
  - List pods in the `application` namespace: `https://kubernetes.default.svc/api/v1/namespaces/application/pods`
  - List pods in the `default` namespace: `https://kubernetes.default.svc/api/v1/namespaces/default/pods`

```sh
training@bastion:~$ export POD_NAME=$(kubectl get po -l component=front-admin -o json -n application | jq -r '.items[0].metadata.name')
training@bastion:~$ kubectl -n application exec -it $POD_NAME -- sh

$ curl -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" -k https://kubernetes.default.svc/api/v1/namespaces/application/pods
# We can now list pods in the application namespace
{
  "kind": "PodList",
  "apiVersion": "v1",
  "metadata": {
    "resourceVersion": "23583"
  },
  "items": [
    {
...
}

$ curl -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" -k https://kubernetes.default.svc/api/v1/namespaces/default/pods
# But it still does not work for the default namespace which is normal this we only created a rolebinding in the application namespace
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "pods is forbidden: User \"system:serviceaccount:application:training-sa\" cannot list resource \"pods\" in API group \"\" in the namespace \"default\"",
  "reason": "Forbidden",
  "details": {
    "kind": "pods"
  },
  "code": 403
}
```

- What do you notice ? What is the solution to solve this ?

> Use a ClusterRole instead of a Role and create Rolebindings in the two namespaces to bind it to the ServiceAccount
