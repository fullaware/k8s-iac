# Proxmox VMs for Kubernetes 

## Overview

This directory contains tooling for:
- creating a Proxmox VM template to use as a source for future VMs (Ansible)
- provisioning VMs (1 control, 3 workers) based on the created template (Terraform)
- installation and configuration of Kubernetes (Ansible)
  - DONE:
    - networking [`antrea`](https://antrea.io/docs/main/docs/getting-started/)
    - [`metrics-server`](https://github.com/kubernetes-sigs/metrics-server)
    - loadbalancer [`metallb`](https://metallb.org/installation/)
    - storage [`OpenEBS`](https://openebs.io/docs/user-guides/localpv-hostpath#install)
    - ingress [`contour`](https://projectcontour.io/getting-started/#option-1-yaml)

### Required:

- Ansible
- Terraform
- Proxmox VE 7.x (Tested on 7.3.x)
- [Passwordless SSH configured](https://www.linuxbabe.com/linux-server/setup-passwordless-ssh-login) to Proxmox VE (PVE) host 

## Creating cloud-init template `0-createtemplate`

To create new cloud-init VM template:
- make sure you can ssh directly into the Proxmox VE (PVE) host without password
- update [0-createtemplate/inventory.yaml](0-createtemplate/inventory.yaml) and replace `proxmox.local` with the address of the PVE host
- modify `vars` section in [0-createtemplate/create-vm-template.yaml](0-createtemplate/create-vm-template.yaml) as needed
  - note: `cloud_image_path` must have a `.qcow2` extension due to PVE compatibility issue
- from `0-createtemplate` directory root, run:
  ```
  ansible-playbook -i inventory.yaml create-vm-template.yaml -K
  ```

## Provisioning VMs `1-provisionvms`

To provision VMs:
- update [1-provisionvms/variables.tf](1-provisionvms/variables.tf) as needed; replace `proxmox.local` with the address of the PVE host
- update/modify [1-provisionvms/main.tf](1-provisionvms/main.tf) to tweak the configuration of VMs
- from `1-provisionvms` directory, run
  ```
  terraform init
  terraform plan -var='pm_user=root@pam' -var='pm_password=<YOUR_PASSWORD>' -out plan

  terraform apply "plan"
  ```

## Installing Kubernetes `2-installk8s`

To install K8s on new VMs:
- make sure you can ssh directly into all VMs without password
- update [2-installk8s/hosts](2-installk8s/hosts) as needed; replace `ansible_host` IPs to match your environment.
- from `2-installk8s` directory, run:
  ```
  ansible-playbook -i hosts install-k8s.yaml -K
  ```

To bootstrap the cluster with `kubeadm`:
- from `2-installk8s` directory, run:
  ```
  ansible-playbook -i hosts controls.yaml -K
  ```

To join the cluster from the workers:
- from `2-installk8s` directory, run:
  ```
  ansible-playbook -i hosts join-workers.yaml -K
  ```
Once all nodes report STATUS Ready then proceed to perform `post-install.yaml`

    ```
    #  kubectl get nodes
    NAME       STATUS   ROLES           AGE   VERSION
    control0   Ready    control-plane   46h   v1.25.5
    worker0    Ready    <none>          46h   v1.25.5
    worker1    Ready    <none>          46h   v1.25.5
    worker2    Ready    <none>          46h   v1.25.5
    ```

Once networking is up you can install metrics-server, metallb, contour, openEBS:

- from `2-installk8s` directory, run:
  ```
  ansible-playbook -i hosts post-install.yaml -K
  ```


## References:
- [docs for Terraform Proxmox provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
- [Deploy Proxmox virtual machines using Cloud-init](https://norocketscience.at/deploy-proxmox-virtual-machines-using-cloud-init/)
- [Proxmox VMs with Terraform](https://norocketscience.at/provision-proxmox-virtual-machines-with-terraform/)
- [Proxmox, Terraform, and Cloud-Init](https://yetiops.net/posts/proxmox-terraform-cloudinit-saltstack-prometheus/)
