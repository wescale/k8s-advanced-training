#!/bin/bash

#Basic error handling
set -o errexit
set -euo pipefail

source oidc.k8s-auth-client

echo "Please login with the user / password provided by the trainer using the following URL:"
echo "${K8S_OIDC_ISSUER}authorize?response_type=code&scope=openid%20profile%20email%20offline_access&client_id=${K8S_OIDC_CLIENT_ID}&redirect_uri=http://localhost/"
echo ""

read -p "Then paste code indicated in the adress bar: \"http://localhost/?code=YOUR_OAUTH2_CODE\": " CODE

echo ""

curl -o tokens.json --request POST \
  --url "${K8S_OIDC_ISSUER}oauth/token" \
  --header 'content-type: application/x-www-form-urlencoded' \
  --data "grant_type=authorization_code&client_id=${K8S_OIDC_CLIENT_ID}&client_secret=${K8S_OIDC_CLIENT_SECRET}&code=${CODE}&redirect_uri=http://localhost/"

set -o nounset

TOKENS=$(cat tokens.json) 
K8S_REFRESH_TOKEN=$(echo ${TOKENS} | jq -r '.refresh_token')
K8S_ID_TOKEN=$(echo ${TOKENS} | jq -r '.id_token')

echo ${TOKENS}|jq ''

echo "Set Kubernetes credentials.."
kubectl config set-credentials oidc-user \
	--auth-provider=oidc \
	--auth-provider-arg=idp-issuer-url=$K8S_OIDC_ISSUER \
	--auth-provider-arg=client-id=$K8S_OIDC_CLIENT_ID \
	--auth-provider-arg=client-secret=$K8S_OIDC_CLIENT_SECRET \
	--auth-provider-arg=refresh-token=$K8S_REFRESH_TOKEN \
	--auth-provider-arg=id-token=$K8S_ID_TOKEN

echo "Done."