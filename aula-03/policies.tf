###############################################################################
# POLICY 1 - S3 somente leitura (Group: developers)
###############################################################################
# Menor privilégio: apenas as duas actions necessárias para ler objetos,
# restritas aos buckets do projeto (technova-*). Nada de "s3:*".

data "aws_iam_policy_document" "s3_read" {
  statement {
    sid    = "ListarBucketsDoProjeto"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::technova-*",
    ]
  }

  statement {
    sid    = "LerObjetosDoProjeto"
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::technova-*/*",
    ]
  }
}

resource "aws_iam_policy" "s3_read" {
  name        = "${local.prefix}-s3-read"
  description = "Leitura de objetos nos buckets technova-* (menor privilegio)"
  policy      = data.aws_iam_policy_document.s3_read.json

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-s3-read"
  })
}

###############################################################################
# POLICY 2 - EC2 + S3 completo (Group: platform-eng)
###############################################################################
# Start/Stop exigem Condition por tag: o engenheiro só liga/desliga
# instâncias marcadas como Project=TechNova, não a frota inteira da conta.

data "aws_iam_policy_document" "ec2_s3_full" {
  statement {
    sid    = "DescreverRecursosEC2"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeTags",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "LigarDesligarInstanciasDoProjeto"
    effect = "Allow"
    actions = [
      "ec2:StartInstances",
      "ec2:StopInstances",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid    = "ListarBucketsDoProjeto"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::technova-*",
    ]
  }

  statement {
    sid    = "LerEscreverObjetosDoProjeto"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::technova-*/*",
    ]
  }
}

resource "aws_iam_policy" "ec2_s3_full" {
  name        = "${local.prefix}-ec2-s3-full"
  description = "EC2 describe + start/stop por tag e S3 read/write nos buckets technova-*"
  policy      = data.aws_iam_policy_document.ec2_s3_full.json

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-ec2-s3-full"
  })
}

###############################################################################
# POLICY 3 - Deny explícito de acoes destrutivas (Group: developers)
###############################################################################
# Deny sempre prevalece sobre Allow, inclusive sobre policies da AWS.
# Rede de seguranca: mesmo que alguem anexe uma policy permissiva por engano,
# ninguem deste group apaga bucket, objeto ou instancia.

data "aws_iam_policy_document" "deny_destructive" {
  statement {
    sid    = "NegarAcoesDestrutivas"
    effect = "Deny"
    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "ec2:TerminateInstances",
      "iam:DeleteUser",
      "iam:DeleteRole",
      "iam:DeletePolicy",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deny_destructive" {
  name        = "${local.prefix}-deny-destructive"
  description = "Deny explicito para acoes de exclusao - prevalece sobre qualquer Allow"
  policy      = data.aws_iam_policy_document.deny_destructive.json

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-deny-destructive"
  })
}

###############################################################################
# POLICY 4 - Restricao extra do estagiario (User: lucas-intern)
###############################################################################
# O lucas esta no group developers, entao herda a policy de leitura.
# Esta policy nega qualquer escrita, garantindo o "somente leitura" real.

data "aws_iam_policy_document" "intern_readonly" {
  statement {
    sid    = "NegarQualquerEscrita"
    effect = "Deny"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:PutBucketPolicy",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:RunInstances",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "intern_readonly" {
  name        = "${local.prefix}-intern-readonly"
  description = "Nega escrita para o estagiario - anexada diretamente ao user"
  policy      = data.aws_iam_policy_document.intern_readonly.json

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-intern-readonly"
  })
}

###############################################################################
# ATTACHMENTS
###############################################################################

resource "aws_iam_group_policy_attachment" "developers_s3_read" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.s3_read.arn
}

resource "aws_iam_group_policy_attachment" "developers_deny_destructive" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.deny_destructive.arn
}

resource "aws_iam_group_policy_attachment" "platform_eng_ec2_s3_full" {
  group      = aws_iam_group.platform_eng.name
  policy_arn = aws_iam_policy.ec2_s3_full.arn
}

resource "aws_iam_user_policy_attachment" "lucas_intern_readonly" {
  user       = aws_iam_user.lucas_intern.name
  policy_arn = aws_iam_policy.intern_readonly.arn
}
