# List of errors


* Resource Quota with very low values to prevent any pod creation
* InitContainer fails and lead to error for the pod
* NetworkPolicy prevent traffic between pods
* Invalid port inside Ingress

# Strategy

At a first glance, no pods exist.

## Got some running pods

No pods means pod creation has been rejected.
Describe some deployments or statefulsets. You will see error message saying something like:

```sh
kubectl edit deployment.apps/wordpress -n application
...
**"exceeded quota: prevent-pods, requested: cpu=200m,memory=256M, used: cpu=0,memory=0, limited: cpu=100m,memory=200m"**
```

That means you have a resource quota in the namespace.
If you look at the existing resource quota, you will see it has very low values.

```sh
kubectl get resourcequota -n application
kubectl describe resourcequota/prevent-pods -n application
```

You can try to change CPU/Memory requests and limits of all containers... or delete the resource quota: `kubectl delete resourcequota/prevent-pods -n application`

At this point, the `mariadb` and `wordpress` pods should appear.


## Fix the wordpress pods

While the `mariadb`pod becomes ready, the `wordpress` pod is marked as `init failed`.
If you describe the pod, you will see there is an `initContainer` that fails...

Normal, it exits with error code 1.

Edit the deployment `wordpress` to fix or remove the `initContainers` section.

Delete or fix the `initContainers` section.

At this point, the `wordpress` is no more in error.

## Investigate network filtering

The `wordpress` pod never comes `Ready`. If you look at the logs, you see it stucks on the Database connection.

```sh
kubectl logs pod/wordpress-XXXXX -n application
16:48:59.70 INFO  ==> Trying to connect to the database server
...
```

We suppose connection to DB has problems.

Perform some checks:
* endpoints for the `wordpress-mariadb` service -> OK, we retrieve the mariab pod behind. Means selector and label is OK.
* control port number and port name -> OK.

Finally launch an ubuntu image to investigate:
```sh
kubectl run --image=ubuntu:latest -ti -n application -- bash
# Then
apt-get install -y dnsutils telnet
# Test DNS is OK
nslookup wordpress-mariadb 
# Test TCP access -> KO
telnet -e i wordpress-mariadb 3306
```

At this point, we can look for network policies...

```sh
# Hum! Look for Network Policies?
kubectl get netpol -n application
# Delete this NetPol
kubectl delete  netpol/deny-all -n application
```

Now, the `wordpress` pod should be `Ready` as the Readiness probe is passed.
You can see logs to confirm.

## Access from you browser

If you try to access to the service from your Web browser, you got 503 errors.

You can check the `wordpress` service has endpoints -> OK.

Now, you can look at the Ingresses...
You see an existing ingress named `wordpress` whose port name is `smtp`... it should be `http`.

## Test the wordpress app

Once the Ingress is fixed, access using your Browser should work!!