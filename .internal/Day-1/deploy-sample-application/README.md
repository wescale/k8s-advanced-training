# Deploy sample application

This exercise contains instructions to deploy the sample application `microservices-demo` that will be used during the entire training course.

> Resources deployed here will serve as a base for future exercises. The stack will not be complete after this. We will alter its deployment and make changes to it throughout the course.

## Deploy the base

As of now, we are only going to deploy the admin part of the application. It is composed of three services: a `mongodb` database to store the articles, an `article-service` that executes the instructions and a `front-admin` user interface.

You will now deploy these three components:

- First, you can look at the different folders to see what type of resource you are going to deploy. Try to understand what each of them do.

- Then, use the `kubectl` command to create the `application` namespace.

```sh
training@bastion:~$ kubectl create ns application
```

- Finally, deploy the base using the manifests at your disposal (*hint: order might be important if you want to avoid restarting pods*).

```sh
# Deploy objects
training@bastion:~$ kubectl apply -f mongodb -n application
training@bastion:~$ kubectl apply -f article-service -n application
training@bastion:~$ kubectl apply -f front-admin -n application

# Check that everything runs correctly
training@bastion:~$ kubectl get po -n application
```

Once done, you should be able to access the admin user interface on your browser at the `demo-admin.k8s-ops-X.wescaletraining.fr`. Try to add to sample article to see if it is working.
