#outputs.tf

output "ansible_control_public_ip" { value = aws_instance.ansible_control.public_ip }
output "al2023_managed_private_ip" { value = aws_instance.al2023_managed_node.private_ip }
output "debian_managed_private_ip" { value = aws_instance.debian_managed_node.private_ip }
output "aws_region" { value = var.aws_region }
output "project_name" { value = var.project_name }