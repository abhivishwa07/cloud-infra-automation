# ==============================================================================
# Input Variables
# ==============================================================================

variable "location" {
  type        = string
  description = "The Azure Region where resources should be created."
  default     = "North Central US"
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group in which to create the storage account."
  default     = "rg-terraform"
}

variable "storage_account_prefix" {
  type        = string
  description = "Prefix for the storage account name. A random suffix will be appended to ensure global uniqueness."
  default     = "tfstore"
}

variable "account_tier" {
  type        = string
  description = "Defines the Tier to use for this storage account. Valid options are Standard and Premium."
  default     = "Standard"
}

variable "account_replication_type" {
  type        = string
  description = "Defines the type of replication to use for this storage account. Valid options are LRS, GRS, RAGRS, ZRS, GZRS and RAGZRS."
  default     = "LRS"
}

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resources."
  default = {
    Environment = "Development"
    CreatedBy   = "Terraform"
    Project     = "AzureStorageProvisioning"
  }
}

variable "vm_size" {
  type        = string
  description = "The SKU size for the Linux Virtual Machine."
  default     = "Standard_B2s"
}

variable "admin_username" {
  type        = string
  description = "The administrator username for the VM."
  default     = "azureuser"
}

