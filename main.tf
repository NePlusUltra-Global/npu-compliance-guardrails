################################################################################
# 29TH REGIME: POLICY ENFORCEMENT NODE
# Terraform Root Configuration
# Purpose: Deterministic sovereignty guardrails for EU-centric infrastructure
################################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Cloud backend configured per deployment environment
  # cloud {
  #   organization = "29th-regime-oss"
  #   workspaces {
  #     name = "sovereignty-enforcement"
  #   }
  # }
}

provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      Regime      = "29TH"
      Enforcement = "Policy-as-Code"
      Doctrine    = "European Digital Sovereignty"
      ManagedBy   = "Terraform"
      AuditDate   = timestamp()
    }
  }
}

################################################################################
# Sovereignty Module: EU-West-1 (Primary)
################################################################################

module "sovereign_logging_primary" {
  source = "./modules/npu-sovereign-logging-s3"

  environment = var.environment
  region      = "eu-west-1"
  purpose     = "deterministic_audit_trail"

  bucket_name_prefix = "sovereign-audit-trail"
  enforce_encryption = true
  enforce_versioning = true
  enable_replication = false # Replicated via secondary module

  tags = {
    Sovereignty = "eu-west-1"
    Region      = "IE"
  }
}

################################################################################
# Sovereignty Module: EU-Central-1 (Secondary)
################################################################################

module "sovereign_logging_secondary" {
  source = "./modules/npu-sovereign-logging-s3"

  environment = var.environment
  region      = "eu-central-1"
  purpose     = "replicated_audit_trail"

  bucket_name_prefix = "sovereign-audit-trail"
  enforce_encryption = true
  enforce_versioning = true
  enable_replication = false

  tags = {
    Sovereignty = "eu-central-1"
    Region      = "DE"
  }
}

################################################################################
# Outputs: Enforcement Node Status
################################################################################

output "primary_audit_bucket" {
  description = "EU-West-1 Sovereign Audit Trail Bucket ARN"
  value       = module.sovereign_logging_primary.bucket_arn
}

output "secondary_audit_bucket" {
  description = "EU-Central-1 Replicated Audit Trail Bucket ARN"
  value       = module.sovereign_logging_secondary.bucket_arn
}

output "enforcement_node_id" {
  description = "Policy enforcement node identifier"
  value       = "29TH-REGIME-${var.environment}-${var.primary_region}"
}
