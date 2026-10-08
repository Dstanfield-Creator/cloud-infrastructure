# Terraform: AWS VPC and EC2 Baseline

> A minimal, secure AWS starting point: two-AZ VPC with public and private subnets, a single NAT gateway, and one Amazon Linux 2023 instance in a private subnet that is reachable only through Systems Manager Session Manager.

**Status:** Active · **Updated:** 2026-10-08

## Cost warning

This configuration creates billable resources the moment `terraform apply` finishes, even if the instance is idle.

| Resource | Approximate cost | Notes |
|---|---|---|
| NAT gateway | USD 0.045 to 0.059 per hour (USD 33 to 43 per month) plus the same rate per GB processed | Charged while it exists. The single largest line item here |
| Public IPv4 address (NAT EIP) | USD 0.005 per hour (about USD 3.65 per month) | Applies to every public IPv4 address since February 2024 |
| EC2 `t3.micro` | USD 0.010 to 0.013 per hour (USD 8 to 10 per month) | Stop the instance when not needed; the NAT gateway keeps billing |
| gp3 root volume, 20 GiB | USD 1.60 to 1.90 per month | Billed while the volume exists |

Expect roughly USD 45 to 60 per month in total. Prices vary by region; check the AWS pricing pages before applying and run `terraform destroy` when you are done. If you need the instance but not Internet egress, replace the NAT gateway with VPC interface endpoints for `ssm`, `ssmmessages` and `ec2messages` (three endpoints are usually cheaper than one NAT gateway only when traffic is low; do the arithmetic for your region).

## What it creates

```
VPC 172.16.0.0/16
  public-a   172.16.0.0/20    IGW route, hosts the NAT gateway
  public-b   172.16.16.0/20   IGW route
  private-a  172.16.128.0/20  NAT route, hosts the EC2 instance
  private-b  172.16.144.0/20  NAT route
```

| Component | Detail |
|---|---|
| VPC | DNS support and hostnames enabled; the default security group is adopted and emptied |
| Subnets | Two public, two private, across the first two AZs that do not need opt-in; public subnets do not auto-assign public IPs |
| Routing | Public route table to the IGW; private route table to the NAT gateway |
| Security group | No inbound rules. Outbound TCP 443 only, which is all SSM and package updates need |
| IAM | Role and instance profile with the AWS managed `AmazonSSMManagedInstanceCore` policy |
| EC2 | Latest AL2023 AMI from SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`, private subnet, no public IP, IMDSv2 required with hop limit 1, encrypted gp3 root volume |
| Tags | `Project`, `Environment`, `Owner`, `ManagedBy`, `Repository` on every resource via `default_tags`, plus `Name` |

## Prerequisites

- Terraform 1.5 or later and AWS provider `~> 5.0`.
- AWS CLI v2 with credentials from IAM Identity Center or a named profile. Do not export long-lived access keys into shell files that get committed.
- The Session Manager plugin for the AWS CLI, installed locally.
- IAM permissions to create VPC, EC2, IAM roles and instance profiles, and to read the public SSM parameter.

## Usage

```bash
export AWS_PROFILE=sandbox          # or aws sso login --profile sandbox
export AWS_REGION=ap-southeast-2

terraform init
terraform plan -var project_name=demo -var environment=dev
terraform apply -var project_name=demo -var environment=dev
```

Use a `terraform.tfvars` file for anything beyond a demo. Keep it free of secrets; this configuration needs none.

### Connect with Session Manager

The instance has no SSH daemon exposed and no key pair. The SSM agent ships with AL2023 and registers through the NAT gateway a minute or two after boot.

```bash
# Confirm the agent has checked in
aws ssm describe-instance-information \
  --query 'InstanceInformationList[].{ID:InstanceId,Ping:PingStatus,OS:PlatformName}' --output table

# Interactive shell (the output also prints this command)
aws ssm start-session --target "$(terraform output -raw instance_id)"

# Port forward a local port to a service on the instance
aws ssm start-session --target "$(terraform output -raw instance_id)" \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8080"],"localPortNumber":["18080"]}'
```

Sessions are logged in CloudTrail. Enable session logging to S3 or CloudWatch Logs in Systems Manager > Session Manager > Preferences for a full keystroke record.

## Variables

| Name | Default | Description |
|---|---|---|
| `aws_region` | `ap-southeast-2` | Deployment region |
| `project_name` | `baseline` | Prefix for names and the `Project` tag |
| `environment` | `dev` | One of `dev`, `test`, `staging`, `prod` |
| `owner` | `platform-team@example.com` | `Owner` tag |
| `additional_tags` | `{}` | Extra tags merged into `default_tags` |
| `vpc_cidr` | `172.16.0.0/16` | RFC 1918 range, /24 or larger |
| `instance_type` | `t3.micro` | EC2 instance type |
| `root_volume_size_gb` | `20` | gp3 root volume size |
| `kms_key_id` | `null` | Customer managed key for the root volume; null uses `aws/ebs` |
| `detailed_monitoring` | `false` | 1-minute CloudWatch metrics |

## Outputs

| Name | Description |
|---|---|
| `vpc_id`, `vpc_cidr`, `availability_zones` | Network identity |
| `public_subnet_ids`, `private_subnet_ids` | Subnet IDs for attaching further resources |
| `nat_gateway_public_ip` | Source address for all outbound traffic from private subnets (useful for allow-lists) |
| `instance_id`, `instance_private_ip`, `ami_id` | Instance details |
| `instance_security_group_id`, `instance_role_arn` | For extending access rules or IAM policy |
| `ssm_session_command` | Copy-paste `aws ssm start-session` command |

## Design notes

- The AMI is pinned in state with `ignore_changes = [ami]`. New AL2023 releases will not replace the instance on their own. Run `terraform apply -replace=aws_instance.this` when you want to roll forward.
- `http_put_response_hop_limit = 1` means a container running on the instance cannot reach the instance role credentials. Raise it to 2 only if you knowingly run containers that need the role.
- Nothing listens publicly. If you add a load balancer, place it in the public subnets and add a security group rule that allows the load balancer's security group, not a CIDR, to reach the instance.
- Not included, by design: VPC flow logs, CloudTrail, GuardDuty, backups. Add them before using this for anything that matters.

## Teardown

```bash
terraform destroy
```

Destroy removes the NAT gateway and releases the Elastic IP, which stops the hourly charges. Check the VPC console afterwards for anything created outside Terraform (for example ENIs left by a service you attached by hand), because those block VPC deletion.

---

**Author:** Danny Stanfield · Perth, WA  
**License:** MIT
