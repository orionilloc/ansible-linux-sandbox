#outputs.tf

output "aws_region"   { value = var.aws_region }
output "project_name" { value = var.project_name }
output "s3_bucket_name" { value = data.aws_s3_bucket.state_bucket.id }

output "ansible_control_id"        { value = aws_instance.ansible_control.id }
output "ansible_control_private_ip" { value = aws_instance.ansible_control.private_ip }

output "al2023_managed_id"   { value = aws_instance.al2023_managed_node.id }
output "debian_managed_id"   { value = aws_instance.debian_managed_node.id }
output "ubuntu_managed_id"   { value = aws_instance.ubuntu_managed_node.id }
output "fedora_managed_id"   { value = aws_instance.fedora_managed_node.id }
output "rhel_managed_id"     { value = aws_instance.rhel_managed_node.id }
output "opensuse_managed_id" { value = aws_instance.opensuse_managed_node.id }

output "al2023_managed_private_ip"   { value = aws_instance.al2023_managed_node.private_ip }
output "debian_managed_private_ip"   { value = aws_instance.debian_managed_node.private_ip }
output "ubuntu_managed_private_ip"   { value = aws_instance.ubuntu_managed_node.private_ip }
output "fedora_managed_private_ip"   { value = aws_instance.fedora_managed_node.private_ip }
output "rhel_managed_private_ip"     { value = aws_instance.rhel_managed_node.private_ip }
output "opensuse_managed_private_ip" { value = aws_instance.opensuse_managed_node.private_ip }
