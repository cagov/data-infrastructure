##################################
#         Bastion Host           #
##################################

data "aws_ami" "bastion" {
  count       = var.enable_rds ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_eip" "bastion" {
  count    = var.enable_rds ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.bastion[0].id

  tags = {
    Name = "${local.prefix}-bastion"
  }
}

resource "aws_security_group" "bastion" {
  count       = var.enable_rds ? 1 : 0
  name        = "${local.prefix}-bastion-sg"
  description = "Bastion host for RDS SSH tunnel access"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "SSH from allowed CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_ssh_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-bastion-sg"
  }
}

resource "aws_iam_role" "bastion" {
  count = var.enable_rds ? 1 : 0
  name  = "${local.prefix}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  count      = var.enable_rds ? 1 : 0
  role       = aws_iam_role.bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  count = var.enable_rds ? 1 : 0
  name  = "${local.prefix}-bastion-profile"
  role  = aws_iam_role.bastion[0].name
}

resource "aws_instance" "bastion" {
  count         = var.enable_rds ? 1 : 0
  ami           = data.aws_ami.bastion[0].id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public[0].id

  vpc_security_group_ids = [aws_security_group.bastion[0].id]
  iam_instance_profile   = aws_iam_instance_profile.bastion[0].name

  # We launch the instance with the list of known public keys.
  # If that list changes, we force recration of the instance.
  # A little heavy-handed, but favors configuration over code,
  # and the IP stays the same.
  user_data = <<-EOF
    #!/bin/bash
    %{ for key in var.bastion_authorized_keys ~}
    echo "${key}" >> /home/ec2-user/.ssh/authorized_keys
    %{ endfor ~}
  EOF

  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  tags = {
    Name = "${local.prefix}-bastion"
  }
}
