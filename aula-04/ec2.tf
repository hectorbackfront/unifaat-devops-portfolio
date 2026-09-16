data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_key_pair" "technova" {
  key_name   = var.key_name
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = {
    Name = var.key_name
  }
}

resource "aws_instance" "api" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.api.id]
  key_name                    = aws_key_pair.technova.key_name
  iam_instance_profile        = data.aws_iam_instance_profile.lab_role.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash

    set -e

    dnf install -y git

    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
    dnf install -y nodejs

    node --version
    npm --version

    cd /opt

    git clone ${var.api_repository} technova-api

    cd /opt/technova-api/entregas/aula-01/aula-01/app

    npm install

    nohup npm start > /var/log/technova-api.log 2>&1 &
  EOF

  tags = {
    Name = "technova-api"
  }
}
