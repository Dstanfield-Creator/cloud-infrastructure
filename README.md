# Cloud Infrastructure

Cloud platform guides, Infrastructure-as-Code, deployment strategies, and operational best practices for AWS, Azure, and GCP.

## Structure

```
├── docs/                # Cloud architecture and deployment guides
├── terraform/           # Terraform modules and configurations
├── docker-compose/      # Container orchestration examples
├── reference/           # Quick reference and checklists
├── CONTRIBUTING.md      # Contribution guidelines
└── LICENSE
```

## Platforms & Topics

- **AWS** — EC2, S3, RDS, VPC, Lambda, IAM, monitoring
- **Azure** — VMs, App Services, SQL Database, AKS, cost management
- **GCP** — Compute Engine, Cloud Storage, Firestore, Kubernetes
- **Infrastructure as Code** — Terraform, CloudFormation, ARM templates
- **Containers & Orchestration** — Docker, Kubernetes, ECS, AKS
- **Networking** — VPC design, security groups, load balancing, DNS
- **Cost Optimization** — Reserved instances, spot pricing, resource tagging
- **Disaster Recovery & HA** — Failover, backups, multi-region strategies

## Contents

| Path | Description |
|---|---|
| [terraform/proxmox-vm/](./terraform/proxmox-vm/) | Debian 12 cloud-image VM on Proxmox VE with the bpg/proxmox provider: image download, cloud-init snippet, LVM-thin disk, API token from environment variables |
| [terraform/aws-vpc-ec2-baseline/](./terraform/aws-vpc-ec2-baseline/) | Two-AZ VPC with public/private subnets, single NAT gateway, and an SSM-only EC2 instance (no inbound SSH, IMDSv2, encrypted gp3) |
| [docker-compose/monitoring-stack/](./docker-compose/monitoring-stack/) | Prometheus, Alertmanager, Grafana, node_exporter, cAdvisor and blackbox_exporter with SSH probes and starter alert rules |
| [docs/cloud-init-for-proxmox-and-cloud-vms.md](./docs/cloud-init-for-proxmox-and-cloud-vms.md) | Cloud-init user-data guide: users and keys, sshd hardening, packages, UFW baseline, and attaching on Proxmox and AWS |
| [reference/cloud-cli-cheatsheet.md](./reference/cloud-cli-cheatsheet.md) | AWS CLI and Azure CLI quick reference for identity, instances, security groups, storage, public-exposure checks, cost and remote shells |

## Getting Started

Start with [terraform/](./terraform/) for infrastructure-as-code examples, [docker-compose/](./docker-compose/) for container stacks, or [docs/](./docs/) for guides.

---

**Author:** Danny Stanfield · Perth, WA
**License:** MIT
