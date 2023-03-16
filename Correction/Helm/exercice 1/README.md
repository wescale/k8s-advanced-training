# Install Helm 3 and try it


- Install Helm: https://helm.sh/docs/intro/install/
- Create a new Chart => simpleApp. Use Helm commands
```sh
helm create simpleapp 
```
- Can you browse through all the  generated files : templates, values ... and try to understand how it works ? 
- What is the default project in the chart helm ? 
There is none. It will be installed on the current namespace
- Install the application. And voila you have an application up and running in the kubernetes cluster. Check it out.
```sh
$ helm install simpleapp ./simpleapp
```
- Checkout the revision, version saved by Helm and using Helm API.
```sh
$ helm ls
$ kubectl get all
```
- Clean up this installation using helm commands
```sh
$ helm uninstall simpleapp 
```





