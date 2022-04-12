# Network policies

In this exercise, you will manipulate network policies.

A `wordpress` application is deployed into the namespace `application`:
* `wordpress` PHP stack:
  * 1 deployment
  * 1 `wordpress` service
* `MariaDB` database:
  * 1 statefulset
  * 1 `wordpress-mariadb` service 

An `nginx` ingress controller running in a `ingress-nginx` namespace.

Because the nginx ingress controller exposes ports 80 and 443 to the worker nodes, you can access the Wordpress from your web browser. **Ask the trainer to provide the URL.**

At the end of the exercise, you will have secured the stack: only the nginx proxy will receive traffic from Internet and only nginx will be allowed to connect to the the wordpress app.

# Step 1 - Deny all traffic

Create network policies to deny all ingress traffic for namespaces `ingress-nginx` and `application`.

Ensure the application is not accessible from your web browser.
# Step 2 - Allow traffic to the proxy

Create a network policy to allow ingress traffic to TCP:80 and TCP:443 from Internet to the `nginx` pods.

You should get HTTP 503 errors in your web browser.

# Step 3 - Allow traffic to the database

Create a network policy to allow ingress traffic to TCP:XXXX from the wordpress pods in the namespace `application` to mariadb pods in the `application` namespace.
# Step 4 - Allow traffic to the web-application

Create a network policy to allow ingress traffic from the `nginx` pods in the namespace `ingress-nginx` to wordpress pods in the `application` namespace.

NOTE: you may need to delete the `wordpress` pod if it has been restarted too many times by the kubelet (CrashLoopBackOff).

What are the ports to be allowed?

# Step 5 - Clean network policies

Delete all existing network policies in `ingress-nginx` and `application` namespaces.