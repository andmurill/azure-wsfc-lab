variable "location" {
  description = "Azure region for the lab"
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Short prefix used in resource names"
  type        = string
  default     = "wsfc"
}

variable "allowed_rdp_cidr" {
  description = "Public IP in CIDR form allowed to RDP to the VMs, e.g. 203.0.113.10/32"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_rdp_cidr, 0))
    error_message = "allowed_rdp_cidr must be a valid CIDR such as 203.0.113.10/32."
  }
}

variable "vnet_address_space" {
  description = "Address space of the virtual network"
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "subnet_prefix" {
  description = "Address prefix of the subnet that holds the VMs"
  type        = string
  default     = "10.10.1.0/24"
}
