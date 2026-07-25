#main.tf

terraform {
  backend "s3" {
    key          = "ansible-sandbox/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}


data "aws_caller_identity" "current" {}

data "aws_s3_bucket" "state_bucket" {
  bucket = "ansible-linux-sandbox-tf-state-${data.aws_caller_identity.current.account_id}"
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
  owners      = ["136693071363"]
  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

data "aws_ami" "fedora" {
  most_recent = true
  owners      = ["125523088429"]
  filter {
    name   = "name"
    values = ["Fedora-Cloud-Base-*x86_64*"]
  }
}

data "aws_ami" "rhel" {
  most_recent = true
  owners      = ["309956199498"]
  filter {
    name   = "name"
    values = ["RHEL-*_HVM-*-x86_64-*-Hourly2-GP3"]
  }
}

data "aws_ami" "opensuse" {
  most_recent = true
  owners      = ["679593333241"]
  filter {
    name   = "name"
    values = ["openSUSE-Leap-*-v*-hvm-ssd-x86_64*"]
  }
}

resource "aws_iam_role" "lab_role" {
  name_prefix = "${var.project_name}-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.lab_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ssm_communication" {
  name = "ssm-communication"
  role = aws_iam_role.lab_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:StartSession", "ssm:SendCommand", "ssm:TerminateSession", "ssm:ResumeSession"]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_access" {
  name = "s3-access-for-ansible"
  role = aws_iam_role.lab_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          data.aws_s3_bucket.state_bucket.arn,
          "${data.aws_s3_bucket.state_bucket.arn}/*"
        ]
      },
      {
        Effect   = "Deny"
        Action   = ["s3:DeleteObject", "s3:PutObject"]
        Resource = ["${data.aws_s3_bucket.state_bucket.arn}/ansible-sandbox/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_describe" {
  name = "ec2-describe-for-dynamic-inventory"
  role = aws_iam_role.lab_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ec2:DescribeTags"]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "lab_profile" {
  name_prefix = "${var.project_name}-profile"
  role        = aws_iam_role.lab_role.name
}

resource "aws_instance" "ansible_control" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private_subnet.id
  vpc_security_group_ids      = [aws_security_group.sg_control.id]
  iam_instance_profile        = aws_iam_instance_profile.lab_profile.name
  associate_public_ip_address = false

  user_data = templatefile("${path.module}/user-data.sh", {
    ansible_configuration = file("${path.module}/ansible.cfg")
    dynamic_inventory_config = templatefile("${path.module}/aws_ec2.yml", {
      s3_bucket_name = data.aws_s3_bucket.state_bucket.id
    })
  })

  depends_on = [
    aws_instance.al2023_managed_node,
    aws_instance.debian_managed_node,
    aws_instance.ubuntu_managed_node,
    aws_instance.fedora_managed_node,
    aws_instance.rhel_managed_node,
    aws_instance.opensuse_managed_node
  ]

  tags = { Name = "${var.project_name}-Control", AnsibleGroup = "control" }
}

resource "aws_instance" "al2023_managed_node" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_managed.id]
  iam_instance_profile   = aws_iam_instance_profile.lab_profile.name
  user_data              = <<-EOF
              #!/bin/env bash
              set -euo pipefail
              exec > >(tee /var/log/user-data.log) 2>&1

              echo "set enable-bracketed-paste off" >> /etc/inputrc
              echo "set enable-bracketed-paste off" >> /etc/skel/.inputrc
              EOF

  tags = { Name = "${var.project_name}-AL2023-Managed", AnsibleGroup = "al2023" }
}

resource "aws_instance" "debian_managed_node" {
  ami                    = data.aws_ami.debian_12.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_managed.id]
  iam_instance_profile   = aws_iam_instance_profile.lab_profile.name

  user_data = <<-EOF
              #!/bin/env bash
              set -euo pipefail
              exec > >(tee /var/log/user-data.log) 2>&1

              apt-get update
              apt-get install -y python3
              mkdir /tmp/ssm
              curl https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb -o /tmp/ssm/amazon-ssm-agent.deb
              dpkg -i /tmp/ssm/amazon-ssm-agent.deb
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              EOF

  tags = { Name = "${var.project_name}-Debian-Managed", AnsibleGroup = "debian" }
}

resource "aws_instance" "ubuntu_managed_node" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_managed.id]
  iam_instance_profile   = aws_iam_instance_profile.lab_profile.name
  tags                   = { Name = "${var.project_name}-Ubuntu-Managed", AnsibleGroup = "ubuntu" }
}

resource "aws_instance" "fedora_managed_node" {
  ami                    = data.aws_ami.fedora.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_managed.id]
  iam_instance_profile   = aws_iam_instance_profile.lab_profile.name
  user_data              = <<-EOF
                           #!/bin/env bash
                           set -euo pipefail
                           exec > >(tee /var/log/user-data.log) 2>&1

                           dnf install -y python3
                           dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
                           dnf install -y python3-libdnf5
                           systemctl enable --now amazon-ssm-agent
                           echo "set enable-bracketed-paste off" >> /etc/inputrc
                           echo "set enable-bracketed-paste off" >> /etc/skel/.inputrc
                           EOF
  tags                   = { Name = "${var.project_name}-Fedora-Managed", AnsibleGroup = "fedora" }
}

resource "aws_instance" "rhel_managed_node" {
  ami                    = data.aws_ami.rhel.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_managed.id]
  iam_instance_profile   = aws_iam_instance_profile.lab_profile.name
  user_data              = <<-EOF
                           #!/bin/env bash
                           set -euo pipefail
                           exec > >(tee /var/log/user-data.log) 2>&1

                           yum install -y python3
                           yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
                           systemctl enable --now amazon-ssm-agent
                           echo "set enable-bracketed-paste off" >> /etc/inputrc
                           echo "set enable-bracketed-paste off" >> /etc/skel/.inputrc
                           EOF
  tags                   = { Name = "${var.project_name}-RHEL-Managed", AnsibleGroup = "rhel" }
}

resource "aws_instance" "opensuse_managed_node" {
  ami                    = data.aws_ami.opensuse.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_managed.id]
  iam_instance_profile   = aws_iam_instance_profile.lab_profile.name
  user_data              = <<-EOF
                           #!/bin/env bash
                           set -euo pipefail
                           exec > >(tee /var/log/user-data.log) 2>&1

                           until zypper refresh; do
                           echo "zypper not ready for additional package installs. Retrying..."
                           sleep 5
                           done

                           zypper install -y python3
                           rpm -i https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
                           systemctl enable --now amazon-ssm-agent
                           EOF
  tags                   = { Name = "${var.project_name}-SUSE-Managed", AnsibleGroup = "opensuse" }
}
