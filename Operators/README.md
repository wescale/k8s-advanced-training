# Hands-on: Operators

During this exercise we will install a mysql operator to create mysql cluster and manage backups to minio S3 bucket
https://github.com/bitpoke/mysql-operator

## Installing Mysql Operator

Install the operator with helm

```sh
helm repo add bitpoke https://helm-charts.bitpoke.io
helm repo update
helm install mysql-operator bitpoke/mysql-operator
```

Check the operator controller is deployed

```sh
kubectl get pods
NAME               READY   STATUS    RESTARTS   AGE
mysql-operator-0   2/2     Running   0          41s
```

The operator extended K8S api server with 2 new api resources

```sh
kubectl get crd | grep "mysql"
mysqlbackups.mysql.presslabs.org            2020-11-24T15:26:31Z
mysqlclusters.mysql.presslabs.org           2020-11-24T15:26:31Z
```
The operator will listen to API requests on mysqlbackups and mysqlclusters to manage the mysql cluster
## Create a Mysql cluster

First we will create a secret containing the root password

```sh
kubectl apply -f root-secret.yaml
```

Then we will deploy the resource MysqlCluster to create the database cluster

```sh
kubectl apply -f cluster.yaml
```

List deployed cluster

```sh
kubectl get mysql
```

Check cluster state

```sh
kubectl describe mysql my-db
```

We can see that the operator created a mysql cluster with 2 replicas one master and one replica + persistent volumes

```sh
kubectl get pods -l role=master
kubectl get pods -l role=replica
kubectl get pvc
```
Test the connection to the database

```sh
kubectl run mysql-client --image=mysql:8 -it --rm --restart=Never -- /bin/bash
#then in the container prompt
mysql -h my-db-mysql -uroot -pdbsecret -e 'SELECT 1'
```

If we delete the master pod we can see that the operator promoted the replica pod to master
```sh
kubectl delete pod -l role=master
kubectl get pods -l role=master
kubectl get pods -l role=replica
```

## Create a DB backup
In order to save the backup we will deploy a minio s3 server
```sh
helm repo add minio https://helm.min.io/
helm repo update
helm install minio --set accessKey=myaccesskey,secretKey=mysecretkey,resources.requests.memory=1G,defaultBucket.enabled=true,defaultBucket.name=mysql  minio/minio
```
Then we create the secret to access minio server
```sh
kubectl apply -f backup-secret.yaml
```
Deploy the backup config
```sh
kubectl apply -f backup.yaml
```
Check the backup was successful

```sh
kubectl describe mysqlbackup
```

Verify in minio

```sh
export POD_NAME=$(kubectl get pods --namespace default -l "release=minio" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 9000
```

Open a tunnel in your local machine
```sh
ssh -L 9000:localhost:9000 -F provided_ssh_config bastion
```

URL: http://localhost:9000/minio/mysql/


Delete all the created resources:
```sh
kubectl delete -f .
helm uninstall minio
helm uninstall mysql-operator
```

