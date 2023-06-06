## Test backup and restore of etcd

Backups of ETCD are a good starting point to recover from a disaster.

RKE2 can configure [automatic backups of etcd](https://docs.rke2.io/backup_restore#options) and send them to [S3](https://docs.rke2.io/backup_restore#s3-compatible-api-support).

Here, we propose to explore backup/restore features. You will put the cluster in a specific state, then do a one-time snapshot and inspect the state after a restore operation:

```sh
# run specific pods
kubectl run important-pod --image=gcr.io/google-samples/hello-app:1.0 --port=8080
# Ensure the pod is running
kubectl get po
# Connect to a master-0 node
ssh -F provided_ssh_config master-0
# Take the snapshot
sudo rke2 etcd-snapshot save --name test-snapshot
# Change the cluster state
kubectl delete pod important-pod
```

To restore the snapshot, stop `rke2-server` service on **all** masters, reset the cluster then restart the see the `rke2-server`. You can see this [procedure](https://docs.rke2.io/backup_restore#restoring-a-snapshot-to-existing-nodes) for more information.

On **ALL** masters:

```sh
# Run the following command on ALL masters
sudo systemctl stop rke2-server
```

On **master-0** (where the snapshot is):

```sh
# Retrieve the snapshot name
sudo rke2 etcd-snapshot list
# Note the absolute path and run:
sudo rke2 server \
  --cluster-reset \
  --cluster-reset-restore-path=<PATH-TO-SNAPSHOT>
# Restart the rke2 service
sudo systemctl start rke2-server
```

On **master-1** and **master-2**:

```sh
sudo rm -rf /var/lib/rancher/rke2/server/db/
sudo systemctl start rke2-server
```

Now, it is time to verify our deleted pod is present again:

```sh
# ensure the important-pod is running
kubectl describe pod important-pod
# clean 
kubectl delete pod/important-pod
```

## Rotate the certificates

Kubernetes involves a lot of certificates, which must be rotated in the case of a comprimised cert or just because they will soon expire.

RKE2 provides useful commands to rotate certificates.

On ALL masters, run:

```sh
sudo rke2 certificate rotate
sudo systemctl restart rke2-server 
```

## Activate the audit logs

Activating the audit logs of the api server is the only way to know who or what pod as perform operations like *delete* on a cluster.

For, that you have an example of configuration for of an [audit policy](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#audit-policy) in the [audit-policy.yaml](./audit-policy.yaml) file. Look at this file, in particular the `rules` section.

To enable audit log, on **ALL** master:

* Backup your `config.yaml` file:
  * `sudo cp /etc/rancher/rke2/config.yaml /etc/rancher/rke2/config.yaml.bu`
* Create a `/home/training/audit-policy.yaml` file
  * vi `/home/training/audit-policy.yaml` copy and paste the content of the given file
* Edit the `/etc/rancher/rke2/config.yaml` to add:

```yaml
audit-policy-file: /home/training/audit-policy.yaml
kube-apiserver-arg: audit-log-path=/var/lib/rancher/rke2/server/logs/audit.log
```
* Run `sudo systemctl restart rke2-server`.

Now, you can see relevant actions in `/var/lib/rancher/rke2/server/logs/audit.log` of a *control plane* node.

Perform a test:

```sh
# Create a pod
kubectl run pod-with-special-name --image=gcr.io/google-samples/hello-app:1.0 --port=8080
# Then delete it
kubectl delete pod pod-with-special-name
```

Now connect to any master node and look for the delete operation.

Because there is no `logrotate` configuration for the audit logs, disable them:

```sh
sudo cp /etc/rancher/rke2/config.yaml.bu /etc/rancher/rke2/config.yaml
sudo systemctl restart rke2-server
```

## Update Strategy

Any cluster will need to be updated at a moment.
Different possibilities will be discussed later but in the case of an update of an existing cluster, the strategy must be carefully thought.

RKE2 provides a [manual](https://docs.rke2.io/upgrade/manual_upgrade) or [automated upgrades](https://docs.rke2.io/upgrade/automated_upgrade) with an additional controller.

The sequence is always the same: first the masters, then the workers.
