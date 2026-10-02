# ==============================================================================
# Output Values
# ==============================================================================

output "resource_group_name" {
  description = "The name of the Resource Group created."
  value       = azurerm_resource_group.rg.name
}

output "storage_account_id" {
  description = "The ID of the Storage Account."
  value       = azurerm_storage_account.storage.id
}

output "storage_account_name" {
  description = "The generated name of the Storage Account (with unique suffix)."
  value       = azurerm_storage_account.storage.name
}

output "storage_primary_blob_endpoint" {
  description = "The primary endpoint for blob storage."
  value       = azurerm_storage_account.storage.primary_blob_endpoint
}

output "public_ip_address" {
  description = "The Public IP address of the virtual machine."
  value       = azurerm_public_ip.public_ip.ip_address
}

output "virtual_machine_id" {
  description = "The ID of the Virtual Machine."
  value       = azurerm_linux_virtual_machine.vm.id
}

output "ssh_private_key_pem" {
  description = "The generated private SSH key for accessing the VM."
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

