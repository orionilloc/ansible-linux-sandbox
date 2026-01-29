#main.tf

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_ami" "debian_12" {
  most_recent = true
  owners      = ["136693071363"] # Debian Official
  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }
}

resource "aws_iam_role" "lab_role" {
  name_prefix = "${var.project_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.lab_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "lab_profile" {
  name_prefix = "${var.project_name}-profile"
  role        = aws_iam_role.lab_role.name
}

resource "aws_instance" "ansible_control" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.generated_key.key_name
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.sg_control.id]
  iam_instance_profile        = aws_iam_instance_profile.lab_profile.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user-data.sh", {
    inventory_content = templatefile("${path.module}/inventory.ini", {
      al2023_ip = aws_instance.al2023_managed_node.private_ip
      debian_ip = aws_instance.debian_managed_node.private_ip
    }),
    private_key_pem = tls_private_key.key.private_key_pem
  })

  tags = { Name = "${var.project_name}-Control" }
}

resource "aws_instance" "al2023_managed_node" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.generated_key.key_name
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_managed.id]
  iam_instance_profile   = aws_iam_instance_profile.lab_profile.name
  tags = { Name = "${var.project_name}-AL2023-Managed" }
}

resource "aws_instance" "debian_managed_node" {
  ami                    = data.aws_ami.debian_12.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.generated_key.key_name
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_managed.id]
  iam_instance_profile   = aws_iam_instance_profile.lab_profile.name
  tags = { Name = "${var.project_name}-Debian-Managed" }
}