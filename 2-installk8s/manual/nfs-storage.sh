# Install NFS Storage Class
# NOTE: Install nfs-common on all nodes
# sudo apt install nfs-common -y
# NOTE: NFS export parameters
# /mnt/nfsdir     10.28.28.0/24(rw,sync,no_subtree_check,no_root_squash)

helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner

helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --create-namespace \
  --namespace nfs-provisioner \
  --set nfs.server=10.28.28.30 \
  --set nfs.path=/mnt/pool0/nfs \
  --set storageClass.onDelete=true

kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'