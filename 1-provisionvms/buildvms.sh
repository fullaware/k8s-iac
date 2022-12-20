terraform init
terraform plan -var='pm_user=root@pam' -var='pm_password=<YOUR_PASSWORD>' -out plan
terraform apply "plan"
