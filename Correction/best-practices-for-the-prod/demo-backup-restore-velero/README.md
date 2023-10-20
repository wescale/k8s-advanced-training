# Demo - Backup / Restore with Velero


## Prepare Backup Storage

In order to save the backup we will deploy a minio s3 server
```sh
kubectl create ns velero
helm repo add minio https://helm.min.io/
helm repo update
helm install minio -n velero --set accessKey=myaccesskey,secretKey=mysecretkey,resources.requests.memory=1G,defaultBucket.enabled=true,defaultBucket.name=velero  minio/minio
```

Then we create the secret to access minio server

```sh
kubectl apply -f backup-secret.yaml
```


## Install Velero

Install CLI

```sh
wget https://github.com/vmware-tanzu/velero/releases/download/v1.11.1/velero-v1.11.1-linux-amd64.tar.gz

tar xvf velero-v1.11.1-linux-amd64.tar.gz velero-v1.11.1-linux-amd64/velero

sudo mv velero-v1.11.1-linux-amd64/velero /usr/bin/
sudo chmod +x /usr/bin/velero

velero version
```

Then install velero in the cluster

```sh
velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.2.1 \
    --bucket velero \
    --secret-file ./velero-creds \
    --use-volume-snapshots=false \
    --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://minio.velero.svc:9000
```


For more information, see the debugging information.

Verify in minio

```sh
export POD_NAME=$(kubectl get pods --namespace velero -l "release=minio" -o jsonpath="{.items[0].metadata.name}")
kubectl -n velero port-forward --address 0.0.0.0 $POD_NAME 9000
```

URL: http://BASTION_URL:9000/minio/velero/

## Install your app

Install a nginx server

```sh
kubectl apply -f nginx.yaml
kubectl apply -f nginx-pv.yaml
```

Retreive then access NodePort

```sh
kubectl get svc nginx -n nginx-example
```

Modify your html page (don't do that in production)

```sh

kubectl exec -it -n nginx-example pods/nginx-deployment-747864f4b5-kddtk -- bash -c "echo '<h1>Hello world</h1>' > /usr/share/nginx/html/index.html"
```

## Back up

Create a backup for any object that matches the app=nginx label selector:

```sh
velero backup create nginx-backup --selector app=nginx
```

Verify your backup

```sh
velero backup get
```


> Alternatively if you want to backup all objects except those matching the label backup=ignore:
>
>```sh
>
>velero backup create nginx-backup --selector 'backup notin (ignore)'
>```
> 
>(Optional) Create regularly scheduled backups based on a cron expression using the app=nginx label selector:
>
>
>```sh
>velero schedule create nginx-daily --schedule="0 1 * * *" --selector app=nginx
>```
>
>
>Alternatively, you can use some non-standard shorthand cron expressions:
>
>```sh
>velero schedule create nginx-daily --schedule="@daily" --selector app=nginx
>```
>

See the cron package’s documentation for more usage examples.

Simulate a disaster

```sh
kubectl delete namespace nginx-example
```

To check that the nginx deployment and service are gone, run:

```sh
kubectl get all -n nginx-example
```

You should get no results.

NOTE: You might need to wait for a few minutes for the namespace to be fully cleaned up.

Restore

Run

```sh
velero restore create --from-backup nginx-backup
```

Verify

```sh
velero restore get
```


After the restore finishes, the output looks like the following:

> 
> NAME | BACKUP | STATUS | STARTED | COMPLETED | ERRORS | WARNINGS | CREATED | SELECTOR
> ---|---|---|---|---|---|---|---|---| 
> nginx-backup-20230918122315 | nginx-backup | Completed | 2023-09-18 12:23:15 +0000 UTC | 2023-09-18 12:23:16 +0000 UTC | 0 | 0 | 2023-09-18 12:23:15 +0000 UTC | `<none>`

> NOTE: The restore can take a few moments to finish. During this time, the STATUS column reads InProgress.

After a successful restore, the STATUS column is Completed, and WARNINGS and ERRORS are 0. All objects in the nginx-example namespace should be just as they were before you deleted them.

If there are errors or warnings, you can look at them in detail:

```sh
velero restore describe <RESTORE_NAME>
```

Verify and check your nginx

```sh
kubectl get all -n nginx-example
```

NAME | READY | STATUS | RESTARTS | AGE
---|---|---|---|---|
pod/nginx-deployment-747864f4b5-kddtk | 1/1 | Running | 0 | 50s

NAME | TYPE | CLUSTER-IP | EXTERNAL-IP | PORT(S) | AGE
---|---|---|---|---|
service/my-nginx | NodePort | 10.43.187.212 | `<none>` | 80:30212/TCP | 49s

NAME | READY | UP-TO-DATE | AVAILABLE | AGE
---|---|---|---|---|
deployment.apps/nginx-deployment | 1/1 | 1 | 1 | 50s

NAME | DESIRED | CURRENT | READY | AGE
---|---|---|---|---|
replicaset.apps/nginx-deployment-747864f4b5 | 1 | 1 | 1 | 50s


Delete all the created resources:

```sh
kubectl delete -f .
kubectl delete ns velero
```