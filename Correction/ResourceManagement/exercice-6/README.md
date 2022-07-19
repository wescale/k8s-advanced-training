## Create a Deployment without resource specifications

View the `QoS` class of the created pods and the resource requests/limits: 

kubect get pods -n default-resources-config

kubectl describe pods xxx -n default-resources-config

limits > requests => QoS burstable

