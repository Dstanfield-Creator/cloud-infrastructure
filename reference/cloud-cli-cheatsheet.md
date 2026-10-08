# Cloud CLI Cheatsheet

> Day-to-day AWS CLI and Azure CLI commands for identity, instances, networking, storage, public-exposure checks, cost and remote shells.

**Status:** Active · **Updated:** 2026-10-08

## Conventions

- AWS CLI v2 and Azure CLI 2.x. Placeholders use `example.com`, `192.0.2.x`, AWS account `123456789012`, and IDs such as `i-0123456789abcdef0`, `rg-example`, `vm-example`, `stexample`.
- `--query` is JMESPath on both CLIs. `--output table` for reading, `--output text` (AWS) or `--output tsv` (Azure) for scripts.
- Credentials come from `aws configure sso` or `AWS_PROFILE`, and from `az login`. Never paste access keys into a shell; they end up in history.

## Identity and context

| Task | AWS | Azure |
|---|---|---|
| Who am I | `aws sts get-caller-identity` | `az account show --output table` |
| Current config | `aws configure list` | `az account list --query '[].{Name:name,ID:id,Default:isDefault}' --output table` |
| Switch context | `export AWS_PROFILE=sandbox` | `az account set --subscription "<subscription-id>"` |

## Instances and VMs

```bash
# AWS: one row per instance with its Name tag
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{ID:InstanceId,Name:Tags[?Key==`Name`]|[0].Value,Type:InstanceType,State:State.Name,IP:PrivateIpAddress,AZ:Placement.AvailabilityZone}' \
  --output table
aws ec2 describe-instances --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].InstanceId' --output text
aws ec2 start-instances --instance-ids i-0123456789abcdef0
aws ec2 stop-instances  --instance-ids i-0123456789abcdef0

# Azure: -d adds power state and IPs
az vm list -d --query '[].{Name:name,RG:resourceGroup,Size:hardwareProfile.vmSize,State:powerState,IP:privateIps,PublicIP:publicIps}' --output table
az vm start      --resource-group rg-example --name vm-example
az vm deallocate --resource-group rg-example --name vm-example   # "az vm stop" keeps billing the compute
```

## Security groups and NSGs

```bash
# AWS: rules for one group
aws ec2 describe-security-groups --group-ids sg-0123456789abcdef0 \
  --query 'SecurityGroups[].IpPermissions[].{Proto:IpProtocol,From:FromPort,To:ToPort,CIDRs:join(`,`,IpRanges[].CidrIp)}' --output table
# AWS: groups that allow 22/tcp from anywhere ("all traffic" rules have no FromPort; check those separately)
aws ec2 describe-security-groups \
  --filters Name=ip-permission.cidr,Values=0.0.0.0/0 Name=ip-permission.from-port,Values=22 \
  --query 'SecurityGroups[].{ID:GroupId,Name:GroupName,VPC:VpcId}' --output table

# Azure: inbound allow rules on an NSG, defaults included
az network nsg rule list --resource-group rg-example --nsg-name nsg-example --include-default \
  --query "[?direction=='Inbound' && access=='Allow'].{Name:name,Prio:priority,Port:destinationPortRange,Source:sourceAddressPrefix}" --output table
# Azure: rules open to the Internet on 22 or on every port
az network nsg rule list --resource-group rg-example --nsg-name nsg-example \
  --query "[?direction=='Inbound' && access=='Allow' && (sourceAddressPrefix=='*' || sourceAddressPrefix=='Internet') && (destinationPortRange=='22' || destinationPortRange=='*')].name" --output tsv
# Azure: effective rules on a NIC (subnet NSG plus NIC NSG combined)
az network nic list-effective-nsg --resource-group rg-example --name nic-example --output table
```

## Object storage

```bash
# AWS S3
aws s3 ls
aws s3 ls s3://example-bucket/ --recursive --human-readable --summarize
aws s3api get-public-access-block --bucket example-bucket
aws s3api get-bucket-policy-status --bucket example-bucket --query PolicyStatus.IsPublic
aws s3control get-public-access-block --account-id 123456789012          # account-wide block
# Every bucket whose policy makes it public ("no-policy" means no bucket policy at all)
for b in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
  printf '%s: ' "$b"
  aws s3api get-bucket-policy-status --bucket "$b" --query PolicyStatus.IsPublic --output text 2>/dev/null || echo no-policy
done

# Azure Blob (null for PublicBlobs means the account default, which is false on accounts created since late 2023)
az storage account list --query '[].{Name:name,RG:resourceGroup,PublicBlobs:allowBlobPublicAccess,TLS:minimumTlsVersion}' --output table
az storage account list --query '[?allowBlobPublicAccess==`true`].name' --output tsv
az storage container list --account-name stexample --auth-mode login \
  --query '[].{Name:name,Public:properties.publicAccess}' --output table
az storage blob list --account-name stexample --container-name backups --auth-mode login \
  --query '[].{Name:name,Size:properties.contentLength,Modified:properties.lastModified}' --output table
```

## Cost

```bash
# AWS Cost Explorer: must be enabled once in the console; each API call costs USD 0.01
aws ce get-cost-and-usage --time-period Start=2026-09-01,End=2026-10-01 --granularity MONTHLY \
  --metrics UnblendedCost --query 'ResultsByTime[].Total.UnblendedCost.[Amount,Unit]' --output text
aws ce get-cost-and-usage --time-period Start=2026-09-01,End=2026-10-01 --granularity MONTHLY \
  --metrics UnblendedCost --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[].Groups[].[Keys[0],Metrics.UnblendedCost.Amount]' --output table

# Azure consumption (current subscription; dates are inclusive)
az consumption usage list --start-date 2026-09-01 --end-date 2026-09-30 \
  --query '[].{Service:consumedService,Resource:instanceName,Cost:pretaxCost,Currency:currency}' --output table
```

## Remote shells without inbound SSH

```bash
# AWS Systems Manager Session Manager: needs the session-manager-plugin locally and an
# instance role with AmazonSSMManagedInstanceCore (see terraform/aws-vpc-ec2-baseline)
aws ssm describe-instance-information \
  --query 'InstanceInformationList[].{ID:InstanceId,Ping:PingStatus,OS:PlatformName,Agent:AgentVersion}' --output table
aws ssm start-session --target i-0123456789abcdef0
aws ssm start-session --target i-0123456789abcdef0 --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["5432"],"localPortNumber":["15432"]}'

# Azure
az extension add --name ssh
az ssh vm --resource-group rg-example --name vm-example        # Entra ID login; VM needs the AADSSHLoginForLinux extension
az ssh vm --ip 192.0.2.20 --local-user admin --private-key-file ~/.ssh/id_ed25519   # key-based login to a local account
```

---

**Author:** Danny Stanfield · Perth, WA  
**License:** MIT
