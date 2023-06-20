This exercise aims to configure the cluster API server to use OpenIDConnect (OIDC) tokens for user authentication.

As indicated in the following schema, Kubernetes does not perform the OIDC authentication flow of the end-user.
It just validates the given tokens and eventually refresh them if needed.

![oidc-flow](./oidc-flow.png)

To demonstrate that, we are setting up a Keycloak instance as a docker container on the bastion instance for conveniance.
We are generating a custom certificate with certbot for SSL communication as it is needed by Kubernetes.
Once OIDC authentication configured, we create a custom user on keycloak and demonstrate how to log on the Kubernetes cluster and how RBAC is mapped.

# Install prerequisites

```bash
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    certbot
```

Install Docker :
```bash
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io

sudo usermod -aG docker training # Relaunch the ssh session
```

Generate the certificate for the Keycloak instance
```bash
export BASTION_URL=bastion.k8s-ops-0.wescaletraining.fr
sudo certbot certonly --standalone --register-unsafely-without-email --preferred-challenges http -d $BASTION_URL
```

Launch a Keycloak server the generated certificate
```bash
sudo docker run -d -e KEYCLOAK_USER=admin -e KEYCLOAK_PASSWORD=password --name keycloak -p 443:443 \
  -v /etc/letsencrypt/live/$BASTION_URL/fullchain.pem:/etc/x509/https/tls.crt \
  -v /etc/letsencrypt/live/$BASTION_URL/privkey.pem:/etc/x509/https/tls.key \
  docker.io/jboss/keycloak:16.1.1 -Djboss.https.port=443
```

Activate the oidc authentication plugin on the API servers. For that, add the following attributes to **ALL** the masters in the `/etc/rancher/rke2/config.yaml` file.

```yaml
kube-apiserver-arg:
 - oidc-issuer-url=https://bastion.k8s-ops-0.wescaletraining.fr/auth/realms/master
 - oidc-client-id=kubernetes
 - oidc-groups-claim=groups
 - "oidc-groups-prefix=keycloak:"
 - oidc-username-claim=email
```

Then restart all the RKE2 server services: `systemctl restart rke2-server`.

Create a Keycloak client with the following information
- id: `kubernetes`
- protocol: `openid connect`
- access type: `confidential`
- valid redirect uris
  - `http://localhost:18000` # for kubelogin
  - `http://localhost:8000` # for kubelogin
- roles
  - create a new role `developer`
- mapper
  - name: `groups`
  - type: `user client role`
  - client id: `kubernetes`
  - token claim name: `groups`

Create a test user called john
- users
  - name: `john`
    email: `john@wescaletraining.fr`
    email verified: `true`
    password: `Password1`
    role: `developer`

Create a rolebinding for the developer Keycloak group
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developer-role-binding
subjects:
- kind: Group
  name: keycloak:developer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
```

Retrieve the `creds/kube_config_cluster.yml` file on your laptop
```bash
scp -F provided_ssh_config bastion:/home/training/.kube/config kubeconfig
export KUBECONFIG=kubeconfig
```

Install kubectl plugin whoami
```bash
kubectl krew install whoami
```

Show that we are connected as admin user
```bash
kubectl whoami
kubectl get nodes
```

Install kubectl plugin kubelogin
```bash
kubectl krew install oidc-login
```

Retrieve the secret for the `kubernetes' Keycloak client on the credentials tab

Setup kubectl OIDC login
```bash
kubectl oidc-login setup \
--oidc-issuer-url=https://$BASTION_URL/auth/realms/master \
--oidc-client-id=kubernetes \
--oidc-client-secret=<CLIENT_SECRET> \
--insecure-skip-tls-verify
```

Login as john@wescaletraining.fr

Add login configuration in kubeconfig file
```bash
kubectl config set-credentials oidc \   
  --exec-api-version=client.authentication.k8s.io/v1beta1 \
  --exec-command=kubectl \
  --exec-arg=oidc-login \
  --exec-arg=get-token \
  --exec-arg=--oidc-issuer-url=https://$BASTION_URL/auth/realms/master \
  --exec-arg=--oidc-client-id=kubernetes \
  --exec-arg=--oidc-client-secret=<CLIENT_SECRET> \
  --exec-arg=--insecure-skip-tls-verify
```

Show that we are connected as john@wescaletraining.fr
```bash
kubectl whoami --user oidc
kubectl --user oidc get pods -A # it works
kubectl --user oidc get nodes # it does not work because we have the role viewer 
```
