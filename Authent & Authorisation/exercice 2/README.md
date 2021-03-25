This exercice aims to configure the cluster API server to use OpenIDConnect (OIDC) tokens for user authentication.

As indicated in the following schema, Kubernetes does not perform the OIDC authentication flow of the end-user.
It just validates the given tokens and eventually refresh them if needed.

![oidc-flow](./oidc-flow.png)

For the exercise, you will use the identity provider [https://auth0.com/](https://auth0.com/).
This SaaS is a standard solution to manage user federation.
It is compliant with several protocols ; in particular with OIDC.
# Create users

 - You don't need to do this step. It's already done. Ask the trainer for a login / password of a user existing on the Auth0 domain used for the exercise.

# Enable the OIDC plugin on the api-server

- Modify /home/training/cluster.yml to add the idp details:

```sh
services:
  kube-api:
    extra_args:
      oidc-issuer-url: "https://dev-wexm65ih.eu.auth0.com/"
      oidc-username-claim: "email"
      oidc-client-id: "HQHSoQZzPW20rrVXWj8MquFdCCJsmLvM"
```

- Try to apply your modification, do `rke up` and check if the cluster is still up.

```sh
kubectl get nodes
```

- We need to authenticate the user from kubectl. We will take the help of `k8s-auth-client-helper.sh` to generate tokens and configure kubectl for our user. To run, the helper needs a local file `oidc.k8s-auth-client`. Ask the trainer to provide it.

```sh
./k8s-auth-client-helper.sh
```

Auth0 will generate a code this has to be copied in the console.
One copied, we will get a new entry `oidc-user` in the `users` section of the `.kube/config` file. 

Can you verify this ?

- Try to list the nodes of the cluster using the new `oidc-user` user (option --user)

- We can see that the user is getting authenticated but he needs authorization. For that, create a cluster role that can do everything in all k8s ressources.

- Create a ClusterRoleBinding to attach the clusterRole to your user
- Try to list the nodes of the cluster using the new user (option --user)

Are you satisfied with this configuration?
What could you improve?