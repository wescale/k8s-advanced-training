This exercice aims to  configure the cluster kubernetes through OIDC(OpenID Connect) to authenticate and authorize using google account.

# Create OAuth Client in Google & modify the api-server of the Kube

 - You don't need to do this step. It's already done. Ask the trainer for the Client-id and client-secret.
 Go to https://console.cloud.google.com/apis/credentials and create the Client ID, and Secret. While creating the Client ID, select the app type as Desktop App. Once generated, download the JSON file.

- Modify /home/training/cluster.yml to add the idp details:

```sh
services:
  kube-api:
    extra_args:
      oidc-issuer-url: "https://accounts.google.com"
      oidc-username-claim: "email"
      oidc-client-id: "<client-id>"
```

- Try apply your modification, do rke up and check if the cluster is still up.

```sh
kubectl get nodes
```

- We need to authenticate the user from kubectl. We will take the help of k8s-oidc-helper to generate a token and the same token can be pasted in the console to generate the .kube config for our user:

```sh
./k8s-oidc-helper --client-id xxx   --client-secret xxx   --write=true
```

Google will generate the code and this has to be copied in the console.
One copied, we will get a new user added automatically in .kube/config file. 

Can you verify this ?

- Now we can see that the user is getting authenticated, now it needs authorization. For that, we need to create a cluster role that can do everything in all k8s ressources.

- Create a ClusterRoleBinding to attach the clusterRole to your user
- Try to access the cluster using the new user (option --user)