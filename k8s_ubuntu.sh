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
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# On the control plane node only, initialize the cluster and set up kubectl access.
sudo kubeadm init --pod-network-cidr 172.12.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl get nodes

# Install the Calico network add-on.

kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Install Antrea network add-on.

# kubectl apply -f https://raw.githubusercontent.com/antrea-io/antrea/main/build/yamls/antrea.yml

# Get the join command (this command is also printed during kubeadm init . Feel free to simply copy it from there).

kubeadm token create --print-join-command
# Copy the join command from the control plane node. Run it on each worker node as root (i.e. with sudo ).

sudo kubeadm join ...

# On the control plane node, verify all nodes in your cluster are ready. Note that it may take a few moments for all of the nodes to
# enter the READY state.

kubectl get nodes

# Install Metrics
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Fix issue with local TLS not allowing insecure connection
kubectl -n kube-system edit deploy metrics-server 

# add the parameters below right after image: k8s.gcr.io/metrics-server-amd64:v0.3.1 line:

        command:
        - /metrics-server
        - --kubelet-insecure-tls
        - --kubelet-preferred-address-types=InternalIP

# Install NFS Storage Class
# NOTE: NFS export parameters
# /mnt/nfsdir     10.28.28.0/24(rw,sync,no_subtree_check,no_root_squash)

helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner

helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --create-namespace \
  --namespace nfs-provisioner \
  --set nfs.server=10.28.28.30 \
  --set nfs.path=/mnt/nfsdir \
  --set storageClass.onDelete=true

kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Install Metatllb Load Balancer

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.5/config/manifests/metallb-native.yaml

# ipaddresspool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.28.28.70-10.28.28.79

# l2advertisement.yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system

# Install Contour Ingress HTTPProxy

kubectl apply -f https://projectcontour.io/quickstart/contour.yaml

# httpproxy.yaml
apiVersion: projectcontour.io/v1
kind: HTTPProxy
metadata:
  name: car-demo
  namespace: car-demo
spec:
  virtualhost:
    fqdn: car-demo.10.28.28.73.nip.io # IP address of envoy LoadBalancer
  routes:
    - conditions:
      - prefix: /
      services:
        - name: car-demo
          port: 8080

# Portainer

# Prometheus and Grafana
https://www.fosstechnix.com/install-prometheus-and-grafana-on-kubernetes-using-helm/
# Install to --namespace monitoring

# Install Jenkins

# jenkins-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: jenkins
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: jenkins-server
  sessionAffinity: None
  type: LoadBalancer
status:
  loadBalancer: {}

---

apiVersion: v1
kind: Service
metadata:
  name: jenkins-jnlp
spec:
  type: ClusterIP
  ports:
    - port: 50000
      targetPort: 50000
  selector:
    app: jenkins-server
    
# jenkins-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-pvc
  namespace: jenkins
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi

# jenkins-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins-server
  template:
    metadata:
      labels:
        app: jenkins-server
    spec:
      containers:
        - name: jenkins
          image: jenkins/jenkins:lts
          ports:
            - name: httpport
              containerPort: 8080
            - name: jnlpport
              containerPort: 50000
          volumeMounts:
            - name: jenkins-data
              mountPath: /var/jenkins_home
      volumes:
        - name: jenkins-data
          persistentVolumeClaim:
              claimName: jenkins-pvc



# Configure Kubernetes Plugin for Jenkins
https://illya-chekrygin.com/2017/08/26/configuring-certificates-for-jenkins-kubernetes-plugin-0-12/