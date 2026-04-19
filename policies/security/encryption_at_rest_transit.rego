################################################################################
# 29TH REGIME: SECURITY POLICY ENFORCEMENT (OPA/Rego)
# Policy: Encryption at Rest & In Transit
# Reference: NIS2 Article 21, GDPR Article 32 (Technical & Organizational Measures)
################################################################################

package sovereign.security

# Deny: Storage account without encryption at rest
deny[msg] {
    resource := input.resource
    resource.type == "azurerm_storage_account"
    not has_encryption_at_rest(resource)
    
    msg := sprintf(
        "DETERMINISTIC DENY: Storage account '%s' lacks encryption at rest. Violates GDPR Article 32(1)(a).",
        [resource.name]
    )
}

# Deny: Database without Transparent Data Encryption (TDE)
deny[msg] {
    resource := input.resource
    resource.type in ["azurerm_mssql_server", "azurerm_postgresql_server"]
    not has_tde_enabled(resource)
    
    msg := sprintf(
        "DETERMINISTIC DENY: Database '%s' lacks TDE (Transparent Data Encryption). Non-compliant with NIS2.",
        [resource.name]
    )
}

# Deny: Network traffic without TLS/HTTPS
deny[msg] {
    resource := input.resource
    resource.type == "azurerm_api_management_api"
    not has_https_protocol(resource)
    
    msg := sprintf(
        "DETERMINISTIC DENY: API '%s' does not enforce HTTPS. Violates data-in-transit encryption mandate.",
        [resource.name]
    )
}

# Deny: CORS configured with wildcard origins
deny[msg] {
    resource := input.resource
    cors := resource.cors_policy
    cors.allowed_origins[_] == "*"
    
    msg := sprintf(
        "DETERMINISTIC DENY: Resource '%s' CORS allows wildcard origins. Cross-site attack vector.",
        [resource.name]
    )
}

# Deny: Network security group allows public RDP access
deny[msg] {
    resource := input.resource
    resource.type == "azurerm_network_security_rule"
    resource.direction == "Inbound"
    resource.access == "Allow"
    resource.destination_port_range in ["3389", "*"]
    resource.source_address_prefix == "*"
    
    msg := sprintf(
        "DETERMINISTIC DENY: NSG rule '%s' exposes RDP to public internet. Critical vulnerability.",
        [resource.name]
    )
}

# Helper functions
has_encryption_at_rest(resource) {
    resource.customer_managed_key_enabled == true
}

has_tde_enabled(resource) {
    resource.transparent_data_encryption[0].enabled == true
}

has_https_protocol(resource) {
    resource.protocols[_] == "https"
}
