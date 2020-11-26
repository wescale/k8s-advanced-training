  # who-can
/sonobuoy run --plugin https://raw.githubusercontent.com/vmware-tanzu/sonobuoy-plugins/master/who-can/who-can.yaml
results=$(sonobuoy retrieve)
./sonobuoy results $results --mode=detailed|jq '.details|select(."subject-kind" == "User")."subject-name"'|sort --uniq

training@master-0:~$ 

kubectl create -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/images/conformance/conformance-e2e.yaml


## encrypt configuration in etcd



  ## Vault and injector

  https://learn.hashicorp.com/tutorials/vault/kubernetes-sidecar


  ## Pod disruption budget

  ## OPA

  No 2 ingress with the same name in different namespaces
  No images with the latest tag?
  Enforce tagging  ?

https://www.magalix.com/blog/enforce-that-all-kubernetes-container-images-must-have-a-label-that-is-not-latest-using-opa

