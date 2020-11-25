#  Install an application from a predefined chart

The objective of this exercise is to migrate the k8s configuration from an application to Helm.
This is a simple two-thirds application: frontend and backend

Rewrite  the different yaml files for this using Chart Helm. You find here:

- Create namespace helm-demo 
```sh
apiVersion: v1
kind: Namespace
metadata:
  name: helm-demo
  labels:
    stage: test
```
- frontend-deployment.yaml
- backend-deployment.yaml
- frontend-service.yaml
- backend-service.yaml

