# Cloud Infrastructure

> Infrastructure as Code and operational reference for public cloud: Terraform on AWS, CLI references for AWS and Azure, and a professional Azure operations case study. This is the Cloud department of my GitHub.

**Status:** Active · **Updated:** 2026-10-08

## Structure

```
├── terraform/
│   └── aws-vpc-ec2-baseline/   # Two-AZ VPC, single NAT gateway, SSM-only EC2 (IMDSv2, encrypted gp3)
├── reference/
│   └── cloud-cli-cheatsheet.md # AWS CLI and Azure CLI quick reference
├── case-studies/
│   └── cloud-vm-management/    # Professional: Azure VM/storage/network operations, PowerShell, ServiceNow, ITIL
├── CONTRIBUTING.md             # Contribution guidelines
└── LICENSE
```

## Contents

| Path | Description | Status |
|---|---|---|
| [terraform/aws-vpc-ec2-baseline/](./terraform/aws-vpc-ec2-baseline/) | Two-AZ VPC with public/private subnets, single NAT gateway, and an SSM-only EC2 instance (no inbound SSH, IMDSv2, encrypted gp3) | Reference |
| [reference/cloud-cli-cheatsheet.md](./reference/cloud-cli-cheatsheet.md) | AWS CLI and Azure CLI quick reference for identity, instances, security groups, storage, public-exposure checks, cost and remote shells | Active |
| [case-studies/cloud-vm-management/](./case-studies/cloud-vm-management/) | Azure VM, storage and network operations, PowerShell automation, ServiceNow and ITIL change process (2021–2022) | Completed |

## Moved to other departments

- Proxmox VM Terraform and the cloud-init guide: [lab-ops](https://github.com/Dstanfield-Creator/lab-ops) (`terraform/proxmox-vm/`, `docs/`)
- Prometheus / Grafana Compose stack: [monitoring](https://github.com/Dstanfield-Creator/cyber-resources/tree/master/monitoring/compose/monitoring-stack)

## Conventions

- No account IDs, ARNs with account numbers, key names or public IPs appear in committed files. Terraform reads credentials from the environment.

---

**Author:** Danny Stanfield · Perth, WA  
**License:** MIT
