#!/bin/bash

set -euo pipefail

# Create an environment variable for the correct distribution
export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"

# Add the Cloud SDK distribution URI as a package source
echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# Import the Google Cloud Platform public key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

# Update the package list and install the Cloud SDK
apt-get update && sudo apt-get install -y google-cloud-sdk kubectl nano unzip git
gcloud config set compute/zone europe-west1-b

wget -O /usr/bin/rke https://github.com/rancher/rke/releases/download/v1.0.14/rke_linux-amd64
chmod +x /usr/bin/rke

snap install go --classic
go get github.com/micahhausler/k8s-oidc-helper