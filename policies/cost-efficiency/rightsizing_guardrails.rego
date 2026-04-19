################################################################################
# 29TH REGIME: COST EFFICIENCY POLICY ENFORCEMENT (OPA/Rego)
# Policy: Resource Right-Sizing & Cost Guardrails
# Reference: FinOps principles, TCO optimization
################################################################################

package sovereign.cost_efficiency

# Define cost thresholds (monthly, EUR)
max_compute_monthly_cost := 50000  # EUR
max_storage_monthly_cost := 20000  # EUR
max_bandwidth_monthly_cost := 10000  # EUR

# Deny: Oversized VM instances (cost abuse)
deny[msg] {
    resource := input.resource
    resource.type == "azurerm_virtual_machine"
    vm_size := resource.vm_size
    is_oversized_vm(vm_size)
    
    msg := sprintf(
        "COST GUARDRAIL: VM '%s' uses oversized instance '%s' (>8 vCPU). Requires justification and cost approval.",
        [resource.name, vm_size]
    )
}

# Deny: Storage account without lifecycle policies (cost waste)
deny[msg] {
    resource := input.resource
    resource.type == "azurerm_storage_account"
    not has_lifecycle_policy(resource)
    
    msg := sprintf(
        "COST GUARDRAIL: Storage account '%s' lacks lifecycle policy. Archive/delete old blobs to optimize cost.",
        [resource.name]
    )
}

# Audit: Database without Reserved Instances (potential cost optimization)
audit[msg] {
    resource := input.resource
    resource.type == "azurerm_mssql_server"
    not has_reserved_instance(resource)
    
    msg := sprintf(
        "COST OPTIMIZATION: Database '%s' not using Reserved Instances. Could save ~40% cost.",
        [resource.name]
    )
}

# Deny: Unmanaged disks (legacy, more expensive)
deny[msg] {
    resource := input.resource
    resource.type == "azurerm_virtual_machine_data_disk"
    resource.managed_disk_type == null
    
    msg := sprintf(
        "COST GUARDRAIL: VM disk '%s' uses unmanaged disks. Migrate to managed disks (cheaper, better reliability).",
        [resource.name]
    )
}

# Helper: Oversized VM detection
is_oversized_vm(vm_size) {
    # Standard_D16s_v3 and larger = 8+ vCPU, expensive
    oversized := [
        "Standard_D16s_v3",
        "Standard_D32s_v3",
        "Standard_D64s_v3",
        "Standard_E16s_v3",
        "Standard_E32s_v3",
        "Standard_F16s",
        "Standard_F32s",
    ]
    oversized[_] == vm_size
}

has_lifecycle_policy(resource) {
    resource.lifecycle_policy != null
    resource.lifecycle_policy.rules != null
    count(resource.lifecycle_policy.rules) > 0
}

has_reserved_instance(resource) {
    resource.reserved_instance_enabled == true
}
