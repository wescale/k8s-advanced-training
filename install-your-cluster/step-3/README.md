## Test backup and restore of etcd

Backups of ETCD are a good starting point to recover from a disaster.

RKE can configure automatic backups of etcd and send them to S3:
```
services:
  etcd:
    backup_config:
      interval_hours: 1
      retention: 6
      s3backupconfig:
        access_key: S3_ACCESS_KEY
        secret_key: S3_SECRET_KEY
        bucket_name: s3-bucket-name
        region: ""
        folder: ""
        endpoint: s3.amazonaws.com
        custom_ca: |-
          -----BEGIN CERTIFICATE-----
          $CERTIFICATE
          -----END CERTIFICATE----

```

Here, we propose to explore backup/restore features. You will put the cluster in a specific state, then do a one-time snapshot and inspect the state after a restore operation:

```sh
# run specific pods
kubectl run important-pod --image=gcr.io/google-samples/hello-app:1.0 --port=8080
# do snapshot
rke etcd snapshot-save --name test-snapshot
# change the cluster state
kubectl delete pod important-pod
# do restore
rke etcd snapshot-restore --name test-snapshot
# ensure the important-pod is running
kubectl describe pod important-pod
```

## Rotate the certificates

Kubernetes involves a lot of certificates, which must be rotated in the case of a comprimised cert or just because they will soon expire.

RKE provides useful commands to rotate certificates.

```sh
rke cert rotate
```

## Activate the audit logs

Activating the audit logs of the api server is the only way to know who or what pod as perform operations like *delete* on a cluster.

For, that you have an example of configuration for RKE in `audit.yml`. Look at this file, in particular the `rules`.

* Append the `audit.yml` to your `cluster.yml`
* Run `rke up` to update the cluster.

Now, you can see relevant actions in `/var/log/kube-audit/audit-log.json` of a *control plane* node.

Perform a test:
```sh
# Create a pod
kubectl run pod-with-special-name --image=gcr.io/google-samples/hello-app:1.0 --port=8080
# Then delete it
kubectl delete pod pod-with-special-name
```

Now connect to any master node and look for the delete operation.

## Update Strategy

Any cluster will need to be updated at a moment.
Different possibilities will be discussed later but in the case of an update of an existing cluster, the strategy must be carefully thought.

Look at the `update_strategy` section of the current `cluster.yml` file.
A parameter is not acceptable for the production.

Which one?
