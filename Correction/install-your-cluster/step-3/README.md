
# Activate the audit logs

```
ssh -F provided_ssh_config master-0
less /var/log/kube-audit/audit-log.json
less -f /var/log/kube-audit/audit-log.json | grep pod-with-special-name | grep deletionTimestamp
```

# Upgrade strategy

`drain: false` is not acceptable as it will cause sudden pod deletion and potential loss of services.


By default, nodes are cordoned first before upgrading. Each node should always be cordoned before starting its upgrade so that new pods will not be scheduled to it, and traffic will not reach the node. In addition to cordoning each node, RKE can also be configured to drain each node before starting its upgrade. Draining a node will evict all the pods running on the computing resource.

For information on draining and how to safely drain a node, refer to the Kubernetes documentation.

If the drain directive is set to true in the cluster.yml, worker nodes will be drained before they are upgraded. The default value is false


See [upgrade strategy](https://rancher.com/docs/rke/latest/en/upgrades/configuring-strategy/)
