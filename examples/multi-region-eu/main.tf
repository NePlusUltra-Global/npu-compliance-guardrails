################################################################################
# 29TH REGIME: MULTI-REGION EU SOVEREIGNTY ENFORCEMENT
# Example: Deploying to EU-West-1 (Ireland) + EU-Central-1 (Frankfurt)
# Demonstrates: Reusable modules, cross-region audit trails, deterministic enforcement
#
# ARCHITECTURE:
# See README.md for full architecture diagram (Mermaid flowchart).
# This configuration deploys:
#  - Primary: eu-west-1 (Ireland) — GDPR hub with audit trail bucket
#  - Secondary: eu-central-1 (Frankfurt) — redundancy with cross-region replication
#  - Encryption: KMS-managed keys, versioning enabled, retention 7 years
#
################################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Terraform Cloud backend configuration (optional)
  # cloud {
  #   organization = "29th-regime-oss"
  #   workspaces {
  #     name = "sovereignty-eu-multiregion"
  #   }
  # }
}

################################################################################
# VARIABLES: Deployment Configuration
################################################################################

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Must be dev, test, or prod."
  }
}

variable "primary_region" {
  description = "Primary AWS region (Ireland — GDPR hub)"
  type        = string
  default     = "eu-west-1"
}

variable "secondary_region" {
  description = "Secondary AWS region (Frankfurt — redundancy)"
  type        = string
  default     = "eu-central-1"
}

################################################################################
# PROVIDER: Primary Region (EU-West-1)
################################################################################

provider "aws" {
  alias  = "primary"
  region = var.primary_region
  
  default_tags {
    tags = {
      Regime           = "29TH"
      Environment      = var.environment
      Enforcement      = "Policy-as-Code"
      Jurisdiction     = "EU"
      ComplianceFrame  = "NIS2+GDPR"
      Doctrine         = "Sovereignty is Deterministic Enforcement"
    }
  }
}

################################################################################
# PROVIDER: Secondary Region (EU-Central-1)
################################################################################

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
  
  default_tags {
    tags = {
      Regime           = "29TH"
      Environment      = var.environment
      Enforcement      = "Policy-as-Code"
      Jurisdiction     = "EU"
      ComplianceFrame  = "NIS2+GDPR"
      Doctrine         = "Sovereignty is Deterministic Enforcement"
    }
  }
}

################################################################################
# PRIMARY REGION: Sovereign Audit Trail (Primary)
################################################################################

module "sovereign_logging_primary" {
  source = "../../modules/npu-sovereign-logging-s3"
  
  providers = {
    aws = aws.primary
  }
  
  environment         = var.environment
  region              = var.primary_region
  purpose             = "primary_audit_trail"
  bucket_name_prefix  = "29th-regime-audit"
  enforce_encryption  = true
  enforce_versioning  = true
  enable_replication  = false
  retention_days      = 2555  # 7 years
  
  tags = {
    SovereigntyNode = "Primary"
    DataCenter      = "IE"
    GeopoliticalZone = "EU-Western"
  }
}

################################################################################
# SECONDARY REGION: Sovereign Audit Trail (Failover/Redundancy)
################################################################################

module "sovereign_logging_secondary" {
  source = "../../modules/npu-sovereign-logging-s3"
  
  providers = {
    aws = aws.secondary
  }
  
  environment         = var.environment
  region              = var.secondary_region
  purpose             = "secondary_audit_trail"
  bucket_name_prefix  = "29th-regime-audit"
  enforce_encryption  = true
  enforce_versioning  = true
  enable_replication  = false
  retention_days      = 2555  # 7 years
  
  tags = {
    SovereigntyNode = "Secondary"
    DataCenter      = "DE"
    GeopoliticalZone = "EU-Central"
  }
}

################################################################################
# CROSS-REGION REPLICATION: Primary → Secondary (Manual Setup)
# Note: S3 replication requires separate configuration outside modules
################################################################################

resource "aws_s3_bucket_replication_configuration" "primary_to_secondary" {
  provider = aws.primary
  
  role   = aws_iam_role.replication.arn
  bucket = module.sovereign_logging_primary.bucket_id
  
  depends_on = [
    module.sovereign_logging_primary,
    module.sovereign_logging_secondary
  ]
  
  rule {
    id     = "replicate-to-secondary"
    status = "Enabled"
    
    destination {
      bucket       = module.sovereign_logging_secondary.bucket_arn
      storage_class = "STANDARD"
    }
  }
}

################################################################################
# IAM ROLE: Cross-Region Replication
################################################################################

resource "aws_iam_role" "replication" {
  name = "29th-regime-s3-replication-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "replication" {
  name = "29th-regime-s3-replication-policy"
  role = aws_iam_role.replication.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = module.sovereign_logging_primary.bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${module.sovereign_logging_primary.bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${module.sovereign_logging_secondary.bucket_arn}/*"
      }
    ]
  })
}

################################################################################
# OUTPUTS: Infrastructure Status
################################################################################

output "primary_audit_bucket" {
  description = "Primary audit trail bucket (EU-West-1, Ireland)"
  value = {
    bucket_id             = module.sovereign_logging_primary.bucket_id
    bucket_arn            = module.sovereign_logging_primary.bucket_arn
    region                = var.primary_region
    encryption_key_arn    = module.sovereign_logging_primary.encryption_key_arn
    versioning_enabled    = module.sovereign_logging_primary.versioning_enabled
    retention_days        = module.sovereign_logging_primary.retention_days
  }
}

output "secondary_audit_bucket" {
  description = "Secondary audit trail bucket (EU-Central-1, Frankfurt) — Failover"
  value = {
    bucket_id             = module.sovereign_logging_secondary.bucket_id
    bucket_arn            = module.sovereign_logging_secondary.bucket_arn
    region                = var.secondary_region
    encryption_key_arn    = module.sovereign_logging_secondary.encryption_key_arn
    versioning_enabled    = module.sovereign_logging_secondary.versioning_enabled
    retention_days        = module.sovereign_logging_secondary.retention_days
  }
}

output "enforcement_node_id" {
  description = "Policy enforcement node identifier"
  value       = "29TH-REGIME-${var.environment}-${var.primary_region}-MULTI-REGION"
}

output "compliance_framework" {
  description = "Compliance framework enforced"
  value = {
    standards = ["NIS2", "GDPR", "FADP"]
    enforcement_type = "Deterministic Policy-as-Code"
    data_residency = "EU-only"
    audit_trail_retention_years = 7
    geopolitical_zones = ["EU-Western (Ireland)", "EU-Central (Frankfurt)"]
  }
}
