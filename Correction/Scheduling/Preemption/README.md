## Deploy pods without priority class

Scale the deployment to 10 replicas >>

```sh
kubectl scale deployment test-deploy --replicas=10 -n pc-demo
```
