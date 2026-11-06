variable "location" {
  description = "Azure region for the lab"
  type        = string
  default     = "centralus"
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

variable "vm_size" {
  description = "Size of all lab VMs"
  type        = string
  default     = "Standard_B2ms"
}

variable "admin_username" {
  description = "Local administrator user name for the VMs"
  type        = string
  default     = "labadmin"
}

variable "dc_private_ip" {
  description = "Static private IP of the domain controller"
  type        = string
  default     = "10.10.1.10"
}

variable "shutdown_time" {
  description = "Daily auto-shutdown time in HHmm"
  type        = string
  default     = "2300"
}

variable "shutdown_timezone" {
  description = "Windows time zone ID used for the auto-shutdown schedule"
  type        = string
  default     = "Central America Standard Time"
}
