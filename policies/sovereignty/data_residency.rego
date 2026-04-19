################################################################################
# 29TH REGIME: SOVEREIGNTY POLICY ENFORCEMENT (OPA/Rego)
# Policy: EU Data Residency Enforcement
# Reference: GDPR Article 32, NIS2 Article 21
################################################################################

package sovereign.data_residency

# Allowed EU regions for data processing
allowed_eu_regions := [
    "eu-west-1",           # AWS Ireland
    "eu-central-1",        # AWS Frankfurt
    "eu-north-1",          # AWS Stockholm
    "westeurope",          # Azure Netherlands
    "northeurope",         # Azure Ireland
    "germanywestcentral",  # Azure Frankfurt
    "switzerlandnorth",    # Azure Switzerland (non-EU but GDPR compliant)
    "europe-west1",        # GCP Belgium
    "europe-west4",        # GCP Netherlands
    "europe-north1",       # GCP Finland
]

# Forbidden regions (non-EU, non-compliant)
forbidden_regions := [
    "us-east-1",
    "us-west-2",
    "ap-southeast-1",
    "ap-northeast-1",
    "ca-central-1",
]

# Deny: Resource deployed to non-EU region
deny[msg] {
    resource := input.resource
    location := resource.location
    not contains_value(allowed_eu_regions, location)
    
    msg := sprintf(
        "DETERMINISTIC DENY: Resource '%s' deployed to non-EU region '%s'. Violates GDPR Article 32 (EU data residency).",
        [resource.name, location]
    )
}

# Deny: Resource in forbidden region
deny[msg] {
    resource := input.resource
    location := resource.location
    contains_value(forbidden_regions, location)
    
    msg := sprintf(
        "HARD BLOCK: Resource '%s' in forbidden region '%s'. Non-compliance with sovereignty doctrine.",
        [resource.name, location]
    )
}

# Audit: Storage account replication target
audit[msg] {
    resource := input.resource
    resource.type == "azurerm_storage_account"
    replication := resource.account_replication_type
    replication in ["GRS", "RA-GRS"]  # Geo-replication to non-EU
    
    msg := sprintf(
        "AUDIT: Storage account '%s' replicates to non-EU region. Consider LRS/ZRS for EU-only.",
        [resource.name]
    )
}

# Helper: Check if value exists in array
contains_value(arr, val) {
    arr[_] == val
}
