
# Activate the audit logs

```
ssh -F provided_ssh_config master-0
less /var/log/kube-audit/audit-log.json
```

# Update strategy

`drain: false` is not acceptable as it will cause sudden pod deletion and potential loss of services.

See [update strategy](https://rancher.com/docs/rke/latest/en/upgrades/configuring-strategy/)
