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

> As we have seen, the `default` ServiceAccount is used by default in pods when you don't specify a ServiceAccount explicitly

- Inspect the `front-admin` pod the verify this statement

> The `serviceAccountName` key is set with the name of the `default` ServiceAccount.

> The information of the ServiceAccount is mounted inside the container of the Pod, through the usage of a projected volume, in the `/var/run/secrets/kubernetes.io/serviceaccount` folder.

You will now request the API server from the `front-admin` pod using the `curl` command.

- Exec in the container using the `kubectl exec -it` command and try to retrieve information from the API server at the `https://kubernetes.default.svc/api/v1` endpoint. What do you notice ?

- Do the same call using the ServiceAccount token bound to the pod in the `Authorization: Bearer` HTTP header

- Try to you use this token to list all the Pods
  - Inside the default namespace: `https://kubernetes.default.svc/api/v1/namespaces/default/pods`
  - Inside the current namespace: `https://kubernetes.default.svc/api/v1/namespaces/wsc-kubernetes-training-sa/pods`

- What do you notice ?

## Create a custom ServiceAccount

As said earlier this is not a best practice to use the `default` ServiceAccount if you intend to give it permissions since it is assigned by default to every pod in the namespace.

We will now create a custom ServiceAccount instead and give it permissions to request the API server.

- Create a Servce Account called `training-sa` in the `application` namespace

- A ServiceAccount is not that useful unless certain rights are bound to it. Define a Role allowing to list all the Pods in the `application` namespace. What kind of Role do you need ? Role or ClusterRole ?

- Create the Role in the `application` namespace

- Bind the Role you've just created and the ServiceAccount created above

- Edit the `front-end` Deployment to specify the `training-sa` serviceAccount

- Connect to the new `front-end` pod and try to list the pods using the ServiceAccount token:
  - List pods in the `application` namespace: `https://kubernetes.default.svc/api/v1/namespaces/application/pods`
  - List pods in the `default` namespace: `https://kubernetes.default.svc/api/v1/namespaces/default/pods`

- What do you notice ? What is the solution to solve this ?
