variable "aws_region" {
  description = "Region to deploy into."
  type        = string
  default     = "ap-southeast-2"
}

# --- Tagging -----------------------------------------------------------------

variable "project_name" {
  description = "Short project identifier used in resource names and the Project tag."
  type        = string
  default     = "baseline"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,24}$", var.project_name))
    error_message = "project_name must be 2-24 lowercase letters, digits or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment, used in names and the Environment tag."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev, test, staging, prod."
  }
}

variable "owner" {
  description = "Team or distribution list responsible for the resources (Owner tag)."
  type        = string
  default     = "platform-team@example.com"
}

variable "additional_tags" {
  description = "Extra tags merged into default_tags for every resource."
  type        = map(string)
  default     = {}
}

# --- Network -----------------------------------------------------------------

variable "vpc_cidr" {
  description = "RFC 1918 CIDR for the VPC. Subnets are carved as /20s from a /16; pick a range that does not overlap your other networks."
  type        = string
  default     = "172.16.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && can(regex("/([0-9]|1[0-9]|2[0-4])$", var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR no smaller than /24."
  }
}

# --- Compute -----------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type. Must support IMDSv2 and gp3 (all current families do)."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size_gb" {
  description = "Root gp3 volume size in GiB. AL2023 needs at least 8."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size_gb >= 8
    error_message = "root_volume_size_gb must be at least 8."
  }
}

variable "kms_key_id" {
  description = "Customer managed KMS key ARN for the root volume. Null uses the AWS managed aws/ebs key."
  type        = string
  default     = null
}

variable "detailed_monitoring" {
  description = "Enable 1-minute CloudWatch metrics for the instance (extra cost)."
  type        = bool
  default     = false
}
