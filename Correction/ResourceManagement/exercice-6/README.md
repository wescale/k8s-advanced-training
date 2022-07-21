## Create a Deployment without resource specifications

View the `QoS` class of the created pods and the resource requests/limits: 

'''sh
kubectl get pods -n default-resources-config
'''

'''sh
kubectl describe pods xxx -n default-resources-config
'''

limits > requests => QoS burstable


## Create a Deployment with only limits

What do you see as QoS class? > Garanteed
Why ? Limits = Resquested 

