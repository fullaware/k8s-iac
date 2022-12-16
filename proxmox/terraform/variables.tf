variable "pm_api_url" {
  default = "https://10.28.28.10:8006/api2/json"
}

variable "pm_node" {
  default = "pve"
}

variable "pm_user" {
  default = ""
}

variable "pm_password" {
  default = ""
}

variable "ssh_key_file" {
  default = "~/.ssh/id_ed25519.pub"
}
