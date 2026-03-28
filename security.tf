#security.tf

resource "aws_security_group" "sg_control" {
  vpc_id      = aws_vpc.lab_vpc.id
  name        = "${var.project_name}-control-sg"
  description = "Allow for SSM-managed Control Node"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ControlSG" }
}

resource "aws_security_group" "sg_managed" {
  vpc_id      = aws_vpc.lab_vpc.id
  name        = "${var.project_name}-managed-sg"
  description = "Allow internal traffic from Control Node"

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.sg_control.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ManagedSG" }
}
