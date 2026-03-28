#outputs.tf

output "ansible_control_public_ip" { value = aws_instance.ansible_control.public_ip }
output "al2023_managed_private_ip" { value = aws_instance.al2023_managed_node.private_ip }
output "debian_managed_private_ip" { value = aws_instance.debian_managed_node.private_ip }
output "ubuntu_managed_private_ip" { value = aws_instance.ubuntu_managed_node.private_ip }
output "arch_managed_private_ip"   { value = aws_instance.arch_managed_node.private_ip }
output "ansible_control_id" { value = aws_instance.ansible_control.id }
output "al2023_managed_id"  { value = aws_instance.al2023_managed_node.id }
output "debian_managed_id"  { value = aws_instance.debian_managed_node.id }
output "ubuntu_managed_id"  { value = aws_instance.ubuntu_managed_node.id }
output "arch_managed_id"    { value = aws_instance.arch_managed_node.id }
output "aws_region" { value = var.aws_region }
output "project_name" { value = var.project_name }
