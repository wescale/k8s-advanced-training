# Audit logs, ETCD backup/restore and cluster upgrade

In this exercise, you will take a look at parts of Kubernetes cluster management:

- Tracking actions made on the cluster with audit logs
- Take a snapshot of a cluster at a given time and restore it

## Enabling audit logs

Activating the audit logs of the API server is the only way to know who or what pod performed what operation on a given cluster. This can be useful to identify malicious operations that happened on your cluster.

This is done through the configuration of an [audit policy](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#audit-policy). You have an example in the [audit-policy.yaml](./audit-policy.yaml) file. Take a look at the defined rules and try to understand what they mean.

To enable audit logs, mention this audit policy on the API server configuration:

```sh
# Copy the audit policy file to the master node
training@bastion:~$ scp -F ~/provided_ssh_config ./audit-policy.yaml master-0:~
# Connect to the master node
training@master-0:~$ ssh -F ~/provided_ssh_config master-0
training@master-0:~$ sudo -i

# Move the audit policy to the /etc/kubernetes directory
root@master-0:~$ mv /home/training/audit-policy.yaml /etc/kubernetes/sss
# Edit the API server manifest to mention the audit policy
root@master-0:~$ vi /etc/kubernetes/manifests/kube-apiserver.yaml
...
spec:
  containers:
  - command:
    - kube-apiserver
    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-log-maxsize=100
    - --audit-log-maxbackup=10
    ...
    volumeMounts:
    - mountPath: /etc/kubernetes/audit-policy.yaml
      name: audit-policy
      readOnly: true
    - mountPath: /var/log/kubernetes/audit/
      name: audit-log
      readOnly: false
    ...
  volumes:
  - name: audit
    hostPath:
      path: /etc/kubernetes/audit-policy.yaml
      type: File
  - name: audit-log
    hostPath:
      path: /var/log/kubernetes/audit/
      type: DirectoryOrCreate

root@master-0:~$ exit
```

Questions:

- What do you think are the meaning of the `--audit-log-maxsize` and `--audit-log-maxbackup` parameters ?
- Why do we have to add two volumes on the API server pod specification ?
- Where will audit logs be located ?

After a few seconds, you should see the kube-apiserver pod restarting with the new configuration:

```sh
training@master-0:~$ kubectl get po -n kube-system -l component=kube-apiserver --watch
```

**Now to make this change consistent, perform the same operation on the other two master nodes.**

Perform a test:

```sh
# Create a dummy pod
training@bastion:~$ kubectl run pod-with-special-name --image=gcr.io/google-samples/hello-app:1.0 --port=8080
# Then delete it
training@bastion:~$ kubectl delete pod pod-with-special-name
```

- Now connect to any master node and look for the *DELETE* operation.

## Etcd backup/restore

Since the etcd database stores the current state of the cluster, it means that if the data is lost in any, you are in big troubles. To prevent this from happening, performing etcd backups regularly is a good starting point.

Here, we propose to explore backup/restore features. You will put the cluster in a specific state, perform a one-time snapshot, do some destructive operation, and finally restore the previous state from the snapshot:

```sh
# Deploy an important pod
training@bastion:~$ kubectl run important-pod --image=gcr.io/google-samples/hello-app:1.0 --port=8080
# Ensure it is running
training@bastion:~$ kubectl get po

# Connect to the master-0 node
training@bastion:~$ ssh -F ~/provided_ssh_config master-0
training@master-0:~$ sudo -i

# Inspect the etcd pod manifest to see where the data is stored
root@master-0:~$ cat /etc/kubernetes/manifests/etcd.yaml

# Now we will use the etcdctl command to perform a snapshot
# The command is incomplete, you can find what you need in the etcd pod manifest
root@master-0:~$ ETCDCTL_API=3 etcdctl --endpoints=<TO_BE_FILLED> \
  --cacert=<TO_BE_FILLED> \
  --cert=<TO_BE_FILLED> \
  --key=<TO_BE_FILLED> \
  snapshot save /tmp/snapshot.db
root@master-0:~$ chmod 644 /tmp/snapshot.db

# Go back to the bastion instance to retrieve the snapshot and copy it to the two other masters
root@master-0:~$ exit
training@master-0:~$ exit
training@bastion:~$ scp -F ~/provided_ssh_config master-0:/tmp/snapshot.db master-1:/tmp
training@bastion:~$ scp -F ~/provided_ssh_config master-0:/tmp/snapshot.db master-2:/tmp

# Simulate a destructive operation
training@bastion:~$ kubectl delete po important-pod
# The pod should be gone
training@bastion:~$ kubectl get po


# REPEAT THE FOLLOWING STEPS FOR ALL MASTERS
# Connect the master node to restore the snapshot in the /var/lib/etcd-backup directory
training@bastion:~$ ssh -F ~/provided_ssh_config master-0
training@master-0:~$ sudo -i
root@master-0:~$ ETCDCTL_API=3 etcdctl --endpoints=<TO_BE_FILLED> \
  --cacert=<TO_BE_FILLED> \
  --cert=<TO_BE_FILLED> \
  --key=<TO_BE_FILLED> \
  --data-dir=/var/lib/etcd-backup \
  snapshot restore /tmp/snapshot.db

# Check the content of the new data-dir
root@master-0:~$ ls -l /var/lib/etcd-backup/
# Put ALL masters in "maintenance" by temporarily moving controlplane manifests
root@master-0:~$ mv /etc/kubernetes/manifests /etc/kubernetes/manifests.old
# Edit the etcd pod manifest to target the new data-dir
root@master-0:~$ vi /etc/kubernetes/manifests.old/etcd.yaml


# Once this is done for every master, the cluster should be inacessible
training@bastion:~$ kubectl get po # This should hang

# We are now ready to spawn back our controlplane !
# For EVERY master, put back the manifests into place
root@master-0:~$ mv /etc/kubernetes/manifests.old /etc/kubernetes/manifests

# After a few seconds/minutes, the important pod you accidentally deleted should be back !
training@bastion:~$ kubectl get po
```
