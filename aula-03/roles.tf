###############################################################################
# TRUST POLICY - quem pode assumir a role
###############################################################################
# Principal e o servico EC2, nao um usuario. E isso que permite a instancia
# receber credenciais temporarias automaticamente, sem access key gravada
# em disco ou em variavel de ambiente na maquina.

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    sid     = "PermitirEC2AssumirRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${local.prefix}-ec2-role"
  description        = "Role assumida por instancias EC2 para acessar os buckets de dados da aplicacao"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-ec2-role"
  })
}

###############################################################################
# PERMISSIONS POLICY - o que a role pode fazer
###############################################################################
# Escopo mais estreito que o dos usuarios: apenas technova-app-data-*,
# e nao todos os buckets technova-*. A aplicacao so enxerga os proprios dados.

data "aws_iam_policy_document" "ec2_app_data" {
  statement {
    sid    = "ListarBucketsDeDados"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::technova-app-data-*",
    ]
  }

  statement {
    sid    = "LerEscreverDadosDaAplicacao"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::technova-app-data-*/*",
    ]
  }
}

resource "aws_iam_policy" "ec2_app_data" {
  name        = "${local.prefix}-ec2-app-data"
  description = "Read/Write restrito aos buckets technova-app-data-*"
  policy      = data.aws_iam_policy_document.ec2_app_data.json

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-ec2-app-data"
  })
}

resource "aws_iam_role_policy_attachment" "ec2_role_app_data" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_app_data.arn
}

###############################################################################
# INSTANCE PROFILE - o "adaptador" entre a role e a instancia EC2
###############################################################################
# Uma instancia EC2 nao recebe uma role diretamente: ela recebe um instance
# profile, que e o container que carrega a role.

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-ec2-profile"
  })
}
