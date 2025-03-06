# Operators

In the microservices demo app architecture, we can consider the MongoDB database since it is storing all of our articles. If we loose its data, we kinda loose everything. On top of that, we want it to scale and absorb incoming requests as they increase more on more.

As a result, we want the MongoDB db to be "highly available" (or HA). On the paper, we can just increase the number of replicas and the job is done. But having a MongoDB cluster is a lot more complex than that. You have to adapt the configuration accordingly, configure the sharding, potentially add arbiters, ...etc.

Doing this manually would require a lot of attention and does not have any real value. Instead, all of this can be done via the [MongoDB Operator](https://github.com/mongodb/mongodb-kubernetes-operator/tree/master).

During this exercise we will replace the existing MongoDB database by a new MongoDB cluster handled by the operator

## Installing MongoDB Operator

- First, we are going to install the operator using its Helm chart

```sh
training@bastion:~$ helm repo add mongodb https://mongodb.github.io/helm-charts
training@bastion:~$ helm install mongodb-operator mongodb/community-operator --namespace mongodb-operator \
  --set operator.watchNamespace="application" --create-namespace
# Create RBAC for operator in the application namespace
training@bastion:~$ helm template mongodb/community-operator --show-only templates/database_roles.yaml --namespace application | kubectl apply -f -
```

- Check that the operator is correctly deployed

```sh
training@bastion:~$ kubectl get po -n mongodb-operator
```

- The operator also created a new CustomResourceDefinition (CRD). Look for it using the `kubectl api-resources` command. You can also explore the spec of the CRD using the `kubectl explain` command.

```sh
training@bastion:~$ kubectl api-resources | grep mongo
training@bastion:~$ kubectl explain mongodbcommunity.spec
```

## Create a new MongoDB cluster

- Create a new MongoDB cluster in the `application` namespace using the [mongodb-cluster.yaml](./mongodb-cluster.yaml) skeleton that has the following properties:
  - Cluster name: `mongodb-cluster`
  - Number of replicas: `1`
  - The MongoDB version should match with the one from the existing MongoDB
  - Create a user called `training` who is cluster admin. You can freely choose the associated password

```sh
training@bastion:~$ kubectl create secret mongodb-training-password --from-litteral password=password -n application
training@bastion:~$ kubectl apply -f mongodb-cluster.yaml -n application
```

- Wait for your new cluster to be ready

```sh
training@bastion:~$ watch kubectl get mdbc -n application
```

- When your cluster is ready inspect the resources created in your namespace (pods, pvc, secrets, ...etc)

- Look for the secret containing the cluster config and decode its content. How many members do you see in the MongoDB ReplicaSet ?

```sh
training@bastion:~$ kubectl get secret mongodb-cluster-config -o json -n application | jq -r '.data["cluster-config.json"]' | base64 -d | jq
# Only one member in the ReplicaSet
```

- Scale the cluster to 3 replicas

```sh
training@bastion:~$ kubectl apply -f mongodb-cluster-replicas.yaml -n application
```

- Look at the config again. Do you see if something has changed ? Magic, no ?

```sh
training@bastion:~$ kubectl get secret mongodb-cluster-config -o json -n application | jq -r '.data["cluster-config.json"]' | base64 -d | jq
# We have three members now. The operator reconfigured the cluster automatically
```

## Migrate existing data

We will now migrate our list of articles from the old MongoDB to our new cluster. To do that, we will use the `mongoexport` and `mongoimport` utilities.

- Install these tools on the bastion instance:

```sh
# Download package
training@bastion:~$ wget https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2404-x86_64-100.11.0.deb
# Install it
training@bastion:~$ sudo dpkg -i mongodb-database-tools-ubuntu2404-x86_64-100.11.0.deb
# Check that the tools are installed
training@bastion:~$ mongoexport --version
mongoexport version: 100.11.0
git version: b8a566a7f38fdcd9ba62256bee1880c999f2d4d7
Go version: go1.22.11
   os: linux
   arch: amd64
   compiler: gc

training@bastion:~$ mongoimport --version
mongoimport version: 100.11.0
git version: b8a566a7f38fdcd9ba62256bee1880c999f2d4d7
Go version: go1.22.11
   os: linux
   arch: amd64
   compiler: gc
```

- In a new shell, open a local port to access the old MongoDB directly

```sh
training@bastion:~$ kubectl port-forward svc/mongodb 27017:27017 -n application
```

- Use the `mongoexport` tool to export the data

```sh
training@bastion:~$ mongoexport --host="localhost:27017" --collection=article --db=article-alpha --out=articles.json

# Inspect the content of outputed articles.json file
training@bastion:~$ cat articles.json
```

- Now open a local port to access the new MongoDB cluster

```sh
training@bastion:~$ kubectl port-forward svc/mongodb-cluster-svc 27017:27017 -n application
```

- And we import the data

```sh
training@bastion:~$ mongoimport --host="localhost:27017" --username=training \
  --authenticationMechanism=SCRAM-SHA-256 --authenticationDatabase admin \
  --db=article-alpha --collection=article --file=articles.json
```

- Does it work ? Why ? Let's try to fix that

> It does not work because our training user does not have admin rights to the article-alpha database

- Edit the `MongoDBCommunity` object to assign the `dbOwner` role to our `training` user on the `article-alpha` database.

```sh
training@bastion:~$ kubectl apply -f mongodb-cluster-role.yaml -n application
```

- Wait for the cluster to be ready and try the import command again. Is it good now ?

> It does work now

We can now reconfigure the `article-service` to target the new DB. The operator created a secret called `mongodb-cluster-admin-training` that contains the connection strings we can use to connect to the MongoDB cluster.

- Alter the `MONGODB_URI` environment variable in the `article-service` Deployment to use the `connectionString.standard` key of the `mongodb-cluster-admin-training` instead. You can use this [documentation](https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/#define-a-container-environment-variable-with-data-from-a-single-secret) if you need to.

```sh
training@bastion:~$ kubectl apply -f article-service-deployment.yaml -n application
```

- Check the new `article-service` pod logs to verify it is targeting the new DB. Take a look at the admin UI to see if everything is still working.

- The old MongoDB is now useless, we can delete it

```sh
training@bastion:~$ kubectl delete sts,svc,pvc -l component=mongodb -n application
```
