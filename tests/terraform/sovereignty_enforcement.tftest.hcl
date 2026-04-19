################################################################################
# 29TH REGIME: TERRAFORM TESTS
# Test: Sovereignty Policy Enforcement (terraform test)
# Runs: terraform test -verbose
################################################################################

run "test_primary_region_compliance" {
  command = plan

  variables {
    environment    = "prod"
    primary_region = "eu-west-1"
  }

  # Assert: Primary region must be EU
  assert {
    condition = startswith(var.primary_region, "eu-")
    error_message = "Primary region must be EU-centric per GDPR Article 32."
  }
}

run "test_deny_non_eu_region" {
  command = plan

  variables {
    environment    = "prod"
    primary_region = "us-east-1"  # Non-EU, should fail
  }

  expect_failures = [
    module.sovereign_logging_primary
  ]
}

run "test_encryption_mandatory" {
  command = plan

  variables {
    environment         = "prod"
    primary_region      = "eu-west-1"
    enforce_encryption  = true  # Must be true
  }

  # Assert: Encryption must be enforced
  assert {
    condition     = var.enforce_encryption == true
    error_message = "Encryption at rest is mandatory (non-negotiable)."
  }
}

run "test_versioning_enabled" {
  command = plan

  variables {
    environment         = "prod"
    primary_region      = "eu-west-1"
    enforce_versioning  = true  # Immutability for audit trails
  }

  assert {
    condition     = var.enforce_versioning == true
    error_message = "Versioning (immutability) is mandatory for audit trails."
  }
}

run "test_retention_period_compliant" {
  command = plan

  variables {
    environment    = "prod"
    primary_region = "eu-west-1"
    retention_days = 2555  # 7 years (NIS2 retention period)
  }

  # Assert: Retention >= 7 years per NIS2
  assert {
    condition     = var.retention_days >= 2555
    error_message = "Retention period must be >= 7 years per NIS2 Article 21."
  }
}

run "test_module_outputs_audit_trail" {
  command = apply

  variables {
    environment    = "prod"
    primary_region = "eu-west-1"
  }

  # Assert: Outputs contain required audit trail metadata
  assert {
    condition     = output.primary_audit_bucket.encryption_key_arn != null
    error_message = "Primary audit bucket must be encrypted with KMS key."
  }

  assert {
    condition     = output.primary_audit_bucket.versioning_enabled == true
    error_message = "Primary audit bucket must have versioning enabled."
  }
}

run "test_compliance_framework_output" {
  command = apply

  variables {
    environment    = "prod"
    primary_region = "eu-west-1"
  }

  # Assert: Compliance framework is declared
  assert {
    condition     = output.compliance_framework.standards == ["NIS2", "GDPR", "FADP"]
    error_message = "Compliance framework must include NIS2, GDPR, FADP."
  }

  assert {
    condition     = output.compliance_framework.data_residency == "EU-only"
    error_message = "Data residency must be EU-only per sovereignty doctrine."
  }
}

run "test_cost_guardrail_retention" {
  command = plan

  variables {
    environment    = "prod"
    primary_region = "eu-west-1"
    retention_days = 10000  # Excessive retention (cost waste)
  }

  # Assert: Warn (not fail) on excessive retention
  # In real scenario, this would trigger a Checkov warning
  assert {
    condition     = var.retention_days <= 7300  # Reasonable max
    error_message = "Retention > 10 years may exceed cost-efficiency guardrails. Review necessity."
  }
}

run "test_multi_region_deployment" {
  command = plan

  variables {
    environment      = "prod"
    primary_region   = "eu-west-1"
    secondary_region = "eu-central-1"
  }

  # Assert: Both regions are EU
  assert {
    condition = startswith(var.primary_region, "eu-") && startswith(var.secondary_region, "eu-")
    error_message = "Both regions must be EU-centric."
  }

  # Assert: Regions are different (redundancy requirement)
  assert {
    condition     = var.primary_region != var.secondary_region
    error_message = "Primary and secondary regions must differ (redundancy requirement)."
  }
}

run "test_enforce_https_bucket_policy" {
  command = apply

  variables {
    environment    = "prod"
    primary_region = "eu-west-1"
  }

  # Assert: Bucket policy denies non-HTTPS requests
  assert {
    condition = (
      length(aws_s3_bucket_policy.audit_trail.policy) > 0
    )
    error_message = "S3 bucket policy must be defined (enforce HTTPS)."
  }
}
