################################################################################
# 29TH REGIME: POLICY ENFORCEMENT NODE
# Input Variables
################################################################################

variable "environment" {
  description = "Deployment environment (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "primary_region" {
  description = "Primary AWS region for sovereignty enforcement"
  type        = string
  default     = "eu-west-1"
  validation {
    condition     = startswith(var.primary_region, "eu-")
    error_message = "Primary region must be EU-based per sovereignty doctrine."
  }
}

variable "secondary_region" {
  description = "Secondary AWS region for redundancy and sovereignty"
  type        = string
  default     = "eu-central-1"
  validation {
    condition     = startswith(var.secondary_region, "eu-")
    error_message = "Secondary region must be EU-based per sovereignty doctrine."
  }
}

variable "cost_threshold_monthly" {
  description = "Monthly cost threshold (EUR) for guardrail enforcement"
  type        = number
  default     = 100000
  validation {
    condition     = var.cost_threshold_monthly > 0
    error_message = "Cost threshold must be positive."
  }
}

variable "enable_compliance_enforcement" {
  description = "Enable deterministic compliance guardrails (NIS2, GDPR)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
