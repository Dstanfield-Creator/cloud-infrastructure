# AWS baseline: two-AZ VPC, single NAT gateway, one private EC2 instance
# reachable only through AWS Systems Manager Session Manager.
#
# Credentials are resolved by the AWS provider from the environment or the
# shared config (AWS_PROFILE, IAM Identity Center, instance role). Nothing in
# this configuration stores a credential.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Applied to every taggable resource created through this provider.
  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        Owner       = var.owner
        ManagedBy   = "terraform"
        Repository  = "cloud-infrastructure/terraform/aws-vpc-ec2-baseline"
      },
      var.additional_tags,
    )
  }
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Latest Amazon Linux 2023 AMI published by AWS for this region.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)

  # A /16 VPC yields /20 subnets. Public subnets take the first two blocks,
  # private subnets start at block 8 to leave room for more tiers later.
  public_subnet_cidrs  = [for i in range(2) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnet_cidrs = [for i in range(2) : cidrsubnet(var.vpc_cidr, 4, i + 8)]
}

# --- Network -----------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name_prefix}-vpc" }
}

# Adopt the VPC default security group and strip every rule from it so
# nothing can rely on it by accident.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name_prefix}-default-locked" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-public-${local.azs[count.index]}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${local.name_prefix}-private-${local.azs[count.index]}"
    Tier = "private"
  }
}

# One NAT gateway keeps cost down at the expense of AZ resilience. It is
# billed per hour and per GB processed whether or not anything uses it.
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]
  tags       = { Name = "${local.name_prefix}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.this]
  tags          = { Name = "${local.name_prefix}-nat" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name_prefix}-private-rt" }
}

resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- Security group ----------------------------------------------------------

# No ingress rules at all. Shell access goes through Session Manager, which
# only needs outbound HTTPS from the instance to the SSM endpoints. DNS,
# DHCP, NTP and IMDS traffic is not filtered by security groups.
resource "aws_security_group" "instance" {
  name        = "${local.name_prefix}-instance"
  description = "Baseline instance SG: no inbound, HTTPS outbound only"
  vpc_id      = aws_vpc.this.id

  tags = { Name = "${local.name_prefix}-instance" }
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.instance.id
  description       = "HTTPS out for SSM, package repositories and updates"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# --- IAM ---------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${local.name_prefix}-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.instance.name
}

# --- Compute -----------------------------------------------------------------

resource "aws_instance" "this" {
  ami                         = nonsensitive(data.aws_ssm_parameter.al2023_ami.value)
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  associate_public_ip_address = false
  ebs_optimized               = true
  monitoring                  = var.detailed_monitoring

  # IMDSv2 only. A hop limit of 1 stops containers on the host from reaching
  # the instance role credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    encrypted             = true
    kms_key_id            = var.kms_key_id
    delete_on_termination = true
    tags                  = { Name = "${local.name_prefix}-app-root" }
  }

  tags = { Name = "${local.name_prefix}-app" }

  # The SSM agent only registers once the role carries the SSM policy.
  depends_on = [aws_iam_role_policy_attachment.ssm_core]

  lifecycle {
    # The SSM parameter moves with every AL2023 release. Ignoring it keeps
    # Terraform from replacing the instance on each plan; remove this line
    # (or use -replace) to roll forward deliberately.
    ignore_changes = [ami]
  }
}
