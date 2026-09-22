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
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  key_name                    = aws_key_pair.technova.key_name
  iam_instance_profile        = data.aws_iam_instance_profile.lab_role.name
  associate_public_ip_address = true

  # Referenciar o endpoint do RDS aqui cria uma dependência implícita:
  # o Terraform só cria a EC2 depois que o RDS estiver "available".
  user_data = <<-EOF
    #!/bin/bash
    set -e

    dnf install -y postgresql15

    # Extra (bônus): testa a conexão EC2 -> RDS automaticamente no boot e
    # salva o resultado em log. Uso exclusivo de laboratório — a senha só
    # existe enquanto esta instância efêmera está no ar.
    LOGFILE=/var/log/technova-db-test.log
    echo "=== Teste automatico de conexao EC2 -> RDS ===" > $LOGFILE
    date >> $LOGFILE

    export PGPASSWORD='${var.db_password}'

    for i in $(seq 1 20); do
      if psql -h "${aws_db_instance.main.address}" \
              -U "${var.db_username}" \
              -d "${var.db_name}" \
              -p 5432 \
              -c "SELECT version();" >> $LOGFILE 2>&1; then
        echo "Conexao OK na tentativa $i" >> $LOGFILE
        break
      fi
      echo "Tentativa $i falhou, aguardando 30s..." >> $LOGFILE
      sleep 30
    done
  EOF

  tags = {
    Name = "${var.project_name}-api"
  }
}
