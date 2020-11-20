#!/bin/bash
# Create an environment variable for the correct distribution
export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"

# Add the Cloud SDK distribution URI as a package source
echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# Import the Google Cloud Platform public key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

# Update the package list and install the Cloud SDK
apt-get update && sudo apt-get install -y google-cloud-sdk kubectl nano unzip git
gcloud config set compute/zone europe-west1-b

apt-get update && sudo apt-get install -y conntrack nftables

for module in br_netfilter ip6_udp_tunnel ip_set ip_set_hash_ip ip_set_hash_net iptable_filter iptable_nat iptable_mangle iptable_raw nf_conntrack_netlink nf_conntrack nf_conntrack_ipv4   nf_defrag_ipv4 nf_nat nf_nat_ipv4 nf_nat_masquerade_ipv4 nfnetlink udp_tunnel veth vxlan x_tables xt_addrtype xt_conntrack xt_comment xt_mark xt_multiport xt_nat xt_recent xt_set  xt_statistic xt_tcpudp;
do
if ! lsmod | grep -q $module; then
    echo "module $module is not present";
    modprobe $module
    # if grep $module /lib/modules/$(uname -r)/modules.builtin; then
    #     echo "module is on the computer"
    # else
    #     echo "module is not on the computer"
    # fi    
fi;
done

sysctl net.bridge.bridge-nf-call-iptables=1

sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update && sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

echo "Add training user to the Docker group"
usermod -aG docker training