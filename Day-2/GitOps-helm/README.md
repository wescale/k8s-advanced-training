# Manage HA with HELM 

Connect to argocd UI: see last exercice.

Go to your container with the UI, enter in exec in your container

Modify Nginx default page

```sh
echo '<h1> WeScale !!! </h1>' > /usr/share/nginx/html/index.html
```

Kill you pod and look what happened ...

> Your are not in HA

## Migrate to HA apps

Prerequisite:
- Have a github account

TODO: 
- Check => `sample-demo`.
- Can you browse through all the  generated files : templates, values ... and try to understand how it works ? 
- Create a new argocd application for dev purpose: 
  - Fork this repo and create a branch ha: `git switch -c ha`
  - Update your argocd application to point to your own github repo
- Update charts to go an HA apps: 1 commit/push per update
  - Set replicas to 3 with `{{ .Values.replicas . }}` and put an entry in `values.yaml` file
  - fix the antiaffitiny

Extra: 
  - enable topology constraint
    - configure the number of app per node to 1: `{{ .Values.maxSkew . }}` and put an entry in `values.yaml` file
  - Create a PVC and mount it in deployments (create `pvc.yaml` in templates folder) and:
    - name: {{ include "simpleapp.fullname" . }}-pv-claim
    - storage: 1Mi (managed by `values.yaml`)
    - mount the path: `mountPath: "/usr/share/nginx/html"` in your deployment
  - add annotations to pod and deployment
    - if only set: `{{- if .Values.annotations }}`
    - raw annotations: `{{- toYaml .Values.annotations | nindent ... }}` where `...` == number of spaces

PVC sample:
```yaml
volumeClaimTemplates:
  - metadata:
      name: {{ include "simpleapp.fullname" . }}
    spec:
      accessModes:
        - ReadWriteOnce
      storageClassName: standard
      resources:
        requests:
          storage: 1Mi
```

Create an ArgoCD application

```sh
export myuser=sphinxgaia

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: declarative-gitops-chart-ha
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/$myuser/k8s-advanced-training.git'
    targetRevision: ha
    path: 'Correction/GitOps-helm/sample-demo'
  syncPolicy:
    automated:
      prune: true
    syncOptions:
    - CreateNamespace=true
  destination:
    server: https://kubernetes.default.svc
    namespace: 'declarative-gitops-ha'
EOF
```

Check with ArgoCD UI or 

```sh
kubectl get po,svc -n declarative-gitops
```


## Clean

```sh
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete ns argocd
kubectl delete ns ui-gitops
kubectl delete ns declarative-gitops
kubectl delete ns declarative-gitops-ha
```