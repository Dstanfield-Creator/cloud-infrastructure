output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "The two AZs in use."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs (NAT gateway lives in the first one)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (instance lives in the first one)."
  value       = aws_subnet.private[*].id
}

output "nat_gateway_public_ip" {
  description = "Elastic IP of the NAT gateway. This is the source address for all outbound traffic from private subnets."
  value       = aws_eip.nat.public_ip
}

output "instance_security_group_id" {
  description = "Security group attached to the instance (no ingress rules)."
  value       = aws_security_group.instance.id
}

output "instance_role_arn" {
  description = "IAM role assumed by the instance."
  value       = aws_iam_role.instance.arn
}

output "instance_id" {
  description = "EC2 instance ID. Pass this to aws ssm start-session --target."
  value       = aws_instance.this.id
}

output "instance_private_ip" {
  description = "Private IPv4 address of the instance."
  value       = aws_instance.this.private_ip
}

output "ami_id" {
  description = "AMI the instance was launched from."
  value       = aws_instance.this.ami
}

output "ssm_session_command" {
  description = "Ready-to-run command to open a shell on the instance."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.this.id}"
}
