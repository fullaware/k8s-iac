cat << EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat << EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

sudo apt update && sudo apt install -y containerd

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

sudo systemctl restart containerd

sudo swapoff -a

sudo apt update && sudo apt install -y apt-transport-https curl

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat << EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update
sudo apt-get install -y kubelet=1.25.5-00 kubeadm=1.25.5-00 kubectl=1.25.5-00
sudo apt-mark hold kubelet kubeadm kubectl


sudo apt install qemu-guest-agent -y
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent
# On the control plane node only, initialize the cluster and set up kubectl access.
sudo kubeadm init --pod-network-cidr 172.12.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl get nodes

# If things don't work out RESET
# sudo kubeadm reset -f
# sudo rm -rf /etc/cni/net.d
# sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
# Install the Calico network add-on.

# kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Install Antrea network add-on.

kubectl apply -f https://raw.githubusercontent.com/antrea-io/antrea/main/build/yamls/antrea.yml

# Get the join command (this command is also printed during kubeadm init . Feel free to simply copy it from there).

# kubeadm token create --print-join-command
# Copy the join command from the control plane node. Run it on each worker node as root (i.e. with sudo ).

# sudo kubeadm join ...

# On the control plane node, verify all nodes in your cluster are ready. Note that it may take a few moments for all of the nodes to
# enter the READY state.

kubectl get nodes

# Install Metrics
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Fix issue with local TLS not allowing insecure connection
# kubectl -n kube-system edit deploy metrics-server 

# add the parameters below 

cat << EOF | sudo tee patch-metrics-server.yaml
---
spec:
  template:
    spec:
      containers:
      - name: metrics-server
        image: k8s.gcr.io/metrics-server/metrics-server:v0.6.2      
        command:
        - /metrics-server
        - --kubelet-insecure-tls
        - --kubelet-preferred-address-types=InternalIP
EOF

kubectl -n kube-system patch deploy metrics-server --type merge --patch-file patch-metrics-server.yaml

# Install OpenEBS Local PV Hostpath volumes will be created under /var/openebs/local

kubectl apply -f https://openebs.github.io/charts/openebs-operator-lite.yaml 
kubectl apply -f https://openebs.github.io/charts/openebs-lite-sc.yaml
kubectl patch storageclass openebs-hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'


# Install Metatllb Load Balancer

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
#  EDIT Addresses to fit your cluster

cat <<EOF | kubectl create -f -
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.28.28.70-10.28.28.79
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
EOF

# Install Contour Ingress HTTPProxy

kubectl apply -f https://projectcontour.io/quickstart/contour.yaml

# Install Portainer Business Edition (Free for 5 nodes) using LoadBalancer
kubectl apply -n portainer -f https://downloads.portainer.io/ee2-16/portainer-lb.yaml

# Prometheus and Grafana
#     https://www.fosstechnix.com/install-prometheus-and-grafana-on-kubernetes-using-helm/
# Install to --namespace monitoring