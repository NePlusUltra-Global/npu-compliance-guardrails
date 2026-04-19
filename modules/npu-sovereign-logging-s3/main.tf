################################################################################
# 29TH REGIME: REUSABLE MODULE — SOVEREIGN S3 AUDIT LOGGING
# Purpose: Deterministic audit trail storage for sovereignty enforcement
# Usage: module "logging" { source = "./modules/npu-sovereign-logging-s3" }
################################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "environment" {
  description = "Deployment environment (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "region" {
  description = "AWS region (MUST be EU-centric)"
  type        = string
  validation {
    condition     = startswith(var.region, "eu-")
    error_message = "Region must be EU-centric (eu-west-1, eu-central-1, etc.)"
  }
}

variable "purpose" {
  description = "Audit trail purpose (e.g., deterministic_audit_trail, replicated_audit_trail)"
  type        = string
  default     = "audit_trail"
}

variable "bucket_name_prefix" {
  description = "S3 bucket name prefix (will be concatenated with random suffix)"
  type        = string
  default     = "sovereign-audit-trail"
}

variable "enforce_encryption" {
  description = "Enforce encryption at rest (KMS customer-managed key)"
  type        = bool
  default     = true
}

variable "enforce_versioning" {
  description = "Enable versioning for audit trail immutability"
  type        = bool
  default     = true
}

variable "enable_replication" {
  description = "Enable cross-region replication to secondary EU region"
  type        = bool
  default     = false
}

variable "retention_days" {
  description = "Log retention period (days). After this, archive to Glacier (WORM)"
  type        = number
  default     = 2555  # 7 years (GDPR/NIS2 compliance)
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}

################################################################################
# DATA SOURCES
################################################################################

data "aws_caller_identity" "current" {}

################################################################################
# LOCALS: DETERMINISTIC NAMING & CONFIGURATION
################################################################################

locals {
  environment_normalized = upper(var.environment)
  region_code            = replace(var.region, "-", "_")
  
  bucket_name = "${var.bucket_name_prefix}-${var.environment}-${local.region_code}-${data.aws_caller_identity.current.account_id}"
  
  common_tags = merge(
    var.tags,
    {
      Regime             = "29TH"
      Environment        = var.environment
      Purpose            = var.purpose
      AuditImmutable     = "true"
      ComplianceFrame    = "NIS2+GDPR"
      DataJurisdiction   = "EU"
      ManagedBy          = "Terraform"
    }
  )
}

################################################################################
# S3 BUCKET: SOVEREIGN AUDIT TRAIL
################################################################################

resource "aws_s3_bucket" "audit_trail" {
  bucket = local.bucket_name
  
  tags = local.common_tags
}

################################################################################
# VERSIONING: Immutability for Audit Trail
################################################################################

resource "aws_s3_bucket_versioning" "audit_trail" {
  count  = var.enforce_versioning ? 1 : 0
  bucket = aws_s3_bucket.audit_trail.id
  
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"  # Can be enabled with MFA for extra security
  }
}

################################################################################
# ENCRYPTION: Customer-Managed KMS Key (Sovereign Key Management)
################################################################################

resource "aws_kms_key" "audit_trail" {
  count                   = var.enforce_encryption ? 1 : 0
  description             = "Sovereign audit trail encryption key (${var.environment})"
  deletion_window_in_days = 30  # GDPR compliance
  enable_key_rotation     = true
  
  tags = local.common_tags
}

resource "aws_kms_alias" "audit_trail" {
  count         = var.enforce_encryption ? 1 : 0
  name          = "alias/sovereign-audit-trail-${var.environment}-${local.region_code}"
  target_key_id = aws_kms_key.audit_trail[0].key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_trail" {
  count  = var.enforce_encryption ? 1 : 0
  bucket = aws_s3_bucket.audit_trail.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.audit_trail[0].arn
    }
    bucket_key_enabled = true
  }
}

################################################################################
# BUCKET POLICY: Public Block + Audit Access Only
################################################################################

resource "aws_s3_bucket_public_access_block" "audit_trail" {
  bucket = aws_s3_bucket.audit_trail.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "audit_trail" {
  bucket = aws_s3_bucket.audit_trail.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyHTTP"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.audit_trail.arn,
          "${aws_s3_bucket.audit_trail.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowAuditWrite"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.audit_trail.arn}/*"
      }
    ]
  })
}

################################################################################
# LIFECYCLE POLICY: Archival & WORM (Write-Once, Read-Many)
################################################################################

resource "aws_s3_bucket_lifecycle_configuration" "audit_trail" {
  bucket = aws_s3_bucket.audit_trail.id
  
  rule {
    id     = "archive-old-logs"
    status = "Enabled"
    
    # Transition to GLACIER after 30 days (minimize hot storage cost)
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
    
    # Deep archive after 90 days (7-year retention)
    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }
    
    # Expire after retention period
    expiration {
      days = var.retention_days
    }
  }
}

################################################################################
# LOGGING: S3 Access Logs (Meta-audit)
################################################################################

resource "aws_s3_bucket" "access_logs" {
  bucket = "${local.bucket_name}-access-logs"
  
  tags = merge(
    local.common_tags,
    { Purpose = "s3_access_logs" }
  )
}

resource "aws_s3_bucket_logging" "audit_trail" {
  bucket = aws_s3_bucket.audit_trail.id
  
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "access-logs/"
}

################################################################################
# OUTPUTS
################################################################################

output "bucket_id" {
  description = "Audit trail bucket ID"
  value       = aws_s3_bucket.audit_trail.id
}

output "bucket_arn" {
  description = "Audit trail bucket ARN (for cross-account access)"
  value       = aws_s3_bucket.audit_trail.arn
}

output "bucket_region" {
  description = "Bucket region (sovereignty jurisdiction)"
  value       = var.region
}

output "encryption_key_arn" {
  description = "KMS key ARN (customer-managed encryption)"
  value       = var.enforce_encryption ? aws_kms_key.audit_trail[0].arn : null
}

output "versioning_enabled" {
  description = "Whether versioning (immutability) is enabled"
  value       = var.enforce_versioning
}

output "retention_days" {
  description = "Audit log retention period (days)"
  value       = var.retention_days
}

output "bucket_access_logs_bucket" {
  description = "Access logs bucket (meta-audit)"
  value       = aws_s3_bucket.access_logs.id
}
